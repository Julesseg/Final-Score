import Foundation

/// The custom Game form: every setting of a Game, kept coherent as it is
/// edited, so whatever the form shows can always be saved and played.
///
/// Rather than refusing a combination, each change pulls the settings it
/// affects back into line: Teams of 2 move the Player count to whole Teams, a
/// Tally drops the Dealer. The one thing it can't settle alone is the name,
/// which `GameStore.canSave` checks against the other Games.
public struct GameDraft: Hashable, Sendable {
    /// The most Players a custom Game can seat.
    public static let playerLimit = 16

    /// The Game as it stands, never built-in, with its name tidied.
    public var game: Game {
        var game = settings
        game.name = game.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return game
    }

    private var settings: Game

    /// A blank Game: Rounds between 2 and 8 Players, each on their own.
    public init() {
        self.init(game: Game(
            name: "",
            symbol: "suit.heart.fill",
            accent: .blue,
            structure: .rounds,
            teamPlay: .individual,
            playerCount: 2...8,
            direction: .highWins,
            endCondition: .none,
            quickScores: [],
            allowsNegative: true,
            tracksDealer: true,
            isBuiltIn: false
        ))
    }

    /// Opens on the settings of `game`, as a custom Game. Anything incoherent
    /// in it is brought into line the way the form would.
    public init(game: Game) {
        settings = game
        settings.isBuiltIn = false
        teamSize = game.teamPlay.size
        structure = game.structure
        endCondition = game.endCondition
        allowsNegative = game.allowsNegative
    }

    /// Whether there is a name, not counting spaces.
    public var hasName: Bool {
        !game.name.isEmpty
    }

    public var name: String {
        get { settings.name }
        set { settings.name = newValue }
    }

    /// An SF Symbol name.
    public var symbol: String {
        get { settings.symbol }
        set { settings.symbol = newValue }
    }

    public var accent: Game.AccentToken {
        get { settings.accent }
        set { settings.accent = newValue }
    }

    public var direction: Game.Direction {
        get { settings.direction }
        set { settings.direction = newValue }
    }

    // MARK: Players and Teams

    /// How many Players sit on one Team; 1 is individual play. Between 1 and
    /// half the limit, so there is always room for two Teams. The Player count
    /// moves to whole Teams, at least two of them.
    public var teamSize: Int {
        get { settings.teamPlay.size }
        set {
            let size = min(max(newValue, 1), Self.playerLimit / 2)
            settings.teamPlay = size == 1 ? .individual : .teams(of: size)
            setPlayerCount(minPlayers, maxPlayers, keeping: .lowerBound)
        }
    }

    /// The fewest Players, in whole Teams. Raising it past the most Players
    /// raises that too.
    public var minPlayers: Int {
        get { settings.playerCount.lowerBound }
        set { setPlayerCount(newValue, maxPlayers, keeping: .lowerBound) }
    }

    /// The most Players, in whole Teams. Lowering it past the fewest Players
    /// lowers that too.
    public var maxPlayers: Int {
        get { settings.playerCount.upperBound }
        set { setPlayerCount(minPlayers, newValue, keeping: .upperBound) }
    }

    /// The Player counts the form offers: whole Teams, from two Teams up to
    /// the limit.
    public var playerCountRange: ClosedRange<Int> {
        2 * teamSize...(Self.playerLimit / teamSize) * teamSize
    }

    private enum Bound { case lowerBound, upperBound }

    /// Snaps both bounds up to whole Teams within `playerCountRange`; when
    /// they cross, the one just set wins.
    private mutating func setPlayerCount(_ lower: Int, _ upper: Int, keeping kept: Bound) {
        let (lower, upper) = (wholeTeams(lower), wholeTeams(upper))
        settings.playerCount = switch kept {
        case .lowerBound: lower...max(lower, upper)
        case .upperBound: min(lower, upper)...upper
        }
    }

    private func wholeTeams(_ players: Int) -> Int {
        let range = playerCountRange
        let roundedUp = (players + teamSize - 1) / teamSize * teamSize
        return min(max(roundedUp, range.lowerBound), range.upperBound)
    }

    // MARK: Scoring

    /// Rounds or a Tally. A Tally has no Rounds, so it drops the Dealer and
    /// loses a Round count.
    public var structure: Game.Structure {
        get { settings.structure }
        set {
            settings.structure = newValue
            tracksDealer = settings.tracksDealer
            endCondition = settings.endCondition
        }
    }

    /// Only a Rounds Game tracks the Dealer.
    public var tracksDealer: Bool {
        get { settings.tracksDealer }
        set { settings.tracksDealer = newValue && structure == .rounds }
    }

    /// Counts at least 1. A Tally never reaches a Round count, so it has none.
    public var endCondition: Game.EndCondition {
        get { settings.endCondition }
        set {
            settings.endCondition = switch newValue {
            case .none: .none
            case .targetTotal(let target): .targetTotal(max(target, 1))
            case .roundCount where structure == .tally: .none
            case .roundCount(let count): .roundCount(max(count, 1))
            }
        }
    }

    /// Turning negatives off drops any Quick score below 0, which could no
    /// longer be entered.
    public var allowsNegative: Bool {
        get { settings.allowsNegative }
        set {
            settings.allowsNegative = newValue
            settings.quickScores = Self.tidy(settings.quickScores, allowsNegative: newValue)
        }
    }

    // MARK: Quick scores

    /// Ascending, without repeats.
    public var quickScores: [Int] {
        settings.quickScores
    }

    /// Adds a Quick score, unless it is 0 — an untouched Score already records
    /// that — already offered, or below 0 in a Game without negatives.
    public mutating func addQuickScore(_ points: Int) {
        settings.quickScores = Self.tidy(settings.quickScores + [points], allowsNegative: allowsNegative)
    }

    public mutating func removeQuickScores(atOffsets offsets: IndexSet) {
        settings.quickScores = settings.quickScores.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
    }

    private static func tidy(_ quickScores: [Int], allowsNegative: Bool) -> [Int] {
        Set(quickScores)
            .filter { $0 != 0 && (allowsNegative || $0 > 0) }
            .sorted()
    }
}
