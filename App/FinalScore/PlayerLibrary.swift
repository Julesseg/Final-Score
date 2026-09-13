import Observation
import OSLog
import FinalScoreCore

/// The user's Roster — an observable view of Core's `PlayerStore`.
/// Like `MatchLibrary`, every change is written as it happens.
@MainActor
@Observable
final class PlayerLibrary {
    private let store: PlayerStore
    /// Alphabetical, as the store orders them.
    private(set) var players: [Player]

    init(store: PlayerStore) {
        self.store = store
        players = store.players
    }

    /// The new Player, or the one already going by that name; nil for a blank
    /// name.
    func add(named name: String) -> Player? {
        attempt("add a Player") { _ = try store.add(named: name) }
        players = store.players
        // Looked up rather than returned, so a Player whose write failed is
        // still the one handed back.
        return store.player(named: name)
    }

    func canRename(_ player: Player, to name: String) -> Bool {
        store.canRename(player.id, to: name)
    }

    func rename(_ player: Player, to name: String) {
        attempt("rename a Player") { try store.rename(player.id, to: name) }
        players = store.players
    }

    func delete(_ player: Player) {
        attempt("delete a Player") { try store.delete(player.id) }
        players = store.players
    }

    /// A write that fails is logged rather than raised, as in `MatchLibrary`:
    /// the change still holds for the rest of the session.
    private func attempt(_ change: String, _ body: () throws -> Void) {
        do {
            try body()
        } catch {
            Logger.persistence.error(
                "Could not \(change, privacy: .public) on the Roster: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
