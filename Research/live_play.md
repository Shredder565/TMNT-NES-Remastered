# Whole-room play, frame by frame against the original (USA ROM)

Done on 12 November 2026. The earlier enemy checks fed the turtle, the
camera and the frame counter from the recording. This one does not: the
real room scene is given the same buttons as the original and everything
is compared on every frame. Scripts: `Research/cynes/enemy_record.py`
(set "live") and `Research/cynes/live_replay.gd.txt`.

## How the two are lined up

- The original is started by putting the turtle in a room (as all the
  recordings here are). The room takes about 40 frames to come up; it is
  running from the first frame an object changes, which is an enemies'
  frame. The remake's room is loaded and its first frame is made to be
  that frame.
- The frame counter: the remake's counter now follows the turtle's own
  frame count (`OriginalEnemy.counter`), so enemies' frames are the even
  ones and his the odd ones, as in the original. For the comparison it is
  set once, at the start, to the original's value. In play it starts
  wherever it starts: the original's has been running since power-on.
- The original acts on buttons one frame after the emulator is given
  them, so the remake gets each frame's buttons a frame late.
- While its room comes up the original's turtle cannot be touched and,
  if hit, stands frozen for 6 updates. That is not copied: in both the
  turtle is kept safe for the first 70 frames, and the buttons start
  after that.
- A frame the original drops (its counter stands still) is sat out.

## What is compared

Every frame: the turtle's position to the 1/256 pixel; his energy; his
box (the box of the animation the original shows against the remake's
`touch_box`); and the set of all enemies and thrown things, each with
its kind, position to the 1/256 pixel, animation and hit points.

## Result

Ten runs through all of world 1's rooms but the second: standing;
walking right; walking and swinging every 30 frames; walking and
jumping; standing and swinging among soldiers; walking left and
swinging; and so on. 7390 frames.

| What | Frames that agree |
| --- | --- |
| The turtle's position | 7390 |
| His energy | 7390 |
| His box | 7390 |
| Every enemy and thrown thing | 7389 |

The one frame is a dropped frame in the last room: the emulator's
picture of memory was taken half-way through the original's update (a
hit already worked out, in the remake's terms a frame early).

## What had to be put right to get there

Found by chasing the first difference each time.

- **Sword hits** (`OriginalEnemy.update_now`, `Turtle.weapon_box_for_enemies`).
  The original works out the weapon's hits once an update, on the
  enemies' frame, and only *afterwards* puts the weapon in its place for
  the frame of the swing (7:$CC7E: the hit pass, then 7:$E145). So a hit
  always meets the weapon where it was put an update earlier, and on the
  first update of a swing there is nothing to hit with. The weapon keeps
  its place on the screen meanwhile, so it moves with a scrolling screen.
  The remake used Godot's overlap, which hit an update early and only
  when a box first came to overlap (the original hits again every 24
  updates for as long as the boxes overlap). The kinds run by
  `OriginalEnemy` now use the original's test; the reach measured for
  all four turtles still holds.
- **A swing goes on through a hit**, and one can be started while he is
  thrown. The remake cancelled it.
- **The throw.** Gravity acts from his first update (the remake gave him
  one update at full speed first); the map is felt at the moment of the
  hit, so a turtle against a wall is not thrown into it; and he can act
  on the update after he lands (the remake waited one more).
- **At the screen's side** he is held by his whole pixels and the
  fraction runs on.
- **Enemies made as the screen scrolls, and when the room comes up:**
  `enemy_spawning.md`.
- **Touching:** `touching.md`. In play the box is right on every frame.

## What cannot line up, and what was not tried

- **Kind 92's throw** is rolled from a number no replay can know
  (`enemy_92_94.md`). It did not come up in these runs; when it does the
  two will part.
- **Dropped frames.** The original drops frames when it is busy (often
  in the last room). The remake never does, so in real time it runs
  slightly ahead there. In the comparison they are sat out.
- **The room coming up** (the first 40 frames, and the turtle's odd
  state for the next few) is not copied.
- **Items.** Picked up in two runs with the same effect on his energy;
  nothing else about them was compared.
- Not tried: the second room and its boss, held fights, doors, ladders,
  crouching and upward swings, the other three turtles, death.

## A second, rougher batch

Ten more runs with more going on: walking left and swinging through the
first sewer; the second room up to its boss; a mix of walking, crouching
swings, jumps to the left with a swing, and upward swings; jumping
through the fourth room. 7590 frames.

Three more things were put right from these: something thrown while the
screen scrolls starts one scroll step out from the thrower (like an
enemy made at the screen's edge); the turtle's box shrinks on the update
he crouches but drops 8 only from the update after; and (above) a swing
goes on through a hit.

Five of the ten runs then agree on every frame, or all but a handful.
What is still different in the others, each found as the first
difference of a run and not put right:

- **Swings carried into the air or started just before a fall.** In the
  mixed runs the original's turtle was able to start a forward swing a
  few frames after an upward one as he walked off a ledge, where the
  remake's upward swing was still running; and a crouching swing with
  jump pressed goes on in the air in the original, box lowered and all.
  The swing's rules in the air need a look by whoever owns the turtle.
- **Up held on the ground** in the first sewer: the original's turtle
  goes to states 0B and 0C and stays put; the remake's moved upward. Not
  looked into.
- **The last room's screen does not follow a jump up.** The original's
  camera stayed on the lower floor throughout; the remake's moves up with
  him, and the enemies near the floor are then removed as off the
  screen. How the original scrolls up and down was not read.
- **The first sewer's held fight.** For 8 frames as the screen stops at
  508 a soldier punches in the original and walks in the remake: its
  distance to the turtle is a pixel out while the screen is being held.
- In the fifth room one run starts with the remake's turtle 32 pixels
  higher than the original's (the remake's way of standing him at a
  place lifts him out of a floor there); he drops, and after 31 frames
  the two agree for the rest of the run.

After a first difference the two runs are no longer the same game, so
the counts for these runs say little: over the whole batch the turtle
agrees on 5991 frames, his energy on 6676, his box on 6223, and the
enemies on 6166 of 7590.

## Follow-up (12 November 2026, later)

The open differences of the second batch were gone through. Read from
code or measured, and now in the remake:

- **The screen up and down** (read from 4:$9906, measured on the last
  room's ladder). A room taller than one screen is shown a whole screen
  at a time and the screen never follows a jump. It changes when the
  turtle's middle is less than 11 from the screen's top while he climbs
  with Up held, or 172 or more down it. Every object is cleared; the
  screen moves 4 pixels an update for 48 updates; he is held meanwhile
  and ends 32 pixels on. The remake centred the screen on him. Guess in
  the remake: the new screen's enemies come up as when a room does.
- **Up at a ladder.** "States 0B and 0C" are taking a ladder and being on
  one; there is a ladder at that spot of the first sewer. What differed
  was timing: after taking a ladder he pauses, and like everything else
  he is moved by what the update before decided, so letting go of Up or
  Down takes one more step. Both are now so.
- **Swings.** For two updates after a swing ends a press of attack is
  thrown away: a new forward swing can start 11 updates after the last
  began, an upward or downward one 13 (measured by pressing again at
  every delay). A downward swing keeps him in the crouching box, lowered,
  also in the air; when it ends the low box stays one update more, then
  the full box 8 lower for one. Any swing's box outlasts it by one
  update, and a swing made in a high jump uncurls him for the rest of
  it.
- **Kind 92's throw** did come up once the runs were repeated: the
  comparison now takes the original's unpredictable number from the
  recording, as the fed comparison does. In play the remake rolls.

Both batches again, 14880 frames:

| Batch | Turtle | Energy | His box | Enemies |
| --- | --- | --- | --- | --- |
| First (7390 frames) | 7390 | 7390 | 7390 | 7389 |
| Second (7490 frames) | 7083 | 7305 | 7098 | 6987 |

Eight of the second batch's ten runs now agree on the turtle and his
energy for every frame. Still open there:

- the first sewer's held fight (8 frames; not looked at yet);
- the fifth room's run that starts 32 pixels high (31 frames; it is the
  remake's way of standing him at a place);
- the last room's mixed run: from frame 262 a kind 92 is hit once more
  in the remake than in the original, and the two part; a box 8 lower
  without a swing at frame 302 is not explained either;
- the fourth room's mixed run: at frame 576 the remake makes a kind 91
  the original does not;
- one frame in a jumping run where the ball box comes a frame late.
