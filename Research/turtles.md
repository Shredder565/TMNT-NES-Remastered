# The four turtles in rooms: what they share and what differs (USA ROM)

Worked out on 12 November 2026. Each turtle was chosen on the Start
screen in the emulator and put through the same buttons in the first
sewer (stand, walk, the three swings, crouch, jump, a swing in the air,
a ladder, being hurt); every frame's picture number ($0400), animation
($0570), the weapon object in slot 1 (its animation $0571, picture $0401,
place) and the sprite table were recorded. Facts are marked **(code)**,
**(measured)** or **(guess)**. Scripts: `Research/cynes/turtle_swings_checks.py`,
and `sword_reach.py` with $67 forced for the reach sweep.

## Shared by all four (measured)

The same picture numbers and animation numbers, on the same frames:

| Doing | Animation | Pictures |
| --- | --- | --- |
| Standing | $80 | 9 |
| Walking | $81 | 8, 9, 10, 9 |
| Crouching | $83 | 13 |
| In the air | $85 | 16 |
| On a ladder | $88 | 23, 7 |
| Hurt | $89 | 25 |

Movement was identical too: replaying each turtle's 494-frame recording
in the remake gave the same position on every frame for all four. The
graphics pages are the same (0 and 21 in the sewer).

## What differs

- **Bandana**: one colour number of the sprite colours, from 7:$D675
  (see `start_screen.md`).
- **Weapon damage**: the row per turtle at 6:$9BCB (already used).
- **The three swings**: each turtle has his own animation for swinging
  up, forward and down (code: 4:$9F48, 4:$9F50, 4:$9F4C, one byte per
  turtle), and the weapon's animation is that number plus $0C.

| Turtle | Up | Forward | Down | Weapon pictures |
| --- | --- | --- | --- | --- |
| Leonardo | $90 | $91 | $92 | 1 to 7 |
| Raphael | $99 | $9A | $9B | 24 to 30 |
| Michelangelo | $96 | $97 | $98 | 17 to 23 |
| Donatello | $93 | $94 | $95 | 10 to 16 |

## How a swing runs (code, measured)

Every animation of the turtle and his weapon is a list of picture
numbers in bank 6 (the list's address is at $8BC5 + twice the animation
number less $80; it ends in $FF, or $FE when it repeats) and a number of
updates each picture stays ($9305 + the animation number). The body's
list and the weapon's have the same length and step together. A swing's
first and last entries are the standing (or crouching) picture with no
weapon; the entries between have the weapon out, at the place the table
at 7:$E23F gives for that entry, from his position.

The first entry is one update shorter than the others (the update the
swing begins in is counted), so a swing lasts (entries x updates) - 1
updates and the weapon is first out after (updates - 1):

| Turtle | Forward swing | Updates each | Lasts | Weapon out after |
| --- | --- | --- | --- | --- |
| Leonardo | 9, 11, 35, 90, 9 | 2 | 9 updates | 1 |
| Raphael | 9, 30, 11, 35, 93, 93, 35, 35, 90, 9 | 1 | 9 | 0 |
| Michelangelo | 9, 2, 35, 97, 97, 56, 54, 9 | 1 | 7 | 0 |
| Donatello | 9, 34, 35, 9 | 5 | 19 | 4 |

Donatello's upward and downward swings are 2 updates an entry; the other
turtles use the same number for all three. For Leonardo this is the
timeline the lead measured (one update, two per frame, two more); the
remake now takes the number of updates and the entries from the ROM, so
the same code runs all four. Leonardo's crouching swing has no weapon
picture on its first frame, which is why his weapon stays at his middle
there; that is read from the weapon's list too.

Replaying the recordings: the weapon's picture was the same on every
frame of every swing for all four turtles (108, 104, 80 and 176 frames),
and its place the same except during the swing in the air, where the
original's weapon trails the turtle's rise and fall by one update (not
copied).

## Reach (measured)

Swept in the emulator as for Leonardo: a foot soldier (kind 98) held
level with the turtle at each distance, one swing, hit or not (2-pixel
steps; negative is behind him).

| Turtle | Forward | Up | Down |
| --- | --- | --- | --- |
| Leonardo | -22 to 42 | -16 to 38 | -16 to 16 |
| Raphael | -10 to 30 | -10 to 22 | -10 to 30 |
| Michelangelo | -14 to 40 | -22 to 40 | -14 to 32 |
| Donatello | -24 to 56 | -10 to 24 | -8 to 22 |

The remake's swings hit and miss at the same edges for all four turtles
and all three swings (tested at the two edges and 2 pixels beyond each),
with one exception found on 12 November 2026. Raphael's crouching swing
at its far edge (30 ahead): in the original the soldier is hit when its
place is level with the turtle's middle or anything up to 32 lower, and
missed when 2 higher; in the remake it is missed when level. So the
remake's box for that swing is 2 or 3 pixels lower at that step than
the original's. His forward swing agrees (hit from 12 higher down). The
test sweeps his crouching swing with the soldier 4 lower, where the
original's edges are the same (-10 to 30, measured) and both agree. The
other three turtles' boxes are tall enough not to show it. Not fixed
here: the swing's box belongs to the turtle's owner.

## Why Raphael's crouching swing misses at its far step (cause found 13 November 2026; not changed)

*Read from code (6:$9AD3 to $9B8F).* The original's test of an enemy's
box against the weapon's has two parts. First it asks which of the two
is higher, by the two objects' own height values. If the enemy is the
higher one it compares the enemy's bottom edge with the weapon's top
edge; otherwise the enemy's top edge with the weapon's bottom edge.
Only one pair of edges is ever compared.

When the turtle is low (crouching, or in a low swing: bit 1 of his flags
at $0540) the boxes of his own objects, slots 0 to 4, are built 8 lower
than their height values (6:$9B5D). But the "which is higher" question
is still asked with the weapon's own height value, without the 8.

At the far step of Raphael's crouching swing the weapon's place is level
with his middle, and its box is 8 high to each side, so the box reaches
from his middle down to 16 below it. A soldier whose place is level with
his middle is not the higher one (equal counts as not higher), so only
its top edge is compared with the weapon's bottom edge, and that is a
hit, though the soldier's box ends 2 above its place and so does not
reach down into the weapon's box at all. With the soldier 2 higher it is
the higher one, its bottom edge is compared with the weapon's top edge,
and that is a miss. Both are what was measured.

The remake's test (`OriginalEnemy.touches_box`) asks "which is higher"
with the middle of the box it is handed, which already has the 8 added
(`Turtle._weapon_box`). So an enemy whose place is from level with the
weapon's own height to 7 below it is taken for the higher one and tested
by the wrong pair of edges. That is the 2 or 3 pixels seen: the three
other turtles' boxes are tall enough to meet the enemy's box either way.

To put right (not done here: the swing's box and the enemies' test
belong to others): hand the weapon's own height (without the 8) to the
test as well, and use it for the "which is higher" question only. The
same holds for the turtle's own box when he crouches: `touches_turtle`
should ask the question with his height value, not the lowered middle.

## In the remake

- `Resources/AssetRipper/Sprites/TurtleSwings.json`: the 35 body pictures
  the twelve swings use, by picture number (shared; the bandana's colour
  is swapped in). `TurtleWeapons.json`: the 28 weapon pictures.
  `Leonardo.json` keeps the shared standing, walking, crouching, jumping
  and ladder pictures and gains the hurt picture.
- `RomLevels.weapon_swing` also returns each swing's picture lists and
  updates; `Turtle.gd` draws the body picture and the weapon from them.

Not done: the special weapons (shuriken, boomerang, scroll); the weapon
trailing in the air; the hurt picture was captured from a blinking
turtle and may lack a sprite.
