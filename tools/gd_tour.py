"""Run the Godot screenshot tour on the laptop (a window opens while it plays) and save the pictures in build/shots.
Usage:  python tools/gd_tour.py [ROUTE] [STOP]      e.g.  python tools/gd_tour.py ch1 "Day 1 · the museum" """
import pathlib, shutil, subprocess, sys
sys.stdout.reconfigure(encoding="utf-8")
GODOT = r"C:\Users\2006a\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
ROOT = pathlib.Path(__file__).resolve().parent.parent
out = ROOT / "build" / "shots"; shutil.rmtree(out, ignore_errors=True)
args = [GODOT, "--path", str(ROOT / "godot"), "--resolution", "1544x720", "--", "--shots", out.as_posix(), *sys.argv[1:]]
try:
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=400)
    txt = r.stdout + r.stderr
except subprocess.TimeoutExpired as e:
    txt = "TIMED OUT (the window was closed)"
print("\n".join(l for l in txt.splitlines() if "shots:" in l or "FAIL" in l or "SCRIPT ERROR" in l or "TIMED" in l or "ERROR" in l)[:3000])
print("\n".join(sorted(p.name for p in out.glob("*.png"))))
