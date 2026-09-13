import Foundation

extension Game {
    /// The Games that ship with the app, in the order the Game picker lists them.
    public static let builtIns: [Game] = [.belote, .tarot, .rami, .skyjo, .scrabble, .points]

    public static let belote = Game(
        name: "Belote",
        symbol: "suit.club.fill",
        accent: .blue,
        structure: .rounds,
        teamPlay: .teams(of: 2),
        playerCount: 4...4,
        direction: .highWins,
        endCondition: .targetTotal(501),
        // A Round's 162 points are split between the Teams by the cards each
        // took, so a Score lands anywhere in that range and is always typed.
        quickScores: [],
        allowsNegative: false,
        scorers: .everyone,
        tracksDealer: true,
        isBuiltIn: true
    )

    public static let tarot = Game(
        name: "Tarot",
        symbol: "crown.fill",
        accent: .indigo,
        structure: .rounds,
        teamPlay: .individual,
        playerCount: 3...5,
        direction: .highWins,
        endCondition: .none,
        // What a Petite, Garde, Garde sans and Garde contre are worth against
        // each defender when made or lost by nothing. Other Scores are typed.
        quickScores: [25, 50, 100, 150],
        allowsNegative: true,
        scorers: .everyone,
        tracksDealer: true,
        isBuiltIn: true
    )

    public static let rami = Game(
        name: "Rami",
        symbol: "suit.diamond.fill",
        accent: .red,
        structure: .rounds,
        teamPlay: .individual,
        playerCount: 2...6,
        direction: .lowWins,
        endCondition: .targetTotal(100),
        quickScores: [],
        allowsNegative: true,
        scorers: .everyone,
        tracksDealer: true,
        isBuiltIn: true
    )

    public static let skyjo = Game(
        name: "Skyjo",
        symbol: "square.grid.3x3.fill",
        accent: .teal,
        structure: .rounds,
        teamPlay: .individual,
        playerCount: 2...8,
        direction: .lowWins,
        endCondition: .targetTotal(100),
        quickScores: [],
        allowsNegative: true,
        scorers: .everyone,
        tracksDealer: true,
        isBuiltIn: true
    )

    public static let scrabble = Game(
        name: "Scrabble",
        symbol: "textformat.abc",
        accent: .green,
        structure: .rounds,
        teamPlay: .individual,
        playerCount: 2...4,
        direction: .highWins,
        endCondition: .none,
        quickScores: [],
        allowsNegative: true,
        scorers: .everyone,
        tracksDealer: false,
        isBuiltIn: true
    )

    /// The generic counter for any board game: a Tally rather than Rounds.
    public static let points = Game(
        name: "Points",
        symbol: "plusminus",
        accent: .orange,
        structure: .tally,
        teamPlay: .individual,
        playerCount: 2...8,
        direction: .highWins,
        endCondition: .none,
        quickScores: [],
        allowsNegative: true,
        scorers: .everyone,
        tracksDealer: false,
        isBuiltIn: true
    )
}
