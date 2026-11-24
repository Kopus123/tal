extends RefCounted
## Getting around and starting things: the village map, the notice board (jobs), the chapter list.

## the map: places you've been, tap one to go there
static func map(main: Control) -> void:
	var inner := Kit.sheet(main, "지도 · the village", 0.6)
	var pins: Array = Game.world_st.map.filter(func(p): return Game.S.known.has(p.p) and Game.ST.places.has(p.p))
	if pins.is_empty(): inner.add_child(Kit.label("You haven't been anywhere you could walk back to yet.", 20, Kit.MUTE, true)); return
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8); inner.add_child(grid)
	for p in pins:
		var pl: Dictionary = Game.ST.places[p.p]
		var b := Kit.button("%s\n%s%s" % [pl.get("name", p.p), pl.get("sub", ""), "  · you're here" if p.p == Game.S.loc else ""], p.p == Game.S.loc, 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size.y = 72
		b.pressed.connect(func(): Kit.close(inner); Game.enter(p.p)); grid.add_child(b)


## the notice board in the village hall: today's jobs, the one you're on
static func board(main: Control) -> void:
	var inner := Kit.sheet(main, "의뢰 게시판 · notice board", 0.6)
	var cur: Dictionary = Game.job_on()
	var card := func(j: Dictionary, mine: bool):
		inner.add_child(Kit.label("%s · %s" % [j.ko, j.en], 24))
		inner.add_child(Kit.label("for %s · %s · %s" % [Game.ST.cast.get(j.client, {}).get("n", j.client), Game.won(j.pay), j.level], 17, Kit.MUTE))
		inner.add_child(Kit.label(j.note, 19, Kit.PAPER_INK, true))
		for w in j.get("ask", {}).keys():   # leads: who to ask, and where they are right now
			var p: Dictionary = Game.PEOPLE.get(w, {})
			var at: Dictionary = Game.where_now(p) if not p.is_empty() and not Game.away_now(w) else {}
			var pl: Dictionary = Game.ST.places.get(at.get("place", ""), {})
			inner.add_child(Kit.label("·  Ask %s: %s" % [Game.ST.cast.get(w, {}).get("n", w), ("%s (%s) right now" % [pl.name, pl.get("sub", "")]) if not pl.is_empty() else "not around right now"], 18, Kit.MUTE, true))
		if mine:
			var q := Kit.button("Give up for today"); q.pressed.connect(func(): Kit.close(inner); Game._job_effect("fail"); Game.changed.emit()); inner.add_child(q)
		elif cur.is_empty():
			var t := Kit.button("Take this job", true); t.pressed.connect(func(): Kit.close(inner); Game.take_job(j.id)); inner.add_child(t)
	if not cur.is_empty():
		inner.add_child(Kit.label("YOU'RE WORKING ON", 14, Kit.MUTE)); card.call(cur, true)
	inner.add_child(Kit.label("ON THE BOARD TODAY", 14, Kit.MUTE))
	var list: Array = Game.jobs_today()
	if list.is_empty(): inner.add_child(Kit.label("Nothing new today. Come back tomorrow.", 20, Kit.MUTE))
	for j in list: card.call(j, false)


## chapters: start one, carry on in one, the free days, the test areas
static func chapters(main: Control) -> void:
	var inner := Kit.sheet(main, "목차 · chapters", 0.55)
	var chs: Array = Game.world_st.chapters
	for i in chs.size():
		var c: Dictionary = chs[i]
		if c.cont or not Game.CH.has(c.id): continue
		var unlocked: bool = i == 0 or c.free or c.dev or Game.S.done.has(chs[i - 1].id) or Game.S.done.has(c.id)
		var started: bool = Game.S.prog.get(c.id, {}).get("F", {}).get("started", false) or Game.S.ch == c.id
		var label := "%s · %s%s" % [c.t, c.sub, "  (test area)" if c.dev else ""]
		var b := Kit.wide(label + ("" if unlocked else "  🔒"), false, 22); b.disabled = not unlocked
		b.pressed.connect(func(): Kit.close(inner); main.leave_title(); Game.start_chapter(c.id, not started))
		inner.add_child(b)
		if started and not c.free:
			var r := Kit.button("    ↺ start %s over" % c.t, false, 17)
			Kit.sure(r, "    ↺ Start over? Your place in it is lost. Tap again.", func(): Kit.close(inner); main.leave_title(); main.start_over(c.id)); inner.add_child(r)
