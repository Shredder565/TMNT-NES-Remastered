"""Checks the door notes (Research/doors.md) against the original game.

Runs the player's own ROM in cynes, a small NES emulator for Python
(pip install cynes), with no window, and reads the game's memory.

    python door_checks.py "path/to/Teenage Mutant Ninja Turtles (USA).nes"

RAM addresses are the ones in Research/ram_map_notes.md.
"""
import sys
from cynes import NES, NES_INPUT_START, NES_INPUT_LEFT, NES_INPUT_UP, NES_INPUT_DOWN

nes = NES(sys.argv[1])


def run(frames, buttons=0, invincible=False):
    nes.controller = buttons
    for _ in range(frames):
        if invincible:              # keeps enemies from interrupting
            nes[0x0500] = 60
            nes[0x0630] = 60
        nes.step()


def state():
    return {
        "inside": nes[0x5C], "area": nes[0x5D], "x": nes[0x0480], "y": nes[0x0460],
        "scroll_x": nes[0x4F] | nes[0x50] << 8, "scroll_y": nes[0x51] | nes[0x52] << 8,
    }


# Title screen -> turtle select -> the first overworld.
run(200)
for _ in range(3):
    run(5, NES_INPUT_START)
    run(90)
run(120)
print("start of the game:", state())

# 1. Walk left onto the first manhole.
frames = 0
while nes[0x5C] == 0 and frames < 120:
    run(1, NES_INPUT_LEFT)
    frames += 1
print("entered the manhole after", frames, "frames:", state())
at_manhole = nes.save()

# 2. Climb down a little, then back up and out of the top.
run(150)
run(60, NES_INPUT_DOWN, invincible=True)
lowest_y_inside = None
for _ in range(400):
    run(1, NES_INPUT_UP, invincible=True)
    if nes[0x5C] == 0:
        break
    lowest_y_inside = nes[0x0460]
print("last Y on the ladder before leaving:", lowest_y_inside, "->", state())

# 3. A building door. Re-use the manhole but send it to area 4 instead
#    (the door record's own arrival values), then try Up at each X.
nes.load(at_manhole)
nes[0x5D], nes[0x0480], nes[0x0460] = 4, 0x2C, 0x8C
run(200, invincible=True)
in_building = nes.save()
standing_y = nes[0x0460]
works = []
for x in range(16, 72, 2):
    nes.load(in_building)
    nes[0x0480] = x
    run(6, invincible=True)
    run(12, NES_INPUT_UP, invincible=True)
    if nes[0x5C] == 0:
        works.append(x)
print("standing Y in the building:", standing_y, "(the floor's top edge is at 160)")
print("Up leaves the building from X =", works[0], "to", works[-1])
