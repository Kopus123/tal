extends Node
## The game: its state, and the story's rules (autoload "Game"). A port of the web version's js/core/*.js:
## flow (beats, choices, answers, rewinds, chapters), rules (effects "! set x", conditions "if lit&!oiled"),
## world (the clock, money, friendship, things you own), villagers, events, encounters and jobs.
## Nothing here draws anything: the screen listens to the signals and asks for what it needs.

signal changed                       ## something visible changed: redraw
signal sound(name: String)
signal toast(text: String)
signal lean(at: Vector2, on: bool)   ## lean in on a thing (x, y in % of the picture) while you look at it
signal rewound                       ## a wrong turn: back to the decision
signal timecard                      ## the time of day changed: show the big card
signal finished(chapter: String)     ## the final deduction is solved
signal reply(ko: String, en: String) ## small talk while you're meant to be typing something else

const SLOTS := ["morning", "afternoon", "evening", "night"]
const SLOT_KO := {"morning": "아침", "afternoon": "낮", "evening": "저녁", "night": "밤"}
const REL_STEPS := [3, 7, 12, 18]
const START_MONEY := 20000
const SAVE_PATH := "user://save.json"
const WORDS_PATH := "user://words.json"
const LOG_PATH := "user://playlog.txt"

var world_st: Dictionary = {}        ## world.story
var world: Dictionary = {}           ## alias kept for the screens: world.story (cast, words, meanings)
var CH: Dictionary = {}              ## chapter id -> parsed story files
var PEOPLE: Dictionary = {}          ## villagers (story/people/*.people)
var PNODES: Dictionary = {}          ## every scene from the people files
var PSTART: Dictionary = {}          ## scenes a talk can start (to remember you heard them today)
var ST: Dictionary = {}              ## the chapter being played, merged with the world
var ch: Dictionary:                  ## (old name, used by the screens)
	get: return ST

## the save
var S: Dictionary = {}
var F: Dictionary:
	get: return S.F
var loc: String:
	get: return S.loc
	set(v): S.loc = v
var node: String:
	get: return S.node
	set(v): S.node = v
var W: Dictionary:                   ## the world part of the save: day, time, money, friendships...
	get: return S.world

var words: Dictionary = {}           ## your notebook: guesses, sure, lines you've seen each word in
var enc_off := false                 ## tests turn encounters off (they'd interrupt a planned route)
var testing := false                 ## tests: don't write the save or the play log
var _leaning := false
var _t0 := 0


func _ready() -> void:
	world_st = Story.parse(_read("res://story/world.story"), "world.story"); world = world_st
	for c in world_st.chapters:
		if c.file == "": continue
		var st := {}
		for f in c.file.split("+"):
			st = Story.parse(_read("res://story/" + f.strip_edges()), f.strip_edges(), st)
		CH[c.id] = st
	for pf in world_st.people_files:
		var d := Story.parse(_read("res://story/people/" + pf.file), pf.file)
		PEOPLE.merge(d.people); PNODES.merge(d.nodes)
	for p in PEOPLE.values():
		for x in p.chat + p.story + p.ask: PSTART[x.scene] = true
	var saved := _read(WORDS_PATH)
	if saved != "":
		var w = JSON.parse_string(saved)
		if w is Dictionary: words = w
	S = _fresh()


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


func warnings() -> Array:
	var out: Array = world_st.warnings.duplicate()
	for c in CH.values(): out.append_array(c.warnings)
	return out


func _fresh_world() -> Dictionary:
	return {"day": 1, "slot": 0, "frozen": 0, "money": START_MONEY, "rel": {}, "met": {}, "seen": {}, "evs": {}, "gossip": {},
		"inv": {}, "g": {}, "did": {}, "jobs": {}, "job": ""}


func _fresh() -> Dictionary:
	return {"world": _fresh_world(), "prog": {}, "done": {}, "ch": "", "loc": "", "node": "", "F": {}, "cs": {}, "visited": {}, "known": {}, "mx": {}, "tl": {}}


## ---------- the play log: everything you do, with the time, to read after a playtest.
##   adb shell run-as com.kopus123.tal cat files/playlog.txt
func note(what: String) -> void:
	if testing: return
	var s := (Time.get_ticks_msec() - _t0) / 1000
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null: return
	f.seek_end(); f.store_line("%02d:%02d  %s" % [s / 60, s % 60, what]); f.close()


## ---------- saving: one file, written after every change
func save() -> void:
	if testing: return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(S))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_save() -> bool:
	var d = JSON.parse_string(_read(SAVE_PATH))
	if not (d is Dictionary) or not CH.has(d.get("ch", "")): return false
	S = _fresh(); S.merge(d, true); S.world = _fresh_world(); S.world.merge(d.world, true)
	_use(S.ch)
	if not ST.places.has(S.loc): S.loc = ST.meta.get("start-place", "")
	if S.node != "" and not ST.nodes.has(S.node): S.node = ""
	_t0 = Time.get_ticks_msec(); note("\n===== back in %s, %s =====" % [S.ch, Time.get_datetime_string_from_system(false, true)])
	changed.emit(); return true


func save_words() -> void:
	if testing: return
	var f := FileAccess.open(WORDS_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(words))


## ---------- chapters
func chapter_info(id: String) -> Dictionary:
	for c in world_st.chapters:
		if c.id == id: return c
	return {}


func _use(id: String) -> void:
	var c: Dictionary = CH[id]
	var free: bool = chapter_info(id).get("free", false)
	ST = {"meta": world_st.meta.duplicate(), "cast": world_st.cast.duplicate(), "evidence": world_st.evidence.duplicate(),
		"places": c.places, "nodes": c.nodes.duplicate(), "statements": c.statements, "examines": c.examines, "cases": c.cases,
		"phones": c.phones, "hints": c.hints, "events": c.events, "encounters": c.encounters, "jobs": c.jobs, "free": free, "warnings": c.warnings}
	ST.meta.merge(c.meta, true); ST.cast.merge(c.cast, true); ST.evidence.merge(c.evidence, true)
	if free: ST.nodes.merge(PNODES)


func _stash() -> void:
	if S.ch != "": S.prog[S.ch] = JSON.parse_string(JSON.stringify({"loc": S.loc, "node": S.node, "F": S.F, "cs": S.cs, "visited": S.visited}))


## start a chapter (restart = from the top; otherwise carry on where you were in it)
func start_chapter(id: String, restart := true) -> void:
	_stash()
	var p: Dictionary = S.prog.get(id, {}) if not restart else {}
	S.ch = id; _use(id); _leaning = false
	if not p.is_empty() and p.get("F", {}).get("started", false):
		for k in ["loc", "node", "F", "cs", "visited"]: S[k] = p[k]
		if not ST.places.has(S.loc): S.loc = ST.meta.get("start-place", "")
		changed.emit(); save(); return
	S.F = {"started": 1}; S.cs = {}; S.visited = {}; S.node = ""; S.loc = ST.meta.get("start-place", ""); S.known[S.loc] = 1
	_t0 = Time.get_ticks_msec(); note("\n===== new playthrough of %s, %s =====" % [id, Time.get_datetime_string_from_system(false, true)])
	_stash(); go(ST.meta.get("start", ""))


## a test area or a single story file on its own (the shed)
func start(file: String) -> void:
	for c in world_st.chapters:
		if c.file == file: start_chapter(c.id, true); return


func next_chapter() -> Dictionary:
	var i := 0
	for c in world_st.chapters:
		i += 1
		if c.id == S.ch: return world_st.chapters[i] if i < world_st.chapters.size() else {}
	return {}


## the final deduction is solved: the chapter is done. A chapter that "continues" in the next file just goes on.
func finale() -> void:
	S.done[S.ch] = 1; _stash(); save()
	var nx := next_chapter()
	if not nx.is_empty() and nx.cont and CH.has(nx.id): start_chapter(nx.id, true); return
	finished.emit(S.ch)


func place() -> Dictionary: return ST.places.get(S.loc, {})
func beat() -> Dictionary: return ST.nodes.get(S.node, {})


## ---------- conditions: "a&!b", "money>=500", "rel:sujin>=2", "@shed", "time:night", "hold:sh_oil"
func cond_value(t: String) -> Variant:
	if t.begins_with("@"): return S.loc == t.substr(1)
	if t == "lit": return bool(S.F.get("lit", 0))
	if t == "money": return W.money
	if t == "day": return W.day
	if t == "clock": return not W.frozen
	if t == "allSolved": return case_ready()
	var i := t.find(":")
	if i > 0:
		var a := t.substr(i + 1)
		match t.substr(0, i + 1):
			"hold:": return S.F.get("hold", "") == a
			"time:": return slot_name() == a
			"g:": return W.g.get(a, 0)
			"rel:": return W.rel.get(a, 0)
			"has:": return W.inv.get(a, 0)
			"on:": return events_on(W.day).any(func(e): return e.id == a)
			"job:": return W.job == a
			"jobdone:": return W.jobs.get(a, {}).has("done")
			"here:": return PEOPLE.has(a) and people_here().has(PEOPLE[a])
	return S.F.get(t, 0)


func cond(c: String) -> bool:
	if c == "": return true
	var re := Story.R("^(.+?)(>=|<=|>|<|=)(-?\\d+)$")
	for term in c.split("&"):
		var t := term.strip_edges(); var neg := t.begins_with("!")
		if neg: t = t.substr(1)
		var m := re.search(t); var ok := false
		if m:
			var raw = cond_value(m.get_string(1))
			var v := float(raw) if raw != null else 0.0
			var n := float(m.get_string(3))
			match m.get_string(2):
				">=": ok = v >= n
				"<=": ok = v <= n
				">": ok = v > n
				"<": ok = v < n
				"=": ok = v == n
		else:
			ok = bool(cond_value(t))
		if ok == neg: return false
	return true


## "A ? B : C" targets
func target(t: String) -> String:
	var m := Story.R("^(.+?)\\s*\\?\\s*(\\S+)\\s*:\\s*(\\S+)$").search(t)
	return (m.get_string(2) if cond(m.get_string(1)) else m.get_string(3)) if m else t.strip_edges()


## ---------- effects. Money, friendship and items add up, so each beat pays them out only once, ever
## ("each time" at the end repeats it, like a bus fare).
const ONCE := ["money", "rel", "item", "time"]

func run_fx(list: Array, key := "") -> void:
	var i := -1
	for e in list:
		i += 1
		if e.c != "" and not cond(e.c): continue
		var a: String = e.a
		if e.k in ONCE and not (e.k == "time" and Story.R("^(stop|go|set\\s)").search(a)):
			var m := Story.R("^(.*?)\\s+each time$").search(a)
			if m: a = m.get_string(1)
			elif key != "":
				var k := "%s:%s:%d" % [S.ch, key, i]
				if W.did.has(k): continue
				W.did[k] = 1
		_effect(e.k, a)


func _effect(k: String, a: String) -> void:
	match k:
		"set":
			for f in a.split(","):
				f = f.strip_edges()
				if f.begins_with("g:"): W.g[f.substr(2)] = 1
				else: S.F[f] = 1
		"unset":
			for f in a.split(","):
				f = f.strip_edges()
				if f.begins_with("g:"): W.g.erase(f.substr(2))
				else: S.F.erase(f)
		"give", "have":
			for v in a.split(","):
				var id := v.strip_edges()
				if k == "give" and not S.F.has("ev_" + id):
					toast.emit("Evidence: " + plain(ST.evidence.get(id, {}).get("label", id)))
				S.F["ev_" + id] = 1
		"statement":
			if not S.F.has("st_" + a): S.F["st_" + a] = 1; toast.emit("Statement saved to your case board.")
		"place": S.loc = a; S.known[a] = 1
		"led": S.F["led"] = a
		"sfx": sound.emit(a)
		"toast": toast.emit(a)
		"learn": pass
		"mixup":
			var p := a.split("/")
			var key := "%s/%s" % [p[0].strip_edges(), p[1].strip_edges() if p.size() > 1 else ""]
			S.mx[key] = S.mx.get(key, 0) + 1
			toast.emit("You misheard that. Saved in your notebook: %s / %s" % [p[0].strip_edges(), p[1].strip_edges() if p.size() > 1 else ""])
		"money":
			var m := Story.R("^([+\\-=]?)(\\d+)$").search(a)
			if m:
				var before: int = W.money; var n := int(m.get_string(2))
				W.money = n if m.get_string(1) == "=" else maxi(0, W.money + (-n if m.get_string(1) == "-" else n))
				var d: int = W.money - before
				if d != 0: toast.emit("%s%s · %s left" % ["+" if d > 0 else "−", won(absi(d)), won(W.money)])
		"rel":
			var p := a.split(" ", false)
			if p.size() == 2:
				var m := Story.R("^([+\\-=]?)(\\d+)$").search(p[1])
				if m:
					if m.get_string(1) == "=": W.rel[p[0]] = int(m.get_string(2))
					else: add_rel(p[0], -int(m.get_string(2)) if m.get_string(1) == "-" else int(m.get_string(2)))
		"item":
			var m := Story.R("^([+-]?)(\\S+)$").search(a)
			if m:
				var n: int = maxi(0, W.inv.get(m.get_string(2), 0) + (-1 if m.get_string(1) == "-" else 1))
				if n > 0: W.inv[m.get_string(2)] = n
				else: W.inv.erase(m.get_string(2))
		"time":
			if a == "stop": W.frozen = 1
			elif a == "go": W.frozen = 0
			elif a == "sleep": next_morning()
			elif a.begins_with("set "):
				var i := SLOTS.find(a.substr(4).strip_edges())
				if i >= 0 and i != W.slot: W.slot = i; timecard.emit()
			elif a.begins_with("+"):
				for i in int(a.substr(1)): pass_time()
		"chapter": S.F["goChapter"] = a.strip_edges()
		"job": _job_effect(a)
		"away": W.g["away_" + a.strip_edges()] = W.day * 4 + W.slot
		_: push_warning("effect not in the Godot version yet: " + k)


static func won(n: int) -> String:
	var s := str(n); var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0: out += ","
		out += s[i]
	return out + "원"


## ---------- moving through the story
func go(id: String) -> void:
	id = target(id)
	if not ST.nodes.has(id):
		if id != "": push_warning("no scene " + id)
		S.node = ""; _end_lean(); save(); changed.emit(); return
	S.node = id; S.known[S.loc] = 1
	if ST.free and PSTART.has(id): W.seen[id] = W.day   # a villager's conversation, heard today
	var nd: Dictionary = ST.nodes[id]
	run_fx(nd.get("fx", []), id)
	if nd.has("ko"): _met(nd.ko)
	save(); changed.emit()


## Continue on a beat with no choices
func next() -> void:
	var b := beat()
	if b.has("rewind"): rewound.emit(); go(b.rewind)
	elif b.has("next"): go(b.next)
	elif S.F.has("goChapter"):
		var c: String = S.F.goChapter; S.F.erase("goChapter"); start_chapter(c, false)
	else:
		S.node = ""; _end_lean(); save()
		if not check_events(): changed.emit()


func choose(o: Dictionary) -> void:
	if o.get("ko", "").contains("안녕"): S.F["said_hi_" + S.loc] = W.day
	note("  chose: " + plain(o.get("en", o.get("ko", ""))))
	sound.emit("tap"); run_fx(o.get("fx", []), S.node + ">" + o.go); go(o.go)


## walk away from a beat that's waiting on you (the lock's "Leave it")
func leave() -> void:
	note("  walked away from it")
	S.node = ""; _end_lean(); save(); changed.emit()


## tapping away from a thing you're looking at: the rest of what happens there still happens, you just
## don't have to read it line by line; a question you haven't answered is left for later
func step_back() -> void:
	note("  stepped back")
	for i in 40:
		var b := beat()
		if b.is_empty(): break
		if b.has("ch") or b.has("type"):
			leave(); return
		next()
	_end_lean(); changed.emit()


## ---------- answers
func _digits(s: String) -> String:
	var out := ""
	for c in s:
		if c >= "0" and c <= "9": out += c
	return out


## the number pad / lock
func answer(value: String) -> void:
	var b := beat()
	var v := _digits(value)
	if b.get("kind", "") != "phone": v = v.lstrip("0") if v.lstrip("0") != "" else "0"
	for a in b.ans:
		var want := _digits(a[0])
		if b.get("kind", "") != "phone": want = want.lstrip("0") if want.lstrip("0") != "" else "0"
		if want == v:
			note("  tried %s: right" % value); go(a[1]); return
	note("  tried %s: wrong" % value); go(b.get("miss", ""))


## sentence tiles: the tiles you put in order
func answer_build(tiles: Array) -> void:
	var b := beat()
	note("  built: " + " ".join(tiles.map(func(t): return plain(t))))
	for a in b.ans:
		if a[0].size() == tiles.size() and range(tiles.size()).all(func(i): return a[0][i] == tiles[i]):
			go(a[1]); return
	go(b.get("miss", ""))


## typed Korean: close enough counts. Returns "exact", "close" (you see what to fix, then Continue goes on),
## "chat" (small talk: they answer and wait) or "miss".
const COMMON := [["안녕하세요", "{안녕하세요}!", "They say hello back, and wait for you to go on."], ["안녕", "{네}, {안녕하세요}~", "They nod, and wait."],
	["고마워요", "{네}~", "They smile. That wasn't what you came to say, though."], ["감사합니다", "{네}~", "They smile. That wasn't what you came to say, though."],
	["네", "{네}?", "They wait for the rest."], ["아니요", "{네}?", "They look confused."], ["몰라요", "...{네}?", "They wait."], ["저기요", "{네}?", "They wait for your question."]]
var typed_close: Dictionary = {}     ## after a "close" answer: {yours, correct, target}

func answer_type(val: String) -> String:
	var b := beat(); var v := _tnorm(val)
	if v == "": return ""
	note("  typed: " + val)
	var best: Array = []; var bd := 999; var bn := 1
	for a in b.ans:
		var d := jamo_dist(v, _tnorm(a[0]))
		if d < bd: bd = d; best = a; bn = jamo(_tnorm(a[0])).size()
	if not best.is_empty():
		# beginners misspell: about a third of the letters can be off (안녕하세요 with 3 slips still counts)
		var lim := maxi(2, int(round(bn * 0.3)))
		if bd <= lim and _tnorm(best[0]).contains("안녕"): S.F["said_hi_" + S.loc] = W.day
		if bd == 0: go(best[1]); return "exact"
		if bd <= lim: typed_close = {"yours": val, "correct": plain(best[0]), "target": best[1]}; changed.emit(); return "close"
	for c in COMMON:
		if jamo_dist(v, _tnorm(c[0])) <= 1:
			# hello again, after you've already said it here today: they just wait for what you came to say
			if c[0].begins_with("안녕") and S.F.get("said_hi_" + S.loc, -1) == W.day:
				reply.emit("{네}?", "You've already said hello. They're waiting for what you came to say."); return "chat"
			if c[0].begins_with("안녕"): S.F["said_hi_" + S.loc] = W.day
			reply.emit(c[1], c[2]); return "chat"
	go(b.get("miss", "")); return "miss"


func close_go_on() -> void:
	var t: String = typed_close.target; typed_close = {}; go(t)


func _tnorm(s: String) -> String:
	return Story.R("[\\s.?!~,·…]").sub(plain(s), "", true)


## Hangul -> letters, so 봣어요 vs 봤어요 counts as one small slip, not a whole wrong syllable
static func jamo(s: String) -> Array:
	var out := []
	for ch_ in s:
		var c := ch_.unicode_at(0) - 0xAC00
		if c >= 0 and c < 11172:
			out.append("L%d" % (c / 588)); out.append("V%d" % (c % 588 / 28))
			if c % 28: out.append("T%d" % (c % 28))
		else: out.append(ch_)
	return out


static func jamo_dist(a: String, b: String) -> int:
	var x := jamo(a); var y := jamo(b)
	var prev := range(y.size() + 1)
	for i in range(1, x.size() + 1):
		var cur := [i]
		for j in range(1, y.size() + 1):
			cur.append(mini(mini(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + (0 if x[i - 1] == y[j - 1] else 1)))
		prev = cur
	return prev[y.size()]


## show something you have
func present(id: String) -> void:
	var b := beat()
	note("  showed: " + id)
	for s in b.shows:
		if s[0] == id: go(s[1]); return
	go(b.get("miss", ""))


## two things that can't both be true
func clash(a: String, b_: String) -> void:
	var b := beat()
	note("  pointed out: %s / %s" % [a, b_])
	for p in b.pairs:
		if (p[0][0] == a and p[0][1] == b_) or (p[0][0] == b_ and p[0][1] == a): go(p[1]); return
	go(b.get("miss", ""))


## close-ups: tap what you notice
func exam() -> Dictionary: return ST.examines.get(beat().get("exam", ""), {})
func exam_found(d: Dictionary) -> bool: return S.F.has("ex_%s_%s" % [exam().id, d.id])
func exam_tap(detail_id: String) -> bool:
	var x := exam()
	for d in x.get("details", []):
		if d.id == detail_id and not exam_found(d):
			S.F["ex_%s_%s" % [x.id, d.id]] = 1; note("  noticed: " + detail_id)
			run_fx(d.fx, "ex_%s_%s" % [x.id, d.id]); _met(d.t); sound.emit("learn"); save(); changed.emit(); return true
	return false
func exam_keys_left() -> int:
	return exam().get("details", []).filter(func(d): return d.key and not exam_found(d)).size()


## ---------- places
func is_closed(p: String) -> bool:
	var pl: Dictionary = ST.places.get(p, {})
	return pl.has("closed") and cond(pl.closed.c)


func enter(p: String) -> bool:
	if not ST.places.has(p): return false
	if is_closed(p):
		sound.emit("wrong"); toast.emit(ST.places[p].closed.t); return false
	S.loc = p; S.node = ""; S.known[p] = 1; _end_lean()
	note("went to: %s (%s)" % [ST.places[p].get("sub", p), p])
	var pl := place()
	if pl.has("always"): go(pl.always); return true
	if pl.has("first") and not S.visited.has(p):
		S.visited[p] = 1; go(pl.first); return true
	S.visited[p] = 1; save()
	if not check_events(): changed.emit()
	return true


## the things you can tap right now (the first spot per label whose COND holds)
func spots_now() -> Array:
	var out := []; var seen := {}
	for s in place().get("spots", []):
		if seen.has(s.l) or not cond(s.c): continue
		seen[s.l] = true; out.append(s)
	return out


func tap_spot(s: Dictionary) -> void:
	S.F["found_%s_%s" % [S.loc, s.l]] = 1
	var h: String = S.F.get("hold", "")
	note("  tapped: %s%s%s" % [s.l, (" holding " + h) if h != "" else "", " (flashlight on)" if S.F.get("lit", 0) else ""])
	sound.emit("tap")
	if s.kind == "=>":
		var m := Story.R("^place\\s+(\\S+)").search(s.t)
		if m: enter(m.get_string(1))
		elif s.t == "board": changed.emit()   # the notice board opens from the screen
	else:
		_leaning = true; lean.emit(Vector2(s.x, s.y), true)
		go(s.t)


func _end_lean() -> void:
	if _leaning:
		_leaning = false; lean.emit(Vector2.ZERO, false)


func desc() -> String:
	for d in place().get("desc", []):
		if cond(d.c): return d.t
	return ""


func hint() -> String:
	for h in ST.get("hints", []):
		if cond(h.c): return h.t
	return "Look around."


## ---------- pockets: evidence you carry (notes and papers stay on the case board)
func pockets() -> Array:
	var out := []
	for id in ST.evidence:
		var e: Dictionary = ST.evidence[id]
		if S.F.has("ev_" + id) and e.icon not in ["letter", "photo", "phone", "card", "ticket", "man", "fake", "eyebrow", "paint", "wood", "boots", "bag"]: out.append(e)
	return out


func owned() -> Array:
	return ST.evidence.values().filter(func(e): return S.F.has("ev_" + e.id))


func owned_statements() -> Array:
	return ST.statements.values().filter(func(x): return S.F.has("st_" + x.id) and ST.nodes.has(x.node))


func pocket(id: String) -> void:
	sound.emit("click")
	note("  pocket: " + ("flashlight " + ("off" if S.F.get("lit", 0) else "on") if id == "flashlight" else ("put away " if S.F.get("hold", "") == id else "took out ") + id))
	if id == "flashlight": S.F["lit"] = 0 if S.F.get("lit", 0) else 1
	elif S.F.get("hold", "") == id: S.F.erase("hold")
	else: S.F["hold"] = id
	save(); changed.emit()


## ---------- the phone (할머니's): threads of messages; reading one can set flags
func has_phone() -> bool: return bool(S.F.get("hasPhone", 0)) and not ST.phones.is_empty()
func thread_msgs(t: Dictionary) -> Array: return t.m.filter(func(m): return cond(m.c))
func thread_unread(t: Dictionary) -> bool:
	return S.F.get("readn_" + t.id, 0) < thread_msgs(t).filter(func(m): return not m.has("d")).size()
func read_thread(id: String) -> void:
	for t in ST.phones:
		if t.id != id: continue
		run_fx(t.fx, "phone_" + id)
		S.F["read_" + id] = 1; S.F["readn_" + id] = thread_msgs(t).filter(func(m): return not m.has("d")).size()
		for m in thread_msgs(t):
			if m.has("ko"): _met(m.ko)
		note("  read messages: " + t.name); save(); changed.emit()
func heard_voicemail(id: String) -> void:
	S.F["vm_" + id] = 1; note("  listened to a voicemail in " + id); save(); changed.emit()


## ---------- the case board: fill in the blanks, pin the proof
func cases_open() -> Array: return ST.cases.filter(func(q): return cond(q.c))
func case_ready() -> bool: return ST.cases.filter(func(q): return not q.final and cond(q.c)).all(func(q): return S.cs.has(q.id))
func _norm_ans(s: String) -> String: return Story.R("[\\s.?!~,·]").sub(s, "", true)

func proof_ok(q: Dictionary, pf: Array) -> bool:
	var needs: Array = q.needs
	if needs.is_empty(): return true
	var orders := [[0, 1], [1, 0]] if needs.size() == 2 else [range(needs.size())]
	for o in orders:
		var ok := true
		for i in needs.size():
			if i >= pf.size() or not (pf[o[i]] in needs[i].alts): ok = false
		if ok: return true
	return false


## returns "" when solved, else what's wrong ("words", "proof", "both")
func solve(id: String, fill: Array, proofs: Array) -> String:
	var q: Dictionary = {}
	for c in ST.cases:
		if c.id == id: q = c
	if q.is_empty(): return "both"
	var words_ok: bool = q.blanks.size() == fill.size()
	if words_ok:
		for i in q.blanks.size():
			if not Array(q.blanks[i].split("/")).any(func(a): return _norm_ans(a) == _norm_ans(fill[i])): words_ok = false
	var p_ok := proof_ok(q, proofs)
	note("  case board %s: %s%s → %s" % [id, ", ".join(fill), (" + " + ", ".join(proofs)) if not proofs.is_empty() else "", "right" if words_ok and p_ok else "wrong"])
	if words_ok and p_ok:
		S.cs[id] = 1; S.F["solved_" + id] = 1; sound.emit("solve"); save(); changed.emit()
		if q.final: finale()
		return ""
	sound.emit("wrong")
	return "words" if p_ok else ("proof" if words_ok else "both")


## ---------- words you meet: remembered under each word in your notebook (the last few lines, newest first)
func word(w: String) -> Dictionary:
	if not words.has(w): words[w] = {"note": "", "sure": false, "ctx": []}
	return words[w]


func _met(text: String) -> void:
	var line := plain(text)
	for t in Story.tokens(text):
		var r := word(t[1])
		var ctx: Array = r.ctx
		ctx.erase(line); ctx.push_front(line)
		if ctx.size() > 5: ctx.resize(5)
	save_words()


static func plain(s: String) -> String: return Story.plain(s)


## ---------- the clock: morning, afternoon, evening, night. Sleeping starts the next morning.
func slot_name() -> String: return SLOTS[clampi(W.slot, 0, 3)]

func events_on(day: int) -> Array:
	return world_st.calendar.filter(func(e): return (e.day == day) if e.has("day") else (day >= e.from and (day - e.from) % e.every == 0))

func pass_time() -> bool:
	if W.frozen or W.slot >= 3: return false
	_miss_events(); W.slot += 1; timecard.emit(); _closing_time(); save()
	note("time passed: now " + slot_name())
	if not check_events(): changed.emit()
	return true

func next_morning() -> void:
	_miss_events(); W.day += 1; W.slot = 0; timecard.emit(); save()
	note("slept: day %d" % W.day)

## if the place you're in has just closed, you're shown out to the first open place its exits lead to
func _closing_time() -> void:
	if not is_closed(S.loc): return
	for s in place().get("spots", []):
		var m := Story.R("^place\\s+(\\S+)").search(s.t)
		var p := m.get_string(1) if m else _scene_exit(s.t)
		if p != "" and ST.places.has(p) and not is_closed(p):
			toast.emit(place().closed.t + " You head back outside."); S.loc = p; return

func _scene_exit(sc: String, depth := 0) -> String:
	if not Story.R("^\\w+$").search(sc): return ""
	var i := 1; var id := sc
	while ST.nodes.has(id):
		var nd: Dictionary = ST.nodes[id]
		for f in nd.get("fx", []):
			if f.k == "place": return f.a.strip_edges()
		if depth < 1:
			for c in nd.get("ch", []):
				var p := _scene_exit(c.go, depth + 1)
				if p != "": return p
		i += 1; id = "%s.%d" % [sc, i]
	return ""


## ---------- villagers (free days): who is where, friendship, the talk menu
func rel_level(who: String) -> int: return REL_STEPS.filter(func(n): return W.rel.get(who, 0) >= n).size()

func add_rel(who: String, n: int) -> void:
	var before := rel_level(who)
	W.rel[who] = maxi(0, W.rel.get(who, 0) + n)
	if rel_level(who) > before: toast.emit("You and %s are getting closer. %s" % [ST.cast.get(who, {}).get("n", who), "♥".repeat(rel_level(who))])

## FNV-style hash, the same numbers as the web version (so the same people are in the same places on the same day)
static func day_hash(s: String) -> int:
	var a := 2166136261
	for i in s.length(): a = _imul(a ^ s.unicode_at(i), 16777619)
	a = a ^ (a >> 16); a = _imul(a, 0x45d9f3b)
	return (a ^ (a >> 16)) & 0xFFFFFFFF

static func _imul(a: int, b: int) -> int:
	a &= 0xFFFFFFFF; b &= 0xFFFFFFFF
	return ((a * (b & 0xFFFF)) + (((a * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF

func where_now(p: Dictionary, slot := "") -> Dictionary:
	if slot == "": slot = slot_name()
	var o: Array = p.at.get(slot, [])
	if o.is_empty(): return {}
	return o[day_hash("%d/%s/%s" % [W.day, p.id, slot]) % o.size()]

func away_now(id: String) -> bool: return W.g.get("away_" + id, -1) == W.day * 4 + W.slot

func people_here() -> Array:
	if not ST.get("free", false) or W.frozen: return []
	var out := []
	for p in PEOPLE.values():
		var a := where_now(p)
		if not a.is_empty() and a.place == S.loc and not away_now(p.id): out.append(p)
	return out

func _bye(p: Dictionary) -> String:
	var k: String = "bye_" + p.id; var n: int = W.g.get(k, 0); W.g[k] = n + 1
	return p.bye[n % maxi(1, p.bye.size())] if not p.bye.is_empty() else ""

## 은 after a final consonant, 는 after a vowel: "할머니는?" = "what about grandma?"
static func topic_of(w: String) -> String:
	var c := w.unicode_at(w.length() - 1) - 0xAC00
	return "{%s}{%s|은/는}?" % [w, "은" if c >= 0 and c < 11172 and c % 28 else "는"]

func talk_to(id: String) -> void:
	var p: Dictionary = PEOPLE.get(id, {})
	if p.is_empty(): return
	sound.emit("tap"); note("  talked to " + id)
	var day: int = W.day; var lv := rel_level(id); var seen: Dictionary = W.seen
	var ok := func(x): return x.lv <= lv and cond(x.c)
	if W.met.get(id, -1) != day:
		W.met[id] = day; go(p.greet[(day + id.length()) % maxi(1, p.greet.size())]); return
	var told: Array = W.gossip.get(id, [])
	if not told.is_empty(): go(told.pop_front()); return
	var job := job_on(); var js: String = job.ask.get(id, "") if not job.is_empty() else ""
	var st = null
	for x in p.story:
		if ok.call(x) and not seen.has(x.scene): st = x; break
	if st != null and js == "": go(st.scene); return
	var pool: Array = p.chat.filter(func(x): return ok.call(x) and seen.get(x.scene, -1) != day)
	pool.sort_custom(func(a, b): return seen.get(a.scene, 0) < seen.get(b.scene, 0))
	var asks: Array = p.ask.filter(func(x): return cond(x.c) and words.has(x.word) and seen.get(x.scene, -1) != day)
	if asks.is_empty() and js == "": go(pool[0].scene if not pool.is_empty() else _bye(p)); return
	var opts := []
	if js != "": opts.append({"en": "About the job: " + job.en, "go": js, "c": "", "fx": []})
	if st != null: opts.append({"en": "Just chat", "go": st.scene, "c": "", "fx": []})
	elif not pool.is_empty(): opts.append({"en": "Just chat", "go": pool[0].scene, "c": "", "fx": []})
	for x in asks: opts.append({"ko": topic_of(x.word), "go": x.scene, "c": "", "fx": []})
	opts.append({"en": "Leave it for now", "go": _bye(p), "c": "", "fx": []})
	var key := "_talk_" + id
	ST.nodes[key] = {"id": key, "who": "narr", "en": "What do you want to talk to %s about?" % ST.cast.get(id, {}).get("n", id), "ch": opts}
	go(key)


## ---------- events and encounters (free days)
func _ev_key(e: Dictionary) -> String: return "%s@%d" % [e.id, W.day]

func events_now() -> Array:
	if not ST.get("free", false) or W.frozen: return []
	return ST.events.filter(func(e): return e.slot == slot_name() and cond(e.when) and not W.evs.has(_ev_key(e)))

func check_events() -> bool:
	if S.node != "": return false
	for e in events_now():
		if e.place == S.loc: W.evs[_ev_key(e)] = "seen"; go(e.scene); return true
	if enc_off: return false
	for n in encounters_today():
		var k := "enc:%s@%d" % [n.id, W.day]
		if n.slot == slot_name() and n.place == S.loc and not W.evs.has(k): W.evs[k] = "seen"; go(n.scene); return true
	return false

func encounters_today() -> Array:
	if not ST.get("free", false) or W.frozen or ST.encounters.is_empty(): return []
	var d: int = W.day
	var pool: Array = ST.encounters.filter(func(n): return not n.at.is_empty() and cond(n.when) and not W.evs.has("enc:%s@%d" % [n.id, d - 1]))
	pool.sort_custom(func(a, b): return day_hash("%d/%s" % [d, a.id]) < day_hash("%d/%s" % [d, b.id]))
	var picked := []; var used := {}
	for n in pool:
		if picked.size() >= 2 + day_hash("n%d" % d) % 2: break
		var at: Dictionary = n.at[day_hash("%d@%s" % [d, n.id]) % n.at.size()]
		var k: String = at.slot + " " + at.place
		if used.has(k): continue
		used[k] = true; picked.append({"id": n.id, "scene": n.scene, "slot": at.slot, "place": at.place})
	return picked

func _miss_events() -> void:
	for e in events_now():
		W.evs[_ev_key(e)] = "missed"
		if not e.missed.is_empty():
			if not W.gossip.has(e.missed[0]): W.gossip[e.missed[0]] = []
			W.gossip[e.missed[0]].append(e.missed[1])


## ---------- jobs from the notice board
func job_on() -> Dictionary: return ST.jobs.get(W.job, {}) if W.job != "" else {}

func jobs_today() -> Array:
	var list := []
	for j in ST.jobs.values():
		var s: Dictionary = W.jobs.get(j.id, {})
		if not s.has("done") and s.get("failed", -1) != W.day and W.job != j.id and cond(j.when): list.append(j)
	list.sort_custom(func(a, b): return day_hash("%d:%s" % [W.day, a.id]) < day_hash("%d:%s" % [W.day, b.id]))
	return list.slice(0, 3)

func take_job(id: String) -> void:
	var j: Dictionary = ST.jobs.get(id, {})
	if j.is_empty() or W.job != "": return
	W.job = id
	var re := Story.R("^(ev_|st_|ex_)?" + id + "_")
	for k in S.F.keys():
		if re.search(k): S.F.erase(k)
	note("  took the job: " + j.en); save(); go(j.start)

func _job_effect(a: String) -> void:
	var j := job_on()
	if j.is_empty(): return
	if a == "done":
		W.jobs[j.id] = {"done": W.day}; W.job = ""; W.money += j.pay; add_rel(j.client, j.thanks); sound.emit("solve")
		toast.emit("Job done: %s · +%s" % [j.en, won(j.pay)])
	elif a == "fail":
		W.jobs[j.id] = {"failed": W.day}; W.job = ""; sound.emit("wrong")
		toast.emit("The job's off for today: %s. It'll be back another day." % j.en)
