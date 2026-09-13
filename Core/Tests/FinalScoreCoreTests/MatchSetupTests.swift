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
        #expect(setup.seat(of: ada.id) == 2)
        #expect(setup.seat(of: marie.id) == nil)
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

    @Test func aGameThatTracksTheDealerStartsWithTheSeatingOrderAndChosenRotation() throws {
        var setup = MatchSetup(game: .skyjo, roster: roster, previous: nil)
        setup.toggle(grace.id)
        setup.toggle(ada.id)
        setup.toggle(linus.id)
        #expect(setup.rotation == .clockwise, "Clockwise until told otherwise")

        setup.rotation = .counterclockwise
        let match = try #require(setup.makeMatch())

        #expect(match.seating == Seating(order: [grace.id, ada.id, linus.id], rotation: .counterclockwise))
        #expect(match.rounds[0].dealer == grace.id)
    }

    @Test func aGameThatDoesNotTrackTheDealerStartsWithNoSeating() throws {
        let previous = match(of: .skyjo, between: [ada, grace])
        var setup = MatchSetup(game: .scrabble, roster: roster, previous: previous)
        setup.rotation = .counterclockwise

        let match = try #require(setup.makeMatch())

        #expect(match.seating == nil)
        #expect(match.rounds[0].dealer == nil)
    }

    @Test func thePreviousMatchsRotationComesPreSelected() {
        let previous = Match(
            game: .tarot,
            teams: [ada, grace, linus].map { Team(players: [$0]) },
            seating: Seating(order: [ada.id, grace.id, linus.id], rotation: .counterclockwise)
        )

        let setup = MatchSetup(game: .skyjo, roster: roster, previous: previous)

        #expect(setup.rotation == .counterclockwise)
    }

    // MARK: Team Games

    /// Picks everyone, in the order given, into a Belote setup.
    private func beloteSetup(seating players: [Player]) -> MatchSetup {
        var setup = MatchSetup(game: .belote, roster: roster, previous: nil)
        for player in players {
            setup.pick(player.id)
        }
        return setup
    }

    @Test func aTeamGameSeatsPartnersAcrossTheTableFromEachOther() throws {
        let setup = beloteSetup(seating: [ada, grace, linus, marie])

        #expect(setup.teams.map { $0.map(\.name) } == [["Ada", "Linus"], ["Grace", "Marie"]])
        #expect(setup.canStart)

        let match = try #require(setup.makeMatch())

        #expect(match.teams.map(\.name) == ["Ada & Linus", "Grace & Marie"])
        #expect(
            match.seating == Seating(order: [ada.id, grace.id, linus.id, marie.id], rotation: .clockwise),
            "Seats keep the order they were picked in, whoever partners whom"
        )
    }

    @Test func theDealStillPassesSeatBySeatInATeamGame() throws {
        var match = try #require(beloteSetup(seating: [ada, grace, linus, marie]).makeMatch())

        #expect(match.rounds[0].dealer == ada.id)
        match.setScore(81, for: match.teams[0].id, inRound: match.rounds[0].id)
        match.startNewRound()

        #expect(match.rounds[1].dealer == grace.id, "The next seat deals, not the next Team")
    }

    @Test func everyonePlayingIsListedInSeatingOrderNotInTeamOrder() throws {
        let match = try #require(beloteSetup(seating: [ada, grace, linus, marie]).makeMatch())

        #expect(match.players == [ada, grace, linus, marie])
    }

    @Test func aTeamGameCannotStartOnHalfATeam() {
        var setup = MatchSetup(game: .belote, roster: roster, previous: nil)

        setup.pick(ada.id)
        setup.pick(grace.id)
        setup.pick(linus.id)

        #expect(!setup.canStart, "Three Players leave Grace and Marie's Team a Player short")
        #expect(setup.makeMatch() == nil)
        #expect(setup.teams.map { $0.map(\.name) } == [["Ada", "Linus"], ["Grace"]], "The Teams show as they form")

        setup.pick(marie.id)
        #expect(setup.canStart)
        #expect(!setup.canPick(tim.id), "Belote seats four and no more")
    }

    @Test func swappingTwoSeatsReFormsTheTeamsAroundThem() throws {
        var setup = beloteSetup(seating: [ada, grace, linus, marie])

        setup.swapSeats(grace.id, linus.id)

        #expect(setup.teams.map { $0.map(\.name) } == [["Ada", "Grace"], ["Linus", "Marie"]])
        #expect(setup.seat(of: grace.id) == 3)
        #expect(setup.seat(of: linus.id) == 2)

        let match = try #require(setup.makeMatch())
        #expect(match.seating?.order == [ada.id, linus.id, grace.id, marie.id])
    }

    @Test func aPlayerCanOnlyTradeSeatsWithSomeoneOffTheirOwnTeam() {
        let setup = beloteSetup(seating: [ada, grace, linus, marie])

        #expect(
            setup.swapCandidates(for: ada.id).map(\.name) == ["Grace", "Marie"],
            "Trading seats with Linus would leave Ada on the same Team"
        )
        #expect(setup.swapCandidates(for: tim.id).isEmpty, "Tim has no seat to trade")
    }

    @Test func inAnIndividualGameEverySeatIsWorthTradingWith() {
        var setup = MatchSetup(game: .skyjo, roster: roster, previous: nil)
        setup.pick(ada.id)
        setup.pick(grace.id)
        setup.pick(linus.id)

        #expect(setup.swapCandidates(for: grace.id).map(\.name) == ["Ada", "Linus"])
    }

    @Test func aRematchOfATeamGameWithoutADealerKeepsTheSameTeams() throws {
        // No built-in Game is like this yet, but nothing stops one being.
        var untracked = Game.belote
        untracked.tracksDealer = false
        var setup = MatchSetup(game: untracked, roster: roster, previous: nil)
        for player in [ada, grace, linus, marie] {
            setup.pick(player.id)
        }
        let previous = try #require(setup.makeMatch())
        #expect(previous.seating == nil)

        let rematch = try #require(
            MatchSetup(game: untracked, roster: roster, previous: previous).makeMatch()
        )

        #expect(rematch.teams.map(\.name) == previous.teams.map(\.name))
    }

    @Test func swappingSeatsWithSomeoneWhoHasNoneLeavesTheTeamsAlone() {
        var setup = beloteSetup(seating: [ada, grace, linus, marie])

        setup.swapSeats(ada.id, tim.id)

        #expect(setup.seating == [ada.id, grace.id, linus.id, marie.id])
    }

    @Test func aRematchOfATeamGamePreSelectsEveryoneInTheirSeatingOrder() throws {
        let previous = try #require(beloteSetup(seating: [ada, grace, linus, marie]).makeMatch())

        let setup = MatchSetup(game: .belote, roster: roster, previous: previous)

        #expect(setup.seating == [ada.id, grace.id, linus.id, marie.id])
        #expect(setup.teams.map { $0.map(\.name) } == [["Ada", "Linus"], ["Grace", "Marie"]])
    }

    @Test func anIndividualGameGivesEveryPlayerATeamOfTheirOwn() {
        var setup = MatchSetup(game: .skyjo, roster: roster, previous: nil)
        setup.pick(ada.id)
        setup.pick(grace.id)
        setup.pick(linus.id)

        #expect(setup.teams.map { $0.map(\.name) } == [["Ada"], ["Grace"], ["Linus"]])
    }
}
