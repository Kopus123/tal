extends Control
## 지도, the drawn map of the village (the drawings come from tools/make_map.py). Places you've been to are drawn in: tap
## one to go there. Places someone has only named are a pencilled circle with the name: you know they exist, and you find
## the way yourself. Paths show between the places on your map.

signal picked(p: String)

const LAND := Vector2(1200, 545)
const PIN := Vector2(132, 104)

var _at := {}        ## place -> the middle of its drawing (story/world.story === map)
var land := TextureRect.new()
var _k := 1.0


func _ready() -> void:
	land.texture = load("res://map/land.svg"); land.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; land.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(land)
	var roads := Control.new(); roads.name = "roads"; roads.mouse_filter = Control.MOUSE_FILTER_IGNORE; roads.draw.connect(_draw_roads.bind(roads)); land.add_child(roads)
	for p in Game.world_st.map:
		_at[p.p] = Vector2(p.x, p.y) / 100.0 * LAND
		if not Game.ST.places.has(p.p): continue
		if Game.S.known.has(p.p): _pin(p.p, true)
		elif Game.named(p.p): _pin(p.p, false)
	resized.connect(_fit); _fit()


func _fit() -> void:
	_k = minf(size.x / LAND.x, size.y / LAND.y)
	if _k <= 0.0: return
	land.size = LAND; land.scale = Vector2(_k, _k); land.position = (size - LAND * _k) / 2


func _on_map(p: String) -> bool: return Game.ST.places.has(p) and (Game.S.known.has(p) or Game.named(p))


## a path: a soft double line, a little crooked, dotted where you only know the place by name; the bus is dashes
func _draw_roads(c: Control) -> void:
	for r in Game.world_st.map_paths:
		if not (_on_map(r[0]) and _on_map(r[1]) and _at.has(r[0]) and _at.has(r[1])): continue
		var a: Vector2 = _at[r[0]] + Vector2(0, 8); var b: Vector2 = _at[r[1]] + Vector2(0, 8)
		var n := (b - a).orthogonal().normalized() * (a.distance_to(b) * (0.12 if hash(r[0] + r[1]) % 2 else -0.12))
		var pts := PackedVector2Array()
		for i in 25:
			var t := i / 24.0; pts.append(a.lerp((a + b) / 2 + n, t).lerp(((a + b) / 2 + n).lerp(b, t), t))
		var both: bool = Game.S.known.has(r[0]) and Game.S.known.has(r[1])
		if r[2] == "bus" or not both:
			for i in range(0, 24, 2): c.draw_line(pts[i], pts[i + 1], Color("7a5a3c") if r[2] == "bus" else Color(0.35, 0.28, 0.2, 0.6), 4.0 if r[2] == "bus" else 2.5, true)
		else:
			c.draw_polyline(pts, Color("b08b5e"), 8.0, true); c.draw_polyline(pts, Color("ecd9ab"), 4.5, true)


func _pin(p: String, been: bool) -> void:
	var pl: Dictionary = Game.ST.places[p]
	var b := Button.new(); b.size = PIN; b.position = _at[p] - Vector2(PIN.x / 2, 52); b.flat = true; b.set_meta("place", p); b.set_meta("word", pl.get("name", p))
	b.set_meta("heard", not been)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	if been:
		var t := TextureRect.new(); t.texture = load("res://map/%s.svg" % (p if ResourceLoader.exists("res://map/%s.svg" % p) else "madang")); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.position = Vector2(16, 0); t.size = Vector2(100, 75); t.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(t)
	var here: bool = p == Game.S.loc
	b.draw.connect(func():
		var f := b.get_theme_default_font(); var nm: String = pl.get("name", p); var sz := 19
		var w := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 18
		var r := Rect2((PIN.x - w) / 2, 74, w, 28)
		if been:
			b.draw_style_box(Kit.box(7, Kit.PAPER_INK if here else Color("fbf6e9"), Color("6b4528"), 2, 0), r)
			b.draw_string(f, Vector2(r.position.x + 9, r.position.y + 21), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Kit.PAPER if here else Kit.PAPER_INK)
			if here:   # a red seal: you are here
				var c := Vector2(PIN.x - 22, 14); b.draw_circle(c, 16, Color("b3241c"), true, -1, true); b.draw_arc(c, 13, 0, TAU, 32, Color(1, 1, 1, 0.8), 1.5, true)
				b.draw_string(f, c + Vector2(-12, 5), "여기", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		else:   # pencil: only a name
			var c := Vector2(PIN.x / 2, 44); var ink := Color(0.25, 0.22, 0.2, 0.75)
			for i in 3: b.draw_arc(c + Vector2(i * 1.5 - 1, 1 - i), 22.0 + i, 0.3 + i, TAU + 0.1 + i, 40, ink, 1.6, true)
			b.draw_string(f, c + Vector2(-6, 10), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
			b.draw_string(f, Vector2(r.position.x + 9, r.position.y + 21), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, ink))
	b.pressed.connect(func():
		if been: picked.emit(p)
		else: Game.sound.emit("tap"); Game.toast.emit("You've only heard of it. Find the way there first."))
	land.add_child(b)
