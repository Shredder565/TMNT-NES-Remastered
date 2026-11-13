# World 2's lake: the clock, the currents, the bombs (USA ROM)

Worked out on 13 November 2026. **(code)** = read from the program,
**(measured)** = seen in the emulator (cynes), **(guess)**. Addresses
are bank:address. The swimming itself is in `swimming.md`; the survey in
`world2.md`. Scripts: `Research/cynes/lake_record.py` with
`swim_replay.gd.txt`. The remake: `Scripts/Levels/Lake.gd`.

## The things at fixed places, in general (code 4:$AB94, 4:$B554)

The room's table (4:$ACCD, `doors.md`) has 44 entries for the lake. Up to
eight are "in hand" at a time (lists at $0628 to $06B8).

- **Taken in hand** (4:$AC05, every update): two points are looked at,
  10 and 246 across the screen. An entry on the screen (of the map) a
  point is in is taken if its span across reaches the point: its right
  end not left of the left point, or its left end not right of the right
  point. So: an entry is in hand while its span meets the part of the
  screen from 10 to 246, on the row of screens on show. The same test
  the other way round lets it go (4:$B60E).
- Each kind in the table has a routine for when it is taken (table at
  4:$B57C) and each entry then a stage routine run every update (table
  at 4:$B5FE). Most make an object from the table at 4:$B9E5 (object
  kind, animation, hit points, flags) at the entry's place: its right
  end across, its top down.
- A change of row clears the lists (`swimming.md`).

## The clock (code 4:$A94E, 0:$8146; measured)

- $BB seconds, $BA updates. Set to 140 and 30 as the room comes up after
  the jump in (measured).
- The swimming routine calls the clock first thing on each of its
  updates: with $BB at 0 it starts scene 5 and the routine does nothing
  else; otherwise $BA goes down, and at 0 it is set to 30 and a second
  goes (sounds at 22, 21 and 5). So it stands still whenever his routine
  does not run: in a change of row, at a bomb.
- **On the strip** (code; measured): four tiles from column 14 of the
  strip's third row (under his energy; at 112 to 143 across, 216 to 223
  down the picture): the minutes, tile $2E (a colon), two digits of
  seconds. Measured: it shows for 8 frames and is blank for 8, over and
  over. Which 8 was not lined up with the frame counter: the remake
  uses the phase of the special weapon's box (guess).
- **Scene 5, the time is up** (code 6:$A110, $A117; measured): 50 calls,
  one every second frame: the background's sixteen colours are set to a
  list of the room's own or all to colour $15, by bit 2 of the count.
  Then all four turtles' energy is 0 and the play step is 7, the usual
  end of a turtle; with none left that is the end of the game.

## The currents (code 4:$B7F5 to $B844; measured in six runs)

Table kinds 20 to 27 make no object. Each update, for each one in hand
in turn: if he is already in another current (its number is in $8B)
this one is passed over. Otherwise, if his place across the screen is
greater than the entry's left end and not greater than its right end
(both made into places on the screen by taking off the screen's corner,
in single bytes), $8B takes the entry's number and $7E the kind's value:

| Table kind | $7E | Way |
| --- | --- | --- |
| 20, 24 | $10, $11 | up |
| 21, 25 | $20, $21 | down |
| 22, 26 | $40, $41 | right |
| 23, 27 | $80, $81 | left |

and if not, both are set to 0. Only his place across is asked: the
entry's two heights are not looked at. What the low bit of the value is
for was not found (the swimming routine uses the high four bits only).
The lake has 21 (three), 25 (three), 22 (two) and 26 (three).

## The bombs (code 4:$B7BC, 6:$96B5, 6:$A167, $A19F; measured once)

- Table kinds 17 to 1E, one each, make an object of kind 09 (an item)
  with animation 38 (pictures 8C and 8D, 4 updates each) and one bit of
  eight in its hit-points byte. $7D keeps the bits of the bombs seen to;
  one whose bit is set comes up with animation 39 (picture 8E) and its
  colours changed (sprite colours 0F 0F 07 29 become 0F 0F 00 12:
  measured).
- Its box (table 6:$8935 by animation): 4 each side and 46 up from its
  place. The item pass (enemies' frames) uses the usual box test
  (`touching.md`). Measured: touched with his middle at (210, 447) and
  the bomb at (224, 490), not 2 pixels further left.
- **Touching it** (6:$96B5), if he has energy and its bit is not yet in
  $7D: the bit is set, his blinking is ended, and scene 6 begins
  (4:$A983: $B5 = 6, the bubble removed).
- **Scene 6** runs every second frame, starting the frame after the
  touch; the turtle and the enemies are not run (the bombs' own pictures
  go on changing; his animation stands still: measured).
  1. Each call moves him one pixel up or down towards 25 above the
     bomb's place (the code takes $18 off with the carry clear).
  2. The call that finds him there puts him at the bomb's place across
     and sets a count of 64.
  3. Each call after takes one off; his picture is 8B while bit 2 of the
     count is set, else 8A. At 0: the bomb gets animation 39 and the
     changed colours, his speeds are set to 0, a sound; and if $7D is
     $FF scene 7 begins, else play goes on.
  Measured: 165 frames from the touch to play going on, with 18 pixels
  to rise: (18 + 1 + 64) calls.
- He stays where the scene put him. His routine runs again 2 frames
  after the last call.

## The end (code 6:$A1ED, $A1F3; not measured)

Scene 7 calls a routine in bank 2 ($B5B2, then $B5BE every call) with a
step number in $03C2; when that reaches $13 the world is set to 2 (the
third) through the code that ends world 1 (6:$A0F3) and world 3's
overworld begins. What bank 2 shows was not read. **The remake goes
straight to world 3's overworld.**

## Compared with the emulator

Seven runs with the clock, the currents and the bombs live in both (in
the emulator only the objects that hurt, kinds 1B to 22, were taken away
every frame; his energy refilled), the real room scene given the same
buttons: through five current regions on all three rows, with Down held
in one, and to the first bomb and on. 7679 frames. His place, both
speeds, facing and energy agree on all 7679; the current he is in, the
clock (seconds and count) and the bombs' bits on all 7679; animation
and picture on 7677 (two frames at the bomb).

## The lines that switch on and off (code 5:$8E79, $8E9B, 6:$9B90; measured)

Table kinds 13, 14, 15, 16 make an object of kind 1F, 20, 21 or 22
(4:$B786): two end pieces, one above and one below its place, and
nothing between. Their routine (5:$8E79): once the frame counter is $50
or more the object becomes kind 23, 24, 25 or 26 with animation 5A, 5C,
5E or 60: a zigzag line between the end pieces. That kind's routine
(5:$8E9B) turns it back when the counter is under $50. So every line in
the lake is off for the same 80 frames of every 256 and on for the
other 176.

- Touching: kinds 1F to 22 cost nothing (the touch table has 0); kinds
  23 to 26 cost 16. The box is by animation: 2 each side and 32, 40, 48
  or 64 up; and for kinds 23 to 26 (and 89) the box test takes the same
  distance below the object's place as above it (6:$9B90, list at
  6:$9BC6), where every other object's box ends 2 above its place.
- Measured: switched on, the picture is blank for one update in four
  (pictures 93 then 94 three times, and so on for the others).
- Measured: a swimmer who touches one loses 16 and blinks for 24
  updates; he is not thrown and his speeds do not change.
- The lake has 6, 6, 3 and 4 of the four lengths.

Compared: six runs with the lines live in both (the columns taken away,
energy not refilled): 4342 frames; place, speeds, pictures, facing,
current, clock all 4342; energy 4340 (in one run the remake's hurt
comes 2 frames from the original's). The frame counter itself was
checked to agree through a change of row and a disarming: the remake's
counter now runs on while the turtle is held.

## Not done

- Table kind 12 (a column of seven objects of kinds 1B to 1E, 10 on
  touch; routines 5:$8DE2 and $8DE5; stage routine 4:$BAD0). Not read,
  not made: two places in the lake.
- Table kind 1F: a list of palette changes every 6 updates (7:$FE78,
  list at 7:$FEC3: palettes $0C, $0D, $0E, $0E, $0D, $0C). Not made.
- Scene 7's screens. The flashing of scene 5 is one tint, not the
  original's two palettes.
- When $7D is cleared (the remake clears it when the world is begun
  again, and when it is won: guess).
- Sounds.
