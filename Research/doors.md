# Doors, manholes and the overworld in the original (USA ROM)

Worked out on 10 November 2026 by disassembling the door code in program
bank 7 ($E68A-$E837 finds and uses a door, $F089-$F117 works out which
screen the turtle is on) and the overworld walking code in bank 6
($A8B5-$AAD8), then checking the results in an emulator. The checks can be
re-run with `Research/cynes/door_checks.py`. The decoder is
`Scripts/Rom/RomLevels.gd`.

## Door records

A door is 11 bytes. A list of doors ends with $FF.

| Byte | Meaning |
| --- | --- |
| 0 | Screen number inside the map (row x map width + column) |
| 1, 2 | The door's X and Y inside that screen |
| 3 | Where it leads: 1 a side-scrolling room, 0 the overworld |
| 4 | Room number (for the overworld: the world number) |
| 5, 6 | Turtle's X and Y on the screen after arriving |
| 7, 8 | Camera X after arriving, high byte first |
| 9, 10 | Camera Y after arriving, high byte first |

The turtle's place in the new map is camera + screen position. The values
are the turtle's middle ($0480 / $0460), not his feet.

## Where the lists are (bank 7)

$E84F holds 7 pointers: one table for each world's rooms, then one for the
overworlds. Each table is a row of pointers (per room, or per world for the
overworld) followed directly by its first list.

| Table | Lists | Doors |
| --- | --- | --- |
| Overworlds, $E85D | 5 (worlds 1-5) | 9, 3, 12, 31, 5 |
| World 1 rooms, $EB00 | 6 | 9 |
| World 2 rooms, $EB75 | 1 | 2 |
| World 3 rooms, $EB8E | 7 | 12 |
| World 4 rooms, $EC27 | 17 | 34 |
| World 5 rooms, $EDCF | 9 | 11 |
| World 6 rooms, $EE63 | 4 | 7 |

135 doors in all: 60 on the overworlds and 75 in rooms.

Two oddities the decoder has to allow for:

- World 2 has two rooms but one list, and world 4 has 18 rooms but 17
  lists. The rooms without a list have no doors (the underwater level and
  world 4's last room).
- The list for world 4's room 16 has no $FF at the end; it runs straight
  into the next table. The decoder stops a list where the next one begins.

## How a door is chosen

The game works out which screen the turtle's middle is on, then takes the
first door on that screen that is less than 32 pixels away across and less
than 32 away down (40 in world 6). Confirmed for the first manhole.

## What sets a door off

| Where | How | Status |
| --- | --- | --- |
| Overworld | Walking so that the point the game checks ahead of the turtle lands on a door tile (kind 2). A door tile with no door record in reach acts as a wall. | Read from the code; the first manhole confirmed in the emulator |
| Room, doorway | Pressing Up while standing on the floor in front of a door tile. Walking through it does nothing. | Measured: at the building in world 1 (door tiles at X 32-39) Up works with the turtle's middle at X 32 to 46, and not in the air |
| Room, ladder | Climbing up until the turtle's middle is within about 16 pixels of the top of the screen. | Measured: still inside at Y 17, gone at the next step |

Of the 75 room doors, 40 are ladders out of the top, 33 are doorways, and
2 (a pair inside world 4's room 15 that lead to each other) sit on neither a
door tile nor a ladder. What sets those two off is not known, and the remake
does not use them.

## The overworld maps

Same layout as the rooms (see `level_format.md`) with these differences:

| What | Rooms | Overworld |
| --- | --- | --- |
| Screen size | 8 x 6 blocks (256 x 192) | 8 x 8 blocks (256 x 256) |
| Block shapes and colours | bank 3 | bank 4 |
| Block shape pointers (bank 1) | $8015 | $8001, per world |
| Block colour pointers (bank 1) | $8033 | $800B, per world |
| Screen data pointers (bank 1) | $805D | $8051, per world |
| Map (width, height, screens) | $F49E, per world then area | $F4AA, per world |
| Graphics page | $D5CE | $D5C8, one byte per world |
| Palette number | $D63B | $D636, one byte per world |

Sizes in screens: 2 x 2, 2 x 1, 5 x 5, 4 x 4, 3 x 3. World 6 has no
overworld. The decoded first overworld matches the emulator's screen.

$D679 holds the camera position at the start of each world (X, Y, two bytes
each, low byte first). For world 1 the turtle then stands at camera +
(128, 120) = (160, 296), which matches the emulator. For worlds 2 and 4 that
point is inside a wall, so the true starting spot there is still unknown;
the remake uses the nearest walkable spot.

## Walking on the overworld

The speed was measured. The rest of this section is read from the code and
has only been checked by the one walk onto the first manhole.

- One update every 2 frames, 2 pixels per update (60 pixels a second),
  whole pixels only.
- No diagonals: if Left or Right is held, Up and Down are ignored.
- Before each step the game looks at one point ahead of the turtle's
  middle: up (0, -3), down (0, +6), left (-7, +3), right (+7, +3).
- Tile kinds 4 and 12 at that point stop him (12 is water on these maps).
  Kind 2 is a door. Kind 6 lets a turtle on foot through but stops the van
  (the flag at $0606); the van also moves 3 pixels a step and cannot use
  doors. The van is not in the remake yet.

The planned walking route on the decoded map found no way from the start to
the building at (424, 288) without going through the first sewer, which is
how the original is laid out.

## The feet

Standing on a floor, the turtle's Y value ($0460) is 20 pixels above the
floor's top edge (140 on the building floor at 160; 76 on the sewer ledge at
96). `sprite_notes.md` gives 24 for the bottom of the lowest sprite; the
difference is how far the sprite hangs below the standing line.

## World 5's hidden Technodrome

Three caves in world 5 (rooms 2, 3 and 4) each have an inner door whose
record leads to rooms 5, 7 and 8. When such a door is used, the code at
$E723 compares the room the turtle is in with the value at $55 and, if they
match, sends him to room 6 instead (the Technodrome). $55 is kept to 2, 3 or
4. Where $55 is first set was not traced; the remake picks one of the three
caves at random when the game starts.

## Not done yet

The starting spots for worlds 2 and 4, what $55 starts as, the van, the
enemies and obstacles on the overworld (the turtle's own overworld sprites
are in `enemy_kinds.md`), the two unexplained doors in world 4's room 15, the
dam's dive into the water in world 2 (the game sets turtle state $0D when a
door tile is touched there once the camera is 128 pixels or more to the
right), and the fade between screens.

## Arriving in a room, from the code and against the emulator (13 November 2026)

Read from 7:$E755 to $E837 and 4:$9761; then every door of world 1 was
gone through in the emulator and in the remake
(`Research/cynes/door_record.py`, `door_replay.gd.txt`).

- The record's bytes 5 and 6 become his place on the screen and bytes 7
  to 10 the screen's corner, as they are. He is not stood on a floor and
  the screen is not centred on him. (The remake centred the screen and
  lifted him out of floors.) World 1's records put him on a ladder at
  (40, 24) or (200, 24) on the screen, on a floor, or, at the second
  room's ledge door, 8 pixels above the ledge.
- His state is set to 0 unless the cell at his middle is ladder (kinds 9
  and 0A), when the ladder is taken. Measured: on a ladder he is in state
  0B on his first update and 0C from the next; over a floor he stands; in
  the air he goes through states 6 and 7 and falls.
- The door sets a count of 7 ($03EE). While it runs down, one a turtle
  update, his routine runs but his speeds do not move him: Up on the
  ladder does nothing yet, and at the ledge door his fall speed builds up
  for 7 updates before he drops (measured: first moved on his 8th update,
  by 420/256 of a pixel).
- The same routine clears the held-fight bits, the room's clock and the
  room's points (`encounters.md`, `enemy_placement.md`).
- Measured timing: enemies are made 25 frames after the door, stand
  still until frame 42, when everything starts; items appear on that
  frame.

### The map cells left over from the overworld (measured)

The cell memory (7:$C7C7) is sixteen columns wide and wraps every 480
pixels down (two pages of 15 rows). A one-screen room fills its own
twelve rows only. Below it, 192 to 255 down, and just above it (the wrap
brings the same row round), enemies' map tests find what the overworld
left: its own cells 192 to 255 down its first page, in the columns that
were on screen. After the first manhole that is water (kind 0C) nearly
everywhere, which is what `enemy_routines.md` measured. After the
building's door part of it is empty, and the kind 86 on that room's
ceiling rises out of the room there on arriving. The remake works these
cells out from its own overworld map (`RoomScene._cells_left_over`); it
gives the emulator's cells for the five doors where those overworld rows
were on screen when the door was used. Where they were not, the original
has whatever was drawn there last, which depends on the way walked; the
remake still takes the columns on screen (a guess).

### Things at fixed places (read from code 4:$AB94, table 4:$ACCD)

Per world and area, 8-byte entries ending in $FF: screen, X from and to,
Y from and to, kind, a number, flags. Kinds below $10 are the items;
world 1's five are exactly those the remake had listed by hand, and it
now reads the table (`RomLevels.fixed_things`). Other kinds there (11 in
world 1's last room; 12 to 26 in the dam; 28 to 3D later) are obstacles
and the like, not looked at. The original keeps up to eight of them at a
time in a list of their own as the screen comes near and gives each an
object slot from 5 up (measured: slot 7 with two enemies there, slot 11
with six), so an item can take one of the six enemy slots. The remake
puts all of a room's items out at once and does not count them.

### Result

Nine doors in, nine out. From the frame the room starts, 288 frames each
with no buttons: the screen, the turtle's position, his energy, his box
and every enemy agree on all 2592 frames. Going back out by Up, the
small turtle and the overworld's screen end where the original's do for
all nine. Not matched: the door acts on the first frame Up is down in
the remake, 3 or 4 frames later in the original.

One recording of `live_play.md` (the fifth room, walking left) starts
with the turtle put 32 pixels inside a pillar by the recorder. The
original leaves him there and raises him onto the pillar the moment he
jumps; the remake now also leaves him there but its jump does not raise
him, so that run differs from frame 72. It cannot happen in play.

### Two follow-ups (13 November 2026)

- **A doorway takes him through on his update after the one that sees
  Up** (measured: 3 or 4 frames from the button; a ladder's top 1 frame).
  The remake's doorway now waits for that second update; in the nine-door
  comparison it leaves after 3 and 2 frames where the original took 3 and
  4 (the comparison gives the remake its buttons a frame sooner).
- **Items hold an object slot while they are on the screen** (measured in
  the door recordings: slot 7 beside two enemies, slot 11 beside six).
  The remake now counts an item on the screen as one of the six placed
  enemies if a place was free when it came on, else as one of the four
  thrown things. Taken as "on the screen" by the objects' own rule (4
  pixels inside); the original's list takes an item up 10 pixels inside,
  which was not copied. No recording here has an item and six enemies on
  the screen at once, so the effect itself was not compared.
