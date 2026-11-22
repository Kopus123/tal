class_name Kit
extends RefCounted
## The look of every screen in one place: colors, text, buttons, paper panels, pop-ups, pictures.
## (Change a color here and it changes everywhere.)

const INK := Color("151a24")
const PAPER := Color("efe6cf")
const PAPER_LIGHT := Color("fbf6e9")
const PAPER_INK := Color("2a231d")
const MUTE := Color("8a7d66")
const LINE := Color("cbbf9f")
const WORD := Color("7a3b1e")
const HILITE := Color("e9c97a")


static func label(t: String, sz: int, c: Color = PAPER_INK, wrap := false) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", c)
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func box(radius: int, bg: Color, border: Color = Color.TRANSPARENT, bw := 0, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(radius); s.border_color = border; s.set_border_width_all(bw); s.set_content_margin_all(pad)
	return s


## dark = the main action (ink on paper inverted); otherwise a paper button with an ink border
static func button(t: String, dark := false, sz := 22) -> Button:
	var b := Button.new(); b.text = t; b.add_theme_font_size_override("font_size", sz)
	var n := box(12, PAPER_INK if dark else PAPER_LIGHT, PAPER_INK, 0 if dark else 2, 12); n.content_margin_left = 16; n.content_margin_right = 16
	var p := n.duplicate(); p.bg_color = n.bg_color.darkened(0.15)
	var d := n.duplicate(); d.bg_color = n.bg_color.lerp(PAPER, 0.6); d.border_color = LINE
	for st in ["normal", "hover", "focus"]: b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("pressed", p); b.add_theme_stylebox_override("disabled", d)
	var fc := PAPER if dark else PAPER_INK
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(st, fc)
	b.add_theme_color_override("font_disabled_color", MUTE)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if dark else HORIZONTAL_ALIGNMENT_LEFT
	return b


## a full-width button whose text wraps onto more lines (choices, cards)
static func wide(t: String, dark := false, sz := 22) -> Button:
	var b := button(t, dark, sz); b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


## a sheet of paper over everything (the case board, the phone, the notebook...). Returns the inside to fill;
## close it with `Kit.close(inside)`.
static func sheet(parent: Control, title: String, wide := 0.8) -> VBoxContainer:
	var o := ColorRect.new(); o.color = Color(0, 0, 0, 0.6); o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); parent.add_child(o)
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", box(18, PAPER, Color.TRANSPARENT, 0, 20))
	p.anchor_left = (1 - wide) / 2; p.anchor_right = 1 - (1 - wide) / 2; p.anchor_top = 0.04; p.anchor_bottom = 0.96; o.add_child(p)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 10); p.add_child(col)
	var head := HBoxContainer.new(); col.add_child(head)
	var t := label(title, 30); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
	var x := button("✕", true); x.custom_minimum_size = Vector2(56, 56); head.add_child(x)
	x.pressed.connect(func(): Game.sound.emit("tap"); o.queue_free())
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; col.add_child(sc)
	var inner := VBoxContainer.new(); inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL; inner.add_theme_constant_override("separation", 10); sc.add_child(inner)
	inner.set_meta("overlay", o)
	return inner


static func close(inner: Control) -> void:
	if inner.has_meta("overlay"): inner.get_meta("overlay").queue_free()


static func clear(c: Node) -> void:
	for k in c.get_children(): k.queue_free()


## ---------- pictures
static var _sheet: Texture2D
static var _icons: Dictionary = {}
static var _people: Texture2D
static var _pinfo: Dictionary = {}

## a word's picture ("기름") or a picture by its own name ("#oil")
static func icon(key: String) -> Texture2D:
	if _sheet == null:
		_sheet = load("res://icons/sheet.png")
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://icons/index.json"))
		if d is Dictionary: _icons = d
	var i = _icons.get("words", {}).get(key)
	if i == null: return null
	var a := AtlasTexture.new(); a.atlas = _sheet
	var sz := float(_icons.size); var cols := int(_icons.cols)
	a.region = Rect2((int(i) % cols) * sz, int(int(i) / cols) * sz, sz, sz)
	return a


static func _load_people() -> void:
	if _people != null: return
	_people = load("res://art/people.png")
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://art/people.json"))
	if d is Dictionary: _pinfo = d


## a speaker's face ("sujin", "worried"); someone with no look (the bus, a text, a stranger) gets a speaker icon
static func face(who: String, ex := "neutral") -> Texture2D:
	_load_people()
	var a := AtlasTexture.new(); a.atlas = _people
	var row: int = _pinfo.get("cast", []).find(who); var f := float(_pinfo.get("face", 200))
	if row < 0:
		a.region = Rect2(_pinfo.get("figures", []).size() * f, _pinfo.get("cast", []).size() * f, f, f); return a
	var col: int = maxi(0, _pinfo.get("faces", []).find(ex))
	a.region = Rect2(col * f, row * f, f, f)
	return a


## a villager standing (free days)
static func figure(who: String) -> Texture2D:
	_load_people()
	var i: int = _pinfo.get("figures", []).find(who)
	if i < 0: return null
	var a := AtlasTexture.new(); a.atlas = _people
	a.region = Rect2(i * float(_pinfo.fig_w), _pinfo.get("cast", []).size() * float(_pinfo.face), float(_pinfo.fig_w), float(_pinfo.fig_h))
	return a


## ---------- text with tappable Korean words: "{봤어요}" becomes a link to its notebook page, colored by how well you
## know it (new, seen, your guess, sure; grammar pieces quieter). Names and sounds (수진, 아이고) are tappable too.
const STATUS_COLORS := {"new": "a8620f", "seen": "3d5f9a", "guess": "7a4a9a", "sure": "3f8b77", "gram": "6b6255"}
const STATUS_DARK := {"new": "f0b35a", "seen": "9db8ea", "guess": "c9a3e6", "sure": "8fd3c0", "gram": "c9cfdb"}

static func esc(s: String) -> String: return s.replace("[", "[lb]")


static func status(w: String) -> String:
	if Game.world.words.get(w, {}).get("g", false): return "gram"
	var r: Dictionary = Game.words.get(w, {})
	if r.is_empty(): return "new"
	if r.note.strip_edges() != "": return "sure" if r.sure else "guess"
	return "new" if r.ctx.size() <= 1 else "seen"


static var _names_re: RegEx
static func _names(s: String, dark: bool) -> String:
	if _names_re == null:
		var ns: Array = Game.world.names.keys()
		ns.sort_custom(func(a, b): return a.length() > b.length())
		_names_re = RegEx.create_from_string("(?<![가-힣])(" + "|".join(ns.map(func(n): return _rx(n))) + ")") if not ns.is_empty() else RegEx.create_from_string("(?!x)x")
	var c: String = STATUS_DARK.gram if dark else STATUS_COLORS.gram
	return _names_re.sub(s, "[url=n:$1][color=#%s]$1[/color][/url]" % c, true)


static func _rx(s: String) -> String:
	var out := ""
	for ch in s: out += ("\\" + ch) if ".*+?^${}()|[]\\".contains(ch) else ch
	return out


static func ko(s: String, dark := false) -> String:
	var re := Story.R("\\{([^}|]+)(?:\\|([^}]+))?\\}")
	var out := ""; var at := 0
	var cols: Dictionary = STATUS_DARK if dark else STATUS_COLORS
	for m in re.search_all(s):
		out += _names(esc(s.substr(at, m.get_start() - at)), dark)
		var entry := m.get_string(2) if m.get_string(2) != "" else m.get_string(1)
		var st := status(entry)
		out += "[url=w:%s][color=#%s][u]%s[/u][/color][/url]" % [entry, cols[st], esc(m.get_string(1))]
		at = m.get_end()
	return out + _names(esc(s.substr(at)), dark)


static func rich(sz := 24, c: Color = PAPER_INK) -> RichTextLabel:
	var r := RichTextLabel.new(); r.bbcode_enabled = true; r.fit_content = true; r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_color_override("default_color", c); r.meta_underlined = false
	for k in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]: r.add_theme_font_size_override(k, sz)
	r.scroll_active = false
	return r
