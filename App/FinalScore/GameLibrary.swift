import Foundation
import Observation
import OSLog
import FinalScoreCore

/// The Games the user has authored — an observable view of Core's
/// `GameStore`. Like `MatchLibrary`, every change is written as it happens.
@MainActor
@Observable
final class GameLibrary {
    private let store: GameStore
    /// In the order they were created, as the store lists them.
    private(set) var customGames: [CustomGame]

    init(store: GameStore) {
        self.store = store
        customGames = store.customGames
    }

    /// Every Game to pick from: the built-ins, then the custom Games.
    var allGames: [Game] {
        store.games
    }

    func canSave(_ draft: GameDraft, replacing id: CustomGame.ID?) -> Bool {
        store.canSave(draft, replacing: id)
    }

    func add(_ draft: GameDraft) {
        attempt("add a Game") { _ = try store.add(draft) }
        customGames = store.customGames
    }

    func update(_ id: CustomGame.ID, to draft: GameDraft) {
        attempt("edit a Game") { try store.update(id, to: draft) }
        customGames = store.customGames
    }

    func delete(_ id: CustomGame.ID) {
        attempt("delete a Game") { try store.delete(id) }
        customGames = store.customGames
    }

    func duplicate(_ game: Game) -> GameDraft {
        store.duplicate(game)
    }

    /// A write that fails is logged rather than raised, as in `MatchLibrary`:
    /// the change still holds for the rest of the session.
    private func attempt(_ change: String, _ body: () throws -> Void) {
        do {
            try body()
        } catch {
            Logger.persistence.error(
                "Could not \(change, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
