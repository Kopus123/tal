extends Playtester
## Lets an AI play the real game, on screen, one command at a time (tools/gd_agent.py sends them). It only ever sees what
## a player sees: the words on the paper, the buttons, the rings on the picture, pictures of the screen. It taps like a
## finger. Its notes go into playtest/ai-notes.md the moment it makes them. After 30 minutes it stops.

const LIMIT := 30 * 60.0
const OFF := ["Chapters", "Korean keyboard test", "test area", "Restart:", "start over", "Free days"]   ## not part of the story

var _home := ""
var _cap: Label
var _dot: Panel
var _list: Array = []       ## the buttons as last listed
var _rings: Array = []
var _cards: Array = []
var _start := 0
var _n := 0
var _seen_lines := {}
var _over := false


func go(m: Control, dir_: String) -> void:
	main = m; _home = dir_; dir = dir_; DirAccess.make_dir_recursive_absolute(dir)
	Game.testing = true; Voice.instant = true; Settings.frozen = true; g.words = {}; g.enc_off = true; main.guard = 0; Swipe.glide = false
	DisplayServer.window_set_title("탈 · an AI is playing")
	errors = Catcher.new(); OS.add_logger(errors)
	var fb: Array[Font] = []
	for fn in ["malgun.ttf", "seguisym.ttf", "seguiemj.ttf"]:
		var ff := FontFile.new()
		if ff.load_dynamic_font("C:/Windows/Fonts/" + fn) == OK: fb.append(ff)
	ThemeDB.fallback_font.fallbacks = fb
	_overlay()
	await _frames(6)
	main.leave_title(); g.S = g._fresh(); g.start_chapter("prologue", true); await settle()
	_start = Time.get_ticks_msec()
	_write("ready.txt", _describe())
	while true:
		await _frames(2)
		if left() < -45: main.get_tree().quit(); return
		if not FileAccess.file_exists(dir + "/cmd.json"): continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(dir + "/cmd.json"))
		DirAccess.remove_absolute(dir + "/cmd.json")
		if not (d is Dictionary): continue
		var out := ""
		for c in d.cmds:
			var r = await _do(str(c).strip_edges())
			out += str(r) if r != null else "(that went wrong)
"
		_write("out_%s.txt" % d.id, out + "\n" + _describe())
		if _over: await main.get_tree().create_timer(4).timeout; main.get_tree().quit(); return


func left() -> float: return LIMIT - (Time.get_ticks_msec() - _start) / 1000.0
func clock() -> String:
	var s := int((Time.get_ticks_msec() - _start) / 1000.0); return "%02d:%02d" % [s / 60, s % 60]


func _write(fn: String, t: String) -> void:
	var f := FileAccess.open(dir + "/" + fn + ".tmp", FileAccess.WRITE); f.store_string(t); f.close()
	DirAccess.rename_absolute(dir + "/" + fn + ".tmp", dir + "/" + fn)


func _append(fn: String, t: String) -> void:
	var p := dir + "/" + fn
	var f := FileAccess.open(p, FileAccess.READ_WRITE if FileAccess.file_exists(p) else FileAccess.WRITE)
	if f: f.seek_end(); f.store_line(t); f.close()


## ---------- what you watch: the AI's words along the bottom, a dot where it taps
func _overlay() -> void:
	var l := CanvasLayer.new(); l.layer = 50; main.get_tree().root.add_child.call_deferred(l)
	_cap = Kit.label("", 22, Color.WHITE); _cap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); _cap.offset_top = -50; _cap.offset_bottom = -8
	_cap.grow_horizontal = Control.GROW_DIRECTION_BOTH; _cap.grow_vertical = Control.GROW_DIRECTION_BEGIN; _cap.mouse_filter = Control.MOUSE_FILTER_IGNORE; _cap.visible = false
	_cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _cap.custom_minimum_size.x = 900; _cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap.add_theme_stylebox_override("normal", Kit.box(12, Color(0.1, 0.25, 0.5, 0.9), Color.TRANSPARENT, 0, 10)); l.add_child(_cap)
	_dot = Panel.new(); _dot.size = Vector2(44, 44); _dot.mouse_filter = Control.MOUSE_FILTER_IGNORE; _dot.visible = false
	_dot.add_theme_stylebox_override("panel", Kit.box(22, Color(0.2, 0.6, 1.0, 0.55), Color.WHITE, 3, 0)); l.add_child(_dot)


func caption(t: String) -> void: _cap.text = t; _cap.visible = t != ""


func _touch(p: Vector2, down: bool) -> void:
	if down and _dot: _dot.position = p - _dot.size / 2; _dot.visible = true; _dot.modulate.a = 1.0
	super._touch(p, down)
	if not down and _dot:
		var t := _dot.create_tween(); t.tween_property(_dot, "modulate:a", 0.0, 0.5)


func bug(kind: String, text: String, _c: Control = null) -> void:
	_append("ai-actions.md", "  - (%s) the player hit a problem: [%s] %s" % [clock(), kind, text])


func wait(s: float) -> void: await main.get_tree().create_timer(s).timeout


## ---------- what's on the screen, in words
func _describe() -> String:
	var o := PackedStringArray()
	var mins := maxi(0, int(left() / 60.0))
	if left() <= 0: return "TIME IS UP. Make your final notes (note ...), then stop."
	if g.S.done.has("ch1"): o.append("*** CHAPTER 1 IS FINISHED. That's the whole story so far: make your last notes and stop. ***")
	o.append("[%s played, %d min left]  %s · %s" % [clock(), mins, main.title_ko.text, main.title_en.text])
	for e in errors.take(): _append("ai-actions.md", "  - SCRIPT ERROR: " + e)
	var t := top()
	if t != main: o.append("--- a page is open over the game (✕, Close or `back` shuts it) ---")
	_rings = []; _cards = []
	if t == main:
		if main.cork.visible:
			o.append("CASE BOARD. Cards up (card N picks one):")
			for id in main.cork._cards:
				_cards.append(id)
				o.append("  card %d: [%s] %s%s" % [_cards.size(), g.card(id).get("kind", ""), g.card_label(g.card(id)), "  (pinned)" if g.is_pinned(id) else "  (loose)"])
			for l in g.board().links: o.append("  string: %s — %s" % [g.card_label(g.card(l[0])), g.card_label(g.card(l[1]))])
			o.append("  the evidence box (box opens it): %d things in it" % g.boxed().size())
		elif main.room.cam_mode: o.append("CAMERA up: viewfinder over the picture (frame X Y moves it, in % of the picture; tap the shutter; ✕ lowers it)")
		elif g.S.node == "":
			o.append("THE PICTURE (look = a picture file of the screen). Rings on it (ring N taps one):")
			for s in g.spots_now():
				_rings.append(s)
				var named: bool = s.kind == "=>" or g.F.has("found_%s_%s" % [g.S.loc, s.l])
				o.append("  ring %d at %d%%,%d%%%s" % [_rings.size(), s.x, s.y, ": " + s.l if named else "  (no label yet)"])
		else:
			var b: Dictionary = g.beat()
			if b.get("type", "") == "examine": o.append("CLOSE-UP of something: look at it (look), then tap what catches your eye (at X Y, in % of the picture)")
			elif b.get("type", "") == "camera": o.append("CAMERA: a frame over the picture. frame X Y puts its middle there (%), then press Take the photo. Use look to see where they are.")
			elif b.get("audio", false): o.append("(you only HEAR this line: \"%s\")" % g.plain(b.ko))
	var txt := []; walk(t if t != main else main.paper, txt, func(k): return (k is Label or k is RichTextLabel) and not _in_button(k))
	o.append("TEXT:")
	for l in txt:
		var s: String = text_of(l).strip_edges()
		if s == "" or l == main.title_ko or l == main.title_en or s == "▾  more" or l.modulate.a < 0.05: continue
		o.append("  " + s.replace("\n", " / "))
	if main.toast_box:
		for p in main.toast_box.get_children():
			if not p.is_queued_for_deletion() and p.get_child_count(): o.append("  (message: %s)" % p.get_child(0).text)
	var es := []; walk(t, es, func(k): return k is LineEdit)
	for e in es: o.append("  a box to write in (write TEXT): \"%s\"%s" % [e.text, "  hint: " + e.placeholder_text if e.text == "" else ""])
	if main.kb and main.kb.visible: o.append("KOREAN KEYBOARD open: type 한글 types it and presses Say it. Typed so far: \"%s\"  hint line: \"%s\"" % [main.kb.shown.text, main.kb.hint_l.text])
	_list = []
	var names := PackedStringArray()
	for b in buttons(t):
		var s: String = b.text.replace("\n", " / ").strip_edges()
		if main.kb and main.kb.is_ancestor_of(b) and not s in ["Hint", "✕"]: continue
		if s == "": s = "📷 camera" if b == main.room.cam_btn else ("shutter (take the picture)" if b == main.room.shutter else b.get_meta("word", "(picture button)") + ("  (only heard of)" if b.get_meta("heard", false) else ""))
		if OFF.any(func(x): return s.contains(x)): continue
		_list.append(b); names.append("%d) %s%s" % [_list.size(), s, "  [greyed]" if b.disabled or b.get_meta("dim", false) else ""])
	o.append("BUTTONS (tap N, or tap part of the words):"); o.append("  " + "\n  ".join(names))
	return "\n".join(o)


func _in_button(n: Node) -> bool:
	while n and n != main:
		if n is BaseButton: return true
		n = n.get_parent()
	return false


func _line_now() -> String:
	var b: Dictionary = g.beat()
	if b.is_empty(): return ""
	var who: String = g.ST.cast.get(b.get("who", ""), {}).get("n", "")
	var s := ""
	if b.has("ko"): s = "%s%s\"%s\"" % [who, " (heard only): " if b.get("audio", false) else ": ", g.plain(b.ko)]
	if b.has("en"): s += ("  " if s != "" else "") + b.en
	return s


## ---------- one command
func _do(c: String) -> String:
	var sp := c.find(" "); var cmd := (c if sp < 0 else c.left(sp)).to_lower(); var arg := "" if sp < 0 else c.substr(sp + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	if left() <= 0 and not cmd in ["note", "done"]: return "TIME IS UP: only note and done work now.\n"
	_n += 1
	if cmd in ["note", "say"]:
		caption(("📝 " if cmd == "note" else "") + arg)
		if cmd == "note": _append("ai-notes.md", "- **%s** (%s) %s" % [clock(), main.title_ko.text, arg]); return "noted.\n"
		return ""
	_append("ai-actions.md", "- %s %s" % [clock(), c])
	var msg := ""
	match cmd:
		"tap":
			var b: BaseButton = null
			if arg.is_valid_int():
				if int(arg) >= 1 and int(arg) <= _list.size() and is_instance_valid(_list[int(arg) - 1]): b = _list[int(arg) - 1]
				else: return "Button %s isn't there any more (the screen changed): use the new list.
" % arg
			else:
				for x in buttons():
					if x.text.strip_edges() == arg: b = x; break
				if b == null: b = find_btn(arg)
			if b == null or not is_instance_valid(b): return "No such button: %s\n" % arg
			if OFF.any(func(x): return b.text.contains(x)): return "That's outside the story: leave it.\n"
			if b.disabled: return "That button is greyed out.\n"
			await press(b); await wait(0.35)
		"ring":
			if not arg.is_valid_int() or int(arg) < 1 or int(arg) > _rings.size(): return "No such ring.\n"
			await tap_at(_spot_pos(_rings[int(arg) - 1])); await wait(0.6)
		"at":
			var p := arg.replace(",", " ").split(" ", false)
			if p.size() < 2: return "at X Y\n"
			var was: int = g.S.F.size()
			await tap_at(rect_of(main.room).position + Vector2(float(p[0]), float(p[1])) / 100.0 * rect_of(main.room).size); await wait(0.4)
			msg = "(something happened)\n" if g.S.F.size() != was else "(nothing there)\n"
		"card":
			if not arg.is_valid_int() or int(arg) < 1 or int(arg) > _cards.size(): return "No such card.\n"
			await _tap_card(_cards[int(arg) - 1]); await wait(0.3)
		"box":
			if not main.cork.visible: return "The board isn't open.\n"
			await tap_at(rect_of(main.cork).position + main.cork.box_rect().get_center()); await wait(0.4)
		"frame":
			var p := arg.replace(",", " ").split(" ", false)
			if p.size() < 2 or not main.room.frame.visible: return "No frame to move.\n"
			for i in 3:
				var want := rect_of(main.room).position + Vector2(float(p[0]), float(p[1])) / 100.0 * rect_of(main.room).size
				if rect_of(main.room.frame).get_center().distance_to(want) > 12: await swipe(rect_of(main.room.frame).get_center(), want)
			await wait(0.3)
		"next":   # Continue until there's something to decide (every line is shown)
			for i in 40:
				if top() != main or g.S.node == "" or _waits(g.beat()): break
				if i == 0: msg += "  " + _line_now() + "\n"
				var lab := ""
				for x in ["Continue", "Begin", "Look around", "Done looking"]:
					if find_btn(x, main.paper): lab = x; break
				if lab == "" or main.board_view: break
				await press(find_btn(lab, main.paper)); await wait(0.7)
				if g.S.node != "": msg += "  " + _line_now() + "\n"
		"type":
			if main.kb == null: return "There's nothing to type into.\n"
			main.kb.clear(); await _type(arg); await wait(0.5); await _say_it(); await wait(0.5)
		"write":
			var es := []; walk(top(), es, func(k): return k is LineEdit)
			if es.is_empty(): return "No box to write in.\n"
			await reach(es[0]); await tap_at(rect_of(es[0]).get_center()); es[0].text = arg; es[0].text_changed.emit(arg); await wait(0.4)
		"word":
			var rs := []; walk(top(), rs, func(k): return k is RichTextLabel)
			for r in rs:
				var m := Story.R("\\[url=(w:[^\\]]*)\\](?:\\[[^\\]]*\\])*" + arg).search(r.text)
				if m: r.meta_clicked.emit(m.get_string(1)); await wait(0.5); return ""
			return "You don't see that word to tap.\n"
		"swipe":
			var ss := []; walk(top(), ss, func(k): return k is ScrollContainer)
			if ss.is_empty(): return "Nothing to scroll.\n"
			var r := rect_of(ss[-1]); var d := Vector2(0, r.size.y * 0.35) * (1 if arg != "down" else -1)
			await swipe(r.get_center() - d, r.get_center() + d); await wait(0.3)
		"back": main._go_back(); await wait(0.4)
		"look":
			var fn := "look_%03d.jpg" % _n
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_jpg(dir + "/" + fn, 0.8)
			return "picture: %s/%s\n" % [dir, fn]
		"screen": pass
		"done": _over = true; return "Stopping. Bye.\n"
		_: return "Unknown command: %s\n" % cmd
	await settle()
	return msg
