import sys,json; sys.path.insert(0,'/home/claude/work')
from cap import *
from probe import at2, clear
R,L,A,B,U,D=NES_INPUT_RIGHT,NES_INPUT_LEFT,NES_INPUT_A,NES_INPUT_B,NES_INPUT_UP,NES_INPUT_DOWN
def script(kind,f):
    # kind 0: run right with a jump every 96 frames; 1: run right, long jumps; 2: left
    if kind==0: return R|(A if f%96<22 else 0)
    if kind==1: return R|(A if f%64<30 else 0)
    if kind==2: return L|(A if f%96<22 else 0)
out={}
for ar in range(6):
    W,H=room_dims(0,ar)
    for kind,screen in ((0,0),(1,0),(2,W-1)):
        spot=stand_spot(0,ar,screen)
        if spot is None: continue
        e=at2(ar,spot[0],spot[1]); n=e.nes
        tr=[]; start=((n[0x4F]|n[0x50]<<8)+n[0x480]+n[0x490]/256.0, n[0x460]+20+n[0x470]/256.0)
        for f in range(1000):
            n[0x500]=60; n[0x77]=0x80; clear(n)
            e.run(1,script(kind,f))
            sx=n[0x4F]|n[0x50]<<8; sy=n[0x51]|n[0x52]<<8
            tr.append((sx+n[0x480]+n[0x490]/256.0,sy+n[0x460]+20+n[0x470]/256.0,n[0x5D],n[0x5C],sx,n[0x5E]))
            if n[0x5D]!=ar or n[0x5C]!=1: break
        out['%d_%d'%(ar,kind)]=dict(area=ar,kind=kind,spot=spot,start=start,trace=tr)
        print(ar,kind,'start',start,'frames',len(tr),'end',[round(v) for v in tr[-1]])
json.dump(out,open('/home/claude/work/play_emu.json','w'))
