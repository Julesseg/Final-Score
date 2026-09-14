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
    /// "2–8 players · Lowest wins", or "4 players · Teams of 2 · Highest wins"
    var summary: String {
        let players = playerCount.count == 1
            ? "\(playerCount.lowerBound) players"
            : "\(playerCount.lowerBound)–\(playerCount.upperBound) players"
        let teams = teamPlay == .individual ? nil : "Teams of \(teamPlay.size)"
        let winner = switch direction {
        case .highWins: "Highest wins"
        case .lowWins: "Lowest wins"
        }
        return [players, teams, winner].compactMap { $0 }.joined(separator: " · ")
    }
}

extension Match {
    /// What a Team's name, Total and crown wear.
    func style(of team: Team.ID) -> TeamStyle {
        TeamStyle(color: accent(of: team).color)
    }

    /// "Grace wins", "Ada and Linus tie", or nil while in play or without a Score.
    var outcomeText: String? {
        outcome.map { $0.text(wins: "wins", tie: "tie") }
    }

    /// "Grace would win", or nil before the first Score.
    var standingText: String? {
        standing.map { $0.text(wins: "would win", tie: "would tie") }
    }

    /// The Match list's line about a Match: "Round 7 · Marie leads 340" or
    /// "Round 7 · Ada and Marie tied on 340" while in play, "Marie won · 501"
    /// or "Ada and Marie tied · 501" once ended.
    var statusText: String {
        if isEnded {
            guard let outcome, let leadingTotal else { return "Ended before any Score" }
            return "\(outcome.text(wins: "won", tie: "tied")) · \(leadingTotal)"
        }
        var parts: [String] = []
        if game.structure == .rounds {
            parts.append("Round \(rounds.count)")
        }
        if let standing, let leadingTotal {
            parts.append("\(standing.text(wins: "leads", tie: "tied on")) \(leadingTotal)")
        }
        return parts.isEmpty ? "No Scores yet" : parts.joined(separator: " · ")
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

/// A Team's colour, deepened on a light background so that even a green or
/// orange Total reads from across the table. Dark mode takes it as it is.
struct TeamStyle: ShapeStyle {
    let color: Color

    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .light ? color.mix(with: .black, by: 0.2) : color
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

/// The Game's symbol and name, in place of a plain title over a Match.
struct GameTitle: ToolbarContent {
    let game: Game

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Label {
                Text(game.name).font(.headline)
            } icon: {
                Image(systemName: game.symbol)
                    .foregroundStyle(game.accent.color)
            }
            .labelStyle(.titleAndIcon)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }
}
