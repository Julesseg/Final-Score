import Foundation

public enum TeamLabels {
    public static func abbreviations(for teams: [Team]) -> [Team.ID: String] {
        let words = teams.map { team in
            team.name.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        }
        var lengths = Array(repeating: 1, count: teams.count)
        var labels = words.map { abbreviation($0, length: 1) }

        for _ in 0..<2 {
            let collisions = groups(labels).values.filter { $0.count > 1 }
            for indices in collisions {
                for index in indices {
                    lengths[index] += 1
                    labels[index] = abbreviation(words[index], length: lengths[index])
                }
            }
        }

        let collisions = groups(labels).values.filter { $0.count > 1 }
        var reserved = Set(labels.map(normalized))
        for indices in collisions {
            var suffix = 1
            for index in indices {
                let base = labels[index]
                while reserved.contains(normalized(base + String(suffix))) { suffix += 1 }
                labels[index] = base + String(suffix)
                reserved.insert(normalized(labels[index]))
                suffix += 1
            }
        }
        return Dictionary(uniqueKeysWithValues: zip(teams.map(\.id), labels))
    }

    private static func abbreviation(_ words: [String], length: Int) -> String {
        guard !words.isEmpty else { return "?" }
        return words.map { word in
            let prefix = word.prefix(length)
            return prefix.prefix(1).uppercased() + prefix.dropFirst().lowercased()
        }.joined()
    }

    private static func normalized(_ label: String) -> String {
        label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func groups(_ labels: [String]) -> [String: [Int]] {
        Dictionary(grouping: labels.indices, by: { normalized(labels[$0]) })
    }
}
