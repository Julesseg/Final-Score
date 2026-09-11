# Final Score

A scoreboard for card and board games. It replaces the pen-and-paper scorepad
you reach for mid-game, so everything here is shaped by one constraint: entering
a score must be faster than writing it down.

## Language

### The two things called "game"

**Game**:
A ruleset with a scoring system — Belote, Rummy, Yahtzee. Ships built-in or is
authored by the user. Exists independently of anyone playing it.
_Avoid_: game type, preset, ruleset, template

**Match**:
One play of a Game, from setup to a Winner, with its own Teams and Scores.
_Avoid_: session, game, play

### Who scores

**Team**:
The unit a Score belongs to — one or more Players, and the thing a column of the
scorepad represents. Most Games give every Player a Team of one; partnership
games group them. Composed once at Match setup and fixed for the whole Match.
Teams stay out of the UI unless the Game asks for them.
_Avoid_: side, pair, partnership, column, scorer

**Player**:
A person in the user's roster, reused across Matches. Distinct from the person
holding the phone.
_Avoid_: participant, user, competitor

**Dealer**:
The Player who deals for a given Round.
_Avoid_: starter, first player

**Seating order**:
The order Players sit around the table, set at Match setup. The Dealer advances
along it each Round, in whichever rotation the Match is set to.
_Avoid_: turn order, player order, rotation

### Scoring

**Structure**:
Whether a Game is scored as Rounds or as a Tally. Declared by the Game.
_Avoid_: mode, format, kind

**Round**:
One row of a Match's scorepad — a hand, a deal, a turn. Games with the Rounds
Structure accumulate them.
_Avoid_: hand, deal, turn, trick

**Tally**:
The Structure with no Rounds: each Team has a running Total that points are
added to and taken from as they happen.
_Avoid_: counter, running score, freeplay

**Score**:
A Team's points for one Round, or one increment within a Tally.
_Avoid_: points, entry, value, cell

**Quick score**:
One of the values a Game offers as a single tap on the scorepad — Coinche's nine
contracts, say. Declared per Game; a Game may offer none, in which case the
scorepad hides them.
_Avoid_: chip, shortcut, preset score, step

**Override**:
Entering a Score by keypad, ignoring the Step entirely. Always available, in
every Game, on every Score.
_Avoid_: manual entry, custom score, free entry

**Total**:
A Team's Scores summed across a Match. Always derived, never stored.
_Avoid_: running score, tally (a Tally is a Structure), sum

**Direction**:
Whether the highest or the lowest Total wins. Declared by the Game.
_Avoid_: sort order, polarity, high/low

**End condition**:
The Game's declared signal that a Match has run its course — a Round count
reached, or a Total crossing a target. The app announces it; it never stops the
user scoring past it or ending early.
_Avoid_: game over, limit, win condition

**Winner**:
The Team whose Total wins under the Game's Direction when a Match is ended.
Always derived, never stored, so correcting an old Score corrects the Winner.
_Avoid_: champion, leader (the leader is whoever is winning mid-Match)

### Starting again

**Rematch**:
A new Match created from a finished one's configuration — same Game, same Teams,
empty scorepad. Distinct from resuming, which returns to a Match still in play.
_Avoid_: replay, repeat, new round, restart
