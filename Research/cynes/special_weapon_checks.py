"""Measurements behind Research/special_weapons.md. Needs the player's own
ROM and the cynes emulator; nothing from the ROM is stored here.

usage: python3 special_weapon_checks.py path/to/rom.nes [folder for pictures]

1. Gives Leonardo a special weapon in the first sewer, presses B, and
   prints the turtle's picture and every thrown object frame by frame
   (standing, crouching, with A held, and the triple star). With a folder
   it saves each frame's picture as <run>_<frame>.png.
2. Throws the star at whatever enemy comes and prints what a hit takes off.
"""
import sys, os
from cynes import NES, NES_INPUT_START, NES_INPUT_LEFT, NES_INPUT_RIGHT, NES_INPUT_DOWN, NES_INPUT_A, NES_INPUT_B
from PIL import Image

rom = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else None

def run(nes, frames, buttons=0):
    picture = None
    for _ in range(frames):
        nes.controller = buttons
        picture = nes.step()
    return picture

def in_first_sewer():
    nes = NES(rom)
    run(nes, 200)
    for _ in range(3):
        run(nes, 5, NES_INPUT_START)
        run(nes, 90)
    run(nes, 120)
    while nes[0x5C] == 0:
        run(nes, 1, NES_INPUT_LEFT)
    run(nes, 120)
    run(nes, 150, NES_INPUT_DOWN)   # down the ladder
    run(nes, 170, NES_INPUT_RIGHT)  # off the ledge to the floor, facing right
    return nes

def no_enemies(nes):
    for slot in range(5, 16):
        nes[0x440 + slot] = 0
        nes[0x400 + slot] = 0

start = in_first_sewer().save()

def record(name, weapon, plan, enemies=False):
    nes = NES(rom)
    nes.load(start)
    nes[0x73] = weapon; nes[0xA8] = 5; nes[0x5B] = 1
    last = None
    for frame, buttons in enumerate(plan):
        nes[0x500] = 60; nes[0x77] = 0x80
        if not enemies:
            no_enemies(nes)
        picture = run(nes, 1, buttons)
        if out:
            Image.fromarray(picture).save(os.path.join(out, "%s_%d.png" % (name, frame)))
        thrown = [(slot, "%02X" % nes[0x440 + slot], nes[0x400 + slot], nes[0x480 + slot], nes[0x460 + slot]) for slot in range(2, 5) if nes[0x440 + slot]]
        now = (nes[0x400], nes[0x570], tuple(thrown), nes[0xA8])
        if now != last:
            print("%s frame %2d: turtle picture %d animation %02X at (%d, %d); thrown (slot, kind, picture, x, y) %s; count %d" % (
                name, frame, nes[0x400], nes[0x570], nes[0x480], nes[0x460], thrown, nes[0xA8]))
            last = now

B, D, A = NES_INPUT_B, NES_INPUT_DOWN, NES_INPUT_A
record("stand", 1, [0] * 10 + [B] * 2 + [0] * 60)
record("crouch", 1, [D] * 10 + [D | B] * 2 + [D] * 60)
record("air", 1, [0] * 10 + [A] * 20 + [A | B] * 2 + [A] * 10 + [0] * 30)
record("triple", 2, [0] * 10 + [B] * 2 + [0] * 60)

# 2. What a hit takes off: a foot soldier (kind 98) is found, held 60 pixels
# in front of the turtle and given hit points to spare.
SOLDIER = 0x98
nes = NES(rom)
slot = None
for area in range(6):
    for corner in range(8, 800, 64):         # put the screen at several places in each of world 1's rooms
        nes.load(start)
        nes[0x48] = 0; nes[0x5D] = area; nes[0x5C] = 1
        nes[0x480] = 128; nes[0x460] = 156
        nes[0x4F] = corner & 255; nes[0x50] = corner >> 8; nes[0x51] = 0; nes[0x52] = 0
        for frame in range(60):
            nes[0x500] = 60; nes[0x77] = 0x80
            run(nes, 1)
        found = [s for s in range(5, 11) if nes[0x440 + s] == SOLDIER and nes[0x560 + s] > 0]
        if found:
            slot = found[0]
            break
    if slot is not None:
        break
if slot is None:
    print("no foot soldier met")
    sys.exit()
held = nes.save()

def trial(weapon, energy, hit_points):
    nes.load(held)
    for other in range(5, 16):
        if other != slot:
            nes[0x440 + other] = 0
    across, down = 120, nes[0x460]
    nes[0x73] = weapon; nes[0xA8] = 9; nes[0x5B] = 1
    nes[0x560 + slot] = hit_points
    for frame in range(60):
        nes[0x480] = across; nes[0x450] = nes[0x450] & 0xFE; nes[0x500] = 60; nes[0x77] = energy
        nes[0x480 + slot] = across + 60; nes[0x460 + slot] = down
        for speed in (0x4E0, 0x4F0, 0x4B0, 0x4C0):
            nes[speed + slot] = 0
        stars = [s for s in range(2, 5) if nes[0x440 + s] == 0x1A]
        run(nes, 1, B if 10 <= frame < 12 else 0)
        if nes[0x560 + slot] != hit_points:
            return "lost %d, enemy is now kind %02X; stars before %s, after %s" % (
                hit_points - nes[0x560 + slot], nes[0x440 + slot], stars, [s for s in range(2, 5) if nes[0x440 + s] == 0x1A])
    return "no hit"

print("the star, full energy:", trial(1, 0x80, 100))
print("the star, energy 63:", trial(1, 0x3F, 100))
print("the triple star, full energy:", trial(2, 0x80, 100))
print("the star against an enemy with 5 hit points:", trial(1, 0x80, 5))
