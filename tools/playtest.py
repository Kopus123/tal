"""Play every route in tests/ automatically in a hidden Chrome or Edge window.

Usage:  python tools/playtest.py            (all routes)
        python tools/playtest.py ch1        (just one)

Starts a tiny local web server, opens index.html?autotest=<routes> headless, and prints the result.
Exit code 1 if any route fails, with the step, the scene it was in, and why.
"""
import functools, http.server, pathlib, re, shutil, subprocess, sys, tempfile, threading, html

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parent.parent
BROWSERS = [r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            "google-chrome", "chromium", "msedge"]

class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass

def browser():
    for b in BROWSERS:
        if pathlib.Path(b).exists() or shutil.which(b): return b
    sys.exit("No Chrome or Edge found.")

def main():
    routes = sys.argv[1:] or sorted(p.stem for p in (ROOT / "tests").glob("*.route"))
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=str(ROOT)))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{srv.server_address[1]}/index.html?autotest={','.join(routes)}"
    with tempfile.TemporaryDirectory() as prof:
        r = subprocess.run([browser(), "--headless=new", "--disable-gpu", "--no-first-run", "--mute-audio",
                            f"--user-data-dir={prof}", "--virtual-time-budget=600000", "--dump-dom", url],
                           capture_output=True, text=True, encoding="utf-8", timeout=600)
    srv.shutdown()
    m = re.search(r'<pre id="autotest"[^>]*>(.*?)</pre>', r.stdout, re.S)
    if not m:
        print("FAIL: the test never reported back (the page may have crashed).")
        print(r.stderr[-2000:]); sys.exit(1)
    report = html.unescape(m.group(1))
    print(report)
    sys.exit(0 if report.startswith("PASS") else 1)

if __name__ == "__main__":
    main()
