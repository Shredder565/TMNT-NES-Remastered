"""Prove the mini interpreter: the title tune's sound RAM in cynes (whole
game running) against the sound program run alone in mini6502."""
import sys; sys.path.insert(0,'/home/claude/work'); sys.path.insert(0,'/home/claude/work_agent_sound')
from emu import *
from mini6502 import SoundRun
e=E(); n=e.nes
rows=[]
for f in range(2400):
    e.run(1,0); rows.append(bytes(n[a] for a in range(0x100,0x1B0)))
start=next(f for f,r in enumerate(rows) if r[0x0A]==0x4E)
print('tune 4E appears at frame',start)
s=SoundRun(); s.play(0x4E)
LO,HI=0x04,0xAE
s=SoundRun(); s.frame(); s.play(0x4E)
prev=None; eq=0; skipped=[]; f=start
while f<len(rows) and rows[f][0x0A]==0x4E:
    mine=bytes(s.ram(0x100+i) for i in range(LO,HI)); theirs=rows[f][LO:HI]
    if mine==theirs:
        eq+=1; prev=mine; s.frame(); f+=1
    elif prev==theirs:
        skipped.append(f); f+=1        # the game missed one update this frame
    else:
        print('real difference at',f,[('%04X'%(0x100+LO+i),mine[i],theirs[i]) for i in range(len(mine)) if mine[i]!=theirs[i]][:8]); break
print('frames equal',eq,'frames where the game skipped its sound update',skipped,'stopped at',f)
