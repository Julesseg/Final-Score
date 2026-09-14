import Testing
import Foundation
@testable import FinalScoreCore

@Suite("A Team's accent")
struct TeamAccentTests {
    private func match(of game: Game, accent: Game.AccentToken, teams count: Int) -> Match {
        var game = game
        game.accent = accent
        return Match(game: game, teams: (0..<count).map { Team(players: [Player(name: "Player \($0)")]) })
    }

    @Test func theFirstTeamWearsTheGamesAccent() {
        let match = match(of: .skyjo, accent: .purple, teams: 3)
        #expect(match.accent(of: match.teams[0].id) == .purple)
    }

    @Test func everyTeamGetsItsOwnAccentUpToEightTeams() {
        for accent in Game.AccentToken.allCases {
            let match = match(of: .skyjo, accent: accent, teams: 8)
            let accents = match.teams.map { match.accent(of: $0.id) }
            #expect(Set(accents).count == 8, "Distinct Team accents on a \(accent) Game")
        }
    }

    @Test func fourTeamsSideBySideNeverWearAlikeHues() {
        let alike: [Set<Game.AccentToken>] = [[.blue, .indigo], [.red, .pink], [.green, .teal]]
        for accent in Game.AccentToken.allCases {
            let match = match(of: .skyjo, accent: accent, teams: 8)
            let accents = match.teams.map { match.accent(of: $0.id) }
            for start in accents.indices {
                let four = Set((0..<4).map { accents[(start + $0) % accents.count] })
                #expect(alike.allSatisfy { four.intersection($0).count < 2 }, "Columns \(start)… on a \(accent) Game")
            }
        }
    }

    @Test func aPaleAccentGivesWayToAReadableOneForTotals() {
        // Yellow, mint and cyan wash out as large text on a light background.
        for (pale, readable) in [(Game.AccentToken.yellow, Game.AccentToken.orange), (.mint, .green), (.cyan, .teal)] {
            let match = match(of: .skyjo, accent: pale, teams: 2)
            #expect(match.accent(of: match.teams[0].id) == readable)
            #expect(!match.teams.map { match.accent(of: $0.id) }.contains(pale))
        }
    }

    @Test func accentsRepeatInOrderPastEightTeams() {
        let match = match(of: .skyjo, accent: .red, teams: 10)
        #expect(match.accent(of: match.teams[8].id) == match.accent(of: match.teams[0].id))
        #expect(match.accent(of: match.teams[9].id) == match.accent(of: match.teams[1].id))
    }

    @Test func aTeamKeepsItsAccentAcrossARematch() {
        let finished = match(of: .skyjo, accent: .blue, teams: 4)
        let accents = finished.teams.map { finished.accent(of: $0.id) }
        let rematch = Match(game: finished.game, teams: finished.teams)
        #expect(rematch.teams.map { rematch.accent(of: $0.id) } == accents)
    }
}
