import Foundation

extension Match {
    public struct LeaderboardEntry: Identifiable, Equatable, Sendable {
        public let team: Team
        public let total: Int
        public let rank: Int
        public var id: Team.ID { team.id }
    }

    public var leaderboard: [LeaderboardEntry] {
        let ordered = teams.enumerated().map { index, team in
            (index: index, team: team, total: total(for: team.id))
        }.sorted { left, right in
            if left.total == right.total { return left.index < right.index }
            return game.direction == .highWins ? left.total > right.total : left.total < right.total
        }
        var rank = 1
        return ordered.enumerated().map { index, entry in
            if index > 0, entry.total != ordered[index - 1].total { rank = index + 1 }
            return LeaderboardEntry(team: entry.team, total: entry.total, rank: rank)
        }
    }
}
