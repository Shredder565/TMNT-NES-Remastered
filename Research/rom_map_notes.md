# TMNT (NES) ROM offsets

Source: Data Crystal, "Teenage Mutant Ninja Turtles (NES)/ROM map", as pasted
by Neil on 10 November 2026 (GNU Free Documentation License 1.2).
Offsets are positions in the .nes file, including the 16-byte header, as the
page gives them. None of these have been checked against the ROM yet.
"TSA" means the tables that build larger background blocks out of 8x8 tiles.

| File offset | Meaning |
| --- | --- |
| 0x04061-0x04062 | World 1 data pointer |
| 0x04011-0x04012 | World 1 TSA data pointer |
| 0x0401B-0x0401C | World 1 attribute data pointer |
| 0x186F9-0x1871C | Enemy list pointers |
| 0x1871D-? | Enemy list data |
| 0x18B10-0x18BC0 | Enemy attack damage |
| 0x19BDB-0x19BEE | Turtles' attack damage |
| 0x1A102-? | World to go to after the Rocksteady battle |
| 0x1AC9F-0x1ACA0 | World 1 enemy data pointer |
| 0x1AE3C-0x1BB22 | Enemy data |
| 0x1C68F-? | Initial health for turtles |
| 0x1D5D8-? | World 1 pattern table (which graphics pages a world loads) |
| 0x1D646-? | World 1 palette |
| 0x1E86D-0x1E86E | World 1 entrance data pointer |
| 0x1F7A6-0x1F7D9 | Palette data pointers |
| 0x1F4BA-0x1F4BB | World 1 scroll data pointer |
| 0x1F7DA-0x1FA45 | Palette data |

## Checked since

- 0x1E86D (10 November 2026): this is the first entry of the overworld door
  table at console address $E85D in bank 7. It points at world 1's overworld
  doors. The full door layout is in `doors.md`.
- 0x186F9, 0x1871D, 0x19BDB, 0x1AC9F, 0x1AE3C (10 November 2026): the enemy
  line-up pointers and data, the turtles' weapon damage, and the overworld
  and room enemy placement. All are in bank 6; see `enemy_placement.md`.
