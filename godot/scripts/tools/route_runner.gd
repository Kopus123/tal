class_name RouteRunner
extends RefCounted
## Plays a playthrough file (tests/routes/NAME.route, the web version's format) through the Godot engine, step by step.
## Used by tests/test_routes.gd (headless, as a test) and scripts/tools/shot_tour.gd (on screen, with screenshots:
## set `after_step`, an awaitable callable(cmd, arg), and it's called after every step).
## Steps about the web's notebook internals (guess, used, knows, note) are skipped and counted.

const SKIP := ["guess", "used", "knows", "note"]
var g: Node
var failed := false
var skipped := 0
var line_no := 0
var route := ""
var after_step: Callable
var stop_at := ""     ## stop at this "#@ checkpoint" label


func _init(game: Node) -> void:
	g = game


func run(name: String) -> bool:
	## returns true when the route played through (or reached stop_at)
	route = name; failed = false; skipped = 0
	var text := FileAccess.get_file_as_string("res://tests/routes/%s.route" % name)
	var n := 0; line_no = 0
	for raw in text.split("\n"):
		line_no += 1
		var line := raw.strip_edges()
		if stop_at != "" and line.begins_with("#@") and line.substr(2).strip_edges() == stop_at: return true
		if line == "" or line.begins_with("#"): continue
		var sp := line.find(" ")
		var cmd := line if sp < 0 else line.substr(0, sp)
		var arg := "" if sp < 0 else line.substr(sp + 1).strip_edges()
		if cmd in SKIP: skipped += 1; continue
		if cmd == "oldsave":   # the rest checks how web saves upgrade: there are no web saves in the Godot app
			print("     %s: stopped at line %d (old web saves don't apply to the Godot app)" % [name, line_no]); break
		if not has_method("s_" + cmd): fail("unknown step " + cmd); break
		call("s_" + cmd, arg)
		if failed: break
		n += 1
		if after_step.is_valid(): await after_step.call(cmd, arg)
	if not failed: print("ok   %s: %d steps%s" % [name, n, ("  (%d skipped: notebook details)" % skipped) if skipped else ""])
	return not failed


func fail(msg: String) -> void:
	if failed: return
	failed = true
	printerr("FAIL %s.route:%d: %s\n     at %s, place %s, beat %s" % [route, line_no, msg, g.S.ch, g.S.loc, g.S.node if g.S.node != "" else "(looking around)"])


## ---------- moving on
func _waits(b: Dictionary) -> bool:   ## a beat that needs you to do something (not just Continue)
	return b.has("ch") or b.get("type", "") in ["build", "type", "number", "present", "contradict", "camera"] \
		or (b.get("type", "") == "examine" and g.exam_keys_left() > 0)


func idle() -> void:
	for i in 150:
		if g.S.node == "" or failed: return
		if _waits(g.beat()): fail("needs a decision before it can go on"); return
		g.next()
	fail("never finished the scene")


## Continue until `found` returns something
func until(found: Callable, what: String) -> Variant:
	for i in 150:
		var f = found.call()
		if f: return f
		if g.S.node == "" or _waits(g.beat()): break
		g.next()
	fail("never reached " + what); return null


func _type_is(t: String) -> Callable: return func(): return g.beat().get("type", "") == t


## ---------- the steps
func s_chapter(a: String) -> void:
	g.S = g._fresh(); g.enc_off = true; g.typed_close = {}; g.start_chapter(a, true)

func s_switch(a: String) -> void: g.start_chapter(a, true)
func s_idle(_a: String) -> void: idle()
func s_expect(a: String) -> void:
	if not g.cond(a): fail("expected " + a)
func s_done(a: String) -> void:
	if not g.S.done.has(a): fail("chapter %s isn't finished" % a)
func s_encounters(a: String) -> void: g.enc_off = a != "on"

func s_choose(a: String) -> void:
	var o = until(func():
		for c in g.beat().get("ch", []):
			if g.cond(c.c) and g.plain(c.get("en", c.get("ko", ""))).contains(a): return c
		return null, 'a choice "%s"' % a)
	if o: g.choose(o)

func s_anychoice(_a: String) -> void:
	var o = until(func():
		for c in g.beat().get("ch", []):
			if g.cond(c.c): return c
		return null, "a choice")
	if o: g.choose(o)

func _spot(label: String) -> Dictionary:
	for s in g.place().get("spots", []):
		if s.l == label and g.cond(s.c): return s
	return {}

func s_spot(a: String) -> void:
	idle()
	var s := _spot(a)
	if s.is_empty(): fail('no spot "%s" here (spots: %s)' % [a, ", ".join(g.spots_now().map(func(x): return x.l))]); return
	g.tap_spot(s)

func s_tap(a: String) -> void: s_spot(a)

func s_nospot(a: String) -> void:
	idle()
	if not _spot(a).is_empty(): fail('"%s" is offered here but shouldn\'t be' % a)

func s_type(a: String) -> void:
	if until(_type_is("type"), "a typed answer") == null: return
	var r: String = g.answer_type(a)
	if r == "close": g.close_go_on()

func s_build(a: String) -> void:
	if until(_type_is("build"), "sentence tiles") == null: return
	var tiles: Array = g.beat().tiles; var used := {}; var seq := []
	for w in Story.split_bar(a):
		var hit := -1
		for i in tiles.size():
			if not used.has(i) and g.plain(tiles[i]) == g.plain(w): hit = i; break
		if hit < 0: fail('no tile "%s"' % w); return
		used[hit] = true; seq.append(tiles[hit])
	g.answer_build(seq)

func s_number(a: String) -> void:
	if until(_type_is("number"), "a number pad") == null: return
	g.answer(a)

func s_present(a: String) -> void:
	if until(_type_is("present"), 'a chance to show "%s"' % a) == null: return
	if not g.S.F.has("ev_" + a): fail('"%s" isn\'t something you have' % a); return
	g.present(a)

func s_contradict(a: String) -> void:
	if until(_type_is("contradict"), "a contradiction") == null: return
	var p := a.split("+")
	for k in p:
		k = k.strip_edges()
		if not g.S.F.has("ev_" + k) and not g.S.F.has("st_" + k): fail('"%s" isn\'t on the list to pick' % k); return
	g.clash(p[0].strip_edges(), p[1].strip_edges())

func s_examine(a: String) -> void:
	if until(_type_is("examine"), "a close-up") == null: return
	for d in a.split("|"):
		if not g.exam_tap(d.strip_edges()): fail('tapping "%s" didn\'t find it' % d.strip_edges()); return
	if g.exam_keys_left() > 0: fail("the close-up still wants more details"); return
	g.next()

func s_camera(_a: String) -> void:
	if until(_type_is("camera"), "the camera") == null: return
	g.next()

func s_leave(_a: String) -> void:
	if until(func(): return _waits(g.beat()), "a Never mind") == null: return
	g.leave()

func s_phone(a: String) -> void:
	if not g.ST.phones.any(func(t): return t.id == a): fail('no phone thread "%s"' % a); return
	g.read_thread(a)
	for t in g.ST.phones:
		if t.id == a and g.thread_msgs(t).any(func(m): return m.has("vm")): g.heard_voicemail(a)

func s_map(a: String) -> void:
	idle()
	if not g.S.known.has(a): fail('"%s" isn\'t on the map yet' % a); return
	g.enter(a)
	if g.S.loc != a: fail("map didn't go to " + a)

func s_closed(a: String) -> void:
	idle()
	var before: String = g.S.loc
	if g.enter(a) or g.S.loc != before: fail(a + " let you in, but it should be closed")

func s_talk(a: String) -> void:
	idle()
	var p: Dictionary = g.PEOPLE.get(a, {})
	if not g.people_here().has(p):
		var w: Dictionary = g.where_now(p) if not p.is_empty() else {}
		if not w.is_empty() and w.place != g.S.loc and g.S.known.has(w.place): g.enter(w.place); idle()
	if not g.people_here().has(p): fail("%s isn't here now (here: %s)" % [a, ", ".join(g.people_here().map(func(x): return x.id))]); return
	g.talk_to(a)

func s_wait(_a: String) -> void:
	idle()
	if g.W.frozen or g.W.slot >= 3: fail("there is no Wait here (is the clock running, and is it before night?)"); return
	g.pass_time()

func s_sleep(_a: String) -> void:
	idle()
	if g.W.frozen or g.S.loc != g.ST.meta.get("home", "") or g.W.slot < 2: fail("there is no Go to bed here (home, evening or night, clock running)"); return
	g.next_morning()

func s_job(a: String) -> void:
	idle()
	if _spot("Notice board").is_empty(): fail("no notice board here"); return
	if not g.jobs_today().any(func(j): return j.id == a) or g.W.job != "":
		fail('job "%s" isn\'t on the board (on it: %s)' % [a, ", ".join(g.jobs_today().map(func(j): return j.id))]); return
	g.take_job(a)

func s_noboard(a: String) -> void:
	if g.jobs_today().any(func(j): return j.id == a): fail('job "%s" is on the board, but shouldn\'t be' % a)

func s_shown(a: String) -> void:
	if a.begins_with("#bPhone"):
		if g.has_phone() != (not a.ends_with("no")): fail("the phone button is " + ("showing" if g.has_phone() else "hidden"))

func s_saved(a: String) -> void:
	if a.begins_with("m.") or a.begins_with("w.") or a.begins_with("tl."): skipped += 1; return
	var v: Variant = g.S
	for k in a.split("."):
		if v is Dictionary: v = v.get(k)
		elif v is Array and k.is_valid_int(): v = v[int(k)] if int(k) < v.size() else null
		else: v = null
	if not v: fail("the save has nothing at " + a)

func s_fx(a: String) -> void:
	var m := Story.R("^@(\\S+)\\s+(.+)$").search(a)
	g.run_fx(Story.parse_fx(m.get_string(2) if m else a), m.get_string(1) if m else "")

func s_solve(a: String) -> void: _solve(a, false)
func s_nosolve(a: String) -> void: _solve(a, true)
func _solve(a: String, expect_fail: bool) -> void:
	var parts := a.split(";")
	var head := parts[0].strip_edges().split(" ", false)
	var id := head[0]
	var fill := []
	for w in " ".join(head.slice(1)).split("|"):
		if w.strip_edges() != "": fill.append(w.strip_edges())
	var proofs := []
	if parts.size() > 1:
		for p in parts[1].split("+"): proofs.append(p.strip_edges())
	var q = null
	for c in g.ST.cases:
		if c.id == id: q = c
	if q == null: fail("no deduction " + id); return
	if not g.cond(q.c): fail("deduction %s isn't on the board yet" % id); return
	var r: String = g.solve(id, fill, proofs)
	if expect_fail and r == "": fail("deduction %s was accepted but shouldn't be" % id)
	if not expect_fail and r != "": fail("deduction %s not accepted (%s off)" % [id, r])

func s_pocket(a: String) -> void:
	idle()
	if not g.pockets().any(func(e): return e.id == a): fail(a + " isn't in your pockets"); return
	g.pocket(a)

func s_back(_a: String) -> void:
	idle()
	if not g.place().has("back"): fail("no back arrow here"); return
	g.enter(g.place().back)


## ---------- the case board lab
func s_link(a: String) -> void:
	idle()
	var p := a.split(" ", false)
	for id in p:
		if not g.board().cards.has(id): fail('"%s" is not on your board' % id); return
	var r: String = g.board_link(p[0], p[1])
	if r != "": fail("couldn't pin that string: " + r)

func s_unlink(a: String) -> void:
	var p := a.split(" ", false)
	if not g.is_linked(p[0], p[1]): fail("there's no string between %s and %s" % [p[0], p[1]]); return
	g.board_unlink(p[0], p[1])

func s_buy(a: String) -> void:
	if not g.board_buy(a): fail("couldn't buy " + a)

func s_nogo(a: String) -> void:
	idle()
	if not _spot(a).is_empty(): fail('"%s" is open, but should not be yet' % a)
