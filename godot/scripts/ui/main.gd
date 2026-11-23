extends Control
## The screen. Sideways: the picture on the left (room.gd), the paper on the right.
## The paper shows whatever the story is doing: someone talking (their face, the Korean line, what they do, your choices),
## a puzzle (sentence tiles, typing, showing evidence, two things that clash, a close-up, the camera, a number), or,
## when nothing is happening, the place's description, your pockets and the clock.
## Pop-ups live in their own files: board.gd (case board), phone.gd, notebook.gd, places.gd (map, notice board, chapters).
##   godot --path godot -- --shots OUT_DIR     screenshot tour (scripts/tools/shot_tour.gd)

const BUILD := "4.10"   ## MAJOR.FIXES: the major number goes up for a big new part of the game (1 shed, 2 whole game, 3 case board); the decimal for each fix update

var room: Control
var paper: PanelContainer
var title_ko: Label
var title_en: Label
var clock_btn: Button
var bar_btns: Dictionary = {}
var body: VBoxContainer
var acts: VBoxContainer
var pockets_box: HFlowContainer
var pocket_hint: Label
var foot: HBoxContainer
var toast_box: VBoxContainer
var card: Control
var tour: RefCounted
var kb: Control                      ## the Korean keyboard while a typed answer is open
var _build_seq: Array = []           ## sentence tiles picked so far
var _picks: Array = []               ## contradictions: the two you picked
var _numpad := ""
var _reply: Array = []               ## small talk while typing: [ko, en]
var _shown_node := ""
var voice := Voice.new()
var scape: Node                      ## the place's music and background sound
var cork: Control                    ## the case board lab
var card_sel := ""
var busy := false                    ## your own line is playing: wait for it


func _ready() -> void:
	RenderingServer.set_default_clear_color(Kit.INK)
	add_child(voice)
	_build()
	Game.changed.connect(_refresh)
	Game.sound.connect(_play)
	Game.toast.connect(_toast)
	Game.rewound.connect(_rewound)
	Game.timecard.connect(_timecard)
	Game.finished.connect(_finished)
	Game.reply.connect(func(k, e): _reply = [k, e]; voice.say(k, Game.beat().get("to", "sign")); _refresh())
	var args := OS.get_cmdline_user_args()
	scape = load("res://scripts/ui/scape.gd").new(); add_child(scape)
	if "--shots" in args:
		AudioServer.set_bus_mute(0, true)   # screenshot tours run silently
		var i := args.find("--shots")
		tour = load("res://scripts/tools/shot_tour.gd").new()   # kept here: a tour nobody holds on to is freed mid-way
		tour.run(self, args[i + 1] if i + 1 < args.size() else "user://shots", args[i + 2] if i + 2 < args.size() else "shed", args[i + 3] if i + 3 < args.size() else "")
		return
	_title()


## ---------- layout
func _build() -> void:
	var bg := ColorRect.new(); bg.color = Kit.INK; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var row := HBoxContainer.new(); row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); row.add_theme_constant_override("separation", 14)
	row.offset_left = 14; row.offset_top = 12; row.offset_right = -14; row.offset_bottom = -12
	add_child(row)
	var arc := AspectRatioContainer.new(); arc.ratio = 4.0 / 3.0; arc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; arc.size_flags_stretch_ratio = 2.2
	row.add_child(arc)
	room = load("res://scripts/ui/room.gd").new(); arc.add_child(room)
	room.wants.connect(func(w): _open("jobs" if w == "board" else w))
	room.overheard.connect(_overheard)
	card = _card(); room.add_child(card)
	cork = load("res://scripts/ui/cork.gd").new(); cork.visible = false; arc.add_child(cork)
	cork.selected.connect(func(id): card_sel = id; _refresh())
	cork.box_open.connect(_box)
	clock_btn = Kit.button("", true, 18); clock_btn.position = Vector2(12, 12); clock_btn.pressed.connect(_day_panel); room.add_child(clock_btn)

	paper = PanelContainer.new(); paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL; paper.custom_minimum_size.x = 400
	var ps := Kit.box(18, Kit.PAPER, Color.TRANSPARENT, 0, 18); ps.content_margin_left = 22; ps.content_margin_right = 22
	paper.add_theme_stylebox_override("panel", ps); row.add_child(paper)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 10); paper.add_child(col)

	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 6); col.add_child(head)
	var names := VBoxContainer.new(); names.size_flags_horizontal = Control.SIZE_EXPAND_FILL; names.add_theme_constant_override("separation", -4); head.add_child(names)
	title_ko = Kit.label("", 28); names.add_child(title_ko)
	title_en = Kit.label("", 14, Kit.MUTE); title_en.clip_text = true; names.add_child(title_en)
	for k in [["note", "수첩"], ["board", "사건"], ["phone", "폰"], ["map", "지도"], ["menu", "☰"]]:
		var b := Kit.button(k[1], true, 17); b.custom_minimum_size = Vector2(52, 52); b.alignment = HORIZONTAL_ALIGNMENT_CENTER; head.add_child(b); bar_btns[k[0]] = b
	bar_btns.note.pressed.connect(func(): _open("notebook"))
	bar_btns.board.pressed.connect(func(): _open("board"))
	bar_btns.phone.pressed.connect(func(): _open("phone"))
	bar_btns.map.pressed.connect(func(): _open("map"))
	bar_btns.menu.pressed.connect(_menu)

	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 24   # a tap that wobbles a little is still a tap, not a scroll
	col.add_child(scroll)
	var inner := VBoxContainer.new(); inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL; inner.add_theme_constant_override("separation", 12); scroll.add_child(inner)
	body = VBoxContainer.new(); body.add_theme_constant_override("separation", 8); inner.add_child(body)
	acts = VBoxContainer.new(); acts.add_theme_constant_override("separation", 8); inner.add_child(acts)
	var pk := VBoxContainer.new(); pk.add_theme_constant_override("separation", 6); col.add_child(pk)
	pockets_box = HFlowContainer.new(); pockets_box.add_theme_constant_override("h_separation", 8); pk.add_child(pockets_box)
	pocket_hint = Kit.label("", 15, Kit.MUTE, true); pk.add_child(pocket_hint)
	foot = HBoxContainer.new(); foot.add_theme_constant_override("separation", 8); col.add_child(foot)
	var bl := Kit.label("build %s" % BUILD, 12, Color(1, 1, 1, 0.25)); bl.anchor_top = 1; bl.anchor_bottom = 1; bl.offset_top = -18; bl.offset_left = 16; add_child(bl)
	toast_box = VBoxContainer.new(); toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP); toast_box.position.y = 20; toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH; add_child(toast_box)


## ---------- what's on the paper
func _refresh() -> void:
	if Game.ST.is_empty(): return
	var pl: Dictionary = Game.place()
	var b: Dictionary = Game.beat()
	title_ko.text = pl.get("name", ""); title_en.text = pl.get("sub", "").to_upper()
	bar_btns.phone.visible = Game.has_phone()
	bar_btns.board.visible = not Game.ST.cases.is_empty() or not Game.owned().is_empty()
	bar_btns.map.visible = b.is_empty() and pl.get("travel", "") != "no" and Game.S.known.size() > 1
	clock_btn.visible = Game.S.F.has("started") and pl.get("mode", "") != "explore"
	clock_btn.text = "%d일째 · %s   %s" % [Game.W.day, Game.SLOT_KO[Game.slot_name()], Game.won(Game.W.money)]
	Kit.clear(body); Kit.clear(acts); Kit.clear(foot)
	var t: String = b.get("type", "")
	card.visible = t == "card"
	if kb and (t != "type" or Game.node != _shown_node): kb.queue_free(); kb = null
	if Game.node != _shown_node:
		_build_seq = []; _picks = []; _numpad = ""; _reply = []
		if b.has("ko") and not b.get("audio", false) and b.who != "narr" and Settings.get_("auto") == 1: voice.say(b.ko, b.who)
		elif b.get("audio", false): voice.say(b.ko, b.who)
	_shown_node = Game.node
	if scape: scape.update(pl)
	var lab: bool = pl.get("mode", "") == "board" or board_view
	cork.visible = lab; room.visible = not lab
	if lab: cork.refresh()
	if lab and (b.is_empty() or board_view): _lab()
	elif b.is_empty(): _looking()
	elif t == "card":
		card.get_node("T").text = b.title; card.get_node("S").text = b.get("sub", "")
		_text("[color=#8a7d66]Sound on. Tap any underlined word to open its page in your notebook.[/color]"); _cont("Begin")
	elif t == "number": _number(b)
	elif t == "build": _build_beat(b)
	elif t == "type": _type_beat(b)
	elif t == "present": _present_beat(b)
	elif t == "contradict": _contradict_beat(b)
	elif t == "examine": _examine_beat()
	elif t == "camera": _text(Kit.esc(b.en)); _act("Take the photo", func(): room.shoot(b), true)
	elif t == "photo":
		var pic := TextureRect.new(); pic.texture = load("res://art/photo.png"); pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pic.custom_minimum_size = Vector2(0, 260); body.add_child(pic)
		_text(Kit.esc(b.en)); _cont("Continue")
	else: _say_beat(b)
	_pockets(b.is_empty())
	room.refresh()


func _text(bb: String, sz := 24, c: Color = Kit.PAPER_INK) -> RichTextLabel:
	var r := Kit.rich(sz, c); r.text = bb; r.meta_clicked.connect(func(w): _word(str(w))); body.add_child(r); return r


func _act(t: String, f: Callable, dark := false) -> Button:
	var b := Kit.wide(t, dark); b.pressed.connect(f); acts.add_child(b); return b


func _cont(t: String) -> void:
	_act(t, func(): Game.sound.emit("tap"); Game.next(), true)


## nothing happening: where you are, and (free days) who's here, the clock
## voices from somewhere you can't see (a 3D place): the last few lines, as much of each as you caught
var _heard: Array = []
func _overheard(who: String, ko: String, clear: float) -> void:
	if clear <= 0.0: _heard.append({"t": "(voices, too far away to make out)"})
	else:
		var ms: Array = Story.R("\\{[^}]+\\}").search_all(ko); var keep := int(ceil(ms.size() * clear))
		var shown := ko
		if clear < 1.0:   # the words you missed become … (which ones depends on the line, so it's the same each time)
			var idx: Array = range(ms.size()); var rng := RandomNumberGenerator.new(); rng.seed = hash(ko)
			for i in range(idx.size() - 1, 0, -1):
				var j := rng.randi_range(0, i); var t = idx[i]; idx[i] = idx[j]; idx[j] = t
			var drop: Array = idx.slice(keep)
			shown = ""; var at := 0
			for i in ms.size():
				shown += ko.substr(at, ms[i].get_start() - at) + ("…" if i in drop else ms[i].get_string())
				at = ms[i].get_end()
			shown += ko.substr(at)
		else: Game._met(ko)
		_heard.append({"t": shown, "who": who})
	if _heard.size() > 5: _heard.pop_front()
	_refresh()


func _looking() -> void:
	_text(Kit.esc(Game.desc()))
	if room.set3 and not _heard.is_empty():
		_text("[color=#8a7d66]OVERHEARD[/color]", 15)
		for h in _heard:
			if h.has("who"): _text(Kit.ko(h.t), 24)
			else: _text("[color=#8a7d66]" + Kit.esc(h.t) + "[/color]", 18)
	if Game.ST.free and not Game.W.frozen:
		for p in Game.people_here():
			_act("Talk to " + Game.ST.cast.get(p.id, {}).get("n", p.id), func(): Game.talk_to(p.id))
		var home: bool = Game.S.loc == Game.ST.meta.get("home", "")
		if home and Game.W.slot >= 2: _foot("Go to bed", func(): Game.sound.emit("page"); Game.next_morning(); _refresh())
		if Game.W.slot < 3: _foot("Wait a while", func(): Game.sound.emit("page"); Game.pass_time())


func _foot(t: String, f: Callable) -> void:
	var b := Kit.button(t, false, 18); b.alignment = HORIZONTAL_ALIGNMENT_CENTER; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.pressed.connect(f); foot.add_child(b)


## the case board lab: the card you're looking at, big, and what you can do with it; leaving is one button away
var lab_go := false
var board_view := false
var _en_open := ""         ## a line whose folded-away English you asked to see   ## the case board, opened from the top bar (in the chapters)
func _lab() -> void:
	var bd: Dictionary = Game.board()
	if lab_go:
		_text("Where to?", 24, Kit.MUTE)
		for s in Game.spots_now():
			if s.kind == "=>": _act(s.l, func(): lab_go = false; Game.tap_spot(s))
		_act("◂ Back to the board", func(): lab_go = false; _refresh())
		return
	var id: String = card_sel
	if id != "" and not Game.card(id).is_empty():
		var cd: Dictionary = Game.card(id)
		var ko: String = cd.get("ko", "")
		match cd.kind:
			"thing": ko = cd.label + ("\n" + cd.ko if cd.ko != "" else "")
			"person": ko = Game.ST.cast.get(cd.who, {}).get("n", cd.who) + ("\n실종 · missing" if cd.get("missing", false) else "")
			"say": ko = Game.ST.cast.get(cd.who, {}).get("n", cd.who) + ":\n" + cd.ko
			"photo": ko = "사진 · photo\n" + cd.ko
		var r := Kit.rich(28); r.text = Kit.ko(ko); r.meta_clicked.connect(func(w): _word(str(w))); body.add_child(r)
		if cd.kind == "note" and cd.get("en", "") != "": body.add_child(Kit.label("(your note: " + cd.en + ")", 20, Kit.MUTE, true))
		if cd.kind == "say":
			var hb := Kit.button("▶ Hear it", false, 20); hb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; hb.pressed.connect(func(): voice.say(cd.ko, cd.who)); body.add_child(hb)
		var pinned: bool = Game.is_pinned(id)
		if not pinned:
			_text("Loose: not pinned up yet.", 20, Kit.MUTE)
			var pb := _act("📌  Pin it up  (a thumbtack: %d left)" % bd.tacks, func(): _lab_pin(id), true)
			pb.disabled = bd.tacks <= 0
			if bd.tacks <= 0: _text("Out of thumbtacks. The shop sells them.", 20, Kit.MUTE)
		elif cork.from == "":
			var sb := _act("🧵  Pick up a string from here  (%d left)" % bd.strings, func(): cork.carry(id), true)
			sb.disabled = bd.strings <= 0
		elif cork.from != id:
			_act("🧵  Tie the string here", func(): cork.tie(id), true)
			_act("Put the string down", func(): cork.drop())
		else: _act("Put the string down", func(): cork.drop())
		if cork.from != "" and cork.from != id and not pinned: _text("Pin it up first, then you can tie string to it.", 20, Kit.MUTE)
		for l in bd.links:   # its strings, each with a way to take it down
			if not id in [l[0], l[1]]: continue
			var other: String = l[1] if l[0] == id else l[0]
			var worn: bool = l.size() > 2 and l[2]
			var a: String = l[0]; var b: String = l[1]
			_act("✂  Take down the string to %s%s" % [Game.card_label(Game.card(other)), "  (frayed: it'll snap)" if worn else ""], func(): Game.board_unlink(a, b))
		if pinned and cork.from == "": _act("Pull the thumbtack out", func(): Game.board_unpin(id))
		if cork.from == "": _act("📦  Put it in the box", func(): card_sel = ""; cork.sel = ""; Game.board_box(id); cork.refresh(); _refresh())
	else:
		_text(Kit.esc(Game.desc()), 22)
		if cork.from != "": _act("Put the string down", func(): cork.drop())
	var worn_n: int = bd.get("frayed", 0)
	_text("🧵 String: %d%s   ·   📌 Thumbtacks: %d   ·   %s" % [bd.strings, " (%d frayed)" % worn_n if worn_n > 0 else "", bd.tacks, Game.won(Game.W.money)], 20, Kit.MUTE)
	if board_view: _act("Close the board ▸", func(): board_view = false; card_sel = ""; _refresh())
	else: _act("Leave the board ▸", func(): lab_go = true; _refresh())
	if id != "" and not Game.card(id).is_empty():   # the card itself, bigger; tap it to see it full screen
		var pv: Control = cork.preview(id, 300.0); pv.mouse_filter = Control.MOUSE_FILTER_STOP; acts.add_child(pv)
		pv.gui_input.connect(func(e): if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed: card_big(id))
		acts.add_child(Kit.label("(tap the card to see it bigger)", 16, Kit.MUTE))


## a card over the whole screen; tap anywhere (or ✕) to put it back
func card_big(id: String) -> void:
	Game.sound.emit("tap")
	var o := ColorRect.new(); o.color = Color(0, 0, 0, 0.82); o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(o)
	var c: Control = cork._make(id); c.set_meta("preview", true); c.rotation_degrees = 0
	var k := minf(size.x * 0.9 / c.size.x, size.y * 0.88 / c.size.y)
	c.scale = Vector2(k, k); cork.crisp(c, k); c.position = (size - c.size * k) / 2; o.add_child(c)
	var x := Kit.button("✕", true, 28); x.custom_minimum_size = Vector2(72, 72); o.add_child(x)
	x.position = Vector2(size.x - 92, 20)
	x.pressed.connect(func(): o.queue_free())
	o.gui_input.connect(func(e): if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed: Game.sound.emit("tap"); o.queue_free())


## the evidence box: everything you've taken down, and everything new. Put any of it back up.
func _box() -> void:
	var inner := Kit.sheet(self, "증거 상자 · Evidence box", 0.7)
	var ids: Array = Game.boxed()
	if ids.is_empty(): inner.add_child(Kit.label("Empty. Drag a card onto the box to put it away.", 20, Kit.MUTE, true))
	for id in ids:
		var cd: Dictionary = Game.card(id)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 14); inner.add_child(row)
		var pic := TextureRect.new(); pic.texture = cork._picture(cd); pic.custom_minimum_size = Vector2(110, 84)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; row.add_child(pic)
		var l := Kit.label(("● " if Game.board().cards[id].get("new", false) else "") + Game.card_label(cd), 20, Kit.PAPER_INK, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		var b := Kit.button("Put it up", true, 18); row.add_child(b)
		b.pressed.connect(func(): Game.board_unbox(id); cork.refresh(); Kit.close(inner); _box())
	Game.box_seen(); cork.refresh()


func _lab_pin(id: String) -> void:
	var r: String = Game.board_pin(id)
	if r == "no tacks": Game.toast.emit("You're out of thumbtacks. The shop sells them.")
	cork.refresh(); _refresh()


## someone talks (or the narration, or a sign)
func _say_beat(b: Dictionary) -> void:
	var who: String = b.get("who", "narr")
	if who == "narr": _text(Kit.esc(b.get("en", "")))
	elif who == "sign":
		var r := _text("[center][bgcolor=#e2d6b8][font_size=36] %s [/font_size][/bgcolor][/center]" % Kit.ko(b.ko))
		r.add_theme_font_size_override("normal_font_size", 36)
		_hear(b)
		if b.has("en"): _text(Kit.esc(b.en), 19, Kit.MUTE)
	else:
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 14); body.add_child(line)
		var side := VBoxContainer.new(); side.add_theme_constant_override("separation", 2); line.add_child(side)
		var f := TextureRect.new(); f.texture = Kit.face(who, b.get("ex", "neutral")); f.custom_minimum_size = Vector2(110, 110)
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; side.add_child(f)
		var c: Dictionary = Game.ST.cast.get(who, {})
		var nm := Kit.label(c.get("n", ""), 16, Color(c.get("c", "#888"))); nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; side.add_child(nm)
		var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(right)
		if b.get("audio", false):
			right.add_child(Kit.label("You only hear this. It gets written down once you act on it.", 17, Kit.MUTE, true))
		else:
			var r := Kit.rich(30); r.text = Kit.ko(b.ko); r.meta_clicked.connect(func(w): _word(str(w))); right.add_child(r)
		var again := Kit.button("▶ Again", false, 16); again.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		again.pressed.connect(func(): voice.say(b.ko, who)); right.add_child(again)
		if b.has("en"):
			if b.get("audio", false) or _en_open == b.id or not Game.line_known(b.ko): _text(Kit.esc(b.en), 19, Kit.MUTE)
			else:   # you know every word: the Korean is enough
				var sh := Kit.button("show what they do", false, 15); sh.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				sh.pressed.connect(func(): _en_open = b.id; _refresh()); body.add_child(sh)
	var shown := 0
	for o in b.get("ch", []):
		if not Game.cond(o.c): continue
		shown += 1
		var t: String = ("“%s”" % Game.plain(o.ko)) if o.has("ko") else o.get("en", "")
		_act(t, func():
			if busy: return
			if o.has("ko"):
				busy = true; voice.say_then(o.ko, "you", func(): busy = false; Game.choose(o))
			else: Game.choose(o))
	if shown == 0: _cont("Continue" if (b.has("next") or b.has("rewind")) else "Look around")


func _hear(b: Dictionary) -> void:
	var h := Kit.button("▶ Read aloud", false, 16); h.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; h.pressed.connect(func(): voice.say(b.ko, b.who)); body.add_child(h)


## ---------- puzzles
func _number(b: Dictionary) -> void:
	_text(Kit.esc(b.en))
	if b.kind == "count":
		var lock = load("res://scripts/ui/lock.gd").new()
		lock.setup(len(Game._digits(b.ans[0][0])) if not b.ans.is_empty() else 4)
		lock.tried.connect(func(v): Game.answer(v))
		room.add_child(lock); return
	var shown: String = _numpad if _numpad != "" else {"time": "_ : _ _", "won": "0 원", "phone": "010-____-____"}.get(b.kind, "_")
	if _numpad != "":
		if b.kind == "time" and _numpad.length() > 2: shown = _numpad.substr(0, _numpad.length() - 2) + ":" + _numpad.right(2)
		elif b.kind == "won": shown = Game.won(int(_numpad))
	var d := Kit.label(shown, 44); d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; body.add_child(d)
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8); acts.add_child(grid)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "✓"]:
		var btn := Kit.button(k if k != "✓" else ("Pay" if b.kind == "won" else "Say it"), k == "✓", 26)
		btn.custom_minimum_size = Vector2(0, 58); btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = k == "✓" and _numpad == ""
		btn.pressed.connect(func():
			Game.sound.emit("tap")
			if k == "✓": Game.answer(_numpad); return
			if k == "⌫": _numpad = _numpad.left(-1)
			elif _numpad.length() < 11: _numpad += k
			_refresh())
		grid.add_child(btn)
	_leave_btn()


func _leave_btn() -> void:
	var l := Kit.button("Never mind", false, 18); l.alignment = HORIZONTAL_ALIGNMENT_CENTER; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.pressed.connect(func(): Game.leave()); foot.add_child(l)


func _build_beat(b: Dictionary) -> void:
	_text(Kit.esc(b.en))
	var line := " ".join(_build_seq.map(func(i): return Game.plain(b.tiles[i]))) if not b.join else "".join(_build_seq.map(func(i): return Game.plain(b.tiles[i])))
	var shown := Kit.label(line if line != "" else ("Tap the pieces to build the word" if b.join else "Tap words to build a sentence"), 30 if line != "" else 18, Kit.PAPER_INK if line != "" else Kit.MUTE, true)
	body.add_child(shown)
	var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 8); flow.add_theme_constant_override("v_separation", 8); acts.add_child(flow)
	for i in b.tiles.size():
		var t := Kit.button(Game.plain(b.tiles[i]), false, 26); t.disabled = i in _build_seq
		t.pressed.connect(func():
			Game.sound.emit("tap"); _build_seq.append(i)
			if not b.join: voice.say(b.tiles[i], "you")
			_refresh())
		flow.add_child(t)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); acts.add_child(row)
	var clr := Kit.button("Clear"); clr.alignment = HORIZONTAL_ALIGNMENT_CENTER; clr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clr.pressed.connect(func(): _build_seq = []; _refresh()); row.add_child(clr)
	var say := Kit.button("Say it", true); say.size_flags_horizontal = Control.SIZE_EXPAND_FILL; say.disabled = _build_seq.is_empty()
	say.pressed.connect(func():
		var seq: Array = _build_seq.map(func(i): return b.tiles[i])
		if busy: return
		busy = true; voice.say_then(" ".join(seq) if not b.join else "".join(seq), "you", func(): busy = false; Game.answer_build(seq)))
	row.add_child(say)
	_leave_btn()


## what you typed against what was right: the letters that line up stay plain; yours that don't are struck in red,
## and the ones you missed are marked green (spaces and punctuation don't count)
static func _diff(yours: String, right: String) -> Array:
	var skip := func(c: String) -> bool: return " .?!~,·…".contains(c)
	var u: Array = []; for c in yours: if not skip.call(c): u.append(c)
	var ci: Array = []; for i in right.length(): if not skip.call(right[i]): ci.append(i)
	var cc: Array = ci.map(func(i): return right[i])
	var L: Array = []
	for i in u.size() + 1:
		var row: Array = []; row.resize(cc.size() + 1); row.fill(0); L.append(row)
	for i in range(u.size() - 1, -1, -1):
		for j in range(cc.size() - 1, -1, -1):
			L[i][j] = L[i + 1][j + 1] + 1 if u[i] == cc[j] else maxi(L[i + 1][j], L[i][j + 1])
	var ok_u := {}; var ok_c := {}; var a := 0; var b := 0
	while a < u.size() and b < cc.size():
		if u[a] == cc[b]: ok_u[a] = 1; ok_c[b] = 1; a += 1; b += 1
		elif L[a + 1][b] >= L[a][b + 1]: a += 1
		else: b += 1
	var y := ""
	for k in u.size(): y += Kit.esc(u[k]) if ok_u.has(k) else "[color=#b3241c][s]%s[/s][/color]" % Kit.esc(u[k])
	var r := ""
	for k in right.length():
		var n: int = ci.find(k)
		r += Kit.esc(right[k]) if n < 0 or ok_c.has(n) else "[bgcolor=#cfe9d6][color=#1f6b3a]%s[/color][/bgcolor]" % Kit.esc(right[k])
	return [y, r]


## typed answers: the game's own Korean keyboard opens over the bottom of the screen
func _type_beat(b: Dictionary) -> void:
	_text(Kit.esc(b.en))
	if not _reply.is_empty():
		_text("[b]%s[/b]" % Kit.ko(_reply[0]), 26); _text(Kit.esc(_reply[1]), 18, Kit.MUTE)
	if not Game.typed_close.is_empty():
		var df := _diff(Game.typed_close.yours, Game.typed_close.correct)
		_text("[color=#8a7d66]Close enough! Watch the marked letters.[/color]\nYou wrote:  %s\nRight:  %s" % [df[0], df[1]], 24)
		_act("Continue", func(): Game.close_go_on(), true); return
	if kb == null:
		kb = load("res://scripts/ui/korean_keyboard.gd").new(); add_child(kb)
		kb.hint_text = Game.plain(b.ans[0][0]) if not b.ans.is_empty() else ""
		kb.submitted.connect(func(t):
			if busy: return
			busy = true; voice.say_then(t, "you", func(): busy = false; Game.answer_type(t)))
		kb.closed.connect(func(): kb = null; Game.leave())


func _cards(items: Array, pick: Callable, picked: Array = []) -> void:
	for e in items:
		var is_st: bool = e.has("node")
		var b := Kit.wide("", e.id in picked, 18); b.custom_minimum_size = Vector2(0, 64)
		if is_st:
			var nd: Dictionary = Game.ST.nodes[e.node]
			b.icon = Kit.face(nd.who, nd.get("ex", "neutral")); b.text = "%s: %s" % [Game.ST.cast.get(nd.who, {}).get("n", ""), Game.plain(nd.ko)]
		else:
			b.icon = Kit.icon("#" + e.icon); b.text = "%s · %s" % [Game.plain(e.label), e.desc]
		b.expand_icon = false; b.add_theme_constant_override("icon_max_width", 48)
		b.pressed.connect(func(): pick.call(e.id)); acts.add_child(b)


func _present_beat(b: Dictionary) -> void:
	_text(Kit.esc(b.en))
	var ev := Game.owned()
	if ev.is_empty(): _text("You have nothing to show.", 20, Kit.MUTE)
	_cards(ev, func(id): Game.sound.emit("tap"); Game.present(id))
	_leave_btn()


func _contradict_beat(b: Dictionary) -> void:
	_text(Kit.esc(b.en))
	var pick := func(id):
		Game.sound.emit("tap")
		if id in _picks: _picks.erase(id)
		else:
			_picks.append(id)
			if _picks.size() > 2: _picks.pop_front()
		_refresh()
	if not Game.owned_statements().is_empty(): acts.add_child(Kit.label("STATEMENTS", 14, Kit.MUTE))
	_cards(Game.owned_statements(), pick, _picks)
	if not Game.owned().is_empty(): acts.add_child(Kit.label("EVIDENCE", 14, Kit.MUTE))
	_cards(Game.owned(), pick, _picks)
	var c := Kit.button("These two can't both be true" if _picks.size() == 2 else "Pick two (%d/2)" % _picks.size(), true)
	c.disabled = _picks.size() != 2; c.pressed.connect(func(): Game.clash(_picks[0], _picks[1])); foot.add_child(c)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leave_btn()


func _examine_beat() -> void:
	var x: Dictionary = Game.exam()
	_text(Kit.esc(x.get("prompt", "Look closely. Tap anything that catches your eye.")) + " [b]Tap the picture.[/b]")
	var found: Array = x.details.filter(func(d): return Game.exam_found(d))
	_text("Noticed %d of %d" % [found.size(), x.details.size()], 17, Kit.MUTE)
	for i in range(found.size() - 1, -1, -1): _text("· " + Kit.ko(found[i].t), 21)
	var left: int = Game.exam_keys_left()
	var d := _act("Keep looking" if left else "Done looking", func(): Game.next(), true); d.disabled = left > 0


## ---------- pockets (exploring)
func _pockets(free: bool) -> void:
	Kit.clear(pockets_box)
	var items: Array = Game.pockets()
	pockets_box.get_parent().visible = free and not items.is_empty()
	for e in items:
		var on: bool = bool(Game.F.get("lit", 0)) if e.id == "flashlight" else Game.F.get("hold", "") == e.id
		var b := Button.new(); b.custom_minimum_size = Vector2(108, 108); b.icon = Kit.icon("#" + e.icon); b.expand_icon = true
		b.text = Game.plain(e.label); b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP; b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 15 if b.text.length() > 6 else 18); b.clip_text = true
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(c, Kit.PAPER_INK)
		var st := Kit.box(12, Color("efe3c4") if on else Kit.PAPER_LIGHT, Kit.PAPER_INK if on else Kit.LINE, 4 if on else 2, 10)
		for s in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(s, st)
		b.pressed.connect(Game.pocket.bind(e.id)); pockets_box.add_child(b)
	var h: String = Game.F.get("hold", "")
	pocket_hint.text = ("Holding: %s. Tap where to use it." % Game.plain(Game.ST.evidence[h].label)) if h != "" and Game.ST.evidence.has(h) \
		else ("Flashlight on. Drag on the picture to point it." if Game.F.get("lit", 0) else "Tap something in your pockets to take it out.")


## ---------- pop-ups
func _open(what: String) -> void:
	_play("tap")
	match what:
		"notebook": load("res://scripts/ui/notebook.gd").open(self, "")
		"board":
			board_view = not board_view; card_sel = ""
			if board_view: Game._case_tick(true)   # looking at the board settles what's left to settle
			_refresh()
		"phone": load("res://scripts/ui/phone.gd").open(self)
		"map": load("res://scripts/ui/places.gd").map(self)
		"jobs": load("res://scripts/ui/places.gd").board(self)


func _word(w: String) -> void:
	_play("tap")
	if w.begins_with("n:"): load("res://scripts/ui/notebook.gd").name_page(self, w.substr(2)); return
	load("res://scripts/ui/notebook.gd").open(self, w.trim_prefix("w:"))


func _menu() -> void:
	_play("tap")
	var inner := Kit.sheet(self, "메뉴", 0.5)
	var hint := Kit.label("", 20, Kit.PAPER_INK, true)
	var b1 := Kit.button("💡  Think (a nudge)"); b1.pressed.connect(func(): hint.text = Game.hint(); Game.note("  HINT: " + hint.text)); inner.add_child(b1); inner.add_child(hint)
	var b2 := Kit.button("📖  Chapters"); b2.pressed.connect(func(): Kit.close(inner); load("res://scripts/ui/places.gd").chapters(self)); inner.add_child(b2)
	var b3 := Kit.button("⌨  Korean keyboard test"); b3.pressed.connect(func(): Kit.close(inner); _keyboard_test()); inner.add_child(b3)
	var b5 := Kit.button("💬  What was said"); b5.pressed.connect(func(): Kit.close(inner); _log_sheet()); inner.add_child(b5)
	var b4 := Kit.button("⚙  Settings"); b4.pressed.connect(func(): Kit.close(inner); _settings()); inner.add_child(b4)


## 기록: every line so far in this chapter, newest at the bottom; tap ▶ to hear one again
func _log_sheet() -> void:
	var inner := Kit.sheet(self, "기록 · what was said", 0.72)
	var lines: Array = Game.S.get("log", [])
	if lines.is_empty(): inner.add_child(Kit.label("Nothing yet.", 20, Kit.MUTE)); return
	for e in lines:
		if e.who == "narr":
			inner.add_child(Kit.label(e.en, 18, Kit.MUTE, true)); continue
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); inner.add_child(row)
		if e.who != "you" and e.who != "sign" and Game.ST.cast.get(e.who, {}).has("look"):
			var f := TextureRect.new(); f.texture = Kit.face(e.who, e.get("ex", "neutral")); f.custom_minimum_size = Vector2(56, 56)
			f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; row.add_child(f)
		var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.add_theme_constant_override("separation", 0); row.add_child(col)
		col.add_child(Kit.label("You" if e.who == "you" else ("Written" if e.who == "sign" else Game.ST.cast.get(e.who, {}).get("n", e.who)), 15, Kit.MUTE))
		if e.get("heard", false): col.add_child(Kit.label("🔊 Heard, not written down yet", 20, Kit.MUTE))
		else:
			var r := Kit.rich(22); r.text = Kit.ko(e.ko); r.meta_clicked.connect(func(w): _word(str(w))); col.add_child(r)
		if e.get("en", "") != "": col.add_child(Kit.label(e.en, 16, Kit.MUTE, true))
		var say := Kit.button("▶", false, 18); var k: String = e.ko; var who: String = e.who
		say.pressed.connect(func(): voice.say(k, who)); row.add_child(say)
	await get_tree().process_frame
	var sc := inner.get_parent() as ScrollContainer
	if sc: sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)


## 설정: how it sounds and how big the Korean is
func _settings() -> void:
	var inner := Kit.sheet(self, "설정 · settings", 0.62)
	var rows := [["auto", "Read lines aloud by themselves", [[1, "On"], [0, "Off"]]], ["voices", "Voices", [[1, "On"], [0, "Off"]]],
		["slow", "Voice speed", [[0, "Normal"], [1, "Slow"]]], ["size", "Korean text size", [[0, "Small"], [1, "Medium"], [2, "Large"]]],
		["glow", "Things glow when named", [[1, "On"], [0, "Off"]]], ["fade", "Hints fade as you learn words", [[1, "On"], [0, "Off"]]], ["sound", "Sound effects", [[1, "On"], [0, "Off"]]], ["music", "Music", [[2, "On"], [1, "Low"], [0, "Off"]]],
		["amb", "Background sounds", [[2, "On"], [1, "Low"], [0, "Off"]]]]
	for r in rows:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); inner.add_child(row)
		var l := Kit.label(r[1], 20); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		for opt in r[2]:
			var b := Kit.button(opt[1], Settings.get_(r[0]) == opt[0], 18); b.alignment = HORIZONTAL_ALIGNMENT_CENTER; b.custom_minimum_size.x = 96
			b.pressed.connect(func():
				Settings.set_(r[0], opt[0]); voice.apply(); scape.update(Game.place()); Kit.close(inner); _settings(); _refresh())
			row.add_child(b)
	var t := Kit.button("▶  Test the voice", false, 18); t.pressed.connect(func(): voice.say("{안녕하세요}", "word")); inner.add_child(t)


func _keyboard_test() -> void:
	var k = load("res://scripts/ui/keyboard_test.gd").new(); k.main = self; add_child(k)


func _day_panel() -> void:
	_play("tap")
	var inner := Kit.sheet(self, "Day %d" % Game.W.day, 0.55)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); inner.add_child(row)
	for i in 4:
		var s: String = Game.SLOTS[i]
		var b := Kit.button("%s\n%s%s" % [Game.SLOT_KO[s], s.capitalize(), " · now" if i == Game.W.slot else ""], i == Game.W.slot, 20)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.disabled = i < Game.W.slot; row.add_child(b)
	inner.add_child(Kit.label("The story is in charge of the time right now." if Game.W.frozen else
		"Wait a while moves to the next part of the day. At night, go to bed in the courtyard to start day %d." % (Game.W.day + 1), 19, Kit.PAPER_INK, true))
	inner.add_child(Kit.label("Wallet: " + Game.won(Game.W.money), 22))
	var met: Array = Game.W.met.keys().filter(func(w): return Game.PEOPLE.has(w))
	if not met.is_empty():
		inner.add_child(Kit.label("PEOPLE", 14, Kit.MUTE))
		for w in met:
			inner.add_child(Kit.label("%s  %s%s" % [Game.ST.cast.get(w, {}).get("n", w), "♥".repeat(Game.rel_level(w)), "♡".repeat(Game.REL_STEPS.size() - Game.rel_level(w))], 22))
	inner.add_child(Kit.label("COMING UP", 14, Kit.MUTE))
	for n in range(Game.W.day, Game.W.day + 4):
		var ev: Array = Game.events_on(n)
		inner.add_child(Kit.label("%s: %s" % ["Today" if n == Game.W.day else ("Tomorrow" if n == Game.W.day + 1 else "Day %d" % n),
			", ".join(ev.map(func(e): return Game.plain(e.label))) if not ev.is_empty() else "nothing special"], 19))


## ---------- the start screen
func _title() -> void:
	var o := ColorRect.new(); o.color = Kit.INK; o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(o)
	var c := CenterContainer.new(); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); o.add_child(c)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); v.custom_minimum_size.x = 440; c.add_child(v)
	var t := Kit.label("탈", 120, Kit.PAPER); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var s := Kit.label("청 솔 마 을", 26, Kit.MUTE); s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(s)
	var go_on := func(f: Callable): o.queue_free(); f.call()
	if Game.has_save():
		var b := Kit.button("Continue", false); b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(func(): go_on.call(func(): if not Game.load_save(): Game.start_chapter("prologue", true))); v.add_child(b)
	var n := Kit.button("New game" if Game.has_save() else "Start", not Game.has_save()); n.alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.pressed.connect(func(): go_on.call(func(): Game.S = Game._fresh(); Game.start_chapter("prologue", true))); v.add_child(n)
	var ch := Kit.button("Chapters"); ch.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ch.pressed.connect(func(): go_on.call(func(): Game.load_save(); load("res://scripts/ui/places.gd").chapters(self))); v.add_child(ch)


## ---------- the title card ("@card 1장 | 탈"), the time-of-day card, the end of a chapter
func _card() -> Control:
	var c := ColorRect.new(); c.color = Color(0, 0, 0, 0.82); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); c.visible = false; c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Kit.label("", 84, Kit.PAPER); t.name = "T"; c.add_child(t)
	var s := Kit.label("", 30, Color(Kit.PAPER, 0.7)); s.name = "S"; c.add_child(s)
	for l in [t, s]:
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.offset_top = -40; t.offset_bottom = -40; s.offset_top = 60; s.offset_bottom = 60
	return c


func _timecard() -> void:
	var l := Kit.label("%s\nday %d · %s" % [Game.SLOT_KO[Game.slot_name()], Game.W.day, Game.slot_name()], 56, Kit.PAPER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(l); l.modulate.a = 0
	var tw := create_tween(); tw.tween_property(l, "modulate:a", 1.0, 0.3); tw.tween_interval(1.2); tw.tween_property(l, "modulate:a", 0.0, 0.5); tw.tween_callback(l.queue_free)


func _rewound() -> void:
	_play("wrong")
	var f := ColorRect.new(); f.color = Color(0.85, 0.75, 0.55, 0.35); f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(f); var tw := create_tween(); tw.tween_property(f, "modulate:a", 0.0, 0.7); tw.tween_callback(f.queue_free)


func _finished(id: String) -> void:
	var inner := Kit.sheet(self, Game.ST.meta.get("end-title", "끝"), 0.6)
	inner.add_child(Kit.label(Game.ST.meta.get("end-text", ""), 22, Kit.PAPER_INK, true))
	var nx: Dictionary = Game.next_chapter()
	if not nx.is_empty() and not nx.free and Game.CH.has(nx.id):
		var b := Kit.button("Start " + nx.t, true); b.pressed.connect(func(): Kit.close(inner); Game.start_chapter(nx.id, true)); inner.add_child(b)
	var k := Kit.button("Keep exploring"); k.alignment = HORIZONTAL_ALIGNMENT_CENTER; k.pressed.connect(func(): Kit.close(inner)); inner.add_child(k)


## ---------- sound and little messages
func _play(n: String) -> void:
	if Settings.get_("sound") == 0: return
	var stream := load("res://sfx/%s.wav" % n) as AudioStream
	if stream == null: return
	var p := AudioStreamPlayer.new(); p.stream = stream; add_child(p); p.play(); p.finished.connect(p.queue_free)
	if n == "slam": room.shake()


func _toast(t: String) -> void:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", Kit.box(14, Color(0.08, 0.09, 0.12, 0.92), Color.TRANSPARENT, 0, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(Kit.label(Game.plain(t), 20, Kit.PAPER)); toast_box.add_child(p)
	var tw := create_tween(); tw.tween_interval(2.8); tw.tween_property(p, "modulate:a", 0.0, 0.4); tw.tween_callback(p.queue_free)
