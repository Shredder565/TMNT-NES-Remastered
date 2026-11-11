# Leonardo's movement in the original (USA ROM)

Measured on 10 November 2026 by running the ROM in MesenCE 2.2.1 (Linux,
scripted test mode) and reading RAM every frame in the first sewer of Area 1.
An invincibility poke ($0500 and $0630 held at 60) kept enemies from
interrupting; it did not change the movement values.

## How the game stores movement

- The turtle is updated on every second frame: 30 updates a second.
- Position and speed are 16-bit: a whole-pixel byte and a 1/256-pixel byte.

| What | Whole byte | Fraction byte |
| --- | --- | --- |
| X position | $0480 | $0490 |
| Y position | $0460 | (not found yet) |
| X speed | $04E0 | $04F0 |
| Y speed | $04B0 | $04C0 |

The fraction addresses are my finding; Data Crystal lists only the whole bytes.
Buttons held ($0032): A $80, B $40, Select $20, Start $10, Up 8, Down 4, Left 2, Right 1.

## Values (1/256 pixel per update)

| What | Value | In pixels |
| --- | --- | --- |
| Walk speed | 576 | 2.25 per update, 67.5 per second |
| Ladder climb speed | 576 | 2.25 per update |
| Jump take-off speed | -1536 | -6 per update |
| Gravity | +84 each update | 0.328 per update, per update |
| Low-jump cut | speed set to -624 | applied 4 updates after take-off if A is not held |
| High-jump boost | speed set to -1536 again | applied 8 updates after take-off if A is still held |
| Fastest fall seen | 2076 | 8.1 per update, still increasing when he landed |

## Behaviour

- Three jump heights: 33 px (A released within 4 updates), 57-58 px
  (released between 4 and 8), 97 px (held for 8 or more).
- On the ground he starts and stops instantly, with no acceleration.
- In the air, pressing a direction sets full walk speed at once. Letting go
  of the direction keeps the sideways drift until landing.
- A step is: move by the current speed, then add gravity, then apply the
  jump rules and read the buttons.
- Walking off a ledge starts the fall at speed 0.
- On landing the Y position overshoots by up to 2 px for one update and is
  then snapped to the floor.
- Hit by an enemy (one sample only): thrown back at about 384 sideways and
  about -258 upward. Treat as approximate.

## Checked against the ROM

- 0x1C68F: the byte $80 loaded into $77-$7A, so each turtle starts with 128 energy.
- 0x1F7A6: 26 two-byte pointers. The first points at file offset 0x1F7DA, which
  matches Data Crystal's "Palette Data" start. The data are NES colour numbers.

## Not measured yet

Fall speed limit, crouch and attack timings, the other three turtles, and
swimming. Overworld walking is in `doors.md`.

## Added 10 November 2026 (from the crawler checks, `enemy_8D.md`)

- Energy is 128 when full. A crawler's touch takes 7.
- After a hit the safe-time counter at $0500 is set to 24 and counts down
  once per update: 48 frames, 0.8 seconds.
- Two more knock-back samples gave -258 upward both times, and 336 and 384
  sideways one update after the hit.
