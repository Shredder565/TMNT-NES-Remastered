"""Emulator recordings behind "The fight" in Research/overworld.md.

Needs the `cynes` package and the helper scripts described in the agent
brief (emu.py, capow.py). Run with: python3 -I overworld_fight_checks.py [folder]
With a folder it writes one JSON file per recording, in the shape
overworld_fight_replay.gd.txt reads.
"""
import sys, os, json
sys.path.insert(0, '/home/claude/work')
from emu import *

R, L, U, D, B, S = NES_INPUT_RIGHT, NES_INPUT_LEFT, NES_INPUT_UP, NES_INPUT_DOWN, NES_INPUT_B, NES_INPUT_START

def boot_with(turtle):
    """World 1's overworld at its start, with the given turtle (0 to 3) chosen on the Start screen."""
    e = E(); e.run(200)
    for k in range(3):
        e.run(5, S); e.run(90)
    e.run(120)
    if turtle:
        e.run(1, S); e.run(30)
        for k in range(turtle):
            e.run(2, D); e.run(10)
        e.run(1, S); e.run(80)
    return e

def at(px, py):
    os.chdir('/home/claude/work')
    from capow import exit_state
    e = E(); n = e.nes; n.load(exit_state())
    sx = max(0, min(px - 128, 256)); sy = max(0, min(py - 120, 272))
    n[0x48] = 0; n[0x5D] = 0; n[0x5C] = 0
    n[0x480] = px - sx; n[0x460] = py - sy
    n[0x4F] = sx & 255; n[0x50] = sx >> 8; n[0x51] = sy & 255; n[0x52] = sy >> 8
    for f in range(100):
        n[0x500] = 60; n[0x77] = 0x80; e.run(1)
    n[0x500] = 0
    return e

def record(e, plan, keep_energy=False):
    n = e.nes; rows = []
    for b in plan:
        if keep_energy: n[0x77 + n[0x67]] = 0x80
        e.run(1, b)
        cx = n[0x4F] | n[0x50] << 8; cy = n[0x51] | n[0x52] << 8
        out = n[0x401] != 0
        rows.append(dict(btn=b, fc=n[0x1E], cam=[cx, cy], tx=cx + n[0x480], ty=cy + n[0x460], left=n[0x450] & 1,
                         pic=n[0x400], st=n[0x510], wpic=n[0x401], rel=[n[0x481] - n[0x480], n[0x461] - n[0x460]] if out else [0, 0],
                         en=n[0x77 + n[0x67]], safe=n[0x500],
                         e=[[n[0x440 + X], cx + n[0x480 + X], cy + n[0x460 + X], n[0x560 + X]] for X in range(2, 16) if n[0x440 + X] in (0x40, 0x9A, 0x9B)]))
    return rows

def show(rows):
    last = None
    for f, r in enumerate(rows):
        key = (r['st'], r['pic'], r['wpic'], tuple(r['rel']), r['en'], r['safe'] > 0, tuple(tuple(e[::3]) for e in r['e']))
        if key != last:
            print('frame %3d state %d picture %d weapon %d at %s energy %d safe %d enemies %s' % (f, r['st'], r['pic'], r['wpic'], r['rel'], r['en'], r['safe'], r['e'])); last = key

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else None
    attack = [0]*10 + [B]*2 + [0]*40 + [R]*6 + [0]*6 + [B]*2 + [0]*40 + [L]*6 + [0]*6 + [B]*2 + [0]*40 + [U]*6 + [0]*6 + [B]*2 + [0]*40 + [D]*6 + [B]*20 + [0]*30 + [R | B]*30 + [0]*20
    runs = {}
    for t in range(4):
        print('the attack, turtle', t); runs['attack_%d' % t] = record(boot_with(t), attack); show(runs['attack_%d' % t])
    print('a soldier walks into him and is hit')
    runs['soldier_touch'] = record(at(376, 152), [D]*20 + [0]*100 + ([B]*2 + [0]*28)*8 + [0]*60); show(runs['soldier_touch'])
    print('a soldier beside him: a miss to the right, a hit upward')
    runs['soldier_beside'] = record(at(40, 432), [R]*135 + [0]*265 + [L]*30 + [0]*60 + [R]*2 + [0]*10 + ([B]*2 + [0]*28)*2 + [U]*2 + [0]*10 + ([B]*2 + [0]*28)*2 + [0]*30); show(runs['soldier_beside'])
    print('a roller drives past while he swings (his energy is refilled every frame)')
    runs['roller'] = record(at(376, 208), [U]*60 + [0]*30 + ([B]*2 + [0]*14)*20 + [0]*40, keep_energy=True); show(runs['roller'])
    if out:
        for name, rows in runs.items():
            json.dump(rows, open(os.path.join(out, 'overworld_fight_%s.json' % name), 'w'))
