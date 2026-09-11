import Foundation

/// A ruleset with a scoring system — Skyjo, Tarot. A fixed set of declarative
/// settings, never rules (ADR-0002): the app neither validates nor computes a
/// Score, because the keypad Override covers anything these settings can't say.
public struct Game: Codable, Hashable, Sendable {
    public var name: String
    /// An SF Symbol name.
    public var symbol: String
    public var accent: AccentToken
    public var structure: Structure
    public var teamPlay: TeamPlay
    public var playerCount: ClosedRange<Int>
    public var direction: Direction
    public var endCondition: EndCondition
    /// One-tap values offered on the scorepad; empty hides them.
    public var quickScores: [Int]
    public var allowsNegative: Bool
    public var scorers: Scorers
    public var tracksDealer: Bool
    public var isBuiltIn: Bool

    public init(
        name: String,
        symbol: String,
        accent: AccentToken,
        structure: Structure,
        teamPlay: TeamPlay,
        playerCount: ClosedRange<Int>,
        direction: Direction,
        endCondition: EndCondition,
        quickScores: [Int],
        allowsNegative: Bool,
        scorers: Scorers,
        tracksDealer: Bool,
        isBuiltIn: Bool
    ) {
        self.name = name
        self.symbol = symbol
        self.accent = accent
        self.structure = structure
        self.teamPlay = teamPlay
        self.playerCount = playerCount
        self.direction = direction
        self.endCondition = endCondition
        self.quickScores = quickScores
        self.allowsNegative = allowsNegative
        self.scorers = scorers
        self.tracksDealer = tracksDealer
        self.isBuiltIn = isBuiltIn
    }

    /// A named colour; the app decides how each one renders.
    public enum AccentToken: String, Codable, Hashable, Sendable, CaseIterable {
        case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink
    }

    public enum Structure: String, Codable, Hashable, Sendable {
        /// One row of Scores per Round.
        case rounds
        /// A running Total per Team, with no Rounds.
        case tally
    }

    public enum TeamPlay: Codable, Hashable, Sendable {
        /// Every Player is a Team of one.
        case individual
        /// Players are grouped into Teams of this size.
        case teams(of: Int)
    }

    public enum Direction: String, Codable, Hashable, Sendable {
        case highWins
        case lowWins
    }

    /// The signal that a Match has run its course. Announced, never enforced.
    public enum EndCondition: Codable, Hashable, Sendable {
        case none
        case targetTotal(Int)
        case roundCount(Int)
    }

    public enum Scorers: String, Codable, Hashable, Sendable {
        /// Every Team gets a Score each Round.
        case everyone
        /// Only one Team scores each Round; every other Team gets 0.
        case oneTeamPerRound
    }
}
