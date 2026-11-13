"""Check a WAV rendered by render_wav.gd against the pitches the original's
program sends: in every stretch where a channel's pitch number stays put,
the spectrum should peak at that channel's frequency."""
import sys, json, wave, numpy as np
sys.path.insert(0,'/home/claude/work_agent_sound')
from mini6502 import SoundRun
wavp, tune, frames = sys.argv[1], int(sys.argv[2],16), int(sys.argv[3])
w = wave.open(wavp); x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float)
CPU = 1789773.0
s = SoundRun(); s.frame(); s.take_writes(); s.play(tune)
reg = {}
hist = []
for f in range(frames):
    s.frame()
    for a, v in s.take_writes(): reg[a] = v
    hist.append(dict(reg))
def check(name, lo, hi, vol, div):
    ok = bad = 0; i = 0
    while i < frames:
        j = i
        key = (hist[i].get(lo), hist[i].get(hi, 0) & 7)
        while j < frames and (hist[j].get(lo), hist[j].get(hi, 0) & 7) == key: j += 1
        if j - i >= 5 and key[0] is not None:
            j2 = j; j = min(j, i + 9)
            p = key[0] | key[1] << 8
            loud = all((hist[k].get(vol, 0) & 15) >= 3 for k in range(i, j)) if vol else all((hist[k].get(0x4008, 0) & 0x80) or (hist[k].get(0x4008, 0) & 0x7F) >= 4 * (j - i) for k in range(i, j))
            if loud and p >= 8:
                f0 = CPU / (div * (p + 1))
                seg = x[(i + 1) * 735:(j) * 735]
                sp = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))); fr = np.fft.rfftfreq(len(seg), 1 / 44100.0)
                band = (fr > f0 * 0.97) & (fr < f0 * 1.03)
                near = (fr > f0 * 0.75) & (fr < f0 * 1.25)
                pk = fr[near][np.argmax(sp[near])]
                if abs(pk - f0) <= max(f0 * 0.02, 44100.0 / len(seg)): ok += 1
                else: bad += 1; print('  ', name, 'frames', i, j, 'expected %.1f Hz, strongest nearby %.1f' % (f0, pk))
        i = max(j, j2) if 'j2' in dir() and j2 >= j else j
        j2 = 0
    print(name, 'stretches with the right pitch:', ok, 'wrong:', bad)
check('square 1', 0x4002, 0x4003, 0x4000, 16)
check('square 2', 0x4006, 0x4007, 0x4004, 16)
check('triangle', 0x400A, 0x400B, None, 32)
