extends Node3D
## Grey box 3: a subway station. Two people whisper which coin locker the package is in.
## Every round is shuffled: what they chat about, how and when they say the number (sometimes they correct
## themselves), where they stand, the guard's route. Commuters walk through: they're cover you can walk behind.
## Standing around near the two looks suspicious unless you're acting natural (ticket machine, drinks, map).

const SPEED := 4.2
const ROOM := Vector2(18, 13)
const START := Vector3(0, 0, 5.3)
const CAM_OFF := Vector3(0, 17.0, 10.0)   # high up with a narrow lens, so walls stay upright
const GUARD_RANGE := 6.0
const GUARD_HALF := 0.61                   # half the width of the guard's view (35 degrees)
const TALK_RANGE := 4.5
const TALK_HALF := 0.8
const NOTICE := 1.3                        # closer than this to either of them and they notice you, cover or not
const NUM := ["일", "이", "삼", "사", "오"]
const SPOTS := [   # where the two can stand
	[Vector3(4.8, 0, -3.4), Vector3(6.2, 0, -3.4)],
	[Vector3(-4.6, 0, 3.4), Vector3(-3.4, 0, 3.4)],
	[Vector3(0.8, 0, -4.2), Vector3(2.2, 0, -4.2)],
]
const GUARD_POINTS := [
	Vector3(-6.5, 0, 4.2), Vector3(-6.5, 0, -3.8), Vector3(1.5, 0, -1.6), Vector3(7.5, 0, 0.5),
	Vector3(2.0, 0, 4.4), Vector3(-2.0, 0, -4.8), Vector3(5.0, 0, 4.6), Vector3(-1.5, 0, 2.0),
]
const EXITS := [Vector3(-8.6, 0, 5.2), Vector3(8.6, 0, -1.0), Vector3(-5.0, 0, 6.1), Vector3(5.0, 0, 6.1), Vector3(-4.0, 0, -6.1), Vector3(4.0, 0, -6.1)]
const NATURAL_FOR := 12.0                  # how long one thing looks natural before it looks odd too

var test := false
var freeze_guard := false
var freeze_talkers := false
var no_commuters := false
var player: CharacterBody3D
var body_mesh: Node3D
var cam: Camera3D
var guard: Node3D
var talkers := {}
var cones := {}
var bubbles := {}
var lockers: Array = []
var locker_mats: Array = []
var props: Array = []           # [position, what you're doing there]
var commuters: Array = []       # {body, path, i, speed}
var commuter_t := 0.0
var opened := {}
var wrongs := 0
var voice: AudioStreamPlayer
var lowpass: AudioEffectLowPassFilter
var talk_bus := 0
var clips := {}
var answer := 1
var suspicion := 0.0
var state := "play"          # play, won, caught
var talk: Array = []         # this loop's lines: [who, clip, pause after, whispered]
var line_i := 0
var wait := 0.0
var speaking := ""
var noticed_cd := 0.0
var t_look := {"a": 0.0, "b": 0.0}
var t_next := 4.0
var spot := 0
var walking := false
var route: Array = []
var g_i := 0
var g_target := Vector3.ZERO
var g_pause := 0.0
var g_base := 0.0
var g_speed := 1.7
var investigating := false
var loiter_t := 0.0
var natural_t := 0.0
var natural_what := ""
var played := []              # clips played this round (the tester reads these)
var num_cut := 0.0            # how clear the number was where you stood
var moved := false
# screen
var sus_bar: ProgressBar
var goal: Label
var doing: Label
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
	var ids := ["ans", "q2", "ok", "ok2", "huh", "lead_0", "lead_1", "lead_2"]
	for i in 5: ids += ["st_%da" % i, "st_%db" % i]
	for n in range(1, 6):
		for p in 3: ids.append("num_p%d_%d" % [p, n])
		for w in range(1, 6):
			if w != n: ids.append("trap_%d_%d" % [w, n])
	for id in ids: clips[id] = load("res://voice/%s.mp3" % id)
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


func _sign(text: String, size: int, pos: Vector3, parent: Node3D) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font_size = size; l.pixel_size = 0.006; l.outline_size = size / 5
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.position = pos; parent.add_child(l); return l


func _bubble(on: Node3D) -> Label3D:
	var l := _sign("• • •", 72, Vector3(0, 2.0, 0), on); l.pixel_size = 0.005; l.no_depth_test = true; l.visible = false; return l


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
	_sign("지하철", 120, Vector3(-3, 2.4, -hd), self).pixel_size = 0.008
	for p in [Vector3(-1.5, 0, 0.8), Vector3(3.0, 0, 2.2), Vector3(5.5, 0, -4.7)]:
		_box(p, Vector3(2.2, 0.5, 0.7), Color(0.55, 0.42, 0.3), false)                     # benches (you can be seen over them)
	for p in [Vector3(-3.0, 0, 2.6), Vector3(0.0, 0, -3.8), Vector3(-4.8, 0, -1.5)]:
		_box(p, Vector3(0.7, 2.2, 0.7), Color(0.85, 0.85, 0.82), true)                     # pillars: cover
	_box(Vector3(3.7, 0, -3.4), Vector3(0.6, 2.2, 0.6), Color(0.85, 0.85, 0.82), true)
	# places where standing still looks normal (for a while)
	_box(Vector3(6.2, 0, -2.4), Vector3(0.9, 1.8, 0.6), Color(0.3, 0.6, 0.45), true)
	_sign("표", 70, Vector3(6.2, 2.1, -2.4), self); props.append([Vector3(6.2, 0, -2.4), "buying a ticket"])
	_box(Vector3(-4.0, 0, 4.4), Vector3(0.9, 1.8, 0.6), Color(0.75, 0.3, 0.3), true)
	_sign("음료", 70, Vector3(-4.0, 2.1, 4.4), self); props.append([Vector3(-4.0, 0, 4.4), "buying a drink"])
	_box(Vector3(1.5, 0, -6.2), Vector3(2.0, 1.8, 0.25), Color(0.85, 0.75, 0.35), true)
	_sign("노선도", 70, Vector3(1.5, 2.1, -6.0), self); props.append([Vector3(1.5, 0, -5.9), "reading the map"])
	for i in 5:   # coin lockers along the left wall, labelled in Hangul
		var l := _box(Vector3(-hw + 0.5, 0, -2.4 + i * 1.2), Vector3(0.6, 1.9, 1.0), Color(0.3, 0.45, 0.62), true)
		_sign(NUM[i], 120, Vector3(0, 1.35, 0), l)
		var dg := _sign(str(i + 1), 48, Vector3(0.75, 1.35, 0), l); dg.modulate = Color(1, 1, 1, 0.7); dg.no_depth_test = true
		lockers.append(l); var lm: StandardMaterial3D = (l.get_child(1) as MeshInstance3D).material_override
		lm.emission_enabled = true; lm.emission = Color.BLACK; locker_mats.append(lm)
	talkers = {"a": _person(SPOTS[0][0], Color(0.95, 0.55, 0.15)), "b": _person(SPOTS[0][1], Color(0.98, 0.78, 0.3))}
	for k in talkers:
		bubbles[k] = _bubble(talkers[k])
		cones[k] = _cone(talkers[k], TALK_RANGE, TALK_HALF, Color(1, 0.85, 0.2, 0.25)); cones[k].visible = false
	guard = _person(GUARD_POINTS[0], Color(0.85, 0.2, 0.2))
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
	doing = _label(24); doing.position = Vector2(24, 96); root.add_child(doing)
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
	loiter_t = 0.0; natural_t = 0.0; voice.stop(); speaking = ""; noticed_cd = 0.0
	spot = randi() % SPOTS.size(); walking = false
	for k in talkers:
		talkers[k].position = SPOTS[spot][0 if k == "a" else 1]
		bubbles[k].visible = false; cones[k].visible = false; t_look[k] = 0.0; talkers[k].rotation.y = _face_partner(k)
	_new_talk(); wait = 2.0; t_next = 5.0
	player.position = START; player.velocity = Vector3.ZERO; body_mesh.rotation.y = 0
	cam.position = START + CAM_OFF; cam.look_at(START, Vector3.UP)
	for m in locker_mats: m.albedo_color = Color(0.3, 0.45, 0.62)
	# the guard's route: five of the points, in any order, with stops of any length
	var pts := GUARD_POINTS.duplicate(); pts.shuffle(); route.clear()
	for i in 5: route.append([pts[i], randf_range(0.0, 3.0)])
	g_speed = randf_range(1.4, 2.0)
	guard.position = route[0][0]; g_i = 1; g_target = route[1][0]; g_pause = 0.0; investigating = false
	var gd: Vector3 = g_target - guard.position; guard.rotation.y = atan2(-gd.x, -gd.z)
	for c in commuters: c.body.queue_free()
	commuters.clear(); commuter_t = 0.0
	if not no_commuters: _first_commuters()
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


# ---------------------------------------------------------------- what they say

func _small(i: int) -> Array:
	return [["a", "st_%da" % i, 0.6, false], ["b", "st_%db" % i, randf_range(1.0, 2.5), false]]


## One loop of their conversation: some small talk, the secret somewhere in it, said one of several ways.
func _make_talk() -> Array:
	var out := []
	var topics := [0, 1, 2, 3, 4]; topics.shuffle()
	var before := randi_range(0, 2); var after := randi_range(0, 2 - before)
	for i in before: out += _small(topics[i])
	out.append(["check", "", 0.0, false])          # they look around first (or don't)
	var lead := randi_range(0, 2)
	out.append(["a", "lead_%d" % lead, 0.5, true])
	if lead != 2: out += [["b", "ans", 0.5, true], ["a", "q2", 0.5, true]]
	var num: String
	if randf() < 0.3:   # "사 번... 아니, 삼 번이요"
		var w := answer
		while w == answer: w = randi_range(1, 5)
		num = "trap_%d_%d" % [w, answer]
	else: num = "num_p%d_%d" % [randi_range(0, 2), answer]
	out.append(["b", num, 0.6, true])
	out.append(["a", ["ok", "ok2"].pick_random(), 1.0, false])
	for i in after: out += _small(topics[before + i])
	out[-1][2] = randf_range(3.0, 5.0)
	return out


func _new_talk() -> void:
	talk = _make_talk(); line_i = 0


func _say_next() -> void:
	var l: Array = talk[line_i]
	if l[0] == "check":
		var r := 1.0 if freeze_talkers else randf()
		if r < 0.35: _glance("a"); _glance("b"); wait = 2.0
		elif r < 0.7: _glance(["a", "b"].pick_random()); wait = 1.5
		else: wait = 0.3
		line_i += 1; return
	voice.stream = clips[l[1]]; voice.play(); played.append(l[1])
	if l[1].begins_with("num_") or l[1].begins_with("trap_"): num_cut = lowpass.cutoff_hz
	speaking = l[0]; bubbles[speaking].visible = true


func _line_done() -> void:
	for b in bubbles.values(): b.visible = false
	if voice.stream == clips["huh"]: speaking = ""; return
	if speaking == "": return
	wait = talk[line_i][2]; line_i += 1; speaking = ""
	if line_i >= talk.size():   # the end of a loop: sometimes they move somewhere else first
		_new_talk()
		if randf() < 0.5 and not freeze_talkers: _move_spot()


func _whispered() -> bool:
	return speaking != "" and line_i < talk.size() and talk[line_i][3]


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


func _move_spot() -> void:
	var to := spot
	while to == spot: to = randi() % SPOTS.size()
	spot = to; walking = true
	var tw := create_tween().set_parallel()
	var secs := 0.0
	for k in talkers:
		var dest: Vector3 = SPOTS[spot][0 if k == "a" else 1]
		var d: Vector3 = dest - talkers[k].position
		secs = maxf(secs, d.length() / 1.3)
		talkers[k].rotation.y = atan2(-d.x, -d.z)
	for k in talkers: tw.tween_property(talkers[k], "position", SPOTS[spot][0 if k == "a" else 1], secs)
	tw.chain().tween_callback(func():
		walking = false; wait = 1.0
		for k in talkers: _turn(k, _face_partner(k)))


# ---------------------------------------------------------------- commuters: moving cover

func _first_commuters() -> void:
	await get_tree().physics_frame   # the walls have to be in the physics world before paths can be checked
	var tries := 0
	while commuters.size() < 4 and tries < 20:
		_spawn_commuter(true); tries += 1


func _clear(a: Vector3, b: Vector3, skip_a: bool, skip_b: bool) -> bool:   # room for a person to walk from a to b?
	var ss := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new(); var sp := SphereShape3D.new(); sp.radius = 0.5
	q.shape = sp; q.collision_mask = 1
	var n := maxi(1, int(a.distance_to(b) / 0.3))
	for j in n + 1:
		var pt := a.lerp(b, float(j) / n)
		if (skip_a and pt.distance_to(a) < 0.8) or (skip_b and pt.distance_to(b) < 0.8): continue   # the exits sit in the wall
		for k in talkers:
			if Vector2(pt.x - talkers[k].position.x, pt.z - talkers[k].position.z).length() < 1.0: return false
		q.transform = Transform3D(Basis(), pt + Vector3(0, 0.85, 0))
		if not ss.intersect_shape(q, 1).is_empty(): return false
	return true


func _spawn_commuter(anywhere := false) -> bool:
	var path := []
	var ctr: Vector3 = (talkers.a.position + talkers.b.position) / 2
	var go_near := randf() < 0.6
	for tries in 150:   # a path that goes around things, often past the two
		var ex := EXITS.duplicate(); ex.shuffle()
		var mid := Vector3(randf_range(-6.5, 6.5), 0, randf_range(-4.5, 4.5))
		var near := tries % 4 != 3 if go_near else tries % 4 == 0
		if near: mid = ctr + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(1.4, 2.5)
		if absf(mid.x) > 7.8 or absf(mid.z) > 5.6: continue
		var p := [ex[0], mid, ex[1]]
		if tries >= 30:   # no straight way: add a turn on one side
			var turn := Vector3(randf_range(-7.0, 7.0), 0, randf_range(-5.0, 5.0))
			if randf() < 0.5: p.insert(1, turn)
			else: p.insert(2, turn)
		var ok := true
		for j in p.size() - 1:
			if not _clear(p[j], p[j + 1], j == 0, j == p.size() - 2): ok = false; break
		if ok: path = p; break
	if path.is_empty(): return false
	var b := StaticBody3D.new(); b.collision_layer = 2; b.collision_mask = 0   # blocks sight, not you
	var s := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.45; cap.height = 1.6; s.shape = cap; s.position.y = 0.8; b.add_child(s)
	var look := _person(Vector3.ZERO, Color(0.55, 0.55, 0.6)); remove_child(look); b.add_child(look)
	add_child(b)
	var c := {"body": b, "path": path, "i": 1, "speed": randf_range(1.2, 1.9)}
	b.position = path[0]
	if anywhere: b.position = path[0].lerp(path[1], randf());
	commuters.append(c); return true


func _commuters(dt: float) -> void:
	for c in commuters.duplicate():
		var to: Vector3 = c.path[c.i] - c.body.position; to.y = 0
		if to.length() < 0.15:
			c.i += 1
			if c.i >= c.path.size():
				c.body.queue_free(); commuters.erase(c); continue
			continue
		c.body.position += to.normalized() * minf(to.length(), c.speed * dt)
		c.body.rotation.y = atan2(-to.x, -to.z)
	commuter_t -= dt
	if commuters.size() < 4 and commuter_t <= 0.0:
		_spawn_commuter(); commuter_t = randf_range(0.5, 3.0)


# ---------------------------------------------------------------- seeing and hearing

func _sees(eye: Node3D, rng: float, half: float) -> bool:
	var to := player.global_position - eye.global_position; to.y = 0
	if to.length() > rng: return false
	var fwd := -eye.global_transform.basis.z; fwd.y = 0
	if fwd.normalized().angle_to(to.normalized()) > half: return false
	var q := PhysicsRayQueryParameters3D.create(eye.global_position + Vector3(0, 1.4, 0), player.global_position + Vector3(0, 1.0, 0), 2)
	if eye.get_parent() is StaticBody3D: q.exclude = [eye.get_parent().get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _near_talkers() -> float:
	return minf(player.global_position.distance_to(talkers.a.global_position), player.global_position.distance_to(talkers.b.global_position))


## 0 = clear, 1 = muffled. Whispered lines only carry a short way.
func _clarity(d: float, secret: bool) -> float:
	return clampf((d - 1.7) / 1.4, 0.0, 1.0) if secret else clampf((d - 2.4) / 3.5, 0.0, 1.0)


func _natural_here() -> String:
	for p in props:
		if Vector2(p[0].x - player.position.x, p[0].z - player.position.z).length() < 1.25: return p[1]
	return ""


# ---------------------------------------------------------------- every frame

func _guard(dt: float) -> void:
	if g_pause > 0.0:
		g_pause -= dt; guard.rotation.y = g_base + sin(g_pause * 1.8) * 1.1
		if g_pause <= 0.0 and investigating:
			investigating = false; g_target = route[g_i][0]
		return
	var to := g_target - guard.position; to.y = 0
	if to.length() < 0.1:
		g_base = guard.rotation.y
		if investigating:
			g_pause = 3.0; return
		g_pause = route[g_i][1]; g_i = (g_i + 1) % route.size(); g_target = route[g_i][0]
		if g_i == 0: route[g_i][1] = randf_range(0.0, 3.0)
		return
	guard.position += to.normalized() * minf(to.length(), g_speed * (1.7 if investigating else 1.0) * dt)
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
	var still := dir.length() < 0.12
	if not still and not moved:
		moved = true; hint.visible = false
	player.velocity = Vector3(dir.x, 0, dir.y) * SPEED
	player.move_and_slide(); player.position.y = 0
	if not still: body_mesh.rotation.y = atan2(-dir.x, -dir.y)
	if not freeze_guard: _guard(dt)
	if not no_commuters: _commuters(dt)
	# what you look like you're doing
	natural_what = _natural_here() if still else ""
	if natural_what != "": natural_t += dt
	else: natural_t = maxf(0.0, natural_t - dt * 2.0)
	var natural := natural_what != "" and natural_t < NATURAL_FOR
	if still and not natural and _near_talkers() < 4.5: loiter_t += dt
	else: loiter_t = maxf(0.0, loiter_t - dt * 2.0)
	if natural: doing.text = "Acting natural: " + natural_what
	elif natural_what != "": doing.text = "You've been %s for a while..." % natural_what
	elif loiter_t > 2.5: doing.text = "Standing around here looks odd"
	else: doing.text = ""
	# the talkers glance around now and then
	if not freeze_talkers and not walking:
		t_next -= dt
		if t_next <= 0.0 and t_look.a <= 0.0 and t_look.b <= 0.0:
			_glance(["a", "b"].pick_random()); t_next = randf_range(2.5, 7.0)
	for k in talkers:
		if t_look[k] > 0.0:
			t_look[k] -= dt
			if t_look[k] <= 0.0:
				_turn(k, _face_partner(k)); cones[k].visible = false
	# being noticed (acting natural, people barely care)
	var care := 0.2 if natural else 1.0
	var watched := false
	var gdist := player.position.distance_to(guard.position)
	if _sees(guard, GUARD_RANGE, GUARD_HALF) or gdist < 1.0:   # the closer he is, the quicker he's sure
		suspicion += dt * care * (0.5 + 1.4 * (1.0 - gdist / GUARD_RANGE)); watched = true
	var spotted := _near_talkers() < NOTICE
	var seen_by_them := false
	for k in talkers:
		if t_look[k] > 0.0 and _sees(talkers[k], TALK_RANGE, TALK_HALF): seen_by_them = true
	if seen_by_them and not natural: spotted = true
	elif seen_by_them: suspicion += dt * 0.08; watched = true
	if loiter_t > 2.5:
		suspicion += dt * 0.12; watched = true
		for c in commuters:   # passers-by notice someone lurking
			if c.body.position.distance_to(player.position) < 2.2: suspicion += dt * 0.15
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
			_new_talk(); wait = 3.0; bubbles["b"].visible = true
	if not watched: suspicion = maxf(0.0, suspicion - dt * 0.1)
	if suspicion >= 1.0:
		suspicion = 1.0; _end("caught"); return
	near_locker = -1; var best := 1.3
	for i in lockers.size():
		var lp: Vector3 = lockers[i].global_position
		var d := Vector2(lp.x - player.position.x, lp.z - player.position.z).length()
		if d < best and not opened.has(i): near_locker = i; best = d
	for i in lockers.size():   # the one the button opens lights up
		var m: StandardMaterial3D = locker_mats[i]
		m.albedo_color = Color(0.18, 0.22, 0.28) if opened.has(i) else (Color(1.0, 0.82, 0.25) if i == near_locker else Color(0.3, 0.45, 0.62))
		m.emission = Color(0.6, 0.45, 0.05) if i == near_locker else Color.BLACK
	open_btn.visible = near_locker >= 0
	if near_locker >= 0: open_btn.text = "Open %s" % NUM[near_locker]


func _process(dt: float) -> void:
	cam.position = cam.position.lerp(player.position + CAM_OFF, 1.0 - exp(-6.0 * dt)); cam.look_at(cam.position - CAM_OFF, Vector3.UP)
	sus_bar.value = suspicion
	toast_t -= dt
	if toast_t <= 0.0: toast.text = ""
	if state != "play": return
	var d := _near_talkers()
	var secret := _whispered()
	var k := _clarity(d, secret)
	lowpass.cutoff_hz = lerpf(9000.0, 350.0, k)
	AudioServer.set_bus_volume_db(talk_bus, lerpf(0.0, -16.0, k) - 24.0 * clampf((d - 6.0) / 3.0, 0.0, 1.0))
	if d > 7.5: hear_label.text = "Too far to hear"
	elif secret: hear_label.text = "They're whispering: " + ("clear" if k < 0.25 else "can't make it out")
	else: hear_label.text = "Hearing: " + ("clear" if k < 0.25 else "muffled")
	if speaking == "" and not voice.playing and not walking:
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


func _quiet_round(at_spot: int) -> void:   # a round with the guard, the commuters and their wandering held still
	freeze_guard = true; freeze_talkers = true; no_commuters = true
	_reset(); guard.position = Vector3(8.0, 0, 5.8)
	spot = at_spot
	for k in talkers:
		talkers[k].position = SPOTS[spot][0 if k == "a" else 1]; talkers[k].rotation.y = _face_partner(k)
	await _secs(0.1)


func _run_test() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().position = Vector2i(-3000, 60)   # out of the way
	await _secs(0.8); await _shot("1_start")
	_check(state == "play" and toast.text.begins_with("Handler") and commuters.size() == 4, "it starts right away, with commuters walking about")
	var paths_ok := true; var close := 0
	for i in 30:
		for c in commuters: c.body.queue_free()
		commuters.clear()
		while not _spawn_commuter(): pass
		var cp: Array = commuters[-1].path
		for j in cp.size() - 1:
			if not _clear(cp[j], cp[j + 1], j == 0, j == cp.size() - 2): paths_ok = false
		var cl := false
		for q in cp.slice(1, -1): cl = cl or q.distance_to((talkers.a.position + talkers.b.position) / 2) < 2.6
		if cl: close += 1
	_check(paths_ok and close >= 7, "commuters walk around things, and often close past the two (%d/30)" % close)
	for c in commuters: c.body.queue_free()
	commuters.clear(); for i in 4: _spawn_commuter(true)
	# the conversation is different every time
	var where := {}; var how := {}; var traps := 0; var right := true
	for i in 300:
		var tk := _make_talk()
		for j in tk.size():
			var c: String = tk[j][1]
			if c.begins_with("num_") or c.begins_with("trap_"):
				where[j] = 1; how[c.substr(0, 6)] = 1
				if c.begins_with("trap_"): traps += 1
				if not c.ends_with("_%d" % answer): right = false
	_check(where.size() >= 4 and how.size() >= 4 and traps > 40 and right, "the number comes at %d different points, said %d ways, %d corrections in 300 rounds" % [where.size(), how.size(), traps])
	_check(_clarity(3.0, true) > 0.8 and _clarity(3.0, false) < 0.3, "3 m away: small talk is clear, the whisper isn't")
	# the ticket machine: hidden from them and acting natural
	await _quiet_round(0)
	await _put(Vector3(6.2, 0, -1.75))
	_glance("a", _at("a")); _glance("b", _at("b")); await _secs(0.5)
	_check(state == "play" and not ("huh" in played), "behind the ticket machine they can't see you, even looking your way")
	_check(doing.text.begins_with("Acting natural"), "standing at the ticket machine you're acting natural")
	var got := false
	for i in 120:
		await _secs(0.5)
		natural_t = 0.0; suspicion = minf(suspicion, 0.5)   # (as if stepping away and back now and then)
		if played.any(func(c): return c.begins_with("num_") or c.begins_with("trap_")):
			got = true; break
	_check(got, "they say the number (heard: %s)" % ", ".join(played))
	_check(num_cut > 6000.0, "from there the whisper is clear (%d Hz)" % num_cut)
	await _shot("2_listening")
	# standing around in the open near them, unseen, still looks odd
	await _quiet_round(0)
	await _put(Vector3(2.4, 0, -1.6)); await _secs(5.0)
	_check(suspicion > 0.1 and doing.text.begins_with("Standing"), "loitering near them builds suspicion even unseen (%.2f)" % suspicion)
	# seen in the open when one of them looks over
	suspicion = 0.0; noticed_cd = 0.0
	_glance("a", _at("a")); await _secs(0.6)
	_check("huh" in played and suspicion > 0.2, "in the open, when they look over, they notice (suspicion %.2f)" % suspicion)
	await _shot("3_noticed")
	# a commuter between you and the guard hides you
	await _quiet_round(0)
	guard.position = Vector3(-2, 0, 3); guard.rotation.y = 0.0     # looking up the screen
	await _put(Vector3(-2, 0, -1.0)); await _secs(0.1)
	var saw := _sees(guard, GUARD_RANGE, GUARD_HALF)
	no_commuters = false
	while not _spawn_commuter(): pass
	var cmt: Dictionary = commuters[-1]; cmt.speed = 0.0; cmt.body.position = Vector3(-2, 0, 1.0)
	await get_tree().physics_frame; await get_tree().physics_frame
	var hid := not _sees(guard, GUARD_RANGE, GUARD_HALF)
	_check(saw and hid, "a commuter walking between you and the guard blocks his view")
	await _shot("4_commuter")
	# they move between spots
	await _quiet_round(0); freeze_talkers = false
	var before_a: Vector3 = talkers.a.position
	_move_spot(); await _secs(11.0)
	_check(talkers.a.position.distance_to(before_a) > 2.0 and not walking, "the two walk to another spot")
	# lockers: one wrong is normal, two looks odd, three brings the guard
	await _quiet_round(0)
	var wrong := []
	for i in 5:
		if i + 1 != answer: wrong.append(i)
	await _put(lockers[wrong[0]].global_position + Vector3(1.0, 0, 0)); await _secs(0.2)
	_check(open_btn.visible and open_btn.text == "Open %s" % NUM[wrong[0]], "next to a locker the button says its Hangul number")
	_check(locker_mats[wrong[0]].emission != Color.BLACK and locker_mats[wrong[1]].emission == Color.BLACK, "only the locker the button opens lights up")
	_open(wrong[0]); _check(state == "play" and suspicion < 0.15 and not investigating, "one wrong locker is fine")
	_open(wrong[1]); _check(state == "play" and suspicion > 0.25 and not investigating, "a second one draws looks")
	freeze_guard = false
	_open(wrong[2]); _check(investigating, "a third one brings the guard over")
	_open(answer - 1); _check(state == "won" and panel.visible, "the right locker wins")
	await _shot("5_won")
	# the guard's route changes every round
	freeze_guard = false; freeze_talkers = false; no_commuters = true
	var firsts := {}
	for i in 6:
		_reset(); firsts[str(route[0][0]) + str(route[1][0])] = 1
	_check(firsts.size() >= 3, "the guard's route is different each round (%d different in 6)" % firsts.size())
	_reset(); await _secs(0.2)
	var g0 := guard.position
	await _secs(1.0)
	_check(guard.position.distance_to(g0) > 1.0, "the guard walks his route")
	await _put(guard.position + (-guard.global_transform.basis.z * Vector3(1, 0, 1)).normalized() * 2.0)
	await _secs(3.0)
	_check(state == "caught", "walking into the guard's view gets you caught")
	await _shot("6_caught")
	# the thumb stick
	_reset(); await _secs(0.2)
	var before := player.position
	var tch := InputEventScreenTouch.new(); tch.index = 0; tch.position = Vector2(200, 500); tch.pressed = true; Input.parse_input_event(tch)
	var dr := InputEventScreenDrag.new(); dr.index = 0; dr.position = Vector2(290, 500); Input.parse_input_event(dr)
	await _secs(0.6)
	_check(player.position.x > before.x + 1.0 and not hint.visible, "dragging on the left moves you, and the hint goes away")
	tch.pressed = false; Input.parse_input_event(tch)
	print("DONE %d failed" % _fails)
	get_tree().quit(1 if _fails else 0)
