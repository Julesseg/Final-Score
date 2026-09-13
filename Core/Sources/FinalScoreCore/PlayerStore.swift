import Foundation

/// The user's roster: every Player they have ever set a Match up with, kept as
/// one JSON file the app hands it (ADR-0001).
///
/// A Match takes its own copy of each Player when it starts, so nothing done
/// to the roster — a rename, a delete — ever reaches a Match already played.
///
/// Every change is written straight away. A write that throws still leaves the
/// change in `players`: the throw says the roster didn't reach the disk, not
/// that the change didn't happen.
///
/// Not `Sendable`, for the same reason as `MatchStore`: it belongs to the
/// isolation domain that opened it.
public final class PlayerStore {
    private let file: URL

    /// Alphabetical — the order the roster is listed in.
    public private(set) var players: [Player]

    /// Opens the roster kept in `file`. A file that is missing or can't be read
    /// leaves an empty roster rather than a launch that fails.
    public init(file: URL) {
        self.file = file
        players = Self.alphabetical((try? Data(contentsOf: file))
            .flatMap { try? JSONDecoder().decode([Player].self, from: $0) } ?? [])
    }

    /// Adds a Player to the roster, or finds the one already going by that
    /// name, ignoring case — typing "ada" for Ada is picking Ada, not meeting
    /// someone new. A blank name adds nobody.
    public func add(named name: String) throws -> Player? {
        let name = Self.tidy(name)
        guard !name.isEmpty else { return nil }
        if let existing = player(named: name) {
            return existing
        }
        let player = Player(name: name)
        players = Self.alphabetical(players + [player])
        try write()
        return player
    }

    /// Corrects a Player's name. Matches already played keep the name they
    /// were played under.
    public func rename(_ id: Player.ID, to name: String) throws {
        let name = Self.tidy(name)
        guard !name.isEmpty, let index = players.firstIndex(where: { $0.id == id }) else { return }
        players[index].name = name
        players = Self.alphabetical(players)
        try write()
    }

    /// Takes a Player off the roster. Matches they played keep them.
    public func delete(_ id: Player.ID) throws {
        players.removeAll { $0.id == id }
        try write()
    }

    private func player(named name: String) -> Player? {
        players.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private static func alphabetical(_ players: [Player]) -> [Player] {
        // The id breaks ties, so two Players with one name keep one stable order.
        players.sorted {
            switch $0.name.localizedStandardCompare($1.name) {
            case .orderedSame: $0.id.uuidString < $1.id.uuidString
            case let order: order == .orderedAscending
            }
        }
    }

    private static func tidy(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func write() throws {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(players).write(to: file, options: .atomic)
    }
}
