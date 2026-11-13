# Losing a turtle, and GAME OVER (USA ROM)

Worked out on 12 November 2026 in the emulator (cynes), with the code
read where noted. Facts are marked **(code)**, **(measured)** or
**(guess)**. Script: `Research/cynes/losing_a_turtle_checks.py`.

## In a room (measured)

Recorded in the first sewer with Leonardo's energy ($77) set to 4 and an
enemy's touch taking the rest.

- On the blow his energy is 0 and his state ($0510) becomes $0A. His
  animation is $8A: pictures 25, 26, 27 and 28, 6 updates each (the
  animation's list and number of updates are in the ROM's usual tables,
  6:$8BC5 and 6:$9305), drawn in sprite colour group 3 instead of his
  own. After 48 frames he is no longer drawn. The room carries on.
- 147 frames after the blow the screen goes dark and the Start screen
  comes up by itself ($35 = 1) with $0617 = 1, the "just captured" flag.
  The captured turtle's face is covered (the same cover the screen always
  puts on a turtle with no energy) and the choice starts on the next
  turtle with energy, counting on from the captured one (code 3:$AA2A).
- The message is his name from the table at 3:$B47D (LEONARDO, RAPHAEL,
  MICHAELANGELO, DONATELLO), then the mark $FB, which carries on with
  " GOT / CAUGHT. WHO / FIGHTS NEXT?" from 3:$B4AE one place further on;
  after the long name the second entry there is used, starting on the
  second line (code 3:$AEAB, 3:$AFCC). Splinter says it in world 1 (the
  speaker comes from 3:$AEC6).
- The screen waits for Start (it stayed up 3 seconds untouched). Up and
  Down choose among the turtles who are left.
- Start does not go back to the room. The game starts the world again on
  its overworld, at the world's starting place, with the chosen turtle
  (code 7:$CE40: the play step becomes 3 minus the captured flag, which
  is the "begin the world" step; measured: inside flag 0, camera
  (16, 176), turtle at 144 across). The other turtles' energy is as it
  was and the captured one stays at 0.

## On the overworld (measured)

A roller's touch took all of Leonardo's energy. His animation becomes
$AB: picture 171 (flattened), which shows for 62 frames. As in a room the
Start screen comes up 147 frames after the blow with the same message,
and Start begins again from the world's starting place.

## The last turtle (measured, code)

With the other three already at 0, the same blow and the same 147
frames; then, instead of the Start screen (code 3:$A936: all four
energies are 0), the screen is cleared and shows GAME OVER alone (the
tile list at 7:$CA36). The counter at $46, which starts at 3, is taken
down by one (code 7:$CD24). If it is now 0 the game goes back to its
title. Otherwise, 272 frames after GAME OVER appeared, CONTINUE and END
are shown with a marker beside CONTINUE (code 7:$CD2B; tile lists 7 and
6 of the table at 7:$CAB7). Select moves the marker between the two and
Start chooses (code 7:$CD55). CONTINUE sets all four turtles' energy to
full and begins the same world again from its start with Leonardo; END
goes back to the title. So there are two continues.

## Rescuing a captured turtle (added 13 November 2026)

Script: `Research/cynes/rescue_checks.py`.

- **Where (code, measured).** Item kind 0E is the captive. It is one of
  the things a room has at fixed places (the list at bank 4, $AB94, which
  `RomLevels.fixed_things` reads). The whole game has four: world 3 area
  3 (at (896, 480) in the room), world 4 area 12, world 5 area 0 and
  world 6 area 0. Worlds 1 and 2 have none, so a turtle lost there stays
  lost until world 3.
- **When he is there (code 4:$B934, measured).** When the place comes up,
  nothing is made if the flag at $56 is set (a rescue has been made
  already). Otherwise the four turtles are gone through for one with no
  energy, starting at a number the frame counter gives (bits 1 and 2).
  The way it goes round has a slip: from start 2 it looks at turtles 2,
  3, 0 and 2 again, never at turtle 1. If none is found nothing is made.
  The one found is remembered in $57, the sprite graphics are switched
  (set 9) and colour patch $45 + his number puts his bandana's colour in
  sprite colour group 2. Measured in world 3's area 3: with Raphael
  captured the captive stood there in red; with Michelangelo and
  Donatello captured it was one of the two; with nobody captured there
  was nothing.
- **What he looks like (measured).** Picture 155 (animation $EB): a
  turtle standing, tied round with rope, six 8 x 16 sprites (three tiles
  mirrored). He does not move.
- **Touching him (code 6:$9756, measured).** The turtle in $57 gets full
  energy (128), the room's own sprite graphics and colours come back, $56
  is set to 1, a sound plays, and the captive is gone, all on the frame
  of the touch. Play goes on without a pause; the rescued turtle can be
  chosen on the Start screen from then on.
- **The flag (code).** $56 is cleared by a new game and by CONTINUE (they
  wipe that part of memory), and by the routine that ends a boss fight
  (6:$9E48) for every boss but the first and the third in its table. So
  after one rescue no other captive is shown until then.

Sprite map: `Resources/AssetRipper/Sprites/Captive.json`. In the remake
`RoomScene._place_items` puts the captive in when the room is loaded
(`captive_to_show`, with the original's way of going round), and
`_on_captive_freed` gives the turtle back. A picture of the remake's room
with the captive and one from the emulator agree in every pixel of him.

Found on the way: the remake drew every item 4 lines too low (the
original's sprites do not get the 4-line shift its background gets). A
slice of pizza and the captive now sit where the original shows them
(`Item.SPRITE_LINES_UP`); the item's box was left where it was.

Different: the remake chooses the captive when the room is loaded, not
when his screen comes up; the rescue flag is cleared after world 1's
last boss and by CONTINUE only (the later bosses are not made yet); no
sound.

## In the remake

`RoomScene._on_turtle_died` and `_step_capture` count the 147 frames
while the turtle shows his defeat pictures (new frames in `Leonardo.json`
and `LeonardoOverworld.json`), then open the Start screen with the
"caught" message (`InfoScreenData.caught_message`) or, for the last
turtle, `Scripts/UI/GameOverScreen.gd`. Leaving the Start screen, or
CONTINUE, begins the world again from its overworld start
(`_restart_world`); without a ROM, where there is no overworld, the
stand-in room is loaded again. END, or the third GAME OVER, starts the
game afresh.

Different from the original:

- The defeat pictures are drawn in the turtle's own colours, not colour
  group 3.
- On the GAME OVER screen the marker is a plain square (the original's
  is an object picture, number $49); Select moves it, as in the original;
  the words use the Start screen's letter tiles, which have the same
  letter numbers.
- (Corrected 13 November 2026: after END the original shows the notice
  again and then the title, measured; the remake does the same.)
- No sounds.
