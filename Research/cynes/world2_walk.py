"""Getting about world 2 in the emulator (cynes): its overworld from the start of play, the
lower doorway, the jump into the lake, and the clock running out. See Research/world2.md.
   python3 world2_walk.py path/to/rom.nes"""
import sys
from cynes import NES, NES_INPUT_START, NES_INPUT_LEFT, NES_INPUT_RIGHT, NES_INPUT_UP
nes = NES(sys.argv[1])
def run(frames, buttons=0):
    for _ in range(frames):
        nes.controller = buttons; nes.step()
def where(): return (nes[0x480] + (nes[0x4F] | nes[0x50] << 8), nes[0x460] + (nes[0x51] | nes[0x52] << 8))
def state(): return dict(step=nes[0x34], inside=nes[0x5C], area=nes[0x5D], at=where(), turtle_state=nes[0x510], clock=(nes[0xBB], nes[0xBA]))

run(200)
for _ in range(3):
    run(5, NES_INPUT_START); run(90)
run(120)
while nes[0x5C] == 0: run(1, NES_INPUT_LEFT)          # into world 1's first manhole
# Begin world 2: the play step "begin the world" with the world and (on the overworld) the area at 1.
nes[0x48] = 1; nes[0x5D] = 1; nes[0x5C] = 0; nes[0x34] = 2
run(200)
print("world 2 begins:", state(), "van flag", nes[0x606])
start = nes.save()

while where()[0] < 152: run(1, NES_INPUT_RIGHT)
while nes[0x5C] == 0: run(1, NES_INPUT_UP)
run(120)
print("by the lower doorway:", state())
print("  objects:", ["%02X" % nes[0x440 + s] for s in range(5, 16) if nes[0x440 + s]])

nes.load(start); run(1)
nes[0x480] = 0x58; nes[0x460] = 0x58                  # where area 0's top door lets him out
run(4)
while where()[0] < 376:
    nes[0x77] = 0x80; nes[0x500] = 30; run(1, NES_INPUT_RIGHT)
frame = 0; last = None
while not (nes[0x5C] and nes[0x510] == 0x0F):
    nes[0x77] = 0x80
    run(1, NES_INPUT_UP if nes[0x5C] == 0 and nes[0x510] == 0 else 0); frame += 1
    now = (nes[0x570], nes[0x34], nes[0x5C])
    if now != last: print("  frame", frame, "animation %02X" % nes[0x570], state()); last = now
print("under water:", state())
print("  fixed things in hand:", [("%02X" % nes[0x650 + i], nes[0x678 + i], nes[0x680 + i]) for i in range(8) if nes[0x650 + i]])
print("  objects:", [("%02X" % nes[0x440 + s], nes[0x480 + s], nes[0x460 + s]) for s in range(5, 16) if nes[0x440 + s]])

nes[0xBB] = 2                                          # two seconds left
frame = 0; last = None
while nes[0x34] == 6 and frame < 600:
    run(1); frame += 1
    now = (nes[0xB5], nes[0xBB], nes[0x77])
    if now != last: print("  frame", frame, "scene %02X clock %d energy %d" % now); last = now
print("after the clock ran out: play step", nes[0x34], "energies", [nes[0x77 + i] for i in range(4)])
