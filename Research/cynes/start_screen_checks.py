"""Emulator checks behind Research/start_screen.md.

Needs the `cynes` package and the helper scripts described in the agent
brief (emu.py, cap.py, lv.py). Run with: python3 -I start_screen_checks.py
What it prints is what the note quotes: the step counter while the screen
opens, what each button changes, how long leaving takes, and whether the
ROM's layout matches the screen.
"""
import sys, os, pickle
sys.path.insert(0, '/home/claude/work')
import numpy as np
from emu import *
from cynes import NES_INPUT_SELECT
from lv import b, w

NT_BASE = 9186          # where cynes 0.1.2 keeps the first name table in a saved state

def boot_overworld():
    e = E(); e.run(200)
    for k in range(3):
        e.run(5, NES_INPUT_START); e.run(90)
    e.run(120)
    return e

def name_table(n):
    raw = np.array(n.save()).tobytes()
    return raw[NT_BASE:NT_BASE + 0x400]

def colour_list(n):
    return bytes(n[0x59F + k] for k in range(32))

def sprites(n):
    return [(n[0x200 + i], n[0x201 + i], n[0x202 + i], n[0x203 + i]) for i in range(0, 256, 4) if n[0x200 + i] < 0xEF]

def layout_from_rom():
    """The Start screen's layout, decoded from the ROM (entry 4 of the table at 7:$E3CE, data in bank 3)."""
    a = w(7, 0xE3CE + 8); out = {}
    place = b(3, a) | b(3, a + 1) << 8; a += 2
    while True:
        c = b(3, a)
        if c == 0xFF: return out
        if c == 0x7F:
            place = b(3, a + 1) | b(3, a + 2) << 8; a += 3
        elif c & 0x80:
            for i in range(c & 0x7F): out[place] = b(3, a + 1 + i); place += 1
            a += 1 + (c & 0x7F)
        else:
            for i in range(c): out[place] = b(3, a + 1); place += 1
            a += 2

if __name__ == '__main__':
    e = boot_overworld(); n = e.nes
    e.run(60, NES_INPUT_RIGHT)
    e.run(1, NES_INPUT_START)
    last = None
    for f in range(260):
        e.run(1)
        s = (n[0x35], n[0xD0], n[0x8E] & 0x80, n[0x94])
        if s != last:
            print('frame', f + 1, 'open flag', s[0], 'step', s[1], 'typing', bool(s[2]), 'map strips', s[3]); last = s
    print('marker sprite (y, tile, colour group, x):', sprites(n))
    rom = layout_from_rom(); nt = name_table(n)
    same = sum(1 for i in range(0x400) if rom.get(0x2000 + i) == nt[i])
    print('layout bytes equal to the screen:', same, 'of 1024 (the rest are the parts filled in afterwards)')
    for name, button in (('A', NES_INPUT_A), ('B', NES_INPUT_B), ('Left', NES_INPUT_LEFT), ('Right', NES_INPUT_RIGHT),
                         ('Select', NES_INPUT_SELECT), ('Down', NES_INPUT_DOWN), ('Down', NES_INPUT_DOWN), ('Up', NES_INPUT_UP)):
        before = name_table(n); colours = colour_list(n)
        e.run(2, button); e.run(20)
        after = name_table(n); colours2 = colour_list(n)
        print(name, 'turtle', n[0x67],
              'screen changes', [(hex(0x2000 + i), '%02X>%02X' % (before[i], after[i])) for i in range(0x400) if before[i] != after[i]],
              'colour changes', [(i, '%02X>%02X' % (colours[i], colours2[i])) for i in range(32) if colours[i] != colours2[i]])
    e.run(1, NES_INPUT_START)
    for f in range(60):
        e.run(1)
        if n[0x34] == 6 and n[0x3D] == 0 and n[0x35] == 0:
            print('playing again', f + 1, 'frames after Start'); break
