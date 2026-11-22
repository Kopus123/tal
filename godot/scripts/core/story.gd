class_name Story
extends RefCounted
## Reads story/*.story files: the same format as the web version (documented at the top of story/world.story).
## Mirrors js/core/parse.js. Anything it doesn't understand goes in `warnings`, so nothing is silently dropped
## (the route tests fail on warnings).
##
##   var st := Story.parse(text, "ch1.story")          # one file
##   st = Story.parse(text2, "jobs.story", st)         # add another file to the same result


static func empty() -> Dictionary:
	return {"meta": {}, "cast": {}, "words": {}, "meanings": {}, "names": {}, "grammar": {}, "tells": {}, "places": {}, "nodes": {},
		"evidence": {}, "statements": {}, "examines": {}, "phones": [], "cases": [], "hints": [], "chapters": [], "map": [],
		"calendar": [], "people": {}, "people_files": [], "events": [], "encounters": [], "jobs": {}, "cards": {}, "unlocks": [], "warnings": []}


## "a | b | {x|y}" split on the bars that aren't inside {braces}
static func split_bar(s: String) -> Array:
	var out := []; var depth := 0; var cur := ""
	for c in s:
		if c == "{": depth += 1
		elif c == "}": depth -= 1
		if c == "|" and depth == 0:
			out.append(cur.strip_edges()); cur = ""
		else:
			cur += c
	out.append(cur.strip_edges())
	return out


## "set a, b; sfx slam if lit" -> [{k, a, c}]
static func parse_fx(s: String) -> Array:
	var out := []
	var re := RegEx.create_from_string("^(\\w+)\\s+(.+?)(?:\\s+if\\s+(\\S+))?$")
	for part in s.split(";"):
		var m := re.search(part.strip_edges())
		if m: out.append({"k": m.get_string(1), "a": m.get_string(2).strip_edges(), "c": m.get_string(3)})
	return out


static var _re := {}
static func R(p: String) -> RegEx:
	if not _re.has(p): _re[p] = RegEx.create_from_string(p)
	return _re[p]


static func _bar(line: String) -> PackedStringArray:
	var p := line.split("|")
	for i in p.size(): p[i] = p[i].strip_edges()
	return p


static func parse(src: String, file := "story", st: Dictionary = {}) -> Dictionary:
	if st.is_empty(): st = empty()
	var sec := ""; var cur: Dictionary = {}
	var S := {"scene": "", "last": {}, "count": 0, "early": []}   # the scene being read (a dictionary, so helpers can change it)
	var ln := 0
	for raw in src.split("\n"):
		ln += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"): continue
		var h := R("^===\\s*(\\w+)\\s*(.*)$").search(line)
		if h:
			sec = h.get_string(1); var arg := h.get_string(2).strip_edges()
			match sec:
				"scene": S.scene = arg; S.last = {}; S.count = 0; S.early = []
				"place": cur = {"id": arg, "spots": [], "desc": []}; st.places[arg] = cur
				"phone": cur = {"id": arg, "m": [], "fx": [], "name": arg, "av": "?", "c": "#888"}; st.phones.append(cur)
				"examine": cur = {"id": arg, "details": [], "art": "", "prompt": "", "compare": ""}; st.examines[arg] = cur
				"person": cur = {"id": arg, "at": {}, "greet": [], "chat": [], "story": [], "ask": [], "bye": []}; st.people[arg] = cur
				"event": cur = {"id": arg, "when": "", "slot": "", "place": "", "scene": "", "missed": []}; st.events.append(cur)
				"encounter": cur = {"id": arg, "at": [], "scene": "", "when": ""}; st.encounters.append(cur)
				"job": cur = {"id": arg, "ko": arg, "en": arg, "level": "easy", "client": "", "pay": 0, "thanks": 1, "when": "", "note": "", "start": "", "ask": {}}; st.jobs[arg] = cur
				"pattern": cur = {}   # notebook pattern pages: not in the Godot version yet
				"card": cur = {"id": arg, "kind": "", "start": false, "at": []}; st.cards[arg] = cur
				"unlock": cur = {"id": arg, "when": [], "fx": []}; st.unlocks.append(cur)
			continue
		var m: RegExMatch
		match sec:
			"meta":
				var i := line.find(" ")
				if i > 0: st.meta[line.substr(0, i)] = line.substr(i + 1).strip_edges()
			"cast":
				var p := _bar(line)
				st.cast[p[0]] = {"n": p[1] if p.size() > 1 else "", "c": p[2] if p.size() > 2 else "#888", "voice": p.size() > 3 and p[3] != "", "look": p[4] if p.size() > 4 else ""}
			"chapters":
				var p := _bar(line)
				if p.size() >= 4:
					var how: String = p[4] if p.size() > 4 else ""
					st.chapters.append({"id": p[0], "t": p[1], "sub": p[2], "file": p[3], "cont": how == "continues", "free": how == "free", "dev": how == "dev"})
			"map":
				m = R("^pin\\s+(\\S+)\\s+([\\d.]+)\\s+([\\d.]+)(?:\\s+(above|left|right|below))?").search(line)
				if m: st.map.append({"p": m.get_string(1), "x": float(m.get_string(2)), "y": float(m.get_string(3)), "side": m.get_string(4) if m.get_string(4) != "" else "above"})
			"people":
				var p := _bar(line)
				if p.size() >= 2: st.people_files.append({"id": p[0], "file": p[1]})
			"words":
				m = R("^(.+?)\\s*=\\s*(.+)$").search(line)
				if m: st.words[m.get_string(1)] = {"g": true} if m.get_string(2) == "(grammar)" else {"p": m.get_string(2)}
			"meanings", "grammar", "tells":
				var i := line.find("|")
				if i > 0: st[sec][line.substr(0, i).strip_edges()] = line.substr(i + 1).strip_edges()
			"names":
				var p := _bar(line)
				st.names[p[0]] = {"kind": p[1] if p.size() > 1 else "name", "d": p[2] if p.size() > 2 else ""}
			"calendar":
				var p := split_bar(line)
				m = R("^(\\w+)\\s+every\\s+(\\d+)(?:\\s+from\\s+(\\d+))?$").search(p[0])
				if m: st.calendar.append({"id": m.get_string(1), "every": int(m.get_string(2)), "from": int(m.get_string(3)) if m.get_string(3) != "" else int(m.get_string(2)), "label": p[1] if p.size() > 1 else "", "note": p[2] if p.size() > 2 else ""})
				else:
					m = R("^(\\w+)\\s+day\\s+(\\d+)$").search(p[0])
					if m: st.calendar.append({"id": m.get_string(1), "day": int(m.get_string(2)), "label": p[1] if p.size() > 1 else "", "note": p[2] if p.size() > 2 else ""})
					else: _warn(st, file, ln, line)
			"hints":
				m = R("^if\\s+(\\S+):\\s*(.+)$").search(line)
				st.hints.append({"c": m.get_string(1), "t": m.get_string(2)} if m else {"c": "", "t": line})
			"deduce":
				m = R("^(\\w+)(\\s+final)?\\s+if\\s+(\\S+)\\s*\\|\\s*(.+?)\\s*\\|\\s*(.+)$").search(line)
				if m:
					var why := m.get_string(5); var needs := []
					var k := R("^(.*?)\\s*\\|\\s*needs\\s+(.+)$").search(why)
					if k:
						why = k.get_string(1)
						for x in k.get_string(2).split("+"):
							var hm := R("\"([^\"]*)\"").search(x)
							var ids := R("\"[^\"]*\"").sub(x, "").strip_edges()
							var alts := []
							for a in ids.split("/"): alts.append(a.strip_edges())
							needs.append({"alts": alts, "hint": hm.get_string(1) if hm else ""})
					var blanks := []
					for t in tokens(m.get_string(4)): blanks.append(t[1])
					st.cases.append({"id": m.get_string(1), "final": m.get_string(2) != "", "c": m.get_string(3), "text": m.get_string(4), "why": why, "needs": needs, "blanks": blanks})
			"evidence":
				var p := _bar(line)
				var id := p[0]
				st.evidence[id] = {"id": id, "label": p[1] if p.size() > 1 else id, "icon": p[2] if p.size() > 2 else "",
					"desc": p[3] if p.size() > 3 else "", "ko": "|".join(p.slice(4)) if p.size() > 4 else ""}
			"examine":
				m = R("^(art|prompt|compare)\\s+(.+)$").search(line)
				if m: cur[m.get_string(1)] = m.get_string(2)
				else:
					m = R("^detail\\s+(\\w+)\\s+([\\d.]+)\\s+([\\d.]+)\\s+([\\d.]+)(\\s+key)?\\s*\\|\\s*(.+?)(?:\\s+!\\s+(.+))?$").search(line)
					if m: cur.details.append({"id": m.get_string(1), "x": float(m.get_string(2)), "y": float(m.get_string(3)), "r": float(m.get_string(4)),
						"key": m.get_string(5) != "", "t": m.get_string(6), "fx": parse_fx(m.get_string(7)) if m.get_string(7) != "" else []})
					else: _warn(st, file, ln, line)
			"phone":
				m = R("^name\\s+(.+)").search(line)
				if m: cur.name = m.get_string(1); continue
				m = R("^avatar\\s+(\\S+)\\s+(\\S+)").search(line)
				if m: cur.av = m.get_string(1); cur.c = m.get_string(2); continue
				m = R("^on-open\\s+(.+)").search(line)
				if m: cur.fx = parse_fx(m.get_string(1)); continue
				m = R("^day(?:@(\\S+))?\\s+(.+)").search(line)
				if m: cur.m.append({"d": m.get_string(2), "c": m.get_string(1)}); continue
				m = R("^(them|me)(?:@(\\S+))?\\s+(\\S+)\\s+(.+)").search(line)
				if m: cur.m.append({"me": m.get_string(1) == "me", "c": m.get_string(2), "t": m.get_string(3), "ko": m.get_string(4)}); continue
				m = R("^sys(?:@(\\S+))?\\s+(.+)").search(line)
				if m: cur.m.append({"sys": true, "c": m.get_string(1), "ko": m.get_string(2)}); continue
				m = R("^voice(?:@(\\S+))?\\s+(\\S+)\\s+([a-z_]+)\\s+(.+)").search(line)
				if m: cur.m.append({"vm": true, "c": m.get_string(1), "t": m.get_string(2), "who": m.get_string(3), "ko": m.get_string(4)}); continue
				m = R("^note(?:@(\\S+))?\\s+(.+)").search(line)
				if m: cur.note = m.get_string(2); cur.note_c = m.get_string(1); continue
				_warn(st, file, ln, line)
			"person":
				m = R("^at\\s+(\\w+)\\s+(\\w+)\\s+([\\d.]+)\\s+([\\d.]+)$").search(line)
				if m:
					if not cur.at.has(m.get_string(1)): cur.at[m.get_string(1)] = []
					cur.at[m.get_string(1)].append({"place": m.get_string(2), "x": float(m.get_string(3)), "y": float(m.get_string(4))})
					continue
				m = R("^greet\\s+(\\w+)$").search(line)
				if m: cur.greet.append(m.get_string(1)); continue
				m = R("^(chat|story)\\s+(\\d+)\\s+(\\w+)(?:\\s+if\\s+(\\S+))?$").search(line)
				if m: cur[m.get_string(1)].append({"lv": int(m.get_string(2)), "scene": m.get_string(3), "c": m.get_string(4)}); continue
				m = R("^ask\\s+(\\S+)\\s+(\\w+)(?:\\s+if\\s+(\\S+))?$").search(line)
				if m: cur.ask.append({"word": m.get_string(1), "scene": m.get_string(2), "c": m.get_string(3)}); continue
				m = R("^bye\\s+(\\w+)$").search(line)
				if m: cur.bye.append(m.get_string(1)); continue
				_warn(st, file, ln, line)
			"event":
				m = R("^when\\s+(\\S+)$").search(line)
				if m: cur.when = m.get_string(1); continue
				m = R("^at\\s+(\\w+)\\s+(\\w+)$").search(line)
				if m: cur.slot = m.get_string(1); cur.place = m.get_string(2); continue
				m = R("^scene\\s+(\\w+)$").search(line)
				if m: cur.scene = m.get_string(1); continue
				m = R("^missed\\s+(\\w+)\\s+(\\w+)$").search(line)
				if m: cur.missed = [m.get_string(1), m.get_string(2)]; continue
				_warn(st, file, ln, line)
			"encounter":
				m = R("^at\\s+(\\w+)\\s+(\\w+)$").search(line)
				if m: cur.at.append({"slot": m.get_string(1), "place": m.get_string(2)}); continue
				m = R("^scene\\s+(\\w+)$").search(line)
				if m: cur.scene = m.get_string(1); continue
				m = R("^when\\s+(\\S+)$").search(line)
				if m: cur.when = m.get_string(1); continue
				_warn(st, file, ln, line)
			"job":
				m = R("^title\\s+(.+?)\\s*\\|\\s*(.+)$").search(line)
				if m: cur.ko = m.get_string(1); cur.en = m.get_string(2); continue
				m = R("^(level|client|start)\\s+(\\S+)$").search(line)
				if m: cur[m.get_string(1)] = m.get_string(2); continue
				m = R("^(pay|thanks)\\s+(\\d+)$").search(line)
				if m: cur[m.get_string(1)] = int(m.get_string(2)); continue
				m = R("^when\\s+(\\S+)$").search(line)
				if m: cur.when = m.get_string(1); continue
				m = R("^note\\s+(.+)$").search(line)
				if m: cur.note = m.get_string(1); continue
				m = R("^ask\\s+(\\w+)\\s+(\\w+)$").search(line)
				if m: cur.ask[m.get_string(1)] = m.get_string(2); continue
				_warn(st, file, ln, line)
			"place":
				m = R("^(name|sub|art|first|always|ambient|travel|music|sound|light|mode|dark|back)\\s+(.+)$").search(line)
				if m: cur[m.get_string(1)] = m.get_string(2); continue
				m = R("^desc\\s+(?:if\\s+(\\S+):\\s*)?(.+)$").search(line)
				if m: cur.desc.append({"c": m.get_string(1), "t": m.get_string(2)}); continue
				m = R("^closed\\s+(\\S+)\\s*\\|\\s*(.+)$").search(line)
				if m: cur.closed = {"c": m.get_string(1), "t": m.get_string(2)}; continue
				m = R("^spot\\s+\"([^\"]+)\"\\s+([\\d.]+)\\s+([\\d.]+)\\s+(->|=>)\\s+(.+?)(?:\\s+if\\s+(\\S+))?$").search(line)
				if m:
					cur.spots.append({"l": m.get_string(1), "x": float(m.get_string(2)), "y": float(m.get_string(3)), "kind": m.get_string(4), "t": m.get_string(5), "c": m.get_string(6)})
					continue
				if not line.begins_with("glow "): _warn(st, file, ln, line)
			"scene":
				_scene_line(st, S, line, file, ln)
			"card":
				# say WHO FACE | 한국어  /  thing ICON | label | 한국어  /  person WHO  /  place ART | 한국어 | English  /  time ICON | 한국어  /  start
				var p := split_bar(line)
				var head: PackedStringArray = str(p[0]).split(" ", false)
				match head[0]:
					"say": cur.kind = "say"; cur.who = head[1]; cur.ex = head[2] if head.size() > 2 else "neutral"; cur.ko = p[1] if p.size() > 1 else ""
					"thing": cur.kind = "thing"; cur.icon = head[1]; cur.label = p[1] if p.size() > 1 else ""; cur.ko = p[2] if p.size() > 2 else ""
					"person": cur.kind = "person"; cur.who = head[1]; cur.missing = head.size() > 2 and head[2] == "missing"
					"note": cur.kind = "note"; cur.color = head[1] if head.size() > 1 else "yellow"; cur.ko = p[1] if p.size() > 1 else ""; cur.en = p[2] if p.size() > 2 else ""
					"at": cur.at = [float(head[1]) / 100.0, float(head[2]) / 100.0] if head.size() > 2 else []
					"place": cur.kind = "place"; cur.art = head[1]; cur.ko = p[1] if p.size() > 1 else ""; cur.en = p[2] if p.size() > 2 else ""
					"time": cur.kind = "time"; cur.icon = head[1]; cur.ko = p[1] if p.size() > 1 else ""
					"start": cur.start = true
					_: _warn(st, file, ln, line)
			"unlock":
				if line.begins_with("when "):
					for pair in line.substr(5).split(","):
						var ab := pair.strip_edges().split("-")
						if ab.size() == 2: cur.when.append([ab[0].strip_edges(), ab[1].strip_edges()])
				elif line.begins_with("!"): cur.fx.append_array(parse_fx(line.substr(1)))
				else: _warn(st, file, ln, line)
			"endings", "pattern":
				pass   # notebook grammar pages: not in the Godot version yet
			_:
				_warn(st, file, ln, "nothing reads the section === " + sec)
	return st


static func _warn(st: Dictionary, file: String, ln: int, line: String) -> void:
	st.warnings.append("%s:%d: %s" % [file, ln, line])


static func _node(st: Dictionary, S: Dictionary, n: Dictionary) -> Dictionary:
	S.count += 1
	var id: String = S.scene if S.count == 1 else "%s.%d" % [S.scene, S.count]
	if not S.early.is_empty():
		n["fx"] = S.early; S.early = []
	var last: Dictionary = S.last
	if not last.is_empty() and not last.has("next") and not last.has("rewind") and not last.has("ch") and not last.has("ans") and not last.has("shows") and not last.has("pairs"): last["next"] = id
	n["id"] = id; st.nodes[id] = n; S.last = n
	return n


static func _scene_line(st: Dictionary, S: Dictionary, line: String, file: String, ln: int) -> void:
	var last: Dictionary = S.last
	var m: RegExMatch
	if line.begins_with("~"):
		_node(st, S, {"who": "narr", "en": line.substr(1).strip_edges()}); return
	if line.begins_with("(") and line.ends_with(")"):
		if not last.is_empty(): last["en"] = line.substr(1, line.length() - 2)
		return
	if line.begins_with("!"):
		var f := parse_fx(line.substr(1))
		if last.is_empty(): S.early.append_array(f)
		else:
			last["fx"] = last.get("fx", []) + f
			for e in f:
				if e.k == "statement": st.statements[e.a] = {"id": e.a, "node": last.id}
		return
	m = R("^\\*\\s+(.+?)\\s+->\\s+(.+?)(?:\\s+if\\s+(\\S+))?(?:\\s+!\\s+(.+))?$").search(line)
	if m:
		var lab := m.get_string(1)
		var o := {"go": m.get_string(2), "c": m.get_string(3), "fx": parse_fx(m.get_string(4)) if m.get_string(4) != "" else []}
		if lab.begins_with("["): o["en"] = lab.trim_prefix("[").trim_suffix("]")
		else: o["ko"] = lab
		if not last.has("ch"): last["ch"] = []
		last.ch.append(o); return
		return
	if line.begins_with("->"):
		if not last.is_empty(): last["next"] = line.substr(2).strip_edges()
		return
	if line.begins_with("<-"):
		if not last.is_empty(): last["rewind"] = line.substr(2).strip_edges()
		return
	m = R("^@build\\s+(.+)$").search(line)
	if m:
		var k := R("^(.*?)\\s*\\|\\s*join$").search(m.get_string(1))
		_node(st, S, {"type": "build", "en": k.get_string(1) if k else m.get_string(1), "join": k != null, "tiles": [], "ans": []}); return
		return
	m = R("^tiles:\\s*(.+)$").search(line)
	if m:
		last["tiles"] = split_bar(m.get_string(1)); return
		return
	m = R("^@type\\s+(.+)$").search(line)
	if m:
		var k := R("^(.*?)\\s*\\|\\s*([a-z_]+)$").search(m.get_string(1))
		_node(st, S, {"type": "type", "en": k.get_string(1) if k else m.get_string(1), "to": k.get_string(2) if k else "", "ans": []}); return
		return
	m = R("^@number\\s+(.+?)(?:\\s*\\|\\s*(time|won|phone|count))?$").search(line)
	if m:
		_node(st, S, {"type": "number", "en": m.get_string(1), "kind": m.get_string(2) if m.get_string(2) != "" else "count", "ans": []}); return
		return
	m = R("^answer:\\s*(.+?)\\s+->\\s+(.+)$").search(line)
	if m:
		var a = m.get_string(1).strip_edges() if last.get("type", "") in ["type", "number"] else split_bar(m.get_string(1))
		last.ans.append([a, m.get_string(2).strip_edges()]); return
		return
	m = R("^miss\\s+->\\s+(.+)$").search(line)
	if m:
		last["miss"] = m.get_string(1).strip_edges(); return
		return
	m = R("^@camera\\s+(?:([\\d.]+)\\s+([\\d.]+)\\s*\\|\\s*)?(.+)$").search(line)
	if m:
		_node(st, S, {"type": "camera", "tx": float(m.get_string(1)) if m.get_string(1) != "" else 50.0, "ty": float(m.get_string(2)) if m.get_string(2) != "" else 50.0, "en": m.get_string(3)}); return
		return
	m = R("^@photo\\s+(.+)$").search(line)
	if m:
		_node(st, S, {"type": "photo", "en": m.get_string(1)}); return
		return
	m = R("^@present\\s+(.+)$").search(line)
	if m:
		_node(st, S, {"type": "present", "en": m.get_string(1), "shows": []}); return
		return
	m = R("^show:\\s*(\\S+)\\s+->\\s+(.+)$").search(line)
	if m:
		last.shows.append([m.get_string(1), m.get_string(2).strip_edges()]); return
		return
	m = R("^@examine\\s+(\\w+)$").search(line)
	if m:
		_node(st, S, {"type": "examine", "exam": m.get_string(1)}); return
		return
	m = R("^@contradict\\s+(.+)$").search(line)
	if m:
		_node(st, S, {"type": "contradict", "en": m.get_string(1), "pairs": []}); return
		return
	m = R("^pair:\\s*(\\S+)\\s*\\+\\s*(\\S+)\\s+->\\s+(.+)$").search(line)
	if m:
		last.pairs.append([[m.get_string(1), m.get_string(2)], m.get_string(3).strip_edges()]); return
		return
	m = R("^@card\\s+(.+?)(?:\\s*\\|\\s*(.+))?$").search(line)
	if m:
		_node(st, S, {"type": "card", "title": m.get_string(1), "sub": m.get_string(2)}); return
		return
	m = R("^([a-z_]+)(?:\\[([\\w ]+)\\])?(?:@([a-z]{2}))?:\\s*(.+)$").search(line)
	if m:
		var tags := m.get_string(2).split(" ", false)
		var ex := "neutral"
		for t in tags:
			if t != "audio": ex = t
		_node(st, S, {"who": m.get_string(1), "ex": ex, "audio": "audio" in tags, "ko": m.get_string(4).replace("\\n", "\n")}); return
		return
	_warn(st, file, ln, line)


## the words in a line: "{봤어요}" and "{surface|entry}" -> [[surface, entry], ...]
static func tokens(text: String) -> Array:
	var out := []
	for m in R("\\{([^}|]+)(?:\\|([^}]+))?\\}").search_all(text):
		out.append([m.get_string(1), m.get_string(2) if m.get_string(2) != "" else m.get_string(1)])
	return out


static func plain(s: String) -> String:
	return R("\\{([^}|]+)(?:\\|[^}]+)?\\}").sub(s, "$1", true)
