"""Draws the village map: godot/map/land.svg (the land itself) and one little drawing per place (godot/map/<place>.svg).
The map page (godot/scripts/ui/village_map.gd) puts the places on it as you hear of them or go there.
Usage:  python tools/make_map.py"""
import math, pathlib, random
OUT = pathlib.Path(__file__).resolve().parent.parent / "godot" / "map"; OUT.mkdir(exist_ok=True)
W, H = 1200, 545
R = random.Random(4)
s = []
def p(d, fill="none", stroke="none", w=1.0, o=1.0, dash="", cap="round"):
    s.append(f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" opacity="{o}" stroke-linecap="{cap}" stroke-linejoin="round"' + (f' stroke-dasharray="{dash}"' if dash else "") + "/>")

# ---- the paper
s.append(f'<rect width="{W}" height="{H}" fill="#efe3c4"/>')
for i in range(26): s.append(f'<ellipse cx="{R.uniform(0,W):.0f}" cy="{R.uniform(0,H):.0f}" rx="{R.uniform(60,190):.0f}" ry="{R.uniform(30,90):.0f}" fill="{R.choice(["#e4d3a8","#f6edd5","#dfcb9c"])}" opacity="{R.uniform(.15,.35):.2f}"/>')
for i in range(170):
    x, y, l = R.uniform(0, W), R.uniform(0, H), R.uniform(6, 18); p(f"M{x:.0f},{y:.0f} q{l/2:.0f},{R.uniform(-2,2):.1f} {l:.0f},0", stroke="#cdb988", w=.8, o=.5)
# ---- mountains, ink wash, far to near
for (x1, y, x2, top, c, o) in [(-60,150,220,10,"#9fb0a2",.5),(120,140,420,-10,"#a9b8aa",.45),(330,120,600,20,"#b4c1b2",.4),(560,105,800,30,"#bcc8b8",.35),
                               (-80,250,170,70,"#86998b",.6),(60,240,330,60,"#7f9486",.6),(240,200,440,90,"#93a597",.5),(820,90,1060,10,"#b4c1b2",.4),(980,110,1260,0,"#a9b8aa",.45)]:
    m = (x1 + x2) / 2
    gid = f"g{len(s)}"   # an ink wash: strong at the top, gone at the foot
    s.append(f'<defs><linearGradient id="{gid}" x1="0" y1="{top}" x2="0" y2="{y}" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="{c}" stop-opacity="1"/><stop offset="0.55" stop-color="{c}" stop-opacity="0.75"/><stop offset="1" stop-color="{c}" stop-opacity="0"/></linearGradient></defs>')
    p(f"M{x1},{y} Q{m-70},{top+46} {m-14},{top+8} Q{m},{top-6} {m+16},{top+10} Q{m+74},{top+52} {x2},{y} Z", fill=f"url(#{gid})", o=min(1, o * 1.45))
    h = y - top   # the ridge line, only near the peak
    p(f"M{m-(m-x1)*.42:.0f},{top+h*.36:.0f} Q{m-46},{top+32} {m-14},{top+8} Q{m},{top-6} {m+16},{top+10} Q{m+50},{top+36} {m+(x2-m)*.42:.0f},{top+h*.38:.0f}", stroke="#5d7064", w=2, o=o * .8)
    for k in range(4): p(f"M{m-10+k*14:.0f},{top+30+k*9:.0f} q6,18 {R.uniform(-6,10):.0f},{R.uniform(26,44):.0f}", stroke="#5d7064", w=1.4, o=o * .5)
def pine(x, y, k=1.0, o=.85):
    for j in range(3): p(f"M{x},{y-22*k+j*7*k:.1f} l{7*k+j*2*k:.1f},{12*k:.1f} h{-2*(7*k+j*2*k):.1f} Z", fill="#4a6655", o=o)
    p(f"M{x},{y+4*k:.1f} v{7*k:.1f}", stroke="#5a3f28", w=2.2 * k, o=o)
for i in range(46):
    x, y = R.uniform(6, 330), R.uniform(120, 300)
    if 90 < x < 260 and 60 < y < 240 and R.random() < .55: continue
    pine(x, y, R.uniform(.6, 1.05), .75)
for x, y in [(690,60),(715,74),(760,52),(930,60),(960,84),(1130,190),(1160,214),(1175,180),(905,250),(935,268),(640,252),(664,268),(760,180),(782,196)]: pine(x, y, .9)
# ---- the river, from the mountains past the village
river = "M742,-20 C700,60 800,110 792,180 S850,300 930,352 S1080,420 1230,404"
p(river, stroke="#8fb4c4", w=62); p(river, stroke="#a9cbd8", w=48); p(river, stroke="#cfe4ea", w=14, o=.8)
for x, y in [(752,40),(776,104),(788,170),(806,236),(848,296),(908,344),(990,380),(1080,402),(1160,408)]:
    p(f"M{x},{y} q6,-5 12,0 t12,0", stroke="#eef6f7", w=2); p(f"M{x-14},{y+12} q5,-4 10,0", stroke="#eef6f7", w=1.6)
for x, y in [(742,220),(752,232),(770,262),(1010,348),(1022,354),(890,392),(904,400)]: p(f"M{x},{y} l-2,-18 M{x+5},{y} l1,-22 M{x+10},{y} l3,-16", stroke="#7c9156", w=2)
# ---- rice fields and dry fields
for (x0, y0, n, m) in [(60,400,5,4),(300,478,3,2),(1000,200,3,3)]:
    for r_ in range(m):
        for c_ in range(n):
            x, y = x0 + c_ * 40 + r_ * 6, y0 + r_ * 29
            p(f"M{x},{y} l36,-3 l3,25 l-37,3 Z", fill=R.choice(["#c3d09a", "#b5c689", "#cfd8a6"]), stroke="#8a9c62", w=1.2, o=.85)
            for k in range(3): p(f"M{x+6+k*10},{y+6} l1,14", stroke="#7f9558", w=1, o=.6)
# ---- roofs of the village (nobody in particular), and the wall round them
def house(x, y, w=30, c="#59616a"):
    s.append(f'<rect x="{x-w/2+4:.0f}" y="{y-4}" width="{w-8}" height="13" fill="#f7efdc" stroke="#7a5a3c" stroke-width="1.2"/>')
    p(f"M{x-w/2-4},{y} Q{x},{y-7} {x+w/2+4},{y} L{x+w/2-3},{y-12} L{x-w/2+3},{y-12} Z", fill=c, stroke="#3a4048", w=1)
for x, y in [(286,268),(322,290),(300,330),(350,372),(312,384),(366,418),(470,296),(520,306),(498,346),(462,372),(528,262),(606,330),(640,352),(664,318),(430,452),(392,470),(590,250),(690,400)]: house(x, y, R.choice([26, 30, 34]), R.choice(["#59616a", "#666d74", "#6b5440"]))
p("M268,300 Q262,352 300,404 Q340,448 396,438", stroke="#9a8a6c", w=4, o=.6); p("M268,300 Q262,352 300,404 Q340,448 396,438", stroke="#f2e7ca", w=1.4, o=.9, dash="3 7")
# ---- a compass, and a torn double border
cx, cy = 1128, 486
for a in range(0, 360, 90):
    t = math.radians(a); u = math.radians(a + 90)
    p(f"M{cx+34*math.sin(t):.1f},{cy-34*math.cos(t):.1f} L{cx+7*math.sin(u):.1f},{cy-7*math.cos(u):.1f} L{cx},{cy} Z", fill="#7a5a3c", o=.8)
    p(f"M{cx+34*math.sin(t):.1f},{cy-34*math.cos(t):.1f} L{cx-7*math.sin(u):.1f},{cy+7*math.cos(u):.1f} L{cx},{cy} Z", fill="#e9d9b2", stroke="#7a5a3c", w=1)
s.append(f'<circle cx="{cx}" cy="{cy}" r="22" fill="none" stroke="#7a5a3c" stroke-width="1.4" opacity=".7"/>')
s.append(f'<rect x="7" y="7" width="{W-14}" height="{H-14}" fill="none" stroke="#8a6c45" stroke-width="3" opacity=".75"/><rect x="14" y="14" width="{W-28}" height="{H-28}" fill="none" stroke="#8a6c45" stroke-width="1" opacity=".6"/>')
(OUT / "land.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*2}" height="{H*2}" viewBox="0 0 {W} {H}">' + "".join(s) + "</svg>", encoding="utf-8")

# ---------------------------------------------------------------- the places (96 x 72 each)
def roof(x, y, w, h, c="#3f464e", e="#262b31"):   # a curved tiled roof
    g = f'<path d="M{x-w/2-7},{y+h} Q{x-w/4},{y+h-5} {x},{y+h-5} Q{x+w/4},{y+h-5} {x+w/2+7},{y+h} Q{x+w/2-5},{y+h-8} {x+w/2-11},{y} L{x-w/2+11},{y} Q{x-w/2+5},{y+h-8} {x-w/2-7},{y+h} Z" fill="{c}" stroke="{e}" stroke-width="1.6" stroke-linejoin="round"/>'
    for k in range(1, int(w // 10)): g += f'<path d="M{x-w/2+k*10:.0f},{y+2} l{(k*10-w/2)*.12:.1f},{h-7}" stroke="{e}" stroke-width="1" opacity=".5"/>'
    return g + f'<rect x="{x-w/2+9}" y="{y-3}" width="{w-18}" height="4" rx="2" fill="{e}"/>'
def wall(x, y, w, h, c="#f6ecd6"): return f'<rect x="{x-w/2}" y="{y}" width="{w}" height="{h}" fill="{c}" stroke="#6b4528" stroke-width="1.6"/>'
def lattice(x, y, w, h): return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#fff8e4" stroke="#6b4528" stroke-width="1.2"/>' + "".join(f'<path d="M{x+k*w/4:.1f},{y} v{h}" stroke="#6b4528" stroke-width=".8"/>' for k in (1, 2, 3)) + f'<path d="M{x},{y+h/2:.1f} h{w}" stroke="#6b4528" stroke-width=".8"/>'
PL = {
 "madang": wall(48,36,62,22) + lattice(22,40,15,16) + lattice(59,40,15,16) + '<rect x="41" y="40" width="14" height="18" fill="#8a5a34"/>' + roof(48,18,66,20) + '<ellipse cx="14" cy="62" rx="7" ry="6" fill="#7a4a30"/><ellipse cx="25" cy="64" rx="6" ry="5" fill="#8a5638"/><circle cx="84" cy="46" r="10" fill="#4f7d4f"/><circle cx="81" cy="43" r="2" fill="#e98a3a"/><circle cx="88" cy="48" r="2" fill="#e98a3a"/><path d="M84,56 v9" stroke="#5a3f28" stroke-width="3"/>',
 "gongbang": wall(48,36,54,22,"#e6d2ae") + '<rect x="28" y="41" width="16" height="17" fill="#6b4528"/><ellipse cx="62" cy="48" rx="8" ry="10" fill="#e8b872" stroke="#5a3b24" stroke-width="1.4"/><path d="M57,45 q2,-2 4,0 M63,45 q2,-2 4,0 M57,51 q5,5 10,0" stroke="#3a2416" stroke-width="1.6" fill="none"/>' + roof(48,18,58,20,"#6a4d36","#3f2c1d") + '<path d="M78,62 l14,-6 l3,5 l-14,6 Z" fill="#b98a54" stroke="#6b4528" stroke-width="1"/>',
 "golmok": '<path d="M10,66 L32,30 L38,30 L30,66 Z" fill="#b9ad97" stroke="#7d7260" stroke-width="1.5"/><path d="M86,66 L64,30 L58,30 L66,66 Z" fill="#b9ad97" stroke="#7d7260" stroke-width="1.5"/><path d="M30,66 L40,32 L56,32 L66,66 Z" fill="#e3d1a6"/><path d="M14,26 Q48,40 82,24" stroke="#4a4038" stroke-width="1.4" fill="none"/>' + "".join(f'<rect x="{x}" y="{y}" width="8" height="10" rx="4" fill="{c}" stroke="#5a2a20" stroke-width="1"/>' for x, y, c in [(22,30,"#d8503c"),(40,33,"#e8b53a"),(57,32,"#4f8a9a")]),
 "hall": wall(48,36,60,22) + '<rect x="40" y="40" width="16" height="18" fill="#7a4a30"/>' + roof(48,18,66,20) + '<path d="M82,66 V30" stroke="#5a3f28" stroke-width="2.5"/><rect x="70" y="28" width="24" height="17" fill="#d9b374" stroke="#6b4528" stroke-width="1.6"/><rect x="73" y="31" width="8" height="5" fill="#fff8e4"/><rect x="83" y="33" width="8" height="8" fill="#fff8e4"/>',
 "sanqil": '<path d="M14,68 Q44,58 38,44 Q34,32 58,22" stroke="#c9a46a" stroke-width="9" fill="none" stroke-linecap="round"/><path d="M14,68 Q44,58 38,44 Q34,32 58,22" stroke="#ecd9ab" stroke-width="5" fill="none" stroke-linecap="round"/>' + "".join(f'<path d="M{x},{y-18} l8,13 h-16 Z M{x},{y-10} l10,15 h-20 Z" fill="#47664f"/><path d="M{x},{y+5} v6" stroke="#5a3f28" stroke-width="2.5"/>' for x, y in [(70,46),(18,42),(84,60)]) + '<path d="M60,60 v-12" stroke="#5a3f28" stroke-width="2.5"/><path d="M52,40 h14 l5,4 l-5,4 h-14 Z" fill="#a5713f" stroke="#5a3b24" stroke-width="1.2"/>',
 "jeol": wall(48,42,44,18,"#e9c7a0") + '<rect x="40" y="44" width="16" height="16" fill="#8a3b2a"/>' + roof(48,27,56,17,"#3f5a52","#22332e") + roof(48,10,38,14,"#3f5a52","#22332e") + '<rect x="32" y="24" width="32" height="5" fill="#b5483a"/><circle cx="82" cy="44" r="6" fill="#e0553f" stroke="#5a2a20" stroke-width="1.2"/><path d="M82,36 v-7" stroke="#4a4038" stroke-width="1.4"/><path d="M24,62 h48 l5,6 h-58 Z" fill="#b9b0a0" stroke="#7d7568" stroke-width="1.2"/>',
 "sikdang": wall(48,36,62,24) + '<rect x="22" y="42" width="24" height="18" fill="#c9a06a" stroke="#6b4528" stroke-width="1.2"/><path d="M22,42 h24 v6 q-3,4 -6,0 q-3,4 -6,0 q-3,4 -6,0 q-3,4 -6,0 Z" fill="#c8402f"/><ellipse cx="63" cy="53" rx="12" ry="5" fill="#fff8e4" stroke="#6b4528" stroke-width="1.4"/><path d="M53,52 q10,-10 20,0" fill="#e07a3a"/><path d="M58,42 q-3,-5 0,-8 M66,42 q-3,-5 0,-8" stroke="#8a8174" stroke-width="1.6" fill="none"/>' + roof(48,16,66,20,"#6b4528","#3f2815"),
 "jeong": '<path d="M14,66 h68" stroke="#7d7568" stroke-width="3"/><rect x="28" y="28" width="44" height="4" fill="#4a5058"/><path d="M31,32 v34 M69,32 v34" stroke="#4a5058" stroke-width="3"/><rect x="34" y="36" width="32" height="18" fill="#cfe4ea" opacity=".85"/><rect x="36" y="54" width="28" height="4" fill="#8a5a34"/><path d="M84,66 V20" stroke="#4a5058" stroke-width="3"/><circle cx="84" cy="18" r="11" fill="#2f5fa5" stroke="#1d3b68" stroke-width="1.6"/><rect x="78" y="14" width="12" height="7" rx="2" fill="#fff"/><circle cx="81" cy="22" r="1.6" fill="#fff"/><circle cx="87" cy="22" r="1.6" fill="#fff"/>',
 "gang": '<path d="M4,62 Q26,54 48,62 T92,60" stroke="#8fb4c4" stroke-width="13" fill="none"/><path d="M8,60 q6,-4 12,0 M44,63 q6,-4 12,0 M70,60 q6,-4 12,0" stroke="#eef6f7" stroke-width="2" fill="none"/><path d="M8,52 Q48,12 88,52" fill="none" stroke="#6b4528" stroke-width="7"/><path d="M8,52 Q48,12 88,52" fill="none" stroke="#a9743f" stroke-width="3.6"/><path d="M18,44 v-11 M33,35 v-12 M48,32 v-12 M63,35 v-12 M78,44 v-11" stroke="#6b4528" stroke-width="3"/><path d="M18,34 Q48,10 78,34" stroke="#6b4528" stroke-width="2" fill="none"/>',
 "museum": '<path d="M12,32 L48,10 L84,32 Z" fill="#cfd5da" stroke="#5f6670" stroke-width="1.8"/><circle cx="48" cy="24" r="5" fill="#e8b872" stroke="#5a3b24" stroke-width="1.2"/><rect x="14" y="32" width="68" height="5" fill="#b9c1c8" stroke="#5f6670" stroke-width="1.2"/>' + "".join(f'<rect x="{x}" y="38" width="8" height="21" fill="#eef1f3" stroke="#5f6670" stroke-width="1.2"/>' for x in (18, 34, 54, 70)) + '<rect x="44" y="42" width="8" height="17" fill="#5f6670"/><path d="M8,60 h80 v5 h-80 Z" fill="#b9c1c8" stroke="#5f6670" stroke-width="1.2"/>',
 "sijang": "".join(f'<path d="M{x},30 h{w} l5,14 h-{w+10} Z" fill="{c}" stroke="#5a3b24" stroke-width="1.4"/><path d="M{x+w/4:.0f},30 l-2,14 M{x+w/2:.0f},30 v14 M{x+3*w/4:.0f},30 l2,14" stroke="#fff3df" stroke-width="3"/><rect x="{x}" y="44" width="{w}" height="18" fill="#a9743f" stroke="#5a3b24" stroke-width="1.4"/>' for x, w, c in [(8,34,"#c8402f"),(54,34,"#2f6a9a")]) + '<circle cx="17" cy="46" r="5" fill="#8fbf6a"/><circle cx="26" cy="45" r="5" fill="#7fae5a"/><circle cx="35" cy="46" r="5" fill="#9fca78"/><path d="M60,47 q8,-5 14,0 q-6,5 -14,0 M74,47 l5,-3 v6 Z" fill="#9fb4c4" stroke="#4f6270" stroke-width="1"/>',
}
for k, g in PL.items(): (OUT / f"{k}.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="288" height="216" viewBox="0 0 96 72">{g}</svg>', encoding="utf-8")
print(f"land + {len(PL)} places in {OUT}")
