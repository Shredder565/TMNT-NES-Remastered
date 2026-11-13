"""The enemies agent's whole-room recordings again (same rooms, same
buttons), with one thing more per frame: which sound number the game asked
for.  A sentinel is put in $0194 (the byte "start sound" keeps its number
in) before each frame; whatever is there after the frame was asked for
during it.  The music's drum track is kept switched off so that its own
drum sounds (numbers 2-6) do not hide the game's calls.
usage: python3 -I snd_live.py <set> -> snd_<set>.json"""
import sys, json
sys.path.insert(0,'/home/claude/work_agent_enemies'); sys.path.insert(0,'/home/claude/work')
import rec
from common import *
SENT=0xEE
import os
KILL_DRUMS=os.environ.get("KEEP_DRUMS")!="1"
def record(area,x,y,script,frames,poke=None,settle=1,safe=True):
    e=place(area,x,y,settle=settle); n=e.nes
    rows=[]
    for f in range(frames):
        if safe:
            n[0x450]|=4; n[0x500]=60
            n[0x77]=0x80
        elif f<70:
            n[0x450]|=4; n[0x500]=30
        elif f==70:
            n[0x450]&=0xFB; n[0x500]=0
        if poke: poke(f,n)
        btn=script(f)
        n[0x194]=SENT
        if KILL_DRUMS: n[0x10D]=0
        e.run(1,btn)
        s=n[0x194]
        cam=n[0x4F]|n[0x50]<<8; camy=n[0x51]|n[0x52]<<8
        rows.append(dict(c=n[0x1E],b=btn,cam=cam,camy=camy,t=[n[0x480],n[0x490],n[0x460],n[0x470],n[0x450],n[0x510],n[0x570],n[0x540],n[0x500]],w=[[n[0x440+X],n[0x480+X],n[0x460+X],n[0x570+X]] for X in range(1,5) if n[0x440+X] or n[0x570+X]],o=rec.snap(n),hold=n[0x5E],e=n[0x77],sc=(n[0x40]-256 if n[0x40]>127 else n[0x40]),r=n[0x45],
                         s=(s if s!=SENT else -1),m=n[0x10A]))
    return dict(area=area,start=[x,y],rows=rows,hits=sorted(getattr(poke,'frames',[])),hit_kind=getattr(poke,'kind',0))
rec.record=record
if __name__=='__main__':
    name=sys.argv[1]
    data=rec.SETS[name]()
    json.dump(data,open('/home/claude/work_agent_sound/snd_%s.json'%name,'w'))
    for k,v in data.items():
        ev=[(f,'%02X'%r['s']) for f,r in enumerate(v['rows']) if r['s']>=0]
        print(k,len(v['rows']),'energy at end',v['rows'][-1]['e'],ev[:60])
