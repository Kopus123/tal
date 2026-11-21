extends Control
## Pipeline test: if this shows on the phone with readable Korean, the laptop-to-phone chain works.

const BUILD := 1

func _ready() -> void:
	var l := Label.new()
	l.text = "탈 · Godot 테스트\n한국어 글자가 보여요?\nbuild %d" % BUILD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 64)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(l)
