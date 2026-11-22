extends Control
## The picture: the drawing for where you are (or a close-up), lit for real: the time of day, night darkness, your
## flashlight, moonlight. Things to tap are hidden in it. Villagers stand in it on free days. Also the camera frame.
## The drawing is lit inside its own little world (a SubViewport) so the light doesn't touch the paper on the right.

signal wants(what: String)   ## a spot that opens something on the screen (the notice board, the phone)
signal caught                ## a stakeout: a light found you

const ART_W := 1600.0
const ART_H := 1200.0
const SPOT_R := 0.075            ## how close (fraction of the picture's width) a tap must be to a hidden spot
const LEAN_ZOOM := 1.6
const STEP_BACK := 0.28          ## leaning in: a tap further than this (fraction of the width) from the middle steps back
const DRAG_PX := 24.0
## moonlight through the shed window, per drawing: where (fraction of the picture), how strong, how far
const MOON := {"shed": [Vector2(0.81, 0.25), 0.55, 1.1], "shed_window": [Vector2(0.3, 0.3), 0.5, 2.2]}
## the light outside at each time of day (indoors it changes less)
const SKY := {"morning": Color(1.0, 0.97, 0.92), "afternoon": Color.WHITE, "evening": Color(1.0, 0.8, 0.66), "night": Color(0.42, 0.48, 0.72)}

var vp: SubViewport
var art: Sprite2D
var night: CanvasModulate
var torch: PointLight2D
var moon: PointLight2D
var cam: Camera2D
var view: TextureRect
var figs: Control
var marks: Control
var frame: Panel
var back_btn: Button
var cam_btn: Button                ## raise the camera (places, when you have one)
var shutter: Button
var cam_x: Button
var veil: Control                  ## the dark around the viewfinder, the film count
var cam_mode := false
var glow: Control                  ## soft rings on what someone just named
var drift: CPUParticles2D          ## dust, leaves, motes in the air
## a stakeout
var watch: Control                 ## the people on patrol (dark shapes) and you, the eye at the top
var _walk: Array = []              ## {d, t, tex, light, step}
var _sus := 0.0                    ## how close they are to seeing you (1 = seen)
var _me := Vector2(-1, -1)         ## where you are (percent), while you creep somewhere
var _moving := false
var _beat := 0.0
var _so_place := ""
var _still := 0.0                  ## how long the frame has sat still (it focuses after a moment)
var _focused := false
var _resizing := false
var _last_snap := 0
var _art_key := ""
var _ripples := []
var _empty := 0
var _press_at := Vector2.ZERO
var _dragged := false
var _exam_miss := 0


func _ready() -> void:
	clip_contents = true
	vp = SubViewport.new(); vp.size = Vector2i(int(ART_W), int(ART_H)); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	art = Sprite2D.new(); art.centered = false; vp.add_child(art)
	night = CanvasModulate.new(); vp.add_child(night)
	torch = _light(Color(1.0, 0.9, 0.72), 1.5, 1.35); torch.position = Vector2(ART_W, ART_H) / 2; vp.add_child(torch)   # starts in the middle
	moon = _light(Color(0.7, 0.8, 1.0), 0.5, 1.0); vp.add_child(moon)
	cam = Camera2D.new(); cam.position = Vector2(ART_W, ART_H) / 2; vp.add_child(cam); cam.make_current()
	view = TextureRect.new(); view.texture = vp.get_texture(); view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE; view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	figs = Control.new(); figs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); figs.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(figs)
	marks = Control.new(); marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks); add_child(marks)
	frame = Panel.new(); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.visible = false
	var fs := StyleBoxFlat.new(); fs.bg_color = Color(1, 1, 1, 0.05); fs.border_color = Color(1, 1, 1, 0.9); fs.set_border_width_all(3); fs.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", fs); add_child(frame)
	back_btn = Button.new(); back_btn.text = "‹"; back_btn.add_theme_font_size_override("font_size", 44)
	back_btn.custom_minimum_size = Vector2(84, 84)
	for st in ["normal", "hover", "focus"]: back_btn.add_theme_stylebox_override(st, _round(Color(0.04, 0.05, 0.07, 0.6)))
	back_btn.add_theme_stylebox_override("pressed", _round(Color(0.1, 0.1, 0.12, 0.8)))
	back_btn.pressed.connect(func(): Game.sound.emit("tap"); Game.enter(Game.place().back))
	add_child(back_btn)
	drift = CPUParticles2D.new(); drift.emitting = false; add_child(drift)
	watch = Control.new(); watch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); watch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	watch.draw.connect(_draw_watch); add_child(watch)
	glow = Control.new(); glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.draw.connect(_draw_glow); add_child(glow)
	var gt := create_tween().set_loops(); gt.tween_property(glow, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE); gt.tween_property(glow, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	veil = Control.new(); veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.draw.connect(_draw_veil); veil.visible = false; add_child(veil)
	move_child(frame, -1)
	cam_btn = _icon_btn("📷", func(): camera(true)); shutter = _icon_btn("", _snap); cam_x = _icon_btn("✕", func(): camera(false))
	shutter.custom_minimum_size = Vector2(104, 104)
	for st in ["normal", "hover", "focus"]: shutter.add_theme_stylebox_override(st, _ring(Color(1, 1, 1, 0.92)))
	shutter.add_theme_stylebox_override("pressed", _ring(Color(0.8, 0.8, 0.8, 1)))
	resized.connect(func(): back_btn.position = Vector2(10, size.y - 94); _place_cam_btns(); _place_figs())
	set_process(false)
	Game.lean.connect(_on_lean)


func _icon_btn(t: String, f: Callable) -> Button:
	var b := Button.new(); b.text = t; b.add_theme_font_size_override("font_size", 36); b.custom_minimum_size = Vector2(84, 84)
	for st in ["normal", "hover", "focus"]: b.add_theme_stylebox_override(st, _round(Color(0.04, 0.05, 0.07, 0.6)))
	b.add_theme_stylebox_override("pressed", _round(Color(0.1, 0.1, 0.12, 0.8)))
	b.pressed.connect(f); b.visible = false; add_child(b); return b


func _ring(c: Color) -> StyleBoxFlat:   ## the shutter: a white disc in a dark ring
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(52); s.border_color = Color(0.05, 0.05, 0.07, 0.7); s.set_border_width_all(8)
	return s


func _place_cam_btns() -> void:
	cam_btn.position = Vector2(size.x - 94, size.y - 94)
	shutter.position = Vector2(size.x - 124, (size.y - 104) / 2)
	cam_x.position = Vector2(size.x - 94, 10)


## ---------- the camera: raise it, drag the viewfinder where you want, wait for it to focus, take the shot
func camera(on: bool) -> void:
	if on == cam_mode: return
	cam_mode = on; Game.sound.emit("tap")
	if on:
		frame.set_meta("placed", true)
		frame.size = size * 0.36; frame.position = (size - frame.size) / 2; _still = 0.0; _focused = false
	refresh()


func _snap() -> void:
	if not cam_mode: return
	if Time.get_ticks_msec() - _last_snap < 700: return   # the film has to wind on
	_last_snap = Time.get_ticks_msec()
	var r := Rect2(frame.position / size * 100.0, frame.size / size * 100.0)
	var why: String = Game.take_photo(r, _art_key)
	if why == "no film": Game.sound.emit("wrong"); Game.toast.emit("Out of film. The shop sells it."); return
	var f := ColorRect.new(); f.color = Color.WHITE; f.mouse_filter = Control.MOUSE_FILTER_IGNORE; f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(f)
	var tw := create_tween(); tw.tween_property(f, "modulate:a", 0.0, 0.45); tw.tween_callback(f.queue_free)
	veil.queue_redraw()


func _process(dt: float) -> void:   # the viewfinder settles and focuses once you stop moving it
	if _so_place != "": _so_tick(dt)
	if not cam_mode:
		if _so_place == "": set_process(false)
		return
	_still += dt
	if _still > 0.3 and not _focused:
		_focused = true; Game.sound.emit("tap"); frame.modulate.a = 1.0; veil.queue_redraw()


func _draw_veil() -> void:
	var f := Rect2(frame.position, frame.size); var dim := Color(0, 0, 0, 0.5)
	veil.draw_rect(Rect2(0, 0, size.x, f.position.y), dim)
	veil.draw_rect(Rect2(0, f.end.y, size.x, size.y - f.end.y), dim)
	veil.draw_rect(Rect2(0, f.position.y, f.position.x, f.size.y), dim)
	veil.draw_rect(Rect2(f.end.x, f.position.y, size.x - f.end.x, f.size.y), dim)
	var c := Color(1, 1, 1, 0.95 if _focused else 0.4); var k := 26.0
	for corner in [f.position, Vector2(f.end.x, f.position.y), f.end, Vector2(f.position.x, f.end.y)]:
		var sx := 1.0 if corner.x == f.position.x else -1.0; var sy := 1.0 if corner.y == f.position.y else -1.0
		veil.draw_line(corner, corner + Vector2(k * sx, 0), c, 4); veil.draw_line(corner, corner + Vector2(0, k * sy), c, 4)
	var font := ThemeDB.fallback_font
	veil.draw_string(font, f.position + Vector2(4, -10), "🎞 %d" % Game.board().get("film", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.9))
	var hc := f.end   # the corner you drag to resize
	veil.draw_circle(hc, 16, Color(1, 1, 1, 0.9)); veil.draw_line(hc - Vector2(7, 7), hc + Vector2(7, 7), Color(0.1, 0.1, 0.12), 2.5)
	veil.draw_line(hc + Vector2(7, 7), hc + Vector2(1, 7), Color(0.1, 0.1, 0.12), 2.5); veil.draw_line(hc + Vector2(7, 7), hc + Vector2(7, 1), Color(0.1, 0.1, 0.12), 2.5)
	var tip := "Drag to move  ·  drag the corner (or pinch) to resize  ·  press the white button"
	var tw := font.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	veil.draw_string(font, Vector2((size.x - tw) / 2, size.y - 22), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.75))


func _round(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(42); s.border_color = Color(1, 0.98, 0.92, 0.35); s.set_border_width_all(2)
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
	var b: Dictionary = Game.beat()
	var exam: bool = b.get("type", "") == "examine"
	if exam and cam.zoom != Vector2.ONE:
		cam.zoom = Vector2.ONE; cam.position = Vector2(ART_W, ART_H) / 2; marks.visible = true
	var key: String = Game.exam().get("art", "") if exam else pl.get("art", "")
	if not exam and Game.ST.get("free", false) and ResourceLoader.exists("res://art/%s_live.png" % key): key += "_live"
	if key != _art_key:
		_art_key = key
		var tex := load("res://art/%s.png" % key) as Texture2D
		art.texture = tex
		if tex: art.scale = Vector2(ART_W / tex.get_width(), ART_H / tex.get_height())
		modulate.a = 0.0; create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
		_exam_miss = 0
	# the light: night darkness (with a flashlight), or the time of day
	var dark := float(pl.get("dark", "0"))
	if exam: night.color = Color.WHITE
	elif dark > 0:
		var v := 1.0 - dark
		night.color = Color(v * 0.9, v * 0.95, v * 1.15).clamp()
	elif pl.get("light", "") == "own": night.color = Color.WHITE
	else:
		var sky: Color = SKY[Game.slot_name()] if Game.S.F.has("started") else Color.WHITE
		night.color = sky.lerp(Color.WHITE, 0.55) if pl.get("light", "") == "indoors" else sky
	torch.enabled = dark > 0 and bool(Game.F.get("lit", 0)) and not exam
	if MOON.has(key) and dark > 0:
		moon.enabled = true; moon.position = MOON[key][0] * Vector2(ART_W, ART_H); moon.energy = MOON[key][1]; moon.texture_scale = MOON[key][2]
	else: moon.enabled = false
	# the camera: yours to raise when you're standing somewhere (not mid-conversation, not at the board)
	var can_shoot: bool = not Game.ST.is_empty() and Game.node == "" and not exam and pl.get("mode", "") != "board"
	if not can_shoot: cam_mode = false
	cam_btn.visible = can_shoot and not cam_mode; shutter.visible = cam_mode; cam_x.visible = cam_mode; veil.visible = cam_mode
	back_btn.visible = pl.has("back") and Game.node == "" and not cam_mode
	marks.visible = not cam_mode and cam.zoom == Vector2.ONE
	if cam_mode: set_process(true); veil.queue_redraw(); _place_cam_btns()
	frame.visible = b.get("type", "") == "camera" or cam_mode
	if frame.visible and not frame.has_meta("placed"):
		frame.set_meta("placed", true); frame.size = size * Vector2(0.44, 0.52); frame.position = size * Vector2(0.28, 0.24)
	if not frame.visible: frame.remove_meta("placed")
	if cam_mode: frame.modulate.a = 1.0 if _focused else 0.5
	_place_figs()
	_stakeout(pl)
	marks.queue_redraw(); glow.queue_redraw()
	_drift(pl.get("ambient", "") if not exam else "")


## ---------- what someone just named lights up in the picture (a soft golden ring)
func _draw_glow() -> void:
	if Settings.get_("glow") == 0 or cam_mode or cam.zoom != Vector2.ONE: return
	var b: Dictionary = Game.beat()
	if not b.has("ko"): return
	var named: Array = Story.tokens(b.ko).map(func(t): return t[1])
	for g in Game.place().get("glow", []):
		if not g.w in named or Game.know_level(g.w) == 2: continue   # a word you know doesn't need pointing at
		var a := 0.45 if Game.know_level(g.w) == 1 else 1.0
		var c := Vector2(g.x, g.y) / 100.0 * size; var rx: float = g.r / 100.0 * size.x
		var ry: float = (g.h / 100.0 * size.y) if g.h > 0 else rx
		var pts := PackedVector2Array()
		for i in 49: pts.append(c + Vector2(cos(TAU * i / 48.0) * rx, sin(TAU * i / 48.0) * ry))
		glow.draw_polyline(pts, Color(1.0, 0.84, 0.4, 0.95 * a), 4.0, true)
		glow.draw_polyline(pts, Color(1.0, 0.84, 0.4, 0.25 * a), 12.0, true)


## ---------- the air: dust in sunbeams, falling leaves, motes of light
var _drift_kind := ""
func _drift(kind: String) -> void:
	if kind == _drift_kind and drift.emitting == (kind != ""): return
	_drift_kind = kind; drift.emitting = false
	if not kind in ["dust", "leaves", "motes"]: return
	drift.position = Vector2(size.x / 2, 0); drift.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drift.emission_rect_extents = Vector2(size.x / 2, 4); drift.direction = Vector2(0, 1); drift.spread = 25
	match kind:
		"leaves":
			drift.amount = 14; drift.lifetime = 9.0; drift.gravity = Vector2(18, 26); drift.initial_velocity_min = 10; drift.initial_velocity_max = 30
			drift.angular_velocity_min = -90; drift.angular_velocity_max = 90; drift.scale_amount_min = 5; drift.scale_amount_max = 9
			drift.color = Color(0.86, 0.55, 0.22, 0.85)
		"dust":
			drift.position = Vector2(size.x / 2, size.y / 2); drift.emission_rect_extents = size / 2; drift.direction = Vector2(1, -0.2); drift.spread = 180
			drift.amount = 22; drift.lifetime = 8.0; drift.gravity = Vector2(2, -1); drift.initial_velocity_min = 2; drift.initial_velocity_max = 8
			drift.angular_velocity_min = 0; drift.angular_velocity_max = 0; drift.scale_amount_min = 2; drift.scale_amount_max = 3.5
			drift.color = Color(1, 0.96, 0.85, 0.45)
		"motes":
			drift.position = Vector2(size.x / 2, size.y / 2); drift.emission_rect_extents = size / 2; drift.direction = Vector2(0, -1); drift.spread = 60
			drift.amount = 18; drift.lifetime = 7.0; drift.gravity = Vector2(0, -4); drift.initial_velocity_min = 4; drift.initial_velocity_max = 10
			drift.angular_velocity_min = 0; drift.angular_velocity_max = 0; drift.scale_amount_min = 2.5; drift.scale_amount_max = 4.5
			drift.color = Color(1, 0.88, 0.55, 0.7)
	drift.preprocess = drift.lifetime   # already in the air when you arrive
	drift.emitting = true


## ---------- the stakeout: set up the patrol when you arrive; take it down when you leave
func _stakeout(pl: Dictionary) -> void:
	var on: bool = pl.get("mode", "") == "stakeout"
	if not on:
		if _so_place != "": _so_clear()
		return
	if _so_place == Game.loc and Game.so().get("x", -1.0) == _me.x and Game.so().get("y", -1.0) == _me.y: return
	if _so_place != Game.loc:
		_so_clear(); _so_place = Game.loc
		for d in pl.get("walkers", []):
			var t := TextureRect.new(); t.texture = Kit.figure(d.who); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT; t.modulate = Color(0.06, 0.06, 0.08, 0.95); t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			watch.add_child(t)
			var l := _light(Color(1.0, 0.86, 0.6), 1.7, d.r / 100.0 * ART_W * 2.0 / 512.0); l.enabled = true; vp.add_child(l)
			_walk.append({"d": d, "t": randf(), "tex": t, "light": l, "step": 0.0, "dir": 1.0})
		_sus = 0.0
	if not _moving:
		var s: Dictionary = Game.so(); _me = Vector2(s.get("x", 50.0), s.get("y", 92.0))
	set_process(true); watch.queue_redraw()


func _so_clear() -> void:
	for w in _walk: w.tex.queue_free(); w.light.queue_free()
	_walk.clear(); _so_place = ""; _sus = 0.0; _moving = false; watch.queue_redraw()


## each frame: they walk their beat (and stop while something's being said); their light finds you or doesn't
func _so_tick(dt: float) -> void:
	var paused: bool = Game.node != "" or not visible
	var me_px := _me / 100.0 * size
	var hidden: bool = Game.so().get("hid", "") != "" and not _moving
	var lit: bool = bool(Game.F.get("lit", 0))
	var seen := false
	for w in _walk:
		var d: Dictionary = w.d
		if not paused: w.t = fmod(w.t + dt / d.sec, 2.0)
		var k: float = w.t if w.t <= 1.0 else 2.0 - w.t          # there and back
		var face: float = 1.0 if w.t <= 1.0 else -1.0
		var pos: Vector2 = d.a.lerp(d.b, smoothstep(0.0, 1.0, k))
		var dir: Vector2 = (d.b - d.a).normalized() * face
		var h := size.y * 0.34 * clampf(pos.y / 80.0, 0.6, 1.2)
		w.tex.size = Vector2(h * 200.0 / 424.0, h); w.tex.position = pos / 100.0 * size - Vector2(w.tex.size.x / 2, h)
		w.tex.flip_h = face < 0
		var beam: Vector2 = pos + dir * d.r * 0.9 + Vector2(0, 4)  # the light falls ahead of them
		w.light.position = beam / 100.0 * Vector2(ART_W, ART_H)
		var r_px: float = d.r / 100.0 * size.x
		var beam_px := beam / 100.0 * size
		if not hidden and me_px.distance_to(beam_px) < r_px: seen = true                      # in the beam, in the open
		if lit and me_px.distance_to(pos / 100.0 * size) < r_px * 2.4: seen = true             # your own light gives you away
		if not paused:   # footsteps: louder the closer they are
			w.step += dt
			if w.step > 0.55:
				w.step = 0.0
				var near := clampf(1.0 - me_px.distance_to(pos / 100.0 * size) / size.x, 0.0, 1.0)
				_sfx("step", lerpf(-30.0, -4.0, near))
	if not paused:
		_sus = clampf(_sus + (dt * 1.5 if seen else -dt * 0.45), 0.0, 1.0)
		if _sus > 0.35:
			_beat += dt
			if _beat > lerpf(1.0, 0.35, _sus): _beat = 0.0; _sfx("heart", lerpf(-14.0, 0.0, _sus))
		if _sus >= 1.0:
			_sus = 0.0; _moving = false; _sfx("spotted", 0.0); Game.note("  spotted"); caught.emit()
	watch.queue_redraw()


func _sfx(n: String, db: float) -> void:
	if Settings.get_("sound") == 0: return
	var s := load("res://sfx/%s.wav" % n) as AudioStream
	if s == null: return
	var p := AudioStreamPlayer.new(); p.stream = s; p.volume_db = db; add_child(p); p.play(); p.finished.connect(p.queue_free)


## a tap in a stakeout: creep to a hiding place, or toward a way out (in the open the whole way)
func _so_tap(p: Vector2) -> void:
	if _moving: return
	var pct := p / size * 100.0
	var best: Dictionary = {}; var bd := 1e9; var kind := ""
	for h in Game.place().get("hides", []):
		var dd := (Vector2(h.x, h.y) - pct).length()
		if dd < 10 and dd < bd: bd = dd; best = h; kind = "hide"
	for s in Game.spots_now():
		var dd := (Vector2(s.x, s.y) - pct).length()
		if dd < 10 and dd < bd: bd = dd; best = s; kind = "spot"
	if best.is_empty(): _ripple(p); return
	var to := Vector2(best.x, best.y)
	var secs := clampf(_me.distance_to(to) / 40.0, 0.35, 1.6)
	_moving = true; Game.so_move(_me.x, _me.y); Game.sound.emit("tap")
	var tw := create_tween(); tw.tween_property(self, "_me", to, secs).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_moving = false
		if _so_place == "": return
		if kind == "hide": Game.so_hide(best.l)
		else: Game.so_move(to.x, to.y); Game.tap_spot(best))


## you (a crouched shadow), the hiding places, and the eye: how close they are to seeing you
func _draw_watch() -> void:
	if _so_place == "": return
	var font := ThemeDB.fallback_font
	var hid: String = Game.so().get("hid", "") if not _moving else ""
	for h in Game.place().get("hides", []):
		var c := Vector2(h.x, h.y) / 100.0 * size
		watch.draw_arc(c, 22, 0, TAU, 32, Color(0.75, 0.85, 1.0, 0.35 if h.l != hid else 0.8), 2.0)
		var w := font.get_string_size(h.l, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		watch.draw_string(font, c + Vector2(-w / 2, 40), h.l, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.9, 1.0, 0.55))
	var me := _me / 100.0 * size
	var col := Color(0.02, 0.02, 0.03, 0.55) if hid != "" else Color(0.02, 0.02, 0.03, 0.9)
	watch.draw_circle(me + Vector2(0, -14), 9, col); watch.draw_colored_polygon(PackedVector2Array([me + Vector2(-14, 4), me + Vector2(14, 4), me + Vector2(9, -8), me + Vector2(-9, -8)]), col)
	if hid == "": watch.draw_arc(me + Vector2(0, -6), 24, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)   # you're in the open
	# the eye
	var e := Vector2(size.x / 2, 34)
	var lid := PackedVector2Array()
	for i in 17: lid.append(e + Vector2(lerpf(-34, 34, i / 16.0), -sin(PI * i / 16.0) * 16))
	for i in 17: lid.append(e + Vector2(lerpf(34, -34, i / 16.0), sin(PI * i / 16.0) * 16))
	watch.draw_colored_polygon(lid, Color(0, 0, 0, 0.45))
	var open := Color(1, 1 - _sus, 1 - _sus, 0.35 + 0.6 * _sus)
	watch.draw_polyline(lid + PackedVector2Array([lid[0]]), open, 2.5, true)
	if _sus > 0.02: watch.draw_circle(e, 4 + 9 * _sus, Color(0.9, 0.15, 0.1, 0.35 + 0.6 * _sus))


## ---------- villagers standing in the picture (free days)
func _place_figs() -> void:
	Kit.clear(figs)
	if Game.ST.is_empty() or Game.beat().get("type", "") == "examine": return
	for p in Game.people_here():
		var a: Dictionary = Game.where_now(p)
		var t := TextureRect.new(); t.texture = Kit.figure(p.id); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		var look: String = Game.ST.cast.get(p.id, {}).get("look", "")
		var m := Story.R("size=([\\d.]+)").search(look)
		var h := size.y * 0.3 * (float(m.get_string(1)) if m else 1.0)
		t.size = Vector2(h * 200.0 / 424.0, h); t.position = Vector2(a.x / 100.0 * size.x - t.size.x / 2, a.y / 100.0 * size.y - h)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE; t.set_meta("who", p.id); figs.add_child(t)


## ---------- input: tap a spot, drag the light (or the camera frame), or tap nothing
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMagnifyGesture and cam_mode:   # pinch the viewfinder bigger or smaller
		_frame_size(frame.size.x / size.x * e.factor, true); _still = 0.0; _focused = false; return
	# touches arrive as mouse events too (Godot's default), so mouse events cover phone and laptop alike.
	# a press that moves more than a little is a drag (pointing the light): letting go after it taps nothing
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if frame.visible:
			if _resizing: _frame_size((e.position.x - frame.position.x) / size.x, false)
			else: frame.position = (frame.position + e.relative).clamp(Vector2.ZERO, size - frame.size)
			if cam_mode: _still = 0.0; _focused = false; frame.modulate.a = 0.5; veil.queue_redraw()
		else: _aim(e.position)
		if e.position.distance_to(_press_at) > DRAG_PX: _dragged = true
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press_at = e.position; _dragged = false
			_resizing = cam_mode and e.position.distance_to(frame.position + frame.size) < 56
			if not frame.visible: _aim(e.position)
		else:
			_resizing = false
			if not _dragged and not cam_mode: _tap(e.position)


## the viewfinder's size, as a fraction of the picture's width (it keeps the picture's shape); pinch or drag its corner
func _frame_size(k: float, keep_center: bool) -> void:
	k = clampf(k, 0.12, 0.8)
	var c := frame.position + frame.size / 2
	frame.size = size * k
	frame.position = ((c - frame.size / 2) if keep_center else frame.position).clamp(Vector2.ZERO, size - frame.size)
	veil.queue_redraw()


func _aim(p: Vector2) -> void:
	torch.position = cam.get_screen_center_position() + (p / size - Vector2(0.5, 0.5)) * Vector2(ART_W, ART_H) / cam.zoom


func _tap(p: Vector2) -> void:
	var pct := p / size * 100.0
	var b: Dictionary = Game.beat()
	if b.get("type", "") == "examine": _exam_tap(pct); return
	if _so_place != "" and Game.node == "": _so_tap(p); return
	if Game.node != "":
		# looking closely at something: a tap well away from it (it sits in the middle) steps back from it
		if Game._leaning and (p - size / 2).length() > size.x * STEP_BACK: Game.step_back()
		return
	for f in figs.get_children():   # a villager
		if Rect2(f.position, f.size).has_point(p): Game.talk_to(f.get_meta("who")); return
	var best: Dictionary = {}; var bd := 1e9
	for s in Game.spots_now():
		var d := (Vector2(s.x, s.y * ART_H / ART_W) - Vector2(pct.x, pct.y * ART_H / ART_W)).length() / 100.0
		if d < SPOT_R and d < bd: bd = d; best = s
	if not best.is_empty():
		if best.kind == "=>" and best.t in ["board", "phone"]:
			Game.F["found_%s_%s" % [Game.loc, best.l]] = 1; Game.sound.emit("tap"); wants.emit(best.t); return
		Game.tap_spot(best); return
	_ripple(p)
	Game.note("  tapped nothing at %d%%, %d%%%s" % [pct.x, pct.y, " in the dark" if float(Game.place().get("dark", "0")) > 0.6 and not Game.F.get("lit", 0) else ""])
	if float(Game.place().get("dark", "0")) > 0.6 and not Game.F.get("lit", 0):
		_empty += 1
		if _empty % 3 == 1: Game.toast.emit("Too dark to make anything out.")


## a close-up: tap what you notice (after a few misses, faint rings show where to look)
func _exam_tap(pct: Vector2) -> void:
	var best = null; var bd := 1e9
	for d in Game.exam().get("details", []):
		var dist := (Vector2(d.x, d.y * ART_H / ART_W) - Vector2(pct.x, pct.y * ART_H / ART_W)).length()
		if dist <= d.r and dist < bd: bd = dist; best = d
	if best == null or Game.exam_found(best):
		_exam_miss += 1; _ripple(pct / 100.0 * size); Game.sound.emit("tap"); marks.queue_redraw(); return
	Game.exam_tap(best.id)


## the camera: the people (the target) have to be inside the frame
func shoot(b: Dictionary) -> void:
	var r := Rect2(frame.position / size * 100.0, frame.size / size * 100.0).grow(-6)
	if not r.has_point(Vector2(b.tx, b.ty)):
		Game.sound.emit("wrong"); Game.toast.emit("They're not in the frame yet. Drag the frame over them first."); return
	Game.sound.emit("tap")
	var f := ColorRect.new(); f.color = Color.WHITE; f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(f)
	var tw := create_tween(); tw.tween_property(f, "modulate:a", 0.0, 0.5); tw.tween_callback(func(): f.queue_free(); Game.next())


## ---------- leaning in on a thing you're looking at
func _on_lean(at: Vector2, on: bool) -> void:
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_parallel()
	if on:
		var half := Vector2(ART_W, ART_H) / LEAN_ZOOM / 2
		var c := (at / 100.0 * Vector2(ART_W, ART_H)).clamp(half, Vector2(ART_W, ART_H) - half)
		t.tween_property(cam, "zoom", Vector2.ONE * LEAN_ZOOM, 0.55); t.tween_property(cam, "position", c, 0.55)
	else:
		t.tween_property(cam, "zoom", Vector2.ONE, 0.45); t.tween_property(cam, "position", Vector2(ART_W, ART_H) / 2, 0.45)
	marks.visible = not on; figs.visible = not on


## ---------- small marks: a faint dot on things you've found, ripples where you tapped nothing
func _ripple(p: Vector2) -> void:
	var r := {"p": p, "t": 0.0}; _ripples.append(r)
	var tw := create_tween(); tw.tween_method(func(v): r.t = v; marks.queue_redraw(), 0.0, 1.0, 0.5)
	tw.tween_callback(func(): _ripples.erase(r); marks.queue_redraw())


func _draw_marks() -> void:
	if Game.ST.is_empty(): return
	if Game.beat().get("type", "") == "examine":
		for d in Game.exam().get("details", []):
			var c := Vector2(d.x, d.y) / 100.0 * size
			if Game.exam_found(d): marks.draw_arc(c, 18, 0, TAU, 32, Color(1, 0.85, 0.4, 0.9), 3)
			elif _exam_miss >= 4: marks.draw_arc(c, d.r / 100.0 * size.x, 0, TAU, 32, Color(1, 1, 1, 0.35), 2)
	elif Game.node == "":
		var hidden: bool = Game.place().get("mode", "") == "explore"   # the shed: you find things yourself
		var font := ThemeDB.fallback_font
		for s in Game.spots_now():
			var c := Vector2(s.x, s.y) / 100.0 * size
			var found := Game.F.has("found_%s_%s" % [Game.loc, s.l])
			if hidden:
				if found: marks.draw_circle(c, 5, Color(1, 0.98, 0.92, 0.35))
				continue
			# a way out: always marked and named. Something to look at: a soft ring; its name once you've looked
			var exit: bool = s.kind == "=>"
			marks.draw_circle(c, 15, Color(1, 0.98, 0.92, 0.16))
			marks.draw_arc(c, 15, 0, TAU, 40, Color(1, 0.98, 0.92, 0.85), 2.5)
			if exit: marks.draw_arc(c, 6, 0, TAU, 16, Color(1, 0.98, 0.92, 0.85), 3)
			if exit or found:
				var label: String = s.l
				var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
				var at := Vector2(clampf(c.x - w / 2, 4, size.x - w - 4), c.y + 22)
				marks.draw_rect(Rect2(at - Vector2(10, 18), Vector2(w + 20, 28)), Color(0.08, 0.1, 0.14, 0.82))
				marks.draw_string(font, at + Vector2(0, 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.95, 0.92, 0.86))
	for r in _ripples:
		marks.draw_arc(r.p, 10 + 26 * r.t, 0, TAU, 32, Color(1, 1, 1, 0.8 * (1 - r.t)), 2.5)


## the slam: the whole picture jolts
func shake() -> void:
	var tw := create_tween()
	for i in 6: tw.tween_property(view, "position", Vector2(randf_range(-9, 9), randf_range(-7, 7)), 0.035)
	tw.tween_property(view, "position", Vector2.ZERO, 0.05)
