import Testing
@testable import FinalScoreCore

@Suite("Scorepad")
struct ScorepadTests {
    /// A Skyjo Match between Ada, Grace and Linus, in that column order.
    private func skyjoMatch() -> Match {
        var setup = MatchSetup(game: .skyjo)
        setup.playerNames = ["Ada", "Grace", "Linus"]
        return setup.makeMatch()!
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
}
