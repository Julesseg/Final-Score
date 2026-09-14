import Testing
import Foundation
@testable import FinalScoreCore

@Suite("The custom Game form")
struct GameDraftTests {
    @Test func aNewDraftIsAnIndividualRoundsGameThatIsNotBuiltIn() {
        let game = GameDraft().game

        #expect(game.structure == .rounds)
        #expect(game.teamPlay == .individual)
        #expect(game.playerCount == 2...8)
        #expect(game.endCondition == .none)
        #expect(game.quickScores.isEmpty)
        #expect(!game.isBuiltIn)
    }

    @Test func aDraftOfABuiltInGivesBackTheSameSettingsAsACustomGame() {
        var belote = Game.belote
        belote.isBuiltIn = false

        #expect(GameDraft(game: .belote).game == belote)
    }

    @Test func theNameIsTidiedAndABlankOneIsNotReadyToSave() {
        var draft = GameDraft()
        draft.name = "   "
        #expect(!draft.hasName)

        draft.name = "  Uno "
        #expect(draft.hasName)
        #expect(draft.game.name == "Uno")
    }

    // MARK: Players and Teams

    @Test func aTeamOfOneIsIndividualPlay() {
        var draft = GameDraft(game: .belote)
        draft.teamSize = 1

        #expect(draft.game.teamPlay == .individual)
    }

    @Test func choosingTeamsMovesThePlayerCountToWholeTeamsWithAtLeastTwoOfThem() {
        var draft = GameDraft()
        draft.minPlayers = 3
        draft.maxPlayers = 7

        draft.teamSize = 2

        #expect(draft.game.teamPlay == .teams(of: 2))
        #expect(draft.game.playerCount == 4...8)
    }

    @Test func largerTeamsRaiseTheFewestPlayersToTwoTeams() {
        var draft = GameDraft()
        draft.teamSize = 3

        #expect(draft.game.playerCount == 6...9)
    }

    @Test(arguments: [3, 5, 7])
    func thePlayerCountStaysWithinTheLimitWhateverTheTeamSize(size: Int) {
        var draft = GameDraft()
        draft.maxPlayers = GameDraft.playerLimit
        draft.teamSize = size

        #expect(draft.game.playerCount.upperBound <= GameDraft.playerLimit)
        #expect(draft.game.playerCount.upperBound.isMultiple(of: size))
        #expect(draft.game.playerCount.lowerBound == 2 * size)
    }

    @Test func thePlayerCountSnapsToWholeTeams() {
        var draft = GameDraft(game: .belote)

        draft.maxPlayers = 5
        #expect(draft.game.playerCount == 4...6)

        draft.minPlayers = 5
        #expect(draft.game.playerCount == 6...6)
    }

    @Test func raisingTheFewestPlayersPastTheMostRaisesTheMostToo() {
        var draft = GameDraft()
        draft.minPlayers = 10

        #expect(draft.game.playerCount == 10...10)
    }

    @Test func loweringTheMostPlayersPastTheFewestLowersTheFewestToo() {
        var draft = GameDraft()
        draft.minPlayers = 5
        draft.maxPlayers = 3

        #expect(draft.game.playerCount == 3...3)
    }

    @Test func thePlayerCountNeverDropsBelowTwoNorPassesTheLimit() {
        var draft = GameDraft()
        draft.minPlayers = 0
        draft.maxPlayers = 100

        #expect(draft.game.playerCount == 2...GameDraft.playerLimit)
    }

    @Test func theTeamSizeStaysBetweenOneAndHalfTheLimit() {
        var draft = GameDraft()
        draft.teamSize = 0
        #expect(draft.teamSize == 1)

        draft.teamSize = 100
        #expect(draft.teamSize == GameDraft.playerLimit / 2)
    }

    // MARK: Structure

    @Test func aTallyHasNoDealerNoRoundCountAndEveryoneScores() {
        var draft = GameDraft(game: .coinche)
        draft.endCondition = .roundCount(10)

        draft.structure = .tally

        let game = draft.game
        #expect(!game.tracksDealer, "A Tally has no Rounds to deal")
        #expect(game.scorers == .everyone, "A Tally has no Round for one Team to score")
        #expect(game.endCondition == .none, "A Tally never reaches a Round count")
    }

    @Test func aTallyKeepsATargetTotal() {
        var draft = GameDraft(game: .skyjo)
        draft.structure = .tally

        #expect(draft.game.endCondition == .targetTotal(100))
    }

    @Test func aTallyRefusesRoundSettings() {
        var draft = GameDraft()
        draft.structure = .tally

        draft.tracksDealer = true
        draft.scorers = .oneTeamPerRound
        draft.endCondition = .roundCount(5)

        #expect(!draft.game.tracksDealer)
        #expect(draft.game.scorers == .everyone)
        #expect(draft.game.endCondition == .none)
    }

    @Test func anEndConditionCountsAtLeastOne() {
        var draft = GameDraft()

        draft.endCondition = .targetTotal(0)
        #expect(draft.game.endCondition == .targetTotal(1))

        draft.endCondition = .roundCount(-3)
        #expect(draft.game.endCondition == .roundCount(1))
    }

    // MARK: Quick scores

    @Test func quickScoresAreAddedInAscendingOrderWithoutRepeats() {
        var draft = GameDraft()

        draft.addQuickScore(50)
        draft.addQuickScore(20)
        draft.addQuickScore(50)

        #expect(draft.game.quickScores == [20, 50])
    }

    @Test func aQuickScoreOfZeroAddsNothing() {
        var draft = GameDraft()
        draft.addQuickScore(0)

        #expect(draft.game.quickScores.isEmpty, "An untouched Score already records 0")
    }

    @Test func aNegativeQuickScoreNeedsNegativeScoresAllowed() {
        var draft = GameDraft(game: .belote)
        draft.addQuickScore(-10)
        #expect(draft.game.quickScores.isEmpty)

        draft.allowsNegative = true
        draft.addQuickScore(-10)
        #expect(draft.game.quickScores == [-10])
    }

    @Test func disallowingNegativeScoresDropsTheNegativeQuickScores() {
        var draft = GameDraft()
        draft.addQuickScore(-10)
        draft.addQuickScore(10)

        draft.allowsNegative = false

        #expect(draft.game.quickScores == [10])
    }

    @Test func quickScoresAreRemovedByPosition() {
        var draft = GameDraft(game: .tarot)

        draft.removeQuickScores(atOffsets: [0, 2])

        #expect(draft.game.quickScores == [50, 150])
    }

    @Test func aDraftOpenedOnAnIncoherentGameMakesItCoherent() {
        var broken = Game.points
        broken.teamPlay = .teams(of: 2)
        broken.playerCount = 3...5
        broken.tracksDealer = true
        broken.quickScores = [5, -5, 0, 5]
        broken.allowsNegative = false

        let game = GameDraft(game: broken).game

        #expect(game.playerCount == 4...6)
        #expect(!game.tracksDealer)
        #expect(game.quickScores == [5])
    }
}
