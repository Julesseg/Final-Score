import SwiftUI
import FinalScoreCore

/// Home: every Match the user has started, and the way into a new one.
struct MatchListView: View {
    let library: MatchLibrary
    let roster: PlayerLibrary
    @State private var path: [Match.ID] = []
    @State private var isSettingUp = false

    var body: some View {
        NavigationStack(path: $path) {
            // The library already lists in-progress Matches above finished ones.
            let inProgress = library.matches.filter { !$0.isEnded }
            let finished = library.matches.filter(\.isEnded)
            List {
                section("In Progress", inProgress)
                section("Finished", finished)
            }
            .overlay {
                if library.matches.isEmpty {
                    ContentUnavailableView(
                        "No Matches Yet",
                        systemImage: "list.number",
                        description: Text("Tap New Match to start scoring.")
                    )
                }
            }
            .navigationTitle("Matches")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Match", systemImage: "plus") { isSettingUp = true }
                        .accessibilityIdentifier("newMatchButton")
                }
            }
            .navigationDestination(for: Match.ID.self) { id in
                if let match = library.match(id: id) {
                    let binding = Binding(
                        get: { library.match(id: id) ?? match },
                        set: { library.save($0) }
                    )
                    switch match.game.structure {
                    case .rounds: ScorepadView(match: binding)
                    case .tally: TallyView(match: binding)
                    }
                }
            }
            .sheet(isPresented: $isSettingUp) {
                NewMatchView(roster: roster, previous: library.lastStarted) { match in
                    library.save(match)
                    isSettingUp = false
                    path = [match.id]
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ matches: [Match]) -> some View {
        if !matches.isEmpty {
            Section(title) {
                ForEach(matches) { match in
                    NavigationLink(value: match.id) {
                        MatchRow(match: match)
                    }
                    .accessibilityIdentifier("matchRow")
                }
            }
        }
    }
}

private struct MatchRow: View {
    let match: Match

    var body: some View {
        HStack(spacing: 12) {
            GameSymbol(game: match.game)
            VStack(alignment: .leading, spacing: 2) {
                Text(match.game.name)
                    .font(.headline)
                Text(match.teams.map(\.name).formatted(.list(type: .and)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("matchStatus")
            }
        }
        .padding(.vertical, 2)
    }

    /// "In progress · Round 3", "In progress" for a Tally, "Finished · Grace wins"
    private var status: String {
        guard match.isEnded else {
            return match.game.structure == .rounds ? "In progress · Round \(match.rounds.count)" : "In progress"
        }
        return ["Finished", match.outcomeText].compactMap(\.self).joined(separator: " · ")
    }
}
