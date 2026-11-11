# Enemy kind 98, the foot-soldier-looking one (USA ROM)

Recorded on 11 November 2026 in the third room of the first sewer (world 1,
area 2), which has six of them. The emulated game was dropped into the room
with the turtle standing still and safe from harm at three different
places, and the soldiers' memory was saved every frame from the moment the
room loaded. The remake's version is `Scripts/Enemies/Soldier.gd`.

I have not found this kind's behaviour code. The numbers below are
measured; the rules that connect them are only what three recordings with
a motionless turtle showed, and the remake's rules are a simple pattern
fitted to those.

## Measured

Updated every second frame; speeds in 1/256ths of a pixel per update.

| What | Value |
| --- | --- |
| Hit points | 12 (two of Leonardo's hits) |
| Damage on touch | 17 |
| Walking speed | 320 (1.25 pixels per update) |
| Fall | starts at 512, gains 36 each update |
| Hop | 320 sideways and 1536 upward, gaining 36 each update; after 6 updates the upward speed is set to 0 |
| Hop size | 34 pixels up, 35 pixels across, 29 updates |
| Resting height | 3 pixels below the floor's top edge |
| Standing between attacks | 13 updates |
| Kick | one frame held for 6 updates |
| Punch | two frames, 6 updates each |
| Walking animation | frames 128, 129, 130, 129, about 3 updates each |

## What the recordings showed

- Each soldier appears at its place and drops onto the floor.
- Those that landed 96 and 120 pixels from the turtle hopped towards him
  at once. One that landed 16 pixels away did not.
- After the hop, one stood for 129 updates, then walked towards him and
  stopped with the two middles 23 pixels apart. The one that had not hopped
  stood for 26 updates, walked 5, and also stopped at 23.
- In reach, they stand, then kick or punch, over and over. The order of
  kicks and punches was irregular.
- One on the floor below a ledge jumped up onto it with a spin (speed 320
  across, 1536 up, frames 142 to 144). What sets that off was not worked
  out.
- An object of kind 99 appeared while they attacked. I take it to be the
  part of the attack that hurts, but did not check.

## What the remake does

- Falls, hops (when it lands more than 90 pixels away), rests (26 updates,
  or 129 after a hop), walks to 23 pixels, then kicks and punches in pairs
  with 13 updates between.
- It always faces the turtle.
- Guesses: it only walks at a turtle within 40 pixels of its own floor
  height, and it stops at walls.
- Its kicks and punches do not hurt by themselves. Only touching it does.

Added later (`shots_spawning_tiles.md`): the 129-update stand after a hop
turned out to be a 25-update wait and then eight thrown stars (kind 99),
and the remake now throws them. It also makes the spinning jump, with the
recorded numbers and a rule of my own for when.

## Not done yet

The real rule for the jump onto ledges, whether its kicks and punches hurt
at a distance, what it does when hit, how it reacts to a moving turtle, and the real rules
behind all of it.
