# The screen's layout and the HUD

What the original puts where on its 256 x 240 screen, in a room and on
the overworld, and what the remake does. Facts are marked **read from
code** (the ROM's program, read with a disassembler kept outside the
project), **measured** (the original run in an emulator; script
`Research/cynes/hud_checks.py`) or **guess**.

## The 4-line shift (cause found)

*Read from code.* Every frame the routine at 7:$C460 hands the console
its scroll. The sideways number goes out as it is; the vertical number
has 4 taken off it first (7:$C47A to $C481). So the whole background
is drawn 4 lines lower than the game's own numbers say, on every screen
of the game. Sprites are placed by their own numbers and do not get the
shift.

What follows from it (*measured*):

- With a vertical scroll of 0 the console starts 4 lines above the top
  of the screen's memory, which wraps to its last lines. Those hold
  colour choices, not tiles, so the top 4 lines of the title, the Start
  screen and every room show a thin band of odd tiles (the second half
  of the colour table read as tiles).
- A room's 192 lines begin on screen line 4.
- On the overworld the map is 4 lines lower than its sprites: a sprite
  whose place is line 120 of the screen stands on the map line that the
  scroll numbers would put at line 116.
- The left 8 pixels are switched off by the console's own setting. The
  right 8 are hidden by a column of fifteen plain 8 x 16 sprites at 248
  across, from line 2 down (they are the first fifteen sprites every
  frame). They hide the column where new map tiles are written.

## A room

*Read from code (0:$8001 to $8054) and measured.* The first of those
edge sprites sits at line 193. When the console reports that it has
been drawn, the program points the console at another part of screen
memory (address $2900, kept in $29/$2A) with no scroll: the strip. This
happens only inside a room (`$5C` not 0) at play step 6.

| screen lines | what shows |
|---|---|
| 0 to 3 | the odd band (above) |
| 4 to 194 | the room, its first 191 lines |
| 195 to 200 | empty |
| 201 to 208 | Pts., score, energy, tops of the boxes |
| 209 to 216 | bottoms of the boxes |
| 217 to 224 | HI, best score (and a boss's energy) |
| 225 to 239 | empty |

The strip's tiles (*measured*; they are the same numbers in every room's
graphics page, and use the room's first colour group, 0F 01 16 20 in
most rooms):

- column 1: "Pts." is tiles 1F 2F 0B; "HI" two rows down is 17 18.
- columns 4 to 10: seven digits. A digit is its own number as a tile,
  and nought is tile 0A.
- columns 12 to 19: the playing turtle's energy, eight tiles. *Read
  from code (0:$81AC) and measured for all 129 values:* one full tile
  (30) for each 16 energy; if 8 or more is left over, one more full
  tile; if 1 to 7 is left over, a half tile (31); the rest empty (32).
  Note this is not the Start screen's rule (four tiles of 32 each).
- columns 21 and 22, two rows: the weapon box, tiles 40 to 43 for
  Leonardo, 44 to 47 Raphael, 48 to 4B Michelangelo, 4C to 4F Donatello
  (left column top and bottom, then right column).
- columns 24 and 25: an empty box, tiles 3C to 3F, where a special
  weapon and its count go.
- columns 27 and 28: one more empty box in the rooms tried in worlds 3
  and 4, and not in worlds 1, 2 and 5.
- *Read from code (0:$8121):* while a boss is fought, its energy is
  written two rows under the turtle's as eight tiles by the same rule.
  In one room of world 2 a clock is written there instead (not looked
  at further).

The program writes one part of the strip every eighth frame, in turn.

## The overworld

*Measured.* No strip: the map fills all 240 lines. The only thing over
it is the playing turtle's energy, as eight 8 x 16 sprites in a row at
96 to 159 across and lines 209 to 224, in the sprites' fourth colour
group (0F 0F 16 37 in world 1). Each stands for 16 energy by the rule
above: full is tile AA (with AB under it), half AC, empty AE, from the
sprites' graphics page. With nine sprites on those lines (the edge
column's too) the console leaves one out, so one block flickers.

The top 4 lines of the overworld come from the same row of screen
memory as the bottom 4, so at times they show the map from 240 lines
further down instead of the right piece.

## What the remake does

With a ROM (`RoomScene._lay_out_screen`):

- a room is drawn from line 4, 191 lines of it, with lines 0 to 3 and
  195 on black, and `Scripts/UI/HudStrip.gd` draws the strip from the
  ROM's tiles on lines 195 to 239;
- the overworld's view is the original's screen (`overworld_screen`),
  all 240 lines, the map 4 lines lower than the sprites, with
  `Scripts/UI/OverworldEnergyBar.gd` for the energy;
- the left and right 8 pixels are dark;
- the door wipe covers the room's 191 lines or the overworld's 240.

The help text that used to sit under the picture (turtle, area, keys,
build number) is off; F9 turns it on and off. Without a ROM nothing
changes: the plain bar and the text stay.

Compared with the emulator, pixel for pixel:

| picture | result |
|---|---|
| the strip, 8 cases (5 worlds, 4 turtles, 5 energies) | the same in 7; in 1, eight pixels on the strip's first line where the original still shows the room |
| a whole room frame, turtle standing | the same but for the band on lines 0 to 3 |
| a whole overworld frame, energy full and at $45 | the same but for three tiles' worth of lines 0 to 3 and the one flickering block |

## A tall room, while the screen changes (checked 12 November 2026)

*Measured* in world 1's area 5 (two screens high), with the turtle put at
the bottom of the upper screen so that the screen moves down: three
emulator frames, two during the move and one after, against the remake
drawn at the same heights. Nothing differs on lines 4 to 239 but the
turtle himself, so the layout holds while `_view_top` moves.

One thing seen on the way (*read from code, 7:$C434 to $C453, and
measured*): in a room the scroll the console gets is the one the game
had a frame earlier, so the background is one frame behind the game's
own scroll number (4 lines, during a screen change). The remake draws
the scroll at once.

## Still different

- The odd band on lines 0 to 3 of a room, and the wrong-row lines at
  the top of the overworld, are not copied (black, and the right map).
- The score and best score always read 0000000: the remake keeps none.
- Special weapons, their counts, the third box's contents and the
  world 2 clock are not there.
- One energy block does not flicker on the overworld.
