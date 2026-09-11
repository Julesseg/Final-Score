# Domain in Core as Codable values, persisted as JSON

`AGENTS.md` requires all business logic to live in `Core/`, a pure SwiftPM
package with no dependency beyond Foundation so `swift test` runs it on Linux CI
in seconds. SwiftData's `@Model` types cannot live there, so keeping the domain
in Core and adopting SwiftData are mutually exclusive. We chose the domain: every
type — `Game`, `Match`, `Round`, `Score`, `Player`, `Team` — is a `Codable`
value type in Core, and a Match is persisted as a JSON snapshot.

## Consequences

No free CloudKit sync, no generated queries, and any change to the stored shape
needs a hand-written migration. All three are affordable here: a Match is a few
kilobytes, a heavy user has a few hundred of them, and there is no server. In
exchange, the entire scoring model — totals, winner derivation, end conditions,
dealer rotation — is unit-tested on the fast loop rather than behind a simulator.

Anyone reaching for SwiftData later should understand they are also proposing to
move the domain out of Core, which is the decision that actually needs making.
