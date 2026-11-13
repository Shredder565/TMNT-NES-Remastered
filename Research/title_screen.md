# The screens before play

How the original gets from power-on to the first world, and what the
remake does. Facts are marked **read from code** (the ROM's program, read
with a disassembler kept outside the project), **measured** (the original
run in an emulator, script `Research/cynes/title_screen_checks.py`) or
**guess**.

## What the original shows

1. **The notice** (the names and rights text). Game state 0, step 1.
   *Measured:* it is up from frame 3 after power-on to frame 260, that is
   256 frames. *Read from code (7:$C59C):* Start or Select ends it early.
2. **The title**: the publisher's mark, the game's name and PUSH START.
   Game state 0, step 2, from frame 262. *Read from code (7:$C5E1):* it
   waits for Start. If nothing is pressed for 256 frames the game state
   becomes 1, a demonstration of play in a room with flashing colours;
   Start during it comes back to the title. *(Measured.)*
3. **Start on the title** (state 0, step 3; *read from code 7:$C60F*,
   times *measured*): PUSH START is wiped within two frames, written back
   8 frames later, and so on every 8 frames; 127 frames after the press,
   with the words showing, the game state moves on (2, 3, then 4) and the
   first world's overworld is drawn in with the same wipe a door uses
   (see `overworld.md`).

## Where the pictures come from

*Read from code.* Both screens are layouts in the same table the Start
screen uses (7:$E3CE, format in `start_screen.md`):

| screen | table entry | data in program bank | asked for at |
|---|---|---|---|
| notice | $13 | 0 (data at $84AC) | 7:$D22C |
| title  | $01 | 1 (data at $BCFD) | 7:$C93C |

Both use background graphics page $0F, no scroll, and the same colours:
all 32 places are first filled with $0F (7:$F77E), then colour patch $21
of the list at 7:$FA36 is written in (01 16 30 / 01 16 2A / 16 27 10 for
the first three groups). PUSH START is tile list 0 of the list at
7:$CAB7: ten tiles written from screen memory place $22CB (row 22,
column 11). Its "wipe" form is the same list asked for with the top bit
set, which writes blanks.

## The four lines at the top

*Measured.* As on every screen of this game the picture sits 4 lines
lower than the scroll numbers say, and the left 8 pixels are hidden. On
the title the four lines above the picture are not empty: they show a
few lit pixels at the left. They are exactly what the console would draw
if its vertical scroll were 252 instead of 0: the last four lines of the
screen's memory, which hold colour choices and not tiles, read as the
bottom halves of a row of tiles (the second half of the colour table,
bytes 32 to 63, as "row 31"). Drawing that row above the picture makes
the remake's title match the emulator in all 61,440 pixels; the notice
matches too (its colour bytes there are 0, a blank tile). So the 4-line
shift is a real property of how the picture is scrolled and not an
emulator quirk. Its cause is in `hud.md`: the program takes 4 off the
vertical scroll before handing it to the console (7:$C47A).

## What the remake does

`Scenes/UI/Title.tscn` (`Scripts/UI/TitleScreen.gd`) is where the game
opens when a ROM is in place, where the ROM screen goes after copying a
ROM, and where END at GAME OVER goes. It shows the notice for 256
frames (the pause key skips it), then the title until the pause key is
pressed, then blinks PUSH START for 128 frames and loads the game.
`InfoScreenData.screen_layout(bank, entry)` reads any layout;
`title_colours()` gives the colours. Without a ROM there is no notice
and the title is plain text.

## Still different

- The demonstration of play after 256 idle frames is not made; the
  title simply waits.
- (Done 13 November 2026: Select ends the notice too, as in the
  original.)
- The first world appears at once after the blink rather than being
  wiped in.
- No sound.
