extends RefCounted
## 할머니's phone: her message threads. Reading one can move the story on (it sets read_ID); a voicemail you can only
## hear (vm_ID once you've listened).

static func open(main: Control) -> void:
	var inner := Kit.sheet(main, "메시지", 0.5)
	_list(main, inner)


static func _list(main: Control, inner: VBoxContainer) -> void:
	Kit.clear(inner)
	for t in Game.ST.phones:
		var ms: Array = Game.thread_msgs(t)
		var last = null
		for m in ms:
			if not m.has("d"): last = m
		var b := Kit.button("%s %s\n%s" % [t.name, "●" if Game.thread_unread(t) else "", ("🔊 voicemail" if last.has("vm") else Game.plain(last.get("ko", ""))) if last != null else ""], false, 20)
		b.custom_minimum_size.y = 76
		b.pressed.connect(func(): Game.sound.emit("tap"); _thread(main, inner, t)); inner.add_child(b)


static func _thread(main: Control, inner: VBoxContainer, t: Dictionary) -> void:
	Game.read_thread(t.id)
	Kit.clear(inner)
	var back := Kit.button("‹ " + t.name, true, 20); back.pressed.connect(func(): main.voice.stop(); _list(main, inner)); inner.add_child(back)
	for m in Game.thread_msgs(t):
		if m.has("d"):
			var d := Kit.rich(17, Kit.MUTE); d.text = "[center]%s[/center]" % Kit.ko(m.d); d.meta_clicked.connect(func(w): main._word(str(w))); inner.add_child(d); continue
		if m.get("sys", false):
			inner.add_child(Kit.label(m.ko, 17, Kit.MUTE)); continue
		var row := HBoxContainer.new(); inner.add_child(row)
		var bub := PanelContainer.new(); bub.size_flags_horizontal = Control.SIZE_SHRINK_END if m.get("me", false) else Control.SIZE_SHRINK_BEGIN
		bub.add_theme_stylebox_override("panel", Kit.box(16, Color("d9e8d0") if m.get("me", false) else Kit.PAPER_LIGHT, Kit.LINE, 1, 12))
		if m.get("me", false):
			var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(sp)
		row.add_child(bub)
		if m.get("vm", false):
			var vb := Kit.button("🔊  Voicemail · %s · tap to listen" % m.t, false, 20)
			vb.pressed.connect(func(): Game.heard_voicemail(t.id); main.voice.say(m.ko, m.who)); bub.add_child(vb); continue
		var v := VBoxContainer.new(); bub.add_child(v)
		var r := Kit.rich(24); r.custom_minimum_size.x = 380; r.text = Kit.ko(m.ko); r.meta_clicked.connect(func(w): main._word(str(w))); v.add_child(r)
		v.add_child(Kit.label(m.get("t", ""), 14, Kit.MUTE))
	if t.has("note") and Game.cond(t.get("note_c", "")):
		inner.add_child(Kit.label(t.note, 18, Kit.MUTE, true))
