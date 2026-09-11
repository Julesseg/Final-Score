import SwiftUI
import FinalScoreCore

/// The paper scorepad: one column per Team, one row per Round, Totals along
/// the bottom. Tapping a cell opens the keypad on it, and every key lands the
/// Score straight away — there is no confirm step.
struct ScorepadView: View {
    @Binding var match: Match
    @State private var selection: Cell?
    @State private var entry = ScoreEntry()
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private struct Cell: Hashable {
        let round: Round.ID
        let team: Team.ID
    }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                HStack(spacing: 0) {
                    grid
                    if selection != nil {
                        Divider()
                        keypad
                            .frame(width: 280)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    grid
                    if selection != nil {
                        Divider()
                        keypad
                    }
                }
            }
        }
        .tint(match.game.accent.color)
        .navigationTitle(match.game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Round", systemImage: "plus", action: startNewRound)
                    .disabled(!match.canStartNewRound)
                    .accessibilityIdentifier("newRoundButton")
            }
        }
        .onAppear(perform: selectFirstUnscoredCell)
    }

    // MARK: Grid

    private static let roundColumnWidth: CGFloat = 44
    private static let minimumTeamColumnWidth: CGFloat = 76

    private var grid: some View {
        GeometryReader { proxy in
            let columnWidth = max(
                Self.minimumTeamColumnWidth,
                (proxy.size.width - Self.roundColumnWidth) / CGFloat(max(match.teams.count, 1))
            )
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    header(columnWidth: columnWidth)
                    Divider()
                    ScrollViewReader { scroller in
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(match.rounds.enumerated()), id: \.element.id) { index, round in
                                    row(round, number: index + 1, columnWidth: columnWidth)
                                        .id(round.id)
                                }
                            }
                        }
                        .onChange(of: match.rounds.count) {
                            if let last = match.rounds.last {
                                withAnimation { scroller.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                    Divider()
                    totals(columnWidth: columnWidth)
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
    }

    private func header(columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("#")
                .foregroundStyle(.secondary)
                .frame(width: Self.roundColumnWidth)
            ForEach(Array(match.teams.enumerated()), id: \.element.id) { index, team in
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
                .foregroundStyle(match.isPartlyFilled(round) ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                .frame(width: Self.roundColumnWidth)
            ForEach(Array(match.teams.enumerated()), id: \.element.id) { index, team in
                cell(Cell(round: round.id, team: team.id), in: round, roundNumber: number, teamIndex: index)
                    .frame(width: columnWidth)
            }
        }
        .padding(.vertical, 2)
    }

    private func cell(_ cell: Cell, in round: Round, roundNumber: Int, teamIndex: Int) -> some View {
        let points = round.points(for: cell.team)
        let isSelected = selection == cell
        return Button {
            select(cell)
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
        .accessibilityIdentifier("cell.\(roundNumber).\(teamIndex)")
        .accessibilityLabel("\(match.teams[teamIndex].name), Round \(roundNumber)")
        .accessibilityValue(points.map(String.init) ?? "Not scored")
    }

    private func totals(columnWidth: CGFloat) -> some View {
        let leaders = Set(match.leaders.map(\.id))
        return VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("Σ")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: Self.roundColumnWidth)
                    .accessibilityLabel("Totals")
                ForEach(Array(match.teams.enumerated()), id: \.element.id) { index, team in
                    VStack(spacing: 0) {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .opacity(leaders.contains(team.id) ? 1 : 0)
                            .accessibilityHidden(!leaders.contains(team.id))
                            .accessibilityLabel("Leading")
                            .accessibilityIdentifier("leader.\(index)")
                        Text("\(match.total(for: team.id))")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(match.totalsArePartial ? .secondary : .primary)
                            .accessibilityIdentifier("total.\(index)")
                    }
                    .frame(width: columnWidth)
                }
            }
            if let partial = match.rounds.firstIndex(where: match.isPartlyFilled) {
                Label("Partial Totals — Round \(partial + 1) isn't fully scored", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("partialTotalsNotice")
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Keypad

    @ViewBuilder
    private var keypad: some View {
        if let selection,
           let roundIndex = match.rounds.firstIndex(where: { $0.id == selection.round }),
           let team = match.teams.first(where: { $0.id == selection.team }) {
            KeypadView(
                title: "\(team.name) · Round \(roundIndex + 1)",
                text: entry.text,
                allowsNegative: match.game.allowsNegative,
                nextTitle: nextKeyTitle,
                onDigit: { entry.type($0); commit() },
                onDelete: { entry.deleteBackward(); commit() },
                onToggleSign: { entry.toggleSign(); commit() },
                onNext: advance,
                onDismiss: { self.selection = nil }
            )
        }
    }

    private var nextTeam: Team.ID? {
        guard let selection,
              let index = match.teams.firstIndex(where: { $0.id == selection.team }),
              index + 1 < match.teams.count
        else { return nil }
        return match.teams[index + 1].id
    }

    private var selectionIsInLastRound: Bool {
        selection?.round == match.rounds.last?.id
    }

    private var nextKeyTitle: String {
        if nextTeam != nil { return "Next" }
        return selectionIsInLastRound ? "New Round" : "Done"
    }

    private func select(_ cell: Cell) {
        selection = cell
        let points = match.rounds.first { $0.id == cell.round }?.points(for: cell.team)
        entry = ScoreEntry(points: points)
    }

    private func commit() {
        guard let selection else { return }
        match.setScore(entry.value, for: selection.team, inRound: selection.round)
    }

    /// Lands the cell's Score — an untouched cell becomes an explicit 0, never a
    /// blank — then moves along the Round, starting a new one after the last Team.
    private func advance() {
        guard let current = selection else { return }
        commit()
        if let nextTeam {
            select(Cell(round: current.round, team: nextTeam))
        } else if selectionIsInLastRound {
            startNewRound()
        } else {
            selection = nil
        }
    }

    private func startNewRound() {
        match.startNewRound()
        selectFirstUnscoredCell()
    }

    private func selectFirstUnscoredCell() {
        guard let round = match.rounds.last,
              let team = match.teams.first(where: { round.points(for: $0.id) == nil })
        else { return }
        select(Cell(round: round.id, team: team.id))
    }
}
