"""Random play: a bot taps around the game at random and reports anything that breaks.

Usage:  python tools/fuzz.py                      (6 runs of 150 taps from every checkpoint in tests/ch1.route)
        python tools/fuzz.py --runs 20 --taps 300 (longer)
        python tools/fuzz.py --seed 7             (a different set of random runs)
        python tools/fuzz.py --only "Free days · the village"   (just one checkpoint)

It plays the solution route (tests/ch1.route) in a hidden phone-sized Chrome window, and at every
'#@' checkpoint stops to tap around at random. After every tap it checks for things that should never
happen: errors, nothing to tap, text off the screen, buttons on top of each other, raw markup on screen,
the clock going backwards, standing inside a closed place, a save that doesn't load back the same.

Runs are seeded, so the same command finds the same problems. Each problem is printed with the checkpoint,
the seed, and the last taps that led to it. Exit code 1 if anything was found.
"""
import argparse, functools, html, http.server, pathlib, re, subprocess, sys, tempfile, threading, urllib.parse

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from playtest import Quiet, browser, ROOT  # same server and browser as the route tests

sys.stdout.reconfigure(encoding="utf-8")

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--route", default="ch1")
    ap.add_argument("--runs", type=int, default=6, help="runs from each checkpoint")
    ap.add_argument("--taps", type=int, default=150, help="taps per run")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--only", default="", help="just this checkpoint label")
    ap.add_argument("--width", type=int, default=375)
    ap.add_argument("--height", type=int, default=812)
    a = ap.parse_args()
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=str(ROOT)))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    q = urllib.parse.urlencode({"autotest": a.route, "fuzz": f"{a.seed},{a.runs},{a.taps}", **({"only": a.only} if a.only else {})})
    url = f"http://127.0.0.1:{srv.server_address[1]}/index.html?{q}"
    with tempfile.TemporaryDirectory() as prof:
        r = subprocess.run([browser(), "--headless=new", "--disable-gpu", "--no-first-run", "--mute-audio",
                            f"--window-size={a.width},{a.height}", "--hide-scrollbars",
                            f"--user-data-dir={prof}", "--virtual-time-budget=7200000", "--dump-dom", url],
                           capture_output=True, text=True, encoding="utf-8", timeout=1800)
    srv.shutdown()
    m = re.search(r'<pre id="autotest"[^>]*>(.*?)</pre>', r.stdout, re.S)
    if not m:
        print("FAIL: the bot never reported back (the page may have crashed or run out of time).")
        print(r.stderr[-2000:]); sys.exit(1)
    report = html.unescape(m.group(1))
    print(report)
    sys.exit(0 if report.startswith("PASS") else 1)

if __name__ == "__main__":
    main()
