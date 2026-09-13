import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Ending a Match")
struct MatchEndingTests {
    private func match(of game: Game, players: [String] = ["Ada", "Grace", "Linus"]) -> Match {
        Match(game: game, teams: players.map { Team(players: [Player(name: $0)]) })
    }

    /// Scores one full Round, one value per Team in column order, then moves on.
    private func play(_ points: [Int], in match: inout Match) {
        let round = match.rounds[match.rounds.count - 1].id
        for (team, value) in zip(match.teams, points) {
            match.setScore(value, for: team.id, inRound: round)
        }
        match.startNewRound()
    }

    private func game(_ base: Game, endCondition: Game.EndCondition, direction: Game.Direction? = nil) -> Game {
        var game = base
        game.endCondition = endCondition
        direction.map { game.direction = $0 }
        return game
    }

    // MARK: End condition

    @Test func aTotalReachingTheTargetReachesTheEndCondition() {
        var match = match(of: game(.scrabble, endCondition: .targetTotal(50)))
        play([30, 20, 10], in: &match)
        #expect(!match.endConditionIsReached)

        play([20, 0, 0], in: &match)
        #expect(match.endConditionIsReached)
    }

    @Test func aTotalLandingExactlyOnTheTargetReachesIt() {
        var match = match(of: .skyjo)
        play([99, 10, 20], in: &match)
        #expect(!match.endConditionIsReached)

        play([1, 10, 20], in: &match)
        #expect(match.endConditionIsReached)
    }

    @Test func aTotalOnlyReachesTheTargetOnceItsRoundIsFullyScored() {
        var match = match(of: game(.scrabble, endCondition: .targetTotal(50)))
        match.setScore(60, for: match.teams[0].id, inRound: match.rounds[0].id)

        #expect(match.totalsArePartial)
        #expect(!match.endConditionIsReached)

        match.setScore(0, for: match.teams[1].id, inRound: match.rounds[0].id)
        match.setScore(0, for: match.teams[2].id, inRound: match.rounds[0].id)

        #expect(match.endConditionIsReached)
    }

    @Test func aReachedTargetStaysReachedWhileTheNextRoundIsEntered() {
        var match = match(of: .skyjo)
        play([100, 10, 20], in: &match)

        match.setScore(-2, for: match.teams[0].id, inRound: match.rounds[1].id)

        #expect(match.totalsArePartial)
        #expect(match.endConditionIsReached)
    }

    @Test func correctingATotalBackUnderTheTargetUnreachesIt() {
        var match = match(of: .skyjo)
        play([100, 10, 20], in: &match)
        #expect(match.endConditionIsReached)

        match.setScore(99, for: match.teams[0].id, inRound: match.rounds[0].id)

        #expect(!match.endConditionIsReached)
    }

    @Test func theRoundCountIsReachedOnceThatManyRoundsAreFullyScored() {
        var match = match(of: game(.tarot, endCondition: .roundCount(2)))
        play([10, -5, -5], in: &match)
        #expect(!match.endConditionIsReached)

        let round = match.rounds[1].id
        match.setScore(10, for: match.teams[0].id, inRound: round)
        match.setScore(10, for: match.teams[1].id, inRound: round)
        #expect(!match.endConditionIsReached, "Round 2 is only partly scored")

        match.setScore(10, for: match.teams[2].id, inRound: round)
        #expect(match.endConditionIsReached)
    }

    @Test func aGameWithNoEndConditionNeverReachesIt() {
        var match = match(of: .scrabble)
        for _ in 0..<20 {
            play([500, 500, 500], in: &match)
        }
        #expect(!match.endConditionIsReached)
    }

    @Test func scoringPastTheEndConditionStaysPossible() {
        var match = match(of: .skyjo)
        play([100, 10, 20], in: &match)
        #expect(match.endConditionIsReached)

        play([5, 5, 5], in: &match)

        #expect(match.rounds.count == 3)
        #expect(match.total(for: match.teams[0].id) == 105)
        #expect(!match.isEnded)
    }

    // MARK: Skyjo

    @Test func inSkyjoATotalCrossing100EndsTheMatchAndTheLowestTotalWins() {
        var match = match(of: .skyjo)
        play([40, 30, 35], in: &match)
        play([45, 12, 50], in: &match)
        #expect(!match.endConditionIsReached)

        play([20, 8, 30], in: &match)

        #expect(match.endConditionIsReached, "Linus crossed 100")
        match.end()
        #expect(match.outcome == .won(by: match.teams[1]), "Grace has the lowest Total, 50")
    }

    // MARK: Winner

    @Test func thereIsNoOutcomeWhileTheMatchIsInPlayOnlyAStanding() {
        var match = match(of: .skyjo)
        #expect(match.standing == nil)

        play([100, 10, 20], in: &match)

        #expect(!match.isEnded)
        #expect(match.outcome == nil)
        #expect(match.standing == .won(by: match.teams[1]))
    }

    @Test func theUnscoredTeamsOfARoundAreListedInColumnOrder() {
        var match = match(of: .skyjo)
        match.setScore(4, for: match.teams[1].id, inRound: match.rounds[0].id)

        #expect(match.unscoredTeams(in: match.rounds[0]).map(\.name) == ["Ada", "Linus"])
    }

    @Test func theHighestTotalWinsWhenTheHighestWins() {
        var match = match(of: .scrabble)
        play([120, 180, 90], in: &match)

        match.end()

        #expect(match.outcome == .won(by: match.teams[1]))
    }

    @Test func levelBestTotalsAreATie() {
        var match = match(of: .skyjo)
        play([12, 30, 12], in: &match)

        match.end()

        #expect(match.outcome == .tied([match.teams[0], match.teams[2]]))
    }

    @Test func correctingAnOldScoreAfterTheEndCorrectsTheWinner() {
        var match = match(of: .skyjo)
        play([60, 10, 20], in: &match)
        play([45, 5, 5], in: &match)
        match.end()
        #expect(match.outcome == .won(by: match.teams[1]))

        match.setScore(30, for: match.teams[1].id, inRound: match.rounds[0].id)

        #expect(match.outcome == .won(by: match.teams[2]))
    }

    @Test func aMatchEndedBeforeAnyScoreHasNoWinner() {
        var match = match(of: .skyjo)
        match.end()

        #expect(match.isEnded)
        #expect(match.outcome == nil)
    }

    // MARK: Ending

    @Test func aMatchCanBeEndedAtAnyTime() {
        var match = match(of: .skyjo)
        play([3, 4, 5], in: &match)
        #expect(!match.endConditionIsReached)

        let when = Date(timeIntervalSince1970: 5_000)
        match.end(at: when)

        #expect(match.isEnded)
        #expect(match.endedAt == when)
        #expect(match.outcome == .won(by: match.teams[0]))
    }

    @Test func endingMeansEveryTeamStillUnscoredInTheLastRoundScoredNothing() {
        var match = match(of: .skyjo)
        play([10, 20, 30], in: &match)
        match.setScore(-5, for: match.teams[2].id, inRound: match.rounds[1].id)

        match.end()

        #expect(match.rounds[1].points(for: match.teams[0].id) == 0)
        #expect(match.rounds[1].points(for: match.teams[1].id) == 0)
        #expect(!match.totalsArePartial)
    }

    @Test func endingDropsTheEmptyRoundThatWasWaitingToBeScored() {
        var match = match(of: .skyjo)
        play([10, 20, 30], in: &match)
        #expect(match.rounds.count == 2)

        match.end()

        #expect(match.rounds.count == 1)
    }

    @Test func aMatchEndedBeforeAnyScoreKeepsItsOneRound() {
        var match = match(of: .skyjo)
        match.end()
        #expect(match.rounds.count == 1)
    }

    @Test func endingAgainKeepsTheFirstEnd() {
        var match = match(of: .skyjo)
        match.end(at: Date(timeIntervalSince1970: 1_000))
        match.end(at: Date(timeIntervalSince1970: 2_000))

        #expect(match.endedAt == Date(timeIntervalSince1970: 1_000))
    }

    @Test func anEndedMatchSurvivesAJSONRoundTrip() throws {
        var match = match(of: .skyjo)
        play([12, 5, 9], in: &match)
        match.end(at: Date(timeIntervalSince1970: 9_000))

        let decoded = try JSONDecoder().decode(Match.self, from: JSONEncoder().encode(match))

        #expect(decoded == match)
        #expect(decoded.outcome == .won(by: match.teams[1]))
    }

    @Test func aSnapshotSavedBeforeMatchesCouldEndReadsBackInPlay() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(match(of: .skyjo))) as! [String: Any]
        json.removeValue(forKey: "endedAt")

        let decoded = try JSONDecoder().decode(Match.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(!decoded.isEnded)
    }
}
