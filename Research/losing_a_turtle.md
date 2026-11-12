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
- On the GAME OVER screen the marker is a plain square and is moved with
  Up or Down (the remake has no Select button); the words use the Start
  screen's letter tiles, which have the same letter numbers.
- END goes to the title in both (see `title_screen.md`); the remake
  shows the notice again first.
- What the original does about a captured turtle later (rescuing him)
  was not looked at.
- No sounds.
