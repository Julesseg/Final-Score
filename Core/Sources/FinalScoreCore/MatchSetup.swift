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

    public var canStart: Bool {
        game.playerCount.contains(seating.count)
    }

    /// The Match these Players start, each as a Team of one in Seating order;
    /// nil until `canStart`. The Match takes its own copy of every Player, so
    /// later Roster edits never reach it. A Game that tracks the Dealer also
    /// fixes the Seating order and rotation, with the first seat dealing.
    public func makeMatch() -> Match? {
        guard canStart else { return nil }
        let teams = seating
            .compactMap { id in roster.first { $0.id == id } }
            .map { Team(players: [$0]) }
        return Match(
            game: game,
            teams: teams,
            seating: game.tracksDealer ? Seating(order: seating, rotation: rotation) : nil
        )
    }
}
