"""Bug reports made with the bug button: fetch them from the phone and list them.
Usage:  python tools/gd_bugs.py            copy the phone's reports to build/bugs and list them (ask before using the phone)
        python tools/gd_bugs.py --clear    the same, then remove them from the phone (only after they're copied)
        python tools/gd_bugs.py --here     just list what's already in build/bugs"""
import json, pathlib, subprocess, sys
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parent.parent; OUT = ROOT / "build" / "bugs"; OUT.mkdir(parents=True, exist_ok=True)
ADB = pathlib.Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb.exe"; PKG = "com.kopus123.tal"
def sh(*a): return subprocess.run([str(ADB), "exec-out", "run-as", PKG, *a], capture_output=True).stdout
if "--here" not in sys.argv:
    names = [n for n in sh("ls", "files/bugs").decode("utf-8", "replace").split() if n.startswith("bug_")]
    stamp = {}
    for n in names:
        data = sh("cat", f"files/bugs/{n}")
        if n.endswith(".json"):
            try: stamp[n[:-5]] = json.loads(data)["when"].replace(":", "").replace(" ", "_")
            except (ValueError, KeyError): stamp[n[:-5]] = "x"
        (OUT / n).write_bytes(data)
    for n in names:   # named by when, so a later batch never overwrites this one
        base, ext = n.rsplit(".", 1)
        if base in stamp: (OUT / n).replace(OUT / f"{stamp[base]}_{n}")
    if "--clear" in sys.argv:
        for n in names:
            base, ext = n.rsplit(".", 1)
            if (OUT / f"{stamp.get(base, 'x')}_{n}").stat().st_size > 0: sh("rm", f"files/bugs/{n}")
for f in sorted(OUT.glob("*.json")):
    d = json.loads(f.read_text(encoding="utf-8"))
    print(f"\n=== {f.stem}   {d['when']}   build {d['build']}   [{d['kind'] or 'no kind'}]\n  {d['chapter']} / {d['place']} / {d['beat'] or 'looking around'}   day {d['day']} {d['time']}"
          + "".join(f"   {k}" for k in ("board", "camera", "keyboard", "busy") if d.get(k)))
    print("  just before:", " | ".join(x.strip() for x in d["log"][-10:]))
    print("  touches:", "; ".join(f"{t[0]:.0f}s ({t[1]},{t[2]}) {t[3]}" for t in d["trail"][-8:]))
    print("  on screen:", " · ".join(d["screen"][:24]))
    if f.with_suffix(".jpg").exists(): print("  picture:", f.with_suffix(".jpg"))
