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

extension Match {
    /// "Grace wins", "Ada and Linus tie", or nil while in play or without a Score.
    var outcomeText: String? {
        outcome.map { $0.text(wins: "wins", tie: "tie") }
    }

    /// "Grace would win", or nil before the first Score.
    var standingText: String? {
        standing.map { $0.text(wins: "would win", tie: "would tie") }
    }

    /// What the End condition says, once reached: "A Total reached 100".
    var endConditionText: String? {
        switch game.endCondition {
        case .none: nil
        case .targetTotal(let target): "A Total reached \(target)"
        case .roundCount(let count): "\(count) Rounds played"
        }
    }
}

private extension Match.Outcome {
    func text(wins: String, tie: String) -> String {
        switch self {
        case .won(let team): "\(team.name) \(wins)"
        case .tied(let teams): "\(teams.map(\.name).formatted(.list(type: .and))) \(tie)"
        }
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
