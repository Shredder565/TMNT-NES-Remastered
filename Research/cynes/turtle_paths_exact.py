import json
E=json.load(open('/home/claude/work/play_emu.json')); R=json.load(open('/home/claude/work/play_remake.json'))
tot=0
for k in sorted(E):
    e=E[k]['trace']; r=R[k]; n=min(len(e),len(r)); n=next((f for f in range(n) if e[f][5]),n); first=n
    for f in range(n):
        if abs(e[f][0]-r[f][0])>0.6 or abs(e[f][1]-r[f][1])>0.6: first=f; break
    tot+=first
    extra='' if first>=n else ' emu (%.2f, %.2f) cam %d lock %d; remake (%.2f, %.2f); before: emu (%.2f, %.2f) remake (%.2f, %.2f)'%(e[first][0],e[first][1],e[first][4],e[first][5],r[first][0],r[first][1],e[first-2][0],e[first-2][1],r[first-2][0],r[first-2][1])
    print(k,'exact for',first,'of',n,'frames',extra); full=globals().get('full',0)+n
print('total exact frames',tot,'of',full)
