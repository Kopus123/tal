extends Control
## The case board (lab): a corkboard with picture cards. Drag a card to move it. Tap it to look at it.
## Hold your finger on a card until the ring fills to pick up a string, then hold on another card to pin it there
## (holding takes a moment on purpose: think before you connect). Tap a string to take it down.

signal selected(id: String)

const HOLD := 0.8                  ## seconds to hold for a pin
const CARD := Vector2(138, 168)    ## card size (at the board's design size; scales with the board)

var sel := ""                      ## the card you're looking at
var from := ""                     ## a string picked up from this card, waiting to be pinned
var _press := {}                   ## {id, at, t, moved}
var _cards := {}                   ## id -> Control


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)


func _scale() -> float: return clampf(size.y / 720.0, 0.5, 1.6)


func refresh() -> void:
	var b: Dictionary = Game.board()
	for id in _cards.keys():
		if not b.cards.has(id): _cards[id].queue_free(); _cards.erase(id)
	for id in b.cards:
		if not _cards.has(id): _cards[id] = _make(id); add_child(_cards[id])
	_layout(); queue_redraw_all()


func _layout() -> void:
	var b: Dictionary = Game.board()
	for id in _cards:
		var c: Control = _cards[id]; var d: Dictionary = b.cards[id]
		c.size = CARD * _scale(); c.position = Vector2(d.x, d.y) * size
		c.get_node("Pic").size = Vector2(c.size.x - 16, c.size.y - 56); c.get_node("Pic").position = Vector2(8, 14)
		var l: Label = c.get_node("L"); l.position = Vector2(6, c.size.y - 42); l.size = Vector2(c.size.x - 12, 38)
		c.modulate = Color(1, 1, 1) if id != from else Color(1, 0.9, 0.7)
	queue_redraw_all()


## a card: a white index card with a picture, a short caption, a red thumbtack
func _make(id: String) -> Control:
	var cd: Dictionary = Game.ST.cards[id]
	var p := Panel.new(); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new(); st.bg_color = Color("fbf6e9") if cd.kind != "say" else Color("fff8d8"); st.set_corner_radius_all(4)
	st.shadow_color = Color(0, 0, 0, 0.35); st.shadow_size = 6; st.shadow_offset = Vector2(2, 3)
	p.add_theme_stylebox_override("panel", st)
	p.rotation_degrees = float(hash(id) % 7 - 3)
	var pic := TextureRect.new(); pic.name = "Pic"; pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture = _picture(cd); pic.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.add_child(pic)
	var l := Label.new(); l.name = "L"; l.add_theme_font_size_override("font_size", 15); l.add_theme_color_override("font_color", Kit.PAPER_INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.clip_text = true; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = _caption(cd); l.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.add_child(l)
	return p


static func _picture(cd: Dictionary) -> Texture2D:
	match cd.kind:
		"say", "person": return Kit.face(cd.who, cd.get("ex", "neutral"))
		"thing":
			if cd.icon == "photo" and ResourceLoader.exists("res://art/photo.png"): return load("res://art/photo.png")
			return Kit.icon("#" + cd.icon)
		"place": return load("res://art/%s.png" % cd.art) if ResourceLoader.exists("res://art/%s.png" % cd.art) else null
		"time": return Kit.icon("#" + cd.icon)
	return null


static func _caption(cd: Dictionary) -> String:
	match cd.kind:
		"say": return "“" + Game.plain(cd.ko) + "”"
		"thing": return Game.plain(cd.label)
		"person": return Game.ST.cast.get(cd.who, {}).get("n", cd.who)
		"place", "time": return Game.plain(cd.ko)
	return cd.id


func _pin(id: String) -> Vector2:   ## where a card's thumbtack is
	var c: Control = _cards[id]
	return c.position + Vector2(c.size.x / 2, 6)


func _card_at(p: Vector2) -> String:
	var ids := _cards.keys(); ids.reverse()
	for id in ids:
		if Rect2(_cards[id].position, _cards[id].size).has_point(p): return id
	return ""


## ---------- touch
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = {"id": _card_at(e.position), "at": e.position, "t": 0.0, "moved": false, "done": false}
			set_process(true)
		else:
			_release(e.position)
	elif e is InputEventMouseMotion and not _press.is_empty() and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if e.position.distance_to(_press.at) > 14: _press.moved = true
		if _press.moved and _press.id != "":   # drag the card
			var c: Control = _cards[_press.id]
			var np: Vector2 = c.position + e.relative
			Game.board_move(_press.id, np.x / size.x, np.y / size.y); _layout()


func _process(dt: float) -> void:
	if _press.is_empty() or _press.moved or _press.id == "" or _press.done: queue_redraw_all(); return
	_press.t += dt
	if _press.t >= HOLD:   # held long enough: pick up a string, or pin the one you're carrying
		_press.done = true
		if from == "":
			if Game.board().strings <= 0: Game.toast.emit("You're out of string. Buy more."); return
			from = _press.id; Game.sound.emit("click"); Game.toast.emit("Holding a string. Hold another card to pin it there.")
		elif from != _press.id:
			var r: String = Game.board_link(from, _press.id)
			if r == "no tacks": Game.toast.emit("You're out of thumbtacks. Buy more.")
			from = ""
		else: from = ""
		_layout()
	queue_redraw_all()


func _release(p: Vector2) -> void:
	var pr := _press; _press = {}; set_process(false); queue_redraw_all()
	if pr.is_empty() or pr.moved or pr.done: return
	if pr.id != "":
		sel = pr.id; selected.emit(pr.id); Game.sound.emit("tap"); queue_redraw_all(); return
	# a tap on a string takes it down; a tap on bare cork drops the string you're holding
	for l in Game.board().links:
		if not (_cards.has(l[0]) and _cards.has(l[1])): continue
		var a := _pin(l[0]); var b := _pin(l[1])
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 16:
			Game.board_unlink(l[0], l[1]); return
	if from != "": from = ""; Game.toast.emit("You put the string down."); _layout()


## ---------- drawing: cork, strings, tacks, the hold ring
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("b98b5a"))
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in 900: draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(0.8, 2.2), Color(0.42, 0.28, 0.15, rng.randf_range(0.15, 0.45)))
	draw_rect(Rect2(Vector2.ZERO, size), Color("6b4528"), false, 10)


## strings and the hold ring go on top of the cards: a child that draws last
var _top: Control
func _enter_tree() -> void:
	if _top: return
	_top = Control.new(); _top.mouse_filter = Control.MOUSE_FILTER_IGNORE; _top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top.z_index = 10; _top.draw.connect(_draw_top); add_child(_top)


func queue_redraw_all() -> void:
	queue_redraw()
	if _top: _top.queue_redraw()


func _draw_top() -> void:
	for l in Game.board().links:
		if not (_cards.has(l[0]) and _cards.has(l[1])): continue
		var a := _pin(l[0]); var b := _pin(l[1])
		var mid := (a + b) / 2 + Vector2(0, 18)   # a little sag
		_top.draw_polyline(PackedVector2Array([a, mid, b]), Color(0.72, 0.1, 0.08), 3.0, true)
	for id in _cards:
		var tk := _pin(id)
		_top.draw_circle(tk, 7, Color("c0392b") if id != sel else Color("e9c97a")); _top.draw_circle(tk + Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.5))
	if from != "" and _cards.has(from):
		var m := get_local_mouse_position()
		_top.draw_dashed_line(_pin(from), m, Color(0.72, 0.1, 0.08, 0.7), 3.0, 10.0)
	if not _press.is_empty() and not _press.moved and _press.id != "" and not _press.done and _press.t > 0.12:
		var c: Control = _cards[_press.id]
		_top.draw_arc(c.position + c.size / 2, 40, -PI / 2, -PI / 2 + TAU * minf(_press.t / HOLD, 1.0), 40, Color(1, 1, 1, 0.9), 6)
