import SwiftUI
import FinalScoreCore

@main
struct FinalScoreApp: App {
    @State private var library: MatchLibrary
    @State private var roster: PlayerLibrary

    init() {
        let matches = MatchStore(directory: .matchesDirectory)
        // Seeded from the Matches, for whoever played before there was a Roster.
        let players = PlayerStore(file: .rosterFile, seedingFrom: matches.matches)
        _library = State(initialValue: MatchLibrary(store: matches))
        _roster = State(initialValue: PlayerLibrary(store: players))
    }

    var body: some Scene {
        WindowGroup {
            MatchListView(library: library, roster: roster)
        }
    }
}

/// Where the Matches and the Roster are kept. The only decision the app makes
/// about persistence — the files themselves are Core's business (ADR-0001).
private extension URL {
    static var matchesDirectory: URL {
        dataDirectory.appending(path: "Matches", directoryHint: .isDirectory)
    }

    static var rosterFile: URL {
        dataDirectory.appending(path: "Players.json", directoryHint: .notDirectory)
    }

    /// Application Support, unless a UI test asked for a folder of its own so
    /// its run starts with no Matches and no Players, and its relaunch finds
    /// the same ones again. Debug-only: a release build can't be pointed away
    /// from the real folder.
    private static var dataDirectory: URL {
        #if DEBUG
        if let folder = ProcessInfo.processInfo.environment["DATA_FOLDER"] {
            return URL.applicationSupportDirectory.appending(path: folder, directoryHint: .isDirectory)
        }
        #endif
        return URL.applicationSupportDirectory
    }
}
