import SwiftUI
import FinalScoreCore

extension Game.AccentToken {
    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        }
    }
}

extension Game {
    /// "2–8 players · Lowest wins"
    var summary: String {
        let players = playerCount.count == 1
            ? "\(playerCount.lowerBound) players"
            : "\(playerCount.lowerBound)–\(playerCount.upperBound) players"
        let winner = switch direction {
        case .highWins: "Highest wins"
        case .lowWins: "Lowest wins"
        }
        return "\(players) · \(winner)"
    }
}

/// A Game's symbol on its accent colour.
struct GameSymbol: View {
    let game: Game

    var body: some View {
        Image(systemName: game.symbol)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(game.accent.color.gradient, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}
