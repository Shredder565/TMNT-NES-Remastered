# Enemy kind 8D: the first sewer's crawler (USA ROM)

Measured on 10 November 2026 by reading the game's memory every frame in an
emulator while four of them walked the first screen of the first sewer, and
by letting them touch the turtle. The checks can be re-run with
`Research/cynes/crawler_checks.py`. The remake's version is
`Scripts/Enemies/Crawler.gd`; its sprite map is
`Resources/AssetRipper/Sprites/Kind8D.json`.

I do not know this enemy's official name, so the notes use its kind number.

## Movement

Like the turtle, it is updated on every second frame, and its speeds are in
1/256ths of a pixel per update.

| What | Value | In pixels |
| --- | --- | --- |
| Walking speed | 352 | 1.375 per update, 41.25 per second |
| First update of a fall | 512 downward | 2 |
| Gravity | +24 each update | |
| Hit points | 4 | |
| Damage on touch | 7 of the turtle's 128 energy | |

- It walks at a steady speed and never reacts to the turtle.
- Its position value is its middle across and its bottom edge. On a floor
  it rides 4 pixels below the floor's top edge (Y 180 on the floor at 176,
  Y 100 on the ledge at 96).
- It starts off towards the middle of the screen: right if it appears on
  the left half, left otherwise (read from the code at $8298).
- At the left wall (whose face is at X 16) it turned round at X 30 or 31,
  so it looks about 15 pixels ahead.
- It walks straight off a ledge. The fall began when its whole 24-pixel
  width had left the ledge (at X 131, with the ledge starting at 144).
  While falling it does not move sideways.
- It fell from Y 100 to the floor in 26 updates, passed its resting height
  by 2 pixels, was put back at Y 180 on the next update, and then carried on
  in the same direction.

## The screen edges

With the camera at the start of the room, the crawlers also turned round at
the right edge of the screen (X 242 to 244), where there is no wall. With
the camera 73 pixels along, they walked off both edges of the screen and
were removed. My reading is that the look-ahead position wraps round the
screen, so at the start of the room a crawler at the right edge "sees" the
left wall. That fits both observations but I did not confirm it in the
code. The remake does not copy either effect: its crawlers turn only at
real walls and at the ends of the room, and are never removed for leaving
the screen.

## Being hit and hitting

- One standing sword swing removed it (4 hit points against Leonardo's 7).
  Its slot then holds object kind 15 (hex), which I take to be the puff it leaves; the remake just removes it.
- Each touch took 7 energy. The damage table is at $8B05 in bank 6, one
  byte per kind (the code at $98BE adds 4 to the kind and reads from $8B01).
  In the van the damage is always 7.
- After a touch the turtle's safe-time counter ($0500) is set to 24 and
  counts down once per update, so he can be hurt again after 48 frames.
- Touches happened with the two middles 10 and 12 pixels apart. The
  remake's touch box (12 wide) and the box his weapon can reach are guesses.

## Sprites

Tall sprites (8 x 16) from graphics page 0, sprite palette 1 (NES colours
02, 16, 31 in the sewer). Two frames, three updates each:

| Frame | Tiles, left to right, facing right | Width |
| --- | --- | --- |
| 1 | 240, 242, 244 | 24 |
| 2 | 236, 238 | 16 |

Both frames are centred on the X value and stand on the Y value. Facing
left mirrors them. The sprite table at $0200 showed positions from one
frame earlier than the position values.

## Not done yet

The screen-edge turning described above, and the exact hit boxes. The puff
and being made and removed as the camera moves were added later
(`shots_spawning_tiles.md`).
