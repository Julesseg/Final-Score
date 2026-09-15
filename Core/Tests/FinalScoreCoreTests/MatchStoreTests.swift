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

    @Test func theSeatingAndEachRoundsDealerAreRestored() throws {
        let players = [Player(name: "Ada"), Player(name: "Grace")]
        var match = Match(
            game: .skyjo,
            teams: players.map { Team(players: [$0]) },
            seating: Seating(order: players.map(\.id), rotation: .counterclockwise)
        )
        match.setScore(4, for: match.teams[0].id, inRound: match.rounds[0].id)
        match.startNewRound()
        match.setDealer(players[0].id, inRound: match.rounds[1].id)
        try MatchStore(directory: directory).save(match)

        let restored = try #require(MatchStore(directory: directory).matches.first)

        #expect(restored.seating == match.seating)
        #expect(restored.rounds.map(\.dealer) == [players[0].id, players[0].id])
    }

    @Test func aMatchSavedBeforeDealersWereTrackedStillOpens() throws {
        let match = skyjoMatch()
        let snapshot = """
            {"id":"\(match.id.uuidString)","startedAt":0,"game":\(String(decoding: try JSONEncoder().encode(Game.skyjo), as: UTF8.self)),
             "teams":\(String(decoding: try JSONEncoder().encode(match.teams), as: UTF8.self)),
             "rounds":[{"id":"\(UUID().uuidString)","scores":[]}]}
            """
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(snapshot.utf8).write(to: directory.appendingPathComponent("\(match.id.uuidString).json"))

        let restored = try #require(MatchStore(directory: directory).matches.first)

        #expect(restored.seating == nil)
        #expect(restored.rounds.map(\.dealer) == [nil])
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

    @Test func matchesInProgressAreListedAboveFinishedOnes() throws {
        let store = MatchStore(directory: directory)
        var finishedFirst = skyjoMatch(startedAt: Date(timeIntervalSince1970: 3_000))
        let playingOld = skyjoMatch(startedAt: Date(timeIntervalSince1970: 1_000))
        var finishedLast = skyjoMatch(startedAt: Date(timeIntervalSince1970: 2_000))
        let playingNew = skyjoMatch(startedAt: Date(timeIntervalSince1970: 4_000))
        finishedFirst.end(at: Date(timeIntervalSince1970: 5_000))
        finishedLast.end(at: Date(timeIntervalSince1970: 6_000))

        for match in [finishedFirst, playingOld, finishedLast, playingNew] {
            try store.save(match)
        }

        // In progress newest started first; finished most recently ended first.
        let expected = [playingNew.id, playingOld.id, finishedLast.id, finishedFirst.id]
        #expect(store.matches.map(\.id) == expected)
        #expect(MatchStore(directory: directory).matches.map(\.id) == expected)
    }

    @Test func endingAMatchMovesItBelowTheMatchesStillInProgress() throws {
        let store = MatchStore(directory: directory)
        var newest = skyjoMatch(startedAt: Date(timeIntervalSince1970: 2_000))
        let older = skyjoMatch(startedAt: Date(timeIntervalSince1970: 1_000))
        try store.save(older)
        try store.save(newest)
        #expect(store.matches.map(\.id) == [newest.id, older.id])

        newest.end()
        try store.save(newest)

        #expect(store.matches.map(\.id) == [older.id, newest.id])
    }

    @Test func theNewestStartedOrderIgnoresWhetherAMatchHasEnded() throws {
        let store = MatchStore(directory: directory)
        let older = skyjoMatch(startedAt: Date(timeIntervalSince1970: 1_000))
        var newest = skyjoMatch(startedAt: Date(timeIntervalSince1970: 2_000))
        newest.end(at: Date(timeIntervalSince1970: 3_000))
        try store.save(older)
        try store.save(newest)

        #expect(store.matches.map(\.id) == [older.id, newest.id], "The list puts the one in progress first")
        #expect(store.newestStartedFirst.map(\.id) == [newest.id, older.id])
    }

    @Test func aSnapshotTheStoreCannotReadIsSkippedRatherThanLosingTheRest() throws {
        let match = skyjoMatch()
        try MatchStore(directory: directory).save(match)
        try Data("not a Match".utf8).write(to: directory.appendingPathComponent("\(UUID().uuidString).json"))
        try Data().write(to: directory.appendingPathComponent("notes.txt"))

        #expect(MatchStore(directory: directory).matches == [match])
    }

    @Test func aDeletedMatchIsGoneForGood() throws {
        let store = MatchStore(directory: directory)
        let kept = skyjoMatch(startedAt: Date(timeIntervalSince1970: 1_000))
        var deleted = skyjoMatch(startedAt: Date(timeIntervalSince1970: 2_000))
        deleted.end(at: Date(timeIntervalSince1970: 3_000))
        try store.save(kept)
        try store.save(deleted)

        try store.delete(deleted.id)

        #expect(store.matches == [kept])
        #expect(store.match(id: deleted.id) == nil)
        #expect(store.newestStartedFirst == [kept], "Its Players are no longer the last ones picked")
        #expect(MatchStore(directory: directory).matches == [kept])
    }

    @Test func deletingAMatchInProgressRemovesItsSnapshotFile() throws {
        let store = MatchStore(directory: directory)
        var match = skyjoMatch()
        match.setScore(4, for: match.teams[0].id, inRound: match.rounds[0].id)
        try store.save(match)

        try store.delete(match.id)

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files.isEmpty)
    }

    @Test func deletingAMatchWhoseSnapshotNeverReachedTheDiskStillRemovesIt() throws {
        // A file where the directory should be: the Match was never written.
        try Data().write(to: directory)
        let store = MatchStore(directory: directory)
        let match = skyjoMatch()
        #expect(throws: (any Error).self) { try store.save(match) }

        try store.delete(match.id)

        #expect(store.matches.isEmpty)
    }

    @Test func deletingAMatchTheStoreDoesNotHaveChangesNothing() throws {
        let store = MatchStore(directory: directory)
        let match = skyjoMatch()
        try store.save(match)

        try store.delete(UUID())

        #expect(store.matches == [match])
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
