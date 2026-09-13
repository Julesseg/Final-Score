import Testing
@testable import FinalScoreCore

@Suite("One Team scores per Round")
struct OneTeamPerRoundTests {
    /// A Coinche Match of Ada & Linus against Grace & Marie, in that column order.
    private func coincheMatch() -> Match {
        let players = ["Ada", "Grace", "Linus", "Marie"].map { Player(name: $0) }
        return Match(
            game: .coinche,
            teams: [Team(players: [players[0], players[2]]), Team(players: [players[1], players[3]])],
            seating: Seating(order: players.map(\.id), rotation: .clockwise)
        )
    }

    // MARK: Match

    @Test func choosingTheScorerGivesEveryOtherTeamAnExplicitZero() {
        var match = coincheMatch()
        let round = match.rounds[0].id

        match.setScorer(match.teams[1].id, inRound: round)

        #expect(match.round(round)?.points(for: match.teams[0].id) == 0)
        #expect(match.round(round)?.points(for: match.teams[1].id) == 0)
        #expect(!match.isPartlyFilled(match.rounds[0]), "Nobody is left unscored")
    }

    @Test func aRoundHoldsExactlyOneNonZeroScore() {
        var scorepad = Scorepad(match: coincheMatch())

        scorepad.chooseScorer(scorepad.match.teams[1].id)
        scorepad.enterQuickScore(120)

        let round = scorepad.match.rounds[0]
        #expect(round.scores.count == 2, "Every Team holds a Score")
        #expect(round.scores.filter { $0.points != 0 } == [Score(team: scorepad.match.teams[1].id, points: 120)])
        #expect(scorepad.match.total(for: scorepad.match.teams[1].id) == 120)
    }

    @Test func choosingAnotherScorerTakesTheRoundFromTheFirst() {
        var match = coincheMatch()
        let round = match.rounds[0].id
        match.setScorer(match.teams[0].id, inRound: round)
        match.setScore(90, for: match.teams[0].id, inRound: round)

        match.setScorer(match.teams[1].id, inRound: round)

        #expect(match.round(round)?.points(for: match.teams[0].id) == 0)
        #expect(match.round(round)?.points(for: match.teams[1].id) == 0)
    }

    @Test func theScorerKeepsAScoreItAlreadyHas() {
        var match = coincheMatch()
        let round = match.rounds[0].id
        match.setScore(80, for: match.teams[1].id, inRound: round)

        match.setScorer(match.teams[1].id, inRound: round)

        #expect(match.round(round)?.points(for: match.teams[1].id) == 80)
        #expect(match.round(round)?.points(for: match.teams[0].id) == 0)
    }

    @Test func aGameWhereEveryoneScoresHasNoScorerToChoose() {
        var match = Match(game: .belote, teams: coincheMatch().teams)
        let round = match.rounds[0].id

        match.setScorer(match.teams[1].id, inRound: round)

        #expect(match.rounds[0].scores.isEmpty)
    }

    // MARK: Scorepad

    @Test func aNewRoundAsksWhoScoredBeforeTheKeypadOpens() {
        let scorepad = Scorepad(match: coincheMatch())

        #expect(scorepad.roundAwaitingScorer == scorepad.match.rounds[0].id)
        #expect(scorepad.selection == nil)
    }

    @Test func choosingTheScorerOpensTheKeypadOnTheirScore() {
        var scorepad = Scorepad(match: coincheMatch())
        let grace = scorepad.match.teams[1].id
        let round = scorepad.match.rounds[0].id

        scorepad.chooseScorer(grace)

        #expect(scorepad.roundAwaitingScorer == nil)
        #expect(scorepad.selection == .init(round: round, team: grace))
        #expect(scorepad.keypadText == "0")
        scorepad.type(1)
        scorepad.type(3)
        scorepad.type(0)
        #expect(scorepad.match.total(for: grace) == 130, "The first digit replaces the placeholder 0")
    }

    @Test func nextAfterTheScorerSkipsTheOtherTeamsAndAsksAboutTheNewRound() {
        var scorepad = Scorepad(match: coincheMatch())
        scorepad.chooseScorer(scorepad.match.teams[0].id)
        scorepad.enterQuickScore(100)
        #expect(scorepad.nextStep == .newRound, "Every other Team already holds its 0")

        scorepad.next()

        #expect(scorepad.match.rounds.count == 2)
        #expect(scorepad.selection == nil)
        #expect(scorepad.roundAwaitingScorer == scorepad.match.rounds[1].id)
    }

    @Test func startingANewRoundAsksWhoScoredIt() {
        var scorepad = Scorepad(match: coincheMatch())
        scorepad.chooseScorer(scorepad.match.teams[0].id)

        scorepad.startNewRound()

        #expect(scorepad.roundAwaitingScorer == scorepad.match.rounds[1].id)
        #expect(scorepad.selection == nil)
    }

    @Test func tappingAScoreStillOverridesItWithoutAsking() {
        var scorepad = Scorepad(match: coincheMatch())
        let round = scorepad.match.rounds[0].id
        let ada = scorepad.match.teams[0].id

        scorepad.select(.init(round: round, team: ada))
        scorepad.type(2)
        scorepad.type(0)

        #expect(scorepad.roundAwaitingScorer == nil)
        #expect(scorepad.match.total(for: ada) == 20)
        #expect(scorepad.nextStep == .newRound)
    }

    @Test func anOverrideCanScoreASecondTeamInTheSameRound() {
        var scorepad = Scorepad(match: coincheMatch())
        let round = scorepad.match.rounds[0].id
        let (ada, grace) = (scorepad.match.teams[0].id, scorepad.match.teams[1].id)
        scorepad.chooseScorer(ada)
        scorepad.enterQuickScore(160)

        // Belote and rebelote held in defence still count for the other Team.
        scorepad.select(.init(round: round, team: grace))
        scorepad.type(2)
        scorepad.type(0)

        #expect(scorepad.match.total(for: ada) == 160)
        #expect(scorepad.match.total(for: grace) == 20)
    }

    @Test func hidingTheQuestionLeavesTheRoundUnscored() {
        var scorepad = Scorepad(match: coincheMatch())

        scorepad.deselect()

        #expect(scorepad.roundAwaitingScorer == nil)
        #expect(scorepad.match.rounds[0].scores.isEmpty)
    }

    @Test func choosingAScorerWithNoQuestionAskedDoesNothing() {
        var scorepad = Scorepad(match: coincheMatch())
        scorepad.deselect()

        scorepad.chooseScorer(scorepad.match.teams[0].id)

        #expect(scorepad.selection == nil)
        #expect(scorepad.match.rounds[0].scores.isEmpty)
    }

    @Test func deletingTheRoundBeingAskedAboutAsksAboutTheRoundInPlay() {
        var scorepad = Scorepad(match: coincheMatch())
        scorepad.chooseScorer(scorepad.match.teams[0].id)
        scorepad.enterQuickScore(80)
        scorepad.startNewRound()
        let (first, second) = (scorepad.match.rounds[0].id, scorepad.match.rounds[1].id)

        scorepad.deleteRound(second)

        #expect(scorepad.match.rounds.map(\.id) == [first])
        #expect(scorepad.roundAwaitingScorer == nil, "The Round left is already scored")
        #expect(scorepad.selection == nil)
    }

    @Test func deletingTheOnlyRoundAsksAboutTheEmptyOneLeft() {
        var scorepad = Scorepad(match: coincheMatch())
        scorepad.chooseScorer(scorepad.match.teams[0].id)

        scorepad.deleteRound(scorepad.match.rounds[0].id)

        #expect(scorepad.roundAwaitingScorer == scorepad.match.rounds[0].id)
    }

    @Test func endingTheMatchStopsAsking() {
        var scorepad = Scorepad(match: coincheMatch())
        scorepad.chooseScorer(scorepad.match.teams[0].id)
        scorepad.enterQuickScore(90)
        scorepad.startNewRound()

        scorepad.endMatch()

        #expect(scorepad.roundAwaitingScorer == nil)
        #expect(scorepad.match.rounds.count == 1, "The Round nobody scored is dropped")
    }

    @Test func resumingAScoredRoundOpensWithNothingAsked() {
        var match = coincheMatch()
        match.setScorer(match.teams[0].id, inRound: match.rounds[0].id)

        let scorepad = Scorepad(match: match)

        #expect(scorepad.roundAwaitingScorer == nil)
        #expect(scorepad.selection == nil)
    }

    @Test func resumingARoundOnlyPartlyScoredByOverrideOpensWithNothingAsked() {
        var match = coincheMatch()
        match.setScore(20, for: match.teams[1].id, inRound: match.rounds[0].id)

        let scorepad = Scorepad(match: match)

        #expect(scorepad.roundAwaitingScorer == nil, "Someone already scored this Round")
        #expect(scorepad.selection == nil, "No other Team is waiting on a Score")
    }

    @Test func reopeningAnEndedMatchAsksNothing() {
        var match = coincheMatch()
        match.end()

        #expect(Scorepad(match: match).roundAwaitingScorer == nil)
    }
}
