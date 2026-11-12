# Enemy kinds 81 and 96, 8D and 84, and 86, from the original's code (USA ROM)

Written on 12 November 2026. `enemy_routines.md` says how the routines
were found and what the shared helpers do. Everything here is **read from
code** unless marked otherwise. None of these kinds takes any notice of
being hit (apart from blinking and losing hit points), and only 86 looks
at the turtle. None uses the frame counter or anything random.

These replace the fitted rules in `enemy_8D.md` and `enemy_kinds.md`
(`Crawler.gd`), which stay for the kinds not yet read.

## Kinds 81 and 96 (also 8E and 8F): level fliers - `Flier.gd`

Routines 5:$97D7 (81, 8E, 8F) and 5:$99E5 (96): the two are the same
code. Then 5:$9833 every update.

- **First update:** it picks its way from the screen's scrolling (RAM
  $40, how far the screen moved in the turtle's last update): to the
  right if the screen is scrolling left, otherwise (scrolling right, or
  still) to the left. Speed 640, 2.5 pixels an update. The way it faced
  when it was made does not matter.
- **Every update after:** a wall 10 pixels ahead (plus the whole pixels of
  its speed: 12 going right, 13 going left), at 10, 14 or 6 above its
  position, turns it round. It never changes height.

Hit points and damage on touch from the tables: 81 has 4 and 9; 96 has 9
and 9. Animations: 81 is number 02 (pictures 9F A0, 4 updates each), 96
is number 21 (95 96, 4 each).

The earlier page could explain only 6 of 12 of kind 81's turns. The rest
were turns at walls that are not there: the map look-up going round the
ring of sixteen columns (`enemy_routines.md`).

## Kinds 8D and 84: walkers that drop off ledges - `LedgeWalker.gd`

Routines 5:$978E (8D) and 5:$9977 (84), then 5:$9851 and 5:$9870.

- **Setting off** (its first update, and the update after every landing):
  speed forward, the way it faces: 352 for 8D (1.375 pixels an update),
  768 for 84 (3 pixels). A new one faces left if it was made on the right
  half of the screen.
- **Walking:** if there is nothing 12 pixels behind it, 1 above its
  position, it drops: 2 pixels an update, no sideways speed. Otherwise a
  wall 12 ahead (plus the whole pixels of its speed), at 12, 14 or 6 up,
  turns it round.
- **Dropping:** 24 is added to the fall speed each update. It lands when
  the place 5 above its position is in a floor, and is raised until that
  place is clear: 4 pixels below the floor's top.

Because the ledge test looks *behind* it, it is 12 pixels past the edge
before it drops. Hit points and damage: 8D has 4 and 7; 84 has 4 and 9.
Animations: 8D is number 01 (9D 9E, 3 each); 84 is number 1C (90 91, 2
each).

## Kind 86: along the ceiling, and a swoop - `CeilingCrawler.gd`

Routine 5:$982B, then 5:$987C (crawling), 5:$98D7 (rising) and 5:$9908
(the swoop). The earlier pages had it as a floor walker "recorded wedged
between two walls".

- **Setting off** (first update, and whenever it has found a ceiling):
  like the fliers it goes right if the screen is scrolling left, else
  left. Speed 352.
- **Crawling**, each update, the first that applies:
  1. nothing 12 behind it and 34 above its position (the ceiling has
     ended): it stops going sideways and rises at 3 pixels an update;
  2. a wall 12 ahead, 13 up: it turns round;
  3. the turtle less than 40 pixels away across (height does not come
     into it): it swoops. Animation 07, downward speed 6 pixels an
     update; it keeps its sideways speed.
- **Rising:** 24 is taken off its speed each update (so it rises faster
  and faster). When the place 24 above it is in a wall it is moved down
  until that place is clear, stops, and sets off again.
- **The swoop:** 45 is taken off its downward speed each update, so the
  dive slows, stops and becomes a climb. A wall 10 ahead, 16 up, ends the
  swoop: it rises as above. While going down, a wall at its own position
  (the floor) stops the dive. While going up, a wall 24 above it means it
  is back at the ceiling: it is moved down clear of it and crawls on,
  the same way as before.

So it hangs with its position 24 pixels below the ceiling. Hit points 7,
damage on touch 11. Animations: 06 (pictures 97 98, 8 updates each) on
the ceiling, 07 (picture 99) in the swoop. `Kind86.json` has no picture
99, so the remake keeps the last crawling picture during a swoop.

Above a one-screen room the original's map look-up reads memory left
over from the last map shown (`enemy_routines.md`). In the recordings
that was solid, which is why a kind 86 placed at the very top of a room
crawls there instead of rising off the screen. The remake assumes solid.

## Checked against the emulator

Method in `enemy_routines.md`. Recordings in all six of world 1's
areas: standing, walking each way, pacing, pacing and jumping.

| Kind | Objects | Frames compared | Agree exactly |
| --- | --- | --- | --- |
| 81 | 106 | 29900 | 29900 |
| 8D | 55 | 13964 | 13964 |
| 86 | 44 | 12535 | 12535 |
| 96 | 38 | 21077 | 21077 |

The recordings include 8D dropping off ledges (600 frames), 86 rising
(845 frames) and swooping (2623 frames), and every kind turning at walls.

Not checked, because world 1's first line-ups do not place them: kinds
84, 8E and 8F. They run the same code as 8D and 81 with other numbers,
read from the same tables.

## What is not matched

- The way a flier or a kind 86 sets off depends on the screen's scroll in
  the turtle's last update. The remake takes that from its own screen,
  which follows the original's scrolling rule (`scrolling.md`); in the
  check it is taken from the recording.
- When and where they are made and removed as the screen scrolls is the
  room scene's rule, not covered here.
