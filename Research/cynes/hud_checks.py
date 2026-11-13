"""Measurements behind Research/hud.md. Needs the player's own ROM and the
cynes emulator; nothing from the ROM is stored here.

usage: python3 hud_checks.py path/to/rom.nes

Walks from the start of world 1 into the first manhole, then reads the
strip's tiles out of the picture's layout and the overworld's energy
sprites out of sprite memory, for every energy value.
"""
import sys
import numpy as np
from cynes import NES, NES_INPUT_START, NES_INPUT_LEFT

rom = sys.argv[1]

def run(nes, frames, buttons=0):
    picture = None
    for _ in range(frames):
        nes.controller = buttons
        picture = nes.step()
    return picture

def to_overworld():
    nes = NES(rom)
    run(nes, 200)
    for _ in range(3):
        run(nes, 5, NES_INPUT_START)
        run(nes, 90)
    run(nes, 120)
    return nes

def energy_sprites(nes):
    found = []
    for at in range(0x200, 0x300, 4):
        if nes[at] == 208:
            found.append((nes[at + 3], nes[at + 1]))
    return [tile for _, tile in sorted(found)]

# 1. The overworld: eight sprites on line 208, tiles AA / AC / AE.
seen = {}
nes = to_overworld()
start = nes.save()
for energy in range(0, 129):
    nes.load(start)
    for _ in range(6):
        nes[0x77] = energy
        run(nes, 1)
    seen.setdefault(tuple(energy_sprites(nes)), []).append(energy)
for tiles, energies in seen.items():
    print("overworld energy %3d to %3d:" % (energies[0], energies[-1]), " ".join("%02X" % t for t in tiles))

# 2. A room: where the strip starts, and that the edges are dark.
nes = to_overworld()
while nes[0x5C] == 0:
    run(nes, 1, NES_INPUT_LEFT)
picture = np.array(run(nes, 300)).astype(int)
lit = picture.sum(axis=2) > 0
print("lit pixels in the left 8 columns:", int(lit[:, :8].sum()), " right 8:", int(lit[:, 248:].sum()))
rows = [y for y in range(190, 240) if lit[y].any()]
print("lines with anything on them from 190 down:", rows[0], "to", rows[-1])
print("strip address kept in $29/$2A: %02X%02X" % (nes[0x29], nes[0x2A]))
