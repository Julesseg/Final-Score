import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Match setup")
struct MatchSetupTests {
    private let ada = Player(name: "Ada")
    private let grace = Player(name: "Grace")
    private let linus = Player(name: "Linus")
    private let marie = Player(name: "Marie")
    private let tim = Player(name: "Tim")

    private var roster: [Player] { [ada, grace, linus, marie, tim] }

    private func match(of game: Game, between players: [Player]) -> Match {
        Match(game: game, teams: players.map { Team(players: [$0]) })
    }

    @Test func thePreviousMatchsPlayersArePreSelectedInTheirSeatingOrder() {
        let previous = match(of: .skyjo, between: [linus, ada, grace])

        let setup = MatchSetup(game: .skyjo, roster: roster, previous: previous)

        #expect(setup.seating == [linus.id, ada.id, grace.id])
        #expect(setup.canStart)
    }

    @Test func aPreviousPlayerSinceDeletedFromTheRosterIsNotPreSelected() {
        let previous = match(of: .skyjo, between: [ada, grace, linus])

        let setup = MatchSetup(game: .skyjo, roster: [ada, linus], previous: previous)

        #expect(setup.seating == [ada.id, linus.id])
    }

    @Test func preSelectionStopsAtTheMostPlayersTheNewGameAllows() {
        let previous = match(of: .skyjo, between: [ada, grace, linus, marie, tim])

        let setup = MatchSetup(game: .scrabble, roster: roster, previous: previous)

        #expect(setup.seating == [ada.id, grace.id, linus.id, marie.id])
    }

    @Test func withNoPreviousMatchNobodyIsPickedAndTheMatchCannotStart() {
        let setup = MatchSetup(game: .skyjo, roster: roster, previous: nil)

        #expect(setup.seating.isEmpty)
        #expect(!setup.canStart)
        #expect(setup.makeMatch() == nil)
    }

    @Test func playersTakeTheirSeatsInTheOrderTheyArePicked() {
        var setup = MatchSetup(game: .skyjo, roster: roster, previous: nil)

        setup.toggle(grace.id)
        #expect(!setup.canStart)
        setup.toggle(ada.id)
        setup.toggle(linus.id)
        setup.toggle(grace.id)

        #expect(setup.seating == [ada.id, linus.id])
        #expect(setup.canStart)
    }

    @Test func noMorePlayersCanBePickedThanTheGameAllows() {
        var setup = MatchSetup(game: .scrabble, roster: roster, previous: nil)
        for player in [ada, grace, linus, marie] {
            setup.toggle(player.id)
        }

        #expect(!setup.canPick(tim.id))
        #expect(setup.canPick(ada.id), "A picked Player can always be unpicked")
        setup.toggle(tim.id)
        #expect(setup.seating == [ada.id, grace.id, linus.id, marie.id])
    }

    @Test func startsAMatchWithATeamOfOnePerPlayerInSeatingOrderAndAnEmptyFirstRound() throws {
        let previous = match(of: .skyjo, between: [grace, ada])
        let setup = MatchSetup(game: .skyjo, roster: roster, previous: previous)

        let match = try #require(setup.makeMatch())

        #expect(match.game == .skyjo)
        #expect(match.teams.map(\.players) == [[grace], [ada]])
        #expect(match.rounds.count == 1)
        #expect(match.rounds[0].scores.isEmpty)
    }

    @Test func aPlayerDeletedFromTheRosterMidSetupGivesUpTheirSeat() {
        let previous = match(of: .skyjo, between: [ada, grace, linus])
        var setup = MatchSetup(game: .skyjo, roster: roster, previous: previous)

        setup.roster = [ada, linus, marie]

        #expect(setup.seating == [ada.id, linus.id])
    }

    @Test func aPlayerRenamedMidSetupStartsTheMatchUnderTheirNewName() throws {
        let previous = match(of: .skyjo, between: [ada, grace])
        var setup = MatchSetup(game: .skyjo, roster: roster, previous: previous)

        setup.roster = [ada, Player(id: grace.id, name: "Grace H."), linus]

        let match = try #require(setup.makeMatch())
        #expect(match.teams.map(\.name) == ["Ada", "Grace H."])
    }

    @Test func pickingAnAlreadyPickedPlayerKeepsTheirSeat() {
        let previous = match(of: .skyjo, between: [ada, grace])
        var setup = MatchSetup(game: .skyjo, roster: roster, previous: previous)

        // + Add player, typing a name already on the roster, hands that Player back.
        setup.pick(ada.id)
        setup.pick(linus.id)

        #expect(setup.seating == [ada.id, grace.id, linus.id])
    }
}
