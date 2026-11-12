import sys,json; sys.path.insert(0,'/home/claude/work')
from cap import *
from probe import at2
R,L,A,B,U,D=NES_INPUT_RIGHT,NES_INPUT_LEFT,NES_INPUT_A,NES_INPUT_B,NES_INPUT_UP,NES_INPUT_DOWN
# find a state with a soldier (kind 98) alive in a room
slot=None
def place(ar,x,y,settle=60):
    e=E(); n=e.nes; n.load(base_state())
    W,H=room_dims(0,ar)
    sx=max(0,min(x-128,W*256-256))
    n[0x48]=0; n[0x5D]=ar; n[0x5C]=1
    n[0x480]=x-sx; n[0x460]=y-20; n[0x4F]=sx&255; n[0x50]=sx>>8; n[0x51]=0; n[0x52]=0
    for f in range(settle):
        n[0x500]=60; n[0x77]=0x80; e.run(1)
    return e
best=None
for ar in range(6):
    W,H=room_dims(0,ar)
    for x in range(136,W*256-120,64):
        e=place(ar,x,176); n=e.nes
        for X in range(5,16):
            if n[0x440+X]==0x98 and n[0x560+X]>0: slot=X
        if slot: break
    if slot: break
f=0
print('area',ar,'x',x)
print('slot',slot,'frame',f,'turtle',n[0x480],n[0x460],'enemy',n[0x480+slot],n[0x460+slot],'hp',n[0x560+slot],'anim',n[0x570+slot],'flags',hex(n[0x450+slot]))
base=n.save()
def trial(dx,dy,btn,face_left=False):
    n.load(base)
    for X in range(5,16):
        if X!=slot: n[0x440+X]=0
    tx=120; ty=n[0x460]
    hp0=40
    hit=False
    for f in range(40):
        n[0x480]=tx; n[0x490]=0; n[0x4E0]=0; n[0x4F0]=0
        n[0x450]=(n[0x450]&0xFE)|(1 if face_left else 0)
        n[0x500]=60; n[0x77]=0x80
        n[0x480+slot]=(tx+dx)&255; n[0x460+slot]=ty+dy; n[0x4E0+slot]=0;n[0x4F0+slot]=0;n[0x4B0+slot]=0;n[0x4C0+slot]=0
        n[0x560+slot]=hp0; n[0x500+slot]=0; n[0x450+slot]&=0xFB
        e.run(1,((btn&~B) if f>=6 else 0)|(B if 10<=f<14 and (btn&B) else 0))
        if n[0x440+slot]!=0x98 or n[0x560+slot]!=hp0 or (n[0x450+slot]&4): hit=True; break
    return hit
res={}
for name,btn in (('forward',B),('up',B|U),('down',B|D)):
    for dy in (0,-16,-32,16):
        row=[dx for dx in range(-48,66,2) if trial(dx,dy,btn)]
        res['%s dy%d'%(name,dy)]=row
        print(name,'dy',dy,'hits at dx',(row[0],row[-1]) if row else None, 'n',len(row))
json.dump(res,open('hit_emu.json','w'))
