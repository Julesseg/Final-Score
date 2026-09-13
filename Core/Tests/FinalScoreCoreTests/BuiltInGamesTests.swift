import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Built-in Games")
struct BuiltInGamesTests {
    @Test func skyjoEndsAtOneHundredAndTheLowestTotalWins() {
        let skyjo = Game.skyjo
        #expect(skyjo.name == "Skyjo")
        #expect(skyjo.structure == .rounds)
        #expect(skyjo.teamPlay == .individual)
        #expect(skyjo.playerCount == 2...8)
        #expect(skyjo.direction == .lowWins)
        #expect(skyjo.endCondition == .targetTotal(100))
        #expect(skyjo.quickScores.isEmpty, "A Skyjo Round can land anywhere from -24 up")
        #expect(skyjo.allowsNegative)
        #expect(skyjo.scorers == .everyone)
        #expect(skyjo.tracksDealer)
        #expect(skyjo.isBuiltIn)
    }

    @Test func tarotIsPlayedByThreeToFiveWithNegativeScoresAndNoFixedEnd() {
        let tarot = Game.tarot
        #expect(tarot.name == "Tarot")
        #expect(tarot.structure == .rounds)
        #expect(tarot.teamPlay == .individual)
        #expect(tarot.playerCount == 3...5)
        #expect(tarot.direction == .highWins)
        #expect(tarot.endCondition == .none)
        #expect(tarot.quickScores == [25, 50, 100, 150], "Each contract's worth against one defender")
        #expect(tarot.allowsNegative)
        #expect(tarot.scorers == .everyone)
        #expect(tarot.tracksDealer)
        #expect(tarot.isBuiltIn)
    }

    @Test func ramiCountsPenaltyPointsSoTheLowestTotalWins() {
        let rami = Game.rami
        #expect(rami.name == "Rami")
        #expect(rami.structure == .rounds)
        #expect(rami.teamPlay == .individual)
        #expect(rami.playerCount == 2...6)
        #expect(rami.direction == .lowWins)
        #expect(rami.endCondition == .targetTotal(100))
        #expect(rami.quickScores.isEmpty, "Penalties are whatever is left in hand")
        #expect(rami.allowsNegative)
        #expect(rami.scorers == .everyone)
        #expect(rami.tracksDealer)
        #expect(rami.isBuiltIn)
    }

    @Test func scrabbleIsPlayedByTwoToFourWithNoDealer() {
        let scrabble = Game.scrabble
        #expect(scrabble.name == "Scrabble")
        #expect(scrabble.structure == .rounds)
        #expect(scrabble.teamPlay == .individual)
        #expect(scrabble.playerCount == 2...4)
        #expect(scrabble.direction == .highWins)
        #expect(scrabble.endCondition == .none)
        #expect(scrabble.quickScores.isEmpty, "Word scores spread too widely to pick from")
        #expect(scrabble.allowsNegative, "Unplayed tiles are deducted at the end")
        #expect(scrabble.scorers == .everyone)
        #expect(!scrabble.tracksDealer)
        #expect(scrabble.isBuiltIn)
    }

    @Test func beloteIsPlayedInTeamsOfTwoToFiveHundredAndOne() {
        let belote = Game.belote
        #expect(belote.name == "Belote")
        #expect(belote.structure == .rounds)
        #expect(belote.teamPlay == .teams(of: 2), "The first Game whose Teams hold more than one Player")
        #expect(belote.playerCount == 4...4)
        #expect(belote.direction == .highWins)
        #expect(belote.endCondition == .targetTotal(501))
        #expect(belote.quickScores.isEmpty, "A Round's points are counted off the cards, anywhere from 0 to 162")
        #expect(!belote.allowsNegative, "A Belote Team never scores below 0")
        #expect(belote.scorers == .everyone, "Both Teams score the points they took")
        #expect(belote.tracksDealer)
        #expect(belote.isBuiltIn)
    }

    @Test func pointsIsTheGenericTallyForAnyBoardGame() {
        let points = Game.points
        #expect(points.name == "Points")
        #expect(points.structure == .tally)
        #expect(points.teamPlay == .individual)
        #expect(points.playerCount == 2...8)
        #expect(points.direction == .highWins)
        #expect(points.endCondition == .none, "A generic counter has no target of its own")
        #expect(points.quickScores.isEmpty)
        #expect(points.allowsNegative, "Points are taken away as well as added")
        #expect(points.scorers == .everyone)
        #expect(!points.tracksDealer, "A Tally has no Rounds to deal")
        #expect(points.isBuiltIn)
    }

    @Test func theCatalogueOffersTheFiveRoundsGamesThenPoints() {
        #expect(Game.builtIns.map(\.name) == ["Belote", "Tarot", "Rami", "Skyjo", "Scrabble", "Points"])
    }

    @Test(arguments: Game.builtIns)
    func everyBuiltInHasAnIdentity(game: Game) {
        #expect(game.scorers == .everyone)
        #expect(!game.symbol.isEmpty)
        #expect(game.playerCount.lowerBound >= 2)
        #expect(game.isBuiltIn)
    }

    @Test(arguments: Game.builtIns)
    func aTeamGameOnlySeatsWholeTeams(game: Game) {
        guard case .teams(let size) = game.teamPlay else { return }
        #expect(size >= 2, "A Team of one is an individual Game")
        #expect(
            game.playerCount.allSatisfy { $0.isMultiple(of: size) },
            "Every allowed Player count has to divide into whole Teams of \(size)"
        )
    }

    @Test func everyBuiltInHasItsOwnSymbolAndAccent() {
        #expect(Set(Game.builtIns.map(\.symbol)).count == Game.builtIns.count)
        #expect(Set(Game.builtIns.map(\.accent)).count == Game.builtIns.count)
    }

    @Test(arguments: Game.builtIns)
    func everyBuiltInSurvivesAJSONRoundTrip(game: Game) throws {
        let data = try JSONEncoder().encode(game)
        #expect(try JSONDecoder().decode(Game.self, from: data) == game)
    }
}
