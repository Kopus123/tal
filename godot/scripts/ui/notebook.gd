extends RefCounted
## 수첩, your notebook: every word you've met, and each word's page (your guess, whether you're sure, where you saw it).
## No "check my guess": you work words out yourself. Only numbers get a picture (nothing around you could tell you
## what 사 means; everything else you work out from where it's used).

static func open(main: Control, w: String) -> void:
	if w != "": _page(main, w); return
	var inner := Kit.sheet(main, "수첩 · your notebook", 0.7)
	var met: Array = Game.words.keys().filter(func(k): return not Game.words[k].ctx.is_empty() and not Game.world.words.get(k, {}).get("g", false))
	if met.is_empty(): inner.add_child(Kit.label("No words yet. Tap an underlined word when you see one.", 20, Kit.MUTE, true)); return
	for group in [["Not written down yet", func(r): return r.note.strip_edges() == ""], ["Your guess", func(r): return r.note.strip_edges() != "" and not r.sure], ["Got it", func(r): return r.sure]]:
		var ws: Array = met.filter(func(k): return group[1].call(Game.words[k]))
		if ws.is_empty(): continue
		inner.add_child(Kit.label("%s · %d" % [group[0].to_upper(), ws.size()], 14, Kit.MUTE))
		var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 8); flow.add_theme_constant_override("v_separation", 8); inner.add_child(flow)
		for k in ws:
			var r: Dictionary = Game.words[k]
			var b := Kit.button(k + ("  · " + r.note if r.note.strip_edges() != "" else ""), false, 22)
			b.pressed.connect(func(): _page(main, k)); flow.add_child(b)


static func _page(main: Control, w: String) -> void:
	Game.note("  opened word: " + w)
	var r: Dictionary = Game.word(w)
	main.voice.say("{%s}" % w, "word")
	var inner := Kit.sheet(main, "수첩", 0.6)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 18); inner.add_child(top)
	var spec: String = Game.world.words.get(w, {}).get("p", "")
	if spec.begins_with("sino") or spec.begins_with("nat"):
		var pic := TextureRect.new(); pic.texture = Kit.icon(w); pic.custom_minimum_size = Vector2(120, 120)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; top.add_child(pic)
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(right)
	right.add_child(Kit.label(w, 52))
	var badge := Kit.label("", 15, Kit.MUTE); right.add_child(badge)
	var hear := Kit.button("▶ Hear it", false, 16); hear.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hear.pressed.connect(func(): main.voice.say("{%s}" % w, "word")); right.add_child(hear)
	var upd := func():
		badge.text = ("GOT IT · you're sure" if r.sure else "YOUR GUESS · not sure yet") if r.note.strip_edges() != "" else ("NEW WORD" if r.ctx.size() <= 1 else "NO NOTE YET")
	upd.call()
	# a grammar piece (an ending): the notebook explains it, so there's nothing to guess
	if Game.world.words.get(w, {}).get("g", false):
		badge.text = "GRAMMAR PIECE"
		inner.add_child(Kit.label(Game.world.grammar.get(w, ""), 21, Kit.PAPER_INK, true))
		_seen_in(inner, w, r); return
	inner.add_child(Kit.label("What you think it means", 16, Kit.MUTE))
	var note := LineEdit.new(); note.text = r.note; note.placeholder_text = "Your own words"; note.add_theme_font_size_override("font_size", 24)
	note.custom_minimum_size.y = 56
	var ns := Kit.box(10, Kit.PAPER_LIGHT, Kit.LINE, 2, 8); ns.content_margin_left = 14
	var nf := ns.duplicate(); nf.border_color = Kit.PAPER_INK
	note.add_theme_stylebox_override("normal", ns); note.add_theme_stylebox_override("focus", nf)
	note.add_theme_color_override("font_color", Kit.PAPER_INK); note.add_theme_color_override("font_placeholder_color", Kit.MUTE); note.add_theme_color_override("caret_color", Kit.PAPER_INK)
	inner.add_child(note)
	var sure := CheckBox.new(); sure.text = "I'm sure about this"; sure.button_pressed = r.sure; sure.disabled = r.note.strip_edges() == ""
	sure.add_theme_font_size_override("font_size", 20)
	for c in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]: sure.add_theme_color_override(c, Kit.PAPER_INK)
	sure.add_theme_color_override("font_disabled_color", Kit.MUTE)
	inner.add_child(sure)
	note.text_changed.connect(func(t):
		r.note = t
		if t.strip_edges() == "":
			r.sure = false; sure.button_pressed = false
		sure.disabled = t.strip_edges() == ""; Game.save_words(); upd.call())
	note.text_submitted.connect(func(_t): note.release_focus(); Game.note("  wrote for %s: %s" % [w, r.note]))
	sure.toggled.connect(func(on): r.sure = on; Game.save_words(); upd.call(); Game.sound.emit("solve" if on else "tap"); Game.note("  %s sure about %s" % ["is" if on else "isn't", w]))
	_seen_in(inner, w, r)
	_family(main, inner, w)


## the same word in its other forms (갔어요 · 가요 · 가: they share a picture in world.story), and where you met each,
## side by side: comparing them is how you see what stays the same and what changes
static func _family(main: Control, inner: VBoxContainer, w: String) -> void:
	var base: String = Game.world.words.get(w, {}).get("p", "").split(" ")[0]
	if base == "": return
	var fam: Array = Game.world.words.keys().filter(func(k): return k != w and Game.world.words[k].get("p", "").split(" ")[0] == base and Game.words.has(k) and not Game.words[k].ctx.is_empty())
	if fam.is_empty(): return
	inner.add_child(Kit.label("THE SAME WORD, OTHER FORMS", 14, Kit.MUTE))
	for k in fam:
		var b := Kit.button(k, false, 24); b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func(): Kit.close(inner); _page(main, k)); inner.add_child(b)
		for line in Game.words[k].ctx.slice(0, 2):
			var c := Kit.rich(20); c.text = "   " + Kit.esc(line).replace(k, "[bgcolor=#%s]%s[/bgcolor]" % [Kit.HILITE.to_html(false), k]); inner.add_child(c)


static func _seen_in(inner: VBoxContainer, w: String, r: Dictionary) -> void:
	inner.add_child(Kit.label("Where you've seen it", 16, Kit.MUTE))
	if r.ctx.is_empty(): inner.add_child(Kit.label("Not seen anywhere yet.", 20, Kit.MUTE))
	for line in r.ctx:
		var c := Kit.rich(22); c.text = Kit.esc(line).replace(w, "[bgcolor=#%s]%s[/bgcolor]" % [Kit.HILITE.to_html(false), w]); inner.add_child(c)


## a name (수진) or a sound (아이고): not a word to learn, but you can still look
static func name_page(main: Control, n: String) -> void:
	var d: Dictionary = Game.world.names.get(n, {})
	var inner := Kit.sheet(main, "소리" if d.get("kind", "") == "sound" else "이름", 0.5)
	inner.add_child(Kit.label(n, 52))
	inner.add_child(Kit.label("A SOUND PEOPLE MAKE" if d.get("kind", "") == "sound" else "A NAME", 15, Kit.MUTE))
	inner.add_child(Kit.label(d.get("d", ""), 22, Kit.PAPER_INK, true))
	var hear := Kit.button("▶ Hear it", false, 18); hear.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hear.pressed.connect(func(): main.voice.say(n, "word")); inner.add_child(hear)
	main.voice.say(n, "word")
