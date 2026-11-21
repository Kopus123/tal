"""Run the Godot version's tests headless (no window).
Usage:  python tools/gd_test.py                 every test: routes (all .route files), shed, hangul
        python tools/gd_test.py routes ch1      just some routes"""
import pathlib, subprocess, sys
sys.stdout.reconfigure(encoding="utf-8")
GODOT = r"C:\Users\2006a\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
ROOT = pathlib.Path(__file__).resolve().parent.parent
def run(script, args=()):
    try:
        r = subprocess.run([GODOT, "--headless", "--path", str(ROOT / "godot"), "-s", script, "--", *args], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    except subprocess.TimeoutExpired:
        print(f"{script}: timed out"); return False
    keep = [l for l in (r.stdout + r.stderr).splitlines() if l.strip() and not l.startswith("Godot Engine") and "at: " not in l and "GDScript backtrace" not in l and not l.strip().startswith("[")]
    print("\n".join(keep[:60]))
    return r.returncode == 0
a = sys.argv[1:]
if a and a[0] == "routes": ok = run("tests/test_routes.gd", a[1:])
else: ok = all([run("tests/test_routes.gd"), run("tests/test_hangul.gd")])
sys.exit(0 if ok else 1)
