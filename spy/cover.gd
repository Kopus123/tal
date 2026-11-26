extends Node3D
## Feature 1: the cover card. In the car on the way to the gala, your handler briefs you out loud on who you are
## tonight (Daniel Park) while the facts appear. Then a rehearsal: three questions in Korean, answered with word
## pieces. Everything stays on your phone, but checking it costs: once there are people, someone waiting notices.

const FACTS := [   # pieces of who you are, not answers to set questions ("~" = joins onto the word before it)
	# qs: the different ways someone might ask. "yn": a yes/no question, so 아니요 in front fits
	{"k": "name", "group": "core", "ko": "다니엘 박입니다.", "en": "I'm Daniel Park.",
		"qs": [["성함이 어떻게 되세요?", "May I ask your name?"], ["처음 뵙겠습니다. 누구세요?", "We haven't met. Who are you?"]],
		"chunks": [["다니엘 박", "Daniel Park"], ["~입니다", "I am"]]},
	{"k": "from", "group": "core", "ko": "LA에서 왔습니다.", "en": "I'm from LA.",
		"qs": [["어디에서 오셨어요?", "Where are you from?"], ["어디 사세요?", "Where do you live?"]],
		"chunks": [["LA에서", "from LA"], ["왔습니다", "came"]]},
	{"k": "job", "group": "core", "ko": "투자자입니다.", "en": "I'm an investor.",
		"qs": [["무슨 일 하세요?", "What do you do?"], ["어떤 일을 하세요?", "What line of work are you in?"]],
		"chunks": [["투자자", "investor"], ["~입니다", "I am"]]},
	{"k": "stay", "group": "core", "ko": "일주일 있습니다.", "en": "I'm here for a week.",
		"qs": [["한국에 얼마나 계세요?", "How long are you in Korea?"], ["언제까지 계세요?", "Until when are you here?"]],
		"chunks": [["일주일", "a week"], ["있습니다", "am here"]]},
	{"k": "invited", "group": "core", "ko": "김 대표님이 초대하셨습니다.", "en": "CEO Kim invited me.",
		"qs": [["누가 초대했어요?", "Who invited you?"], ["대표님하고 어떻게 아세요?", "How do you know the CEO?"]],
		"chunks": [["김 대표님이", "CEO Kim"], ["초대하셨습니다", "invited (me)"]]},
	{"k": "parents", "group": "background", "ko": "부모님은 부산 분이십니다.", "en": "My parents are from Busan.",
		"qs": [["부모님은 어디 분이세요?", "Where are your parents from?"], ["한국 분이세요?", "Are you Korean?"]],
		"chunks": [["부모님은", "my parents"], ["부산 분", "Busan people"], ["~이십니다", "are"]]},
	{"k": "korean", "group": "background", "yn": true, "ko": "한국어 잘 못합니다.", "en": "My Korean isn't good.",
		"qs": [["한국어 잘하세요?", "Is your Korean good?"], ["한국말 편하세요?", "Are you comfortable in Korean?"]],
		"chunks": [["한국어", "Korean"], ["잘 못합니다", "not good at"]]},
	{"k": "twice", "group": "background", "yn": true, "ko": "두 번 왔습니다.", "en": "I've been twice.",
		"qs": [["한국에 처음 오셨어요?", "Is this your first time in Korea?"], ["한국 자주 오세요?", "Do you come to Korea often?"]],
		"chunks": [["두 번", "twice"], ["왔습니다", "came"]]},
]
const YN := {"k": "yn", "chunks": [["네", "yes"], ["아니요", "no"]]}   # always yours to add in front, or not
const TITLES := [   # who you're there for, and what people call them: the words to listen for at the party
	["host", "김 대표님", "CEO Kim, the host"], ["broker", "사장님", "boss: the broker"],
	["assistant", "윤 비서", "Secretary Yoon, his assistant"], ["security", "팀장님", "team leader: head of security"],
]
const DODGES := [["d_work", "일 얘기는 나중에 하시죠.", "Let's talk work later."], ["d_secret", "비밀입니다.", "That's a secret."], ["d_well", "글쎄요...", "Well..."]]
const SUBS := {   # what the handler says, as quiet subtitles
	"h_intro": "Tonight you're Daniel Park. Learn him on the way.", "h_name": "Your name. These are pieces, not a script.", "h_from": "You're from L.A.",
	"h_job": "You're an investor. You run money for a fund.", "h_stay": "You're in Seoul for a week.",
	"h_invited": "Kim, the host, invited you. Call him 김 대표님.", "h_parents": "You grew up in Koreatown. Your parents are from Busan.",
	"h_korean": "That's why your Korean is rough. Own it.", "h_twice": "And you've been to Seoul twice before.",
	"h_style": "Daniel is confident. Short answers. Steer back to business.", "h_dodge": "If they ask something you don't know, dodge it.",
	"h_phone": "It's all on your phone. But checking it while someone waits for an answer looks bad.",
	"h_practice": "Let's practice. Nobody asks the same way twice. Use the pieces. Yes or no is up to you.", "h_good": "Good.", "h_good2": "That's it.", "h_close": "Close. Listen.",
	"h_listen": "Now the people you're here for. Listen for what they're called.", "h_t_host": "The host is Kim. People call him...",
	"h_t_broker": "The broker is Choi. His people call him...", "h_t_assistant": "His assistant is Yoon. He calls her...",
	"h_t_security": "The head of security gets called...", "h_t_bartender": "And the bartender is the one behind the bar.",
	"h_no": "No. It's this.", "h_noticed": "Fine in here. At the party, someone waiting would notice that.", "h_done": "We're here. Be Daniel.",
}
const STYLE := "Confident. Short answers. Steer back to business."
const SEEN_FILE := "user://cover_seen"

var test := false
var clips := {}
var voice: AudioStreamPlayer
var side: AudioStreamPlayer      # lines you play yourself (phone, pieces): the handler waits for them
var state := "brief"            # brief, rehearse, done
var run_n := 0                  # bumps on every restart, so a briefing still playing knows to stop
var shown := 0                  # facts shown on the cards so far
var titles_shown := 0
var questions: Array = []       # the rehearsal: three facts
var q_i := 0
var q_n := 0                    # which way the question is asked this time
var most_cards := 0             # the most lines on screen at once in the briefing (tester)
var picked: Array = []          # [fact key, chunk index]
var busy := false
var clean := 0
var phone_open := false
var phone_checks := 0           # checking the phone while a question waits for you
var noticed_said := false
var last_result := ""
var road: Array = []
var you: Node3D
var phone_prop: MeshInstance3D
# screen
var cards: VBoxContainer
var sub: Label
var skip_btn: Button
var phone_btn: Button
var phone_ui: PanelContainer
var talk_ui: PanelContainer
var q_label: Label
var gloss: Label
var gloss_t := 0.0
var ans_label: Label
var said_label: Label
var tile_box: HBoxContainer
var say_btn: Button
var end_ui: PanelContainer
var end_text: Label


func _ready() -> void:
	test = "--test" in OS.get_cmdline_user_args()
	randomize()
	voice = AudioStreamPlayer.new(); add_child(voice)
	side = AudioStreamPlayer.new(); add_child(side)
	side.finished.connect(func(): voice.stream_paused = false)
	var ids := ["h_intro", "h_name", "h_from", "h_job", "h_stay", "h_invited", "h_parents", "h_korean", "h_twice", "h_style", "h_dodge",
		"h_phone", "h_practice", "h_good", "h_good2", "h_close", "h_no", "h_noticed", "h_done", "d_work", "d_secret", "d_well", "h_listen", "h_t_bartender"]
	for t in TITLES: ids += ["h_t_" + t[0], "k_t_" + t[0]]
	for f in FACTS:
		ids.append("a_" + f.k)
		for i in f.qs.size(): ids.append("q_%s_%d" % [f.k, i])
		for i in f.chunks.size(): ids.append("t_%s_%d" % [f.k, i])
	ids += ["t_yn_0", "t_yn_1"]
	for id in ids: clips[id] = load("res://voice/cover/%s.mp3" % id)
	_car()
	_screen()
	if test: _run_test()
	else: _start()


# ---------------------------------------------------------------- the car, at night

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; return m


func _box(pos: Vector3, size: Vector3, c: Color, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	mi.position = pos + Vector3(0, size.y / 2, 0); mi.material_override = _mat(c); parent.add_child(mi); return mi


func _person(pos: Vector3, c: Color) -> Node3D:
	var n := Node3D.new(); n.position = pos; add_child(n)
	var mi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.28; cm.height = 1.1
	mi.mesh = cm; mi.position.y = 0.75; mi.material_override = _mat(c); n.add_child(mi)
	var nose := MeshInstance3D.new(); var nb := BoxMesh.new(); nb.size = Vector3(0.16, 0.12, 0.22)
	nose.mesh = nb; nose.position = Vector3(0, 1.1, -0.28); nose.material_override = _mat(c.darkened(0.55)); n.add_child(nose)
	return n


func _car() -> void:
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.04, 0.05, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.55, 0.6, 0.8); e.ambient_light_energy = 0.6
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-60), deg_to_rad(30), 0); sun.light_energy = 0.7; add_child(sun)
	_box(Vector3(0, -0.05, 0), Vector3(9, 0.05, 60), Color(0.13, 0.13, 0.15))                         # the road
	for i in 12:   # lane marks and city blocks sliding past
		road.append(_box(Vector3(-1.6, 0, -30 + i * 5), Vector3(0.12, 0.02, 2.0), Color(0.85, 0.8, 0.5)))
	for i in 10:
		for side in [-1, 1]:
			var h := randf_range(2.0, 6.0)
			var b := _box(Vector3(side * randf_range(6.5, 8.0), 0, -30 + i * 6.5), Vector3(2.4, h, 4.5), Color(0.18, 0.2, 0.28).lightened(randf() * 0.15))
			road.append(b)
			var win := _box(Vector3(0, h / 2 - 0.2, 0), Vector3(2.45, 0.25, 3.0), Color(1.0, 0.85, 0.45), b); win.position.y = h / 2 - 0.4
	# the car, roof off so you can see in
	var cc := Color(0.15, 0.16, 0.2)
	_box(Vector3(0, 0, 0), Vector3(2.0, 0.25, 4.4), cc)
	_box(Vector3(-1.0, 0, 0), Vector3(0.12, 0.9, 4.4), cc); _box(Vector3(1.0, 0, 0), Vector3(0.12, 0.9, 4.4), cc)
	_box(Vector3(0, 0, -2.2), Vector3(2.0, 0.9, 0.12), cc); _box(Vector3(0, 0, 2.2), Vector3(2.0, 0.9, 0.12), cc)
	_box(Vector3(0, 0.25, -1.55), Vector3(1.8, 0.5, 0.7), Color(0.1, 0.1, 0.12))                       # dashboard
	for x in [-0.48, 0.48]: _box(Vector3(x, 0.25, 0.25), Vector3(0.7, 0.35, 0.7), Color(0.3, 0.22, 0.18))   # seats
	var handler := _person(Vector3(-0.48, 0.25, 0.1), Color(0.35, 0.35, 0.4))
	_box(Vector3(-0.48, 0.55, -0.9), Vector3(0.45, 0.06, 0.06), Color(0.05, 0.05, 0.05))             # the wheel
	handler.rotation.y = 0.0
	you = _person(Vector3(0.48, 0.25, 0.1), Color(0.25, 0.5, 0.95))
	phone_prop = MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(0.14, 0.03, 0.24); phone_prop.mesh = pb
	var pm := _mat(Color(0.4, 0.8, 1.0)); pm.emission_enabled = true; pm.emission = Color(0.3, 0.6, 0.9); phone_prop.material_override = pm
	phone_prop.position = Vector3(0, 0.85, -0.35); phone_prop.visible = false; you.add_child(phone_prop)
	var cam := Camera3D.new(); cam.fov = 34; add_child(cam)
	cam.position = Vector3(2.2, 9.0, 6.5); cam.look_at(Vector3(0.6, 0.3, 0.0), Vector3.UP)


func _process(dt: float) -> void:
	for b in road:   # the city goes by
		b.position.z += dt * 9.0
		if b.position.z > 30.0: b.position.z -= 60.0
	if state == "rehearse" and gloss_t > 0.0:
		gloss_t -= dt
		if gloss_t <= 0.0: gloss.visible = true   # the English comes later: try to catch it by ear first


# ---------------------------------------------------------------- the screen

func _label(size: int) -> Label:
	var l := Label.new(); l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 8); l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8)); return l


func _btn(text: String, size: int, min: Vector2) -> Button:
	var b := Button.new(); b.text = text; b.add_theme_font_size_override("font_size", size); b.custom_minimum_size = min; return b


func _panel_style(a := 0.92) -> StyleBoxFlat:
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.06, 0.07, 0.1, a); st.set_corner_radius_all(14); st.set_content_margin_all(16); return st


func _screen() -> void:
	var ui := CanvasLayer.new(); add_child(ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	cards = VBoxContainer.new(); cards.position = Vector2(24, 22); cards.add_theme_constant_override("separation", 2); root.add_child(cards)
	sub = _label(26); sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); sub.position = Vector2(-460, -70)
	sub.custom_minimum_size = Vector2(920, 0); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sub.modulate = Color(1, 1, 1, 0.85)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(sub)
	skip_btn = _btn("Skip briefing", 22, Vector2(190, 60)); skip_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_btn.position = Vector2(-214, -84); root.add_child(skip_btn); skip_btn.pressed.connect(_skip)
	phone_btn = _btn("Phone", 26, Vector2(150, 70)); phone_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	phone_btn.position = Vector2(-174, 20); root.add_child(phone_btn); phone_btn.pressed.connect(_toggle_phone)
	_talk_screen(root)
	_phone_screen(root)   # on top: to answer, you put it away
	end_ui = PanelContainer.new(); end_ui.add_theme_stylebox_override("panel", _panel_style()); end_ui.set_anchors_preset(Control.PRESET_CENTER)
	end_ui.custom_minimum_size = Vector2(620, 0); end_ui.position = Vector2(-310, -150); root.add_child(end_ui)
	var eb := VBoxContainer.new(); eb.add_theme_constant_override("separation", 22); end_ui.add_child(eb)
	end_text = _label(30); end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; eb.add_child(end_text)
	var go := _btn("Go in", 34, Vector2(0, 100)); eb.add_child(go); go.pressed.connect(_go_in)
	var again := _btn("Again", 24, Vector2(0, 64)); eb.add_child(again); again.pressed.connect(_start)
	end_ui.visible = false


func _phone_screen(root: Control) -> void:   # your cover, all of it, with a Hear button on every line
	phone_ui = PanelContainer.new(); phone_ui.add_theme_stylebox_override("panel", _panel_style(0.97)); root.add_child(phone_ui)
	phone_ui.anchor_left = 1; phone_ui.anchor_right = 1; phone_ui.anchor_top = 0; phone_ui.anchor_bottom = 1
	phone_ui.offset_left = -560; phone_ui.offset_right = -16; phone_ui.offset_top = 100; phone_ui.offset_bottom = -16
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; phone_ui.add_child(sc)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 6); sc.add_child(box)
	var t := _label(30); t.text = "Daniel Park (다니엘 박)"; box.add_child(t)
	var s := _label(20); s.text = STYLE; s.modulate = Color(0.8, 0.8, 0.8); box.add_child(s)
	for group in ["core", "background"]:
		var h := _label(22); h.text = "What anyone might ask" if group == "core" else "If it gets personal"; h.modulate = Color(1, 0.8, 0.4); box.add_child(h)
		for f in FACTS:
			if f.group == group: box.add_child(_phone_line("a_" + f.k, f.ko, f.en))
	var hd := _label(22); hd.text = "When you don't know: dodge"; hd.modulate = Color(1, 0.8, 0.4); box.add_child(hd)
	for d in DODGES: box.add_child(_phone_line(d[0], d[1], d[2]))
	var ht := _label(22); ht.text = "Who to listen for"; ht.modulate = Color(1, 0.8, 0.4); box.add_child(ht)
	for tt in TITLES: box.add_child(_phone_line("k_t_" + tt[0], tt[1], tt[2]))
	phone_ui.visible = false


func _phone_line(clip: String, ko: String, en: String) -> HBoxContainer:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
	var hear := _btn("Hear", 18, Vector2(70, 44)); hear.pressed.connect(_aside.bind(clip)); row.add_child(hear)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 0); row.add_child(col)
	var k := _label(24); k.text = ko; col.add_child(k)
	var e := _label(17); e.text = en; e.modulate = Color(0.75, 0.75, 0.75); col.add_child(e)
	return row


func _talk_screen(root: Control) -> void:   # the rehearsal panel
	talk_ui = PanelContainer.new(); talk_ui.add_theme_stylebox_override("panel", _panel_style()); root.add_child(talk_ui)
	talk_ui.anchor_left = 0; talk_ui.anchor_right = 1; talk_ui.anchor_top = 1; talk_ui.anchor_bottom = 1
	talk_ui.offset_left = 16; talk_ui.offset_right = -16; talk_ui.offset_top = -330; talk_ui.offset_bottom = -10
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); talk_ui.add_child(row)
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.add_theme_constant_override("separation", 8); row.add_child(left)
	var qrow := HBoxContainer.new(); qrow.add_theme_constant_override("separation", 14); left.add_child(qrow)
	q_label = _label(40); q_label.modulate = Color(0.75, 0.85, 1.0); qrow.add_child(q_label)
	var hear := _btn("Hear", 22, Vector2(90, 54)); qrow.add_child(hear); hear.pressed.connect(_hear_q)
	gloss = _label(22); gloss.modulate = Color(0.75, 0.75, 0.75); left.add_child(gloss)
	var arow := HBoxContainer.new(); arow.add_theme_constant_override("separation", 14); left.add_child(arow)
	ans_label = _label(38); ans_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; arow.add_child(ans_label)
	var clr := _btn("Clear", 22, Vector2(100, 54)); arow.add_child(clr); clr.pressed.connect(_clear_pick)
	said_label = _label(22); said_label.modulate = Color(1, 0.9, 0.5); left.add_child(said_label)
	tile_box = HBoxContainer.new(); tile_box.add_theme_constant_override("separation", 8); left.add_child(tile_box)
	say_btn = _btn("Say it", 36, Vector2(190, 130)); say_btn.size_flags_vertical = Control.SIZE_SHRINK_END; row.add_child(say_btn); say_btn.pressed.connect(_say_it)
	var gs := StyleBoxFlat.new(); gs.bg_color = Color(0.2, 0.55, 0.3); gs.set_corner_radius_all(10); say_btn.add_theme_stylebox_override("normal", gs)
	talk_ui.visible = false


# ---------------------------------------------------------------- voices

func _play(id: String) -> void:
	voice.stream = clips[id]; voice.play()
	if SUBS.has(id): sub.text = SUBS[id]


func _aside(id: String) -> void:   # you play a line: the handler pauses mid-sentence and picks up after
	if voice.playing: voice.stream_paused = true
	side.stream = clips[id]; side.play()


func _done() -> void:
	await get_tree().process_frame
	while voice.playing or voice.stream_paused or side.playing: await get_tree().process_frame


func _speak(id: String, n: int) -> bool:   # say a line and wait; false if the run moved on meanwhile
	if n != run_n: return false
	while side.playing: await get_tree().process_frame   # let your own line finish first
	if n != run_n: return false
	_play(id); await _done()
	return n == run_n


func _seen() -> bool:
	return FileAccess.file_exists(SEEN_FILE)


# ---------------------------------------------------------------- 1. the briefing, read to you

func _sub_at(top: bool) -> void:   # subtitles sit low, or above the answer panel while you rehearse
	var vs := get_viewport().get_visible_rect().size
	sub.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sub.custom_minimum_size = Vector2(660 if top else 920, 0); sub.size = sub.custom_minimum_size
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if top else HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(24, 24) if top else Vector2(vs.x / 2 - 460, vs.y - 70)


func _start() -> void:
	_sub_at(false)
	run_n += 1; state = "brief"; shown = 0; titles_shown = 0; clean = 0; phone_checks = 0; noticed_said = false; busy = false
	for c in cards.get_children(): c.queue_free()
	end_ui.visible = false; talk_ui.visible = false; sub.text = ""; voice.stop()
	_set_phone(false)
	skip_btn.visible = _seen() or test
	_brief(run_n)


func _card(ko: String, en: String) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
	var k := _label(28); k.text = ko; row.add_child(k)
	var e := _label(19); e.text = en; e.modulate = Color(0.78, 0.78, 0.78); e.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(e)
	cards.add_child(row); most_cards = maxi(most_cards, cards.get_child_count())
	row.modulate.a = 0.0; create_tween().tween_property(row, "modulate:a", 1.0, 0.35)


func _heading(t: String) -> void:   # a new section: the last one leaves the screen (it's on your phone)
	for c in cards.get_children(): cards.remove_child(c); c.queue_free()
	var h := _label(20); h.text = t; h.modulate = Color(1, 0.8, 0.4); cards.add_child(h)


func _brief(n: int) -> void:
	if not await _speak("h_intro", n): return
	_heading("Daniel Park: " + STYLE)
	for f in FACTS:   # the handler says it in English, then you hear it the way you'll say it, and it goes on the card
		if f.k == "parents": _heading("If it gets personal")
		if not await _speak("h_" + f.k, n): return
		_card(f.ko, f.en); shown += 1
		if not await _speak("a_" + f.k, n): return
		await get_tree().create_timer(0.35).timeout
	if not await _speak("h_style", n): return
	if not await _speak("h_dodge", n): return
	_heading("When you don't know: dodge")
	for d in DODGES:
		_card(d[1], d[2])
		if not await _speak(d[0], n): return
	# who you're there for: the titles to listen for (said in English, then in Korean)
	if not await _speak("h_listen", n): return
	_heading("Who to listen for")
	for t in TITLES:
		if not await _speak("h_t_" + t[0], n): return
		_card(t[1], t[2]); titles_shown += 1
		if not await _speak("k_t_" + t[0], n): return
		await get_tree().create_timer(0.3).timeout
	if not await _speak("h_t_bartender", n): return
	if not await _speak("h_phone", n): return
	_mark_seen()
	_rehearse(n)


func _mark_seen() -> void:
	var f := FileAccess.open(SEEN_FILE, FileAccess.WRITE)
	if f: f.store_string("1")


func _skip() -> void:
	if state != "brief": return
	run_n += 1; voice.stop(); _mark_seen()
	for c in cards.get_children(): c.queue_free()
	shown = FACTS.size()
	_rehearse(run_n)


# ---------------------------------------------------------------- 2. the rehearsal: answer from memory

func _rehearse(n: int) -> void:
	state = "rehearse"; skip_btn.visible = false; _sub_at(true)
	for c in cards.get_children(): c.queue_free()   # off the screen now: it's in your head, or on your phone
	var pool := FACTS.duplicate(); pool.shuffle()
	questions = pool.slice(0, 3); q_i = 0
	if not await _speak("h_practice", n): return
	_ask(n)


func _ask(n: int) -> void:
	if n != run_n: return
	var f: Dictionary = questions[q_i]
	talk_ui.visible = true; said_label.text = ""; picked.clear()
	q_n = randi() % f.qs.size()
	q_label.text = f.qs[q_n][0]; gloss.text = f.qs[q_n][1]; gloss.visible = false; gloss_t = 3.0
	# the pieces: this answer's, mixed with pieces of two others
	var tiles := []
	for i in f.chunks.size(): tiles.append([f.k, i])
	tiles += [["yn", 0], ["yn", 1]]   # yes and no: yours to put in front, or not
	var others := FACTS.filter(func(o): return o.k != f.k); others.shuffle()
	for o in others.slice(0, 1):   # one other answer's pieces: with yes and no, at most 8 tiles, one row
		for i in o.chunks.size(): tiles.append([o.k, i])
	var seen_text := {}; var deck := []
	for t in tiles:
		var tx: String = _chunk(t)[0]
		if not seen_text.has(tx): seen_text[tx] = 1; deck.append(t)
	deck.shuffle()
	for c in tile_box.get_children(): c.queue_free()
	for t in deck:
		var ch: Array = _chunk(t)
		var b := _btn("%s\n%s" % [ch[0], ch[1]], 24, Vector2(112, 96)); b.pressed.connect(_pick.bind(t)); tile_box.add_child(b)
	_show_pick()
	busy = true
	await _speak("q_%s_%d" % [f.k, q_n], n)
	if n == run_n: busy = false


func _fact(k: String) -> Dictionary:
	if k == "yn": return YN
	for f in FACTS:
		if f.k == k: return f
	return {}


func _chunk(t: Array) -> Array:
	return _fact(t[0]).chunks[t[1]]


func _hear_q() -> void:
	if state == "rehearse" and not busy: _play("q_%s_%d" % [questions[q_i].k, q_n])


func _pick(t: Array) -> void:
	if busy or picked.size() >= 4: return
	picked.append(t); _show_pick()
	_aside("t_%s_%d" % t)


func _clear_pick() -> void:
	if busy: return
	picked.clear(); _show_pick()


func _joined(ts: Array) -> String:   # "다니엘 박" + "~이에요" = "다니엘 박이에요"
	var s := ""
	for t in ts:
		var w: String = _chunk(t)[0]
		if w.begins_with("~"): s += w.substr(1)
		elif s == "": s = w
		else: s += " " + w
	return s


func _show_pick() -> void:
	ans_label.text = _joined(picked) if picked else "Tap the pieces to answer"
	ans_label.modulate = Color.WHITE if picked else Color(1, 1, 1, 0.45)
	say_btn.disabled = picked.is_empty()


## good: exactly right · order: the right pieces, wrong order · part: some of the right pieces, nothing else · wrong
func _judge(p: Array, f: Dictionary) -> String:
	var want := []
	for i in f.chunks.size(): want.append(_chunk([f.k, i])[0])
	var got := p.map(func(t): return _chunk(t)[0])
	if got.size() > 1 and (got[0] == "네" or (got[0] == "아니요" and f.get("yn", false))): got = got.slice(1)   # yes/no in front: your call
	if got == want: return "good"
	if got.size() == want.size() and got.all(func(w): return w in want) and want.all(func(w): return w in got): return "order"
	if got.all(func(w): return w in want): return "part"
	return "wrong"


func _say_it() -> void:
	if busy or picked.is_empty() or state != "rehearse": return
	var n := run_n; busy = true
	var f: Dictionary = questions[q_i]
	var r := _judge(picked, f); last_result = r
	if r == "good":
		var lead: String = p_lead(f) if picked[0][0] == "yn" else ""
		if lead != "" and not await _speak(lead, n): return
		if not await _speak("a_" + f.k, n): return
	else:
		for t in picked:
			if not await _speak("t_%s_%d" % t, n): return
	if r == "good":
		clean += 1
		if not await _speak(["h_good", "h_good2"].pick_random(), n): return
	else:   # no cost in here: the handler gives you the right line, and that's how you learn it
		if not await _speak("h_close" if r != "wrong" else "h_no", n): return
		said_label.text = "%s = %s" % [f.ko, f.en]
		if not await _speak("a_" + f.k, n): return
	await get_tree().create_timer(1.2).timeout
	if n != run_n: return
	busy = false; q_i += 1
	if q_i < questions.size(): _ask(n)
	else: _finish(n)


func p_lead(_f: Dictionary) -> String:   # 네 or 아니요 you put in front: say it too
	if picked.size() > 1 and picked[0][0] == "yn": return "t_yn_%d" % picked[0][1]
	return ""


func _finish(n: int) -> void:
	talk_ui.visible = false
	if not await _speak("h_done", n): return
	state = "done"; sub.text = ""
	var t := "You're Daniel Park.\nRehearsal: %d of 3 clean." % clean
	if phone_checks > 0: t += "\nYou checked your phone mid-answer %d time%s." % [phone_checks, "" if phone_checks == 1 else "s"]
	end_text.text = t
	end_ui.visible = true


func _go_in() -> void:   # out of the car and up to the party
	get_tree().change_scene_to_file("res://gala.tscn")


# ---------------------------------------------------------------- 3. the phone: always there, never free

func _toggle_phone() -> void:
	_set_phone(not phone_open)
	if phone_open and state == "rehearse" and talk_ui.visible:   # someone is waiting for your answer
		phone_checks += 1
		if not noticed_said and not busy:
			noticed_said = true; busy = true
			var n := run_n
			await _speak("h_noticed", n)
			if n == run_n: busy = false


func _set_phone(on: bool) -> void:
	phone_open = on; phone_ui.visible = on; phone_prop.visible = on
	phone_btn.text = "Put away" if on else "Phone"
	var body: Node3D = you.get_child(0)
	create_tween().tween_property(body, "rotation:x", -0.35 if on else 0.0, 0.25)   # head down, looking at it


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


func _idle() -> void:   # until nobody's talking and it's your turn
	for i in 200:
		await _secs(0.05)
		if not busy and not voice.playing: return


func _answer(keys: Array) -> void:
	picked = keys.duplicate(); _show_pick(); await _say_it()


func _run_test() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().position = Vector2i(-3000, 60)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEEN_FILE))
	_start()
	_check(not skip_btn.visible or test, "the first time there's no skipping (the tester can)")
	await _secs(0.3)
	_check(state == "brief" and sub.text.begins_with("Tonight") and voice.playing, "the handler starts the briefing out loud, with a subtitle")
	for i in 400:
		await _secs(0.05)
		if shown >= 2: break
	_check(shown >= 2 and cards.get_child_count() >= 3 and _seen() == false, "facts appear on the card as they're said")
	await _secs(1.0); await _shot("c1_briefing")
	# playing a line from the phone pauses the handler, and he picks up where he was
	var before_shown := shown
	_aside("a_name"); await _secs(0.1)
	_check(side.playing and (voice.stream_paused or not voice.playing), "playing a line yourself pauses the handler")
	while side.playing: await _secs(0.05)
	await _secs(0.1)
	_check(not voice.stream_paused and shown == before_shown, "he resumes the same line after (nothing skipped)")
	_check(TITLES.size() == 4 and TITLES.all(func(t): return clips.has("h_t_" + t[0]) and clips.has("k_t_" + t[0])), "the briefing has who to listen for: 4 titles, said in English then Korean")
	var phone_titles := 0
	for c in phone_ui.get_child(0).get_child(0).get_children():
		if c is HBoxContainer and c.get_child(1).get_child(0).text in ["김 대표님", "사장님", "윤 비서", "팀장님"]: phone_titles += 1
	_check(phone_titles == 4, "your phone lists the titles too, with Hear buttons")
	_skip(); await _secs(0.2)
	_check(state == "rehearse" and cards.get_child_count() == 0 and _seen(), "skip goes to the rehearsal, the card clears (memory or phone now)")
	await _idle()
	_check(talk_ui.visible and q_label.text == questions[0].qs[q_n][0] and clips.has("q_%s_%d" % [questions[0].k, q_n]), "the handler asks the first question in Korean")
	var n_tiles := tile_box.get_child_count()
	_check(n_tiles >= questions[0].chunks.size() + 2 and n_tiles <= 11, "the pieces mix this answer with others (%d)" % n_tiles)
	await _secs(3.0)
	_check(gloss.visible, "the English for the question comes after a moment")
	await _shot("c2_rehearsal")
	# phone mid-question: noticed (for free, in here)
	_toggle_phone(); await _secs(0.2)
	_check(phone_open and phone_ui.visible and phone_prop.visible and phone_checks == 1, "checking the phone mid-question shows it in your hand and counts")
	await _shot("c3_phone")
	await _idle()
	_check(sub.text.begins_with("Fine in here"), "the handler warns that at the party someone would notice")
	_toggle_phone()
	# a right answer
	var f0: Dictionary = questions[0]
	var right := []
	for i in f0.chunks.size(): right.append([f0.k, i])
	await _answer(right)
	_check(last_result == "good" and clean == 1 and q_i == 1, "the right pieces in order: clean (%s)" % _joined(right))
	await _idle()
	# the right pieces in the wrong order
	var f1: Dictionary = questions[1]
	var rev := []
	for i in f1.chunks.size(): rev.push_front([f1.k, i])
	await _answer(rev)
	_check(last_result == "order" and clean == 1, "right pieces, wrong order: close, and you hear the real line")
	await _idle()
	# half an answer, and a wrong one (judged directly)
	var f2: Dictionary = questions[2]
	_check(_judge([[f2.k, 0]], f2) == "part", "half the answer counts as close")
	var other: Dictionary = FACTS[0] if f2.k != FACTS[0].k else FACTS[1]
	_check(_judge([[other.k, 0]], f2) == "wrong", "another answer's piece is wrong")
	var kor: Dictionary = _fact("korean"); var tw: Dictionary = _fact("twice")
	var nm: Dictionary = _fact("name")
	_check(_judge([["yn", 1], ["korean", 0], ["korean", 1]], kor) == "good" and _judge([["korean", 0], ["korean", 1]], kor) == "good", "아니요, 한국어 잘 못합니다 counts, with or without 아니요")
	_check(_judge([["twice", 0], ["twice", 1]], tw) == "good" and _judge([["yn", 1], ["twice", 0], ["twice", 1]], tw) == "good", "두 번 왔습니다 counts, with or without 아니요")
	_check(_judge([["yn", 0], ["name", 0], ["name", 1]], nm) == "good" and _judge([["yn", 1], ["name", 0], ["name", 1]], nm) == "wrong", "네 fits in front of anything; 아니요 only answers a yes/no question")
	_check(FACTS.all(func(x): return x.qs.size() >= 2 and not x.ko.begins_with("아니요") and (x.ko.ends_with("니다.") or x.ko.ends_with("습니다."))), "every line is formal, has 2+ ways to be asked, and none starts with 아니요")
	_check(_judge([["korean", 1], ["korean", 0]], kor) == "order", "and the wrong order is still caught")
	_check(_joined([["name", 0], ["name", 1]]) == "다니엘 박입니다" and _joined([["parents", 0], ["parents", 1], ["parents", 2]]) == "부모님은 부산 분이십니다", "pieces join like real Korean (입니다 sticks to the word before)")
	await _answer([[other.k, 0]])
	_check(last_result == "wrong" and said_label.text.begins_with(f2.ko), "a wrong answer: the handler gives you the right line")
	for i in 200:
		await _secs(0.05)
		if state == "done": break
	_check(state == "done" and end_ui.visible and end_text.text.contains("1 of 3") and end_text.text.contains("phone"), "the end: how clean you were, and the phone checks")
	await _shot("c4_end")
	_start(); await _secs(0.2)
	_check(skip_btn.visible and state == "brief", "after the first time you can skip the briefing")
	var qs := {}
	for i in 8:
		_skip(); await _secs(0.05)
		qs[questions[0].k + questions[1].k + questions[2].k] = 1
		_start()
	_check(qs.size() >= 5, "the rehearsal questions change each run (%d different in 8)" % qs.size())
	# the whole briefing, start to end, once
	_start(); most_cards = 0
	var saw_titles := 0
	for i in 3000:
		await _secs(0.05)
		saw_titles = maxi(saw_titles, titles_shown)
		if state == "rehearse": break
	_check(state == "rehearse" and saw_titles == 4 and shown == FACTS.size(), "the full briefing plays through: %d facts, %d titles, then the rehearsal" % [shown, saw_titles])
	_check(most_cards <= 6, "the briefing never has more than 6 lines on screen (%d), so nothing runs off the bottom" % most_cards)
	print("DONE %d failed" % _fails)
	get_tree().quit(1 if _fails else 0)
