# World 2: where the work stands (13 November 2026, the "world2" agent)

Read first: `world2.md` (the survey), `swimming.md`, `lake.md`. This
page lists what is left, in the order the lead asked for it, with what
is already known about each. "Read from code" means the instructions
were followed in the ROM.

## Done

1. The survey (`world2.md`).
2. Swimming (`swimming.md`): 25 runs, 21301 frames, exact.
3. Of the lake's things: the clock (with its place on the strip and the
   time-up scene), the currents, the bombs and the disarming, and going
   on to world 3 after the eighth (`lake.md`): 7 runs, 7679 frames.

## Left of piece 3 (the lake's things)

- **Object kinds 1F, 20, 21, 22** (table kinds 13 to 16; made by
  4:$B786 to $B792 with animations 59, 5B, 5D, 5F, hit points FF; their
  routine is 5:$8E79 for all four by the table at 5:$823B; box table
  gives 5 x 16 for those animations). One on the first screen is a
  zigzag line from ceiling to floor at about 130 across. Not read.
- **Table kind 12**: 4:$B715 clears object slots 5 up and makes seven
  objects (kind 1B at the place with animation 57; 1C, 1D, 1E above at
  -20, -36, -52 and below at +18, +34, +50 with animation 58; flags C9,
  hit points FF); then stage routine 1 (4:$BAD0). Object routines
  5:$8DE2 (1B) and 5:$8DE5 (1C to 1E). Not read. Two places, both with
  flags CB (bit 3: kept in hand when off the screen, 4:$B69E).
- **Table kind 1F**: palette lists (7:$FE78). Not made.
- What a touch by an object does to a swimmer (his state stays 0F?):
  not read. `Turtle.take_damage` has a guess marked "(swimming)".
- The water's colours when he is hurt (4:$A992, $97E3).
- A recorder to start from: `Research/cynes/lake_record.py` takes those
  objects away every frame; leave them in to record them.
- How to get there in the emulator: `Research/cynes/world2_walk.py`
  (the jump in), or `swim_record.py`'s `place()` (any place in the lake).

## Piece 4: room enemies still fitted

Unchanged from the note this page replaces:

- **Kind 9D** (5:$8A94; hit points 40, 21 on touch). Each update, when
  not busy: blinking after a hit: both speeds 0. Nothing in the map 2
  below it: it drops (3 pixels an update to start, animation 9E, the
  shared dropping routine 5:$8CE7). Otherwise it turns to the turtle
  (5:$8381) and takes his distance across: 32 or more: speed 2 pixels
  an update forward and a launch with number 2 of the launch table
  (5:$85B2; tables 5:$8614, $8620, $862C, $8638). Under 32: a test of
  the turtle's flags against zero page $04 decides between backing off
  (a launch forward then turning round, only while the frame counter is
  $C0 or more; with a special weapon chosen, launch number 3) and
  attacking (nothing while the frame counter is under $60; else
  animation 9F, both speeds 0, wait for the animation's end). Not read:
  what $04 holds there; the launch's busy routines 5 and 8 (5:$8CD4,
  $8D13). Still on `Leaper.gd`.
- **Kinds 4B and 4C** (5:$9122, 5:$919B; 23 and 4 hit points, 15 and 5
  on touch). Not read. Still on `Crawler.gd` and `Shot.gd`.
- `Research/cynes/lineup2_record.py` records line-up 2 in world 1's
  fourth room (4B and 4C in five of six runs). Kind 9D's slot (3) has no
  place there: use world 2's area 0 at line-up level 3 (its line-ups by
  level are 0, 0, 1, 2), or world 3's rooms.
- Area 0 of world 2 has three held fights and 53 enemy places
  (`world2.md`); nothing in it has been compared in live play yet.

## Piece 5: the overworld and the end

- The overworld has kind 40 only (four places) and no van.
- **The jump into the lake**: the door at (376, 60). Measured timing in
  `world2.md` (35 frames, he vanishes; 112 more, animation E5 = pictures
  B5, B6, B7, 8 updates each; 96 more, the room is drawn). The door
  code's state 0D was not read for it. Not known: whether the remake's
  overworld turtle can reach and use that door as it is (not tried).
  After the door the turtle's first frames under water have not been
  compared (the remake's `Turtle.arrive` holds him 7 updates as for any
  door).
- **Scene 7** (6:$A1ED; bank 2 $B5B2 and $B5BE, steps in $03C2 up to
  $13): what the original shows after the eighth bomb. Not read.
  `RoomScene._on_lake_finished` goes straight to world 3.
- World 2 has no boss.

## Piece 6: live-play batches

Not started. The lake's part can reuse `swim_replay.gd.txt` (it already
runs the real room scene's turtle and `Lake`); area 0 needs
`live_replay.gd.txt` pointed at world 1 area 0 (`load_area(1, 0)`), and
a recorder that starts the emulator there (`world2_walk.py` shows how to
begin world 2 and use the lower doorway).

## Things noticed on the way

- By the code (4:$9A87) a change of row keeps the turtle's place on the
  screen for its first 8 updates and his place in the room for the other
  40; measured so for a swimmer. `live_play.md` says the reverse for the
  ladder in world 1's last room. Not looked into.
- At the gap in the lake's ceiling (about x 1232) the original scrolls
  up out of the map. Not copied.
- A script error inside one test function does not stop the suite from
  printing its last line: grep the output for "SCRIPT ERROR" too.
