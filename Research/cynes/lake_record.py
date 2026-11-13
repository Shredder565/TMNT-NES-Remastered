"""Swimming with the lake's clock, currents and bombs live: only the objects that hurt (kinds 1B
to 22) are taken away every frame. For swim_replay.gd.txt, which sets the lake going when the
recording's file name has "lake" in it (Research/lake.md).
   python3 lake_record.py path/to/rom.nes rec_lake.json
A row is swim_record.py's, with three more: the scene ($B5), the bombs seen to ($7D), the number
of the current he is in ($8B)."""
import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from swim_record import *

def wipe_hazards(n):
    for slot in range(5, 16):
        if 0x1B <= n[0x440 + slot] <= 0x22: n[0x440 + slot] = 0; n[0x400 + slot] = 0

def place_live(x, y):
    n = NES(ROM); n.load(BASE)
    sx = max(0, min(x - 128, 9 * 256 - 256)); sy = (y // 192) * 192
    n[0x48] = 1; n[0x5D] = 1; n[0x5C] = 1
    n[0x480] = x - sx; n[0x460] = y - sy; n[0x4F] = sx & 255; n[0x50] = sx >> 8; n[0x51] = sy & 255; n[0x52] = sy >> 8
    for f in range(200):
        n[0x77] = 0x80; n[0xBB] = 140; n[0xBA] = 30; n[0x7D] = 0; wipe_hazards(n); run(n, 1)
    return n

def record_live(n, ctl, frames):
    rows = []
    for f in range(frames):
        n[0x77] = 0x80; wipe_hazards(n)
        b = ctl(f) if n[0xB5] == 0 else 0
        run(n, 1, b); rows.append(row(n, b) + [n[0xB5], n[0x7D], n[0x8B]])
    return rows

LAKE_RUNS = {
 'bomb1': ((96, 480), seq((122, lambda f: R | (A if f % 8 < 2 else 0)), (400, lambda f: 0), (300, taps(10, R))), 800),
 'cur_bottom': ((552, 444), taps(11, R), 1400),
 'cur_middle': ((532, 272), taps(12, R), 1400),
 'cur_top': ((1822, 60), taps(9, R), 900),
 'cur_bottom_left': ((1100, 430), taps(10, L), 1200),
 'cur_down_held': ((552, 444), seq((300, taps(11, R)), (200, lambda f: D | R), (300, taps(7, R))), 800),
 'cur_bottom_far': ((1800, 430), taps(13, R), 1200),
}
out = {name: record_live(place_live(*at), ctl, frames) for name, (at, ctl, frames) in LAKE_RUNS.items()}
json.dump(out, open(sys.argv[2], "w"))
for name, rows in out.items():
    print(name, len(rows), "frames; currents:", sorted({"%02X" % r[16] for r in rows}), "scenes:", sorted({"%02X" % r[31] for r in rows}), "clock", rows[0][19], "to", rows[-1][19])
