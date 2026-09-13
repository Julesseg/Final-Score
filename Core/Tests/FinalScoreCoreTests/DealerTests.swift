import Testing
import Foundation
@testable import FinalScoreCore

@Suite("Tracking the Dealer")
struct DealerTests {
    private let ada = Player(name: "Ada")
    private let grace = Player(name: "Grace")
    private let linus = Player(name: "Linus")

    /// A Skyjo Match with Ada, Grace and Linus seated clockwise in that order.
    private func skyjoMatch(rotation: Seating.Rotation) -> Match {
        let players = [ada, grace, linus]
        return Match(
            game: .skyjo,
            teams: players.map { Team(players: [$0]) },
            seating: Seating(order: players.map(\.id), rotation: rotation)
        )
    }

    /// Scores the Round in play so a new one can start, then starts it.
    private func playRound(of match: inout Match) {
        match.setScore(1, for: match.teams[0].id, inRound: match.rounds.last!.id)
        match.startNewRound()
    }

    @Test func clockwiseTheDealerAdvancesOneSeatAndWrapsBackToTheFirst() {
        let seating = Seating(order: [ada.id, grace.id, linus.id], rotation: .clockwise)

        #expect(seating.dealer(after: ada.id) == grace.id)
        #expect(seating.dealer(after: grace.id) == linus.id)
        #expect(seating.dealer(after: linus.id) == ada.id)
    }

    @Test func counterclockwiseTheDealerGoesBackOneSeatAndWrapsToTheLast() {
        let seating = Seating(order: [ada.id, grace.id, linus.id], rotation: .counterclockwise)

        #expect(seating.dealer(after: ada.id) == linus.id)
        #expect(seating.dealer(after: linus.id) == grace.id)
        #expect(seating.dealer(after: grace.id) == ada.id)
    }

    @Test func aDealerWithNoSeatHasNoOneToPassTheDealTo() {
        let seating = Seating(order: [ada.id, grace.id], rotation: .clockwise)

        #expect(seating.dealer(after: linus.id) == nil)
    }

    @Test func theFirstSeatDealsTheFirstRound() {
        #expect(skyjoMatch(rotation: .clockwise).rounds[0].dealer == ada.id)
        #expect(skyjoMatch(rotation: .counterclockwise).rounds[0].dealer == ada.id)
    }

    @Test func eachNewRoundRecordsTheNextDealerInTheMatchsRotation() {
        var clockwise = skyjoMatch(rotation: .clockwise)
        var counterclockwise = skyjoMatch(rotation: .counterclockwise)

        for _ in 1...3 {
            playRound(of: &clockwise)
            playRound(of: &counterclockwise)
        }

        #expect(clockwise.rounds.map(\.dealer) == [ada.id, grace.id, linus.id, ada.id])
        #expect(counterclockwise.rounds.map(\.dealer) == [ada.id, linus.id, grace.id, ada.id])
    }

    @Test func advancingContinuesFromAReassignedDealer() {
        var match = skyjoMatch(rotation: .clockwise)
        playRound(of: &match)

        // A misdeal: Linus deals Round 2 instead of Grace.
        match.setDealer(linus.id, inRound: match.rounds[1].id)
        playRound(of: &match)

        #expect(match.rounds.map(\.dealer) == [ada.id, linus.id, ada.id])
    }

    @Test func reassigningAnEarlierRoundLeavesTheRoundsAfterItAlone() {
        var match = skyjoMatch(rotation: .counterclockwise)
        playRound(of: &match)
        playRound(of: &match)

        match.setDealer(grace.id, inRound: match.rounds[0].id)

        #expect(match.rounds.map(\.dealer) == [grace.id, linus.id, grace.id])
    }

    @Test func onlyAPlayerInTheMatchCanBeMadeDealer() {
        var match = skyjoMatch(rotation: .clockwise)

        match.setDealer(Player(name: "Marie").id, inRound: match.rounds[0].id)

        #expect(match.rounds[0].dealer == ada.id)
    }

    @Test func aGameThatDoesNotTrackTheDealerHasNone() {
        var match = Match(game: .scrabble, teams: [ada, grace].map { Team(players: [$0]) })
        match.setDealer(grace.id, inRound: match.rounds[0].id)
        playRound(of: &match)

        #expect(match.seating == nil)
        #expect(match.rounds.map(\.dealer) == [nil, nil])
    }

    @Test func theScorepadReassignsTheDealerWithoutMovingTheKeypad() {
        var scorepad = Scorepad(match: skyjoMatch(rotation: .clockwise))
        let selection = scorepad.selection

        scorepad.setDealer(grace.id, inRound: scorepad.match.rounds[0].id)

        #expect(scorepad.match.rounds[0].dealer == grace.id)
        #expect(scorepad.selection == selection)
    }

    @Test func theScorepadsNewRoundGoesToTheNextDealer() {
        var scorepad = Scorepad(match: skyjoMatch(rotation: .clockwise))
        scorepad.type(4)

        scorepad.startNewRound()

        #expect(scorepad.match.rounds.map(\.dealer) == [ada.id, grace.id])
    }
}
