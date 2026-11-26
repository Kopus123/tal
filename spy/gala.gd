extends Node3D
## Feature 2: the gala room. A penthouse party: about nine people mingle, chat, come and go. You walk around and
## listen. Nobody wears a name tag: when you've worked out who someone is, stand next to them, open your phone and
## say who they are (Who's who). Your handler tells you if you're right.

const Cover = preload("res://cover.gd")
const SPEED := 3.6
const CAM_OFF := Vector3(0, 15.0, 9.5)
const ROOM := Vector2(20, 14)
const CLOSE := 3.2               # near enough to catch the words (and see them)
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
const HANDLER := {"h_in": "You're in. Find out who's who. Listen first.", "h_him": "That's him.", "h_her": "That's her.",
	"h_wrong": "No. Keep listening.", "h_stop": "Stop guessing. Listen first.", "h_close": "Get closer to them first.",
	"h_room": "Good. You know the room."}
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
var tagged := {}
var wrong_streak := 0
var wrongs := 0
var lock_t := 0.0
var done := false
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
var lock_label: Label
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
	_box(Vector3(-6.0, 0, hd + 0.05), Vector3(1.6, 1.9, 0.2), Color(0.6, 0.6, 0.65), false)                # elevator doors
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
	var ko := _sign("", 44, Vector3(0, 2.55, 0), b); var en := _sign("", 28, Vector3(0, 2.2, 0), b); en.modulate = Color(0.85, 0.85, 0.85)
	var tag := _sign("", 30, Vector3(0, -0.15, 0), b); tag.modulate = Color(1, 0.85, 0.3); tag.visible = false
	var role := id if id in ROLES else "guest"
	var p := {"id": id, "role": role, "body": b, "look": look, "audio": au, "ko": ko, "en": en, "tag": tag, "spot": "", "slot": -1,
		"timer": randf_range(2.0, 12.0), "busy": false, "leaving": false, "gone": false}
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
		if talkers.size() >= 2:
			talkers.shuffle(); var t: String = SMALL.pick_random()
			out.append(["small", [[talkers[0], "sq_" + t], [talkers[1], "sa_" + t]]])
		if host and guests:
			var g = guests.pick_random()
			if randf() < 0.5: out.append(["host", [[g, ["h1", "h3"].pick_random()], [host[0], "r_thanks"]]])
			else: out.append(["host", [[host[0], "h2"], [g, "r_thanks"]]])
		if br and (guests or host):
			out.append(["broker", [[(guests + host).pick_random(), "b2"], [br[0], "r_good"]]])
		if br and asst: out.append(["boss", [[asst[0], "b1"], [br[0], "a1"], [asst[0], "r_yes"]]])
		if br and sec: out.append(["room", [[sec[0], "b3"], [br[0], "r_yes"]]])
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
		var voice_id: String = (p.id if p.role == "guest" else p.role) + "_" + l[1]
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
	for p in people:   # up close you catch the words; from further off, only that they're talking
		if p.gone: continue
		var line: String = p.get("line", "")
		if line == "": p.ko.text = ""; p.en.text = ""; continue
		if player.position.distance_to(p.body.position) < CLOSE:
			p.ko.text = LINES[line][0]; p.en.text = LINES[line][1]
		else: p.ko.text = "• • •"; p.en.text = ""
	if lock_t > 0.0:
		lock_t -= dt
		lock_label.text = "Listen first (%d)" % ceili(lock_t) if lock_t > 0.0 else ""
		for r in role_btns: role_btns[r].disabled = lock_t > 0.0 or tagged.has(r)
	sub_t -= dt
	if sub_t <= 0.0: sub.text = ""
	goal.text = "Who's who: %d of 5" % tagged.size()
	var n := _nearest() if phone_open and not done else {}
	ring.visible = not n.is_empty()
	if ring.visible: ring.position = n.body.position + Vector3(0, 0.05, 0)


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
	sub = _label(26); sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); sub.position = Vector2(-420, -80)
	sub.custom_minimum_size = Vector2(840, 0); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(sub)
	phone_btn = _btn("Phone", 26, Vector2(150, 70)); phone_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	phone_btn.position = Vector2(-174, 20); root.add_child(phone_btn); phone_btn.pressed.connect(_toggle_phone)
	phone_ui = PanelContainer.new(); phone_ui.add_theme_stylebox_override("panel", _style(0.97)); root.add_child(phone_ui)
	phone_ui.anchor_left = 1; phone_ui.anchor_right = 1; phone_ui.anchor_top = 0; phone_ui.anchor_bottom = 1
	phone_ui.offset_left = -520; phone_ui.offset_right = -16; phone_ui.offset_top = 100; phone_ui.offset_bottom = -16
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; phone_ui.add_child(sc)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 8); sc.add_child(box)
	var t := _label(28); t.text = "Who's who"; box.add_child(t)
	var h := _label(18); h.text = "Stand next to someone (they light up), then tap who they are."; h.modulate = Color(0.8, 0.8, 0.8)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(h)
	for r in ROLES:
		var b := _btn("%s  ·  %s" % ROLE_NAME[r], 24, Vector2(0, 58)); b.pressed.connect(_tag.bind(r)); box.add_child(b); role_btns[r] = b
	lock_label = _label(20); lock_label.modulate = Color(1, 0.6, 0.4); box.add_child(lock_label)
	var c := _label(22); c.text = "Your cover: Daniel Park"; c.modulate = Color(1, 0.8, 0.4); box.add_child(c)
	for f in Cover.FACTS:
		var k := _label(22); k.text = "%s   %s" % [f.ko, f.en]; k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(k)
	phone_ui.visible = false
	end_ui = PanelContainer.new(); end_ui.add_theme_stylebox_override("panel", _style()); end_ui.set_anchors_preset(Control.PRESET_CENTER)
	end_ui.custom_minimum_size = Vector2(620, 0); end_ui.position = Vector2(-310, -160); root.add_child(end_ui)
	var eb := VBoxContainer.new(); eb.add_theme_constant_override("separation", 18); end_ui.add_child(eb)
	end_text = _label(30); end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; eb.add_child(end_text)
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
		if ev.pressed and joy_touch == -1 and ev.position.x < get_viewport().get_visible_rect().size.x * 0.45:
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
	phone_btn.text = "Put away" if phone_open else "Phone"
	sub.position.x = -630.0 if phone_open else -420.0   # out from under the phone
	create_tween().tween_property(body_mesh.get_child(0), "rotation:x", -0.35 if phone_open else 0.0, 0.25)


func _nearest() -> Dictionary:
	var best := {}; var bd := TAG_RANGE
	for p in people:
		if p.gone: continue
		var d := player.position.distance_to(p.body.position)
		if d < bd: best = p; bd = d
	return best


func _tag(role: String) -> void:
	if done or lock_t > 0.0 or tagged.has(role): return
	var p := _nearest()
	if p.is_empty(): _handler("h_close"); return
	if p.role == role:
		tagged[role] = true; wrong_streak = 0
		p.tag.text = "%s\n%s" % ROLE_NAME[role]; p.tag.visible = true
		role_btns[role].disabled = true; role_btns[role].text = "%s  ·  %s   (found)" % ROLE_NAME[role]
		_handler("h_her" if p.id in FEMALE else "h_him")
		if tagged.size() == ROLES.size(): _finish()
		return
	wrongs += 1; wrong_streak += 1
	if wrong_streak >= 2:   # guessing: he makes you stop and listen
		_handler("h_stop"); lock_t = 10.0; wrong_streak = 0
		for r in role_btns: role_btns[r].disabled = true
	else: _handler("h_wrong")


func _finish() -> void:
	done = true
	await get_tree().create_timer(1.6).timeout
	_handler("h_room")
	if phone_open: _toggle_phone()
	end_text.text = "You know the room.\n%d:%02d, %d wrong guess%s.\n\n(Talking to them is the next build.)" % [int(clock) / 60, int(clock) % 60, wrongs, "" if wrongs == 1 else "es"]
	end_ui.visible = true


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


func _run_test() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().position = Vector2i(-3000, 60)
	await _secs(0.5)
	_check(people.size() == 9 and ROLES.all(func(r): return not _find(r).is_empty()), "nine people at the party, one of each role")
	_check(people.all(func(p): return p.tag.visible == false), "nobody wears a name tag")
	await _secs(1.5); await _shot("g1_room")
	# they talk, a conversation at a time or two
	var started := talk_count
	await _secs(14.0)
	_check(talk_count - started >= 3 and talks <= 2, "they keep talking among themselves (%d conversations in 14 s)" % (talk_count - started))
	for i in 300:   # over a minute or so, both kinds turn up
		if played.any(func(c): return c.contains("_sq_") or c.contains("_sa_")) and played.any(func(c): return not (c.contains("_sq_") or c.contains("_sa_") or c.begins_with("h_"))): break
		await _secs(0.1)
	_check(played.any(func(c): return c.contains("_sq_") or c.contains("_sa_")) and played.any(func(c): return not (c.contains("_sq_") or c.contains("_sa_"))), "small talk and telling lines both come up")
	# up close you read the words; from across the room, only that they're talking
	var br := _find("broker"); var asst := _find("assistant")
	while br.busy or asst.busy: await _secs(0.1)
	asst.body.position = br.body.position + Vector3(0.9, 0, 0); asst.spot = br.spot
	await _put(br.body.position + Vector3(0, 0, 1.6))
	_talk("boss", [[asst, "b1"], [br, "a1"], [asst, "r_yes"]])
	await _secs(0.3)
	_check(asst.ko.text == LINES.b1[0] and asst.en.text == LINES.b1[1], "close by, you see and hear 사장님, 손님이 기다리세요 (Boss, a guest is waiting)")
	await _shot("g2_close")
	await _put(br.body.position + Vector3(0, 0, 6.0)); await _secs(0.1)
	_check(asst.ko.text == "• • •" or br.ko.text == "• • •", "from across the room you only see that they're talking")
	_check(asst.audio.attenuation_filter_db < -10.0, "and their voices go muffled with distance")
	while asst.busy: await _secs(0.1)
	# Who's who
	_toggle_phone(); await _secs(0.2)
	_check(phone_ui.visible and phone_prop.visible and role_btns.size() == 5, "the phone has the Who's who list, and you look at it")
	await _shot("g3_phone")
	await _put(Vector3(-0.5, 0, 6.3))
	var far_ok := true
	for p in people:
		if player.position.distance_to(p.body.position) < TAG_RANGE: far_ok = false
	if far_ok:
		_tag("broker"); _check(last_handler == "h_close" and tagged.is_empty(), "with nobody next to you: get closer first")
	hold = true
	br = _find("broker")
	await _beside(br); await _secs(0.6)
	_check(ring.visible and ring.position.distance_to(br.body.position) < 0.2, "the person your phone points at lights up")
	await _shot("g3b_ring")
	_tag("broker")
	_check(tagged.has("broker") and br.tag.visible and last_handler == "h_him", "next to the broker, tap Broker: tagged, and the handler says that's him")
	var bt := _find("bartender")
	await _beside(bt)
	_tag("host"); _check(last_handler == "h_wrong" and not tagged.has("host"), "a wrong guess: no, keep listening")
	_tag("security"); _check(last_handler == "h_stop" and lock_t > 9.0 and role_btns.host.disabled, "two wrong guesses in a row: stop guessing, the list locks for a bit")
	lock_t = 0.01; await _secs(0.1)
	_tag("bartender")
	hold = false; _check(tagged.has("bartender") and last_handler == "h_her", "the bartender: that's her")
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
	# they move about, and not through the furniture
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
			if absf(q.x + 4.0) < 1.4 and absf(q.z + 1.6) < 0.4: inside = true    # in the buffet table
			if absf(q.x - 8.2) < 0.3 and absf(q.z + 1.0) < 2.0: inside = true    # in the bar counter
	var moved := 0
	for id in before:
		var p := _find(id)
		if p and p.body.position.distance_to(before[id]) > 1.0: moved += 1
	_check(moved >= 2 and not inside, "people drift between groups (%d moved), around the furniture" % moved)
	# all five
	hold = true
	for r in ROLES:
		if tagged.has(r): continue
		var p := _find(r)
		await _beside(p)
		_tag(r)
	await _secs(2.0)
	_check(done and end_ui.visible and end_text.text.contains("wrong guess"), "everyone found: you know the room")
	await _shot("g4_end")
	print("DONE %d failed" % _fails)
	get_tree().quit(1 if _fails else 0)
