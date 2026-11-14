"""Check the story files for mistakes before anything ships.

Usage:  python tools/check_story.py

Errors (exit code 1): a jump to a scene that doesn't exist, a {word} with no notebook entry,
a picture that isn't drawn, evidence that doesn't exist, a speaker who isn't in the cast, a flag
that is checked but never set, an effect or condition the game doesn't have, ...
Warnings: scenes nothing leads to, evidence nobody hands you, Korean you can't tap, lines that
have no recorded voice yet (run tools/build_audio.py).

What the game understands is read from the game itself, so this file can't fall behind it:
  effects and conditions   the defEffect('name','kind' / defCond('name','kind' lines in js/core/*.js
  sections (=== name)      the case '...' labels in js/core/parse.js
  beats (@name)            the /^@name patterns in js/core/parse.js
  times of day             SLOTS in js/core/world.js
A new effect or condition of an existing KIND needs nothing here. A new kind needs one entry in
EFFECT_KINDS or COND_KINDS below (the checker stops and says so).
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

# ---------------------------------------------------------------- read from the game
ICONS = js_keys("js/icons.js", "const ICON={", "const BADGE")
ARTS = js_keys("js/art.js", "const ART={", "};")
MODS = {"past", "future", "not"}
EXPRESSIONS = {"neutral", "happy", "worried", "surprised", "sad", "audio"}   # faces in js/people.js, plus [audio]

EFFECTS, CONDS = {}, {}          # name -> kind
for _f in sorted((ROOT / "js" / "core").glob("*.js")):
    _src = _f.read_text(encoding="utf-8")
    EFFECTS.update(re.findall(r"^defEffect\('(\w+)','(\w+)'", _src, re.M))
    CONDS.update(re.findall(r"^defCond\('([^']+)','(\w+)'", _src, re.M))
_parser = (ROOT / "js" / "core" / "parse.js").read_text(encoding="utf-8")
SECTIONS = set(re.findall(r"case '(\w+)':", _parser))
BEATS = set(re.findall(r"/\^@(\w+)", _parser))
_slots = re.search(r"const SLOTS=\[([^\]]*)\]", (ROOT / "js" / "core" / "world.js").read_text(encoding="utf-8"))
SLOTS = set(re.findall(r"'(\w+)'", _slots.group(1))) if _slots else set()
if not ({"set", "give"} <= set(EFFECTS) and "@" in CONDS and {"scene", "place"} <= SECTIONS and "build" in BEATS and SLOTS):
    sys.exit("check_story.py could not read the game's rules from js/core (did the def lines or the parser change shape?)")

# ---------------------------------------------------------------- what each kind means
# Every handler gets (d, arg, ln, fname). d collects what a file sets, gives and refers to; the
# cross-checks at the end compare those lists.
AMOUNT = re.compile(r"^[+\-=]?\d+$")

def _fx_flags(d, a, ln, f):
    for v in filter(None, (x.strip() for x in a.split(","))):
        (d["gflags_set"] if v.startswith("g:") else d["flags_set"]).append((v[2:] if v.startswith("g:") else v, ln))
def _fx_evidence(d, a, ln, f): d["gives"] += [(x.strip(), ln) for x in a.split(",") if x.strip()]
def _fx_place(d, a, ln, f): d["placefx"].append((a.strip(), ln))
def _fx_statement(d, a, ln, f):
    if a.strip() in d["statements"]: err(f, ln, f"statement '{a.strip()}' saved twice")
    d["statements"][a.strip()] = ln
def _fx_mixup(d, a, ln, f):
    parts = [x.strip() for x in a.split("/")]
    if len(parts) != 2: err(f, ln, "mixup needs RIGHT / HEARD")
    d["tokens"] += [(x, ln) for x in parts]
def _fx_amount(d, a, ln, f):
    if not AMOUNT.match(a.strip()): err(f, ln, f"'{a}' should be an amount: +500, -200 or =1000")
def _fx_who_amount(d, a, ln, f):
    p = a.split()
    if len(p) != 2 or not AMOUNT.match(p[1]): err(f, ln, f"'{a}' should be WHO and an amount: sujin +1"); return
    d["who_refs"].append((p[0], ln))
def _fx_item(d, a, ln, f):
    m = re.match(r"^([+-]?)(\S+)$", a.strip())
    if not m: err(f, ln, f"'{a}' should be +NAME or -NAME"); return
    if m.group(1) != "-": d["items_given"].append((m.group(2), ln))

EFFECT_KINDS = {"flags": _fx_flags, "unflags": None, "text": None, "place": _fx_place, "evidence": _fx_evidence,
                "statement": _fx_statement, "mixup": _fx_mixup, "amount": _fx_amount, "who_amount": _fx_who_amount, "item": _fx_item}
ADDS_UP = {"amount", "who_amount", "item"}      # these may end in "each time"

def _c_place(d, rest, ln, f): d["placefx"].append((rest, ln))
def _c_slot(d, rest, ln, f):
    if rest not in SLOTS: err(f, ln, f"'{rest}' isn't a time of day ({', '.join(sorted(SLOTS))})")
def _c_gflag(d, rest, ln, f): d["gflags_read"].append((rest, ln))
def _c_who(d, rest, ln, f): d["who_refs"].append((rest, ln))
def _c_item(d, rest, ln, f): d["items_read"].append((rest, ln))

COND_KINDS = {"place": _c_place, "bool": None, "number": None, "slot": _c_slot, "gflag": _c_gflag, "who": _c_who, "item": _c_item}

for _name, _kind in EFFECTS.items():
    if _kind not in EFFECT_KINDS: sys.exit(f"check_story.py: effect '{_name}' has the new kind '{_kind}'. Add it to EFFECT_KINDS.")
for _name, _kind in CONDS.items():
    if _kind not in COND_KINDS: sys.exit(f"check_story.py: condition '{_name}' has the new kind '{_kind}'. Add it to COND_KINDS.")

# flags the game switches on by itself: prefix -> which list of ids it follows
AUTO_FLAGS = [("solved_", "deduce"), ("read_", "phones"), ("readn_", "phones"), ("vm_", "phones"),
              ("st_", "statements"), ("ev_", "evidence"), ("ex_", "details")]

# ---------------------------------------------------------------- one story file
def parse(path):
    """Mirror of parseStory() in js/core/parse.js, keeping line numbers."""
    f = path.name
    d = dict(meta={}, cast={}, words={}, places={}, scenes={}, deduce=[], evidence={}, phones={},
             hints=[], chapters=[], pins=[], jumps=[], flags_set=[], flags_read=[], gives=[], shows=[],
             speakers=[], tokens=[], placefx=[], statements={}, pairs=[], examines={}, exrefs=[],
             gflags_set=[], gflags_read=[], who_refs=[], items_given=[], items_read=[], details=[], raw=[])
    sec = cur = scene = None
    count = 0
    def conds(c, ln):                       # mirror of cond() in js/core/rules.js
        if not c: return
        for t in c.split("&"):
            t = t.strip()
            if t.startswith("!"): t = t[1:]
            m = re.match(r"^(.+?)(>=|<=|>|<|=)(-?\d+)$", t)
            name = m.group(1) if m else t
            if not name: err(f, ln, f"empty condition in '{c}'"); continue
            if name.startswith("@"): kind, rest = CONDS["@"], name[1:]
            elif ":" in name and name[:name.index(":") + 1] in CONDS: kind, rest = CONDS[name[:name.index(":") + 1]], name[name.index(":") + 1:]
            elif name in CONDS: kind, rest = CONDS[name], None
            else:
                if not re.match(r"^\w+$", name): err(f, ln, f"condition '{name}' not understood")
                d["flags_read"].append((name, ln)); continue
            if COND_KINDS[kind]: COND_KINDS[kind](d, rest, ln, f)
    def target(t, ln, frm):
        m = re.match(r"^(.+?)\s*\?\s*(\S+)\s*:\s*(\S+)$", t)
        if m: conds(m.group(1), ln); d["jumps"] += [(m.group(2), ln, frm), (m.group(3), ln, frm)]
        else: d["jumps"].append((t.strip(), ln, frm))
    def effects(s, ln):
        for part in [x.strip() for x in s.split(";") if x.strip()]:
            m = re.match(r"^(\w+)\s+(.+?)(?:\s+if\s+(\S+))?$", part)
            if not m: err(f, ln, f"effect not understood: {part}"); continue
            k, a, c = m.groups(); conds(c, ln)
            if k not in EFFECTS: err(f, ln, f"the game has no effect called '{k}' (it has: {', '.join(sorted(EFFECTS))})"); continue
            kind = EFFECTS[k]
            if kind in ADDS_UP: a = re.sub(r"\s+each time$", "", a)
            if EFFECT_KINDS[kind]: EFFECT_KINDS[kind](d, a, ln, f)
    def tokens(s, ln, raw=True):  # raw=False for English text that mentions Korean names
        d["tokens"] += [(t, ln) for t in ids_in(s)]
        if raw: d["raw"].append((TOK.sub(" ", s), ln))
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
            if sec not in SECTIONS: err(f, ln, f"the game has no section called '=== {sec}'")
            if sec == "scene":
                if arg in d["scenes"]: err(f, ln, f"scene '{arg}' defined twice")
                scene = arg; count = 0; d["scenes"][arg] = dict(ln=ln, beats=0)
            elif sec == "place": cur = d["places"][arg] = dict(ln=ln, spots=[], first=None, always=None, art=None)
            elif sec == "phone": cur = d["phones"][arg] = dict(ln=ln)
            elif sec == "examine": cur = d["examines"][arg] = dict(ln=ln, id=arg, art=None, keys=0)
            continue
        if sec not in SECTIONS: continue
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
            if m: conds(m.group(1), ln)
        elif sec == "deduce":
            m = re.match(r"^(\w+)(\s+final)?\s+if\s+(\S+)\s*\|\s*(.+?)\s*\|\s*(.+)$", line)
            if not m: err(f, ln, "deduction line not understood"); continue
            conds(m.group(3), ln); tokens(m.group(4), ln, False)
            nd = re.search(r"\|\s*needs\s+(.+)$", m.group(5))
            needs = [[y.strip() for y in re.sub(r'"[^"]*"', "", x).split("/")] for x in nd.group(1).split("+")] if nd else []
            if nd and nd.group(1).count('"') < 2 * len(needs): warn(f, ln, f"deduction {m.group(1)}: give each proof a \"hint\" so players know what it asks for")
            d["deduce"].append(dict(id=m.group(1), final=bool(m.group(2)), c=m.group(3), blanks=ids_in(m.group(4)), needs=needs, ln=ln))
        elif sec == "evidence":
            p = [x.strip() for x in line.split("|")]
            if len(p) < 4: err(f, ln, "evidence line needs id | label | picture | description"); continue
            d["evidence"][p[0]] = dict(icon=p[2], ln=ln); tokens(p[1], ln)
            if len(p) > 4: tokens("|".join(p[4:]), ln)
        elif sec == "place":
            if m := re.match(r"^(name|sub|art|first|always|ambient|travel)\s+(.+)$", line):
                cur[m.group(1)] = (m.group(2), ln)
            elif m := re.match(r"^desc\s+(?:if\s+(\S+):\s*)?(.+)$", line): conds(m.group(1), ln)
            elif m := re.match(r'^spot\s+"([^"]+)"\s+([\d.]+)\s+([\d.]+)\s+(->|=>)\s+(.+?)(?:\s+if\s+(\S+))?$', line):
                conds(m.group(6), ln); cur["spots"].append(dict(kind=m.group(4), t=m.group(5), ln=ln))
            elif m := re.match(r"^glow\s+(.+?)\s+[\d.]+\s+[\d.]+", line): d["tokens"].append((m.group(1), ln))
            else: err(f, ln, "place line not understood")
        elif sec == "phone":
            if m := re.match(r"^on-open\s+(.+)", line): effects(m.group(1), ln)
            elif m := re.match(r"^voice(?:@(\S+))?\s+\S+\s+([a-z_]+)\s+(.+)", line):
                conds(m.group(1), ln); d["speakers"].append((m.group(2), ln)); tokens(m.group(3), ln)
            elif m := re.match(r"^(day|them|me|sys|note)(?:@(\S+))?\s+(.+)", line):
                conds(m.group(2), ln); tokens(m.group(3), ln, m.group(1) != "note")
            elif not re.match(r"^(name|avatar)\s", line): err(f, ln, "phone line not understood")
        elif sec == "examine":
            if m := re.match(r"^compare\s+(\S+)", line):
                if m.group(1) not in ARTS: err(f, ln, f"art '{m.group(1)}' isn't drawn in js/art.js")
            elif m := re.match(r"^art\s+(\S+)", line):
                cur["art"] = m.group(1)
                if m.group(1) not in ARTS: err(f, ln, f"art '{m.group(1)}' isn't drawn in js/art.js")
            elif re.match(r"^prompt\s", line): pass
            elif m := re.match(r"^detail\s+(\w+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)(\s+key)?\s*\|\s*(.+?)(?:\s+!\s+(.+))?$", line):
                tokens(m.group(6), ln, False); d["details"].append(f"{cur['id']}_{m.group(1)}")
                if m.group(5): cur["keys"] += 1
                if m.group(7): effects(m.group(7), ln)
            else: err(f, ln, "examine line not understood")
        elif sec == "meanings":
            d.setdefault("meanings", {})[line.split("|")[0].strip()] = ln
        elif sec == "names":
            d.setdefault("names", {})[line.split("|")[0].strip()] = ln
        elif sec == "scene":
            if scene is None: err(f, ln, "line outside a scene"); continue
            if line.startswith("~"): beat(ln)
            elif re.match(r"^\(.*\)$", line): pass
            elif line.startswith("!"): effects(line[1:], ln)
            elif m := re.match(r"^\*\s+(.+?)\s+->\s+(.+?)(?:\s+if\s+(\S+))?(?:\s+!\s+(.+))?$", line):
                target(m.group(2), ln, scene); conds(m.group(3), ln)
                if m.group(4): effects(m.group(4), ln)
                if not m.group(1).startswith("["): tokens(m.group(1), ln)
            elif m := re.match(r"^(->|<-)\s*(.+)$", line): target(m.group(2), ln, scene)
            elif m := re.match(r"^@(\w+)\b\s*(.*)$", line):
                if m.group(1) not in BEATS: err(f, ln, f"the game has no beat called '@{m.group(1)}'"); continue
                beat(ln)
                if m.group(1) == "examine": d["exrefs"].append((m.group(2).strip(), ln))
            elif m := re.match(r"^pair:\s*(\S+)\s*\+\s*(\S+)\s+->\s+(.+)$", line):
                d["pairs"] += [(m.group(1), ln), (m.group(2), ln)]; target(m.group(3), ln, scene)
            elif m := re.match(r"^tiles:\s*(.+)$", line): tokens(m.group(1), ln)
            elif m := re.match(r"^answer:\s*(.+?)\s+->\s+(.+)$", line): tokens(m.group(1), ln); target(m.group(2), ln, scene)
            elif m := re.match(r"^miss\s+->\s+(.+)$", line): target(m.group(1), ln, scene)
            elif m := re.match(r"^show:\s*(\S+)\s+->\s+(.+)$", line): d["shows"].append((m.group(1), ln)); target(m.group(2), ln, scene)
            elif m := re.match(r"^([a-z_]+)(?:\[([\w ]+)\])?(?:@([a-z]{2}))?:\s*(.+)$", line):
                beat(ln); d["speakers"].append((m.group(1), ln)); tokens(m.group(4), ln)
                for tag in (m.group(2) or "").split():
                    if tag not in EXPRESSIONS: err(f, ln, f"unknown expression '{tag}'")
            else: err(f, ln, "scene line not understood")
        # the other sections (grammar, tells, endings, pattern, case) hold no references to check
    return d

def check_icon(spec, f, ln, what):
    parts = spec.split()
    if not parts or parts[0] not in ICONS: err(f, ln, f"{what}: picture '{parts[0] if parts else spec}' isn't drawn in js/icons.js")
    for p in parts[1:]:
        if not (p.startswith("+") and p[1:] in MODS): err(f, ln, f"{what}: unknown badge '{p}'")

# ---------------------------------------------------------------- cross-checks
def main():
    world = parse(STORY / "world.story")
    chapters = {}
    for c in world["chapters"]:
        fp = STORY / c["file"]
        if not fp.exists(): err("world.story", c["ln"], f"chapter file {c['file']} is missing"); continue
        chapters[c["id"]] = (fp.name, parse(fp))
    files = [("world.story", world)] + list(chapters.values())
    words = dict(world["words"])
    for _, (_, d) in chapters.items(): words.update(d["words"])
    cast = set(world["cast"])
    for w, (spec, ln) in words.items():
        if spec != "(grammar)": check_icon(spec, "world.story", ln, w)
    all_places = set()
    for name, d in files:
        for t, ln in d["tokens"]:
            if t not in words: err(name, ln, f"{{{t}}} has no entry in the words list")
    # the world is shared by every file: village flags and things you own
    gset = {x for _, d in files for x, _ in d["gflags_set"]}
    items = {x for _, d in files for x, _ in d["items_given"]}
    for name, d in files:
        for x, ln in d["gflags_read"]:
            if x not in gset: err(name, ln, f"village flag 'g:{x}' is checked but no file ever sets it (! set g:{x})")
        for x, ln in d["items_read"]:
            if x not in items: warn(name, ln, f"'has:{x}' is checked but no story line hands it out (! item +{x})")
        for who, ln in d["who_refs"]:
            if who not in cast and who not in d["cast"]: err(name, ln, f"'{who}' isn't in the cast")
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
                if s["kind"] == "->":
                    m = re.match(r"^(.+?)\s*\?\s*(\S+)\s*:\s*(\S+)$", s["t"])
                    d["jumps"] += [(m.group(2), s["ln"], None), (m.group(3), s["ln"], None)] if m else [(s["t"], s["ln"], None)]
                else:
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
        ids = dict(deduce=[q["id"] for q in d["deduce"]], phones=d["phones"], statements=d["statements"], evidence=evidence, details=d["details"])
        setf = {x for x, _ in d["flags_set"]} | {"started"} | {pre + x for pre, src in AUTO_FLAGS for x in ids[src]}
        for x, ln in d["flags_read"]:
            if x not in setf: err(fname, ln, f"flag '{x}' is checked but never set, so this can never happen")
        # deductions
        if len(ids["deduce"]) != len(set(ids["deduce"])): err(fname, 1, "two deductions share an id")
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
        if spec != "(grammar)" and w not in meanings: warn("world.story", ln, f"word '{w}' has no meaning (=== meanings)")
    namerx = re.compile("|".join(sorted(map(re.escape, names), key=len, reverse=True))) if names else None
    for name, d in files:
        for text, ln in d["raw"]:
            rest = namerx.sub(" ", text) if namerx else text
            left = re.findall(r"[가-힣]+", rest)
            if left: warn(name, ln, f"Korean you can't tap: {' '.join(left)}")
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
    print(f"rules read from the game: {len(EFFECTS)} effects, {len(CONDS)} conditions, {len(SECTIONS)} sections, {len(BEATS)} beats")
    sys.exit(1 if ERR else 0)

if __name__ == "__main__":
    main()
