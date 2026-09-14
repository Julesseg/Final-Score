import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Rematch")
struct RematchTests {
    private let ada = Player(name: "Ada")
    private let grace = Player(name: "Grace")
    private let linus = Player(name: "Linus")
    private let marie = Player(name: "Marie")
    private let tim = Player(name: "Tim")

    private var roster: [Player] { [ada, grace, linus, marie, tim] }

    /// What Rematch opens: setup on the finished Match's own Game, with that
    /// Match's Players picked.
    private func rematchSetup(of finished: Match) -> MatchSetup {
        MatchSetup(game: finished.game, roster: roster, previous: finished)
    }

    /// A Belote Match with Ada and Grace on one Team, the deal passing
    /// counter-clockwise, one Round scored, then ended.
    private func finishedBelote() throws -> Match {
        var setup = MatchSetup(game: .belote, roster: roster, previous: nil)
        for player in [ada, linus, grace, marie] {
            setup.pick(player.id)
        }
        setup.rotation = .counterclockwise
        var match = try #require(setup.makeMatch())
        match.setScore(91, for: match.teams[0].id, inRound: match.rounds[0].id)
        match.setScore(71, for: match.teams[1].id, inRound: match.rounds[0].id)
        match.end()
        return match
    }

    @Test func aRematchSetsUpTheSameGameTeamsSeatingAndRotation() throws {
        let finished = try finishedBelote()

        let setup = rematchSetup(of: finished)

        #expect(setup.game == finished.game)
        #expect(setup.seating == finished.seating?.order)
        #expect(setup.rotation == .counterclockwise)
        #expect(setup.teams.map { $0.map(\.name) } == [["Ada", "Grace"], ["Linus", "Marie"]])
        #expect(setup.canStart, "Same again is one tap")
    }

    @Test func aRematchStartsANewMatchWithNoScoresAndLeavesTheFinishedOneUntouched() throws {
        let finished = try finishedBelote()
        let before = finished

        let rematch = try #require(rematchSetup(of: finished).makeMatch())

        #expect(rematch.id != finished.id)
        #expect(!rematch.isEnded)
        #expect(rematch.rounds.count == 1)
        #expect(rematch.rounds[0].scores.isEmpty)
        #expect(rematch.teams.allSatisfy { rematch.total(for: $0.id) == 0 })
        #expect(rematch.teams.map(\.name) == finished.teams.map(\.name))
        #expect(rematch.seating == finished.seating)
        #expect(rematch.rounds[0].dealer == ada.id, "The same first seat deals again")
        #expect(finished == before)
    }

    @Test func aRematchPlaysTheFinishedMatchsOwnCopyOfItsGame() {
        var shortSkyjo = Game.skyjo
        shortSkyjo.endCondition = .targetTotal(50)
        var finished = Match(game: shortSkyjo, teams: [ada, grace].map { Team(players: [$0]) })
        finished.end()

        let setup = rematchSetup(of: finished)

        #expect(setup.game == shortSkyjo)
    }

    @Test func aRematchOfATallyStartsEveryTotalBackAtZero() throws {
        var finished = Match(game: .points, teams: [ada, grace].map { Team(players: [$0]) })
        finished.recordTallyScore(12, for: finished.teams[0].id)
        finished.end()

        let rematch = try #require(rematchSetup(of: finished).makeMatch())

        #expect(rematch.tallyScores.isEmpty)
        #expect(rematch.teams.map(\.name) == ["Ada", "Grace"])
        #expect(finished.tallyScores.count == 1)
    }

    @Test func aRematchStaysEditableBeforeStart() throws {
        var finished = Match(
            game: .tarot,
            teams: [ada, grace, linus].map { Team(players: [$0]) },
            seating: Seating(order: [ada.id, grace.id, linus.id], rotation: .clockwise)
        )
        finished.end()
        var setup = rematchSetup(of: finished)

        // Linus went home; Marie takes the seat.
        setup.toggle(linus.id)
        setup.toggle(marie.id)
        setup.rotation = .counterclockwise
        let rematch = try #require(setup.makeMatch())

        #expect(rematch.seating == Seating(order: [ada.id, grace.id, marie.id], rotation: .counterclockwise))
    }
}
