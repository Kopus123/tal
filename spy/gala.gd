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
const NOTICE := 2.5              # stand this close to a group for a moment and they notice you
const LINGER := 1.0
const FAST := 10.0                # (tester) the clock runs this much faster, and lines take their length without playing
const COOL := 45.0
const HUNT := 2.8                 # security coming for you: brisk, but you can outwalk him
const OUT_AT := Vector3(-6.0, 0, 6.4)   # in front of the lift doors                # keep away from someone this long, nothing new odd, and their doubt cools a step
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
	# word gets around: what you told someone, passed on
	"g_name": ["저 분, 다니엘 박이래요.", "That's Daniel Park, apparently."], "g_from": ["저 분, LA에서 왔대요.", "He's from LA, apparently."],
	"g_job": ["저 분, 투자자래요.", "He's an investor, apparently."], "g_stay": ["저 분, 일주일 있대요.", "He's here a week, apparently."],
	"g_invited": ["저 분, 김 대표님이 초대하셨대요.", "CEO Kim invited him, apparently."],
	"g_parents": ["저 분, 부모님이 부산 분이시래요.", "His parents are from Busan, apparently."],
	"g_korean": ["저 분, 한국어 잘 못한대요.", "His Korean isn't good, apparently."], "g_twice": ["저 분, 두 번 왔대요.", "He's been here twice, apparently."],
	"g_odd": ["저 분, 좀 이상해요.", "That man's a bit odd."], "al_sec": ["팀장님, 저 분 좀 보세요.", "Team leader, keep an eye on that man."],
	"v_ok": ["저 분, 괜찮은 분이에요.", "He's alright, that one."],
	"w_go": ["같이 가요.", "Let's go together."], "go_yes": ["네, 좋아요.", "Sure, sounds good."], "go_no1": ["아, 지금은 좀...", "Ah, not right now..."],
	"go_no2": ["죄송해요, 얘기 중이라서요.", "Sorry, I'm in the middle of a chat."], "go_bye": ["저 이만 가 볼게요.", "I'll be off now."], "r_really": ["아, 그래요?", "Oh, really?"],
}
const BACK := {   # your turn: what you can ask (you've heard each of these asked of you)
	"b_name": {"k": "b_name", "chunks": [["성함이", ""], ["어떻게 되세요?", ""]]}, "b_job": {"k": "b_job", "chunks": [["무슨 일", ""], ["하세요?", ""]]},
	"b_from": {"k": "b_from", "chunks": [["어디에서", ""], ["오셨어요?", ""]]}, "b_host": {"k": "b_host", "chunks": [["대표님하고", ""], ["어떻게 아세요?", ""]]},
	"b_go": {"k": "b_go", "chunks": [["같이", ""], ["가요", ""]]}, "b_thanks": {"k": "b_thanks", "chunks": [["감사합니다", ""]]}}
const HUH := ["x_again", "x_huh1", "x_huh2", "x_huh3"]   # they didn't quite get you
const ANS := {   # what each of them says when you ask (the broker gives little away)
	"host": {"name": "김지현입니다. 오늘 파티 주최자예요.", "job": "회사 대표입니다.", "from": "서울에서 태어났어요.", "host": "제가 대표예요. 하하."},
	"broker": {"name": "최입니다.", "job": "사업합니다.", "from": "그건 왜요?", "host": "김 대표님하고는 오래 알았어요."},
	"assistant": {"name": "윤서연입니다. 최 사장님 비서예요.", "job": "최 사장님 비서입니다.", "from": "부산에서 왔어요.", "host": "사장님 덕분에 알게 됐어요."},
	"g1": {"name": "이민지입니다.", "job": "의사예요.", "from": "대구에서 왔어요.", "host": "대학교 친구예요."},
	"g2": {"name": "박준호입니다.", "job": "변호사예요.", "from": "서울 사람이에요.", "host": "같이 일했어요."},
	"g3": {"name": "정우진입니다.", "job": "IT 회사 다녀요.", "from": "인천에서 왔어요.", "host": "골프 친구예요."},
	"g4": {"name": "한소희입니다.", "job": "디자이너예요.", "from": "제주도에서 왔어요.", "host": "언니 친구예요."},
	"g5": {"name": "강태호입니다.", "job": "은행에서 일해요.", "from": "대전에서 왔어요.", "host": "사업 파트너예요."},
	"g6": {"name": "오수진입니다.", "job": "기자예요.", "from": "광주에서 왔어요.", "host": "옛날 이웃이에요."},
}
const CHECK := {   # "I heard you're…?": they check what someone told them
	"name": "다니엘 박 씨라고요?", "from": "LA에서 오셨다고요?", "job": "투자자시라고요?", "stay": "일주일 계신다고요?",
	"invited": "김 대표님이 초대하셨다고요?", "parents": "부모님이 부산 분이시라고요?", "korean": "한국어 잘 못하신다고요?", "twice": "두 번 오셨다고요?"}
const SMALL := ["cold", "food", "view", "busy", "wine", "know"]
const HANDLER := {"h_in": "You're in. We know their titles, not their faces. Listen, and mark who's who on your phone.",
	"h_out": "Okay, we're out. Let's see what you got.",
	"h_heat1": "Careful. People are starting to talk about you.", "h_heat2": "Security's watching you now. Keep it clean, or head for the lift.",
	"h_heat3": "They're onto you. Get to the lift. Now.", "h_calm": "Okay. Security's backed off.",
	"h_shot": "What are you doing?! Get out of there. Now."}
const HEAT := [2, 4, 6]          # how much doubt in the room (everyone's added up) before: talk, security watches you, security comes
const ASKERS := ["host", "broker", "assistant", "g1", "g2", "g3", "g4", "g5", "g6"]   # who might ask who you are
const REACT := {"ok": ["아, 반갑습니다.", "Ah, nice to meet you."], "again": ["네? 다시 한 번요?", "Sorry? Once more?"], "cool": ["아... 네.", "Ah... right."],
	"differ": ["네? 다르게 들었는데요.", "Sorry? That's not what I heard."], "fine": ["아, 그렇군요.", "Ah, I see."],
	"stop": ["잠깐만요, 손님.", "Just a moment, sir."],
	"huh1": ["뭐라고요?", "Sorry?"], "huh2": ["죄송해요, 잘 못 들었어요.", "Sorry, I didn't catch that."], "huh3": ["무슨 말씀이세요?", "What do you mean?"]}
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
var ask_check := false           # they're checking something they heard about you
var ask_text := ""
var back := false                # your turn: you ask them
var skip_turn := false           # (tester) answers end without your turn
var hear_btn: Button
var talk_btn: Button
var comp_btn: Button
var done_btn: Button
var ask_clip := ""
var picked: Array = []
var me_voice: AudioStreamPlayer
var phone_open := false
var last_handler := ""
var lift_pad: MeshInstance3D     # the lit floor in front of the lift: stand on it to leave
var ring: MeshInstance3D          # under whoever your phone would point at
var hold := false
var playing := false            # (play mode) an outside player drives the party by text commands
var plog: FileAccess
var tile_map := {}
var hunting := false             # security is coming for you
var hunted := false
var heat_stage := 0               # 0 calm · 1 people talk · 2 security shadows you · 3 he comes for you
var no_heat := false              # (tester) doubt in the room doesn't bring security
var talk_wait := {}               # you tapped Talk while they were mid-chat: they turn to you when it's done
var hunt_wait := 0.0              # he checks in on his earpiece before he comes: your head start
const MAG := 8
var ammo := MAG                   # a silenced pistol: whoever you hit goes down
var gun_prop: MeshInstance3D
var shoot_btn: Button
var downed: Array = []            # who you took down
var glass := false                # a wine glass in your hand: throw it and everyone looks where it smashes
var glass_prop: MeshInstance3D
var throw_btn: Button
var noise_at := Vector3.ZERO      # where it smashed
var distract_t := 0.0             # security's gone to look at the mess this long
var distract_go := false          # (he's still walking over)
var escorting := false           # caught: he walks you out                # (tester) everyone stays put
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
	playing = "--play" in OS.get_cmdline_user_args()
	if playing: test = true
	randomize()
	hvoice = AudioStreamPlayer.new(); add_child(hvoice)
	me_voice = AudioStreamPlayer.new(); add_child(me_voice)
	_room()
	_screen()
	_cast()
	leave_at = randf_range(95.0, 130.0)
	if playing: _run_play()
	elif test: _run_test()
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
	lift_pad = MeshInstance3D.new(); var lpm := BoxMesh.new(); lpm.size = Vector3(2.2, 0.03, 1.5); lift_pad.mesh = lpm
	lift_pad.position = Vector3(-6.0, 0.02, hd - 0.9)
	var lm := _mat(Color(0.95, 0.85, 0.45)); lm.emission_enabled = true; lm.emission = Color(0.95, 0.8, 0.35); lm.emission_energy_multiplier = 0.6
	lift_pad.material_override = lm; add_child(lift_pad)
	_sign("LIFT  ·  엘리베이터", 56, Vector3(-6.0, 1.3, hd - 1.2), self)
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
	glass_prop = MeshInstance3D.new(); glass_prop.mesh = _glass_mesh(); glass_prop.material_override = _glass_mat()
	glass_prop.position = Vector3(0.34, 1.0, -0.15); body_mesh.add_child(glass_prop); glass_prop.visible = false
	gun_prop = MeshInstance3D.new(); var gb := BoxMesh.new(); gb.size = Vector3(0.08, 0.1, 0.42); gun_prop.mesh = gb
	gun_prop.material_override = _mat(Color(0.08, 0.08, 0.09)); gun_prop.position = Vector3(0.34, 1.0, -0.3); body_mesh.add_child(gun_prop)
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

const PALETTE := [[Color(0.85, 0.85, 0.82), "pale grey"], [Color(0.12, 0.12, 0.14), "black"], [Color(0.2, 0.25, 0.4), "navy"],
	[Color(0.14, 0.15, 0.16), "charcoal"], [Color(0.95, 0.95, 0.95), "white"], [Color(0.7, 0.2, 0.3), "red"], [Color(0.3, 0.3, 0.5), "slate blue"],
	[Color(0.5, 0.4, 0.25), "brown"], [Color(0.6, 0.5, 0.7), "lavender"], [Color(0.25, 0.45, 0.4), "teal"], [Color(0.8, 0.6, 0.3), "amber"]]
var look_names := {}


func _cast() -> void:   # who wears what is shuffled every party: you can't learn people by colour
	var pal := PALETTE.duplicate(); pal.shuffle()
	var looks := {}
	var ids := ["host", "broker", "assistant", "security", "bartender", "g1", "g2", "g3", "g4", "g5", "g6"]
	for i in ids.size(): looks[ids[i]] = pal[i][0]; look_names[ids[i]] = pal[i][1]
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
		"timer": randf_range(2.0, 12.0), "veer": 0.0, "veer_t": 0.0, "coming": false, "came": false, "errand": false, "goto": Vector3.ZERO, "come_t": 0.0, "calm_t": 0.0, "tell": false, "chk_t": 0.0, "tell_t": 0.0, "speed": 1.4, "following": false, "follow_t": 0.0, "shadow": false, "look_t": 0.0, "look_pt": Vector3.ZERO, "chk_d": INF, "stuck": 0, "busy": false, "leaving": false, "gone": false, "glance": 0.0,
		"pic": {"met": false, "told": [], "second": [], "ok": false, "wary": false, "doubt": 0, "checked": false, "told_sec": false, "vouched": false, "asked": [], "concern": {}}}   # their picture of you
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
	if p.spot == "" or p.slot < 0: return false   # with you, or between places
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
	var dest: Vector3 = p.goto if p.coming else _slot_pos(p.spot, p.slot)
	var to := dest - b.position; to.y = 0
	if to.length() < 0.2 and not p.coming:
		p.chk_t = 0.0; p.chk_d = INF; p.stuck = 0
		b.velocity = Vector3.ZERO
		var c: Vector3 = SPOTS[p.spot] if p.spot != "bar" else Vector3(8.0, 0, b.position.z)
		if p.id == "bartender": c = Vector3(7.1, 0, -1.0)
		var d := c - b.position
		var mine := player.position - b.position; mine.y = 0
		if p.look_t > 0.0: d = p.look_pt - b.position; d.y = 0                       # what was that?
		elif p.glance > 0.0: d = mine                                                   # a look at you
		elif p.glance < 0.0 or (p.pic.doubt >= 2 and mine.length() < 3.5): d = -mine   # their back to you
		if d.length() > 0.1: b.rotation.y = lerp_angle(b.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-5.0 * dt))
		return
	p.chk_t += dt
	if p.chk_t >= 2.0:   # every couple of seconds: are they getting anywhere?
		if p.chk_d - to.length() < 0.3 and (not p.coming or p.following):
			p.stuck += 1
			if p.stuck >= 2 or to.length() < 1.5: b.position = dest; b.velocity = Vector3.ZERO; p.stuck = 0; return   # step in
			p.veer = [1.5, -1.5].pick_random(); p.veer_t = 1.2   # try round the other way
		else: p.stuck = 0
		p.chk_t = 0.0; p.chk_d = to.length()
	var dir := to.normalized()
	p.veer_t = p.get("veer_t", 0.0) - dt
	var tries: Array = [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.1, -2.1]
	if p.veer_t > 0.0: tries.push_front(p.veer)   # keep going round the same side, don't flip back and forth
	var found := false
	for a in tries:
		var dd := dir.rotated(Vector3.UP, a)
		if not b.test_move(b.global_transform, dd * 0.4):
			dir = dd; found = true
			if a != 0.0 and (p.veer_t <= 0.0 or a != p.veer): p.veer = a; p.veer_t = 0.8
			break
	if not found: b.velocity = Vector3.ZERO; return   # boxed in: wait a moment
	b.velocity = dir * minf(p.speed, to.length() / dt); b.move_and_slide(); b.position.y = 0
	b.rotation.y = lerp_angle(b.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * dt))


func _people(dt: float) -> void:
	for p in people.duplicate():
		if p.gone: continue
		p.glance = maxf(0.0, p.glance - dt) if p.glance > 0.0 else minf(0.0, p.glance + dt)
		if p.coming or p.errand or p.tell or p.following or p.shadow or (hunting and p.role == "security") or (distract_t > 0.0 and p.role == "security"): continue   # on their way to you, or to security, or with you
		if not p.busy: _walk(p, dt)
		if p.leaving and p.spot == "elevator" and _at(p):   # into the lift and gone
			p.gone = true; slots_taken.erase("%s:%d" % [p.spot, p.slot]); p.body.queue_free(); continue
		if p.busy or not _at(p): continue
		p.timer -= dt
		if p.timer <= 0.0:
			var sp := _pick_spot(p)
			var mate := _mate(p)
			if sp != p.spot and not mate.is_empty() and randf() < 0.35 and _free_slots(sp) >= 2: _go_together(p, mate, sp)
			elif sp != p.spot: _go(p, sp)
			p.timer = {"host": randf_range(16, 26), "broker": randf_range(28, 42), "assistant": 3.0, "security": randf_range(18, 30)}.get(p.role, randf_range(10, 18))
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
			talkers.shuffle()
			var topics := SMALL if talkers[0].role == "guest" and talkers[1].role == "guest" else SMALL.filter(func(x): return x != "know")   # the host and the broker's people know everyone
			var t: String = topics.pick_random()
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
		for o in _gossip(m): out.append(o)
		if asst: out.append(["phone", [[asst[0], "a2"]]])
		if sec: out.append(["radio", [[sec[0], "s1"]]])
	return out


func _gossip(m: Array) -> Array:   # someone here knows something about you the others don't: they pass it on
	var out := []
	for p in m:
		if not (p.id in ASKERS): continue
		for o in m:
			if o == p or not (o.id in ASKERS): continue
			if p.pic.wary and not o.pic.wary: out.append(["gossip", [[p, "g_odd"], [o, "r_really"]]])
			for k in p.pic.told:
				if not (k in o.pic.told) and o.pic.doubt < 2 and not (k == "invited" and o.role == "host"): out.append(["gossip", [[p, "g_" + k], [o, "r_really"]]])
	for p in m:   # someone who's taken to you speaks up for you
		if not (p.id in ASKERS) or not p.pic.ok or p.pic.doubt > 0: continue
		for o in m:
			if o != p and o.id in ASKERS and o.pic.doubt > 0 and not o.pic.vouched: out.append(["vouch", [[p, "v_ok"], [o, "r_really"]]])
	return out


func _spread(p: Dictionary, k: String) -> void:   # everyone standing there heard it
	for o in people:
		if o == p or o.gone or o.spot != p.spot: continue
		if k == "odd":
			if o.pic.doubt == 0:   # hearsay makes them curious, no more, and they don't know what was odd
				_doubt(o, 1); o.pic.concern = {"why": "heard_odd", "k": "", "q": -1, "src": "heard"}
		elif not (k in o.pic.told): o.pic.told.append(k); o.pic.second.append(k)
		o.glance = 3.0   # and they all look over at you


func _doubt(o: Dictionary, n: int) -> void:   # curious (1) · doubtful (2) · alarmed (3)
	if not (o.id in ASKERS): return
	o.pic.doubt = clampi(o.pic.doubt + n, 0, 3); o.pic.wary = o.pic.doubt > 0
	if n > 0: o.pic.ok = false; o.calm_t = 0.0   # something new looked odd
	if o.pic.doubt < 2: o.pic.checked = false
	if o.pic.doubt < 3: o.pic.told_sec = false


func _doubters(dt: float) -> void:   # doubt shows in what people do
	if done: return
	var sec := _find("security")
	for p in people:
		if p.gone or p.leaving or not (p.id in ASKERS): continue
		if p.following: _follow(p, dt); continue
		var d: int = p.pic.doubt
		if d > 0:   # keep out of their way and it cools, a step at a time; what they heard stays
			if player.position.distance_to(p.body.position) > 6.0:
				p.calm_t += dt
				if p.calm_t >= COOL: p.calm_t = 0.0; _doubt(p, -1); d = p.pic.doubt
			else: p.calm_t = 0.0
		if p.coming:   # doubtful: they come over to check you
			var gap: Vector3 = player.position - p.body.position; gap.y = 0
			p.come_t -= dt
			if d < 2 or p.come_t <= 0.0: _send_back(p); continue
			if gap.length() > 1.3: p.goto = player.position; _walk(p, dt)
			else:
				p.body.velocity = Vector3.ZERO; p.body.rotation.y = atan2(-gap.x, -gap.z)
				if asking.is_empty() and not ask_busy: _come_check(p)
			continue
		if p.tell:   # alarmed, no room by security: they go right up to him
			if not sec or d < 3: p.tell = false; _send_back(p); continue
			var gs: Vector3 = sec.body.position - p.body.position; gs.y = 0
			p.tell_t += dt
			if gs.length() > 2.0 and p.tell_t < 6.0: p.goto = sec.body.position; p.coming = true; _walk(p, dt); p.coming = false   # (or as close as they can get)
			elif not sec.busy and not p.busy: p.tell = false; p.pic.told_sec = true; _tell_sec(p, sec)
			continue
		if p.busy: continue
		if p.errand:
			if not _at(p): _walk(p, dt)
			elif d < 3 or p.pic.told_sec: p.errand = false
		if d == 1 and _at(p) and p.glance == 0.0 and player.position.distance_to(p.body.position) < 6.0 and randf() < dt * 0.5:
			p.glance = randf_range(1.0, 1.8)   # curious: they keep looking you over
		if d == 2 and not p.pic.checked and asking.is_empty() and _at(p):
			p.coming = true; p.come_t = 20.0
			slots_taken.erase("%s:%d" % [p.spot, p.slot]); p.slot = -1
		if d >= 3 and not p.pic.told_sec and sec and _at(p):   # alarmed: they tell security
			if p.spot != sec.spot:
				if _has_room(sec.spot): _go(p, sec.spot); p.errand = true
				else: p.tell = true; p.tell_t = 0.0; slots_taken.erase("%s:%d" % [p.spot, p.slot]); p.slot = -1
			elif _at(sec) and not sec.busy:
				p.pic.told_sec = true; p.errand = false
				_talk("alarm", [[p, "al_sec"], [sec, "r_yes"]])


func _glass_mesh() -> CylinderMesh:
	var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.04; cm.height = 0.2; return cm


func _glass_mat() -> StandardMaterial3D:
	var m := _mat(Color(0.75, 0.15, 0.25)); m.emission_enabled = true; m.emission = Color(0.5, 0.05, 0.12); m.emission_energy_multiplier = 0.5; return m


func _throw(at := Vector3.INF) -> void:   # the glass flies ahead of you and smashes: everyone looks there, security goes to see
	if not glass or done or escorting or not asking.is_empty() or back: return
	glass = false; glass_prop.visible = false
	if at == Vector3.INF:
		var fwd := Vector3(-sin(body_mesh.rotation.y), 0, -cos(body_mesh.rotation.y))
		at = player.position + fwd * 6.0
	at.y = 0; at.x = clampf(at.x, -ROOM.x / 2 + 0.6, ROOM.x / 2 - 0.6); at.z = clampf(at.z, -ROOM.y / 2 + 0.6, ROOM.y / 2 - 0.6)
	for o in people:   # anyone right beside you sees you do it
		if o.gone or player.position.distance_to(o.body.position) > 2.5: continue
		_doubt(o, 1); o.glance = 3.0
	var g := MeshInstance3D.new(); g.mesh = _glass_mesh(); g.material_override = _glass_mat(); add_child(g)
	var from: Vector3 = player.position + Vector3(0, 1.1, 0)
	g.position = from
	var tw := create_tween()
	tw.tween_method(func(k: float): g.position = from.lerp(at + Vector3(0, 0.1, 0), k) + Vector3(0, 2.4 * k * (1.0 - k), 0); g.rotation.x = k * 9.0, 0.0, 1.0, 0.55)
	await tw.finished
	g.queue_free()
	_smash(at)


func _smash(at: Vector3) -> void:
	played.append("smash"); noise_at = at
	_plg("CRASH: your glass smashes on the floor %s. Everyone turns to look." % _place(at))
	for i in 7:   # shards, and a splash of red
		var sh := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(randf_range(0.04, 0.1), 0.02, randf_range(0.04, 0.1)); sh.mesh = bm
		sh.material_override = _glass_mat(); sh.position = at + Vector3(randf_range(-0.45, 0.45), 0.02, randf_range(-0.45, 0.45)); sh.rotation.y = randf() * TAU; add_child(sh)
	var sp := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.5; cy.bottom_radius = 0.5; cy.height = 0.01; sp.mesh = cy
	sp.material_override = _mat(Color(0.45, 0.05, 0.1)); sp.position = at + Vector3(0, 0.01, 0); add_child(sp)
	var snd := AudioStreamPlayer3D.new(); snd.stream = _smash_sound(); snd.position = at + Vector3(0, 0.5, 0); snd.unit_size = 8.0; add_child(snd); snd.play()
	for p in people:
		if p.gone or p.busy or p.body.position.distance_to(at) > 11.0: continue
		p.look_t = randf_range(2.0, 3.5); p.look_pt = at; p.glance = 0.0
	var sec := _find("security")
	if sec and not sec.busy and not escorting and not done:
		distract_go = true; distract_t = sec.body.position.distance_to(at) / HUNT + 4.5
		if not hunting and not sec.shadow: slots_taken.erase("%s:%d" % [sec.spot, sec.slot]); sec.slot = -1


func _smash_sound() -> AudioStreamWAV:   # breaking glass, made on the spot
	var rate := 22050; var n := int(rate * 0.7)
	var data := PackedByteArray(); data.resize(n * 2)
	var tone := 0.0
	for i in n:
		var t := float(i) / rate
		if randf() < 0.002: tone = randf_range(2500.0, 5200.0)   # bits of glass ringing
		var v := (randf() * 2.0 - 1.0) * exp(-t * 10.0) * 0.75 + sin(t * TAU * tone) * exp(-t * 6.0) * 0.25
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.data = data; return w


func _distract(dt: float) -> void:   # heads turn to the noise; security goes over to look at the mess
	for p in people:
		if p.look_t > 0.0: p.look_t -= dt
	if distract_t <= 0.0: return
	var sec := _find("security")
	if sec.is_empty() or sec.busy or done or escorting: distract_t = 0.0; return
	distract_t -= dt
	var gap: Vector3 = noise_at - sec.body.position; gap.y = 0
	if distract_go and gap.length() > 1.0:
		sec.goto = noise_at; sec.speed = HUNT; sec.coming = true; _walk(sec, dt); sec.coming = false
	else:
		distract_go = false; sec.body.velocity = Vector3.ZERO
		if gap.length() > 0.1: sec.body.rotation.y = lerp_angle(sec.body.rotation.y, atan2(-gap.x, -gap.z), 1.0 - exp(-5.0 * dt))
	if distract_t <= 0.0 and not hunting and not sec.shadow: _send_back(sec)   # back to his post


func _aim() -> Dictionary:   # who you'd hit: security first if he's after you, else whoever's in front of you, else whoever's nearest
	var sec := _find("security")
	if sec and (hunting or sec.shadow) and player.position.distance_to(sec.body.position) < 14.0: return sec
	var fwd := Vector3(-sin(body_mesh.rotation.y), 0, -cos(body_mesh.rotation.y))
	var best := {}; var bd := INF
	for p in people:
		if p.gone: continue
		var to: Vector3 = p.body.position - player.position; to.y = 0
		var d := to.length()
		if d > 14.0 or d < 0.05: continue
		var score := d if fwd.dot(to / d) > 0.75 else d + 100.0   # in front of you counts first
		if score < bd: bd = score; best = p
	if bd > 100.0 and bd - 100.0 > 8.0: return {}
	return best


func _shoot() -> void:   # pfft: they drop. Anyone who sees it panics, and security comes for you
	if ammo <= 0 or done or escorting or not asking.is_empty() or back: return
	var p := _aim()
	ammo -= 1
	var to: Vector3 = (p.body.position if p else player.position + Vector3(-sin(body_mesh.rotation.y), 0, -cos(body_mesh.rotation.y)) * 5.0) - player.position
	body_mesh.rotation.y = atan2(-to.x, -to.z)
	var flash := MeshInstance3D.new(); var fm := SphereMesh.new(); fm.radius = 0.12; fm.height = 0.24; flash.mesh = fm
	var fmat := _mat(Color(1.0, 0.85, 0.4)); fmat.emission_enabled = true; fmat.emission = Color(1.0, 0.7, 0.3); fmat.emission_energy_multiplier = 4.0; flash.material_override = fmat
	flash.position = gun_prop.position + Vector3(0, 0, -0.3); body_mesh.add_child(flash)
	get_tree().create_timer(0.08).timeout.connect(flash.queue_free)
	var snd := AudioStreamPlayer3D.new(); snd.stream = _shot_sound(); snd.position = player.position + Vector3(0, 1.0, 0); add_child(snd); snd.play()
	played.append("shot")
	if p.is_empty(): _plg("You fire. Nobody there."); return
	_plg("You fire at %s. They drop." % _desc(p))
	_drop(p)
	_handler("h_shot")
	var sec := _find("security")
	for o in people:   # everyone who saw: alarmed, and they look at you
		if o.gone or o.body.position.distance_to(player.position) > 10.0: continue
		_doubt(o, 3); o.glance = 5.0; o.look_t = 0.0
	if sec and not hunting and not done:   # he heard it: he comes for you, no waiting
		hunting = true; hunted = true; hunt_wait = 0.6; sec.shadow = false; sec.timer = INF; heat_stage = 3
		slots_taken.erase("%s:%d" % [sec.spot, sec.slot]); sec.slot = -1


func _drop(p: Dictionary) -> void:   # down on the floor, out of the party
	if asking == p: _ask_end("walked")
	p.gone = true; p.busy = true; p.following = false; p.shadow = false; p.coming = false
	if p.slot >= 0: slots_taken.erase("%s:%d" % [p.spot, p.slot])
	downed.append(p.id)
	var b: CharacterBody3D = p.body
	b.velocity = Vector3.ZERO; b.collision_layer = 0; p.audio.stop(); p.ko.text = ""
	if p.role == "security": hunting = false; distract_t = 0.0
	create_tween().tween_property(b, "rotation:x", -PI / 2, 0.35)
	var pos := b.position; create_tween().tween_property(b, "position:y", 0.3, 0.35).from(pos.y)


func _shot_sound() -> AudioStreamWAV:   # a suppressed shot: a hard thump and a hiss
	var rate := 22050; var n := int(rate * 0.3)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := sin(t * TAU * 90.0) * exp(-t * 30.0) * 0.9 + (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.data = data; return w


func _room_doubt() -> int:   # everyone's doubt about you, added up
	var n := 0
	for p in people:
		if not p.gone and p.id in ASKERS: n += p.pic.doubt
	return n


func _heat(dt: float) -> void:   # the more of the room doubts you, the closer security gets
	if done or escorting or no_heat: return
	var sec := _find("security")
	if sec.is_empty(): return
	var h := _room_doubt()
	var st := 0
	for t in HEAT:
		if h >= t: st += 1
	if hunting: st = 3
	if st > heat_stage:
		heat_stage = st
		if st == 1:
			_handler("h_heat1"); sec.glance = 4.0
		elif st == 2:
			_handler("h_heat2"); sec.shadow = true; sec.timer = INF; sec.glance = 4.0
			slots_taken.erase("%s:%d" % [sec.spot, sec.slot]); sec.slot = -1
		elif st == 3 and not hunting:
			_handler("h_heat3"); sec.shadow = false; hunt_wait = 2.0
			hunting = true; hunted = true; sec.timer = INF
			slots_taken.erase("%s:%d" % [sec.spot, sec.slot]); sec.slot = -1
	elif st < heat_stage and st <= 1 and not hunting:   # it's cooled off
		if heat_stage >= 2 and sec.shadow:
			sec.shadow = false; _handler("h_calm"); _send_back(sec)
		heat_stage = st
	if sec.shadow and not sec.busy and distract_t <= 0.0:   # he keeps a few steps off, watching you
		var off: Vector3 = sec.body.position - player.position; off.y = 0
		if off.length() < 0.1: off = Vector3(0, 0, -1)
		var spot: Vector3 = player.position + off.normalized() * 3.0
		var to_me: Vector3 = player.position - sec.body.position; to_me.y = 0
		if off.length() > 3.6:
			sec.goto = spot; sec.speed = 2.2; sec.coming = true; _walk(sec, dt); sec.coming = false
		else:
			sec.body.velocity = Vector3.ZERO
		if to_me.length() > 0.1: sec.body.rotation.y = lerp_angle(sec.body.rotation.y, atan2(-to_me.x, -to_me.z), 1.0 - exp(-5.0 * dt))


func _hunt(dt: float) -> void:   # security comes for you: get to the lift first
	var sec := _find("security")
	if not hunting or done or sec.is_empty() or sec.busy or distract_t > 0.0: return
	var gap: Vector3 = player.position - sec.body.position; gap.y = 0
	if hunt_wait > 0.0:   # a hand to his earpiece, eyes on you: go, now
		hunt_wait -= dt; sec.body.velocity = Vector3.ZERO
		if gap.length() > 0.1: sec.body.rotation.y = lerp_angle(sec.body.rotation.y, atan2(-gap.x, -gap.z), 1.0 - exp(-5.0 * dt))
		return
	if gap.length() > 1.1:
		sec.goto = player.position; sec.speed = HUNT; sec.coming = true; _walk(sec, dt); sec.coming = false
	else: _caught(sec)


func _caught(sec: Dictionary) -> void:   # 잠깐만요, 손님: and he walks you out
	hunting = false; escorting = true; sec.busy = true
	if not asking.is_empty(): _ask_end("walked")
	if phone_open: _toggle_phone()
	player.velocity = Vector3.ZERO
	var d: Vector3 = player.position - sec.body.position
	sec.body.rotation.y = atan2(-d.x, -d.z)
	await _line(sec, "x_stop")


func _escort(dt: float) -> void:   # the two of you walk to the lift, his hand at your elbow
	var sec := _find("security")
	var to := OUT_AT - player.position; to.y = 0
	if to.length() < 0.3:
		escorting = false; _finish(true); return
	if sec and sec.busy and sec.get("said", "") != "": return   # he says his piece first
	player.velocity = to.normalized() * 1.4; player.move_and_slide(); player.position.y = 0
	body_mesh.rotation.y = atan2(-to.x, -to.z)
	if sec:
		var at: Vector3 = player.position + to.normalized().rotated(Vector3.UP, PI / 2) * 0.7
		sec.body.position = sec.body.position.lerp(at, 1.0 - exp(-6.0 * dt)); sec.body.rotation.y = body_mesh.rotation.y


func _mate(p: Dictionary) -> Dictionary:   # a guest standing with them who might tag along
	if p.role != "guest": return {}
	var m := people.filter(func(o): return o != p and o.role == "guest" and not o.gone and not o.busy and not o.leaving and o.spot == p.spot and _at(o))
	return m.pick_random() if m else {}


func _free_slots(spot: String) -> int:
	var n := 0
	for i in 4:
		if not slots_taken.has("%s:%d" % [spot, i]): n += 1
	return n


func _go_together(p: Dictionary, m: Dictionary, sp: String) -> void:   # "같이 가요." "네, 좋아요."
	await _talk("go", [[p, "w_go"], [m, "go_yes"]])
	if p.gone or m.gone or p.following or m.following: return
	_go(p, sp); _go(m, sp); m.timer = p.timer


func _talk_target() -> Dictionary:   # who the Talk button would talk to
	if not asking.is_empty() or back or done or escorting: return {}
	var n := _nearest()
	if n.is_empty() or not (n.id in ASKERS) or n.leaving or n.coming or n.tell or n.following: return {}
	return n


func _companion() -> Dictionary:   # someone walking with you, close enough to talk to
	if not asking.is_empty() or back or done or escorting: return {}
	for p in people:
		if p.following and not p.busy and not p.gone and player.position.distance_to(p.body.position) < 3.0: return p
	return {}


func _talk_btn() -> void:
	var p := _talk_target()
	if p.is_empty(): return
	if p.busy: talk_wait = p; talk_btn.text = "..."   # they finish what they're saying first
	else: _talk_to(p)


func _talk_to(p: Dictionary) -> void:
	if p.is_empty(): return
	p.busy = true
	var d: Vector3 = player.position - p.body.position
	p.body.rotation.y = atan2(-d.x, -d.z)
	_turn(p)


func _turn_keys(who: Dictionary) -> Array:
	return ["b_name", "b_job", "b_from", "b_host", "b_thanks" if who.get("following", false) else "b_go"]


func _will_follow(p: Dictionary) -> bool:   # each of them decides from what they think of you
	if p.pic.doubt > 0 or p.role == "security" or p.role == "bartender": return false
	var ok: bool = p.pic.ok
	match p.role:
		"host": return ok and randf() < 0.9   # looking after her guests is her job
		"broker": return ok and randf() < 0.5
		"assistant": return ok and randf() < 0.3
	if ok: return randf() < 0.85
	if p.pic.met: return randf() < 0.4
	return randf() < 0.15


func _go_ask(who: Dictionary) -> void:   # 같이 가요?
	if who.following: await _line(who, "go_yes"); return
	if _will_follow(who):
		await _line(who, "go_yes"); _start_follow(who)
	else: await _line(who, ["go_no1", "go_no2"].pick_random())


func _start_follow(p: Dictionary) -> void:
	slots_taken.erase("%s:%d" % [p.spot, p.slot])
	p.following = true; p.follow_t = 30.0; p.slot = -1; p.spot = ""; p.errand = false; p.timer = INF
	reactions.append("follow")


func _end_follow(p: Dictionary, say := false) -> void:   # back to the party
	if not p.following: return
	p.following = false
	if say and not p.gone: _line(p, "go_bye")
	_send_back(p)


func _follow(p: Dictionary, dt: float) -> void:   # a step behind you, wherever you go
	if p.busy: return
	p.follow_t -= dt
	if p.pic.doubt > 0 or p.follow_t <= 0.0 or done: _end_follow(p, true); return
	var behind: Vector3 = player.position + Vector3(sin(body_mesh.rotation.y), 0, cos(body_mesh.rotation.y)) * 1.1
	var gap: Vector3 = player.position - p.body.position; gap.y = 0
	if gap.length() > 1.5:
		p.goto = behind; p.speed = SPEED; p.coming = true; _walk(p, dt); p.coming = false; p.speed = 1.4
	else:
		p.body.velocity = Vector3.ZERO
		p.body.rotation.y = lerp_angle(p.body.rotation.y, atan2(-gap.x, -gap.z), 1.0 - exp(-5.0 * dt))


func _tell_sec(p: Dictionary, sec: Dictionary) -> void:
	await _talk("alarm", [[p, "al_sec"], [sec, "r_yes"]])
	if not p.gone: _send_back(p)


func _come_check(p: Dictionary) -> void:   # they come back to whatever made them doubt you
	p.coming = false; p.came = true; p.pic.checked = true
	reactions.append("came")
	var c: Dictionary = p.pic.concern
	var k: String = c.get("k", "")
	if k == "invited" and p.role == "host": k = ""   # she knows who she invited
	if k != "" and k in p.pic.told: _ask(p, [p], k); return   # they heard something about it: "so you're…?"
	if k != "": _ask(p, [p], "", k, c.get("q", -1)); return   # the same question again
	_ask(p, [p])   # they don't know what was odd: an ordinary question


func _send_back(p: Dictionary) -> void:   # back to the party
	p.coming = false; p.slot = -1
	for sp in [_pick_spot(p)] + GUEST_SPOTS:
		if _has_room(sp): _go(p, sp); break
	p.errand = true; p.timer = randf_range(10.0, 18.0)


func _maybe_talk() -> void:
	if talks >= 2: return
	var opts := _options()
	if opts.is_empty(): return
	var gossip := opts.filter(func(o): return o[0] == "gossip" or o[0] == "vouch")
	if gossip and randf() < 0.7:
		var g: Array = gossip.pick_random(); _talk(g[0], g[1]); return
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
		if l[1].begins_with("g_"):   # talking about you: a look your way
			var dm: Vector3 = player.position - p.body.position
			p.body.rotation.y = atan2(-dm.x, -dm.z)
		var voice_id: String = _vk(p) + "_" + l[1]
		p.audio.stream = _clip(voice_id); p.audio.play(); played.append(voice_id)
		p["line"] = l[1]
		if LINES.has(l[1]): _perceive(p, LINES[l[1]][0])
		await _wait_line(p.audio)
		p["line"] = ""
		if l[1].begins_with("g_") and not p.gone: _spread(p, l[1].trim_prefix("g_"))
		if l[1] == "v_ok":   # they take it from someone they trust
			for o in people:
				if o == p or o.gone or o.spot != p.spot: continue
				if o.pic.doubt > 0 and not o.pic.vouched: o.pic.vouched = true; _doubt(o, -1)
				o.glance = 3.0
		if l[1] == "al_sec":   # security looks your way, and so does everyone there
			for o in people:
				if not o.gone and (o.spot == p.spot or o.role == "security"): o.glance = 4.0
			var sc := _find("security")
			if sc and not hunting and not done:
				hunting = true; hunted = true; sc.timer = INF
				slots_taken.erase("%s:%d" % [sc.spot, sc.slot]); sc.slot = -1
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
			if _at(p) and not p.coming and not p.errand and not p.tell and not p.following and not p.shadow and not (hunting and p.role == "security") and not (distract_t > 0.0 and p.role == "security"): _walk(p, dt)
	_doubters(dt)
	_distract(dt)
	_heat(dt)
	_hunt(dt)
	if escorting: _escort(dt); return
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
	throw_btn.visible = false
	shoot_btn.visible = ammo > 0 and not done and not escorting and not phone_open and asking.is_empty() and not back
	shoot_btn.text = "Shoot (%d)" % ammo
	if not talk_wait.is_empty():   # you asked for them: they turn to you as soon as they're free
		var tw: Dictionary = talk_wait
		if tw.gone or done or not asking.is_empty() or back or player.position.distance_to(tw.body.position) > 3.2: talk_wait = {}; talk_btn.text = "Talk"
		elif not tw.busy: talk_wait = {}; talk_btn.text = "Talk"; _talk_to(tw)
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
	talk_btn.visible = (not _talk_target().is_empty() or not talk_wait.is_empty()) and not phone_open
	comp_btn.visible = not _companion().is_empty() and not phone_open
	leave_btn.visible = not done and not escorting and asking.is_empty() and player.position.z > 5.3 and absf(player.position.x + 6.0) < 1.2
	var lmat: StandardMaterial3D = lift_pad.material_override   # pulses when you need to get out
	lmat.emission_energy_multiplier = (1.4 + 1.2 * sin(clock * 6.0)) if (hunting or heat_stage >= 2) and not done else 0.6
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
	throw_btn = _btn("Throw glass", 24, Vector2(150, 70)); throw_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	throw_btn.position = Vector2(-174, 104); root.add_child(throw_btn); throw_btn.pressed.connect(func(): _throw()); throw_btn.visible = false
	shoot_btn = _btn("Shoot (%d)" % MAG, 24, Vector2(150, 70)); shoot_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shoot_btn.position = Vector2(-174, 104); root.add_child(shoot_btn); shoot_btn.pressed.connect(func(): _shoot())
	talk_btn = _btn("Talk", 34, Vector2(200, 110)); root.add_child(talk_btn); talk_btn.pressed.connect(_talk_btn)   # walk up to someone and talk
	talk_btn.anchor_left = 1; talk_btn.anchor_right = 1; talk_btn.anchor_top = 1; talk_btn.anchor_bottom = 1
	talk_btn.offset_left = -240; talk_btn.offset_right = -30; talk_btn.offset_top = -170; talk_btn.offset_bottom = -40; talk_btn.visible = false
	comp_btn = _btn("Talk (with you)", 24, Vector2(210, 80)); root.add_child(comp_btn); comp_btn.pressed.connect(func(): _talk_to(_companion()))   # whoever's walking with you
	comp_btn.anchor_left = 1; comp_btn.anchor_right = 1; comp_btn.anchor_top = 1; comp_btn.anchor_bottom = 1
	comp_btn.offset_left = -240; comp_btn.offset_right = -30; comp_btn.offset_top = -270; comp_btn.offset_bottom = -185; comp_btn.visible = false
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
	_plg("Handler, in your ear (English): " + HANDLER[id])
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


func _finish(walked_out := false) -> void:   # into the lift: the debrief
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
	if walked_out: t += "Escorted out.\n\n"
	if downed: t += "You took down: %s.\n\n" % ", ".join(downed.map(func(id): var q := _who_is(id); return "a guest" if q.role == "guest" else ROLE_NAME[q.role][1]))
	elif hunted: t += "You got out before security reached you.\n\n"
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
	_plg("THE END. Screen shows:\n" + t)


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
	if m.any(func(o): return o.pic.doubt >= 2):   # someone here doubts you: backs turn, voices drop
		for o in m: o.glance = -4.0
		reactions.append("cold"); return
	if m.any(func(o): return o.pic.doubt == 1):   # curious about you: they look you over, nobody asks
		for o in m.filter(func(o): return o.pic.doubt == 1 and not o.busy): o.glance = 2.5
		reactions.append("look"); return
	var fresh := m.filter(func(o): return not o.pic.met and o.id in ASKERS and not o.busy)
	var r := randf()
	if fresh and r < 0.65:
		var who: Dictionary = fresh.pick_random()
		if who.pic.second and randf() < 0.6: _ask(who, m, who.pic.second.pick_random()); reactions.append("check"); return
		_ask(who, m); reactions.append("ask"); return
	if fresh.is_empty() or r < 0.85:   # a look (or a nod, if they've met you), then back to their talk
		var lookers := m.filter(func(o): return not o.busy); lookers.shuffle()
		for o in lookers.slice(0, randi_range(1, 2)): o.glance = randf_range(1.2, 2.2)
		reactions.append("glance"); return
	reactions.append("ignore")   # they don't care who you are


func _ask(p: Dictionary, group: Array, check := "", fact := "", q := -1) -> void:   # "and who are you?", or "I heard you're…?"
	asking = p; ask_group = group; p.busy = true; ask_tries = 0; ask_phone = false
	ask_check = check != ""
	if ask_check:
		ask_fact = _fact(check); ask_q = 0; ask_text = CHECK[check]; ask_clip = "c_" + check
	else:
		ask_fact = _fact(fact) if fact != "" else _pick_fact(p)
		ask_q = q if q >= 0 and q < ask_fact.qs.size() else randi() % ask_fact.qs.size()
		ask_text = ask_fact.qs[ask_q][0]; ask_clip = "q_%s_%d" % [ask_fact.k, ask_q]
	var d: Vector3 = player.position - p.body.position
	p.body.rotation.y = atan2(-d.x, -d.z)
	for o in group:
		if o != p and not o.busy: o.glance = 3.0
	_question()


func _pick_fact(p: Dictionary) -> Dictionary:   # something about you they don't know yet (and nothing silly: the host knows she invited you)
	var ok := Cover.FACTS.filter(func(f): return not (p.role == "host" and f.k == "invited"))
	var left := ok.filter(func(f): return not (f.k in p.pic.told))
	return (left if left else ok).pick_random()


func _question() -> void:
	var p: Dictionary = asking
	ask_t = 15.0; picked.clear(); _show_pick()
	ask_label.text = ask_text; hear_btn.visible = true; done_btn.visible = false
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
	tile_map.clear()
	for t in deck:   # Korean only in here
		var b := _btn(_chunk(t)[0].trim_prefix("~"), 26, Vector2(104, 80)); b.pressed.connect(_pick.bind(t)); tile_box.add_child(b)
		tile_map[b.text] = t
	ask_ui.visible = true
	_plg("ASKED: %s speaks to you, waiting for your answer (15 s). Your pieces: %s" % [_desc(p), " | ".join(tile_map.keys())])
	ask_busy = true
	await _line(p, ask_clip)
	ask_busy = false


func _line(p: Dictionary, id: String) -> void:   # one person says one line out loud, and you see it if you're close
	if p.gone: return
	var vid := _vk(p) + "_" + id
	p.audio.stream = _clip(vid); p.audio.play(); played.append(vid)
	p["said"] = ask_text if id == ask_clip else REACT.get(id.trim_prefix("x_"), [""])[0]
	if id.begins_with("ans_"): p["said"] = ANS[_vk(p)][id.trim_prefix("ans_")]
	if LINES.has(id): p["said"] = LINES[id][0]
	_perceive(p, p.said)
	await _wait_line(p.audio)
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
	hear.pressed.connect(_hear_q); hear_btn = hear
	var arow := HBoxContainer.new(); arow.add_theme_constant_override("separation", 14); left.add_child(arow)
	ans_label = _label(36); ans_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; arow.add_child(ans_label)
	var clr := _btn("Clear", 22, Vector2(100, 54)); arow.add_child(clr); clr.pressed.connect(func(): picked.clear(); _show_pick())
	done_btn = _btn("Done", 22, Vector2(100, 54)); arow.add_child(done_btn); done_btn.visible = false
	done_btn.pressed.connect(func(): if back and not ask_busy: _back_end())
	tile_box = HBoxContainer.new(); tile_box.add_theme_constant_override("separation", 8); left.add_child(tile_box)
	say_btn = _btn("Say it", 34, Vector2(180, 120)); say_btn.size_flags_vertical = Control.SIZE_SHRINK_END; row.add_child(say_btn); say_btn.pressed.connect(_say_it)
	var gs := StyleBoxFlat.new(); gs.bg_color = Color(0.2, 0.55, 0.3); gs.set_corner_radius_all(10); say_btn.add_theme_stylebox_override("normal", gs)
	ask_ui.visible = false


func _fact(k: String) -> Dictionary:
	if BACK.has(k): return BACK[k]
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
	ans_label.text = _joined(picked) if picked else ("Tap the pieces to ask" if back else "Tap the pieces to answer")
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


func _judge_check(p: Array, f: Dictionary) -> String:   # good · differ · or judged like any answer
	var first: String = _chunk(p[0])[0]
	if first == "네": return "good" if p.size() == 1 or _judge(p.slice(1), f) == "good" else "wrong"
	if first == "아니요": return "differ"
	return _judge(p, f)


func _wait_line(au: Node) -> void:   # until the line's been said (the tester just waits its length, on the fast clock)
	if test:
		var n: float = au.stream.get_length() if au.stream else 0.0
		au.stop(); await _secs(maxf(n, 0.05)); return
	await get_tree().process_frame
	while is_instance_valid(au) and au.playing: await get_tree().process_frame


func _me(id: String) -> void:   # Daniel says it
	me_voice.stream = _mine(id); me_voice.play()
	await _wait_line(me_voice)


func _say_it() -> void:
	if ask_busy or picked.is_empty() or asking.is_empty(): return
	if back: _say_back(); return
	ask_busy = true
	var who: Dictionary = asking
	var r := _judge_check(picked, ask_fact) if ask_check else _judge(picked, ask_fact)
	if r == "good":
		if picked[0][0] == "yn": await _me("t_yn_%d" % picked[0][1])
		if picked.size() > 1 or picked[0][0] != "yn": await _me("a_" + ask_fact.k)
	else:
		for t in picked: await _me("t_%s_%d" % t)
	if asking != who: return
	if r == "differ": _ask_end("differ"); return
	if r != "good" and r != "wrong" and ask_tries == 0:   # close: they didn't quite catch it
		ask_tries = 1
		await _line(who, HUH.pick_random())
		if asking == who: _question()
		return
	_ask_end("good" if r == "good" else "bad")


func _ask_end(how: String) -> void:   # how it went decides what they think of you, and they remember
	if back: _back_end(); return
	var who: Dictionary = asking
	if who.is_empty(): return
	asking = {}; ask_ui.visible = false; ask_busy = true
	var k: String = ask_fact.k
	for o in ask_group:   # they all heard it
		if o.gone: continue
		o.pic.met = true
		if how == "good" and not (k in o.pic.told): o.pic.told.append(k)
		if how == "good": o.pic.second.erase(k)   # now they heard it from you
		if how == "good" and not ask_phone and o.pic.doubt == 0: o.pic.ok = true
		if how != "good":
			_doubt(o, 2 if how == "differ" and o == who else 1)
			if o.id in ASKERS: o.pic.concern = {"why": how, "k": k, "q": ask_q, "src": "direct" if o == who else "saw"}   # and why
		elif o.pic.concern.get("k", "") == k or (o == who and who.came): o.pic.concern = {}   # that's cleared up
	reactions.append("answer_" + how)
	if how == "good" and (ask_check or who.came): _doubt(who, -1)   # you passed their check
	if how == "good" and (ask_check or who.came): await _line(who, "x_fine" if not ask_phone else "x_cool")
	elif how == "good": await _line(who, "x_ok" if not ask_phone else "x_cool")
	elif how == "differ": await _line(who, "x_differ")
	elif how != "walked": await _line(who, "x_cool")
	if how == "good" and not done and not skip_turn and not who.gone and player.position.distance_to(who.body.position) < 3.2:
		_turn(who); return   # your turn: ask them something
	who.busy = false; ask_busy = false
	if who.came: who.came = false; _send_back(who)
	if how != "good":
		for o in ask_group: o.glance = -3.0   # they turn back to each other


func _turn(who: Dictionary) -> void:
	back = true; asking = who; ask_group = [who]; ask_tries = 0; ask_busy = false
	_turn_ui()


func _turn_ui() -> void:   # every question piece you know, mixed up
	ask_t = 12.0; picked.clear(); _show_pick()
	ask_label.text = "Your turn: ask them something"; hear_btn.visible = false; done_btn.visible = true
	var deck := []
	for q in _turn_keys(asking):
		for i in BACK[q].chunks.size(): deck.append([q, i])
	deck.shuffle()
	for c in tile_box.get_children(): c.queue_free()
	tile_map.clear()
	for t in deck:
		var b := _btn(_chunk(t)[0], 24, Vector2(104, 80)); b.pressed.connect(_pick.bind(t)); tile_box.add_child(b)
		tile_map[b.text] = t
	ask_ui.visible = true
	_plg("YOUR TURN to ask %s something (12 s). Pieces: %s. Or: done" % [_desc(asking), " | ".join(tile_map.keys())])


func _judge_back(p: Array) -> String:   # the question you built, or "" if it isn't one
	for q in BACK:
		var want := []
		for i in BACK[q].chunks.size(): want.append([q, i])
		if p == want: return q
	return ""


func _say_back() -> void:
	ask_busy = true
	var who: Dictionary = asking
	var q := _judge_back(picked)
	if q != "": await _me("ask_" + q)
	else:
		for t in picked: await _me("t_%s_%d" % t)
	if asking != who or not back: return
	if q == "":
		if ask_tries == 0:   # they try to work out what you meant
			ask_tries = 1; await _line(who, HUH.pick_random())
			if asking == who and back: _turn_ui(); ask_busy = false
			return
		await _line(who, "x_cool"); _doubt(who, 1); _back_end(); return   # they give up, and wonder about you
	var k := q.trim_prefix("b_")
	if k == "go": await _go_ask(who); _back_end(); return
	if k == "thanks":   # off you go, and thanks
		await _line(who, "go_bye"); _back_end(); _end_follow(who); return
	if k in who.pic.asked:   # you asked that already
		await _line(who, "x_cool")
		_doubt(who, 1)   # and again, and again: they start to wonder what you're up to
	else:
		who.pic.asked.append(k); reactions.append("told_" + k)
		await _line(who, "ans_" + k)
	_back_end()


func _back_end() -> void:   # your turn's over: they go back to their talk
	var who: Dictionary = asking
	back = false; asking = {}; ask_ui.visible = false; ask_busy = false; done_btn.visible = false
	if who.is_empty(): return
	who.busy = false
	if who.came: who.came = false; _send_back(who)


func _hear_q() -> void:
	if not asking.is_empty() and not ask_busy: _line(asking, ask_clip)


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
	await get_tree().process_frame; await get_tree().process_frame   # (on the fast clock a short wait can be a single frame)


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
	for p in people: p.calm_t = 0.0
	for p in people: p.pic = {"met": false, "told": [], "second": [], "ok": false, "wary": false, "doubt": 0, "checked": false, "told_sec": false, "vouched": false, "asked": [], "concern": {}}


func _guest_group() -> Array:   # a guest, and whoever's with them (everyone put in their places first)
	for o in people:
		if not o.gone and not o.leaving and o.slot >= 0 and o.id != "bartender": o.body.position = _slot_pos(o.spot, o.slot)
	var gs := people.filter(func(o): return o.role == "guest" and not o.gone and not o.leaving and o.spot != "elevator")
	gs.shuffle()
	var p: Dictionary = gs[0]
	return [p] + people.filter(func(o): return not o.gone and o.spot == p.spot and o != p)   # the guest first


func _facing_away(p: Dictionary) -> bool:
	var fwd := Vector3(-sin(p.body.rotation.y), 0, -cos(p.body.rotation.y))
	var to_me: Vector3 = player.position - p.body.position; to_me.y = 0
	return fwd.dot(to_me.normalized()) < 0.0


func _run_test() -> void:
	AudioServer.set_bus_mute(0, true)
	skip_turn = true; no_heat = true
	Engine.time_scale = FAST; Engine.physics_ticks_per_second = int(60 * FAST); Engine.max_physics_steps_per_frame = int(8 * FAST)   # same small steps, just more of them
	get_window().position = Vector2i(-3000, 60)
	await _secs(0.5)
	_check(people.size() == 9 and ROLES.all(func(r): return not _find(r).is_empty()), "nine people at the party, one of each role")
	_check(people.all(func(p): return p.tag.visible == false), "nobody wears a name tag")
	_check(not HANDLER.has("h_him") and not HANDLER.has("h_wrong"), "the handler has no 'that's him' or 'wrong': he doesn't know their faces")
	await _secs(1.5); await _shot("g1_room")
	var started := talk_count
	await _secs(14.0)
	_check(talk_count - started >= 2 and talks <= 2, "they keep talking among themselves (%d conversations in 14 s)" % (talk_count - started))
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
	for off in [Vector3(0, 0, 3.2), Vector3(0, 0, -3.2), Vector3(3.2, 0, 0), Vector3(-3.2, 0, 0), Vector3(2.4, 0, 2.4), Vector3(-2.4, 0, -2.4)]:
		await _put(asst.body.position.lerp(br.body.position, 0.5) + off)   # somewhere you actually fit, a few steps back
		if player.position.distance_to(asst.body.position) > 2.4 and player.position.distance_to(br.body.position) > 2.4: break
	await _secs(0.1)
	_check(asst.ko.text == "" and br.ko.text == "", "a couple of steps back: no words on screen, you only hear them (%.1f m, '%s' '%s')" % [player.position.distance_to(asst.body.position), asst.ko.text, br.ko.text])
	_check(asst.audio.attenuation_filter_db < -10.0, "and voices go muffled with distance")
	while asst.busy: await _secs(0.1)
	await _put(Vector3(-0.5, 0, 6.3))
	# business stays private near a stranger
	reacted.clear()
	await _put(br.body.position + Vector3(0, 0, 2.0))
	while br.busy or asst.busy: await _secs(0.1)
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
	_check(guesses.get("host", "") == bt.id and not played.slice(said_before).any(func(x): return x.begins_with("h_")), "a wrong mark is saved just the same, and nobody says a word")
	_tag("bartender")
	_check(guesses.get("bartender", "") == bt.id and not guesses.has("host"), "one mark per person: re-marking her moves it")
	_toggle_phone()
	await _put(Vector3(-0.5, 0, 6.3))
	# they notice you: not everyone the same way
	var kinds := {}
	for i in 80:
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
	# your turn: ask them back
	_reset_pics(); skip_turn = false
	grp = _guest_group(); g = grp[0]; await _beside(g)
	_ask(g, grp); await _secs(0.1); await _wait_free()
	picked = _right_pieces(ask_fact); await _say_it(); await _secs(0.2); await _wait_free()
	_check(back and asking == g and ask_ui.visible and ask_label.text.begins_with("Your turn") and tile_box.get_children().any(func(b): return b.text == "성함이"), "answer well, and it's your turn: ask them something")
	await _shot("g7_turn")
	picked = [["b_name", 0], ["b_name", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(played.has(_vk(g) + "_ans_name") and "name" in g.pic.asked and not back and asking.is_empty(), "성함이 어떻게 되세요? and they tell you: " + ANS[_vk(g)].name)
	_turn(g); picked = [["b_name", 0], ["b_name", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.doubt == 1 and not back, "ask the same person the same thing twice: now they're curious about you")
	while g.busy: await _secs(0.1)
	_talk_to(g); picked = [["b_name", 0], ["b_name", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.doubt == 2, "and a third time: they doubt you (doubt=%d back=%s asking=%s)" % [g.pic.doubt, back, asking.get("id", "")])
	_doubt(g, -3); g.coming = false   # (before they come over to check you)
	_reset_pics()
	var bk := _find("broker"); await _beside(bk)
	_turn(bk); picked = [["b_job", 0], ["b_job", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(played.has("broker_ans_job"), "ask the broker what he does: 사업합니다, and no more")
	_reset_pics(); g = grp[0]
	while g.busy: await _secs(0.1)
	await _beside(g)
	_talk_to(g); picked = [["b_name", 1], ["b_name", 0]]; var before_huh := played.size(); await _say_it(); await _secs(0.2); await _wait_free()
	_check(back and played.slice(before_huh).any(func(x): return HUH.any(func(h): return x == _vk(g) + "_" + h)), "a question that doesn't make sense: they try to work out what you meant")
	picked = [["b_job", 1], ["b_from", 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(not back and g.pic.doubt == 1 and played.has(_vk(g) + "_x_cool"), "still no sense: 아... 네., and they wonder about you")
	_turn(g); done_btn.pressed.emit(); await _secs(0.1)
	_check(not back and asking.is_empty(), "or tap Done and ask nothing")
	_reset_pics(); skip_turn = true
	grp = _guest_group(); g = grp[0]; await _beside(g); reactions.clear()
	for o in grp: o.pic.met = true   # (as if they'd just met you)
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
	_check(not asking.is_empty() and HUH.any(func(h): return played.has(_vk(g) + "_" + h)) and ask_label.text == first_q, "almost right: they ask you to say it again (a few different ways) and ask again")
	var wrong_f: Dictionary = Cover.FACTS.filter(func(f): return f.k != ask_fact.k)[0]
	picked = [[wrong_f.k, 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.wary and not g.pic.ok and played.has(_vk(g) + "_x_cool"), "a wrong answer: 아... 네. and they're wary of you now")
	var ck: String = g.pic.concern.get("k", "")
	_check(ck == ask_fact.k and g.pic.concern.src == "direct" and grp.filter(func(o): return o != g and o.id in ASKERS).all(func(o): return o.pic.concern.get("src", "") == "saw"), "they remember why: the question you got wrong (the others in the group saw it)")
	await _secs(1.5)
	_check(g.audio.volume_db < -6.0, "wary of you: they lower their voices when you're near")
	_check(g.pic.doubt == 1, "one slip: curious, not more")
	var looked := false
	for i in 160:
		await _secs(0.1)
		if not g.busy and not _facing_away(g) and g.glance > 0.0: looked = true; break
	_check(looked, "curious: they keep looking you over")
	reacted.clear(); reactions.clear(); _react(g.spot)
	_check(reactions == ["look"], "go back to that group: they look you over, nobody asks")
	await _shot("g6_wary")
	# a second slip: doubtful, and they come to you
	await _put(Vector3(-0.5, 0, 6.3)); await _secs(0.2)
	_doubt(g, 1)
	reacted.clear(); reactions.clear(); _react(g.spot)
	_check(reactions == ["cold"], "doubtful: that group turns their backs")
	var came := false
	for i in 150:
		await _secs(0.1)
		if asking == g: came = true; break
	_check(came and not ask_check and ask_fact.k == ck and player.position.distance_to(g.body.position) < 1.8, "and they walk over to you and ask that same thing again: %s (%s %s check=%s %.1f m, %s)" % [ask_label.text, g.id, str(g.pic), ask_check, player.position.distance_to(g.body.position), str(reactions)])
	await _wait_free()
	picked = [["yn", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.doubt == 3, "get it wrong again: alarmed")
	var told := false
	for i in 250:
		await _secs(0.1)
		if played.has(_vk(g) + "_al_sec"): told = true; break
	var sc := _find("security")
	for i in 60:
		if hunting: break
		await _secs(0.1)
	_check(hunting, "told: security comes for you")
	hunting = false; var scc := _find("security"); _go(scc, "door"); scc.body.position = _slot_pos(scc.spot, scc.slot); scc.speed = 1.4   # (tester) call him off for now
	_check(told, "alarmed: they go and tell security, 팀장님, 저 분 좀 보세요 (%s at %s slot %d at=%s errand=%s tell=%s busy=%s doubt=%d told_sec=%s · security at %s at=%s busy=%s · room=%s)" % [g.id, g.spot, g.slot, _at(g) if g.slot >= 0 else false, g.errand, g.tell, g.busy, g.pic.doubt, g.pic.told_sec, sc.spot, _at(sc), sc.busy, _has_room(sc.spot)])
	_check(not g.coming, "and the one who came over goes back to the party")
	# what they come back with depends on what they know
	_reset_pics()
	var hx := _find("g3")
	while hx.busy: await _secs(0.1)
	await _beside(hx)
	hx.pic.doubt = 2; hx.pic.concern = {"why": "heard_odd", "k": "", "q": -1, "src": "heard"}
	_come_check(hx); await _secs(0.1); await _wait_free()
	_check(asking == hx and not ask_check, "they only heard you're odd: an ordinary question, never 'I heard you're…'")
	picked = _right_pieces(ask_fact); await _say_it(); await _secs(0.2); await _wait_free()
	_check(hx.pic.doubt == 1 and hx.pic.concern.is_empty() and played.has(_vk(hx) + "_x_fine"), "answer it well: 아, 그렇군요, concern cleared and doubt down a step")
	_reset_pics(); await _beside(hx)
	hx.pic.doubt = 2; hx.pic.told = ["from"]; hx.pic.second = ["from"]; hx.pic.concern = {"why": "differ", "k": "from", "q": 0, "src": "direct"}
	_come_check(hx); await _secs(0.1); await _wait_free()
	_check(asking == hx and ask_check and ask_fact.k == "from", "you contradicted what they heard: they come back to check it, " + ask_label.text)
	_ask_end("walked"); await _secs(0.2)
	_reset_pics(); await _beside(hx)
	hx.pic.doubt = 2; hx.pic.concern = {"why": "walked", "k": "job", "q": 1, "src": "direct"}
	_come_check(hx); await _secs(0.1); await _wait_free()
	_check(asking == hx and not ask_check and ask_text == Cover.FACTS.filter(func(f): return f.k == "job")[0].qs[1][0], "you walked off mid-question: they ask you the same thing again, " + ask_text)
	_ask_end("walked"); await _secs(0.2)
	_reset_pics(); await _beside(hx)
	hx.pic.doubt = 2
	_come_check(hx); await _secs(0.1); await _wait_free()
	_check(asking == hx and not ask_check, "doubt with nothing heard: no 'I heard you're…'")
	_ask_end("walked"); await _secs(0.2)
	var hst := _find("host")
	_check(range(80).all(func(_i): return _pick_fact(hst).k != "invited"), "the host never asks who invited you")
	var pal_seen := {}
	for c in get_meta("looks").values(): pal_seen[c] = 1
	_check(pal_seen.size() == 11, "everyone wears a different colour, drawn fresh each party")
	# 같이 가요
	_reset_pics()
	var fa := _find("g1"); var fb := _find("g2")
	while fa.busy or fb.busy: await _secs(0.1)
	fb.spot = fa.spot
	var tsp: String = GUEST_SPOTS.filter(func(x): return x != fa.spot and _free_slots(x) >= 2)[0]
	await _go_together(fa, fb, tsp)
	_check(played.has(_vk(fa) + "_w_go") and played.has(_vk(fb) + "_go_yes") and fa.spot == tsp and fb.spot == tsp, "friends move on together: 같이 가요. 네, 좋아요. (you hear it first)")
	_reset_pics()
	var fg := _find("g3")
	for i in 30:
		if not fg.busy: break
		await _secs(0.1)
	fg.busy = false   # (an earlier test can leave them marked busy)
	await _beside(fg)
	for i in 100:   # (until they're not mid-conversation)
		await _secs(0.1)
		if _talk_target() == fg and not fg.busy: break
	_check(talk_btn.visible and _talk_target() == fg, "stand beside someone free: a Talk button (target=%s fg=%s coming=%s doubt=%d asking=%s back=%s)" % [_talk_target().get("id", ""), fg.id, fg.coming, fg.pic.doubt, asking.get("id", ""), back])
	_talk_btn()
	for i in 100:   # (if a chat just started, they finish it first)
		await _secs(0.1)
		if back: break
	_check(back and asking == fg and tile_map.has("같이") and tile_map.has("가요") and not tile_map.has("감사합니다"), "Talk: your turn, with 같이 + 가요 among the pieces")
	fg.pic.ok = true; fg.pic.met = true
	var fol := false
	for tries in 8:
		picked = [["b_go", 0], ["b_go", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
		if fg.following: fol = true; break
		await _secs(0.2); _talk_btn()
		for i in 100:
			await _secs(0.1)
			if back: break
	_check(fol and played.has(_vk(fg) + "_go_yes"), "someone who likes you: 같이 가요, 네, 좋아요, and they come with you")
	await _put(player.position + Vector3(4.0, 0, 0)); await _secs(3.0)
	if player.position.distance_to(fg.body.position) > 2.2: await _put(Vector3(-0.5, 0, 6.3)); await _secs(3.0)
	_check(fg.following and player.position.distance_to(fg.body.position) < 2.2, "walk off: they keep up, a step behind (%.1f m)" % player.position.distance_to(fg.body.position))
	await _put(Vector3(-0.5, 0, 6.3)); await _secs(5.0)   # somewhere quiet (and they catch up)
	if not asking.is_empty(): _ask_end("walked"); await _secs(0.3)
	_check(comp_btn.visible, "with someone along: a Talk (with you) button (%.1f m, asking=%s)" % [player.position.distance_to(fg.body.position), asking.get("id", "")])
	comp_btn.pressed.emit(); await _secs(0.1)
	_check(back and asking == fg and tile_map.has("감사합니다") and not tile_map.has("같이"), "talk to your companion: you can say 감사합니다 (talking to %s, %s following=%s %.1f m busy=%s)" % [asking.get("id", "nobody"), fg.id, fg.following, player.position.distance_to(fg.body.position), fg.busy])
	picked = [["b_thanks", 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(not fg.following and played.has(_vk(fg) + "_go_bye") and fg.spot != "", "감사합니다: 저 이만 가 볼게요, and back to the party")
	_reset_pics(); fg.pic.doubt = 1
	_check(not _will_follow(fg) and not _will_follow(_find("security")), "someone who doubts you, or security: never")
	var hh := _find("host"); var bb := _find("broker")
	hh.pic.ok = false; bb.pic.ok = false
	_check(range(30).all(func(_i): return not _will_follow(hh) and not _will_follow(bb)), "the host and the broker won't, unless they like you")
	hh.pic.ok = true; bb.pic.ok = true
	_check(range(40).any(func(_i): return _will_follow(hh)) and range(60).any(func(_i): return _will_follow(bb)), "once they like you: the host often comes along, the broker sometimes")
	_reset_pics(); fg.pic.ok = true; fg.pic.met = true
	_start_follow(fg); fg.follow_t = 0.2; await _secs(0.6)
	_check(not fg.following, "after a while they go back to their own evening")
	# repair: pass their check
	_reset_pics()
	await _beside(g)
	g.pic.doubt = 2; g.pic.wary = true; g.pic.checked = true; g.pic.told = ["from"]
	_ask(g, [g], "from"); await _secs(0.1); await _wait_free()
	picked = [["yn", 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.doubt == 1 and played.has(_vk(g) + "_x_fine") and not g.pic.checked, "pass their check: 아, 그렇군요, and their doubt drops a step")
	# repair: someone who likes you vouches
	_reset_pics()
	var va := _find("g3"); var vb := _find("g4")
	while va.busy or vb.busy: await _secs(0.1)
	vb.spot = va.spot; va.pic.ok = true; vb.pic.doubt = 2; vb.pic.wary = true
	_check(_gossip([va, vb]).any(func(o): return o[0] == "vouch" and o[1][0][0] == va), "someone who likes you, standing with someone who doubts you: they can vouch for you (%s %s / %s %s)" % [va.id, str(va.pic), vb.id, str(vb.pic)])
	await _talk("vouch", [[va, "v_ok"], [vb, "r_really"]])
	_check(vb.pic.doubt == 1 and played.has(_vk(va) + "_v_ok"), "저 분, 괜찮은 분이에요: their doubt drops a step (%s doubt=%d vouched=%s %s)" % [vb.id, vb.pic.doubt, vb.pic.vouched, str(reactions.slice(-4))])
	_check(not _gossip([va, vb]).any(func(o): return o[0] == "vouch"), "a vouch works once per person")
	# repair: keep out of their way
	_reset_pics()
	vb.pic.doubt = 1; vb.pic.wary = true; vb.pic.told = ["job"]
	await _beside(vb); vb.calm_t = COOL - 0.3; await _secs(0.6)
	_check(vb.pic.doubt == 1, "stay near them and nothing cools")
	for far in [Vector3(-0.5, 0, 6.3), Vector3(8.0, 0, 5.5), Vector3(-8.0, 0, -5.0), Vector3(8.5, 0, -5.5), Vector3(-8.5, 0, 5.5)]:
		await _put(far)
		if player.position.distance_to(vb.body.position) > 7.0: break
	vb.calm_t = COOL - 0.3; await _secs(0.6)
	_check(vb.pic.doubt == 0 and "job" in vb.pic.told, "keep away for a while: their doubt cools, but they still know what you said (%.1f m away)" % player.position.distance_to(vb.body.position))
	_reset_pics()
	# silence
	_reset_pics(); for p in people: p.glance = 0.0
	await _put(Vector3(-0.5, 0, 6.3))
	grp = _guest_group(); g = grp[0]; await _beside(g)
	_ask(g, grp); await _secs(0.1); await _wait_free()
	ask_t = 0.05; await _secs(0.3); await _wait_free()
	_check(asking.is_empty() and g.pic.wary, "say nothing and they give up on you, wary (%s asking=%s back=%s doubt=%d busy=%s)" % [g.id, asking.get("id", ""), back, g.pic.doubt, ask_busy])
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
	# word gets around
	var ga := _find("g1"); var gb := _find("g2")
	ga.pic.told = ["job"]
	_check(_gossip([ga, gb]).any(func(o): return o[1][0][0] == ga and o[1][0][1] == "g_job") and not _gossip([gb, ga]).any(func(o): return o[1][0][0] == gb), "someone who knows your job, standing with someone who doesn't: they can pass it on")
	_reset_pics()
	while ga.busy or gb.busy: await _secs(0.1)
	gb.spot = ga.spot
	ga.pic.told = ["from"]; ga.pic.met = true
	await _talk("gossip", [[ga, "g_from"], [gb, "r_really"]])
	_check("from" in gb.pic.told and "from" in gb.pic.second and played.has(_vk(ga) + "_g_from") and played.has(_vk(gb) + "_r_really"), "저 분, LA에서 왔대요: now the other one knows, secondhand")
	_check(gb.glance > 0.0, "and they look over at you")
	var left := Cover.FACTS.filter(func(f): return not (f.k in gb.pic.told))
	_check(not left.any(func(f): return f.k == "from"), "they won't ask you where you're from")
	await _beside(gb)
	_ask(gb, [gb], "from"); await _secs(0.1); await _wait_free()
	_check(ask_label.text == CHECK.from and played.has(_vk(gb) + "_c_from"), "but they may check it: " + ask_label.text)
	picked = [["yn", 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(gb.pic.ok and not ("from" in gb.pic.second) and not gb.pic.wary, "네 is enough: now they've heard it from you")
	_reset_pics()
	gb.pic.told = ["job"]; gb.pic.second = ["job"]
	_ask(gb, [gb], "job"); await _secs(0.1); await _wait_free()
	picked = [["yn", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(gb.pic.wary and played.has(_vk(gb) + "_x_differ"), "say 아니요 to what they heard: 네? 다르게 들었는데요, and they're wary")
	_reset_pics()
	ga.pic.wary = true
	while ga.busy or gb.busy: await _secs(0.1)
	await _talk("gossip", [[ga, "g_odd"], [gb, "r_really"]])
	_check(gb.pic.wary, "and doubt travels too: 저 분, 좀 이상해요")
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
	# Talk while they're chatting: they finish, then turn to you
	hold = true
	for p in people: p.busy = false
	_reset_pics(); skip_turn = true
	var tg := _guest_group(); var tw: Dictionary = tg[0]; await _beside(tw)
	var mate: Dictionary = tg[1] if tg.size() > 1 else _find("host")
	_talk("t", [[tw, "sq_cold"], [mate, "sa_cold"]]); await _secs(0.1)
	_check(tw.busy and talk_btn.visible, "they're mid-chat, and you still get a Talk button")
	talk_btn.pressed.emit(); await _secs(0.1)
	_check(not talk_wait.is_empty() and not back, "tap it: they finish what they're saying first")
	for i in 120:
		await _secs(0.1)
		if back: break
		if talk_wait.is_empty() and asking.is_empty() and _talk_target() == tw: talk_btn.pressed.emit()   # (someone else came up to you meanwhile: tap again)
	_check(back and asking == tw, "then they turn to you: your turn (back=%s asking=%s wait=%s busy=%s %.1f m)" % [back, asking.get("id", ""), talk_wait.get("id", ""), tw.busy, player.position.distance_to(tw.body.position)])
	_back_end(); await _secs(0.2)
	# heat: the more people doubt you, the closer security gets
	_reset_pics(); no_heat = false; heat_stage = 0; hunting = false
	var sh := _find("security"); var gsh := people.filter(func(o): return o.id in ASKERS and not o.gone)
	await _put(Vector3(-0.6, 0, 1.6))
	for i in 2: gsh[i].pic.doubt = 1
	await _secs(0.3)
	_check(heat_stage == 1 and played.has("h_heat1") and not sh.shadow, "a few people doubt you: the handler warns you, people are talking")
	for o in gsh: o.pic.checked = true   # (they'd come over to check you otherwise)
	for i in 2: gsh[i].pic.doubt = 2
	for i in 80:
		await _secs(0.1)
		if sh.shadow and player.position.distance_to(sh.body.position) < 4.0: break
	_check(heat_stage == 2 and sh.shadow and played.has("h_heat2") and player.position.distance_to(sh.body.position) < 4.0, "more of them: security leaves his post and keeps a few steps from you, watching (%.1f m)" % player.position.distance_to(sh.body.position))
	await _shot("g8_shadow")
	for o in gsh: o.pic.doubt = 0
	await _secs(0.3)
	_check(heat_stage == 0 and not sh.shadow and played.has("h_calm"), "it cools off: he backs off to his post")
	await _put(sh.body.position + (Vector3(8, 0, 0) if sh.body.position.x < 0 else Vector3(-8, 0, 0)))   # (far from him, so he can't reach you before we look)
	for i in 6: gsh[i].pic.doubt = 2
	for i in 20:
		await _secs(0.05)
		if heat_stage == 3: break
	_check(hunt_wait > 0.0, "and he takes a moment on his earpiece first: your head start")
	_check(heat_stage == 3 and hunting and played.has("h_heat3"), "the whole room doubts you: he comes for you, get to the lift (stage %d hunting=%s escorting=%s doubt %d)" % [heat_stage, hunting, escorting, _room_doubt()])
	hunting = false; hunted = false; heat_stage = 0; no_heat = true; sh.shadow = false; _send_back(sh); _reset_pics()
	# the pistol: two shots, whoever you hit drops; anyone who sees it panics
	_reset_pics(); hold = true
	for p in people: p.busy = false
	_check(ammo == MAG and gun_prop.visible and shoot_btn.visible and shoot_btn.text == "Shoot (%d)" % MAG, "you carry a pistol: a Shoot (%d) button" % MAG)
	var sd := _find("security")
	await _put(Vector3(-0.6, 0, 2.0)); sd.body.position = player.position + Vector3(4.5, 0, 0)
	hunting = true; hunted = true; slots_taken.erase("%s:%d" % [sd.spot, sd.slot]); sd.slot = -1
	body_mesh.rotation.y = PI / 2   # (facing away: you still get him, he's the one after you)
	var wit: Array = people.filter(func(o): return not o.gone and o != sd and o.id in ASKERS and o.body.position.distance_to(player.position) < 10.0)
	_shoot(); await _secs(0.5)
	_check(sd.gone and "security" in downed and not hunting and ammo == MAG - 1 and played.has("shot"), "shoot: security drops, and he's not coming for you any more")
	_check(sd.body.rotation.x < -1.0, "he's lying on the floor")
	_check(wit.is_empty() or wit.all(func(o): return o.pic.doubt == 3), "everyone who saw it is alarmed (%d of them)" % wit.size())
	_check(played.has("h_shot"), "and your handler: what are you doing?! get out")
	var tg2: Dictionary = _guest_group()[0]; await _put(tg2.body.position + Vector3(0, 0, 3.0)); var to2: Vector3 = tg2.body.position - player.position
	body_mesh.rotation.y = atan2(-to2.x, -to2.z)
	ammo = 1; _shoot(); await _secs(0.3)
	_check(tg2.gone and ammo == 0 and not shoot_btn.visible, "the next shot: whoever's in front of you; the last one, and you're out (hit %s)" % [downed])
	await _shot("g9_gun")
	# (put them back up for the rest of the tests)
	for q in [sd, tg2]:
		q.gone = false; q.busy = false; q.body.rotation.x = 0.0; q.body.position.y = 0.0; q.body.collision_layer = 8
		_send_back(q)
	downed.clear(); ammo = MAG; hunting = false; hunted = false; heat_stage = 0; _reset_pics()
	# leave by the lift: the debrief
	hold = true
	for p in people: p.busy = false
	await _beside(_find("host")); _tag("host")
	var sch := _find("security"); sch.body.position = Vector3(8.5, 0, -5.5)
	hunting = true; hunted = true; slots_taken.erase("%s:%d" % [sch.spot, sch.slot]); sch.slot = -1
	await _put(Vector3(-6.0, 0, 6.6)); await _secs(0.2)
	_check(leave_btn.visible and hunting, "security's coming, but you made the lift: you can leave (done=%s escorting=%s asking=%s at %s)" % [done, escorting, asking.get("id", ""), str(player.position)])
	_check(player.position.z < 7.0, "and the doors are solid: you can't walk out of the building")
	var lpe: float = (lift_pad.material_override as StandardMaterial3D).emission_energy_multiplier
	_check(lpe != 0.6, "the lift's pad pulses while security's after you")
	await _finish(); await _secs(0.3)
	await _secs(0.2)
	_check(sub.get_global_rect().position.x > 0.0 and sub.get_global_rect().end.x < get_viewport().get_visible_rect().size.x, "the handler's subtitle sits on screen")
	_check(done and end_ui.visible and end_text.text.contains("Debrief") and end_text.text.contains("김 대표님") and end_text.text.contains("right")
		and end_text.text.contains("바텐더 (bartender): right") and end_text.text.contains("not marked"), "the debrief: which of your marks were right")
	_check(end_text.text.contains("You got out before security reached you"), "and the debrief says you got away")
	await _shot("g4_end")
	print(end_text.text)
	# caught: he walks you out
	done = false; end_ui.visible = false; hunted = false
	var sc2 := _find("security")
	await _put(Vector3(-0.6, 0, 2.6)); sc2.busy = false; sc2.body.position = player.position + Vector3(3.0, 0, -1.0)
	hunting = true; hunted = true
	for i in 300:
		await _secs(0.1)
		if done and end_ui.visible: break
	_check(played.has("security_x_stop"), "he reaches you: 잠깐만요, 손님")
	_check(done and end_text.text.contains("Escorted out") and player.position.distance_to(OUT_AT) < 0.6, "and walks you out to the lift: escorted out (done=%s escorting=%s hunting=%s %.1f m from the lift, sec %.1f m away busy=%s, text starts '%s')" % [done, escorting, hunting, player.position.distance_to(OUT_AT), player.position.distance_to(sc2.body.position), sc2.busy, end_text.text.substr(0, 30).replace("
", " ")])
	print(end_text.text)
	print("DONE %d failed" % _fails)
	get_tree().quit(1 if _fails else 0)


# ---------------------------------------------------------------- play mode (godot gala.tscn -- --play): an outside player, by text
# Commands go in build/agent/cmd.txt, one per line; what you see and hear comes out in build/agent/log.txt.
# The party only moves while a command runs (10x fast); between commands it's frozen.

const PLACES := {"bar": "at the bar", "buffet": "by the buffet", "window_l": "at the left window", "window_r": "at the right window",
	"balcony": "by the balcony doors", "lounge": "on the lounge sofas", "middle": "in the middle of the room", "door": "by the back-room door", "elevator": "by the lift"}
var tags := {}     # person id -> the letter you know them by
var seen := {}     # what you last saw each person doing


func _plg(t: String) -> void:
	if not playing or plog == null: return
	plog.store_line("[%5.1f s] %s" % [clock, t]); plog.flush()


func _desc(p: Dictionary) -> String:
	if p.is_empty(): return "someone"
	return "%s (a %s in %s)" % [tags.get(p.id, "?"), "woman" if p.id in FEMALE else "man", look_names.get(p.id, "dark clothes")]


func _perceive(p: Dictionary, text: String) -> void:   # what you'd catch of a line, from where you stand
	if not playing or text == "" or p.gone: return
	var d := player.position.distance_to(p.body.position)
	if d < READ: _plg("%s says, right beside you (the words show on screen): %s" % [_desc(p), text])
	elif d < 5.0: _plg("%s says, %.0f m away (you hear it; no text on screen): %s" % [_desc(p), d, text])
	elif d < 10.0: _plg("%s is talking, %.0f m away: too far to make out" % [_desc(p), d])


func _place(pos: Vector3) -> String:
	var best := ""; var bd := INF
	for sp in SPOTS:
		var d: float = pos.distance_to(SPOTS[sp])
		if d < bd: bd = d; best = sp
	return PLACES[best] if bd < 3.0 else "walking across the room"


func _look_log() -> void:
	var t := "You look around. You are %s. You see:" % _place(player.position)
	for p in people:
		if p.gone: continue
		var d := player.position.distance_to(p.body.position)
		var doing := "talking" if p.busy else "standing"
		var fwd := Vector3(-sin(p.body.rotation.y), 0, -cos(p.body.rotation.y)); var to_me: Vector3 = player.position - p.body.position; to_me.y = 0
		if to_me.length() > 0.1 and fwd.dot(to_me.normalized()) > 0.7: doing += ", facing you"
		t += "\n  %s, %s, %.0f m away, %s" % [_desc(p), _place(p.body.position), d, doing]
	if guesses: t += "\n  Your phone marks: " + ", ".join(guesses.keys().map(func(r): return "%s = %s" % [ROLE_NAME[r][1], tags.get(guesses[r], "?")]))
	_plg(t)


func _watch() -> void:   # things you'd notice people doing
	for p in people:
		if p.gone: continue
		var d := player.position.distance_to(p.body.position)
		var now := {"look": signf(p.glance), "coming": p.coming, "hunt": hunting and p.role == "security", "follow": p.following}
		var was: Dictionary = seen.get(p.id, {"look": 0.0, "coming": false, "hunt": false})
		if d < 10.0:
			if now.look > 0 and was.look <= 0: _plg("%s looks over at you" % _desc(p))
			if now.look < 0 and was.look >= 0: _plg("%s turns away from you" % _desc(p))
			if now.coming and not was.coming: _plg("%s leaves their group and walks toward you" % _desc(p))
		if now.follow and not was.get("follow", false): _plg("%s walks along with you" % _desc(p))
		if was.get("follow", false) and not now.follow: _plg("%s leaves you and goes back to the party" % _desc(p))
		if now.hunt and not was.hunt: _plg("%s leaves his post and walks toward you, fast" % _desc(p))
		if p.leaving and not was.get("leaving", false) and d < 10.0: _plg("%s heads for the lift to leave" % _desc(p))
		now["leaving"] = p.leaving
		seen[p.id] = now


func _run_play() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().position = Vector2i(60, 60); get_window().always_on_top = true   # on your screen, so you can watch it play
	get_window().title = "Spy box: the playtest agent is playing"
	var dir := ProjectSettings.globalize_path("res://").path_join("../build/agent")
	DirAccess.make_dir_recursive_absolute(dir)
	plog = FileAccess.open(dir.path_join("log.txt"), FileAccess.WRITE)
	var cmd_path := dir.path_join("cmd.txt")
	if not FileAccess.file_exists(cmd_path): FileAccess.open(cmd_path, FileAccess.WRITE).close()
	var letters := "ABCDEFGHIJKLMN".split("")
	var order := people.duplicate(); order.shuffle()
	for i in order.size(): tags[order[i].id] = letters[i]
	Engine.physics_ticks_per_second = int(60 * FAST); Engine.max_physics_steps_per_frame = int(8 * FAST)
	_plg("You step out of the lift into the party. Commands: look | wait N | goto LETTER | away | lift | talk | talkwith | say piece|piece|... | done | mark ROLE (host broker assistant security bartender) | leave | shot NAME | quit")
	Engine.time_scale = FAST; await _secs(1.0); _handler("h_in"); await _secs(0.5); Engine.time_scale = 0.0
	var done_n := 0
	while true:
		await get_tree().create_timer(0.15, true, false, true).timeout   # (real seconds: the party is frozen)
		var all := FileAccess.get_file_as_string(cmd_path).split("\n", false)
		while done_n < all.size():
			var c := all[done_n].strip_edges(); done_n += 1
			if c == "": continue
			_plg("> " + c)
			Engine.time_scale = FAST
			await _do(c)
			_watch()
			Engine.time_scale = 0.0
			if c == "quit": plog.close(); get_tree().quit(); return
		if arrivals.size() > 0 and clock > arrivals[0][0]:
			for p in people:
				if not tags.has(p.id): tags[p.id] = letters[tags.size()]


func _do(c: String) -> void:
	var w := c.split(" ", false)
	match w[0]:
		"look": _look_log()
		"wait":
			var n := float(w[1]) if w.size() > 1 else 2.0
			var until := clock + n
			while clock < until:
				await get_tree().create_timer(0.2).timeout; _watch()
				for p in people:
					if not tags.has(p.id): tags[p.id] = "ABCDEFGHIJKLMN"[tags.size()]; _plg("%s steps out of the lift" % _desc(p))
		"goto":
			for p in people:
				if not p.gone and tags.get(p.id, "") == (w[1] if w.size() > 1 else ""): await _beside(p); _plg("You walk over and stand beside %s" % _desc(p)); break
		"away": await _put(Vector3(-0.5, 0, 6.3)); _plg("You walk off to the empty space near the lift")
		"lift":
			await _put(Vector3(-6.0, 0, 6.6)); await _secs(0.3)
			_plg("You're at the lift doors. " + ("A Leave button shows." if leave_btn.visible else "No Leave button right now."))
		"say":
			var pcs := c.substr(4).split("|", false)
			picked.clear()
			for pc in pcs:
				var k := pc.strip_edges()
				if tile_map.has(k): picked.append(tile_map[k])
				else: _plg("(there's no piece '%s')" % k)
			if picked.is_empty() or asking.is_empty(): _plg("(nobody's waiting on you)"); return
			_plg("You say: " + _joined(picked))
			await _say_it(); await _secs(0.4); await _wait_free(); await _secs(0.3)
		"done":
			if back: _back_end(); _plg("You smile and let them get back to their talk")
		"talk":
			var tt := _talk_target()
			if tt.is_empty(): _plg("(no Talk button: nobody free right beside you)")
			else: _plg("You tap Talk beside %s" % _desc(tt)); _talk_btn()
		"talkwith":
			var cc := _companion()
			if cc.is_empty(): _plg("(nobody walking with you right now)")
			else: _plg("You turn to %s, walking with you" % _desc(cc)); _talk_to(cc)
		"mark":
			var r := w[1] if w.size() > 1 else ""
			if not ROLE_NAME.has(r): _plg("(roles: host broker assistant security bartender)"); return
			var n := _nearest()
			if n.is_empty(): _plg("(nobody close enough to mark)"); return
			_tag(r); _plg("You mark %s on your phone as %s?" % [_desc(n), ROLE_NAME[r][1]])
		"leave":
			if leave_btn.visible: await _finish(); await _secs(1.5)
			else: _plg("(no Leave button here: go to the lift first)")
		"shot": await _shot("agent_" + (w[1] if w.size() > 1 else "x")); _plg("(screenshot saved: build/spy/agent_%s.png)" % (w[1] if w.size() > 1 else "x"))
		"shoot":   # at someone (by letter), or whoever's in front of you
			if ammo <= 0: _plg("(no shots left)"); return
			for p in people:
				if not p.gone and w.size() > 1 and tags.get(p.id, "") == w[1]:
					var to: Vector3 = p.body.position - player.position; body_mesh.rotation.y = atan2(-to.x, -to.z)
			_shoot(); await _secs(0.5)
		"throw":   # throw toward someone (by letter), or straight ahead
			if not glass: _plg("(no glass in your hand: the bartender will give you one)"); return
			var at := Vector3.INF
			for p in people:
				if not p.gone and w.size() > 1 and tags.get(p.id, "") == w[1]: at = p.body.position
			_plg("You throw your glass" + (" toward " + w[1] if at != Vector3.INF else " ahead of you"))
			await _throw(at); await _secs(0.5)
		"quit": pass
		"heat": _plg("(debug) room doubt %d, heat stage %d, hunting=%s, security shadow=%s | " % [_room_doubt(), heat_stage, hunting, _find("security").get("shadow", false)] + ", ".join(people.filter(func(p): return p.id in ASKERS and not p.gone).map(func(p): return "%s=%d" % [tags.get(p.id, "?"), p.pic.doubt])))
		_: _plg("(unknown command)")
