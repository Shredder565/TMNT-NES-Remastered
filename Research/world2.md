# World 2 (the dam): what is in it and how it ends (USA ROM)

Surveyed on 13 November 2026 in the emulator (cynes) and from the ROM's
tables and code. Facts are marked **(code)** = read from the program,
**(table)** = read from a ROM table with the remake's own decoder or a
script, **(measured)** = seen in the emulator, **(guess)**. Addresses
are bank:address. Worlds and areas are counted from 0 in the program:
world 2 is the program's world 1. Speeds are in 1/256 pixel an update.

The scripts are `Research/cynes/world2_survey.py` (the tables) and
`world2_walk.py` (getting about in the emulator).

## The way through

1. The overworld: the top of the dam, 2 x 1 screens. He starts on the
   lower terrace on the left, next to a doorway.
2. That doorway leads to the bottom-left screen of **area 0**, the inside
   of the dam: 3 x 3 screens joined by ladders. Its top-left screen has
   the door out to the dam's top.
3. On the dam's top he walks right to a gap in the wall on the second
   screen and jumps into the lake: **area 1**, under water, 9 x 3
   screens, with a clock of 140 seconds and eight bombs.
4. Disarming the eighth bomb ends the world. There is no boss and no
   entry for this world in the boss table 6:$9E6D (table: area 0 has three
   held fights, area 1 nothing).

## The overworld (table; start measured)

- 2 x 1 screens. The world begins with the screen's corner at (0, 0) and
  the turtle at (128, 136) (`world_end.md`).
- Three doors (7:$E8CB):

| Door at | Leads to | He arrives at (screen corner) |
| --- | --- | --- |
| (72, 84), the hatch on the dam's top | area 0 | (40, 90) on the screen at (0, 0) |
| (152, 120), the doorway on the terrace | area 0 | (40, 156) on the screen at (0, 384) |
| (376, 60), the gap in the wall | area 1 | (96, 96) on the screen at (0, 384) |

- Four enemy places, all slot 0 of line-up 16, which is kind 40: at
  (32, 176) and (224, 80) on the first screen, (64, 80) and (144, 80) on
  the second. Measured: two of kind 40 were walking on the dam's top
  (speed 544) when he got there. Nothing else new: kind 40 is what world
  1's overworld has.
- **No van** (measured: the van flag $0606 is 0 when the world begins;
  the van and Select at 4:$A9E3 belong to world 3). The Start screen
  shows this world's map and message (measured, one picture); its
  boxes for missiles and ropes were not looked at.
- **The jump into the lake** (measured). Walking up into the gap at
  (376, 60): 35 frames after Up he is at (376, 52) and vanishes (no
  picture); 112 frames later his object shows animation E5 (a splash,
  guess); 96 frames after that the underwater room is being drawn. The
  clock is set as the room comes up: $BB = 140, $BA = 30. He appears,
  after the usual hold, in state 0F at (96, 96) on the screen and sinks.
  The code that does the jump is the door routine's state 0D
  (`doors.md`); not read further.

## Area 0: inside the dam (table)

- 3 x 3 screens, background page 22. Tile kinds: empty, wall (4), ladder
  (9) and doorway (2) only: nothing world 1 does not have.
- Doors (7:$EB77): the top-left screen's doorway at (40, 88) leads out
  to (88, 88) on the overworld's first screen; the bottom-left screen's
  at (40, 168) leads out to (128, 144) with the screen at (24, 0).
- Enemy places: 4 to 7 on each of the nine screens (53 in all), slots
  0, 1, 2, 3 (with 4 and 5 on a few).
- Line-ups by level: 0, 0, 1, 2. Line-up 0 is 8D, 81, 81, 98, 98, 98;
  line-up 1 is 86, 86, AA, 91, 49, 49; line-up 2 is 84, 85, 85, 9D, 4B,
  4B. Measured on coming in by the lower doorway: one 8D and four 81.
- Things at fixed places: a whole pizza (kind 01) on screen 2 at
  (224, 96) and a half (kind 02) on screen 5 at (96, 40).
- Held fights (6:$9E6D): row 2, column 2 brings in slot 3 at (128, 180);
  row 1, column 0 brings in slot 4 at (216, 180); row 0, column 2 brings
  in slot 5 at (80, 180). None has a boss code.
- Every kind these line-ups can bring is written from the code except
  **9D and 4B (with its 4C)**: see `world2_enemies_todo.md`.
- The screens change by ladder, a row at a time, as in world 1's last
  room (`live_play.md`).

## Area 1: under water

### The map (table)

9 x 3 screens, background page 24. Tile kinds: empty, wall (4), and two
that world 1's rooms never use in this way:

- **kind 1**, the hurting kind: 400 tiles, the weed growing on the
  rocks. Swimming into it costs 16 energy (code, below).
- **kind 0F**: 264 tiles, in gaps two cells wide between rocks and in
  the floor of the bottom row. A swimming turtle that meets one is
  killed outright (code: state 13 sets his energy to 0). World 1 uses
  kind 0F only as a floor he can land on.

He comes in on the bottom-left screen (number 18).

### Swimming (code; nothing measured yet)

The turtle's ground routine goes to state 0F whenever the program's
world is 1, the area is 1 and he is inside (4:$996F, which also sets
$D3 to 1). State 0F is at 4:$A78B. In outline:

- Left and Right give 2 pixels an update and turn him; the fraction of
  his sideways speed is left alone.
- He sinks: 16 is added to his downward speed every update. A new press
  of A takes 224 off it (a stroke). The speed is kept between 2 up and 2
  down.
- A current (RAM $7E: $10 up, $20 down, $40 right, $80 left) adds 18 up
  or down, or 48 across, every update; with Down held in a current 48
  more downward.
- The map is tested at his place plus the whole pixels of his speed:
  13 to the side at 7 above and 7 below his middle for the sideways
  speed, and 7 above (or below) his middle at the middle and 8 to each
  side for the other. A wall sets that speed to 0; the hurting kind
  hurts; kind 0F kills; a doorway (none in this map) would be a door.
- No sword: B is not read. Object slot 1, the weapon's, carries a bubble
  that rises from his head (animation D8).
- Pictures: animation BC for a stroke or Up, BE for left and right, 8C
  for Down, BF sinking; DA when he dies; 8A and 8B at a bomb.
- His height on the screen is kept between 16 and 181; at either the
  screen changes row (the usual 4 pixels an update), unless a fight
  holds it.
- Hurt: 16 energy, safe for 24 updates, and while that lasts the water's
  colours flash; he is not thrown.

The full account, with the comparison, is to be `swimming.md`.

### The clock (code 4:$A94E; start measured)

$BB holds seconds and $BA a count of 30 turtle updates. Set to 140 and
30 on diving in. Each of his updates takes one off $BA; at 0 it is set
to 30 again and a second goes. Sounds at 22, 21 and 5 seconds. With
$BB at 0 the routine sets scene 5.

**Scene 5, time up** (code 6:$A110, $A117; measured): for 50 calls
(100 frames) the palette flashes between two sets every 8 frames; then
all four turtles' energy is set to 0 and the play step to 7, which is
the game-over path. Measured: scene 5 began 2 frames after the clock
reached 0; 100 frames later every turtle's energy was 0.

### Things at fixed places (table 4:$ACCD; code 4:$B554 on)

44 entries on screens 6 to 26. The kind in the table is not an object
kind: the routines at 4:$B57C (one per table kind) make objects from a
second table at 4:$B9E5 (object kind, animation, hit points, flags).

| Table kind | How many | What it makes (code) |
| --- | --- | --- |
| 12 | 2 | A column of seven objects of kinds 1B, 1C, 1D, 1E in slots 5 to 11: one at the place, three above (20, 36, 52 up) and three below (18, 34, 50 down). Hit points FF. A barrier of some kind (guess: the beam that switches on and off) |
| 13, 14, 15, 16 | 6, 6, 3, 4 | One object of kind 1F, 20, 21 or 22 (animations 59, 5B, 5D, 5F), hit points FF. Not yet seen moving (guess: the weed that reaches out) |
| 17 to 1E | 1 each | **A bomb**: object kind 09, animation 38, its hit points byte holding one bit of eight. Bit set in $7D = already disarmed (animation 39) |
| 1F | 6 | No object: runs a list of palette changes every 6 updates (7:$FE78): the water's or weed's colours cycling |
| 21, 25 | 3, 3 | No object: a current downward while the turtle is between the entry's two X values ($7E = $20 or $21) |
| 22, 26 | 2, 3 | The same, a current to the right ($7E = $40 or $41) |

What the low bit of a current's value means, the objects' own routines
(5:$8DE2, $8DE5 and $8E79 by the table at 5:$823B), and the second-stage
routines at 4:$B5FE were not read yet.

Measured on the first screen: table kind 16 made an object of kind 22 at
(180, 99) and table kind 17 a bomb at (224, 106): a box with a wire to a
bundle of sticks.

Line-up 17, which this area comes up with, holds no enemies and the area
has no enemy places.

### Disarming, and the end (code 6:$A167, $A19F; not measured yet)

Scene 6 is set by 4:$A983 (called through 7:$D0DC; from where was not
traced). Beginning: it finds the bomb among the fixed things, moves the
turtle up or down a pixel a call until he is 24 above it, then puts him
at the bomb's X and counts $40 calls, his picture changing between 8A
and 8B every 4. At the end the bomb's object gets animation 39, palette
$0B is set, and: if $7D is now $FF (all eight) scene 7 begins, else
play goes on.

**Scene 7** (6:$A1ED, then $A1F3) shows a message screen (7:$D141,
$D149: like the one at world 1's end, not read) and then sets the world
to 2 through the same code that ends world 1 (6:$A0F3): world 3's
overworld begins. The boss table's scene numbers (6:$9E58) do not come
into it.

## What this means for the order of work

1. Swimming (state 0F): everything in area 1 hangs on it.
2. The clock, the currents, the bombs and scenes 5, 6, 7: all in bank 4
   and 6, none of it enemy code.
3. Object kinds 1B to 1E and 1F to 22 (bank 5).
4. Kinds 9D, 4B and 4C for area 0's third line-up.
5. The jump into the lake on the overworld.
