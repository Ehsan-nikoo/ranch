# Makes the synthesized sounds: rain loop, thunder, wolf howls. Run: python3 tools/sounds.py sounds
import numpy as np, wave, sys
SR=22050
rng=np.random.default_rng(7)
def save(name, x):
    x=x/np.max(np.abs(x))*0.85
    with wave.open(name,'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x*32767).astype('<i2').tobytes())
def lowpass(x, a):  # one-pole
    y=np.empty_like(x); s=0.0
    for i,v in enumerate(x):
        s+=a*(v-s); y[i]=s
    return y
def hp(x,a): return x-lowpass(x,a)
out=sys.argv[1]
# rain: pink-ish noise + random drips, seamless loop by crossfade
n=SR*6
noise=rng.standard_normal(n+SR)
r=lowpass(hp(noise,0.02),0.35)
drops=np.zeros(n+SR)
for t in rng.integers(0,n+SR-400,900):
    k=np.arange(300); drops[t:t+300]+=rng.uniform(0.3,1)*np.exp(-k/40)*np.sin(k*rng.uniform(0.6,1.4))
r=r+0.25*hp(drops,0.1)
fade=np.linspace(0,1,SR)
loop=r[:n].copy(); loop[:SR]=r[:SR]*fade+r[n:n+SR]*(1-fade)
save(out+'/rain.wav',loop)
# thunder
for k,(L,seed) in enumerate([(5.0,1),(6.5,2)]):
    g=np.random.default_rng(seed); m=int(SR*L); t=np.arange(m)/SR
    x=lowpass(g.standard_normal(m),0.02)
    crack=lowpass(g.standard_normal(m),0.3)*np.exp(-t*9)
    env=(1-np.exp(-t*25))*np.exp(-t*0.9)*(1+0.6*np.sin(t*3.1+seed)*np.sin(t*1.3))
    save(out+'/thunder_%d.wav'%(k+1), x*env*3+crack*0.6)
# wolf howl
for k,(L,f0,f1,f2,seed) in enumerate([(3.4,330,610,450,3),(4.0,300,560,380,4)]):
    m=int(SR*L); t=np.arange(m)/SR; u=t/L
    f=np.where(u<0.25, f0+(f1-f0)*np.sin(u/0.25*np.pi/2), f1+(f2-f1)*((u-0.25)/0.75)**1.4)
    f=f*(1+0.012*np.sin(2*np.pi*5.5*t))
    ph=2*np.pi*np.cumsum(f)/SR
    x=np.sin(ph)+0.35*np.sin(2*ph)+0.12*np.sin(3*ph)
    env=np.clip(u/0.12,0,1)*np.clip((1-u)/0.3,0,1)**1.2
    x=x*env+0.03*lowpass(np.random.default_rng(seed).standard_normal(m),0.2)*env
    # echo across the plain
    y=np.zeros(m+int(SR*1.2)); y[:m]+=x
    for d,a in [(0.31,0.35),(0.67,0.2),(1.05,0.1)]:
        o=int(SR*d); y[o:o+m]+=a*x
    save(out+'/howl_%d.wav'%(k+1), y)
