import Foundation

/// A person at the table.
public struct Player: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// The unit a Score belongs to and a scorepad column represents — a Team of
/// one in individual Games (ADR-0003).
public struct Team: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var players: [Player]

    public init(id: UUID = UUID(), players: [Player]) {
        self.id = id
        self.players = players
    }

    public var name: String {
        players.map(\.name).joined(separator: " & ")
    }
}
