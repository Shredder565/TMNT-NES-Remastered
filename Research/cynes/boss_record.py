"""Records the two boss fights of world 1 in the original. -> rec_boss.json"""
import sys, json
sys.path.insert(0,'.')
from common import *
from rec import record, tap, mix, seq
def low(kind,at,value=7):
    def poke(f,n):
        if f==at:
            for X in range(5,16):
                if n[0x440+X]==kind: n[0x560+X]=value
    poke.frames=[at]; poke.kind=kind; poke.value=value
    return poke
def then(first,frames,after):
    return lambda f: first if f<frames else after(f)
REFILL=256
def run(area,x,y,script,frames,poke=None):
    """as rec.record, and: his energy is filled up every 256th frame; in the
    second room everything on the screen is taken away on the frame the screen stops"""
    seen={}
    def both(f,n):
        if f%REFILL==0 and f>0: n[0x77]=0x80
        if area==1 and n[0x5E]==1 and 'clear' not in seen:
            seen['clear']=f
            for X in range(5,16):
                for base in range(0x400,0x650,0x10): n[base+X]=0
        if poke: poke(f,n)
    r=record(area,x,y,lambda f: 0 if f<70 else script(f),frames,poke=both,safe=False)
    r['refill']=REFILL
    if 'clear' in seen: r['clear_at']=seen['clear']
    if poke: r['low']=[poke.frames[0],poke.value]
    return r
def pace(period,start,extra=lambda f:0):
    return lambda f: 0 if f<start else ((R if ((f-start)//period)%2==0 else L)|extra(f))
swing=lambda every: (lambda f: B if f%every<4 else 0)
jump_swing=lambda f: (A if f%64<26 else 0)|(B if f%40<4 else 0)
SETS={
 'b_stand': lambda: run(1,560,176,then(R,190,lambda f:0),1000),
 'b_swing': lambda: run(1,560,176,then(R,190,swing(26)),1000),
 'b_left_swing': lambda: run(1,560,176,then(R,190,lambda f:(L if f%200<60 else R if f%200<120 else 0)|(B if f%26<4 else 0)),1100),
 'b_jump': lambda: run(1,560,176,then(R,190,pace(90,190,jump_swing)),1200),
 'b_mix': lambda: run(1,560,176,then(R,190,mix(190)),1100),
 'b_beaten': lambda: run(1,560,176,then(R,190,lambda f:(B if f%22<4 else 0)|(L if 700<f<760 else R if f>=900 else 0)),1300,poke=low(0x70,400)),
 'r_stand': lambda: run(5,136,160,then(L,150,lambda f:0),1000),
 'r_swing': lambda: run(5,136,160,then(L,150,swing(26)),1000),
 'r_pace_swing': lambda: run(5,136,160,then(L,150,pace(70,150,swing(24))),1100),
 'r_jump': lambda: run(5,136,160,then(L,150,pace(90,150,jump_swing)),1200),
 'r_mix': lambda: run(5,136,160,then(L,150,mix(150)),1100),
 'r_beaten': lambda: run(5,136,160,then(L,150,lambda f:(B if f%22<4 else 0)|(R if f%120<50 else 0)),900,poke=low(0x71,260)),
}
if __name__=='__main__':
    names=sys.argv[1:] or list(SETS)
    try: data=json.load(open('./rec_boss.json'))
    except Exception: data={}
    for name in names:
        v=SETS[name](); data[name]=v
        rows=v['rows']
        kinds=sorted({'%d:%02X'%(int(s),o[0]) for r in rows for s,o in r['o'].items() if int(s)>=5})
        holds=[(f,rows[f]['hold']) for f in range(1,len(rows)) if rows[f]['hold']!=rows[f-1]['hold']]
        boss=[(f,o[15]) for f,r in enumerate(rows) for s,o in r['o'].items() if o[0] in (0x70,0x71)]
        hp=[]; 
        for f,h in boss:
            if not hp or hp[-1][1]!=h: hp.append((f,h))
        print(name,len(rows),'slots',kinds,'hold',holds,'boss hp',hp[:14],'energy end',rows[-1]['e'])
    json.dump(data,open('./rec_boss.json','w'))
