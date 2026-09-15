# A Game is a fixed set of declarative knobs, not a rules engine

Card games are full of rules an app cannot feasibly encode: shooting the moon in
Hearts, capot in Belote, Coinche's contract-and-chute scoring, Tarot's sliding
target by number of bouts. We considered a small expression language and
hand-written Swift per built-in Game, and rejected both. A `Game` is instead a
fixed struct of declarative fields — structure, team play, player count,
direction, end condition, quick scores, negatives, dealer tracking, and
presentation — editable as a plain form.

## Consequences

The app never validates a Score against a game's rules, and never computes one.
What makes this sufficient is the **Override**: the keypad is always available on
every Score in every Game, so a rule the knobs cannot express degrades to typing
the number, which is exactly what pen and paper required anyway.

The payoff is that the custom-Game editor is a form a user can finish in under a
minute, and that authoring a Game needs no code. A rules engine would have
inverted both: months of work, an editor nobody can learn, and users still
hitting cases it cannot express.
