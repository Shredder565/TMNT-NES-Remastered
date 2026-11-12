# Enemies and thrown things touching the turtle (USA ROM)

Worked out on 12 November 2026: read from the code at 6:$9535 (the
touch pass), 6:$9AD3 and 6:$9B11 (the box test), 6:$9896 (what a touch
does) and 4:$A657 (the turtle being thrown), then checked by sweeping
enemies round the turtle in the emulator
(`Research/cynes/touch_sweep.py`, `touch_replay.gd.txt`). The remake's
copy is `OriginalEnemy.touches_box` and `Turtle.touch_box`.

## When (read from code)

Touches are worked out once an update, on the enemies' frame, after
every object has moved and its animation has stepped. Objects in slots
5 to 15 are tried in order. Left out: an object without the "can be
touched" flag; kind 49 while it waits (animation 50); the puff; and a few
kinds listed at 6:$963F that world 1's rooms do not use.

## The boxes (read from code)

- The turtle's: his middle (20 above his feet), with the half width and
  half height of the animation he shows. 8 lower while he crouches.
- An enemy's, or a thrown thing's: as wide as its animation's pair says
  to each side of its position; from its half height above the position
  down to 2 above it.

The test is not the same on both sides (the same routine as the sword's,
`hit_boxes.md`):

- across: an enemy whose position is left of his middle touches when its
  right edge reaches his left edge (boxes that just meet count); one
  level with or right of his middle only when its left edge is inside his
  right edge by a pixel;
- down: one whose position is above his middle touches when its bottom
  edge reaches his top edge; one level with or below only when its top
  edge is a pixel inside his bottom edge.

So for a 6-wide soldier and the standing turtle (10 wide): from 8 pixels
left of him to 7 right.

## The turtle's box by what he is doing (measured)

| Doing | Animation | Box |
| --- | --- | --- |
| Standing | 80 | 10 x 32 |
| Walking | 81 | 10 x 32 |
| Crouching | 83 | 10 x 22, 8 lower |
| A jump, and the first 8 updates of a held one | 85 | 10 x 32 |
| A held jump from its second push on (the original's state 8) | 87 | 10 x 12 |
| Swinging in the air | 91 | 10 x 32 |

Before this the remake gave him the small box for the whole of every
jump and fall. It now has it only in the high part of a held jump.

## What a touch does (read from code, checked)

- Nothing while he blinks, and nothing with the power item running (the
  enemy is then hit instead, through the weapon's pass).
- Otherwise he loses the kind's damage (table at 6:$8B05), blinks for 24
  updates and is thrown: to the right at 336 if the enemy's position is
  left of his, else (level too) to the left at 384; upward at 258.
- Measured with an enemy held on him: he is hurt every 48 frames, in the
  original and in the remake alike.
- The enemy takes no notice: it is not stopped, turned or removed. (A
  bit is set in its $0530 that no routine read so far looks at.)
- Kinds 99 and 93 (the star and what kind 92 throws) are removed when
  they hurt him. A star that touches him while he blinks flies on.

Damage, checked in the sweep: 98 17, 99 9, 81 9, 8D 7, 86 11, 49 17, 4A
14, 91 18, 92 16, 93 6, 94 18, 95 22, 96 9, AA 14.

## The sweep

One object was held at an offset from the turtle, frame after frame,
frozen (marked busy with nothing to do) and showing one animation, for
18 kind-and-animation pairs: 98 walking, punching and spinning; 99; 81;
8D; 86 crawling and swooping; 49 walking and waiting; 4A; 91; 92; 93;
94; 95; 96; AA. Each with the turtle standing, crouching, walking and in
a held jump. Offsets: three pixels to each side of every edge the rule
predicts, plus points well inside and outside. 2376 trials, 1191 of them
hurt him.

- The rule above, worked from the ROM's tables, gives the right answer
  for all 2376.
- The remake's test (`OriginalEnemy.touches_box`, with the remake's own
  enemy objects and boxes) gives the right answer for all 2376.

Trials that put the object off the bottom of the screen are counted as
"no touch": the original removes it there.

## What changed in the remake

- Kinds run by `OriginalEnemy` no longer use Godot's overlap for
  touching. They make the original's test once an update, in whole
  pixels. (Godot counts boxes that meet on every side, tests every frame,
  and sees the fraction of a pixel.)
- The star, kind 4A, kind 95 and kind 93 go through the same path as
  enemies, so the power item protects against them too and destroys
  them.
- The turtle's small box only in the high jump (above).

## Not covered

- Kinds still run by the fitted scripts (`Crawler.gd` and the rest) and
  the two bosses still use Godot's overlap.
- The sweep holds things still. Whether the remake's turtle shows the
  right box at the right moment in play was checked afterwards: on all
  7390 frames of `live_play.md`.
