"""The recording behind Research/world_end.md. Needs the player's own ROM
and the cynes emulator; nothing from the ROM is stored here.

usage: python3 world_end_checks.py path/to/rom.nes [folder for pictures]

Puts the game in world 1's last room, lets the last boss come in, beats
it with the turtle's own weapon (its hit points are held at 1), and then
prints every change of the game's own state until world 2's overworld is
on show. With a folder, every frame's picture is saved as
frame_<n>.png, n counted from the frame the boss is beaten.
"""
import sys, os
from cynes import NES, NES_INPUT_START, NES_INPUT_LEFT, NES_INPUT_RIGHT, NES_INPUT_B
from PIL import Image

rom = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else None
BOSS = 0x71

def run(nes, frames, buttons=0):
    picture = None
    for _ in range(frames):
        nes.controller = buttons
        picture = nes.step()
    return picture

nes = NES(rom)
run(nes, 200)
for _ in range(3):
    run(nes, 5, NES_INPUT_START)
    run(nes, 90)
run(nes, 120)
while nes[0x5C] == 0:                      # into the first manhole
    run(nes, 1, NES_INPUT_LEFT)
# The last room, with the screen at its left end: the boss comes in by itself.
nes[0x48] = 0; nes[0x5D] = 5; nes[0x5C] = 1
nes[0x480] = 128; nes[0x460] = 100
for at in (0x4F, 0x50, 0x51, 0x52):
    nes[at] = 0
for _ in range(400):
    nes[0x77] = 0x80
    run(nes, 1)

def boss_slot():
    return [slot for slot in range(2, 16) if nes[0x440 + slot] == BOSS]

beaten = None
last = None
for frame in range(4000):
    buttons = 0
    slots = boss_slot()
    if slots and beaten is None:
        slot = slots[0]
        nes[0x560 + slot] = 1               # one hit will do
        nes[0x77] = 0x80
        gap = nes[0x480 + slot] - nes[0x480]
        buttons = NES_INPUT_B if frame % 12 < 2 else 0
        if abs(gap) > 24:
            buttons |= NES_INPUT_RIGHT if gap > 0 else NES_INPUT_LEFT
        elif 6 <= frame % 12 < 8:
            buttons = NES_INPUT_RIGHT if gap > 0 else NES_INPUT_LEFT
    picture = run(nes, 1, buttons)
    if beaten is None and not boss_slot():
        beaten = frame
    if beaten is None:
        continue
    count = frame - beaten
    if out:
        Image.fromarray(picture).save(os.path.join(out, "frame_%d.png" % count))
    state = dict(scene="%02X" % nes[0xB5], step=nes[0x34], hold=nes[0x3D] > 0, fight=nes[0x5E], world=nes[0x48], inside=nes[0x5C],
                 score="%02X%02X%02X0" % (nes[0xC4], nes[0xC3], nes[0xC2]), turtle_x=nes[0x480] if nes[0xB5] else None,
                 april=(nes[0x40F], nes[0x48F], nes[0x46F]))
    if state != last:
        print("frame %4d  %s" % (count, state))
        last = state
    if nes[0x48] == 1 and nes[0x34] == 6 and nes[0x3D] == 0 and nes[0x400] != 0:
        print("frame %4d  the turtle is drawn on world 2's overworld at" % count, (nes[0x480], nes[0x460]),
              "screen corner", (nes[0x4F] | nes[0x50] << 8, nes[0x51] | nes[0x52] << 8))
        break
