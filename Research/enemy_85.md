# Enemy kind 85 (USA ROM)

Read from the original's code on 13 November 2026: its routine is at
5:$94A5 and, once it is under way, 5:$9726 (how these are reached is in
`enemy_routines.md`). Everything here is **read from code** unless it
says measured. The remake's version is `Scripts/Enemies/Swooper.gd`.

Line-up 2 has it in two of its six slots: worlds 2 and 3, and world 1's
third and fourth rooms once the line-up level is 2
(`enemy_placement.md`). Hit points 7, 18 on touch. Its box is 20 x 32.

## What it does

- **First update.** Like the fliers (5:$97FE): it faces left and flies
  left at 1.375 pixels an update, unless the screen scrolled left in the
  turtle's last update, when it goes right.
- **Flying level**, every update: the turtle's distance across and down
  is measured (both without sign), and whether he is above. The distance
  down picks the first band it reaches of 128, 112, 96, 80, 64, 48, 32
  (tables at 5:$9775); under 32 nothing happens. Each band has one slice
  of 8 pixels across: 56 to 63 for the first, 48 to 55, 40 to 47, and so
  on down to 8 to 15 for the last ($977C). Only if the turtle's distance
  across is in the slice of the band does it go. Which side he is on does
  not come into it.
- **Going:** 5.5 pixels an update downward if he is below (animation
  0F), 6.5 upward if he is above (animation 0E), and 1.75 across the way
  it already faces. It never turns.
- **After that** it has a whole pixel of speed up or down, and the
  routine then does nothing more: it flies on in a straight line until it
  leaves the screen.

So the slices lie along a line of about 2 down for 1 across: it dives
when he is on that line, whether ahead of it or behind.

Animations: 0D (pictures 8C 8D, 4 updates each) level, 0E (8F) rising,
0F (8E) diving.

## Checked against the emulator

World 1's fourth room with line-up 2 put in force (the same enemies as
world 2's first area has at its third level): six recordings (standing,
walking each way, pacing with jumps, jumping, pacing), compared by the
method of `enemy_routines.md`: 21 objects of kind 85, 1635 frames, all
agree exactly, 480 of them in a dive. The same recordings have kind 84
(the fast ledge walker, never checked before for want of a room): 10
objects, 8150 frames, all agree exactly.

Recorder: `Research/cynes/lineup2_record.py`.
