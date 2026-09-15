import Testing
@testable import FinalScoreCore

@Suite("Tally pad")
struct TallyPadTests {
    /// A Points Match between Ada, Grace and Linus, in that order.
    private func pointsMatch(_ game: Game = .points) -> Match {
        Match(game: game, teams: ["Ada", "Grace", "Linus"].map { Team(players: [Player(name: $0)]) })
    }

    @Test func aTallyOpensWithTheKeypadAway() {
        #expect(TallyPad(match: pointsMatch()).selection == nil)
    }

    // MARK: − / +

    @Test func eachTapBesideATotalRecordsAScore() {
        var pad = TallyPad(match: pointsMatch())
        let (ada, grace) = (pad.match.teams[0].id, pad.match.teams[1].id)

        pad.adjustTotal(of: ada, by: 1)
        pad.adjustTotal(of: ada, by: 1)
        pad.adjustTotal(of: grace, by: -1)

        #expect(pad.match.tallyScores == [
            Score(team: ada, points: 1), Score(team: ada, points: 1), Score(team: grace, points: -1),
        ])
        #expect(pad.match.total(for: ada) == 2)
        #expect(pad.match.total(for: grace) == -1)
    }

    @Test func minusNeverTakesATotalBelowZeroWhenTheGameAllowsNoNegatives() {
        var game = Game.points
        game.allowsNegative = false
        var pad = TallyPad(match: pointsMatch(game))
        let ada = pad.match.teams[0].id
        pad.adjustTotal(of: ada, by: 1)

        #expect(pad.canAdjustTotal(of: ada, by: -1))
        pad.adjustTotal(of: ada, by: -1)
        #expect(!pad.canAdjustTotal(of: ada, by: -1))
        pad.adjustTotal(of: ada, by: -1)

        #expect(pad.match.total(for: ada) == 0)
        #expect(pad.match.tallyScores.count == 2)
    }

    @Test func noScoreIsAddedOnceTheMatchIsEnded() {
        var pad = TallyPad(match: pointsMatch())
        let ada = pad.match.teams[0].id
        pad.adjustTotal(of: ada, by: 1)
        pad.endMatch()

        #expect(!pad.canAdjustTotal(of: ada, by: 1))
        pad.adjustTotal(of: ada, by: 1)
        pad.select(.newScore(team: ada))

        #expect(pad.match.total(for: ada) == 1)
        #expect(pad.selection == nil)
    }

    // MARK: Keypad

    @Test func typingOnANewScoreRecordsItOnTheFirstKeyAndEditsItAfter() {
        var pad = TallyPad(match: pointsMatch())
        let ada = pad.match.teams[0].id
        pad.adjustTotal(of: ada, by: 1)

        pad.select(.newScore(team: ada))
        #expect(pad.keypadText == "0")
        #expect(pad.match.tallyScores.count == 1, "Opening the keypad records nothing")

        pad.type(2)
        pad.type(5)

        #expect(pad.match.tallyScores.map(\.points) == [1, 25])
        #expect(pad.match.total(for: ada) == 26)
        #expect(pad.selection == .recorded(1))
        #expect(pad.selectedTeam == ada)
    }

    @Test func aNewScoreIsStillBeingAddedOnceItsFirstKeyRecordsIt() {
        var pad = TallyPad(match: pointsMatch())
        let grace = pad.match.teams[1].id
        #expect(!pad.isAddingScore)

        pad.select(.newScore(team: grace))
        #expect(pad.isAddingScore)
        pad.type(1)
        pad.type(2)
        #expect(pad.selection == .recorded(0))
        #expect(pad.isAddingScore)

        pad.select(.recorded(0))
        #expect(!pad.isAddingScore, "Selecting a recorded Score corrects it")
        pad.select(.newScore(team: grace))
        pad.deselect()
        #expect(!pad.isAddingScore)
    }

    @Test func theSignKeyTakesPointsAway() {
        var pad = TallyPad(match: pointsMatch())
        let ada = pad.match.teams[0].id
        pad.adjustTotal(of: ada, by: 30)

        pad.select(.newScore(team: ada))
        pad.toggleSign()
        #expect(pad.match.tallyScores.count == 1, "A sign alone is not a Score yet")
        pad.type(1)
        pad.type(2)

        #expect(pad.match.total(for: ada) == 18)
    }

    @Test func selectingARecordedScoreShowsItAndTypingReplacesIt() {
        var pad = TallyPad(match: pointsMatch())
        let (ada, grace) = (pad.match.teams[0].id, pad.match.teams[1].id)
        pad.adjustTotal(of: ada, by: 1)
        pad.adjustTotal(of: grace, by: 1)

        pad.select(.recorded(0))
        #expect(pad.keypadText == "1")
        #expect(pad.selectedTeam == ada)
        pad.type(8)

        #expect(pad.match.total(for: ada) == 8)
        #expect(pad.match.total(for: grace) == 1)
    }

    @Test func keypadPlusOneAdjustsTheSelectedScore() {
        var pad = TallyPad(match: pointsMatch())
        let ada = pad.match.teams[0].id

        pad.select(.newScore(team: ada))
        pad.adjust(by: 1)
        pad.adjust(by: 1)

        #expect(pad.match.tallyScores.map(\.points) == [2])
        #expect(pad.keypadText == "2")
    }

    @Test func aQuickScoreIsRecordedLikeATypedOne() {
        var pad = TallyPad(match: pointsMatch())
        let ada = pad.match.teams[0].id

        pad.select(.newScore(team: ada))
        pad.enterQuickScore(10)
        pad.adjust(by: 1)

        #expect(pad.match.tallyScores.map(\.points) == [11])
    }

    @Test func keypadMinusOneNeverTakesATotalBelowZeroWhenTheGameAllowsNoNegatives() {
        var game = Game.points
        game.allowsNegative = false
        var pad = TallyPad(match: pointsMatch(game))
        let ada = pad.match.teams[0].id
        pad.adjustTotal(of: ada, by: 1)

        pad.select(.newScore(team: ada))
        pad.adjust(by: -1)
        pad.adjust(by: -1)

        #expect(pad.match.total(for: ada) == 0)
    }

    @Test func puttingTheKeypadAwayOnAScoreOfZeroRemovesIt() {
        var pad = TallyPad(match: pointsMatch())
        let ada = pad.match.teams[0].id
        pad.select(.newScore(team: ada))
        pad.type(4)

        pad.deleteBackward()
        #expect(pad.match.tallyScores.map(\.points) == [0], "Kept while it is being typed")
        pad.deselect()

        #expect(pad.match.tallyScores.isEmpty)
        #expect(pad.selection == nil)
    }

    @Test func movingOffAScoreOfZeroRemovesItAndKeepsTheNextSelectionOnItsScore() {
        var pad = TallyPad(match: pointsMatch())
        let (ada, grace) = (pad.match.teams[0].id, pad.match.teams[1].id)
        pad.adjustTotal(of: ada, by: 5)
        pad.adjustTotal(of: grace, by: 7)

        pad.select(.recorded(0))
        pad.deleteBackward()
        pad.select(.recorded(1))

        #expect(pad.match.tallyScores == [Score(team: grace, points: 7)])
        #expect(pad.selection == .recorded(0))
        #expect(pad.keypadText == "7")
    }

    @Test func reselectingAScoreTypedDownToZeroKeepsItInItsPlace() {
        var pad = TallyPad(match: pointsMatch())
        let (ada, grace) = (pad.match.teams[0].id, pad.match.teams[1].id)
        pad.adjustTotal(of: ada, by: 5)
        pad.adjustTotal(of: grace, by: 7)
        pad.endMatch()

        pad.select(.recorded(0))
        pad.deleteBackward()
        pad.select(.recorded(0))
        pad.type(3)

        #expect(pad.match.tallyScores == [Score(team: ada, points: 3), Score(team: grace, points: 7)])
        #expect(pad.selection == .recorded(0))
    }

    @Test func puttingTheKeypadAwayWithoutTypingRecordsNothing() {
        var pad = TallyPad(match: pointsMatch())

        pad.select(.newScore(team: pad.match.teams[0].id))
        pad.deselect()

        #expect(pad.match.tallyScores.isEmpty)
    }

    @Test func endingTheMatchPutsTheKeypadAwayAndARecordedScoreCanStillBeCorrected() {
        var pad = TallyPad(match: pointsMatch())
        let (ada, grace) = (pad.match.teams[0].id, pad.match.teams[1].id)
        pad.adjustTotal(of: ada, by: 3)
        pad.adjustTotal(of: grace, by: 2)
        pad.select(.newScore(team: grace))

        pad.endMatch()
        #expect(pad.match.isEnded)
        #expect(pad.selection == nil)
        #expect(pad.match.outcome == .won(by: pad.match.teams[0]))

        pad.select(.recorded(1))
        pad.type(9)

        #expect(pad.match.outcome == .won(by: pad.match.teams[1]))
    }

    @Test func aSelectionOutsideTheTallyIsIgnored() {
        var pad = TallyPad(match: pointsMatch())

        pad.select(.recorded(0))

        #expect(pad.selection == nil)
    }
}
