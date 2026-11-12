# Where the original puts its enemies (USA ROM)

Worked out on 10 November 2026 by disassembling the placement code in
program bank 6 ($8146-$82E8 creates an enemy from a placement entry,
$8600-$8680 walks the list as the camera moves) and watching the first
sewer in an emulator. The check can be re-run with
`Research/cynes/enemy_checks.py`. The decoder is in
`Scripts/Rom/RomLevels.gd`.

## Placement entries

Every screen of every map has a list of 3-byte entries ending in $FF.

| Byte | Meaning |
| --- | --- |
| 0 | X inside the screen |
| 1 | Y inside the screen |
| 2 | Slot: which of the room's enemy kinds to put here |

The slot byte only ever takes six values in this ROM ($80, $89, $92, $9B,
$A4, $AD); its low three bits are the slot number 0 to 5. A value below
$10 would be a kind number given directly; no entry uses that.

X and Y become the object's own position values ($0480+slot, $0460+slot).
They are not the feet: the first sewer's crawling enemies sit at Y 180 on
a floor whose top edge is at 176.

## Where the tables are (bank 6)

| What | Address | Indexed by |
| --- | --- | --- |
| Room placement | $8681 | world, then area, then screen number |
| Overworld placement | $AC8F | world, then screen number |
| Line-up choices | $82EB | world, then area: 4 line-up numbers |
| Line-ups | $86E9 | line-up number (0-17): one kind per slot |
| Kind info, kinds $80 and up | $883D | kind minus $80: hit points, first animation number |
| Kind info, kinds below $80 | $8749 | kind: hit points, first animation number |
| Weapon damage | $9BCB | see below |
| Damage on touch | $8B05 | kind: energy the turtle loses (he has 128) |

There are 760 entries in rooms and 80 on the overworlds. Rooms with none:
the underwater level, world 4's rooms 8, 12 and 17, world 5's rooms 5 to 8,
and world 6's last room.

The second byte of the kind info is stored in $0570+slot. Earlier versions
of this page called it a behaviour number. It is the object's animation
number: the tables it indexes ($8E11 and $8DC5, and $8BC5 and $8CC5 for
kinds below $80) point at short lists of frames, not at code. Where each
kind's behaviour code lives has not been found.

## The line-up a room comes up with, and the line-up level (read from code, 13 November 2026)

This replaces the section "Line-ups" below where the two differ. Read
from 7:$D551, 6:$816A to $8222, 6:$9BDF, 7:$C881 and 7:$CC31; the level
rule was then tried in the emulator by setting the points and the clock.

- **Coming up.** A room's line-up is the second byte of its entry in the
  table at 7:$D5CE (beside its graphics page), whatever the level is.
  For world 1 these are the level-0 line-ups (0, 0, 0, 1, 1, 4). They
  are not everywhere: five rooms of world 4 come up with line-up 3
  (kinds 83, A3, A6, 30) though all four of their level line-ups are 4.
  Measured for six rooms. The remake used the level-0 line-up before.
- **Points.** Beating an enemy adds what bits 3 to 6 of its place's slot
  byte pick from the table at 6:$9C03 (two bytes of decimal digits, in
  tens): slot bytes 80, 89, 92, 9B, A4, AD are worth 100, 200, 300, 800,
  900 and 1000. Measured: 100 for kind 8D, 200 for kind 81 in the third
  room, 1000 for kind 92. The points go to the score ($C2 to $C4) and
  to a second count ($C5 to $C7) that starts again when a map is
  entered. Things thrown have no slot byte and are worth nothing.
- **The clock.** $9D/$9E goes up by one every 128th frame in a room and
  also starts again when a map is entered.
- **The level** ($0614, 0 at power-on, never cleared after). Each time a
  place is about to make its enemy (scrolling, or the room coming up),
  unless the line-up in use is 7:
  1. If a change is due ($0605) and no enemy, thrown thing or puff is on
     the screen, the room turns to the line-up its table at 6:$82EB has
     for the level, and the change is no longer due. The enemy being
     made is of the new line-up. If something is on the screen nothing
     happens this time.
  2. If no change is due: the room's points pick a row: 2000, 4000,
     7000, 10000, 14000, 20000, 28000, 35000 and up (table 6:$838B);
     under 2000 nothing happens. The row has four clock values (table
     6:$839B; the first row 32, 24, 16, 8; the second 96, 48, 40, 32).
     The level worked out is how many of them, from the first, the clock
     is still below: 0 to 4. If that differs from $0614 it is stored, a
     change becomes due, and then one is taken off if the hit points of
     object 0 are below 64 and another if below 32, not going below 0.
     Object 0 is the turtle, whose energy is kept elsewhere: measured,
     that byte is always 0, so 2 are always taken off. So the level is
     2 for 2000 points in under 8 clock steps (17 seconds) or 4000 in
     under 32 (68 seconds), 1 for 2000 in under 16 or 4000 in under 40,
     and so on.
- A held fight's extra enemy turns the room to the level's line-up at
  once (`encounters.md`).

In world 1 only the third and fourth rooms have more than one line-up
(0, 1, 2, 2 and 1, 1, 2, 2). Tried in the emulator in the fourth room
with 2000 points and the clock held at 0: the level became 2 on the next
enemy made, and once the screen was clear the room made kinds 4B and 85.

The remake's copy is `RoomScene._check_lineup`. Kinds of line-ups 2 and
3 that have no script yet stand still, as before.

## Line-ups

A room does not name its enemies directly. It names four line-ups, and a
level number at $0614 (0 to 3) picks which one is in use, so the same room
can hold different enemies on different visits. $0614 is 0 when a new game
starts. The code at $8174-$81EC moves it by comparing two counters
($C5/$C6 and $9D/$9E) with tables at $838B and $839B and by looking at
$0560; what those counters count was not traced. The remake always uses
the first line-up.

Every overworld uses line-up 16. Line-up 7 is special-cased in the code
and was not followed.

## Checked against the emulator (first sewer, new game)

- Line-up level 0, line-up 0 in use.
- The four entries of the first screen appear as kind 8D with 4 hit points,
  at the entries' Y values (180, 180, 100, 180). They had already moved
  sideways by the time they were read.
- The next screen's first two entries were caught as they appeared: kind 8D
  at (284, 180) and kind 81 at (285, 64), 4 pixels left of the entries'
  (288, 180) and (289, 64). The game creates an enemy when the camera's
  edge reaches it, so it may already have taken a step.

Only kinds 8D and 81 have been seen. The other kinds, their hit points and
their positions come from the tables alone. Kind 8D has since been measured
in full: see `enemy_8D.md`.

## Weapon damage

The code at $996D-$99A9 takes the damage from $9BCB and subtracts it from
the enemy's hit points ($0560+slot). The table is in pairs: the first value
is used normally, the second when the turtle's energy is below $40 (half).

| Index | Who | Normal | Below half energy |
| --- | --- | --- | --- |
| 0 | Leonardo | 7 | 10 |
| 1 | Raphael | 9 | 9 |
| 2 | Michelangelo | 7 | 12 |
| 3 | Donatello | 15 | 16 |
| 4-7 | The four special weapons ($0073+turtle, 1 to 4) | 18, 14, 16, 29 | 20, 17, 16, 32 |

Read from the code and the table; not measured in play.

## What the remake does with this

Every placement entry gets an enemy with its kind's hit points and damage
on touch. Which kinds have their own sprites and which move is in
`enemy_kinds.md`. Leonardo's swing takes 7 off, or 10 when he is below half
energy. F8 switches them all off.

## Not done yet

Most kinds' behaviour (see `enemy_kinds.md`), when the line-up level
changes, enemies appearing as the camera reaches them instead of all at
once, and items.
