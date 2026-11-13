"""Swimming in world 2's lake, turtle alone: scripted runs recorded frame by frame for
swim_replay.gd.txt (Research/swimming.md). Objects, the things at fixed places and the
currents are cleared every frame; the clock is held at 140.
   python3 swim_record.py path/to/rom.nes out1.json out2.json
A row: frame counter, screen corner (x, y), X and fraction, Y and fraction, speed across (whole,
fraction), speed down, state, animation, picture, flags, energy, current, row change ($3F, $3E),
clock ($BB, $BA), the bubble (kind, x, y, animation, picture, y fraction), animation step and
count, safe time, buttons."""
import sys, json
from cynes import NES, NES_INPUT_START, NES_INPUT_A, NES_INPUT_RIGHT, NES_INPUT_LEFT, NES_INPUT_UP, NES_INPUT_DOWN
R, L, A, U, D = NES_INPUT_RIGHT, NES_INPUT_LEFT, NES_INPUT_A, NES_INPUT_UP, NES_INPUT_DOWN
ROM = sys.argv[1]

def run(nes, frames, buttons=0):
    for _ in range(frames):
        nes.controller = buttons; nes.step()

def base_state():
    nes = NES(ROM)
    run(nes, 200)
    for _ in range(3):
        run(nes, 5, NES_INPUT_START); run(nes, 90)
    run(nes, 120)
    while nes[0x5C] == 0: run(nes, 1, NES_INPUT_LEFT)      # into world 1's first manhole
    return nes.save()
BASE = base_state()

def wipe(n):
    for slot in range(5, 16): n[0x440 + slot] = 0
    for i in range(8): n[0x650 + i] = 0
    n[0x7E] = 0; n[0x8B] = 0

def place(x, y):
    """his middle at (x, y) in the lake: the room is brought up round the place"""
    n = NES(ROM); n.load(BASE)
    sx = max(0, min(x - 128, 9 * 256 - 256)); sy = (y // 192) * 192
    n[0x48] = 1; n[0x5D] = 1; n[0x5C] = 1
    n[0x480] = x - sx; n[0x460] = y - sy; n[0x4F] = sx & 255; n[0x50] = sx >> 8; n[0x51] = sy & 255; n[0x52] = sy >> 8
    for f in range(200):
        n[0x77] = 0x80; n[0xBB] = 140; wipe(n); run(n, 1)
    return n

def row(n, b):
    return [n[0x1E], n[0x4F] | n[0x50] << 8, n[0x51] | n[0x52] << 8, n[0x480], n[0x490], n[0x460], n[0x470], n[0x4E0], n[0x4F0], n[0x4B0], n[0x4C0],
            n[0x510], n[0x570], n[0x400], n[0x450], n[0x77], n[0x7E], n[0x3F], n[0x3E], n[0xBB], n[0xBA],
            n[0x441], n[0x481], n[0x461], n[0x571], n[0x401], n[0x471], n[0x410], n[0x420], n[0x500], b]

def record(n, ctl, frames, energy=True):
    rows = []
    for f in range(frames):
        if energy: n[0x77] = 0x80
        n[0xBB] = 140; wipe(n)
        b = ctl(f); run(n, 1, b); rows.append(row(n, b))
    return rows

def taps(period, hold=0, length=2):
    return lambda f: hold | (A if f % period < length else 0)

def seq(*parts):
    def ctl(f):
        for n_, fn in parts:
            if f < n_: return fn(f)
            f -= n_
        return 0
    return ctl
RUNS = {
 'sink': ((96,480), lambda f:0, 300),
 'right': ((96,480), lambda f:R, 700),
 'right_taps20': ((96,480), taps(20,R), 1000),
 'left_taps8': ((300,460), taps(8,L), 600),
 'up_taps': ((96,480), taps(10,U), 900),
 'taps6': ((96,480), taps(6), 500),
 'down_right': ((96,440), lambda f:D|R, 400),
 'right_taps14': ((96,480), taps(14,R), 1600),
 'zig': ((400,470), seq((120,taps(12,R)),(120,taps(9,L)),(100,lambda f:D),(200,taps(7,U|R)),(200,taps(16,L)),(300,taps(11,R))), 1040),
 'top_row_right': ((96,96), taps(13,R), 1500),
 'mid_row_right': ((96,288), taps(15,R), 1500),
 'mid_left': ((2200,288), taps(12,L), 1500),
 'top_left': ((2200,96), taps(17,L), 1500),
 'bottom_left': ((2100,470), taps(10,L), 1500),
 'hold_a': ((96,480), lambda f:A|R, 300),
 'updown': ((700,300), seq((150,taps(5,U)),(200,lambda f:D|L),(200,taps(5,U|R)),(200,lambda f:D)), 750),
 'lr_both': ((96,460), seq((60,lambda f:L|R),(60,taps(10,L|R)),(100,taps(8,U|D|R))), 220),
 'far_right': ((1500,480), taps(12,R), 1500),
}
RUNS2 = {
 'shaft_down': ((1888,100), seq((200,lambda f:0),(200,lambda f:L if f%40<20 else R),(600,lambda f:0)), 1000, True),
 'weed_shaft': ((1384,60), seq((300,lambda f:L if f%60<30 else R),(600,lambda f:R)), 900, False),
 'weed_shaft_full': ((1384,60), seq((300,lambda f:L if f%60<30 else R),(600,lambda f:R)), 900, True),
 'deadly': ((960,120), taps(12,R), 400, True),
 'left_edge': ((60,480), taps(9,L), 300, True),
 'top_gap': ((1232,60), taps(6,U), 500, True),
 'bottom_deadly': ((650,500), lambda f:0, 400, True),
 'down_hold': ((1888,100), lambda f:D|(R if f%50<25 else L), 900, True),
}
first = {name: record(place(*at), ctl, frames) for name, (at, ctl, frames) in RUNS.items()}
json.dump(first, open(sys.argv[2], "w"))
second = {name: record(place(*at), ctl, frames, energy) for name, (at, ctl, frames, energy) in RUNS2.items()}
json.dump(second, open(sys.argv[3], "w"))
for name, rows in list(first.items()) + list(second.items()):
    print(name, len(rows), "frames; row changes:", sum(1 for i in range(1, len(rows)) if rows[i][17] and not rows[i - 1][17]), "least energy:", min(r[15] for r in rows), "last state: %02X" % rows[-1][11])
