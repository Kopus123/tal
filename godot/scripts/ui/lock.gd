extends ColorRect
## A combination lock with number wheels, over the picture ("@number ... | count" beats).
## Swipe a wheel up or down, or tap the arrows. "Try it" sends the numbers; "Leave it" walks away.

signal tried(value: String)

var digits: Array[int] = []
var labels: Array[Label] = []
var _drag_from := {}


func setup(n: int) -> void:
	digits.resize(n); digits.fill(0)


func _ready() -> void:
	color = Color(0, 0, 0, 0.6); set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var c := CenterContainer.new(); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(c)
	var plate := PanelContainer.new(); var st := StyleBoxFlat.new(); st.bg_color = Color("8d939a"); st.set_corner_radius_all(16)
	st.border_color = Color("4a4f55"); st.set_border_width_all(4); st.set_content_margin_all(18); plate.add_theme_stylebox_override("panel", st)
	c.add_child(plate)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 12); plate.add_child(col)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); row.alignment = BoxContainer.ALIGNMENT_CENTER; col.add_child(row)
	for i in digits.size():
		var w := VBoxContainer.new(); w.add_theme_constant_override("separation", 2); row.add_child(w)
		w.add_child(_arrow("▲", i, -1))
		var face := PanelContainer.new(); var fs := StyleBoxFlat.new(); fs.bg_color = Color("e8e6df"); fs.set_corner_radius_all(8)
		fs.border_color = Color("555"); fs.set_border_width_all(2); fs.content_margin_left = 18; fs.content_margin_right = 18
		face.add_theme_stylebox_override("panel", fs); face.mouse_filter = Control.MOUSE_FILTER_STOP
		face.gui_input.connect(_wheel_input.bind(i)); w.add_child(face)
		var l := Label.new(); l.text = "0"; l.add_theme_font_size_override("font_size", 64); l.add_theme_color_override("font_color", Color("2a2a2a"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; face.add_child(l); labels.append(l)
		w.add_child(_arrow("▼", i, 1))
	var btns := HBoxContainer.new(); btns.add_theme_constant_override("separation", 10); col.add_child(btns)
	var leave := _btn("Leave it", false); leave.pressed.connect(func(): Game.sound.emit("tap"); queue_free(); Game.leave()); btns.add_child(leave)
	var go := _btn("Try it", true); go.pressed.connect(_try); btns.add_child(go)


func _arrow(t: String, i: int, d: int) -> Button:
	var b := Button.new(); b.text = t; b.flat = true; b.custom_minimum_size = Vector2(76, 52); b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color("2a2a2a")); b.pressed.connect(_turn.bind(i, d))
	return b


func _btn(t: String, dark: bool) -> Button:
	var b := Button.new(); b.text = t; b.add_theme_font_size_override("font_size", 22); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new(); s.set_corner_radius_all(10); s.set_content_margin_all(12); s.bg_color = Color("2a231d") if dark else Color("fbf6e9")
	for st in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, s)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(st, Color("efe6cf") if dark else Color("2a231d"))
	return b


func _turn(i: int, d: int) -> void:
	digits[i] = (digits[i] + d + 10) % 10; labels[i].text = str(digits[i])
	Game.sound.emit("click")
	var tw := create_tween(); labels[i].position.y = -10 * d; tw.tween_property(labels[i], "position:y", 0.0, 0.12)


## swipe a wheel: every 40 pixels is one number
func _wheel_input(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed: _drag_from[i] = e.position.y
		else: _drag_from.erase(i)
	elif e is InputEventMouseMotion and _drag_from.has(i):
		var dy: float = e.position.y - _drag_from[i]
		if absf(dy) >= 40:
			_turn(i, -1 if dy < 0 else 1); _drag_from[i] = e.position.y


func _try() -> void:
	var v := "".join(digits.map(func(x): return str(x)))
	queue_free(); tried.emit(v)
