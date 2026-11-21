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
FREE = ["village.story", "jobs.story", "encounters.story"]   # the free days: villagers are drawn live, not painted in
STORIES = ["world.story", "prologue.story", "ch1.story", "village.story", "jobs.story", "encounters.story", "shed.story"]
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
  const live=new Set();
  for(const f of ARTFILES){const st=parseStory(await get(f),null,f);Object.values(st.places).forEach(p=>{if(p.art&&ART[p.art]){arts.add(p.art);if(FREEFILES.includes(f))live.add(p.art)}});
    Object.values(st.examines).forEach(x=>{[x.art,x.compare].forEach(k=>{if(k&&ART[k])arts.add(k)})});
    if(Object.values(st.nodes).some(n=>n.type==='photo'))arts.add('photo')}
  const cast=Object.entries(world.cast).filter(([k,c])=>c.look).map(([k])=>k);
  const people=world.peopleFiles.map(p=>p.id);
  const words=Object.entries(world.words).filter(([w,d])=>d.p&&!d.g).map(([w])=>w).sort().concat(Object.keys(ICON).sort().map(k=>'#'+k));   // '#name' = a picture by its own name (pockets)
  document.getElementById('out').textContent=JSON.stringify({arts:[...arts],live:[...live],words,cast,people});
}catch(e){document.getElementById('out').textContent='ERROR '+e.stack}})();</script>"""

ART_PAGE = HEAD + """<body><div id="a" style="width:1600px;height:1200px"></div><script>
const q=new URLSearchParams(location.search),k=q.get('k');PERSON_OFF=q.get('live')==='1';
document.getElementById('a').innerHTML=k==='photo'?`<svg class="art" viewBox="0 0 300 220">${DEFS}${photoArt()}</svg>`:ART[k]();
const s=document.querySelector('svg');s.setAttribute('width','1600');s.setAttribute('height','1200');s.setAttribute('preserveAspectRatio','xMidYMid slice');</script>"""

## portraits: one row per cast member with a look, one column per face; then the standing figures of the villagers
FACES = ["neutral", "happy", "worried", "surprised", "sad"]
PEOPLE_PAGE = HEAD + """<script src="js/people.js"></script><body><div id="g"></div><script>
(async()=>{const world=parseStory(await fetch('story/world.story').then(r=>r.text()),null,'world.story');ST={cast:world.cast};
  const cast=CAST,people=PEOPLE,faces=FACES,g=document.getElementById('g');
  g.innerHTML=cast.map(k=>`<div style="display:flex">${faces.map(f=>`<div style="width:200px;height:200px">${portrait(world.cast[k].look,f)}</div>`).join('')}</div>`).join('')
    +`<div style="display:flex">${people.map(k=>`<div style="width:200px;height:424px">${figureSVG(k)}</div>`).join('')}<div style="width:200px;height:200px">${speakerGlyph()}</div></div>`;
  document.querySelectorAll('svg').forEach(s=>{const p=s.parentNode;s.setAttribute('width',p.style.width);s.setAttribute('height',p.style.height)})})();</script>"""

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
        tmp[0].write_text(LIST.replace("ARTFILES", json.dumps([s for s in STORIES if s != "world.story"])).replace("FREEFILES", json.dumps(FREE)), encoding="utf-8")
        dom = run(["--dump-dom", base + "/_x_list.html"]).stdout
        m = re.search(r'<pre id="out">(.*?)</pre>', dom, re.S)
        if not m or not m.group(1).startswith("{"): sys.exit("export failed: " + (m.group(1)[:500] if m else dom[:500]))
        info = json.loads(html.unescape(m.group(1)))

        for d in ["story", "art", "icons"]:
            shutil.rmtree(GODOT / d, ignore_errors=True); (GODOT / d).mkdir(parents=True)
        for s in STORIES: shutil.copy(ROOT / "story" / s, GODOT / "story" / s)
        shutil.copytree(ROOT / "story" / "people", GODOT / "story" / "people")
        # voices: the recorded clips, and the index from audio/clips.js ("who|line" -> file)
        clips = json.loads((ROOT / "audio" / "clips.js").read_text(encoding="utf-8").split("=", 1)[1].strip().rstrip(";"))
        (GODOT / "voice").mkdir(exist_ok=True)
        for k, f in clips.items():
            src = ROOT / f
            if src.exists() and not (GODOT / "voice" / src.name).exists(): shutil.copy(src, GODOT / "voice" / src.name)
        (GODOT / "voice" / "index.json").write_text(json.dumps({k: pathlib.Path(f).name for k, f in clips.items()}, ensure_ascii=False), encoding="utf-8")
        shutil.rmtree(GODOT / "tests" / "routes", ignore_errors=True); shutil.copytree(ROOT / "tests", GODOT / "tests" / "routes", ignore=shutil.ignore_patterns("saves", "*.json"))

        tmp[1].write_text(ART_PAGE, encoding="utf-8")
        for k in info["arts"]:
            run([f"--screenshot={GODOT / 'art' / (k + '.png')}", "--window-size=1600,1200", f"{base}/_x_art.html?k={k}"])
        for k in info["live"]:   # free days: the same place with nobody painted in (the villagers are drawn live)
            run([f"--screenshot={GODOT / 'art' / (k + '_live.png')}", "--window-size=1600,1200", f"{base}/_x_art.html?k={k}&live=1"])
        pp = ROOT / "_x_people.html"; tmp.append(pp)
        pp.write_text(PEOPLE_PAGE.replace("CAST", json.dumps(info["cast"])).replace("PEOPLE", json.dumps(info["people"])).replace("FACES", json.dumps(FACES)), encoding="utf-8")
        h = len(info["cast"]) * 200 + 424
        run([f"--screenshot={GODOT / 'art' / 'people.png'}", f"--window-size={max(5, len(info['people']) + 1) * 200},{h}", f"{base}/_x_people.html"])
        (GODOT / "art" / "people.json").write_text(json.dumps({"faces": FACES, "cast": info["cast"], "figures": info["people"], "face": 200, "fig_w": 200, "fig_h": 424},
                                                                ensure_ascii=False), encoding="utf-8")
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
    print(f"ok: {len(STORIES)} story files, {len(info['arts'])} drawings (+{len(info['live'])} without people), {len(info['cast'])} faces, {len(info['people'])} figures, {len(words)} word pictures")


if __name__ == "__main__":
    main()
