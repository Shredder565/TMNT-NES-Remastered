# The Start screen ("INFORMATION") in the original (USA ROM)

Worked out on 12 November 2026 with the emulator (cynes) and by reading
the ROM's code. Each fact is marked **(code)** when it was read from the
code, **(measured)** when it was seen in the emulator, or **(guess)**.
Addresses are written bank:address. The emulator scripts are in
`Research/cynes/start_screen_checks.py`.

## What the player sees

Pressing Start in play (on the overworld or in a room) replaces the
picture with a screen headed `:INFORMATION:AREA n:`. On it:

- the area's small map in a frame at the top left, with a small blinking
  marker where the turtle is;
- the four turtles down the right side (LEO, RAPH, MIKE, DON): a face, the
  name, an energy bar of four tiles, a box for his special weapon and how
  many of it he has;
- two more boxes under them for the area's items (missiles, ropes);
- a box at the bottom left where Splinter or April says a few words,
  typed out a letter at a time.

The game underneath stands still: no object moved while the screen was
open, and all of them were where they had been when it closed (measured,
five enemies in the first sewer).

## Controls on the screen

| Button | What it does | How known |
| --- | --- | --- |
| Down | chooses the next turtle down the list, wrapping to the top | code 3:$AA64, measured |
| Up | the next one up, wrapping to the bottom | code, measured |
| Start | back to the game with the chosen turtle | code 7:$CE06, measured |
| Left, Right, A, B, Select | nothing | measured: no tile, colour or RAM value of the screen changed |

A turtle with no energy left (captured) is passed over, both when the
screen opens and when moving (code 3:$AA2A, 3:$AA9C). A sound plays when
the choice moves, but only if more than one turtle is left (code 3:$AA86).

The chosen turtle is the game's "current turtle" number at $67 itself:
Up and Down change it at once, there is no separate confirm (code,
measured). Back in play the turtle on screen is the new one: the same
body pictures with the bandana's colour changed (measured: only one
colour number of the sprite colours changed, 12 to 16 going from
Leonardo to Raphael), and from then on his own weapon, energy ($77 + his
number) and special weapon.

## Select, in play

Not part of this screen, but checked because it was asked: in a room,
Select switches between the turtle's own weapon and his special weapon
($5B flips between 0 and 1), and only if he has any of the special weapon
($A8 + his number is not 0) (code 4:$982C). On the overworld Select gets
him out of the van when he is driving it (code 4:$A9E3). With no special
weapon and no van, Select did nothing (measured).

## When Start is accepted

The routine at 7:$CDB9 looks at Start on every second frame (measured:
the screen opened on the frame after the press). It refuses when (code):

- the playing turtle has no energy;
- the turtle's state number ($0510) is $16;
- any of several "busy" values is not zero (a screen change, a fade, the
  16-frame hold after a screen change, and others: $24, $03ED, $36, $20,
  $3F, $3D, $B5, $D2).

Opening sets $35 to 1, saves the turtle's picture number and the screen
settings, and from then on the play routine jumps to the screen's own
routine at 3:$A91C every frame instead of running the game (code
7:$CB12).

## How the screen is put together

The routine at 3:$A91C works through steps, one per frame; the step
number is at $D0 (code; measured: $D0 went 1 to 8 over the first ten
frames).

1. If all four turtles are captured, this is where the game ends instead.
   Otherwise the screen's layout is copied to the screen (below), the
   background tiles are switched to graphics page $1B (4 KB pages), and a
   3 by 3 "captured" cover is put over the face of every turtle with no
   energy (code 3:$A936, 3:$ABC6).
2. The four energy bars and special-weapon counts (code 3:$A99A).
3. The screen's colours: colour list number 3 of the table at 7:$F796
   (code 3:$A9AB).
4. The area number in the heading (the world number plus 1), and the
   colour bytes for the two item boxes (code 3:$A9B3).
5. The picture of each turtle's special weapon (code 3:$AA1C).
6. The playing turtle's row is lit (code 3:$AA2A).
7. The small map, in three strips, one strip per frame (code 3:$AA4A,
   3:$B695).
8. From then on, every frame: the marker, the message, and Up / Down
   (code 3:$AA5C).

Before the steps, every frame, the routine at 3:$AC77 sees to the two
item boxes.

Measured timing: the screen is complete 10 frames after Start, the
speaker's face appears on the 11th and the first letter soon after.

### The layout

Screen layouts are in a pointer table at 7:$E3CE. The Start screen is
entry 4 (the code asks for it with the number 8, two bytes per entry) and
its data is in bank 3 at $B948 (code 3:$A977, 7:$C975; measured: 905 of
the 1024 bytes read back from the ROM were on the emulator's screen
unchanged, and the other 119 are the parts filled in afterwards).

The data is a list of blocks. A block starts with a screen address (low
byte first), then runs: a count below $80 followed by one tile to repeat
that many times, or $80 plus a count followed by that many tiles. $7F
starts another block; $FF ends the layout (code 7:$C982). This layout is
one block that fills all 30 rows of 32 tiles and the 64 colour bytes.

Letters are tiles: A to Z are $10 to $29, digits 1 to 9 are tiles 1 to 9,
zero is tile $0A, a blank inside a box is $0F, tile 0 is the dark
background, full stop $0B (code, measured).

### Where the picture sits

The picture starts 12 lines down the screen and its last row is cut off
after 4 lines; the left 8 pixels are blank (measured, comparing the
emulator's picture with one built from the layout: with those two rules
every pixel agrees). 8 of the 12 lines are the scroll the code sets
(7:$C975 puts $E8 in $FC, which this game uses for the vertical scroll;
$FD is the horizontal one). The other 4 were also seen in play: in a room
the floor is drawn 4 lines lower than the map position of the turtle's
feet says. Why was not looked into (it may be how the emulator times the
game's screen setup). The blank left 8 pixels are the console setting at
$FE ($18: left column hidden).

### Energy bars (code 3:$AB03, measured)

A bar is 4 tiles at the place the table at 3:$ADAD gives for the turtle.
Energy is 0 to 128. The code halves it; each 16 of that is one full tile
($30); of what is left, 9 or more counts as another full tile, 1 to 8 as
a half tile ($31); the rest of the bar is empty tiles ($32). The two
tiles after the bar are the count of his special weapon (blank when 0).

### Special weapons (code 3:$AB75)

Each turtle's box is 2 by 2 tiles at the place in the table at 3:$ADB5.
The four tiles for special weapon number n are at 3:$ADBD + 4n; number 0
(none) is an empty box.

### The item boxes (code 3:$AC77)

The table at 3:$AD8B says which worlds use the first box (worlds 3 and
4, counting from 1) and 3:$AD92 which use the second (world 3). A world
that does not use a box has it wiped; one that does shows the item and
how many are held ($A7, $BF) once there is at least one. In world 1 both
are wiped (measured).

### Lighting the chosen turtle (code 3:$AAC0, measured)

Two things change. Three colour bytes of his row are rewritten so that
his face uses colour group 2 and his name and weapon box group 0 (the
other rows have all three in group 1, which is greys). And one colour of
group 2 is set to his own: a "colour patch" from the table at 7:$FA36
(patches 0 to 3: 12 blue, 16 red, 27 orange, 14 purple, written to place
$0B of the colour list). The tile lists that do the rewriting are in the
string table at 7:$CAB7: numbers 3, 4, 5 and 12 light Leonardo, Raphael,
Michelangelo and Donatello (the pairs at 7:$D1C1 name the list and the
patch for each), and 8 to 11 dim them again.

### The map (code 3:$B695)

Per world, three strips. A strip is four bytes at the address the table
at 3:$B641 gives: rows, place (high byte, low byte), width. The tiles of
all three strips follow one another at the address in the table at
3:$B717.

### The marker (code 3:$B8C9, measured)

One tall sprite, tile $AE over $AF of the same graphics page, whose
colour group is the frame counter's low two bits, so it changes colour
every frame. Its place comes from the table at 3:$B934 (four bytes per
world: across scale, across start, down scale, down start): the turtle's
overworld X is multiplied by the scale, the high byte of the result is
added to the start; the same for Y. The X and Y used are the camera's
position plus the turtle's place on the screen, as saved at $95 to $9A.
On the overworld these follow him (measured: the marker moved after he
walked). In a room they stay as they were when he went in, so the marker
shows the manhole or door he used (measured in the first sewer).
World 1's start (160, 296) gives a sprite at X 68, Y 81, drawn one line
lower as sprites always are (measured).

### The message (code 3:$ADD1, measured)

Chosen once, when the map is finished:

- In the room the table at 3:$B020 names for the world (world 1: area 5),
  the world's own message from the table at 3:$B026 ("PREPARE FOR THE
  FIGHT..."). World 2's depends on how many bombs are left.
- While $5E is 3, entry 6 of that table (about teamwork).
- Just after a turtle was captured ($0617), "<name> GOT CAUGHT. WHO FIGHTS
  NEXT?" from 3:$B47D.
- Otherwise one of the world's four messages (table at 3:$B3D6), picked
  by two bits of the frame counter. Number 0 ("FIND AND HELP YOUR
  FRIEND(S) IN THIS STAGE.") is only used when a turtle is captured;
  otherwise number 1 is used in its place.

Who speaks: messages 1 to 3 begin with a byte, 0 for Splinter and 1 for
April; for message 0 and the room messages the speaker comes from a small
table per world (3:$AE55, 3:$AEC6). The face is 4 by 4 tiles written from
the list in the table at 3:$B43F.

Typing: one byte of the message every 4 frames. A tile number is written
and the place moves one to the right; 0 is a space. The first line starts
at row 17, column 3. Marks: $F7 starts the second line (row 19), $F8 the
third (row 21), $FA writes an S when more than one turtle is captured,
$FC writes the number of bombs left, $FD carries on with the speaker's
closing words ("YOU CAN DO IT." / "YOU HAVE MY SUPPORT.", table at
3:$B412) at row 23 column 7, $FE moves to the place given by the next two
bytes, $FF ends. Measured: "GET EXTRA ENERGY WITH PIZZA. YOU CAN DO IT."
took 180 frames, 45 bytes at 4 frames each.

## Leaving

Start is looked at by the same routine as on the way in (7:$CE06). It
puts back the turtle's picture number, clears the screen, restores the
graphics pages and screen settings, and sends the play routine back to
its "set the map up again" step with a flag ($0609) that keeps the
objects as they are (code). Measured, counting from the press: on the
overworld the map was being redrawn until frame 35 and the game stood
still for 16 more ($3D counts down), running again on frame 52; in a
room the same took until frame 27 and 43. What is on show during the
redraw was not looked at (the remake shows black).

## What the remake does

`Scripts/Rom/InfoScreenData.gd` reads the layout, colours, bars, weapon
boxes, item boxes, map, marker table, messages and faces from the ROM at
the addresses above. `Scripts/UI/StartScreen.gd` keeps the screen as the
console does (tiles, colour bytes, colour list), paints it from the ROM's
tiles, types the message and runs the controls; the game is paused
underneath. A picture of the remake's screen and one from the emulator
(world 1 start, same message) agree in every pixel, apart from the
marker's colour, which depends on which frame is looked at.
`RoomScene.open_start_screen` opens it on the pause action (Enter, or
Start on a controller) from the overworld and from rooms, and
`RoomScene.set_turtle` makes the chosen turtle the one who plays.

Not done, or different:

- No sounds.
- The special weapons, their counts, missiles and ropes are always shown
  as "none": the remake does not have them yet. The reader takes them as
  inputs, so they will show once the game keeps them.
- World 2's bomb message, the "got caught" message and the messages
  after an event (table at 3:$B4ED) are not chosen. The held-fight
  message is chosen whenever a held fight is on, which is a guess at what
  $5E = 3 means.
- The rope item's picture (drawn as a sprite) is not drawn.
- All four turtles captured should end the game; the remake has no
  capture yet.
- The switched turtle has his own energy, bandana colour, weapon damage
  and swing boxes, but he is drawn with Leonardo's pictures, so the
  weapon in his hands is still a sword (see the report).
- The picture during the 34 (or 26) frames after leaving is black, a
  guess.
