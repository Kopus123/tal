extends RefCounted
## 사건, the case board. Three lists: deductions (sentences with blanks to fill from words you've met, and sometimes
## proof to pin), evidence, and statements. A deduction is checked as a whole: when it's wrong you only learn that
## something doesn't follow (after two tries, which part).

static var fills := {}      ## deduction id -> the words you've put in so far
static var proofs := {}     ## deduction id -> the proof you've pinned
static var tries := {}
static var tab := "ded"


static func open(main: Control) -> void:
	var inner := Kit.sheet(main, "사건 · the case board", 0.86)
	_draw(main, inner, "")


static func _draw(main: Control, inner: VBoxContainer, open_id: String, miss := "") -> void:
	Kit.clear(inner)
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); inner.add_child(tabs)
	for t in [["ded", "Deductions"], ["ev", "Evidence · %d" % Game.owned().size()], ["st", "Statements · %d" % Game.owned_statements().size()]]:
		var b := Kit.button(t[1], tab == t[0], 18); b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(func(): tab = t[0]; Game.sound.emit("tap"); _draw(main, inner, ""))
		tabs.add_child(b)
	if tab == "ev":
		for e in Game.owned():
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); inner.add_child(row)
			var pic := TextureRect.new(); pic.texture = Kit.icon("#" + e.icon); pic.custom_minimum_size = Vector2(72, 72); pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; row.add_child(pic)
			var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(v)
			var t := Kit.rich(24); t.text = "[b]%s[/b]" % Kit.ko(e.label); t.meta_clicked.connect(func(w): main._word(str(w))); v.add_child(t)
			v.add_child(Kit.label(e.desc, 18, Kit.MUTE, true))
			if e.ko != "":
				var k := Kit.rich(22); k.text = Kit.ko(e.ko); k.meta_clicked.connect(func(w): main._word(str(w))); v.add_child(k)
		if Game.owned().is_empty(): inner.add_child(Kit.label("Nothing yet.", 20, Kit.MUTE))
		return
	if tab == "st":
		for x in Game.owned_statements():
			var nd: Dictionary = Game.ST.nodes[x.node]
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); inner.add_child(row)
			var f := TextureRect.new(); f.texture = Kit.face(nd.who, nd.get("ex", "neutral")); f.custom_minimum_size = Vector2(72, 72); f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; row.add_child(f)
			var t := Kit.rich(24); t.text = Kit.ko(nd.ko); t.meta_clicked.connect(func(w): main._word(str(w))); row.add_child(t)
			var hb := Kit.button("▶", false, 18); hb.pressed.connect(func(): main.voice.say(nd.ko, nd.who)); row.add_child(hb)
		if Game.owned_statements().is_empty(): inner.add_child(Kit.label("Nothing yet. Some things people say get saved here.", 20, Kit.MUTE, true))
		return
	var open_cases: Array = Game.cases_open()
	if open_cases.is_empty(): inner.add_child(Kit.label("Nothing to work out yet. Look around.", 20, Kit.MUTE)); return
	for q in open_cases:
		var solved: bool = Game.S.cs.has(q.id)
		if q.id != open_id:
			var t := Kit.rich(22, Kit.MUTE if solved else Kit.PAPER_INK)
			t.text = ("✓ " if solved else "? ") + _sentence(q, true)
			var b := Kit.button("", false); b.custom_minimum_size.y = 64; b.add_child(t)
			t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); t.offset_left = 14; t.offset_top = 10; t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if solved:
				var why := Kit.label(q.why, 17, Kit.MUTE, true); inner.add_child(b); inner.add_child(why); b.disabled = true
			else:
				b.pressed.connect(func(): Game.sound.emit("tap"); _draw(main, inner, q.id)); inner.add_child(b)
			continue
		_editor(main, inner, q, miss)


## the sentence, with what you've filled in (or the blanks)
static func _sentence(q: Dictionary, solved_or_list: bool) -> String:
	var f: Array = fills.get(q.id, [])
	var i := -1
	var out := Story.R("\\{([^}|]+)(?:\\|([^}]+))?\\}").sub(q.text, "\u0001", true)
	var parts := out.split("\u0001")
	var s := Kit.esc(parts[0])
	for k in range(1, parts.size()):
		i += 1
		var word: String = q.blanks[i] if Game.S.cs.has(q.id) else (f[i] if i < f.size() and f[i] != "" else "____")
		s += "[b][u]%s[/u][/b]" % word + Kit.esc(parts[k])
	return s


static func _editor(main: Control, inner: VBoxContainer, q: Dictionary, miss: String) -> void:
	var f: Array = fills.get(q.id, []); fills[q.id] = f
	while f.size() < q.blanks.size(): f.append("")
	var p: Array = proofs.get(q.id, []); proofs[q.id] = p
	while p.size() < q.needs.size(): p.append("")
	inner.add_child(Kit.label("FILL IN THE BLANKS", 14, Kit.MUTE))
	var slots := HFlowContainer.new(); slots.add_theme_constant_override("h_separation", 8); inner.add_child(slots)
	var s := Kit.rich(26); s.text = _sentence(q, false); inner.add_child(s)
	var act: int = f.find("")
	if act < 0: act = 0
	for i in q.blanks.size():
		var meaning: String = Game.world.meanings.get(q.blanks[i].split("/")[0], "?")
		var b := Kit.button("%d. %s" % [i + 1, f[i] if f[i] != "" else "(%s)" % meaning], f[i] == "", 20)
		b.pressed.connect(func(): f[i] = ""; _draw(main, inner, q.id)); slots.add_child(b)
	inner.add_child(Kit.label("Tap a word to put it in the next blank (tap a filled blank to empty it):", 16, Kit.MUTE, true))
	var pick := HFlowContainer.new(); pick.add_theme_constant_override("h_separation", 8); pick.add_theme_constant_override("v_separation", 8); inner.add_child(pick)
	for w in _shortlist(q):
		var b := Kit.button(w, false, 24)
		b.pressed.connect(func():
			var at: int = f.find("")
			if at < 0: return
			f[at] = w; Game.sound.emit("tap"); _draw(main, inner, q.id))
		pick.add_child(b)
	for i in q.needs.size():
		inner.add_child(Kit.label("PROOF %d: %s" % [i + 1, q.needs[i].hint], 14, Kit.MUTE))
		var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 8); inner.add_child(row)
		for id in _proof_options(q):
			var label := _proof_label(id)
			var b := Kit.button(label, p[i] == id, 17)
			b.pressed.connect(func():
				var other: int = p.find(id)
				if other >= 0 and other != i: p[other] = ""
				p[i] = id if p[i] != id else ""; Game.sound.emit("tap"); _draw(main, inner, q.id))
			row.add_child(b)
	if miss != "": inner.add_child(Kit.label(miss, 20, Color("b5412d"), true))
	var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 8); inner.add_child(row2)
	var clr := Kit.button("Clear"); clr.alignment = HORIZONTAL_ALIGNMENT_CENTER; clr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clr.pressed.connect(func(): fills.erase(q.id); proofs.erase(q.id); _draw(main, inner, q.id)); row2.add_child(clr)
	var chk := Kit.button("Check", true); chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chk.disabled = f.has("") or p.has("")
	chk.pressed.connect(func():
		var r: String = Game.solve(q.id, f, p)
		if r == "":
			fills.erase(q.id); proofs.erase(q.id); tries.erase(q.id)
			if q.final: Kit.close(inner); return
			_draw(main, inner, ""); return
		tries[q.id] = tries.get(q.id, 0) + 1
		var m := "Something doesn't follow."
		if tries[q.id] >= 2 and not q.needs.is_empty():
			m = {"words": "The proof is right. A word is off.", "proof": "The words fit. The proof doesn't.", "both": "Neither the words nor the proof fit yet."}[r]
		_draw(main, inner, q.id, m))
	row2.add_child(chk)
	var back := Kit.button("‹ All deductions"); back.pressed.connect(func(): _draw(main, inner, "")); inner.add_child(back)


## about ten words to choose from: this card's blanks first, then a few blanks from other cards, then words you've met
static func _shortlist(q: Dictionary) -> Array:
	var pool := []
	for b in q.blanks:
		var w: String = b.split("/")[0]
		if not w in pool: pool.append(w)
	var others := []
	for c in Game.cases_open():
		if c == q or Game.S.cs.has(c.id): continue
		for b in c.blanks:
			if not b in pool and not b in others: others.append(b)
	var met: Array = Game.words.keys().filter(func(k): return not Game.words[k].ctx.is_empty() and Game.world.words.has(k) and not Game.world.words[k].get("g", false) and not k in pool and not k in others)
	others.shuffle(); met.shuffle()
	pool.append_array(others.slice(0, maxi(0, 8 - pool.size())))
	pool.append_array(met.slice(0, maxi(0, 10 - pool.size())))
	seed(hash(q.id)); pool.shuffle(); randomize()   # the same order each time you open this card
	return pool


static func _proof_options(q: Dictionary) -> Array:
	var have := []
	for e in Game.owned(): have.append(e.id)
	for x in Game.owned_statements(): have.append(x.id)
	var need := []; var flat := []
	for n in q.needs:
		flat.append_array(n.alts)
		for a in n.alts:
			if a in have and not a in need: need.append(a); break
	var extra: Array = have.filter(func(x): return not x in flat)
	extra.shuffle()
	var opts: Array = need + extra.slice(0, maxi(2, 4 - need.size()))
	opts.shuffle()
	return opts


static func _proof_label(id: String) -> String:
	if Game.ST.evidence.has(id): return "📄 " + Game.plain(Game.ST.evidence[id].label)
	var st: Dictionary = Game.ST.statements.get(id, {})
	if not st.is_empty():
		var nd: Dictionary = Game.ST.nodes[st.node]
		return "💬 %s: %s" % [Game.ST.cast.get(nd.who, {}).get("n", ""), Game.plain(nd.ko).left(22) + "…"]
	return id
