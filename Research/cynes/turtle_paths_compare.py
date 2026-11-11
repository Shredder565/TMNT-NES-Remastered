import json,sys
E=json.load(open('/home/claude/work/play_emu.json')); R=json.load(open('/home/claude/work/play_remake.json'))
TOL=float(sys.argv[1]) if len(sys.argv)>1 else 6
def dev(e,r,f):
    best=99
    for s in (-2,-1,0,1,2):
        g=f+s
        if 0<=g<len(r): best=min(best,max(abs(e[f][0]-r[g][0]),abs(e[f][1]-r[g][1])))
    return best
for k in sorted(E):
    e=E[k]['trace']; r=R.get(k,[]); n=min(len(e),len(r)); first=None
    for f in range(n):
        if dev(e,r,f)>TOL: first=f; break
    if first is None: print(k,'same for all %d frames; ends at'%n,e[-1][:2],[round(x) for x in r[-1][:2]])
    else:
        f=first; print(k,'differs from frame %d:'%f,' '.join('%d:%s/%s'%(g,tuple(e[g][:2]),tuple(round(x) for x in r[g][:2])) for g in range(max(0,f-6),min(n,f+14),2)))
