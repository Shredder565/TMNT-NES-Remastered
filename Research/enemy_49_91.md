# Enemy kinds 49 (with 4A) and 91, from the original's code (USA ROM)

Written on 12 November 2026. `enemy_routines.md` says how the routines
were found and what the shared helpers do. Everything here is **read from
code** unless marked otherwise. These replace the fitted rules for 49 in
`enemy_49_88_A0.md` (`LegacyWalker.gd`) and for 91 in `world1.md`
(`Crawler.gd`).

## Kind 49 - `Lurker.gd`

Routine 5:$9249; what it is busy with at 5:$934C, $9359, $93BD, $93C6
and $93D3. Hit points 28, damage on touch 17. It does not react to a hit.

- **Waiting** (animation 50, how it starts): it turns to the turtle and,
  when he is 32 to 79 pixels away across, comes out (animation 51, 24
  updates). While it shows animation 50 it can neither touch nor be hit:
  the touch code skips it (the list at 6:$963F).
- **Out**, each update, the first that applies:
  1. nothing 10 pixels behind it, 1 above its position: it drops, 3
     pixels an update and 36 more each update, no sideways speed, until
     there is something 12 behind and 4 below it and it can land;
  2. it turns to the turtle; if he is less than 16 pixels away across it
     stops and goes back in (animation 52, 24 updates, then waiting);
  3. a counter goes up by one; every 32nd time it stops, throws kind 4A
     and shows animation 54 for 8 updates;
  4. otherwise it walks at him: 256 (1 pixel an update), set afresh
     every update, 0 if a wall is 10 ahead; a wall 22 ahead at 36 up also
     stops it (it does not turn round).
- A landing ends "busy" as well, so after a drop it is back to the
  waiting rule (though not hidden: it keeps the walking animation until
  the turtle is again 32 to 79 away).

The earlier page's "stops 16 pixels from him and stands" was it going
back in; "throws every 40 updates" was 32 plus the 8 of the throw.

Animations: 50 (picture 90), 51 (90 91 92, 8 updates each), 52 (92 91
90), 53 (93 94, walking), 54 (95, the throw).

Not followed: a byte the routine sets at $0430 (1 coming out, 2 once
back in). It is also what the blink uses, so it has to do with how the
sprite is drawn, probably behind the background while it lurks.

## Kind 4A, what 49 throws - `Missile.gd`

Routine 5:$927C. Made at the thrower's place, 16 above it, facing the
way the thrower faces. It flies level at 832 (3.25 pixels an update)
until it leaves the screen. Walls do not stop it. Hit points 9, damage
14. It is not used up by hitting the turtle (`items_and_hits.md`).

## Kind 91, with the chainsaw - `Chainsaw.gd`

Routine 5:$91C6. Hit points 32, damage on touch 18. It never looks at
where the turtle is.

Each update, the first that applies:

1. **blinking after a hit:** animation 84 (set afresh each update) and
   no speed. So a hit holds it still for the 24 updates of the blink.
2. **nothing 12 behind it, 1 above:** it drops at 3 pixels an update and
   36 more each update, unless a wall is 14 ahead (then it just stands).
3. a counter goes up by one; **every 32nd time** it stops and swings:
   animation 82 if bit 1 of the frame counter is clear, else 83. Nothing
   more until that animation ends (33 and 29 updates).
4. **walking:** when the walking animation (80) is not already on, it is
   started and the speed set: 448 forward (1.75 pixels an update), 0 if a
   wall is 10 ahead. Just before that, if it is within 24 pixels of the
   side of the screen it is facing, it turns to face inward. Then, every
   update, a wall 20 ahead at 36 up turns it round.

The counter only goes up on updates that get as far as step 3, so it
walks 31 updates between swings. The earlier
measurement, "walks for 31 updates, stands for 33", was this.

Animations: 80 (80 88 81 89, 4 updates each), 81 (81 89, falling; also
what a new one shows), 82 and 83 (the swings, 8 and 7 pictures), 84 (87
8A, hurt).

## Checked against the emulator

Method in `enemy_routines.md`. Twelve recordings in areas 3 and 4,
including two with hits forced on the enemies.

| Kind | Objects | Frames compared | Agree exactly |
| --- | --- | --- | --- |
| 49 | 15 | 11024 | 11024 |
| 4A | 21 | 2090 | 2090 |
| 91 | 13 | 11264 | 11264 |

The recordings include 49 waiting, coming out, walking, throwing,
dropping (230 frames) and going back in; and 91 walking, swinging,
blinking after a hit (564 frames) and dropping (40 frames).

## What is not matched

- Which of 91's two swings: the frame counter (see "Chance" in
  `enemy_routines.md`).
- Pictures the sprite maps lack keep the last picture up. The picture
  numbers themselves agree on every frame.
- Kind 49 is not drawn any differently while it waits.
