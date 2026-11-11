"""Checks the enemy placement notes (Research/enemy_placement.md) against
the original game: enters the first sewer and prints each enemy the game
creates while the turtle walks right.

    python enemy_checks.py "path/to/Teenage Mutant Ninja Turtles (USA).nes"

Object slot X keeps its kind in $0440+X, position in $0480+X / $0460+X
(on-screen), hit points in $0560+X and its placement byte in $0540+X.
"""
import sys
from cynes import NES, NES_INPUT_START, NES_INPUT_LEFT, NES_INPUT_RIGHT, NES_INPUT_DOWN, NES_INPUT_A

nes = NES(sys.argv[1])


def run(frames, buttons=0):
    nes.controller = buttons
    for _ in range(frames):
        nes.step()


run(200)
for _ in range(3):
    run(5, NES_INPUT_START)
    run(90)
run(120)
while nes[0x5C] == 0:
    run(1, NES_INPUT_LEFT)
run(150)
print("enemy line-up level ($0614):", nes[0x0614], " line-up in use ($0604):", nes[0x0604])

seen = {}
for frame in range(1000):
    nes[0x0500] = 60                # keeps enemies from interrupting
    nes[0x0630] = 60
    if frame < 400:
        buttons = NES_INPUT_DOWN    # down the entrance ladder
    else:
        buttons = NES_INPUT_RIGHT | (NES_INPUT_A if (frame // 20) % 3 == 0 else 0)
    run(1, buttons)
    camera_x = nes[0x4F] | nes[0x50] << 8
    for slot in range(1, 16):
        kind = nes[0x0440 + slot]
        if kind == 0:
            seen.pop(slot, None)
        elif seen.get(slot) != kind:
            seen[slot] = kind
            print("frame %4d slot %2d kind %02X at (%d, %d) hit points %d placement byte %02X" % (
                frame, slot, kind, camera_x + nes[0x0480 + slot], nes[0x0460 + slot],
                nes[0x0560 + slot], nes[0x0540 + slot]))
