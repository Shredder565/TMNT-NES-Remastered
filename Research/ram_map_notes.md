# TMNT (NES) RAM addresses used by this project

Source: Data Crystal, "Teenage Mutant Ninja Turtles (NES)/RAM map"
(https://datacrystal.tcrf.net/wiki/Teenage_Mutant_Ninja_Turtles_(NES)/RAM_map),
page last edited 28 January 2024, GNU Free Documentation License 1.2.
Only the addresses relevant to the remake are listed; see the page for the rest.

| Address | Meaning |
| --- | --- |
| $001B / $001C | Game state ID / substate ID |
| $0021 | Current PRG bank |
| $0027 / $0028 | Current CHR bank 0 / bank 1 |
| $0030-$0031 / $0032-$0033 | Buttons pressed / held |
| $0048 | World number |
| $005C | Inside subarea flag (0 overworld, 1 subarea) |
| $005D | Current side-scrolling area (0 in overhead areas) |
| $0067 | Current turtle (0 Leo, 1 Raph, 2 Mike, 3 Don) |
| $0073-$0076 | Special weapon per turtle (0 none, 1 stars, 2 triple stars, 3 boomerangs, 4 scrolls) |
| $0077-$007A | Energy per turtle ($00-$80) |
| $00A8-$00AB | Special weapon quantity per turtle ($00-$63) |
| $00FC / $00FD | PPU scroll X / Y |
| $0460 / $0480 | Turtle Y / X position |
| $04B0 / $04E0 | Turtle Y / X velocity |
| $0500 | Invincibility timeout |
| $056X | Enemy hit points |

Found while working out the doors (10 November 2026), not on the Data
Crystal page:

| Address | Meaning |
| --- | --- |
| $004F-$0050 / $0051-$0052 | Camera X / Y in the map, low byte first |
| $005D | On the overworld this holds the world number, not 0 |
| $007F | Screen number the turtle is on, as of the last door check |
| $00AC / $00AD | Turtle X / Y inside that screen, as of the last door check |
| $0055 | World 5: which cave hides the Technodrome (2, 3 or 4) |
| $0606 | Non-zero while driving the van |
