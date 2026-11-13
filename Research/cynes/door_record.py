"""Goes through every door of world 1 in the original and records what comes up.
usage: python3 -I rec_doors.py  -> rec_doors.json"""
import sys, json, pickle
sys.path.insert(0,'.')
from common import *
from rec import snap
from lv import b,w
def door_list(p):
    L=[]
    while b(7,p)!=0xFF and len(L)<12:
        L.append([b(7,p+i) for i in range(11)]); p+=11
    return L
OW=door_list(w(7,w(7,0xE84F+12)))
U_,D_=NES_INPUT_UP,NES_INPUT_DOWN
LAST_CAM=[0,0]
def overworld_state():
    """the overworld of world 1, turtle standing free (before the first manhole)"""
    e=E(); e.run(200)
    for k in range(3): e.run(5,NES_INPUT_START); e.run(90)
    e.run(120)
    return e
def row(n,btn):
    return dict(c=n[0x1E],b=btn,cam=n[0x4F]|n[0x50]<<8,camy=n[0x51]|n[0x52]<<8,inside=n[0x5C],area=n[0x5D],
        t=[n[0x480],n[0x490],n[0x460],n[0x470],n[0x450],n[0x510],n[0x570],n[0x540],n[0x500]],o=snap(n),hold=n[0x5E],e=n[0x77],r=n[0x45],
        w=[],sc=0,lineup=n[0x604],clock=n[0x9D],pts=n[0xC5])
def try_door(index,way,dx,dy):
    d=OW[index]
    e=overworld_state(); n=e.nes
    sx=(d[0]%2)*256; sy=(d[0]//2)*256
    X=sx+d[1]+dx; Y=sy+d[2]+dy
    camx=max(0,min(X-128,256)); camy=max(0,min(Y-120,512-240))
    n[0x4F]=camx&255; n[0x50]=camx>>8; n[0x51]=camy&255; n[0x52]=camy>>8
    n[0x480]=X-camx; n[0x460]=Y-camy
    # the Start screen and back: the map is drawn again around the new place
    e.run(5,NES_INPUT_START); e.run(100); e.run(5,NES_INPUT_START); e.run(100)
    if (n[0x4F]|n[0x50]<<8)!=camx or n[0x480]!=X-camx or n[0x5C]!=0: return None,None
    for f in range(80):
        for s in range(5,16): n[0x440+s]=0
        cam_before=(n[0x4F]|n[0x50]<<8,n[0x51]|n[0x52]<<8)
        e.run(1,way)
        if n[0x5C]==1:
            LAST_CAM[:]=cam_before
            return e,f
    return None,None
def record_door(index):
    for way,dx,dy in ((L,14,0),(R,-14,0),(U_,0,14),(D_,0,-14),(L,10,0),(R,-10,0),(U_,0,10),(D_,0,-10)):
        e,f=try_door(index,way,dx,dy)
        if e: break
    if not e: return None
    n=e.nes; rows=[]; cam_before=list(LAST_CAM)
    for f in range(330):
        n[0x77]=0x80
        n[0x450]|=4; n[0x500]=30
        rows.append(None); e.run(1,0); rows[-1]=row(n,0)
    # now leave by the door he arrived at: Up
    out=[]
    for f in range(400):
        n[0x77]=0x80; n[0x450]|=4; n[0x500]=30
        for s in range(5,16): n[0x440+s]=0
        e.run(1,L if 60<=f<66 else U_)
        if n[0x5C]==0: break
    left=f
    for f in range(120):
        e.run(1,0); out.append(row(n,0))
    return dict(door=index,record=OW[index],way=way,rows=rows,left_after=left,out=out,cam_before=cam_before,left_over=None)
if __name__=='__main__':
    data={}
    for i in range(len(OW)):
        r=record_door(i)
        if r is None: print(i,'not entered'); continue
        data['door%d'%i]=r
        rows=r['rows']
        x=rows[-1]; o=r['out'][-1]
        print(i,r['record'],'area',x['area'],'turtle screen',x['t'][0],x['t'][2],'cam',x['cam'],x['camy'],'state',x['t'][5],'kinds',sorted({'%02X'%v[0] for v in x['o'].values()}),'| out after',r['left_after'],'inside',o['inside'],'turtle',o['t'][0],o['t'][2],'cam',o['cam'],o['camy'])
    json.dump(data,open('./rec_doors.json','w'))
