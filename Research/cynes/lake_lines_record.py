"""The lake with its switching lines live: only the columns (kinds 1B to 1E) are taken away, the
bombs are marked as seen to, and his energy is not refilled. For swim_replay.gd.txt (the file
name must have "lake" and "lines" in it). See Research/lake.md.
   python3 lake_lines_record.py path/to/rom.nes rec_lake_lines.json"""
import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from swim_record import *

def wipe_columns(n):
    for slot in range(5, 16):
        if 0x1B <= n[0x440 + slot] <= 0x1E: n[0x440 + slot] = 0; n[0x400 + slot] = 0

def place_lines(x, y):
    n = NES(ROM); n.load(BASE)
    sx = max(0, min(x - 128, 9 * 256 - 256)); sy = (y // 192) * 192
    n[0x48] = 1; n[0x5D] = 1; n[0x5C] = 1
    n[0x480] = x - sx; n[0x460] = y - sy; n[0x4F] = sx & 255; n[0x50] = sx >> 8; n[0x51] = sy & 255; n[0x52] = sy >> 8
    for f in range(200):
        n[0x77] = 0x80; n[0xBB] = 140; n[0xBA] = 30; n[0x7D] = 0xFF; n[0x500] = 2; wipe_columns(n); run(n, 1)
    n[0x77] = 0x80
    return n

def record_lines(n, ctl, frames):
    rows = []
    for f in range(frames):
        wipe_columns(n); n[0x7D] = 0xFF
        b = ctl(f) if n[0xB5] == 0 else 0
        run(n, 1, b); rows.append(row(n, b) + [n[0xB5], n[0x7D], n[0x8B]])
    return rows

LINE_RUNS = {
 'line_first': ((96,480), taps(16,R), 700),
 'line_first_slow': ((96,480), seq((60,lambda f:0),(700,taps(13,R))), 760),
 'lines_two': ((828,484), taps(12,R), 700),
 'lines_c': ((356,470), taps(14,R), 700),
 'lines_c_left': ((600,470), taps(11,L), 800),
 'lines_hover': ((140,470), seq((100,taps(9,R)),(300,taps(9)),(300,taps(9,R))), 700),
}
out = {name: record_lines(place_lines(*at), ctl, frames) for name, (at, ctl, frames) in LINE_RUNS.items()}
json.dump(out, open(sys.argv[2], "w"))
for name, rows in out.items():
    print(name, len(rows), "frames; hurt at", [i for i in range(1, len(rows)) if rows[i][15] < rows[i - 1][15]], "energy at the end", rows[-1][15])
