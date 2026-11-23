"""Make the Godot version's sound effects as .wav files (godot/sfx/). Same recipes as SFX in js/audio.js.

Usage:  python tools/make_sfx.py
Each sound is a few tones and noise bursts mixed together. Change a recipe, run it again.
"""
import math, pathlib, random, struct, wave

OUT = pathlib.Path(__file__).resolve().parent.parent / "godot" / "sfx"
RATE = 22050


def blank(sec): return [0.0] * int(RATE * sec)


def tone(buf, t0, dur, freq, vol, kind="sine", f1=None):
    """a tone that fades out; f1 = slide to this frequency"""
    n0, n = int(t0 * RATE), int(dur * RATE); ph = 0.0
    for i in range(n):
        if n0 + i >= len(buf): break
        f = freq if f1 is None else freq + (f1 - freq) * i / n
        ph += 2 * math.pi * f / RATE
        w = math.sin(ph) if kind == "sine" else (1.0 if math.sin(ph) > 0 else -1.0) if kind == "square" else (ph / math.pi % 2) - 1
        buf[n0 + i] += w * vol * (1 - i / n) ** 2


def noise(buf, t0, dur, vol, cutoff):
    """a burst of noise through a simple low-pass filter (lower cutoff = duller thud)"""
    n0, n = int(t0 * RATE), int(dur * RATE); a = min(1.0, 2 * math.pi * cutoff / RATE); y = 0.0
    for i in range(n):
        if n0 + i >= len(buf): break
        y += a * (random.uniform(-1, 1) - y)
        buf[n0 + i] += y * vol * 3 * (1 - i / n) ** 1.5


def creak(buf, t0, dur, vol):
    """a rusty hinge: metal sticking and slipping. Lots of tiny scrapes (each a short, ringing click) whose rate
    speeds up and slows down unevenly, through a woody resonance. No steady tone, so it doesn't hum like a bee."""
    n0, n = int(t0 * RATE), int(dur * RATE); t = 0.0
    ring = [(820, .5), (1350, .35), (2300, .2)]                       # the metal and wood it rings through
    while t < dur:
        k = t / dur
        rate = 28 + 55 * math.sin(k * math.pi) ** 2 + random.uniform(-10, 10)   # slips per second, uneven
        amp = vol * (0.35 + 0.65 * math.sin(k * math.pi)) * random.uniform(0.6, 1.0)
        s0 = n0 + int(t * RATE)
        for f, a in ring:
            f *= random.uniform(0.97, 1.03); d = int(RATE * 0.012)
            for i in range(d):
                if s0 + i >= len(buf): break
                buf[s0 + i] += math.sin(2 * math.pi * f * i / RATE) * a * amp * math.exp(-i / (RATE * 0.003))
        noise(buf, t0 + t, 0.006, amp * 0.25, 2500)
        t += 1.0 / max(8, rate)


def save(name, buf):
    peak = max(1e-6, max(abs(x) for x in buf)); k = 0.9 / peak if peak > 0.9 else 1.0
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * k)) * 32767)) for x in buf))


def main():
    OUT.mkdir(parents=True, exist_ok=True); random.seed(7)
    b = blank(1.0); noise(b, 0, .5, .5, 320); noise(b, 0, .09, .4, 1800); tone(b, 0, .45, 55, .5); tone(b, .02, .3, 82, .3); noise(b, .32, .3, .15, 600); save("slam", b)
    b = blank(1.2); creak(b, 0, 1.1, .5); save("creak", b)
    b = blank(.35); tone(b, 0, .12, 180, .25, "square"); noise(b, 0, .08, .3, 1200); tone(b, .03, .2, 90, .3); save("clunk", b)
    b = blank(.08); noise(b, 0, .02, .4, 3200); tone(b, 0, .02, 2200, .1, "square"); save("click", b)
    b = blank(.08); tone(b, 0, .045, 1400, .12); noise(b, 0, .025, .1, 2600); save("tap", b)
    b = blank(1.2); [tone(b, i * .08, .8, f, .15, "sine") for i, f in enumerate([523, 659, 784, 1047])]; save("solve", b)
    b = blank(.3); tone(b, 0, .25, 140, .3); save("wrong", b)
    b = blank(1.0); tone(b, 0, .55, 784, .2, "sine"); tone(b, .09, .7, 1175, .16, "sine"); save("learn", b)
    b = blank(.2); noise(b, 0, .16, .12, 1600); save("page", b)
    b = blank(.15); noise(b, 0, .1, .1, 900); save("open", b)
    b = blank(1.6); tone(b, 0, 1.5, 110, .06, "sine", 105); noise(b, 0, 1.6, .05, 400); save("wind", b)
    b = blank(.22); noise(b, 0, .07, .3, 900); tone(b, 0, .05, 85, .22); noise(b, .02, .06, .1, 2600); save("step", b)
    print("ok:", ", ".join(sorted(p.stem for p in OUT.glob("*.wav"))))


if __name__ == "__main__":
    main()
