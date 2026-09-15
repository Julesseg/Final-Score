import Foundation

/// A Tally Match open on the Tally view: − / + beside every Team's Total, and
/// the keypad Override aimed at one Score for larger changes.
public struct TallyPad: Sendable {
    /// The Score the keypad is typing into.
    public enum Selection: Hashable, Sendable {
        /// A Score the Team hasn't recorded yet: the first key that makes it
        /// worth something records it.
        case newScore(team: Team.ID)
        /// A Score already recorded, by its place in `match.tallyScores`.
        case recorded(Int)
    }

    public private(set) var match: Match
    /// Nil while the keypad is put away.
    public private(set) var selection: Selection?
    /// Whether the keypad was opened to add a Score rather than to correct
    /// one. Still true once its first key records the Score.
    public private(set) var isAddingScore = false
    private var typed = Override()

    /// Opens with the keypad away: − / + are the way most Scores go in.
    public init(match: Match) {
        self.match = match
    }

    public var keypadText: String {
        typed.text
    }

    /// The Team whose Score the keypad is typing into.
    public var selectedTeam: Team.ID? {
        switch selection {
        case nil: nil
        case .newScore(let team): team
        case .recorded(let index): match.tallyScores.indices.contains(index) ? match.tallyScores[index].team : nil
        }
    }

    // MARK: − / +

    /// Whether − / + would record anything: never once the Match is ended,
    /// and never taking a Total below 0 in a Game without negatives.
    public func canAdjustTotal(of team: Team.ID, by delta: Int) -> Bool {
        !match.isEnded && (match.game.allowsNegative || match.total(for: team) + delta >= 0)
    }

    /// Records a Score of `delta` for the Team: each tap is a Score of its own.
    public mutating func adjustTotal(of team: Team.ID, by delta: Int) {
        guard canAdjustTotal(of: team, by: delta) else { return }
        match.recordTallyScore(delta, for: team)
    }

    // MARK: Keypad

    /// Aims the keypad at a Score. A new Score is only offered while the
    /// Match is in play; a recorded one can be corrected at any time.
    public mutating func select(_ newSelection: Selection) {
        var newSelection = newSelection
        switch newSelection {
        case .newScore:
            guard !match.isEnded else { return }
        case .recorded(let index):
            guard match.tallyScores.indices.contains(index) else { return }
        }
        // Moving off a Score of 0 removes it, which shifts every later one
        // down. Selecting it again isn't moving off it: it keeps its place.
        if newSelection != selection,
           let removed = removeZeroSelection(),
           case .recorded(let index) = newSelection, index > removed {
            newSelection = .recorded(index - 1)
        }
        selection = newSelection
        isAddingScore = switch newSelection {
        case .newScore: true
        case .recorded: false
        }
        typed = switch newSelection {
        case .newScore: Override()
        case .recorded(let index): Override(points: match.tallyScores[index].points)
        }
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

    public mutating func enterQuickScore(_ points: Int) {
        typed = Override(points: points)
        land()
    }

    /// The keypad's −1 / +1, on the selected Score. Never takes the Team's
    /// Total below 0 in a Game without negatives.
    public mutating func adjust(by delta: Int) {
        guard let team = selectedTeam else { return }
        let points = typed.points + delta
        if !match.game.allowsNegative {
            let others = match.total(for: team) - landedPoints
            guard others + points >= 0 else { return }
        }
        typed = Override(points: points)
        land()
    }

    /// Puts the keypad away. A Score left at 0 is no Score at all, so it goes.
    public mutating func deselect() {
        _ = removeZeroSelection()
        selection = nil
        isAddingScore = false
    }

    /// Ends the Match and puts the keypad away. Recorded Scores can still be
    /// selected and corrected afterwards.
    public mutating func endMatch() {
        deselect()
        match.end()
    }

    /// What the selected Score currently adds to its Team's Total.
    private var landedPoints: Int {
        guard case .recorded(let index) = selection else { return 0 }
        return match.tallyScores[index].points
    }

    private mutating func land() {
        switch selection {
        case nil:
            return
        case .newScore(let team):
            // A sign or a 0 alone isn't a Score yet.
            guard typed.points != 0 else { return }
            match.recordTallyScore(typed.points, for: team)
            selection = .recorded(match.tallyScores.count - 1)
        case .recorded(let index):
            match.setTallyScore(typed.points, at: index)
        }
    }

    /// Removes the selected Score if it has been typed down to 0, returning
    /// where it was.
    private mutating func removeZeroSelection() -> Int? {
        guard case .recorded(let index) = selection, match.tallyScores[index].points == 0 else { return nil }
        match.removeTallyScore(at: index)
        selection = nil
        return index
    }
}
