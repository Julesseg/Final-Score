import SwiftUI
import FinalScoreCore

/// Home: every Match the user has started, and the way into a new one. Before
/// the first Match, the Games themselves are the way in.
struct MatchListView: View {
    let library: MatchLibrary
    let roster: PlayerLibrary
    let games: GameLibrary
    @State private var path: [Match.ID] = []
    @State private var newMatch: NewMatchRequest?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if library.matches.isEmpty {
                    GameCards(games: games.allGames) { newMatch = NewMatchRequest(game: $0) }
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
                    let rematch = { newMatch = NewMatchRequest(rematching: binding.wrappedValue) }
                    // Keyed on the Match, so a Rematch opened in place of the
                    // finished Match starts from its own state rather than the
                    // finished one's.
                    Group {
                        switch match.game.structure {
                        case .rounds: ScorepadView(match: binding, onRematch: rematch)
                        case .tally: TallyView(match: binding, onRematch: rematch)
                        }
                    }
                    .id(id)
                }
            }
        }
        // On the stack rather than its root, so a Rematch asked for from a
        // pushed Match presents too.
        .sheet(item: $newMatch) { request in
            NewMatchView(
                roster: roster,
                games: games,
                previous: request.rematching ?? library.lastStarted,
                game: request.game,
                onStart: start
            )
        }
    }

    /// Keeps the Match just set up and opens its scorepad in place of
    /// whatever was open, a finished Match included.
    private func start(_ match: Match) {
        library.save(match)
        newMatch = nil
        path = [match.id]
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

/// A New Match being set up: from the button, with no Game yet, from a Game's
/// card, or as a Rematch of a finished Match.
private struct NewMatchRequest: Identifiable {
    let id = UUID()
    let game: Game?
    /// The finished Match whose Game, Teams, Seating order and rotation the
    /// setup opens on. Its own copy of the Game, not the built-in.
    let rematching: Match?

    init(game: Game?) {
        self.game = game
        rematching = nil
    }

    init(rematching finished: Match) {
        game = finished.game
        rematching = finished
    }
}

/// The Games as cards, built-ins first, for a first launch with nothing played
/// yet.
private struct GameCards: View {
    let games: [Game]
    let onChoose: (Game) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick a Game to start scoring")
                    .font(.title3.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(games, id: \.name) { game in
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
