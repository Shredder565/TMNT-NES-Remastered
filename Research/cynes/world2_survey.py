"""World 2's tables, printed from the ROM: doors, rooms, enemy places, things at fixed
places, held fights. See Research/world2.md.   python3 world2_survey.py path/to/rom.nes"""
import sys
prg = open(sys.argv[1], "rb").read()[16:16 + 0x20000]
def b(bank, a): return prg[bank * 0x4000 + (a & 0x3FFF)]
def w(bank, a): return b(bank, a) | b(bank, a + 1) << 8
WORLD = 1

def doors(at):
    out = []
    while b(7, at) != 0xFF:
        r = [b(7, at + i) for i in range(11)]
        out.append(dict(screen=r[0], x=r[1], y=r[2], inside=r[3], area=r[4], to=(r[5], r[6]), corner=(r[7] << 8 | r[8], r[9] << 8 | r[10])))
        at += 11
    return out

m = w(7, 0xF4AA + WORLD * 2)
print("overworld", b(7, m), "x", b(7, m + 1), "screens")
for d in doors(w(7, 0xE85D + WORLD * 2)): print("  door", d)
t = w(6, 0xAC8F + WORLD * 2)
for s in range(b(7, m) * b(7, m + 1)):
    a = w(6, t + s * 2); spots = []
    while b(6, a) != 0xFF: spots.append((b(6, a), b(6, a + 1), "%02X" % b(6, a + 2))); a += 3
    print("  screen", s, "enemy places", spots)
for area in (0, 1):
    m = w(7, w(7, 0xF49E + WORLD * 2) + area * 2)
    width, height = b(7, m), b(7, m + 1)
    print("area", area, width, "x", height, "screens; background page", b(7, w(7, 0xD5CE + WORLD * 2) + area * 2))
    if area == 0:                                   # the underwater area has no door list
        for d in doors(w(7, w(7, 0xE84F + WORLD * 2) + area * 2)): print("  door", d)
        t = w(6, w(6, 0x8681 + WORLD * 2) + area * 2)
        for s in range(width * height):
            a = w(6, t + s * 2); spots = []
            while b(6, a) != 0xFF: spots.append("%02X %02X %02X" % (b(6, a), b(6, a + 1), b(6, a + 2))); a += 3
            print("  screen", s, "enemy places", spots)
        t = w(6, w(6, 0x82EB + WORLD * 2) + area * 2)
        print("  line-ups by level", [b(6, t + i) for i in range(4)])
    a = w(4, w(4, 0xACCD + WORLD * 2) + area * 2)
    while b(4, a) != 0xFF:
        print("  fixed thing: screen %d, x %d-%d, y %d-%d, kind %02X, number %d, flags %02X" % tuple(b(4, a + i) for i in range(8))); a += 8
    a = w(6, w(6, 0x9E6D + WORLD * 2) + area * 2)
    while b(6, a) != 0xFF:
        print("  held fight: row %d column %d at (%d, %d) slot byte %02X" % tuple(b(6, a + i) for i in range(5))); a += 5
for n in (0, 1, 2, 16, 17):
    a = w(6, 0x86E9 + n * 2)
    print("line-up", n, " ".join("%02X" % b(6, a + i) for i in range(6)))
print("the table of what a fixed thing makes (4:$B9E5): kind, animation, hit points, flags")
for i in range(0x10, 0x1E):
    a = 0xB9E5 + i * 5
    print("  %02X: %02X %02X %02X %02X" % (i, b(4, a), b(4, a + 1), b(4, a + 2), b(4, a + 3)))
