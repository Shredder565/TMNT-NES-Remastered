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
| The update he lands on | No sideways movement | Walked on |
| Jump from a standstill with a direction held | First update goes straight up | Moved sideways at once |
| Jump pressed during the update he lands on | Ignored | Jumped |
| Fastest fall | Under 10 pixels an update | 12 |
| Room ends (measured, not read) | Kept 20 pixels from the screen's left and right ends | Could walk to the wall |

The remake's mover is `Turtle._move_in_room`. The practice room (F2) has
no tile map and still uses Godot's collision.

**One thing copied from measurement, not code.** Walking off a ledge, the
original starts to drop about two updates later than the rules above say
(measured at four ledge ends; a fifth dropped at once). I could not see
why in the code. The remake waits two updates.

## How close it is now

Four of the eighteen runs match within 6 pixels for all 1000 frames, and
four more for over 800. Heights now agree to a hundredth of a pixel
where the paths agree. Counting every frame, 60% are within 6 pixels (48%
with update 23's fitted rules).

Known reasons the paths still part:

- **Sub-pixel X while the screen scrolls.** When the screen starts to
  scroll the original's turtle falls about half a pixel behind the
  remake's. I have not read the scrolling code. Half a pixel is enough to
  decide whether he clips the corner of a block.
- **Lag.** Now and then the original skips an update altogether (once in
  the recordings of room 4). The remake never does.
- **Stuck in a corner.** Once, jumping into the corner of a wall and a
  ceiling, the original hung in the air for as long as the recording
  lasted. Not copied, and not understood.
- Two runs differ because the original started a fight there (see
  `encounters.md`) and the remake had enemies switched off.

Not ported yet from the turtle's code: ladders (state 9), being hit
(0E), the weapon, crouching, doors (12), the tile kinds that hurt or
carry him as the code handles them, and swimming (0F). The overworld
turtle has its own code, not read yet.
