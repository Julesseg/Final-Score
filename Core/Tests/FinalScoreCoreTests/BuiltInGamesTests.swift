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
        #expect(skyjo.allowsNegative)
        #expect(skyjo.scorers == .everyone)
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
        #expect(scrabble.scorers == .everyone)
        #expect(!scrabble.tracksDealer)
        #expect(scrabble.isBuiltIn)
    }

    @Test func theCatalogueOffersTheFourIndividualRoundsGames() {
        #expect(Game.builtIns.map(\.name) == ["Tarot", "Rami", "Skyjo", "Scrabble"])
    }

    @Test(arguments: Game.builtIns)
    func everyBuiltInSurvivesAJSONRoundTrip(game: Game) throws {
        let data = try JSONEncoder().encode(game)
        #expect(try JSONDecoder().decode(Game.self, from: data) == game)
    }
}
