import Foundation

/// The New Match form: a Game, the Players from the Roster who will play it,
/// and — for a Game that tracks the Dealer — which way the deal passes.
public struct MatchSetup: Sendable {
    public let game: Game
    /// Everyone who could be picked. Handing it a roster that has lost a
    /// picked Player gives up that Player's seat.
    public var roster: [Player] {
        didSet {
            seating.removeAll { id in !roster.contains { $0.id == id } }
        }
    }
    /// The picked Players, in Seating order.
    public private(set) var seating: [Player.ID]
    /// Which way the deal passes. Only a Game that tracks the Dealer uses it.
    public var rotation: Seating.Rotation

    /// Opens with the `previous` Match's Players already picked, in the same
    /// Seating order, so a repeat game night is one tap. Anyone since deleted
    /// from the roster is left out, and so is anyone past the most Players
    /// this Game allows. The deal passes the way it did last time, or clockwise.
    public init(game: Game, roster: [Player], previous: Match?) {
        self.game = game
        self.roster = roster
        seating = Array(
            (previous?.players ?? [])
                .filter { player in roster.contains { $0.id == player.id } }
                .map(\.id)
                .prefix(game.playerCount.upperBound)
        )
        rotation = previous?.seating?.rotation ?? .clockwise
    }

    /// The Player's 1-based seat, or nil while they aren't picked.
    public func seat(of player: Player.ID) -> Int? {
        seating.firstIndex(of: player).map { $0 + 1 }
    }

    /// Whether tapping the Player would do anything: a picked Player can always
    /// be unpicked, anyone else only while there is a seat left.
    public func canPick(_ player: Player.ID) -> Bool {
        seating.contains(player) || seating.count < game.playerCount.upperBound
    }

    /// Picks the Player into the next seat, or unpicks them if already picked.
    public mutating func toggle(_ player: Player.ID) {
        if let seat = seating.firstIndex(of: player) {
            seating.remove(at: seat)
        } else {
            pick(player)
        }
    }

    /// Picks the Player into the next seat while one is left. A Player already
    /// picked keeps the seat they have.
    public mutating func pick(_ player: Player.ID) {
        guard !seating.contains(player), canPick(player) else { return }
        seating.append(player)
    }

    /// The Players this one could trade seats with to change the Teams: everyone
    /// else picked, in Seating order, less their own Team — trading seats within
    /// a Team leaves that same Team behind. Empty while they have no seat, and
    /// in an individual Game simply everyone else, each seat being its own Team.
    public func swapCandidates(for player: Player.ID) -> [Player] {
        guard seating.contains(player) else { return [] }
        let sameTeam = Set(teams.first { $0.contains { $0.id == player } }?.map(\.id) ?? [])
        return seating
            .filter { !sameTeam.contains($0) }
            .compactMap { id in roster.first { $0.id == id } }
    }

    /// Swaps two picked Players' seats. In a Team Game that is how a Team is
    /// changed, because who plays with whom follows from where people sit.
    /// Does nothing unless both are picked.
    public mutating func swapSeats(_ one: Player.ID, _ other: Player.ID) {
        guard let oneSeat = seating.firstIndex(of: one),
              let otherSeat = seating.firstIndex(of: other)
        else { return }
        seating.swapAt(oneSeat, otherSeat)
    }

    /// The Teams the picked Players would start as, in scorepad column order.
    /// Players rather than `Team`s, because a `Team` minted fresh on every read
    /// would hand out a new identity each time and break anything tracking it;
    /// `makeMatch` is where the Teams get one, once.
    /// Seats alternate between Teams, so partners sit across the table from
    /// each other rather than side by side; an individual Game gives everyone a
    /// Team of their own. Shown as the Teams form, so a Team short of a Player
    /// is listed short rather than hidden.
    public var teams: [[Player]] {
        let size = game.teamPlay.size
        let players = seating.compactMap { id in roster.first { $0.id == id } }
        let teamCount = (players.count + size - 1) / size
        guard teamCount > 0 else { return [] }
        return (0..<teamCount).map { team in
            stride(from: team, to: players.count, by: teamCount).map { players[$0] }
        }
    }

    /// Every seat is taken by a Player the Game allows, and no Team is left
    /// half composed.
    public var canStart: Bool {
        game.playerCount.contains(seating.count)
            && seating.count.isMultiple(of: game.teamPlay.size)
    }

    /// The Match these Players start, in the Teams `teams` composed; nil until
    /// `canStart`. The Match takes its own copy of every Player, so later Roster
    /// edits never reach it. A Game that tracks the Dealer also fixes the
    /// Seating order and rotation, with the first seat dealing.
    public func makeMatch() -> Match? {
        guard canStart else { return nil }
        return Match(
            game: game,
            teams: teams.map { Team(players: $0) },
            seating: game.tracksDealer ? Seating(order: seating, rotation: rotation) : nil
        )
    }
}
