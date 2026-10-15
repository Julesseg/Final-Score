import Testing
@testable import FinalScoreCore

@Suite("Team labels")
struct TeamLabelsTests {
    private func labels(_ names: [String]) -> [String] {
        let teams = names.map { Team(players: [Player(name: $0)]) }
        let labels = TeamLabels.abbreviations(for: teams)
        return teams.map { labels[$0.id]! }
    }

    @Test func initialsUseEachWord() {
        #expect(labels(["Ada", "Grace Hopper", "Jean-Baptiste Dubois"]) == ["A", "GH", "JBD"])
    }

    @Test func similarNamesExpandOnlyTheCollidingLabels() {
        #expect(labels(["Ada", "Alex", "Grace"]) == ["Ad", "Al", "G"])
        #expect(labels(["Alan", "Albert"]) == ["Ala", "Alb"])
        #expect(labels(["Alexandria Montgomery", "Alexandra Martin"]) == ["AlMo", "AlMa"])
    }

    @Test func unresolvedPrefixesAndDuplicateNamesRemainDistinct() {
        #expect(labels(["Alice", "Alicia", "Alice"]) == ["Ali1", "Ali2", "Ali3"])
    }

    @Test func accentsAndCaseDoNotHideCollisions() {
        #expect(labels(["Émile", "emma"]) == ["Émi", "Emm"])
        #expect(labels(["Zoë", "李 明"]) == ["Z", "李明"])
    }

    @Test func emptyNamesAndLiteralNumericSuffixesCannotCollide() {
        let result = labels(["", " ", "Alice", "Alice", "Ali1"])
        #expect(Set(result).count == result.count)
        #expect(result.allSatisfy { !$0.isEmpty })
    }

    @Test func labelsDoNotChangeStoredNames() {
        let team = Team(players: [Player(name: "Alexandria Montgomery")])
        #expect(TeamLabels.abbreviations(for: [team])[team.id] == "AM")
        #expect(team.name == "Alexandria Montgomery")
    }
}
