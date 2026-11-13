"""Measurements behind "Rescuing a captured turtle" in
Research/losing_a_turtle.md. Needs the player's own ROM and the cynes
emulator; nothing from the ROM is stored here.

usage: python3 rescue_checks.py path/to/rom.nes [picture.png]

Puts the game in world 3's area 3 on the screen with the rescue place,
with different turtles captured, and prints what is there; then walks the
turtle into the captive and prints what changes.
"""
import sys
from cynes import NES, NES_INPUT_START, NES_INPUT_LEFT, NES_INPUT_RIGHT
from PIL import Image

rom = sys.argv[1]

def run(nes, frames, buttons=0):
    picture = None
    for _ in range(frames):
        nes.controller = buttons
        picture = nes.step()
    return picture

def in_a_room():
    nes = NES(rom)
    run(nes, 200)
    for _ in range(3):
        run(nes, 5, NES_INPUT_START)
        run(nes, 90)
    run(nes, 120)
    while nes[0x5C] == 0:
        run(nes, 1, NES_INPUT_LEFT)
    return nes

def at_rescue_place(captured):
    nes = in_a_room()
    nes[0x48] = 2; nes[0x5D] = 3; nes[0x5C] = 1          # world 3, area 3
    nes[0x480] = 60; nes[0x460] = 92
    nes[0x4F] = 0; nes[0x50] = 3; nes[0x51] = 0x80; nes[0x52] = 1   # the screen at (768, 384)
    for turtle in captured:
        nes[0x77 + turtle] = 0
    picture = None
    for _ in range(200):
        nes[0x500] = 60; nes[0x77] = 0x80
        picture = run(nes, 1)
    return nes, picture

def things(nes):
    return ["kind %02X picture %d at (%d, %d)" % (nes[0x440 + s], nes[0x400 + s], nes[0x480 + s], nes[0x460 + s]) for s in range(1, 16) if nes[0x440 + s]]

for captured in ([], [1], [2, 3]):
    nes, picture = at_rescue_place(captured)
    print("captured %s: %s; flag $56 = %d, turtle in $57 = %d, energies %s, sprite colours %s" % (
        captured, things(nes) or "nothing there", nes[0x56], nes[0x57], [nes[0x77 + i] for i in range(4)],
        " ".join("%02X" % nes[0x59F + k] for k in range(24, 28))))
    if captured == [1] and len(sys.argv) > 2:
        Image.fromarray(picture).save(sys.argv[2])

nes, _ = at_rescue_place([1])
nes[0x480] = 100; nes[0x460] = 70      # onto the captive's platform
before = None
for frame in range(120):
    nes[0x500] = 0
    run(nes, 1, NES_INPUT_RIGHT if frame > 30 else 0)
    now = (tuple(things(nes)), tuple(nes[0x77 + i] for i in range(4)), nes[0x56], nes[0x27])
    if now != before:
        print("frame %3d turtle at %d: things %s energies %s flag %d sprite page %d" % (frame, nes[0x480], list(now[0]), now[1], now[2], now[3]))
        before = now
