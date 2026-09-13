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

    mutating func setScore(_ points: Int, for team: Team.ID) {
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
    /// When setup finished and the scorepad opened. What "newest" means when
    /// Matches are listed.
    public let startedAt: Date
    public let game: Game
    /// Composed at setup and fixed for the whole Match.
    public let teams: [Team]
    public private(set) var rounds: [Round]
    /// When the user ended the Match; nil while it is in play. The only thing
    /// stored about the end — the Winner is always derived from the Totals.
    public private(set) var endedAt: Date?

    /// A new Match opens on an empty first Round, ready to score.
    public init(id: UUID = UUID(), startedAt: Date = Date(), game: Game, teams: [Team]) {
        self.id = id
        self.startedAt = startedAt
        self.game = game
        self.teams = teams
        self.rounds = [Round()]
    }

    /// Records a Team's points for a Round, replacing any Score already there.
    public mutating func setScore(_ points: Int, for team: Team.ID, inRound round: Round.ID) {
        guard let index = rounds.firstIndex(where: { $0.id == round }) else { return }
        rounds[index].setScore(points, for: team)
    }

    /// Everyone playing, in Seating order.
    public var players: [Player] {
        teams.flatMap(\.players)
    }

    public func round(_ id: Round.ID) -> Round? {
        rounds.first { $0.id == id }
    }

    /// The Round's 1-based number on the scorepad.
    public func number(of round: Round.ID) -> Int? {
        rounds.firstIndex { $0.id == round }.map { $0 + 1 }
    }

    /// A new Round is offered once the last one has at least one Score, so the
    /// scorepad never stacks up empty rows.
    public var canStartNewRound: Bool {
        rounds.last.map { !$0.scores.isEmpty } ?? true
    }

    /// Moves on to a new Round. Moving on means every Team still unscored in
    /// the last Round scored nothing, so each gets an explicit 0: only the Round
    /// in play is ever partly filled.
    public mutating func startNewRound() {
        guard canStartNewRound else { return }
        zeroUnscoredTeamsInLastRound()
        rounds.append(Round())
    }

    /// Takes a misdealt Round off the scorepad, Scores and all. Round numbers
    /// come from position, so the Rounds after it close up. A Match is never
    /// without a Round: deleting the only one leaves an empty one to score.
    public mutating func deleteRound(_ id: Round.ID) {
        rounds.removeAll { $0.id == id }
        if rounds.isEmpty {
            rounds = [Round()]
        }
    }

    /// The Team's Scores summed across every Round. Derived, never stored.
    public func total(for team: Team.ID) -> Int {
        total(for: team, in: rounds)
    }

    private func total(for team: Team.ID, in rounds: [Round]) -> Int {
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
        let scored = teams.count - unscoredTeams(in: round).count
        return scored > 0 && scored < teams.count
    }

    /// Whether the Totals are missing Scores from a partly filled Round.
    public var totalsArePartial: Bool {
        rounds.contains(where: isPartlyFilled)
    }

    /// The Teams with no Score yet in this Round, in column order.
    public func unscoredTeams(in round: Round) -> [Team] {
        teams.filter { round.points(for: $0.id) == nil }
    }

    private mutating func zeroUnscoredTeamsInLastRound() {
        guard let last = rounds.indices.last else { return }
        for team in unscoredTeams(in: rounds[last]) {
            rounds[last].setScore(0, for: team.id)
        }
    }

    // MARK: Ending

    /// Whether the Game's End condition says the Match has run its course. Only
    /// fully scored Rounds count, so a Round still being entered neither
    /// triggers it early nor hides it once reached. Announced, never enforced:
    /// scoring past it stays possible.
    public var endConditionIsReached: Bool {
        let fullyScored = rounds.filter { unscoredTeams(in: $0).isEmpty }
        switch game.endCondition {
        case .none:
            return false
        case .targetTotal(let target):
            return teams.contains { total(for: $0.id, in: fullyScored) >= target }
        case .roundCount(let count):
            return fullyScored.count >= count
        }
    }

    public var isEnded: Bool {
        endedAt != nil
    }

    /// Ends the Match, whether or not its End condition is reached. Like moving
    /// on to a new Round, ending means every Team still unscored in the last
    /// Round scored nothing; a last Round nobody has scored yet is dropped.
    /// Ending a Match already ended keeps its first end.
    public mutating func end(at date: Date = Date()) {
        guard !isEnded else { return }
        if rounds.last?.scores.isEmpty == false {
            zeroUnscoredTeamsInLastRound()
        } else if rounds.count > 1 {
            rounds.removeLast()
        }
        endedAt = date
    }

    /// Who comes out on top: one Team, or several level on the winning Total.
    public enum Outcome: Hashable, Sendable {
        case won(by: Team)
        /// In column order.
        case tied([Team])
    }

    /// How the Match would come out if it ended now; nil before the first Score.
    public var standing: Outcome? {
        let leaders = leaders
        switch leaders.count {
        case 0: return nil
        case 1: return .won(by: leaders[0])
        default: return .tied(leaders)
        }
    }

    /// The Winner under the Game's Direction, or a tie; nil while the Match is
    /// in play or if it ended before any Score. Derived from the Totals, so
    /// correcting an old Score corrects it.
    public var outcome: Outcome? {
        isEnded ? standing : nil
    }
}
