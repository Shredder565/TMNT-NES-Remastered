# The turtle against the map: a side-by-side run with the original (USA ROM)

Worked out on 11 November 2026. The same button presses were fed to the
original (in the cynes emulator) and to the remake, in each of world 1's
six rooms, and the turtle's position was compared update by update. The
scripts are in `Research/cynes/` (`turtle_paths_emulator.py`,
`turtle_paths_compare.py`, `replay_in_remake.gd.txt`, `turtle_probe.py`).

Each run is 1000 frames: run right with a jump every 96 frames, run right
with longer jumps every 64, and run left from the far end. Enemies were
removed in the emulator and switched off in the remake.

Update 23 fitted rules to those measurements. Update 24 found the turtle's
own code (bank 4, $9800 to $AA00) and replaced the fitted rules with what
the code does. "Read from code" below means that; "measured" means seen
in the emulator.

## The original's rules (read from code)

The turtle has a state number at $0510. States 0 to 3 are on the ground
(handler at $9D0C), 6 is "the floor has gone" ($A1B3), 7 and 8 are in the
air ($9FB0), 9 is a ladder, 0E is being hurt, 0F is swimming.

It tests single points of the tile map. A table at $C821 in bank 7 holds
48 points as (across, down) from his middle; his feet are 20 below his
middle. The routine at $A6AF looks up the tile kind at one point and
checks it against one of ten short lists (at $A6EC) that say what each
kind means there. Every test is made where he is now; the game moves him
by his speed afterwards.

Points are given here from his feet.

| When | Points tested | Result |
| --- | --- | --- |
| Walking | 9 ahead, at 7 up and at 24 up | Solid: sideways speed set to 0 |
| Walking | 6 to the right and 6 to the left, 1 below his feet | Nothing under either foot: state 6 |
| Standing still | His middle, 1 below his feet | Nothing there: state 6 |
| State 6 | none | Falling speed set to 0, state 7 |
| In the air, rising | His middle, 32 up | Solid: rising speed set to 0, and the jump gets no further push |
| In the air | 6 ahead at 32 up; 7 ahead at 20 up; 7 ahead at 3 up | Solid: sideways speed set to 0 |
| In the air, falling | His middle, 3 up | A floor: he is raised a pixel at a time until the point 1 up is clear; then, if the point 8 ahead and 13 up is solid, moved back 2 pixels at a time until it is not; both speeds set to 0; state 0 |

"Ahead" in the air is to the right unless he is moving left.

What counts: walls and ceilings are kinds 4, C and D. He can stand on
anything except kinds 0, 1 and 2 (empty, hurting, doorway). He lands on
kinds 4, 8, C and D, and on a ladder (kind 9) only at its top.

Speeds, also from the code: walking 2.25 pixels an update; gravity 84/256
added each update, with the whole pixels of the speed held between -7 and
9; a jump starts at 6 up; four updates in, if the button was let go, the
speed is set to 2.44 up; eight updates in, if it is still held, to 6 up
again. A jump keeps whatever sideways speed he had. Landing sets both
speeds to 0, which is why he does not move sideways on that update.

## Ladders (read from code at $A24D, checked in the emulator; update 25)

- **Taking a ladder.** Only from the ground. Up takes it if there is
  ladder at his middle, 28 above his feet. Down takes it if there is
  ladder 3 below his feet; otherwise Down crouches. He is not moved
  sideways onto the ladder: anywhere across its 16 pixels will do.
- **Climbing.** 2.25 pixels an update, up or down.
- **Up.** He climbs while there is ladder 36 above his feet. Something
  solid there stops him. Past the ladder's top he keeps going while the
  point 3 below his feet is not empty, and is then set down on the first
  thing under him. That leaves him 1 pixel into the ladder's top cell
  (measured: feet at 97 on a ledge whose top is 96) until he next lands.
- **Down.** With floor 3 below and 3 above his feet he is raised to stand
  on it. With nothing 3 below his feet and nothing at his middle he falls.
- **Left or right.** If the three points 9 pixels to that side (32, 20
  and 5 above his feet) are empty or ladder, he lets go and falls, and
  can steer. Otherwise nothing happens.
- **Jump** does nothing on a ladder.

Before, the remake pulled him to the ladder's centre line, took a ladder
only within 6 pixels of it, tested other heights, let him take a ladder
in mid-air, and let jump drop him off.

## Being hit (read from code at $A657; update 25)

He is safe for 24 updates and thrown back: 1.3125 pixels an update to
the right or 1.5 to the left, and 1 pixel up, falling under the usual
gravity with no steering until he lands. The remake had 1.5 both ways.
Which hit throws him which way was not read; the remake throws him away
from what hit him.

## What was wrong before, and is now changed

Before update 23 the remake moved the turtle as a 12 x 40 box with
Godot's own collision.

| What | Original | Remake before |
| --- | --- | --- |
| Jumping up under a ceiling | Stops once the point 32 up is inside it: his feet end 26 to 32 below it | 40 below |
| Sideways in the air with his head level with a ceiling | Cannot move | Could move |
| Falling past a ledge with feet 1 or 2 pixels below its top | Goes in and is put on top | Blocked by its side, falls |
| Landing | When 3 pixels into the floor; raised onto it; pushed out of a wall | At first contact |
| Walking off a ledge's end | Both feet (6 each side) must be past it | Dropped when the box left the ledge |
| The update he lands on | Still moves sideways; stands still for the next one | Walked on |
| Jump from a standstill with a direction held | First update goes straight up | Moved sideways at once |
| Fastest fall | Under 10 pixels an update | 12 |
| Room ends (measured, not read) | Kept 20 pixels from the screen's left and right ends | Could walk to the wall |

The remake's mover is `Turtle._move_in_room` (the move) and
`Turtle._test_room` (the tests). The practice room (F2) has no tile map
and still uses Godot's collision.

## The order of one update (read from code, update 27)

Bank 4, $9851 to $9966, then the turtle's own routine:

1. He is moved by the speeds the last update left (or the screen is asked
   to scroll instead: `Research/scrolling.md`).
2. His routine runs. In the air: gravity first. Then the buttons set his
   sideways speed. Then the map is tested where he now is, and a speed is
   set to nought where something is in the way.

So a wall stops him on the update after he reaches it, and a landing shows
on the same update as the fall that reached the floor: he is moved into
it, found there, and raised, all before the picture is drawn. On that
update he has still moved sideways; his speeds are then nought, so he
stands for one update, and the next one walks.

Walking off a ledge: the update that finds nothing under him only changes
his state (state 6). The next update changes it again to "in the air"
with no fall speed. Gravity starts the update after. Update 26 copied
this as a measured two-update wait without knowing why; it is this, and
the remake now waits the one update the code does.

## Which tiles stop which test (read from code, the tables at 4:$A6EC)

| Test | Stopped by |
| --- | --- |
| Walking into something | Kind 4 only. The side of a moving floor does not stop a walk |
| In the air: head, sides | Kinds 4, 0C, 0D |
| Landing | Kinds 4, 0C, 0D, 0F, and the top of a ladder |
| Pushed out of a wall on landing | Kind 4 only, on the side he is still moving towards. If the wall has just stopped him his speed is nought and the test looks to his right |
| Under his feet, walking | His right foot first. Only if that finds kind 0 does his left foot get a say |

A hurting tile (kind 1) hurts only when one of these tests looks at it:
see `Research/items_and_hits.md`.

## Cells, not tiles (read from code 7:$C7C7, 13 November 2026)

Every point test above looks the map up in cells of 16 x 16 pixels, as
the enemies' tests do (`enemy_routines.md`); a cell is what its top-left
8 x 8 tile is. The remake's turtle looked at single tiles until a run in
the last room showed the difference: a moving floor drawn 8 pixels thick
stops a jump 8 pixels lower than its picture. World 1's other floors and
walls are drawn in whole cells, which is why the runs below never showed
it.

## How close it is now

Update 27: all eighteen runs match the original **exactly**, to the
fraction of a pixel, on every frame compared (11365 frames). Two things
about the comparison itself had to be put right first:

- The original drops a frame now and then while it scrolls (33 times in
  one 1000-frame run). The replay now sits those frames out.
- A run is only compared up to where the original holds the screen for a
  fight: the replay runs without enemies, so the remake holds nothing.

Earlier figures, for the record: 48% of frames within 6 pixels with
update 23's fitted rules, 60% with update 24.
