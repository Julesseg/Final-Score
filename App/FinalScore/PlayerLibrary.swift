import Observation
import OSLog
import FinalScoreCore

/// The user's Player roster — an observable view of Core's `PlayerStore`.
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
    /// name, or when the roster couldn't be written.
    func add(named name: String) -> Player? {
        defer { players = store.players }
        return attempt("add \(name)") { try store.add(named: name) } ?? nil
    }

    func rename(_ player: Player, to name: String) {
        attempt("rename \(player.id)") { try store.rename(player.id, to: name) }
        players = store.players
    }

    func delete(_ player: Player) {
        attempt("delete \(player.id)") { try store.delete(player.id) }
        players = store.players
    }

    /// A write that fails is logged rather than raised, as in `MatchLibrary`:
    /// the change still holds for the rest of the session.
    @discardableResult
    private func attempt<Result>(_ change: String, _ body: () throws -> Result) -> Result? {
        do {
            return try body()
        } catch {
            Logger.persistence.error(
                "Could not \(change, privacy: .private) on the roster: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}
