import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Storing Matches")
final class MatchStoreTests {
    /// A directory of this test's own — one suite instance is made per test —
    /// thrown away when the test ends.
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MatchStoreTests-\(UUID().uuidString)")

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func skyjoMatch(startedAt: Date = Date()) -> Match {
        Match(
            startedAt: startedAt,
            game: .skyjo,
            teams: [Team(players: [Player(name: "Ada")]), Team(players: [Player(name: "Grace")])]
        )
    }

    @Test func aStoreOpenedOnAnEmptyDirectoryHasNoMatches() {
        #expect(MatchStore(directory: directory).matches.isEmpty)
    }

    @Test func aMatchThatCannotBeWrittenIsStillInPlayForTheRestOfTheSession() throws {
        // A file where the directory should be: nothing can be written under it.
        try Data().write(to: directory)
        let store = MatchStore(directory: directory)
        let match = skyjoMatch()

        #expect(throws: (any Error).self) { try store.save(match) }
        #expect(store.matches == [match])
    }

    @Test func aSavedMatchIsBackAfterTheStoreIsOpenedAgain() throws {
        var match = skyjoMatch()
        match.setScore(12, for: match.teams[0].id, inRound: match.rounds[0].id)
        match.setScore(5, for: match.teams[1].id, inRound: match.rounds[0].id)
        try MatchStore(directory: directory).save(match)

        let reopened = MatchStore(directory: directory)

        #expect(reopened.matches == [match])
    }

    @Test func aPartlyFilledRoundIsRestoredExactlyAsItWasLeft() throws {
        var match = skyjoMatch()
        let (ada, grace) = (match.teams[0].id, match.teams[1].id)
        match.setScore(7, for: ada, inRound: match.rounds[0].id)
        match.startNewRound()
        // Round 2 is mid-entry: Ada has scored, Grace hasn't been reached yet.
        match.setScore(3, for: ada, inRound: match.rounds[1].id)
        try MatchStore(directory: directory).save(match)

        let restored = try #require(MatchStore(directory: directory).matches.first)

        #expect(restored.rounds.count == 2)
        #expect(restored.rounds[1].points(for: ada) == 3)
        #expect(restored.rounds[1].points(for: grace) == nil)
        #expect(restored.totalsArePartial)
    }

    @Test func savingAMatchAgainReplacesItsSnapshotRatherThanAddingOne() throws {
        let store = MatchStore(directory: directory)
        var match = skyjoMatch()
        try store.save(match)

        match.setScore(9, for: match.teams[0].id, inRound: match.rounds[0].id)
        try store.save(match)

        #expect(store.matches.count == 1)
        #expect(MatchStore(directory: directory).matches == [match])
    }

    @Test func matchesAreOrderedNewestFirst() throws {
        let store = MatchStore(directory: directory)
        let oldest = skyjoMatch(startedAt: Date(timeIntervalSince1970: 1_000))
        let newest = skyjoMatch(startedAt: Date(timeIntervalSince1970: 3_000))
        let middle = skyjoMatch(startedAt: Date(timeIntervalSince1970: 2_000))

        for match in [oldest, newest, middle] {
            try store.save(match)
        }

        #expect(store.matches.map(\.id) == [newest.id, middle.id, oldest.id])
        #expect(MatchStore(directory: directory).matches.map(\.id) == [newest.id, middle.id, oldest.id])
    }

    @Test func aSnapshotTheStoreCannotReadIsSkippedRatherThanLosingTheRest() throws {
        let match = skyjoMatch()
        try MatchStore(directory: directory).save(match)
        try Data("not a Match".utf8).write(to: directory.appendingPathComponent("\(UUID().uuidString).json"))
        try Data().write(to: directory.appendingPathComponent("notes.txt"))

        #expect(MatchStore(directory: directory).matches == [match])
    }

    @Test func aMatchIsFoundByItsID() throws {
        let store = MatchStore(directory: directory)
        let match = skyjoMatch()
        try store.save(match)

        #expect(store.match(id: match.id) == match)
        #expect(store.match(id: UUID()) == nil)
    }
}
