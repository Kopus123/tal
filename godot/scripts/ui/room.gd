extends Control
## The picture: the drawing for the place you're in, the night darkness, your flashlight (a real light), moonlight,
## the hidden spots you tap, and leaning in on a thing while you look at it. Lives on the left half of the screen.
## The drawing is lit inside its own little world (a SubViewport) so the darkness doesn't touch the paper on the right.

const ART_W := 1600.0
const ART_H := 1200.0
const SPOT_R := 0.075            ## how close (fraction of the picture's width) a tap must be to a hidden spot
const LEAN_ZOOM := 1.6
const STEP_BACK := 0.28        ## leaning in: a tap further than this (fraction of the width) from the middle steps back
## moonlight through the shed window, per drawing: where (fraction of the picture), how strong, how far
const MOON := {"shed": [Vector2(0.81, 0.25), 0.55, 1.1], "shed_window": [Vector2(0.3, 0.3), 0.5, 2.2]}

var vp: SubViewport
var art: Sprite2D
var night: CanvasModulate
var torch: PointLight2D
var moon: PointLight2D
var cam: Camera2D
var view: TextureRect
var marks: Control
var back_btn: Button
var _art_key := ""
var _ripples := []
var _empty := 0
const DRAG_PX := 24.0
var _press_at := Vector2.ZERO
var _dragged := false


func _ready() -> void:
	clip_contents = true
	vp = SubViewport.new(); vp.size = Vector2i(int(ART_W), int(ART_H)); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(vp)
	art = Sprite2D.new(); art.centered = false; vp.add_child(art)
	night = CanvasModulate.new(); vp.add_child(night)
	torch = _light(Color(1.0, 0.9, 0.72), 1.5, 1.35); torch.position = Vector2(ART_W, ART_H) / 2; vp.add_child(torch)   # starts in the middle
	moon = _light(Color(0.7, 0.8, 1.0), 0.5, 1.0); vp.add_child(moon)
	cam = Camera2D.new(); cam.position = Vector2(ART_W, ART_H) / 2; vp.add_child(cam); cam.make_current()
	view = TextureRect.new(); view.texture = vp.get_texture(); view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE; view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	marks = Control.new(); marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks); add_child(marks)
	back_btn = Button.new(); back_btn.text = "‹"; back_btn.add_theme_font_size_override("font_size", 40)
	back_btn.custom_minimum_size = Vector2(64, 64); back_btn.position = Vector2(14, 0); back_btn.flat = false
	back_btn.add_theme_stylebox_override("normal", _round(Color(0.04, 0.05, 0.07, 0.6))); back_btn.add_theme_stylebox_override("pressed", _round(Color(0.1, 0.1, 0.12, 0.8)))
	back_btn.add_theme_stylebox_override("hover", _round(Color(0.04, 0.05, 0.07, 0.6)))
	back_btn.pressed.connect(func(): Game.sound.emit("tap"); Game.enter(Game.place().back))
	add_child(back_btn)
	resized.connect(func(): back_btn.position = Vector2(14, size.y - 78))
	Game.changed.connect(refresh)
	Game.lean.connect(_on_lean)


func _round(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(32); s.border_color = Color(1, 0.98, 0.92, 0.35); s.set_border_width_all(2)
	return s


## a soft round light: bright in the middle, gone at the edge
func _light(c: Color, energy: float, scale: float) -> PointLight2D:
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0)); g.add_point(0.45, Color(1, 1, 1, 0.75))
	var t := GradientTexture2D.new(); t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL; t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(1, 0.5)
	t.width = 512; t.height = 512
	var l := PointLight2D.new(); l.texture = t; l.color = c; l.energy = energy; l.texture_scale = scale; l.enabled = false
	return l


func refresh() -> void:
	var pl: Dictionary = Game.place()
	var key: String = pl.get("art", "")
	if key != _art_key:
		_art_key = key
		var tex := load("res://art/%s.png" % key) as Texture2D
		art.texture = tex
		if tex: art.scale = Vector2(ART_W / tex.get_width(), ART_H / tex.get_height())
		modulate.a = 0.0; create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	var dark := float(pl.get("dark", "0"))
	var v := 1.0 - dark
	night.color = Color(v * 0.9, v * 0.95, v * 1.15).clamp() if dark > 0 else Color.WHITE
	torch.enabled = dark > 0 and bool(Game.F.get("lit", 0))
	if MOON.has(key) and dark > 0:
		moon.enabled = true; moon.position = MOON[key][0] * Vector2(ART_W, ART_H); moon.energy = MOON[key][1]; moon.texture_scale = MOON[key][2]
	else:
		moon.enabled = false
	back_btn.visible = pl.has("back") and Game.node == ""
	marks.queue_redraw()


## ---------- input: tap a spot, drag the light, or tap nothing
func _gui_input(e: InputEvent) -> void:
	# touches arrive as mouse events too (Godot's default), so mouse events cover phone and laptop alike
	# a press that moves more than a little is a drag (pointing the light): letting go after it taps nothing
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_aim(e.position)
		if e.position.distance_to(_press_at) > DRAG_PX: _dragged = true
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press_at = e.position; _dragged = false; _aim(e.position)
		elif not _dragged: _tap(e.position)


func _to_art(p: Vector2) -> Vector2:   ## screen position in this box -> position in the drawing (when not leaning in)
	return p / size * Vector2(ART_W, ART_H)


func _aim(p: Vector2) -> void:
	torch.position = cam.get_screen_center_position() + (p / size - Vector2(0.5, 0.5)) * Vector2(ART_W, ART_H) / cam.zoom


func _tap(p: Vector2) -> void:
	if Game.node != "":
		# looking closely at something: a tap well away from it (it sits in the middle) steps back from it
		if Game._leaning and (p - size / 2).length() > size.x * STEP_BACK: Game.step_back()
		return
	var pct := p / size * 100.0
	var best: Dictionary = {}; var bd := 1e9
	for s in Game.spots_now():
		var d := (Vector2(s.x, s.y * ART_H / ART_W) - Vector2(pct.x, pct.y * ART_H / ART_W)).length() / 100.0
		if d < SPOT_R and d < bd: bd = d; best = s
	if not best.is_empty():
		Game.tap_spot(best); return
	_ripple(p)
	Game.note("  tapped nothing at %d%%, %d%%%s" % [pct.x, pct.y, " in the dark" if float(Game.place().get("dark", "0")) > 0.6 and not Game.F.get("lit", 0) else ""])
	var pl: Dictionary = Game.place()
	if float(pl.get("dark", "0")) > 0.6 and not Game.F.get("lit", 0):
		_empty += 1
		if _empty % 3 == 1: Game.toast.emit("Too dark to make anything out.")


## ---------- leaning in on a thing you're looking at
func _on_lean(at: Vector2, on: bool) -> void:
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_parallel()
	if on:
		var half := Vector2(ART_W, ART_H) / LEAN_ZOOM / 2
		var c := (at / 100.0 * Vector2(ART_W, ART_H)).clamp(half, Vector2(ART_W, ART_H) - half)
		t.tween_property(cam, "zoom", Vector2.ONE * LEAN_ZOOM, 0.55); t.tween_property(cam, "position", c, 0.55)
	else:
		t.tween_property(cam, "zoom", Vector2.ONE, 0.45); t.tween_property(cam, "position", Vector2(ART_W, ART_H) / 2, 0.45)
	marks.visible = not on


## ---------- small marks: a faint dot on things you've found, ripples where you tapped nothing
func _ripple(p: Vector2) -> void:
	var r := {"p": p, "t": 0.0}; _ripples.append(r)
	var tw := create_tween(); tw.tween_method(func(v): r.t = v; marks.queue_redraw(), 0.0, 1.0, 0.5)
	tw.tween_callback(func(): _ripples.erase(r); marks.queue_redraw())


func _draw_marks() -> void:
	if Game.node == "":
		for s in Game.spots_now():
			if Game.F.has("found_%s_%s" % [Game.loc, s.l]):
				marks.draw_circle(Vector2(s.x, s.y) / 100.0 * size, 5, Color(1, 0.98, 0.92, 0.35))
	for r in _ripples:
		marks.draw_arc(r.p, 10 + 26 * r.t, 0, TAU, 32, Color(1, 1, 1, 0.8 * (1 - r.t)), 2.5)


## the slam: the whole picture jolts
func shake() -> void:
	var tw := create_tween()
	for i in 6: tw.tween_property(view, "position", Vector2(randf_range(-9, 9), randf_range(-7, 7)), 0.035)
	tw.tween_property(view, "position", Vector2.ZERO, 0.05)
