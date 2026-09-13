import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Scoring a Tally Match")
struct TallyScoringTests {
    /// A Points Match between Ada, Grace and Linus, in that order.
    private func pointsMatch(_ game: Game = .points) -> Match {
        Match(game: game, teams: ["Ada", "Grace", "Linus"].map { Team(players: [Player(name: $0)]) })
    }

    @Test func aTallyMatchHasNoRounds() {
        let match = pointsMatch()

        #expect(match.rounds.isEmpty)
        #expect(match.tallyScores.isEmpty)
        #expect(!match.canStartNewRound)
    }

    @Test func startingANewRoundDoesNothingInATally() {
        var match = pointsMatch()
        match.recordTallyScore(4, for: match.teams[0].id)

        match.startNewRound()

        #expect(match.rounds.isEmpty)
    }

    @Test func totalsSumEveryScoreRecordedForTheTeam() {
        var match = pointsMatch()
        let (ada, grace, linus) = (match.teams[0].id, match.teams[1].id, match.teams[2].id)

        match.recordTallyScore(1, for: ada)
        match.recordTallyScore(1, for: ada)
        match.recordTallyScore(12, for: grace)
        match.recordTallyScore(-1, for: ada)

        #expect(match.total(for: ada) == 1)
        #expect(match.total(for: grace) == 12)
        #expect(match.total(for: linus) == 0)
        #expect(match.tallyScores.map(\.points) == [1, 1, 12, -1], "Scores keep the order they were recorded in")
        #expect(!match.totalsArePartial, "A Tally has no Round to be partly filled")
    }

    @Test func aRoundsMatchRecordsNoTallyScores() {
        var match = Match(game: .skyjo, teams: pointsMatch().teams)

        match.recordTallyScore(5, for: match.teams[0].id)

        #expect(match.tallyScores.isEmpty)
        #expect(match.total(for: match.teams[0].id) == 0)
    }

    @Test func deletingARoundLeavesATallyWithoutRounds() {
        var match = pointsMatch()

        match.deleteRound(UUID())

        #expect(match.rounds.isEmpty)
    }

    @Test func correctingAScoreCorrectsTheTotal() {
        var match = pointsMatch()
        let ada = match.teams[0].id
        match.recordTallyScore(5, for: ada)
        match.recordTallyScore(3, for: ada)

        match.setTallyScore(30, at: 0)

        #expect(match.total(for: ada) == 33)
    }

    @Test func removingAScoreTakesItOutOfTheTotal() {
        var match = pointsMatch()
        let ada = match.teams[0].id
        match.recordTallyScore(5, for: ada)
        match.recordTallyScore(3, for: ada)

        match.removeTallyScore(at: 0)

        #expect(match.tallyScores.map(\.points) == [3])
        #expect(match.total(for: ada) == 3)
    }

    @Test func eachScoreKnowsTheTeamsTotalJustAfterIt() {
        var match = pointsMatch()
        let (ada, grace) = (match.teams[0].id, match.teams[1].id)
        match.recordTallyScore(10, for: ada)
        match.recordTallyScore(7, for: grace)
        match.recordTallyScore(-4, for: ada)

        #expect(match.totalAfterTallyScore(at: 0) == 10)
        #expect(match.totalAfterTallyScore(at: 1) == 7)
        #expect(match.totalAfterTallyScore(at: 2) == 6)
        #expect(match.totalAfterTallyScore(at: 3) == nil)
    }

    @Test func theHighestTotalLeadsOnceAnyScoreIsRecorded() {
        var match = pointsMatch()
        #expect(match.leaders.isEmpty)

        match.recordTallyScore(2, for: match.teams[1].id)

        #expect(match.leaders.map(\.name) == ["Grace"])
    }

    @Test func aTargetTotalIsTheEndConditionOfATally() {
        var game = Game.points
        game.endCondition = .targetTotal(10)
        var match = pointsMatch(game)
        match.recordTallyScore(9, for: match.teams[0].id)
        #expect(!match.endConditionIsReached)

        match.recordTallyScore(1, for: match.teams[0].id)

        #expect(match.endConditionIsReached)
    }

    @Test func aRoundCountIsNeverReachedInATally() {
        var game = Game.points
        game.endCondition = .roundCount(1)
        var match = pointsMatch(game)

        match.recordTallyScore(9, for: match.teams[0].id)

        #expect(!match.endConditionIsReached)
    }

    @Test func endingATallyMatchDerivesItsWinnerFromTheTotals() {
        var match = pointsMatch()
        match.recordTallyScore(4, for: match.teams[0].id)
        match.recordTallyScore(6, for: match.teams[2].id)

        match.end()

        #expect(match.rounds.isEmpty)
        #expect(match.outcome == .won(by: match.teams[2]))
    }

    @Test func aTallyMatchSurvivesAJSONRoundTrip() throws {
        var match = pointsMatch()
        match.recordTallyScore(4, for: match.teams[0].id)
        match.recordTallyScore(-2, for: match.teams[1].id)

        let decoded = try JSONDecoder().decode(Match.self, from: JSONEncoder().encode(match))

        #expect(decoded == match)
        #expect(decoded.total(for: match.teams[1].id) == -2)
    }

    @Test func aSnapshotSavedBeforeTalliesReadsBackWithNoTallyScores() throws {
        let match = Match(game: .skyjo, teams: pointsMatch().teams)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(match)) as! [String: Any]
        json.removeValue(forKey: "tallyScores")

        let decoded = try JSONDecoder().decode(Match.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(decoded == match)
    }
}
