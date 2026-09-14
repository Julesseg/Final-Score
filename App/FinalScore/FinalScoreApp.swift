import SwiftUI
import FinalScoreCore

@main
struct FinalScoreApp: App {
    @State private var library: MatchLibrary
    @State private var roster: PlayerLibrary
    @State private var games: GameLibrary

    init() {
        let matches = MatchStore(directory: .matchesDirectory)
        // Seeded from the Matches, for whoever played before there was a Roster.
        let players = PlayerStore(file: .rosterFile, seedingFrom: matches.newestStartedFirst)
        _library = State(initialValue: MatchLibrary(store: matches))
        _roster = State(initialValue: PlayerLibrary(store: players))
        _games = State(initialValue: GameLibrary(store: GameStore(file: .gamesFile)))
    }

    var body: some Scene {
        WindowGroup {
            MatchListView(library: library, roster: roster, games: games)
        }
    }
}

/// Where the Matches, the Roster and the custom Games are kept. The only
/// decision the app makes about persistence — the files themselves are Core's
/// business (ADR-0001).
private extension URL {
    static var matchesDirectory: URL {
        dataDirectory.appending(path: "Matches", directoryHint: .isDirectory)
    }

    static var rosterFile: URL {
        dataDirectory.appending(path: "Players.json", directoryHint: .notDirectory)
    }

    static var gamesFile: URL {
        dataDirectory.appending(path: "Games.json", directoryHint: .notDirectory)
    }

    /// Application Support, unless a UI test asked for a folder of its own so
    /// its run starts with no Matches, no Players and no custom Games, and its
    /// relaunch finds the same ones again. Debug-only: a release build can't be
    /// pointed away from the real folder.
    private static var dataDirectory: URL {
        #if DEBUG
        if let folder = ProcessInfo.processInfo.environment["DATA_FOLDER"] {
            return URL.applicationSupportDirectory.appending(path: folder, directoryHint: .isDirectory)
        }
        #endif
        return URL.applicationSupportDirectory
    }
}
