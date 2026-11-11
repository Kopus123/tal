"""Check the story files for mistakes before anything ships.

Usage:  python tools/check_story.py

Errors (exit code 1): a jump to a scene that doesn't exist, a {word} with no notebook entry,
a picture that isn't drawn, evidence that doesn't exist, a speaker who isn't in the cast, ...
Warnings: flags that are checked but never set, scenes nothing leads to, evidence nobody hands
you, lines that have no recorded voice yet (run tools/build_audio.py).
"""
import json, pathlib, re, sys
sys.stdout.reconfigure(encoding="utf-8")

ROOT = pathlib.Path(__file__).resolve().parent.parent
STORY = ROOT / "story"
TOK = re.compile(r"\{([^}|]+)(?:\|([^}]+))?\}")
ERR, WARN = [], []

def err(f, ln, msg): ERR.append(f"{f}:{ln}: {msg}")
def warn(f, ln, msg): WARN.append(f"{f}:{ln}: {msg}")

def ids_in(s): return [m.group(2) or m.group(1) for m in TOK.finditer(s)]

def js_keys(path, start, end=None):
    """keys of a JS object literal like `const ICON={ key:..., }`"""
    src = (ROOT / path).read_text(encoding="utf-8")
    i = src.index(start)
    body = src[i:src.index(end, i)] if end else src[i:]
    return set(re.findall(r"(?:^|[\s,{])([a-z_]\w*):", body, re.M))

ICONS = js_keys("js/icons.js", "const ICON={", "const BADGE")
ARTS = js_keys("js/art.js", "const ART={", "};")
MODS = {"past", "future", "not"}

def parse(path):
    """Mirror of parseStory() in js/engine.js, keeping line numbers."""
    d = dict(meta={}, cast={}, words={}, places={}, scenes={}, deduce=[], evidence={}, phones={},
             hints=[], chapters=[], pins=[], jumps=[], flags_set=[], flags_read=[], gives=[], shows=[],
             speakers=[], tokens=[], placefx=[], statements={}, pairs=[], examines={}, exrefs=[])
    sec = cur = scene = None
    count = 0
    def cond_flags(c, ln):
        if not c: return
        for t in c.split("&"):
            t = t.strip().lstrip("!")
            if t and not t.startswith("@") and t != "allSolved": d["flags_read"].append((t, ln))
            elif t.startswith("@"): d["placefx"].append((t[1:], ln))
    def target(t, ln):
        m = re.match(r"^(.+?)\s*\?\s*(\S+)\s*:\s*(\S+)$", t)
        if m:
            cond_flags(m.group(1), ln); d["jumps"].append((m.group(2), ln, scene)); d["jumps"].append((m.group(3), ln, scene))
        else: d["jumps"].append((t.strip(), ln, scene))
    def effects(s, ln):
        for part in [x.strip() for x in s.split(";") if x.strip()]:
            m = re.match(r"^(\w+)\s+(.+?)(?:\s+if\s+(\S+))?$", part)
            if not m: err(path.name, ln, f"effect not understood: {part}"); continue
            k, a, c = m.groups(); cond_flags(c, ln)
            vals = [x.strip() for x in a.split(",")]
            if k == "set": d["flags_set"] += [(v, ln) for v in vals]
            elif k in ("give", "have"): d["gives"] += [(v, ln) for v in vals]
            elif k == "place": d["placefx"].append((a.strip(), ln))
            elif k == "statement":
                if a.strip() in d["statements"]: err(path.name, ln, f"statement '{a.strip()}' saved twice")
                d["statements"][a.strip()] = ln
            elif k == "mixup":
                parts = [x.strip() for x in a.split("/")]
                if len(parts) != 2: err(path.name, ln, "mixup needs RIGHT / HEARD")
                d["tokens"] += [(x, ln) for x in parts]
            elif k in ("unset", "learn", "led", "toast"): pass
            else: err(path.name, ln, f"unknown effect '{k}'")
    def tokens(s, ln, raw=True):  # raw=False for English text that mentions Korean names
        d["tokens"] += [(t, ln) for t in ids_in(s)]
        if raw: d.setdefault("raw", []).append((TOK.sub(" ", s), ln))
    def beat(ln):
        nonlocal count
        count += 1
        d["scenes"][scene]["beats"] = count
    for ln, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"): continue
        h = re.match(r"^===\s*(\w+)\s*(.*)$", line)
        if h:
            sec, arg = h.group(1), h.group(2).strip()
            if sec == "scene":
                if arg in d["scenes"]: err(path.name, ln, f"scene '{arg}' defined twice")
                scene = arg; count = 0; d["scenes"][arg] = dict(ln=ln, beats=0)
            elif sec == "place": cur = d["places"][arg] = dict(ln=ln, spots=[], first=None, always=None, art=None)
            elif sec == "phone": cur = d["phones"][arg] = dict(ln=ln)
            elif sec == "examine": cur = d["examines"][arg] = dict(ln=ln, art=None, keys=0)
            continue
        if sec == "meta":
            k, _, v = line.partition(" "); d["meta"][k] = (v.strip(), ln)
        elif sec == "cast":
            d["cast"][line.split("|")[0].strip()] = ln
        elif sec == "chapters":
            p = [x.strip() for x in line.split("|")]
            d["chapters"].append(dict(id=p[0], file=p[3] if len(p) > 3 else "", ln=ln))
        elif sec == "map":
            m = re.match(r"^pin\s+(\S+)", line)
            if m: d["pins"].append((m.group(1), ln))
        elif sec == "words":
            m = re.match(r"^(.+?)\s*=\s*(.+)$", line)
            if m: d["words"][m.group(1)] = (m.group(2).strip(), ln)
        elif sec == "hints":
            m = re.match(r"^if\s+(\S+):", line)
            if m: cond_flags(m.group(1), ln)
        elif sec == "deduce":
            m = re.match(r"^(\w+)(\s+final)?\s+if\s+(\S+)\s*\|\s*(.+?)\s*\|\s*(.+)$", line)
            if not m: err(path.name, ln, "deduction line not understood"); continue
            cond_flags(m.group(3), ln); tokens(m.group(4), ln, False)
            nd = re.search(r"\|\s*needs\s+(.+)$", m.group(5))
            needs = [[y.strip() for y in x.split("/")] for x in nd.group(1).split("+")] if nd else []
            d["deduce"].append(dict(id=m.group(1), final=bool(m.group(2)), c=m.group(3), blanks=ids_in(m.group(4)), needs=needs, ln=ln))
        elif sec == "evidence":
            p = [x.strip() for x in line.split("|")]
            if len(p) < 4: err(path.name, ln, "evidence line needs id | label | picture | description"); continue
            d["evidence"][p[0]] = dict(icon=p[2], ln=ln); tokens(p[1], ln)
            if len(p) > 4: tokens("|".join(p[4:]), ln)
        elif sec == "place":
            if m := re.match(r"^(name|sub|art|first|always|ambient|travel)\s+(.+)$", line):
                cur[m.group(1)] = (m.group(2), ln)
            elif m := re.match(r"^desc\s+(?:if\s+(\S+):\s*)?(.+)$", line): cond_flags(m.group(1), ln)
            elif m := re.match(r'^spot\s+"([^"]+)"\s+([\d.]+)\s+([\d.]+)\s+(->|=>)\s+(.+?)(?:\s+if\s+(\S+))?$', line):
                cond_flags(m.group(6), ln); cur["spots"].append(dict(kind=m.group(4), t=m.group(5), ln=ln))
            elif m := re.match(r"^glow\s+(.+?)\s+[\d.]+\s+[\d.]+", line): d["tokens"].append((m.group(1), ln))
            else: err(path.name, ln, "place line not understood")
        elif sec == "phone":
            if m := re.match(r"^on-open\s+(.+)", line): effects(m.group(1), ln)
            elif m := re.match(r"^voice(?:@(\S+))?\s+\S+\s+([a-z_]+)\s+(.+)", line):
                cond_flags(m.group(1), ln); d["speakers"].append((m.group(2), ln)); tokens(m.group(3), ln)
            elif m := re.match(r"^(day|them|me|sys|note)(?:@(\S+))?\s+(.+)", line):
                cond_flags(m.group(2), ln); tokens(m.group(3), ln, m.group(1) != "note")
            elif not re.match(r"^(name|avatar)\s", line): err(path.name, ln, "phone line not understood")
        elif sec == "examine":
            if m := re.match(r"^compare\s+(\S+)", line):
                if m.group(1) not in ARTS: err(path.name, ln, f"art '{m.group(1)}' isn't drawn in js/art.js")
            elif m := re.match(r"^art\s+(\S+)", line):
                cur["art"] = m.group(1)
                if m.group(1) not in ARTS: err(path.name, ln, f"art '{m.group(1)}' isn't drawn in js/art.js")
            elif re.match(r"^prompt\s", line): pass
            elif m := re.match(r"^detail\s+(\w+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)(\s+key)?\s*\|\s*(.+?)(?:\s+!\s+(.+))?$", line):
                tokens(m.group(6), ln, False)
                if m.group(5): cur["keys"] += 1
                if m.group(7): effects(m.group(7), ln)
            else: err(path.name, ln, "examine line not understood")
        elif sec == "pattern": pass
        elif sec == "meanings":
            d.setdefault("meanings", {})[line.split("|")[0].strip()] = ln
        elif sec == "names":
            d.setdefault("names", {})[line.split("|")[0].strip()] = ln
        elif sec in ("grammar", "endings"): pass
        elif sec == "scene":
            if scene is None: err(path.name, ln, "line outside a scene"); continue
            if line.startswith("~"): beat(ln)
            elif re.match(r"^\(.*\)$", line): pass
            elif line.startswith("!"): effects(line[1:], ln)
            elif m := re.match(r"^\*\s+(.+?)\s+->\s+(.+?)(?:\s+if\s+(\S+))?(?:\s+!\s+(.+))?$", line):
                target(m.group(2), ln); cond_flags(m.group(3), ln)
                if m.group(4): effects(m.group(4), ln)
                if not m.group(1).startswith("["): tokens(m.group(1), ln)
            elif m := re.match(r"^(->|<-)\s*(.+)$", line): target(m.group(2), ln)
            elif m := re.match(r"^@examine\s+(\w+)$", line): beat(ln); d["exrefs"].append((m.group(1), ln))
            elif re.match(r"^@(build|type|camera|photo|present|card|contradict|number)\b", line): beat(ln)
            elif m := re.match(r"^pair:\s*(\S+)\s*\+\s*(\S+)\s+->\s+(.+)$", line):
                d["pairs"] += [(m.group(1), ln), (m.group(2), ln)]; target(m.group(3), ln)
            elif m := re.match(r"^tiles:\s*(.+)$", line): tokens(m.group(1), ln)
            elif m := re.match(r"^answer:\s*(.+?)\s+->\s+(.+)$", line): tokens(m.group(1), ln); target(m.group(2), ln)
            elif m := re.match(r"^miss\s+->\s+(.+)$", line): target(m.group(1), ln)
            elif m := re.match(r"^show:\s*(\S+)\s+->\s+(.+)$", line): d["shows"].append((m.group(1), ln)); target(m.group(2), ln)
            elif m := re.match(r"^([a-z_]+)(?:\[([\w ]+)\])?(?:@([a-z]{2}))?:\s*(.+)$", line):
                beat(ln); d["speakers"].append((m.group(1), ln)); tokens(m.group(4), ln)
                for tag in (m.group(2) or "").split():
                    if tag not in ("neutral", "happy", "worried", "surprised", "sad", "audio"):
                        err(path.name, ln, f"unknown expression '{tag}'")
            else: err(path.name, ln, "scene line not understood")
    return d

def check_icon(spec, f, ln, what):
    parts = spec.split()
    if not parts or parts[0] not in ICONS: err(f, ln, f"{what}: picture '{parts[0] if parts else spec}' isn't drawn in js/icons.js")
    for p in parts[1:]:
        if not (p.startswith("+") and p[1:] in MODS): err(f, ln, f"{what}: unknown badge '{p}'")

def main():
    world = parse(STORY / "world.story")
    chapters = {}
    for c in world["chapters"]:
        fp = STORY / c["file"]
        if not fp.exists(): err("world.story", c["ln"], f"chapter file {c['file']} is missing"); continue
        chapters[c["id"]] = (fp.name, parse(fp))
    words = dict(world["words"])
    for _, (_, d) in chapters.items(): words.update(d["words"])
    cast = set(world["cast"])
    for w, (spec, ln) in words.items():
        if spec != "(grammar)": check_icon(spec, "world.story", ln, w)
    all_places = set()
    for name, d in [("world.story", world)] + list(chapters.values()):
        for t, ln in d["tokens"]:
            if t not in words: err(name, ln, f"{{{t}}} has no entry in the words list")
    for fname, d in chapters.values():
        all_places |= set(d["places"])
        scenes, places = d["scenes"], d["places"]
        evidence = dict(world["evidence"]); evidence.update(d["evidence"])
        for k in ("start", "start-place"):
            if k not in d["meta"]: err(fname, 1, f"meta is missing '{k}'")
        if "start" in d["meta"]: d["jumps"].append((d["meta"]["start"][0], d["meta"]["start"][1], None))
        if "start-place" in d["meta"] and d["meta"]["start-place"][0] not in places:
            err(fname, d["meta"]["start-place"][1], "start-place is not a place in this file")
        # places
        for pid, p in places.items():
            if p.get("art") and p["art"][0] not in ARTS: err(fname, p["art"][1], f"art '{p['art'][0]}' isn't drawn in js/art.js")
            for k in ("first", "always"):
                if p.get(k): d["jumps"].append((p[k][0], p[k][1], None))
            for s in p["spots"]:
                if s["kind"] == "->": d["jumps"].append((s["t"], s["ln"], None)) if "?" not in s["t"] else None
                if s["kind"] == "->" and "?" in s["t"]:
                    m = re.match(r"^(.+?)\s*\?\s*(\S+)\s*:\s*(\S+)$", s["t"])
                    d["jumps"] += [(m.group(2), s["ln"], None), (m.group(3), s["ln"], None)]
                elif s["kind"] == "=>":
                    m = re.match(r"^place\s+(\S+)", s["t"])
                    if m and m.group(1) not in places: err(fname, s["ln"], f"spot leads to unknown place '{m.group(1)}'")
                    elif not m and s["t"] != "phone": err(fname, s["ln"], f"spot target '{s['t']}' not understood")
        for p, ln in d["placefx"]:
            if p not in places: err(fname, ln, f"unknown place '{p}'")
        # jumps
        reached = set()
        for t, ln, frm in d["jumps"]:
            base, _, n = t.partition(".")
            if base not in scenes: err(fname, ln, f"jump to unknown scene '{t}'"); continue
            if n and (not n.isdigit() or int(n) < 1 or int(n) > scenes[base]["beats"]):
                err(fname, ln, f"'{t}': scene {base} only has {scenes[base]['beats']} beats")
            if base != frm: reached.add(base)
        for sid, s in scenes.items():
            if sid not in reached: warn(fname, s["ln"], f"nothing leads to scene '{sid}'")
            if s["beats"] == 0: err(fname, s["ln"], f"scene '{sid}' has no beats")
        # speakers
        for who, ln in d["speakers"]:
            if who not in cast and who not in d["cast"]: err(fname, ln, f"speaker '{who}' isn't in the cast")
        # evidence
        given = {e for e, _ in d["gives"]}
        for k, ln in d["exrefs"]:
            if k not in d["examines"]: err(fname, ln, f"no '=== examine {k}' in this file")
        for k, ln in d["pairs"]:
            if k not in d["statements"] and k not in evidence: err(fname, ln, f"'{k}' is neither a statement nor evidence")
        for e, ln in d["gives"] + d["shows"]:
            if e not in evidence: err(fname, ln, f"unknown evidence '{e}'")
        for eid, e in d["evidence"].items():
            check_icon(e["icon"], fname, e["ln"], f"evidence {eid}")
            if eid not in given: warn(fname, e["ln"], f"evidence '{eid}' is never handed to you")
        # flags
        auto = {"started"} | {f"solved_{q['id']}" for q in d["deduce"]} | {f"read_{p}" for p in d["phones"]} \
             | {f"readn_{p}" for p in d["phones"]} | {f"vm_{p}" for p in d["phones"]} | {f"st_{x}" for x in d["statements"]} | {f"ev_{e}" for e in evidence}
        setf = {f for f, _ in d["flags_set"]} | auto
        for f, ln in d["flags_read"]:
            if f not in setf: err(fname, ln, f"flag '{f}' is checked but never set, so this can never happen")
        # deductions
        ids = [q["id"] for q in d["deduce"]]
        if len(ids) != len(set(ids)): err(fname, 1, "two deductions share an id")
        if d["deduce"] and not any(q["final"] for q in d["deduce"]): err(fname, 1, "no deduction is marked final, so the chapter can't end")
        for q in d["deduce"]:
            for alts in q["needs"]:
                for x in alts:
                    if x not in d["statements"] and x not in evidence: err(fname, q["ln"], f"deduction {q['id']} needs '{x}', which is neither a statement nor evidence")
            if not q["blanks"]: err(fname, q["ln"], f"deduction {q['id']} has no blanks")
            for b in q["blanks"]:
                for alt in b.split("/") if b not in words else [b]:
                    if alt not in words: err(fname, q["ln"], f"deduction {q['id']}: answer '{alt}' isn't a word")
    meanings = world.get("meanings", {}); names = set(world.get("names", {}))
    for w, (spec, ln) in words.items():
        if spec != "(grammar)" and w not in meanings: WARN.append(f"world.story:{ln}: word '{w}' has no meaning (=== meanings)")
    namerx = re.compile("|".join(sorted(map(re.escape, names), key=len, reverse=True))) if names else None
    for name, d in [("world.story", world)] + list(chapters.values()):
        for text, ln in d.get("raw", []):
            rest = namerx.sub(" ", text) if namerx else text
            left = re.findall(r"[가-힣]+", rest)
            if left: WARN.append(f"{name}:{ln}: Korean you can't tap: {' '.join(left)}")
    for p, ln in world["pins"]:
        if p not in all_places: err("world.story", ln, f"map pin for unknown place '{p}'")
    # voices
    sys.path.insert(0, str(ROOT / "tools"))
    try:
        import build_audio
        _, keys = build_audio.collect()
        clips = ROOT / "audio" / "clips.js"
        have = json.loads(clips.read_text(encoding="utf-8")[len("window.AUDIO="):].rstrip().rstrip(";")) if clips.exists() else {}
        missing = [k for k in keys if k not in have]
        if missing: WARN.append(f"audio: {len(missing)} lines have no recording yet (run python tools/build_audio.py), e.g. {missing[0]}")
    except Exception as e:
        WARN.append(f"audio: couldn't check recordings ({e})")
    for w in WARN: print("warning:", w)
    for e in ERR: print("ERROR:  ", e)
    n_sc = sum(len(d["scenes"]) for _, d in chapters.values())
    print(f"\n{len(chapters)} story files, {n_sc} scenes, {len(words)} words: {len(ERR)} errors, {len(WARN)} warnings")
    sys.exit(1 if ERR else 0)

if __name__ == "__main__":
    main()
