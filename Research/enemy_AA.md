# Enemy kind AA, from the original's code (USA ROM)

Written on 12 November 2026. `enemy_routines.md` says how the routines
were found. Everything here is **read from code** unless marked
otherwise. Kind AA has two places in world 1 (both in area 3) and was a
purple block that stood still: the earlier pages never saw it appear. It
does appear in this page's recordings (why the earlier ones missed it was
not looked into). The
remake's version is `Scripts/Enemies/Diver.gd`.

Routine 5:$A34F, then 5:$A357 every update (with 5:$9CF8 for the bob
and 5:$A944 for the aim). Hit points 10, damage on touch 14. It takes no
notice of walls, floors or hits.

## The bob

It hangs in the air and bobs. Its downward speed steps through 640,
384, 160, 64, 16 (1/256 pixel an update), then the same upward from 16
to 640, then back down, and so on, changing every second update. One
whole bob moves it 14.6 pixels.

## The aim

Each update, until it has aimed: if the turtle is less than 64 pixels
away across, it takes aim at his middle. It does this once. From then on
it flies that way at 2 pixels an update, with the bob still added, and
is gone when it leaves the screen.

The aim is one of 32 directions: left or right, up or down, and one of
eight steps of a quarter turn (0 level, 7 straight up or down). The
step comes from a table (5:$A9F6) looked up by his distance across and
down in 16-pixel steps. The table itself holds the right angle for
every pair, rounded to the nearest step (checked: all 256 entries equal
the angle formula). But the look-up reads each pair of neighbouring
columns the wrong way round, so the distance across is in effect taken
16 pixels too far or too near, and the aim is off accordingly. The
remake works the angle out and makes the same swap.

The speeds for the eight steps (table at 5:$AA76 and $AA86), across
and down: (510, 0), (498, 114), (460, 222), (398, 318), (318, 398),
(222, 460), (114, 498), (0, 510).

Animation CB: pictures 9A 9B 9C 9D, 4 updates each. No sprite map was
ever recorded for it, so in the remake it is still drawn as a block.

## Checked against the emulator

Method in `enemy_routines.md`. Recordings in area 3 with the turtle
standing, walking in from each side, jumping, and with hits forced.

| Kind | Objects | Frames compared | Agree exactly |
| --- | --- | --- | --- |
| AA | 11 | 3881 | 3881 |

Thin spot: it took aim five times in all, in three of the 32 directions
(left and up at step 2, twice; right and up at step 4, twice, and at
step 5, once). The other directions rest on the code and on the table
check.

## Not done

Its picture. Nothing about how it moves is left unmatched.
