import sys; sys.path.insert(0,'/home/claude/work')
from cap import *
R,L,A=NES_INPUT_RIGHT,NES_INPUT_LEFT,NES_INPUT_A
_cache={}
def at(ar,x,y,settle=0):
    """turtle in world 1 area ar with feet at (x,y), camera as the game would have it"""
    key=ar
    if key not in _cache:
        e,spot,sc=goto_room(0,ar,0); _cache[key]=e.nes.save()
    e=E(); n=e.nes; n.load(_cache[key])
    W,H=room_dims(0,ar)
    sx=max(0,min(x-128,W*256-256))
    n[0x480]=x-sx; n[0x490]=0; n[0x460]=y-20; n[0x470]=0; n[0x4F]=sx&255; n[0x50]=sx>>8
    for a in (0x4B0,0x4C0,0x4E0,0x4F0): n[a]=0
    return e
def pos(n):
    return ((n[0x4F]|n[0x50]<<8)+n[0x480], n[0x460]+20)
def run(e,frames,ctl=0):
    n=e.nes; tr=[]
    for f in range(frames):
        n[0x500]=60; n[0x77]=0x80
        e.run(1,ctl(f) if callable(ctl) else ctl); tr.append(pos(n))
    return tr
def clear(n):
    for X in range(5,16): n[0x440+X]=0
def at2(ar,x,y):
    """proper placement: the room is set up around the spot, enemies removed while settling"""
    e=E(); n=e.nes; n.load(base_state())
    W,H=room_dims(0,ar)
    sx=max(0,min(x-128,W*256-256))
    n[0x48]=0; n[0x5D]=ar; n[0x5C]=1
    n[0x480]=x-sx; n[0x460]=y-20; n[0x4F]=sx&255; n[0x50]=sx>>8; n[0x51]=0; n[0x52]=0
    for f in range(120):
        n[0x500]=60; n[0x77]=0x80; clear(n); e.run(1)
    return e
def run2(e,frames,ctl=0):
    n=e.nes; tr=[]
    for f in range(frames):
        n[0x500]=60; n[0x77]=0x80; clear(n)
        e.run(1,ctl(f) if callable(ctl) else ctl); tr.append((pos(n)[0]+n[0x490]/256.0,pos(n)[1]+n[0x470]/256.0))
    return tr
