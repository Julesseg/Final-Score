import Foundation

/// The New Match form: a Game and the names of the Players who will play it.
public struct MatchSetup: Sendable {
    public let game: Game
    public var playerNames: [String]

    public init(game: Game) {
        self.game = game
        self.playerNames = Array(repeating: "", count: game.playerCount.lowerBound)
    }

    public var canAddPlayer: Bool {
        playerNames.count < game.playerCount.upperBound
    }

    public mutating func addPlayer() {
        guard canAddPlayer else { return }
        playerNames.append("")
    }

    public var canRemovePlayer: Bool {
        playerNames.count > game.playerCount.lowerBound
    }

    public mutating func removePlayer(at index: Int) {
        guard canRemovePlayer, playerNames.indices.contains(index) else { return }
        playerNames.remove(at: index)
    }

    public var canStart: Bool {
        game.playerCount.contains(playerNames.count)
            && trimmedNames.allSatisfy { !$0.isEmpty }
    }

    /// The Match these Players start, each as a Team of one; nil until `canStart`.
    public func makeMatch() -> Match? {
        guard canStart else { return nil }
        let teams = trimmedNames.map { Team(players: [Player(name: $0)]) }
        return Match(game: game, teams: teams)
    }

    private var trimmedNames: [String] {
        playerNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
