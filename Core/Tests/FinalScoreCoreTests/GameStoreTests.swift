import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Custom Games")
final class GameStoreTests {
    /// A directory of this test's own, thrown away when the test ends.
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("GameStoreTests-\(UUID().uuidString)")

    private var file: URL {
        directory.appendingPathComponent("Games.json")
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func draft(named name: String) -> GameDraft {
        var draft = GameDraft()
        draft.name = name
        return draft
    }

    @Test func aStoreWithNoFileHasNoCustomGames() {
        #expect(GameStore(file: file).customGames.isEmpty)
    }

    @Test func aCustomGameIsBackAfterTheStoreIsOpenedAgain() throws {
        let uno = try #require(try GameStore(file: file).add(draft(named: "Uno")))

        #expect(uno.game.name == "Uno")
        #expect(!uno.game.isBuiltIn)
        #expect(GameStore(file: file).customGames == [uno])
    }

    @Test func customGamesAreListedBelowTheBuiltInsInTheOrderTheyWereCreated() throws {
        let store = GameStore(file: file)
        for name in ["Uno", "Hearts", "Azul"] {
            _ = try store.add(draft(named: name))
        }

        #expect(store.customGames.map(\.game.name) == ["Uno", "Hearts", "Azul"])
        #expect(store.games.map(\.name) == Game.builtIns.map(\.name) + ["Uno", "Hearts", "Azul"])
        #expect(GameStore(file: file).customGames.map(\.game.name) == ["Uno", "Hearts", "Azul"])
    }

    @Test func aCustomGameThatCannotBeWrittenIsStillListedForTheRestOfTheSession() throws {
        // A file where the directory should be: nothing can be written under it.
        try Data().write(to: directory)
        let store = GameStore(file: file)

        #expect(throws: (any Error).self) { try store.add(self.draft(named: "Uno")) }
        #expect(store.customGames.map(\.game.name) == ["Uno"])
    }

    @Test func aGameNeedsANameNoOtherGameGoesBy() throws {
        let store = GameStore(file: file)
        _ = try store.add(draft(named: "Uno"))

        #expect(!store.canSave(draft(named: "  ")))
        #expect(!store.canSave(draft(named: "belote")), "Built-ins keep their names")
        #expect(!store.canSave(draft(named: " UNO ")))
        #expect(store.canSave(draft(named: "Hearts")))
        #expect(try store.add(draft(named: "uno")) == nil)
        #expect(store.customGames.count == 1)
    }

    @Test func anEditedGameKeepsItsIdentityAndItsPlaceAndMayKeepItsName() throws {
        let store = GameStore(file: file)
        let uno = try #require(try store.add(draft(named: "Uno")))
        _ = try store.add(draft(named: "Hearts"))
        var edit = GameDraft(game: uno.game)
        edit.name = "UNO"
        edit.endCondition = .targetTotal(500)

        #expect(store.canSave(edit, replacing: uno.id))
        try store.update(uno.id, to: edit)

        let reopened = GameStore(file: file).customGames
        #expect(reopened.map(\.id) == store.customGames.map(\.id))
        #expect(reopened[0].id == uno.id)
        #expect(reopened[0].game.name == "UNO")
        #expect(reopened[0].game.endCondition == .targetTotal(500))
    }

    @Test func anEditCannotTakeAnotherGamesName() throws {
        let store = GameStore(file: file)
        let uno = try #require(try store.add(draft(named: "Uno")))
        _ = try store.add(draft(named: "Hearts"))

        #expect(!store.canSave(draft(named: "hearts"), replacing: uno.id))
        try store.update(uno.id, to: draft(named: "hearts"))

        #expect(store.customGames.map(\.game.name) == ["Uno", "Hearts"])
    }

    @Test func aDeletedGameIsGoneForGood() throws {
        let store = GameStore(file: file)
        let uno = try #require(try store.add(draft(named: "Uno")))
        let hearts = try #require(try store.add(draft(named: "Hearts")))

        try store.delete(uno.id)

        #expect(store.customGames == [hearts])
        #expect(GameStore(file: file).customGames == [hearts])
    }

    @Test func aBuiltInIsDuplicatedAsAnEditableCopyUnderAFreeName() throws {
        let store = GameStore(file: file)

        let copy = store.duplicate(.belote)
        #expect(copy.game.name == "Belote copy")
        #expect(!copy.game.isBuiltIn)
        #expect(copy.game.endCondition == .targetTotal(501))
        #expect(store.customGames.isEmpty, "Nothing is saved until the copy is")

        _ = try store.add(copy)
        #expect(store.duplicate(.belote).game.name == "Belote copy 2")
    }

    @Test func editingOrDeletingACustomGameLeavesItsMatchesExactlyAsTheyWere() throws {
        let store = GameStore(file: file)
        var original = draft(named: "Uno")
        original.endCondition = .targetTotal(500)
        let uno = try #require(try store.add(original))
        var setup = MatchSetup(game: uno.game, roster: [Player(name: "Ada"), Player(name: "Grace")], previous: nil)
        setup.roster.forEach { setup.pick($0.id) }
        var played = try #require(setup.makeMatch())
        played.setScore(120, for: played.teams[0].id, inRound: played.rounds[0].id)
        let matchesDirectory = directory.appendingPathComponent("Matches")
        try MatchStore(directory: matchesDirectory).save(played)

        var edit = GameDraft(game: uno.game)
        edit.name = "Uno No Mercy"
        edit.structure = .tally
        edit.teamSize = 2
        try store.update(uno.id, to: edit)
        try store.delete(uno.id)

        let reopened = try #require(MatchStore(directory: matchesDirectory).match(id: played.id))
        #expect(reopened == played)
        #expect(reopened.game.name == "Uno")
        #expect(reopened.game.structure == .rounds)
        #expect(reopened.game.endCondition == .targetTotal(500))
        #expect(reopened.total(for: reopened.teams[0].id) == 120)
    }

    @Test func aGamesFileThatCannotBeReadIsSetAsideRatherThanOverwritten() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let unreadable = Data("not a list of games".utf8)
        try unreadable.write(to: file)

        let store = GameStore(file: file)
        _ = try store.add(draft(named: "Uno"))

        let kept = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .compactMap { try? Data(contentsOf: $0) }
        #expect(store.customGames.map(\.game.name) == ["Uno"])
        #expect(kept.contains(unreadable))
    }
}
