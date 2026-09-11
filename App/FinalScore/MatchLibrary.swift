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
    /// Newest first, as the store orders them.
    private(set) var matches: [Match]

    init(store: MatchStore) {
        self.store = store
        matches = store.matches
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
        do {
            try store.save(match)
        } catch {
            Logger.persistence.error(
                "Could not save Match \(match.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        matches = store.matches
    }
}

private extension Logger {
    static let persistence = Logger(subsystem: "com.julesseguin.final-score", category: "persistence")
}
