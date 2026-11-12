# How placed enemies come and go as the screen scrolls (USA ROM)

Read from the code on 12 November 2026 (bank 6: $80F6, $8112, $8146,
$822B, $85CC, $864A; bank 7: $EED3, $F089, $DEBB; bank 5: $8077), then
checked in whole-room play (`live_play.md`). It replaces the measured
rule in `shots_spawning_tiles.md`. The remake's copy is
`RoomScene._follow_camera` and `RoomScene._place_enemies`.

## While the room is played (6:$80F6)

Once an update, on the enemies' frame, before any object moves:

- Nothing happens if the screen is held for a fight, or if the screen did
  not scroll in the turtle's last update (RAM $40 is 0).
- Otherwise one point on the screen's leading edge is taken: 248 across
  the screen when it scrolled right, 7 across when it scrolled left. The
  place list gone through is that of the map screen this point is in
  (and of the row of screens found 184 down the screen, or 23 down when
  the screen is scrolling up).
- A place makes its enemy if the edge has passed it in this step. Counted
  round 256 as the original does: scrolling right, if (edge - place) is
  less than the step; scrolling left, if (edge - place) is greater than
  the step taken as a number from 0 to 255. The second test is one short
  at both ends, so with the usual step of 2 only the place one pixel
  beyond the edge is caught, and a place can be stepped over.
- The enemy is put at the edge, in the first free of object slots 5 to
  10; with none free it is not made. It is not made if the cell 8 above
  it is a wall. It faces left if it is on the right half of the screen.
- It is then updated like every other object in the same frame. Every
  object's place on the screen is moved back by the scroll at the start
  of its update, the new one's too, so it ends up one step short of the
  edge (measured: 3 pixels, in a step of 3).

Nothing remembers that a place has made its enemy. Scrolling back and
forth over a place makes another each time, as long as a slot is free.

Two special cases in the code were not followed up because they need the
screen to scroll while it is at the room's end: at the right end the
left edge is used, and at the left end the right edge.

## When a room comes up (6:$85CC)

Two passes, without the wall test:

1. the places of the map screen that the point 7 across the screen is
   in, from that point rightward; these enemies face right;
2. only if the screen straddles two map screens: the places of the
   screen that the point 248 across is in, up to that point; these face
   left.

Each enemy is put as far across the *screen* as its place is across its
own map screen. So when the screen straddles two map screens the enemies
are not at their places: those of the first pass stand further right
than their places by the amount the screen is into the map screen, and
those of the second pass appear on the left part of the screen. (Seen in
every recording that starts part-way into a screen.) The facing comes
from where the object is first put (7 or 248 across), before it is moved
to its place.

## Leaving (5:$8077)

After its update an object is removed if it is less than 4 pixels from
the left or right of the screen or from its top, or 192 or more down.

## Checked

In the ten whole-room recordings of `live_play.md` every enemy the
original makes is made by the remake on the same frame at the same
place, and every one it removes is removed on the same frame: 7389 of
7390 frames agree, and the odd one is a dropped frame.

## Not matched

- A room entered through a door: the remake puts its screen where it
  always has (centred on the turtle), which decides which enemies the
  room comes up with. Where the original puts the screen for each door is
  in the door tables (`doors.md`) and was not looked at here.
- The line-up level (`enemy_placement.md`) is still always the first.
- The enemy a held fight brings in is still made the old way.
