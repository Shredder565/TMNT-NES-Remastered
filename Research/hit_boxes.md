# Hit boxes, the sword, moving floors and doors (USA ROM)

Read from the game's code on 11 November 2026 and, where it says so,
checked in the emulator. This is update 26.

## Hit boxes (read from code, bank 6 $9AD3 and $9B11)

Every object has a box for touching and being hit. Its size depends on
the animation it is showing:

- A list of (half width, half height) pairs is at $8A43.
- Four tables give the pair's number for each animation number: $8835 and
  $8935 for kinds below $80 (animations $80 and up, and below), $895B and
  $89B5 for kinds $80 and up.

How the box sits:

- The turtle and his weapon: centred on the object's position, which for
  the turtle is his middle, 20 above his feet. While he crouches both
  boxes sit 8 lower.
- Enemies and what they throw: as wide as the pair says to each side, and
  from the half height above the position value down to 2 above it. Kinds
  23 to 26 and 89 are centred instead.

Two objects touch when the boxes overlap. One box serves an enemy both
for hurting the turtle and for being hit by the weapon.

Sizes (width x height of the whole box):

| What | Box |
| --- | --- |
| Turtle standing, walking, swinging | 10 x 32 |
| Turtle crouching | 10 x 22 |
| Turtle spinning through the air | 10 x 12 |
| Kind 8D | 14 x 11 |
| Kind 98 | 6 x 30 |
| Kind 86 | 24 x 10 |
| Kinds 91, 92, 4B | 8 x 32 |
| Bosses 70 and 71 | 16 x 28 (32 wide in two of their animations) |

The remake now reads these from the ROM. Before, enemies' boxes were
taken from the size of their pictures, plus 8 pixels all round for being
hit, and the turtle's was 12 x 30 at his feet. The remake uses each
enemy's starting animation only; boxes that change with the animation
(the bosses') are not followed yet.

## The sword (read from code, bank 4 $9E7E and bank 7 $E152)

There are three swings, picked by what is held when attack is pressed,
on the ground and in the air:

| Held | Swing | Frames |
| --- | --- | --- |
| Up | Upward | 4 |
| Nothing | Forward | 3 |
| Down | Downward (crouching, on the ground) | 4 |

Each frame lasts two updates. The weapon is an object of its own. A table
at $E23F in bank 7 gives, for every frame of every swing of every turtle,
where its middle is from the turtle's middle. For Leonardo, facing right:

| Swing | Places (across, down), frame by frame | Box |
| --- | --- | --- |
| Up | (11, -5) (22, -2) (15, -20) (3, -32) | 28 x 28 |
| Forward | (-6, -23) (27, -8) (23, 17) | 28 x 24 |
| Down | (15, 0) (21, 15) (13, 32) (7, 40) | 28 x 28 |

The remake had one fixed 28 x 28 box in front of him, out from the
second frame, and no upward swing. It now moves the box frame by frame
from the first frame, and Up swings upward. The swing-up pictures were
already in `Leonardo.json`.

Not read: how long an enemy is safe after a hit. The remake still counts
one hit each time the box comes to overlap an enemy.

## Moving floors (read from code, bank 4 $A4BF and $A4DE)

Kind D carries him right and kind C carries him left, 1.25 pixels an
update, unless a wall is on that side. Walking, the floor looked at is
the one under his right foot (6 to the right), or under his left if
there is nothing under the right; standing still, the one under his
middle. Update 20 had kind D from measurement and kind C marked as
unknown; kind C was not even solid in the remake. World 1's last room
has both.

## Which way a hit throws him (read from code, bank 6 $989E)

Away from the enemy; if they are level, to the left.

## Doors (read from code, checked in the emulator)

Up on the ground at a doorway starts the door. A doorway is one column
of door tiles but opens over 16 pixels: for a door at X 32, the turtle's
middle at 32 to 47 (measured), with the door tile 28 above his feet.
Doors do nothing while the screen is held for a fight. The remake
accepted 8 pixels to either side.
