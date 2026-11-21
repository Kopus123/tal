"""Check Godot scripts for errors without opening anything.
Usage:  python tools/gd_check.py [res-path ...]      (default: the engine files)"""
import pathlib, subprocess, sys
sys.stdout.reconfigure(encoding="utf-8")
GODOT = r"C:\Users\2006a\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
ROOT = pathlib.Path(__file__).resolve().parent.parent
scripts = sys.argv[1:] or ["scripts/core/story.gd", "scripts/core/game.gd", "scripts/core/hangul.gd"]
bad = 0
for s in scripts:
    try:
        r = subprocess.run([GODOT, "--headless", "--path", str(ROOT / "godot"), "--check-only", "-s", s], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)
        out = (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired:
        print(f"{s}: timed out"); bad += 1; continue
    lines = out.splitlines()
    errs = [l.strip() for i, l in enumerate(lines) if ("SCRIPT ERROR" in l or "GDScript::reload" in l) and "Identifier not found: Game" not in l
            and not (i > 0 and "GDScript::reload" in l and "Identifier not found: Game" in lines[i - 1])]
    if errs: bad += 1; print("== " + s); print("\n".join(errs[:6]))
    else: print("ok " + s)
sys.exit(1 if bad else 0)
