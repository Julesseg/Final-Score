import Foundation

/// A Match open on the scorepad, with the keypad Override aimed at one Team's
/// Score in one Round.
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
    private var typed = Override()

    /// Opens on the first Team still unscored in the last Round, if any.
    public init(match: Match) {
        self.match = match
        selectFirstUnscoredTeam()
    }

    public var keypadText: String {
        typed.text
    }

    public mutating func select(_ position: Position) {
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
        /// Puts the keypad away, after the last Team of an earlier Round.
        case done
    }

    public var nextStep: NextStep {
        if teamAfterSelection != nil { return .nextTeam }
        return selection?.round == match.rounds.last?.id ? .newRound : .done
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

    public mutating func deselect() {
        selection = nil
    }

    public mutating func startNewRound() {
        match.startNewRound()
        selectFirstUnscoredTeam()
    }

    /// Deletes a Round. A keypad on it moves to the first Team still unscored
    /// in the last Round, or is put away if there is none; anywhere else it
    /// stays put.
    public mutating func deleteRound(_ id: Round.ID) {
        match.deleteRound(id)
        guard selection?.round == id else { return }
        deselect()
        selectFirstUnscoredTeam()
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

    private mutating func selectFirstUnscoredTeam() {
        guard let round = match.rounds.last,
              let team = match.teams.first(where: { round.points(for: $0.id) == nil })
        else { return }
        select(Position(round: round.id, team: team.id))
    }
}
