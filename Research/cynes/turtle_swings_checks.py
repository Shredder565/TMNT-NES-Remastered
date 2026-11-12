"""Emulator recording behind Research/turtles.md: each of the four turtles,
chosen on the Start screen, put through the same buttons in the first sewer.
Needs `cynes` and the helper scripts of the agent brief (emu.py, probe.py).
Run with: python3 -I turtle_swings_checks.py
"""
import sys,os,pickle; sys.path.insert(0,"/home/claude/work"); 
from emu import *
S,A,B,U,D,L,R=NES_INPUT_START,NES_INPUT_A,NES_INPUT_B,NES_INPUT_UP,NES_INPUT_DOWN,NES_INPUT_LEFT,NES_INPUT_RIGHT
W='./'
def oam(n): return [(n[0x200+i],n[0x201+i],n[0x202+i],n[0x203+i]) for i in range(0,256,4) if n[0x200+i]<0xEF]
def pal(n): return bytes(n[0x59F+k] for k in range(32))
def room_turtle(t,ar=0,x=300,y=176):
    os.chdir('/home/claude/work')
    from probe import at2, clear
    e=at2(ar,x,y); n=e.nes; os.chdir(W)
    if t:
        e.run(1,S); e.run(30)
        for k in range(t): e.run(2,D); e.run(10)
        e.run(1,S)
        for f in range(70): clear(n); e.run(1)
    assert n[0x67]==t, n[0x67]
    return e
def rec(e,plan,keep_enemies=False,safe=True):
    n=e.nes; rows=[]
    for b in plan:
        if safe: n[0x500]=60
        n[0x77+n[0x67]]=0x80
        if not keep_enemies:
            for X in range(5,16): n[0x440+X]=0
        e.run(1,b)
        cx=n[0x4F]|n[0x50]<<8
        rows.append(dict(btn=b,fc=n[0x1E],cx=cx,x=n[0x480],y=n[0x460],pic=n[0x400],an=n[0x570],fl=n[0x450],st=n[0x510],
            w=dict(k=n[0x441],pic=n[0x401],x=n[0x481],y=n[0x461],an=n[0x571],fl=n[0x451]),
            oam=[o for o in oam(n) if o[1] not in (15,170)],pal=list(pal(n)),p27=n[0x27],p28=n[0x28]))
    return rows
PLAN=[0]*20+[R]*60+[0]*20+[B]*2+[0]*40+[U|B]*2+[0]*40+[D]*20+[D|B]*2+[D]*40+[0]*10+[A]*30+[0]*50+[A]*4+[B]*2+[0]*60+[L]*30+[0]*10+[L|B]*2+[L]*30+[0]*20
if __name__=='__main__':
    for t in range(4):
        e=room_turtle(t); rows=rec(e,PLAN)
        pickle.dump(rows,open(W+'turtle_%d.pkl'%t,'wb'))
        seq=[]
        for r in rows:
            key=(r['an'],r['pic'],r['w']['k'],r['w']['an'],r['w']['pic'])
            if not seq or seq[-1][0]!=key: seq.append([key,1])
            else: seq[-1][1]+=1
        print('turtle',t,'sprite colours',' '.join('%02X'%v for v in rows[0]['pal'][16:24]),'pages',rows[0]['p27'],rows[0]['p28'])
        print('  (anim,pic,weapon kind,weapon anim,weapon pic) x frames:',' '.join('%02X/%d/%02X/%02X/%d x%d'%(k[0],k[1],k[2],k[3],k[4],c) for k,c in seq))
