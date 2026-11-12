# Enemy kinds 92, 9D, 4B and 8F (USA ROM)

Recorded on 11 November 2026, each in a room where it is placed, with the
turtle standing still and safe from harm and the kind's memory saved every
frame from the moment the room loaded. As with kind 98, the numbers are
measured and the rules connecting them are only what the recordings
showed. None of these kinds' behaviour code has been found.

All four are updated every second frame; speeds are in 1/256ths of a pixel
per update.

## Kind 92: walks up and leaps (`Scripts/Enemies/Leaper.gd`)

| What | Value |
| --- | --- |
| Hit points / damage on touch | 24 / 16 |
| Walking speed | 448 (1.75 pixels per update) |
| Fall | starts at 768, gains 36 each update |
| Leap | 448 sideways, 768 upward, gaining 48 each update |
| Leap size | 26 pixels up, 34 updates; sideways for the first 32 of them |
| Resting height | 3 pixels below the floor's top edge |

- It drops onto the floor and at once walks towards the turtle.
- Twice it leapt when the two middles were 37 pixels apart.
- A wall about 14 pixels ahead stopped its sideways movement in the air.
- After landing beside the turtle it stood still for the rest of the
  recording (200 updates). In another recording it leapt onto the turtle's
  position and its object disappeared; what happens there (it may grab
  hold) was not worked out.
- The remake: walks at the turtle, leaps from 37 pixels, then stays put
  until the turtle is more than 37 pixels away again. Guess: it only does
  this for a turtle within 40 pixels of its own floor height.

## Kind 9D: hops back and forth (also `Leaper.gd`)

| What | Value |
| --- | --- |
| Hit points / damage on touch | 40 / 21 |
| Hop | 512 sideways, 768 upward, gaining 48 each update: 64 pixels across |
| Rest between hops | 17 updates |

It hopped towards the turtle, rested, hopped back the same distance, and
kept doing that for the whole recording, ending up beside the turtle
every second hop. Its first hop was 66 pixels, the rest 64; the remake
makes them all 64. The remake's first hop is towards the turtle.

## Kind 4B: walks and pauses (`Scripts/Enemies/Crawler.gd`)

Hit points 23, damage on touch 15. It walks at 296 for 31 updates, stands
for 9, and repeats, turning round at walls. It did not turn towards the
turtle after passing him. It rides 3 pixels into the floor. While it
stood, objects of kind 4C appeared, which I take to be something it
throws or breathes; the remake leaves those out.

## Kind 8F: flies straight (`Crawler.gd`)

Hit points 10, damage on touch 17. Two of them flew left at 640 at a
fixed height, past the turtle and off the screen. The remake flies them
the same way and turns them at walls, which the recording did not show.

## Looked at and left for later

Kinds 88, 49, A0, 9E and 94 have since been done, and the ones still
standing are listed with reasons, in `enemy_49_88_A0.md`.

## Superseded in part

12 November 2026: the routines of kind 92 have been read from the
original's code (`enemy_routines.md`), and the remake now runs them by
those rules: see `enemy_49_91.md` and `enemy_92_94.md`. What this page
says about them is the earlier measurement and fitted pattern.
