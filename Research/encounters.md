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

Both match what the emulator showed. The remake reads this table
(`RomLevels._encounters`) instead of listing bosses by hand.

## The routine, step by step (read from code 6:$9C1D, 13 November 2026)

This replaces the measured account in the next section where the two
differ. The routine is called once an update, on the enemies' frame,
before any object moves (6:$8103, from the main loop's 7:$CF10). RAM $5E
picks what it does:

- **$5E = 0 or 1.** The room's entries are gone through in order; those
  already fought (a bit each in $AE, or in $7C for a boss) are passed
  over. The first whose row and column the camera is on is taken. If $5E
  was 0 it becomes 1 and a count ($9B) is set to 8: the screen is held
  from now on. Then, on this and every later update: if any object slot
  from 5 to 15 holds a kind of $10 or more (an enemy, something thrown,
  a puff; items do not count: 7:$EEE9) nothing more happens. Otherwise
  $B0 is set to 1 and the count goes down by one. When it reaches 0 the
  entry's enemy is made: so it is the eighth update that finds the
  screen clear. Measured: the last soldier left the screen at frame 429,
  the extra one was there at frame 445.
- **A held fight's enemy** (6:$81F4, then $82DB). The room first turns to
  its line-up for the line-up level as it stands (`enemy_placement.md`),
  and the kind is the entry's slot in that line-up. It is put in the
  first free slot from 5 at the entry's X and Y taken as places on the
  screen, without the wall test, facing left if X is 128 or more. $5E
  becomes 2. Being made before the object loop of the same frame, it has
  its first update at once: a soldier made within 24 pixels of the
  turtle is already punching on the frame it appears.
- **A boss** (6:$9D05, $82C9): the code picks its line-up (table at
  6:$9E5F) and colours; it is made the same way but at the entry's X
  less the camera's low byte; $5E becomes 3. Code F5 (world 5) makes six
  objects from a list at 6:$9D84 instead.
- **$5E = 2** (6:$9DA8). Nothing while anything is on the screen. Then a
  sound, and a count of 64 updates (measured again: 127 frames from the
  enemy being taken away to $5E being 0; the earlier "64 frames" was
  wrong). Then the entry's bit is set in $AE and $5E and $B0 are cleared.
- **$5E = 3** (6:$9DD1). Nothing while anything is on the screen (the
  boss, or its puff). Then a sound and 32 updates; for the first boss
  (code F0) another sound and 64 updates more. Then $5E and $B0 are
  cleared and, if the turtle still has energy, the boss's bit is set in
  $7C and RAM $B5 is given a number from the table at 6:$9E58 (2, 3, 9,
  8, 12, 14, 15 by code), which the main loop acts on (7:$CC2A).
- **While $B0 is 1** an object in slots 5 to 7 is held between 6 and 246
  across the screen before the off-screen test (5:$808D): the extra
  enemy and a boss cannot leave the held screen.
- No enemy is made from the room's places while $5E is not 0 (6:$8106).
- $AE, $B0, the room's clock and the room's points are cleared when a
  map is entered (7:$E7FB).

The remake's copy is `RoomScene._check_boss`, `_start_hold`, `_bring_in`
and `OriginalEnemy.held_on_screen`. Still measured, not read: how the
turtle is kept on the held screen (20 to 236).

## Held fights: the entries without a code (read from code, then measured)

Update 21 called these "not understood". They are fights the screen
stops for. World 1 has three: area 0 (camera 508), area 2 (764) and
area 3 (252). What happens:

1. The camera reaches the entry's spot, from either side (the test is on
   the camera's position only). $5E becomes 1. The screen stops and the
   turtle is kept on it.
2. Nothing more happens while any enemy, or anything an enemy threw, is
   on the screen. (The check is at $EEE9 in bank 7.)
3. Fourteen frames after the screen is clear, one more enemy comes in
   ($5E = 2). Its kind is the entry's slot in the room's own line-up: kind
   98 in areas 0 and 2, kind 91 in area 3. It appears at the entry's X
   counted from the screen's left edge: (532, 100), (844, 176), (460, 96).
4. Once that enemy is gone the game plays a sound, waits 64 frames, sets
   the entry's bit in $AE and frees the screen ($5E = 0).

I tested this by removing the enemies from memory, not by fighting them.
The remake does the same (`RoomScene._start_hold`). $AE must be cleared
when a room is entered, since each room numbers its entries from 0; the
remake lets a room's held fights happen again each time it is entered.

The same either-side rule applies to bosses, so the remake's boss trigger
was changed to match.

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
