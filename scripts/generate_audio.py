"""Reproducible, original 16-bit synthesized effects; no downloaded recordings."""
import math, random, struct, wave
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1] / 'content' / 'audio'
RATE = 22050

def write(name, duration, tone, decay, noise_amount, seed, scrape=False):
    rng = random.Random(seed)
    samples=[]
    filtered=0.0
    for i in range(int(RATE*duration)):
        t=i/RATE
        filtered=filtered*0.67+rng.uniform(-1,1)*0.33
        envelope=min(1,t/0.004)*math.exp(-decay*t)*min(1,(duration-t)/0.02)
        noise=(rng.uniform(-1,1)*0.35+filtered)*noise_amount
        body=math.sin(2*math.pi*tone*t)*0.35+math.sin(2*math.pi*tone*1.47*t)*0.15
        if scrape:
            envelope=math.sin(math.pi*t/duration)**0.8
            body=0.08*math.sin(2*math.pi*110*t)
            noise*=0.4+0.6*abs(math.sin(2*math.pi*38*t))
        samples.append(max(-0.9,min(0.9,(body+noise)*envelope))*0.5)
    save(name,samples)

def save(name,samples):
    with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h',int(x*32767)) for x in samples))

for name,args in {
 'step_grass':(.12,95,28,.8,1), 'step_wood':(.14,155,28,.35,2),
 'chop':(.26,210,17,1.2,3), 'saw':(.26,120,8,1.3,4,True),
 'pickup':(.16,80,22,.45,5), 'drop':(.24,110,18,.7,6),
 'build':(.18,330,25,.7,7), 'harvest':(.16,70,22,.9,8),
 'fall':(.65,65,7,1.1,9),
 'punch':(.2,150,32,.95,11), 'shove':(.28,95,15,1.15,12), 'thud':(.5,52,10,.85,13)
}.items(): write(name,*args)
rng=random.Random(10); value=0.; wind=[]
for i in range(RATE*4):
    value=.985*value+.015*rng.uniform(-1,1)
    wind.append(value*.7*(.7+.3*math.sin(2*math.pi*i/(RATE*4))))
# Short fade at the loop boundary guarantees a click-free zero crossing.
for i in range(len(wind)):
    wind[i] *= min(1.0, i/512, (len(wind)-i-1)/512)
save('wind',wind)
print('Generated',len(list(ROOT.glob('*.wav'))),'original effects')
