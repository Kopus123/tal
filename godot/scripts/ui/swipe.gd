class_name Swipe
extends ScrollContainer
## A list you move with your finger, wherever it lands: on a button, on a word, on empty paper. A short press is still
## a tap; once the finger moves up or down, the press is called off and the list follows it, and glides when you let go.
## The bar at the side only shows where you are. A small "more" tab shows while there's more below.
##   var inner := Swipe.make(parent)      ## a VBoxContainer to fill

const START := 18.0        ## how far a finger goes before it's a swipe (a tap wobbles less than this)
const FRICTION := 4.5

static var glide := true   ## (the playtester turns it off: its time runs 40x)
var more: Label
var _down := false
var _mine := false         ## following the finger
var _at := Vector2.ZERO
var _from := 0.0
var _y := 0.0              ## where the list really is (scroll_vertical is whole pixels)
var _speed := 0.0
var _last := 0
var _focus_was: Control


static func make(parent: Control, dark := false) -> VBoxContainer:
	var hold := Control.new(); hold.size_flags_vertical = Control.SIZE_EXPAND_FILL; hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE; hold.clip_contents = true; parent.add_child(hold)
	var s := Swipe.new(); s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hold.add_child(s)
	var pad := MarginContainer.new(); pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pad.add_theme_constant_override("margin_right", 8); pad.mouse_filter = Control.MOUSE_FILTER_PASS; s.add_child(pad)
	var inner := VBoxContainer.new(); inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL; inner.add_theme_constant_override("separation", 10); inner.mouse_filter = Control.MOUSE_FILTER_PASS; pad.add_child(inner)
	inner.set_meta("swipe", s)
	s.more = Kit.label("▾  more", 16, Kit.PAPER if not dark else Color("e9edf3")); s.more.mouse_filter = Control.MOUSE_FILTER_IGNORE; s.more.visible = false
	var st := Kit.box(12, Color(0.16, 0.14, 0.11, 0.82), Color.TRANSPARENT, 0, 4); st.content_margin_left = 14; st.content_margin_right = 14
	s.more.add_theme_stylebox_override("normal", st); s.more.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	s.more.grow_horizontal = Control.GROW_DIRECTION_BOTH; s.more.grow_vertical = Control.GROW_DIRECTION_BEGIN; hold.add_child(s.more)
	return inner


func _ready() -> void:
	scroll_deadzone = 1000000   # the built-in touch scrolling stays out of it (it can't start on a button)
	var bar := get_v_scroll_bar(); bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; bar.custom_minimum_size.x = 8
	bar.add_theme_stylebox_override("scroll", Kit.box(4, Color(0, 0, 0, 0.06), Color.TRANSPARENT, 0, 0))
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]: bar.add_theme_stylebox_override(k, Kit.box(4, Color(0.45, 0.4, 0.32, 0.75), Color.TRANSPARENT, 0, 4))
	bar.changed.connect(_hint); bar.value_changed.connect(func(_v): _hint())


func _hint() -> void:
	if more: more.visible = room_below() > 24


func room_below() -> float:
	var bar := get_v_scroll_bar(); return bar.max_value - bar.page - bar.value


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree(): _down = false; _mine = false; return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = get_global_rect().has_point(e.position); _mine = false; _speed = 0.0
			_at = e.position; _last = Time.get_ticks_usec(); _focus_was = get_viewport().gui_get_focus_owner()
		else:
			_down = false
			if _mine:
				_mine = false
				if Time.get_ticks_usec() - _last > 80000 or not glide: _speed = 0.0
				set_process(absf(_speed) > 40)
	elif e is InputEventMouseMotion and _down:
		if not _mine:
			var d: Vector2 = e.position - _at
			if absf(d.y) < START: return
			if absf(d.x) > absf(d.y) * 1.5: _down = false; return
			var on := get_viewport().gui_get_hovered_control()
			if on == null or not (on == self or is_ancestor_of(on)): _down = false; return   # something is over the list
			if get_v_scroll_bar().max_value <= get_v_scroll_bar().page + 1: _down = false; return
			_begin(e.position)
		if not _mine: return
		var dt := maxf((Time.get_ticks_usec() - _last) / 1e6, 0.001); _last = Time.get_ticks_usec()
		var y := clampf(_from - (e.position.y - _at.y), 0.0, maxf(0.0, get_v_scroll_bar().max_value - get_v_scroll_bar().page))
		_speed = lerpf(_speed, (y - _y) / dt, 0.5); _y = y; scroll_vertical = int(round(y))
		get_viewport().set_input_as_handled()


## it's a swipe: whatever the finger was pressing lets go (its release happens far away, so nothing gets clicked)
func _begin(p: Vector2) -> void:
	propagate_notification(NOTIFICATION_SCROLL_BEGIN)
	var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = Vector2(-5000, -5000); up.global_position = up.position
	var was_down := _down
	get_viewport().push_input(up, true)
	_down = was_down; _mine = true; _from = scroll_vertical; _y = _from; _at = p
	var f := get_viewport().gui_get_focus_owner()
	if f is LineEdit and f != _focus_was: f.release_focus()   # you swiped over the box, you didn't tap it


func _process(dt: float) -> void:   # the glide
	if _mine or absf(_speed) < 40: set_process(false); return
	_speed *= exp(-FRICTION * dt); _y = clampf(_y + _speed * dt, 0.0, maxf(0.0, get_v_scroll_bar().max_value - get_v_scroll_bar().page))
	scroll_vertical = int(round(_y))
