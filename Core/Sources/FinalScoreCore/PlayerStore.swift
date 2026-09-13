import Foundation

/// The user's Roster: every Player they have added, kept as one JSON file the
/// app hands it (ADR-0001).
///
/// A Match takes its own copy of each Player when it starts, so nothing done
/// to the Roster — a rename, a delete — ever reaches a Match already played.
///
/// Every change is written straight away. A write that throws still leaves the
/// change in `players`: the throw says the Roster didn't reach the disk, not
/// that the change didn't happen.
///
/// Not `Sendable`, for the same reason as `MatchStore`: it belongs to the
/// isolation domain that opened it.
public final class PlayerStore {
    private let file: URL

    /// Alphabetical — the order the Roster is listed in.
    public private(set) var players: [Player]

    /// Opens the Roster kept in `file`.
    ///
    /// The first time there is no Roster to open, it starts with the Players of
    /// `matches` — the ones played before there was a Roster — so their last
    /// Match can still be pre-selected. Pass them newest first, as
    /// `MatchStore.newestStartedFirst` lists them: a name played under more than
    /// once keeps its newest Player.
    ///
    /// Nothing here throws. A Roster that can't be read is moved aside, never
    /// overwritten, and a fresh one is started in its place.
    public init(file: URL, seedingFrom matches: [Match] = []) {
        self.file = file
        if let data = try? Data(contentsOf: file) {
            if let players = try? JSONDecoder().decode([Player].self, from: data) {
                self.players = Self.alphabetical(players)
                return
            }
            Self.setAside(file)
        }
        players = []
        for player in matches.flatMap(\.players) where self.player(named: player.name) == nil {
            players.append(player)
        }
        players = Self.alphabetical(players)
        try? write()
    }

    /// The Player going by `name`, ignoring case and surrounding spaces.
    public func player(named name: String) -> Player? {
        let name = Self.tidy(name)
        return players.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Adds a Player to the Roster, or finds the one already going by that
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

    /// Whether `rename` would take: the name isn't blank, and no one else on
    /// the Roster already goes by it — two Players with one name is the very
    /// duplicate renaming is there to fix.
    public func canRename(_ id: Player.ID, to name: String) -> Bool {
        guard !Self.tidy(name).isEmpty else { return false }
        return player(named: name).map { $0.id == id } ?? true
    }

    /// Corrects a Player's name, unless `canRename` says no. Matches already
    /// played keep the name they were played under.
    public func rename(_ id: Player.ID, to name: String) throws {
        guard canRename(id, to: name),
              let index = players.firstIndex(where: { $0.id == id })
        else { return }
        players[index].name = Self.tidy(name)
        players = Self.alphabetical(players)
        try write()
    }

    /// Takes a Player off the Roster. Matches they played keep them.
    public func delete(_ id: Player.ID) throws {
        players.removeAll { $0.id == id }
        try write()
    }

    private func write() throws {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(players).write(to: file, options: .atomic)
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

    /// Renames an unreadable Roster out of the way, so whatever it still holds
    /// can be recovered by hand rather than lost to the next write.
    private static func setAside(_ file: URL) {
        let name = "\(file.deletingPathExtension().lastPathComponent)-unreadable-\(UUID().uuidString)"
        let destination = file.deletingLastPathComponent()
            .appendingPathComponent(name)
            .appendingPathExtension(file.pathExtension)
        try? FileManager.default.moveItem(at: file, to: destination)
    }

    private static func tidy(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
