"""The two boss fights of world 1 again, with the sounds asked for.
usage: python3 -I snd_boss.py [names] -> snd_boss.json"""
import sys, json
sys.path.insert(0,'/home/claude/work_agent_sound')
import snd_live            # puts the sound-recording record() in place
import boss_record
names=sys.argv[1:] or ['b_beaten','r_beaten','b_swing','r_swing']
data={}
for name in names:
    v=boss_record.SETS[name](); data[name]=v
    print(name,[(f,'%02X'%r['s']) for f,r in enumerate(v['rows']) if r['s']>=0 and r['s'] not in (0x0A,0x07,0x08,0x21,0x25)])
json.dump(data,open('/home/claude/work_agent_sound/snd_boss.json','w'))
