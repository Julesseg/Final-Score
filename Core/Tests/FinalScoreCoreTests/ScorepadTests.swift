import Testing
@testable import FinalScoreCore

@Suite("Scorepad")
struct ScorepadTests {
    /// A Skyjo Match between Ada, Grace and Linus, in that column order.
    private func skyjoMatch() -> Match {
        Match(game: .skyjo, teams: ["Ada", "Grace", "Linus"].map { Team(players: [Player(name: $0)]) })
    }

    @Test func aNewMatchOpensOnItsFirstTeam() {
        let match = skyjoMatch()
        let scorepad = Scorepad(match: match)

        #expect(scorepad.selection == .init(round: match.rounds[0].id, team: match.teams[0].id))
        #expect(scorepad.keypadText == "0")
    }

    @Test func everyKeyLandsTheScoreWithoutAConfirmStep() {
        var scorepad = Scorepad(match: skyjoMatch())
        let ada = scorepad.match.teams[0].id

        scorepad.type(1)
        #expect(scorepad.match.total(for: ada) == 1)
        scorepad.type(2)
        #expect(scorepad.match.total(for: ada) == 12)
        scorepad.toggleSign()
        #expect(scorepad.match.total(for: ada) == -12)
        scorepad.deleteBackward()
        #expect(scorepad.match.total(for: ada) == -1)
        #expect(scorepad.keypadText == "-1")
    }

    @Test func nextOnAnUntouchedTeamRecordsZeroAndMovesAlongTheRound() {
        var scorepad = Scorepad(match: skyjoMatch())
        let round = scorepad.match.rounds[0]
        let (ada, grace) = (scorepad.match.teams[0].id, scorepad.match.teams[1].id)
        #expect(scorepad.nextStep == .nextTeam)

        scorepad.next()

        #expect(scorepad.match.round(round.id)?.points(for: ada) == 0)
        #expect(scorepad.selection == .init(round: round.id, team: grace))
    }

    @Test func nextAfterTheLastTeamStartsANewRoundOnItsFirstTeam() {
        var scorepad = Scorepad(match: skyjoMatch())
        scorepad.type(4)
        scorepad.next()
        scorepad.type(9)
        scorepad.next()
        #expect(scorepad.nextStep == .newRound)

        scorepad.next()

        let match = scorepad.match
        #expect(match.rounds.count == 2)
        #expect(match.rounds[0].points(for: match.teams[2].id) == 0)
        #expect(scorepad.selection == .init(round: match.rounds[1].id, team: match.teams[0].id))
    }

    @Test func nextAfterTheLastTeamOfAnEarlierRoundPutsTheKeypadAway() {
        var scorepad = Scorepad(match: skyjoMatch())
        scorepad.type(3)
        scorepad.startNewRound()
        let firstRound = scorepad.match.rounds[0].id
        scorepad.select(.init(round: firstRound, team: scorepad.match.teams[2].id))
        #expect(scorepad.nextStep == .done)

        scorepad.next()

        #expect(scorepad.selection == nil)
        #expect(scorepad.match.rounds.count == 2)
    }

    @Test func startingANewRoundOpensOnItsFirstTeam() {
        var scorepad = Scorepad(match: skyjoMatch())
        scorepad.type(3)

        scorepad.startNewRound()

        let match = scorepad.match
        #expect(match.rounds.count == 2)
        #expect(scorepad.selection == .init(round: match.rounds[1].id, team: match.teams[0].id))
    }

    @Test func selectingAScoredTeamShowsItsScoreAndTypingReplacesIt() {
        var scorepad = Scorepad(match: skyjoMatch())
        scorepad.type(1)
        scorepad.type(5)
        scorepad.next()
        let ada = scorepad.match.teams[0].id

        scorepad.select(.init(round: scorepad.match.rounds[0].id, team: ada))
        #expect(scorepad.keypadText == "15")
        scorepad.type(8)

        #expect(scorepad.match.total(for: ada) == 8)
    }

    @Test func aScoreThreeRoundsAgoIsRetypedWithTheSameKeypad() {
        var scorepad = Scorepad(match: skyjoMatch())
        for _ in 0..<4 {
            scorepad.type(5)
            scorepad.next()
            scorepad.type(6)
            scorepad.next()
            scorepad.type(7)
            scorepad.next()
        }
        let grace = scorepad.match.teams[1].id
        let firstRound = scorepad.match.rounds[0].id

        scorepad.select(.init(round: firstRound, team: grace))
        #expect(scorepad.keypadText == "6")
        scorepad.type(1)
        scorepad.type(6)

        #expect(scorepad.match.round(firstRound)?.points(for: grace) == 16)
        #expect(scorepad.match.total(for: grace) == 34)
        #expect(scorepad.match.leaders.map(\.name) == ["Ada"])
        #expect(scorepad.match.rounds.count == 5, "Correcting an old Score never starts a Round")
    }

    @Test func deletingTheRoundTheKeypadIsOnMovesItToTheRoundInPlay() {
        var scorepad = Scorepad(match: skyjoMatch())
        scorepad.type(3)
        scorepad.startNewRound()
        let (firstRound, secondRound) = (scorepad.match.rounds[0].id, scorepad.match.rounds[1].id)
        scorepad.select(.init(round: firstRound, team: scorepad.match.teams[1].id))

        scorepad.deleteRound(firstRound)

        #expect(scorepad.match.rounds.map(\.id) == [secondRound])
        #expect(scorepad.selection == .init(round: secondRound, team: scorepad.match.teams[0].id))
        #expect(scorepad.keypadText == "0")
    }

    @Test func deletingTheRoundTheKeypadIsOnPutsItAwayWhenNothingIsLeftToScore() {
        var scorepad = Scorepad(match: skyjoMatch())
        // Round 1 all zeros, then on to Linus in Round 2.
        for _ in 0..<5 { scorepad.next() }
        let secondRound = scorepad.match.rounds[1].id
        #expect(scorepad.selection?.round == secondRound)

        scorepad.deleteRound(secondRound)

        #expect(scorepad.match.rounds.count == 1)
        #expect(scorepad.selection == nil)
    }

    @Test func deletingAnotherRoundLeavesTheKeypadWhereItIs() {
        var scorepad = Scorepad(match: skyjoMatch())
        scorepad.type(3)
        scorepad.startNewRound()
        let before = scorepad.selection
        scorepad.type(8)

        scorepad.deleteRound(scorepad.match.rounds[0].id)

        #expect(scorepad.selection == before)
        #expect(scorepad.keypadText == "8")
        #expect(scorepad.match.total(for: scorepad.match.teams[0].id) == 8)
    }

    @Test func resumingMidRoundOpensOnTheFirstTeamStillUnscored() {
        var match = skyjoMatch()
        match.setScore(6, for: match.teams[0].id, inRound: match.rounds[0].id)

        let scorepad = Scorepad(match: match)

        #expect(scorepad.selection == .init(round: match.rounds[0].id, team: match.teams[1].id))
    }

    @Test func resumingAfterAFullyScoredRoundOpensWithTheKeypadAway() {
        var match = skyjoMatch()
        for team in match.teams {
            match.setScore(2, for: team.id, inRound: match.rounds[0].id)
        }

        #expect(Scorepad(match: match).selection == nil)
    }

    // MARK: Quick scores and ±1

    @Test func aQuickScoreLandsAndPlusOneAdjustsIt() {
        var scorepad = Scorepad(match: skyjoMatch())
        let ada = scorepad.match.teams[0].id

        scorepad.enterQuickScore(40)
        #expect(scorepad.match.total(for: ada) == 40)
        scorepad.adjust(by: 1)
        scorepad.adjust(by: 1)

        #expect(scorepad.match.total(for: ada) == 42)
        #expect(scorepad.keypadText == "42")
    }

    @Test func minusOneCrossesZeroIntoNegatives() {
        var scorepad = Scorepad(match: skyjoMatch())
        let ada = scorepad.match.teams[0].id

        scorepad.adjust(by: -1)

        #expect(scorepad.match.total(for: ada) == -1)
        #expect(scorepad.keypadText == "-1")
    }

    @Test func deleteAndSignEditAnAdjustedScore() {
        var scorepad = Scorepad(match: skyjoMatch())
        let ada = scorepad.match.teams[0].id
        scorepad.enterQuickScore(40)
        scorepad.adjust(by: 2)

        scorepad.deleteBackward()
        scorepad.toggleSign()

        #expect(scorepad.match.total(for: ada) == -4)
    }

    @Test func plusOneOnAnUntouchedTeamScoresOne() {
        var scorepad = Scorepad(match: skyjoMatch())
        let round = scorepad.match.rounds[0]
        let ada = scorepad.match.teams[0].id

        scorepad.adjust(by: 1)

        #expect(scorepad.match.round(round.id)?.points(for: ada) == 1)
    }

    @Test func adjustingASelectedScoreStartsFromItsPoints() {
        var scorepad = Scorepad(match: skyjoMatch())
        scorepad.type(1)
        scorepad.type(5)
        scorepad.next()
        let ada = scorepad.match.teams[0].id
        scorepad.select(.init(round: scorepad.match.rounds[0].id, team: ada))

        scorepad.adjust(by: -1)

        #expect(scorepad.match.total(for: ada) == 14)
    }

    @Test func theKeypadIgnoresQuickScores() {
        var game = Game.skyjo
        game.quickScores = [25, 50]
        var scorepad = Scorepad(match: Match(game: game, teams: skyjoMatch().teams))
        let ada = scorepad.match.teams[0].id

        scorepad.enterQuickScore(50)
        scorepad.adjust(by: 1)
        scorepad.type(3)
        scorepad.type(7)

        #expect(scorepad.match.total(for: ada) == 37, "Typing replaces the Score, whatever the list holds")
    }

    @Test func minusOneStopsAtZeroWhenTheGameAllowsNoNegatives() {
        var game = Game.skyjo
        game.allowsNegative = false
        var scorepad = Scorepad(match: Match(game: game, teams: skyjoMatch().teams))
        let ada = scorepad.match.teams[0].id

        scorepad.adjust(by: 1)
        scorepad.adjust(by: -1)
        scorepad.adjust(by: -1)

        #expect(scorepad.match.total(for: ada) == 0)
        #expect(scorepad.keypadText == "0")
    }
}
