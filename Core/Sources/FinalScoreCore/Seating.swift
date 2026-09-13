import Foundation

/// Where the Players of a Game that tracks the Dealer sit around the table, and
/// which way the deal passes. Fixed at Match setup.
public struct Seating: Codable, Hashable, Sendable {
    /// Which way the deal passes around the table.
    public enum Rotation: String, Codable, Hashable, Sendable {
        /// On to the next seat in the Seating order.
        case clockwise
        /// Back to the previous seat in the Seating order.
        case counterclockwise
    }

    /// Every Player, in the order they sit going clockwise. The first seat
    /// deals the first Round.
    public let order: [Player.ID]
    public let rotation: Rotation

    public init(order: [Player.ID], rotation: Rotation) {
        self.order = order
        self.rotation = rotation
    }

    /// Who deals next after `dealer`: one seat along in the rotation, wrapping
    /// around the table. Nil if `dealer` has no seat.
    public func dealer(after dealer: Player.ID) -> Player.ID? {
        guard let seat = order.firstIndex(of: dealer) else { return nil }
        let step = rotation == .clockwise ? 1 : order.count - 1
        return order[(seat + step) % order.count]
    }
}
