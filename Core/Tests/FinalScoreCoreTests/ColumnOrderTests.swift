import Foundation
import Testing
@testable import FinalScoreCore

@Suite("Reordering scorepad columns")
struct ColumnOrderTests {
    private let players = ["Ada", "Grace", "Linus"].map { Player(name: $0) }

    private func match(rotation: Seating.Rotation = .clockwise) -> Match {
        Match(
            game: .skyjo,
            teams: players.map { Team(players: [$0]) },
            seating: Seating(order: players.map(\.id), rotation: rotation)
        )
    }

    @Test(arguments: [Seating.Rotation.clockwise, .counterclockwise])
    func movingColumnsPreservesExistingRoundsAndUsesNewSeatingForTheNext(rotation: Seating.Rotation) {
        var match = match(rotation: rotation)
        let teams = match.teams
        for (index, team) in teams.enumerated() {
            match.setScore((index + 1) * 10, for: team.id, inRound: match.rounds[0].id)
        }
        match.startNewRound()
        match.setDealer(players[1].id, inRound: match.rounds[1].id)
        let rounds = match.rounds
        let totals = teams.map { match.total(for: $0.id) }
        let accents = teams.map { match.accent(of: $0.id) }

        match.moveTeam(teams[0].id, to: 2)

        #expect(match.teams == [teams[1], teams[2], teams[0]])
        #expect(match.players == [players[1], players[2], players[0]])
        #expect(match.rounds == rounds)
        #expect(teams.map { match.total(for: $0.id) } == totals)
        #expect(teams.map { match.accent(of: $0.id) } == accents)
        #expect(match.seating?.rotation == rotation)
        match.startNewRound()
        #expect(match.rounds.last?.dealer == (rotation == .clockwise ? players[2].id : players[0].id))
    }

    @Test func movingPartnershipColumnsKeepsTeamsAndAlternatingSeats() {
        let fourth = Player(name: "Marie")
        let teams = [Team(players: [players[0], players[2]]), Team(players: [players[1], fourth])]
        var match = Match(
            game: .belote, teams: teams,
            seating: Seating(order: [players[0].id, players[1].id, players[2].id, fourth.id], rotation: .clockwise)
        )
        match.moveTeam(teams[0].id, to: 1)

        #expect(match.teams == teams.reversed())
        #expect(match.seating?.order == [players[1].id, players[0].id, fourth.id, players[2].id])
        #expect(match.rounds[0].dealer == players[0].id)
        match.startNewRound()
        #expect(match.rounds[1].dealer == fourth.id)
    }

    @Test func movingOnTheScorepadKeepsTypingIntoTheSameScore() {
        var pad = Scorepad(match: match())
        pad.type(4)
        let selection = pad.selection
        let teams = pad.match.teams

        pad.moveTeam(teams[0].id, to: 2)
        #expect(pad.selection == selection)
        #expect(pad.keypadText == "4")
        pad.type(2)
        #expect(pad.match.rounds[0].points(for: teams[0].id) == 42)
        #expect(pad.nextStep == .newRound)
    }

    @Test func movedColumnsAndAccentsSurviveASnapshot() throws {
        var match = match()
        let teams = match.teams
        let accents = teams.map { match.accent(of: $0.id) }
        match.moveTeam(teams[0].id, to: 2)

        let restored = try JSONDecoder().decode(Match.self, from: JSONEncoder().encode(match))
        #expect(restored == match)
        #expect(teams.map { restored.accent(of: $0.id) } == accents)
        #expect(restored.seating?.order == [players[1].id, players[2].id, players[0].id])
    }

    @Test func movingWithoutDealerTrackingKeepsScoresAndDoesNotAddSeating() {
        let teams = players.map { Team(players: [$0]) }
        var match = Match(game: .scrabble, teams: teams)
        match.setScore(18, for: teams[0].id, inRound: match.rounds[0].id)
        let rounds = match.rounds

        match.moveTeam(teams[0].id, to: 2)

        #expect(match.teams == [teams[1], teams[2], teams[0]])
        #expect(match.seating == nil)
        #expect(match.rounds == rounds)
    }

    @Test func previewingALeftwardInsertionDoesNotChangeTheMatch() {
        var match = match()
        let original = match
        let teams = match.teams

        #expect(match.teams(moving: teams[2].id, to: 0) == [teams[2], teams[0], teams[1]])
        #expect(match == original)
        match.moveTeam(teams[2].id, to: 0)
        #expect(match.teams == [teams[2], teams[0], teams[1]])
        #expect(match.seating?.order == [players[2].id, players[0].id, players[1].id])
    }

    @Test func invalidOrIdenticalTeamsAndFinishedMatchesDoNotChange() {
        var match = match()
        let original = match
        match.moveTeam(match.teams[0].id, to: 3)
        match.moveTeam(UUID(), to: 0)
        match.moveTeam(match.teams[0].id, to: 0)
        match.moveTeam(match.teams[0].id, to: -1)
        #expect(match == original)

        match.end()
        let finished = match
        match.moveTeam(match.teams[0].id, to: 2)
        #expect(match == finished)
    }
}
