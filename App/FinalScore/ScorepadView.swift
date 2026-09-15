import SwiftUI
import FinalScoreCore

/// The paper scorepad: one column per Team, one row per Round, Totals along
/// the bottom. Tapping a Score opens the keypad on it, however old the Round;
/// swiping a Round, or its menu, deletes it. What each gesture and key does is
/// `Scorepad`'s business, in Core. In a Game that tracks the Dealer, a badge
/// marks who deals each Round, and tapping it hands the deal to someone else.
/// Each Team's column wears its own colour, so its Total reads from across the
/// table.
struct ScorepadView: View {
    @Binding var match: Match
    /// Sets up a Rematch of the Match, once it is ended.
    let onRematch: () -> Void
    @State private var scorepad: Scorepad
    @State private var isConfirmingEnd = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(match: Binding<Match>, onRematch: @escaping () -> Void) {
        _match = match
        self.onRematch = onRematch
        _scorepad = State(initialValue: Scorepad(match: match.wrappedValue))
    }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        MatchBanner(match: scorepad.match, onEnd: { isConfirmingEnd = true }, onRematch: onRematch)
                        grid
                    }
                    if scorepad.selection != nil {
                        Divider()
                        keypad
                            .frame(width: 280)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    MatchBanner(match: scorepad.match, onEnd: { isConfirmingEnd = true }, onRematch: onRematch)
                    grid
                    if scorepad.selection != nil {
                        Divider()
                        keypad
                    }
                }
            }
        }
        .tint(game.accent.color)
        .celebrating(scorepad.match)
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            GameTitle(game: game)
            if !scorepad.match.isEnded {
                ToolbarItem(placement: .primaryAction) {
                    Button("End Match", systemImage: "flag.checkered") { isConfirmingEnd = true }
                        .accessibilityIdentifier("endMatchButton")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Round", systemImage: "plus") { scorepad.startNewRound() }
                        .disabled(!scorepad.match.canStartNewRound)
                        .accessibilityIdentifier("newRoundButton")
                }
            }
        }
        .alert("End this Match?", isPresented: $isConfirmingEnd) {
            Button("Cancel", role: .cancel) {}
            Button("End Match") { scorepad.endMatch() }
        } message: {
            Text(endMessage)
        }
        .onChange(of: scorepad.match) { _, updated in
            match = updated
        }
    }

    private var game: Game { scorepad.match.game }
    private var teams: [Team] { scorepad.match.teams }

    /// Warns when ending will give a Team still unscored in the last Round a 0.
    private var endMessage: String {
        let match = scorepad.match
        let unscored = match.rounds.last.map { match.unscoredTeams(in: $0) } ?? []
        let zeroes = unscored.isEmpty || unscored.count == teams.count
            ? ""
            : "\(unscored.map(\.name).formatted(.list(type: .and))) will score 0 this Round. "
        return zeroes + "Scores can still be corrected afterwards."
    }

    // MARK: Keypad

    private var keypad: some View {
        KeypadView(target: $scorepad, title: keypadTitle, nextTitle: nextTitle) { scorepad.next() }
    }

    /// "Grace · Round 2"
    private var keypadTitle: String {
        guard let selection = scorepad.selection,
              let team = teams.first(where: { $0.id == selection.team }),
              let round = scorepad.match.number(of: selection.round)
        else { return "" }
        return "\(team.name) · Round \(round)"
    }

    private var nextTitle: String {
        switch scorepad.nextStep {
        case .nextTeam: "Next"
        case .newRound: "New Round"
        case .done: "Done"
        }
    }

    // MARK: Grid

    private static let roundColumnWidth: CGFloat = 44
    private static let minimumTeamColumnWidth: CGFloat = 76

    private var grid: some View {
        GeometryReader { proxy in
            let columnWidth = max(
                Self.minimumTeamColumnWidth,
                (proxy.size.width - Self.roundColumnWidth) / CGFloat(max(teams.count, 1))
            )
            let contentWidth = Self.roundColumnWidth + columnWidth * CGFloat(teams.count)
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    header(columnWidth: columnWidth)
                    Divider()
                    ScrollViewReader { scroller in
                        List {
                            ForEach(Array(scorepad.match.rounds.enumerated()), id: \.element.id) { index, round in
                                row(round, number: index + 1, columnWidth: columnWidth)
                                    .id(round.id)
                            }
                        }
                        .listStyle(.plain)
                        .onChange(of: scorepad.match.rounds.count) { previous, count in
                            guard count > previous, let last = scorepad.match.rounds.last else { return }
                            withAnimation { scroller.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    Divider()
                    totals(columnWidth: columnWidth)
                }
                .frame(width: max(contentWidth, proxy.size.width), height: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
    }

    private func header(columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("#")
                .foregroundStyle(.secondary)
                .frame(width: Self.roundColumnWidth)
            ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                Text(team.name)
                    .font(.headline)
                    .foregroundStyle(scorepad.match.style(of: team.id))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 4)
                    .frame(width: columnWidth)
                    .accessibilityIdentifier("teamName.\(index)")
            }
        }
        .padding(.vertical, 10)
    }

    private func row(_ round: Round, number: Int, columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("\(number)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(scorepad.match.isPartlyFilled(round) ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                .frame(width: Self.roundColumnWidth)
            ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                score(of: team, in: round, roundNumber: number, teamIndex: index)
                    .frame(width: columnWidth)
            }
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        // A whole Round goes with no undo, so it takes a deliberate tap.
        .swipeActions(allowsFullSwipe: false) {
            deleteButton(for: round)
        }
        // Once the Teams overflow, a sideways drag scrolls the grid instead of
        // swiping, so the Round's menu is the way to delete it at any width.
        .contextMenu {
            deleteButton(for: round)
        }
    }

    private func deleteButton(for round: Round) -> some View {
        Button("Delete Round", systemImage: "trash", role: .destructive) {
            withAnimation { scorepad.deleteRound(round.id) }
        }
    }

    private func score(of team: Team, in round: Round, roundNumber: Int, teamIndex: Int) -> some View {
        let position = Scorepad.Position(round: round.id, team: team.id)
        let points = round.points(for: team.id)
        let isSelected = scorepad.selection == position
        return Button {
            scorepad.select(position)
        } label: {
            Group {
                if let points {
                    Text("\(points)")
                } else if isSelected {
                    Text("0").foregroundStyle(.tertiary)
                } else {
                    Text("·").foregroundStyle(.quaternary)
                }
            }
            .font(.title3.monospacedDigit())
            // Never truncated: a rolling number caught by the columns widening,
            // as the keypad goes away, could otherwise stick as "…".
            .fixedSize(horizontal: true, vertical: false)
            // On the cell rather than its number, so a first Score bumps too.
            .scoreBump(on: points)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8).fill(.tint.opacity(0.15))
                    RoundedRectangle(cornerRadius: 8).strokeBorder(.tint, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("score.\(roundNumber).\(teamIndex)")
        .accessibilityLabel("\(team.name), Round \(roundNumber)")
        .accessibilityValue(points.map(String.init) ?? "Not scored")
        .overlay(alignment: .topLeading) {
            if let dealer = team.players.first(where: { $0.id == round.dealer }) {
                dealerBadge(dealer, in: round, roundNumber: roundNumber)
            }
        }
    }

    /// Marks the Round's Dealer. Tapping it picks someone else to deal — a
    /// misdeal, or "the loser deals" — and later Rounds pass the deal on from them.
    private func dealerBadge(_ dealer: Player, in round: Round, roundNumber: Int) -> some View {
        let choice = Binding<Player.ID>(
            get: { dealer.id },
            set: { scorepad.setDealer($0, inRound: round.id) }
        )
        return Menu {
            Picker("Who deals Round \(roundNumber)?", selection: choice) {
                ForEach(scorepad.match.players) { player in
                    Text(player.name).tag(player.id)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Text("D")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(.tint, in: Circle())
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("dealer.\(roundNumber)")
        .accessibilityLabel("Dealer, Round \(roundNumber)")
        .accessibilityValue(dealer.name)
    }

    private func totals(columnWidth: CGFloat) -> some View {
        let match = scorepad.match
        let leaders = Set(match.leaders.map(\.id))
        // Partial Totals make a partial leader: both are muted until the Round
        // is in, though never so far that a Total stops reading across the table.
        let isPartial = match.totalsArePartial
        let isCompact = verticalSizeClass == .compact
        return VStack(spacing: isCompact ? 0 : 4) {
            HStack(spacing: 0) {
                Text("Σ")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: Self.roundColumnWidth)
                    .accessibilityLabel("Totals")
                ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                    VStack(spacing: 0) {
                        Image(systemName: isPartial ? "crown" : "crown.fill")
                            .font(.caption)
                            .foregroundStyle(isPartial ? AnyShapeStyle(.secondary) : AnyShapeStyle(match.style(of: team.id)))
                            .opacity(leaders.contains(team.id) ? 1 : 0)
                            .accessibilityHidden(!leaders.contains(team.id))
                            .accessibilityLabel("Leading")
                            .accessibilityIdentifier("leader.\(index)")
                        let total = match.total(for: team.id)
                        // Large enough to read from across the table, and
                        // shrunk only when a long Total meets a narrow column.
                        Text("\(total)")
                            .font(.system(size: isCompact ? 34 : 44, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(match.style(of: team.id).opacity(isPartial ? 0.7 : 1))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .padding(.horizontal, 4)
                            .scoreBump(on: total)
                            .accessibilityIdentifier("total.\(index)")
                    }
                    .frame(width: columnWidth)
                }
            }
            if let partial = match.rounds.first(where: match.isPartlyFilled),
               let number = match.number(of: partial.id) {
                Label("Partial Totals — Round \(number) isn't fully scored", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("partialTotalsNotice")
            }
        }
        .padding(.vertical, isCompact ? 4 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
