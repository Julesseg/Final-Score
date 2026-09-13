import Foundation

/// A Match open on the scorepad, with the keypad Override aimed at one Team's
/// Score in one Round. In a Game where only one Team scores each Round, a new
/// Round first asks which Team scored it, then opens the keypad on that Team.
public struct Scorepad: Sendable {
    /// Where a Score sits on the scorepad.
    public struct Position: Hashable, Sendable {
        public let round: Round.ID
        public let team: Team.ID

        public init(round: Round.ID, team: Team.ID) {
            self.round = round
            self.team = team
        }
    }

    public private(set) var match: Match
    /// The Score the keypad is typing into; nil while the keypad is put away.
    public private(set) var selection: Position?
    /// The Round waiting to be told which Team scored it, while the keypad is
    /// put away; nil when nothing is asked. Only ever set in a Game where one
    /// Team scores per Round.
    public private(set) var roundAwaitingScoringTeam: Round.ID?
    private var typed = Override()

    /// Opens ready for the Round in play: on the first Team still unscored in
    /// it, or asking who scored it in a Game where one Team scores per Round —
    /// or with the keypad away on an ended Match, which is only reopened to
    /// look at or to correct.
    public init(match: Match) {
        self.match = match
        if !match.isEnded {
            openRoundInPlay()
        }
    }

    public var keypadText: String {
        typed.text
    }

    /// Opens the keypad on a Score, as an Override: whatever the scorepad was
    /// asking is dropped. In a Game where one Team scores per Round, a Score
    /// tapped in a Round nobody has scored yet answers the question anyway:
    /// its Team takes the Round.
    public mutating func select(_ position: Position) {
        roundAwaitingScoringTeam = nil
        if match.round(position.round)?.scores.isEmpty == true {
            match.setScoringTeam(position.team, inRound: position.round)
        }
        selection = position
        typed = Override(points: match.round(position.round)?.points(for: position.team))
    }

    // Every key lands the Score as typed: there is no confirm step.

    public mutating func type(_ digit: Int) {
        typed.type(digit)
        land()
    }

    public mutating func deleteBackward() {
        typed.deleteBackward()
        land()
    }

    public mutating func toggleSign() {
        typed.toggleSign()
        land()
    }

    // A Quick score or a ±1 leaves the Score showing as if the Team had been
    // selected on it: the next digit replaces it, delete and sign edit it.

    /// Sets the Score to one of the Game's Quick scores. The keypad is never
    /// limited to them.
    public mutating func enterQuickScore(_ points: Int) {
        typed = Override(points: points)
        land()
    }

    /// The −1 / +1 keys, so 40 then +1 +1 lands 42. Never takes a Score below
    /// 0 in a Game without negatives, just as the keypad offers no sign key there.
    public mutating func adjust(by delta: Int) {
        let points = typed.points + delta
        guard match.game.allowsNegative || points >= 0 else { return }
        typed = Override(points: points)
        land()
    }

    /// What the Next key does from the selected Team.
    public enum NextStep: Sendable {
        /// Moves to the next Team in the same Round.
        case nextTeam
        /// Starts a new Round, after the last Team of the last Round.
        case newRound
        /// Puts the keypad away, after the last Team of an earlier Round or of
        /// an ended Match.
        case done
    }

    /// In a Game where one Team scores per Round, Next never moves along the
    /// Round: every other Team scores 0.
    public var nextStep: NextStep {
        if match.game.scorers == .everyone, teamAfterSelection != nil { return .nextTeam }
        return !match.isEnded && selection?.round == match.rounds.last?.id ? .newRound : .done
    }

    /// Lands the selected Score — a Team left untouched gets an explicit 0,
    /// never a blank — then takes the `nextStep`.
    public mutating func next() {
        guard let current = selection else { return }
        land()
        switch nextStep {
        case .nextTeam:
            teamAfterSelection.map { select(Position(round: current.round, team: $0)) }
        case .newRound:
            startNewRound()
        case .done:
            deselect()
        }
    }

    /// Puts the keypad away, or stops asking who scored.
    public mutating func deselect() {
        selection = nil
        roundAwaitingScoringTeam = nil
    }

    /// Answers which Team scored the Round being asked about: every other Team
    /// gets 0, and the keypad opens on this Team's Score. Does nothing when
    /// nothing is asked.
    public mutating func chooseScoringTeam(_ team: Team.ID) {
        guard let round = roundAwaitingScoringTeam else { return }
        select(Position(round: round, team: team))
    }

    public mutating func startNewRound() {
        match.startNewRound()
        deselect()
        openRoundInPlay()
    }

    /// Deletes a Round. A keypad on it, or a question about it, moves to the
    /// Round in play, or goes away if nothing is left to score there or the
    /// Match is ended; anywhere else it stays put.
    public mutating func deleteRound(_ id: Round.ID) {
        match.deleteRound(id)
        guard selection?.round == id || roundAwaitingScoringTeam == id else { return }
        deselect()
        if !match.isEnded {
            openRoundInPlay()
        }
    }

    /// Ends the Match and puts the keypad away. Any Score can still be selected
    /// and corrected afterwards.
    public mutating func endMatch() {
        deselect()
        match.end()
    }

    /// Reassigns who deals a Round. The keypad stays where it is.
    public mutating func setDealer(_ player: Player.ID, inRound round: Round.ID) {
        match.setDealer(player, inRound: round)
    }

    private var teamAfterSelection: Team.ID? {
        guard let selection,
              let index = match.teams.firstIndex(where: { $0.id == selection.team }),
              index + 1 < match.teams.count
        else { return nil }
        return match.teams[index + 1].id
    }

    private mutating func land() {
        guard let selection else { return }
        match.setScore(typed.points, for: selection.team, inRound: selection.round)
    }

    /// Asks who scored the last Round if nobody has yet, in a Game where one
    /// Team scores per Round, where a Round anyone scored needs nothing more.
    /// Otherwise opens the keypad on the first Team still unscored in it.
    private mutating func openRoundInPlay() {
        guard let round = match.rounds.last else { return }
        switch match.game.scorers {
        case .oneTeamPerRound:
            if round.scores.isEmpty {
                roundAwaitingScoringTeam = round.id
            }
        case .everyone:
            guard let team = match.teams.first(where: { round.points(for: $0.id) == nil }) else { return }
            select(Position(round: round.id, team: team.id))
        }
    }
}
