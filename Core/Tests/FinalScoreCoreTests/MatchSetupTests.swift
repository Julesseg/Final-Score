import Testing
@testable import FinalScoreCore

@Suite("Match setup")
struct MatchSetupTests {
    @Test func startsWithTheFewestPlayersTheGameAllows() {
        #expect(MatchSetup(game: .skyjo).playerNames == ["", ""])
        #expect(MatchSetup(game: .tarot).playerNames == ["", "", ""])
    }

    @Test func startsAMatchWithATeamOfOnePerPlayerAndAnEmptyFirstRound() throws {
        var setup = MatchSetup(game: .skyjo)
        setup.playerNames = ["  Ada ", "Grace"]

        let match = try #require(setup.makeMatch())

        #expect(match.game == .skyjo)
        #expect(match.teams.map { $0.players.map(\.name) } == [["Ada"], ["Grace"]])
        #expect(match.rounds.count == 1)
        #expect(match.rounds[0].scores.isEmpty)
    }

    @Test func cannotStartUntilEveryPlayerHasAName() {
        var setup = MatchSetup(game: .skyjo)
        setup.playerNames = ["Ada", "   "]

        #expect(!setup.canStart)
        #expect(setup.makeMatch() == nil)
    }

    @Test func addsPlayersUpToTheGamesMaximum() {
        var setup = MatchSetup(game: .scrabble)
        setup.addPlayer()
        setup.addPlayer()

        #expect(setup.playerNames.count == 4)
        #expect(!setup.canAddPlayer)
        setup.addPlayer()
        #expect(setup.playerNames.count == 4)
    }

    @Test func removesPlayersDownToTheGamesMinimum() {
        var setup = MatchSetup(game: .skyjo)
        setup.playerNames = ["Ada", "Grace", "Linus"]

        setup.removePlayer(at: 1)

        #expect(setup.playerNames == ["Ada", "Linus"])
        #expect(!setup.canRemovePlayer)
        setup.removePlayer(at: 0)
        #expect(setup.playerNames == ["Ada", "Linus"])
    }
}
