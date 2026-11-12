"""Sweeps one enemy object round the turtle in the original and notes where a
touch hurts him, then checks the box rule read from the code (6:$9AD3,
6:$9B11) against every trial.  python3 -I touch_sweep.py -> touch_emu.json"""
import sys, json
sys.path.insert(0,'/home/claude/work_agent_enemies')
from common import *
from lv import b
def box_half(kind,an):
    if kind>=0x80: i=b(6,(0x895B if an>=0x80 else 0x89B5)+an)
    else: i=b(6,(0x8835 if an>=0x80 else 0x8935)+an)
    return b(6,0x8A43+i*2),b(6,0x8A44+i*2)
CENTRED=lambda k: 0x23<=k<0x27 or k==0x89
def overlap(tk_anim,t540,tx,ty,kind,anim,ex,ey):
    hw,hh=box_half(0,tk_anim); low=8 if t540&2 else 0
    tl,tr,tt,tb=tx-hw,tx+hw,ty+low-hh,ty+low+hh
    ew,eh=box_half(kind,anim)
    el,er,et=ex-ew,ex+ew,ey-eh
    eb=ey+eh if CENTRED(kind) else ey-2
    okx=(er>=tl) if ex<tx else (el<tr)
    oky=(eb>=tt) if ey<ty else (et<tb)
    return okx and oky
e=place(0,140,176,settle=80,keep=False); n=e.nes
slot=5
assert not (n[0x450]&4)
base=n.save()
KINDS=[(0x98,0x90),(0x98,0x93),(0x98,0x97),(0x99,0x99),(0x81,0x02),(0x8D,0x01),(0x86,0x06),(0x86,0x07),(0x49,0x53),(0x49,0x50),(0x4A,0x37),(0x91,0x80),(0x92,0x85),(0x93,0x89),(0x94,0x1E),(0x95,0x20),(0x96,0x21),(0xAA,0xCB)]
STATES={'stand':lambda f:0,'crouch':lambda f:D,'jump':lambda f:A if f<30 else 0,'walk':lambda f:R}
def trial(kind,anim,state,dx,dy,frames=44,start=12):
    if state!='jump': frames=24
    n.load(base)
    log=[]; hit=None
    for f in range(frames):
        n[0x77]=0x80
        for X in range(5,16):
            if X!=slot: n[0x440+X]=0
        if f<start:
            n[0x440+slot]=0
        else:
            tx=n[0x480]; ty=n[0x460]
            n[0x440+slot]=kind; n[0x570+slot]=anim; n[0x450+slot]=0xC2; n[0x510+slot]=1; n[0x520+slot]=0
            n[0x480+slot]=(tx+dx)&255; n[0x460+slot]=(ty+dy)&255; n[0x490+slot]=0; n[0x470+slot]=0
            for a in (0x4E0,0x4F0,0x4B0,0x4C0): n[a+slot]=0
            n[0x560+slot]=50; n[0x500+slot]=0; n[0x420+slot]=9
        e.run(1,STATES[state](f))
        if f>=start and n[0x1E]%2==0:
            # the touch pass ran this frame, with these numbers
            log.append([tx,ty,n[0x570],n[0x540]&0x7F,n[0x570+slot] if n[0x440+slot]==kind else anim])
        if f>=start and n[0x77]<0x80:
            hit=dict(f=f,lost=0x80-n[0x77],side=n[0x540]>>7,vx=(n[0x4E0]<<8|n[0x4F0]),vy=(n[0x4B0]<<8|n[0x4C0]),safe=n[0x500],tflags=n[0x450],after=n[0x440+slot],estate=[n[0x4E0+slot],n[0x510+slot],n[0x530+slot]])
            break
    return hit,log
out=[]; bad=0; total=0
for kind,anim in KINDS:
    for state in STATES:
        ew,eh=box_half(kind,anim)
        tw=5; th={'stand':16,'crouch':11,'jump':6,'walk':16}[state]; low=8 if state=='crouch' else 0
        midy=low+eh//2
        # edges the rule predicts, three pixels to each side of each
        ex=[-(ew+tw)+d for d in range(-3,4)]+[(ew+tw)+d for d in range(-3,4)]
        ey=[low-th+2+d for d in range(-3,4)]+[low+th+eh+d for d in range(-3,4)]
        trials=[(dx,midy) for dx in ex]+[(0,dy) for dy in ey]+[(0,midy),(-ew-tw-9,midy),(ew+tw+9,midy),(-ew-tw+1,low-th+3),(ew+tw-2,low+th+eh-2)]
        nh=0
        for dx,dy in trials:
            hit,log=trial(kind,anim,state,dx,dy)
            pred=None
            for i,(tx,ty,ta,t54,ea) in enumerate(log):
                if overlap(ta,t54,tx,ty,kind,ea,tx+dx,ty+dy): pred=i; break
            total+=1; nh+= hit is not None
            ok=(hit is None)==(pred is None)
            if not ok:
                bad+=1
                if bad<12: print('MISMATCH kind %02X anim %02X %s dx %d dy %d hit %s pred %s log %s'%(kind,anim,state,dx,dy,hit,pred,log[:3]))
            out.append(dict(kind=kind,anim=anim,state=state,dx=dx,dy=dy,hit=hit,log=log))
        hx=[t['dx'] for t in out[-len(trials):] if t['hit'] and t['dy']==trials[0][1]]
        hy=[t['dy'] for t in out[-len(trials):] if t['hit'] and t['dx']==0]
        sys.stdout.flush()
        print('%02X/%02X %-6s box %s  hurt across %s  down %s  hits %d'%(kind,anim,state,(ew,eh),(min(hx),max(hx)) if hx else None,(min(hy),max(hy)) if hy else None,nh))
print('trials',total,'rule wrong',bad)
json.dump(out,open('/home/claude/work_agent_enemies/touch_emu.json','w'))
