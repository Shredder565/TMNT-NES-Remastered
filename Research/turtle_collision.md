# The turtle against the map: a side-by-side run with the original (USA ROM)

Worked out on 11 November 2026. The same button presses were fed to the
original (in the cynes emulator) and to the remake, in each of world 1's
six rooms, and the turtle's position was compared update by update. The
scripts are in `Research/cynes/` (`turtle_paths_emulator.py`,
`turtle_paths_compare.py`, `replay_in_remake.gd.txt`, `turtle_probe.py`).

Each run is 1000 frames: run right with a jump every 96 frames, run right
with longer jumps every 64, and run left from the far end. Enemies were
removed in the emulator and switched off in the remake.

"Measured" below means seen in the emulator. I did not find the turtle's
collision code in the ROM, so every rule here is fitted to measurements,
not read from the code.

## What was wrong, and is now changed

Before this, the remake moved the turtle as a 12 x 40 box with Godot's
own collision. The original tests a few points of the tile map instead.

| What | Original (measured) | Remake before |
| --- | --- | --- |
| Jumping up under a ceiling | Stops with his feet 28 to 30 below it | 40 below |
| Sideways in the air with his head in a ceiling's row | Cannot move until he has dropped clear (point 32 above his feet) | Could move |
| Falling past a ledge with feet 1 or 2 pixels below its top | Goes in and is put on top | Blocked by its side, falls |
| Landing | When 3 pixels into the floor; put on top | At first contact |
| Walking off a ledge's end | Keeps going about 16 pixels past the end before dropping (14 to 19 at four ends, 6 at a fifth) | Dropped when the box left the ledge, 6 past |
| The update after landing | No sideways movement | Walked on |
| Jump from a standstill with a direction held | First update goes straight up | Moved sideways at once |
| Jump pressed just before landing | Ignored | Jumped on landing |
| Room ends | Kept 20 pixels from the left and right ends of the screen | Could walk to the wall |

The remake's mover is `Turtle._move_in_room`. Its points: sideways, 6
pixels ahead at 3 and at 20 above his feet, and 3 ahead at 32 above;
upward, his middle at 28 above; landing, his middle at 3 above; standing,
his middle at his feet and 16 behind him. Both tests are made from where
he stands before either move is made, as the original's timing showed.

The practice room (F2) has no tile map and still uses Godot's collision.

## How close it is now

Two of the eighteen runs match within 6 pixels for all 1000 frames, and
several others for 600 to 870. Most of the rest follow the original until
one close call goes the other way (a ledge caught or missed by a pixel),
after which the two paths are simply different.

Known reasons the paths still part:

- **Sub-pixel position.** While the screen scrolls I cannot read the
  fraction of his X in the emulator, and the two drift by up to a pixel.
  That is enough to flip a close call at a block's corner.
- **Ceiling corners.** At the corner of a ceiling block the original
  sometimes rises one update further than the remake. It may test left
  and right of his middle on alternate updates. Not copied.
- **Side reach.** 6 pixels fits walls met on the ground. One wall met in
  the air (room 3) let him 3 or 4 pixels closer. Not explained.
- **Stuck in a corner.** Once, jumping into the corner of a wall and a
  ceiling, the original hung in the air for as long as the recording
  lasted. Not copied.
- **Landing height.** The original keeps the fraction of his Y when it
  puts him on a floor; the remake puts him exactly on it. Under a pixel.
- Two runs differ because the original started a fight there (see
  `encounters.md`) and the remake had enemies switched off.

Not compared at all yet: ladders, crouching, being hit, the weapon, and
the overworld.
