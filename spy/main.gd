extends Node3D
## Grey box: sneak close enough to two people to hear which locker the package is in.
## Far away their voices are quiet and muffled; too close and they notice you. A guard looks around the room.

const SPEED := 4.2
const ROOM := Vector2(18, 13)
const TABLE := Vector3(4.5, 0, -3.0)        # where the two sit and talk
const NOTICE := 1.5                          # closer than this to either of them and they notice you
const START := Vector3(0, 0, 5.3)
const CAM_OFF := Vector3(0, 17.0, 10.0)   # high up with a narrow lens, so walls stay upright
const GUARD_RANGE := 6.5
const GUARD_HALF := 0.61                     # half the width of the guard's view (35 degrees)
const NUM := ["일", "이", "삼", "사", "오"]
const LINES := [   # [who, clip, pause after it]
	["a", "f1", 0.6], ["b", "f2", 2.5],
	["a", "q1", 0.5], ["b", "a1", 0.6], ["a", "q2", 0.5], ["b", "num", 0.8], ["a", "ok", 5.0],
]

var test := false
var player: CharacterBody3D
var body_mesh: Node3D
var cam: Camera3D
var guard: Node3D
var talker_a: Node3D
var talker_b: Node3D
var bubbles := {}
var lockers: Array = []
var locker_mats: Array = []
var opened := {}
var voice: AudioStreamPlayer
var lowpass: AudioEffectLowPassFilter
var talk_bus := 0
var clips := {}
var answer := 1
var suspicion := 0.0
var state := "brief"          # brief, play, won, caught
var line_i := 0
var wait := 0.0
var speaking := ""
var noticed_cd := 0.0
var guard_angles := [0.5, 1.6, 2.6, 1.6]
var guard_i := 0
var guard_t := 0.0
var played := []              # clips played this round (the tester reads this)
# screen
var sus_bar: ProgressBar
var hear_label: Label
var toast: Label
var toast_t := 0.0
var open_btn: Button
var panel: PanelContainer
var panel_text: Label
var panel_btn: Button
var joy_draw: Control
var joy_center := Vector2.ZERO
var joy_vec := Vector2.ZERO
var joy_touch := -1
var near_locker := -1


func _ready() -> void:
	test = "--test" in OS.get_cmdline_user_args()
	randomize()
	_bus()
	for id in ["f1", "f2", "q1", "a1", "q2", "ok", "huh", "n1", "n2", "n3", "n4", "n5"]:
		clips[id] = load("res://voice/%s.mp3" % id)
	_world()
	_screen()
	_reset()
	if test: _run_test()


# ---------------------------------------------------------------- the room

func _bus() -> void:
	AudioServer.add_bus()
	talk_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(talk_bus, "Talk")
	lowpass = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(talk_bus, lowpass)
	voice = AudioStreamPlayer.new(); voice.bus = "Talk"; add_child(voice)
	voice.finished.connect(_line_done)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; return m


func _box(pos: Vector3, size: Vector3, c: Color, blocks_sight: bool) -> StaticBody3D:
	var b := StaticBody3D.new(); b.position = pos + Vector3(0, size.y / 2, 0)
	b.collision_layer = 1 | (2 if blocks_sight else 0)
	var s := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; s.shape = sh; b.add_child(s)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = _mat(c); b.add_child(mi)
	add_child(b); return b


func _person(pos: Vector3, c: Color) -> Node3D:
	var n := Node3D.new(); n.position = pos; add_child(n)
	var mi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.32; cm.height = 1.5
	mi.mesh = cm; mi.position.y = 0.75; mi.material_override = _mat(c); n.add_child(mi)
	var nose := MeshInstance3D.new(); var nb := BoxMesh.new(); nb.size = Vector3(0.2, 0.14, 0.3)
	nose.mesh = nb; nose.position = Vector3(0, 1.2, -0.32); nose.material_override = _mat(c.darkened(0.55)); n.add_child(nose)
	return n


func _bubble(on: Node3D) -> Label3D:
	var l := Label3D.new(); l.text = "• • •"; l.font_size = 72; l.pixel_size = 0.005; l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.position.y = 2.0; l.no_depth_test = true; l.visible = false
	on.add_child(l); return l


func _cone_mesh(r: float, half: float) -> ArrayMesh:
	var v := PackedVector3Array(); var n := 18
	for i in n:
		var a0 := -half + 2.0 * half * float(i) / n
		var a1 := -half + 2.0 * half * float(i + 1) / n
		v.append(Vector3.ZERO); v.append(Vector3(sin(a0) * r, 0, -cos(a0) * r)); v.append(Vector3(sin(a1) * r, 0, -cos(a1) * r))
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); return m


func _world() -> void:
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.08, 0.09, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.7, 0.7, 0.75); e.ambient_light_energy = 0.7
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-62), deg_to_rad(25), 0); sun.shadow_enabled = true; add_child(sun)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = ROOM; fl.mesh = pm; fl.material_override = _mat(Color(0.56, 0.5, 0.44)); add_child(fl)
	var fb := StaticBody3D.new(); var fs := CollisionShape3D.new(); fs.shape = WorldBoundaryShape3D.new(); fb.add_child(fs); add_child(fb)
	var hw := ROOM.x / 2; var hd := ROOM.y / 2; var wc := Color(0.36, 0.38, 0.44)
	_box(Vector3(0, 0, -hd), Vector3(ROOM.x, 1.6, 0.3), wc, true)
	_box(Vector3(0, 0, hd), Vector3(ROOM.x, 1.6, 0.3), wc, true)
	_box(Vector3(-hw, 0, 0), Vector3(0.3, 1.6, ROOM.y), wc, true)
	_box(Vector3(hw, 0, 0), Vector3(0.3, 1.6, ROOM.y), wc, true)
	_box(Vector3(-1.0, 0, -5.2), Vector3(5, 1.1, 0.9), Color(0.45, 0.3, 0.2), true)       # counter
	for p in [Vector3(-3, 0, 0), Vector3(0, 0, 2.5), Vector3(-4.5, 0, 3.6), Vector3(1.5, 0, -1.5), TABLE]:
		_box(p, Vector3(1.1, 0.75, 1.1), Color(0.72, 0.6, 0.45), false)                    # tables (you can be seen over them)
	for p in [Vector3(2.6, 0, -3.0), Vector3(4.5, 0, -0.6), Vector3(-1.5, 0, 1.0), Vector3(6.5, 0, 1.5), Vector3(-5.2, 0, 0.6)]:
		_box(p, Vector3(0.7, 2.2, 0.7), Color(0.85, 0.85, 0.82), true)                     # pillars: cover
	for i in 5:
		var l := _box(Vector3(-hw + 0.5, 0, -2.4 + i * 1.2), Vector3(0.6, 1.9, 1.0), Color(0.3, 0.45, 0.62), true)
		var lab := Label3D.new(); lab.text = str(i + 1); lab.font_size = 110; lab.pixel_size = 0.006; lab.outline_size = 24
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lab.position.y = 1.25; l.add_child(lab)
		lockers.append(l); locker_mats.append((l.get_child(1) as MeshInstance3D).material_override)
	talker_a = _person(TABLE + Vector3(0, 0, -0.9), Color(0.95, 0.55, 0.15))
	talker_b = _person(TABLE + Vector3(0, 0, 0.9), Color(0.98, 0.78, 0.3))
	talker_a.look_at(talker_b.position, Vector3.UP); talker_b.look_at(talker_a.position, Vector3.UP)
	bubbles = {"a": _bubble(talker_a), "b": _bubble(talker_b)}
	guard = _person(Vector3(-2.5, 0, 3.8), Color(0.85, 0.2, 0.2))
	var cone := MeshInstance3D.new(); cone.mesh = _cone_mesh(GUARD_RANGE, GUARD_HALF); cone.position.y = 0.03
	var cm := StandardMaterial3D.new(); cm.albedo_color = Color(1, 0.2, 0.15, 0.22); cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; cm.cull_mode = BaseMaterial3D.CULL_DISABLED; cone.material_override = cm
	guard.add_child(cone)
	player = CharacterBody3D.new(); player.collision_layer = 4; player.collision_mask = 1; add_child(player)
	var ps := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.32; cap.height = 1.5; ps.shape = cap; ps.position.y = 0.75; player.add_child(ps)
	body_mesh = _person(Vector3.ZERO, Color(0.25, 0.5, 0.95)); remove_child(body_mesh); player.add_child(body_mesh)
	cam = Camera3D.new(); cam.fov = 34; add_child(cam)


# ---------------------------------------------------------------- the screen

func _screen() -> void:
	var ui := CanvasLayer.new(); add_child(ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	joy_draw = Control.new(); joy_draw.set_anchors_preset(Control.PRESET_FULL_RECT); joy_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(joy_draw)
	joy_draw.draw.connect(func():
		if joy_touch == -1: return
		joy_draw.draw_circle(joy_center, 90, Color(1, 1, 1, 0.12))
		joy_draw.draw_circle(joy_center + joy_vec * 90, 38, Color(1, 1, 1, 0.45)))
	var top := HBoxContainer.new(); top.position = Vector2(24, 18); top.add_theme_constant_override("separation", 14); root.add_child(top)
	var sl := Label.new(); sl.text = "Suspicion"; sl.add_theme_font_size_override("font_size", 26); top.add_child(sl)
	sus_bar = ProgressBar.new(); sus_bar.max_value = 1.0; sus_bar.show_percentage = false; sus_bar.custom_minimum_size = Vector2(260, 30)
	var fill := StyleBoxFlat.new(); fill.bg_color = Color(0.9, 0.25, 0.2); sus_bar.add_theme_stylebox_override("fill", fill); top.add_child(sus_bar)
	hear_label = Label.new(); hear_label.add_theme_font_size_override("font_size", 28); hear_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hear_label.position = Vector2(-120, 18); hear_label.custom_minimum_size = Vector2(240, 0); hear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(hear_label)
	toast = Label.new(); toast.add_theme_font_size_override("font_size", 28); toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position = Vector2(-300, -150); toast.custom_minimum_size = Vector2(600, 0); toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(toast)
	open_btn = Button.new(); open_btn.add_theme_font_size_override("font_size", 34); open_btn.custom_minimum_size = Vector2(240, 110)
	open_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); open_btn.position = Vector2(-280, -150); open_btn.visible = false; root.add_child(open_btn)
	open_btn.pressed.connect(_open_near)
	panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.custom_minimum_size = Vector2(720, 0); panel.position = Vector2(-360, -170); root.add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 24); panel.add_child(box)
	panel_text = Label.new(); panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel_text.add_theme_font_size_override("font_size", 28); box.add_child(panel_text)
	panel_btn = Button.new(); panel_btn.add_theme_font_size_override("font_size", 32); panel_btn.custom_minimum_size = Vector2(0, 90); box.add_child(panel_btn)
	panel_btn.pressed.connect(_panel_pressed)


func _panel(text: String, btn: String) -> void:
	panel_text.text = text; panel_btn.text = btn; panel.visible = true


func _panel_pressed() -> void:
	if state == "brief": _start()
	else: _reset()


func _say(t: String) -> void:
	toast.text = t; toast_t = 2.5


# ---------------------------------------------------------------- a round

func _reset() -> void:
	answer = randi_range(1, 5); suspicion = 0.0; opened.clear(); played.clear()
	line_i = 0; wait = 1.0; speaking = ""; noticed_cd = 0.0; voice.stop()
	for b in bubbles.values(): b.visible = false
	player.position = START; player.velocity = Vector3.ZERO; body_mesh.rotation.y = 0
	cam.position = START + CAM_OFF; cam.look_at(START, Vector3.UP)
	for m in locker_mats: m.albedo_color = Color(0.3, 0.45, 0.62)
	guard_i = 0; guard_t = 0.0; guard.rotation.y = guard_angles[0]
	joy_touch = -1; joy_vec = Vector2.ZERO; joy_draw.queue_redraw(); open_btn.visible = false; toast.text = ""
	state = "brief"
	_panel("Two people at the corner table know which locker the package is in.\n\nGet close enough to hear the number. Don't let them, or the guard, notice you.\n\nLeft side of the screen: drag to move.", "Start")


func _start() -> void:
	state = "play"; panel.visible = false


func _end(kind: String) -> void:
	state = kind; voice.stop(); speaking = ""; joy_touch = -1; joy_vec = Vector2.ZERO; joy_draw.queue_redraw(); open_btn.visible = false
	for b in bubbles.values(): b.visible = false
	if kind == "won": _panel("You got it: 사물함 %s 번, locker %d.\n\nMission complete." % [NUM[answer - 1], answer], "Again")
	else: _panel("You've been noticed.\n\n(It was 사물함 %s 번, locker %d.)" % [NUM[answer - 1], answer], "Try again")


func _open_near() -> void:
	if near_locker >= 0: _open(near_locker)


func _open(i: int) -> void:
	if state != "play" or opened.has(i): return
	if i + 1 == answer: _end("won"); return
	opened[i] = true; locker_mats[i].albedo_color = Color(0.18, 0.22, 0.28)
	suspicion = minf(1.0, suspicion + 0.35); _say("Empty. And that was loud.")
	if suspicion >= 1.0: _end("caught")


func _say_next() -> void:
	var l: Array = LINES[line_i]
	var id: String = "n%d" % answer if l[1] == "num" else l[1]
	voice.stream = clips[id]; voice.play(); played.append(id)
	speaking = l[0]; bubbles[speaking].visible = true


func _line_done() -> void:
	for b in bubbles.values(): b.visible = false
	if voice.stream == clips["huh"]: speaking = ""; return
	if speaking == "": return
	wait = LINES[line_i][2]; line_i = (line_i + 1) % LINES.size(); speaking = ""


func _seen_by_guard() -> bool:
	var to := player.global_position - guard.global_position; to.y = 0
	if to.length() > GUARD_RANGE: return false
	var fwd := -guard.global_transform.basis.z; fwd.y = 0
	if fwd.normalized().angle_to(to.normalized()) > GUARD_HALF: return false
	var q := PhysicsRayQueryParameters3D.create(guard.global_position + Vector3(0, 1.4, 0), player.global_position + Vector3(0, 1.0, 0), 2)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _near_talkers() -> float:
	return minf(player.global_position.distance_to(talker_a.global_position), player.global_position.distance_to(talker_b.global_position))


func _physics_process(dt: float) -> void:
	if state != "play": return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dir.y += 1
	if joy_vec.length() > 0.12: dir = joy_vec
	dir = dir.limit_length(1.0)
	player.velocity = Vector3(dir.x, 0, dir.y) * SPEED
	player.move_and_slide(); player.position.y = 0
	if dir.length() > 0.12: body_mesh.rotation.y = atan2(-dir.x, -dir.y)
	# the guard looks around
	guard_t += dt
	if guard_t > 3.2:
		guard_t = 0.0; guard_i = (guard_i + 1) % guard_angles.size()
		create_tween().tween_property(guard, "rotation:y", guard_angles[guard_i], 0.8).set_trans(Tween.TRANS_SINE)
	# being noticed
	var d := _near_talkers()
	var watched := false
	if _seen_by_guard(): suspicion += dt * 0.5; watched = true
	noticed_cd -= dt
	if d < NOTICE:
		suspicion += dt * 0.35; watched = true
		if noticed_cd <= 0.0:
			noticed_cd = 5.0; suspicion += 0.25
			for b in bubbles.values(): b.visible = false
			speaking = ""; voice.stream = clips["huh"]; voice.play(); played.append("huh")
			line_i = 0; wait = 3.0; bubbles["b"].visible = true
	if not watched: suspicion = maxf(0.0, suspicion - dt * 0.1)
	if suspicion >= 1.0: suspicion = 1.0; _end("caught")
	# the nearest locker
	near_locker = -1
	for i in lockers.size():
		var lp: Vector3 = lockers[i].global_position
		if Vector2(lp.x - player.position.x, lp.z - player.position.z).length() < 1.25 and not opened.has(i): near_locker = i
	open_btn.visible = near_locker >= 0
	if near_locker >= 0: open_btn.text = "Open %d" % (near_locker + 1)


func _process(dt: float) -> void:
	var want := player.position + CAM_OFF
	cam.position = cam.position.lerp(want, 1.0 - exp(-6.0 * dt)); cam.look_at(cam.position - CAM_OFF, Vector3.UP)
	sus_bar.value = suspicion
	toast_t -= dt
	if toast_t <= 0.0: toast.text = ""
	if state != "play": return
	# what you can hear from here
	var d := _near_talkers()
	var k := clampf((d - 2.4) / 3.5, 0.0, 1.0)
	lowpass.cutoff_hz = lerpf(9000.0, 350.0, k)
	AudioServer.set_bus_volume_db(talk_bus, lerpf(0.0, -16.0, k) - 24.0 * clampf((d - 6.0) / 3.0, 0.0, 1.0))
	hear_label.text = "Hearing: clear" if k < 0.25 else ("Hearing: muffled" if d < 7.5 else "Too far to hear")
	if speaking == "" and not voice.playing:
		wait -= dt
		if wait <= 0.0: _say_next()


func _input(ev: InputEvent) -> void:
	if state != "play": return
	if ev is InputEventScreenTouch:
		if ev.pressed and joy_touch == -1 and ev.position.x < get_viewport().get_visible_rect().size.x * 0.5:
			joy_touch = ev.index; joy_center = ev.position; joy_vec = Vector2.ZERO
		elif not ev.pressed and ev.index == joy_touch:
			joy_touch = -1; joy_vec = Vector2.ZERO
		joy_draw.queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == joy_touch:
		joy_vec = ((ev.position - joy_center) / 90.0).limit_length(1.0); joy_draw.queue_redraw()


# ---------------------------------------------------------------- the tester (godot -- --test)

var _fails := 0
func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok: _fails += 1


func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://").path_join("../build/spy")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(nm + ".png"))


func _secs(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _put(p: Vector3) -> void:
	player.position = p; cam.position = p + CAM_OFF
	await get_tree().physics_frame; await get_tree().physics_frame


func _run_test() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().position = Vector2i(-3000, 60)   # out of the way
	await _secs(0.5); await _shot("1_brief")
	_check(panel.visible and state == "brief", "the briefing shows first")
	_panel_pressed(); _check(state == "play" and not panel.visible, "Start starts")
	# the hiding spot behind the pillar next to them
	await _put(Vector3(1.75, 0, -3.0)); await _secs(0.3)
	_check(lowpass.cutoff_hz > 6000.0, "behind the pillar near the table it's clear (%d Hz)" % lowpass.cutoff_hz)
	_check(not _seen_by_guard(), "the guard can't see that spot")
	var got := false
	for i in 90:
		await _secs(0.5)
		if ("n%d" % answer) in played: got = true; break
	_check(got, "they say the locker number (heard: %s)" % ", ".join(played))
	_check(state == "play" and suspicion < 0.3, "nobody noticed (suspicion %.2f)" % suspicion)
	await _shot("2_listening")
	await _put(Vector3(-6.5, 0, 5.2)); await _secs(0.3)
	_check(lowpass.cutoff_hz < 1500.0 and AudioServer.get_bus_volume_db(talk_bus) < -20.0, "across the room it's muffled and quiet")
	# walking right up to them
	suspicion = 0.0; noticed_cd = 0.0
	await _put(Vector3(5.5, 0, -3.0)); await _secs(0.4)
	_check("huh" in played and suspicion > 0.2, "standing next to them, they notice (suspicion %.2f)" % suspicion)
	await _shot("3_noticed")
	# lockers
	suspicion = 0.0
	var wrong := answer % 5      # a different locker (index)
	await _put(lockers[wrong].global_position + Vector3(1.0, 0, 0)); await _secs(0.2)
	_check(open_btn.visible and open_btn.text == "Open %d" % (wrong + 1), "next to a locker there's an Open button")
	_open(wrong); _check(state == "play" and suspicion >= 0.35, "the wrong locker is loud")
	await _put(lockers[answer - 1].global_position + Vector3(1.0, 0, 0)); await _secs(0.2)
	await _shot("4_locker")
	_open(answer - 1); _check(state == "won" and panel.visible, "the right locker wins")
	await _shot("5_won")
	# the guard
	_panel_pressed(); _panel_pressed()
	await _secs(0.2)
	var f := -guard.global_transform.basis.z; f.y = 0
	await _put(guard.position + f.normalized() * 2.5)
	await _secs(3.0)
	_check(state == "caught", "standing in front of the guard gets you caught")
	await _shot("6_caught")
	# the thumb stick
	_panel_pressed(); _panel_pressed(); await _secs(0.2)
	var before := player.position
	var t := InputEventScreenTouch.new(); t.index = 0; t.position = Vector2(200, 500); t.pressed = true; Input.parse_input_event(t)
	var dr := InputEventScreenDrag.new(); dr.index = 0; dr.position = Vector2(290, 500); Input.parse_input_event(dr)
	await _secs(0.6)
	_check(player.position.x > before.x + 1.0, "dragging on the left moves you (%.1f m)" % (player.position.x - before.x))
	await _shot("7_stick")
	t.pressed = false; Input.parse_input_event(t)
	print("DONE %d failed" % _fails)
	get_tree().quit(1 if _fails else 0)
