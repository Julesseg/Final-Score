extension Match {
    /// The accents Teams wear. Alike hues (blue and indigo, red and pink, green
    /// and teal) sit four apart, so any four Teams side by side wear four
    /// different hues. Yellow, mint and cyan are left out: they wash out as
    /// large text on a light background.
    private static let teamAccents: [Game.AccentToken] = [.blue, .red, .green, .orange, .indigo, .pink, .teal, .purple]

    /// The accent a Team's column and Total wear. The first Team wears the
    /// Game's accent, or the nearest readable one, and the others follow it
    /// around the palette: distinct up to eight Teams, repeating in order past
    /// that. Stays with the Team when columns are swapped.
    public func accent(of team: Team.ID) -> Game.AccentToken {
        let accents = Self.teamAccents
        let first = accents.firstIndex(of: Self.readable(game.accent)) ?? 0
        let column = (teamAccentOrder ?? teams.map(\.id)).firstIndex(of: team) ?? 0
        return accents[(first + column) % accents.count]
    }

    private static func readable(_ accent: Game.AccentToken) -> Game.AccentToken {
        switch accent {
        case .yellow: .orange
        case .mint: .green
        case .cyan: .teal
        default: accent
        }
    }
}
