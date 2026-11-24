extends ColorRect
## Test: typing Korean on the game's own keyboard (the standard 두벌식 layout), so Android's keyboard is never involved.
## Shows a word's picture; you type the word. Letters join into blocks as you go (scripts/core/hangul.gd).

const ROWS := [["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅛ", "ㅕ", "ㅑ", "ㅐ", "ㅔ"], ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"], ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"]]
const SHIFTED := {"ㅂ": "ㅃ", "ㅈ": "ㅉ", "ㄷ": "ㄸ", "ㄱ": "ㄲ", "ㅅ": "ㅆ", "ㅐ": "ㅒ", "ㅔ": "ㅖ"}
const WORDS := ["기름", "망치", "먼저", "탈", "할머니", "열쇠", "사진"]

var main: Control
var h := Hangul.new()
var shift := false
var target := ""
var shown: Label
var pic: TextureRect
var keys: Array[Button] = []
var round_i := 0


func _ready() -> void:
	color = Color("151a24"); set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new(); col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); col.add_theme_constant_override("separation", 10)
	col.offset_left = 20; col.offset_right = -20; col.offset_top = 14; col.offset_bottom = -14; add_child(col)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 18); top.size_flags_vertical = Control.SIZE_EXPAND_FILL; col.add_child(top)
	pic = TextureRect.new(); pic.custom_minimum_size = Vector2(170, 170); pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var pb := PanelContainer.new(); var ps := StyleBoxFlat.new(); ps.bg_color = Color("efe6cf"); ps.set_corner_radius_all(16); ps.set_content_margin_all(8)
	pb.add_theme_stylebox_override("panel", ps); pb.add_child(pic); top.add_child(pb)
	var mid := VBoxContainer.new(); mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mid.alignment = BoxContainer.ALIGNMENT_CENTER; top.add_child(mid)
	var ask := Label.new(); ask.text = "Type the word for this picture."; ask.add_theme_font_size_override("font_size", 20); ask.add_theme_color_override("font_color", Color("a99f8a")); mid.add_child(ask)
	shown = Label.new(); shown.add_theme_font_size_override("font_size", 64); shown.add_theme_color_override("font_color", Color("efe6cf")); mid.add_child(shown)
	var close := Button.new(); close.text = "✕"; close.custom_minimum_size = Vector2(60, 60); close.add_theme_font_size_override("font_size", 28)
	close.pressed.connect(queue_free); top.add_child(close)

	for r in ROWS.size():
		var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 8); col.add_child(row)
		if r == 2: row.add_child(_key("⇧", _toggle_shift, 1.4))
		for j in ROWS[r]:
			var b := _key(j, _type.bind(j)); keys.append(b); row.add_child(b)
		if r == 2: row.add_child(_key("⌫", _back, 1.4))
	var last := HBoxContainer.new(); last.alignment = BoxContainer.ALIGNMENT_CENTER; last.add_theme_constant_override("separation", 8); col.add_child(last)
	last.add_child(_key("space", _type.bind(" "), 4.0))
	last.add_child(_key("Check", _check, 2.0, true))
	_next_word()


func _key(t: String, f: Callable, wide := 1.0, dark := false) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(86 * wide, 70); b.add_theme_font_size_override("font_size", 32 if t.length() == 1 else 22)
	var s := StyleBoxFlat.new(); s.set_corner_radius_all(10); s.bg_color = Color("2a231d") if dark else Color("efe6cf")
	var p := s.duplicate(); p.bg_color = s.bg_color.darkened(0.25)
	for st in ["normal", "hover", "focus"]: b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("pressed", p)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(st, Color("efe6cf") if dark else Color("2a231d"))
	b.pressed.connect(f)
	return b


func _type(j: String) -> void:
	var c: String = SHIFTED.get(j, j) if shift else j
	h.add(c); Game.sound.emit("click")
	if shift: _toggle_shift()
	shown.text = h.text()


func _back() -> void: h.backspace(); Game.sound.emit("click"); shown.text = h.text()


func _toggle_shift() -> void:
	shift = not shift
	var i := 0
	for r in ROWS:
		for j in r:
			keys[i].text = SHIFTED.get(j, j) if shift else j; i += 1


func _check() -> void:
	Game.note("  keyboard: typed %s for %s: %s" % [h.text(), target, "right" if h.text().strip_edges() == target else "wrong"])
	if h.text().strip_edges() == target:
		Game.sound.emit("solve"); Game.toast.emit("맞아요! " + target)
		round_i += 1; _next_word()
	else:
		Game.sound.emit("wrong")
		var tw := create_tween()
		for k in 4: tw.tween_property(shown, "position:x", shown.position.x + (8 if k % 2 else -8), 0.04)
		tw.tween_property(shown, "position:x", shown.position.x, 0.04)


func _next_word() -> void:
	target = WORDS[round_i % WORDS.size()]; h.clear(); shown.text = ""
	pic.texture = Kit.icon(target)
