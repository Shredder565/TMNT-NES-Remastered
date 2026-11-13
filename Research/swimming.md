# Swimming: the turtle in world 2's lake (USA ROM)

Worked out on 13 November 2026. **(code)** = read from the program,
**(measured)** = seen in the emulator (cynes), **(guess)**. Addresses
are bank:address. Speeds are in 1/256 pixel an update; an update is two
frames; his position value is his middle (his feet are 20 below it).
Scripts: `Research/cynes/swim_record.py`, `swim_replay.gd.txt`. The
remake's swimming is the last section of `Scripts/Player/Turtle.gd`
(and `RoomScene._on_swim_row_wanted`, `_step_swim_row_change`).

## When he swims (code)

Every update the turtle's routine asks 4:$996F: is the program's world
1, its area 1, and is he inside? If so $D3 is set to 1. His ground
routine (states 0 to 3, 4:$9D0C) asks the same first and, if so, sets
his state to 0F and does nothing else on that update. State 0F is at
4:$A78B. State 10 (4:$9CFA) waits for an animation to end and then sets
0F; who uses it was not looked for.

## One update (code; the order is the walking turtle's, `turtle_collision.md`)

1. He is moved by the speeds his last update left, or the screen
   scrolls instead: left of 96 across the screen going left, from 160 on
   going right, as on foot (4:$9851). He is kept between 20 and 236
   across.
2. **Up and down the screen** (4:$98C3). His middle is kept from 16 to
   181 down the screen; at either his downward speed is set to 0. At
   exactly 16 or 181, unless a fight holds the screen or he is dead, the
   screen is told to change row ($3F = 1 up, 2 down), the bubble is
   removed, and **nothing else happens on that update**: his routine is
   not run. Measured: a step the screen was to scroll sideways on that
   update is lost too.
3. Otherwise state 0F runs:
   - the water's colours (4:$A992, below) and the clock (4:$A94E,
     `world2.md`); with the clock at 0 nothing more is done;
   - the bubble (below);
   - **facing**: Left or Right held turns him; with both, left;
   - **animation**: no direction held: BC if A is held or he is still
     rising, else BF. Left or Right without Up or Down: BE. Down (with
     or without a side): 8C. Up: BC;
   - **sideways speed**: its whole pixels are set to 2 right, 2 left or
     0 (both or neither held); its fraction is left as it was;
   - **sinking**: 16 is added to his downward speed; if that makes 2
     whole pixels or more the whole pixels are set to 2;
   - **a stroke**: on a new press of A, 224 is taken off;
   - **a current** ($7E not 0; the high four bits pick: $10 up, $20
     down, $40 right, $80 left; tables at 4:$A9C0 and $A9C5): 18 up or
     down, or 48 across, is added; and with Down held 48 more downward;
   - the downward speed is held: 2 whole pixels or more becomes exactly
     2, less than 2 upward becomes exactly 2 upward;
   - **the map** (below).

## The map (code 4:$A896; tables 7:$C821 points 19 to 1E and 2C to 2F, list 7 at 4:$A74D)

Each look is at his middle, plus a point, **plus the whole pixels of
both his speeds as they stand at that moment** (7:$C7AA): he feels where
he is about to be.

- If he has any sideways speed: 13 to the side he is moving to (right
  if the whole pixels are not negative), at 7 above and 7 below. If
  either stops him his sideways speed is set to 0, fraction and all,
  and the looks that follow no longer add it.
- Rising: 7 above, at his middle, 8 right and 8 left. Otherwise 7
  below, at the same three. Any stops: his downward speed is set to 0.

What a look finds:

| Cell kind | What happens |
| --- | --- |
| 4, wall | Stops him |
| 1, the weed | The hurt routine (4:$A5BB) runs there and then; does not stop him |
| 0F | His state is set to 13; stops him |
| 2, doorway | Would be the door state (0D) unless a fight is on; none in this map |
| anything else | Nothing |

Cells are 16 x 16 as everywhere (`turtle_collision.md`); checked here
against the cell memory at $0700 for one screen (measured).

## Being hurt (code 4:$A5BB, 4:$97A3)

By the weed: nothing while he is blinking; else a sound, 16 energy off,
the blink flag and a safe time of 24 updates. He is not thrown and his
state stays 0F. $03EC is set, and while it is and he blinks the water's
colours change every update (palettes $2B and $2C by the low bit of the
safe time); when the safe time ends they are put back.

Out of energy while blinking: the "alive" bit of his flags is cleared
and animation DA is started (pictures 9F, A0, A1, then two empty, 6
updates each); when it has ended the usual losing-a-turtle path follows.

**State 13** (4:$A412; measured in one run): on the update after the
look that found kind 0F he is first moved by his speeds as usual, then
put 13 higher, his energy is set to 0, both speeds to 0, and animation
DB is started (pictures A2 to A5, then two empty, 16 updates each).
Measured: found at 108 down the screen while rising at 2; 93 two frames
later, energy 0.

What an object's touch does to a swimmer was not read.

## The change of row (code 4:$9A87; measured)

The routine is the one a ladder uses. Counted in his updates from the
one that asked: updates 1 to 48 move the screen 4 pixels each. On the
first 8 he keeps his place on the screen; on the other 40 he keeps his
place in the room (so on the screen he goes 160 the other way). Update
49 ends it: going up he is put 2 higher (so from 16 he ends at 174;
going down, from 181 at 21); the current is forgotten ($7E = 0) and the
things at fixed places are cleared to be made again. Then the game
stands still for 4 frames, and his next routine runs on update 52.
His picture stands meanwhile: every update of the change adds one to its
count and every frame between takes one off.

(This differs from what `live_play.md` measured for the ladder in world
1's last room, "his place in the room for the first 40, then carried";
the same code serves both. Not looked into; the ladder path is not
changed.)

Nothing in the code stops a change of row at the top row. Measured: at
the gap in the lake's ceiling at about (1232, 8) he reaches 16, the
screen scrolls up out of the map (its corner's Y becomes -192) and he
swims on in whatever is there. **The remake does not copy this**: with
no row above, he is held at 16.

## The bubble (code 4:$A910; measured)

Object slot 1, the weapon's, is used: whenever its animation is not D8
it is put at his middle, 14 right (facing right) or 8 left, and 12 up,
with animation D8 (one picture, 89) and an upward speed of 384. It
moves on the enemies' frames. Measured: it goes when it is less than 16
from the screen's top, and a new one starts on his next update. B does
nothing under water: the routine never reads it.

## Pictures and box

- Animations (table 6:$8BC5, 5 updates a picture): BC = pictures 80,
  81, 82; BE = 83, 84, 85; BF = 83; 8C = 86, 87, 88. Measured: an
  animation that starts shows its first picture from the next enemies'
  frame; at the end of the list one frame is spent on the end mark, so
  the last picture shows a frame longer.
- The sprite map `Resources/AssetRipper/Sprites/TurtleSwim.json` was
  taken from the game's sprite table (tile numbers and places only):
  pictures 80 to 88, 9F to A1, A2 to A5 and the bubble. Sprite pages 17
  and 24; his colours are the usual ones (0F 09 12 2A for Leonardo).
  Each tile's place is the one seen most often; picture 84 may be a
  pixel out.
- His box under water (table 6:$8835 by animation): half 11 across and
  6 down for all four animations, at his middle.

## Compared with the emulator

26 scripted runs, the turtle alone (objects, fixed things and currents
cleared every frame in the emulator; his energy refilled each frame
except in one run): sinking, each direction, strokes at seven rhythms,
A held, both sides held, three rows of the lake, the weed-lined shaft,
changes of row up and down, a run into the deadly kind, the room's left
end. Compared on every frame: his place to 1/256 pixel and the screen's
corner; both speeds; animation and picture; facing; energy.

| Runs | Frames | Place | Speeds | Animation and picture | Facing | Energy |
| --- | --- | --- | --- | --- | --- | --- |
| The first 18 | 17256 | 17256 | 17256 | 17256 | 17256 | 17256 |
| 7 more (without the gap in the ceiling) | 4045 | 4045 | 4045 | 4045 | 4045 | 4045 |
| The gap in the ceiling | 497 | 147 | 211 | 225 | 497 | 495 |

The run into the deadly kind is compared up to the frame both find it
(the same frame); what follows was checked by hand against the numbers
above. One run starts inside the deadly kind and compares nothing.

Put right on the way: the looks up and down must use the sideways speed
after a wall has set it to 0; the end-of-list frame of an animation; the
lost sideways scroll on the update that asks for a change of row; the
picture's count during the change.

## Not done, or different

- The gap in the ceiling (above).
- The water's colours do not flash while he is hurt, and the two
  colour changes every 256 frames (4:$A997) are not made.
- The clock, the currents' places, bombs and other things: `world2.md`.
  The remake's turtle takes a current from `swim_current`, which
  nothing sets yet.
- Coming into the water through the door (his first frames) has not
  been compared; nor a touch by an object.
- Sounds.
