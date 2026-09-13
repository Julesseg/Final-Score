import SwiftUI
import FinalScoreCore

/// The paper scorepad: one column per Team, one row per Round, Totals along
/// the bottom. Tapping a Score opens the keypad on it, however old the Round;
/// swiping a Round, or its menu, deletes it. What each gesture and key does is
/// `Scorepad`'s business, in Core.
struct ScorepadView: View {
    @Binding var match: Match
    @State private var scorepad: Scorepad
    @State private var isConfirmingEnd = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(match: Binding<Match>) {
        _match = match
        _scorepad = State(initialValue: Scorepad(match: match.wrappedValue))
    }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        banner
                        grid
                    }
                    if scorepad.selection != nil {
                        Divider()
                        KeypadView(scorepad: $scorepad)
                            .frame(width: 280)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    banner
                    grid
                    if scorepad.selection != nil {
                        Divider()
                        KeypadView(scorepad: $scorepad)
                    }
                }
            }
        }
        .tint(game.accent.color)
        .animation(.default, value: scorepad.match.endConditionIsReached)
        .animation(.default, value: scorepad.match.isEnded)
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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

    // MARK: Banner

    /// Once ended, the Winner; before that, the End condition's announcement
    /// once it is reached. Never in the way of scoring.
    @ViewBuilder
    private var banner: some View {
        let match = scorepad.match
        if match.isEnded {
            Label(match.outcomeText ?? "Match ended", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("outcome")
                .modifier(BannerStyle(isCompact: verticalSizeClass == .compact))
        } else if match.endConditionIsReached, let reason = match.endConditionText {
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(reason)
                        .font(.subheadline.bold())
                    if let standing = match.standingText {
                        Text(standing)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("endConditionNotice")
                Spacer(minLength: 8)
                Button("End Match") { isConfirmingEnd = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("endMatchFromNotice")
            }
            .modifier(BannerStyle(isCompact: verticalSizeClass == .compact))
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
    }

    private func totals(columnWidth: CGFloat) -> some View {
        let match = scorepad.match
        let leaders = Set(match.leaders.map(\.id))
        // Partial Totals make a partial leader: both are muted until the Round is in.
        let style: HierarchicalShapeStyle = match.totalsArePartial ? .secondary : .primary
        return VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("Σ")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: Self.roundColumnWidth)
                    .accessibilityLabel("Totals")
                ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                    VStack(spacing: 0) {
                        Image(systemName: match.totalsArePartial ? "crown" : "crown.fill")
                            .font(.caption)
                            .foregroundStyle(match.totalsArePartial ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                            .opacity(leaders.contains(team.id) ? 1 : 0)
                            .accessibilityHidden(!leaders.contains(team.id))
                            .accessibilityLabel("Leading")
                            .accessibilityIdentifier("leader.\(index)")
                        Text("\(match.total(for: team.id))")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(style)
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
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A full-width strip across the top of the scorepad, slimmer in landscape.
private struct BannerStyle: ViewModifier {
    let isCompact: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal)
            .padding(.vertical, isCompact ? 6 : 10)
            .background(.tint.opacity(0.12))
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
