# The special weapons (USA ROM)

Worked out on 13 November 2026 by reading the ROM's code and measuring
in the emulator (cynes). Each fact is marked **(code)**, **(measured)**
or **(guess)**. Addresses are bank:address. Scripts:
`Research/cynes/special_weapon_checks.py` (recordings and measurements)
and `special_weapon_replay.gd.txt` (the remake's pictures of a throw).

## What the game keeps (code)

- $73 + turtle number: which special weapon he has. 0 none, 1 the star,
  2 the triple star, 3 the boomerang, 4 the scroll.
- $A8 + turtle number: how many (99 at most).
- $5B: 1 while the playing turtle's special weapon is the weapon in use,
  0 while his own weapon is.

A new game and CONTINUE clear all of them.

## Getting one (code 6:$96E3; measured for the displays)

Item kinds 05 to 08 give special weapons 1 to 4 (the item's kind less 4).
If it is not the one he has, it replaces it: the count becomes 20 and it
becomes the weapon in use. If it is the one he has, 20 are added, up to
99. The item is gone, with a sound. (The scroll, weapon 4, also marks
its item as taken for good.)

Where the items are, in the rooms' lists of fixed things: kind 08 in
world 3 (areas 2 and 4), world 4 (area 13), world 5 (area 1) and world 6
(area 1); kind 06 in world 4 (area 16); kind 07 in world 5 (area 1).
Kind 05 is in no list: it can only come from what beaten enemies leave
(not looked at). World 1 has none.

## Select (code 4:$982C)

In a room, a new press of Select flips $5B, and puts it back to 0 if the
turtle has none of his special weapon. A sound plays when it changes to
the special weapon. Nothing else reads Select in a room. (On the
overworld Select is the van's business, `start_screen.md`.)

$5B is also set to 0 when a swing begins and when the Start screen is
left, if the playing turtle has no special weapon (4:$9E97, 7:$CE0A): so
changing to a turtle without one goes back to the own weapon.

## What is shown

- The strip (code 0:$82E8, measured; `score.md`): the special weapon's
  box shows tiles $4C + 4n for weapon n and the count as two digits under
  it; while the special weapon is in use the box blinks, blank for 8
  frames in every 16.
- The Start screen (code 3:$AB75; `start_screen.md`): each turtle's box
  shows the four tiles for his weapon from the table at 3:$ADBD, with his
  count after his energy bar.

## Attack with a special weapon in use (code 4:$9E7E, 7:$E066; measured)

With $5B at 1 the attack button starts a throw instead of a swing:

- The turtle's animation is $82 standing, $84 with Down held (crouching)
  or $86 with the jump button held. Their pictures are 9, 11, 5, 9;
  13, 14, 98, 13; and 16, 21, 66, 16: the first for 5 frames, the next
  two 6 each, the last 7, so 24 frames (12 updates) in all. He goes on
  walking, jumping or falling meanwhile (measured: his place moved on at
  walking speed through the throw). A press during the 24 frames is
  thrown away; the next throw can begin on his next update after them.
- What is thrown goes into object slots 2 to 4, so three things at most
  are in the air. If no slot is free nothing is thrown and nothing is
  used up, though the animation plays.
- The thrown object starts at the turtle's place (his middle), 12 lower
  when the animation is the crouching one, facing as he faces, with a
  sideways speed of 5 pixels an update. Its kind and animation come from
  two small tables (7:$E0FF, 7:$E103): weapons 1 and 2 make kind 1A
  (animation $D7), weapon 3 kind 27 ($D6), weapon 4 kind 28 ($D5).
- Weapon 2 throws up to three of kind 1A at once: the first level, the
  second also rising 1 pixel an update, the third sinking 1.
- One is taken off the count for a throw (for a triple throw too). At 0
  the turtle has no special weapon any more and $5B goes back to 0.

## Kind 1A, the star (code 7:$FD5F; measured)

It is seen to with the enemies, on their frame, so it first moves the
frame after it is made. Each update, before it moves:

- the map cell 8 above its place is looked at: empty, a doorway (kind 2),
  a ladder (kinds 9 and 10) and kind 7 let it pass; anything else and it
  is gone;
- it is gone when its place across the screen is less than 7 or 246 and
  more, or (in a room) when its place down the screen is 192 or more or
  less than 4.

Then it moves 5 pixels. Its pictures are 73 to 76: one tile (a tall
sprite, tile 142 of the turtle's own sprite page, sprite colour group 1)
turned four ways, 2 updates each; when the list starts again the last
stays an update longer and the first is an update short.

Hitting (code 6:$996D, measured with a foot soldier held 60 pixels
away): what a hit takes off comes from the same table as the turtle's
own weapon (6:$9BCB, two numbers a row, the second when his energy is
under 64), but from row "special weapon number + 3" while $5B is 1:

| Weapon in use | Normal | Energy under 64 |
| --- | --- | --- |
| 1, the star | 18 | 20 |
| 2, the triple star | 14 | 17 |
| 3, the boomerang | 16 | 16 |
| 4, the scroll | 29 | 32 |

(Measured: 18 and 20 for the star, 14 for one star of the triple.) The
row goes by $5B at the moment of the hit, not by what did the hitting.
The enemy then blinks for 24 updates as after any hit. The star flies on
through an enemy it does not beat; it is gone only when its hit beats
the enemy (the list at 6:$9A89 names kinds 29 and 1A). Measured: the
soldier was hit with its place from 2 above the turtle's middle to at
least 42 below it.

## Kinds 27 and 28, the boomerang and the scroll (code only; not made)

- **Kind 28, the scroll** (7:$FD7B) only has the screen-edge test above:
  it does not look at the map, so walls do not stop it. One picture (72).
  It is not in the list of weapons that go when they beat an enemy.
- **Kind 27, the boomerang** (7:$FD9F): a sound, then every update its
  sideways speed is changed by 40/256 of a pixel against the way it
  faces (7:$F016, 7:$F026), so it slows, stops and comes back. For its
  first 10 updates (a count at $0630) nothing else happens. After that,
  when it is within 12 pixels across and 24 down of the turtle, it is
  caught and gone: if the turtle has no special weapon just then (he
  threw his last), he gets weapon 3 again and it becomes the weapon in
  use; and if the weapon he has is the boomerang, one is added to his
  count. When it is not near him only the screen-edge test applies; it
  does not look at the map. Pictures 60, 61, 63, 62, 2 updates each.

## In the remake

Done:

- `RoomScene.special_kind`, `special_count`, `special_in_use`;
  `give_special` (items 05 to 08 through `Item.taken`); `press_select`
  (the new `select` action: C or Backspace, Back on a controller);
  the strip's box, count and blink; the Start screen's boxes and counts;
  CONTINUE clears them.
- Throwing the star and the triple star: `Turtle._throw` (the three
  animations, by the buttons held), `Scripts/Player/ThrownWeapon.gd`
  (the star, by the rules above), `RoomScene._on_throw_started` (the
  three places, the count), `weapon_damage_now` (the row by the weapon
  in use). Sprite maps: `Kind1A.json`, and four more pictures in
  `TurtleSwings.json`.

Compared with the emulator, picture against picture, every frame from
the press to the star leaving the screen (60 frames each): a standing
throw and a crouching throw are the same in every pixel of the room but
for a small flash (5 by 5 pixels) the original shows at his hand on the
first two to four frames; a triple throw too, but for which of the three stars is drawn on
top while they still overlap (the first 12 frames).

Note only (not made): throwing the boomerang (kind 27) and the scroll
(kind 28). With one of those in use the remake's attack is still the
turtle's own swing, and none is used up.

Different, or not done:

- The star's box against an enemy is the star's own box from the ROM's
  table against the box the room scene gives the enemy; the original's
  own test (with its rule for edges that only touch) is not copied, and
  the heights at which it hits were not compared.
- Item kind 05 (and what beaten enemies leave) is not made.
- No sounds. The flash at his hand is not drawn.
