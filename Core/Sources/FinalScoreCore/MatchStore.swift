import Foundation

/// Every Match the user has started, kept as one JSON snapshot per Match in a
/// directory the app hands it (ADR-0001). Core owns the format and the
/// ordering; the app only decides where the directory lives.
///
/// There is no save action anywhere in the app: a Match is written the moment
/// it changes, so a Match killed mid-Round comes back mid-Round.
///
/// Not `Sendable` — a store belongs to whoever opened it and stays in that one
/// isolation domain, which for the app is the main actor.
public final class MatchStore {
    private let directory: URL
    private var byID: [Match.ID: Match]

    /// In progress above finished, each newest first — the order the Match list
    /// shows them in. A finished Match is as new as its end.
    public private(set) var matches: [Match]

    /// Opens the store on `directory`, creating it if this is the first launch,
    /// and reads back every snapshot in it.
    ///
    /// Nothing here throws: a directory that can't be created or read leaves an
    /// empty store rather than a launch that fails, and `save` reports the
    /// problem when there is finally something to lose.
    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        byID = Self.readSnapshots(in: directory)
        matches = Self.listOrder(byID.values)
    }

    public func match(id: Match.ID) -> Match? {
        byID[id]
    }

    /// Every Match, most recently started first, ended or not — what "the last
    /// Match" means when its Players are picked again, whatever order the list
    /// shows.
    public var newestStartedFirst: [Match] {
        // The id breaks ties, so Matches started in the same instant still come
        // back in one stable order.
        byID.values.sorted { ($0.startedAt, $0.id.uuidString) > ($1.startedAt, $1.id.uuidString) }
    }

    /// Writes the Match's snapshot, replacing the one already there.
    ///
    /// The Match joins `matches` either way: a throw says the snapshot didn't
    /// reach the disk, not that the Match is gone, so a caller mid-Match can
    /// keep scoring on it.
    ///
    /// The write is synchronous on purpose. It is a few kilobytes, and the
    /// whole promise here is that the Score the user just entered is on disk
    /// before the app can be killed — deferring it would trade that away.
    public func save(_ match: Match) throws {
        byID[match.id] = match
        matches = Self.listOrder(byID.values)
        let data = try JSONEncoder().encode(match)
        try data.write(to: url(for: match.id), options: .atomic)
    }

    private func url(for id: Match.ID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private static func listOrder(_ matches: some Collection<Match>) -> [Match] {
        // A finished Match counts as new from when it ended, so the one just
        // finished heads its section. The id breaks ties, so Matches from the
        // same instant still come back in one stable order.
        matches.sorted {
            if $0.isEnded != $1.isEnded { return !$0.isEnded }
            let (lhs, rhs) = ($0.endedAt ?? $0.startedAt, $1.endedAt ?? $1.startedAt)
            return (lhs, $0.id.uuidString) > (rhs, $1.id.uuidString)
        }
    }

    /// Reads what it can. A snapshot this version can't decode is skipped, so
    /// one unreadable file never costs the user the rest of their Matches.
    private static func readSnapshots(in directory: URL) -> [Match.ID: Match] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        let decoder = JSONDecoder()
        let matches = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Match? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Match.self, from: data)
            }
        return Dictionary(matches.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
