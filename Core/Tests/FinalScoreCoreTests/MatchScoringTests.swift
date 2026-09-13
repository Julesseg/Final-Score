import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Scoring a Match")
struct MatchScoringTests {
    /// A Skyjo Match between Ada, Grace and Linus, in that column order.
    private func skyjoMatch() -> Match {
        Match(game: .skyjo, teams: ["Ada", "Grace", "Linus"].map { Team(players: [Player(name: $0)]) })
    }

    /// Scores each row of points, in column order, as a full Round and moves on.
    private func score(_ rounds: [[Int]], in match: inout Match) {
        for points in rounds {
            let round = match.rounds[match.rounds.count - 1].id
            for (team, points) in zip(match.teams, points) {
                match.setScore(points, for: team.id, inRound: round)
            }
            match.startNewRound()
        }
    }

    @Test func totalsSumEachTeamsScoresAcrossRounds() {
        var match = skyjoMatch()
        let (ada, grace, linus) = (match.teams[0].id, match.teams[1].id, match.teams[2].id)

        match.setScore(12, for: ada, inRound: match.rounds[0].id)
        match.setScore(5, for: grace, inRound: match.rounds[0].id)
        match.setScore(0, for: linus, inRound: match.rounds[0].id)
        match.startNewRound()
        match.setScore(-3, for: ada, inRound: match.rounds[1].id)
        match.setScore(20, for: grace, inRound: match.rounds[1].id)
        match.setScore(7, for: linus, inRound: match.rounds[1].id)

        #expect(match.total(for: ada) == 9)
        #expect(match.total(for: grace) == 25)
        #expect(match.total(for: linus) == 7)
    }

    @Test func retypingACellReplacesItsScore() {
        var match = skyjoMatch()
        let ada = match.teams[0].id
        let round = match.rounds[0].id

        match.setScore(1, for: ada, inRound: round)
        match.setScore(12, for: ada, inRound: round)

        #expect(match.rounds[0].points(for: ada) == 12)
        #expect(match.total(for: ada) == 12)
    }

    @Test func aTeamNotYetScoredHasNoScoreWhileAZeroIsKept() {
        var match = skyjoMatch()
        let (ada, grace) = (match.teams[0].id, match.teams[1].id)

        match.setScore(0, for: ada, inRound: match.rounds[0].id)

        #expect(match.rounds[0].points(for: ada) == 0)
        #expect(match.rounds[0].points(for: grace) == nil)
    }

    @Test func totalsArePartialWhileARoundIsPartlyFilled() {
        var match = skyjoMatch()
        let round = match.rounds[0].id

        match.setScore(12, for: match.teams[0].id, inRound: round)
        match.setScore(5, for: match.teams[1].id, inRound: round)

        #expect(match.totalsArePartial)
        #expect(match.total(for: match.teams[0].id) == 12)

        match.setScore(0, for: match.teams[2].id, inRound: round)

        #expect(!match.totalsArePartial)
    }

    @Test func anUntouchedRoundDoesNotMakeTotalsPartial() {
        var match = skyjoMatch()
        #expect(!match.totalsArePartial)

        for team in match.teams {
            match.setScore(4, for: team.id, inRound: match.rounds[0].id)
        }
        match.startNewRound()

        #expect(!match.totalsArePartial)
    }

    @Test func startingANewRoundRecordsZeroForEveryTeamNotYetScored() {
        var match = skyjoMatch()
        let (ada, grace, linus) = (match.teams[0].id, match.teams[1].id, match.teams[2].id)
        match.setScore(8, for: ada, inRound: match.rounds[0].id)

        match.startNewRound()

        #expect(match.rounds[0].points(for: ada) == 8)
        #expect(match.rounds[0].points(for: grace) == 0)
        #expect(match.rounds[0].points(for: linus) == 0)
        #expect(!match.totalsArePartial)
    }

    @Test func theLowestTotalLeadsWhenTheLowestWins() {
        var match = skyjoMatch()
        let round = match.rounds[0].id
        match.setScore(12, for: match.teams[0].id, inRound: round)
        match.setScore(5, for: match.teams[1].id, inRound: round)
        match.setScore(9, for: match.teams[2].id, inRound: round)

        #expect(match.leaders.map(\.name) == ["Grace"])
    }

    @Test func theHighestTotalLeadsWhenTheHighestWins() {
        var match = Match(game: .tarot, teams: ["Ada", "Grace", "Linus"].map { Team(players: [Player(name: $0)]) })
        let round = match.rounds[0].id
        match.setScore(-40, for: match.teams[0].id, inRound: round)
        match.setScore(80, for: match.teams[1].id, inRound: round)
        match.setScore(-40, for: match.teams[2].id, inRound: round)

        #expect(match.leaders.map(\.name) == ["Grace"])
    }

    @Test func theLeaderFollowsEachScoreOfAPartlyFilledRound() {
        var match = skyjoMatch()
        let (ada, grace, linus) = (match.teams[0].id, match.teams[1].id, match.teams[2].id)
        for (team, points) in [(ada, 10), (grace, 20), (linus, 30)] {
            match.setScore(points, for: team, inRound: match.rounds[0].id)
        }
        match.startNewRound()

        match.setScore(15, for: ada, inRound: match.rounds[1].id)

        #expect(match.totalsArePartial)
        #expect(match.leaders.map(\.name) == ["Grace"])

        match.setScore(-12, for: linus, inRound: match.rounds[1].id)

        #expect(match.leaders.map(\.name) == ["Linus"])
    }

    @Test func correctingAScoreThreeRoundsAgoHandsTheLeadOver() {
        var match = skyjoMatch()
        let ada = match.teams[0].id
        score([[4, 9, 10], [6, 2, 3], [5, 5, 5], [1, 1, 1]], in: &match)
        #expect(match.leaders.map(\.name) == ["Ada"])

        match.setScore(14, for: ada, inRound: match.rounds[0].id)

        #expect(match.total(for: ada) == 26)
        #expect(match.leaders.map(\.name) == ["Grace"])
    }

    @Test func deletingARoundTakesItsScoresOutOfTheTotalsAndTheLead() {
        var match = skyjoMatch()
        let ada = match.teams[0].id
        score([[4, 9, 10], [20, 2, 3], [5, 5, 5]], in: &match)
        #expect(match.leaders.map(\.name) == ["Grace"])
        let (second, third) = (match.rounds[1].id, match.rounds[2].id)

        match.deleteRound(second)

        #expect(match.rounds.count == 3)
        #expect(match.round(second) == nil)
        #expect(match.number(of: third) == 2)
        #expect(match.total(for: ada) == 9)
        #expect(match.leaders.map(\.name) == ["Ada"])
    }

    @Test func deletingTheRoundInPlayLeavesTheOneBeforeItLast() {
        var match = skyjoMatch()
        for team in match.teams {
            match.setScore(3, for: team.id, inRound: match.rounds[0].id)
        }
        match.startNewRound()
        match.setScore(7, for: match.teams[0].id, inRound: match.rounds[1].id)
        #expect(match.totalsArePartial)

        match.deleteRound(match.rounds[1].id)

        #expect(match.rounds.count == 1)
        #expect(!match.totalsArePartial)
        #expect(match.canStartNewRound)
    }

    @Test func deletingTheOnlyRoundLeavesAnEmptyOneToScore() {
        var match = skyjoMatch()
        let only = match.rounds[0].id
        match.setScore(7, for: match.teams[0].id, inRound: only)

        match.deleteRound(only)

        #expect(match.rounds.count == 1)
        #expect(match.rounds[0].id != only)
        #expect(match.rounds[0].scores.isEmpty)
        #expect(match.leaders.isEmpty)
    }

    @Test func teamsLevelOnTheBestTotalShareTheLead() {
        var match = skyjoMatch()
        let round = match.rounds[0].id
        match.setScore(4, for: match.teams[0].id, inRound: round)
        match.setScore(9, for: match.teams[1].id, inRound: round)
        match.setScore(4, for: match.teams[2].id, inRound: round)

        #expect(match.leaders.map(\.name) == ["Ada", "Linus"])
    }

    @Test func nobodyLeadsBeforeTheFirstScore() {
        #expect(skyjoMatch().leaders.isEmpty)
    }

    @Test func theLeadingTotalIsTheLowestInSkyjo() {
        var match = skyjoMatch()
        score([[12, 5, 30], [-2, 8, 1]], in: &match)

        #expect(match.leadingTotal == 10)
    }

    @Test func theLeadingTotalIsTheHighestWhenTheHighestWins() {
        var match = Match(game: .scrabble, teams: ["Ada", "Grace"].map { Team(players: [Player(name: $0)]) })
        score([[40, 12], [3, 60]], in: &match)

        #expect(match.leadingTotal == 72)
    }

    @Test func teamsLevelOnTheBestTotalShareTheLeadingTotal() {
        var match = skyjoMatch()
        score([[4, 9, 4]], in: &match)

        #expect(match.leadingTotal == 4)
    }

    @Test func thereIsNoLeadingTotalBeforeTheFirstScore() {
        #expect(skyjoMatch().leadingTotal == nil)
    }

    @Test func aNewRoundWaitsUntilTheLastOneHasAScore() {
        var match = skyjoMatch()
        #expect(!match.canStartNewRound)

        match.startNewRound()
        #expect(match.rounds.count == 1)

        match.setScore(3, for: match.teams[0].id, inRound: match.rounds[0].id)
        #expect(match.canStartNewRound)
        match.startNewRound()
        #expect(match.rounds.count == 2)
        #expect(!match.canStartNewRound)
    }

    @Test func aMatchMidRoundSurvivesAJSONRoundTrip() throws {
        var match = skyjoMatch()
        for team in match.teams {
            match.setScore(6, for: team.id, inRound: match.rounds[0].id)
        }
        match.startNewRound()
        match.setScore(-2, for: match.teams[1].id, inRound: match.rounds[1].id)

        let data = try JSONEncoder().encode(match)
        let decoded = try JSONDecoder().decode(Match.self, from: data)

        #expect(decoded == match)
        #expect(decoded.total(for: match.teams[1].id) == 4)
        #expect(decoded.totalsArePartial)
    }
}
