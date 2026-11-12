# Items, hits and hurting tiles

Read from the original's code. Addresses are bank:address. The remake's
copies are in `Scripts/Levels/Item.gd`, `Scripts/Player/Turtle.gd` and
`Scripts/Enemies/Shot.gd`.

## Items (6:$965C, one routine per kind)

Energy is 128 when full.

| Kind | What it gives | In the remake |
| --- | --- | --- |
| 01 | Whole pizza: energy to full | yes |
| 02 | Half a pizza: +64 | yes |
| 03 | A slice: +32 | yes |
| 05 to 08 | The special weapons | no |
| 0B | The power item, below | yes |
| 0C | Adds 10 to the count at RAM $BF | no |
| 0D | Adds 3 to the count at RAM $A7 | no |
| 0E | Brings a lost turtle back | no |

What $BF and $A7 count has not been worked out.

### Kind 0B

Update 21 recorded this as "nothing changed", because only energy and the
weapon counts were watched. It sets a bit in the turtle's flags ($0540,
bit $10) and a timer of 256 updates. While it runs:

- nothing that touches him hurts him;
- an enemy that touches him is hit instead, with the last line of the
  damage table: 240;
- he walks (and steers in the air) at 3 pixels an update, not 2.25;
- he cannot swing his weapon;
- he blinks for the last 48 updates.

The remake does all five. What he looks like meanwhile in the original
has not been checked: the remake only blinks him at the end.

## A weapon hitting an enemy (6:$9913)

The enemy's blink flag is set and its safe time ($0500) is set to 24
updates. Until that has run out nothing can hit it again. The remake now
has this for every enemy and both bosses; before, every swing that
touched landed.

Damage is as before (the table at 6:$9BCB, two numbers per turtle, the
second when his energy is under half).

## A shot hitting the turtle (6:$9910)

Only shots of kinds 99 and 93 are removed when they hit him. Every other
shot stays and flies on. Update 26 removed any flying shot, as a guess.

## Hurting tiles (kind 1; 4:$A5BB)

A hurting tile does something only when one of the turtle's map tests
looks at it (`Research/turtle_collision.md` lists the points): 3 above
his feet while he stands; ahead of him at two heights and under his right
foot while he walks; his head, sides and landing point in the air. His
chest passing through one while he stands does nothing.

When it does: 16 energy off and the blinking safe time, unless he is
blinking already. He is not thrown and his state does not change: he
goes on walking, jumping or swinging. Update 26 threw him back as if an
enemy had touched him, and tested every cell his body was in.
