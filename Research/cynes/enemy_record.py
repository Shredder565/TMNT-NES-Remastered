"""Records the original frame by frame for the enemy side-by-side check
(Research/enemy_routines.md). Needs the cynes emulator, the player's own
ROM, and the helper scripts cap.py / probe.py / emu.py of this research
(not in the project; paths below are the research machine's).

    python3 -I enemy_record.py 98      -> rec_98.json

The two parts were separate files (common.py, rec.py); they are joined
here, so drop the "from common import *" line if you run it as one file.
"""
import sys; sys.path.insert(0,'/home/claude/work'); sys.path.insert(0,'/home/claude/work_agent_enemies')
import os; os.chdir('/home/claude/work')
from cap import *
from probe import at2, clear
R,L,A,B,U,D=NES_INPUT_RIGHT,NES_INPUT_LEFT,NES_INPUT_A,NES_INPUT_B,NES_INPUT_UP,NES_INPUT_DOWN
def place(ar,x,y,settle=120,keep=True):
    """turtle's feet at room (x,y) in world-1 area ar; enemies kept alive"""
import sys; sys.path.insert(0,'/home/claude/work'); sys.path.insert(0,'/home/claude/work_agent_enemies')
import os; os.chdir('/home/claude/work')
from cap import *
from probe import at2, clear
R,L,A,B,U,D=NES_INPUT_RIGHT,NES_INPUT_LEFT,NES_INPUT_A,NES_INPUT_B,NES_INPUT_UP,NES_INPUT_DOWN
def place(ar,x,y,settle=120,keep=True):
    """turtle's feet at room (x,y) in world-1 area ar; enemies kept alive"""
    e=E(); n=e.nes; n.load(base_state())
    W,H=room_dims(0,ar)
    sx=max(0,min(x-128,W*256-256))
    n[0x48]=0; n[0x5D]=ar; n[0x5C]=1
    sy=(y-1)//192*192 if H>1 else 0
    n[0x480]=x-sx; n[0x460]=y-20-sy; n[0x4F]=sx&255; n[0x50]=sx>>8; n[0x51]=sy&255; n[0x52]=sy>>8
    for f in range(settle):
        n[0x500]=60; n[0x77]=0x80
        if not keep: clear(n)
        e.run(1)
    return e
def objs(n):
    out={}
    for X in range(16):
        k=n[0x440+X]
        if k==0: continue
        out[X]=dict(k=k,x=n[0x480+X],xf=n[0x490+X],y=n[0x460+X],yf=n[0x470+X],vx=n[0x4E0+X],vxf=n[0x4F0+X],vy=n[0x4B0+X],vyf=n[0x4C0+X],pic=n[0x400+X],fl=n[0x450+X],hp=n[0x560+X],an=n[0x570+X],st=n[0x510+X],s2=n[0x520+X],t=n[0x550+X],safe=n[0x500+X],a1=n[0x410+X],a2=n[0x420+X],t6=n[0x630+X])
    return out
def fmt(o):
    return '%02X x%3d.%02X y%3d.%02X v%02X.%02X/%02X.%02X an%02X pic%02X fl%02X st%d/%d a%02X/%02X t%02X hp%d'%(o['k'],o['x'],o['xf'],o['y'],o['yf'],o['vx'],o['vxf'],o['vy'],o['vyf'],o['an'],o['pic'],o['fl'],o['st'],o['s2'],o['a1'],o['a2'],o['t6'],o['hp'])

"""Records the original (cynes) frame by frame for enemy comparisons.
usage: python3 -I rec.py <set>   -> writes rec_<set>.json in the work folder"""
import sys, json
sys.path.insert(0,'/home/claude/work_agent_enemies')
from common import *
OUT='/home/claude/work_agent_enemies/'
def snap(n):
    o={}
    for X in range(1,16):
        k=n[0x440+X]
        if k==0: continue
        o[X]=[k,n[0x480+X],n[0x490+X],n[0x460+X],n[0x470+X],
              (n[0x4E0+X]<<8|n[0x4F0+X]),(n[0x4B0+X]<<8|n[0x4C0+X]),
              n[0x570+X],n[0x400+X],n[0x450+X],n[0x510+X],n[0x520+X],n[0x410+X],n[0x420+X],n[0x630+X],n[0x560+X],n[0x500+X],n[0x550+X],n[0x530+X],n[0x540+X],n[0x640+X],n[0x580+X]]
    return o
def record(area,x,y,script,frames,poke=None,settle=1,safe=True):
    e=place(area,x,y,settle=settle); n=e.nes
    rows=[]
    for f in range(frames):
        if safe:
            n[0x450]|=4; n[0x500]=60
            n[0x77]=0x80
        elif f<70:
            n[0x450]|=4; n[0x500]=30   # safe while the room comes up
        elif f==70:
            n[0x450]&=0xFB; n[0x500]=0
        if poke: poke(f,n)
        btn=script(f)
        e.run(1,btn)
        cam=n[0x4F]|n[0x50]<<8; camy=n[0x51]|n[0x52]<<8
        rows.append(dict(c=n[0x1E],b=btn,cam=cam,camy=camy,t=[n[0x480],n[0x490],n[0x460],n[0x470],n[0x450],n[0x510],n[0x570],n[0x540],n[0x500]],w=[[n[0x440+X],n[0x480+X],n[0x460+X],n[0x570+X]] for X in range(1,5) if n[0x440+X] or n[0x570+X]],o=snap(n),hold=n[0x5E],e=n[0x77],sc=(n[0x40]-256 if n[0x40]>127 else n[0x40]),r=n[0x45]))
    return dict(area=area,start=[x,y],rows=rows,hits=sorted(getattr(poke,'frames',[])),hit_kind=getattr(poke,'kind',0))
def still(f): return 0
def hit(slot_kind,frames_at,dmg=7):
    """pretend the weapon landed on every object of that kind at those frames"""
    def poke(f,n):
        if f in frames_at:
            for X in range(5,16):
                if n[0x440+X]==slot_kind and not (n[0x450+X]&4):
                    n[0x450+X]|=4; n[0x500+X]=0x18
                    n[0x560+X]=max(n[0x560+X]-dmg,1)
    poke.frames=frames_at; poke.kind=slot_kind
    return poke
SETS={}
def walk_lr(period,jump=0):
    def s(f):
        b=R if (f//period)%2==0 else L
        if jump and f%jump<20: b|=A
        return b
    return s
def jumps(f): return A if f%70<24 else 0
SETS['98']=lambda: {
 'still_392': record(2,392,176,still,700),
 'still_300': record(2,300,176,still,700),
 'still_600': record(2,600,176,still,700),
 'still_top': record(2,420,96,still,700),
 'walk_right': record(2,150,176,lambda f:R if f>40 else 0,900),
 'walk_left': record(2,900,176,lambda f:L if f>40 else 0,900),
 'pace': record(2,392,176,walk_lr(90),900),
 'pace_jump': record(2,392,176,walk_lr(100,jump=64),900),
 'jump': record(2,392,176,jumps,700),
 'hit': record(2,392,176,still,700,poke=hit(0x98,{150,260,400})),
 'hit_walk': record(2,300,176,walk_lr(120),800,poke=hit(0x98,{100,230,231,380,520})),
 'a0_walk': record(0,560,176,lambda f:R if f>30 else 0,900),
 'a1_walk': record(1,120,176,lambda f:R if f>30 else 0,700),
}
SETS['w1a']=lambda: {
 'a0_still_140': record(0,140,176,still,600),
 'a0_right': record(0,60,176,lambda f:R if f>40 else 0,1100),
 'a0_left': record(0,940,176,lambda f:L if f>40 else 0,1100),
 'a0_pace': record(0,400,176,walk_lr(150),1000),
 'a0_pace_jump': record(0,620,176,walk_lr(110,jump=70),1000),
 'a1_right': record(1,60,176,lambda f:R if f>40 else 0,900),
 'a1_left': record(1,500,176,lambda f:L if f>40 else 0,700),
 'a1_pace': record(1,300,176,walk_lr(130),900),
 'a2_right': record(2,60,176,lambda f:R if f>40 else 0,900),
 'a2_left': record(2,960,176,lambda f:L if f>40 else 0,900),
 'a2_pace': record(2,200,176,walk_lr(100,jump=90),900),
}
def spot(ar,screen):
    s=stand_spot(0,ar,screen); return s
SETS['w1b']=lambda: {
 'a3_still': record(3,spot(3,0)[0],spot(3,0)[1],still,700),
 'a3_right': record(3,spot(3,0)[0],spot(3,0)[1],lambda f:R if f>40 else 0,1000),
 'a3_left': record(3,spot(3,2)[0],spot(3,2)[1],lambda f:L if f>40 else 0,1000),
 'a3_pace': record(3,spot(3,1)[0],spot(3,1)[1],walk_lr(120,jump=80),1000),
 'a4_still': record(4,spot(4,0)[0],spot(4,0)[1],still,700),
 'a4_right': record(4,spot(4,0)[0],spot(4,0)[1],lambda f:R if f>40 else 0,900),
 'a4_left': record(4,spot(4,1)[0],spot(4,1)[1],lambda f:L if f>40 else 0,900),
 'a4_pace': record(4,spot(4,1)[0],spot(4,1)[1],walk_lr(100,jump=75),1000),
}
SETS['w1c']=lambda: {
 'a5_s0': record(5,spot(5,0)[0],spot(5,0)[1],still,600),
 'a5_s1': record(5,spot(5,1)[0],spot(5,1)[1],still,700),
 'a5_s1_left': record(5,spot(5,1)[0],spot(5,1)[1],lambda f:L if f>40 else 0,900),
 'a5_s1_pace': record(5,spot(5,1)[0],spot(5,1)[1],walk_lr(80,jump=90),900),
 'a5_s0_right': record(5,spot(5,0)[0],spot(5,0)[1],lambda f:R if f>40 else 0,900),
 'a5_hit': record(5,spot(5,1)[0],spot(5,1)[1],walk_lr(70),900,poke=hit(0x92,{120,300,480,700})),
}
SETS['w1d']=lambda: {
 'a4_hit': record(4,spot(4,1)[0],spot(4,1)[1],walk_lr(100),1000,poke=hit(0x91,{150,330,331,500,720})),
 'a3_hit': record(3,spot(3,1)[0],spot(3,1)[1],walk_lr(90),1000,poke=hit(0x49,{150,330,500,720})),
 'a4_right2': record(4,300,spot(4,1)[1],lambda f:R if f>40 else 0,900),
 'a3_right2': record(3,330,spot(3,1)[1],lambda f:R if f>40 else 0,900),
}
SETS['w1e']=lambda: {
 'a5_s2': record(5,spot(5,2)[0],spot(5,2)[1],still,900),
 'a5_s3': record(5,spot(5,3)[0],spot(5,3)[1],still,900),
 'a5_s2_right': record(5,spot(5,2)[0],spot(5,2)[1],lambda f:R if f>40 else 0,900),
 'a5_s3_left': record(5,spot(5,3)[0],spot(5,3)[1],lambda f:L if f>40 else 0,900),
 'a5_s2_pace': record(5,spot(5,2)[0],spot(5,2)[1],walk_lr(90,jump=100),1200),
 'a5_s3_pace': record(5,spot(5,3)[0],spot(5,3)[1],walk_lr(120),1200),
 'a5_s3_hit': record(5,spot(5,3)[0],spot(5,3)[1],walk_lr(100),1000,poke=hit(0x94,{120,300,480,700})),
 'a5_s1_long': record(5,spot(5,1)[0]-90,spot(5,1)[1],still,2400),
}
SETS['aa']=lambda: {
 'a3_r330': record(3,330,176,lambda f:R if f>40 else 0,700),
 'a3_r300': record(3,300,176,lambda f:R if f>80 else 0,700),
 'a3_still480': record(3,480,176,still,600),
 'a3_still400': record(3,400,176,still,600),
 'a3_left': record(3,700,176,lambda f:L if f>40 else 0,900),
 'a3_left_jump': record(3,700,176,lambda f:(L if f>40 else 0)|(A if f%60<25 else 0),900),
 'a3_pace': record(3,560,176,walk_lr(60,jump=90),900),
 'a3_hit': record(3,480,176,walk_lr(80),700,poke=hit(0xAA,{100,200,300})),
}
def run_jump(way,start,every,hold):
    return lambda f: (way if f>start else 0)|(A if f>start and f%every<hold else 0)
SETS['aa2']=lambda: {
 'l380': record(3,380,176,lambda f:L if f>40 else 0,500),
 'l380j': record(3,380,176,run_jump(L,40,50,22),500),
 'l340j': record(3,340,176,run_jump(L,60,44,30),500),
 'r420': record(3,420,176,lambda f:R if f>40 else 0,500),
 'r420j': record(3,420,176,run_jump(R,40,50,22),500),
 'r440j': record(3,440,176,run_jump(R,70,44,30),500),
 'l700j': record(3,700,176,run_jump(L,40,48,26),700),
 'l680j': record(3,680,176,run_jump(L,50,40,30),700),
}
def seq(*parts):
    """parts: (frames, buttons) one after another, then nothing"""
    def s(f):
        for n_,b_ in parts:
            if f<n_: return b_
            f-=n_
        return 0
    return s
def tap(b_,every,hold,base=0,start=70):
    return lambda f: 0 if f<start else base|(b_ if (f-start)%every<hold else 0)
SETS['live']=lambda: {
 'a0_stand': record(0,180,176,still,500,safe=False),
 'a0_right': record(0,180,176,lambda f:R if f>=70 else 0,900,safe=False),
 'a0_right_swing': record(0,180,176,tap(B,30,4,base=R),900,safe=False),
 'a0_right_jump': record(0,180,176,tap(A,70,30,base=R),900,safe=False),
 'a2_stand': record(2,392,176,still,600,safe=False),
 'a2_swing': record(2,392,176,tap(B,26,4),700,safe=False),
 'a2_left_swing': record(2,600,176,tap(B,34,4,base=L),800,safe=False),
 'a3_right': record(3,136,176,tap(A,90,34,base=R),900,safe=False),
 'a4_right': record(4,136,144,tap(B,40,4,base=R),800,safe=False),
 'a5_left': record(5,392,368,tap(B,36,4,base=L),800,safe=False),
}
def mix(start=70):
    def s(f):
        if f<start: return 0
        g=(f-start)%160
        if g<50: return R|(B if g%25<4 else 0)
        if g<70: return D|(B if 54<=g<58 else 0)
        if g<110: return L|(A if g<90 else 0)|(B if 80<=g<84 else 0)
        return U|(B if g%25<4 else 0)
    return s
SETS['live2']=lambda: {
 'a0_left': record(0,900,176,tap(B,32,4,base=L),900,safe=False),
 'a0_mix': record(0,300,176,mix(),900,safe=False),
 'a1_right': record(1,60,176,tap(B,36,4,base=R),600,safe=False),
 'a2_mix': record(2,392,176,mix(),900,safe=False),
 'a2_right_jump': record(2,150,176,tap(A,60,28,base=R),800,safe=False),
 'a3_left': record(3,632,176,tap(B,30,4,base=L),800,safe=False),
 'a3_mix': record(3,400,176,mix(),800,safe=False),
 'a4_left': record(4,392,160,tap(A,80,30,base=L),700,safe=False),
 'a5_top': record(5,136,160,tap(B,40,4,base=R),800,safe=False),
 'a5_mix': record(5,392,368,mix(),800,safe=False),
}
if __name__=='__main__':
    name=sys.argv[1]
    data=SETS[name]()
    json.dump(data,open(OUT+'rec_%s.json'%name,'w'))
    for k,v in data.items():
        kinds=sorted({'%02X'%o[0] for r in v['rows'] for o in r['o'].values()})
        print(k,len(v['rows']),'kinds seen',kinds,'end turtle',v['rows'][-1]['cam']+v['rows'][-1]['t'][0],v['rows'][-1]['t'][2]+20)
