# The end of world 1: from the last boss's fall to world 2 (USA ROM)

Worked out on 12 and 13 November 2026 in the emulator (cynes), frame by
frame, with the code read where noted. Facts are marked **(code)**,
**(measured)** or **(guess)**. Addresses are bank:address. Scripts:
`Research/cynes/world_end_checks.py` (the recording) and
`world_end_replay.gd.txt` (the remake's pictures for the same frames).

Frames below are counted from the frame the last boss (kind 71) is
beaten, as the picture shows them.

## What happens

| Frame | What the player sees | How known |
| --- | --- | --- |
| 0 | The boss turns into the usual puff; 5000 points. The boss's energy bar stays on the strip, empty. The buttons are dead from here on | measured; code |
| 20 | The puff is gone | measured |
| 86 | The turtle turns left and starts to walk by himself, one pixel every second frame, with his walking pictures | measured; code 6:$A070 |
| 93 | The boss's bar leaves the strip | measured |
| 309 | He has reached April (walking from 153 across): he is put at 50 across, standing; April, who sat tied on the crate, stands | measured; code |
| 559, 560 | The room breaks up (two frames of a half-cleared picture) | measured |
| 561, 562 | Black | measured |
| 563 | The Start screen, complete but for the map, which is drawn in over this frame and the next; April's face is there at once | measured |
| 571 | The first letter; one step of the message every 8 frames after it | measured; code |
| 1075 | The last frame of the Start screen (the message's end mark was read) | measured |
| 1076 | One frame of a half-cleared picture, then black | measured |
| 1078 to 1109 | World 2's overworld is drawn in from the top, a row of tiles a frame; the eight energy sprites show from 1081, all empty | measured |
| 1110 to 1125 | Everything stands still (the 16-frame hold) | measured |
| 1130 | The turtle appears on world 2's map and the energy sprites show his energy; play goes on | measured |

The score does not change after the 5000. No button does anything from
frame 0 to frame 1130: a run with Start, Select, A and the direction
buttons pressed throughout gave the same frames for every change of the
game's own state, and the turtle did not move in the first 86 frames
with Left held (measured).

## How the program does it

**The boss is beaten (code 6:$99B1).** For a boss (kinds 70 to 7F) the
hit routine puts a byte from the table at 6:$9A7F into $D2: 1 for kinds
71 and 73, 0 for the others listed. While $D2 is not 0 the turtle's own
routine clears the buttons before it looks at them (4:$9757), so he only
finishes what he was doing; and Start is refused (7:$CDCC).

**The wait (code 6:$9DD1).** With the fight flag ($5E) at 3 this routine
runs every update. Nothing happens while anything is left on the screen
(7:$EEE9; the puff counts). Then a sound, and a count of $20 updates in
$9B. When it runs out: $5E and the boss flag $B0 are set to 0, the
fight's bit is set in $7C and the "scene" number $B5 is taken from the
table at 6:$9E58 by the boss's number in $7B: 2 after the first boss, 3
after the last boss of world 1, then 9, 8, $0C, $0E, $0F, 8 for the
later ones. (The first boss waits $C0 updates more, with a tune, before
this.) Measured: 82 frames from the blow to $B5 becoming 3, of which 18
are the puff.

**While $B5 is not 0 (code 7:$CC9C)** the play routine does not run the
turtle or the enemies at all. Every second frame it calls the scene
routine at 6:$9F47, which has two tables of routines: one for a scene
that is beginning ($B5 = n, table at 6:$9F51) and one for a scene under
way ($B5 = n + $80, table at 6:$9F78).

**Scene 3, the walk (code 6:$A070).** Every call: all objects but
April are removed; the turtle faces left, his power-item flag and state
are cleared and his height is set to 140 (his middle). If he is to the
left of April, or less than 16 to her right, he is put at 50 across with
the standing picture, April's picture becomes 145 and she goes up one
line, and the scene is "under way". Otherwise he goes one pixel left and
his picture is chosen from 8, 9, 10, 9 by bits 3 and 4 of the frame
counter (so each shows 8 frames). The walk pays no heed to walls.

**Scene 3 under way (code 6:$A0BE)** waits for a byte of the sound
program's memory ($019D) to become non-zero, that is for the tune to end,
then sets $B5 to 4. Measured: 250 frames.

**Scene 4, April's words (code 6:$A0C8, 7:$D15C).** The Start screen is
put together in one go (its steps 0 to 5, with the playing turtle's row
lit), then the map and the message routine are run every second frame
(7:$D1AD) with the message state $8E at 1. State 1 (3:$AE5B) takes the
message from the table at 3:$B4ED by world, spoken by April (by Splinter
in the third world); a seventh entry is used instead when $03D4 is set
(not looked at). The marker is not drawn and no button is read. World
1's message is "DON'T LET THE / FOOT CLAN DE- / STROY THE DAM." and
then April's closing words. Because the routine runs every second frame
a step of the message takes 8 frames, not the 4 of the Start screen in
play; the message is 64 steps (measured: 512 frames from the first
letter to the last frame). The heading still says AREA 1 and the map is
world 1's.

**The message's end (code 6:$A0E7, 3:$AF86).** The end mark sets $8E to
3; the scene routine sees it and sets the world ($48) and area to 1, the
"inside" flag to 0 and the play step ($34) to 2, which is "begin the
world". The numbers 1 are written into the code: this scene serves the
end of world 1 only.

**World 2 begins (code 7:$D2D7, 4:$96B8).** The screen's corner comes
from the table at 7:$D679 (four bytes a world) and the turtle's place on
the screen from the table at 7:$D73D (two bytes a world). Measured for
all five worlds by setting the play step to 2:

| World | Screen corner | Turtle on the screen |
| --- | --- | --- |
| 1 | (16, 176) | (144, 120): 16 further right than the table's 128 |
| 2 | (0, 0) | (128, 136) |
| 3 | (224, 160) | (128, 124) |
| 4 | (768, 768) | (128, 168) |
| 5 | (384, 160) | (128, 120) |

(For world 1 the same step started from the middle of play gave corner
(32, 176) and 128 across: the same place on the map, so its first screen
is pushed 16 by something else. Not looked into.)

The map is drawn in as after a door, but the picture's rows come two
frames later, the turtle appears 4 frames later (5 after the hold, not
1), and the eight energy sprites are on show from the fifth frame with
the empty tile ($AE), turning to his energy when he appears (measured).

## April (measured)

She is object slot 15 with no kind number, made on the frame the boss
comes in. Tied: picture 144 at (26, 166) on the fight's screen. Freed:
picture 145 at (26, 165). Her sprites are 8 x 16, from the sprite page
the fight uses (page 8), in sprite colour groups 2 (0F 08 24 37) and 3
(0F 0F 26 37). The sprite map is `Resources/AssetRipper/Sprites/April.json`.

## In the remake

- `RoomScene._on_boss_defeated` starts the scene for the world's last
  boss; `_step_world_end` runs it (`EndStage`: the wait, the walk, the
  250 frames, the message), `_see_to_april` keeps April in the room
  while the boss or the scene is there, and `_begin_next_world` starts
  the next world with the map drawn in (`_start_wipe(true)`).
- The buttons are made dead by releasing the game's actions every frame
  before the turtle looks at them (`_mute_buttons`).
- `StartScreen.open` takes `event: true`: `InfoScreenData.event_message`
  for the words, 4 dark frames, a step every 8 frames, no marker, no
  buttons, the right 8 pixels dark (the room's edge sprites are still
  there in the original), and `event_finished` a frame after the end.
- `RomLevels.overworld` now takes the turtle's place on the first screen
  from the ROM's second table (`RoomData.start_camera` is the corner).
  Before, world 2 began 16 lines out.
- `RoomScene.finish_world_end()` skips the scene (tests).

Compared with the emulator, picture against picture, 73 frames between
frame 82 and frame 1131: every pixel below the top 4 lines is the same,
except

- the eight pixels on the strip's first line that `hud.md` lists (on
  some frames);
- frames 559 and 560, and 1076, where the original shows a half-cleared
  picture and the remake black or the old picture;
- frame 563 (and 564), where the original's map is still being drawn;
- frame 1080, where the original shows a few stray sprites;
- one of the eight energy sprites, which flickers in the original;
- the puff (frames 0 to 19): the remake's puff is the enemies' own and
  ends one frame early.

Not done, or different:

- No sounds; the 250 frames are a count, not a tune's length.
- The picture the turtle shows between the blow and the walk is whatever
  the remake's turtle shows with no buttons (the original's finishes its
  swing the same way; not compared pose by pose).
- The walking pictures' phase goes by the original's frame counter; the
  remake starts it where the recording had it.
- Only world 1's ending is made. The other bosses' scenes (numbers 2,
  9, 8, $0C, $0E, $0F in the table above) were not read; after the first
  boss the remake does what it did before.
