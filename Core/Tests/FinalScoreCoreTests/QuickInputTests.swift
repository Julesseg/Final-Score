import Foundation
import Testing
@testable import FinalScoreCore

@Suite("Quick inputs")
struct QuickInputTests {
    @Test func pointsStepIsOptionalAndPositive() {
        var draft = GameDraft()
        #expect(draft.pointsStep == nil)
        #expect(draft.game.adjustmentStep == 1)
        draft.pointsStep = 5
        #expect(draft.game.adjustmentStep == 5)
        #expect(GameDraft(game: draft.game).pointsStep == 5)
        draft.pointsStep = 0
        #expect(draft.pointsStep == 1)
        draft.pointsStep = -5
        #expect(draft.pointsStep == 1)
        draft.pointsStep = nil
        #expect(draft.game.adjustmentStep == 1)
    }

    @Test func savedGamesAndMatchesKeepTheirStepAndOlderDataDefaultsToOne() throws {
        var game = Game.tarot
        game.pointsStep = 5
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        #expect(try decoder.decode(Game.self, from: encoder.encode(game)).pointsStep == 5)
        let match = Match(game: game, teams: [Team(players: [Player(name: "Ada")])])
        #expect(try decoder.decode(Match.self, from: encoder.encode(match)).game.adjustmentStep == 5)

        var oldGame = try #require(JSONSerialization.jsonObject(with: encoder.encode(game)) as? [String: Any])
        oldGame.removeValue(forKey: "pointsStep")
        let decoded = try decoder.decode(Game.self, from: JSONSerialization.data(withJSONObject: oldGame))
        #expect(decoded.pointsStep == nil)
        #expect(decoded.adjustmentStep == 1)
    }

    @Test func stepAdjustmentsRespectRoundAndTallyNegativeRules() {
        var game = Game.belote
        game.pointsStep = 5
        let teams = [Team(players: [Player(name: "Ada")])]
        var scorepad = Scorepad(match: Match(game: game, teams: teams))
        scorepad.adjust(by: -game.adjustmentStep)
        #expect(scorepad.match.total(for: teams[0].id) == 0)
        scorepad.adjust(by: game.adjustmentStep)
        #expect(scorepad.match.total(for: teams[0].id) == 5)
        scorepad.type(3)
        #expect(scorepad.match.total(for: teams[0].id) == 3)

        game.structure = .tally
        var tally = TallyPad(match: Match(game: game, teams: teams))
        tally.select(.newScore(team: teams[0].id))
        tally.adjust(by: game.adjustmentStep)
        tally.adjust(by: -game.adjustmentStep)
        tally.adjust(by: -game.adjustmentStep)
        #expect(tally.match.total(for: teams[0].id) == 0)
    }
}
