extends Control
## The screen: the picture on the left (room.gd), the paper on the right: what's happening, your choices, your pockets.
## Overlays: the combination lock, a word's picture, the menu, the Korean keyboard test.
##   godot --path . -- --shots OUT_DIR     plays the escape room and saves a screenshot of every step (tools/shot_tour.gd)

const BUILD := 5
const INK := Color("151a24")
const PAPER := Color("efe6cf")
const PAPER_INK := Color("2a231d")
const MUTE := Color("8a7d66")
const STORY := "shed.story"

var room: Control
var paper: PanelContainer
var title_ko: Label
var title_en: Label
var body: RichTextLabel
var acts: VBoxContainer
var pockets_box: HFlowContainer
var pocket_hint: Label
var toast_box: VBoxContainer
var card: Control
var players := []
var icons: Dictionary = {}
var sheet: Texture2D
var tour: RefCounted


func _ready() -> void:
	RenderingServer.set_default_clear_color(INK)
	var idx = JSON.parse_string(FileAccess.get_file_as_string("res://icons/index.json"))
	if idx: icons = idx
	sheet = load("res://icons/sheet.png")
	_build()
	Game.changed.connect(_refresh)
	Game.sound.connect(_play)
	Game.toast.connect(_toast)
	var args := OS.get_cmdline_user_args()
	Game.start(STORY)
	if "--shots" in args:
		var i := args.find("--shots")
		tour = load("res://scripts/tools/shot_tour.gd").new()   # kept here: a tour nobody holds on to is freed mid-way
		tour.run(self, args[i + 1] if i + 1 < args.size() else "user://shots")


## ---------- layout
func _build() -> void:
	var bg := ColorRect.new(); bg.color = INK; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var row := HBoxContainer.new(); row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); row.add_theme_constant_override("separation", 14)
	row.offset_left = 14; row.offset_top = 12; row.offset_right = -14; row.offset_bottom = -12
	add_child(row)
	var arc := AspectRatioContainer.new(); arc.ratio = 4.0 / 3.0; arc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; arc.size_flags_stretch_ratio = 2.2
	row.add_child(arc)
	room = load("res://scripts/ui/room.gd").new(); arc.add_child(room)
	card = _card(); room.add_child(card)

	paper = PanelContainer.new(); paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL; paper.custom_minimum_size.x = 380
	var ps := StyleBoxFlat.new(); ps.bg_color = PAPER; ps.set_corner_radius_all(18); ps.content_margin_left = 22; ps.content_margin_right = 22; ps.content_margin_top = 16; ps.content_margin_bottom = 16
	paper.add_theme_stylebox_override("panel", ps); row.add_child(paper)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 12); paper.add_child(col)

	var head := HBoxContainer.new(); col.add_child(head)
	var names := VBoxContainer.new(); names.size_flags_horizontal = Control.SIZE_EXPAND_FILL; names.add_theme_constant_override("separation", -4); head.add_child(names)
	title_ko = _label("", 30, PAPER_INK); names.add_child(title_ko)
	title_en = _label("", 15, MUTE); names.add_child(title_en)
	var menu := _button("☰", true); menu.custom_minimum_size = Vector2(56, 56); menu.pressed.connect(_menu); head.add_child(menu)

	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var inner := VBoxContainer.new(); inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL; inner.add_theme_constant_override("separation", 14); scroll.add_child(inner)
	body = RichTextLabel.new(); body.bbcode_enabled = true; body.fit_content = true; body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color", PAPER_INK); body.add_theme_font_size_override("normal_font_size", 24)
	body.add_theme_font_size_override("bold_font_size", 30); body.meta_underlined = false
	body.meta_clicked.connect(func(w): _word(str(w)))
	inner.add_child(body)
	acts = VBoxContainer.new(); acts.add_theme_constant_override("separation", 8); inner.add_child(acts)
	var pk := VBoxContainer.new(); pk.add_theme_constant_override("separation", 6); col.add_child(pk)
	pockets_box = HFlowContainer.new(); pockets_box.add_theme_constant_override("h_separation", 8); pk.add_child(pockets_box)
	pocket_hint = _label("", 16, MUTE); pocket_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pk.add_child(pocket_hint)
	var bl := _label("build %d" % BUILD, 12, Color(1, 1, 1, 0.25)); bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); bl.position = Vector2(18, -22); add_child(bl)
	bl.anchor_top = 1; bl.anchor_bottom = 1; bl.offset_top = -20; bl.offset_left = 18
	toast_box = VBoxContainer.new(); toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP); toast_box.position.y = 20; toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH; add_child(toast_box)


func _label(t: String, sz: int, c: Color) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", c)
	return l


func _button(t: String, dark := false) -> Button:
	var b := Button.new(); b.text = t; b.add_theme_font_size_override("font_size", 22)
	var n := StyleBoxFlat.new(); n.set_corner_radius_all(12); n.content_margin_left = 16; n.content_margin_right = 16; n.content_margin_top = 12; n.content_margin_bottom = 12
	n.bg_color = PAPER_INK if dark else Color("fbf6e9"); n.border_color = PAPER_INK; n.set_border_width_all(0 if dark else 2)
	var p := n.duplicate(); p.bg_color = n.bg_color.darkened(0.15)
	for st in ["normal", "hover", "focus"]: b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("pressed", p)
	var fc := PAPER if dark else PAPER_INK
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(st, fc)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if not dark else HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


## ---------- what's on the paper
func _refresh() -> void:
	var pl: Dictionary = Game.place()
	title_ko.text = pl.get("name", ""); title_en.text = pl.get("sub", "").to_upper()
	for c in acts.get_children(): c.queue_free()
	var b: Dictionary = Game.beat()
	card.visible = b.get("type", "") == "card"
	if b.is_empty():
		body.text = _esc(Game.desc())
	elif b.get("type", "") == "card":
		card.get_node("T").text = b.title; card.get_node("S").text = b.get("sub", "")
		body.text = "[color=#8a7d66]Sound on. Tap any underlined word to see its picture.[/color]"
		_cont("Begin")
	elif b.get("type", "") == "number":
		body.text = _esc(b.en)
		var lock = load("res://scripts/ui/lock.gd").new(); lock.setup(len(Game._digits(b.ans[0][0])) if not b.ans.is_empty() else 4)
		lock.tried.connect(func(v): Game.answer(v))
		room.add_child(lock)
	else:
		body.text = _beat_text(b)
		var shown := 0
		for o in b.get("ch", []):
			if not Game.cond(o.c): continue
			shown += 1
			var btn := _button(Game.plain(o.get("en", o.get("ko", ""))))
			btn.pressed.connect(Game.choose.bind(o)); acts.add_child(btn)
		if shown == 0: _cont("Continue")
	_pockets()


func _cont(t: String) -> void:
	var c := _button(t, true); c.pressed.connect(func(): Game.sound.emit("tap"); Game.next()); acts.add_child(c)


func _esc(s: String) -> String: return s.replace("[", "[lb]")


## Korean words become tappable (they open the word's picture)
func _ko(s: String) -> String:
	var re := RegEx.create_from_string("\\{([^}|]+)(?:\\|([^}]+))?\\}")
	var out := ""; var at := 0
	for m in re.search_all(s):
		out += _esc(s.substr(at, m.get_start() - at))
		var entry := m.get_string(2) if m.get_string(2) != "" else m.get_string(1)
		out += "[url=%s][color=#7a3b1e][u]%s[/u][/color][/url]" % [entry, _esc(m.get_string(1))]
		at = m.get_end()
	return out + _esc(s.substr(at))


func _beat_text(b: Dictionary) -> String:
	var who: String = b.get("who", "narr")
	if who == "narr": return _esc(b.get("en", ""))
	if who == "sign":
		return "[center][bgcolor=#e2d6b8][font_size=38] %s [/font_size][/bgcolor][/center]\n[color=#8a7d66][font_size=19]%s[/font_size][/color]" % [_ko(b.ko), _esc(b.get("en", ""))]
	var name: String = Game.world.cast.get(who, {}).get("n", who)
	return "[color=#8a7d66][font_size=18]%s[/font_size][/color]\n[font_size=32]%s[/font_size]\n[color=#8a7d66][font_size=19]%s[/font_size][/color]" % [_esc(name), _ko(b.ko), _esc(b.get("en", ""))]


## ---------- pockets
func _pockets() -> void:
	for c in pockets_box.get_children(): c.queue_free()
	var items: Array = Game.pockets()
	var free_to_look: bool = Game.node == "" and Game.place().get("mode", "") == "explore"
	pockets_box.get_parent().visible = free_to_look and not items.is_empty()
	for e in items:
		var on: bool = bool(Game.F.get("lit", 0)) if e.id == "flashlight" else Game.F.get("hold", "") == e.id
		# each thing shows its name underneath (in Korean for things labelled in Korean: 기름 on the oil can)
		var b := Button.new(); b.custom_minimum_size = Vector2(96, 112); b.icon = _icon("#" + e.icon); b.expand_icon = true
		b.text = Game.plain(e.label); b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP; b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 17); b.clip_text = true
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(c, PAPER_INK)
		var st := StyleBoxFlat.new(); st.set_corner_radius_all(12); st.bg_color = Color("efe3c4") if on else Color("fbf6e9")
		st.border_color = PAPER_INK if on else Color("cbbf9f"); st.set_border_width_all(4 if on else 2); st.set_content_margin_all(12)
		for s in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(s, st)
		b.pressed.connect(Game.pocket.bind(e.id)); pockets_box.add_child(b)
	var h: String = Game.F.get("hold", "")
	pocket_hint.text = ("Holding: %s. Tap where to use it." % Game.plain(Game.ch.evidence[h].label)) if h != "" and Game.ch.evidence.has(h) \
		else ("Flashlight on. Drag on the picture to point it." if Game.F.get("lit", 0) else "Tap something in your pockets to take it out.")


## a picture from the sheet: a word ("기름") or a picture by its own name ("#oil")
func _icon(key: String) -> Texture2D:
	var i = icons.get("words", {}).get(key)
	if i == null or sheet == null: return null
	var a := AtlasTexture.new(); a.atlas = sheet
	var sz := float(icons.size); a.region = Rect2((int(i) % int(icons.cols)) * sz, int(int(i) / int(icons.cols)) * sz, sz, sz)
	return a


## ---------- a word's page: its picture, and the meaning if you want to check
func _word(w: String) -> void:
	_play("tap"); Game.note("  opened word: " + w)
	var o := _overlay()
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 10); o.get_child(0).add_child(box)
	# only numbers get a picture here: nothing around you can tell you what 사 means. Every other word you work out
	# from what's around you (the things in your pockets have their Korean names on them), so no picture gives it away.
	var spec: String = Game.world.words.get(w, {}).get("p", "")
	if spec.begins_with("sino") or spec.begins_with("nat"):
		var pic := TextureRect.new(); pic.texture = _icon(w); pic.custom_minimum_size = Vector2(180, 180); pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; box.add_child(pic)
	var l := _label(w, 52, PAPER_INK); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(l)
	var ok := _button("Close", true); ok.pressed.connect(o.get_parent().queue_free); box.add_child(ok)


func _overlay() -> Control:
	var o := ColorRect.new(); o.color = Color(0, 0, 0, 0.55); o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(o)
	var c := CenterContainer.new(); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); o.add_child(c)
	var p := PanelContainer.new(); var st := StyleBoxFlat.new(); st.bg_color = PAPER; st.set_corner_radius_all(18); st.set_content_margin_all(26)
	p.add_theme_stylebox_override("panel", st); p.custom_minimum_size.x = 420; c.add_child(p)
	return c


## ---------- the menu: a nudge, start over, the keyboard test
func _menu() -> void:
	_play("tap")
	var o := _overlay()
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 10); o.get_child(0).add_child(box)
	var hint := _label("", 20, PAPER_INK); hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.custom_minimum_size.x = 380
	var b1 := _button("💡  Think (a nudge)"); b1.pressed.connect(func(): hint.text = Game.hint(); Game.note("  HINT: " + hint.text)); box.add_child(b1); box.add_child(hint)
	var b2 := _button("⌨  Korean keyboard test"); b2.pressed.connect(func(): o.get_parent().queue_free(); _keyboard()); box.add_child(b2)
	var b3 := _button("↺  Start the shed over"); b3.pressed.connect(func(): Game.note("  started over")); b3.pressed.connect(func(): o.get_parent().queue_free(); room._art_key = ""; Game.start(STORY)); box.add_child(b3)
	var b4 := _button("Close", true); b4.pressed.connect(func(): o.get_parent().queue_free()); box.add_child(b4)


func _keyboard() -> void:
	var k = load("res://scripts/ui/keyboard_test.gd").new(); k.main = self; add_child(k)


## ---------- the title card ("@card 시험 | 창고")
func _card() -> Control:
	var c := ColorRect.new(); c.color = Color(0, 0, 0, 0.82); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); c.visible = false; c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _label("", 84, PAPER); t.name = "T"; c.add_child(t)
	var s := _label("", 30, Color(PAPER, 0.7)); s.name = "S"; c.add_child(s)
	for l in [t, s]:
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.offset_top = -40; t.offset_bottom = -40; s.offset_top = 60; s.offset_bottom = 60
	return c


## ---------- sound and little messages
func _play(n: String) -> void:
	var stream := load("res://sfx/%s.wav" % n) as AudioStream
	if stream == null: return
	var p := AudioStreamPlayer.new(); p.stream = stream; add_child(p); p.play(); p.finished.connect(p.queue_free)
	if n == "slam": room.shake()


func _toast(t: String) -> void:
	var p := PanelContainer.new(); var st := StyleBoxFlat.new(); st.bg_color = Color(0.08, 0.09, 0.12, 0.92); st.set_corner_radius_all(14); st.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", st); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(Game.plain(t), 20, PAPER); p.add_child(l); toast_box.add_child(p)
	var tw := create_tween(); tw.tween_interval(2.6); tw.tween_property(p, "modulate:a", 0.0, 0.4); tw.tween_callback(p.queue_free)
