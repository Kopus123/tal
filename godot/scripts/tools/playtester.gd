class_name Playtester
extends RouteRunner
## A player made of code: plays a route (tests/routes/*.route) through the real screen with a fingertip, as fast as the
## laptop draws, and reports everything a person would trip over.   python tools/gd_play.py [ROUTE] [STOP]
##
## It never calls the game's rules to move on: it finds the button (or card, or spot in the picture), swipes to it if
## it's below the fold, and presses it with a wobbly, off-center finger. Along the way, on every new screen:
##   - everything the story offers right now is on screen, and only goes away when it should (_expected)
##   - every button is on screen, big enough for a finger, not covered, not overlapping, its words not cut off
##   - everything longer than its box can be swiped from anywhere, and a swipe never presses anything
##   - every other choice, wrong answer and "Never mind" is tried too, then taken back (_branch)
##   - the notebook, phone, board, box, map, menu, log, settings, day panel and camera are gone through (_pages)
##   - the game is saved and loaded back at each checkpoint, and has to look the same
##   - script errors are caught with the step that caused them
## Time runs 40x, voices take one frame. Problems are printed once each, with a picture (build/play/bug_*.jpg).

const FINGER := 48.0          ## smallest comfortable target, in screen units (720 = the phone's height = 73 mm)
const WOBBLE := 9.0           ## a fingertip moves about a millimeter during a tap
const SMALL_OK := ["✕"]
const SCROLLERS := ["paper", "sheet"]

var main: Control
var dir := ""
var issues: Array = []        ## {kind, text, where, n, shot}
var _issue_at := {}
var _seen := {}               ## screens already inspected
var _tried := {}              ## options, spots, answers already tried
var _bar_pos := {}
var _shots := 0
var _bugs := 0
var _tasks: Array = []
var taps := 0
var swipes := 0
var screens := 0
var _step := ""
var _rng := RandomNumberGenerator.new()
var _t0 := 0
var _depth := 0               ## inside a side trip (a choice tried and taken back)
var errors: Catcher
var _from_line := 0


## errors from the engine and the scripts, as they happen
class Catcher extends Logger:
	var got: Array = []
	var m := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _ed: bool, type: int, bt: Array) -> void:
		if type == 1: return   # warnings
		var at := "%s:%d" % [file.get_file(), line]
		for b in bt:
			if b.get_frame_count() > 0: at = "%s:%d (%s)" % [b.get_frame_file(0).get_file(), b.get_frame_line(0), b.get_frame_function(0)]; break
		m.lock(); got.append("%s  at %s" % [rationale if rationale != "" else code, at]); m.unlock()
	func take() -> Array:
		m.lock(); var g := got; got = []; m.unlock(); return g


## from, stop: "#@ checkpoint" labels. Before `from`, the story is run through without the screen (instantly).
func play(m: Control, out_dir: String, name: String, stop := "", from := "") -> void:
	main = m; dir = out_dir; _t0 = Time.get_ticks_msec()
	_rng.seed = 5
	DirAccess.make_dir_recursive_absolute(dir)
	Game.testing = true; Voice.instant = true; Settings.frozen = true; Swipe.glide = false; g.words = {}; main.guard = 0
	if "--large" in OS.get_cmdline_user_args(): Settings.get_("size"); Settings.v.size = 2   # some parts are played with the biggest text
	Engine.time_scale = 40.0; Engine.max_fps = 0; OS.low_processor_usage_mode = false; OS.low_processor_usage_mode_sleep_usec = 1
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if not "--show" in OS.get_cmdline_user_args(): DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true); DisplayServer.window_set_position(Vector2i(-6000, -6000))
	RenderingServer.render_loop_enabled = "--show" in OS.get_cmdline_user_args()   # nothing is drawn except for the pictures
	var fb: Array[Font] = []   # asking Windows for a font for every Korean word is what takes the time
	for fn in ["malgun.ttf", "seguisym.ttf", "seguiemj.ttf"]:
		var ff := FontFile.new()
		if ff.load_dynamic_font("C:/Windows/Fonts/" + fn) == OK: fb.append(ff)
	ThemeDB.fallback_font.fallbacks = fb
	errors = Catcher.new(); OS.add_logger(errors)
	main.room.vp.size = Vector2i(640, 480); main.room.vp.size_2d_override = Vector2i(1600, 1200); main.room.vp.size_2d_override_stretch = true   # the same picture, cheaper to draw
	await _frames(4)
	var first := ""
	for l in FileAccess.get_file_as_string(route_file(name)).split("\n"):
		if l.begins_with("chapter "): first = l.substr(8).strip_edges(); break
	if stop == "-": stop = ""
	_part("")
	if from == "": await _title_screen(first)
	else:
		var r := RouteRunner.new(g); r.stop_at = from
		main.leave_title()
		if not await r.run(name) or r.line_no <= 1: print("couldn't get to " + from)
		_from_line = r.line_no; main._shown_node = "?"; g.changed.emit(); await settle()
	await close_top()
	var ok: bool = await play_route(name, stop)
	if not failed and stop == "": await _pages("the end")
	_part("end")
	for t in _tasks: WorkerThreadPool.wait_for_task_completion(t)
	_report(name, ok)
	main.get_tree().quit(0 if ok and issues.is_empty() else 1)


func _report(name: String, ok: bool) -> void:
	var secs := (Time.get_ticks_msec() - _t0) / 1000.0
	var rank := {"stuck": 0, "error": 1, "missing": 2, "dead": 3, "covered": 4, "scroll": 5, "offscreen": 6, "overlap": 7, "cut": 8, "small": 9}
	print("pages (ms): ", _tm)
	print("frames %d in %.1f s; checks %.1f s, pictures %.1f s" % [_nf, _tf / 1e6, _ti / 1e6, _tshot / 1e6])
	issues.sort_custom(func(a, b): return rank.get(a.kind, 5) < rank.get(b.kind, 5) if a.kind != b.kind else a.n > b.n)
	var out := ["PLAYED %s: %s in %.1f s · %d taps · %d swipes · %d different screens · %d pictures · %d kinds of problem" % [
		name, "to the end" if ok else "STUCK", secs, taps, swipes, screens, _shots, issues.size()]]
	for i in issues:
		out.append("[%s] %s%s\n      first at: %s%s" % [i.kind, i.text, "  (x%d)" % i.n if i.n > 1 else "", i.where, ("   " + i.shot) if i.shot != "" else ""])
	var t := "\n".join(out)
	print("\n=====REPORT=====\n" + t + "\n=====END=====")
	var jf := FileAccess.open(dir + "/report.json", FileAccess.WRITE)
	if jf: jf.store_string(JSON.stringify({"ok": ok, "secs": secs, "taps": taps, "swipes": swipes, "screens": screens, "shots": _shots, "issues": issues, "pages": _tm, "parts": _parts}))
	var f := FileAccess.open(dir + "/report.txt", FileAccess.WRITE)
	if f: f.store_string(t)


func bug(kind: String, text: String, c: Control = null) -> void:
	var k := kind + "|" + text
	if _issue_at.has(k): _issue_at[k].n += 1; return
	var i := {"kind": kind, "text": text, "where": "line %d, %s, %s (%s)%s" % [line_no, _step, g.S.get("loc", ""), g.S.get("node", "") if g.S.get("node", "") != "" else "looking around", "  in a side trip" if _depth else ""], "n": 1, "shot": ""}
	_issue_at[k] = i; issues.append(i)
	if _bugs < 80: _bugs += 1; i.shot = "bug_%02d_%s.jpg" % [_bugs, kind]; _save_shot(i.shot, rect_of(c) if c else Rect2())


## ---------- time and pictures
var _nf := 0
var _tf := 0
var _ti := 0
var _tshot := 0
func _frames(n: int) -> void:
	var t := Time.get_ticks_usec()
	for i in n: await main.get_tree().process_frame
	_nf += n; _tf += Time.get_ticks_usec() - t


func settle() -> void:
	await _frames(3)
	var nb = load("res://scripts/ui/notebook.gd")
	for i in 60:
		if not nb.filling:
			await _frames(2); break
		await _frames(3)
	_check_errors()


func _check_errors() -> void:
	for e in errors.take(): bug("error", e)


func _save_shot(fn: String, box := Rect2()) -> void:
	var tt := Time.get_ticks_usec()
	RenderingServer.force_draw(false)
	var im: Image = main.get_viewport().get_texture().get_image()
	_tshot += Time.get_ticks_usec() - tt
	if im == null or im.is_empty(): return
	_tasks.append(WorkerThreadPool.add_task(func():
		im.convert(Image.FORMAT_RGB8)
		if box.size != Vector2.ZERO:
			var r := Rect2i(box.grow(5)).intersection(Rect2i(0, 0, im.get_width(), im.get_height()))
			for k in 4:
				im.fill_rect(Rect2i(r.position.x, r.position.y + k, r.size.x, 1), Color.RED); im.fill_rect(Rect2i(r.position.x, r.end.y - k, r.size.x, 1), Color.RED)
				im.fill_rect(Rect2i(r.position.x + k, r.position.y, 1, r.size.y), Color.RED); im.fill_rect(Rect2i(r.end.x - k, r.position.y, 1, r.size.y), Color.RED)
		im.save_jpg(dir + "/" + fn, 0.85)))


func snap_screen(what: String) -> void:
	_shots += 1
	_save_shot("s%03d_%s.jpg" % [_shots, Story.R("[^\\w가-힣]+").sub(what, "_", true).left(40)])


## ---------- looking at the screen
func rect_of(c: Control) -> Rect2:
	return (c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)).abs()


func screen() -> Rect2: return main.get_viewport_rect()


func text_of(c: Control) -> String:
	if c is Button: return c.text
	if c is RichTextLabel: return c.get_parsed_text()
	if c is Label: return c.text
	return c.name


func _gone(n: Node) -> bool:
	while n and n != main:
		if n.is_queued_for_deletion(): return true
		n = n.get_parent()
	return false


func walk(n: Node, out: Array, f: Callable) -> void:
	for k in n.get_children():
		if k is SubViewport or k is CanvasLayer or k.is_queued_for_deletion(): continue
		if k is CanvasItem and not k.visible: continue
		if f.call(k): out.append(k)
		walk(k, out, f)


## the thing on top right now: the last full-screen sheet, or the main screen
func top() -> Control:
	var t: Control = main
	for k in main.get_children():
		if k is ColorRect and k.get_index() > 0 and k.visible and not k.is_queued_for_deletion() and k.mouse_filter == Control.MOUSE_FILTER_STOP and k.size.x > screen().size.x * 0.9: t = k
		elif k.get_script() != null and k is Control and k.visible and not k.is_queued_for_deletion() and k.get_script().resource_path.ends_with("keyboard_test.gd"): t = k
	return t


func buttons(scope: Control = null) -> Array:
	var out := []; walk(scope if scope else top(), out, func(k): return k is BaseButton and k.mouse_filter != Control.MOUSE_FILTER_IGNORE)
	return out


func find_btn(t: String, scope: Control = null, exact := false) -> BaseButton:
	var part: BaseButton = null
	for b in buttons(scope):
		var s: String = b.text.strip_edges()
		if s == t: return b
		if not exact and part == null and s.contains(t): part = b
	return part


func scroller_of(c: Control) -> ScrollContainer:
	var p := c.get_parent()
	while p and p != main:
		if p is ScrollContainer: return p
		p = p.get_parent()
	return null


## what a finger at this point touches
func pick(p: Vector2, n: Node = null) -> Control:
	if n == null: n = main
	var ks := n.get_children()
	if n is Control:
		var inside := Rect2(Vector2.ZERO, n.size).has_point(n.get_global_transform_with_canvas().affine_inverse() * p)
		if n.clip_contents and not inside: return null
	for i in range(ks.size() - 1, -1, -1):
		var k = ks[i]
		if k is SubViewport or k.is_queued_for_deletion() or not (k is CanvasItem) or not k.visible: continue
		var r := pick(p, k)
		if r: return r
	if n is Control and n.mouse_filter != Control.MOUSE_FILTER_IGNORE and Rect2(Vector2.ZERO, n.size).has_point(n.get_global_transform_with_canvas().affine_inverse() * p): return n
	return null


func _is_in(c: Control, anc: Control) -> bool: return c == anc or (c != null and anc.is_ancestor_of(c))


func page_name() -> String:
	var t := top()
	if t != main:
		var ls := []; walk(t, ls, func(k): return k is Label)
		return "page " + (ls[0].text if not ls.is_empty() else t.name)
	if main.cork.visible: return "board"
	if main.room.cam_mode: return "camera"
	var b: Dictionary = g.beat()
	return "looking" if b.is_empty() else b.get("type", "say")


## ---------- the checks, on every new screen
func inspect() -> void:
	var sc := top(); var bs := buttons(sc)
	var key := "%s|%s|%s|%s|%s" % [page_name(), g.S.node, g.S.loc, ",".join(bs.map(func(b): return b.text)), main.kb != null]
	if _seen.has(key): return
	_seen[key] = 1; screens += 1
	var t := Time.get_ticks_usec()
	if sc == main: _expected()
	_check_buttons(sc, bs)
	_check_text(sc)
	_ti += Time.get_ticks_usec() - t
	await _check_scrolls(sc)
	var sk := "shot|%s|%s|%s" % [page_name(), g.S.loc, g.S.node.get_slice(".", 0) if page_name() != "say" else ""]
	if not _seen.has(sk) and _depth == 0: _seen[sk] = 1; snap_screen(page_name() + "_" + g.S.loc + "_" + g.S.node)


func _check_buttons(sc: Control, bs: Array) -> void:
	var view := screen()
	var rects := []
	for b: BaseButton in bs:
		var r := rect_of(b); var t := text_of(b).replace("\n", " / ").left(40); var s := scroller_of(b)
		if t == "": t = "(picture button)"
		if r.size.x < FINGER - 4 or r.size.y < FINGER - 4:
			bug("small", "%s: \"%s\" is %dx%d (a finger needs %d)" % [page_name(), t, r.size.x, r.size.y, FINGER], b)
		if s:
			var sr := rect_of(s)
			if r.position.x < sr.position.x - 2 or r.end.x > sr.end.x + 2: bug("cut", "%s: \"%s\" sticks out sideways of its list" % [page_name(), t], b)
			var vis := r.intersection(sr)
			if vis.size.y < r.size.y * 0.6: continue   # below the fold: swiping reaches it (checked when it's used)
			r = vis
		elif not view.grow(1).encloses(r):
			bug("offscreen", "%s: \"%s\" is off the screen by %d" % [page_name(), t, maxi(maxi(r.end.x - view.end.x, r.end.y - view.end.y), maxi(-r.position.x, -r.position.y))], b); continue
		var hit := pick(r.get_center())
		if not _is_in(hit, b) and not _is_in(b, hit if hit else main) or hit == main:
			bug("covered", "%s: \"%s\" is covered by %s" % [page_name(), t, _what(hit)], b)
		elif hit != null and not _is_in(hit, b):
			bug("covered", "%s: \"%s\" is covered by %s" % [page_name(), t, _what(hit)], b)
		if b is Button and not b.disabled and b.clip_text and b.text != "":
			var w: float = b.get_theme_font("font").get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			if w > b.size.x - 16: bug("cut", "%s: the words on \"%s\" don't fit" % [page_name(), t], b)
		rects.append([r, b, t])
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i][1].is_ancestor_of(rects[j][1]): continue
			var x: Rect2 = rects[i][0].intersection(rects[j][0])
			if x.size.x > 4 and x.size.y > 4: bug("overlap", "%s: \"%s\" and \"%s\" overlap" % [page_name(), rects[i][2], rects[j][2]], rects[i][1])
	# a person has to see there is more: the way forward shouldn't hide below the fold without a hint
	if sc == main and main.paper.is_visible_in_tree() and g.node != "":
		var es: Array = bs.filter(func(b): return not b.disabled and main.acts.is_ancestor_of(b))
		if not es.is_empty():
			var sr := rect_of(scroller_of(es[0]))
			if es.all(func(b): return rect_of(b).position.y > sr.end.y - 20) and not main.scroller.more.visible:
				bug("scroll", "%s: every button is below the fold and nothing says so" % page_name(), es[0])


func _what(c: Control) -> String:
	if c == null: return "nothing that takes touches"
	if main.kb and _is_in(c, main.kb): return "the Korean keyboard"
	var t := text_of(c)
	return "%s%s" % [c.get_class(), " \"%s\"" % t.left(24) if t != c.name else ""]


func _check_text(sc: Control) -> void:
	var ls := []; walk(sc, ls, func(k): return k is Label or k is RichTextLabel)
	var view := screen(); var paper := rect_of(main.paper)
	for l: Control in ls:
		var t := text_of(l)
		if t.strip_edges() == "" or l.modulate.a < 0.05: continue
		for bad in ["{", "}", "[url", "[color", "[lb]", "<null>", "%s", "%d", "\\n"]:
			if t.contains(bad): bug("cut", "%s: raw \"%s\" showing in \"%s\"" % [page_name(), bad, t.left(40)], l); break
		var r := rect_of(l)
		if l is RichTextLabel and not l.scroll_active and l.get_content_height() > l.size.y + 3: bug("cut", "%s: text cut off at the bottom: \"%s\"" % [page_name(), t.left(40)], l)
		if l is Label:
			if l.clip_text and l.autowrap_mode == TextServer.AUTOWRAP_OFF and l != main.title_en:
				var w: float = l.get_theme_font("font").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
				if w > l.size.x + 2: bug("cut", "%s: label cut off: \"%s\"" % [page_name(), t.left(40)], l)
			elif l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.get_visible_line_count() < l.get_line_count() and not main.cork.is_ancestor_of(l): bug("cut", "%s: label cut off: \"%s\"" % [page_name(), t.left(40)], l)
		if scroller_of(l) or main.cork.is_ancestor_of(l): continue
		if not view.grow(2).encloses(r) and not main.room.is_ancestor_of(l): bug("offscreen", "%s: text off the screen: \"%s\"" % [page_name(), t.left(40)], l)
		if main.paper.is_ancestor_of(l) and r.end.x > paper.end.x + 1: bug("offscreen", "%s: text sticks out of the paper: \"%s\"" % [page_name(), t.left(40)], l)


## everything taller than its box swipes, wherever the finger lands, and the swipe presses nothing
func _check_scrolls(sc: Control) -> void:
	var ss := []; walk(sc, ss, func(k): return k is ScrollContainer)
	for s: ScrollContainer in ss:
		var bar := s.get_v_scroll_bar()
		if bar.max_value - bar.page < 30: continue
		var kind := "%s/%s" % [page_name(), "paper" if main.paper.is_ancestor_of(s) else "list"]
		if _tried.get("scroll|" + kind, 0) >= 3: continue
		_tried["scroll|" + kind] = _tried.get("scroll|" + kind, 0) + 1
		var was_page := page_name(); var was := s.scroll_vertical; var sr := rect_of(s); var node: String = g.S.node
		for fx in [0.2, 0.5, 0.8]:
			if not is_instance_valid(s): break
			s.scroll_vertical = 0; await _frames(1)
			var p := sr.position + sr.size * Vector2(fx, 0.75)
			var on := pick(p)
			await swipe(p, p - Vector2(0, minf(sr.size.y * 0.5, 220)))
			if page_name() != was_page or g.S.node != node:
				bug("scroll", "%s: swiping pressed something (%s)" % [kind, _what(on)], s); return
			if s.scroll_vertical < 20: bug("scroll", "%s: can't swipe when the finger lands on %s" % [kind, on.get_class() if on else "nothing"], on)
		if is_instance_valid(s): s.scroll_vertical = was; await _frames(1)
	await settle()


## ---------- what should be on the screen, worked out from the story (not from the code that draws it)
func _expected() -> void:
	var b: Dictionary = g.beat(); var t: String = b.get("type", ""); var pl: Dictionary = g.place()
	var need: Array = []
	# the bar along the top: once you have something, it stays, and it stays where it was
	var bar: Dictionary = {"note": true, "menu": true, "board": not g.ST.cases.is_empty() or not g.owned().is_empty() or not g.board().photos.is_empty() or g.ST.free, "phone": g.has_phone(),
		"map": g.S.known.size() > 1}
	for k in bar:
		var bb: Button = main.bar_btns[k]
		if bar[k] and (not bb.is_visible_in_tree() or bb.self_modulate.a < 0.2): bug("missing", "the %s button isn't there while %s" % [k, page_name()])
		elif bar[k]:
			if bb.disabled: bug("dead", "the %s button is off while %s" % [k, page_name()], bb)
			if _bar_pos.has(k) and _bar_pos[k].distance_to(rect_of(bb).position) > 3: bug("missing", "the %s button jumped to another place in the bar" % k, bb)
			_bar_pos[k] = rect_of(bb).position
			if not screen().encloses(rect_of(bb)): bug("offscreen", "the %s button is off the screen" % k, bb)
	if main.cork.visible and not b.is_empty() and not main.board_view: pass   # (someone's talking, in the lab)
	elif main.cork.visible:
		if find_btn("Leave the board", main) == null and find_btn("Close the board", main) == null and find_btn("Back to the board", main) == null: bug("missing", "no way off the board")
		return
	if b.is_empty():
		_check_trap()
		if main.room.cam_mode:
			if not main.room.shutter.is_visible_in_tree() or not main.room.cam_x.is_visible_in_tree(): bug("missing", "the camera has no shutter or no ✕")
			return
		if main.room._lean_on: bug("dead", "the picture stays zoomed in while looking around (%s)" % g.S.loc)
		if not main.room.marks.is_visible_in_tree(): bug("missing", "the rings on the picture are gone while looking around")
		if not main.room.figs.is_visible_in_tree(): bug("missing", "the people in the picture are gone while looking around")
		if main.room.back_btn.visible and main.room.cam_mode: bug("overlap", "the back arrow shows with the camera up")
		if pl.get("mode", "") != "board" and not main.room.cam_btn.is_visible_in_tree(): bug("missing", "no camera button while looking around")
		if pl.has("back") and not main.room.back_btn.is_visible_in_tree(): bug("missing", "no back arrow")
		for s in g.spots_now():
			var p := _spot_pos(s); var hit := pick(p)
			if hit != main.room: bug("covered", "the spot \"%s\" in %s is under %s" % [s.l, g.S.loc, _what(hit)], hit)
		var sp: Array = g.spots_now()
		for i in sp.size():
			for j in range(i + 1, sp.size()):
				if sp[i].kind == sp[j].kind and _spot_pos(sp[i]).distance_to(_spot_pos(sp[j])) < 44: bug("overlap", "spots \"%s\" and \"%s\" in %s are too close to tell apart" % [sp[i].l, sp[j].l, g.S.loc])
		if g.ST.free and not g.W.frozen:
			for p in g.people_here(): need.append("Talk to " + g.ST.cast.get(p.id, {}).get("n", p.id))
			if g.W.slot < 3: need.append("Wait a while")
			if g.S.loc == g.ST.meta.get("home", "") and g.W.slot >= 2: need.append("Go to bed")
		for e in g.pockets(): need.append(g.plain(e.label))
		if g.spots_now().is_empty() and need.is_empty() and not pl.has("back"): bug("stuck", "nothing to do in %s" % g.S.loc)
	else:
		if main.room._lean_on != g._leaning or (g._leaning and g._lean_loc != g.S.loc): bug("dead", "the picture is zoomed in on something from before (%s)" % g.S.loc)
		if t in ["", "say"] and not main.room.cam_btn.is_visible_in_tree() and not main.room.cam_mode: bug("missing", "no camera button while someone's line waits")
		match t:
			"card": need = ["Begin"]
			"number":
				if b.kind == "count": need = ["Try it", "Leave it"]
				else: need = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "⌫", "Pay" if b.kind == "won" else "Say it", "Never mind"]
			"build":
				for x in b.tiles: need.append(g.plain(x))
				need.append_array(["Clear", "Say it", "Never mind"])
			"type":
				if not g.typed_close.is_empty(): need = ["Continue"]
				else: need = ["ㅂ", "ㅁ", "ㅋ", "ㅡ", "⇧", "⌫", "space", "Hint", "Say it", "✕"]
			"present":
				for e in g.owned(): need.append(g.plain(e.label))
				need.append("Never mind")
			"contradict":
				for e in g.owned(): need.append(g.plain(e.label))
				for x in g.owned_statements(): need.append(g.plain(g.ST.nodes[x.node].ko))
				need.append("Never mind")
			"examine": need = ["Done looking" if g.exam_keys_left() == 0 else "Keep looking"]
			"camera": need = ["Take the photo"]
			"photo": need = ["Continue"]
			_:
				var ch: Array = b.get("ch", []).filter(func(o): return g.cond(o.c))
				for o in ch: need.append(g.plain(o.ko) if o.has("ko") else o.get("en", ""))
				if ch.is_empty(): need.append("Continue" if (b.has("next") or b.has("rewind")) else "Look around")
				if b.get("who", "narr") != "narr": need.append("▶")
	var have: Array = buttons(main).map(func(x): return x.text)
	for n in need:
		if not have.any(func(h): return h.contains(n)): bug("missing", "%s: \"%s\" isn't there" % [page_name(), n])


## ---------- traps: from wherever you are, with nothing solved, there has to be a way out and a way on
## every scene and place you could get to from here right now, just by walking and talking
func _reach() -> Dictionary:
	var places := {g.S.loc: 1}; var todo := [g.S.loc]; var nodes := {}; var ends := false
	while not todo.is_empty():
		var pl: Dictionary = g.ST.places.get(todo.pop_back(), {})
		var go := []
		if pl.has("back"): go.append(pl.back)
		if pl.get("travel", "") != "no":
			for k in g.S.known: go.append(k)
		for s in pl.get("spots", []):
			if not g.cond(s.c): continue
			var m := Story.R("^place\\s+(\\S+)").search(s.t)
			if m: go.append(m.get_string(1))
			elif s.kind == "->": ends = _follow(g.target(s.t), nodes, go) or ends
		for key in ["first", "always"]:
			if pl.has(key) and not g.S.visited.has(pl.get("id", "")): ends = _follow(pl[key], nodes, go) or ends
		for p in go:
			if g.ST.places.has(p) and not places.has(p) and not g.is_closed(p): places[p] = 1; todo.append(p)
	for id in g.job_on().get("ask", {}).values(): _follow(id, nodes, [])   # what you can ask people about the job you're on
	return {"places": places, "nodes": nodes, "ends": ends}


func _follow(id: String, nodes: Dictionary, go: Array) -> bool:
	var ends := false; var todo := [id]
	while not todo.is_empty():
		var n: String = g.target(todo.pop_back())
		if nodes.has(n) or not g.ST.nodes.has(n): continue
		nodes[n] = 1
		var nd: Dictionary = g.ST.nodes[n]
		for f in nd.get("fx", []):
			if f.k == "place": go.append(f.a.strip_edges())
			if f.k in ["chapter", "finish"]: ends = true
		for k in ["next", "rewind", "miss"]:
			if nd.has(k): todo.append(nd[k])
		for c in nd.get("ch", []): todo.append(c.go)
		for a in nd.get("ans", []): todo.append(a[1])
		for a in nd.get("shows", []): todo.append(a[1])
		for a in nd.get("pairs", []): todo.append(a[1])
	return ends


const OPTIONAL := ["k1", "k3", "k7"]   ## hello and goodbye at the restaurant: nice, but nothing depends on them
func _check_trap(left := "") -> void:
	if g.S.node != "" or g.ST.is_empty() or g.ST.places.get(g.S.loc, {}).get("mode", "") == "board": return
	var r := _reach()
	if r.places.size() < 2 and not r.ends: bug("stuck", "trapped in %s: no way out%s" % [g.S.loc, " after walking away from " + left if left != "" else ""])
	elif left != "" and not r.nodes.has(left):
		var sc := left.get_slice(".", 0)
		if not r.nodes.has(sc) and not sc in OPTIONAL: bug("stuck", "walking away from %s loses it for good" % left)


## ---------- a finger
func _touch(p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = 0; e.position = p * main.get_viewport().get_final_transform().get_scale(); e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()


func _slide(p: Vector2, by: Vector2) -> void:
	var k := main.get_viewport().get_final_transform().get_scale()
	var e := InputEventScreenDrag.new(); e.index = 0; e.position = p * k; e.relative = by * k; e.screen_relative = by * k
	Input.parse_input_event(e); Input.flush_buffered_events()


func tap_at(p: Vector2, wobble := true) -> void:
	taps += 1
	_touch(p, true); await _frames(1)
	if wobble:
		var d := Vector2.from_angle(_rng.randf() * TAU) * WOBBLE * _rng.randf(); _slide(p + d, d); p += d
	_touch(p, false); await settle()


func swipe(a: Vector2, b: Vector2) -> void:
	swipes += 1
	_touch(a, true); await _frames(1)
	var at := a
	for i in range(1, 7):
		var q := a.lerp(b, i / 6.0); _slide(q, q - at); at = q; await _frames(1)
	_touch(b, false); await _frames(2)


## swipe until it's in view
func reach(c: Control) -> void:
	var s := scroller_of(c)
	if s == null: return
	for i in 24:
		if not is_instance_valid(c) or not is_instance_valid(s): return
		var sr := rect_of(s); var r := rect_of(c)
		var need := r.get_center().y
		var m := minf(30, r.size.y / 2) - 3
		if need > sr.position.y + m and need < sr.end.y - m: return
		var was := s.scroll_vertical; var down := need > sr.get_center().y
		var mid := sr.get_center(); var len := clampf(absf(need - mid.y), 60, sr.size.y * 0.6)
		mid.x = sr.position.x + sr.size.x * [0.5, 0.2, 0.85][i % 3]
		await swipe(mid + Vector2(0, len / 2) * (1 if down else -1), mid - Vector2(0, len / 2) * (1 if down else -1))
		if not is_instance_valid(s): return
		if s.scroll_vertical == was and i >= 2:
			bug("scroll", "%s: can't swipe down to \"%s\"" % [page_name(), text_of(c).left(30)], c)
			s.ensure_control_visible(c); await _frames(2); return


## press a button like a person: find it, reach it, press a bit off its middle; it must fire, once
func press(b: BaseButton) -> bool:
	if b == null or not is_instance_valid(b): return false
	await reach(b)
	if not is_instance_valid(b): return false
	var t := text_of(b).left(40).replace("\n", " / ")
	if b.disabled: bug("dead", "%s: \"%s\" is greyed out when it's needed" % [page_name(), t], b); return false
	var r := rect_of(b)
	var s := scroller_of(b)
	if s: r = r.intersection(rect_of(s))
	var off := Vector2(_rng.randf_range(-0.22, 0.22), _rng.randf_range(-0.22, 0.22)) * r.size
	off = off.clamp(Vector2(-60, -16), Vector2(60, 16))
	var p := r.get_center() + off
	var hit := pick(p); var page := page_name()
	if not _is_in(hit, b):
		p = r.get_center(); hit = pick(p)
		if not _is_in(hit, b): bug("covered", "%s: couldn't press \"%s\": %s is on top" % [page, t, _what(hit)], b); b.pressed.emit(); await settle(); return true
	var fired := [0]; var f := func(): fired[0] += 1
	b.pressed.connect(f)
	await tap_at(p)
	if fired[0] == 0:
		bug("dead", "%s: pressing \"%s\" did nothing" % [page, t], b if is_instance_valid(b) else null)
		if is_instance_valid(b): b.pressed.emit(); await settle()
	elif fired[0] > 1: bug("dead", "%s: one press on \"%s\" counted %d times" % [page, t, fired[0]])
	if is_instance_valid(b) and b.pressed.is_connected(f): b.pressed.disconnect(f)
	return true


func press_text(t: String, scope: Control = null, exact := false) -> bool:
	var b := find_btn(t, scope, exact)
	if b == null: bug("missing", "%s: no \"%s\" button" % [page_name(), t]); return false
	return await press(b)


func close_top() -> void:
	for i in 6:
		var t := top()
		if t == main or t == main._title_o: return
		var b := find_btn("✕", t, true)
		if b == null: b = find_btn("Close", t, true)
		if b == null: b = find_btn("Keep exploring", t)
		if b == null: bug("stuck", "%s: no way to close it" % page_name()); t.queue_free(); await settle(); return
		await press(b)


func _spot_pos(s: Dictionary) -> Vector2:
	return rect_of(main.room).position + Vector2(s.x, s.y) / 100.0 * rect_of(main.room).size


## ---------- side trips: try it, see it doesn't break or trap you, then take it back
func _keep() -> Dictionary:
	return {"S": g.S.duplicate(true), "words": g.words.duplicate(true), "close": g.typed_close.duplicate(true), "bv": main.board_view, "lean": g._leaning, "lean_loc": g._lean_loc, "talks": _talks()}

func _talks() -> Dictionary:   # talk menus are made on the spot, not in the story files
	var out := {}
	for id in g.ST.nodes:
		if id.begins_with("_talk_"): out[id] = g.ST.nodes[id]
	return out

func _back_to(k: Dictionary) -> void:
	while top() != main: top().free()
	g.S = k.S.duplicate(true); g.words = k.words.duplicate(true); g.typed_close = k.close.duplicate(true); g._vcards = {}; g._use(g.S.ch); g.ST.nodes.merge(k.talks, true)
	main.board_view = k.bv; main.lab_go = false; main.card_sel = ""; main.busy = false
	g._leaning = false; g.lean.emit(Vector2.ZERO, false)
	if k.get("lean", false): g._leaning = true; g._lean_loc = k.lean_loc; main.room._lean_on = true
	if main.kb: main.kb.queue_free(); main.kb = null
	main._shown_node = "?"
	g.changed.emit(); await settle()


## play on from here until it settles: back to looking around, or to something that needs a decision
func _run_on(limit := 60) -> void:
	var loops := {}
	for i in limit:
		await inspect()
		if g.S.node == "" or _waits(g.beat()): return
		var k: String = g.S.node
		loops[k] = loops.get(k, 0) + 1
		if loops[k] > 3: bug("stuck", "goes round in circles at %s" % k); return
		await _go_on()
		if g.S.node == k and top() == main: bug("stuck", "Continue doesn't move on at %s" % k); g.next(); await settle()
		if top() != main: await inspect(); await close_top()
	bug("stuck", "a conversation that never ends, from %s" % g.S.node)


func _branch(key: String, f: Callable) -> void:
	if _tried.has(key) or _depth >= 3: return
	print("@ ..%s" % key)
	_tried[key] = 1; _depth += 1
	var k := _keep()
	var at: String = g.S.node
	await f.call()
	if key.ends_with(">leave"): _check_trap(at)
	await _run_on()
	_check_trap()
	await _try_all()
	await _back_to(k)
	_depth -= 1


## everything else you could do right here
func _try_all() -> void:
	var b: Dictionary = g.beat(); var t: String = b.get("type", "")
	var here := "%s|%s" % [g.S.ch, g.S.node]
	if b.is_empty():
		for s in g.spots_now():
			if s.kind == "=>" or g.cond_value("clock") and _depth: continue
			await _branch("spot|%s|%s" % [g.S.loc, s.t], func(): await _tap_spot(s))
		return
	if b.has("ch"):
		for o in b.ch:
			if not g.cond(o.c): continue
			await _branch("%s>%s" % [here, o.go], func(): await _pick_choice(o))
	match t:
		"build":
			await _branch(here + ">wrong", func():
				for i in b.tiles.size(): await press_text(g.plain(b.tiles[i]), main.paper, true)
				await press_text("Clear", main.paper, true)
				if not main._build_seq.is_empty(): bug("dead", "Clear doesn't clear the tiles")
				await press_text(g.plain(b.tiles[b.tiles.size() - 1]), main.paper, true)
				await press_text("Say it", main.paper, true); await _frames(3))
			await _branch(here + ">leave", func(): await press_text("Never mind", main.paper))
		"type":
			await _branch(here + ">wrong", func(): await _type("몰라요"); await _say_it())
			await _branch(here + ">hello", func(): await _type("안녕하세요"); await _say_it())
			if not b.ans.is_empty():
				await _branch(here + ">close", func():
					await _type(_misspell(g.plain(b.ans[0][0]))); await _say_it(); await inspect()
					if not g.typed_close.is_empty(): await press_text("Continue", main.paper))
			await _branch(here + ">hints", func():
				for i in 4: await press_text("Hint", main.kb)
				if main.kb and main.kb.hint_l.text == "": bug("dead", "the Hint key shows nothing"))
			await _branch(here + ">notebook", func():   # look something up while typing, come back, keep typing
				await _type("가"); await press(main.bar_btns.note); await inspect(); await close_top()
				if main.kb == null or main.kb.shown.text != "가": bug("missing", "what you were typing is lost after looking in the notebook")
				await press(main.bar_btns.board); await inspect()
				if main.board_view: await press_text("Close the board", main))
			await _branch(here + ">leave", func(): await press_text("✕", main.kb, true))
		"number":
			await _branch(here + ">wrong", func(): await _enter_number("7", b))
			await _branch(here + ">leave", func(): await press_text("Leave it" if b.kind == "count" else "Never mind", main))
		"present":
			for e in g.owned(): await _branch(here + ">show " + e.id, func(): await press_text(g.plain(e.label), main.paper))
			await _branch(here + ">leave", func(): await press_text("Never mind", main.paper))
		"contradict":
			await _branch(here + ">wrong", func():
				var cs: Array = buttons(main.acts).slice(0, 3).map(func(x): return x.text)
				for c in cs: await press_text(c, main.acts, true)
				await press_text("can't both be true", main.paper))
			await _branch(here + ">leave", func(): await press_text("Never mind", main.paper))
		"examine":
			await _branch(here + ">miss", func():
				for i in 5: await tap_at(rect_of(main.room).position + rect_of(main.room).size * Vector2(0.03, 0.03 + i * 0.01)))
		"camera":
			await _branch(here + ">miss", func():
				var f: Control = main.room.frame
				await swipe(rect_of(f).get_center(), rect_of(main.room).position + rect_of(f).size * 0.4)
				await press_text("Take the photo", main.paper))


func _misspell(s: String) -> String:
	for i in s.length():
		var c := s.unicode_at(i) - 0xAC00
		if c >= 0 and c < 11172 and c % 28 == 20: return s.left(i) + char(0xAC00 + c - 1) + s.substr(i + 1)   # ㅆ -> ㅅ, what everyone gets wrong
	for i in s.length():
		var c := s.unicode_at(i) - 0xAC00
		if c >= 0 and c < 11172 and c % 28 == 0: return s.left(i) + char(0xAC00 + c + 4) + s.substr(i + 1)
	return s


## ---------- doing things
func _go_on() -> void:
	var b: Dictionary = g.beat(); var t: String = b.get("type", "")
	var label := "Begin" if t == "card" else ("Done looking" if t == "examine" else "")
	if label == "":
		for x in ["Continue", "Look around"]:
			var bb := find_btn(x, main.paper)
			if bb: label = x; break
	if label == "": bug("stuck", "no way on from %s" % g.S.node); g.next(); await settle(); return
	await press_text(label, main.paper)


## sometimes a player taps a word in the line to look it up
var _words_tapped := 0
func _tap_word() -> void:
	if _words_tapped >= 14 or _tried.has("word|" + g.S.node) or not g.beat().has("ko") or g.beat().get("audio", false): return
	_tried["word|" + g.S.node] = 1
	if _tried.size() % 5: return
	var rs := []; walk(main.body, rs, func(k): return k is RichTextLabel)
	for r: RichTextLabel in rs:
		if not r.text.begins_with("[url=w:"): continue
		_words_tapped += 1
		var p := rect_of(r).position + Vector2(13, r.get_theme_font_size("normal_font_size") * 0.65)
		await tap_at(p)
		if top() == main: bug("dead", "tapping the first word of a line doesn't open it", r); return
		await _word_page(); return


## a word's page: hear it, guess, tick sure, see where you met it
func _word_page() -> void:
	await inspect()
	var t := top(); var es := []; walk(t, es, func(k): return k is LineEdit)
	if not es.is_empty():
		var le: LineEdit = es[0]
		await reach(le); await tap_at(rect_of(le).get_center())
		if not le.has_focus(): bug("dead", "can't put the cursor in the word note", le)
		le.text = "test"; le.text_changed.emit("test"); await _frames(1)
		var cs := []; walk(t, cs, func(k): return k is CheckBox)
		for c in cs:
			var bf: bool = c.button_pressed
			await press(c)
			if c.button_pressed == bf: bug("dead", "\"I'm sure\" doesn't tick", c)
		await inspect()
	if find_btn("▶ Hear it", t): await press_text("▶ Hear it", t)
	await close_top()


func go_idle() -> void:
	for i in 150:
		if top() != main: await inspect(); await close_top()
		await inspect()
		if g.S.node == "" or failed: return
		if _waits(g.beat()): fail("needs a decision before it can go on"); return
		await _tap_word()
		await _test_double_tap()
		var k: String = g.S.node
		await _go_on()
		if g.S.node == k and g.beat().get("id", "") == k and top() == main: bug("stuck", "Continue doesn't move on at %s" % k); g.next(); await settle()
	fail("never finished the scene")


func go_until(found: Callable, what: String) -> Variant:
	for i in 150:
		if top() != main: await inspect(); await close_top()
		await inspect()
		var f = found.call()
		if f: return f
		if g.S.node == "" or _waits(g.beat()): break
		await _tap_word()
		await _go_on()
	fail("never reached " + what); return null


var _voice_tested := 0
## with the real voices: say your line, then open and close the phone (which cuts the voice off): the story must go on
func _test_voice(o: Dictionary, b: BaseButton) -> void:
	_voice_tested += 1
	var k := _keep(); var was: String = g.S.node
	Voice.instant = false
	await press(b)
	if g.S.node == was:
		if not main.busy: bug("dead", "your line plays but the game isn't waiting for it")
		main.voice.stop(); await _real(0.15)
		if g.S.node == was or main.busy: bug("stuck", "your voice line was cut off and the choices stopped working")
	await _back_to(k)
	b = find_btn("“%s”" % g.plain(o.ko), main.paper)
	if b:
		await press(b); await press(main.bar_btns.note); await close_top()   # look in the notebook while it plays
		var t0 := Time.get_ticks_msec()
		while g.S.node == was and Time.get_ticks_msec() - t0 < 6000: await _frames(2)
		if g.S.node == was: bug("stuck", "opening the notebook while you speak stops the story")
	Voice.instant = true; await _back_to(k)


func _real(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000: await _frames(1)


func _test_double_tap() -> void:
	var b := find_btn("Continue", main.paper)
	if b == null or _tried.has("double"): return
	_tried["double"] = 1
	var k := _keep(); var was: String = g.S.node
	main.guard = 220; await _real(0.3)
	await reach(b); var p := rect_of(b).get_center()
	await tap_at(p); var one: String = g.S.node
	await tap_at(p)
	if g.S.node != one: bug("dead", "a double tap on Continue skips the next line")
	main.guard = 0
	await _back_to(k)


func _pick_choice(o: Dictionary) -> void:
	var t: String = g.plain(o.ko) if o.has("ko") else o.get("en", "")
	var was: String = g.S.node
	var b := find_btn("“%s”" % t if o.has("ko") else t, main.paper)
	if b == null: bug("missing", "the choice \"%s\" isn't there" % t); g.choose(o); await settle(); return
	if o.has("ko") and _depth == 0 and _voice_tested < 1 and _from_line == 0: await _test_voice(o, b); b = find_btn("“%s”" % t, main.paper)
	await press(b); await _frames(2)
	if g.S.node == was and target_of(o) != was: bug("dead", "choosing \"%s\" does nothing" % t); main.busy = false; g.choose(o); await settle()

func target_of(o: Dictionary) -> String: return g.target(o.go)


func _tap_spot(s: Dictionary) -> void:
	if main.board_view: await press_text("Close the board", main)
	if g.place().get("mode", "") == "board":   # the board lab: you leave by name
		if find_btn("Leave the board", main): await press_text("Leave the board", main); await inspect()
		await press_text(s.l, main.acts); return
	var was := [g.S.node, g.S.loc, g.S.F.has("found_%s_%s" % [g.S.loc, s.l])]
	g.S.F.erase("found_%s_%s" % [g.S.loc, s.l])
	var key := "found_%s_%s" % [g.S.loc, s.l]
	await tap_at(_spot_pos(s) + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12)))
	if not g.S.F.has(key):
		bug("dead", "tapping \"%s\" in %s didn't open it (got %s)" % [s.l, was[1], g.S.node if g.S.node != was[0] else "nothing"])
		if g.S.node == was[0] and g.S.loc == was[1]: g.tap_spot(s); await settle()
	elif g.S.node == was[0] and g.S.loc == was[1] and top() == main and not g.is_closed(Story.R("^place\\s+").sub(s.t, "")):
		bug("dead", "\"%s\" in %s does nothing" % [s.l, was[1]])


## ---------- the steps of a route, by finger
func play_route(name: String, stop := "") -> bool:
	route = name; failed = false; line_no = 0
	for raw in FileAccess.get_file_as_string(route_file(name)).split("\n"):
		line_no += 1
		if line_no < _from_line: continue
		var line := raw.strip_edges()
		if line.begins_with("#@"):
			if stop != "" and line.substr(2).strip_edges() == stop: return true
			_part(line.substr(2).strip_edges())
			_step = line; await _reload_check(); await _pages(line.substr(2).strip_edges())
			continue
		if line == "" or line.begins_with("#"): continue
		var sp := line.find(" ")
		var cmd := line if sp < 0 else line.substr(0, sp)
		var arg := "" if sp < 0 else line.substr(sp + 1).strip_edges()
		if cmd in SKIP: continue
		if cmd == "oldsave": break
		_step = line; print("@ %d %s" % [line_no, line])
		if has_method("p_" + cmd): await call("p_" + cmd, arg)
		elif has_method("s_" + cmd): call("s_" + cmd, arg); await settle()
		else: fail("unknown step " + cmd)
		if failed: bug("stuck", "the route stopped here: " + _fail_msg); await _frames(2); return false
	return true


var _parts := {}          ## how long each part took (the next run shares the work out evenly)
var _part_name := ""
var _part_t := 0
func _part(n: String) -> void:
	var t := Time.get_ticks_msec()
	if _part_t: _parts[_part_name] = (t - _part_t) / 1000.0
	_part_name = n; _part_t = t


var _fail_msg := ""
func fail(msg: String) -> void:
	if not failed: _fail_msg = msg
	failed = true


func p_chapter(a: String) -> void:
	g.enc_off = true
	if g.S.ch != a or g.S.loc == "": g.start_chapter(a, true)
	await settle(); await inspect()

func p_switch(a: String) -> void: g.start_chapter(a, true); await settle(); await inspect()
func p_idle(_a: String) -> void: await go_idle()

func p_choose(a: String) -> void:
	var o = await go_until(func():
		for c in g.beat().get("ch", []):
			if g.cond(c.c) and g.plain(c.get("en", c.get("ko", ""))).contains(a): return c
		return null, 'a choice "%s"' % a)
	if o: await _try_all(); await _pick_choice(o)

func p_anychoice(_a: String) -> void:
	var o = await go_until(func():
		for c in g.beat().get("ch", []):
			if g.cond(c.c): return c
		return null, "a choice")
	if o: await _try_all(); await _pick_choice(o)

func p_spot(a: String) -> void:
	await go_idle()
	var s := _spot(a)
	if s.is_empty(): fail('no spot "%s" here (spots: %s)' % [a, ", ".join(g.spots_now().map(func(x): return x.l))]); return
	await _try_all()
	await _tap_spot(s)

func p_tap(a: String) -> void: await p_spot(a)
func p_nospot(a: String) -> void: await go_idle(); s_nospot(a)


func _say_it() -> void: await press_text("Say it", main.kb, true); await _frames(3)

func p_type(a: String) -> void:
	if await go_until(_type_is("type"), "a typed answer") == null: return
	await _try_all()
	await _type(a); await _say_it()
	if not g.typed_close.is_empty(): await inspect(); await press_text("Continue", main.paper)

const VOW := {"ㅘ": "ㅗㅏ", "ㅙ": "ㅗㅐ", "ㅚ": "ㅗㅣ", "ㅝ": "ㅜㅓ", "ㅞ": "ㅜㅔ", "ㅟ": "ㅜㅣ", "ㅢ": "ㅡㅣ"}
const FIN := {"ㄳ": "ㄱㅅ", "ㄵ": "ㄴㅈ", "ㄶ": "ㄴㅎ", "ㄺ": "ㄹㄱ", "ㄻ": "ㄹㅁ", "ㄼ": "ㄹㅂ", "ㄽ": "ㄹㅅ", "ㄾ": "ㄹㅌ", "ㄿ": "ㄹㅍ", "ㅀ": "ㄹㅎ", "ㅄ": "ㅂㅅ"}
const CHO := "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"
const JUNG := "ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ"
const JONG := " ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ"
const SHIFT := {"ㅃ": "ㅂ", "ㅉ": "ㅈ", "ㄸ": "ㄷ", "ㄲ": "ㄱ", "ㅆ": "ㅅ", "ㅒ": "ㅐ", "ㅖ": "ㅔ"}

func _type(t: String) -> void:
	if main.kb == null: bug("missing", "no keyboard where you have to type"); return
	var base: String = main.kb.shown.text; var typed := ""
	for c in t:
		var u := c.unicode_at(0) - 0xAC00
		var keys := ""
		if u >= 0 and u < 11172:
			var v := JUNG[u % 588 / 28]; keys = CHO[u / 588] + VOW.get(v, v)
			if u % 28: var f := JONG[u % 28]; keys += FIN.get(f, f)
		elif c == " ": keys = " "
		elif "?!.,".contains(c): continue   # no key for it; it doesn't count
		typed += c
		for k in keys:
			if main.kb == null: return
			if SHIFT.has(k): await _key("⇧")
			await _key("space" if k == " " else k)
	if main.kb and main.kb.shown.text != base + typed: bug("dead", "typed %s, the keyboard shows %s" % [typed, main.kb.shown.text])


func _key(k: String) -> void:
	var b := find_btn(k, main.kb, true)
	if b == null: bug("missing", "the keyboard has no %s key" % k); return
	var r := rect_of(b); var p := r.get_center() + Vector2(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.25, 0.25)) * r.size
	if not _is_in(pick(p), b): bug("covered", "the %s key is covered by %s" % [k, _what(pick(p))], b)
	taps += 1
	_touch(p, true); _touch(p, false); await _frames(1)


func p_build(a: String) -> void:
	if await go_until(_type_is("build"), "sentence tiles") == null: return
	await _try_all()
	for w in Story.split_bar(a):
		var b: BaseButton = null
		for x in buttons(main.acts):
			if x.text == g.plain(w) and not x.disabled: b = x; break
		if b == null: fail('no tile "%s"' % w); return
		await press(b)
	await press_text("Say it", main.paper, true); await _frames(3)


func _enter_number(a: String, b: Dictionary) -> void:
	if b.kind == "count":
		var lock: Control = null
		for k in main.room.get_children():
			if k.get_script() and k.get_script().resource_path.ends_with("lock.gd") and not k.is_queued_for_deletion(): lock = k
		if lock == null: bug("missing", "no lock to turn"); return
		for i in mini(a.length(), lock.digits.size()):
			var ups: Array = buttons(lock).filter(func(x): return x.text == "▲")
			for j in int(a[i]): await press(ups[i])
		await press_text("Try it", lock); return
	for c in a:
		if c >= "0" and c <= "9": await press_text(c, main.acts, true)
	await press_text("Pay" if b.kind == "won" else "Say it", main.acts, true); await settle()

func p_number(a: String) -> void:
	if await go_until(_type_is("number"), "a number pad") == null: return
	await _try_all()
	await _enter_number(a, g.beat())

func p_present(a: String) -> void:
	if await go_until(_type_is("present"), 'a chance to show "%s"' % a) == null: return
	if not g.S.F.has("ev_" + a): fail('"%s" isn\'t something you have' % a); return
	await _try_all()
	await press_text(g.plain(g.ST.evidence[a].label) + " · ", main.acts)

func p_contradict(a: String) -> void:
	if await go_until(_type_is("contradict"), "a contradiction") == null: return
	await _try_all()
	for k in a.split("+"):
		k = k.strip_edges()
		var t: String = g.plain(g.ST.evidence[k].label) if g.S.F.has("ev_" + k) else (g.plain(g.ST.nodes[g.ST.statements[k].node].ko) if g.S.F.has("st_" + k) else "")
		if t == "": fail('"%s" isn\'t on the list to pick' % k); return
		await press_text(t, main.acts)
	await press_text("can't both be true", main.paper)

func p_examine(a: String) -> void:
	if await go_until(_type_is("examine"), "a close-up") == null: return
	await _try_all()
	for d in a.split("|"):
		d = d.strip_edges()
		for x in g.exam().details:
			if x.id != d or g.exam_found(x): continue
			await tap_at(_spot_pos(x))
			if not g.exam_found(x): bug("dead", "tapping the detail \"%s\" doesn't find it" % d); g.exam_tap(d); await settle()
	if g.exam_keys_left() > 0: fail("the close-up still wants more details"); return
	await inspect(); await _go_on()

func p_camera(_a: String) -> void:
	if await go_until(_type_is("camera"), "the camera") == null: return
	await _try_all()
	var b: Dictionary = g.beat(); var f: Control = main.room.frame; var was: String = g.S.node
	for i in 4:
		var want := _spot_pos({"x": b.tx, "y": b.ty}); var c := rect_of(f).get_center()
		if want.distance_to(c) > 20: await swipe(c, want)
	await press_text("Take the photo", main.paper)
	await main.get_tree().create_timer(1.5).timeout; await settle()   # the flash
	if g.S.node == was: bug("dead", "the photo can't be taken by dragging the frame onto them"); g.next(); await settle()

func p_leave(_a: String) -> void:
	if await go_until(func(): return _waits(g.beat()), "a Never mind") == null: return
	if main.kb: await press_text("✕", main.kb, true)
	else: await press_text("Never mind", main.paper)

func p_phone(a: String) -> void:
	if top() != main: await close_top()
	var t: Dictionary = {}
	for x in g.ST.phones:
		if x.id == a: t = x
	if t.is_empty(): fail('no phone thread "%s"' % a); return
	if g.has_phone():
		await press(main.bar_btns.phone); await inspect()
		await press_text(t.name, top()); await inspect()
		for b in buttons(top()):
			if is_instance_valid(b) and b.text.contains("Voicemail"): await press(b)
		await press_text("‹ Back", top()); await press_text("Close", top(), true)
	if not g.S.F.has("read_" + a): s_phone(a); await settle()   # (a phone you haven't been handed yet)

func p_map(a: String) -> void:
	await go_idle()
	if not g.S.known.has(a): fail('"%s" isn\'t on the map yet' % a); return
	if main.bar_btns.map.disabled or main.bar_btns.map.get_meta("dim"): bug("missing", "no map button here"); g.enter(a); await settle(); return
	await press(main.bar_btns.map); await inspect()
	var pl: Dictionary = g.ST.places.get(a, {})
	var b: BaseButton = null
	for x in buttons(top()):
		if x.get_meta("place", "") == a: b = x
	if b == null: bug("missing", "%s isn't on the map page" % a); await close_top(); g.enter(a); await settle(); return
	await press(b)
	if g.S.loc != a and not g.is_closed(a): fail("map didn't go to " + a)

func p_closed(a: String) -> void: await go_idle(); s_closed(a); await settle()

func p_talk(a: String) -> void:
	await go_idle()
	var p: Dictionary = g.PEOPLE.get(a, {})
	if not g.people_here().has(p):
		var w: Dictionary = g.where_now(p) if not p.is_empty() else {}
		if not w.is_empty() and w.place != g.S.loc and g.S.known.has(w.place): await p_map(w.place); await go_idle()
	if not g.people_here().has(p): fail("%s isn't here now" % a); return
	for f in main.room.figs.get_children():
		if f.is_queued_for_deletion() or f.get_meta("who") != a: continue
		if _tried.has("fig|" + a): continue
		_tried["fig|" + a] = 1
		var was := _keep()
		await tap_at(rect_of(f).get_center())
		if g.S.node == "": bug("dead", "tapping %s in the picture doesn't talk to them" % a)
		await _back_to(was)
		break
	await press_text("Talk to " + g.ST.cast.get(a, {}).get("n", a), main.paper)
	if g.S.node == "": bug("dead", "Talk to %s does nothing" % a); g.talk_to(a); await settle()

func p_wait(_a: String) -> void:
	await go_idle()
	if g.W.frozen or g.W.slot >= 3: fail("there is no Wait here"); return
	await press_text("Wait a while", main.paper)

func p_sleep(_a: String) -> void:
	await go_idle()
	if g.W.frozen or g.S.loc != g.ST.meta.get("home", "") or g.W.slot < 2: fail("there is no Go to bed here"); return
	await press_text("Go to bed", main.paper)

func p_job(a: String) -> void:
	await go_idle()
	var s := _spot("Notice board")
	if s.is_empty(): fail("no notice board here"); return
	if not g.jobs_today().any(func(j): return j.id == a) or g.W.job != "": fail('job "%s" isn\'t on the board' % a); return
	await _tap_spot(s)
	if top() == main: bug("dead", "the notice board doesn't open"); g.take_job(a); await settle(); return
	await inspect()
	var i: int = 0
	for j in g.jobs_today():
		if j.id == a: break
		i += 1
	var bs: Array = buttons(top()).filter(func(b): return b.text == "Take this job")
	if i < bs.size(): await press(bs[i])
	if g.W.job != a: bug("dead", "couldn't take the job %s" % a); await close_top(); g.take_job(a); await settle()

func p_pocket(a: String) -> void:
	await go_idle()
	if not g.pockets().any(func(e): return e.id == a): fail(a + " isn't in your pockets"); return
	await press_text(g.plain(g.ST.evidence[a].label), main.pockets_box)

func p_back(_a: String) -> void:
	await go_idle()
	if not g.place().has("back"): fail("no back arrow here"); return
	await press(main.room.back_btn)


## ---------- the case board, by finger
func p_solve(a: String) -> void:
	await go_idle()
	g._case_tick(); await settle()
	var parts := a.split(";"); var id := parts[0].strip_edges().split(" ", false)[0]
	var q = null
	for c in g.ST.cases:
		if c.id == id: q = c
	var was: String = g.S.ch
	if q == null or q.needs.is_empty():   # it happens when you look at the board
		if not main.bar_btns.board.disabled and q != null:
			await _open_board(); await inspect(); await _leave_board()
		s_solve(a) if not failed else null
		await settle(); return
	var b: Dictionary = g.board(); b.strings = maxi(b.strings, 6); b.tacks = maxi(b.tacks, 6)
	var qid := "q:" + id
	if not b.cards.has(qid): fail("the question for %s isn't on your board" % id); return
	var proofs: Array = []
	if parts.size() > 1:
		for p in parts[1].split("+"): proofs.append(g._vid(p.strip_edges()))
	await _open_board()
	for c in [qid] + proofs:
		if not b.cards.has(c): fail('"%s" is not on your board' % c); return
		if g.is_boxed(c): await _unbox(c)
		if not g.is_pinned(c):
			await _tap_card(c); await press_text("📌  Pin it up", main.paper)
			if not g.is_pinned(c): bug("dead", "Pin it up didn't pin %s" % c); g.board_pin(c)
	for p in proofs:
		if g.S.ch != was or g.S.cs.has(id): break
		if g.is_linked(qid, p): continue
		await _tap_card(qid); await press_text("Pick up a string", main.paper)
		await _tap_card(p); await inspect(); await press_text("Tie the string here", main.paper)
		if not g.is_linked(qid, p) and g.S.ch == was: bug("dead", "couldn't tie %s to %s" % [qid, p]); main.cork.drop(); g.board_link(qid, p)
	g._case_tick(); await settle()
	if not g.S.cs.has(id) and g.S.ch == was: fail("%s didn't settle" % id)
	if top() != main: await inspect(); await close_top()
	if main.cork.visible and g.S.ch == was: await _leave_board()


func p_nosolve(a: String) -> void: await go_idle(); s_nosolve(a); await settle()


func _open_board() -> void:
	if main.cork.visible: return
	if main.bar_btns.board.disabled: bug("missing", "no board button"); main._open("board")
	else: await press(main.bar_btns.board)
	await settle()
	if not main.cork.visible and top() == main and g.S.node == "": bug("dead", "the board button doesn't open the board"); main.board_view = true; main._refresh(); await settle()


func _leave_board() -> void:
	if not main.board_view: return
	if not await press_text("Close the board", main): main.board_view = false; main._refresh(); await settle()
	if main.cork.visible and g.place().get("mode", "") != "board": bug("dead", "Close the board doesn't close it"); main.board_view = false; main._refresh(); await settle()


func _unbox(id: String) -> void:
	await tap_at(rect_of(main.cork).position + main.cork.box_rect().get_center())
	if top() == main: bug("dead", "tapping the evidence box doesn't open it"); g.board_unbox(id); await settle(); return
	await inspect()
	var i: int = g.boxed().find(id)
	var bs: Array = buttons(top()).filter(func(b): return b.text == "Put it up")
	if i >= 0 and i < bs.size(): await press(bs[i])
	if g.is_boxed(id): bug("dead", "Put it up didn't take %s out of the box" % id); g.board_unbox(id); await settle()
	await close_top()


## a point on this card that a finger would really land on
func _card_point(id: String) -> Vector2:
	var c: Control = main.cork._cards.get(id)
	if c == null: return Vector2.INF
	var xf: Transform2D = main.cork.get_global_transform_with_canvas()
	for f in [Vector2(0.5, 0.5), Vector2(0.5, 0.2), Vector2(0.2, 0.5), Vector2(0.8, 0.5), Vector2(0.5, 0.85), Vector2(0.15, 0.15), Vector2(0.85, 0.15), Vector2(0.15, 0.85), Vector2(0.85, 0.85)]:
		var local: Vector2 = c.get_transform() * (c.size * f)
		if main.cork._card_at(local) == id and pick(xf * local) == main.cork and not main.cork.box_rect().has_point(local): return xf * local
	return Vector2.INF


func _tap_card(id: String) -> void:
	var p := _card_point(id)
	if p == Vector2.INF: bug("covered", "the board card %s is buried under others" % g.card(id).get("kind", id), main.cork._cards.get(id)); main.cork.pick(id); await settle(); return
	await tap_at(p)
	if main.card_sel != id: bug("dead", "tapping a board card doesn't pick it (%s)" % g.card(id).get("kind", id)); main.cork.pick(id); await settle()


## ---------- the pages: everything the top bar and the picture offer, gone through like someone curious
func _title_screen(first: String) -> void:
	_step = "title"; await _frames(6)
	if top() == main: bug("missing", "no title screen"); return
	await inspect()
	if find_btn("Chapters", top()):
		await press_text("Chapters", top()); await inspect(); snap_screen("chapters")
		if first != g.first_chapter():
			await close_top(); main.leave_title(); g.S = g._fresh(); g.start_chapter(first, true); await settle(); return
		await close_top(); await settle()
		if g.S.ch == "" and not is_instance_valid(main._title_o): bug("stuck", "closing Chapters on the title screen leaves an empty game", null)
		if find_btn("New game", top()) == null and find_btn("Start", top()) == null: main._title(); await settle()
	var b := find_btn("New game", top())
	if b == null: b = find_btn("Start", top(), true)
	Engine.time_scale = 1.0   # (it asks first, for a few seconds)
	await press(b)
	if is_instance_valid(main._title_o) and not main._title_o.is_queued_for_deletion():
		if not g.has_save(): bug("dead", "Start doesn't start")
		var again := find_btn("Tap again", top())
		if again == null: bug("missing", "New game doesn't ask before erasing your game")
		else: await press(again)
	Engine.time_scale = 40.0
	await settle(); await inspect()


func _reload_check() -> void:
	## leaving the game and coming back: what's on the screen must be the same
	if main.board_view: await _leave_board()
	var before: Array = buttons(main).map(func(b): return b.text)
	g.S = JSON.parse_string(JSON.stringify(g.S)); g._vcards = {}; g._use(g.S.ch); main._shown_node = "?"
	if main.kb: main.kb.queue_free(); main.kb = null
	g.changed.emit(); await settle()
	var after: Array = buttons(main).map(func(b): return b.text)
	if before != after: bug("missing", "after leaving and coming back the buttons differ: %s / %s" % [before, after])


func _full() -> bool: return line_no % 3 == 0 or _from_line == 0


func _notebook_quick() -> void:
	await press(main.bar_btns.note)
	if top() == main: bug("dead", "the notebook button doesn't open it"); return
	await press_text("단어 · Words", top()); await inspect()
	var tiles: Array = buttons(top()).filter(func(b): return b.text == "" and b.get_parent() is GridContainer)
	if not tiles.is_empty():
		await press(tiles[-1])
		if page_name().begins_with("page 수첩 ·"): bug("dead", "a word in the notebook doesn't open")
		else: await press_text("✕", top(), true)
	main._go_back(); await settle()   # the phone's back gesture
	if top() != main: bug("dead", "the back gesture doesn't close the notebook"); await close_top()


var _tm := {}
func _timed(n: String, f: Callable) -> void:
	print("@ ..%s" % n)
	var t := Time.get_ticks_usec(); await f.call(); _tm[n] = _tm.get(n, 0) + (Time.get_ticks_usec() - t) / 1000


func _pages(label: String) -> void:
	if g.S.node != "" and _waits(g.beat()): return
	var was_step := _step; _step = "pages at " + label; print("@ " + _step)
	var k := _keep(); _depth += 1
	await inspect()
	# tapping nothing in the picture must not break anything
	await tap_at(rect_of(main.room).position + rect_of(main.room).size * Vector2(0.5, 0.06))
	if g.S.node == "": await _timed("camera", _camera)
	if main.clock_btn.is_visible_in_tree(): await press(main.clock_btn); await inspect(); snap_screen("day_panel"); await close_top()
	if not main.bar_btns.map.disabled and not main.bar_btns.map.get_meta("dim"): await press(main.bar_btns.map); await inspect(); snap_screen("map"); await _map_page()
	if not main.bar_btns.phone.disabled: await _timed("phone", _phone)
	await _timed("notebook", _notebook if _full() else _notebook_quick)
	if not main.bar_btns.board.disabled: await _timed("board", _board)
	await _timed("menu", _menu)
	await _bug_button()
	_depth -= 1
	await _back_to(k); _step = was_step


## the map: every place you know is on it and tappable; one you've only heard of doesn't take you there
func _map_page() -> void:
	var pins := {}
	for x in buttons(top()):
		if x.has_meta("place"): pins[x.get_meta("place")] = x
	for p in g.world_st.map:
		if not g.ST.places.has(p.p): continue
		if (g.S.known.has(p.p) or g.named(p.p)) and not pins.has(p.p): bug("missing", "%s isn't on the map" % p.p)
		if pins.has(p.p) and not g.S.known.has(p.p):
			var was: String = g.S.loc
			await press(pins[p.p])
			if g.S.loc != was or top() == main: bug("dead", "you can go to %s without having been there" % p.p)
	await close_top()


func _phone() -> void:
	await press(main.bar_btns.phone); await inspect(); snap_screen("phone")
	for t in g.ST.phones:
		var b := find_btn(t.name, top())
		if b == null: bug("missing", "the thread %s isn't on the phone" % t.name); continue
		await press(b); await inspect(); snap_screen("phone_" + t.id)
		for x in buttons(top()):
			if is_instance_valid(x) and (x.text == "▶" or x.text.contains("Voicemail")): await press(x); break
		await press_text("‹ Back", top())
	await press_text("Close", top(), true)
	if top() != main: bug("dead", "Close doesn't close the phone")


func _notebook() -> void:
	var nb = load("res://scripts/ui/notebook.gd")
	await press(main.bar_btns.note)
	if top() == main: bug("dead", "the notebook button doesn't open it"); return
	for t in nb.TABS:
		if t[0] == "mix" and g.S.mx.is_empty(): continue
		await press_text(t[1], top()); await inspect(); snap_screen("notebook_" + t[0])
		if page_name() == "page ": bug("missing", "the notebook tab %s is empty" % t[0])
		match t[0]:
			"pat", "gram", "num", "mix":
				for x in buttons(top()):
					if is_instance_valid(x) and not x.disabled and not nb.TABS.any(func(y): return y[1] == x.text) and x.text != "✕":
						await press(x); await inspect(); await _back_in_notebook(t[1]); break
	await press_text("단어 · Words", top())
	if nb._vocab().is_empty(): await close_top(); return
	for f in ["Guessing", "Got it", "No note yet", "All"]: await press_text(f, top(), true); await inspect()
	for s in ["A–Z", "Newest", "ㄱㄴㄷ"]: await press_text(s, top(), true); await inspect()
	var tiles: Array = buttons(top()).filter(func(b): return b.text == "" and b.get_parent() is GridContainer)
	if tiles.size() != nb._vocab().size(): bug("missing", "the notebook lists %d of %d words" % [tiles.size(), nb._vocab().size()])
	if not tiles.is_empty():   # the last word on the list: swipe all the way down to it and open it, and come back to the same place
		for i in [tiles.size() - 1, 0]:
			tiles = buttons(top()).filter(func(b): return b.text == "" and b.get_parent() is GridContainer)
			if i >= tiles.size(): continue
			var sc := scroller_of(tiles[i])
			await press(tiles[i])
			var at := sc.scroll_vertical if is_instance_valid(sc) else -1
			if page_name().begins_with("page 수첩 ·"): bug("dead", "a word in the notebook doesn't open")
			else:
				if not _seen.has("wp"): _seen["wp"] = 1; await inspect(); snap_screen("word_page")
				var t := top(); await press_text("✕", t, true)
			if is_instance_valid(sc) and sc.scroll_vertical != at: bug("scroll", "the notebook loses your place after opening a word")
	var es := []; walk(top(), es, func(k): return k is LineEdit)
	if not es.is_empty() and not tiles.is_empty():
		var le: LineEdit = es[0]; await reach(le)
		await tap_at(rect_of(le).get_center())
		if not le.has_focus(): bug("dead", "can't tap into the notebook search", le)
		le.text = "요"; le.text_changed.emit("요"); await settle()
		le.text = ""; le.text_changed.emit(""); await settle()
	await close_top()


func _back_in_notebook(tab: String) -> void:
	for i in 3:
		if top() == main: await press(main.bar_btns.note); await press_text(tab, top()); return
		if find_btn("단어 · Words", top()): return
		await press_text("✕", top(), true)


func _board() -> void:
	await _open_board(); await inspect(); snap_screen("board")
	var b: Dictionary = g.board()
	for q in g.ST.cases:
		if not q.needs.is_empty() and g.cond(q.c) and g.ST.questions.has(q.id) and not main.cork._cards.has("q:" + q.id) and not b.cards.get("q:" + q.id, {}).has("put"): bug("missing", "the question %s isn't on the board" % q.id)
	# the box
	await tap_at(rect_of(main.cork).position + main.cork.box_rect().get_center())
	if top() == main: bug("dead", "tapping the evidence box doesn't open it")
	else:
		await inspect(); snap_screen("evidence_box")
		for i in 3:
			if find_btn("Put it up", top()): await press_text("Put it up", top()); await inspect()
		await close_top()
	# cards: look at them, big; drag one; pin, string, untie, unpin, box
	var up: Array = main.cork._cards.keys()
	for id in up.slice(0, 4 if _full() else 2):
		await _tap_card(id); await inspect()
		if not _seen.has("cardbig"):
			_seen["cardbig"] = 1
			var ps := []; walk(main.acts, ps, func(k): return k is Control and k.mouse_filter != Control.MOUSE_FILTER_IGNORE and not (k is BaseButton) and k.has_signal("gui_input") and k.get_class() == "Control" and k.custom_minimum_size.y > 80)
			if not ps.is_empty():
				await reach(ps[0]); await tap_at(rect_of(ps[0]).get_center())
				if top() == main: bug("dead", "tapping the big card doesn't show it full screen", ps[0])
				else: await inspect(); snap_screen("card_big"); await close_top()
	if up.size() >= 1:
		var id: String = up[0]; var p := _card_point(id)
		if p != Vector2.INF:
			var was := Vector2(b.cards[id].x, b.cards[id].y)
			var to := rect_of(main.cork).get_center() + Vector2(90, -40)
			await swipe(p, to); await settle()
			if Vector2(b.cards[id].x, b.cards[id].y).distance_to(was) < 0.01: bug("dead", "dragging a board card doesn't move it")
	if up.size() >= 2 and _full():
		b.tacks = maxi(b.tacks, 4); b.strings = maxi(b.strings, 3); main._refresh(); await settle()
		for id in up.slice(0, 2):
			await _tap_card(id)
			if not g.is_pinned(id): await press_text("📌  Pin it up", main.paper)
		if not g.is_linked(up[0], up[1]):
			await _tap_card(up[0]); await press_text("Pick up a string", main.paper); await inspect()
			await press_text("Put the string down", main.paper)
			await _tap_card(up[0]); await press_text("Pick up a string", main.paper)
			await _tap_card(up[1]); await press_text("Tie the string here", main.paper)
			if not g.is_linked(up[0], up[1]): bug("dead", "tying a string does nothing")
			else:
				await inspect(); snap_screen("board_tied")
				var nl: int = b.links.size()
				if await press_text("Take down the string", main.paper) and b.links.size() != nl - 1: bug("dead", "Take down the string does nothing")
		await press_text("Peel it off" if b.cards[up[1]].get("stuck", false) else "Pull the thumbtack out", main.paper)
		if g.is_pinned(up[1]): bug("dead", "Pull the thumbtack out does nothing")
		await press_text("Put it in the box", main.paper)
		if not g.is_boxed(up[1]): bug("dead", "Put it in the box does nothing")
		# drag one into the box
		var p := _card_point(up[0])
		if p != Vector2.INF:
			await swipe(p, rect_of(main.cork).position + main.cork.box_rect().get_center()); await settle()
			if not g.is_boxed(up[0]): bug("dead", "dragging a card onto the box doesn't put it away")
	await _leave_board()


func _camera() -> void:
	if g.place().get("mode", "") == "board" or not main.room.cam_btn.is_visible_in_tree(): return
	var b: Dictionary = g.board(); b.film = maxi(b.film, 3); var n: int = b.photos.size()
	await press(main.room.cam_btn)
	if not main.room.cam_mode: bug("dead", "the camera button doesn't raise the camera"); return
	await inspect()
	var f: Control = main.room.frame; var was := rect_of(f)
	await swipe(was.get_center(), was.get_center() + Vector2(-70, 40))
	if rect_of(f).position.distance_to(was.position) < 20: bug("dead", "dragging the viewfinder doesn't move it")
	var r := rect_of(f)
	await swipe(r.end + Vector2(6, 4), r.end + Vector2(70, 50))
	if absf(rect_of(f).size.x - r.size.x) < 10: bug("dead", "dragging the viewfinder's corner doesn't resize it")
	main.room._last_snap = -99999
	await press(main.room.shutter)
	if g.board().photos.size() != n + 1: bug("dead", "the shutter doesn't take a photo")
	if not _seen.has("camshot"): _seen["camshot"] = 1; snap_screen("camera")
	await press(main.room.cam_x)
	if main.room.cam_mode: bug("dead", "✕ doesn't lower the camera")


## the bug button: one tap keeps a report with a picture, wherever you are; it never covers a button of the game
func _bug_button() -> void:
	var bb: CanvasLayer = main.bugs
	for x in buttons(main):
		if x.is_visible_in_tree() and rect_of(x).intersects(rect_of(bb.btn)): bug("covered", "the bug button covers \"%s\"" % text_of(x), x)
	if _tried.has("bugbtn"): return
	_tried["bugbtn"] = 1
	var d: String = bb.get_script().folder
	bb.get_script().folder = "user://bugs_test_%d" % OS.get_process_id()
	var f: String = bb.get_script().folder + "/bug_001"
	var count := func(): return DirAccess.get_files_at(bb.get_script().folder).size() if DirAccess.dir_exists_absolute(bb.get_script().folder) else 0
	await tap_at(rect_of(bb.btn).get_center())
	if not is_instance_valid(bb.strip): bug("dead", "the bug button opens nothing")
	await tap_at(rect_of(bb.btn).get_center())
	if is_instance_valid(bb.strip): bug("dead", "tapping the bug again doesn't close it")
	if count.call() > 0: bug("dead", "the bug button keeps a report without a choice being picked")
	await tap_at(rect_of(bb.btn).get_center())
	var b: BaseButton = find_btn("Confusing", bb.strip) if is_instance_valid(bb.strip) else null
	if b == null: bug("missing", "the bug button doesn't ask what kind it was")
	else:
		for x in buttons(bb.strip):
			if not screen().encloses(rect_of(x)): bug("offscreen", "the bug choice \"%s\" is off the screen" % x.text, x)
		await tap_at(rect_of(b).get_center())
		var j = JSON.parse_string(FileAccess.get_file_as_string(f + ".json"))
		if not (j is Dictionary) or j.get("kind", "") != "Confusing" or j.get("place", "") != g.S.loc: bug("dead", "picking a kind of bug doesn't keep the report")
		if is_instance_valid(bb.strip): bug("dead", "the bug choices stay open after picking one")
		if not FileAccess.file_exists(f + ".jpg"): bug("dead", "the bug report has no picture")
	for x in [".json", ".jpg"]: DirAccess.remove_absolute(f + x)
	DirAccess.remove_absolute(bb.get_script().folder); bb.get_script().folder = d


func _menu() -> void:
	await press(main.bar_btns.menu); await inspect(); snap_screen("menu")
	await press_text("Think", top())
	await inspect()
	for x in ["Chapters", "What was said", "Settings", "Korean keyboard test"]:
		if find_btn(x, top()) == null:
			await close_top(); await press(main.bar_btns.menu)
		await press_text(x, top()); await settle()
		if top() == main: bug("dead", "menu > %s opens nothing" % x); continue
		await inspect(); snap_screen("menu_" + x)
		if x == "What was said" and not g.S.log.is_empty():
			var says: Array = buttons(top()).filter(func(b): return b.text == "▶")
			if not says.is_empty(): await press(says[-1])
		if x == "Settings" and _full():
			var before: Dictionary = Settings.v.duplicate()
			for opt in ["Large", "Small", "Medium", "Slow", "Normal", "Low", "On"]:
				var b := find_btn(opt, top(), true)
				if b: await press(b); await inspect()
			Settings.v = before
			var ls := []; walk(top(), ls, func(k): return k is ScrollContainer)
			if not ls.is_empty():
				ls[0].scroll_vertical = 100000; await _frames(2); var at: int = ls[0].scroll_vertical
				var offs: Array = buttons(top()).filter(func(b): return b.text == "Off" and rect_of(ls[0]).encloses(rect_of(b)))
				if not offs.is_empty():
					await press(offs[-1]); await _frames(4)
					if is_instance_valid(ls[0]) and absf(ls[0].scroll_vertical - at) > 20: bug("scroll", "the settings list jumps when you press something in it")
			Settings.v = before
		if x == "What was said":   # the phone's back gesture closes it too
			main._go_back(); await settle()
			if top() != main: bug("dead", "the back gesture doesn't close %s" % x)
		await close_top()
