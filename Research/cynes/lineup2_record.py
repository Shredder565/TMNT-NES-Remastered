"""Line-up 2 (kinds 84, 85, 9D, 4B) in world 1's fourth room, as world 2 and 3 have it. -> rec_w2.json"""
import sys, json
sys.path.insert(0,'.')
from common import *
import rec
from rec import record, still, walk_lr, jumps, spot
def lineup2(f,n): n[0x604]=2
SETS={
 'still': lambda: record(3,spot(3,0)[0],spot(3,0)[1],still,700,poke=lineup2),
 'right': lambda: record(3,spot(3,0)[0],spot(3,0)[1],lambda f:R if f>40 else 0,1000,poke=lineup2),
 'left': lambda: record(3,spot(3,2)[0],spot(3,2)[1],lambda f:L if f>40 else 0,1000,poke=lineup2),
 'pace': lambda: record(3,spot(3,1)[0],spot(3,1)[1],walk_lr(120,jump=80),1000,poke=lineup2),
 'jump': lambda: record(3,spot(3,1)[0],spot(3,1)[1],jumps,800,poke=lineup2),
 'pace2': lambda: record(3,330,176,walk_lr(70),900,poke=lineup2),
}
data={k:v() for k,v in SETS.items()}
json.dump(data,open('./rec_w2.json','w'))
for k,v in data.items():
    kinds=sorted({'%02X'%o[0] for r in v['rows'] for o in r['o'].values()})
    n85=sum(1 for r in v['rows'] for o in r['o'].values() if o[0]==0x85)
    dives=sum(1 for r in v['rows'] for o in r['o'].values() if o[0]==0x85 and o[7] in (0x0E,0x0F))
    print(k,len(v['rows']),kinds,'frames with an 85:',n85,'diving:',dives)
