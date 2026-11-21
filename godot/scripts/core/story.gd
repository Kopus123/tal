class_name Story
extends RefCounted
## Reads story/*.story files: the same format as the web version (documented at the top of story/world.story,
## parsed there by js/core/parse.js). This reads the parts the Godot version uses so far; anything else is listed
## in `warnings` so nothing gets silently dropped.
##
##   var st := Story.parse(text, "shed.story")         # one file
##   var st := Story.parse(text2, "world.story", st)   # add another file to the same result

static func empty() -> Dictionary:
	return {"meta": {}, "cast": {}, "words": {}, "meanings": {}, "names": {}, "places": {}, "nodes": {},
		"evidence": {}, "hints": [], "chapters": [], "warnings": []}


## "a | b | {x|y}" split on the bars that aren't inside {braces}
static func split_bar(s: String) -> PackedStringArray:
	var out := PackedStringArray(); var depth := 0; var cur := ""
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


static func parse(src: String, file := "story", st: Dictionary = {}) -> Dictionary:
	if st.is_empty(): st = empty()
	var R := func(p: String) -> RegEx: return RegEx.create_from_string(p)
	var re_head: RegEx = R.call("^===\\s*(\\w+)\\s*(.*)$")
	var re_place_kv: RegEx = R.call("^(name|sub|art|first|always|ambient|travel|music|sound|light|mode|dark|back)\\s+(.+)$")
	var re_desc: RegEx = R.call("^desc\\s+(?:if\\s+(\\S+):\\s*)?(.+)$")
	var re_spot: RegEx = R.call("^spot\\s+\"([^\"]+)\"\\s+([\\d.]+)\\s+([\\d.]+)\\s+(->|=>)\\s+(.+?)(?:\\s+if\\s+(\\S+))?$")
	var re_choice: RegEx = R.call("^\\*\\s+(.+?)\\s+->\\s+(.+?)(?:\\s+if\\s+(\\S+))?(?:\\s+!\\s+(.+))?$")
	var re_number: RegEx = R.call("^@number\\s+(.+?)(?:\\s*\\|\\s*(time|won|phone|count))?$")
	var re_answer: RegEx = R.call("^answer:\\s*(.+?)\\s+->\\s+(.+)$")
	var re_card: RegEx = R.call("^@card\\s+(.+?)(?:\\s*\\|\\s*(.+))?$")
	var re_say: RegEx = R.call("^([a-z_]+)(?:\\[([\\w ]+)\\])?(?:@([a-z]{2}))?:\\s*(.+)$")
	var re_hint: RegEx = R.call("^if\\s+(\\S+):\\s*(.+)$")
	var re_word: RegEx = R.call("^(.+?)\\s*=\\s*(.+)$")

	var sec := ""; var cur: Dictionary = {}
	var S := {"scene": "", "last": {}, "count": 0, "early": []}   # the scene being read (a dictionary, so helpers can change it)
	var ln := 0
	for raw in src.split("
"):
		ln += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"): continue
		var h := re_head.search(line)
		if h:
			sec = h.get_string(1); var arg := h.get_string(2).strip_edges()
			if sec == "scene":
				S.scene = arg; S.last = {}; S.count = 0; S.early = []
			elif sec == "place":
				cur = {"id": arg, "spots": [], "desc": []}; st.places[arg] = cur
			continue
		var m: RegExMatch
		match sec:
			"meta":
				var i := line.find(" ")
				if i > 0: st.meta[line.substr(0, i)] = line.substr(i + 1).strip_edges()
			"cast":
				var p := line.split("|")
				st.cast[p[0].strip_edges()] = {"n": p[1].strip_edges() if p.size() > 1 else "", "c": p[2].strip_edges() if p.size() > 2 else "#888"}
			"chapters":
				var p := line.split("|")
				if p.size() >= 4: st.chapters.append({"id": p[0].strip_edges(), "file": p[3].strip_edges()})
			"words":
				m = re_word.search(line)
				if m: st.words[m.get_string(1)] = {"g": true} if m.get_string(2) == "(grammar)" else {"p": m.get_string(2)}
			"meanings":
				var i := line.find("|")
				if i > 0: st.meanings[line.substr(0, i).strip_edges()] = line.substr(i + 1).strip_edges()
			"names":
				var p := line.split("|")
				st.names[p[0].strip_edges()] = {"kind": p[1].strip_edges() if p.size() > 1 else "name", "d": p[2].strip_edges() if p.size() > 2 else ""}
			"hints":
				m = re_hint.search(line)
				st.hints.append({"c": m.get_string(1), "t": m.get_string(2)} if m else {"c": "", "t": line})
			"evidence":
				var p := line.split("|")
				var id := p[0].strip_edges()
				st.evidence[id] = {"id": id, "label": p[1].strip_edges() if p.size() > 1 else id, "icon": p[2].strip_edges() if p.size() > 2 else "",
					"desc": p[3].strip_edges() if p.size() > 3 else "", "ko": "|".join(p.slice(4)).strip_edges() if p.size() > 4 else ""}
			"place":
				m = re_place_kv.search(line)
				if m:
					cur[m.get_string(1)] = m.get_string(2); continue
				m = re_desc.search(line)
				if m:
					cur.desc.append({"c": m.get_string(1), "t": m.get_string(2)}); continue
				m = re_spot.search(line)
				if m:
					cur.spots.append({"l": m.get_string(1), "x": float(m.get_string(2)), "y": float(m.get_string(3)), "kind": m.get_string(4), "t": m.get_string(5), "c": m.get_string(6)})
					continue
				if not line.begins_with("glow ") and not line.begins_with("closed "): st.warnings.append("%s:%d: %s" % [file, ln, line])
			"scene":
				_scene_line(st, S, line, file, ln, re_choice, re_number, re_answer, re_card, re_say)
			_:
				pass   # sections the Godot version doesn't use yet (grammar, patterns, map, ...)
	return st


static func _node(st: Dictionary, S: Dictionary, n: Dictionary) -> Dictionary:
	S.count += 1
	var id: String = S.scene if S.count == 1 else "%s.%d" % [S.scene, S.count]
	if not S.early.is_empty():
		n["fx"] = S.early; S.early = []
	var last: Dictionary = S.last
	if not last.is_empty() and not last.has("next") and not last.has("rewind") and not last.has("ch") and not last.has("ans"): last["next"] = id
	n["id"] = id; st.nodes[id] = n; S.last = n
	return n


static func _scene_line(st: Dictionary, S: Dictionary, line: String, file: String, ln: int, re_choice: RegEx, re_number: RegEx, re_answer: RegEx, re_card: RegEx, re_say: RegEx) -> void:
	var last: Dictionary = S.last
	if line.begins_with("~"):
		_node(st, S, {"who": "narr", "en": line.substr(1).strip_edges()}); return
	if line.begins_with("(") and line.ends_with(")"):
		if not last.is_empty(): last["en"] = line.substr(1, line.length() - 2)
		return
	if line.begins_with("!"):
		if last.is_empty(): S.early.append_array(parse_fx(line.substr(1)))
		else: last["fx"] = last.get("fx", []) + parse_fx(line.substr(1))
		return
	var m := re_choice.search(line)
	if m:
		var lab := m.get_string(1)
		var o := {"go": m.get_string(2), "c": m.get_string(3), "fx": parse_fx(m.get_string(4)) if m.get_string(4) != "" else []}
		if lab.begins_with("["): o["en"] = lab.trim_prefix("[").trim_suffix("]")
		else: o["ko"] = lab
		if not last.has("ch"): last["ch"] = []
		last.ch.append(o); return
	if line.begins_with("->"):
		if not last.is_empty(): last["next"] = line.substr(2).strip_edges()
		return
	if line.begins_with("<-"):
		if not last.is_empty(): last["rewind"] = line.substr(2).strip_edges()
		return
	m = re_number.search(line)
	if m:
		_node(st, S, {"type": "number", "en": m.get_string(1), "kind": m.get_string(2) if m.get_string(2) != "" else "count", "ans": []}); return
	m = re_answer.search(line)
	if m:
		last.ans.append([m.get_string(1).strip_edges(), m.get_string(2).strip_edges()]); return
	if line.begins_with("miss "):
		last["miss"] = line.trim_prefix("miss").strip_edges().trim_prefix("->").strip_edges(); return
	m = re_card.search(line)
	if m:
		_node(st, S, {"type": "card", "title": m.get_string(1), "sub": m.get_string(2)}); return
	m = re_say.search(line)
	if m:
		var tags := m.get_string(2).split(" ", false)
		var ex := "neutral"
		for t in tags:
			if t != "audio": ex = t
		_node(st, S, {"who": m.get_string(1), "ex": ex, "audio": "audio" in tags, "ko": m.get_string(4).replace("\n", "
")}); return
	st.warnings.append("%s:%d: %s" % [file, ln, line])


## the words in a line: "{봤어요}" and "{surface|entry}" -> [[surface, entry], ...]
static func tokens(text: String) -> Array:
	var out := []
	for m in RegEx.create_from_string("\\{([^}|]+)(?:\\|([^}]+))?\\}").search_all(text):
		out.append([m.get_string(1), m.get_string(2) if m.get_string(2) != "" else m.get_string(1)])
	return out
