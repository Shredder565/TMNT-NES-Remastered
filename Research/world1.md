# World 1: its items, its boss, and how it ends (USA ROM)

Worked out on 11 November 2026 in the emulator, by dropping the game into
each of world 1's six rooms and listing every object that showed up,
including the ones that are not in the enemy placement tables. Speeds are
in 1/256ths of a pixel per update; an update is two frames.

## What is in each room

| Area | Size (screens) | Placed enemy kinds | Also found |
| --- | --- | --- | --- |
| 0 | 4 x 1 | 8D, 81, 98 | a slice of pizza at (928, 32) |
| 1 | 3 x 1 | 8D, 81, 98 | the first boss, kind 70 (see `encounters.md`) |
| 2 | 4 x 1 | 81, 98 | item kind 0B at (560, 64) |
| 3 | 3 x 1 | 86, 49, AA | a slice of pizza at (640, 40) |
| 4 | 2 x 1 | 86, 49, 91 | a whole pizza at (32, 48), a slice at (304, 64) |
| 5 | 2 x 2 | 96, 92, 94 | the boss, kind 71 |

Kind AA has two places in area 3 but never appeared in any recording.

## Items

Items are objects with low kind numbers. Touching one removes it.

| Kind | Picture | What touching it did |
| --- | --- | --- |
| 03 | A slice of pizza | Energy 48 became 80: +32 |
| 01 | A whole pizza | Energy 48 became 128: full |
| 0B | Not recognised | Nothing I was watching changed. Read from code since: it is the power item (`Research/items_and_hits.md`) |

I could not find the table that places items in the ROM (three byte
orders were tried), so the remake lists world 1's five items by hand in
`Scripts/Levels/RoomScene.gd`. The other worlds' items have not been
surveyed. The item kinds in between (02, and 05 to 08) were not seen; 02
is probably the half pizza.

## Kind 91

It carries a chainsaw. Hit points 32, damage on touch 18. One that had
room walked at 448 for 31 updates, stood for 33, and turned at walls; two
others were wedged between walls. The remake runs it with
`Scripts/Enemies/Crawler.gd`.

## The boss: kind 71

It looks like Rocksteady. Hit points 96 and damage on touch 23, both from
the ROM's tables; its bullet (kind 19) does 9. It is not in the placement
tables. It appeared at (208, 68) in area 5's top-left screen when the
turtle stood at X 32, 80 or 128 on that screen's floor, and not from
further right. The remake brings it in once the turtle is left of X 136
on that screen; where the ROM keeps this was not found.

One 25-second recording, turtle standing still at X 60. After dropping to
the floor the boss repeated the same round four times:

| Step | Measured |
| --- | --- |
| Walks at the turtle | 512 (2 pixels per update) |
| Stops and shoots | 31 and 36 pixels away; stands 48 updates; one bullet at the start, 5 across and 20 up, flying at 1280 |
| Walks closer | 11 or 12 updates |
| Jumps over him | 512 across, 1792 upward; rise stopped dead after 20 updates, 82 pixels up; gains 78 each update falling |
| Stands | 3 to 5 updates |
| Jumps back over him | the same jump: 92 pixels across in 46 or 47 updates |
| Stands, then walks at him again | 5 or 6 updates |

It rides 4 pixels into the floor. A wall stopped its sideways movement in
the air about 20 pixels short.

The remake (`Scripts/Enemies/Rocksteady.gd`) plays that round. It is a
replay of what the boss did against a turtle who never moved, not the
original's rules, so the real boss may act differently in a real fight.
The remake's jump lands a few pixels short of the recorded 92. What the
boss does when hit was not looked at.

## How the world ends

The code at $A0E7 in bank 6 runs after the boss: when the value at $8E
reaches 3 it sets the world number to 1, clears the "inside a room" flag
and starts the next world on its overworld. The remake shows
"WORLD 1 CLEAR" for three seconds and opens world 2's overworld. Whatever
the original shows in between (April's rescue) is not done.

## The other boss, and April

Found in update 21: see `encounters.md`. Kind 70 comes in on area 1's last
screen, with a picture of Rocksteady holding April on the ledge above. My
earlier search missed it because it only appears when the screen scrolls
there from the left. The same notes give the ROM table that places both
bosses, so the remake no longer lists them by hand, and correct the
guess above about where kind 71 appears: the rule is "camera at X 0",
which is the same thing as the turtle being left of X 128.

## Still missing from world 1

On the overworld kinds 9C, 42 and AC still stand (`overworld.md`); the other
three turtles still carry Leonardo's sword and pictures
(`start_screen.md`); rescuing a captured turtle (`losing_a_turtle.md`);
what the original shows when the world is won (April's rescue); score;
sound; the special weapons and the other items in
`items_and_hits.md`; and everything listed as approximate on the enemies'
own pages (their routines have not been read from the code yet).

## Superseded in part

12 November 2026: the routines of kind 91 have been read from the
original's code (`enemy_routines.md`), and the remake now runs them by
those rules: see `enemy_49_91.md` and `enemy_92_94.md`. What this page
says about them is the earlier measurement and fitted pattern.
