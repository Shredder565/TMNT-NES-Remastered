"""Write down what the original's sound program sends to the sound chip.

A scenario is a list of events (frame, number) and a count of frames; an
event's number is started just before that frame's step (-1 = silence
everything, -2 = begin a fade-out).  The output has, for each scenario, one
list of writes per frame (register * 256 + value); list 0 holds the writes
of events at frame 0, which come before the first step, list k+1 the writes
of step k together with those of events that came just before it... to keep
it simple each frame's list is: [events' writes..., step's writes...].

usage: python3 -I rec_writes.py out.json            (the standard set)"""
import sys, json
sys.path.insert(0, '/home/claude/work_agent_sound')
from mini6502 import SoundRun

def run(events, frames):
    s = SoundRun(); s.frame(); s.take_writes()
    out = []
    ev = {}
    for f, n in events: ev.setdefault(f, []).append(n)
    for f in range(frames):
        for n in ev.get(f, []):
            if n == -1: s.stop()
            elif n == -2: s.cpu.mem[0x199] = 7
            else: s.play(n)
        s.frame()
        out.append([a * 256 + v for a, v in s.take_writes()])
    state = dict(slots=[s.ram(0x10A + i) for i in range(6)], over=s.ram(0x19D))
    return out, state

TUNES = [0x4E,0x53,0x57,0x5B,0x5F,0x63,0x67,0x6B,0x6F,0x73,0x77,0x7B,0x7F,0x83,0x87,0x8B]
def standard():
    sc = []
    for n in range(1, 0x4E):
        sc.append(dict(name='sound %02X' % n, events=[[0, n]], frames=500))
    for n in TUNES:
        sc.append(dict(name='tune %02X' % n, events=[[0, n]], frames=7000))
    sc.append(dict(name='sample 8F', events=[[0, 0x8F]], frames=5))
    sc.append(dict(name='52 after 53', events=[[0, 0x53], [200, 0x52]], frames=400))
    # effects over a tune: the first square wave is taken and given back
    for tune, at, fx in ((0x53, 100, 0x21), (0x5B, 333, 0x25), (0x4E, 150, 0x3C), (0x6B, 77, 0x07), (0x5F, 500, 0x2A), (0x6F, 41, 0x12)):
        sc.append(dict(name='tune %02X, effect %02X at %d' % (tune, fx, at), events=[[0, tune], [at, fx], [at + 90, fx], [at + 93, 0x08]], frames=900))
    # every effect over the overworld tune, at an awkward moment
    for fx in range(1, 0x4B):
        sc.append(dict(name='tune 53, effect %02X' % fx, events=[[0, 0x53], [217, fx], [230, 0x22]], frames=600))
    # priorities: lower numbers do not cut higher ones
    sc.append(dict(name='21 then 07 then 2A', events=[[0, 0x21], [3, 0x07], [6, 0x2A], [8, 0x25]], frames=200))
    sc.append(dict(name='16 twice', events=[[0, 0x16], [5, 0x16], [9, 0x01]], frames=100))
    # fades, stops, the tunes that start over others
    sc.append(dict(name='fade 5B', events=[[0, 0x5B], [300, -2]], frames=800))
    sc.append(dict(name='fade 53 with effects', events=[[0, 0x53], [100, -2], [200, 0x21], [320, 0x2A]], frames=600))
    sc.append(dict(name='stop', events=[[0, 0x6F], [250, -1], [260, 0x22]], frames=400))
    sc.append(dict(name='77 over 5B', events=[[0, 0x5B], [200, 0x77], [210, 0x21], [215, 0x42], [400, 0x21]], frames=900))
    sc.append(dict(name='7F over 53', events=[[0, 0x53], [200, 0x7F], [600, 0x53]], frames=1200))
    sc.append(dict(name='83 locks', events=[[0, 0x5B], [100, 0x83], [120, 0x53], [130, -1], [140, 0x21], [500, 0x53]], frames=900))
    sc.append(dict(name='tune to tune', events=[[0, 0x4E], [300, 0x53], [700, 0x5B], [1000, 0x73], [1500, 0x7B], [1900, 0x8B]], frames=2500))
    sc.append(dict(name='48 and 4B', events=[[0, 0x53], [100, 0x48], [400, 0x4B]], frames=900))
    return sc

if __name__ == '__main__':
    sc = standard()
    for s in sc:
        s['writes'], s['end'] = run(s['events'], s['frames'])
    json.dump(sc, open(sys.argv[1], 'w'))
    print(len(sc), 'scenarios', sum(len(w) for s in sc for w in s['writes']), 'writes')
