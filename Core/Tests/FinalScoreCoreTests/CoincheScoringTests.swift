import Testing
@testable import FinalScoreCore

/// Coinche gives each Round to one Team, but the scorepad doesn't know that:
/// the user types the winning Team's points, and moving on gives the other
/// Team its 0, as in any Game.
@Suite("Coinche scoring")
struct CoincheScoringTests {
    /// A Coinche Match of Ada & Linus against Grace & Marie, in that column order.
    private func coincheMatch() -> Match {
        let players = ["Ada", "Grace", "Linus", "Marie"].map { Player(name: $0) }
        return Match(
            game: .coinche,
            teams: [Team(players: [players[0], players[2]]), Team(players: [players[1], players[3]])],
            seating: Seating(order: players.map(\.id), rotation: .clockwise)
        )
    }

    @Test func aNewRoundOpensTheKeypadOnTheFirstTeam() {
        let scorepad = Scorepad(match: coincheMatch())

        #expect(scorepad.selection == .init(round: scorepad.match.rounds[0].id, team: scorepad.match.teams[0].id))
        #expect(scorepad.keypadText == "0")
    }

    @Test func scoringOneTeamAndStartingTheNextRoundGivesTheOtherTeamAnExplicitZero() {
        var scorepad = Scorepad(match: coincheMatch())
        let (ada, grace) = (scorepad.match.teams[0].id, scorepad.match.teams[1].id)
        scorepad.enterQuickScore(120)

        scorepad.startNewRound()

        let match = scorepad.match
        #expect(match.rounds.count == 2)
        #expect(match.rounds[0].points(for: ada) == 120)
        #expect(match.rounds[0].points(for: grace) == 0)
        #expect(!match.totalsArePartial)
        #expect(scorepad.selection == .init(round: match.rounds[1].id, team: ada))
    }
}
