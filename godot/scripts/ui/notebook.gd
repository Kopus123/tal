extends RefCounted
## 수첩, your notebook: every word you've met, and each word's page (your guess, whether you're sure, where you saw it).
## No "check my guess": you work words out yourself. Only numbers get a picture (nothing around you could tell you
## what 사 means; everything else you work out from where it's used).

## the notebook: tabs along the top (words, grammar, patterns, numbers, misheard, what the colors mean).
## Words: filter by how well you know them, search Korean or your own notes, sort, and tap one to open its page.
static var tab := "words"
static var filt := "all"
static var sort_by := "ko"
static var query := ""

const TABS := [["words", "단어 · Words"], ["gram", "문법 · Grammar"], ["pat", "패턴 · Patterns"], ["num", "숫자 · Numbers"], ["mix", "잘못 들음 · Misheard"], ["key", "표시 · Key"]]

static func open(main: Control, w: String) -> void:
	if w != "": _page(main, w); return
	var inner := Kit.sheet(main, "수첩 · your notebook", 0.88)
	_draw(main, inner)


static func _draw(main: Control, inner: VBoxContainer) -> void:
	Kit.clear(inner)
	var bar := HFlowContainer.new(); bar.add_theme_constant_override("h_separation", 8); bar.add_theme_constant_override("v_separation", 8); inner.add_child(bar)
	for t in TABS:
		if t[0] == "mix" and Game.S.mx.is_empty(): continue
		var b := Kit.button(t[1], t[0] == tab, 18)
		b.pressed.connect(func(): tab = t[0]; Game.sound.emit("tap"); _draw(main, inner)); bar.add_child(b)
	match tab:
		"words": _words(main, inner)
		"gram": _grammar(main, inner)
		"pat": _patterns(main, inner)
		"num": _numbers(main, inner)
		"mix": _misheard(main, inner)
		"key": _key(inner)


static func _st(k: String) -> String: return Kit.status(k)

## ---------- words
static func _vocab() -> Array:
	return Game.words.keys().filter(func(k): return not Game.words[k].ctx.is_empty() and Game.world.words.has(k) and not Game.world.words[k].get("g", false))


static func _words(main: Control, inner: VBoxContainer) -> void:
	var all := _vocab()
	if all.is_empty(): inner.add_child(Kit.label("No words yet. Tap an underlined word when you see one.", 20, Kit.MUTE, true)); return
	var n_sure := all.filter(func(k): return _st(k) == "sure").size(); var n_guess := all.filter(func(k): return _st(k) == "guess").size()
	inner.add_child(Kit.label("%d got it  ·  %d guessing  ·  %d words seen" % [n_sure, n_guess, all.size()], 16, Kit.MUTE))
	var tools := HFlowContainer.new(); tools.add_theme_constant_override("h_separation", 8); tools.add_theme_constant_override("v_separation", 8); inner.add_child(tools)
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10)
	var fill := func(): _fill(main, grid, all)
	for f in [["all", "All"], ["todo", "No note yet"], ["guess", "Guessing"], ["sure", "Got it"]]:
		var b := Kit.button(f[1], f[0] == filt, 17)
		b.pressed.connect(func(): filt = f[0]; _draw(main, inner)); tools.add_child(b)
	var sep := Control.new(); sep.custom_minimum_size = Vector2(16, 1); tools.add_child(sep)
	for s in [["ko", "ㄱㄴㄷ"], ["en", "A–Z"], ["new", "Newest"]]:
		var b := Kit.button(s[1], s[0] == sort_by, 17)
		b.pressed.connect(func(): sort_by = s[0]; _draw(main, inner)); tools.add_child(b)
	var q := LineEdit.new(); q.text = query; q.placeholder_text = "Search Korean or your notes"; q.add_theme_font_size_override("font_size", 20)
	q.custom_minimum_size = Vector2(0, 50); q.clear_button_enabled = true
	var qs := Kit.box(10, Kit.PAPER_LIGHT, Kit.LINE, 2, 8); qs.content_margin_left = 14
	q.add_theme_stylebox_override("normal", qs); q.add_theme_stylebox_override("focus", qs)
	q.add_theme_color_override("font_color", Kit.PAPER_INK); q.add_theme_color_override("font_placeholder_color", Kit.MUTE); q.add_theme_color_override("caret_color", Kit.PAPER_INK)
	inner.add_child(q)
	q.text_changed.connect(func(t): query = t.strip_edges(); fill.call())   # only the list redraws, so you keep typing
	inner.add_child(grid)
	fill.call()


static func _fill(main: Control, grid: GridContainer, all: Array) -> void:
	Kit.clear(grid)
	var list: Array = all.duplicate()
	match filt:
		"todo": list = list.filter(func(k): return _st(k) in ["new", "seen"])
		"guess": list = list.filter(func(k): return _st(k) == "guess")
		"sure": list = list.filter(func(k): return _st(k) == "sure")
	if query != "":
		var ql := query.to_lower()
		list = list.filter(func(k): return k.contains(query) or Game.words[k].note.to_lower().contains(ql))
	match sort_by:
		"ko": list.sort()
		"en": list.sort_custom(func(a, b):
			var x: String = Game.words[a].note.strip_edges().to_lower(); var y: String = Game.words[b].note.strip_edges().to_lower()
			if (x == "") != (y == ""): return y == ""
			return x < y if x != y else a < b)
		"new": list.reverse()
	if list.is_empty(): grid.add_child(Kit.label("Nothing here.", 20, Kit.MUTE)); return
	var turn: int = grid.get_meta("turn", 0) + 1; grid.set_meta("turn", turn)
	filling = true
	for i in list.size():
		if i >= 30 and i % 12 == 0:
			await main.get_tree().process_frame
			if not is_instance_valid(grid): filling = false; return
			if grid.get_meta("turn") != turn: return   # another filter or search took over
		grid.add_child(_tile(main, list[i]))
	filling = false


static func _fit(f: Font, t: String, w: float) -> String:
	if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= w: return t
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x > w: t = t.left(-1)
	return t + "…"


static var _looks: Dictionary = {}
static var filling := false      ## the list is still coming in
## a word as a little index card: the Korean big, your note under it, a stripe in its color
static func _tile(main: Control, k: String) -> Button:
	var st := _st(k); var col := Color("#" + Kit.STATUS_COLORS[st])
	var b := Button.new(); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size = Vector2(0, 86)
	b.set_meta("word", k)
	if not _looks.has(st):
		var sb := Kit.box(10, Kit.PAPER_LIGHT, Kit.LINE, 1, 10); sb.border_width_left = 8; sb.border_color = col
		var sp := sb.duplicate(); sp.bg_color = Kit.PAPER_LIGHT.darkened(0.08); _looks[st] = [sb, sp]
	for s in ["normal", "hover", "focus"]: b.add_theme_stylebox_override(s, _looks[st][0])
	b.add_theme_stylebox_override("pressed", _looks[st][1])
	var note: String = Game.words[k].note.strip_edges()
	b.draw.connect(func():   # drawn, not built out of labels: there are hundreds of these
		var f := b.get_theme_default_font(); var w := b.size.x - 28
		b.draw_string(f, Vector2(20, 40), k, HORIZONTAL_ALIGNMENT_LEFT, w, 28, col.darkened(0.15))
		b.draw_string(f, Vector2(20, 70), _fit(f, note if note != "" else "—", w), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Kit.PAPER_INK if note != "" else Kit.MUTE))
	b.pressed.connect(func():
		Game.sound.emit("tap"); var pg := _page(main, k)
		pg.get_meta("overlay").tree_exited.connect(func():   # back in the list: what you just wrote shows on its card
			if not is_instance_valid(b) or not b.is_inside_tree() or b.is_queued_for_deletion(): return
			(func():
				if not is_instance_valid(b) or not b.is_inside_tree() or b.is_queued_for_deletion(): return
				var g := b.get_parent(); var nb := _tile(main, k); g.add_child(nb); g.move_child(nb, b.get_index()); b.queue_free()).call_deferred()))
	return b


## ---------- grammar: the little pieces you've met, the endings, and the tells you've noticed
static func _grammar(main: Control, inner: VBoxContainer) -> void:
	var gram: Array = Game.words.keys().filter(func(k): return Game.world.words.get(k, {}).get("g", false) and not Game.words[k].ctx.is_empty())
	inner.add_child(Kit.label("PIECES THAT STICK TO WORDS", 14, Kit.MUTE))
	if gram.is_empty(): inner.add_child(Kit.label("The ones you run into collect here.", 18, Kit.MUTE))
	for k in gram: inner.add_child(_row(main, k, Game.world.grammar.get(k, ""), true))
	inner.add_child(Kit.label("ENDINGS", 14, Kit.MUTE))
	for e in Game.world.get("endings", []): inner.add_child(_row(main, e.k, e.d, false))
	var tells: Array = Game.world.tells.keys()
	var caught: Array = tells.filter(func(k): return Game.words.has(k) and not Game.words[k].ctx.is_empty())
	inner.add_child(Kit.label("TELLS · %d of %d noticed" % [caught.size(), tells.size()], 14, Kit.MUTE))
	for k in caught: inner.add_child(_row(main, k, Game.world.tells[k], true))
	if caught.size() < tells.size(): inner.add_child(Kit.label("How people say things can give them away. Listen to the endings.", 18, Kit.MUTE, true))


static func _row(main: Control, k: String, d: String, tap: bool) -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 14)
	var kb := Kit.button(k, false, 24); kb.custom_minimum_size = Vector2(150, 0); kb.disabled = not tap
	if tap: kb.pressed.connect(func(): main.voice.say("{%s}" % k, "word"))
	row.add_child(kb)
	var dl := Kit.label(d, 19, Kit.PAPER_INK, true); dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(dl)
	return row


## ---------- patterns: pages that open as you notice the same change happening to different words
static func _patterns(main: Control, inner: VBoxContainer) -> void:
	var pats: Array = Game.world.get("patterns", [])
	var open: Array = pats.filter(func(p): return Game.pattern_open(p))
	for p in open:
		var b := Kit.wide(p.title, false, 24); b.custom_minimum_size.y = 60; b.pressed.connect(func(): Game.sound.emit("tap"); _pattern(main, p)); inner.add_child(b)
	var left := pats.size() - open.size()
	if left > 0: inner.add_child(Kit.label(("%d more to spot." % left if not open.is_empty() else "Nothing yet.") + " Keep listening to how people say things.", 19, Kit.MUTE, true))


static func _pattern(main: Control, p: Dictionary) -> void:
	var inner := Kit.sheet(main, "패턴", 0.7)
	inner.add_child(Kit.label(p.title, 28, Kit.PAPER_INK, true))
	inner.add_child(Kit.label(p.note, 20, Kit.MUTE, true))
	for pr in p.pairs:
		if p.when.is_empty() and not (Game.words.has(pr[1]) and not Game.words[pr[1]].ctx.is_empty()): continue
		var r := Kit.rich(26); r.text = "%s  [color=#8a7d66]→[/color]  %s" % [Kit.esc(pr[0]), Kit.ko("{%s}" % pr[1]) if Game.world.words.has(pr[1]) else Kit.esc(pr[1])]
		r.meta_clicked.connect(func(y): main._word(str(y))); inner.add_child(r)


## ---------- numbers: Korean has two sets; this page shows both, brighter where you've heard them
static func _numbers(main: Control, inner: VBoxContainer) -> void:
	inner.add_child(Kit.label("Korean has two sets of numbers. Native numbers count hours and things: 아홉 시 = 9 o'clock, 두 개 = two of them. Sino-Korean numbers are for money, minutes and phone numbers: 천 원 = 1,000 won, 삼십 분 = 30 minutes. So 9:30 is 아홉 시 삼십 분.", 19, Kit.PAPER_INK, true))
	for set in [["NATIVE · hours, counting", [["하나 / 한", "1"], ["둘 / 두", "2"], ["셋 / 세", "3"], ["넷 / 네", "4"], ["다섯", "5"], ["여섯", "6"], ["일곱", "7"], ["여덟", "8"], ["아홉", "9"], ["열", "10"], ["열한", "11"], ["열두", "12"]]],
			["SINO-KOREAN · money, minutes, phones", [["공", "0"], ["일", "1"], ["이", "2"], ["삼", "3"], ["사", "4"], ["오", "5"], ["육", "6"], ["칠", "7"], ["팔", "8"], ["구", "9"], ["십", "10"], ["백", "100"], ["천", "1,000"], ["만", "10,000"]]]]:
		inner.add_child(Kit.label(set[0], 14, Kit.MUTE))
		var g := GridContainer.new(); g.columns = 6; g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8); inner.add_child(g)
		for c in set[1]:
			var k: String = c[0].split(" / ")[0]
			var met: bool = Game.words.has(k) and not Game.words[k].ctx.is_empty()
			var b := Kit.button("%s\n%s" % [c[0], c[1]], met, 20); b.alignment = HORIZONTAL_ALIGNMENT_CENTER; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func(): main.voice.say("{%s}" % k, "word")); g.add_child(b)
	inner.add_child(Kit.label("Dark ones are numbers you've heard in the story. Tap any to hear it.", 17, Kit.MUTE, true))


## ---------- misheard: what they said, next to what you thought you heard
static func _misheard(main: Control, inner: VBoxContainer) -> void:
	inner.add_child(Kit.label("When a line is only spoken and you pick a word that sounds almost the same, the pair is kept here. Tap each to hear the difference.", 18, Kit.MUTE, true))
	for key in Game.S.mx:
		var p: PackedStringArray = str(key).split("/")
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); inner.add_child(row)
		for i in 2:
			var w: String = p[i] if i < p.size() else ""
			var b := Kit.button("%s\n%s" % [w, "what they said" if i == 0 else "what you heard"], i == 0, 22); b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.pressed.connect(func(): main.voice.say("{%s}" % w, "word")); row.add_child(b)
			if i == 0: row.add_child(Kit.label("≠", 30, Kit.MUTE))
		if int(Game.S.mx[key]) > 1: row.add_child(Kit.label("×%d" % Game.S.mx[key], 18, Kit.MUTE))


## ---------- key: what the colors mean
static func _key(inner: VBoxContainer) -> void:
	inner.add_child(Kit.label("WORD COLORS", 14, Kit.MUTE))
	for row in [["new", "새", "New: the first time you've run into this word."], ["seen", "새", "No note yet: you've seen it before but haven't written what it means."],
			["guess", "새", "Guessing: you wrote what you think it means."], ["sure", "새", "Got it: you ticked \"I'm sure\"."], ["gram", "는", "A grammar piece: a little part that sticks to words. Tap it for an explanation."]]:
		var r := Kit.rich(22); r.text = "[color=#%s][u]%s[/u][/color]   %s" % [Kit.STATUS_COLORS[row[0]], row[1], row[2]]; inner.add_child(r)
	inner.add_child(Kit.label("ON THE CASE BOARD", 14, Kit.MUTE))
	for t in ["Pink notes are your questions: they go up by themselves. Tie the things that answer one to it; nobody tells you when it's right, you'll notice.",
			"Photos you take are captioned only with where and when. Whether one matters is for you to work out.",
			"Taking a string down frays it; a frayed one snaps next time. A tack you pull out is bent."]:
		inner.add_child(Kit.label("·  " + t, 19, Kit.PAPER_INK, true))


static func _page(main: Control, w: String) -> VBoxContainer:
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
		_seen_in(inner, w, r); return inner
	inner.add_child(Kit.label("What you think it means", 16, Kit.MUTE))
	var note := LineEdit.new(); note.text = r.note; note.placeholder_text = "Your own words"; note.add_theme_font_size_override("font_size", 24)
	note.custom_minimum_size.y = 56
	var ns := Kit.box(10, Kit.PAPER_LIGHT, Kit.LINE, 2, 8); ns.content_margin_left = 14
	var nf := ns.duplicate(); nf.border_color = Kit.PAPER_INK
	note.add_theme_stylebox_override("normal", ns); note.add_theme_stylebox_override("focus", nf)
	note.add_theme_color_override("font_color", Kit.PAPER_INK); note.add_theme_color_override("font_placeholder_color", Kit.MUTE); note.add_theme_color_override("caret_color", Kit.PAPER_INK)
	inner.add_child(note)
	var sure := CheckBox.new(); sure.text = "I'm sure about this"; sure.button_pressed = r.sure; sure.disabled = r.note.strip_edges() == ""
	sure.add_theme_font_size_override("font_size", 20); sure.custom_minimum_size.y = 56
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
	return inner


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
