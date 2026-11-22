"""Make the Godot version's music and background sounds as seamless loops (godot/music/*.wav, godot/amb/*.wav).

Usage:  python tools/make_music.py
Music: calm, tense, festival (what a place's "music" line asks for). Background: birds, room, market, night,
river, wind, bus (a place's "sound" line). Everything is made from tones and filtered noise, so it's all ours.
Each loop is made a little long, then its tail is faded into its start, so it repeats without a seam.
"""
import pathlib
import wave
import numpy as np
from scipy import signal

ROOT = pathlib.Path(__file__).resolve().parent.parent / "godot"
RATE = 22050
rng = np.random.default_rng(7)


def secs(t): return int(t * RATE)


def save(path, x, tail=2.0):
    """fold the extra tail back over the start (a crossfade), so the end runs straight into the beginning"""
    n = secs(tail); body, end = x[:-n].copy(), x[-n:]
    fade = np.linspace(0, 1, n)
    body[:n] = body[:n] * fade + end * (1 - fade)
    body = body / max(1e-6, np.max(np.abs(body))) * 0.8
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes((body * 32767).astype("<i2").tobytes())
    print(f"  {path.relative_to(ROOT)}  {len(body) / RATE:.0f}s")


def lowpass(x, hz, order=2): return signal.lfilter(*signal.butter(order, hz / (RATE / 2)), x)
def highpass(x, hz, order=2): return signal.lfilter(*signal.butter(order, hz / (RATE / 2), "high"), x)
def bandpass(x, lo, hi, order=2): return signal.lfilter(*signal.butter(order, [lo / (RATE / 2), hi / (RATE / 2)], "band"), x)
def noise(n): return rng.uniform(-1, 1, n)


def slow(n, rate_hz, depth=1.0):
    """a slow, wandering 0..1 curve (wind gusts, a crowd swelling)"""
    k = max(2, int(n / RATE * rate_hz) + 2)
    pts = rng.uniform(1 - depth, 1, k)
    return np.interp(np.arange(n), np.linspace(0, n, k), pts)


def pluck(freq, dur, vol=1.0, bright=0.5):
    """a plucked string (Karplus-Strong): a little like a gayageum"""
    n = secs(dur); p = max(2, int(RATE / freq))
    buf = rng.uniform(-1, 1, p); out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = (buf[i % p] + buf[(i + 1) % p]) * 0.5 * (0.994 + 0.005 * bright)
    return out * vol * np.exp(-np.linspace(0, 3, n))


def tone(freq, dur, vol=1.0, attack=0.02, release=None, kind="sine"):
    n = secs(dur); t = np.arange(n) / RATE
    w = np.sin(2 * np.pi * freq * t) if kind == "sine" else signal.sawtooth(2 * np.pi * freq * t)
    env = np.minimum(1, t / max(attack, 1e-3)); rel = release or dur * 0.6
    env *= np.clip((dur - t) / rel, 0, 1)
    return w * env * vol


def put(buf, x, at):
    i = secs(at) % len(buf); j = min(len(buf), i + len(x))
    buf[i:j] += x[:j - i]
    if j - i < len(x): buf[:len(x) - (j - i)] += x[j - i:]   # wraps round: the loop is seamless


NOTES = {"C3": 130.8, "D3": 146.8, "E3": 164.8, "G3": 196.0, "A3": 220.0, "C4": 261.6, "D4": 293.7, "E4": 329.6,
         "G4": 392.0, "A4": 440.0, "C5": 523.3, "D5": 587.3, "E5": 659.3, "G5": 784.0, "A2": 110.0, "E2": 82.4, "D2": 73.4}
PENTA = ["C4", "D4", "E4", "G4", "A4", "C5", "D5", "E5"]


def calm(L=48.0):
    """slow plucked notes over a soft held chord, wandering up and down the pentatonic scale"""
    buf = np.zeros(secs(L + 2))
    for i, ch in enumerate([["C3", "G3", "E4"], ["A2", "E3", "C4"], ["D3", "A3", "D4"], ["C3", "G3", "E4"]]):
        for nm in ch: put(buf, lowpass(tone(NOTES[nm], 12.5, 0.10, attack=3, release=4), 900), i * 12)
    step, at, k = 0.83, 0.4, 3
    while at < L:
        if rng.random() < 0.62:
            k = int(np.clip(k + rng.choice([-2, -1, -1, 1, 1, 2]), 0, len(PENTA) - 1))
            put(buf, pluck(NOTES[PENTA[k]], 2.6, 0.55), at)
        at += step * rng.choice([1, 1, 2])
    return buf


def tense(L=40.0):
    """a low drone that won't settle, a slow heartbeat, a high note now and then that doesn't belong"""
    n = secs(L + 2); t = np.arange(n) / RATE
    buf = (np.sin(2 * np.pi * 55 * t) + 0.7 * np.sin(2 * np.pi * 55.6 * t) + 0.4 * np.sin(2 * np.pi * 82.4 * t)) * 0.12
    buf = lowpass(buf * slow(n, 0.2, 0.5), 400)
    for b in np.arange(0, L, 1.6):
        put(buf, lowpass(tone(48, 0.25, 0.6, attack=0.005), 120), b); put(buf, lowpass(tone(44, 0.22, 0.4, attack=0.005), 120), b + 0.3)
    for at in np.arange(3, L, 7.5): put(buf, pluck(rng.choice([466.2, 698.5, 622.3]), 3.5, 0.25), at + rng.uniform(0, 2))
    return buf


def festival(L=32.0):
    """bright plucks over a drum pattern (deep thump, sharp slap)"""
    buf = np.zeros(secs(L + 2)); beat = 0.42
    for i, at in enumerate(np.arange(0, L, beat)):
        if i % 4 in (0, 3): put(buf, lowpass(tone(70, 0.3, 0.7, attack=0.003), 200), at)
        if i % 4 == 2: put(buf, highpass(noise(secs(0.08)) * np.exp(-np.linspace(0, 6, secs(0.08))), 1500) * 0.5, at)
        if rng.random() < 0.7: put(buf, pluck(NOTES[rng.choice(PENTA[2:])] * 2 ** rng.choice([0, 0, 1]) / 1, 1.2, 0.35), at)
    return buf


# ---------------- background sounds
def birds(L=30.0):
    n = secs(L + 2); buf = lowpass(noise(n), 500) * 0.15 * slow(n, 0.3, 0.6)
    for at in np.sort(rng.uniform(0, L, 26)):
        f0 = rng.uniform(2400, 4200)
        for j in range(rng.integers(1, 5)):
            d = rng.uniform(0.05, 0.12); m = secs(d); tt = np.arange(m) / RATE
            f = f0 + rng.uniform(-600, 900) * tt / d
            chirp = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.sin(np.pi * tt / d) * 0.35
            put(buf, chirp, at + j * (d + 0.04))
    return buf


def room(L=30.0):
    n = secs(L + 2); buf = lowpass(noise(n), 250) * 0.5 + lowpass(noise(n), 2500) * 0.04
    for at in np.arange(0, L, 1.0): put(buf, highpass(noise(secs(0.015)), 3000) * 0.06, at)   # a clock somewhere
    return buf


def market(L=30.0):
    n = secs(L + 2)
    buf = sum(bandpass(noise(n), lo, lo * 2.2) * slow(n, r, 0.8) for lo, r in [(250, 2.5), (400, 3.3), (650, 2.1)]) * 0.5
    for at in rng.uniform(0, L, 14): put(buf, tone(rng.uniform(1800, 3200), 0.25, 0.15, attack=0.002, release=0.2), at)   # a spoon on a bowl
    return buf


def night(L=30.0):
    n = secs(L + 2); buf = lowpass(noise(n), 300) * 0.2 * slow(n, 0.15, 0.5)
    for at in np.arange(0, L, 0.9):
        if rng.random() < 0.8:
            for j in range(3): put(buf, tone(4600, 0.035, 0.12, attack=0.003, release=0.02), at + j * 0.06)   # crickets
    return buf


def river(L=30.0):
    n = secs(L + 2); buf = bandpass(noise(n), 200, 1800) * (0.6 + 0.4 * slow(n, 1.5, 0.6))
    for at in rng.uniform(0, L, 40): put(buf, tone(rng.uniform(500, 1200), 0.06, 0.08, attack=0.005, release=0.05), at)
    return buf


def wind(L=30.0):
    n = secs(L + 2); return bandpass(noise(n), 150, 900) * slow(n, 0.25, 0.9) ** 2


def bus(L=20.0):
    n = secs(L + 2); t = np.arange(n) / RATE
    eng = lowpass(signal.sawtooth(2 * np.pi * 38 * t) * 0.5 + noise(n) * 0.3, 180) * (0.8 + 0.2 * slow(n, 0.5, 1))
    return eng + bandpass(noise(n), 400, 1200) * 0.05


if __name__ == "__main__":
    for name, f in [("calm", calm), ("tense", tense), ("festival", festival)]: save(ROOT / "music" / f"{name}.wav", f())
    for name, f in [("birds", birds), ("room", room), ("market", market), ("night", night), ("river", river), ("wind", wind), ("bus", bus)]:
        save(ROOT / "amb" / f"{name}.wav", f())
