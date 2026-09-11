import SwiftUI
import FinalScoreCore

@main
struct FinalScoreApp: App {
    @State private var library = MatchLibrary(store: MatchStore(directory: .matchesDirectory))

    var body: some Scene {
        WindowGroup {
            MatchListView(library: library)
        }
    }
}

private extension URL {
    /// Where the Matches are kept. The only decision the app makes about
    /// persistence — the snapshots themselves are Core's business (ADR-0001).
    static var matchesDirectory: URL {
        URL.applicationSupportDirectory.appending(path: folderName, directoryHint: .isDirectory)
    }

    /// "Matches", unless a UI test asked for a folder of its own so its run
    /// starts on an empty list and its relaunch finds the same Matches again.
    /// Debug-only: a release build can't be pointed away from the real folder.
    private static var folderName: String {
        #if DEBUG
        ProcessInfo.processInfo.environment["MATCHES_FOLDER"] ?? "Matches"
        #else
        "Matches"
        #endif
    }
}
