"""Emulator recordings behind Research/losing_a_turtle.md.
Needs `cynes` and the helper scripts of the agent brief (emu.py, cap.py).
Run with: python3 -I losing_a_turtle_checks.py
It prints, whenever something changes: the playing turtle, the four
energies, his state, animation and picture, the play step ($34), the
Start screen's flag and step ($35, $D0), the captured flag ($0617).
"""
import sys, os
sys.path.insert(0, '/home/claude/work')
import numpy as np
from emu import *
R, S = NES_INPUT_RIGHT, NES_INPUT_START

def room():
    os.chdir('/home/claude/work')
    from cap import goto_room
    e, spot, sc = goto_room(0, 0, 1)
    return e

def watch(e, plan):
    n = e.nes; last = None
    for f, b in enumerate(plan):
        e.run(1, b)
        key = (n[0x67], tuple(n[0x77 + i] for i in range(4)), n[0x510], n[0x570], n[0x400], n[0x34], n[0x35], n[0xD0], n[0x617], n[0x5C], n[0x46])
        if key != last:
            print('frame %3d turtle %d energy %s state %02X animation %02X picture %3d | step %d start screen %d/%d caught %d inside %d continues %d' % ((f,) + key[:1] + (list(key[1]),) + key[2:]))
            last = key

if __name__ == '__main__':
    print('one turtle lost in the first sewer, then Start')
    e = room(); n = e.nes
    n[0x77] = 4; n[0x500] = 0; n[0x450] &= 0xDB
    watch(e, [R]*300 + [0]*100 + [S]*2 + [0]*200)
    print('the last turtle lost, then Start on CONTINUE')
    e = room(); n = e.nes
    n[0x77] = 4; n[0x78] = 0; n[0x79] = 0; n[0x7A] = 0; n[0x500] = 0; n[0x450] &= 0xDB
    watch(e, [R]*300 + [0]*500 + [S]*2 + [0]*300)
