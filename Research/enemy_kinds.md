# The enemy kinds: what each looks like and which ones move (USA ROM)

Recorded on 11 November 2026. For each kind the emulated game was dropped
into a room where the kind is placed (by redirecting the first manhole, as
in `doors.md`), and ten seconds of the game's memory and sprite table were
saved. The pictures and the speeds below come from those recordings. Only
kind 8D was studied by hand (`enemy_8D.md`); the rest of this page is from
automatic processing and has had one look by eye, not a careful check.

I do not know the kinds' official names, so they are listed by number.

## The kinds in use

"In use" means placed somewhere in a room's first line-up or on an
overworld: 29 kinds.

| Kind | Where | Places | Hit points | Touch damage | Own sprites | In the remake |
| --- | --- | --- | --- | --- | --- | --- |
| 40 | overworld | 24 | 6 | 10 | yes | stands still |
| 42 | overworld | 15 | 0 | 0 | no (block) | stands still |
| 49 | rooms | 8 | 28 | 17 | yes | walks up and stands (`enemy_49_88_A0.md`) |
| 4B | rooms | 50 | 23 | 15 | yes | walks at 296 for 31 updates, stands for 9 (`enemy_92.md`) |
| 81 | rooms | 81 | 4 | 9 | yes | flies at 640 (2.5 px per update) |
| 82 | rooms | 34 | 4 | 11 | yes | stands still |
| 84 | rooms | 35 | 4 | 9 | yes | walks at 768 (3 px per update) |
| 85 | rooms | 88 | 7 | 18 | yes | walks at 352 (1.38 px per update) |
| 86 | rooms | 35 | 7 | 11 | yes | walks at 352 (1.38 px per update) |
| 88 | rooms | 17 | 9 | 15 | yes | lowers and climbs on a fixed path (`enemy_49_88_A0.md`) |
| 8D | rooms | 36 | 4 | 7 | yes | walks at 352 (1.38 px per update) |
| 8F | rooms | 22 | 10 | 17 | yes | flies at 640 (2.5 px per update) |
| 91 | rooms | 3 | 32 | 18 | yes | walks at 448 for 31 updates, stands for 33 (`world1.md`) |
| 92 | rooms | 75 | 24 | 16 | yes | walks up and leaps (`enemy_92.md`) |
| 94 | rooms | 25 | 24 | 18 | yes | walks at 352 for 16 updates, stands for 16 (`enemy_49_88_A0.md`) |
| 96 | rooms | 135 | 9 | 9 | yes | flies at 640 (2.5 px per update) |
| 97 | rooms | 20 | 35 | 21 | yes | stands still |
| 98 | rooms | 18 | 12 | 17 | yes | hops, walks up, kicks and punches (`enemy_98.md`) |
| 9A | overworld | 13 | 48 | 128 | no (block) | stands still |
| 9B | overworld | 13 | 48 | 128 | no (block) | stands still |
| 9C | overworld | 4 | 48 | 128 | no (block) | stands still |
| 9D | rooms | 7 | 40 | 21 | yes | hops back and forth (`enemy_92.md`) |
| 9E | rooms | 5 | 44 | 21 | yes | jumps straight up (`enemy_49_88_A0.md`) |
| A0 | rooms | 22 | 47 | 22 | yes | walks up, then charges (`enemy_49_88_A0.md`) |
| A7 | rooms | 8 | 6 | 7 | yes | flies at 768 (3 px per update) |
| A8 | rooms | 9 | 6 | 11 | yes | flies at 768 (3 px per update) |
| AA | rooms | 2 | 10 | 14 | no (block) | stands still |
| AB | rooms | 25 | 8 | 15 | yes | stands still |
| AC | overworld | 11 | 255 | 0 | yes | stands still |

Hit points and touch damage are read from the ROM's tables
(`enemy_placement.md`). Touch damage 128 is the turtle's whole energy.

## How the pictures were taken

The game keeps its sprite table at $0200. Each sprite in it was given to
the nearest object, and for every animation frame number ($0400+slot) the
sprites seen at the same offset in at least half of the samples were kept.
Tiles the turtle himself uses were removed. The result is one sprite map
per kind in `Resources/AssetRipper/Sprites/KindXX.json`, in the same
format as Leonardo's.

Known weak spots:

- An animation shows up to four of the frames seen most. For kinds that
  were attacking during the recording (91 and 98, for example) that can mix
  walking and attacking poses.
- Kinds built from several objects (97 with A5, 94 with 95, 88 with 89) show
  only the main object's part.
- The colours are the sprite colours of the room the kind was recorded in.
- Five kinds never appeared and are still purple blocks: AA (two places
  only), and the overworld kinds 42, 9A, 9B and 9C, which did not appear
  when the turtle was put next to their places. What makes them appear was
  not traced.

## The kinds that move

`Scripts/Enemies/Crawler.gd` moves ten kinds: a steady speed, turning
round at a wall. Two of them, 4B and 8F, were added later and are described
in `enemy_92.md`, along with the leaping kinds 92 and 9D. The table below
covers the first eight. The speed of each is read from its recording, where it
never changed. The fliers keep their height.

| Kinds | Speed | Wall turns explained |
| --- | --- | --- |
| 8D | 352, walks | 8 of 8 (if the look-ahead wraps round the screen) |
| 84 | 768, walks | 60 of 62 (if it wraps) |
| 96 | 640, flies | 11 of 11, with real walls 13 pixels ahead |
| 81 | 640, flies | 6 of 12 |
| A7, A8 | 768, fly | 4 of 5 |
| 86 | 352, walks | recorded wedged between two walls, turning every update |
| 85 | 352, walks | never turned in its recording |

"Wall turns explained" is how many of the kind's recorded turns a wall
check at the fitted distance accounts for. For 8D and 84 it only works if
the check wraps round the screen (`enemy_8D.md`); the remake checks real
walls only. For 81, A7 and A8 some turns are not explained, so their
turning points in the remake will differ from the original. Whether 84, 85
and 86 fall off ledges like 8D or turn at them was not seen; the remake
lets them fall.

Kind 98 has its own script and its own page, `enemy_98.md`.

## The kinds that stand still

Six drawn kinds still stand: 82, 91, 97 and AB in rooms, and 40 and AC on
the overworld. `enemy_49_88_A0.md` says why for each. In the remake they stand
at their places and play their frames.

## Leonardo on the overworld

His overworld sprites were recorded the same way while walking right,
left, up and down at the start of the game, and are in
`LeonardoOverworld.json`. They are tall sprites from graphics page 16,
sprite palette 0. There are two frames each for right, up and down, each
shown for 8 updates while walking; left is the right-facing pair mirrored.
Standing still shows the first frame of the pair.

Since this page was written: the things enemies throw and fire, the puff
they leave, and their being made and removed as the camera moves are in
`shots_spawning_tiles.md`.

## Not done yet

Behaviour for the 6 still kinds, the 5 kinds never seen, the objects
enemies throw or fire, bosses, the other three line-up levels, and names.
