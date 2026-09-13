import Foundation

/// A Team's points for one Round, or one increment within a Tally.
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
    /// The Player who deals this Round; nil in a Game that doesn't track the
    /// Dealer.
    public internal(set) var dealer: Player.ID?

    public init(id: UUID = UUID(), scores: [Score] = [], dealer: Player.ID? = nil) {
        self.id = id
        self.scores = scores
        self.dealer = dealer
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
    /// Where everyone sits and which way the deal passes; nil in a Game that
    /// doesn't track the Dealer.
    public let seating: Seating?
    /// Always empty in a Tally Match.
    public private(set) var rounds: [Round]
    /// The Scores of a Tally Match, in the order they were recorded. Always
    /// empty in a Rounds Match.
    public private(set) var tallyScores: [Score]
    /// When the user ended the Match; nil while it is in play. The only thing
    /// stored about the end — the Winner is always derived from the Totals.
    public private(set) var endedAt: Date?

    /// A new Rounds Match opens on an empty first Round, ready to score, dealt
    /// by the first seat when there is a `seating`; a new Tally Match on every
    /// Total at 0.
    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        game: Game,
        teams: [Team],
        seating: Seating? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.game = game
        self.teams = teams
        self.seating = seating
        self.rounds = game.structure == .rounds ? [Round(dealer: seating?.order.first)] : []
        self.tallyScores = []
    }

    /// Snapshots saved before Tallies existed have no `tallyScores`, and ones
    /// saved before the Dealer was tracked have no `seating`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        game = try container.decode(Game.self, forKey: .game)
        teams = try container.decode([Team].self, forKey: .teams)
        seating = try container.decodeIfPresent(Seating.self, forKey: .seating)
        rounds = try container.decode([Round].self, forKey: .rounds)
        tallyScores = try container.decodeIfPresent([Score].self, forKey: .tallyScores) ?? []
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
    }

    /// Records a Team's points for a Round, replacing any Score already there.
    public mutating func setScore(_ points: Int, for team: Team.ID, inRound round: Round.ID) {
        guard let index = rounds.firstIndex(where: { $0.id == round }) else { return }
        rounds[index].setScore(points, for: team)
    }

    /// In a Game where only one Team scores each Round, gives the Round to this
    /// Team: every other Team gets an explicit 0, and this one keeps any Score
    /// it already has, or 0 until its points are entered. Does nothing in a
    /// Game where every Team scores.
    public mutating func setScorer(_ team: Team.ID, inRound round: Round.ID) {
        guard game.scorers == .oneTeamPerRound,
              teams.contains(where: { $0.id == team }),
              let index = rounds.firstIndex(where: { $0.id == round })
        else { return }
        for other in teams {
            let points = other.id == team ? rounds[index].points(for: team) ?? 0 : 0
            rounds[index].setScore(points, for: other.id)
        }
    }

    /// Reassigns who deals a Round — a misdeal, or a house rule like "the loser
    /// deals". Rounds already started keep their Dealer; the next new Round
    /// passes the deal on from whoever deals the last one. Only a seated
    /// Player can deal.
    public mutating func setDealer(_ player: Player.ID, inRound round: Round.ID) {
        guard seating?.order.contains(player) == true,
              let index = rounds.firstIndex(where: { $0.id == round })
        else { return }
        rounds[index].dealer = player
    }

    /// Everyone playing, in Seating order — which in a Team Game is not the
    /// order the Teams hold them, because partners sit apart. A Game that
    /// doesn't track the Dealer has no Seating, so the seats its Teams imply
    /// stand in: a Rematch built from this order re-forms the same Teams.
    public var players: [Player] {
        guard let seating else { return alternatingSeats }
        let everyone = teams.flatMap(\.players)
        let seated = seating.order.compactMap { seat in everyone.first { $0.id == seat } }
        // Nobody playing is ever left out, whatever the Seating says.
        return seated + everyone.filter { !seating.order.contains($0.id) }
    }

    /// One Player from each Team in turn, the way Match setup seats them.
    private var alternatingSeats: [Player] {
        let deepest = teams.map(\.players.count).max() ?? 0
        return (0..<deepest).flatMap { slot in
            teams.compactMap { slot < $0.players.count ? $0.players[slot] : nil }
        }
    }

    public func round(_ id: Round.ID) -> Round? {
        rounds.first { $0.id == id }
    }

    /// The Round's 1-based number on the scorepad.
    public func number(of round: Round.ID) -> Int? {
        rounds.firstIndex { $0.id == round }.map { $0 + 1 }
    }

    /// A new Round is offered once the last one has at least one Score, so the
    /// scorepad never stacks up empty rows. Never in a Tally.
    public var canStartNewRound: Bool {
        guard game.structure == .rounds else { return false }
        return rounds.last.map { !$0.scores.isEmpty } ?? true
    }

    /// Moves on to a new Round, dealt by the seat after the last Round's
    /// Dealer. Moving on means every Team still unscored in the last Round
    /// scored nothing, so each gets an explicit 0: only the Round in play is
    /// ever partly filled.
    public mutating func startNewRound() {
        guard canStartNewRound else { return }
        zeroUnscoredTeamsInLastRound()
        let dealer = rounds.last?.dealer.flatMap { seating?.dealer(after: $0) }
        rounds.append(Round(dealer: dealer))
    }

    /// Takes a misdealt Round off the scorepad, Scores and all. Round numbers
    /// come from position, so the Rounds after it close up. A Match is never
    /// without a Round: deleting the only one leaves an empty one to score,
    /// dealt again by the same Dealer. A Round the Match doesn't have, as in a
    /// Tally, deletes nothing.
    public mutating func deleteRound(_ id: Round.ID) {
        guard rounds.contains(where: { $0.id == id }) else { return }
        let dealer = rounds.first { $0.id == id }?.dealer
        rounds.removeAll { $0.id == id }
        if rounds.isEmpty {
            rounds = [Round(dealer: dealer)]
        }
    }

    /// The Team's Scores summed across every Round, or across its Tally.
    /// Derived, never stored.
    public func total(for team: Team.ID) -> Int {
        total(for: team, in: rounds)
    }

    /// The Team's Total counting only these Rounds, and the whole Tally.
    private func total(for team: Team.ID, in rounds: [Round]) -> Int {
        rounds.reduce(0) { $0 + ($1.points(for: team) ?? 0) }
            + tallyScores.reduce(0) { $0 + ($1.team == team ? $1.points : 0) }
    }

    /// The Teams whose Total is best under the Game's Direction — several when
    /// level, none before the first Score.
    public var leaders: [Team] {
        guard !tallyScores.isEmpty || rounds.contains(where: { !$0.scores.isEmpty }) else { return [] }
        let totals = teams.map { total(for: $0.id) }
        let best = switch game.direction {
        case .highWins: totals.max()
        case .lowWins: totals.min()
        }
        return zip(teams, totals).filter { $0.1 == best }.map(\.0)
    }

    /// The best Total under the Game's Direction, shared by every leader; nil
    /// before the first Score.
    public var leadingTotal: Int? {
        leaders.first.map { total(for: $0.id) }
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

    // MARK: Tally

    /// Records a Score in a Tally Match: points added to the Team's Total, or
    /// taken from it when negative. Does nothing in a Rounds Match.
    public mutating func recordTallyScore(_ points: Int, for team: Team.ID) {
        guard game.structure == .tally else { return }
        tallyScores.append(Score(team: team, points: points))
    }

    /// Corrects the points of a Score already recorded.
    public mutating func setTallyScore(_ points: Int, at index: Int) {
        guard tallyScores.indices.contains(index) else { return }
        tallyScores[index].points = points
    }

    /// Takes a recorded Score out of the Tally, and so out of its Team's Total.
    public mutating func removeTallyScore(at index: Int) {
        guard tallyScores.indices.contains(index) else { return }
        tallyScores.remove(at: index)
    }

    /// The Team's Total just after this Score was recorded; nil if there is no
    /// such Score.
    public func totalAfterTallyScore(at index: Int) -> Int? {
        guard tallyScores.indices.contains(index) else { return nil }
        let team = tallyScores[index].team
        return tallyScores[...index].reduce(0) { $0 + ($1.team == team ? $1.points : 0) }
    }

    // MARK: Ending

    /// Whether the Game's End condition says the Match has run its course. Only
    /// fully scored Rounds count, so a Round still being entered neither
    /// triggers it early nor hides it once reached; every Score of a Tally
    /// counts, and a Tally never reaches a Round count. Announced, never enforced:
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
