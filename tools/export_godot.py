"""Copy what the Godot version shares with the web version into godot/.

Usage:  python tools/export_godot.py

  story/*.story               -> godot/story/                 (the same story files; Godot reads them too)
  scene drawings (js/art.js)  -> godot/art/<key>.png          (only the ones a Godot story file uses), 1600x1200
  word pictures (js/icons.js) -> godot/icons/sheet.png + index.json   (every word in world.story, badges included, and
                                 every picture by its own name as '#name';
                                 one sheet, 16 across, 128 px each; index.json maps word -> its square)

The drawings live in JavaScript, so a hidden Chrome/Edge draws them and takes pictures of them
(as PNG, so text in drawings and the web fonts come out exactly as in the web game).
Run it again after changing art, icons or story files.
"""
import http.server, json, pathlib, re, shutil, socketserver, subprocess, sys, threading, html

ROOT = pathlib.Path(__file__).resolve().parent.parent
GODOT = ROOT / "godot"
STORIES = ["world.story", "shed.story"]          # the files the Godot version reads so far
BROWSERS = [r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"]
ICON, COLS = 128, 16
HEAD = """<!doctype html><meta charset="utf-8"><link href="https://fonts.googleapis.com/css2?family=Gowun+Dodum&family=Gowun+Batang&display=swap" rel="stylesheet">
<style>html,body{margin:0;padding:0;background:transparent;overflow:hidden}svg{display:block}</style>
<script src="js/art.js"></script><script src="js/icons.js"></script><script src="js/core/parse.js"></script>"""

LIST = HEAD + """<body><pre id="out">waiting</pre><script>
(async()=>{try{
  const get=f=>fetch('story/'+f).then(r=>r.text());
  const world=parseStory(await get('world.story'),null,'world.story');const arts=new Set();
  for(const f of ARTFILES){const st=parseStory(await get(f),null,f);Object.values(st.places).forEach(p=>{if(p.art&&ART[p.art])arts.add(p.art)})}
  const words=Object.entries(world.words).filter(([w,d])=>d.p&&!d.g).map(([w])=>w).sort().concat(Object.keys(ICON).sort().map(k=>'#'+k));   // '#name' = a picture by its own name (pockets)
  document.getElementById('out').textContent=JSON.stringify({arts:[...arts],words});
}catch(e){document.getElementById('out').textContent='ERROR '+e.stack}})();</script>"""

ART_PAGE = HEAD + """<body><div id="a" style="width:1600px;height:1200px"></div><script>
document.getElementById('a').innerHTML=ART[new URLSearchParams(location.search).get('k')]();
const s=document.querySelector('svg');s.setAttribute('width','1600');s.setAttribute('height','1200');</script>"""

ICON_PAGE = HEAD + """<body><div id="g" style="display:grid;grid-template-columns:repeat(COLS,ICONpx);width:WIDTHpx"></div><script>
(async()=>{const world=parseStory(await fetch('story/world.story').then(r=>r.text()),null,'world.story');
  const words=WORDS,spec=w=>w.startsWith('#')?w.slice(1):world.words[w].p;
  document.getElementById('g').innerHTML=words.map(w=>`<div style="width:ICONpx;height:ICONpx">${iconSVG(spec(w))}</div>`).join('');
  document.querySelectorAll('svg').forEach(s=>{s.setAttribute('width','ICON');s.setAttribute('height','ICON')})})();</script>"""


def main():
    browser = next((b for b in BROWSERS if pathlib.Path(b).exists()), None)
    if not browser: sys.exit("No Chrome or Edge found.")
    handler = lambda *a, **k: http.server.SimpleHTTPRequestHandler(*a, directory=str(ROOT), **k)
    http.server.SimpleHTTPRequestHandler.log_message = lambda *a: None
    srv = socketserver.TCPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{srv.server_address[1]}"
    tmp = [ROOT / "_x_list.html", ROOT / "_x_art.html", ROOT / "_x_icons.html"]
    run = lambda args: subprocess.run([browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--virtual-time-budget=8000",
                                       "--default-background-color=00000000", *args], capture_output=True, text=True, encoding="utf-8", timeout=180)
    try:
        tmp[0].write_text(LIST.replace("ARTFILES", json.dumps([s for s in STORIES if s != "world.story"])), encoding="utf-8")
        dom = run(["--dump-dom", base + "/_x_list.html"]).stdout
        m = re.search(r'<pre id="out">(.*?)</pre>', dom, re.S)
        if not m or not m.group(1).startswith("{"): sys.exit("export failed: " + (m.group(1)[:500] if m else dom[:500]))
        info = json.loads(html.unescape(m.group(1)))

        for d in ["story", "art", "icons"]:
            shutil.rmtree(GODOT / d, ignore_errors=True); (GODOT / d).mkdir(parents=True)
        for s in STORIES: shutil.copy(ROOT / "story" / s, GODOT / "story" / s)

        tmp[1].write_text(ART_PAGE, encoding="utf-8")
        for k in info["arts"]:
            run([f"--screenshot={GODOT / 'art' / (k + '.png')}", "--window-size=1600,1200", f"{base}/_x_art.html?k={k}"])
        words = info["words"]; rows = (len(words) + COLS - 1) // COLS
        tmp[2].write_text(ICON_PAGE.replace("WORDS", json.dumps(words, ensure_ascii=False)).replace("COLS", str(COLS))
                          .replace("WIDTH", str(COLS * ICON)).replace("ICON", str(ICON)), encoding="utf-8")
        run([f"--screenshot={GODOT / 'icons' / 'sheet.png'}", f"--window-size={COLS * ICON},{rows * ICON}", f"{base}/_x_icons.html"])
        (GODOT / "icons" / "index.json").write_text(json.dumps({"size": ICON, "cols": COLS, "words": {w: i for i, w in enumerate(words)}},
                                                              ensure_ascii=False), encoding="utf-8")
    finally:
        srv.shutdown()
        for t in tmp: t.unlink(missing_ok=True)
    missing = [k for k in info["arts"] if not (GODOT / "art" / f"{k}.png").exists()]
    if missing or not (GODOT / "icons" / "sheet.png").exists(): sys.exit(f"export failed: missing {missing or 'icon sheet'}")
    print(f"ok: {len(STORIES)} story files, {len(info['arts'])} drawings, {len(words)} word pictures")


if __name__ == "__main__":
    main()
