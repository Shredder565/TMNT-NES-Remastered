"""Measurements behind "Doorways that are not ladders, and doors between
rooms" in Research/overworld.md. Needs the player's own ROM and the cynes
emulator; nothing from the ROM is stored here.

usage: python3 door_looks_checks.py path/to/rom.nes

Puts the turtle in front of a door by writing his place into the game's
memory at the moment the game is about to draw a map (so that it draws
the one asked for), holds Up, and prints for each frame after the door is used: how
far down the picture is drawn, the hold counter and whether he is drawn.
"""
import sys
import numpy as np
from cynes import NES, NES_INPUT_START, NES_INPUT_UP, NES_INPUT_LEFT

rom = sys.argv[1]

def run(nes, frames, buttons=0):
    picture = None
    for _ in range(frames):
        nes.controller = buttons
        picture = nes.step()
    return picture

def in_play():
    nes = NES(rom)
    run(nes, 200)
    for _ in range(3):
        run(nes, 5, NES_INPUT_START)
        run(nes, 90)
    run(nes, 120)
    return nes

def entering_a_room():
    """Stopped on the frame the first manhole is used: the game is about to draw a room."""
    nes = in_play()
    while nes[0x5C] == 0:
        run(nes, 1, NES_INPUT_LEFT)
    return nes

def leaving_a_room():
    """Stopped on the frame the ladder out is used: the game is about to draw the overworld."""
    nes = entering_a_room()
    run(nes, 150)
    while nes[0x5C] == 1:
        run(nes, 1, NES_INPUT_UP)
    return nes

def put(nes, world, area, inside, x, y, screen_x, screen_y):
    """His middle at (x, y) on the map, the screen's corner at (screen_x, screen_y)."""
    nes[0x48] = world
    nes[0x5D] = area
    nes[0x5C] = 1 if inside else 0
    nes[0x480] = x - screen_x
    nes[0x460] = y - screen_y
    nes[0x4F] = screen_x & 255
    nes[0x50] = screen_x >> 8
    nes[0x51] = screen_y & 255
    nes[0x52] = screen_y >> 8
    for _ in range(150):
        nes[0x77] = 0x80
        run(nes, 1)

def watch(nes, label, frames=140):
    used = None
    print("==", label)
    for frame in range(frames):
        nes[0x77] = 0x80
        picture = np.array(run(nes, 1, NES_INPUT_UP if used is None else 0)).astype(int)
        lit = picture.sum(axis=2) > 0
        rows = [y for y in range(240) if lit[y, 8:248].any()]
        sprites = sum(1 for at in range(0x200, 0x300, 4) if nes[at] < 0xEF and nes[at + 3] != 248 and nes[at] != 208)
        if used is None and nes[0x34] != 6:
            used = frame
        if used is not None:
            print(frame - used, "inside" if nes[0x5C] else "outside", "step", nes[0x34], "hold", nes[0x3D],
                  "drawn down to line", rows[-1] + 1 if rows else 0, "picture", nes[0x400], "sprites", sprites)
            if frame - used > 60:
                break

nes = leaving_a_room()
put(nes, 0, 0, False, 424, 304, 256, 184)
watch(nes, "overworld building door into room 4 (world 1)")
run(nes, 60)
watch(nes, "room 4's doorway out to the overworld")
nes = entering_a_room()
put(nes, 4, 5, True, 144, 160, 0, 0)
watch(nes, "world 5, room 5's doorway into room 2")
