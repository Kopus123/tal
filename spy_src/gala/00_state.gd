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
const FAST := 20.0                # (tester) the clock runs this much faster, and lines take their length without playing
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
	"g_name": ["저 분, 에릭 신이래요.", "That's Eric Shin, apparently."], "g_from": ["저 분, LA에서 왔대요.", "He's from LA, apparently."],
	"g_job": ["저 분, 투자자래요.", "He's an investor, apparently."], "g_stay": ["저 분, 일주일 있대요.", "He's here a week, apparently."],
	"g_invited": ["저 분, 김 대표님이 초대하셨대요.", "CEO Kim invited him, apparently."],
	"g_parents": ["저 분, 부모님이 부산 분이시래요.", "His parents are from Busan, apparently."],
	"g_korean": ["저 분, 한국어 잘 못한대요.", "His Korean isn't good, apparently."], "g_twice": ["저 분, 두 번 왔대요.", "He's been here twice, apparently."],
	"g_odd": ["저 분, 좀 이상해요.", "That man's a bit odd."], "al_sec": ["팀장님, 저 분 좀 보세요.", "Team leader, keep an eye on that man."],
	"v_ok": ["저 분, 괜찮은 분이에요.", "He's alright, that one."],
	"w_go": ["같이 가요.", "Let's go together."], "go_yes": ["네, 좋아요.", "Sure, sounds good."], "go_no1": ["아, 지금은 좀...", "Ah, not right now..."],
	"go_no2": ["죄송해요, 얘기 중이라서요.", "Sorry, I'm in the middle of a chat."],
	# the deal: getting to the broker, and his check
	"appt_wait": ["잠깐만요.", "One moment."], "appt_in": ["들어가세요.", "Go on in."], "appt_no": ["죄송해요, 지금은 안 돼요.", "Sorry, not right now."],
	"appt_go": ["아, 네! 같이 가요.", "Oh, yes! Come with me."], "appt_meh": ["글쎄요...", "Well..."], "appt_asst": ["비서한테 얘기하세요.", "Talk to my assistant."],
	"appt_huh": ["네? 최 사장님이요?", "Sorry? President Choi?"], "deal_hi": ["어서 오세요. 앉으세요.", "Welcome. Have a seat."],
	"deal_ok": ["좋습니다. 여기 있습니다.", "Good. Here it is."],
	"b_self": ["안녕하세요. 에릭 신입니다. 최 사장님하고 약속 있어요.", "Hello. I'm Eric Shin. I have an appointment with President Choi."],
	"real_huh": ["네? 에릭 신 씨는 벌써 오셨는데요...", "Sorry? Eric Shin's already here..."], "deal_bad": ["당신, 누구야?", "Who the hell are you?"], "go_bye": ["저 이만 가 볼게요.", "I'll be off now."], "r_really": ["아, 그래요?", "Oh, really?"],
}
const BACK := {   # your turn: what you can ask (you've heard each of these asked of you)
	"b_name": {"k": "b_name", "chunks": [["성함이", ""], ["어떻게 되세요?", ""]]}, "b_job": {"k": "b_job", "chunks": [["무슨 일", ""], ["하세요?", ""]]},
	"b_from": {"k": "b_from", "chunks": [["어디에서", ""], ["오셨어요?", ""]]}, "b_host": {"k": "b_host", "chunks": [["대표님하고", ""], ["어떻게 아세요?", ""]]},
	"b_appt": {"k": "b_appt", "chunks": [["최 사장님하고", ""], ["약속 있어요", ""]]},
	"b_wine": {"k": "b_wine", "chunks": [["와인 한 잔", ""], ["주세요", ""]]},
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
const EN_MORE := {   # (English mode) what the lines with no English beside them mean
	"에릭 신 씨라고요?": "Eric Shin, I hear?", "LA에서 오셨다고요?": "From LA, I hear?", "투자자시라고요?": "An investor, I hear?", "일주일 계신다고요?": "Here a week, I hear?",
	"김 대표님이 초대하셨다고요?": "CEO Kim invited you, I hear?", "부모님이 부산 분이시라고요?": "Your parents are from Busan, I hear?",
	"한국어 잘 못하신다고요?": "Your Korean's not good, I hear?", "두 번 오셨다고요?": "You've been twice, I hear?",
	"김지현입니다. 오늘 파티 주최자예요.": "I'm Kim Ji-hyun. I'm hosting tonight.", "회사 대표입니다.": "I run a company.", "서울에서 태어났어요.": "I was born in Seoul.", "제가 대표예요. 하하.": "I'm the CEO. Ha ha.",
	"최입니다.": "Choi.", "사업합니다.": "I'm in business.", "그건 왜요?": "Why do you ask?", "김 대표님하고는 오래 알았어요.": "I've known CEO Kim a long time.",
	"윤서연입니다. 최 사장님 비서예요.": "I'm Yoon Seo-yeon. President Choi's assistant.", "최 사장님 비서입니다.": "I'm President Choi's assistant.", "부산에서 왔어요.": "I'm from Busan.", "사장님 덕분에 알게 됐어요.": "I know her through my boss.",
	"이민지입니다.": "I'm Lee Min-ji.", "의사예요.": "I'm a doctor.", "대구에서 왔어요.": "I'm from Daegu.", "대학교 친구예요.": "We're friends from university.",
	"박준호입니다.": "I'm Park Jun-ho.", "변호사예요.": "I'm a lawyer.", "서울 사람이에요.": "I'm from Seoul.", "같이 일했어요.": "We worked together.",
	"정우진입니다.": "I'm Jung Woo-jin.", "IT 회사 다녀요.": "I work at an IT company.", "인천에서 왔어요.": "I'm from Incheon.", "골프 친구예요.": "Golf buddies.",
	"한소희입니다.": "I'm Han So-hee.", "디자이너예요.": "I'm a designer.", "제주도에서 왔어요.": "I'm from Jeju.", "언니 친구예요.": "She's my sister's friend.",
	"강태호입니다.": "I'm Kang Tae-ho.", "은행에서 일해요.": "I work at a bank.", "대전에서 왔어요.": "I'm from Daejeon.", "사업 파트너예요.": "Business partners.",
	"오수진입니다.": "I'm Oh Su-jin.", "기자예요.": "I'm a journalist.", "광주에서 왔어요.": "I'm from Gwangju.", "옛날 이웃이에요.": "We used to be neighbours.",
	"성함이": "your name", "어떻게 되세요?": "is...?", "무슨 일": "what work", "하세요?": "do you do?", "어디에서": "where", "오셨어요?": "are you from?",
	"대표님하고": "the CEO,", "어떻게 아세요?": "how do you know her?", "최 사장님하고": "with President Choi", "약속 있어요": "I have an appointment",
	"같이": "together", "가요": "let's go", "와인 한 잔": "a glass of wine", "주세요": "please", "감사합니다": "thank you", "네": "yes", "아니요": "no",
}
var english := false              # text in English (the voices stay Korean): for testing what things do
var en_btn: Button
var EN := {}
const CHECK := {   # "I heard you're…?": they check what someone told them
	"name": "에릭 신 씨라고요?", "from": "LA에서 오셨다고요?", "job": "투자자시라고요?", "stay": "일주일 계신다고요?",
	"invited": "김 대표님이 초대하셨다고요?", "parents": "부모님이 부산 분이시라고요?", "korean": "한국어 잘 못하신다고요?", "twice": "두 번 오셨다고요?"}
const SMALL := ["cold", "food", "view", "busy", "wine", "know"]
const HANDLER := {"h_in": "You're in. Choi has the drive. Get to him through his assistant, or the host. Then get out.",
	"h_got": "That's the drive. Now get out of there.",
	"h_real1": "Bad news. The real Eric Shin just pulled up downstairs. You've got about a minute.",
	"h_real2": "He's in the room. Finish it and get out.", "h_blown": "He's talking to them. You're blown. Go, now!",
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
const BR := Vector3(-50.0, 0, 0)          # the back room: far off, so from the party you can't see in (nor the party from in there)
const DOOR_IN := Vector3(-9.3, 0, 2.5)    # in front of the brown door
const BR_ENTRY := Vector3(-46.6, 0, 0)    # just inside the back room's door
const BR_SEAT := Vector3(-51.5, 0, -1.5)  # where the broker waits for you
const REAL_WARN := 150.0           # the handler hears the real Eric Shin is downstairs
const REAL_AT := 210.0             # and he steps out of the lift
var real := {}                     # the real buyer
var real_stage := 0                # 0 not yet · 1 warned · 2 in the room · 3 he's told them
var no_real := false
var no_ask := false                # (tester) nobody walks up and asks you anything               # (tester) he doesn't come unless a test sends him
var blown := false
var blow_t := 0.0                  # word reaches the broker in the back room
var right_btn: Button
const SIPS := 10
var inv: Array = ["gun"]           # what you carry (the gun starts in the bag)
var hand := ""                     # what's in your hand: "" · drink · gun · drive
var sips := 0
var hand_btn: Button               # tap: the obvious thing · hold: a ring of options
var bag_btn: Button
var bag_box: HBoxContainer         # the bag open: your items, and Back
var bag_open := false
var ring_box: Control
var ring_open := false
var holding := false
var hold_t := 0.0
var placed: Array = []             # glasses you put down: {node, sips}
var offer_mode := false
var offer_rings: Array = []        # [person, ring]
var tap_at := Vector2.ZERO
var tap_t := 0.0
var touch_pos := Vector2.ZERO      # where your finger is (or last was)
var gate := ""                    # who's taking you to the broker: "assistant" or "host"
var gate_by := {}
var gate_check := false           # the assistant is checking who you are
var door_open := false
var in_back := false
var deal_step := -1               # the broker's check: -1 not yet, then each question in turn
var deal_ask := false
var has_drive := false
var killed := false
var drive_prop: MeshInstance3D
var back_door: Node3D
var waiter: Node3D
var waiter_t := 0.0
var fade: ColorRect
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
const PALETTE := [[Color(0.85, 0.85, 0.82), "pale grey"], [Color(0.12, 0.12, 0.14), "black"], [Color(0.2, 0.25, 0.4), "navy"],
	[Color(0.14, 0.15, 0.16), "charcoal"], [Color(0.95, 0.95, 0.95), "white"], [Color(0.7, 0.2, 0.3), "red"], [Color(0.3, 0.3, 0.5), "slate blue"],
	[Color(0.5, 0.4, 0.25), "brown"], [Color(0.6, 0.5, 0.7), "lavender"], [Color(0.25, 0.45, 0.4), "teal"], [Color(0.8, 0.6, 0.3), "amber"]]
var look_names := {}
const SURFACES := [   # where a glass can be put down: [centre, half size (x, z), top]
	[Vector3(8.2, 0, -1.0), Vector2(0.4, 2.1), 1.1], [Vector3(-4.0, 0, -1.6), Vector2(1.5, 0.5), 0.9], [Vector3(3.6, 0, 3.6), Vector2(0.5, 0.5), 0.4],
	[BR + Vector3(-1.5, 0, 0), Vector2(0.9, 0.5), 0.42], [BR + Vector3(3.2, 0, 0), Vector2(0.4, 1.0), 1.0]]
var _fails := 0
