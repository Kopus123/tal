extends Node3D
## Grey box 2: a subway station. Two people whisper which coin locker the package is in.
## Far away their voices are quiet and muffled, and the number is whispered, so you have to get close.
## They glance around now and then; a guard walks a route. Lockers are labelled in Hangul.

const SPEED := 4.2
const ROOM := Vector2(18, 13)
const START := Vector3(0, 0, 5.3)
const CAM_OFF := Vector3(0, 17.0, 10.0)   # high up with a narrow lens, so walls stay upright
const GUARD_RANGE := 6.0
const GUARD_HALF := 0.61                   # half the width of the guard's view (35 degrees)
const GUARD_SPEED := 1.7
const TALK_RANGE := 4.5
const TALK_HALF := 0.8
const NOTICE := 1.3                        # closer than this to either of them and they notice you, cover or not
const NUM := ["일", "이", "삼", "사", "오"]
const SECRET := ["a1", "q2", "num"]        # said quietly
const LINES := [   # [who, clip, pause after it]
	["a", "f1", 0.6], ["b", "f2", 2.5],
	["a", "q1", 0.5], ["b", "a1", 0.6], ["a", "q2", 0.5], ["b", "num", 0.8], ["a", "ok", 5.0],
]
const ROUTE := [   # [where the guard walks to, how long he stands there looking around]
	[Vector3(-6.5, 0, 4.2), 1.5], [Vector3(-6.5, 0, -3.8), 2.5], [Vector3(1.5, 0, -1.6), 0.0],
	[Vector3(7.5, 0, 0.5), 2.0], [Vector3(2.0, 0, 4.4), 0.0],
]

var test := false
var freeze_guard := false
var player: CharacterBody3D
var body_mesh: Node3D
var cam: Camera3D
var guard: Node3D
var talkers := {}
var cones := {}
var bubbles := {}
var lockers: Array = []
var locker_mats: Array = []
var opened := {}
var wrongs := 0
var voice: AudioStreamPlayer
var lowpass: AudioEffectLowPassFilter
var talk_bus := 0
var clips := {}
var answer := 1
var suspicion := 0.0
var state := "play"          # play, won, caught
var line_i := 0
var wait := 0.0
var speaking := ""
var looked := false
var noticed_cd := 0.0
var t_look := {"a": 0.0, "b": 0.0}
var t_next := 4.0
var g_i := 0
var g_target := Vector3.ZERO
var g_pause := 0.0
var g_base := 0.0
var investigating := false
var played := []              # clips played this round (the tester reads these)
var num_cut := 0.0            # how clear the number was where you stood
var moved := false
# screen
var sus_bar: ProgressBar
var goal: Label
var hear_label: Label
var hint: Label
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


# ---------------------------------------------------------------- the station

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


func _cone(on: Node3D, r: float, half: float, c: Color) -> MeshInstance3D:
	var v := PackedVector3Array(); var n := 18
	for i in n:
		var a0 := -half + 2.0 * half * float(i) / n
		var a1 := -half + 2.0 * half * float(i + 1) / n
		v.append(Vector3.ZERO); v.append(Vector3(sin(a0) * r, 0, -cos(a0) * r)); v.append(Vector3(sin(a1) * r, 0, -cos(a1) * r))
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new(); mi.mesh = m; mi.position.y = 0.03
	var mat := StandardMaterial3D.new(); mat.albedo_color = c; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mi.material_override = mat
	on.add_child(mi); return mi


func _world() -> void:
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.08, 0.09, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.7, 0.7, 0.75); e.ambient_light_energy = 0.7
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-62), deg_to_rad(25), 0); sun.shadow_enabled = true; add_child(sun)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = ROOM; fl.mesh = pm; fl.material_override = _mat(Color(0.62, 0.63, 0.62)); add_child(fl)
	var fb := StaticBody3D.new(); var fs := CollisionShape3D.new(); fs.shape = WorldBoundaryShape3D.new(); fb.add_child(fs); add_child(fb)
	var hw := ROOM.x / 2; var hd := ROOM.y / 2; var wc := Color(0.36, 0.38, 0.44)
	_box(Vector3(0, 0, -hd), Vector3(ROOM.x, 1.6, 0.3), wc, true)
	_box(Vector3(0, 0, hd), Vector3(ROOM.x, 1.6, 0.3), wc, true)
	_box(Vector3(-hw, 0, 0), Vector3(0.3, 1.6, ROOM.y), wc, true)
	_box(Vector3(hw, 0, 0), Vector3(0.3, 1.6, ROOM.y), wc, true)
	var sign := Label3D.new(); sign.text = "지하철"; sign.font_size = 120; sign.pixel_size = 0.008; sign.outline_size = 20
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED; sign.position = Vector3(0, 2.4, -hd); add_child(sign)
	for p in [Vector3(-1.5, 0, 0.8), Vector3(3.0, 0, 2.2), Vector3(5.5, 0, -4.7)]:
		_box(p, Vector3(2.2, 0.5, 0.7), Color(0.55, 0.42, 0.3), false)                     # benches (you can be seen over them)
	for p in [Vector3(-3.0, 0, 2.6), Vector3(0.0, 0, -3.8), Vector3(-4.8, 0, -1.5)]:
		_box(p, Vector3(0.7, 2.2, 0.7), Color(0.85, 0.85, 0.82), true)                     # pillars: cover
	_box(Vector3(3.7, 0, -3.4), Vector3(0.6, 2.2, 0.6), Color(0.85, 0.85, 0.82), true)    # the pillar next to them
	_box(Vector3(6.2, 0, -2.4), Vector3(0.9, 1.8, 0.6), Color(0.3, 0.6, 0.45), true)      # a ticket machine
	for i in 5:   # coin lockers along the left wall, labelled in Hangul
		var l := _box(Vector3(-hw + 0.5, 0, -2.4 + i * 1.2), Vector3(0.6, 1.9, 1.0), Color(0.3, 0.45, 0.62), true)
		var ko := Label3D.new(); ko.text = NUM[i]; ko.font_size = 120; ko.pixel_size = 0.006; ko.outline_size = 24
		ko.billboard = BaseMaterial3D.BILLBOARD_ENABLED; ko.position.y = 1.35; l.add_child(ko)
		var dg := Label3D.new(); dg.text = str(i + 1); dg.font_size = 48; dg.pixel_size = 0.006; dg.outline_size = 12; dg.modulate = Color(1, 1, 1, 0.7)
		dg.billboard = BaseMaterial3D.BILLBOARD_ENABLED; dg.position = Vector3(0.75, 1.35, 0); dg.no_depth_test = true; l.add_child(dg)
		lockers.append(l); locker_mats.append((l.get_child(1) as MeshInstance3D).material_override)
	talkers = {"a": _person(Vector3(4.8, 0, -3.4), Color(0.95, 0.55, 0.15)), "b": _person(Vector3(6.2, 0, -3.4), Color(0.98, 0.78, 0.3))}
	for k in talkers:
		talkers[k].rotation.y = _face_partner(k)
		bubbles[k] = _bubble(talkers[k])
		cones[k] = _cone(talkers[k], TALK_RANGE, TALK_HALF, Color(1, 0.85, 0.2, 0.25)); cones[k].visible = false
	guard = _person(ROUTE[0][0], Color(0.85, 0.2, 0.2))
	_cone(guard, GUARD_RANGE, GUARD_HALF, Color(1, 0.2, 0.15, 0.22))
	player = CharacterBody3D.new(); player.collision_layer = 4; player.collision_mask = 1; add_child(player)
	var ps := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.32; cap.height = 1.5; ps.shape = cap; ps.position.y = 0.75; player.add_child(ps)
	body_mesh = _person(Vector3.ZERO, Color(0.25, 0.5, 0.95)); remove_child(body_mesh); player.add_child(body_mesh)
	cam = Camera3D.new(); cam.fov = 34; add_child(cam)


# ---------------------------------------------------------------- the screen

func _label(size: int) -> Label:
	var l := Label.new(); l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 8); l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8)); return l


func _screen() -> void:
	var ui := CanvasLayer.new(); add_child(ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	joy_draw = Control.new(); joy_draw.set_anchors_preset(Control.PRESET_FULL_RECT); joy_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(joy_draw)
	joy_draw.draw.connect(func():
		if joy_touch == -1: return
		joy_draw.draw_circle(joy_center, 90, Color(1, 1, 1, 0.12))
		joy_draw.draw_circle(joy_center + joy_vec * 90, 38, Color(1, 1, 1, 0.45)))
	var top := HBoxContainer.new(); top.position = Vector2(24, 18); top.add_theme_constant_override("separation", 14); root.add_child(top)
	var sl := _label(26); sl.text = "Suspicion"; top.add_child(sl)
	sus_bar = ProgressBar.new(); sus_bar.max_value = 1.0; sus_bar.show_percentage = false; sus_bar.custom_minimum_size = Vector2(240, 30)
	var fill := StyleBoxFlat.new(); fill.bg_color = Color(0.9, 0.25, 0.2); sus_bar.add_theme_stylebox_override("fill", fill); top.add_child(sus_bar)
	goal = _label(26); goal.position = Vector2(24, 60); goal.text = "Goal: find out which locker"; root.add_child(goal)
	hear_label = _label(28); hear_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hear_label.position = Vector2(-200, 18); hear_label.custom_minimum_size = Vector2(400, 0); hear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(hear_label)
	toast = _label(30); toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position = Vector2(-380, -150); toast.custom_minimum_size = Vector2(760, 0); toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(toast)
	hint = _label(26); hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); hint.position = Vector2(40, -70); hint.text = "Drag here to move"; hint.modulate = Color(1, 1, 1, 0.6); root.add_child(hint)
	open_btn = Button.new(); open_btn.add_theme_font_size_override("font_size", 34); open_btn.custom_minimum_size = Vector2(240, 110)
	open_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); open_btn.position = Vector2(-280, -150); open_btn.visible = false; root.add_child(open_btn)
	open_btn.pressed.connect(_open_near)
	panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.custom_minimum_size = Vector2(620, 0); panel.position = Vector2(-310, -130); root.add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 24); panel.add_child(box)
	panel_text = _label(30); panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(panel_text)
	panel_btn = Button.new(); panel_btn.add_theme_font_size_override("font_size", 32); panel_btn.custom_minimum_size = Vector2(0, 90); box.add_child(panel_btn)
	panel_btn.pressed.connect(_reset)


func _panel(text: String, btn: String) -> void:
	panel_text.text = text; panel_btn.text = btn; panel.visible = true


func _say(t: String, secs := 2.5) -> void:
	toast.text = t; toast_t = secs


# ---------------------------------------------------------------- a round

func _reset() -> void:
	answer = randi_range(1, 5); suspicion = 0.0; opened.clear(); played.clear(); wrongs = 0; num_cut = 0.0
	line_i = 0; wait = 2.0; speaking = ""; looked = false; noticed_cd = 0.0; voice.stop()
	for k in talkers:
		bubbles[k].visible = false; cones[k].visible = false; t_look[k] = 0.0; talkers[k].rotation.y = _face_partner(k)
	t_next = 5.0
	player.position = START; player.velocity = Vector3.ZERO; body_mesh.rotation.y = 0
	cam.position = START + CAM_OFF; cam.look_at(START, Vector3.UP)
	for m in locker_mats: m.albedo_color = Color(0.3, 0.45, 0.62)
	guard.position = ROUTE[0][0]; g_i = 1; g_target = ROUTE[1][0]; g_pause = 0.0; investigating = false
	var gd: Vector3 = g_target - guard.position; guard.rotation.y = atan2(-gd.x, -gd.z)
	joy_touch = -1; joy_vec = Vector2.ZERO; joy_draw.queue_redraw(); open_btn.visible = false
	panel.visible = false; state = "play"
	_say("Handler: those two know which locker it's in. Listen in.", 6.0)


func _end(kind: String) -> void:
	state = kind; voice.stop(); speaking = ""; joy_touch = -1; joy_vec = Vector2.ZERO; joy_draw.queue_redraw(); open_btn.visible = false
	for k in talkers: bubbles[k].visible = false
	toast.text = ""
	if kind == "won": _panel("Got it: %s 번.\nMission complete." % NUM[answer - 1], "Again")
	else: _panel("You've been noticed.\n(It was %s 번, locker %d.)" % [NUM[answer - 1], answer], "Try again")


func _open_near() -> void:
	if near_locker >= 0: _open(near_locker)


func _open(i: int) -> void:
	if state != "play" or opened.has(i): return
	if i + 1 == answer: _end("won"); return
	opened[i] = true; locker_mats[i].albedo_color = Color(0.18, 0.22, 0.28); wrongs += 1
	if wrongs == 1:
		suspicion += 0.05; _say("Empty.")
	elif wrongs == 2:
		suspicion += 0.25; _say("Empty. People are starting to look at you.")
	else:
		suspicion += 0.3; _say("The guard heard that. He's coming.")
		investigating = true; g_pause = 0.0; g_target = Vector3(player.position.x + 1.4, 0, player.position.z)
	if suspicion >= 1.0: suspicion = 1.0; _end("caught")


# ---------------------------------------------------------------- the two talkers

func _face_partner(k: String) -> float:
	var d: Vector3 = talkers["b" if k == "a" else "a"].position - talkers[k].position
	return atan2(-d.x, -d.z)


func _turn(k: String, ang: float) -> void:
	var from: float = talkers[k].rotation.y
	create_tween().tween_method(func(v: float): talkers[k].rotation.y = lerp_angle(from, ang, v), 0.0, 1.0, 0.3)


func _glance(k: String, at := INF, secs := 1.8) -> void:
	var ang: float = at
	if ang == INF: ang = _face_partner(k) + (1.0 if randf() < 0.5 else -1.0) * randf_range(1.0, 2.6)
	_turn(k, ang); t_look[k] = secs; cones[k].visible = true


func _say_next() -> void:
	var l: Array = LINES[line_i]
	if l[1] == "q1" and not looked:   # before the secret part, they both check nobody's around
		looked = true; _glance("a"); _glance("b"); wait = 2.0; return
	looked = false
	var id: String = "n%d" % answer if l[1] == "num" else l[1]
	voice.stream = clips[id]; voice.play(); played.append(id)
	if l[1] == "num": num_cut = lowpass.cutoff_hz
	speaking = l[0]; bubbles[speaking].visible = true


func _line_done() -> void:
	for b in bubbles.values(): b.visible = false
	if voice.stream == clips["huh"]: speaking = ""; return
	if speaking == "": return
	wait = LINES[line_i][2]; line_i = (line_i + 1) % LINES.size(); speaking = ""


func _sees(eye: Node3D, rng: float, half: float) -> bool:
	var to := player.global_position - eye.global_position; to.y = 0
	if to.length() > rng: return false
	var fwd := -eye.global_transform.basis.z; fwd.y = 0
	if fwd.normalized().angle_to(to.normalized()) > half: return false
	var q := PhysicsRayQueryParameters3D.create(eye.global_position + Vector3(0, 1.4, 0), player.global_position + Vector3(0, 1.0, 0), 2)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _near_talkers() -> float:
	return minf(player.global_position.distance_to(talkers.a.global_position), player.global_position.distance_to(talkers.b.global_position))


## 0 = clear, 1 = muffled. Whispered lines only carry a short way.
func _clarity(d: float, secret: bool) -> float:
	return clampf((d - 1.7) / 1.4, 0.0, 1.0) if secret else clampf((d - 2.4) / 3.5, 0.0, 1.0)


# ---------------------------------------------------------------- every frame

func _guard(dt: float) -> void:
	if g_pause > 0.0:
		g_pause -= dt; guard.rotation.y = g_base + sin(g_pause * 1.8) * 1.1
		if g_pause <= 0.0 and investigating:
			investigating = false; g_target = ROUTE[g_i][0]
		return
	var to := g_target - guard.position; to.y = 0
	if to.length() < 0.1:
		g_base = guard.rotation.y
		if investigating:
			g_pause = 3.0; return
		g_pause = ROUTE[g_i][1]; g_i = (g_i + 1) % ROUTE.size(); g_target = ROUTE[g_i][0]
		return
	guard.position += to.normalized() * minf(to.length(), GUARD_SPEED * (1.7 if investigating else 1.0) * dt)
	guard.rotation.y = lerp_angle(guard.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * dt))


func _physics_process(dt: float) -> void:
	if state != "play": return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dir.y += 1
	if joy_vec.length() > 0.12: dir = joy_vec
	dir = dir.limit_length(1.0)
	if dir.length() > 0.12 and not moved:
		moved = true; hint.visible = false
	player.velocity = Vector3(dir.x, 0, dir.y) * SPEED
	player.move_and_slide(); player.position.y = 0
	if dir.length() > 0.12: body_mesh.rotation.y = atan2(-dir.x, -dir.y)
	if not freeze_guard: _guard(dt)
	# the talkers glance around now and then
	t_next -= dt
	for k in talkers:
		if t_look[k] > 0.0:
			t_look[k] -= dt
			if t_look[k] <= 0.0:
				_turn(k, _face_partner(k)); cones[k].visible = false
	if t_next <= 0.0 and t_look.a <= 0.0 and t_look.b <= 0.0:
		_glance(["a", "b"].pick_random()); t_next = randf_range(3.5, 7.0)
	# being noticed
	var watched := false
	var gdist := player.position.distance_to(guard.position)
	if _sees(guard, GUARD_RANGE, GUARD_HALF) or gdist < 1.0:   # the closer he is, the quicker he's sure
		suspicion += dt * (0.5 + 1.4 * (1.0 - gdist / GUARD_RANGE)); watched = true
	var spotted := _near_talkers() < NOTICE
	for k in talkers:
		if t_look[k] > 0.0 and _sees(talkers[k], TALK_RANGE, TALK_HALF): spotted = true
	noticed_cd -= dt
	if spotted:
		suspicion += dt * 0.4; watched = true
		if noticed_cd <= 0.0:   # they stop, stare at you, and start over
			noticed_cd = 5.0; suspicion += 0.2
			for k in talkers:
				bubbles[k].visible = false
				var d: Vector3 = player.position - talkers[k].position
				_glance(k, atan2(-d.x, -d.z), 2.5)
			speaking = ""; voice.stream = clips["huh"]; voice.play(); played.append("huh")
			line_i = 0; looked = false; wait = 3.0; bubbles["b"].visible = true
	if not watched: suspicion = maxf(0.0, suspicion - dt * 0.1)
	if suspicion >= 1.0:
		suspicion = 1.0; _end("caught"); return
	near_locker = -1
	for i in lockers.size():
		var lp: Vector3 = lockers[i].global_position
		if Vector2(lp.x - player.position.x, lp.z - player.position.z).length() < 1.25 and not opened.has(i): near_locker = i
	open_btn.visible = near_locker >= 0
	if near_locker >= 0: open_btn.text = "Open %s" % NUM[near_locker]


func _process(dt: float) -> void:
	cam.position = cam.position.lerp(player.position + CAM_OFF, 1.0 - exp(-6.0 * dt)); cam.look_at(cam.position - CAM_OFF, Vector3.UP)
	sus_bar.value = suspicion
	toast_t -= dt
	if toast_t <= 0.0: toast.text = ""
	if state != "play": return
	var d := _near_talkers()
	var secret: bool = speaking != "" and LINES[line_i][1] in SECRET
	var k := _clarity(d, secret)
	lowpass.cutoff_hz = lerpf(9000.0, 350.0, k)
	AudioServer.set_bus_volume_db(talk_bus, lerpf(0.0, -16.0, k) - 24.0 * clampf((d - 6.0) / 3.0, 0.0, 1.0))
	if d > 7.5: hear_label.text = "Too far to hear"
	elif secret: hear_label.text = "They're whispering: " + ("clear" if k < 0.25 else "can't make it out")
	else: hear_label.text = "Hearing: " + ("clear" if k < 0.25 else "muffled")
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


func _at(k: String) -> float:
	var d: Vector3 = player.position - talkers[k].position
	return atan2(-d.x, -d.z)


func _run_test() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().position = Vector2i(-3000, 60)   # out of the way
	await _secs(0.5); await _shot("1_start")
	_check(state == "play" and not panel.visible and toast.text.begins_with("Handler"), "it starts right away with one line from the handler")
	_check(_clarity(3.0, true) > 0.8 and _clarity(3.0, false) < 0.3, "3 m away: small talk is clear, the whisper isn't")
	# behind the ticket machine, next to them
	freeze_guard = true; guard.position = ROUTE[0][0]
	await _put(Vector3(6.2, 0, -1.75))
	_glance("a", _at("a")); _glance("b", _at("b")); await _secs(0.5)
	_check(state == "play" and not ("huh" in played), "behind the ticket machine they can't see you, even looking your way")
	var got := false
	for i in 90:
		await _secs(0.5)
		if ("n%d" % answer) in played:
			got = true; break
	_check(got, "they say the number (heard: %s)" % ", ".join(played))
	_check(num_cut > 6000.0, "from behind the machine the whisper is clear (%d Hz)" % num_cut)
	_check(state == "play" and suspicion < 0.3, "nobody noticed (suspicion %.2f)" % suspicion)
	await _shot("2_listening")
	# out in the open while one of them looks over
	suspicion = 0.0; noticed_cd = 0.0
	await _put(Vector3(3.3, 0, -1.5))
	_glance("a", _at("a")); await _secs(0.6)
	_check("huh" in played and suspicion > 0.2, "in the open, when they look over, they notice (suspicion %.2f)" % suspicion)
	await _shot("3_noticed")
	# lockers: one wrong is normal, two looks odd, three brings the guard
	suspicion = 0.0; guard.position = ROUTE[3][0]   # (the guard is kept out of this part)
	var wrong := []
	for i in 5:
		if i + 1 != answer: wrong.append(i)
	await _put(lockers[wrong[0]].global_position + Vector3(1.0, 0, 0)); await _secs(0.2)
	_check(open_btn.visible and open_btn.text == "Open %s" % NUM[wrong[0]], "next to a locker the button says its Hangul number")
	await _shot("4_locker")
	_open(wrong[0]); _check(state == "play" and suspicion < 0.15 and not investigating, "one wrong locker is fine")
	_open(wrong[1]); _check(state == "play" and suspicion > 0.25 and not investigating, "a second one draws looks")
	freeze_guard = false
	_open(wrong[2]); _check(investigating, "a third one brings the guard over")
	_open(answer - 1); _check(state == "won" and panel.visible, "the right locker wins")
	await _shot("5_won")
	# the guard's route
	_reset(); await _secs(0.2)
	var g0 := guard.position
	await _secs(1.0)
	_check(guard.position.distance_to(g0) > 1.0, "the guard walks his route")
	await _put(guard.position + (-guard.global_transform.basis.z * Vector3(1, 0, 1)).normalized() * 2.5)
	await _secs(3.0)
	_check(state == "caught", "walking into the guard's view gets you caught")
	await _shot("6_caught")
	# the thumb stick
	_reset(); await _secs(0.2)
	var before := player.position
	var t := InputEventScreenTouch.new(); t.index = 0; t.position = Vector2(200, 500); t.pressed = true; Input.parse_input_event(t)
	var dr := InputEventScreenDrag.new(); dr.index = 0; dr.position = Vector2(290, 500); Input.parse_input_event(dr)
	await _secs(0.6)
	_check(player.position.x > before.x + 1.0 and not hint.visible, "dragging on the left moves you, and the hint goes away")
	t.pressed = false; Input.parse_input_event(t)
	print("DONE %d failed" % _fails)
	get_tree().quit(1 if _fails else 0)
