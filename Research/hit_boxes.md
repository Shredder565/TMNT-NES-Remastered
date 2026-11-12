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

### How a swing runs in time (measured, update 30)

Recorded frame by frame in the emulator (`Research/cynes/sword_reach.py`):

- The update attack is pressed, and for one update more, the weapon sits
  at his middle and he still shows his standing (or crouching) picture.
- Then each frame of the swing lasts two updates: his picture changes and
  the weapon goes to that frame's place.
- Then, for two more updates, the weapon is back at his middle and he
  stands as usual. Only after that can he swing again.

So the forward swing takes 9 updates and the other two 11. The weapon's
box can hit for the whole of that, also while it is at his middle.

One thing the table does not say: on the crouching swing's first frame
the weapon stays at his middle (0, 0), not at (15, 0).

Before update 30 the remake ran only the frames (6 updates for every
swing, so the fourth frame of Up and Down never came), with no first
update and no last two.

### Boxes that only just meet (read from code, 6:$9AE1)

The test is not the same on both sides. An enemy to the left of (or
above) the weapon is hit when the boxes just meet; one to the right (or
below) only when they overlap by a pixel. For a 6-wide soldier and the
28-wide sword that is from 17 pixels left of the sword's middle to 16
right of it.

### Checked

Leonardo facing right, a foot soldier held still at every 2 pixels from
48 behind him to 64 ahead, at four heights, for each of the three swings:
the remake hits at exactly the places the original does (12 rows of the
same first place, last place and count; for instance the forward swing,
level with him: from 22 behind to 42 ahead).

How long an enemy is safe after a hit is in `items_and_hits.md`.

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

## When a swing can hit (12 November 2026)

Found in whole-room play (`live_play.md`): the hit test meets the weapon
where it was put one update earlier, so the first update of a swing
cannot hit, and each place of the weapon counts an update later than the
picture shows it. The kinds run by `OriginalEnemy` now use the
original's own test instead of Godot's overlap. The reach given above
is unchanged.
