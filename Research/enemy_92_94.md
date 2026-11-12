# Enemy kinds 92 (with 93) and 94 (with 95), from the original's code (USA ROM)

Written on 12 November 2026. `enemy_routines.md` says how the routines
were found and what the shared helpers do. Everything here is **read from
code** unless marked otherwise. These replace the fitted rules for 92 in
`enemy_92.md` (`Leaper.gd`) and for 94 in `enemy_49_88_A0.md`
(`Crawler.gd`). Both kinds are in world 1's last room (area 5).

## Kind 92 - `Pouncer.gd`

Routine 5:$9288. Hit points 24, damage on touch 16. It does not react
to a hit.

Each update on the ground, the first that applies:

1. **nothing right under it** (1 above its position): it drops, 3 pixels
   an update and 36 more each update, no sideways speed.
2. it turns to the turtle. **Less than 40 pixels away across:** it leaps:
   3 pixels an update upward, keeping whatever sideways speed it has
   (448 if it was walking, 0 if it had just thrown). In the air it is
   flight set 1 of `enemy_routines.md` (pull 48). Not if a wall is 14
   ahead at 36 or 12 up: then it stands.
3. **40 or more away:** it takes the game's one unpredictable number
   (RAM $45) and, if its low six bits are all 0 (one time in 64),
   stops and throws kind 93 (animation 86, which runs on into 8A). If
   there is no room for another thrown thing it walks instead.
4. otherwise it **walks at him:** 448 (1.75 pixels an update), set
   afresh every update; 0 if a wall is 10 ahead; a wall 20 ahead at 36
   up also stops it.

With nothing in the way the leap rises 24 pixels; it lands 3 pixels
into the floor, like the soldier.

Animations: 85 (8B 8C 8D, 4 updates each, walking), 86 (8C 8E 8F, then
8A), 8A (8F, held), 88 (90, in the air).

## Kind 93, what 92 throws - `Boomerang.gd`

Routine 5:$92F3. Made at the thrower's place, 34 above it, facing the
thrower's way, with speed 1024 (4 pixels an update). Every update 16 is
taken off that speed, so it slows, turns and comes back (it goes about
126 pixels out). After its first 6 updates it is removed as soon as it
is less than 4 pixels across from the kind 92 that threw it. Height
does not come into it, and a wall does not stop it. Hit points 7, damage
6. It is used up by hitting the turtle (`items_and_hits.md`).

If the thrower has gone, or has leapt over it, it flies on and leaves
the screen.

## Kind 94 - `Gunner.gd`

Routine 5:$9983. Hit points 24, damage on touch 18. It never turns to
the turtle and does not react to a hit.

Each update, the first that applies:

1. **nothing 12 behind it, 1 above:** it drops at 2 pixels an update and
   24 more each update, keeping its sideways speed, and lands 4 pixels
   into the floor. Not if a wall is 14 ahead.
2. **the turtle less than 32 pixels above or below it** (his middle
   against its position), **and bit 5 of the frame counter clear** (32
   frames in every 64): it stops, shows animation 1F and fires kind 95.
   This is done again every update, so it fires one an update until the
   four places for thrown things are full.
3. otherwise it **walks** the way it faces: 352 (1.375 pixels an
   update), set afresh every update, 0 if a wall is 10 ahead; a wall 12
   ahead turns it round.

Animations: 1E (97 98 99, 4 updates each), 1F (97 9A).

## Kind 95, what 94 fires - `Missile.gd`

Routine 5:$99D9. Made at the gunner's place, 17 above it, facing its
way; flies level at 640 (2.5 pixels an update) until it leaves the
screen. Walls do not stop it. Hit points 24, damage 22. Not used up by
hitting the turtle.

## Checked against the emulator

Method in `enemy_routines.md`. Fourteen recordings in area 5, on both
its floors, some with hits forced.

| Kind | Objects | Frames compared | Agree exactly |
| --- | --- | --- | --- |
| 92 | 13 | 13215 | 13215 |
| 93 | 1 | 306 | 306 |
| 94 | 4 | 3140 | 3140 |
| 95 | 129 | 10880 | 10880 |
| 96 | 38 | 21077 | 21077 |

Thin spots: kind 92 threw only once in all the recordings, so kind 93
rests on one flight; kind 94 never walked off a ledge, so its drop is
read from code but not checked; kind 92's drop was seen for 149 frames.

## What is not matched, and why

- **Kind 92's throw is truly unpredictable.** RAM $45 is stirred by a
  loop the game runs for as long as each frame has time left over
  (7:$C395), so its value depends on how busy every earlier frame was.
  The remake rolls a number of its own with the same one-in-64 odds. In
  the check the recording's value is used (the value the frame before
  left behind).
- **Kind 94's firing** follows the frame counter (see "Chance" in
  `enemy_routines.md`): the rhythm is the original's, its phase is not.
- **Area 5 is two screens tall.** How the original's map look-up wraps up
  and down there was not worked out; the remake looks at the real map.
  The recordings agree all the same.
