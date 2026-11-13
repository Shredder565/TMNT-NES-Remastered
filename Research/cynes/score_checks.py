"""Measurements behind Research/score.md. Needs the player's own ROM and
the cynes emulator; nothing from the ROM is stored here.

usage: python3 score_checks.py path/to/rom.nes

1. Walks into the first sewer, makes the turtle untouchable (the power
   item's flag) and runs right; prints the score and what was beaten each
   time the score changes.
2. Reads the strip's box tiles out of the screen's memory for each turtle
   and special weapon number.
"""
import sys
import numpy as np
from cynes import NES, NES_INPUT_START, NES_INPUT_LEFT, NES_INPUT_RIGHT, NES_INPUT_A, NES_INPUT_DOWN

rom = sys.argv[1]
SCREEN_MEMORY_IN_SAVE = 9186   # where cynes keeps the four screens' tiles in a saved state

def run(nes, frames, buttons=0):
    for _ in range(frames):
        nes.controller = buttons
        nes.step()

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
    run(nes, 150, NES_INPUT_DOWN)   # down the ladder to the floor
    return nes

def score(nes, at=0xC2):
    return "%02X%02X%02X0" % (nes[at + 2], nes[at + 1], nes[at])

# 1. What gives points.
nes = in_first_sewer()
before = score(nes)
for frame in range(1500):
    nes[0x77] = 0x80           # full energy
    nes[0x540] |= 0x10         # the power item's flag: what touches him is beaten
    things = {slot: (nes[0x440 + slot], nes[0x540 + slot]) for slot in range(2, 16) if nes[0x440 + slot]}
    run(nes, 1, NES_INPUT_RIGHT | (NES_INPUT_A if (frame // 40) % 3 == 0 else 0))
    now = score(nes)
    if now != before:
        gone = ["kind %02X slot byte %02X" % thing for slot, thing in things.items() if nes[0x440 + slot] != thing[0]]
        print("frame %4d  %s -> %s  best %s  beaten: %s" % (frame, before, now, score(nes, 0xC8), ", ".join(gone)))
        before = now

# 2. The boxes.
def box_rows(nes):
    raw = np.array(nes.save()).tobytes()
    for screen in range(4):
        tiles = raw[SCREEN_MEMORY_IN_SAVE + screen * 0x400:SCREEN_MEMORY_IN_SAVE + (screen + 1) * 0x400]
        if tiles[9 * 32 + 1] == 0x1F:   # "Pts."
            return [" ".join("%02X" % tiles[row * 32 + col] for col in range(20, 30)) for row in range(9, 12)]
    return []

start = nes.save()
for turtle in range(4):
    for number, count, in_use in [(0, 0, 0), (1, 5, 0), (2, 23, 0), (3, 99, 0), (4, 1, 0), (1, 5, 1)]:
        nes.load(start)
        seen = set()
        for frame in range(64):
            nes[0x67] = turtle
            nes[0x73 + turtle] = number
            nes[0xA8 + turtle] = count
            nes[0x5B] = in_use
            nes[0x77 + turtle] = 0x80
            run(nes, 1)
            if frame >= 32:
                seen.add(tuple(box_rows(nes)))
        print("turtle %d, special weapon %d, count %d, in use %d:" % (turtle, number, count, in_use))
        for rows in seen:
            print("    " + " | ".join(rows))
