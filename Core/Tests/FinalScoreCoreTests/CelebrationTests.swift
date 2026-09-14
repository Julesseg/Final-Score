import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Celebrating a Match")
struct CelebrationTests {
    /// A Skyjo Match between Ada and Grace: reaching 100 is the End condition.
    private func skyjo() -> Match {
        Match(game: .skyjo, teams: ["Ada", "Grace"].map { Team(players: [Player(name: $0)]) })
    }

    /// Scores the last Round, one value per Team in column order, then moves on.
    private func play(_ points: [Int], in match: inout Match) {
        let round = match.rounds[match.rounds.count - 1].id
        for (team, value) in zip(match.teams, points) {
            match.setScore(value, for: team.id, inRound: round)
        }
        match.startNewRound()
    }

    @Test func reachingTheEndConditionIsCelebrated() {
        var match = skyjo()
        play([60, 20], in: &match)
        let before = match

        play([50, 10], in: &match)

        #expect(match.celebration(since: before) == .endConditionReached)
    }

    @Test func aScoreThatLeavesTheEndConditionAsItWasIsNotCelebrated() {
        var match = skyjo()
        let start = match
        play([10, 20], in: &match)
        #expect(match.celebration(since: start) == nil, "Still short of the End condition")

        play([100, 0], in: &match)
        let reached = match
        play([5, 5], in: &match)
        #expect(match.celebration(since: reached) == nil, "Already reached: only the moment it is reached counts")
    }

    @Test func aRoundStillBeingEnteredDoesNotCelebrateEarly() {
        var match = skyjo()
        let before = match

        match.setScore(120, for: match.teams[0].id, inRound: match.rounds[0].id)

        #expect(match.celebration(since: before) == nil)
    }

    @Test func endingTheMatchCelebratesTheWinner() {
        var match = skyjo()
        play([30, 10], in: &match)
        let before = match

        match.end()

        #expect(match.celebration(since: before) == .ended(.won(by: match.teams[1])))
    }

    @Test func endingOnATieCelebratesEveryTeamLevel() {
        var match = skyjo()
        play([10, 10], in: &match)
        let before = match

        match.end()

        #expect(match.celebration(since: before) == .ended(.tied(match.teams)))
    }

    @Test func endingPastTheEndConditionCelebratesTheWinnerRatherThanTheAnnouncement() {
        var match = skyjo()
        play([90, 10], in: &match)
        let before = match

        // The Round that reaches it lands as the Match is ended.
        match.setScore(20, for: match.teams[0].id, inRound: match.rounds.last!.id)
        match.end()

        #expect(match.celebration(since: before) == .ended(.won(by: match.teams[1])))
    }

    @Test func endingBeforeAnyScoreHasNoWinnerToCelebrate() {
        var match = skyjo()
        let before = match

        match.end()

        #expect(match.celebration(since: before) == nil)
    }

    @Test func correctingAScoreAfterTheEndIsNotCelebratedAgain() {
        var match = skyjo()
        play([30, 10], in: &match)
        match.end()
        let ended = match

        match.setScore(0, for: match.teams[0].id, inRound: match.rounds[0].id)

        #expect(match.celebration(since: ended) == nil)
    }

    @Test func aTallyReachingItsTargetIsCelebrated() {
        var game = Game.points
        game.endCondition = .targetTotal(3)
        var match = Match(game: game, teams: skyjo().teams)
        match.recordTallyScore(2, for: match.teams[0].id)
        let before = match

        match.recordTallyScore(1, for: match.teams[0].id)

        #expect(match.celebration(since: before) == .endConditionReached)
    }
}
