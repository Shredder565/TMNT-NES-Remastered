"""Emulator recordings behind Research/overworld.md.

Needs the `cynes` package and the helper scripts described in the agent
brief (emu.py, capow.py). Run with: python3 -I overworld_checks.py
It prints, for world 1's overworld: the turtle's picture numbers as he
walks, the camera's scroll marks, and what each enemy that comes in does.
The remake side of the comparison is Research/cynes/overworld_replay.gd.txt.
"""
import sys, os, json
sys.path.insert(0, '/home/claude/work')
from emu import *

R, L, U, D = NES_INPUT_RIGHT, NES_INPUT_LEFT, NES_INPUT_UP, NES_INPUT_DOWN

def boot_overworld():
    e = E(); e.run(200)
    for k in range(3):
        e.run(5, NES_INPUT_START); e.run(90)
    e.run(120)
    return e

def at(px, py):
    """The turtle put at a spot of world 1's overworld (the camera is set round him, so nothing has come in yet)."""
    os.chdir('/home/claude/work')
    from capow import exit_state
    e = E(); n = e.nes; n.load(exit_state())
    sx = max(0, min(px - 128, 256)); sy = max(0, min(py - 120, 272))
    n[0x48] = 0; n[0x5D] = 0; n[0x5C] = 0
    n[0x480] = px - sx; n[0x460] = py - sy
    n[0x4F] = sx & 255; n[0x50] = sx >> 8; n[0x51] = sy & 255; n[0x52] = sy >> 8
    for f in range(100):
        n[0x500] = 60; n[0x77] = 0x80; e.run(1)
    return e

def signed(v): return v - 256 if v > 127 else v

def record(e, buttons, frames):
    """One row per frame: buttons, frame counter, camera, turtle, and every other object."""
    n = e.nes; rows = []
    for f in range(frames):
        n[0x77] = 0x80; n[0x500] = 60          # keep him alive and safe
        b = buttons(f); e.run(1, b)
        cx = n[0x4F] | n[0x50] << 8; cy = n[0x51] | n[0x52] << 8
        rows.append(dict(btn=b, fc=n[0x1E], cam=[cx, cy], tx=cx + n[0x480], ty=cy + n[0x460],
                         pic=n[0x400], anim=n[0x570], left=n[0x450] & 1,
                         e=[[n[0x440 + X], cx + n[0x480 + X], cy + n[0x460 + X], 'f%d' % n[0x400 + X], bool(n[0x450 + X] & 1),
                             signed(n[0x4E0 + X]) * 256 + n[0x4F0 + X], signed(n[0x4B0 + X]) * 256 + n[0x4C0 + X]]
                            for X in range(1, 16) if n[0x440 + X]],
                         colours=[n[0x59F + k] for k in range(32)], pages=[n[0x27], n[0x28]]))
    return rows

def show_walk(rows):
    last = None
    for f, r in enumerate(rows):
        key = (r['btn'], r['pic'], r['anim'], r['left'])
        if key != last:
            print('frame %3d buttons %2d picture %d animation %02X facing left %d at %d,%d camera %s' %
                  (f, r['btn'], r['pic'], r['anim'], r['left'], r['tx'], r['ty'], r['cam'])); last = key

def show_enemies(rows):
    last = {}
    for f, r in enumerate(rows):
        for i, o in enumerate(r['e']):
            key = (o[0], o[4], o[5], o[6])
            if last.get(i) != key:
                print('frame %3d kind %02X at %d,%d picture %s facing left %s speed %d,%d' % (f, o[0], o[1], o[2], o[3], o[4], o[5], o[6])); last[i] = key
    print('colour lists seen:', len({tuple(r['colours']) for r in rows}), 'graphics pages seen:', {tuple(r['pages']) for r in rows})

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else None
    walk = [(R, 60), (0, 6), (R, 24), (L, 40), (U, 120), (0, 4), (D | R, 30), (D | L, 20), (U | D, 10), (0, 10)]
    plan = [b for b, n in walk for _ in range(n)]
    rows = record(boot_overworld(), lambda f: plan[f], len(plan)); show_walk(rows)
    runs = {'walk': rows}
    print('kind 9A (comes in from the left near the start)')
    runs['9A'] = record(boot_overworld(), lambda f: R if f < 48 else (0 if f < 58 else (L if f < 106 else 0)), 400); show_enemies(runs['9A'])
    print('kind 9B (comes in from the top)')
    runs['9B'] = record(at(376, 208), lambda f: U if f < 60 else 0, 900); show_enemies(runs['9B'])
    print('kind 40 (comes in from the bottom, then the turtle walks up and down)')
    runs['40'] = record(at(376, 152), lambda f: D if f < 20 else (U if 200 <= f < 260 else (D if 400 <= f < 440 else 0)), 700); show_enemies(runs['40'])
    print('kind 40 (two come in from the right)')
    runs['40b'] = record(at(40, 432), lambda f: R if f < 135 else (L if 400 <= f < 430 else 0), 700); show_enemies(runs['40b'])
    if out:
        for name, rows in runs.items():
            json.dump(rows, open(os.path.join(out, 'overworld_%s.json' % name), 'w'))
