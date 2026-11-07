"""Draw the home-screen icon (a grinning mask on night ink) at the sizes Android wants."""
import pathlib
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "icons"
OUT.mkdir(exist_ok=True)

def draw(size, pad):
    S = 1024  # draw big, then downsample for smooth edges
    im = Image.new("RGB", (S, S), "#151a24")
    d = ImageDraw.Draw(im)
    # dancheong band
    d.rectangle([0, int(S*.80), S, int(S*.84)], fill="#3f8b77")
    d.rectangle([0, int(S*.80), S, int(S*.81)], fill="#b5412d")
    k = 1 - pad * 2
    cx, cy = S/2, S*.46
    rx, ry = S*.28*k, S*.36*k
    d.ellipse([cx-rx, cy-ry, cx+rx, cy+ry], fill="#e7d2a7", outline="#7d5c3a", width=int(S*.012))
    lw = int(S*.026*k)
    # brows and smiling eyes
    for sx in (-1, 1):
        ex = cx + sx*rx*.42
        d.arc([ex-rx*.36, cy-ry*.62, ex+rx*.36, cy-ry*.18], 200, 340, fill="#2e2218", width=lw)
        d.arc([ex-rx*.3, cy-ry*.30, ex+rx*.3, cy+ry*.02], 200, 340, fill="#2e2218", width=lw)
        d.ellipse([ex-rx*.17, cy+ry*.08, ex+rx*.17, cy+ry*.26], fill="#d9876f")
    # grin
    d.chord([cx-rx*.62, cy+ry*.05, cx+rx*.62, cy+ry*.72], 15, 165, fill="#5a2a1d")
    return im.resize((size, size), Image.LANCZOS)

draw(512, 0.0).save(OUT / "icon-512.png")
draw(192, 0.0).save(OUT / "icon-192.png")
draw(512, 0.12).save(OUT / "maskable-512.png")
draw(180, 0.0).save(OUT / "apple-180.png")
print("icons written")
