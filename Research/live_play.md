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
