import SwiftUI
import FinalScoreCore

struct LeaderboardView: View {
    let match: Match
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let leaders = Set(match.leaders.map(\.id))
        NavigationStack {
            List {
                Section {
                    ForEach(Array(match.leaderboard.enumerated()), id: \.element.id) { index, entry in
                        let style = match.style(of: entry.id)
                        HStack(spacing: 16) {
                            Text("\(entry.rank)")
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 28)
                            HStack(spacing: 6) {
                                Image(systemName: match.totalsArePartial ? "crown" : "crown.fill")
                                    .font(.caption)
                                    .foregroundStyle(style)
                                    .opacity(leaders.contains(entry.id) ? 1 : 0)
                                    .accessibilityHidden(true)
                                Text(entry.team.name)
                                    .font(.headline)
                                    .foregroundStyle(style)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(entry.total)")
                                .font(.title2.bold().monospacedDigit())
                                .foregroundStyle(style)
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Rank \(entry.rank), \(entry.team.name), \(entry.total) points")
                        .accessibilityIdentifier("leaderboardRow.\(index)")
                    }
                } header: {
                    Text(match.game.direction == .highWins ? "Highest Total wins" : "Lowest Total wins")
                } footer: {
                    if match.totalsArePartial {
                        Text("Includes scores entered so far. Some Teams have not scored this Round yet.")
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("closeLeaderboardButton")
                }
            }
        }
        .tint(match.game.accent.color)
    }
}
