import SwiftUI
import FinalScoreCore

/// Home: every Match the user has started, and the way into a new one. Before
/// the first Match, the Games themselves are the way in.
struct MatchListView: View {
    let library: MatchLibrary
    let roster: PlayerLibrary
    @State private var path: [Match.ID] = []
    @State private var newMatch: NewMatchRequest?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if library.matches.isEmpty {
                    GameCards { newMatch = NewMatchRequest(game: $0) }
                } else {
                    matchList
                }
            }
            .navigationTitle("Matches")
            // Pinned within thumb reach, over whatever scrolls behind it.
            .safeAreaBar(edge: .bottom) {
                Button {
                    newMatch = NewMatchRequest(game: nil)
                } label: {
                    Label("New Match", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .frame(maxWidth: 480)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .accessibilityIdentifier("newMatchButton")
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
            .sheet(item: $newMatch) { request in
                NewMatchView(roster: roster, previous: library.lastStarted, game: request.game) { match in
                    library.save(match)
                    newMatch = nil
                    path = [match.id]
                }
            }
        }
    }

    private var matchList: some View {
        // The library already lists in-progress Matches above finished ones.
        let inProgress = library.matches.filter { !$0.isEnded }
        let finished = library.matches.filter(\.isEnded)
        return List {
            section("In Progress", inProgress)
            section("Finished", finished)
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

/// A New Match being set up: from the button, with no Game yet, or from a
/// Game's card.
private struct NewMatchRequest: Identifiable {
    let id = UUID()
    let game: Game?
}

/// The built-in Games as cards, for a first launch with nothing played yet.
private struct GameCards: View {
    let onChoose: (Game) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick a Game to start scoring")
                    .font(.title3.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(Game.builtIns, id: \.name) { game in
                        Button { onChoose(game) } label: {
                            GameCard(game: game)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("gameCard.\(game.name)")
                    }
                }
            }
            .padding()
        }
    }
}

private struct GameCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GameSymbol(game: game)
            Spacer(minLength: 8)
            Text(game.name)
                .font(.headline)
            Text(game.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .background(game.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MatchRow: View {
    let match: Match

    var body: some View {
        HStack(spacing: 12) {
            GameSymbol(game: match.game)
            VStack(alignment: .leading, spacing: 2) {
                Text(match.teams.map(\.name).formatted(.list(type: .and)))
                    .font(.headline)
                    .lineLimit(1)
                Text(match.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("matchStatus")
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    /// "Skyjo", or "Skyjo · Sep 13, 2026" once finished.
    private var details: String {
        [match.game.name, match.endedAt?.formatted(date: .abbreviated, time: .omitted)]
            .compactMap(\.self)
            .joined(separator: " · ")
    }
}
