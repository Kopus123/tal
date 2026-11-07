"""Record every line in story/*.story with Microsoft neural voices (edge-tts).

Usage:  python tools/build_audio.py
Reads the cast (with voices), every spoken line, choice, sentence tile, phone message and word
straight from the story files. Writes audio/<hash>.mp3 per line plus audio/clips.js.
Only new or changed lines get recorded; clips for lines that no longer exist are deleted.
"""
import asyncio, hashlib, json, pathlib, re
import edge_tts

ROOT = pathlib.Path(__file__).resolve().parent.parent
AUDIO = ROOT / "audio"
VOICE_NAMES = {"SunHi": "ko-KR-SunHiNeural", "InJoon": "ko-KR-InJoonNeural", "Hyunsu": "ko-KR-HyunsuMultilingualNeural"}
TOK = re.compile(r"\{([^}|]+)(?:\|[^}]+)?\}")

def normalize(s):  # must match normT() in js/engine.js
    s = TOK.sub(r"\1", s).replace("\\n", " ")
    s = re.sub("[📸🏮^♡✖📞🔔💙]", "", s).replace("/", ", ")
    return re.sub(r"\s+", " ", s).strip()

def collect():
    cast, keys = {}, []
    def add(who, text):
        t = normalize(text)
        if t:
            keys.append(f"{who}|{t}")
    for f in sorted((ROOT / "story").glob("*.story")):
        sec = None
        for raw in f.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            h = re.match(r"^===\s*(\w+)", line)
            if h:
                sec = h.group(1); continue
            if sec == "cast":
                k, _n, _c, v = [p.strip() for p in line.split("|")]
                if v:
                    name, rate, pitch = v.split()
                    cast[k] = (VOICE_NAMES[name], rate, pitch)
            elif sec == "words":
                m = re.match(r"^(.+?)\s*=", line)
                if m: add("word", m.group(1))
            elif sec == "phone":
                m = re.match(r"^(them|me)\s+\S+\s+(.+)", line)
                if m: add("sign", m.group(2))
            elif sec == "scene":
                if m := re.match(r"^\*\s+(.+?)\s+->", line):
                    if not m.group(1).startswith("["): add("you", m.group(1))
                elif m := re.match(r"^tiles:\s*(.+)", line):
                    for t in m.group(1).split("|"): add("you", t)
                elif m := re.match(r"^answer:\s*(.+?)\s+->", line):
                    add("you", " ".join(t.strip() for t in m.group(1).split("|")))
                elif m := re.match(r"^([a-z_]+):\s*(.+)", line):
                    who = m.group(1)
                    add(who if who in cast else "sign", m.group(2))
    add("sujin", "{안녕하세요}!")  # settings voice test
    return cast, list(dict.fromkeys(keys))

def fname(key):
    return hashlib.md5(key.encode("utf-8")).hexdigest()[:10] + ".mp3"

async def record(key, cast, sem):
    who, text = key.split("|", 1)
    out = AUDIO / fname(key)
    if out.exists() and out.stat().st_size > 0:
        return False
    voice, rate, pitch = cast.get(who, cast["sign"])
    spoken = text.replace("~", "").replace("→", ",").replace("↑", "").replace("·", ",")
    async with sem:
        for attempt in range(3):
            try:
                await edge_tts.Communicate(spoken, voice, rate=rate, pitch=pitch).save(str(out))
                return True
            except Exception as e:
                if attempt == 2: print("FAILED", key, e)
                await asyncio.sleep(1.5)

async def main():
    AUDIO.mkdir(exist_ok=True)
    cast, keys = collect()
    sem = asyncio.Semaphore(6)
    made = await asyncio.gather(*(record(k, cast, sem) for k in keys))
    mapping = {k: "audio/" + fname(k) for k in keys if (AUDIO / fname(k)).exists()}
    keep = set(fname(k) for k in keys)
    removed = 0
    for f in AUDIO.glob("*.mp3"):
        if f.name not in keep:
            f.unlink(); removed += 1
    (AUDIO / "clips.js").write_text("window.AUDIO=" + json.dumps(mapping, ensure_ascii=False) + ";\n", encoding="utf-8")
    print(f"{len(mapping)}/{len(keys)} clips ready, {sum(1 for x in made if x)} newly recorded, {removed} old clips removed")

asyncio.run(main())
