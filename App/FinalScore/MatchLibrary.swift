import Observation
import OSLog
import FinalScoreCore

/// The Matches the user has started — an observable view of Core's
/// `MatchStore`. Every change writes a fresh snapshot: there is no save action
/// to forget, so a Match killed mid-Round comes back mid-Round.
@MainActor
@Observable
final class MatchLibrary {
    private let store: MatchStore
    /// In progress above finished, as the store lists them.
    private(set) var matches: [Match]
    /// The Match started most recently, ended or not: whose Players a new
    /// Match opens with.
    private(set) var lastStarted: Match?

    init(store: MatchStore) {
        self.store = store
        matches = store.matches
        lastStarted = store.newestStartedFirst.first
    }

    func match(id: Match.ID) -> Match? {
        store.match(id: id)
    }

    /// Takes a new or changed Match into the library and writes its snapshot.
    ///
    /// A write that fails is logged rather than raised: the Match stays in play
    /// for the rest of the session and the very next Score writes the whole
    /// snapshot again, so there is nothing to interrupt scoring for.
    func save(_ match: Match) {
        attempt("save Match \(match.id)") { try store.save(match) }
    }

    /// Removes the Match from the library and its snapshot from disk.
    ///
    /// A snapshot that can't be removed is logged rather than raised: the Match
    /// is still gone for the rest of the session, though the next launch may
    /// bring it back.
    func delete(_ id: Match.ID) {
        attempt("delete Match \(id)") { try store.delete(id) }
    }

    /// Makes the change, logging a failure rather than raising it, then takes
    /// the store's Matches as they now stand.
    private func attempt(_ change: String, _ body: () throws -> Void) {
        do {
            try body()
        } catch {
            Logger.persistence.error(
                "Could not \(change, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        matches = store.matches
        lastStarted = store.newestStartedFirst.first
    }
}
