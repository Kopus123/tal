extends Node
## The game's state and story flow (autoload "Game"). Same rules as js/core/flow.js and js/core/rules.js:
## places with spots, scenes made of beats, choices, effects ("! set x"), conditions ("if lit&!oiled").
## Nothing here draws anything: the UI listens to `changed`, `sound` and `toast` and asks for what it needs.

signal changed          ## something visible changed: redraw
signal sound(name: String)
signal toast(text: String)
signal lean(at: Vector2, on: bool)   ## lean in on a thing (x, y in % of the picture) while you look at it

var world: Dictionary = {}     ## world.story: words, meanings, cast
var ch: Dictionary = {}        ## the chapter being played (a story file)
var F: Dictionary = {}         ## flags: anything "! set x" turned on, plus ev_ID (evidence you have)
var loc := ""                  ## the place you're in
var node := ""                 ## the beat on screen ("" = looking around)
var time_slot := "night"
var _leaning := false

## ---------- the play log: everything you do, with the time, so a playtest can be read afterwards.
## On the phone it's in the app's files; from the laptop:  adb shell run-as com.kopus123.tal cat files/playlog.txt
const LOG_PATH := "user://playlog.txt"
var _t0 := 0


func note(what: String) -> void:
	var s := (Time.get_ticks_msec() - _t0) / 1000
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null: return
	f.seek_end(); f.store_line("%02d:%02d  %s" % [s / 60, s % 60, what]); f.close()


func _ready() -> void:
	world = Story.parse(_read("res://story/world.story"), "world.story")


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


## start a story file from the top
func start(file: String) -> void:
	ch = Story.parse(_read("res://story/" + file), file)
	_t0 = Time.get_ticks_msec()
	note("
===== new playthrough of %s, %s =====" % [file, Time.get_datetime_string_from_system(false, true)])
	for w in ch.warnings: push_warning("story line not understood: " + w)
	F = {"started": 1}; loc = ch.meta.get("start-place", ""); node = ""; _leaning = false
	go(ch.meta.get("start", ""))


func place() -> Dictionary: return ch.places.get(loc, {})
func beat() -> Dictionary: return ch.nodes.get(node, {})


## ---------- conditions: "a&!b", "lit", "hold:sh_oil", "@shed", "time:night", "ev_sh_key"
func cond(c: String) -> bool:
	if c == "": return true
	for term in c.split("&"):
		var neg := term.begins_with("!")
		var t := term.trim_prefix("!")
		var v := false
		if t == "lit": v = bool(F.get("lit", 0))
		elif t.begins_with("hold:"): v = F.get("hold", "") == t.substr(5)
		elif t.begins_with("@"): v = loc == t.substr(1)
		elif t.begins_with("time:"): v = time_slot == t.substr(5)
		else: v = bool(F.get(t, 0))
		if v == neg: return false
	return true


## "A ? B : C" targets
func _target(t: String) -> String:
	var m := RegEx.create_from_string("^(\\S+)\\s*\\?\\s*(\\S+)\\s*:\\s*(\\S+)$").search(t)
	return (m.get_string(2) if cond(m.get_string(1)) else m.get_string(3)) if m else t


## ---------- effects
func run_fx(list: Array) -> void:
	for e in list:
		if e.c != "" and not cond(e.c): continue
		var a: String = e.a
		match e.k:
			"set":
				for f in a.split(","): F[f.strip_edges()] = 1
			"unset":
				for f in a.split(","): F.erase(f.strip_edges())
			"give", "have":
				for v in a.split(","):
					var id := v.strip_edges()
					if e.k == "give" and not F.has("ev_" + id):
						toast.emit("You found: " + plain(ch.evidence.get(id, {}).get("label", id)))
					F["ev_" + id] = 1
			"place": loc = a
			"sfx": sound.emit(a)
			"toast": toast.emit(a)
			"time":
				var m := RegEx.create_from_string("^set\\s+(\\w+)$").search(a)
				if m: time_slot = m.get_string(1)
			_: pass   # effects the Godot version doesn't need yet (money, rel, statement, ...)


## ---------- moving through the story
func go(id: String) -> void:
	id = _target(id)
	if not ch.nodes.has(id):
		node = ""; _end_lean(); changed.emit(); return
	node = id
	run_fx(ch.nodes[id].get("fx", []))
	changed.emit()


## Continue on a beat with no choices
func next() -> void:
	var b := beat()
	if b.has("rewind"): go(b.rewind)
	elif b.has("next"): go(b.next)
	else:
		node = ""; _end_lean(); changed.emit()


func choose(o: Dictionary) -> void:
	note("  chose: " + plain(o.get("en", o.get("ko", ""))))
	sound.emit("tap"); run_fx(o.fx); go(o.go)


## the number pad / lock: compare digits
func answer(value: String) -> void:
	var b := beat()
	for a in b.ans:
		if _digits(a[0]) == _digits(value):
			note("  tried %s: right" % value); go(a[1]); return
	note("  tried %s: wrong" % value)
	go(b.get("miss", ""))


func _digits(s: String) -> String:
	var out := ""
	for c in s:
		if c >= "0" and c <= "9": out += c
	return out


## walk away from a beat that's waiting on you (the lock's "Leave it")
func leave() -> void:
	note("  walked away from it")
	node = ""; _end_lean(); changed.emit()


func enter(p: String) -> void:
	if not ch.places.has(p): return
	loc = p; node = ""; _end_lean()
	note("went to: %s (%s)" % [ch.places[p].get("sub", p), p])
	var pl := place()
	if pl.has("first") and not F.has("visited_" + p):
		F["visited_" + p] = 1; go(pl.first); return
	F["visited_" + p] = 1
	changed.emit()


## ---------- explore places: the things you can tap right now (the first spot per label whose COND holds)
func spots_now() -> Array:
	var out := []; var seen := {}
	for s in place().get("spots", []):
		if seen.has(s.l) or not cond(s.c): continue
		seen[s.l] = true; out.append(s)
	return out


func tap_spot(s: Dictionary) -> void:
	var h: String = F.get("hold", "")
	note("  tapped: %s%s%s" % [s.l, (" holding " + h) if h != "" else "", " (flashlight on)" if F.get("lit", 0) else ""])
	F["found_%s_%s" % [loc, s.l]] = 1
	sound.emit("tap")
	if s.kind == "=>":
		var m := RegEx.create_from_string("^place\\s+(\\S+)").search(s.t)
		if m: enter(m.get_string(1))
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
	for h in ch.get("hints", []):
		if cond(h.c): return h.t
	return "Look around."


## ---------- pockets: evidence you carry (notes stay out). Tap: the flashlight switches on/off; anything else you hold.
func pockets() -> Array:
	var out := []
	for id in ch.evidence:
		var e: Dictionary = ch.evidence[id]
		if F.has("ev_" + id) and e.icon != "letter": out.append(e)
	return out


func pocket(id: String) -> void:
	sound.emit("click")
	note("  pocket: " + ("flashlight " + ("off" if F.get("lit", 0) else "on") if id == "flashlight" else ("put away " if F.get("hold", "") == id else "took out ") + id))
	if id == "flashlight": F["lit"] = 0 if F.get("lit", 0) else 1
	elif F.get("hold", "") == id: F.erase("hold")
	else: F["hold"] = id
	changed.emit()


## ---------- words
## "{봤어요}" -> "봤어요"
static func plain(s: String) -> String:
	return RegEx.create_from_string("\\{([^}|]+)(?:\\|[^}]+)?\\}").sub(s, "$1", true)
