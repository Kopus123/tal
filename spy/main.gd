extends Node3D
## Grey box 3: a subway station. Two people whisper which coin locker the package is in.
## Every round is shuffled: what they chat about, how and when they say the number (sometimes they correct
## themselves), where they stand, the guard's route. Commuters walk through: they're cover you can walk behind.
## Standing around near the two looks suspicious unless you're acting natural (ticket machine, drinks, map).
## The man in red is their lookout. When he gets suspicious he comes over and asks what you're doing:
## you build an answer from Korean words and say it, or give up and act it out in English (always works, badly).

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
const GOAL := "Goal: find out which locker"
const TILES := {"ticket": ["표", "ticket"], "drink": ["음료", "drink"], "map": ["노선도", "map"], "friend": ["친구", "friend"],
	"train": ["지하철", "subway"], "buy": ["사요", "buy"], "look": ["봐요", "look at"], "wait": ["기다려요", "wait for"],
	"home": ["집에", "home"], "work": ["회사에", "to work"], "school": ["학교에", "to school"], "go": ["가요", "go"], "meet": ["만나요", "meet"]}
const VERB_EN := {"buy": "I'm buying", "look": "I'm looking at", "wait": "I'm waiting for", "go": "I'm going", "meet": "I'm meeting"}
const NOUN_EN := {"ticket": "a ticket", "drink": "a drink", "map": "the subway map", "friend": "a friend", "train": "the subway",
	"home": "home", "work": "to work", "school": "to school"}
const QS := {   # what the lookout asks, and the words you get to answer with
	"what": {"ko": "저기요, 뭐 하세요?", "en": "Excuse me, what are you doing?", "obj": "g_whatobj",
		"tiles": ["ticket", "drink", "map", "friend", "train", "buy", "look", "wait"]},
	"where": {"ko": "어디 가세요?", "en": "Where are you going?", "obj": "g_whereobj",
		"tiles": ["home", "work", "school", "friend", "go", "meet", "wait", "buy"]},
}
const GOOD := {   # answers that make sense, and the machine that has to be nearby for them to be believable (-1: none)
	"what": {"ticket buy": 0, "drink buy": 1, "map look": 2, "friend wait": -1, "train wait": -1},
	"where": {"home go": -1, "work go": -1, "school go": -1, "friend meet": -1},
}
const PROP_KO := ["표", "음료", "노선도"]
const IDEAS := {   # "I can't say it": what you try to get across, and how it goes: badly, awkwardly, luckily
	"ticket": ["You mime buying a ticket so hard you knock his hat off.", "You point at the ticket machine and nod way too much.", "You wave an old receipt like it's a ticket. He buys it."],
	"drink": ["You mime drinking, choke on nothing, and cough on him.", "You make slurping noises at him.", "You hold up an empty can. He nods."],
	"map": ["You trace your route on his chest with your finger.", "You stare at the ceiling and say \"map...\" in English.", "You hold up your phone with a map open. Good enough."],
	"friend": ["You hug him and call him \"friend\". In English.", "You wave at a stranger like you know them.", "A stranger waves back by chance. He believes you."],
	"train": ["You make loud choo-choo noises.", "You point at the tunnel and tap your wrist. Slowly.", "A train rumbles by just as you point. Perfect timing."],
	"home": ["You lie down on the floor and pretend to sleep.", "You draw a house in the air with both hands.", "You yawn and point at the exit. He gets it."],
}
const IDEA_KO := {"ticket": "표", "drink": "음료", "map": "노선도", "friend": "친구", "train": "지하철", "home": "집"}

var test := false
var freeze_guard := false
var freeze_talkers := false
var no_commuters := false
var player: CharacterBody3D
var body_mesh: Node3D
var cam: Camera3D
var guard: CharacterBody3D
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
var g_stuck := 0.0
# the lookout
var g_mode := "patrol"        # patrol, approach (coming to ask you), talk, watch (you said you'd do something: he checks)
var g_count := 0              # times he has questioned you this round
var g_cd := 0.0               # after a talk he leaves you be for a while
var approach_t := 0.0
var talk_n := 0               # bumps whenever a talk ends, so lines still playing from it know to stop
var q_id := "what"
var q_fails := 0
var timeouts := 0
var patience := 0.0
var patience_max := 20.0
var picked: Array = []
var busy := false             # someone in the talk is speaking
var watch_prop := -1
var watch_t := 0.0
var gvoice: AudioStreamPlayer
var pvoice: AudioStreamPlayer
var alert: Label3D
var followup := -1            # (tester) 1: always ask where you're going next, 0: never
var english_roll := -1.0      # (tester) fixes how the English goes
var last_result := {}
var talk_ui: PanelContainer
var q_label: Label
var gloss: Label
var gloss_t := 0.0
var pat_bar: ProgressBar
var ans_label: Label
var said_label: Label
var tile_box: HBoxContainer
var say_btn: Button
var cant_btn: Button
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
	ids += ["g_what", "g_where", "g_again", "g_ok", "g_ok2", "g_meh", "g_huh", "g_whatobj", "g_whereobj", "g_there_0", "g_there_1", "g_there_2", "g_odd", "g_hey"]
	for k in TILES: ids.append("p_t_" + k)
	for q in GOOD:
		for g in GOOD[q]: ids += ["p_s_" + g.replace(" ", "_"), "g_help_" + g.replace(" ", "_")]
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
	gvoice = AudioStreamPlayer.new(); add_child(gvoice)   # the lookout and you: right next to each other, so always clear
	pvoice = AudioStreamPlayer.new(); add_child(pvoice)


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
	var fb := StaticBody3D.new(); fb.collision_layer = 8; var fs := CollisionShape3D.new(); fs.shape = WorldBoundaryShape3D.new(); fb.add_child(fs); add_child(fb)
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
	guard = CharacterBody3D.new(); guard.collision_layer = 0; guard.collision_mask = 1; add_child(guard)   # walks around things
	var gs := CollisionShape3D.new(); var gc := CapsuleShape3D.new(); gc.radius = 0.3; gc.height = 1.5; gs.shape = gc; gs.position.y = 0.75; guard.add_child(gs)
	var gm := _person(Vector3.ZERO, Color(0.85, 0.2, 0.2)); remove_child(gm); guard.add_child(gm)
	guard.position = GUARD_POINTS[0]
	_cone(guard, GUARD_RANGE, GUARD_HALF, Color(1, 0.2, 0.15, 0.22))
	alert = _sign("!", 130, Vector3(0, 2.3, 0), guard); alert.modulate = Color(1, 0.85, 0.2); alert.no_depth_test = true; alert.visible = false
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
	goal = _label(26); goal.position = Vector2(24, 60); goal.text = GOAL; root.add_child(goal)
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
	_talk_screen(root)


func _btn(text: String, size: int, min: Vector2) -> Button:
	var b := Button.new(); b.text = text; b.add_theme_font_size_override("font_size", size); b.custom_minimum_size = min; return b


func _talk_screen(root: Control) -> void:   # the bottom panel while the lookout questions you
	talk_ui = PanelContainer.new(); root.add_child(talk_ui)
	talk_ui.anchor_left = 0; talk_ui.anchor_right = 1; talk_ui.anchor_top = 1; talk_ui.anchor_bottom = 1
	talk_ui.offset_left = 16; talk_ui.offset_right = -16; talk_ui.offset_top = -372; talk_ui.offset_bottom = -10
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.06, 0.07, 0.1, 0.92); st.set_corner_radius_all(14); st.set_content_margin_all(16)
	talk_ui.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); talk_ui.add_child(row)
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.add_theme_constant_override("separation", 8); row.add_child(left)
	var qrow := HBoxContainer.new(); qrow.add_theme_constant_override("separation", 14); left.add_child(qrow)
	q_label = _label(40); q_label.modulate = Color(1, 0.75, 0.7); qrow.add_child(q_label)
	var hear := _btn("Hear", 22, Vector2(90, 54)); qrow.add_child(hear)
	hear.pressed.connect(_hear)
	gloss = _label(22); gloss.modulate = Color(0.75, 0.75, 0.75); left.add_child(gloss)
	pat_bar = ProgressBar.new(); pat_bar.max_value = 1.0; pat_bar.show_percentage = false; pat_bar.custom_minimum_size = Vector2(0, 8)
	var pf := StyleBoxFlat.new(); pf.bg_color = Color(1, 0.6, 0.2); pat_bar.add_theme_stylebox_override("fill", pf); left.add_child(pat_bar)
	var arow := HBoxContainer.new(); arow.add_theme_constant_override("separation", 14); left.add_child(arow)
	ans_label = _label(38); ans_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; arow.add_child(ans_label)
	var clr := _btn("Clear", 22, Vector2(100, 54)); arow.add_child(clr); clr.pressed.connect(_clear_pick)
	said_label = _label(22); said_label.modulate = Color(1, 0.9, 0.5); said_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(said_label)
	tile_box = HBoxContainer.new(); tile_box.add_theme_constant_override("separation", 8); left.add_child(tile_box)
	var right := VBoxContainer.new(); right.add_theme_constant_override("separation", 14); right.alignment = BoxContainer.ALIGNMENT_END; row.add_child(right)
	say_btn = _btn("Say it", 36, Vector2(190, 130)); right.add_child(say_btn); say_btn.pressed.connect(_say_it)
	var gs := StyleBoxFlat.new(); gs.bg_color = Color(0.2, 0.55, 0.3); gs.set_corner_radius_all(10); say_btn.add_theme_stylebox_override("normal", gs)
	cant_btn = _btn("I can't say it", 22, Vector2(190, 70)); right.add_child(cant_btn); cant_btn.pressed.connect(_cant_say)
	talk_ui.visible = false


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
	guard.position = route[0][0]; g_i = 1; g_target = route[1][0]; g_pause = 0.0; g_stuck = 0.0
	g_mode = "patrol"; g_count = 0; g_cd = 0.0; talk_n += 1; busy = false; talk_ui.visible = false; alert.visible = false
	watch_prop = -1; goal.text = GOAL; gvoice.stop(); pvoice.stop()
	var gd: Vector3 = g_target - guard.position; guard.rotation.y = atan2(-gd.x, -gd.z)
	for c in commuters: c.body.queue_free()
	commuters.clear(); commuter_t = 0.0
	if not no_commuters: _first_commuters()
	joy_touch = -1; joy_vec = Vector2.ZERO; joy_draw.queue_redraw(); open_btn.visible = false
	panel.visible = false; state = "play"
	_say("Handler: those two know which locker. The man in red is their lookout.", 6.0)


func _end(kind: String, why := "You've been noticed.") -> void:
	state = kind; voice.stop(); speaking = ""; joy_touch = -1; joy_vec = Vector2.ZERO; joy_draw.queue_redraw(); open_btn.visible = false
	talk_n += 1; busy = false; talk_ui.visible = false; alert.visible = false; g_mode = "patrol"
	for k in talkers: bubbles[k].visible = false
	toast.text = ""
	if kind == "won": _panel("Got it: %s 번.\nMission complete." % NUM[answer - 1], "Again")
	else: _panel("%s\n(It was %s 번, locker %d.)" % [why, NUM[answer - 1], answer], "Try again")


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
		suspicion += 0.3; _start_approach("Empty. The lookout heard that. He's coming over.")
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


# ---------------------------------------------------------------- the lookout comes over and asks

func _start_approach(why: String) -> void:
	if g_mode != "patrol" or state != "play": return
	g_mode = "approach"; approach_t = 0.0; alert.visible = true; g_pause = 0.0
	_say(why, 4.0)


func _start_talk() -> void:
	g_mode = "talk"; g_count += 1; talk_n += 1; alert.visible = false
	var n := talk_n
	joy_touch = -1; joy_vec = Vector2.ZERO; joy_draw.queue_redraw(); open_btn.visible = false; doing.text = ""; toast.text = ""
	var d := guard.position - player.position; body_mesh.rotation.y = atan2(-d.x, -d.z)
	patience_max = [20.0, 15.0, 11.0][mini(g_count, 3) - 1]
	talk_ui.visible = true; said_label.text = ""
	cant_btn.disabled = g_count >= 3
	cant_btn.text = "No more excuses" if g_count >= 3 else "I can't say it"
	if g_count >= 3:   # third time: he's had enough of you
		busy = true; q_label.text = "또 당신이에요?"; gloss.text = "You again?"; gloss.visible = true; ans_label.text = ""; _tiles_for([])
		_gsay("g_again"); await _done(gvoice)
		if n != talk_n: return
		busy = false
	_ask("what")


func _hear() -> void:
	if not busy and g_mode == "talk": _gsay("g_" + q_id)


func _gsay(id: String) -> void:
	gvoice.stream = clips[id]; gvoice.play(); played.append(id)


func _done(p: AudioStreamPlayer) -> void:
	await get_tree().process_frame
	while p.playing: await get_tree().process_frame


func _psay(ids: Array) -> void:   # your character says it out loud
	for id in ids:
		pvoice.stream = clips[id]; pvoice.play(); played.append(id)
		await _done(pvoice)


func _ask(q: String) -> void:
	q_id = q; picked.clear(); q_fails = 0; timeouts = 0
	q_label.text = QS[q].ko; gloss.text = QS[q].en; gloss.visible = false; gloss_t = 3.0
	patience = patience_max
	_tiles_for(QS[q].tiles); _show_pick()
	_gsay("g_" + q)


func _tiles_for(keys: Array) -> void:
	for c in tile_box.get_children(): c.queue_free()
	for k in keys:
		var b := _btn("%s\n%s" % TILES[k], 25, Vector2(108, 100)); b.pressed.connect(_pick.bind(k)); tile_box.add_child(b)
	say_btn.visible = true


func _pick(k: String) -> void:
	if busy or picked.size() >= 3: return
	picked.append(k); _show_pick()
	pvoice.stream = clips["p_t_" + k]; pvoice.play()   # each word says itself when you tap it


func _clear_pick() -> void:
	if busy: return
	picked.clear(); _show_pick()


func _show_pick() -> void:
	var words := []
	for k in picked: words.append(TILES[k][0])
	ans_label.text = " ".join(words) if words else "Tap words to answer"
	ans_label.modulate = Color.WHITE if words else Color(1, 1, 1, 0.45)
	say_btn.disabled = picked.is_empty()


func _ko(key: String) -> String:
	var w := []
	for k in key.split(" "): w.append(TILES[k][0])
	return " ".join(w)


func _en(key: String) -> String:
	var w := key.split(" ")
	return "\"%s %s.\"" % [VERB_EN[w[1]], NOUN_EN[w[0]]]


## What did you just say? good / order (right words, verb first) / noun (half a sentence) / verb (do what?) / weird
func _judge(p: Array, q: String) -> Dictionary:
	var nouns := p.filter(func(k): return NOUN_EN.has(k))
	var verbs := p.filter(func(k): return VERB_EN.has(k))
	if p.size() == 2 and nouns.size() == 1 and verbs.size() == 1:
		var key: String = nouns[0] + " " + verbs[0]
		if GOOD[q].has(key): return {"kind": "good" if p[0] == nouns[0] else "order", "key": key, "prop": GOOD[q][key], "en": _en(key)}
		return {"kind": "weird", "en": _en(key)}
	if p.size() == 1 and nouns.size() == 1:
		for key in GOOD[q]:
			if key.begins_with(nouns[0] + " "):
				return {"kind": "noun", "key": key, "prop": GOOD[q][key], "en": "\"%s.\"" % TILES[nouns[0]][1].capitalize()}
		return {"kind": "weird", "en": "\"%s.\"" % TILES[nouns[0]][1].capitalize()}
	if p.size() == 1: return {"kind": "verb", "en": "\"%s...\"" % VERB_EN[verbs[0]]}
	return {"kind": "weird", "en": "\"%s.\" That's not a sentence." % " ".join(p.map(func(k): return TILES[k][1]))}


func _say_it() -> void:
	if busy or picked.is_empty() or g_mode != "talk": return
	var n := talk_n; busy = true
	var r := _judge(picked, q_id); last_result = r
	if r.kind == "good": await _psay(["p_s_" + r.key.replace(" ", "_")])
	else: await _psay(picked.map(func(k): return "p_t_" + k))
	if n != talk_n: return
	said_label.text = "You said: " + r.en
	await _react(r, n)
	if n == talk_n: busy = false


func _react(r: Dictionary, n: int) -> void:
	if r.kind in ["good", "order", "noun"]:
		if r.kind != "good":   # he works out what you meant and says it properly
			_gsay("g_help_" + r.key.replace(" ", "_")); await _done(gvoice)
			if n != talk_n: return
			said_label.text = ("In Korean the action goes last: " if r.kind == "order" else "He finished it for you: ") + _ko(r.key) + " = " + _en(r.key)
		suspicion = clampf(suspicion + {"good": -0.35, "noun": -0.1, "order": -0.15}[r.kind], 0.0, 1.0)
		if r.prop >= 0 and Vector2(props[r.prop][0].x - player.position.x, props[r.prop][0].z - player.position.z).length() > 3.0:
			_gsay("g_there_%d" % r.prop); await _done(gvoice)   # fine, but the machine is over there. Go on then.
			if n != talk_n: return
			_start_watch(r.prop); return
		if q_id == "what" and (followup == 1 or (followup == -1 and (g_count >= 2 or randf() < 0.35))):
			_gsay("g_meh"); await _done(gvoice)
			if n != talk_n: return
			_ask("where"); return
		_gsay("g_ok2" if q_id == "where" else "g_ok"); await _done(gvoice)
		if n != talk_n: return
		_end_talk(); return
	if r.kind == "verb":   # "buy... what?"
		suspicion += 0.05; _gsay(QS[q_id].obj); await _done(gvoice)
		if n != talk_n: return
		said_label.text += "   He asks: %s" % ("뭐를요? (What?)" if q_id == "what" else "어디요? (Where?)")
		picked.clear(); _show_pick(); return
	q_fails += 1   # nonsense
	if g_count >= 3:
		_gsay("g_odd"); await _done(gvoice)
		if n == talk_n: _end("caught", "The lookout didn't buy it.")
		return
	suspicion += 0.2 if q_fails == 1 else 0.3
	_gsay("g_huh" if q_fails == 1 else "g_odd"); await _done(gvoice)
	if n != talk_n or _caught_by_him(): return
	if q_fails == 1:
		picked.clear(); _show_pick(); patience = maxf(patience, patience_max * 0.6)
	else: _end_talk()


func _timeout() -> void:
	timeouts += 1; busy = true
	var n := talk_n
	suspicion += 0.15 if timeouts == 1 else 0.3
	_gsay("g_hey" if timeouts == 1 else "g_odd"); await _done(gvoice)
	if n != talk_n: return
	busy = false
	if _caught_by_him(): return
	if timeouts == 1: patience = patience_max * 0.5
	else: _end_talk()


func _caught_by_him() -> bool:
	if suspicion < 1.0: return false
	suspicion = 1.0; _end("caught", "The lookout didn't buy it."); return true


func _end_talk() -> void:
	talk_n += 1; busy = false; talk_ui.visible = false
	g_mode = "patrol"; g_cd = 25.0; g_pause = 0.0; g_target = route[g_i][0]; goal.text = GOAL


func _start_watch(i: int) -> void:
	talk_n += 1; busy = false; talk_ui.visible = false
	g_mode = "watch"; watch_prop = i; watch_t = 12.0
	goal.text = "Go to %s. He's watching." % PROP_KO[i]


func _watch_done(ok: bool) -> void:
	_gsay("g_ok" if ok else "g_odd")
	suspicion = clampf(suspicion + (-0.2 if ok else 0.5), 0.0, 1.0)   # a lie he caught you in
	_end_talk(); doing.text = ""
	_caught_by_him()


# ---------------------------------------------------------------- "I can't say it": act it out in English

func _cant_say() -> void:
	if busy or g_mode != "talk" or g_count >= 3: return
	for c in tile_box.get_children(): c.queue_free()
	for k in IDEAS:
		var b := _btn(k, 28, Vector2(118, 100)); b.pressed.connect(_english.bind(k)); tile_box.add_child(b)
	var back := _btn("Back", 24, Vector2(100, 100)); tile_box.add_child(back)
	back.pressed.connect(func():
		if not busy:
			_tiles_for(QS[q_id].tiles); _show_pick())
	say_btn.visible = false
	ans_label.text = "What are you trying to say?"; ans_label.modulate = Color.WHITE


func _english(idea: String) -> void:
	if busy: return
	var n := talk_n; busy = true
	var tried := not picked.is_empty() or q_fails > 0       # having a go in Korean first makes the odds kinder
	var odds := [0.15, 0.6] if tried else [0.3, 0.75]
	var roll := randf() if english_roll < 0.0 else english_roll
	var tier := 0 if roll < odds[0] else (1 if roll < odds[1] else 2)
	last_result = {"kind": "english", "tier": tier}
	for c in tile_box.get_children(): c.queue_free()
	ans_label.text = "(in English)"; said_label.text = IDEAS[idea][tier]
	_gesture(tier)
	await get_tree().create_timer(2.4).timeout
	if n != talk_n: return
	suspicion = clampf(suspicion + [0.4, 0.25, 0.1][tier], 0.0, 1.0)
	_gsay(["g_odd", "g_meh", "g_ok"][tier]); await _done(gvoice)
	if n != talk_n or _caught_by_him(): return
	_end_talk()
	_say("Handler: \"%s\" is %s." % [idea, IDEA_KO[idea]], 5.0)   # a piece for next time, never the whole line


func _gesture(tier: int) -> void:
	var tw := create_tween()
	if tier == 0:   # flailing
		tw.tween_property(body_mesh, "rotation:y", body_mesh.rotation.y + TAU * 2.0, 0.9)
		tw.parallel().tween_property(body_mesh, "position:y", 0.5, 0.45)
		tw.tween_property(body_mesh, "position:y", 0.0, 0.3)
	elif tier == 1:   # little hops
		for i in 2:
			tw.tween_property(body_mesh, "position:y", 0.3, 0.15)
			tw.tween_property(body_mesh, "position:y", 0.0, 0.15)
	else:   # a calm nod
		tw.tween_property(body_mesh, "rotation:x", 0.25, 0.2)
		tw.tween_property(body_mesh, "rotation:x", 0.0, 0.2)


# ---------------------------------------------------------------- every frame

func _guard(dt: float) -> void:
	g_cd = maxf(0.0, g_cd - dt)
	if g_mode == "talk" or g_mode == "watch":   # he stands and looks at you
		var d := player.position - guard.position
		guard.rotation.y = lerp_angle(guard.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-8.0 * dt)); return
	if g_mode == "approach":
		approach_t += dt
		var tp := player.position - guard.position; tp.y = 0
		if tp.length() < 1.7: _start_talk(); return
		if approach_t > 8.0 and approach_t - dt <= 8.0:
			suspicion = minf(0.95, suspicion + 0.15); _say("Walking away from him looks bad. He's hurrying.")
		_walk(tp, 4.6 if approach_t > 8.0 else 2.8, dt); return
	if g_pause > 0.0:
		g_pause -= dt; guard.rotation.y = g_base + sin(g_pause * 1.8) * 1.1
		return
	var to := g_target - guard.position; to.y = 0
	if to.length() < 0.15 or g_stuck > 1.5:
		g_base = guard.rotation.y; g_stuck = 0.0
		g_pause = route[g_i][1]; g_i = (g_i + 1) % route.size(); g_target = route[g_i][0]
		if g_i == 0: route[g_i][1] = randf_range(0.0, 3.0)
		return
	_walk(to, g_speed, dt)
	g_stuck = g_stuck + dt if guard.get_real_velocity().length() < g_speed * 0.3 else 0.0


func _walk(to: Vector3, sp: float, dt: float) -> void:   # straight there, or veer round whatever's in the way
	var dir := to.normalized()
	for a in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.1, -2.1]:
		var dd := dir.rotated(Vector3.UP, a)
		if not guard.test_move(guard.global_transform, dd * 0.45): dir = dd; break
	guard.velocity = dir * minf(sp, to.length() / dt); guard.move_and_slide(); guard.position.y = 0
	guard.rotation.y = lerp_angle(guard.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * dt))


func _physics_process(dt: float) -> void:
	if state != "play": return
	if g_mode == "talk":   # you stand there and answer; the station carries on around you
		_guard(dt)
		if not no_commuters: _commuters(dt)
		return
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
	var guard_saw := false
	if g_mode == "patrol" and (_sees(guard, GUARD_RANGE, GUARD_HALF) or gdist < 1.0):   # the closer he is, the quicker he's sure
		suspicion += dt * care * (0.5 + 1.4 * (1.0 - gdist / GUARD_RANGE)) * (0.5 if g_cd > 0.0 else 1.0); watched = true; guard_saw = true
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
	# the lookout: past a point he comes over to ask (unless he only just did)
	if g_mode == "patrol" and g_cd <= 0.0 and ((guard_saw and suspicion >= 0.6) or suspicion >= 0.85):
		_start_approach("Their lookout is coming over. Get an excuse ready." if g_count == 0 else "The lookout is coming over again.")
	if g_mode == "approach": suspicion = minf(suspicion, 0.95)   # what you tell him decides it
	if g_mode == "watch":
		watch_t -= dt
		doing.text = "He's watching: go to %s (%d)" % [PROP_KO[watch_prop], ceili(watch_t)]
		if natural_what == props[watch_prop][1]: _watch_done(true)
		elif watch_t <= 0.0: _watch_done(false)
		if state != "play": return
	if suspicion >= 1.0:
		suspicion = 1.0; _end("caught", "The lookout has seen enough." if guard_saw else "You've been noticed."); return
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
	var focus := player.position; var off := CAM_OFF
	if g_mode == "talk":   # in close on the two of you, above the panel
		focus = (player.position + guard.position) / 2 + Vector3(0, 0, 1.3); off = CAM_OFF * 0.5
	cam.position = cam.position.lerp(focus + off, 1.0 - exp(-6.0 * dt)); cam.look_at(cam.position - off, Vector3.UP)
	if g_mode == "talk":
		gloss_t -= dt
		if gloss_t <= 0.0: gloss.visible = true    # the English comes a moment later: try to catch it by ear first
		if not busy and not gvoice.playing:
			patience -= dt
			if patience <= 0.0: _timeout()
		pat_bar.value = patience / patience_max
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
	if state != "play" or g_mode == "talk": return
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


func _talk_now(at: Vector3, count := 0) -> void:   # a quiet round where the lookout is already asking you
	await _quiet_round(0); await _put(at)
	guard.position = at + Vector3(1.4, 0, 0); g_count = count; followup = 0; english_roll = -1.0
	_start_talk()
	for i in 150:
		await _secs(0.05)
		if not busy and q_label.text == QS.what.ko and not gvoice.playing: break


func _answer(keys: Array) -> void:
	picked = keys.duplicate(); _show_pick(); await _say_it()


func _lookout_tests() -> void:
	# a good answer at the right place: he leaves, and you look less suspicious
	await _talk_now(Vector3(6.2, 0, -1.75)); suspicion = 0.6
	await _answer(["ticket", "buy"])
	_check(last_result.kind == "good" and "p_s_ticket_buy" in played and g_mode == "patrol" and not talk_ui.visible and suspicion < 0.3,
		"표 사요 at the ticket machine: he believes you and leaves (%.2f)" % suspicion)
	_check(g_cd > 20.0, "and then leaves you alone for a while")
	# a good answer far from the machine: he points, and watches you go
	await _talk_now(Vector3(0.5, 0, 4.0))
	await _answer(["drink", "buy"])
	_check(g_mode == "watch" and "g_there_1" in played and goal.text.contains("음료"), "음료 사요 far from the drinks: 음료는 저기 있어요, he watches you go")
	await _put(Vector3(-4.0, 0, 3.7)); await _secs(0.2)
	_check(g_mode == "patrol" and "g_ok" in played, "going there satisfies him")
	await _talk_now(Vector3(0.5, 0, 4.0)); suspicion = 0.3
	await _answer(["map", "look"]); watch_t = 0.05; await _secs(0.2)
	_check(g_mode == "patrol" and suspicion > 0.45 and "g_odd" in played, "not going makes him more suspicious (%.2f)" % suspicion)
	# nonsense: he doesn't get it and asks again; twice and he walks off suspicious
	await _talk_now(Vector3(0.5, 0, 4.0)); suspicion = 0.2
	await _answer(["friend", "buy"])
	_check(last_result.kind == "weird" and talk_ui.visible and "g_huh" in played and said_label.text.contains("buying a friend") and absf(suspicion - 0.4) < 0.01,
		"친구 사요: he's confused, you see you said \"I'm buying a friend\", one more go")
	await _answer(["train", "look"])
	_check(not talk_ui.visible and g_mode == "patrol" and absf(suspicion - 0.7) < 0.01, "a second bit of nonsense and he walks off suspicious")
	await _shot("7_nonsense")
	# broken but understandable
	await _talk_now(Vector3(0.5, 0, 4.0))
	await _answer(["wait", "friend"])
	_check(last_result.kind == "order" and "g_help_friend_wait" in played and said_label.text.begins_with("In Korean the action goes last"), "기다려요 친구: he gets it, and you learn the verb goes last")
	await _talk_now(Vector3(0.5, 0, 4.0))
	await _answer(["train"])
	_check(last_result.kind == "noun" and "g_help_train_wait" in played and said_label.text.contains("지하철 기다려요"), "just 지하철: he finishes it for you (지하철 기다려요?)")
	await _talk_now(Vector3(0.5, 0, 4.0))
	await _answer(["buy"])
	_check(last_result.kind == "verb" and "g_whatobj" in played and talk_ui.visible and picked.is_empty(), "just 사요: 뭐를요? and you try again")
	# a second question
	await _talk_now(Vector3(0.5, 0, 4.0)); followup = 1
	await _answer(["friend", "wait"])
	_check(q_id == "where" and "g_where" in played and talk_ui.visible, "sometimes he asks a second thing: 어디 가세요?")
	await _answer(["home", "go"])
	_check(not talk_ui.visible and "g_ok2" in played and "p_s_home_go" in played, "집에 가요: 네, 조심히 가세요")
	# too slow
	await _talk_now(Vector3(0.5, 0, 4.0)); suspicion = 0.2
	patience = 0.05; await _secs(0.3)
	_check("g_hey" in played and suspicion > 0.3 and talk_ui.visible, "taking too long: 저기요? (%.2f)" % suspicion)
	# I can't say it: always gets you through, at a price, and you get a piece of Korean for next time
	var costs := []
	for roll in [0.0, 0.5, 0.95]:
		await _talk_now(Vector3(0.5, 0, 4.0)); suspicion = 0.2; english_roll = roll
		_cant_say(); await get_tree().process_frame
		if roll == 0.0: _check(tile_box.get_child_count() == IDEAS.size() + 1, "I can't say it shows ideas in English")
		await _english("ticket")
		costs.append(snappedf(suspicion - 0.2, 0.01))
		if roll == 0.0: await _shot("8_english")
	_check(costs == [0.4, 0.25, 0.1] and not talk_ui.visible and toast.text.contains("표"), "acting it out goes badly, awkwardly or luckily %s, and the handler gives you the word" % str(costs))
	await _talk_now(Vector3(0.5, 0, 4.0)); english_roll = 0.2
	picked = ["ticket"]; await _english("ticket")
	_check(last_result.tier == 1, "trying some Korean first makes the English go better")
	# third time
	await _talk_now(Vector3(0.5, 0, 4.0), 2)
	for i in 300:
		await get_tree().process_frame
		if "g_what" in played: break
	_check("g_again" in played and cant_btn.disabled, "the third time: 또 당신이에요? and no English way out")
	await _answer(["friend", "buy"])
	_check(state == "caught", "and nonsense then gets you caught")
	freeze_guard = false


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
	_check(paths_ok and close >= 5, "commuters walk around things, and often close past the two (%d/30)" % close)
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
	_open(wrong[0]); _check(state == "play" and suspicion < 0.15 and g_mode == "patrol", "one wrong locker is fine")
	_open(wrong[1]); _check(state == "play" and suspicion > 0.25 and g_mode == "patrol", "a second one draws looks")
	_open(wrong[2]); _check(g_mode == "approach" and alert.visible, "a third one brings the lookout over")
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
	await _put(guard.position + (-guard.global_transform.basis.z * Vector3(1, 0, 1)).normalized() * 2.5)
	for i in 80:
		await _secs(0.1)
		if g_mode == "talk": break
	_check(state == "play" and g_mode == "talk" and talk_ui.visible, "in the lookout's view he comes over to question you, not catch you")
	await _secs(0.5)
	_check("g_what" in played and q_label.text == QS.what.ko and tile_box.get_child_count() == 8, "he asks 뭐 하세요? and you get 8 words to answer with")
	await _secs(3.0)
	_check(gloss.visible, "the English for his question shows up after a moment")
	await _shot("6_questioned")
	await _lookout_tests()
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
