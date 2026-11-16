"""Original seeded vector scenery; no reference artwork is copied."""
from pathlib import Path
import random, math
out=Path(__file__).resolve().parents[1]/'content/art'
for variant in range(4):
 r=random.Random(410+variant)
 parts=['<svg xmlns="http://www.w3.org/2000/svg" width="128" height="160" viewBox="0 0 128 160">','<path d="M47 149 L57 111 L54 65 L69 64 L74 117 L85 150 L69 144 L63 153 L58 143Z" fill="#795745" stroke="#3c3528" stroke-width="2"/>','<path d="M62 143 Q70 114 62 81 M62 113 L40 88 M68 105 L87 78" fill="none" stroke="#b18a61" stroke-width="3"/>']
 for i in range(160):
  a=r.random()*math.tau; d=math.sqrt(r.random()); x=64+math.cos(a)*49*d; y=62+math.sin(a)*44*d
  col=r.choice(['#0c392b','#104833','#15553a','#1b6140','#236c42','#34784a'])
  parts.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{r.randint(5,12)}" ry="{r.randint(4,9)}" fill="{col}" stroke="#123d2b" stroke-width=".6"/>')
 parts.append('</svg>'); (out/f'tree_{variant}.svg').write_text(''.join(parts))
r=random.Random(72); parts=['<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192">','<path fill="#ac9865" d="M0 0H192V192H0Z"/>']
for i in range(1600):
 x=r.randrange(192); y=r.randrange(192); col=r.choice(['#bba775','#c3af7e','#8f8559','#a18f5d'])
 parts.append(f'<path d="M{x} {y}q4 -2 9 0" fill="none" stroke="{col}" opacity=".45" stroke-width="{r.choice([1,2,3])}"/>')
parts.append('</svg>'); (out/'earth.svg').write_text(''.join(parts))
# Fine wood grain is baked once, so interiors can be rich without per-frame paths.
r=random.Random(912)
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192">','<path fill="#805332" d="M0 0H192V192H0Z"/>']
for row in range(12):
 for col in range(-1,4):
  x=col*64+(32 if row%2 else 0); y=row*16
  color=r.choice(['#a87c49','#a07543','#b1844f','#986b3e'])
  parts.append(f'<rect x="{x+1}" y="{y+1}" width="62" height="14" rx="2" fill="{color}" stroke="#604126"/>')
  for j in range(3):
   yy=y+4+j*3
   parts.append(f'<path d="M{x+5} {yy}q25 -2 50 0" fill="none" stroke="#d1a369" opacity=".28"/>')
parts.append('</svg>'); (out/'floor.svg').write_text(''.join(parts))
for variant in range(3):
 r=random.Random(600+variant);parts=['<svg xmlns="http://www.w3.org/2000/svg" width="128" height="96">']
 for i in range(145):
  x=r.uniform(8,120);y=r.uniform(18,89); height=r.uniform(4,17)
  if ((x-64)/59)**2+((y-54)/39)**2>1:continue
  col=r.choice(['#7c8145','#8e9050','#666f3c','#a0a05b'])
  parts.append(f'<path d="M{x:.1f} {y:.1f}q-2 -7 {r.uniform(-6,6):.1f} {-height:.1f}" fill="none" stroke="{col}" stroke-width="2" opacity=".7"/>')
 parts.append('</svg>');(out/f'grass_{variant}.svg').write_text(''.join(parts))
