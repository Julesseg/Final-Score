import SwiftUI
import FinalScoreCore

/// The paper scorepad: one column per Team, one row per Round, Totals along
/// the bottom. Tapping a Score opens the keypad on it; what to do with each key
/// is `Scorepad`'s business, in Core.
struct ScorepadView: View {
    @Binding var match: Match
    @State private var scorepad: Scorepad
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(match: Binding<Match>) {
        _match = match
        _scorepad = State(initialValue: Scorepad(match: match.wrappedValue))
    }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                HStack(spacing: 0) {
                    grid
                    if scorepad.selection != nil {
                        Divider()
                        KeypadView(scorepad: $scorepad)
                            .frame(width: 280)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    grid
                    if scorepad.selection != nil {
                        Divider()
                        KeypadView(scorepad: $scorepad)
                    }
                }
            }
        }
        .tint(game.accent.color)
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Round", systemImage: "plus") { scorepad.startNewRound() }
                    .disabled(!scorepad.match.canStartNewRound)
                    .accessibilityIdentifier("newRoundButton")
            }
        }
        .onChange(of: scorepad.match) { _, updated in
            match = updated
        }
    }

    private var game: Game { scorepad.match.game }
    private var teams: [Team] { scorepad.match.teams }

    // MARK: Grid

    private static let roundColumnWidth: CGFloat = 44
    private static let minimumTeamColumnWidth: CGFloat = 76

    private var grid: some View {
        GeometryReader { proxy in
            let columnWidth = max(
                Self.minimumTeamColumnWidth,
                (proxy.size.width - Self.roundColumnWidth) / CGFloat(max(teams.count, 1))
            )
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    header(columnWidth: columnWidth)
                    Divider()
                    ScrollViewReader { scroller in
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(scorepad.match.rounds.enumerated()), id: \.element.id) { index, round in
                                    row(round, number: index + 1, columnWidth: columnWidth)
                                        .id(round.id)
                                }
                            }
                        }
                        .onChange(of: scorepad.match.rounds.count) {
                            if let last = scorepad.match.rounds.last {
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
