# How the original stores its side-scrolling rooms (USA ROM)

Worked out on 11 November 2026 by disassembling the room-loading code in
program bank 7 ($D367-$D424 sets the pointers up, $D843-$D8F7 draws a
column) and checking the result against a room recorded in Mesen. The
decoder is `Scripts/Rom/RomLevels.gd`.

## Structure

- 6 worlds (the game's "Areas" 1-6; RAM $0048). Each has several areas
  (rooms; RAM $005D): 6, 2, 7, 18, 9 and 4, 46 in all.
- A room is a grid of screens. Its map is: width, height, then one screen
  number per grid cell. $FF means no screen there.
- A screen is 48 bytes: 6 rows of 8 block numbers. 256 x 192 pixels.
- A block is 16 bytes: 4 rows of 4 tile numbers. 32 x 32 pixels.
- One more byte per block holds the colour group (0-3) of each quarter,
  two bits each: top-left, top-right, bottom-left, bottom-right.

## Where things are (console addresses; bank 7 is fixed at $C000)

| What | Bank | Address | Indexed by |
| --- | --- | --- | --- |
| Block shape pointers | 1 | $8015 | world (see exceptions) |
| Block colour pointers | 1 | $8033 | world (see exceptions) |
| Screen data pointers | 1 | $805D | world |
| Block shapes and colour bytes | 3 | from the pointers above | block number |
| Screens | 1 | from the pointer above | screen number x 48 |
| Room map pointers | 7 | $F49E | world, then area |
| Graphics page and sprite set | 7 | $D5CE | world, then area (2 bytes) |
| Palette number | 7 | $D63B | world, then area |
| Palette colour lists | 7 | $F796 | palette number; list ends at $FE |
| Tile kinds | 7 | $FC93 | graphics page minus 13 |

Exceptions for the block tables: world 5 uses index 6 + area; world 4 uses
index 0 for area 0 and index 12 for area 17.

The overworld uses a parallel set of tables ($8001, $800B, $8051, $F4AA,
$D5C8) and 8 x 8 block screens. Decoded on 10 November 2026: see `doors.md`.

## Tile kinds

The table is a list of (last tile number, kind) pairs. A tile's kind is
that of the first pair whose tile number is not below it. Kinds seen:

| Kind | Meaning |
| --- | --- |
| 0 | Empty |
| 4 | Solid |
| 9, 11 | Ladder (confirmed in the first sewer) |
| 2 | Door or manhole (see `doors.md`) |
| 12 | On the overworld: blocks the way (water). In rooms: unknown |
| 6 | On the overworld: stops the van but not a turtle on foot |
| 1 | In rooms: hurts, not solid (`shots_spawning_tiles.md`) |
| 13 | In rooms: a floor that carries the turtle along |
| 15 | In rooms: a floor that drains energy every update |
| 7, 10 | Unknown yet |

## Checked

- World 1 area 0 decodes to the same tiles and colour groups that Mesen
  showed on screen for the first 568 pixels of the first sewer.
- All 46 areas decode and render as recognisable rooms, including the dam
  interior, the underwater level and the Technodrome.
- Leonardo stops at the pillar at x=474, one pixel from the original's 473.

## Not done yet

The unknown tile kinds and items. Enemy placement is in
`enemy_placement.md`. Entrances, exits and
the overworld maps are now in `doors.md`.
