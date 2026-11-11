"""Checks the notes on enemy kind 8D (Research/enemy_8D.md) against the
original game: walking speed, turning, falling and the damage on touch.

    python crawler_checks.py "path/to/Teenage Mutant Ninja Turtles (USA).nes"

Object slot X: kind $0440+X, X $0480+X (fraction $0490+X), Y $0460+X,
X speed $04E0+X / $04F0+X, Y speed $04B0+X / $04C0+X.
"""
import sys
from cynes import NES, NES_INPUT_START, NES_INPUT_LEFT, NES_INPUT_RIGHT, NES_INPUT_DOWN

nes = NES(sys.argv[1])


def run(frames, buttons=0, invincible=False):
    nes.controller = buttons
    for _ in range(frames):
        if invincible:
            nes[0x0500] = 60
            nes[0x0630] = 60
        nes.step()


def signed16(high, low):
    value = high << 8 | low
    return value - 65536 if value > 32767 else value


run(200)
for _ in range(3):
    run(5, NES_INPUT_START)
    run(90)
run(120)
while nes[0x5C] == 0:
    run(1, NES_INPUT_LEFT)
run(150)
in_sewer = nes.save()

# 1. Watch the four crawlers of the first screen for 15 seconds.
last = {}
for frame in range(900):
    run(1, invincible=True)
    for slot in (5, 6, 7, 8):
        speed = (signed16(nes[0x04E0 + slot], nes[0x04F0 + slot]), signed16(nes[0x04B0 + slot], nes[0x04C0 + slot]))
        if last.get(slot) != speed and (speed[1] == 0 or last.get(slot, (0, 0))[1] == 0):
            print("frame %3d slot %d at (%3d, %3d): speed across %5d, down %4d" % (
                frame, slot, nes[0x0480 + slot], nes[0x0460 + slot], speed[0], speed[1]))
        last[slot] = speed

# 2. Stand on the floor and let them touch the turtle.
nes.load(in_sewer)
run(260, NES_INPUT_DOWN)
while nes[0x0460] < 150:
    run(1, NES_INPUT_RIGHT)
energy = nes[0x77]
for frame in range(600):
    run(1)
    if nes[0x77] != energy:
        print("frame %3d: energy %d -> %d, safe-time counter %d" % (frame, energy, nes[0x77], nes[0x0500]))
        energy = nes[0x77]
