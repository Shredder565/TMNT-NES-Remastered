# Where the ordinary enemies' rules live, and how the original runs them (USA ROM)

Found on 12 November 2026 by following the object loop in program bank 5.
Addresses are bank:address. Everything here is **read from code** unless
it says "measured" (seen in the cynes emulator) or "guess". The remake's
copy of the shared parts is `Scripts/Enemies/OriginalEnemy.gd`.

## One frame

The game's main loop in a room (7:$CC4A) looks at the frame counter (RAM
$1E, which goes up by one every frame the game is not lagging):

- **odd** counter: the turtle's own update (bank 4);
- **even** counter: new enemies are made as the screen reaches their
  places (6:$80F6), then every object is updated (5:$8012), then every
  object's animation steps (6:$8005), then touches and weapon hits are
  worked out (6:$9535).

So the turtle and the enemies move on alternate frames. Measured: an
object's place on the screen is only brought into line with a scroll on
its own update, so for the one frame in between it is drawn where it
would be had the screen not moved.

## The object loop (5:$8012)

For each of the object slots 2 to 15 that holds something:

1. the object's place on the screen is shifted by how far the screen has
   scrolled (7:$F161);
2. its kind's routine runs (below);
3. if it is blinking after a hit, its safe time ($0500) counts down and
   the blink ends at 0 (5:$8049);
4. it is moved by its two speeds, if bit 6 of its flags is set (7:$EF03);
5. it is removed if it has left the screen (5:$8077): in a room, within 4
   pixels of the left, right or top of the screen, or at 192 or more down.

## Which routine a kind gets (5:$8032)

- Kinds $70 to $7F are the bosses: 5:$AA96 and the table at 5:$AABE.
- Every other kind first looks at the object's "busy" byte ($0510). If it
  is not 0 the object is in the middle of something and the byte at $0520
  picks what, from one of two tables: 5:$82E3, or 5:$9477 for kinds $80
  and up whose animation number is below $80.
- Otherwise the kind picks: the table at 5:$823B for kinds $10 to $52
  (items and things thrown), and the table at 5:$940A for kinds $80 and
  up.

The routines of the kinds placed in world 1's rooms, and of what they
throw:

| Kind | Routine | Remake |
| --- | --- | --- |
| 81 (also 8E, 8F) | 5:$97D7 | see `enemy_kinds.md` |
| 8D | 5:$978E | see `enemy_8D.md` |
| 86 | 5:$982B | see `enemy_kinds.md` |
| 98, the foot soldier | 5:$864B | `Soldier.gd`, `enemy_98.md` |
| 99, its star | 5:$8708 | `Star.gd`, `enemy_98.md` |
| 49 | 5:$9249 | `enemy_49_88_A0.md` |
| 4A, thrown by 49 | 5:$927C | |
| 91 | 5:$91C6 | |
| 92 | 5:$9288 | `enemy_92.md` |
| 93, with 92 | 5:$92F3 | |
| 94 | 5:$9983 | |
| 95, fired by 94 | 5:$99D9 | |
| 96 | 5:$99E5 | |
| AA | 5:$A34F | |
| 15, the puff of a beaten enemy | 5:$8733 | `Puff.gd` |

The full tables (kind, address) are easy to print again with the
project's disassembler; they are not copied here.

The "busy" routines shared by many kinds (table 5:$82E3, by the number in
$0520): 1 = in a jump (5:$8A3B), 2 = dropping off a ledge (5:$8A7F), 3 =
waiting for the animation on show to end (5:$832F), 4 = a thrown thing
flying until it meets a wall (5:$8A6A).

## What an object keeps

Besides what `AGENT_BRIEF.md` lists: $0410 the step it is at in its
animation, $0420 updates left before the next step, $0520 what it is busy
with, $0630 a spare timer (the soldier's stun), $0540 the slot byte of its
placement entry. Flags ($0450): bit 0 facing left, bit 1 can be touched
and hit, bit 2 blinking, bit 6 moved by its speeds. A new enemy has flags
$C2, or $C3 (facing left) if it appears on the right half of the screen.

Slots: 0 the turtle, 1 to 4 his weapon, 5 to 10 placed enemies (so six at
most at once: 7:$EED3), 11 to 14 what enemies throw (7:$EEC7: four at
most).

## Shared helpers

| Address | What it does |
| --- | --- |
| 5:$8381 | Measures how far the turtle is, across and down, and turns the object to face him unless he is less than 8 pixels away across |
| 5:$83D6 | Looks at the map a given distance *behind* the object (away from the way it faces): is there anything at all |
| 5:$83F4 | Turns round: flips the facing and reverses the sideways speed |
| 5:$8466 | Looks for a wall a given distance ahead in the way it is moving (to the right if it is not moving), plus the whole pixels of its speed, at three heights: the one asked for, 14 up and 6 up |
| 5:$8584 | Sets off forward at a speed, unless that finds a wall 10 ahead |
| 5:$84B1 | One update in the air: gravity, then walls and ceilings (below) |
| 5:$8421 | Landing: if the place asked for (4 above the object) is in a floor, raises the object a pixel at a time until it is not (31 at most), clears "busy" and both speeds |
| 5:$8101 | Makes a thrown object from a table at 5:$816D of (kind, across, up) |
| 7:$F072 | The kind of map cell at an offset from the object |
| 6:$8081 | Starts an animation; 6:$8010 steps it |

"Wall" means cell kinds 4, 0C and 0D.

### In the air (5:$84B1)

Seven sets of numbers (tables at 5:$855A to $857D); the soldier uses the
first. Each update: the pull is added to the downward speed; then

- rising: a wall `front` pixels ahead, `high` up, stops both speeds;
- falling: a wall `side` pixels ahead at the object's own height stops
  the sideways speed;
- either way a wall `side` ahead at `middle` up does the same;
- rising with none of those: a wall straight above at `head` stops the
  rise.

"Ahead" is to the right unless it is moving left, and the whole pixels of
the sideways speed are added to the distance (1 for a soldier going
right, but -2 going left, because -1.25 rounds down).

| Set | Pull | front | high | middle | side | head |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 36 | 8 | 32 | 16 | 12 | 35 |
| 1 | 48 | 14 | 42 | 24 | 14 | 42 |
| 2 | 28 | 14 | 34 | 16 | 14 | 36 |
| 3 | 28 | 12 | 40 | 24 | 14 | 40 |
| 4 | 28 | 16 | 20 | 8 | 18 | 20 |
| 5 | 40 | 14 | 28 | 12 | 14 | 28 |
| 6 | 78 | 20 | 42 | 18 | 20 | 42 |

## The map as enemies feel it (7:$C7C7)

- Cells are 16 x 16 pixels. Measured against the room data: a cell is
  whatever its top-left 8 x 8 tile is.
- The game keeps one screen's worth of cells in RAM at $0700: sixteen
  columns in a ring, looked up by (place in the room) mod 256. A place
  past the side of the screen is therefore answered with the column
  sixteen along, on the other side.
- A screen that has scrolled part of a column shows seventeen columns,
  and the two at the edges share one place in the ring. Measured: scrolling
  right, the column coming in replaces the one going out once the screen
  is 8 pixels into it. Scrolling left, the column coming in on the left is
  only taken up when it is wholly on the screen. Turning back does not
  undo either. `OriginalEnemy.screen_moved_to` follows this.
- Not followed up: what is in the ring when a room has just been entered
  with the screen part-way into a column (the remake assumes the right-hand
  rule); the same question up and down in rooms two screens tall; and
  places below the room (the remake calls them empty; the original reads
  whatever lies after the room in the ring).

## Animations (6:$8010)

An animation number picks a list of picture numbers and how many updates
each is shown (tables at 6:$8E11 and $9445 for kinds $80 up with
animation numbers $80 up). A list ends in $FF ("ended": the step number
becomes $FF, which is what a waiting routine looks for; left alone it
starts again an update later), $FE (start again) or $FD (go on to
another animation). Starting an animation that is already on show starts
it again from its first picture; several routines do that every update.

The hit box follows the animation (`hit_boxes.md`).

## Hits (6:$9913)

A weapon hit lands only on an object that is not blinking. It sets the
blink flag and a safe time of 24 updates and takes off the damage. At 0
hit points the object becomes kind 15, the puff. What else a hit does is
up to the kind's own routine, which sees the blink flag.

Every 25th puff in a room becomes an item instead of vanishing (5:$8733,
counter at $03D8, kinds 5 to 7 by the bits of RAM $45), unless bit 0 of
$45 is set. The remake does not do this.

## Chance

The enemy code read so far has no random number generator. Where a
choice looks random it comes from the frame counter ($1E). The remake
keeps a counter that goes up once a frame (`OriginalEnemy.counter`), so
the choices are made the same way, but its value at any moment is not
the original's: the original's counter stops during lag frames and has
been running since power-on.

## The side-by-side check

`Research/cynes/enemy_record.py` records the original frame by frame:
the turtle, the camera, the frame counter and every object's position,
speeds, animation and flags. `Research/cynes/enemy_replay.gd.txt` plays
the same frames in the remake: the turtle's place, the camera and the
frame counter are taken from the recording; each enemy is taken over, as
it stands, on the first frame the recording shows it; from then on the
remake's rules run it and eleven numbers are compared on every frame
(position and speeds to the 1/256 pixel, animation, step, time left in
the step, picture, facing, blinking, busy). Things an enemy throws are
made by the remake's own enemy and must turn up where the original's do.

What that does not test: the making of enemies as the screen scrolls
(that is the room scene's work), and hits by the remake's own sword (a
hit is forced on the same frame on both sides).
