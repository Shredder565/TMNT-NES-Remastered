# Enemy kind 98, the foot soldier, and its star, kind 99 (USA ROM)

Rewritten on 12 November 2026 from the original's code: the soldier's
routine is at 5:$864B and the star's at 5:$8708 (`enemy_routines.md` says
how they were found and what the shared helpers do). Everything here is
**read from code** unless marked otherwise. The remake's versions are
`Scripts/Enemies/Soldier.gd` and `Scripts/Enemies/Star.gd`.

The earlier version of this page was measurements and a fitted pattern.
Most of that pattern was wrong: there is no "rest", no fixed number of
stars, and no rule about ledges.

## Numbers

| What | Value | |
| --- | --- | --- |
| Hit points | 12 | table |
| Damage on touch | 17; a star 9 | table |
| Walking speed | 320 (1.25 pixels an update) | code |
| Jump | 1536 upward, 320 across, pull 36 an update | code |
| Dropping off a ledge | 2 pixels an update to start, then 36 more each update | code |
| Star | 768 (3 pixels an update) | code |
| Stunned after a hit | 16 updates | code |

## What it does on the ground

Every update, in this order:

1. **Blinking after a hit:** the first update it takes up its stunned
   pose (animation 98) and both speeds are set to 0; it then counts 16
   updates and jumps (as in 3).
2. **Nothing under its back foot** (12 pixels behind it, 1 above its
   position): it drops. Sideways speed 0.
3. It turns to face the turtle (unless he is less than 8 pixels away
   across) and looks at how far away he is across. Up and down do not
   come into it at all.
   - **96 or more:** it jumps: 1536 up and 320 forward. If a wall is 10
     ahead the sideways speed is 0; if a wall is 24 ahead it turns round
     first and jumps the other way.
   - **64 to 95:** if the frame counter is below 192 (three frames in
     four) it throws a star: animation 95, and nothing more until that
     animation ends (13 updates). Its speeds are not touched, so one that
     was walking slides on while it throws. Otherwise it walks.
   - **24 to 63:** it walks.
   - **Under 24:** it stops and attacks, and does nothing more until the
     animation ends. Which attack: the long punch (animation 93, 25
     updates) if the frame counter is 96 or more, else the short one
     (animation 94, 19 updates). If the turtle has a special weapon
     chosen (RAM $5B) it kicks instead: animation 91 if bit 3 of the
     frame counter is set, else 92.
4. **Walking:** only when the walking animation (90) is *not* already on
   show is it started and the speed set (320 forward; 0 if a wall is 10
   ahead). Then, every update, a wall 24 ahead turns it round.

Two things follow from 4 that look like bugs and are the original's:

- A soldier that already shows the walking animation with no speed walks
  on the spot. That is how it stands after a jump (the falling half of a
  jump puts the walking animation on) and after dropping in when it is
  made. The earlier page's "stood for 129 updates" was this.
- The walking speed is set from the way it faces at that moment and is
  not changed when it turns to face the turtle later, so a soldier can
  walk backwards.

The wall test looks to the right when the soldier has no speed, whichever
way it faces.

## In a jump (5:$8A3B)

The flight is set 0 of `enemy_routines.md`: a wall 8 ahead at 32 up (or
12 ahead at 16 up) stops the rise and the sideways speed; a ceiling 35
up stops the rise. While rising the animation is set afresh every
update: animation AB at first, the spin (97) once the speed is under 3
pixels an update, so the spin stays on its first picture. Once it is
falling at 2 pixels an update or more the walking animation is put on
(again every update). Falling, it lands when the place 4 above its
position is in a floor: it is raised a pixel at a time until that place
is clear, which leaves its position 3 pixels below the floor's top.

A jump with nothing in the way rises 131 pixels and carries it 107.5.
The 34-pixel "hop" on the earlier page was a jump that met a ceiling.

## Dropping (5:$8A7F)

36 is added to the fall speed each update. Once there is something 12
behind it and 6 below its position it lands as above.

## The star (5:$8101, 5:$8708)

- Made at the soldier's place across and 36 above it, if one of the four
  slots for thrown things is free. A star that would start in a wall (8
  above its own position) is not made.
- On its first update, which is the same update as the throw, it turns
  to the side the turtle is on and sets off at 768. So it is first seen 3
  pixels out from the soldier.
- After that it is removed when the place 4 above it is a wall (kind 4
  only), or when it leaves the screen. It does not fall.
- It can be hit by the turtle's weapon (it has 1 hit point), and it is
  removed when it hits him (`items_and_hits.md`).

## Animations (tables in bank 6)

| Number | Updates per picture | Pictures | Used for |
| --- | --- | --- | --- |
| 90 | 3 | 80 81 82 81 | walking |
| 91 | 16 | 8A | kick (special weapon chosen) |
| 92 | 6 | 8A 8B 8C 8A | kick (special weapon chosen) |
| 93 | 6 | 82 86 87 82 | long punch |
| 94 | 6 | 82 83 82 | short punch |
| 95 | 4 | 82 84 85 | throw |
| 96 | 4 | 8A 88 89 | throw (special weapon chosen) |
| 97 | 1 | 8D 8E 90 8F, repeating | spin |
| 98 | 8 | 91, repeating | stunned |
| AB | 8 | 80, repeating | rising |
| 99 | 8 | 92 93, repeating | the star |

Its hit box is 6 wide and 30 tall, but 48 wide while it punches or
kicks (animations 92 to 94): that is how its attacks reach. The remake
follows the box per animation when a ROM is installed.

## Checked against the emulator

Thirteen recordings in world 1 (areas 0, 1 and 2): the turtle standing at
four places, walking right, walking left, pacing, pacing and jumping,
jumping on the spot, and two with hits forced on the soldiers. Method in
`enemy_routines.md`.

- Kind 98: 28 soldiers, 15685 frames compared, all 15685 agree exactly.
- Kind 99: 34 stars, 2878 frames compared, all 2878 agree exactly.

## What is not matched, and why

- **The frame counter.** Which punch, and whether it throws or walks at
  64 to 95 pixels, come from the original's frame counter. The remake
  has a counter that does the same job, but in play its value is its own
  (see "Chance" in `enemy_routines.md`). In the check the recording's
  counter is used.
- **Special weapons.** The kicks and the second throw animation need a
  special weapon chosen; the remake has none yet, so they are written but
  never used and were not checked.
- **Pictures.** `Kind98.json` has 9 of the pictures (80 to 83, 86, 87, 8E
  to 90). While an animation shows one it lacks, the last picture stays
  up. The picture *numbers* agree with the original on every frame.
- **Slots.** The original has six places for placed enemies and four for
  thrown things, shared by every kind. The remake counts stars only.
- **Making and removing.** How a soldier comes to be made as the screen
  scrolls is the room scene's rule (`shots_spawning_tiles.md`), not
  covered here. Removal at the screen's edge is the original's rule.
