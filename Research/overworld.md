# The overworld: what moves in the original (USA ROM, world 1)

Worked out on 12 November 2026 by recording the emulator (cynes) frame by
frame under scripted buttons, replaying the same buttons in the remake,
and reading the ROM's code where the recordings needed explaining. Each
fact is marked **(code)**, **(measured)** or **(guess)**. Speeds are in
1/256 pixel per update; an update is two frames. Addresses are
bank:address. The emulator script is `Research/cynes/overworld_checks.py`.

## What was compared

Six recordings on world 1's overworld, 226 to 1500 frames each: two of
walking in all four directions with stops, turns, walls and two buttons
at once; and four with enemies on screen (kind 9A once, kind 9B once,
kind 40 twice). For each frame: the turtle's picture number ($0400),
position, animation number ($0570); every other object slot's kind,
position, picture, flags and speed; the camera; the 32 colour numbers at
$059F; the two graphics pages ($27, $28).

## What animates or moves

| Thing | In the original | In the remake before | Now |
| --- | --- | --- | --- |
| The turtle's walk | 4 steps per direction (below) | 2 steps, never restarting | as the original |
| The turtle's bandana | the playing turtle's colour | Raphael's red for Leonardo | from the ROM's table |
| Kind 9A, 9B (rollers) | drive round the streets | stood still, purple blocks | as the original (below) |
| Kind 40 (soldier) | walks at the turtle | stood still | as the original (below) |
| Enemies appearing | come in at the screen's edges | all there from the start | as the original (below) |
| Background, colours | nothing: no colour of the list at $059F and neither graphics page changed in 3,800 recorded frames, and standing still for 600 frames no pixel of the map changed (measured) | nothing | nothing |
| The van | not in world 1: its places use only kinds 40, 9A and 9B (code: placement table 6:$AC8F, line-up 16) | - | - |
| The turtle's attack (B) | he swings his weapon on the overworld (code 4:$AA25: state 1, animations $C6 to $C8) | missing | as the original ("The fight" below) |
| Touching an enemy | hurts: kind 40 takes 10, kinds 9A and 9B take 128, all of a turtle's energy (code: damage table 6:$8B05) | nothing | as the original |
| Kind 9C, 42, AC | not placed in world 1 | stand still | unchanged |

## The turtle's walk (measured; code 4:$AA44, 4:$A634)

His state routine sets an animation number from what is held: standing
$C3 (down), $C1 (up), $C5 (right and left); walking $C2, $C0, $C4. The
animation is only set when it differs from the one running, so it starts
again when he stops or turns between across, up and down, and carries on
through a turn from left to right.

Pictures ($0400): right 148, 149, 148, 147; up 151, 152, 151, 150; down
145, 146, 145, 144. The first picture stays 7 updates, each later one 8.
Standing shows 148, 151 or 145. Picture 146 is 144 mirrored and 152 is
150 mirrored; 147 and 149 are different drawings. Against a wall he
walks on the spot. Left is the right pictures mirrored.

The remake had only two pictures per direction (one of them filed under
the wrong number) and kept counting across stops. Its sprite map now
holds all nine pictures. Replaying a 324-frame recording (walls, stops,
turns): his position is the same on every frame and his picture on all
but the 18 below.

Not matched: with Up and Down held together the original shows the
walking-up pictures without moving, the remake stands (cannot happen on
a real pad); and once, walking on the spot against a wall, the original
held a picture two frames longer than its usual 16.

The original acts on a button one frame after it is pressed (measured);
the replay allows for that.

## The four turtles' colour (measured, code)

The turtles share their pictures. The bandana is one colour of the
sprite colours (place $12 of the list at $059F), set from four bytes at
7:$D675: $12 blue, $16 red, $27 orange, $14 purple for turtles 0 to 3.

## The screen on the overworld (measured)

The picture is 256 by 240 and scrolls only when he walks while his place
on it is beyond a mark: right at 126 or more across, left at 124 or
less, up at 116 or less, down at 118 or more. Otherwise he moves on the
screen. When world 1 begins he stands at 144 across and 120 down, so the
first step right scrolls at once. Coming out of a room the screen is put
where the door's record says (measured for the first sewer's ladder:
camera (16, 176), turtle at (128, 120) on it).

The remake keeps this as a number (`RoomScene.overworld_screen`), which
matched the original's camera on every frame of all four enemy
recordings. It is used for the enemies. What the remake shows is still
its own centred view with the HUD strip below it, which is not how the
original lays the overworld out (its HUD overlaps the map); that was not
part of this work.

## Enemies coming and going (measured; code 5:$8077)

No enemy is there when the map comes up, at the start of the world or
out of a manhole (measured: none after 600 frames standing still).
One is made when the screen's scrolling brings its place 8 pixels inside
any of the four edges. It starts one scroll step away from its place,
against the way the screen moved (2 pixels, as if moved with the screen
twice), faces the turtle, and acts in that same update. It is removed
when its place on the screen is less than 4 or more than 251 either way
(code). The turtle is updated on one frame and everything else on the
next, in turn (code 7:$CC4A).

## Where the enemies' routines are (code)

Not known before. The loop at 5:$8012 goes through object slots 2 to 15
every update: the kind's routine, the blink timer, the move (7:$EF03,
only if bit 6 of the flags is set), then the off-screen test. The
routine is chosen like this (5:$8032):

- kinds below $70: the table at 5:$823B, entry (kind - $10);
- kinds $70 to $7F: the boss dispatch at 5:$AA96;
- kinds $80 and up: the table at 5:$940A, entry (kind - $80), unless the
  animation number's top bit is set, when it goes through 5:$8212.

A state number above 0 ($0510) goes to a second table instead (5:$82D1,
5:$9465). From those tables: kind 9A is at 5:$877E, 9B at 5:$87C0, 9C at
5:$87F8, 40 at 5:$8907 (and, for whoever does them next, 81 at $97D7, 8D
at $978E, 98 at $864B, 86 at $982B, 91 at $91C6, 92 at $9288, 94 at
$9983, 96 at $99E5, 49 at $9249, AA at $A34F).

Helpers they use: 7:$F062 and 7:$F06A set the across and down speed (Y
whole pixels, A the fraction); 7:$F072 gives the kind of map cell at the
enemy's place plus (A across, Y down); 5:$8381 measures the distance to
the turtle (across in $00, down in $01, $02 = 1 when he is higher) and
turns the enemy to face him when he is 8 or more away across; 7:$D104
sets the animation.

## Kinds 9A and 9B, the rollers (code 5:$877E, 5:$87C0; measured)

They keep going the way they are going until the way is blocked, then
try the next way round: 9A right, up, left, down; 9B right, down, left,
up. If the next way is blocked too they stand one update, turned round,
and start again.

Before a move the routine looks at two points, from the enemy's own
position: right (16, -24) and (16, -4); left (-16, -24) and (-16, -4);
up (8, -28) and (-8, -28); down (8, 2) and (-8, 2). A wall (cell kind 4)
or water (kind 12) at either stops that move. The point is worked out on
the screen in one byte, so a point above the top of the screen is looked
up 256 pixels lower (measured: this is why the 9B that comes in near the
top edge can drive right under a wall line before turning down).

Speeds: 544 across, 576 up and down; while the turtle drives the van
($0606) 608 and 640. Animations: $B0 up (pictures 135, 136), $B1 down
(137, 138), $B2 across (139, 140); the first picture stays 7 updates and
the second 9 (measured). Hit points 48, touch damage 128.

Replay against the original: kind 9B's position, facing and picture
were the same on all 424 updates of a 900-frame recording (three times
round its block); kind 9A's on 99 of 104 updates (the other 5 follow a
dropped frame, where the comparison slips by one).

## Kind 40, the soldier (code 5:$8907; measured)

Each update it measures the distance to the turtle. If he is 10 or more
pixels away across it walks that way (the way it faces) unless the point
(12, -6) ahead is blocked; failing that, or when he is closer than 10
across, it walks up or down toward him if he is 10 or more away that
way, unless the point (0, -19) above or (0, 1) below is blocked. A
blocked up or down falls back to across. Otherwise it stands. Speed 544
every way. Animations $6E up (pictures 199, 200), $6F down (197, 198),
$70 across (201, 202): 3 updates, then 5 (measured). Hit points 6, touch
damage 10.

Replay against the original: position and facing the same on all 346
updates of one recording and 280 of 286 of the other (again a slip after
a dropped frame); the picture on about 85% of them.

Both recordings include an enemy standing still for a single update in
mid-walk; the rules above produce the same stop at the same place.

## The fight (added 12 November 2026, second pass)

Recorded: the attack in all four directions for each of the four
turtles; a soldier walking into the turtle and being hit; a soldier
standing next to him, missed by one swing and hit by another; and a
roller driving past him while he swings. `Research/cynes/overworld_fight_checks.py`
and `overworld_fight_replay.gd.txt` are the scripts.

**The attack** (code 4:$AA25, 7:$E115; measured). A new press of B puts
him in state 1 with animation $C7 (facing down), $C6 (up) or $C8 (right
and left), from the four bytes at 4:$AA8E. Their pictures are 184, 186
and 185, in the animation lists every object uses (bank 6: the list's
address at $8BC5 + twice the animation number less $80, updates per
picture at $9305 + the animation number): two pictures of 3 updates. As
with every animation the first picture is one update short, so the
weapon is out for 5 updates (10 frames) and he is held for 6. He can
move again on the 7th.

The weapon is object slot 1. Its animation comes from the 16 bytes at
7:$E135 (four per turtle, by direction: down, up, right, left): Leonardo
$B1 $B0 $B2, Raphael $B4 $B3 $B5, Michelangelo $B7 $B6 $B8, Donatello
$BA $B9 $BB. Where it is, from his position, is in the table at 7:$E2DD:
one pointer per weapon animation from $B0, then (across, down) for each
picture. Leonardo: down (-2, 18), up (4, -17), across (13, 1). Donatello
reaches 17 across; Michelangelo's moves between its two pictures. The
across number is mirrored by the way he last walked sideways, for up and
down attacks as well (his own up and down pictures are mirrored by it
too). The weapon's box is centred there; half its size comes from the
usual box tables (6:$8835, 6:$8A43) by the weapon's animation: 3 x 4 for
most, 6 x 3 for Donatello across. The weapons are single 8 x 16 sprites
in sprite colour group 3.

Pressed while he walks, the attack does not stop him: he goes on at
walking speed the way he was going for as long as it lasts (measured
going right over open ground; what a wall does then was not looked at -
the remake stops him at one).

**Boxes** (code 6:$9AD3, the same routine as in rooms). The overworld
turtle's own box is 8 x 8, centred on his position. An enemy's is its
half width to each side and from its half height above its position down
to 2 above it: kind 40 is 6 wide and 12 tall, the rollers 24 wide and 18
tall. Two boxes meet when they overlap; edges that only touch count when
the enemy is to the left or above (code 6:$9AE1).

**Hitting** (measured). A weapon hit takes the turtle's weapon damage
(the same per-turtle row as in rooms, 6:$9BCB; Leonardo 7). Kind 40 has
6 hit points and goes at once: it turns into object kind $2C, a burst
that shows for about 46 frames (the remake shows its usual puff, 18
frames). A roller has 48; after a hit it blinks and cannot be hit again
for 24 updates, and it keeps driving.

An enemy that is touching the turtle's own box when he attacks is hit as
if by the weapon (measured once: a soldier standing against him was
finished on the first frame of a downward swing whose weapon box did not
reach it). This is a reading of one recording, not of the code.

**Being hurt** (measured). An enemy touching him takes its touch damage
off his energy (kind 40: 128 to 118; a roller: all of it) and he blinks,
safe, for 24 updates. He is not thrown back. If he was attacking and the
enemy could not be hit (a roller within its 24 updates), he is hurt just
the same and the attack stops.

**Replay against the original**, same buttons, frame by frame:

| Recording | Frames | Result |
| --- | --- | --- |
| The attack, four directions and while walking, each turtle | 320 x 4 | his position the same on every frame; the weapon's picture and place the same on all but the first and last frame of each swing (the remake is one frame early at both ends) |
| Soldier walks into him, then is hit | 420 | his energy the same on every frame; the soldier goes 2 frames later than in the original |
| Soldier beside him: a miss, then a hit | 664 | the soldier alive and its hit points the same on every frame |
| Roller drives past while he swings | 450 | the roller's hit points the same on every frame; the same 51 frames of blinking after it touched him |

## Kind 9C, and what kinds 42 and AC are (added 12 November 2026, fourth pass)

None of the three is placed in world 1. Kind 9C is on world 3's
overworld (four places), kind 42 on world 4's (fifteen) and kind AC on
world 5's (eleven) (code: placement table 6:$AC8F).

**Kind 9C** (code 5:$87F8; measured) is a roller that comes after the
turtle, with the rollers' pictures, speeds and tests. It only decides
during 8 frames of every 16 (bit 3 of the frame counter, $1E); in
between it keeps the speed it has. Deciding: it turns to face him when
he is 8 or more pixels away across. If he is that far away, then facing
right it tries right and, whatever came of that, left; facing left it
tries left; if left is free it goes left. Failing that, if he is 8 or
more away up or down it tries up when he is higher, and down when he is
lower or up is blocked. Otherwise it stands. Trying left straight after
right means it goes right only when left is blocked: that is what the
code does, and the recording agrees (with the turtle above it and a
wall in the way it drove up and down on the spot for seconds).

Replay against the original (world 3, 800 frames, the turtle walking
right, up, down and left near it): the turtle and the screen corner the
same on every frame, and kind 9C's place and facing the same on all 770
frames it was there (within the 2 pixels by which the original's own
numbers jump while the screen scrolls). Hit points 48, touch damage 128,
as the other rollers.

In the recordings an enemy's speed reads 0 for one update when its box
first meets the turtle's. Leaving that out matches every frame; putting
it in does not, so it is not copied.

**Kind 42** (code 5:$89CC; one recording in world 4) is not a ground
enemy. It comes in flying, 3 pixels an update up and across toward the
turtle, and at the same moment an object of kind 43 appears at its place
on the ground. About 50 frames later the kind 43 turns into kind 52 (a
burst, animation $AE; code 5:$8A0F does this when 43's own animation
ends) and is gone 44 frames after that; the flyer leaves the screen.
So it looks like an aircraft dropping a bomb at the spot where it came
in. Hit points 0, touch damage 0 for kind 42 itself; what the bomb or
burst does to the turtle was not measured.

**Kind AC** (code 5:$A59F, not recorded) allows only two of itself at a
time (a count at $03EB), is put at the top of the screen in a column 32
pixels wide worked out from where the screen is, moves down at 2.5
pixels an update, and then becomes another kind (through 5:$8644). With
world 5's message about a search light on ground level, it is probably
that light.

The remake now runs kind 9C (`Scripts/Enemies/OverworldEnemy.gd`).
Kinds 42 and AC still stand where they are placed: each is several
objects working together (flyer, bomb, burst; light and what it turns
into) and needs its own recordings in worlds 4 and 5, which the remake
cannot be played through to yet.

## Going through a door (added 12 November 2026, third pass; measured)

Recorded frame by frame: walking onto the first manhole, standing in the
sewer, climbing back out. For each frame: the "inside" flag ($5C), the
play routine's step ($34) and hold counter ($3D), the turtle's state,
animation and picture, the colour list, and the picture itself.

**Onto a manhole.** There is no picture of the turtle climbing down. On
the frame his step reaches the manhole the game is already inside
($5C = 1), his picture number is 0 (he is not drawn) and the screen is
black. The room is then drawn in from the top, one row of tiles (8
lines) a frame, 24 frames for the sewer's 24 rows. The colour list does
not change: it is the drawing that is gradual, not a fade. Everything
then stands still for 16 frames ($3D counts down). Two frames later his
state becomes $0B and then $0C (on a ladder), and 7 frames after the
hold ended he is first drawn, hanging on the ladder at the top of the
screen (animation $88, picture 23). He does not move until a button is
pressed: he stayed there 3 seconds in the recording. From manhole to
first sight of him: 49 frames.

**Up a ladder and out.** At 17 lines from the top his state goes $12,
$0D, and the game is on the overworld: black, the map drawn in from the
top over 32 frames (its picture is 30 rows), the 16-frame hold, and he
is drawn the frame after, standing facing down (picture 145) at the
place the door's record gives. 51 frames in all.

The remake had neither: doors changed sides at once (with a 10-frame
rest on the overworld). `RoomScene.use_door` now shows it: black, the
rows drawn in one a frame (24 in a room; on the overworld 32 frames, of
which the remake's shorter view shows the first 24 rows), the 16-frame
hold with nothing moving, and the turtle appearing 7 frames later in a
room and 1 on the overworld. In a room he arrives hanging on the ladder
where the door leaves him on one, as before. The study keys (F3, F4, F7)
still change maps at once.

Not looked at: doors between two rooms, and doorways that are not
ladders (assumed the same); sounds.

## Still different from the original

- Losing all his energy on the overworld only puts him back at the
  world's start after a moment (the placeholder; what the original does
  is the next piece of work).
- A beaten soldier leaves the remake's usual puff, not the original's
  longer burst (kind $2C).
- No sounds.
- Kind 9C (it chases the turtle, code 5:$87F8) and kinds 42 and AC stand
  still. None is placed in world 1.
- The remake's view of the overworld is centred on the turtle with the
  HUD below; the original's is 240 lines tall, scrolls by the marks
  above and has its HUD over the map.
- The rollers' faster speeds are in, but nothing drives a van yet.
- Whether a roller comes in facing left when the turtle is to its left
  was not seen (guess: it faces him, like the soldier).
