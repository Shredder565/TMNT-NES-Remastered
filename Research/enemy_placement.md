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
