# Encounters: how the bosses come in, and world 1's first boss (USA ROM)

Worked out on 11 November 2026 from the game's code and checked in the
emulator. Speeds are in 1/256ths of a pixel per update; an update is two
frames. "Read from code" means I followed the instructions in the ROM;
"measured" means I watched it happen in the emulator.

## The encounter table (read from code, checked for world 1's two bosses)

Bank 6, $9E6D: one pointer per world, each to one pointer per area, each
to a list ending in $FF. An entry is five bytes, sometimes six:

| Byte | Meaning |
| --- | --- |
| 0 | Row of screens the camera must be on |
| 1 | Column. 0: the camera must be at X 0. Otherwise the camera's X must be 3 to 5 pixels short of that screen (for column 2: 507 to 509) |
| 2, 3 | Where the object appears: X within that screen column, Y within the row |
| 4 | A slot byte; its low three bits pick a kind from a line-up |
| 5 | Only if it is $F0 or more: a code. $9E5F + code gives the line-up to pick from |

The routine that reads it is at $9C30 in bank 6. Each entry fires once;
bits in $7C and $AE remember which have.

Because the camera must be 3 to 5 pixels short of the screen, a boss in a
column other than 0 only appears when the screen scrolls there from the
left. Dropping the turtle straight onto the last screen, as my earlier
tests did, never met the condition. That is why update 20's notes said
the second boss could not be found.

The entries with a code are the bosses: six in the whole game. World 1:

| Area | Entry | Kind | Appears at | Camera |
| --- | --- | --- | --- | --- |
| 1 | 00 02 60 B4 B0 F0 | 70 | (608, 180) | X 508 |
| 5 | 00 00 D0 44 B9 F1 | 71 | (208, 68) | X 0 |

Both match what the emulator showed. The remake now reads this table
(`RomLevels._encounters`) instead of listing bosses by hand.

**Not understood:** the entries without a code (world 1 has three, in
areas 0, 2 and 3, all with slot byte 9B). Meeting their camera condition
set $5E to 1 and nothing else that I could see happened. The remake
ignores them.

## During a fight (measured)

- $5E goes 1, then 3 fourteen frames later, and the boss is there.
- The camera stops. In both of world 1's fights it did not move again
  until the boss was beaten.
- The turtle was held between 20 and 220 pixels from the screen's left
  edge in the kind 70 fight (he reached 215 in the other, where a wall
  may have been what stopped him).
- The second bar on the status strip shows the boss's energy.
- The sprite colours change. In the kind 70 fight sprite palette 2 became
  0F 08 24 37 and palette 3 became 0F 0F 26 37 (read from the game's
  palette buffer at $059F).

## Kind 70 (it looks like Bebop)

Hit points 72, damage on touch 19 (ROM tables). Leonardo's 7 a hit means
11 hits. Beating it gave 4000 points and, about three seconds later, set
bit 0 of $7C and cleared $5E. The world does not end.

Its first act (bank 5, $AAFF) is to put a second object, kind 11, on the
ledge by the door: at (196, 83) on the screen, facing left. Kind 11 is one
picture of two figures, who look like Rocksteady holding April. It is gone
the moment the boss is beaten.

### Its routine (read from code at bank 5 $AADB, and it matches every recording)

| State | What it does |
| --- | --- |
| 1 | Faces the turtle, sets speed 512, goes to state 2 |
| 2 | Walking. A wall 12 pixels ahead stops it. At screen X below 25, or 232 and above, it turns round. Then by distance to the turtle, sideways only: under 16, go to state 5. Under 36, go to state 3 if bits 4 and 5 of the frame counter are both 0 (16 frames in every 64). Otherwise, after 48 updates in this state, go to state 1 (but see below) |
| 3 | Sets upward speed 1280: a jump |
| 4 | In the air: 78 added to the fall speed each update. On landing, state 7 |
| 5, 6 | Stops and plays its stopped animation, 12 updates in all. Then state 9 |
| 7 | Faces away from the turtle, speed 512, state 2 |
| 9 | Stands. When the frame counter's bits 1 to 4 are all 0 (once every 32 frames): state 1 if bit 6 is set, state 7 if not |

Because the position moves after the routine runs, it always takes one
more step than the rule says: it stops 12 or 13 pixels from the turtle,
not 15.

Measured and in agreement: stop 12 updates; jump 44 pixels high and about
35 updates long; against a turtle who stood still, a steady 16-update
round of "step, stop, stand" going toward, toward, away, away.

**Left out of the remake:** in state 2, after 48 updates and further than
35 pixels away, the original jumps instead of turning if bit 4 of the
turtle's flags ($0450) is set. I saw that bit both set and clear while he
walked, jumped and attacked and could not tell what it means.

The remake's version is `Scripts/Enemies/Bebop.gd`. It keeps its own
frame counter, so the timing of its choices will not line up with the
original's frame for frame.
