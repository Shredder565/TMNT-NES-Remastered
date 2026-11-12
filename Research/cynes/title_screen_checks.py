"""Measurements behind Research/title_screen.md. Needs the player's own ROM
and the cynes emulator; nothing from the ROM is stored here.

usage: python3 title_screen_checks.py path/to/rom.nes
"""
import sys
import numpy as np
from cynes import NES, NES_INPUT_START

rom = sys.argv[1]
nes = NES(rom)

def run(frames, buttons=0):
    for _ in range(frames):
        nes.controller = buttons
        nes.step()

# 1. When each screen is up: game state ($1B) and step ($1C) by frame.
seen = []
for frame in range(600):
    run(1)
    now = (nes[0x1B], nes[0x1C])
    if not seen or seen[-1][1] != now:
        seen.append((frame, now))
print("state changes with nothing pressed:", seen)

# 2. Start on the title: how long until the state moves on.
nes = NES(rom)
run(300)
run(2, NES_INPUT_START)
for frame in range(200):
    run(1)
    if nes[0x1B] != 0:
        print("state leaves 0 this many frames after Start:", frame)
        break

# 3. The top four lines of the title are not blank.
nes = NES(rom)
run(400)
picture = np.array(nes.step())
print("lit pixels in the top four lines of the title:", int((picture[:4].sum(axis=2) > 0).sum()))
