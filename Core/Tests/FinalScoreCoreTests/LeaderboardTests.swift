import Testing
@testable import FinalScoreCore

@Suite("Leaderboard")
struct LeaderboardTests {
    private let teams = ["Ada", "Grace", "Linus"].map { Team(players: [Player(name: $0)]) }

    @Test(arguments: [Game.Direction.highWins, .lowWins])
    func roundsRankCurrentTotalsInTheGamesDirection(_ direction: Game.Direction) {
        var game = Game.tarot
        game.direction = direction
        var match = Match(game: game, teams: teams)
        for (team, score) in zip(teams, [10, -5, 20]) {
            match.setScore(score, for: team.id, inRound: match.rounds[0].id)
        }
        let expected = direction == .highWins ? [teams[2], teams[0], teams[1]] : [teams[1], teams[0], teams[2]]
        #expect(match.leaderboard.map(\.team) == expected)
        #expect(match.leaderboard.map(\.rank) == [1, 2, 3])
        #expect(match.leaderboard.map(\.total) == (direction == .highWins ? [20, 10, -5] : [-5, 10, 20]))
    }

    @Test func tiesShareARankAndKeepTeamOrderIncludingBeforeAnyScore() {
        var match = Match(game: .points, teams: teams)
        #expect(match.leaderboard.map(\.team) == teams)
        #expect(match.leaderboard.map(\.rank) == [1, 1, 1])
        match.recordTallyScore(10, for: teams[0].id)
        match.recordTallyScore(10, for: teams[1].id)
        #expect(match.leaderboard.map(\.rank) == [1, 1, 3])
        match.recordTallyScore(20, for: teams[2].id)
        #expect(match.leaderboard.map(\.team) == [teams[2], teams[0], teams[1]])
        #expect(match.leaderboard.map(\.rank) == [1, 2, 2])
        match.setTallyScore(-5, at: 2)
        #expect(match.leaderboard.map(\.team) == teams)
        #expect(match.leaderboard.map(\.total) == [10, 10, -5])
    }

    @Test func partialRoundsAndCorrectionsImmediatelyChangeTheLeaderboard() {
        var match = Match(game: .skyjo, teams: teams)
        match.setScore(5, for: teams[0].id, inRound: match.rounds[0].id)
        #expect(match.leaderboard.map(\.team) == [teams[1], teams[2], teams[0]])
        match.setScore(-5, for: teams[0].id, inRound: match.rounds[0].id)
        #expect(match.leaderboard.map(\.team) == teams)
        #expect(match.leaderboard.map(\.total) == [-5, 0, 0])
    }
}
