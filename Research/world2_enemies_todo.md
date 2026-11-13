# World 2's enemies and things: where the work stands (13 November 2026)

Written by the second enemies agent when it stopped. "Read from code"
means the instructions were followed in the ROM; nothing here that is
not marked so was checked.

## What world 2's rooms use

- **Area 0** (the dam, outside): comes up with line-up 0 (kinds 8D, 81,
  98: all written from the code). Its four level line-ups are 0, 0, 1, 2
  (`enemy_placement.md`), so at levels 2 and 3 it turns to line-up 1
  (86, AA, 91, 49: all written) and line-up 2 (84, 85, 9D, 4B).
  - 84 and 85 are written and checked (`enemy_81_8D_86.md`,
    `enemy_85.md`).
  - **9D and 4B (with its 4C) are still on the fitted scripts**
    (`Leaper.gd`, `Crawler.gd`, `Shot.gd`).
- **Area 1** (under water): comes up with line-up 17, whose six slots
  hold 00, 00, 00, D0, 01, D1: not enemies of the usual sort. Its things
  are in the table of things at fixed places (4:$ACCD, `doors.md`): 40
  entries of kinds 12 to 26. None of that has been read. The turtle's
  swimming (state 0F; the ground routine goes there when 4:$996F says
  so, first lines of 4:$9D0C) has not been read either.
- **Items**: area 0 has a whole pizza and a half; the remake now takes
  every world's items from the ROM's table.

## Kind 9D: what has been read so far (5:$8A94; not finished, not written)

Hit points 40, 21 on touch. Each update, when it is not busy:

1. Blinking after a hit: both speeds are set to 0 and nothing else.
2. Nothing in the map 2 below its position: it drops (3 pixels an
   update to start, animation 9E, the shared dropping routine 5:$8CE7).
3. Otherwise it turns to the turtle (the shared helper 5:$8381) and
   takes his distance across.
   - 32 or more: it sets its speed to 2 pixels an update forward and
     launches with number 2 of the launch table (5:$85B2; tables at
     5:$8614, $8620, $862C, $8638: an upward speed of 3 pixels an update,
     a busy routine and an animation per number).
   - Under 32: a test of the turtle's flags against a byte of scratch
     memory (zero page $04) decides between backing off (a launch
     forward followed by turning round, only while the frame counter is
     $C0 or more; with a special weapon chosen, launch number 3) and
     attacking; what that byte holds at that moment was not worked out.
     The attack: nothing while the frame counter is under $60; else
     animation 9F, both speeds 0, and it waits for the animation to end.

Not read: the launch's busy routines for this kind (numbers 5 and 8 of
the table at 5:$82E3: 5:$8CD4 and 5:$8D13), and the routine at 5:$8B05
that follows it in the ROM (another kind's).

It shares its animation numbers (AB, AC and so on) with kind 98, so the
soldier's jump code may be reused by it; not confirmed.

## Kind 4B and its 4C

Routines at 5:$9122 and 5:$919B. Not read. Hit points 23, 15 on touch;
4C: 4 hit points, 5 on touch.

## A recording to check them with

`Research/cynes/lineup2_record.py` puts line-up 2 in force in world 1's
fourth room and records six runs; kinds 4B and 4C are in five of them.
Kind 9D's slot (3) has no place in that room: world 2's first area, or
world 3's rooms (which come up with line-up 2), are needed for it. In
those recordings a kind 83 also appears where line-up 2 has none; not
looked into.
