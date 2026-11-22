extends Control
## The case board (lab): a corkboard in a metal frame on a brick wall. Every kind of card looks like what it is:
## people are black-and-white polaroids, the missing person is a poster, places are faded photos taped up,
## things are evidence photos with numbered tags, statements are torn notebook pages, times and your own
## questions are sticky notes.
## Drag a card to move it. Tap it to look at it. Hold a card until the ring fills to pick up a string, then hold
## another card to tie it there (holding takes a moment on purpose: think before you connect). Tap a string to take
## it down: a fresh string comes down frayed, a frayed one snaps, and the thumbtack always bends.

signal selected(id: String)

const HOLD := 0.8                  ## seconds to hold for a pin
const INK := Color("1f2a4a")       ## pen ink
const STRING := Color(0.74, 0.07, 0.07)
const WORN := Color(0.86, 0.5, 0.45)
const TACKS := [Color("c0392b"), Color("2f6fd1"), Color("e3b505"), Color("2e8b57"), Color("ececec")]

var sel := ""                      ## the card you're looking at
var from := ""                     ## a string picked up from this card, waiting to be pinned
var _press := {}                   ## {id, at, t, moved, done}
var _cards := {}                   ## id -> Control
var _top: Control                  ## strings, tacks and the hold ring: drawn over the cards
var _help: PanelContainer          ## how to tie, until you've done it once (and while you carry a string)
static var _bw: ShaderMaterial     ## old black-and-white photo
static var _sepia: ShaderMaterial  ## old faded colour photo


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout); set_process(false)
	_top = Control.new(); _top.mouse_filter = Control.MOUSE_FILTER_IGNORE; _top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top.draw.connect(_draw_top); add_child(_top)
	_help = PanelContainer.new(); _help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_theme_stylebox_override("panel", Kit.box(10, Color(0.08, 0.06, 0.05, 0.85), Color.TRANSPARENT, 0, 12))
	var hl := Kit.label("", 18, Color("f3ead2")); hl.name = "L"; hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _help.add_child(hl)
	add_child(_help)


func _s() -> float: return clampf(size.y / 720.0 * 0.8, 0.45, 1.4)   ## card scale
func _inner() -> Rect2:   ## the cork inside the frame
	var m := 46.0 * _s()
	return Rect2(Vector2(m, m), size - Vector2(m, m) * 2)


func refresh() -> void:
	var b: Dictionary = Game.board()
	for id in _cards.keys():
		if not b.cards.has(id): _cards[id].queue_free(); _cards.erase(id)
	for id in b.cards:
		if not _cards.has(id): _cards[id] = _make(id); add_child(_cards[id])
	if sel != "" and not _cards.has(sel): sel = ""
	if size.x > 0:
		for id in b.cards:
			if b.cards[id].get("auto", false): _autoplace(id)
	move_child(_top, -1); move_child(_help, -1)   # strings over cards; the how-to over everything
	_layout(); queue_redraw()


func _layout() -> void:
	var b: Dictionary = Game.board(); var r := _inner(); var s := _s()
	for id in _cards: _place(id, b.cards[id], r, s)
	_help_text()
	_top.queue_redraw()


func _place(id: String, d: Dictionary, r: Rect2, s: float) -> void:
	var c: Control = _cards[id]
	c.scale = Vector2(s, s) * (1.06 if not _press.is_empty() and _press.moved and _press.id == id else 1.0)
	var room := r.size - c.size * s
	c.position = r.position + Vector2(clampf(d.x, 0, 1) * room.x, clampf(d.y, 0, 1) * room.y)
	c.queue_redraw()


## a new card goes up where it covers the least of what's already there
func _autoplace(id: String) -> void:
	var b: Dictionary = Game.board(); var r := _inner(); var s := _s()
	var me: Vector2 = _cards[id].size * s; var room := r.size - me
	var best := Vector2(0.5, 0.5); var least := INF
	for j in 7:
		for i in 9:
			var p := Vector2(i / 8.0, j / 6.0); var at := r.position + p * room
			var cover := 0.0
			for o in b.cards:
				if o == id or b.cards[o].get("auto", false): continue
				var oc: Control = _cards[o]; var op: Vector2 = r.position + Vector2(b.cards[o].x, b.cards[o].y) * (r.size - oc.size * s)
				cover += Rect2(at, me).intersection(Rect2(op, oc.size * s)).get_area()
			if cover < least - 1.0: least = cover; best = p
	b.cards[id].x = best.x; b.cards[id].y = best.y; b.cards[id].erase("auto")


func _help_text() -> void:
	var t := ""
	if from != "": t = "Holding a string.  Now hold another card until the ring fills to tie it there.\nTap bare cork to put it down."
	elif not Game.F.has("board_tied"): t = "To tie two cards together: hold your finger on one until the ring fills,\nthen hold the other one.  Tap a string to take it down."
	_help.visible = t != ""
	(_help.get_node("L") as Label).text = t
	_help.size = Vector2.ZERO; _help.reset_size()
	var r := _inner()
	_help.position = Vector2(r.position.x + (r.size.x - _help.size.x) / 2, r.end.y - _help.size.y - 10)


## ---------- the cards
const SIZES := {"person": Vector2(124, 156), "missing": Vector2(168, 222), "place": Vector2(196, 146), "thing": Vector2(144, 170),
	"time": Vector2(112, 100), "note": Vector2(132, 112), "say": Vector2(214, 124)}

func _kind(cd: Dictionary) -> String: return "missing" if cd.kind == "person" and cd.get("missing", false) else cd.kind


func _make(id: String) -> Control:
	var cd: Dictionary = Game.ST.cards[id]; var k := _kind(cd)
	var c := Control.new(); c.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.size = SIZES.get(k, Vector2(140, 160))
	c.rotation_degrees = float(absi(hash(id)) % 9 - 4) * 0.9
	c.draw.connect(_draw_card.bind(c, id))
	match k:
		"person":
			_photo(c, Kit.face(cd.who, cd.get("ex", "neutral")), Rect2(9, 9, 106, 106), _mat_bw())
			_text(c, Game.ST.cast.get(cd.who, {}).get("n", cd.who), Rect2(4, 118, 116, 34), 20, INK)
		"missing":
			var band := ColorRect.new(); band.color = Color("b3241c"); band.position = Vector2(0, 0); band.size = Vector2(168, 46); band.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(band)
			_text(c, "실종", Rect2(0, 2, 168, 42), 30, Color.WHITE)
			_photo(c, Kit.face(cd.who, "neutral"), Rect2(18, 54, 132, 120), _mat_bw())
			_text(c, Game.ST.cast.get(cd.who, {}).get("n", cd.who), Rect2(4, 176, 160, 26), 20, Color("1a1a1a"))
			_text(c, "MISSING  ·  SEEN THIS MORNING?", Rect2(4, 201, 160, 18), 10, Color("6a6a6a"))
		"place":
			var tex: Texture2D = load("res://art/%s.png" % cd.art) if ResourceLoader.exists("res://art/%s.png" % cd.art) else null
			_photo(c, tex, Rect2(7, 7, 182, 108), _mat_sepia(), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
			_text(c, Game.plain(cd.ko), Rect2(6, 117, 184, 26), 16, Color("3a3226"))
			for side in [-1, 1]:   # two strips of tape across the top corners
				var tp := ColorRect.new(); tp.color = Color(0.95, 0.91, 0.76, 0.72); tp.size = Vector2(50, 16); tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tp.position = Vector2(-8 if side < 0 else 154, -2 if side < 0 else -10); tp.rotation_degrees = -32 * side; c.add_child(tp)
		"thing":
			var bg := ColorRect.new(); bg.color = Color("2f2f31"); bg.position = Vector2(7, 7); bg.size = Vector2(130, 114); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(bg)
			var pic: Texture2D = load("res://art/photo.png") if cd.icon == "photo" and ResourceLoader.exists("res://art/photo.png") else Kit.icon("#" + cd.icon)
			_photo(c, pic, Rect2(17, 15, 110, 98), _mat_sepia() if cd.icon == "photo" else null)
			var tag := Label.new(); tag.text = "#%d" % _evidence_no(cd.id); tag.add_theme_font_size_override("font_size", 15); tag.add_theme_color_override("font_color", Color.BLACK)
			tag.add_theme_stylebox_override("normal", Kit.box(2, Color("f4c20d"), Color.TRANSPARENT, 0, 3)); tag.position = Vector2(2, 100); tag.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(tag)
			_text(c, Game.plain(cd.label), Rect2(5, 124, 134, 42), 15, Color("2a2a2a"))
		"time":
			_text(c, Game.plain(cd.ko), Rect2(6, 18, 100, 76), 32, INK)
		"note":
			_text(c, Game.plain(cd.ko), Rect2(8, 14, 116, 92), 20, INK)
		"say":
			_photo(c, Kit.face(cd.who, cd.get("ex", "neutral")), Rect2(8, 12, 42, 42), _mat_bw())
			_text(c, Game.ST.cast.get(cd.who, {}).get("n", cd.who), Rect2(0, 56, 58, 18), 12, Color("5a5a6a"))
			var q := _text(c, "“" + Game.plain(cd.ko) + "”", Rect2(62, 8, 146, 110), 15, INK)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; q.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return c


func _photo(c: Control, tex: Texture2D, r: Rect2, mat: Material, mode := TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var t := TextureRect.new(); t.texture = tex; t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; t.stretch_mode = mode
	t.position = r.position; t.size = r.size; t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mat: t.material = mat
	c.add_child(t); return t


func _text(c: Control, t: String, r: Rect2, sz: int, col: Color) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.clip_text = true; l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = r.position; l.size = r.size; l.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(l); return l


## a card's picture on its own (the paper on the right shows it bigger)
static func _picture(cd: Dictionary) -> Texture2D:
	match cd.kind:
		"say", "person": return Kit.face(cd.who, cd.get("ex", "neutral"))
		"thing":
			if cd.icon == "photo" and ResourceLoader.exists("res://art/photo.png"): return load("res://art/photo.png")
			return Kit.icon("#" + cd.icon)
		"place": return load("res://art/%s.png" % cd.art) if ResourceLoader.exists("res://art/%s.png" % cd.art) else null
		"time": return Kit.icon("#" + cd.icon)
	return null


func _evidence_no(id: String) -> int:
	var n := 0
	for k in Game.ST.cards:
		if Game.ST.cards[k].kind == "thing": n += 1
		if k == id: return n
	return n


static func _shader(code: String) -> ShaderMaterial:
	var sh := Shader.new(); sh.code = code
	var m := ShaderMaterial.new(); m.shader = sh; return m

static func _mat_bw() -> ShaderMaterial:
	if _bw == null: _bw = _shader("shader_type canvas_item;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); float g = dot(c.rgb, vec3(0.3, 0.59, 0.11)); g = clamp((g - 0.5) * 1.3 + 0.5, 0.0, 1.0); COLOR = vec4(vec3(g) * vec3(0.97, 0.96, 0.93), c.a); }")
	return _bw

static func _mat_sepia() -> ShaderMaterial:
	if _sepia == null: _sepia = _shader("shader_type canvas_item;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); float g = dot(c.rgb, vec3(0.3, 0.59, 0.11)); vec3 s = vec3(g) * vec3(1.08, 0.94, 0.74); COLOR = vec4(mix(c.rgb, s, 0.7) * 0.92 + 0.04, c.a); }")
	return _sepia


## the paper of each card (its children draw on top of this)
func _draw_card(c: Control, id: String) -> void:
	var cd: Dictionary = Game.ST.cards.get(id, {}); var k := _kind(cd); var r := Rect2(Vector2.ZERO, c.size)
	var lifted: bool = not _press.is_empty() and _press.moved and _press.id == id
	c.draw_rect(Rect2(Vector2(3, 5) * (2.2 if lifted else 1.0), c.size), Color(0, 0, 0, 0.38 if lifted else 0.3))   # shadow
	match k:
		"time", "note":
			var col: Color = {"pink": Color("f7a8bd"), "blue": Color("a9d3f2"), "green": Color("b8e39a")}.get(cd.get("color", ""), Color("f8e36f"))
			c.draw_rect(r, col)
			c.draw_rect(Rect2(0, 0, r.size.x, 14), col.darkened(0.07))   # the sticky strip
			c.draw_colored_polygon(PackedVector2Array([Vector2(r.size.x - 18, r.size.y), Vector2(r.size.x, r.size.y - 18), Vector2(r.size.x, r.size.y)]), Color(0, 0, 0, 0.12))
		"say":
			c.draw_rect(r, Color("fbfaf2"))
			var y := 26.0
			while y < r.size.y - 4: c.draw_line(Vector2(56, y), Vector2(r.size.x - 4, y), Color(0.55, 0.7, 0.9, 0.55), 1.0); y += 19.0
			c.draw_line(Vector2(57, 0), Vector2(57, r.size.y), Color(0.9, 0.35, 0.35, 0.6), 1.5)
			var x := 0.0; var pts := PackedVector2Array()   # torn bottom edge
			while x <= r.size.x: pts.append(Vector2(x, r.size.y + (3.0 if int(x / 7) % 2 == 0 else -1.0))); x += 7.0
			c.draw_polyline(pts, Color("fbfaf2"), 4.0)
		"missing": c.draw_rect(r, Color("f3f0e6"))
		"place", "person", "thing": c.draw_rect(r, Color("f6f3ec"))
		_: c.draw_rect(r, Color.WHITE)
	if id == sel: c.draw_rect(r.grow(5), Kit.HILITE, false, 5)
	elif id == from: c.draw_rect(r.grow(5), STRING, false, 4)
	elif Game.board().cards.get(id, {}).get("new", false): c.draw_rect(r.grow(3), Color(1, 1, 1, 0.7), false, 3)


func _pin(id: String) -> Vector2:   ## where a card's thumbtack is
	var c: Control = _cards[id]
	return c.get_transform() * Vector2(c.size.x / 2, 10)


func _card_at(p: Vector2) -> String:
	var ids := []
	for k in get_children():   # topmost first
		if k != _top and k != _help: ids.push_front(k)
	for k in ids:
		var local: Vector2 = (k as Control).get_transform().affine_inverse() * p
		if Rect2(Vector2.ZERO, k.size).grow(4).has_point(local): return _cards.find_key(k)
	return ""


## ---------- touch
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = {"id": _card_at(e.position), "at": e.position, "t": 0.0, "moved": false, "done": false}
			if _press.id != "": move_child(_cards[_press.id], _top.get_index() - 1)   # it comes to the front
			set_process(true)
		else:
			_release(e.position)
	elif e is InputEventMouseMotion and from != "" and _press.is_empty(): _top.queue_redraw()   # the string follows you
	elif e is InputEventMouseMotion and not _press.is_empty() and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not _press.moved and e.position.distance_to(_press.at) > 14: _press.moved = true
		if _press.moved and _press.id != "":   # drag the card
			var c: Control = _cards[_press.id]; var r := _inner()
			var room := r.size - c.size * c.scale
			var np: Vector2 = (c.position + e.relative - r.position) / room
			Game.board_move(_press.id, np.x, np.y)
			_place(_press.id, Game.board().cards[_press.id], r, _s()); _top.queue_redraw()


func _process(dt: float) -> void:
	_top.queue_redraw()
	if _press.is_empty() or _press.moved or _press.id == "" or _press.done: return
	_press.t += dt
	if _press.t >= HOLD:   # held long enough: pick up a string, or pin the one you're carrying
		_press.done = true
		if from == "": carry(_press.id)
		elif from != _press.id: tie(_press.id)
		else: drop()


func carry(id: String) -> void:
	var b := Game.board()
	if b.strings <= 0: Game.toast.emit("You're out of string. The shop sells it."); return
	from = id; Game.sound.emit("click"); _layout(); selected.emit(sel)


func tie(id: String) -> void:
	var r: String = Game.board_link(from, id)
	if r == "no tacks": Game.toast.emit("You're out of thumbtacks. The shop sells them.")
	elif r == "same": Game.toast.emit("Those two are already tied.")
	from = ""; _layout(); selected.emit(sel)


func drop() -> void:
	if from == "": return
	from = ""; Game.toast.emit("You put the string down."); _layout(); selected.emit(sel)


func _release(p: Vector2) -> void:
	var pr := _press; _press = {}; set_process(false)
	if pr.is_empty() or pr.done: _top.queue_redraw(); return
	if pr.moved:
		if pr.id != "": Game.save(); _place(pr.id, Game.board().cards[pr.id], _inner(), _s())   # saved once, when you let go
		_top.queue_redraw(); return
	if pr.id != "":
		var was := sel; sel = pr.id; Game.sound.emit("tap")
		if was != "" and _cards.has(was): _cards[was].queue_redraw()
		_cards[sel].queue_redraw(); selected.emit(sel); return
	# a tap on a string takes it down; a tap on bare cork drops the string you're holding, or lets go of the card
	for l in Game.board().links:
		if not (_cards.has(l[0]) and _cards.has(l[1])): continue
		var pts := _curve(_pin(l[0]), _pin(l[1]))
		for i in pts.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p) < 18:
				Game.board_unlink(l[0], l[1]); _top.queue_redraw(); return
	if from != "": drop(); return
	if sel != "":
		var was := sel; sel = ""
		if _cards.has(was): _cards[was].queue_redraw()
		selected.emit("")


## ---------- drawing: the brick wall, the metal frame, the cork
func _draw() -> void:
	var s := _s(); var r := _inner()
	draw_rect(Rect2(Vector2.ZERO, size), Color("6e3b2a"))   # mortar
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var bw := 64.0 * s; var bh := 26.0 * s; var g := 3.0 * s
	var row := 0; var y := 0.0
	while y < size.y:
		var x := -bw / 2.0 if row % 2 == 1 else 0.0
		while x < size.x:
			var tone := rng.randf_range(-0.07, 0.07)
			draw_rect(Rect2(x + g, y + g, bw - g, bh - g), Color(0.55 + tone, 0.24 + tone * 0.6, 0.17 + tone * 0.4))
			x += bw
		y += bh; row += 1
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))   # the room's dim; the board's lit
	# the aluminium frame
	var f := 14.0 * s; var fr := r.grow(f)
	draw_rect(Rect2(fr.position + Vector2(6, 8) * s, fr.size), Color(0, 0, 0, 0.45))
	draw_rect(fr, Color("9aa1a8"))
	draw_rect(Rect2(fr.position, Vector2(fr.size.x, f * 0.45)), Color("d3d8dc"))
	draw_rect(Rect2(fr.position, Vector2(f * 0.45, fr.size.y)), Color("c3c9ce"))
	draw_rect(Rect2(fr.position + Vector2(0, fr.size.y - f * 0.4), Vector2(fr.size.x, f * 0.4)), Color("6c737a"))
	draw_rect(Rect2(fr.position + Vector2(fr.size.x - f * 0.4, 0), Vector2(f * 0.4, fr.size.y)), Color("7b8289"))
	# the cork
	draw_rect(r, Color("b88a57"))
	rng.seed = 7
	for i in 1400:
		var c := Color(0.36, 0.22, 0.1, rng.randf_range(0.12, 0.4)) if rng.randf() < 0.7 else Color(0.9, 0.74, 0.5, rng.randf_range(0.15, 0.35))
		draw_circle(r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y), rng.randf_range(0.8, 2.4) * s, c)
	# old pin holes
	for i in 40: draw_circle(r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y), 1.6 * s, Color(0.2, 0.12, 0.05, 0.6))
	# a shadow along the top of the cork, under the frame
	for i in 6: draw_rect(Rect2(r.position + Vector2(0, i * 2 * s), Vector2(r.size.x, 2 * s)), Color(0, 0, 0, 0.16 - i * 0.025))


## a string hangs a little: more the longer it is
func _curve(a: Vector2, b: Vector2) -> PackedVector2Array:
	var sag := clampf(a.distance_to(b) * 0.07, 6.0, 34.0) * _s()
	var mid := (a + b) / 2 + Vector2(0, sag)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	return pts


func _draw_top() -> void:
	var s := _s(); var b: Dictionary = Game.board()
	for l in b.links:
		if not (_cards.has(l[0]) and _cards.has(l[1])): continue
		var pts := _curve(_pin(l[0]), _pin(l[1]))
		var worn: bool = l.size() > 2 and l[2]
		var sh := PackedVector2Array()
		for p in pts: sh.append(p + Vector2(2, 4) * s)
		_top.draw_polyline(sh, Color(0, 0, 0, 0.25), 3.0 * s, true)
		_top.draw_polyline(pts, WORN if worn else STRING, (2.2 if worn else 3.2) * s, true)
		if worn:   # a knot where it was tied back together, and loose fibres
			var k := pts[6]
			_top.draw_circle(k, 4.0 * s, STRING.darkened(0.2))
			for d in [Vector2(-7, -5), Vector2(6, -7), Vector2(-4, 8), Vector2(8, 5)]: _top.draw_line(k, k + d * s, WORN, 1.2 * s, true)
	for id in _cards:
		var tk := _pin(id); var col: Color = TACKS[absi(hash(id)) % TACKS.size()]
		_top.draw_circle(tk + Vector2(3, 4) * s, 7.5 * s, Color(0, 0, 0, 0.35))
		_top.draw_circle(tk, 7.5 * s, col.darkened(0.25)); _top.draw_circle(tk + Vector2(-1, -1) * s, 6 * s, col)
		_top.draw_circle(tk + Vector2(-2.5, -2.5) * s, 2.2 * s, Color(1, 1, 1, 0.6))
	if from != "" and _cards.has(from):
		_top.draw_dashed_line(_pin(from), get_local_mouse_position(), Color(STRING, 0.75), 3.0 * s, 10.0 * s)
	if not _press.is_empty() and not _press.moved and _press.id != "" and not _press.done and _press.t > 0.12:
		var c: Control = _cards[_press.id]
		var ctr := c.get_transform() * (c.size / 2)
		_top.draw_arc(ctr, 44 * s, 0, TAU, 48, Color(0, 0, 0, 0.35), 9 * s)
		_top.draw_arc(ctr, 44 * s, -PI / 2, -PI / 2 + TAU * minf(_press.t / HOLD, 1.0), 48, Color(1, 1, 1, 0.95), 7 * s)
