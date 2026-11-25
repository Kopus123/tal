"""Record every line in story/*.story with Microsoft neural voices (edge-tts).

Usage:  python tools/build_audio.py                 (record what's new or changed)
        python tools/build_audio.py --plan          (only say what it would record, and the ElevenLabs cost)
        python tools/build_audio.py --only sujin    (ElevenLabs: record just these characters this time)
Characters listed in tools/elevenlabs.json are voiced by ElevenLabs (needs the ELEVENLABS_API_KEY environment
variable; it is never printed). It checks the characters left this month first and won't go over. Until a line's
ElevenLabs clip exists, the line keeps its free voice, so nothing goes silent.
Reads the cast (with voices), every spoken line, choice, sentence tile, phone message and word
straight from the story files. Writes audio/<hash>.mp3 per line plus audio/clips.js.
Only new or changed lines get recorded; clips for lines that no longer exist are deleted.
"""
import argparse, asyncio, hashlib, json, os, pathlib, re, sys, urllib.error, urllib.request
import edge_tts

sys.stdout.reconfigure(encoding="utf-8")

ROOT = pathlib.Path(__file__).resolve().parent.parent
AUDIO = ROOT / "audio"
VOICE_NAMES = {"SunHi": "ko-KR-SunHiNeural", "InJoon": "ko-KR-InJoonNeural", "Hyunsu": "ko-KR-HyunsuMultilingualNeural"}
TOK = re.compile(r"\{([^}|]+)(?:\|[^}]+)?\}")

def split_bar(s):  # must match splitBar() in js/core/parse.js
    out, d, cur = [], 0, ""
    for c in s:
        d += (c == "{") - (c == "}")
        if c == "|" and not d: out.append(cur.strip()); cur = ""
        else: cur += c
    return out + [cur.strip()]

def normalize(s):  # must match normT() in js/audio.js
    s = TOK.sub(r"\1", s).replace("\\n", " ")
    s = re.sub("[📸🏮^♡✖📞🔔💙]", "", s).replace("/", ", ")
    return re.sub(r"\s+", " ", s).strip()

def collect():
    cast, keys = {}, []
    def add(who, text):
        t = normalize(text)
        if t and re.search(r"\w", t):  # "..." alone has nothing to say
            keys.append(f"{who}|{t}")
    files = sorted(list((ROOT / "story").glob("*.story")) + list((ROOT / "story" / "people").glob("*.people")),
                   key=lambda p: (p.name != "world.story", p.name))  # cast first
    for f in files:
        sec = None; join = False
        for raw in f.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            h = re.match(r"^===\s*(\w+)", line)
            if h:
                sec = h.group(1); continue
            if sec == "cast":
                k, _n, _c, v = [p.strip() for p in line.split("|")][:4]
                if v:
                    name, rate, pitch = v.split()
                    cast[k] = (VOICE_NAMES[name], rate, pitch)
            elif sec == "words":
                m = re.match(r"^(.+?)\s*=", line)
                if m: add("word", m.group(1))
            elif sec == "person":
                if m := re.match(r"^ask\s+(\S+)\s+\w+", line):
                    w = m.group(1); c = ord(w[-1]) - 0xAC00
                    add("you", w + ("은" if 0 <= c < 11172 and c % 28 else "는") + "?")
            elif sec == "names":
                add("word", line.split("|")[0].strip())
            elif sec == "evidence":
                parts = [x.strip() for x in line.split("|")]
                if len(parts) >= 5 and parts[4]: add("sign", "|".join(parts[4:]))
                if len(sp := split_bar(line)) > 1 and re.search("[가-힣]", sp[1]): add("sign", sp[1])
                if len(sp) > 4 and sp[4]: add("sign", sp[4])
            elif sec == "questions":
                if len(sp := split_bar(line)) > 1: add("sign", sp[1])
            elif sec == "phone":
                m = re.match(r"^(them|me)(?:@\S+)?\s+\S+\s+(.+)", line)
                if m: add("sign", m.group(2))
                if m := re.match(r"^voice(?:@\S+)?\s+\S+\s+([a-z_]+)\s+(.+)", line):
                    add(m.group(1) if m.group(1) in cast else "sign", m.group(2))
            elif sec == "scene":
                if line.startswith("show:"):
                    continue
                if line.startswith("@"):   # "@build ... | join": the answer is one word, its pieces are never said alone
                    join = bool(re.match(r"^@build\b.*\|\s*join$", line))
                if m := re.match(r"^\*\s+(.+?)\s+->", line):
                    if not m.group(1).startswith("["): add("you", m.group(1))
                elif m := re.match(r"^tiles:\s*(.+)", line):
                    for t in ([] if join else split_bar(m.group(1))): add("you", t)
                elif m := re.match(r"^answer:\s*(.+?)\s+->", line):
                    add("you", ("" if join else " ").join(split_bar(m.group(1))))
                elif m := re.match(r"^([a-z_]+)(?:\[[\w ]+\])?(?:@[a-z]{2})?:\s*(.+)", line):
                    who = m.group(1)
                    add(who if who in cast else "sign", m.group(2))
    add("sujin", "{안녕하세요}!")  # settings voice test
    return cast, list(dict.fromkeys(keys))

def fname(key):
    return hashlib.md5(key.encode("utf-8")).hexdigest()[:10] + ".mp3"

# ---------------------------------------------------------------- ElevenLabs
EL = json.loads((ROOT / "tools" / "elevenlabs.json").read_text(encoding="utf-8"))

def el_voice(key):
    return EL["voices"].get(key.split("|", 1)[0]) if EL.get("enabled", True) else None

def el_name(key):  # the voice, model and speed are part of the name, so changing them re-records
    v = el_voice(key)
    return "el" + hashlib.md5(f"{EL['model']}|{v['id']}|{v['speed']}|{key}".encode("utf-8")).hexdigest()[:10] + ".mp3"

def api_key():
    k = os.environ.get("ELEVENLABS_API_KEY")
    if not k and os.name == "nt":  # set for the account after this window opened
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h: k = winreg.QueryValueEx(h, "ELEVENLABS_API_KEY")[0]
        except OSError: pass
    return k

def el_left(k):
    r = json.load(urllib.request.urlopen(urllib.request.Request("https://api.elevenlabs.io/v1/user/subscription", headers={"xi-api-key": k}), timeout=30))
    return r["character_limit"] - r["character_count"]

def spoken(text):
    return text.replace("~", "").replace("→", ",").replace("↑", "").replace("·", ",")

def el_record(key, k):
    who, text = key.split("|", 1); v = el_voice(key)
    body = json.dumps({"text": spoken(text), "model_id": EL["model"], "language_code": "ko",
                       "voice_settings": {"stability": 0.5, "similarity_boost": 0.75, "speed": v["speed"]}}).encode()
    req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{v['id']}?output_format=mp3_44100_128", data=body,
                                 headers={"xi-api-key": k, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    for attempt in range(3):
        try:
            data = urllib.request.urlopen(req, timeout=90).read()
            (AUDIO / el_name(key)).write_bytes(data); return True
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")[:200]
            if e.code in (401, 402, 403) or "quota" in msg: print(f"ElevenLabs stopped: {e.code} {msg}"); return None
            if attempt == 2: print("FAILED", key, e.code, msg)
        except Exception as e:
            if attempt == 2: print("FAILED", key, e)

async def record(key, cast, sem):
    who, text = key.split("|", 1)
    out = AUDIO / fname(key)
    if out.exists() and out.stat().st_size > 0:
        return False
    voice, rate, pitch = cast.get(who, cast["sign"])
    async with sem:
        for attempt in range(3):
            try:
                await edge_tts.Communicate(spoken(text), voice, rate=rate, pitch=pitch).save(str(out))
                return True
            except Exception as e:
                if attempt == 2: print("FAILED", key, e)
                await asyncio.sleep(1.5)

async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", action="store_true", help="only say what would be recorded")
    ap.add_argument("--only", nargs="*", default=None, help="ElevenLabs: only these characters this time")
    a = ap.parse_args()
    AUDIO.mkdir(exist_ok=True)
    cast, keys = collect()
    el_todo = [k for k in keys if el_voice(k) and not (AUDIO / el_name(k)).exists()]
    if a.only is not None: el_todo = [k for k in el_todo if k.split("|", 1)[0] in a.only]
    cost = sum(len(spoken(k.split("|", 1)[1])) for k in el_todo)
    by = {}
    for k in el_todo: w = k.split("|", 1)[0]; by[w] = by.get(w, 0) + len(spoken(k.split("|", 1)[1]))
    if el_todo:
        print(f"ElevenLabs: {len(el_todo)} lines to record, {cost} characters (" + ", ".join(f"{w} {n}" for w, n in sorted(by.items(), key=lambda x: -x[1])) + ")")
    k = api_key() if el_todo else None
    if el_todo and not k: print("ElevenLabs: no ELEVENLABS_API_KEY set, so these keep their free voices for now"); el_todo = []
    if el_todo:
        left = el_left(k); print(f"ElevenLabs: {left} characters left this month")
        if cost > left: print("ElevenLabs: that's more than is left, so nothing is recorded with it this time (try --only)"); el_todo = []
    if a.plan:
        print(f"(plan only) {sum(1 for x in keys if not (AUDIO / fname(x)).exists())} free-voice clips to record"); return
    sem = asyncio.Semaphore(6)
    made = await asyncio.gather(*(record(k, cast, sem) for k in keys))   # the free voice for every line: the fallback
    el_made = 0
    for i, key in enumerate(el_todo, 1):
        r = el_record(key, k)
        if r is None: break
        el_made += bool(r)
        if i % 20 == 0: print(f"  ElevenLabs {i}/{len(el_todo)}")
    if el_todo: print(f"ElevenLabs: {el_made} recorded")
    def use(x): return el_name(x) if el_voice(x) and (AUDIO / el_name(x)).exists() else fname(x)
    mapping = {x: "audio/" + use(x) for x in keys if (AUDIO / use(x)).exists()}
    keep = set(fname(x) for x in keys) | set(el_name(x) for x in keys if el_voice(x))
    removed = 0
    for f in AUDIO.glob("*.mp3"):
        if f.name not in keep:
            f.unlink(); removed += 1
    (AUDIO / "clips.js").write_text("window.AUDIO=" + json.dumps(mapping, ensure_ascii=False) + ";\n", encoding="utf-8")
    print(f"{len(mapping)}/{len(keys)} clips ready, {sum(1 for x in made if x)} newly recorded, {removed} old clips removed")

if __name__ == "__main__":
    asyncio.run(main())
