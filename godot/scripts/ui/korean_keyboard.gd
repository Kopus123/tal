extends PanelContainer
## The game's own Korean keyboard (standard 두벌식 layout) for typed answers, so Android's keyboard is never involved.
## Letters join into blocks as you type (scripts/core/hangul.gd). Sits over the bottom of the screen.
## Hint: each tap shows more of the answer (first letter of each word, then two, then all of it).

signal submitted(text: String)
signal closed

const ROWS := [["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅛ", "ㅕ", "ㅑ", "ㅐ", "ㅔ"], ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"], ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"]]
const SHIFTED := {"ㅂ": "ㅃ", "ㅈ": "ㅉ", "ㄷ": "ㄸ", "ㄱ": "ㄲ", "ㅅ": "ㅆ", "ㅐ": "ㅒ", "ㅔ": "ㅖ"}

var hint_text := ""
var h := Hangul.new()
var shift := false
var keys: Array[Button] = []
var shown: Label
var hint_l: Label
var hint_level := 0


func _ready() -> void:
	anchor_left = 0; anchor_right = 1; anchor_top = 0.44; anchor_bottom = 1
	offset_left = 0; offset_right = 0; offset_top = 0; offset_bottom = 0
	add_theme_stylebox_override("panel", Kit.box(18, Color("1d2330"), Color.TRANSPARENT, 0, 12))
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 6); add_child(col)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 10); col.add_child(top)
	var close := _key("✕", func(): closed.emit(); queue_free(), 1.0); top.add_child(close)
	var mid := VBoxContainer.new(); mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mid.add_theme_constant_override("separation", -6); top.add_child(mid)
	shown = Kit.label("", 40, Kit.PAPER); mid.add_child(shown)
	hint_l = Kit.label("", 22, Kit.MUTE); mid.add_child(hint_l)
	top.add_child(_key("Hint", _hint, 1.3))
	top.add_child(_key("Say it", _say, 1.6, true))
	for r in ROWS.size():
		var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 6); col.add_child(row)
		if r == 2: row.add_child(_key("⇧", _toggle_shift, 1.4))
		for j in ROWS[r]:
			var b := _key(j, _type.bind(j)); keys.append(b); row.add_child(b)
		if r == 2: row.add_child(_key("⌫", _back, 1.4))
	var last := HBoxContainer.new(); last.alignment = BoxContainer.ALIGNMENT_CENTER; col.add_child(last)
	last.add_child(_key("space", _type.bind(" "), 5.0))


func _key(t: String, f: Callable, wide := 1.0, dark := false) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(84 * wide, 58); b.add_theme_font_size_override("font_size", 30 if t.length() == 1 else 20)
	var s := Kit.box(10, Kit.PAPER_INK if dark else Kit.PAPER, Color.TRANSPARENT, 0, 4)
	var p := s.duplicate(); p.bg_color = s.bg_color.darkened(0.25)
	for st in ["normal", "hover", "focus"]: b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("pressed", p)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(st, Kit.PAPER if dark else Kit.PAPER_INK)
	b.pressed.connect(f)
	return b


func _type(j: String) -> void:
	h.add(SHIFTED.get(j, j) if shift else j); Game.sound.emit("click")
	if shift: _toggle_shift()
	shown.text = h.text()


func _say() -> void:
	if h.text().strip_edges() != "": submitted.emit(h.text())


func _back() -> void:
	h.backspace(); Game.sound.emit("click"); shown.text = h.text()


func _toggle_shift() -> void:
	shift = not shift
	var i := 0
	for r in ROWS:
		for j in r:
			keys[i].text = SHIFTED.get(j, j) if shift else j; i += 1


## the answer with only the first letters of each word showing, more each time
func _hint() -> void:
	hint_level = mini(hint_level + 1, 3); Game.sound.emit("tap"); Game.note("  keyboard hint %d" % hint_level)
	if hint_level >= 3: hint_l.text = hint_text; return
	var out := []
	for w in hint_text.split(" "):
		var s := ""
		for i in w.length(): s += w[i] if i < hint_level or ".?!~,…".contains(w[i]) else "_"
		out.append(s)
	hint_l.text = " ".join(out)
