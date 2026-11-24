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


def hinge(buf, t0, dur, vol):
    """a heavy door on a dry hinge: the pin sticks and slips a few hundred times a second, the rate gliding up and
    back down as the door swings (that glide is the creak), heard through the wood and iron it shakes"""
    n0, n = int(t0 * RATE), int(dur * RATE); src = [0.0] * n; ph = 0.0; hold = 0
    for i in range(n):
        k = i / n
        f = (135 + 190 * math.sin(math.pi * min(1.0, k * 1.15)) ** 1.5) * (1 + 0.05 * math.sin(k * 47))
        ph += f / RATE * random.uniform(0.93, 1.07)
        if hold > 0: hold -= 1; continue
        if ph >= 1.0:
            ph -= 1.0; src[i] = (0.4 + 0.6 * math.sin(math.pi * k)) * random.uniform(0.7, 1.0)
            if random.random() < 0.012: hold = int(RATE * random.uniform(0.008, 0.02)); ph = 0.0   # it sticks for a moment
    for f, q, a in [(290, 5, .12), (610, 8, .45), (1080, 12, 1.0), (1720, 14, 1.5), (2650, 16, 1.6)]:
        w = 2 * math.pi * f / RATE; rr = math.exp(-w / (2 * q)); c1 = 2 * rr * math.cos(w); c2 = -rr * rr; y1 = y2 = 0.0
        for i in range(n):
            y = src[i] + c1 * y1 + c2 * y2; y2 = y1; y1 = y
            buf[n0 + i] += y * a * vol * 0.35


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
    b = blank(.22); noise(b, 0, .09, .22, 420); tone(b, 0, .06, 70, .18); save("step", b)   # a soft shoe on stone
    # the courtyard gate thrown open: the iron latch, the hinge, and the planks hitting the wall
    b = blank(1.25); noise(b, 0, .03, .5, 3000); tone(b, 0, .05, 1900, .25); tone(b, .035, .06, 1450, .2); noise(b, .035, .03, .35, 2400)
    hinge(b, .08, .5, .42)
    noise(b, .52, .28, .4, 260); tone(b, .52, .3, 68, .4); tone(b, .53, .16, 118, .25); noise(b, .525, .05, .35, 1500); noise(b, .68, .05, .12, 900); noise(b, .8, .04, .07, 900); save("gate", b)
    print("ok:", ", ".join(sorted(p.stem for p in OUT.glob("*.wav"))))


if __name__ == "__main__":
    main()
