# Shots, enemies following the camera, the defeat puff, and three more tile kinds (USA ROM)

Worked out on 11 November 2026 from emulator recordings. Speeds are in
1/256ths of a pixel per update, and an update is two frames.

## What enemies throw and fire

Each is its own object that starts beside the enemy and flies level in a
straight line. Its damage on touch comes from the same ROM table as the
enemies' ($8B05 + kind). The remake's version is `Scripts/Enemies/Shot.gd`.

| Shot | From | Starts at (across, up) | Speed | Damage | When |
| --- | --- | --- | --- | --- | --- |
| 99 | 98, the soldier | 3, 36 | 768 | 9 | After a hop: 25 updates' wait, then 8 of them 13 updates apart |
| 4A | 49 | 4, 16 | 832 | 14 | Every 40 updates while it stands in reach |
| 4C | 4B | 4, 20 | 832 | 5 | One at the start of each stand; flies 15 updates (45 pixels), hangs, gone after 39 |
| 95 | 94 | 2, 17 | 640 | 22 | Four, one an update, at the start of each stand |
| 9F | 9E | 4, 12 | 832 | 30 | On landing and 25 updates later; 11 and 43 updates into each jump |

- "Across" is on the side the enemy faces.
- The soldier's long wait after a hop, which `enemy_98.md` first gave as
  129 updates, is the 25-update wait plus the eight stars.
- 4A, 95, 9F and 99 lasted until they left the screen.
- In the air, kind 9E fired once each way; the remake fires the first at
  the turtle's side and the second away from it.
- Guesses in the remake: a flying shot is used up when it hits the turtle;
  shots pass through walls; the sword does not stop them.
- Not done: kind 49 was once seen throwing while walking, and kind 88's
  attached object (kind 89) and kind 92's (kind 93) were not studied.

## Enemies follow the camera

Measured in the first sewer by walking the camera away from the first
screen and back while logging every object.

- When a room loads, the places on screen get their enemies.
- Walking right, an enemy is made when the screen's right edge is 8 pixels
  past its place (the enemy at X 288 appeared with the camera at 40 or 41,
  those at 352, 448, 456 and 480 likewise).
- Walking left, the same at the left edge (the enemies at 288 and 128
  appeared with the camera at 280 and 120).
- An enemy within about 8 pixels of leaving either side of the screen is
  removed.
- A place makes its enemy again every time the edge reaches it, so going
  away and coming back brings an enemy back.

The remake does the same in rooms. Its guesses: for rooms taller than one
screen, a place also makes its enemy when its row scrolls into view; a
place does not make a second enemy while its first is still on screen; and
there is no limit on how many enemies exist at once (the original has a
fixed number of object slots). Whether a beaten enemy comes back was not
tested by itself, but nothing in what was seen treats it differently.

## The defeat puff

A beaten enemy's object becomes kind 15 for 9 updates: three pictures
centred on the enemy's position. `Scripts/Enemies/Puff.gd`.

## Tile kinds 1, 13 and 15 in rooms

Found by dropping the emulated turtle onto the first exposed tile of each
kind and watching his energy and position. Enemies in those rooms were not
switched off, so only repeated, regular effects are counted.

| Kind | What happened | In the remake |
| --- | --- | --- |
| 1 | He passed through it. While inside he lost 16 energy every 48 frames, the same rhythm as being touched by an enemy | Not solid; hurts for 16 with the usual safe time |
| 13 | He stood on it and was carried right at 1.25 pixels per update, then dropped off its end | A solid floor that carries him right at 320 |
| 15 | He came to rest 6 pixels into it and lost 16 energy every update or so until he had none | A solid floor that takes 16 every update, with no safe time |

Weak spots: kind 13 was measured in one room (world 4, area 1), so other
rooms' moving floors may run the other way; the remake's kind 15 holds
him on top instead of 6 pixels in; and kind 15 covers large areas of some
rooms that have not been looked at one by one.

Still unknown: kinds 7, 10 and 12. He fell straight through 7 and 12 from
above without harm. The code at $FD4B-$FD7A lets thrown objects pass
through kinds 2, 7, 9, 10 and 12, and the code at $88F8 in bank 5 treats 4
and 12 as blocking something, which was not followed up.

## The soldier's spinning jump

Recorded once (`enemy_98.md`): 320 across and 1536 upward, losing 36 each
update; after 37 updates the upward speed is set to 0, 128 pixels up; then
it falls. The remake uses those numbers. When it jumps is a pattern of
mine, not the original's rule: for a turtle on a floor more than 40 pixels
above it and within 120 pixels across, or when a wall stands between them
on the same floor. Guesses: walls stop its sideways movement in the air,
and a ceiling stops its rise.
