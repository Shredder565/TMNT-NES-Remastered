# Sound: the original's sound program, and ours

Everything here is **read from code** (bank 0, $85EC-$918A, and the fixed
bank's entry points) unless it says **measured** or **guess**. Addresses are
bank:address. Our own program is `Scripts/Sound/`; it is written from this
note, not from the listing. Nothing of the ROM is shipped: the tables and
the music data are read out of the player's ROM when the game starts.

## 1. Where it lives

| What | Where |
| --- | --- |
| "Start sound number A" (called all over the game) | 7:$CEF0. It notes the bank in use, brings in bank 0, calls 0:$9057, and puts the bank back |
| "Silence everything" | 7:$CEC0, which calls 0:$9016 |
| Once-a-frame step | 0:$8644, called by 7:$CED5 from the picture interrupt (7:$C3A3) |
| Table of sounds | 0:$918B, three bytes for each number (its address is the word at 0:$9014) |
| Sound and music data | 0:$933B to about 0:$BEAF |
| Loudness-shape tables | pointers at 0:$BEB0, data after them |
| Pitch-wobble tables | pointers at 0:$BEE2 (the same block of pointers, 25 entries further on) |
| Note pitches | 0:$8FE4 (24 notes, two octaves) and 0:$8FCC (the 12 notes below) |
| The one drum sample | its four chip values at 7:$FE41; its 129 bytes of data at 7:$FF00 |

The interrupt calls the step on **every** picture, also on pictures where
the game itself is late (the frame counter $1E does not move), so music
keeps time while the game slows. Two exceptions: the step is left out if
the interrupt lands while the game is in the middle of changing banks ($F0
bit 7) or in the middle of a "start sound" call ($2F bit 7). **Measured**:
in the 400 frames of the title tune after power-on this happened once.

## 2. Six voices

The program runs six voices ("slots"), in this order each frame:

| Slot | Chip channel | Used for |
| --- | --- | --- |
| 0 | first square wave ($4000-$4003) | music |
| 1 | second square wave ($4004-$4007) | music |
| 2 | triangle ($4008-$400B) | music (bass) |
| 3 | noise ($400C-$400F) | the music's drum track. It makes no sound itself: each drum note *starts a sound effect* (in slot 5) or the drum sample |
| 4 | first square wave again | sound effects |
| 5 | noise again | sound effects, and the drums slot 3 asks for |

**Effects take the first square wave from the music.** While slot 4 is
busy, every value slot 0 wants to send to the chip is thrown away (the
check is in the "may I write" helper 0:$8CE8, and only slot 0 is checked);
slot 0 keeps reading its notes and stepping its loudness all the while, so
the tune stays in time. When the effect ends (0:$8F55) the channel is
silenced, and if slot 0 is playing, its loudness and its pitch as they
would be now are sent again, so the music comes back mid-note. The noise
channel has no such check: slot 3 only starts things in slot 5, and an
effect in slot 5 just replaces whatever is there, subject to the rule
below.

## 3. Starting a sound (0:$9057)

The number picks an entry of the table at 0:$918B: one byte and an address.
Bits 0-2 of the byte are the slot; bits 3-4 say how many more entries
(the ones that follow it in the table) belong to the same sound. So a
sound is one to four voices, and a tune is simply four table entries in a
row: `$4E` is the first tune (entries $4E, $4F, $50, $51 for slots 0-3).

- Numbers `$01-$4A` are effects. Number 1 is an empty effect for slot 5
  (it only stops the noise). Number 0 is not a sound (its "entry" is
  program bytes).
- Numbers `$4B` and up are tunes: `$4B` and `$48` (three voices, slots
  4, 1 and 5, written in the effects' format), and the four-voice tunes
  `$4E $53 $57 $5B $5F $63 $67 $6B $6F $73 $77 $7B $7F $83 $87 $8B`.
  `$52` is a lone entry for slot 3 that plays no drum at all, for ever:
  starting it is how the game says "silence, and keep it".
- Numbers `$8F` and up are samples: number - `$8F` picks four bytes at
  7:$FE41 which go to $4010-$4013, between $0F and $1F written to $4015.
  Only sample 0 (number `$8F`) is real: rate 15, start level 0, data at
  $FF00, 129 bytes; the bytes after the first table entry are program.

Rules before anything starts:

- A tune (`$4B` up): refused while tune `$83` is in slot 3. Otherwise
  everything is silenced first (see below), except for tunes `$77` and
  `$7F`, which start over whatever is playing without that silencing.
  Starting `$83` or `$7F` clears the "tune over" byte $019D.
- An effect: number `$16` is refused while `$16` is already in slot 5 (it
  does not start again on top of itself). While tune `$77` is in slot 1,
  effects 7 to `$3D` are refused.
- Then, voice by voice: **a voice is only taken if the new number is not
  lower than the number playing in that slot.** A lower number is simply
  dropped for that voice. (So effect `$21` cuts off `$07`, not the other
  way; and a tune's voices always win.)

Taking a voice: its data address is set, its length count is set to 1 (so
the first step reads the data), its loop count is cleared, the "last high
pitch byte sent" is set to an impossible value so the first note sends it;
for slots 0-1 the quieting, the "second tone" byte and the echo are
cleared; for slots 0-2 the transposing is cleared. **The format of the
data is decided by its first byte: below `$30` it is in the effects'
format, otherwise in the music format** (and then the fade-out counters
are cleared). Last, the channel is quietened: `$30` to its first register
and `$7F` to its second (for the triangle 0 to the first); for slot 0 only
if no effect holds the channel.

"Silence everything" (0:$9016): does nothing while tune `$83` is in slot
3; otherwise clears all six slots, the two wobble counters and the
fade-out bytes, silences the triangle ($0B to $4015, 0 to $4008, $0F to
$4015), and sends `$30` to $4000, $4004, $400C and `$7F` to $4001, $4005.

## 4. Each frame (0:$8644)

First the **fade-out** (0:$8612; the game starts one by putting 7 in
$0199, at 2:$B88C, 2:$BF9F and 3:$BCC6). While $0199 is not 0: when it is
1 everything is silenced as above (which also ends the fade); when it is 2
and the counter $0198 is exactly `$20`, the drum track (slot 3) is
stopped; otherwise the counter goes up, and each time it reaches `$2F` it
goes back to 0, the fade amount $0197 goes up by one, and $0199 down by
one. The fade amount is taken off every loudness the two music square
waves send. So a fade lasts 6 x 47 = 282 frames, a step quieter every 47.

Then each slot that holds a sound, 0 to 5:

1. Its length count goes down. If it reaches 0, the next piece of its
   data is read (section 5 or 6) and that is all for this frame.
2. Otherwise nothing more is done for slots 2-5, for a voice in the
   effects' format, or for a voice that is in a rest. The rest of this
   list is the music square waves only.
3. **Echo memory**, if the echo is on: when the frames left are an exact
   multiple of the tempo unit (twice the unit for echo settings 4 and
   up), the note's pitch is written into the next of four remembered
   pitches.
4. **Wobble** (vibrato), if on, and not in the tail of a note: its count
   goes down, and at 0 the next step of the wobble table moves the pitch
   and the pitch is sent.
5. **Loudness**: its count goes down, and at 0:
   - first the tail check: if the frames left are fewer than the note's
     "tail length", the voice enters its tail. If the "second tone" byte
     has a tail loudness (bits 2-3), that loudness is sent now; if its
     bit 1 is set, the tail uses the second tone.
   - then, by the stage the note is in:
     - *shaped by a table*: the next byte of the loudness table is
       taken: low four bits are the loudness, high four bits (if not 0)
       how many frames to hold it. `$FB` marks where a repeat starts;
       `$FE n` goes back to the mark until it has been passed n times;
       `$FF` ends the shape and the note holds.
     - *simple shape*: one quieter each frame, for as many frames as the
       shape number says, then hold.
     - *hold*: nothing.
     - *tail*: with the echo on, the pitch is replaced by the
       remembered pitch from 1, 2 or 3 notes back (the echo setting)
       and sent. Then, unless a tail loudness was given: every
       "fall time" frames the loudness goes one down, but never below 1.

Sending a loudness (0:$871E): 0 is sent as 0. Otherwise the voice's
quieting is taken off, then the fade amount; if either would bring it to
0 or below it is 1 instead. It is joined with the voice's tone bits (or
the second tone's, when that is in use) and sent to the channel's first
register.

Sending a pitch (0:$8BDA): the high byte first (with bit 3 set, which is
a length code that never runs out in practice), then the low byte. For
the two music square waves the high byte is **left unsent when it has not
changed** since the last one sent, as long as the voice has no sweep and
its tone byte has the "steady loudness" bit; writing it would restart the
wave and click. If a wobble table has run to its end (`$FF`), pitches are
no longer sent for that voice until its next note.

## 5. The music format (slots 0-2; slot 3 below)

A byte's high four bits are the command, the low four its first value.

| Byte | Meaning |
| --- | --- |
| `0n`-`Bn` | A note: high bits 0-11 are the twelve notes of the pitch table, low bits the length: (n+1) tempo units |
| `Cn` | A rest of (n+1) tempo units. The channel is silenced |
| `Dn` + bytes | Tempo unit = n frames, then the instrument. Square waves, three more bytes: tone bits (high four) and loudness (low four); the loudness shape number; the tail byte (below). Triangle, one more byte: the note-length setting |
| `E0`-`E5` | Octave. The table pitch is halved (5 - octave) times, so 5 is the table itself and lower numbers are higher octaves |
| `E6 xx` | Tempo unit = xx |
| `E7 xx` | Loudness shape number |
| `E8 xx` | Tail byte: low four bits = tail length in sixteenths of the note's length; high four bits = fall time in frames (0 counts as 1) |
| `E9 xx` | Tone. 0: stop using the second tone. Low four bits 0: xx becomes the tone bits. Otherwise xx is the "second tone" byte: high four bits are the tone used instead of the normal one, bit 0 = use it at the start of each note, bit 1 = use it in the tail, bits 2-3 = tail loudness |
| `EA xx` | Transpose all following notes by xx half-notes (bit 7 set: downwards, by the low bits) |
| `EB xx yy` | Wobble on: xx high four bits = delay before it starts, in tempo units; low four = depth; yy = which wobble table. `EB 00` (two bytes) turns it off |
| `EC xx` | Echo: 0 off; 1-3 = the tail plays the note 1-3 notes back; 4-6 the same but the memory is written every second tempo unit |
| `F0`-`FA`, `FC` | Quieting: this much is taken off every loudness |
| `FB` | Mark the start of a repeat |
| `FE n` | Go back to the mark until this has been passed n times |
| `FE FF lo hi` | Jump to an address (how tunes loop for ever) |
| `FD lo hi` | Play the piece at this address, then come back (one level deep) |
| `FF` | End of a called piece; otherwise the end of the voice |

A note on a square wave: the loudness shape starts at once (with a table,
its first value is sent; with the simple shape, numbers `$80` up, the
instrument's loudness is sent and the low four bits of the number are
the count of quieter steps). With a table shape the instrument's
"loudness" value is not a loudness but the quieting. Then the pitch: the
table entry for the note (moved by the transpose; below the table's first
note the second, lower table is used), halved for the octave. If the echo
is on the pitch goes into the memory. If the wobble has no delay its
first step is applied at once. The note's tail length is worked out as
(frames x tail sixteenths) / 16, rounded down.

The wobble (0:$8857): each table byte's low four bits are a step, 0-7 up
and 9-15 down (16 minus it), times the depth, added to the note's pitch
number; high four bits (if not 0) are how many frames until the next
step. `$FB`, `$FE n` and `$FF` as in the loudness tables.

The triangle has no loudness; the length of its notes is set through the
chip's own counter ($4008). With setting L from the instrument: L = 0
plays the whole note; L of `$80` or more sends L minus `$80`; otherwise
(L+1) x (note's length number + 1) is sent, and anything of `$80` or more
plays the whole note. So with a small L the bass notes are short and get
longer with their written length.

When a voice ends: square waves and the effect noise are silenced; the
triangle is silenced; slot 3 ending tune `$83` or `$7F` sets the **"tune
over" byte $019D to $FF**, which the game waits on in four places
(2:$BDE3, 2:$BE13, 4:$9797, 6:$A0BE).

### The drum track (slot 3)

Only `Dn` (tempo unit, no more bytes), the `F` commands, and notes. A
note's low four bits are its length as above; its high four bits are the
drum: 0-4 start effects 2, 3, 4, 5, 6; 5-10 start effect 2; 11 starts the
sample; 12 is a rest. Because drums are ordinary effects in slot 5, the
rule of section 3 applies: a drum is dropped while a higher-numbered
effect is making noise there.

## 6. The effects' format (slots 4 and 5, and three-voice "tunes")

| Byte | Meaning |
| --- | --- |
| `0n` (n not 0) + bytes | Frames for each following note = n. Square wave: two more bytes, the tone byte (sent whole as the channel's first register, see below) and the sweep byte for the second register (`$88` means "no sweep": `$7F` is sent). Noise: nothing more. Triangle: one more byte, sent to $4008 |
| `F8 xx` | Frames for each note = xx (not for the noise) |
| `F9 xx` | Tone byte = xx (not for the noise) |
| `FA xx` | Sweep byte = xx (not for the noise) |
| `FB`, `FD`, `FE`, `FF` | As in music |
| anything else | A note. Square wave, two bytes: high four bits of the first = loudness, low four = high part of the pitch number, second byte = low part. Noise, one byte: high four bits loudness, low four the noise pitch |

If the tone byte has the "steady loudness" bit, each note sends tone
byte + loudness; if not, the tone byte is sent as it is and the chip's own
fading does the loudness (the note's loudness nibble is then unused).
Effects use the chip's sweep for slides and its fading for decays; the
program does nothing to an effect voice between its notes.

On the noise the tone byte is `$30` (steady loudness), and the mode bit
(the "metallic" noise) cannot be set by an effect note, since only four
pitch bits are sent.

## 7. Memory (per slot X unless said)

$010A number playing (0 = free). $0104 frames left of the note. $0110
tempo unit. $0116 flags: bit 0 effects' format, bits 1-2 loudness stage
(0 table, 1 simple, 2 hold, 3 tail), bit 3 inside a called piece, bit 4
wobble on, bit 5 use the second tone, bit 6 resting, bit 7 has a sweep.
$011C repeat count. $0122/$0128 data address. $012E/$0134 repeat mark.
$013A/$0140 address to come back to. $0146 last high pitch byte sent.
$014C loudness now. $0152 instrument loudness. $0158 tone byte. $015E
octave. $0161 transpose (slots 0-2). $0154 triangle note-length setting.
Slots 0-1 only: $0164 shape number, $0166 shape count, $0168 shape
place, $016A/$016C shape repeat count and mark, $016E tail length, $0170
tail sixteenths, $0172/$0174 fall time and its count, $0176 quieting,
$0178 last low pitch byte, $017A/$017C the note's pitch, $017E wobble
delay, $0180 wobble count, $0182 depth, $0184 table, $0186/$0188/$018A
place, mark and repeat count, $018C second-tone byte, $018E echo setting
(`$80` off), $0190 next place in the echo memory, $019E-$01AD the echo
memory (four pitches for each of the two voices).
One of each: $0192/$0193 slot and register offset being worked on, $0194
number asked for, $0197-$0199 fade amount, counter and stage, $019A last
effect sweep, $019C last triangle length sent, $019D tune over. $0196 is
read as "silence slot 0 when the effect gives the channel back" but
nothing in the ROM ever writes it.

## 8. Every call of "start sound" in the game

All 76 places that call 7:$CEF0 (found by searching the ROM for the call;
**read from code** means the lines just before the call were read, not
always the whole routine). "Ours" is where our game makes the same call;
"-" means that part of the game is not in the remake yet, or the call was
not followed far enough to place it.

**Measured**: in the ten whole-room recordings of `Research/live_play.md`,
made again with the number asked for written down each frame
(`Research/cynes/sound_live_record.py`, `sound_live_replay.gd.txt`), the
original asked for a sound 204 times (jumps, landings, swings, hits,
enemies beaten, the turtle hurt, the boss's tune); ours asks for the same
number on the same frame all 204 times.

### The turtle (bank 4)

| Where | Number | When | Ours |
| --- | --- | --- | --- |
| 4:$9E7B | `$07` | a jump begins (his state becomes 7) | `Turtle._control` |
| 4:$A1B0 | `$08` | he lands (any landing: a jump, a fall, a throw by a hit) | `Turtle._test_room` |
| 4:$9F6B | `$0A $0C $0E $10` | a swing begins: one number per turtle (table 4:$9F7C); Donatello's is `$12` instead inside a room | `Turtle._begin_swing` (number set in `RoomScene.set_turtle`); the overworld swing is not wired |
| 4:$9F79 | `$14 $14 $16 $17` | a special weapon is thrown, by its kind 1-4 (table 4:$9F80) | `RoomScene._on_throw_started` |
| 4:$9845 | `$3C` | Select changes weapon (only if he has any special weapon) | `RoomScene.press_select` |
| 4:$A5CE | `$25`, or `$2F` when $D3 is set | hurt by a hurting tile (16 energy) | `Turtle.tile_hurt` (`$25` only; what sets $D3 was not followed) |
| 4:$97BB, 4:$A414 | `$83` | the turtle's energy is gone: the "caught" tune. The game then waits for $019D (4:$9797) before the Start screen opens | `RoomScene._on_turtle_died` |
| 4:$999E | `$33` | energy below `$18`: the low-energy warning, once ($03D6 remembers) | - |
| 4:$9A0B | `$2C` | his state becomes `$16` (going into a doorway/manhole; **guess**) | - |
| 4:$9A45 | `$29` | his state becomes `$17` (coming out; **guess**) | - |
| 4:$A561 | `$2A` | a count runs out in a state not followed | - |
| 4:$A974 | `$33 $63 $67` | by $BB (`$16`, `$15`, `$05`): not followed | - |
| 4:$A980 | `$4B` | not followed (overworld van; **guess**) | - |
| 4:$AA16 | `$32` | getting into the van (**guess**) | - |

### Hits and items (bank 6, $9600-$9B00)

| Where | Number | When | Ours |
| --- | --- | --- | --- |
| 6:$994A | `$21`; `$41` for kinds 74/75 in slot 5 | a weapon lands on an enemy | `Turtle.weapon_lands` (`$21` only) |
| 6:$9A13 | `$22` | an enemy is beaten. In a held fight ($5E = 3) only kinds 98 and 8D make it | `Puff.leave` (always `$22`) |
| 6:$9A1B | `$42` | kind 76 beaten in a held fight | - |
| 6:$9A4D | `$01` | on the overworld, kinds 12-14 beaten (stops their noise) | - |
| 6:$98F7 | `$25` | the turtle is hurt by a touch | `Turtle.take_damage` |
| 6:$96AF | `$34` | a pizza (kinds 01-03) is picked up | `Item.pick_up` |
| 6:$971F | `$35` | a special weapon (05-08), the power item (0B), missiles (0C) or ropes (0D) picked up | `Item.pick_up` |
| 6:$976E | `$3D` | a captured turtle is freed (kind 0E) | `Item.pick_up` |
| 6:$97B6 | `$22` | touching kind 40 with $0606 set: not followed | - |
| 6:$97BE | `$83` | touching kind 51 (it takes the turtle at once) | - |
| 6:$97F0 | `$32` | touching kind A2 (getting in the van; **guess**) | - |
| 6:$9ABC, 6:$BB32 | `$27` | something collected that sets a bit in $80/$81 or $8C: not followed | - |

### Fights, bosses and the end of a world (bank 6, $9C00-$A800)

| Where | Number | When | Ours |
| --- | --- | --- | --- |
| 6:$9CC7 | `$7B` | a held fight with a boss begins (encounter slot 0), after "silence everything" | see section 9 |
| 6:$9CD6 | `$73` | the same for the other kind of boss entry | `RoomScene._start_fight` |
| 6:$9DB4, 6:$9E03 | `$77` | the boss is beaten: the short tune that starts on top of everything | `RoomScene` (section 9) |
| 6:$9DF2 | `$42` | world 3 only, when a count of bosses reaches 0 | - |
| 6:$9E54 | `$7F` | the world is won (worlds 1-4) | `RoomScene` (section 9) |
| 6:$A0CA, 6:$A324 | `$52` | world-end scene: silence | section 9 |
| 6:$A1DD, 6:$A2AA, 6:$A41B, 6:$A49C, 6:$A567, 6:$A67A, 6:$A69E, 6:$A6E1, 6:$A715, 6:$A779 | `$32 $3F $19 $1B $1C $29 $2C $44 $48 $31` | steps of the scenes between worlds: not followed one by one | - |
| 6:$AB5F, 6:$AB78 | `$20`, `$1E` | A and B in the van: firing | - |

### Enemies (bank 5)

| Where | Number | When | Ours |
| --- | --- | --- | --- |
| 5:$8A07, 5:$8A18 | `$24`, `$28` | kinds below 70 at 5:$89F8: not followed | - |
| 5:$B156, 5:$BD07 | `$2D` | a boss fires or throws | - |
| 5:$B6F4, 5:$BE4A | `$45`, `$46` | later bosses, after "silence everything" | - |
| 5:$BA0B | `$42`, or `$48` for slot 5 | a boss is beaten | - |

### Screens (banks 2, 3 and 7)

| Where | Number | When | Ours |
| --- | --- | --- | --- |
| 7:$C5D6 | `$4E` | the title appears | `TitleScreen.show_phase` |
| 7:$C605 | `$3C` | Start on the title | `TitleScreen.press_start` |
| 7:$CDEE | `$3E` | Start in play: the Start screen opens | `RoomScene.open_start_screen` |
| 3:$AA8B | `$3C` | the choice on the Start screen moves (more than one turtle left) | `StartScreen.move_selection` |
| 3:$AF7E | `$39`, or `$36` when $24 is set | each letter of a message that is typed | `StartScreen._type_one` (`$36` for the world-end message is a **guess**) |
| 3:$BAE4 | `$4E` | not followed | - |
| 3:$BE57, 3:$BEB8 | `$3A` | not followed | - |
| 7:$CBF9, 7:$CC01, 7:$CC09 | area's tune | a world, room or overworld begins (section 9) | `RoomScene.show_room` |
| 7:$CD21 | `$8B` | a long count ($9D/$9E) reaches `$FF00`: not followed | - |
| 7:$F3BD | `$38` | while a number in the top strip counts ($0A set): not followed | - |
| 7:$FDA8 | `$16` | every update the boomerang (kind 27) flies | - |
| 2:$B631, 2:$BDDD, 2:$BE10 | `$7F` | the scenes of bank 2 (the story pictures): not followed | - |
| 2:$B66C | `$4E` | the same | - |
| 2:$BA00 | `$31` | the same | - |
| 2:$BDEA | `$87` | the same, after waiting for $019D | - |
| 2:$BF91 | `$52` | the same | - |

**Measured** on the Start screen: `$3E` on the frame it opens, `$39` for
each letter (every 4 frames), `$3C` when the choice moves, nothing when it
closes; **the tune goes on playing** behind the Start screen.
