# Synthesizes seamless ambience loops into ../sounds: prairie wind and night crickets.
import numpy as np
import wave
from pathlib import Path

SR = 22050
out = Path(__file__).resolve().parent.parent / "sounds"
out.mkdir(exist_ok=True)
rng = np.random.default_rng(1)


def save(name, x):
    x = x / np.abs(x).max() * 0.8
    with wave.open(str(out / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def lowpass(x, cutoff):
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(f, len(x))  # FFT filtering is circular, so the loop stays seamless


def slow_env(n, cycles):
    # periodic gusts: sum of sines whose periods divide the loop length
    t = np.arange(n) / n
    e = sum(np.sin(2 * np.pi * (c * t + rng.random())) / (i + 1) for i, c in enumerate(cycles))
    return 0.55 + 0.45 * e / np.abs(e).max()


n = SR * 20
wind = lowpass(rng.standard_normal(n), 500) * slow_env(n, [2, 3, 7])
wind += lowpass(rng.standard_normal(n), 1600) * 0.25 * slow_env(n, [5, 11])
save("wind.wav", wind)

n = SR * 12
t = np.arange(n) / SR
crk = np.zeros(n)
for voice in range(5):
    f = rng.uniform(4200, 5200)
    rate = rng.uniform(1.2, 2.2)  # chirps per second
    period = int(SR / rate)
    for start in range(int(rng.random() * period), n, period):
        for p in range(3):  # each chirp is three quick pulses
            s = start + p * int(SR * 0.025)
            m = int(SR * 0.015)
            if s + m < n:
                crk[s:s + m] += np.sin(2 * np.pi * f * t[:m]) * np.hanning(m) * rng.uniform(0.3, 1)
crk += lowpass(rng.standard_normal(n), 300) * 0.05
save("crickets.wav", crk)
print("ok")
