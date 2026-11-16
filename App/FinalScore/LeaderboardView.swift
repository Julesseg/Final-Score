import SwiftUI
import FinalScoreCore

struct LeaderboardView: View {
    let match: Match
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(match.leaderboard.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 16) {
                            Text("\(entry.rank)")
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 28)
                            Text(entry.team.name)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(entry.total)")
                                .font(.title2.bold().monospacedDigit())
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
