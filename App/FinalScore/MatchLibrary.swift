import Observation
import FinalScoreCore

/// The Matches the user has started. In memory only for now: nothing survives
/// a relaunch yet.
@MainActor
@Observable
final class MatchLibrary {
    private(set) var matches: [Match] = []

    func add(_ match: Match) {
        matches.insert(match, at: 0)
    }

    func update(_ match: Match) {
        guard let index = matches.firstIndex(where: { $0.id == match.id }) else { return }
        matches[index] = match
    }

    func match(id: Match.ID) -> Match? {
        matches.first { $0.id == id }
    }
}
