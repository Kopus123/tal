"""The playtester: plays a chapter through the real screen with a fingertip, at full speed, and reports every problem
(godot/scripts/tools/playtester.gd explains what it checks). The chapter is split at its "#@" checkpoints and the parts
are played side by side; the story before each part is run through without the screen.
Usage:  python tools/gd_play.py [ROUTE] [--from "Day 1 · the bus"] [--to "Day 2 · the morning"] [--jobs 6] [--show]
--show: one part, on screen. Pictures: build/play (sheet_*.jpg = all of them; bug_*.jpg = one per problem, boxed in red).
The windows are blank and off the screen on purpose (nothing is drawn except the pictures). Each part says what it's
doing in build/play/*/log.txt and is stopped if it goes quiet for 15 seconds."""
import json, math, pathlib, shutil, subprocess, sys, time
from PIL import Image, ImageDraw
sys.stdout.reconfigure(encoding="utf-8")
GODOT = r"C:\Users\2006a\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
ROOT = pathlib.Path(__file__).resolve().parent.parent
out = ROOT / "build" / "play"
av = sys.argv[1:]
def opt(n, d=""):
    if n in av: i = av.index(n); v = av[i + 1]; del av[i:i + 2]; return v
    return d
frm, to, jobs, show = opt("--from"), opt("--to"), int(opt("--jobs", "10")), "--show" in av
av = [a for a in av if not a.startswith("--")]
route = av[0] if av else "ch1"
shutil.rmtree(out, ignore_errors=True); out.mkdir(parents=True, exist_ok=True)
cache = ROOT / "godot" / ".godot" / "global_script_class_cache.cfg"
if not cache.exists() or "Swipe" not in cache.read_text(encoding="utf-8"):
    subprocess.run([GODOT, "--headless", "--path", str(ROOT / "godot"), "--import"], capture_output=True, timeout=600)
swap = ROOT / "godot/tests" / route / "world.story"   # a whole other story, with its own route
marks = [l[2:].strip() for l in (ROOT / "godot/tests" / (route if swap.exists() else "routes") / (route + ".route")).read_text(encoding="utf-8").splitlines() if l.startswith("#@")]
parts = [(a, b) for a, b in zip([""] + marks, marks + [""])]
if frm: parts = parts[[p[0] for p in parts].index(frm):]
if to: parts = parts[:[p[1] for p in parts].index(to) + 1]
if show: parts, jobs = [(parts[0][0], parts[-1][1])], 1
# neighbouring parts are played by one player, as evenly as last time's clock says
hist = ROOT / "build" / "play_times.json"; times = json.loads(hist.read_text(encoding="utf-8")) if hist.exists() else {}
cost = [times.get(route + "|" + p[0], 10) for p in parts]; share = sum(cost) / max(1, min(jobs, len(parts))); groups, acc = [], 0.0
for p, c in zip(parts, cost):
    if groups and acc + c / 2 < share: groups[-1] = (groups[-1][0], p[1]); acc += c
    else: groups.append(p); acc = c
parts = groups; queue = list(parts); running, done, t0 = [], [], time.time()
while queue or running:
    while queue and len(running) < jobs:
        a, b = queue.pop(0); d = out / ("p%02d" % parts.index((a, b))); d.mkdir()
        args = [GODOT, "--path", str(ROOT / "godot"), "--resolution", "1544x720", "--audio-driver", "Dummy", "--disable-vsync"]
        if not show: args += ["--position", "-6000,-6000"]
        f = open(d / "log.txt", "wb")
        running.append({"p": subprocess.Popen(args + ["--", "--play", d.as_posix(), route, b or "-", a] + (["--show"] if show else []) + (["--large"] if parts.index((a, b)) % 2 else []) + (["--story", "res://tests/" + route] if swap.exists() else []), stdout=f, stderr=subprocess.STDOUT), "d": d, "f": f, "size": 0, "since": time.time(), "start": time.time(), "part": (a, b), "why": ""})
    time.sleep(0.1)
    for r in running[:]:
        n = (r["d"] / "log.txt").stat().st_size
        if n != r["size"]: r["size"], r["since"] = n, time.time()
        if r["p"].poll() is None:
            if b"Failed to load script" in (r["d"] / "log.txt").read_bytes()[:20000]: r["why"] = "a script doesn't compile"
            elif time.time() - r["since"] > 15: r["why"] = "it hung (nothing happened for 15 s)"
            elif time.time() - r["start"] > 240: r["why"] = "over 4 minutes"
            if not r["why"]: continue
            r["p"].kill(); r["p"].wait()
        r["f"].close(); running.remove(r); done.append(r)
        if "compile" in r["why"]: queue.clear()
wall = time.time() - t0
merged, tot, ok = {}, {"taps": 0, "swipes": 0, "screens": 0, "shots": 0}, True
for r in sorted(done, key=lambda r: r["d"].name):
    log = (r["d"] / "log.txt").read_text(encoding="utf-8", errors="replace"); rep = r["d"] / "report.json"
    if not rep.exists():
        ok = False; print("PART \"%s\" %s\n%s\n" % (r["part"][0] or "start", "STOPPED: " + r["why"] if r["why"] else "ended early", log[-900:])); continue
    j = json.loads(rep.read_text(encoding="utf-8")); ok = ok and j["ok"]
    for k in tot: tot[k] += j[k]
    for k, v in j["parts"].items(): times[route + "|" + k] = v
    for i in j["issues"]:
        k = i["kind"] + "|" + i["text"]
        if k in merged: merged[k]["n"] += i["n"]
        else:
            if i["shot"]: i["shot"] = r["d"].name + "/" + i["shot"]
            merged[k] = i
rank = ["stuck", "error", "missing", "dead", "covered", "scroll", "offscreen", "overlap", "cut", "small", "slow"]
iss = sorted(merged.values(), key=lambda i: (rank.index(i["kind"]) if i["kind"] in rank else 99, -i["n"]))
L = ["PLAYED %s: %s in %.0f s (%d parts) · %d taps · %d swipes · %d screens · %d pictures · %d kinds of problem" % (route, "to the end" if ok else "NOT TO THE END", wall, len(done), tot["taps"], tot["swipes"], tot["screens"], tot["shots"], len(iss))]
for i in iss: L.append("[%s] %s%s\n      first at: %s   %s" % (i["kind"], i["text"], "  (x%d)" % i["n"] if i["n"] > 1 else "", i["where"], i["shot"]))
hist.write_text(json.dumps(times, ensure_ascii=False), encoding="utf-8")
(out / "report.txt").write_text("\n".join(L), encoding="utf-8"); print("\n".join(L))
shots = sorted(out.glob("p*/s[0-9]*.jpg")); W, H, C, R = 386, 180, 4, 6
for p in range(math.ceil(len(shots) / (C * R))):
    sh = Image.new("RGB", (W * C, (H + 14) * R), "#222"); d = ImageDraw.Draw(sh)
    for i, f in enumerate(shots[p * C * R:(p + 1) * C * R]):
        x, y = i % C * W, i // C * (H + 14)
        try: sh.paste(Image.open(f).resize((W, H)), (x, y + 14))
        except OSError: pass
        d.text((x + 2, y + 1), (f.parent.name + " " + f.stem).encode("ascii", "replace").decode(), fill="#fff")
    sh.save(out / f"sheet_{p + 1:02d}.jpg", quality=88)
sys.exit(0 if ok and not iss else 1)
