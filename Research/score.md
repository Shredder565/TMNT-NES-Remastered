# The score, and the boxes on the strip (USA ROM)

Worked out on 12 November 2026 by reading the ROM's code and by measuring
in the emulator (cynes). Each fact is marked **(code)**, **(measured)** or
**(guess)**. Addresses are bank:address. Script:
`Research/cynes/score_checks.py`.

## Where the score is kept (code, measured)

- The score is three bytes at RAM $C2 to $C4, low byte first, each holding
  two decimal digits. The strip shows the six digits and then a nought
  that is always there (0:$8084, 0:$841D), so every score ends in 0.
- The best score is the same three bytes at $C8 to $CA, shown after "HI".
  After every addition the two are compared from the top byte down and the
  best score takes the score's value when the score is higher (7:$C88C).
- A new game sets the score to 0, with three continues, full energy and no
  special weapons (7:$C669). CONTINUE wipes the game's whole work area
  from $48 to $DF except $C8 to $CA (7:$C6D6), so the score starts again at
  0 and the best score stays. Nothing ever clears the best score: it lasts
  until the console is switched off.
- The strip is the only place a score was found. The Start screen shows
  none (measured: its picture is the same with a score of 6800 as with 0).
  GAME OVER and the title are layouts with no digits in them (guess for
  the rest: no other code reads $C2 to $C4 or $C8 to $CA for display).

## What gives points (code, measured)

One routine adds to the score (7:$C889: the two low bytes to add are in A
and Y) and one place calls it: the end of the routine that takes a hit off
an enemy, when the hit has beaten it (6:$9A1E, through 6:$9BDF). So only
beating something scores. Picking up an item gives nothing, nor does
finishing a world or a rescue (measured: the score did not move from the
last boss's fall to world 2's overworld).

How much does not go by the enemy's kind. Every object carries the slot
byte of the entry it was made from ($0540 + its slot number). If that
byte is 0 nothing is given. Otherwise four of its bits (mask $78) pick a
pair of bytes from the table at 6:$9C03:

| Bits 3 to 6 | Points |
| --- | --- |
| 0 | 100 |
| 1 | 200 |
| 2 | 300 |
| 3 | 800 |
| 4 | 900 |
| 5 | 1000 |
| 6 | 4000 |
| 7 | 5000 |
| 8 to 11 | 6000, 7000, 8000, 9000 |
| 12 | 10000 |

A room's placed enemies have slot bytes $80, $89, $92, $9B, $A4 and $AD
(`enemy_placement.md`), whose bits 3 to 6 are the same as the slot number
0 to 5. So the six slots of a line-up are worth 100, 200, 300, 800, 900
and 1000, whatever kind stands in them.

Measured in world 1 (the score and the beaten object's kind and slot byte
on the frame the score changed):

| Beaten | Slot byte | Points |
| --- | --- | --- |
| kind 8D (areas 0 and 1) | $80 | 100 |
| kind 81 (area 1), kind 86 (areas 3 and 4) | $89 | 200 |
| kind 96 (area 5) | $92 | 300 |
| kind 98 (area 1) | $9B | 800 |
| kind 92 (area 5) | $AD | 1000 |
| the first boss, kind 70 | $B0 | 4000 |
| the last boss, kind 71 | $B9 | 5000 |
| a thrown thing beaten in the air (kinds 99 and 4A) | $80 | 100 |
| the overworld's soldier, kind 40 | $80 | 100 |

The overworld's rollers carry $A4 (900 points; not beaten in the
recording). A boss's and a held fight's slot byte is the fifth byte of its
entry in the encounter table (`encounters.md`). The object that stands by
in the first boss fight (kind 11) carries 0.

The enemies in these measurements were beaten both by the weapon and by
touching the turtle while the power item ran; both go through the same
routine and scored the same.

## A second count, for the enemies (code; not used by the remake)

Each addition is made a second time to three more bytes, $C5 to $C7
(6:$9BEB, 7:$C881). They are set to 0 by the set-up at 7:$E809. The
enemy routine at 6:$816A compares $C6 and $C5 with eight steps at 6:$838B
(2000, 4000, 7000, 10000, 14000, 20000, 28000 and 35000 points) and,
together with a clock at $9D/$9E and the turtle's energy, chooses which of
the room's four enemy line-ups is in use ($0614). So the more points are
made the harder line-ups come in. This belongs to the enemies, and is
only noted here.

## The strip's boxes (code 0:$82E8; measured for all four turtles)

The program writes the strip a part at a time: on every second frame,
when the frame counter's bits 1 and 2 are 0, 1, 2 or 3, the score and best
score, the energy, the boss's energy, or the boxes (0:$8062). So each part
is written every eighth frame.

- Columns 21 and 22: the playing turtle's own weapon, tiles $40 + 4 x his
  number (Leonardo $40 to $43, Raphael $44 to $47, Michelangelo $48 to
  $4B, Donatello $4C to $4F): left column top and bottom, then the right
  column.
- Columns 24 and 25: his special weapon. $73 + his number holds which one
  (0 for none). None is the empty box, tiles $3C to $3F. Number n is tiles
  $4C + 4n to $4F + 4n in the same order ($50 for 1, $54 for 2, $58 for 3,
  $5C for 4).
- Under it, on the "HI" row, the count from $A8 + his number as two
  digits (5 is written 05, nought being tile $0A); nothing when it is 0.
- While the special weapon is the one in use ($5B is 1) the box blinks:
  on the frames when bit 3 of the frame counter is 0 the box's four tiles
  are written blank (0:$8181), and the boxes' own part writes them back.
  The count stays.
- Columns 27 and 28: a third box in worlds 3 and 4 only (the table at
  0:$8402). It is empty until the count at $A7 is more than 0, then shows
  tiles $34 to $37 with that count under it.

Measured: for each of the four turtles, special weapons 0 to 4 and counts
of 5, 23, 99 and 1, the emulator's strip and the remake's are the same in
every pixel (20 pictures), as they are with a score of 6800 and a best
score of 1234560.

## In the remake

- `RomLevels.points_for(slot_byte)` reads the table; `EnemySpot.points`
  and `Encounter.points` carry the result.
- `RoomScene` keeps `score` and `high_score` (`add_score`, `set_score`).
  A beaten enemy leaves its puff the moment it is beaten, and that is
  where the scene gives the points (`_on_thing_entered`): a placed enemy
  its slot's, a boss or a held fight's enemy its entry's, anything else
  that could be beaten (a thrown thing) 100. The enemies' own scripts were
  not changed.
- The best score is kept in `Game.high_score` for as long as the program
  runs. CONTINUE sets the score to 0.
- `HudStrip.show_scores` shows both; `HudStrip.show_special` and
  `show_third` take the special weapon, its count, the blink and the third
  box's count.

Different from the original:

- The remake writes the strip at once, not a part every eighth frame.
- An enemy line-up does not change with the points made.
