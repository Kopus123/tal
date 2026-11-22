extends RefCounted
## 할머니's phone: it looks like a phone (dark screen, status bar, message bubbles). Her threads; tap a message to hear it.
## Reading a thread can move the story on (read_ID); a voicemail you can only hear (vm_ID once you've listened).

const SCREEN := Color("10141b")
const BAR := Color("0b0d12")
const THEM := Color("252c39")
const ME := Color("2f6f61")
const TEXT := Color("e9edf3")
const SOFT := Color("8a93a3")
const ACCENT := Color("8fd3c0")


static func open(main: Control) -> void:
	var o := ColorRect.new(); o.color = Color(0, 0, 0, 0.7); o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); main.add_child(o)
	var body := PanelContainer.new()
	var frame := StyleBoxFlat.new(); frame.bg_color = BAR; frame.set_corner_radius_all(38); frame.border_color = Color("1b1f27"); frame.set_border_width_all(10)
	frame.content_margin_left = 10; frame.content_margin_right = 10; frame.content_margin_top = 8; frame.content_margin_bottom = 14
	body.add_theme_stylebox_override("panel", frame)
	body.anchor_left = 0.5; body.anchor_right = 0.5; body.anchor_top = 0.03; body.anchor_bottom = 0.97
	body.offset_left = -230; body.offset_right = 230
	o.add_child(body)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 0); body.add_child(col)
	var status := HBoxContainer.new(); col.add_child(status)
	var tl := Kit.label("08:47", 15, SOFT); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; status.add_child(tl)
	status.add_child(Kit.label("▂▄▆  42%", 15, SOFT))
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 8); col.add_child(top)
	var screen := PanelContainer.new(); screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_theme_stylebox_override("panel", Kit.box(14, SCREEN, Color.TRANSPARENT, 0, 10)); col.add_child(screen)
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.scroll_deadzone = 24; screen.add_child(sc)
	var inner := VBoxContainer.new(); inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL; inner.add_theme_constant_override("separation", 8); sc.add_child(inner)
	var ctx := {"main": main, "o": o, "top": top, "inner": inner, "sc": sc}
	_list(ctx)


static func _flat(t: String, c: Color, sz := 20) -> Button:
	var b := Button.new(); b.text = t; b.flat = true; b.add_theme_font_size_override("font_size", sz)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(st, c)
	return b


static func _head(ctx: Dictionary, title: String, back: Callable) -> void:
	Kit.clear(ctx.top)
	if back.is_valid():
		var b := _flat("‹ Back", ACCENT); b.pressed.connect(back); ctx.top.add_child(b)
	var t := Kit.label(title, 22, TEXT); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ctx.top.add_child(t)
	var x := _flat("Close", ACCENT); x.pressed.connect(func(): ctx.main.voice.stop(); ctx.o.queue_free(); Game.sound.emit("tap")); ctx.top.add_child(x)


static func _list(ctx: Dictionary) -> void:
	_head(ctx, "메시지", Callable())
	Kit.clear(ctx.inner)
	for t in Game.ST.phones:
		var last = null
		for m in Game.thread_msgs(t):
			if not m.has("d"): last = m
		var b := Button.new(); b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.custom_minimum_size.y = 74
		b.text = "%s%s\n%s" % [t.name, "   ●" if Game.thread_unread(t) else "", ("🔊 voicemail" if last.has("vm") else Game.plain(last.get("ko", ""))) if last != null else ""]
		b.add_theme_font_size_override("font_size", 19); b.clip_text = true
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(st, TEXT)
		var s := Kit.box(12, Color("171c25"), Color("222834"), 1, 12)
		for st in ["normal", "hover", "focus"]: b.add_theme_stylebox_override(st, s)
		var p := s.duplicate(); p.bg_color = Color("222a36"); b.add_theme_stylebox_override("pressed", p)
		b.pressed.connect(func(): Game.sound.emit("tap"); _thread(ctx, t)); ctx.inner.add_child(b)


static func _thread(ctx: Dictionary, t: Dictionary) -> void:
	Game.read_thread(t.id)
	_head(ctx, t.name, func(): ctx.main.voice.stop(); _list(ctx))
	Kit.clear(ctx.inner)
	var main: Control = ctx.main
	for m in Game.thread_msgs(t):
		if m.has("d"):
			var d := Kit.rich(16, SOFT); d.text = "[center]%s[/center]" % Kit.ko(m.d, true); d.meta_clicked.connect(func(w): main._word(str(w))); ctx.inner.add_child(d); continue
		if m.get("sys", false):
			var sl := Kit.label(m.ko, 16, SOFT); sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ctx.inner.add_child(sl); continue
		var me: bool = m.get("me", false)
		var row := HBoxContainer.new(); ctx.inner.add_child(row)
		if me:
			var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(sp)
		var bub := PanelContainer.new()
		var st := Kit.box(16, ME if me else THEM, Color.TRANSPARENT, 0, 12)
		if me: st.corner_radius_bottom_right = 4
		else: st.corner_radius_bottom_left = 4
		bub.add_theme_stylebox_override("panel", st); row.add_child(bub)
		if m.get("vm", false):
			var vb := _flat("🔊  Voicemail · %s · tap to listen" % m.t, ACCENT, 19)
			vb.pressed.connect(func(): Game.heard_voicemail(t.id); main.voice.say(m.ko, m.who)); bub.add_child(vb); continue
		var v := VBoxContainer.new(); bub.add_child(v)
		var r := Kit.rich(23, TEXT); r.custom_minimum_size.x = 300; r.text = Kit.ko(m.ko, true)
		r.meta_clicked.connect(func(w): main._word(str(w))); v.add_child(r)
		var foot := HBoxContainer.new(); v.add_child(foot)
		var hear := _flat("▶", ACCENT, 16); hear.pressed.connect(func(): main.voice.say(m.ko, "sign")); foot.add_child(hear)
		var tm := Kit.label(m.get("t", ""), 14, SOFT); tm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; foot.add_child(tm)
		# tapping the bubble itself plays it too
		bub.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed: main.voice.say(m.ko, "sign"))
	if t.has("note") and Game.cond(t.get("note_c", "")):
		ctx.inner.add_child(Kit.label(t.note, 17, SOFT, true))
	await ctx.main.get_tree().process_frame
	ctx.sc.scroll_vertical = 100000
