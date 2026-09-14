import Foundation

/// A Game the user authored, with an identity that survives renaming it.
public struct CustomGame: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var game: Game

    public init(id: UUID = UUID(), game: Game) {
        self.id = id
        self.game = game
    }
}

/// The Games the user has authored, kept as one JSON file the app hands it
/// (ADR-0001). Built-in Games never enter it: they are read-only, and copied
/// here by `duplicate` to be edited.
///
/// A Match takes its own copy of its Game when it starts, so editing or
/// deleting a custom Game never reaches a Match already played.
///
/// Every change is written straight away. A write that throws still leaves the
/// change in `customGames`, as in `PlayerStore`.
///
/// Not `Sendable`, for the same reason as `MatchStore`: it belongs to the
/// isolation domain that opened it.
public final class GameStore {
    private let file: URL

    /// In the order they were created — the order the Game picker lists them
    /// in, below the built-ins.
    public private(set) var customGames: [CustomGame]

    /// Every Game to pick from: the built-ins, then the custom Games.
    public var games: [Game] {
        Game.builtIns + customGames.map(\.game)
    }

    /// Opens the custom Games kept in `file`.
    ///
    /// Nothing here throws. A file that can't be read is moved aside, never
    /// overwritten, and the store starts empty in its place.
    public init(file: URL) {
        self.file = file
        guard let data = try? Data(contentsOf: file) else {
            customGames = []
            return
        }
        if let games = try? JSONDecoder().decode([CustomGame].self, from: data) {
            customGames = games
        } else {
            Self.setAside(file)
            customGames = []
        }
    }

    /// Whether `draft` has a name no other Game goes by, ignoring case — two
    /// Games under one name couldn't be told apart in the picker or on a
    /// Match. The Game being edited, `replacing`, may keep its own.
    public func canSave(_ draft: GameDraft, replacing id: CustomGame.ID? = nil) -> Bool {
        let name = draft.game.name
        guard !name.isEmpty else { return false }
        let others = Game.builtIns + customGames.filter { $0.id != id }.map(\.game)
        return !others.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Saves `draft` as a new custom Game, listed last; nil unless `canSave`.
    public func add(_ draft: GameDraft) throws -> CustomGame? {
        guard canSave(draft) else { return nil }
        let custom = CustomGame(game: draft.game)
        customGames.append(custom)
        try write()
        return custom
    }

    /// Replaces a custom Game's settings, keeping its identity and its place,
    /// unless `canSave` says no.
    public func update(_ id: CustomGame.ID, to draft: GameDraft) throws {
        guard canSave(draft, replacing: id),
              let index = customGames.firstIndex(where: { $0.id == id })
        else { return }
        customGames[index].game = draft.game
        try write()
    }

    public func delete(_ id: CustomGame.ID) throws {
        customGames.removeAll { $0.id == id }
        try write()
    }

    /// A draft of `game`'s settings under a name no Game goes by yet — "Belote
    /// copy", then "Belote copy 2". Nothing is saved until the draft is added.
    public func duplicate(_ game: Game) -> GameDraft {
        var draft = GameDraft(game: game)
        let base = "\(draft.game.name) copy"
        draft.name = base
        var number = 2
        while !canSave(draft) {
            draft.name = "\(base) \(number)"
            number += 1
        }
        return draft
    }

    private func write() throws {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(customGames).write(to: file, options: .atomic)
    }

    /// Renames an unreadable file out of the way, so whatever it still holds
    /// can be recovered by hand rather than lost to the next write.
    private static func setAside(_ file: URL) {
        let name = "\(file.deletingPathExtension().lastPathComponent)-unreadable-\(UUID().uuidString)"
        let destination = file.deletingLastPathComponent()
            .appendingPathComponent(name)
            .appendingPathExtension(file.pathExtension)
        try? FileManager.default.moveItem(at: file, to: destination)
    }
}
