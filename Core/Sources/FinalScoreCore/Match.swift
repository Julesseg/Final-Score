import Foundation

/// A Team's points for one Round.
public struct Score: Codable, Hashable, Sendable {
    public var team: Team.ID
    public var points: Int

    public init(team: Team.ID, points: Int) {
        self.team = team
        self.points = points
    }
}

/// One row of the scorepad. A Team with no Score here hasn't been scored yet;
/// a Team that scored nothing holds an explicit 0.
public struct Round: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public private(set) var scores: [Score]

    public init(id: UUID = UUID(), scores: [Score] = []) {
        self.id = id
        self.scores = scores
    }

    /// The Team's points this Round, or nil if it hasn't been scored yet.
    public func points(for team: Team.ID) -> Int? {
        scores.first { $0.team == team }?.points
    }

    mutating func setPoints(_ points: Int, for team: Team.ID) {
        if let index = scores.firstIndex(where: { $0.team == team }) {
            scores[index].points = points
        } else {
            scores.append(Score(team: team, points: points))
        }
    }
}

/// One play of a Game, from setup to a Winner. Holds its own copy of the Game,
/// so later edits to that Game never reach it.
public struct Match: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var game: Game
    public var teams: [Team]
    public private(set) var rounds: [Round]

    /// A new Match opens on an empty first Round, ready to score.
    public init(id: UUID = UUID(), game: Game, teams: [Team]) {
        self.id = id
        self.game = game
        self.teams = teams
        self.rounds = [Round()]
    }

    /// Records a Team's points for a Round, replacing any Score already there.
    public mutating func setScore(_ points: Int, for team: Team.ID, inRound round: Round.ID) {
        guard let index = rounds.firstIndex(where: { $0.id == round }) else { return }
        rounds[index].setPoints(points, for: team)
    }

    /// A new Round is offered once the last one has at least one Score, so the
    /// scorepad never stacks up empty rows.
    public var canStartNewRound: Bool {
        rounds.last.map { !$0.scores.isEmpty } ?? true
    }

    public mutating func startNewRound() {
        guard canStartNewRound else { return }
        rounds.append(Round())
    }

    /// The Team's Scores summed across every Round. Derived, never stored.
    public func total(for team: Team.ID) -> Int {
        rounds.reduce(0) { $0 + ($1.points(for: team) ?? 0) }
    }

    /// The Teams whose Total is best under the Game's Direction — several when
    /// level, none before the first Score.
    public var leaders: [Team] {
        guard rounds.contains(where: { !$0.scores.isEmpty }) else { return [] }
        let totals = teams.map { total(for: $0.id) }
        let best = switch game.direction {
        case .highWins: totals.max()
        case .lowWins: totals.min()
        }
        return zip(teams, totals).filter { $0.1 == best }.map(\.0)
    }

    /// Whether some, but not all, Teams have a Score in this Round.
    public func isPartlyFilled(_ round: Round) -> Bool {
        let scored = teams.filter { round.points(for: $0.id) != nil }.count
        return scored > 0 && scored < teams.count
    }

    /// Whether the Totals are missing Scores from a partly filled Round.
    public var totalsArePartial: Bool {
        rounds.contains(where: isPartlyFilled)
    }
}
