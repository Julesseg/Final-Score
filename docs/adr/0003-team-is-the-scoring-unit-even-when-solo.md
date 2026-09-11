# Team is the scoring unit, even for solo games

A column of the scorepad belongs to a `Team`, never directly to a `Player`. In
Skyjo or Scrabble every Team holds exactly one Player, which looks like pointless
indirection until you reach Belote and Coinche, where the score genuinely belongs
to a partnership. The alternative — `Player` columns now, teams retrofitted later
— would mean rewriting every score path, the winner derivation, and the persisted
format, because "who scored" is load-bearing in all three.

## Consequences

One code path for scoring instead of two, at the cost of a wrapper type that is
degenerate for five of the seven built-in Games. The UI hides Teams entirely
unless the Game declares `teamPlay: .teams(of:)`, so the indirection never
reaches the user.

Teams are composed once at Match setup and are fixed for its duration. Games
where partnerships re-form every deal — Tarot's taker-versus-defenders, Barbu —
are therefore modelled with individual columns and the Override rather than with
per-Round teams, which would have put a "who took it" step inside every single
round and defeated the point of the app.
