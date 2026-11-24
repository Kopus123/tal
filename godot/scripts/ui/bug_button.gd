extends CanvasLayer
## The bug button: a small bug at the left edge, over everything. Tap it and a strip of choices opens; tap it again (or
## leave it) and the strip closes, nothing kept. Picking a choice keeps the report: a picture of the screen from when you
## tapped the bug, where you are, what you did just before, and a copy of your save, in user://bugs (nothing is sent
## anywhere). Read back with tools/gd_bugs.py.

const KINDS := ["Can't tap it", "Looks wrong", "I'm stuck", "Confusing", "Korean's off", "Idea"]
static var folder := "user://bugs"

var main: Control
var btn: Button
var strip: PanelContainer
var _trail: Array = []       ## the last touches: [seconds, x, y, what was under it]
var _pic: Image              ## the screen when the bug was tapped, and what was going on: kept only if you pick a choice
var _what: Dictionary = {}
var _t0 := Time.get_ticks_msec()


func _ready() -> void:
	layer = 40
	btn = Button.new(); btn.custom_minimum_size = Vector2(52, 52); btn.size = Vector2(52, 52); btn.position = Vector2(6, 232); btn.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: btn.add_theme_stylebox_override(st, Kit.box(26, Color(1, 1, 1, 0.07 if st != "pressed" else 0.3), Color(1, 1, 1, 0.16), 1, 0))
	btn.draw.connect(_draw_bug); btn.pressed.connect(toggle); add_child(btn)


func _draw_bug() -> void:   # drawn: an oval, a head, six legs, two feelers
	var c := btn.size / 2 + Vector2(0, 2); var w := Color(1, 1, 1, 0.6)
	for s in [-1, 1]:
		for k in 3: btn.draw_line(c + Vector2(s * 6, -4 + k * 6), c + Vector2(s * 15, -8 + k * 8), w, 2.0, true)
		btn.draw_line(c + Vector2(s * 2, -12), c + Vector2(s * 7, -19), w, 2.0, true)
	btn.draw_set_transform(c, 0.0, Vector2(0.72, 1.0)); btn.draw_circle(Vector2(0, 2), 12, w, true, -1, true); btn.draw_set_transform(Vector2.ZERO)
	btn.draw_circle(c + Vector2(0, -10), 5, w, true, -1, true)


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_trail.append([(Time.get_ticks_msec() - _t0) / 1000.0, int(e.position.x), int(e.position.y), ""])
		if _trail.size() > 14: _trail.pop_front()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not _trail.is_empty():
		var on := get_viewport().gui_get_hovered_control()
		if on: _trail[-1][3] = (on.text.left(30) if (on is Button or on is Label) and on.text != "" else on.get_class())


func _seen(n: Node, out: Array) -> void:   ## the words on the screen, top to bottom as drawn
	for k in n.get_children():
		if k is SubViewport or (k is CanvasItem and not k.visible): continue
		var t := ""
		if k is RichTextLabel: t = k.get_parsed_text()
		elif k is Label or k is Button: t = k.text
		if t.strip_edges() != "" and out.size() < 60: out.append(t.strip_edges().left(90).replace("\n", " / "))
		_seen(k, out)


func toggle() -> void:
	if is_instance_valid(strip) and not strip.is_queued_for_deletion(): close(); return
	_pic = get_viewport().get_texture().get_image()   # the screen as it was, before anything pops up
	var words := []; _seen(main, words)
	_what = {"when": Time.get_datetime_string_from_system(false, true), "build": main.BUILD, "kind": "", "chapter": Game.S.get("ch", ""), "place": Game.S.get("loc", ""), "beat": Game.S.get("node", ""),
		"day": Game.W.get("day", 0) if Game.S.has("world") else 0, "time": Game.slot_name() if Game.S.has("world") else "", "board": main.board_view, "camera": main.room.cam_mode, "keyboard": main.kb != null, "busy": main.busy,
		"trail": _trail.slice(0, -1), "log": Game.trace.duplicate(), "screen": words, "window": str(DisplayServer.window_get_size()), "save": Game.S.duplicate(true)}
	Game.sound.emit("tap")
	strip = PanelContainer.new(); strip.add_theme_stylebox_override("panel", Kit.box(16, Color(0.08, 0.09, 0.12, 0.96), Color(1, 1, 1, 0.25), 1, 10))
	strip.position = Vector2(66, 226); add_child(strip)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); strip.add_child(row)
	row.add_child(Kit.label("What's wrong?", 18, Kit.PAPER))
	for k in KINDS:
		var b := Kit.button(k, false, 17); b.custom_minimum_size = Vector2(0, 52); row.add_child(b)
		b.pressed.connect(func(): close(); _keep(k))
	var me := strip
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(me) and me == strip: close()


func close() -> void:   ## nothing is kept
	if is_instance_valid(strip): strip.queue_free()
	strip = null


func _keep(kind: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var n := 1
	while FileAccess.file_exists("%s/bug_%03d.json" % [folder, n]): n += 1
	var f := "%s/bug_%03d" % [folder, n]
	if _pic and not _pic.is_empty(): _pic.save_jpg(f + ".jpg", 0.8)
	_what.kind = kind
	var o := FileAccess.open(f + ".json", FileAccess.WRITE)
	if o: o.store_string(JSON.stringify(_what)); o.close()
	_pic = null; _what = {}
	Game.note("  (bug reported: %s)" % f); Game.sound.emit("click"); Game.toast.emit("Saved: %s" % kind)
