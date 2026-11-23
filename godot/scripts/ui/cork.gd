extends Control
## The case board (lab): a corkboard in a metal frame on a brick wall. Every kind of card looks like what it is:
## people are black-and-white polaroids, the missing person is a poster, places are faded photos taped up,
## things are evidence photos with numbered tags, statements are torn notebook pages, times and your own
## questions are sticky notes.
## Drag a card to move it. Tap it to look at it: the paper on the right shows it big, with what you can do with it
## (pin it up with a thumbtack, pick up a string, tie the string here, take a string down). Cards go up loose; only
## pinned cards can have strings. A fresh string comes down frayed, a frayed one snaps; a tack pulled out is bent.

signal selected(id: String)
signal box_open                    ## the evidence box was tapped

const INK := Color("1f2a4a")       ## pen ink
const STRING := Color(0.74, 0.07, 0.07)
const WORN := Color(0.86, 0.5, 0.45)
const TACKS := [Color("c0392b"), Color("2f6fd1"), Color("e3b505"), Color("2e8b57"), Color("ececec")]

var sel := ""                      ## the card you're looking at
var from := ""                     ## a string picked up from this card, waiting to be pinned
var _press := {}                   ## {id, at, grab, moved}
var _cards := {}                   ## id -> Control
var _top: Control                  ## strings and tacks: drawn over the cards
var _help: PanelContainer          ## how to tie, until you've done it once (and while you carry a string)
static var _bw: ShaderMaterial     ## old black-and-white photo
static var _sepia: ShaderMaterial  ## old faded colour photo


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_top = Control.new(); _top.mouse_filter = Control.MOUSE_FILTER_IGNORE; _top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top.draw.connect(_draw_top); add_child(_top)
	_help = PanelContainer.new(); _help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_theme_stylebox_override("panel", Kit.box(10, Color(0.08, 0.06, 0.05, 0.85), Color.TRANSPARENT, 0, 12))
	var hl := Kit.label("", 20, Color("f3ead2")); hl.name = "L"; hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _help.add_child(hl)
	add_child(_help)


func _s() -> float: return clampf(size.y / 720.0 * 0.86, 0.45, 1.4)   ## card scale
func _inner() -> Rect2:   ## the cork inside the frame
	var m := 46.0 * _s()
	return Rect2(Vector2(m, m), size - Vector2(m, m) * 2)


func refresh() -> void:
	var b: Dictionary = Game.board()
	for id in _cards.keys():
		if not b.cards.has(id) or Game.is_boxed(id): _cards[id].queue_free(); _cards.erase(id)
	for id in b.cards:
		if not _cards.has(id) and not Game.is_boxed(id): _cards[id] = _make(id); add_child(_cards[id])
	if sel != "" and not _cards.has(sel): sel = ""
	if size.x > 0:
		for id in b.cards:
			if b.cards[id].get("auto", false) and _cards.has(id): _autoplace(id)
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
	c.rotation_degrees = c.get_meta("tilt", 0.0) * (1.0 if d.get("pinned", false) else 3.0)   # loose cards lie crooked
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
				if o == id or b.cards[o].get("auto", false) or not _cards.has(o): continue
				var oc: Control = _cards[o]; var op: Vector2 = r.position + Vector2(b.cards[o].x, b.cards[o].y) * (r.size - oc.size * s)
				cover += Rect2(at, me).intersection(Rect2(op, oc.size * s)).get_area()
			if cover < least - 1.0: least = cover; best = p
	b.cards[id].x = best.x; b.cards[id].y = best.y; b.cards[id].erase("auto")


func _help_text() -> void:
	var t := ""
	if from != "": t = "Holding a string from: %s\nTap another pinned card, then \"Tie the string here\" on the right." % Game.card_label(Game.card(from))
	elif not Game.F.has("board_tied"): t = "Tap a card to look at it.  Pin cards up with thumbtacks,\nthen tie string between them (the buttons on the right)."
	_help.visible = t != ""
	(_help.get_node("L") as Label).text = t
	_help.size = Vector2.ZERO; _help.reset_size()
	var r := _inner()
	_help.position = Vector2(r.position.x + (r.size.x - _help.size.x) / 2, r.end.y - _help.size.y - 10)


## ---------- the cards
const SIZES := {"person": Vector2(124, 160), "missing": Vector2(168, 226), "place": Vector2(196, 150), "thing": Vector2(144, 176),
	"time": Vector2(112, 100), "note": Vector2(136, 116), "say": Vector2(226, 142), "photo": Vector2(186, 164)}

func _kind(cd: Dictionary) -> String: return "missing" if cd.kind == "person" and cd.get("missing", false) else cd.kind


func _make(id: String) -> Control:
	var cd: Dictionary = Game.card(id); var k := _kind(cd)
	var c := Control.new(); c.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.size = SIZES.get(k, Vector2(140, 160))
	c.set_meta("tilt", float(absi(hash(id)) % 9 - 4) * 0.9)
	c.draw.connect(_draw_card.bind(c, id))
	match k:
		"person":
			_photo(c, Kit.face(cd.who, cd.get("ex", "neutral")), Rect2(9, 9, 106, 106), _mat_bw())
			_text(c, Game.ST.cast.get(cd.who, {}).get("n", cd.who), Rect2(2, 117, 120, 40), 23, INK)
		"missing":
			var band := ColorRect.new(); band.color = Color("b3241c"); band.position = Vector2(0, 0); band.size = Vector2(168, 46); band.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(band)
			_text(c, "실종", Rect2(0, 2, 168, 42), 30, Color.WHITE)
			_photo(c, Kit.face(cd.who, "neutral"), Rect2(18, 54, 132, 120), _mat_bw())
			_text(c, Game.ST.cast.get(cd.who, {}).get("n", cd.who), Rect2(4, 175, 160, 30), 23, Color("1a1a1a"))
			_text(c, "MISSING · SEEN HER?", Rect2(4, 204, 160, 20), 13, Color("6a6a6a"))
		"place":
			var tex: Texture2D = load("res://art/%s.png" % cd.art) if ResourceLoader.exists("res://art/%s.png" % cd.art) else null
			_photo(c, tex, Rect2(7, 7, 182, 108), _mat_sepia(), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
			_text(c, Game.plain(cd.ko), Rect2(4, 116, 188, 32), 21, Color("3a3226"))
			for side in [-1, 1]:   # two strips of tape across the top corners
				var tp := ColorRect.new(); tp.color = Color(0.95, 0.91, 0.76, 0.72); tp.size = Vector2(50, 16); tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tp.position = Vector2(-8 if side < 0 else 154, -2 if side < 0 else -10); tp.rotation_degrees = -32 * side; c.add_child(tp)
		"thing":
			var bg := ColorRect.new(); bg.color = Color("2f2f31"); bg.position = Vector2(7, 7); bg.size = Vector2(130, 114); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(bg)
			var pic: Texture2D = load("res://art/photo.png") if cd.icon == "photo" and ResourceLoader.exists("res://art/photo.png") else Kit.icon("#" + cd.icon)
			_photo(c, pic, Rect2(17, 15, 110, 98), _mat_sepia() if cd.icon == "photo" else null)
			var tag := Label.new(); tag.text = "#%d" % _evidence_no(cd.id); tag.add_theme_font_size_override("font_size", 17); tag.add_theme_color_override("font_color", Color.BLACK)
			tag.add_theme_stylebox_override("normal", Kit.box(2, Color("f4c20d"), Color.TRANSPARENT, 0, 3)); tag.position = Vector2(2, 100); tag.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(tag)
			_text(c, Game.plain(cd.label), Rect2(3, 122, 138, 52), 18, Color("2a2a2a"))
		"time":
			_text(c, Game.plain(cd.ko), Rect2(6, 18, 100, 76), 34, INK)
		"note":
			var qt: String = Game.plain(cd.ko)
			_text(c, qt, Rect2(6, 14, 124, 98), 23 if qt.length() <= 10 else (19 if qt.length() <= 18 else 16), INK)
		"photo":   # one you took: exactly what was in your frame, printed black and white, where and when underneath
			_photo(c, photo_tex(cd), Rect2(8, 8, 170, 124), _mat_bw(), TextureRect.STRETCH_SCALE)
			_text(c, Game.plain(cd.ko), Rect2(4, 133, 178, 28), 16, Color("3a3226"))
		"say":
			_photo(c, Kit.face(cd.who, cd.get("ex", "neutral")), Rect2(8, 12, 42, 42), _mat_bw())
			_text(c, Game.ST.cast.get(cd.who, {}).get("n", cd.who), Rect2(0, 56, 58, 34), 14, Color("5a5a6a"))
			var q := _text(c, "“" + Game.plain(cd.ko) + "”", Rect2(62, 6, 160, 132), 18, INK)
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


## a photo you took: the part of the place's drawing that was in your frame
static var _shots: Dictionary = {}   ## pictures already loaded from the phone
static func photo_tex(cd: Dictionary) -> Texture2D:
	var file: String = cd.get("file", "")
	if file != "":   # taken in a 3D place: the picture itself
		if not _shots.has(file):
			var im := Image.load_from_file(file)
			_shots[file] = ImageTexture.create_from_image(im) if im != null and not im.is_empty() else null
		return _shots[file]
	var path := "res://art/%s.png" % cd.get("art", "")
	if not ResourceLoader.exists(path): return null
	var t: Texture2D = load(path)
	var r: Array = cd.rect
	var a := AtlasTexture.new(); a.atlas = t
	a.region = Rect2(r[0] / 100.0 * t.get_width(), r[1] / 100.0 * t.get_height(), r[2] / 100.0 * t.get_width(), r[3] / 100.0 * t.get_height())
	return a


## a card's picture on its own (the paper on the right shows it bigger)
static func _picture(cd: Dictionary) -> Texture2D:
	match cd.kind:
		"photo": return photo_tex(cd)
		"say", "person": return Kit.face(cd.who, cd.get("ex", "neutral"))
		"thing":
			if cd.icon == "photo" and ResourceLoader.exists("res://art/photo.png"): return load("res://art/photo.png")
			return Kit.icon("#" + cd.icon)
		"place": return load("res://art/%s.png" % cd.art) if ResourceLoader.exists("res://art/%s.png" % cd.art) else null
		"time": return Kit.icon("#" + cd.icon)
	return null


func _evidence_no(id: String) -> int:
	if id.begins_with("ev:"): return Game.ST.evidence.keys().find(id.substr(3)) + 1   # the chapter's evidence, in story order
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
	var cd: Dictionary = Game.card(id); var k := _kind(cd); var r := Rect2(Vector2.ZERO, c.size)
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
		"place", "person", "thing", "photo": c.draw_rect(r, Color("f6f3ec"))
		_: c.draw_rect(r, Color.WHITE)
	if c.has_meta("preview"): return
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


## ---------- touch: drag to move, tap to look (everything else is a button on the paper)
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = {"id": _card_at(e.position), "at": e.position, "moved": false}
			if _press.id != "":
				_press.grab = e.position - _cards[_press.id].position   # where on the card your finger is
				move_child(_cards[_press.id], _top.get_index() - 1)    # it comes to the front
		else:
			_release(e.position)
	elif e is InputEventMouseMotion and not _press.is_empty() and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not _press.moved and e.position.distance_to(_press.at) > 22: _press.moved = true
		if _press.moved and _press.id != "":   # drag the card
			var c: Control = _cards[_press.id]; var r := _inner()
			var room := r.size - c.size * _s()
			var np: Vector2 = (e.position - _press.grab - r.position) / room   # the card stays under your finger
			Game.board_move(_press.id, np.x, np.y)
			_place(_press.id, Game.board().cards[_press.id], r, _s()); _top.queue_redraw()


func _release(p: Vector2) -> void:
	var pr := _press; _press = {}
	if pr.is_empty(): return
	if pr.moved and pr.id != "" and box_rect().has_point(p):   # dropped on the box: put away
		if sel == pr.id: sel = ""
		if from == pr.id: from = ""
		Game.board_box(pr.id); refresh(); selected.emit(sel); return
	if not pr.moved and pr.id == "" and box_rect().has_point(p): Game.sound.emit("tap"); box_open.emit(); return
	if pr.moved:
		if pr.id != "": Game.save(); _place(pr.id, Game.board().cards[pr.id], _inner(), _s())   # saved once, when you let go
		_top.queue_redraw(); return
	pick(pr.id)   # a tap: look at that card (bare cork: look at nothing)


func pick(id: String) -> void:
	var was := sel; sel = id
	if id != "": Game.sound.emit("tap")
	for k in [was, sel]:
		if _cards.has(k): _cards[k].queue_redraw()
	_top.queue_redraw(); selected.emit(sel)


func carry(id: String) -> void:
	if Game.board().strings <= 0: Game.toast.emit("You're out of string. The shop sells it."); return
	from = id; Game.sound.emit("click"); _layout(); _cards[id].queue_redraw(); selected.emit(sel)


func tie(id: String) -> void:
	var r: String = Game.board_link(from, id)
	if r == "same": Game.toast.emit("Those two are already tied.")
	elif r == "no string": Game.toast.emit("You're out of string. The shop sells it.")
	var was := from; from = ""
	if _cards.has(was): _cards[was].queue_redraw()
	_layout(); selected.emit(sel)


func drop() -> void:
	if from == "": return
	var was := from; from = ""
	if _cards.has(was): _cards[was].queue_redraw()
	_layout(); selected.emit(sel)


## the selected card again, bigger, for the paper on the right
func preview(id: String, width: float) -> Control:
	var c := _make(id); c.set_meta("preview", true); c.rotation_degrees = 0
	var k := minf(width / c.size.x, 300.0 / c.size.y)
	var w := Control.new(); w.custom_minimum_size = c.size * k; w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.scale = Vector2(k, k); crisp(c, k); w.add_child(c)
	return w


## a card shown scaled up: its words drawn at the big size instead of stretched (stretched text goes blurry)
static func crisp(c: Control, k: float) -> void:
	for l in c.get_children():
		if l is Label:
			l.add_theme_font_size_override("font_size", int(round(l.get_theme_font_size("font_size") * k)))
			l.size *= k; l.scale = Vector2.ONE / k


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


## the evidence box, in the bottom right corner of the cork
func box_rect() -> Rect2:
	var s := _s(); var r := _inner(); var sz := Vector2(176, 104) * s
	return Rect2(r.end - sz - Vector2(10, 4) * s, sz)


func _draw_box() -> void:
	var s := _s(); var r := box_rect(); var n: int = Game.box_unseen()
	# new things stick up out of the top, with a little paper tag saying how many
	if n > 0:
		for i in mini(n, 3):
			var w := Vector2(r.position.x + r.size.x * (0.22 + 0.22 * i), r.position.y + 10 * s)
			var pts := PackedVector2Array([Vector2(-22, 0), Vector2(22, 0), Vector2(24, -34 - 6 * (i % 2)), Vector2(-20, -36 - 6 * (i % 2))])
			var rot := deg_to_rad(-8.0 + 8.0 * i)
			var poly := PackedVector2Array()
			for q in pts: poly.append(w + (q * s).rotated(rot))
			_top.draw_colored_polygon(poly, Color("f6f3ec") if i != 1 else Color("f8e36f"))
			_top.draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0, 0, 0, 0.25), 1.0)
	_top.draw_rect(Rect2(r.position + Vector2(4, 6) * s, r.size), Color(0, 0, 0, 0.35))
	_top.draw_rect(r, Color("a9783f"))
	_top.draw_rect(Rect2(r.position, Vector2(r.size.x, 16 * s)), Color("8a5f2e"))                     # the rim
	_top.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.3, r.size.y * 0.42), Vector2(r.size.x * 0.4, 30 * s)), Color("efe6cf"))   # its label
	var font := ThemeDB.fallback_font
	var lw := font.get_string_size("증거", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s)).x
	_top.draw_string(font, Vector2(r.get_center().x - lw / 2, r.position.y + r.size.y * 0.42 + 23 * s), "증거", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s), Color("3a2a1a"))
	if n > 0:
		var tag := Rect2(r.end.x - 40 * s, r.position.y - 14 * s, 34 * s, 28 * s)
		_top.draw_rect(tag, Color("fbf6e9")); _top.draw_rect(tag, Color(0, 0, 0, 0.3), false, 1.0)
		var t := str(n); var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * s)).x
		_top.draw_string(font, Vector2(tag.get_center().x - tw / 2, tag.end.y - 7 * s), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * s), Color("b3241c"))


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
	_draw_box()
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
		if not b.cards[id].get("pinned", false): continue
		var tk := _pin(id); var col: Color = TACKS[absi(hash(id)) % TACKS.size()]
		_top.draw_circle(tk + Vector2(3, 4) * s, 7.5 * s, Color(0, 0, 0, 0.35))
		_top.draw_circle(tk, 7.5 * s, col.darkened(0.25)); _top.draw_circle(tk + Vector2(-1, -1) * s, 6 * s, col)
		_top.draw_circle(tk + Vector2(-2.5, -2.5) * s, 2.2 * s, Color(1, 1, 1, 0.6))
	if from != "" and _cards.has(from) and sel != "" and sel != from and _cards.has(sel):
		_top.draw_dashed_line(_pin(from), _pin(sel), Color(STRING, 0.8), 3.0 * s, 10.0 * s)
