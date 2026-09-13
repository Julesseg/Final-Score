import Testing
import Foundation
@testable import FinalScoreCore

@Suite("The Player roster")
final class PlayerStoreTests {
    /// A directory of this test's own, thrown away when the test ends.
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlayerStoreTests-\(UUID().uuidString)")

    private var file: URL {
        directory.appendingPathComponent("Players.json")
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func aPlayerAddedToTheRosterIsBackAfterTheStoreIsOpenedAgain() throws {
        let ada = try #require(try PlayerStore(file: file).add(named: "Ada"))

        #expect(PlayerStore(file: file).players == [ada])
    }

    @Test func aPlayerThatCannotBeWrittenIsStillOnTheRosterForTheRestOfTheSession() throws {
        // A file where the directory should be: nothing can be written under it.
        try Data().write(to: directory)
        let store = PlayerStore(file: file)

        #expect(throws: (any Error).self) { try store.add(named: "Ada") }
        #expect(store.players.map(\.name) == ["Ada"])
    }

    @Test func addingANameAlreadyOnTheRosterGivesBackThatPlayerRatherThanADuplicate() throws {
        let store = PlayerStore(file: file)
        let ada = try #require(try store.add(named: "  Ada "))

        #expect(ada.name == "Ada")
        #expect(try store.add(named: "ada") == ada)
        #expect(store.players == [ada])
    }

    @Test func aBlankNameAddsNobody() throws {
        let store = PlayerStore(file: file)

        #expect(try store.add(named: "  ") == nil)
        #expect(store.players.isEmpty)
    }

    @Test func aRenamedPlayerKeepsTheirIdentityAndTheNewNameSticks() throws {
        let store = PlayerStore(file: file)
        let grace = try #require(try store.add(named: "Grcae"))

        try store.rename(grace.id, to: " Grace ")

        #expect(PlayerStore(file: file).players == [Player(id: grace.id, name: "Grace")])
    }

    @Test func renamingToABlankNameKeepsTheOldOne() throws {
        let store = PlayerStore(file: file)
        let grace = try #require(try store.add(named: "Grace"))

        try store.rename(grace.id, to: "   ")

        #expect(store.players == [grace])
    }

    @Test func aDeletedPlayerIsGoneForGood() throws {
        let store = PlayerStore(file: file)
        let ada = try #require(try store.add(named: "Ada"))
        let grace = try #require(try store.add(named: "Grace"))

        try store.delete(ada.id)

        #expect(store.players == [grace])
        #expect(PlayerStore(file: file).players == [grace])
    }

    @Test func renamingOrDeletingAPlayerLeavesTheMatchesTheyPlayedExactlyAsTheyWere() throws {
        let roster = PlayerStore(file: file)
        let ada = try #require(try roster.add(named: "Ada"))
        let grace = try #require(try roster.add(named: "Grcae"))
        var setup = MatchSetup(game: .skyjo, roster: roster.players, previous: nil)
        setup.toggle(ada.id)
        setup.toggle(grace.id)
        var played = try #require(setup.makeMatch())
        played.setScore(12, for: played.teams[0].id, inRound: played.rounds[0].id)
        played.setScore(5, for: played.teams[1].id, inRound: played.rounds[0].id)
        let matchesDirectory = directory.appendingPathComponent("Matches")
        try MatchStore(directory: matchesDirectory).save(played)

        try roster.rename(grace.id, to: "Grace")
        try roster.delete(ada.id)

        let reopened = try #require(MatchStore(directory: matchesDirectory).match(id: played.id))
        #expect(reopened == played)
        #expect(reopened.teams.map(\.name) == ["Ada", "Grcae"])
        #expect(reopened.total(for: reopened.teams[0].id) == 12)
        #expect(reopened.total(for: reopened.teams[1].id) == 5)
    }

    @Test func theRosterIsListedAlphabeticallyWhateverOrderPlayersJoinedIn() throws {
        let store = PlayerStore(file: file)
        for name in ["linus", "Grace", "Ada"] {
            _ = try store.add(named: name)
        }
        #expect(store.players.map(\.name) == ["Ada", "Grace", "linus"])

        try store.rename(store.players[0].id, to: "Marie")

        #expect(store.players.map(\.name) == ["Grace", "linus", "Marie"])
        #expect(PlayerStore(file: file).players.map(\.name) == ["Grace", "linus", "Marie"])
    }
}
