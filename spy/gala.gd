extends Node3D
## Feature 2: the gala room. A penthouse party: about nine people mingle, chat, come and go. You walk around and
## listen. Nobody wears a name tag, and your handler doesn't know their faces either. When you think you know who
## someone is, stand next to them and mark them on your phone. Nobody tells you if you're right: you find out in the
## debrief, after you leave by the lift. Linger by a group and they notice you: some ask who you are (answer with your
## cover pieces), some just glance and carry on. Each person remembers how that went.

const Cover = preload("res://cover.gd")
const SPEED := 3.6
const CAM_OFF := Vector3(0, 15.0, 9.5)
const ROOM := Vector2(20, 14)
const READ := 1.6                # right beside them: you can make out the words (Korean only, never English)
const NOTICE := 2.0              # stand this close to a group for a moment and they notice you
const LINGER := 2.0
const TAG_RANGE := 2.6
const START := Vector3(-6.0, 0, 5.4)
const ELEVATOR := Vector3(-6.0, 0, 6.2)
const ROLES := ["host", "broker", "assistant", "security", "bartender"]
const ROLE_NAME := {"host": ["Host", "김 대표님"], "broker": ["Broker", "최 사장님"], "assistant": ["Assistant", "윤 비서"],
	"security": ["Head of security", "팀장님"], "bartender": ["Bartender", "바텐더"]}
const FEMALE := ["assistant", "bartender", "g1", "g4", "g6"]
const TALKERS := ["host", "broker", "assistant", "g1", "g2", "g3", "g4", "g5", "g6"]
const LINES := {
	"h1": ["김 대표님, 초대해 주셔서 감사해요.", "CEO Kim, thanks for inviting me."],
	"h2": ["와 주셔서 감사합니다. 즐거운 시간 보내세요.", "Thanks for coming. Have a good time."],
	"h3": ["대표님, 파티 정말 멋져요!", "Sir, the party is amazing!"],
	"b1": ["사장님, 손님이 기다리세요.", "Boss, a guest is waiting for you."],
	"b2": ["최 사장님, 요즘 사업은 어떠세요?", "President Choi, how's business these days?"],
	"b3": ["사장님, 방 준비됐습니다.", "Boss, the room is ready."],
	"a1": ["윤 비서, 물 좀 갖다줘요.", "Secretary Yoon, get me some water."],
	"a2": ["네, 최 사장님 비서입니다.", "Yes, this is President Choi's secretary."],
	"s1": ["경호팀, 이상 없습니다.", "Security team: all clear."],
	"s2": ["팀장님, 엘리베이터 좀 봐 주세요.", "Team leader, keep an eye on the elevator, please."],
	"t1": ["저기요, 와인 한 잔 주세요.", "Excuse me, a glass of wine, please."],
	"t2": ["뭐 드릴까요?", "What can I get you?"],
	"r_yes": ["네, 알겠습니다.", "Yes, understood."], "r_thanks": ["감사합니다.", "Thank you."],
	"r_good": ["덕분에 좋아요.", "Good, thanks for asking."], "r_wine": ["네, 여기 있습니다.", "Here you are."],
	"sq_cold": ["오늘 날씨 춥네요.", "It's cold today."], "sa_cold": ["네, 진짜 추워요.", "Yes, really cold."],
	"sq_food": ["음식 맛있어요?", "Is the food good?"], "sa_food": ["네, 진짜 맛있어요.", "Yes, really good."],
	"sq_view": ["여기 경치 좋네요.", "The view is great up here."], "sa_view": ["네, 서울이 다 보여요.", "Yes, you can see all of Seoul."],
	"sq_busy": ["요즘 바빠요?", "Busy these days?"], "sa_busy": ["네, 좀 바빠요.", "Yes, a bit."],
	"sq_wine": ["이 와인 비싸요?", "Is this wine expensive?"], "sa_wine": ["아마 비쌀 거예요.", "Probably."],
	"sq_know": ["누구 알아요?", "Know anyone here?"], "sa_know": ["아니요, 아무도 몰라요.", "No, nobody."],
}
const SMALL := ["cold", "food", "view", "busy", "wine", "know"]
const HANDLER := {"h_in": "You're in. We know their titles, not their faces. Listen, and mark who's who on your phone.",
	"h_out": "Okay, we're out. Let's see what you got."}
const ASKERS := ["host", "broker", "assistant", "g1", "g2", "g3", "g4", "g5", "g6"]   # who might ask who you are
const REACT := {"ok": ["아, 반갑습니다.", "Ah, nice to meet you."], "again": ["네? 다시 한 번요?", "Sorry? Once more?"], "cool": ["아... 네.", "Ah... right."]}
const SPOTS := {   # where people gather
	"bar": Vector3(6.6, 0, -1.0), "buffet": Vector3(-4.0, 0, -1.6), "window_l": Vector3(-5.5, 0, -5.3), "window_r": Vector3(1.0, 0, -5.3),
	"balcony": Vector3(6.5, 0, -5.3), "lounge": Vector3(3.6, 0, 3.6), "middle": Vector3(-0.6, 0, 1.2), "door": Vector3(-8.3, 0, 2.5),
	"elevator": Vector3(-6.0, 0, 4.6),
}
const GUEST_SPOTS := ["bar", "buffet", "window_l", "window_r", "balcony", "lounge", "middle"]

var test := false
var people: Array = []          # {id, role, body, look, audio, ko, en, tag, spot, slot, timer, busy, leaving, gone}
var slots_taken := {}           # "spot:i" -> person id
var clock := 0.0
var talk_cd := 3.0
var talks := 0                  # conversations going right now
var talk_count := 0
var recent: Array = []          # kinds of conversation lately, so the same one doesn't come round again at once
var played: Array = []
var arrivals := [[35.0, "g5"], [70.0, "g6"]]
var leave_at := 0.0
var clips := {}
var player: CharacterBody3D
var body_mesh: Node3D
var phone_prop: MeshInstance3D
var cam: Camera3D
var hvoice: AudioStreamPlayer
var guesses := {}               # role -> the id of whoever you marked as that
var done := false
var linger_spot := ""            # the group you're standing by, and for how long
var linger_t := 0.0
var reacted := {}                # groups that already reacted to you this time you came over
var reactions: Array = []        # (tester) what groups did: ask, glance, ignore, cold
var asking := {}                 # whoever is waiting for your answer
var ask_fact := {}
var ask_q := 0
var ask_tries := 0
var ask_t := 0.0
var ask_phone := false           # you checked your phone while they waited
var ask_busy := false
var ask_group: Array = []
var picked: Array = []
var me_voice: AudioStreamPlayer
var phone_open := false
var last_handler := ""
var ring: MeshInstance3D          # under whoever your phone would point at
var hold := false                # (tester) everyone stays put
# screen
var goal: Label
var sub: Label
var sub_t := 0.0
var phone_btn: Button
var phone_ui: PanelContainer
var role_btns := {}
var leave_btn: Button
var ask_ui: PanelContainer
var ask_label: Label
var ans_label: Label
var tile_box: HBoxContainer
var say_btn: Button
var end_ui: PanelContainer
var end_text: Label
var joy_draw: Control
var joy_center := Vector2.ZERO
var joy_vec := Vector2.ZERO
var joy_touch := -1


func _ready() -> void:
	test = "--test" in OS.get_cmdline_user_args()
	randomize()
	hvoice = AudioStreamPlayer.new(); add_child(hvoice)
	me_voice = AudioStreamPlayer.new(); add_child(me_voice)
	_room()
	_screen()
	_cast()
	leave_at = randf_range(95.0, 130.0)
	if test: _run_test()
	else:
		await get_tree().create_timer(1.0).timeout
		_handler("h_in")


func _clip(id: String) -> AudioStream:
	if not clips.has(id): clips[id] = load("res://voice/gala/%s.mp3" % id)
	return clips[id]


func _mine(id: String) -> AudioStream:   # your own voice (Daniel), from the car
	if not clips.has("me_" + id): clips["me_" + id] = load("res://voice/cover/%s.mp3" % id)
	return clips["me_" + id]


func _vk(p: Dictionary) -> String:   # whose voice: guests by name, everyone else by role
	return p.id if p.role == "guest" else p.role


# ---------------------------------------------------------------- the penthouse

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; return m


func _box(pos: Vector3, size: Vector3, c: Color, solid := true) -> Node3D:
	var n: Node3D
	if solid:
		var b := StaticBody3D.new(); b.collision_layer = 1; b.collision_mask = 0
		var s := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; s.shape = sh; b.add_child(s); n = b
	else: n = Node3D.new()
	n.position = pos + Vector3(0, size.y / 2, 0)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = _mat(c); n.add_child(mi)
	add_child(n); return n


func _glow(pos: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.position = pos + Vector3(0, size.y / 2, 0)
	var m := _mat(c); m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = 1.2; mi.material_override = m; add_child(mi)


func _sign(text: String, size: int, pos: Vector3, parent: Node3D) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font_size = size; l.pixel_size = 0.006; l.outline_size = size / 5
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.position = pos; l.no_depth_test = true; parent.add_child(l); return l


func _room() -> void:
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.03, 0.04, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.85, 0.78, 0.7); e.ambient_light_energy = 0.75
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-65), deg_to_rad(20), 0); sun.light_energy = 0.6; sun.shadow_enabled = true; add_child(sun)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = ROOM; fl.mesh = pm; fl.material_override = _mat(Color(0.55, 0.5, 0.45)); add_child(fl)
	_box(Vector3(3.6, 0, 3.6), Vector3(4.2, 0.02, 3.4), Color(0.45, 0.2, 0.2), false)                      # rug in the lounge
	var hw := ROOM.x / 2; var hd := ROOM.y / 2; var wc := Color(0.18, 0.18, 0.22)
	_box(Vector3(0, 0, -hd), Vector3(ROOM.x, 1.4, 0.3), wc)
	_box(Vector3(-8.4, 0, hd), Vector3(3.2, 1.4, 0.3), wc); _box(Vector3(2.4, 0, hd), Vector3(15.2, 1.4, 0.3), wc)   # a gap for the lift
	_box(Vector3(-hw, 0, 0), Vector3(0.3, 1.4, ROOM.y), wc); _box(Vector3(hw, 0, 0), Vector3(0.3, 1.4, ROOM.y), wc)
	for i in 9:   # the city through the windows
		_glow(Vector3(-8.5 + i * 2.1, 1.4, -hd - 0.05), Vector3(1.8, 0.12, 0.12), Color(1.0, 0.8, 0.45))
		_glow(Vector3(-8.5 + i * 2.1 + randf_range(-0.5, 0.5), 1.6, -hd - 0.4), Vector3(0.2, 0.2, 0.2), Color(0.6, 0.8, 1.0))
	_box(Vector3(-6.0, 0, hd + 0.05), Vector3(1.6, 1.9, 0.2), Color(0.6, 0.6, 0.65))                       # elevator doors
	_sign("엘리베이터", 60, Vector3(-6.0, 2.3, hd), self)
	_box(Vector3(-hw + 0.1, 0, 2.5), Vector3(0.2, 1.9, 1.3), Color(0.35, 0.22, 0.14), false)               # the back room's door, shut
	_box(Vector3(8.2, 0, -1.0), Vector3(0.8, 1.1, 4.2), Color(0.25, 0.15, 0.1))                             # bar
	for i in 6: _glow(Vector3(9.6, 1.2, -2.8 + i * 0.7), Vector3(0.12, 0.35, 0.12), Color(0.5, 0.9, 0.6) if i % 2 else Color(0.9, 0.5, 0.3))
	_box(Vector3(-4.0, 0, -1.6), Vector3(3.0, 0.9, 1.0), Color(0.9, 0.9, 0.88))                             # buffet
	_box(Vector3(2.0, 0, 3.6), Vector3(0.9, 0.6, 2.6), Color(0.3, 0.3, 0.35)); _box(Vector3(5.2, 0, 3.6), Vector3(0.9, 0.6, 2.6), Color(0.3, 0.3, 0.35))   # sofas
	_box(Vector3(3.6, 0, 3.6), Vector3(1.0, 0.4, 1.0), Color(0.2, 0.15, 0.12))                              # low table
	for p in [Vector3(-8.8, 0, -6.2), Vector3(9.0, 0, -6.2), Vector3(-1.5, 0, -6.2)]: _box(p, Vector3(0.6, 1.2, 0.6), Color(0.2, 0.45, 0.25))   # plants
	player = CharacterBody3D.new(); player.collision_layer = 4; player.collision_mask = 1; add_child(player)
	var ps := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.5; ps.shape = cap; ps.position.y = 0.75; player.add_child(ps)
	body_mesh = _look(Color(0.25, 0.5, 0.95)); player.add_child(body_mesh)
	phone_prop = MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(0.14, 0.03, 0.24); phone_prop.mesh = pb
	var pmat := _mat(Color(0.4, 0.8, 1.0)); pmat.emission_enabled = true; pmat.emission = Color(0.3, 0.6, 0.9); phone_prop.material_override = pmat
	phone_prop.position = Vector3(0, 1.05, -0.4); phone_prop.visible = false; body_mesh.add_child(phone_prop)
	var ear := AudioListener3D.new(); ear.position.y = 1.5; player.add_child(ear); ear.make_current()   # you hear from where you stand
	player.position = START
	ring = MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.42; tm.outer_radius = 0.55; ring.mesh = tm
	var rm := _mat(Color(1, 0.85, 0.3)); rm.emission_enabled = true; rm.emission = Color(1, 0.75, 0.2); rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm; ring.visible = false; add_child(ring)
	cam = Camera3D.new(); cam.fov = 34; add_child(cam); cam.position = START + CAM_OFF; cam.look_at(START, Vector3.UP)


func _look(c: Color) -> Node3D:   # a grey-box person
	var n := Node3D.new()
	var mi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.3; cm.height = 1.5
	mi.mesh = cm; mi.position.y = 0.75; mi.material_override = _mat(c); n.add_child(mi)
	var nose := MeshInstance3D.new(); var nb := BoxMesh.new(); nb.size = Vector3(0.18, 0.13, 0.28)
	nose.mesh = nb; nose.position = Vector3(0, 1.2, -0.3); nose.material_override = _mat(c.darkened(0.55)); n.add_child(nose)
	return n


# ---------------------------------------------------------------- the people

func _cast() -> void:
	var looks := {"host": Color(0.85, 0.85, 0.82), "broker": Color(0.12, 0.12, 0.14), "assistant": Color(0.2, 0.25, 0.4),
		"security": Color(0.14, 0.15, 0.16), "bartender": Color(0.95, 0.95, 0.95), "g1": Color(0.7, 0.2, 0.3), "g2": Color(0.3, 0.3, 0.5),
		"g3": Color(0.5, 0.4, 0.25), "g4": Color(0.6, 0.5, 0.7), "g5": Color(0.25, 0.45, 0.4), "g6": Color(0.8, 0.6, 0.3)}
	for id in ["host", "broker", "assistant", "security", "bartender", "g1", "g2", "g3", "g4"]:
		_spawn(id, looks[id], false)
	set_meta("looks", looks)


func _spawn(id: String, c: Color, late: bool) -> Dictionary:
	var b := CharacterBody3D.new(); b.collision_layer = 8; b.collision_mask = 1; add_child(b)
	var s := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.28; cap.height = 1.5; s.shape = cap; s.position.y = 0.75; b.add_child(s)
	var look := _look(c); b.add_child(look)
	var au := AudioStreamPlayer3D.new(); au.position.y = 1.5; au.unit_size = 2.4; au.max_distance = 18.0; au.max_db = 2.0
	au.attenuation_filter_cutoff_hz = 2500.0; au.attenuation_filter_db = -30.0; b.add_child(au)   # far voices go muffled
	var ko := _sign("", 40, Vector3(0, 2.4, 0), b)
	var tag := _sign("", 30, Vector3(0, -0.15, 0), b); tag.modulate = Color(1, 0.85, 0.3); tag.visible = false
	var role := id if id in ROLES else "guest"
	var p := {"id": id, "role": role, "body": b, "look": look, "audio": au, "ko": ko, "tag": tag, "spot": "", "slot": -1,
		"timer": randf_range(2.0, 12.0), "busy": false, "leaving": false, "gone": false, "glance": 0.0,
		"pic": {"met": false, "told": [], "ok": false, "wary": false}}   # their picture of you
	people.append(p)
	if late:
		b.position = ELEVATOR; _go(p, "elevator")
		p.timer = randf_range(3.0, 5.0)
	elif id == "bartender":
		b.position = Vector3(9.1, 0, -1.0); p.spot = "bar"; p.slot = 9; p.timer = INF
	else:
		var sp: String = _pick_spot(p)
		_go(p, sp); b.position = _slot_pos(sp, p.slot)
	return p


func _slot_pos(spot: String, i: int) -> Vector3:
	if spot == "bar":   # along the front of the counter
		return Vector3(7.1, 0, -2.4 + i * 0.9) if i < 4 else Vector3(9.1, 0, -1.0)
	var r := 1.15 if spot == "buffet" else 0.85
	if spot == "buffet":   # on the open sides of the table
		return SPOTS.buffet + [Vector3(-2.1, 0, 0), Vector3(2.1, 0, 0), Vector3(-0.8, 0, 1.0), Vector3(0.8, 0, 1.0)][i]
	if spot == "lounge":   # between the sofas
		return SPOTS.lounge + [Vector3(0, 0, -1.6), Vector3(0, 0, 1.6), Vector3(-0.9, 0, -1.7), Vector3(0.9, 0, 1.7)][i]
	return SPOTS[spot] + Vector3(r, 0, 0).rotated(Vector3.UP, PI / 4 + i * PI / 2)


func _go(p: Dictionary, spot: String) -> void:
	slots_taken.erase("%s:%d" % [p.spot, p.slot])
	var free := -1
	for i in 4:
		if not slots_taken.has("%s:%d" % [spot, i]): free = i; break
	if free == -1: return   # full: stay put
	p.spot = spot; p.slot = free; slots_taken["%s:%d" % [spot, free]] = p.id


func _at(p: Dictionary) -> bool:
	return Vector2(p.body.position.x, p.body.position.z).distance_to(Vector2(_slot_pos(p.spot, p.slot).x, _slot_pos(p.spot, p.slot).z)) < 0.25


func _find(id: String) -> Dictionary:
	for p in people:
		if p.id == id and not p.gone: return p
	return {}


func _pick_spot(p: Dictionary) -> String:   # where each kind of person wants to be next
	var br := _find("broker")
	match p.role:
		"host":   # works the room: goes where the guests are
			var best := ""; var most := -1
			for sp in GUEST_SPOTS:
				var n := 0
				for o in people:
					if not o.gone and o.spot == sp and o.role == "guest": n += 1
				if sp != p.spot and n > most and _has_room(sp): best = sp; most = n
			return best if best != "" else "middle"
		"broker": return ["lounge", "window_r", "balcony", "middle"].filter(func(s): return s != p.spot and _has_room(s)).pick_random()
		"assistant": return br.spot if br and _has_room(br.spot, p) else p.spot
		"security":
			var opts := ["door", "elevator"]
			if br: opts.append(br.spot)
			opts = opts.filter(func(s): return s != p.spot and _has_room(s))
			return opts.pick_random() if opts else p.spot
	var g := GUEST_SPOTS.filter(func(s): return s != p.spot and _has_room(s))
	return g.pick_random() if g else p.spot


func _has_room(spot: String, me: Dictionary = {}) -> bool:
	if spot == "": return false
	for i in 4:
		var who = slots_taken.get("%s:%d" % [spot, i], "")
		if who == "" or (me and who == me.id): return true
	return false


func _walk(p: Dictionary, dt: float) -> void:   # straight there, or veer round whatever's in the way
	var b: CharacterBody3D = p.body
	var to := _slot_pos(p.spot, p.slot) - b.position; to.y = 0
	if to.length() < 0.2:
		b.velocity = Vector3.ZERO
		var c: Vector3 = SPOTS[p.spot] if p.spot != "bar" else Vector3(8.0, 0, b.position.z)
		if p.id == "bartender": c = Vector3(7.1, 0, -1.0)
		var d := c - b.position
		var mine := player.position - b.position; mine.y = 0
		if p.glance > 0.0: d = mine                                                   # a look at you
		elif p.glance < 0.0 or (p.pic.wary and mine.length() < 3.5): d = -mine        # their back to you
		if d.length() > 0.1: b.rotation.y = lerp_angle(b.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-5.0 * dt))
		return
	var dir := to.normalized()
	for a in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.1, -2.1]:
		var dd := dir.rotated(Vector3.UP, a)
		if not b.test_move(b.global_transform, dd * 0.4): dir = dd; break
	b.velocity = dir * minf(1.4, to.length() / dt); b.move_and_slide(); b.position.y = 0
	b.rotation.y = lerp_angle(b.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * dt))


func _people(dt: float) -> void:
	for p in people.duplicate():
		if p.gone: continue
		p.glance = maxf(0.0, p.glance - dt) if p.glance > 0.0 else minf(0.0, p.glance + dt)
		if not p.busy: _walk(p, dt)
		if p.leaving and p.spot == "elevator" and _at(p):   # into the lift and gone
			p.gone = true; slots_taken.erase("%s:%d" % [p.spot, p.slot]); p.body.queue_free(); continue
		if p.busy or not _at(p): continue
		p.timer -= dt
		if p.timer <= 0.0:
			var sp := _pick_spot(p)
			if sp != p.spot: _go(p, sp)
			p.timer = {"host": randf_range(16, 26), "broker": randf_range(28, 42), "assistant": 3.0, "security": randf_range(18, 30)}.get(p.role, randf_range(22, 40))
	for a in arrivals.duplicate():   # late arrivals step out of the lift, and the host goes to greet them
		if clock >= a[0]:
			arrivals.erase(a); var np := _spawn(a[1], get_meta("looks")[a[1]], true)
			var h := _find("host")
			if h and not h.busy and _has_room("elevator", h): _go(h, "elevator"); h.timer = 14.0
	if leave_at > 0.0 and clock >= leave_at:   # someone calls it a night
		leave_at = -1.0
		var gs := people.filter(func(o): return not o.gone and o.role == "guest" and not o.busy)
		if gs: _leave(gs.pick_random())


func _leave(p: Dictionary) -> void:
	p.leaving = true; p.timer = INF
	slots_taken.erase("%s:%d" % [p.spot, p.slot])
	p.spot = "elevator"; p.slot = 3 if not slots_taken.has("elevator:3") else 2


# ---------------------------------------------------------------- what they say to each other

func _together() -> Dictionary:   # who's standing with whom right now
	var g := {}
	for p in people:
		if p.gone or p.busy or p.leaving or not _at(p): continue
		if not g.has(p.spot): g[p.spot] = []
		g[p.spot].append(p)
	return g


func _who(members: Array, roles: Array) -> Array:
	return members.filter(func(m): return (m.role in roles) or (m.id in roles))


func _options() -> Array:   # every conversation that could start now: [kind, [[person, line], ...]]
	var out := []
	var gs := _together()
	for spot in gs:
		var m: Array = gs[spot]
		var guests := _who(m, ["guest"]); var host := _who(m, ["host"]); var br := _who(m, ["broker"])
		var asst := _who(m, ["assistant"]); var sec := _who(m, ["security"]); var bt := _who(m, ["bartender"])
		var talkers := m.filter(func(x): return x.id in TALKERS)
		# business stays private: not with a stranger standing right there, unless he or his people have taken to you
		var stranger: bool = player.position.distance_to(SPOTS[spot]) < 4.0 and not (br and br[0].pic.ok) and not (asst and asst[0].pic.ok)
		if talkers.size() >= 2:
			talkers.shuffle(); var t: String = SMALL.pick_random()
			out.append(["small", [[talkers[0], "sq_" + t], [talkers[1], "sa_" + t]]])
		if host and guests:
			var g = guests.pick_random()
			if randf() < 0.5: out.append(["host", [[g, ["h1", "h3"].pick_random()], [host[0], "r_thanks"]]])
			else: out.append(["host", [[host[0], "h2"], [g, "r_thanks"]]])
		if br and (guests or host):
			out.append(["broker", [[(guests + host).pick_random(), "b2"], [br[0], "r_good"]]])
		if br and asst and not stranger: out.append(["boss", [[asst[0], "b1"], [br[0], "a1"], [asst[0], "r_yes"]]])
		if br and sec and not stranger: out.append(["room", [[sec[0], "b3"], [br[0], "r_yes"]]])
		if host and sec: out.append(["hostsec", [[host[0], "s2"], [sec[0], "r_yes"]]])
		if bt and guests:
			var g2 = guests.pick_random()
			if randf() < 0.5: out.append(["bar", [[bt[0], "t2"], [g2, "t1"], [bt[0], "r_wine"]]])
			else: out.append(["bar", [[g2, "t1"], [bt[0], "r_wine"]]])
		if asst: out.append(["phone", [[asst[0], "a2"]]])
		if sec: out.append(["radio", [[sec[0], "s1"]]])
	return out


func _maybe_talk() -> void:
	if talks >= 2: return
	var opts := _options()
	if opts.is_empty(): return
	var fresh := opts.filter(func(o): return o[0] != "small" and not (o[0] in recent))
	var smalls := opts.filter(func(o): return o[0] == "small")
	var pick: Array
	if fresh and (randf() < 0.45 or smalls.is_empty()): pick = fresh.pick_random()
	elif smalls: pick = smalls.pick_random()
	else: pick = opts.pick_random()
	recent.append(pick[0])
	if recent.size() > 3: recent.pop_front()
	_talk(pick[0], pick[1])


func _talk(kind: String, lines: Array) -> void:
	talks += 1; talk_count += 1
	var who := []
	for l in lines:
		if not l[0] in who: who.append(l[0])
	for p in who: p.busy = true
	for l in lines:
		var p: Dictionary = l[0]
		if p.gone: break
		for o in who:   # face whoever's speaking (the speaker faces the group)
			if o != p:
				var d: Vector3 = p.body.position - o.body.position
				o.body.rotation.y = atan2(-d.x, -d.z)
		if who.size() > 1:
			var other: Dictionary = who[1] if who[0] == p else who[0]
			var d2: Vector3 = other.body.position - p.body.position
			p.body.rotation.y = atan2(-d2.x, -d2.z)
		var voice_id: String = _vk(p) + "_" + l[1]
		p.audio.stream = _clip(voice_id); p.audio.play(); played.append(voice_id)
		p["line"] = l[1]
		await get_tree().process_frame
		while is_instance_valid(p.body) and p.audio.playing: await get_tree().process_frame
		p["line"] = ""
		await get_tree().create_timer(0.45).timeout
	for p in who: p.busy = false
	talks -= 1


# ---------------------------------------------------------------- every frame

func _physics_process(dt: float) -> void:
	clock += dt
	if not hold: _people(dt)
	else:   # (tester) nobody walks off, but they still turn to look
		for p in people:
			if p.gone or p.busy: continue
			p.glance = maxf(0.0, p.glance - dt) if p.glance > 0.0 else minf(0.0, p.glance + dt)
			if _at(p): _walk(p, dt)
	if done: return
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


func _process(dt: float) -> void:
	var focus := player.position + (Vector3(3.4, 0, 0) if phone_open else Vector3.ZERO)   # the phone covers the right: keep you in view
	cam.position = cam.position.lerp(focus + CAM_OFF, 1.0 - exp(-6.0 * dt)); cam.look_at(cam.position - CAM_OFF, Vector3.UP)
	talk_cd -= dt
	if talk_cd <= 0.0:
		_maybe_talk(); talk_cd = randf_range(1.5, 3.5)
	for p in people:   # right beside them you can make out the words (in Korean); otherwise you only hear them
		if p.gone: continue
		var line: String = p.get("line", "")
		var d := player.position.distance_to(p.body.position)
		var said: String = p.get("said", "")
		if d >= READ: p.ko.text = ""
		elif line != "" and LINES.has(line): p.ko.text = LINES[line][0]
		else: p.ko.text = said
		p.audio.volume_db = -12.0 if p.pic.wary and d < 4.5 else 0.0   # wary of you: they lower their voices
	sub_t -= dt
	if sub_t <= 0.0: sub.text = ""
	goal.text = "Marked: %d of 5" % guesses.size()
	var n := _nearest() if phone_open and not done else {}
	ring.visible = not n.is_empty()
	if ring.visible: ring.position = n.body.position + Vector3(0, 0.05, 0)
	for r in role_btns: role_btns[r].disabled = n.is_empty()
	leave_btn.visible = not done and asking.is_empty() and player.position.z > 6.1 and absf(player.position.x + 6.0) < 0.9
	if done: return
	_linger(dt)
	if not asking.is_empty():
		var who: Dictionary = asking
		if player.position.distance_to(who.body.position) > 3.2: _ask_end("walked")      # walking off mid-question
		elif not ask_busy:
			ask_t -= dt
			if ask_t <= 0.0: _ask_end("silent")


# ---------------------------------------------------------------- the screen

func _label(size: int) -> Label:
	var l := Label.new(); l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 8); l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8)); return l


func _btn(text: String, size: int, min: Vector2) -> Button:
	var b := Button.new(); b.text = text; b.add_theme_font_size_override("font_size", size); b.custom_minimum_size = min; return b


func _style(a := 0.95) -> StyleBoxFlat:
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.06, 0.07, 0.1, a); st.set_corner_radius_all(14); st.set_content_margin_all(16); return st


func _screen() -> void:
	var ui := CanvasLayer.new(); add_child(ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	joy_draw = Control.new(); joy_draw.set_anchors_preset(Control.PRESET_FULL_RECT); joy_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(joy_draw)
	joy_draw.draw.connect(_draw_joy)
	goal = _label(26); goal.position = Vector2(24, 20); root.add_child(goal)
	sub = _label(26); sub.anchor_left = 0.5; sub.anchor_right = 0.5; sub.anchor_top = 1; sub.anchor_bottom = 1
	sub.offset_left = -420; sub.offset_right = 420; sub.offset_top = -80; sub.offset_bottom = -40
	sub.custom_minimum_size = Vector2(840, 0); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(sub)
	phone_btn = _btn("Phone", 26, Vector2(150, 70)); phone_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	phone_btn.position = Vector2(-174, 20); root.add_child(phone_btn); phone_btn.pressed.connect(_toggle_phone)
	phone_ui = PanelContainer.new(); phone_ui.add_theme_stylebox_override("panel", _style(0.97)); root.add_child(phone_ui)
	phone_ui.anchor_left = 1; phone_ui.anchor_right = 1; phone_ui.anchor_top = 0; phone_ui.anchor_bottom = 1
	phone_ui.offset_left = -520; phone_ui.offset_right = -16; phone_ui.offset_top = 100; phone_ui.offset_bottom = -16
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; phone_ui.add_child(sc)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 8); sc.add_child(box)
	var t := _label(28); t.text = "Who's who"; box.add_child(t)
	var h := _label(18); h.text = "Stand next to someone (they light up), then mark who you think they are. You can change it."; h.modulate = Color(0.8, 0.8, 0.8)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(h)
	for r in ROLES:
		var b := _btn("%s  ·  %s" % ROLE_NAME[r], 24, Vector2(0, 58)); b.pressed.connect(_tag.bind(r)); box.add_child(b); role_btns[r] = b
	var c := _label(22); c.text = "Your cover: Daniel Park"; c.modulate = Color(1, 0.8, 0.4); box.add_child(c)
	for f in Cover.FACTS:
		var k := _label(22); k.text = "%s   %s" % [f.ko, f.en]; k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(k)
	phone_ui.visible = false
	leave_btn = _btn("Leave", 30, Vector2(170, 80)); leave_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	leave_btn.position = Vector2(-85, -110); root.add_child(leave_btn); leave_btn.pressed.connect(_finish); leave_btn.visible = false
	_ask_screen(root)
	end_ui = PanelContainer.new(); end_ui.add_theme_stylebox_override("panel", _style()); end_ui.set_anchors_preset(Control.PRESET_CENTER)
	end_ui.custom_minimum_size = Vector2(640, 0); end_ui.position = Vector2(-320, -320); root.add_child(end_ui)
	var eb := VBoxContainer.new(); eb.add_theme_constant_override("separation", 18); end_ui.add_child(eb)
	end_text = _label(24); end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; eb.add_child(end_text)
	var again := _btn("Again", 30, Vector2(0, 80)); eb.add_child(again); again.pressed.connect(func(): get_tree().reload_current_scene())
	var car := _btn("Back to the car", 24, Vector2(0, 64)); eb.add_child(car); car.pressed.connect(func(): get_tree().change_scene_to_file("res://cover.tscn"))
	end_ui.visible = false


func _draw_joy() -> void:
	if joy_touch == -1: return
	joy_draw.draw_circle(joy_center, 90, Color(1, 1, 1, 0.12))
	joy_draw.draw_circle(joy_center + joy_vec * 90, 38, Color(1, 1, 1, 0.45))


func _input(ev: InputEvent) -> void:
	if done: return
	if ev is InputEventScreenTouch:
		var vs := get_viewport().get_visible_rect().size
		var on_panel: bool = ask_ui.visible and ev.position.y > vs.y - 330.0   # tapping your answer pieces isn't walking
		if ev.pressed and joy_touch == -1 and not on_panel and ev.position.x < vs.x * 0.45:
			joy_touch = ev.index; joy_center = ev.position; joy_vec = Vector2.ZERO
		elif not ev.pressed and ev.index == joy_touch:
			joy_touch = -1; joy_vec = Vector2.ZERO
		joy_draw.queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == joy_touch:
		joy_vec = ((ev.position - joy_center) / 90.0).limit_length(1.0); joy_draw.queue_redraw()


func _handler(id: String) -> void:
	hvoice.stream = _clip(id); hvoice.play(); played.append(id); last_handler = id
	sub.text = "Handler: " + HANDLER[id]; sub_t = 3.5


# ---------------------------------------------------------------- Who's who: say who someone is

func _toggle_phone() -> void:
	phone_open = not phone_open
	phone_ui.visible = phone_open; phone_prop.visible = phone_open
	if phone_open and not asking.is_empty(): ask_phone = true   # they're waiting, and they see you look it up
	phone_btn.text = "Put away" if phone_open else "Phone"
	sub.offset_left = -630.0 if phone_open else -420.0; sub.offset_right = sub.offset_left + 840.0   # out from under the phone
	create_tween().tween_property(body_mesh.get_child(0), "rotation:x", -0.35 if phone_open else 0.0, 0.25)


func _nearest() -> Dictionary:
	var best := {}; var bd := TAG_RANGE
	for p in people:
		if p.gone: continue
		var d := player.position.distance_to(p.body.position)
		if d < bd: best = p; bd = d
	return best


func _tag(role: String) -> void:   # your guess, nothing more: nobody tells you if it's right
	if done: return
	var p := _nearest()
	if p.is_empty(): return
	if guesses.has(role):   # moving a mark to someone else
		var old := _find(guesses[role])
		if old: old.tag.visible = false
	for r in guesses.keys():   # one mark per person
		if guesses[r] == p.id: guesses.erase(r); role_btns[r].text = "%s  ·  %s" % ROLE_NAME[r]
	guesses[role] = p.id
	p.tag.text = ROLE_NAME[role][1] + "?"; p.tag.visible = true
	role_btns[role].text = "%s  ·  %s   (marked)" % ROLE_NAME[role]


func _finish() -> void:   # into the lift: the debrief
	if done: return
	done = true
	if not asking.is_empty(): _ask_end("walked")
	if phone_open: _toggle_phone()
	leave_btn.visible = false
	sub.offset_left = -420.0; sub.offset_right = 420.0
	if not asking.is_empty() or ask_ui.visible: ask_ui.visible = false
	_handler("h_out")
	await get_tree().create_timer(1.2).timeout
	var t := "Debrief\n\n"
	var right := 0
	for r in ROLES:
		var line := "%s (%s): " % [ROLE_NAME[r][1], ROLE_NAME[r][0].to_lower()]
		if not guesses.has(r): line += "not marked"
		else:
			var p := _who_is(guesses[r])
			if p.role == r: line += "right"; right += 1
			else: line += "wrong, that was " + ("a guest" if p.role == "guest" else ROLE_NAME[p.role][1])
		t += line + "\n"
	var ok := people.filter(func(o): return o.pic.ok).size()
	var wary := people.filter(func(o): return o.pic.wary).size()
	t += "\n%d of 5 right. %d:%02d at the party.\n%d took to you, %d are wary of you." % [right, int(clock) / 60, int(clock) % 60, ok, wary]
	end_text.text = t
	end_ui.visible = true


func _who_is(id: String) -> Dictionary:   # anyone, even someone who's left
	for p in people:
		if p.id == id: return p
	return {}


# ---------------------------------------------------------------- they notice you

func _linger(dt: float) -> void:   # stay by a group for a moment and they react, each in their own way
	var near := ""
	if asking.is_empty():
		for p in people:
			if p.gone or p.leaving or p.spot == "elevator" or p.spot == "" or not _at(p): continue
			if player.position.distance_to(p.body.position) < NOTICE: near = p.spot; break
	if near != linger_spot: linger_spot = near; linger_t = 0.0
	elif near != "": linger_t += dt
	if near != "" and linger_t > LINGER and not reacted.has(near):
		reacted[near] = true; _react(near)
	for s in reacted.keys():   # walk away and come back: they can react again
		if player.position.distance_to(SPOTS[s]) > 4.0: reacted.erase(s)


func _react(spot: String) -> void:
	var m := people.filter(func(o): return not o.gone and not o.leaving and o.spot == spot)
	if m.is_empty(): return
	if m.any(func(o): return o.pic.wary):   # someone here has doubts about you: backs turn, voices drop
		for o in m: o.glance = -4.0
		reactions.append("cold"); return
	var fresh := m.filter(func(o): return not o.pic.met and o.id in ASKERS and not o.busy)
	var r := randf()
	if fresh and r < 0.45:
		_ask(fresh.pick_random(), m); reactions.append("ask"); return
	if fresh.is_empty() or r < 0.8:   # a look (or a nod, if they've met you), then back to their talk
		var lookers := m.filter(func(o): return not o.busy); lookers.shuffle()
		for o in lookers.slice(0, randi_range(1, 2)): o.glance = randf_range(1.2, 2.2)
		reactions.append("glance"); return
	reactions.append("ignore")   # they don't care who you are


func _ask(p: Dictionary, group: Array) -> void:   # "and who are you?"
	asking = p; ask_group = group; p.busy = true; ask_tries = 0; ask_phone = false
	var left := Cover.FACTS.filter(func(f): return not (f.k in p.pic.told))
	ask_fact = (left if left else Cover.FACTS).pick_random()
	ask_q = randi() % ask_fact.qs.size()
	var d: Vector3 = player.position - p.body.position
	p.body.rotation.y = atan2(-d.x, -d.z)
	for o in group:
		if o != p and not o.busy: o.glance = 3.0
	_question()


func _question() -> void:
	var p: Dictionary = asking
	ask_t = 15.0; picked.clear(); _show_pick()
	ask_label.text = ask_fact.qs[ask_q][0]
	var tiles := []
	for i in ask_fact.chunks.size(): tiles.append([ask_fact.k, i])
	tiles += [["yn", 0], ["yn", 1]]
	var others := Cover.FACTS.filter(func(o): return o.k != ask_fact.k); others.shuffle()
	for i in others[0].chunks.size(): tiles.append([others[0].k, i])
	var seen := {}; var deck := []
	for t in tiles:
		var tx: String = _chunk(t)[0]
		if not seen.has(tx): seen[tx] = 1; deck.append(t)
	deck.shuffle()
	for c in tile_box.get_children(): c.queue_free()
	for t in deck:   # Korean only in here
		var b := _btn(_chunk(t)[0].trim_prefix("~"), 26, Vector2(104, 80)); b.pressed.connect(_pick.bind(t)); tile_box.add_child(b)
	ask_ui.visible = true
	ask_busy = true
	await _line(p, "q_%s_%d" % [ask_fact.k, ask_q])
	ask_busy = false


func _line(p: Dictionary, id: String) -> void:   # one person says one line out loud, and you see it if you're close
	if p.gone: return
	var vid := _vk(p) + "_" + id
	p.audio.stream = _clip(vid); p.audio.play(); played.append(vid)
	p["said"] = ask_fact.qs[ask_q][0] if id.begins_with("q_") else REACT.get(id.trim_prefix("x_"), [""])[0]
	await get_tree().process_frame
	while is_instance_valid(p.body) and p.audio.playing: await get_tree().process_frame
	p["said"] = ""


func _ask_screen(root: Control) -> void:   # answering someone: build it from your cover pieces
	ask_ui = PanelContainer.new(); ask_ui.add_theme_stylebox_override("panel", _style(0.92)); root.add_child(ask_ui)
	ask_ui.anchor_left = 0; ask_ui.anchor_right = 1; ask_ui.anchor_top = 1; ask_ui.anchor_bottom = 1
	ask_ui.offset_left = 16; ask_ui.offset_right = -16; ask_ui.offset_top = -300; ask_ui.offset_bottom = -10
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); ask_ui.add_child(row)
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.add_theme_constant_override("separation", 10); row.add_child(left)
	var qrow := HBoxContainer.new(); qrow.add_theme_constant_override("separation", 14); left.add_child(qrow)
	ask_label = _label(38); ask_label.modulate = Color(0.75, 0.85, 1.0); qrow.add_child(ask_label)
	var hear := _btn("Hear", 22, Vector2(90, 54)); qrow.add_child(hear)
	hear.pressed.connect(_hear_q)
	var arow := HBoxContainer.new(); arow.add_theme_constant_override("separation", 14); left.add_child(arow)
	ans_label = _label(36); ans_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; arow.add_child(ans_label)
	var clr := _btn("Clear", 22, Vector2(100, 54)); arow.add_child(clr); clr.pressed.connect(func(): picked.clear(); _show_pick())
	tile_box = HBoxContainer.new(); tile_box.add_theme_constant_override("separation", 8); left.add_child(tile_box)
	say_btn = _btn("Say it", 34, Vector2(180, 120)); say_btn.size_flags_vertical = Control.SIZE_SHRINK_END; row.add_child(say_btn); say_btn.pressed.connect(_say_it)
	var gs := StyleBoxFlat.new(); gs.bg_color = Color(0.2, 0.55, 0.3); gs.set_corner_radius_all(10); say_btn.add_theme_stylebox_override("normal", gs)
	ask_ui.visible = false


func _fact(k: String) -> Dictionary:
	if k == "yn": return Cover.YN
	for f in Cover.FACTS:
		if f.k == k: return f
	return {}


func _chunk(t: Array) -> Array:
	return _fact(t[0]).chunks[t[1]]


func _pick(t: Array) -> void:
	if ask_busy or picked.size() >= 4: return
	picked.append(t); _show_pick()
	me_voice.stream = _mine("t_%s_%d" % t); me_voice.play()


func _joined(ts: Array) -> String:
	var s := ""
	for t in ts:
		var w: String = _chunk(t)[0]
		if w.begins_with("~"): s += w.substr(1)
		elif s == "": s = w
		else: s += " " + w
	return s


func _show_pick() -> void:
	if ans_label == null: return
	ans_label.text = _joined(picked) if picked else "Tap the pieces to answer"
	ans_label.modulate = Color.WHITE if picked else Color(1, 1, 1, 0.45)
	say_btn.disabled = picked.is_empty()


func _judge(p: Array, f: Dictionary) -> String:   # good · order · part · wrong (same rules as the car)
	var want := []
	for i in f.chunks.size(): want.append(_chunk([f.k, i])[0])
	var got := p.map(func(t): return _chunk(t)[0])
	if got.size() > 1 and (got[0] == "네" or (got[0] == "아니요" and f.get("yn", false))): got = got.slice(1)
	if got == want: return "good"
	if got.size() == want.size() and got.all(func(w): return w in want) and want.all(func(w): return w in got): return "order"
	if got.all(func(w): return w in want): return "part"
	return "wrong"


func _me(id: String) -> void:   # Daniel says it
	me_voice.stream = _mine(id); me_voice.play()
	await get_tree().process_frame
	while me_voice.playing: await get_tree().process_frame


func _say_it() -> void:
	if ask_busy or picked.is_empty() or asking.is_empty(): return
	ask_busy = true
	var who: Dictionary = asking
	var r := _judge(picked, ask_fact)
	if r == "good":
		if picked.size() > 1 and picked[0][0] == "yn": await _me("t_yn_%d" % picked[0][1])
		await _me("a_" + ask_fact.k)
	else:
		for t in picked: await _me("t_%s_%d" % t)
	if asking != who: return
	if r != "good" and r != "wrong" and ask_tries == 0:   # close: they didn't quite catch it
		ask_tries = 1
		await _line(who, "x_again")
		if asking == who: _question()
		return
	_ask_end("good" if r == "good" else "bad")


func _ask_end(how: String) -> void:   # how it went decides what they think of you, and they remember
	var who: Dictionary = asking
	if who.is_empty(): return
	asking = {}; ask_ui.visible = false; ask_busy = true
	var k: String = ask_fact.k
	for o in ask_group:   # they all heard it
		if o.gone: continue
		o.pic.met = true
		if how == "good" and not (k in o.pic.told): o.pic.told.append(k)
		if how == "good" and not ask_phone: o.pic.ok = true
		if how != "good": o.pic.wary = true; o.pic.ok = false
	reactions.append("answer_" + how)
	if how == "good": await _line(who, "x_ok" if not ask_phone else "x_cool")
	elif how != "walked": await _line(who, "x_cool")
	who.busy = false; ask_busy = false
	if how != "good":
		for o in ask_group: o.glance = -3.0   # they turn back to each other


func _hear_q() -> void:
	if not asking.is_empty() and not ask_busy: _line(asking, "q_%s_%d" % [ask_fact.k, ask_q])


# ---------------------------------------------------------------- the tester (godot gala.tscn -- --test)

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


func _beside(p: Dictionary) -> void:   # stand right next to someone, somewhere you actually fit
	for off in [Vector3(0, 0, 0.6), Vector3(0, 0, -0.6), Vector3(0.6, 0, 0), Vector3(-0.6, 0, 0), Vector3(0.45, 0, 0.45), Vector3(-0.45, 0, -0.45)]:
		await _put(p.body.position + off)
		if _nearest() == p: return


func _wait_free() -> void:   # until the person asking you has finished talking
	for i in 200:
		if not ask_busy: return
		await _secs(0.05)


func _right_pieces(f: Dictionary) -> Array:
	var r := []
	for i in f.chunks.size(): r.append([f.k, i])
	return r


func _reset_pics() -> void:
	for p in people: p.pic = {"met": false, "told": [], "ok": false, "wary": false}


func _guest_group() -> Array:   # a guest, and whoever's with them (everyone put in their places first)
	for o in people:
		if not o.gone and not o.leaving and o.slot >= 0 and o.id != "bartender": o.body.position = _slot_pos(o.spot, o.slot)
	var gs := people.filter(func(o): return o.role == "guest" and not o.gone and not o.leaving and o.spot != "elevator")
	gs.shuffle()
	var p: Dictionary = gs[0]
	return people.filter(func(o): return not o.gone and o.spot == p.spot)


func _facing_away(p: Dictionary) -> bool:
	var fwd := Vector3(-sin(p.body.rotation.y), 0, -cos(p.body.rotation.y))
	var to_me: Vector3 = player.position - p.body.position; to_me.y = 0
	return fwd.dot(to_me.normalized()) < 0.0


func _run_test() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().position = Vector2i(-3000, 60)
	await _secs(0.5)
	_check(people.size() == 9 and ROLES.all(func(r): return not _find(r).is_empty()), "nine people at the party, one of each role")
	_check(people.all(func(p): return p.tag.visible == false), "nobody wears a name tag")
	_check(not HANDLER.has("h_him") and not HANDLER.has("h_wrong"), "the handler has no 'that's him' or 'wrong': he doesn't know their faces")
	await _secs(1.5); await _shot("g1_room")
	var started := talk_count
	await _secs(14.0)
	_check(talk_count - started >= 3 and talks <= 2, "they keep talking among themselves (%d conversations in 14 s)" % (talk_count - started))
	# reading: only right beside them, only Korean
	hold = true
	var br := _find("broker"); var asst := _find("assistant")
	while br.busy or asst.busy: await _secs(0.1)
	_go(asst, br.spot); asst.body.position = _slot_pos(asst.spot, asst.slot); br.body.position = _slot_pos(br.spot, br.slot)
	await _put(asst.body.position.lerp(br.body.position, 0.5) + Vector3(0, 0, 0.5))
	_talk("boss", [[asst, "b1"], [br, "a1"], [asst, "r_yes"]])
	await _secs(0.3)
	_check(asst.ko.text == LINES.b1[0], "right beside them you can make out 사장님, 손님이 기다리세요")
	_check(people.all(func(p): return not p.has("en")), "and there's no English over anyone, ever")
	await _shot("g2_close")
	await _put(asst.body.position.lerp(br.body.position, 0.5) + Vector3(0, 0, 3.2)); await _secs(0.1)
	_check(asst.ko.text == "" and br.ko.text == "", "a couple of steps back: no words on screen, you only hear them")
	_check(asst.audio.attenuation_filter_db < -10.0, "and voices go muffled with distance")
	while asst.busy: await _secs(0.1)
	await _put(Vector3(-0.5, 0, 6.3))
	# business stays private near a stranger
	reacted.clear()
	await _put(br.body.position + Vector3(0, 0, 2.0))
	_check(not _options().any(func(o): return o[0] == "boss"), "near a stranger, the broker and his assistant don't talk business")
	asst.pic.ok = true
	_check(_options().any(func(o): return o[0] == "boss"), "once his assistant has taken to you, they do")
	asst.pic.ok = false
	await _put(Vector3(-0.5, 0, 6.3))
	# marking people: your guess, no verdict
	_toggle_phone(); await _secs(0.2)
	_check(phone_ui.visible and phone_prop.visible and role_btns.size() == 5, "the phone has the Who's who list, and you look at it")
	await _shot("g3_phone")
	await _beside(br); await _secs(0.3)
	_check(ring.visible and ring.position.distance_to(br.body.position) < 0.2, "the person your phone points at lights up")
	var said_before := played.size()
	_tag("broker")
	_check(guesses.get("broker", "") == br.id and br.tag.visible and br.tag.text == ROLE_NAME.broker[1] + "?", "mark the broker: your mark goes over him, with a ?")
	var bt := _find("bartender")
	await _beside(bt)
	_tag("host")
	_check(guesses.get("host", "") == bt.id and played.size() == said_before, "a wrong mark is saved just the same, and nobody says a word")
	_tag("bartender")
	_check(guesses.get("bartender", "") == bt.id and not guesses.has("host"), "one mark per person: re-marking her moves it")
	_toggle_phone()
	await _put(Vector3(-0.5, 0, 6.3))
	# they notice you: not everyone the same way
	var kinds := {}
	for i in 40:
		_reset_pics(); asking = {}; ask_busy = false
		var grp := _guest_group()
		if grp.is_empty(): continue
		for o in grp: o.busy = false
		reactions.clear(); _react(grp[0].spot)
		if reactions: kinds[reactions[0]] = 1
		if not asking.is_empty():
			asking.busy = false; asking = {}; ask_ui.visible = false
	_check(kinds.has("ask") and kinds.has("glance") and kinds.has("ignore"), "a group you hang around: some ask who you are, some glance and carry on, some ignore you (%s)" % ", ".join(kinds.keys()))
	_reset_pics(); ask_busy = false
	for p in people: p.glance = 0.0; p.busy = false
	# lingering is what sets it off
	var grp := _guest_group()
	reactions.clear(); reacted.clear()
	await _beside(grp[0]); await _secs(LINGER + 0.6)
	_check(reactions.size() >= 1, "stand by a group for a moment and they react (%s)" % (reactions[0] if reactions else "nothing"))
	if not asking.is_empty(): _ask_end("walked")
	await _secs(0.3)
	_reset_pics(); for p in people: p.glance = 0.0
	# someone asks: a good answer
	grp = _guest_group(); var g: Dictionary = grp[0]
	await _beside(g); reactions.clear()
	_ask(g, grp); await _secs(0.1); await _wait_free()
	_check(ask_ui.visible and ask_label.text == ask_fact.qs[ask_q][0] and played.has(_vk(g) + "_q_%s_%d" % [ask_fact.k, ask_q]), "they ask out loud, in Korean: " + ask_label.text)
	_check(tile_box.get_children().all(func(b): return not b.text.contains("I am") and not b.text.contains("from")), "your pieces are Korean only")
	await _shot("g5_asked")
	picked = _right_pieces(ask_fact); await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.ok and g.pic.met and ask_fact.k in g.pic.told and grp.all(func(o): return o.pic.met), "answer well: they take to you, and the whole group remembers what you said")
	_check(played.has(_vk(g) + "_x_ok"), "and they say 아, 반갑습니다")
	reacted.clear(); reactions.clear(); _react(g.spot)
	_check(reactions.has("glance") or reactions.has("ask"), "come back later: the ones who met you just nod")
	if not asking.is_empty(): _ask_end("walked")
	await _secs(0.3)
	# a near miss, then a bad answer
	_reset_pics(); for p in people: p.glance = 0.0
	grp = _guest_group(); g = grp[0]
	await _beside(g)
	_ask(g, grp); await _secs(0.1); await _wait_free()
	var rv := _right_pieces(ask_fact); rv.reverse()
	if rv.size() < 2: rv = [_right_pieces(ask_fact)[0]]
	picked = rv if _judge(rv, ask_fact) != "good" else [rv[0]]
	var first_q := ask_label.text
	await _say_it(); await _secs(0.1); await _wait_free()
	_check(not asking.is_empty() and played.has(_vk(g) + "_x_again") and ask_label.text == first_q, "almost right: 네? 다시 한 번요? and they ask again")
	var wrong_f: Dictionary = Cover.FACTS.filter(func(f): return f.k != ask_fact.k)[0]
	picked = [[wrong_f.k, 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.wary and not g.pic.ok and played.has(_vk(g) + "_x_cool"), "a wrong answer: 아... 네. and they're wary of you now")
	await _secs(1.5)
	_check(g.audio.volume_db < -6.0, "wary of you: they lower their voices when you're near")
	await _secs(3.5)
	_check(_facing_away(g), "and keep their back to you")
	reacted.clear(); reactions.clear(); _react(g.spot)
	_check(reactions == ["cold"], "go back to that group: nobody asks, they turn away")
	await _shot("g6_wary")
	# silence
	_reset_pics(); for p in people: p.glance = 0.0
	await _put(Vector3(-0.5, 0, 6.3))
	grp = _guest_group(); g = grp[0]; await _beside(g)
	_ask(g, grp); await _secs(0.1); await _wait_free()
	ask_t = 0.05; await _secs(0.3); await _wait_free()
	_check(asking.is_empty() and g.pic.wary, "say nothing and they give up on you, wary")
	# the phone while they wait
	_reset_pics(); for p in people: p.glance = 0.0
	grp = _guest_group(); g = grp[0]; await _beside(g)
	_ask(g, grp); await _secs(0.1); await _wait_free()
	_toggle_phone(); _toggle_phone()
	picked = _right_pieces(ask_fact); await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.met and not g.pic.ok and not g.pic.wary, "look it up on your phone while they wait: right answer, but they don't warm to you")
	_reset_pics()
	# walking off mid-question
	grp = _guest_group(); g = grp[0]; await _beside(g)
	_ask(g, grp); await _secs(0.1)
	await _put(Vector3(-0.5, 0, 6.3)); await _secs(0.2); await _wait_free()
	_check(asking.is_empty() and g.pic.wary, "walk away while they're asking: rude, and they remember")
	_reset_pics()
	hold = false
	# people come and go
	clock = 34.9; await _secs(0.4)
	var g5 := _find("g5")
	_check(not g5.is_empty() and people.size() == 10 and g5.body.position.distance_to(ELEVATOR) < 3.5, "someone arrives late, out of the lift")
	var leaver: Dictionary = people.filter(func(o): return o.role == "guest" and not o.gone and not o.busy and o.id != "g5")[0]
	leaver.body.position = SPOTS.elevator + Vector3(0.5, 0, 0.5); _leave(leaver)
	for i in 60:
		await _secs(0.1)
		if leaver.gone: break
	_check(leaver.gone, "someone leaves the party through the lift")
	var before := {}
	for p in people:
		if not p.gone and p.role in ["guest", "host"]: before[p.id] = p.body.position
	for p in people:
		if p.role == "guest" and not p.gone: p.timer = 0.0
	var inside := false
	for i in 40:
		await _secs(0.1)
		for p in people:
			if p.gone: continue
			var q: Vector3 = p.body.position
			if absf(q.x + 4.0) < 1.4 and absf(q.z + 1.6) < 0.4: inside = true
			if absf(q.x - 8.2) < 0.3 and absf(q.z + 1.0) < 2.0: inside = true
	var moved := 0
	for id in before:
		var p := _find(id)
		if p and p.body.position.distance_to(before[id]) > 1.0: moved += 1
	_check(moved >= 2 and not inside, "people drift between groups (%d moved), around the furniture" % moved)
	# leave by the lift: the debrief
	hold = true
	for p in people: p.busy = false
	await _beside(_find("host")); _tag("host")
	await _put(Vector3(-6.0, 0, 6.6)); await _secs(0.2)
	_check(leave_btn.visible, "at the lift doors you can leave")
	_check(player.position.z < 7.0, "and the doors are solid: you can't walk out of the building")
	await _finish(); await _secs(0.3)
	await _secs(0.2)
	_check(sub.get_global_rect().position.x > 0.0 and sub.get_global_rect().end.x < get_viewport().get_visible_rect().size.x, "the handler's subtitle sits on screen")
	_check(done and end_ui.visible and end_text.text.contains("Debrief") and end_text.text.contains("김 대표님") and end_text.text.contains("right")
		and end_text.text.contains("바텐더 (bartender): right") and end_text.text.contains("not marked"), "the debrief: which of your marks were right")
	await _shot("g4_end")
	print(end_text.text)
	print("DONE %d failed" % _fails)
	get_tree().quit(1 if _fails else 0)
