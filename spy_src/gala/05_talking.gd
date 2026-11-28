# ---------------------------------------------------------------- talking with you: their questions, your answers, your turn

func _talk_target() -> Dictionary:   # who the Talk button would talk to
	if not asking.is_empty() or back or done or escorting or in_back or killed: return {}
	var n := _nearest()
	if n.is_empty() or not (n.id in ASKERS or n.role == "bartender") or n.leaving or n.coming or n.tell or n.following: return {}
	return n


func _companion() -> Dictionary:   # someone walking with you, close enough to talk to
	if not asking.is_empty() or back or done or escorting: return {}
	for p in people:
		if p.following and not p.busy and not p.gone and player.position.distance_to(p.body.position) < 3.0: return p
	return {}


func _talk_btn() -> void:
	var p := _talk_target()
	if p.is_empty(): return
	if p.busy: talk_wait = p; talk_btn.text = "..."   # they finish what they're saying first
	else: _talk_to(p)


func _talk_to(p: Dictionary) -> void:
	if p.is_empty(): return
	p.busy = true
	var d: Vector3 = player.position - p.body.position
	p.body.rotation.y = atan2(-d.x, -d.z)
	_turn(p)


func _turn_keys(who: Dictionary) -> Array:
	if who.role == "bartender": return ["b_wine"]
	return ["b_name", "b_job", "b_from", "b_appt", "b_thanks" if who.get("following", false) else "b_go"]


func _will_follow(p: Dictionary) -> bool:   # each of them decides from what they think of you
	if p.pic.doubt > 0 or p.role == "security" or p.role == "bartender": return false
	var ok: bool = p.pic.ok
	match p.role:
		"host": return ok and randf() < 0.9   # looking after her guests is her job
		"broker": return ok and randf() < 0.5
		"assistant": return ok and randf() < 0.3
	if ok: return randf() < 0.85
	if p.pic.met: return randf() < 0.4
	return randf() < 0.15


func _go_ask(who: Dictionary) -> void:   # 같이 가요?
	if who.following: await _line(who, "go_yes"); return
	if _will_follow(who):
		await _line(who, "go_yes"); _start_follow(who)
	else: await _line(who, ["go_no1", "go_no2"].pick_random())


func _start_follow(p: Dictionary) -> void:
	slots_taken.erase("%s:%d" % [p.spot, p.slot])
	p.following = true; p.follow_t = 30.0; p.slot = -1; p.spot = ""; p.errand = false; p.timer = INF
	reactions.append("follow")


func _end_follow(p: Dictionary, say := false) -> void:   # back to the party
	if not p.following: return
	p.following = false
	if say and not p.gone: _line(p, "go_bye")
	_send_back(p)


func _follow(p: Dictionary, dt: float) -> void:   # a step behind you, wherever you go
	if p.busy: return
	p.follow_t -= dt
	if p.pic.doubt > 0 or p.follow_t <= 0.0 or done: _end_follow(p, true); return
	var behind: Vector3 = player.position + Vector3(sin(body_mesh.rotation.y), 0, cos(body_mesh.rotation.y)) * 1.1
	var gap: Vector3 = player.position - p.body.position; gap.y = 0
	if gap.length() > 1.5:
		p.goto = behind; p.speed = SPEED; p.coming = true; _walk(p, dt); p.coming = false; p.speed = 1.4
	else:
		p.body.velocity = Vector3.ZERO
		p.body.rotation.y = lerp_angle(p.body.rotation.y, atan2(-gap.x, -gap.z), 1.0 - exp(-5.0 * dt))


func _ask(p: Dictionary, group: Array, check := "", fact := "", q := -1) -> void:   # "and who are you?", or "I heard you're…?"
	asking = p; ask_group = group; p.busy = true; ask_tries = 0; ask_phone = false
	ask_check = check != ""
	if ask_check:
		ask_fact = _fact(check); ask_q = 0; ask_text = CHECK[check]; ask_clip = "c_" + check
	else:
		ask_fact = _fact(fact) if fact != "" else _pick_fact(p)
		ask_q = q if q >= 0 and q < ask_fact.qs.size() else randi() % ask_fact.qs.size()
		ask_text = ask_fact.qs[ask_q][0]; ask_clip = "q_%s_%d" % [ask_fact.k, ask_q]
	var d: Vector3 = player.position - p.body.position
	p.body.rotation.y = atan2(-d.x, -d.z)
	for o in group:
		if o != p and not o.busy: o.glance = 3.0
	_question()


func _pick_fact(p: Dictionary) -> Dictionary:   # something about you they don't know yet (and nothing silly: the host knows she invited you)
	var ok := Cover.FACTS.filter(func(f): return not (p.role == "host" and f.k == "invited"))
	var left := ok.filter(func(f): return not (f.k in p.pic.told))
	return (left if left else ok).pick_random()


func _question() -> void:
	var p: Dictionary = asking
	ask_t = 15.0; picked.clear(); _show_pick()
	ask_label.text = _en(ask_text); hear_btn.visible = true; done_btn.visible = false; right_btn.visible = english
	var tiles := []
	for i in ask_fact.chunks.size(): tiles.append([ask_fact.k, i])
	tiles += [["yn", 0], ["yn", 1]]
	var others: Array = (Cover.DEAL if deal_ask else Cover.FACTS).filter(func(o): return o.k != ask_fact.k); others.shuffle()
	for i in others[0].chunks.size(): tiles.append([others[0].k, i])
	var seen := {}; var deck := []
	for t in tiles:
		var tx: String = _chunk(t)[0]
		if not seen.has(tx): seen[tx] = 1; deck.append(t)
	deck.shuffle()
	for c in tile_box.get_children(): c.queue_free()
	tile_map.clear()
	for t in deck:   # Korean only in here
		var kt: String = _chunk(t)[0].trim_prefix("~")
		var b := _btn(_en(kt), 22 if english else 26, Vector2(104, 80)); b.pressed.connect(_pick.bind(t)); tile_box.add_child(b)
		tile_map[kt] = t
	ask_ui.visible = true
	_plg("ASKED: %s speaks to you, waiting for your answer (15 s). Your pieces: %s" % [_desc(p), " | ".join(tile_map.keys())])
	ask_busy = true
	await _line(p, ask_clip)
	ask_busy = false


func _line(p: Dictionary, id: String) -> void:   # one person says one line out loud, and you see it if you're close
	if p.gone: return
	var vid := _vk(p) + "_" + id
	p.audio.stream = _clip(vid); p.audio.play(); played.append(vid)
	p["said"] = ask_text if id == ask_clip else REACT.get(id.trim_prefix("x_"), [""])[0]
	if id.begins_with("ans_"): p["said"] = ANS[_vk(p)][id.trim_prefix("ans_")]
	if LINES.has(id): p["said"] = LINES[id][0]
	_perceive(p, p.said)
	await _wait_line(p.audio)
	p["said"] = ""


func _fact(k: String) -> Dictionary:
	if BACK.has(k): return BACK[k]
	for f in Cover.DEAL:
		if f.k == k: return f
	if k == "yn": return Cover.YN
	for f in Cover.FACTS:
		if f.k == k: return f
	return {}


func _chunk(t: Array) -> Array:
	return _fact(t[0]).chunks[t[1]]


func _pick(t: Array) -> void:
	if ask_busy or picked.size() >= 4: return
	picked.append(t); _show_pick()
	me_voice.stream = _mine("t_%s_%d" % t); me_voice.play()


func _joined(ts: Array) -> String:
	var s := ""
	for t in ts:
		var w: String = _chunk(t)[0]
		if w.begins_with("~"): s += w.substr(1)
		elif s == "": s = w
		else: s += " " + w
	return s


func _show_pick() -> void:
	if ans_label == null: return
	ans_label.text = (_joined(picked) if not english else " ".join(picked.map(func(t): return _en(_chunk(t)[0].trim_prefix("~"))))) if picked else ("Tap the pieces to ask" if back else "Tap the pieces to answer")
	ans_label.modulate = Color.WHITE if picked else Color(1, 1, 1, 0.45)
	say_btn.disabled = picked.is_empty()


func _judge(p: Array, f: Dictionary) -> String:   # good · order · part · wrong (same rules as the car)
	var want := []
	for i in f.chunks.size(): want.append(_chunk([f.k, i])[0])
	var got := p.map(func(t): return _chunk(t)[0])
	if got.size() > 1 and (got[0] == "네" or (got[0] == "아니요" and f.get("yn", false))): got = got.slice(1)
	if got == want: return "good"
	if got.size() == want.size() and got.all(func(w): return w in want) and want.all(func(w): return w in got): return "order"
	if got.all(func(w): return w in want): return "part"
	return "wrong"


func _judge_check(p: Array, f: Dictionary) -> String:   # good · differ · or judged like any answer
	var first: String = _chunk(p[0])[0]
	if first == "네": return "good" if p.size() == 1 or _judge(p.slice(1), f) == "good" else "wrong"
	if first == "아니요": return "differ"
	return _judge(p, f)


func _wait_line(au: Node) -> void:   # until the line's been said (the tester just waits its length, on the fast clock)
	if test:
		var n: float = au.stream.get_length() if au.stream else 0.0
		au.stop(); await _secs(maxf(n, 0.05)); return
	await get_tree().process_frame
	while is_instance_valid(au) and au.playing: await get_tree().process_frame


func _me(id: String) -> void:   # Eric says it
	me_voice.stream = _mine(id); me_voice.play()
	await _wait_line(me_voice)


func _say_it() -> void:
	if ask_busy or picked.is_empty() or asking.is_empty(): return
	if back: _say_back(); return
	ask_busy = true
	var who: Dictionary = asking
	var r := _judge_check(picked, ask_fact) if ask_check else _judge(picked, ask_fact)
	if r == "good":
		if picked[0][0] == "yn": await _me("t_yn_%d" % picked[0][1])
		if picked.size() > 1 or picked[0][0] != "yn": await _me("a_" + ask_fact.k)
	else:
		for t in picked: await _me("t_%s_%d" % t)
	if asking != who: return
	if r == "differ": _ask_end("differ"); return
	if r != "good" and r != "wrong" and ask_tries == 0:   # close: they didn't quite catch it
		ask_tries = 1
		await _line(who, HUH.pick_random())
		if asking == who: _question()
		return
	_ask_end("good" if r == "good" else "bad")


func _ask_end(how: String) -> void:   # how it went decides what they think of you, and they remember
	if back: _back_end(); return
	var who: Dictionary = asking
	if who.is_empty(): return
	if deal_ask: _deal_answer(how); return
	if gate_check and who == gate_by: _gate_result(how); return
	asking = {}; ask_ui.visible = false; ask_busy = true
	var k: String = ask_fact.k
	for o in ask_group:   # they all heard it
		if o.gone: continue
		o.pic.met = true
		if how == "good" and not (k in o.pic.told): o.pic.told.append(k)
		if how == "good": o.pic.second.erase(k)   # now they heard it from you
		if how == "good" and not ask_phone and o.pic.doubt == 0: o.pic.ok = true
		if how != "good":
			_doubt(o, 2 if how == "differ" and o == who else 1)
			if o.id in ASKERS: o.pic.concern = {"why": how, "k": k, "q": ask_q, "src": "direct" if o == who else "saw"}   # and why
		elif o.pic.concern.get("k", "") == k or (o == who and who.came): o.pic.concern = {}   # that's cleared up
	reactions.append("answer_" + how)
	if how == "good" and (ask_check or who.came): _doubt(who, -1)   # you passed their check
	if how == "good" and (ask_check or who.came): await _line(who, "x_fine" if not ask_phone else "x_cool")
	elif how == "good": await _line(who, "x_ok" if not ask_phone else "x_cool")
	elif how == "differ": await _line(who, "x_differ")
	elif how != "walked": await _line(who, "x_cool")
	if how == "good" and not done and not skip_turn and not who.gone and player.position.distance_to(who.body.position) < 3.2:
		_turn(who); return   # your turn: ask them something
	who.busy = false; ask_busy = false
	if who.came: who.came = false; _send_back(who)
	if how != "good":
		for o in ask_group: o.glance = -3.0   # they turn back to each other


func _turn(who: Dictionary) -> void:
	back = true; asking = who; ask_group = [who]; ask_tries = 0; ask_busy = false
	_turn_ui()


func _turn_ui() -> void:   # every question piece you know, mixed up
	ask_t = 12.0; picked.clear(); _show_pick()
	ask_label.text = "Your turn: ask them something"; hear_btn.visible = false; done_btn.visible = true; right_btn.visible = false
	var deck := []
	for q in _turn_keys(asking):
		for i in BACK[q].chunks.size(): deck.append([q, i])
	deck.shuffle()
	for c in tile_box.get_children(): c.queue_free()
	tile_map.clear()
	for t in deck:
		var kt: String = _chunk(t)[0]
		var b := _btn(_en(kt), 20 if english else 24, Vector2(104, 80)); b.pressed.connect(_pick.bind(t)); tile_box.add_child(b)
		tile_map[kt] = t
	ask_ui.visible = true
	_plg("YOUR TURN to ask %s something (12 s). Pieces: %s. Or: done" % [_desc(asking), " | ".join(tile_map.keys())])


func _judge_back(p: Array) -> String:   # the question you built, or "" if it isn't one
	for q in BACK:
		var want := []
		for i in BACK[q].chunks.size(): want.append([q, i])
		if p == want: return q
	return ""


func _say_back() -> void:
	ask_busy = true
	var who: Dictionary = asking
	var q := _judge_back(picked)
	if q != "": await _me("ask_" + q)
	else:
		for t in picked: await _me("t_%s_%d" % t)
	if asking != who or not back: return
	if q == "":
		if ask_tries == 0:   # they try to work out what you meant
			ask_tries = 1; await _line(who, HUH.pick_random())
			if asking == who and back: _turn_ui(); ask_busy = false
			return
		await _line(who, "x_cool"); _slip(who); _back_end(); return   # they give up, and wonder about you
	if q == "b_appt": await _appt(who); return
	if q == "b_wine":   # 네, 여기 있습니다: you face her and take the glass
		await _line(who, "r_wine")
		var d: Vector3 = who.body.position - player.position; body_mesh.rotation.y = atan2(-d.x, -d.z)
		if not ("drink" in inv): inv.append("drink")
		sips = SIPS; hand = "drink"; _props(); _back_end(); return
	var k := q.trim_prefix("b_")
	if k == "go": await _go_ask(who); _back_end(); return
	if k == "thanks":   # off you go, and thanks
		await _line(who, "go_bye"); _back_end(); _end_follow(who); return
	if k in who.pic.asked:   # you asked that already
		await _line(who, "x_cool")
		_slip(who)   # and again, and again: they start to wonder what you're up to
	else:
		who.pic.asked.append(k); reactions.append("told_" + k)
		await _line(who, "ans_" + k)
	_back_end()


func _back_end() -> void:   # your turn's over: they go back to their talk
	var who: Dictionary = asking
	back = false; asking = {}; ask_ui.visible = false; ask_busy = false; done_btn.visible = false
	if who.is_empty(): return
	who.busy = false
	if who.came: who.came = false; _send_back(who)


func _hear_q() -> void:
	if not asking.is_empty() and not ask_busy: _line(asking, ask_clip)
