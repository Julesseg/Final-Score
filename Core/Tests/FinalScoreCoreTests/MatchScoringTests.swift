import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Scoring a Match")
struct MatchScoringTests {
    /// A Skyjo Match between Ada, Grace and Linus, in that column order.
    private func skyjoMatch() -> Match {
        var setup = MatchSetup(game: .skyjo)
        setup.playerNames = ["Ada", "Grace", "Linus"]
        return setup.makeMatch()!
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
        var setup = MatchSetup(game: .tarot)
        setup.playerNames = ["Ada", "Grace", "Linus"]
        var match = setup.makeMatch()!
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
