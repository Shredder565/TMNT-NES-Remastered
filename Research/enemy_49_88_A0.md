# Enemy kinds 49, 88, A0, 9E and 94 (USA ROM)

Recorded on 11 November 2026 the same way as the kinds in `enemy_92.md`:
one or two recordings each, from the moment the room loaded, with the
turtle standing still and safe from harm. The numbers are measured; the
rules connecting them are only what those recordings showed. None of these
kinds' behaviour code has been found. Speeds are in 1/256ths of a pixel per
update, and an update is two frames.

## Kind 49: walks up and stands (`Scripts/Enemies/Soldier.gd`)

Hit points 28, damage on touch 17.

- It hung in the air for 25 updates, dropped (768, gaining 36 each update),
  stood for 26 updates, and walked towards the turtle at 256.
- It walked off the ledge it was on, fell to the floor, stood 25 updates
  and walked on.
- Once on the way it stopped for 9 updates in a throwing pose, and objects
  of kind 4A appeared. The remake leaves that out.
- It stopped 15 and 16 pixels from the turtle in two recordings, and then
  only stood there.
- The remake runs it with the soldier's script: no hop, no attacks, walking
  speed 256, stopping at 16 pixels.

## Kind 88: lowers itself and climbs back (`Scripts/Enemies/PathEnemy.gd`)

Hit points 9, damage on touch 15. It moves only up and down, at 512, and
takes no notice of the turtle. From its place at Y 48 it lowered to 142,
climbed back in uneven steps, and then settled into this loop, which was
seen twice in full:

| Step | Updates | From Y to Y |
| --- | --- | --- |
| Lower | 42 | 60 to 144 |
| Stop | 2 | |
| Climb | 32 | 144 to 80 |
| Stop | 5 | |
| Climb | 3 | 80 to 74 |
| Stop | 6 | |
| Climb | 7 | 74 to 60 |
| Stop | 3 | |

Objects of kind 89 appeared while it moved, which I take to be shots; the
remake leaves them out. The remake lowers it 96 pixels from its place and
then repeats the loop, so its first descent differs slightly from the
recording's (which stopped 2 pixels higher and climbed in other steps the
first time). Whether the lowest point depends on the floor was not checked;
only one room was recorded.

## Kind A0: walks up, then charges (`Scripts/Enemies/Charger.gd`)

Hit points 47, damage on touch 22. One recording:

- Dropped in, stood 26 updates, walked towards the turtle at 448.
- Stopped 31 pixels from him and stood 12 updates.
- Charged at 1152 (4.5 pixels per update) for 18 updates, which took it 81
  pixels, through the turtle and out the other side.
- Made a small hop on the spot (6 pixels up), stood 13 updates, and
  charged back at him.

The remake does the same, with the hop and the wait after a charge rolled
into one 27-update stand. Guesses: it stops at walls, and only goes for a
turtle within 40 pixels of its own floor height.

## Kind 9E: jumps straight up (`Scripts/Enemies/Leaper.gd`)

Hit points 44, damage on touch 21. It stood for 75 updates, jumped
straight up at 1152 (losing 28 each update, and stopped dead after 26
updates, 82 pixels up), fell back, and stood again. Objects of kind 9F
appeared, left out of the remake.

## Kind 94: walks and pauses (`Scripts/Enemies/Crawler.gd`)

Hit points 24, damage on touch 18. It walks at 352 for 16 updates and
stands for 16, falls off ledges, and turns at walls. Objects of kind 95
appeared while it stood, left out of the remake. It rides 4 pixels into
the floor.

## Still not moving

| Kind | Why |
| --- | --- |
| 82 | Made one short hop and its object disappeared; in another room it did nothing |
| 91 | Did not appear when its room was loaded this way |
| 97 | Drifts in straight lines and arcs and has a second part (kind A5) |
| AB | Moves 32 pixels at a time along one axis, sometimes in arcs; no rule found |
| 40, AC | Overworld kinds; the overworld turtle cannot fight yet |
