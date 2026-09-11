import SwiftUI

@main
struct FinalScoreApp: App {
    @State private var library = MatchLibrary()

    var body: some Scene {
        WindowGroup {
            MatchListView(library: library)
        }
    }
}
