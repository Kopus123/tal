extends "res://gala.gd"
## The party's tests. Run them all:  godot --path . res://gala_test.tscn -- --test
## or just some, by name:  ... -- --test=items,mission   (core chat heat gun english items mission exit)
## Every section but core starts from a clean party (_fresh), so one can't break the next.


const SECTIONS := ["core", "chat", "heat", "gun", "english", "items", "mission", "danger", "exit"]


func _run_test() -> void:
	AudioServer.set_bus_mute(0, true)
	skip_turn = true; no_heat = true; no_real = true
	english = false; en_btn.text = "English: off"
	Engine.time_scale = FAST; Engine.physics_ticks_per_second = int(60 * FAST); Engine.max_physics_steps_per_frame = int(8 * FAST)   # same small steps, just more of them
	get_window().position = Vector2i(-3000, 60)
	await _secs(0.5)
	var want := SECTIONS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test="): want = Array(a.trim_prefix("--test=").split(",", false))
	for sec in SECTIONS:
		if not (sec in want): continue
		print("== ", sec)
		if sec != "core": await _fresh()
		match sec:
			"core": await _t_core()
			"chat": await _t_chat()
			"heat": await _t_heat()
			"gun": await _t_gun()
			"english": await _t_english()
			"items": await _t_items()
			"mission": await _t_mission()
			"danger": await _t_danger()
			"exit": await _t_exit()
	print("DONE %d failed" % _fails)
	get_tree().quit(1 if _fails else 0)


func _t_core() -> void:
	_check(people.size() == 9 and ROLES.all(func(r): return not _find(r).is_empty()), "nine people at the party, one of each role")
	_check(people.all(func(p): return p.tag.visible == false), "nobody wears a name tag")
	_check(not HANDLER.has("h_him") and not HANDLER.has("h_wrong"), "the handler has no 'that's him' or 'wrong': he doesn't know their faces")
	await _secs(1.5); await _shot("g1_room")
	var started := talk_count
	await _secs(14.0)
	_check(talk_count - started >= 1 and talks <= 2, "they keep talking among themselves (%d conversations in 14 s)" % (talk_count - started))
	# reading: only right beside them, only Korean
	hold = true
	var br := _find("broker"); var asst := _find("assistant")
	var _w1 := clock
	while (br.busy or asst.busy) and clock - _w1 < 30.0: await _secs(0.1)   # (never forever)
	_go(asst, br.spot); asst.body.position = _slot_pos(asst.spot, asst.slot); br.body.position = _slot_pos(br.spot, br.slot)
	await _put(asst.body.position.lerp(br.body.position, 0.5) + Vector3(0, 0, 0.5))
	_talk("boss", [[asst, "b1"], [br, "a1"], [asst, "r_yes"]])
	await _secs(0.3)
	_check(asst.ko.text == LINES.b1[0], "right beside them you can make out 사장님, 손님이 기다리세요")
	_check(people.all(func(p): return not p.has("en")), "and there's no English over anyone, ever")
	await _shot("g2_close")
	for off in [Vector3(0, 0, 3.2), Vector3(0, 0, -3.2), Vector3(3.2, 0, 0), Vector3(-3.2, 0, 0), Vector3(2.4, 0, 2.4), Vector3(-2.4, 0, -2.4)]:
		await _put(asst.body.position.lerp(br.body.position, 0.5) + off)   # somewhere you actually fit, a few steps back
		if player.position.distance_to(asst.body.position) > 2.4 and player.position.distance_to(br.body.position) > 2.4: break
	await _secs(0.1)
	_check(asst.ko.text == "" and br.ko.text == "", "a couple of steps back: no words on screen, you only hear them (%.1f m, '%s' '%s')" % [player.position.distance_to(asst.body.position), asst.ko.text, br.ko.text])
	_check(asst.audio.attenuation_filter_db < -10.0, "and voices go muffled with distance")
	var _w2 := clock
	while (asst.busy) and clock - _w2 < 30.0: await _secs(0.1)   # (never forever)
	await _put(Vector3(-0.5, 0, 6.3))
	# business stays private near a stranger
	reacted.clear()
	await _put(br.body.position + Vector3(0, 0, 2.0))
	var _w3 := clock
	while (br.busy or asst.busy) and clock - _w3 < 30.0: await _secs(0.1)   # (never forever)
	_check(not _options().any(func(o): return o[0] == "boss"), "near a stranger, the broker and his assistant don't talk business")
	asst.pic.ok = true
	_check(_options().any(func(o): return o[0] == "boss"), "once his assistant has taken to you, they do")
	asst.pic.ok = false
	await _put(Vector3(-0.5, 0, 6.3))
	# marking people: your guess, no verdict
	_toggle_phone(); await _secs(0.2)
	_check(phone_ui.visible and phone_prop.visible and role_btns.size() == 5, "the phone has the Who's who list, and you look at it")
	await _shot("g3_phone")
	await _beside(br); await _secs(0.3)
	_check(ring.visible and ring.position.distance_to(br.body.position) < 0.2, "the person your phone points at lights up")
	var said_before := played.size()
	_tag("broker")
	_check(guesses.get("broker", "") == br.id and br.tag.visible and br.tag.text == ROLE_NAME.broker[1] + "?", "mark the broker: your mark goes over him, with a ?")
	var bt := _find("bartender")
	await _beside(bt)
	_tag("host")
	_check(guesses.get("host", "") == bt.id and not played.slice(said_before).any(func(x): return x.begins_with("h_")), "a wrong mark is saved just the same, and nobody says a word")
	_tag("bartender")
	_check(guesses.get("bartender", "") == bt.id and not guesses.has("host"), "one mark per person: re-marking her moves it")
	_toggle_phone()
	await _put(Vector3(-0.5, 0, 6.3))
	# they notice you: not everyone the same way
	var kinds := {}
	for i in 80:
		_reset_pics(); asking = {}; ask_busy = false
		var grp := _guest_group()
		if grp.is_empty(): continue
		for o in grp: o.busy = false
		reactions.clear(); _react(grp[0].spot)
		if reactions: kinds[reactions[0]] = 1
		if not asking.is_empty():
			asking.busy = false; asking = {}; ask_ui.visible = false
	_check(kinds.has("ask") and kinds.has("glance") and kinds.has("ignore"), "a group you hang around: some ask who you are, some glance and carry on, some ignore you (%s)" % ", ".join(kinds.keys()))
	_reset_pics(); ask_busy = false
	for p in people: p.glance = 0.0; p.busy = false
	# lingering is what sets it off
	var grp := _guest_group()
	reactions.clear(); reacted.clear()
	await _beside(grp[0]); await _secs(LINGER + 0.6)
	_check(reactions.size() >= 1, "stand by a group for a moment and they react (%s)" % (reactions[0] if reactions else "nothing"))
	if not asking.is_empty(): _ask_end("walked")
	await _secs(0.3)
	_reset_pics(); for p in people: p.glance = 0.0
	# someone asks: a good answer
	grp = _guest_group(); var g: Dictionary = grp[0]
	await _beside(g); reactions.clear()
	_ask(g, grp); await _secs(0.1); await _wait_free()
	_check(ask_ui.visible and ask_label.text == ask_fact.qs[ask_q][0] and played.has(_vk(g) + "_q_%s_%d" % [ask_fact.k, ask_q]), "they ask out loud, in Korean: " + ask_label.text)
	_check(tile_box.get_children().all(func(b): return not b.text.contains("I am") and not b.text.contains("from")), "your pieces are Korean only")
	await _shot("g5_asked")
	picked = _right_pieces(ask_fact); await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.ok and g.pic.met and ask_fact.k in g.pic.told and grp.all(func(o): return o.pic.met), "answer well: they take to you, and the whole group remembers what you said")
	_check(played.has(_vk(g) + "_x_ok"), "and they say 아, 반갑습니다")
	# your turn: ask them back
	_reset_pics(); skip_turn = false
	grp = _guest_group(); g = grp[0]; await _beside(g)
	no_ask = true   # (only g talks to you here)
	_ask(g, grp); await _secs(0.1); await _wait_free()
	picked = _right_pieces(ask_fact); await _say_it(); await _secs(0.2); await _wait_free()
	_check(back and asking == g and ask_ui.visible and ask_label.text.begins_with("Your turn") and tile_box.get_children().any(func(b): return b.text == "성함이"), "answer well, and it's your turn: ask them something")
	await _shot("g7_turn")
	picked = [["b_name", 0], ["b_name", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(played.has(_vk(g) + "_ans_name") and "name" in g.pic.asked and not back and asking.is_empty(), "성함이 어떻게 되세요? and they tell you: " + ANS[_vk(g)].name)
	_turn(g); picked = [["b_name", 0], ["b_name", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.doubt == 1 and not back, "ask the same person the same thing twice: now they're curious about you")
	var _w4 := clock
	while (g.busy) and clock - _w4 < 30.0: await _secs(0.1)   # (never forever)
	_talk_to(g); picked = [["b_name", 0], ["b_name", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.doubt == 2, "and a third time: they doubt you (doubt=%d back=%s asking=%s)" % [g.pic.doubt, back, asking.get("id", "")])
	_doubt(g, -3); g.coming = false   # (before they come over to check you)
	no_ask = false
	if not asking.is_empty(): _ask_end("walked")
	_reset_pics()
	var bk := _find("broker"); await _beside(bk)
	_turn(bk); picked = [["b_job", 0], ["b_job", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(played.has("broker_ans_job"), "ask the broker what he does: 사업합니다, and no more")
	_reset_pics(); g = grp[0]
	for i in 200:
		if not g.busy: break
		await _secs(0.1)
	g.busy = false
	await _beside(g); no_ask = true; await _clear_ask()   # (nobody else butts in)
	_talk_to(g); picked = [["b_name", 1], ["b_name", 0]]; var before_huh := played.size(); await _say_it(); await _secs(0.2); await _wait_free()
	_check(back and played.slice(before_huh).any(func(x): return HUH.any(func(h): return x == _vk(g) + "_" + h)), "a question that doesn't make sense: they try to work out what you meant")
	picked = [["b_job", 1], ["b_from", 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(not back and g.pic.doubt == 1 and played.has(_vk(g) + "_x_cool"), "still no sense: 아... 네., and they wonder about you (back=%s doubt=%d)" % [back, g.pic.doubt])
	no_ask = false
	_turn(g); done_btn.pressed.emit(); await _secs(0.1)
	_check(not back and asking.is_empty(), "or tap Done and ask nothing")
	_reset_pics(); skip_turn = true
	grp = _guest_group(); g = grp[0]; await _beside(g); reactions.clear()
	for o in grp: o.pic.met = true   # (as if they'd just met you)
	reacted.clear(); reactions.clear(); _react(g.spot)
	_check(reactions.has("glance") or reactions.has("ask"), "come back later: the ones who met you just nod")
	if not asking.is_empty(): _ask_end("walked")
	await _secs(0.3)
	# a near miss, then a bad answer
	_reset_pics(); for p in people: p.glance = 0.0
	grp = _guest_group(); g = grp[0]
	await _beside(g)
	_ask(g, grp); await _secs(0.1); await _wait_free()
	var rv := _right_pieces(ask_fact); rv.reverse()
	if rv.size() < 2: rv = [_right_pieces(ask_fact)[0]]
	picked = rv if _judge(rv, ask_fact) != "good" else [rv[0]]
	var first_q := ask_label.text
	await _say_it(); await _secs(0.1); await _wait_free()
	_check(not asking.is_empty() and HUH.any(func(h): return played.has(_vk(g) + "_" + h)) and ask_label.text == first_q, "almost right: they ask you to say it again (a few different ways) and ask again")
	var wrong_f: Dictionary = Cover.FACTS.filter(func(f): return f.k != ask_fact.k)[0]
	picked = [[wrong_f.k, 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.wary and not g.pic.ok and played.has(_vk(g) + "_x_cool"), "a wrong answer: 아... 네. and they're wary of you now")
	var ck: String = g.pic.concern.get("k", "")
	_check(ck == ask_fact.k and g.pic.concern.src == "direct" and grp.filter(func(o): return o != g and o.id in ASKERS).all(func(o): return o.pic.concern.get("src", "") == "saw"), "they remember why: the question you got wrong (the others in the group saw it)")
	await _secs(1.5)
	_check(g.audio.volume_db < -6.0, "wary of you: they lower their voices when you're near")
	_check(g.pic.doubt == 1, "one slip: curious, not more")
	var looked := false
	for i in 160:
		await _secs(0.1)
		if not g.busy and not _facing_away(g) and g.glance > 0.0: looked = true; break
	_check(looked, "curious: they keep looking you over")
	reacted.clear(); reactions.clear(); _react(g.spot)
	_check(reactions == ["look"], "go back to that group: they look you over, nobody asks")
	await _shot("g6_wary")
	# a second slip: doubtful, and they come to you
	await _put(Vector3(-0.5, 0, 6.3)); await _secs(0.2)
	_doubt(g, 1)
	reacted.clear(); reactions.clear(); _react(g.spot)
	_check(reactions == ["cold"], "doubtful: that group turns their backs")
	var came := false
	for i in 150:
		await _secs(0.1)
		if asking == g: came = true; break
	_check(came and not ask_check and ask_fact.k == ck and player.position.distance_to(g.body.position) < 1.8, "and they walk over to you and ask that same thing again: %s (%s %s check=%s %.1f m, %s)" % [ask_label.text, g.id, str(g.pic), ask_check, player.position.distance_to(g.body.position), str(reactions)])
	await _wait_free()
	picked = [["yn", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.doubt == 3, "get it wrong again: alarmed")
	var told := false
	for i in 250:
		await _secs(0.1)
		if played.has(_vk(g) + "_al_sec"): told = true; break
	var sc := _find("security")
	for i in 60:
		if hunting: break
		await _secs(0.1)
	_check(hunting, "told: security comes for you")
	hunting = false; var scc := _find("security"); _go(scc, "door"); scc.body.position = _slot_pos(scc.spot, scc.slot); scc.speed = 1.4   # (tester) call him off for now
	_check(told, "alarmed: they go and tell security, 팀장님, 저 분 좀 보세요 (%s at %s slot %d at=%s errand=%s tell=%s busy=%s doubt=%d told_sec=%s · security at %s at=%s busy=%s · room=%s)" % [g.id, g.spot, g.slot, _at(g) if g.slot >= 0 else false, g.errand, g.tell, g.busy, g.pic.doubt, g.pic.told_sec, sc.spot, _at(sc), sc.busy, _has_room(sc.spot)])
	_check(not g.coming, "and the one who came over goes back to the party")
	# what they come back with depends on what they know
	_reset_pics()
	var hx := _find("g3")
	var _w5 := clock
	while (hx.busy) and clock - _w5 < 30.0: await _secs(0.1)   # (never forever)
	await _beside(hx)
	hx.pic.doubt = 2; hx.pic.concern = {"why": "heard_odd", "k": "", "q": -1, "src": "heard"}
	_come_check(hx); await _secs(0.1); await _wait_free()
	_check(asking == hx and not ask_check, "they only heard you're odd: an ordinary question, never 'I heard you're…'")
	picked = _right_pieces(ask_fact); await _say_it(); await _secs(0.2); await _wait_free()
	_check(hx.pic.doubt == 1 and hx.pic.concern.is_empty() and played.has(_vk(hx) + "_x_fine"), "answer it well: 아, 그렇군요, concern cleared and doubt down a step")
	_reset_pics(); await _beside(hx)
	hx.pic.doubt = 2; hx.pic.told = ["from"]; hx.pic.second = ["from"]; hx.pic.concern = {"why": "differ", "k": "from", "q": 0, "src": "direct"}
	_come_check(hx); await _secs(0.1); await _wait_free()
	_check(asking == hx and ask_check and ask_fact.k == "from", "you contradicted what they heard: they come back to check it, " + ask_label.text)
	_ask_end("walked"); await _secs(0.2)
	_reset_pics(); await _beside(hx)
	hx.pic.doubt = 2; hx.pic.concern = {"why": "walked", "k": "job", "q": 1, "src": "direct"}
	_come_check(hx); await _secs(0.1); await _wait_free()
	_check(asking == hx and not ask_check and ask_text == Cover.FACTS.filter(func(f): return f.k == "job")[0].qs[1][0], "you walked off mid-question: they ask you the same thing again, " + ask_text)
	_ask_end("walked"); await _secs(0.2)
	_reset_pics(); await _beside(hx)
	hx.pic.doubt = 2
	_come_check(hx); await _secs(0.1); await _wait_free()
	_check(asking == hx and not ask_check, "doubt with nothing heard: no 'I heard you're…'")
	_ask_end("walked"); await _secs(0.2)
	var hst := _find("host")
	_check(range(80).all(func(_i): return _pick_fact(hst).k != "invited"), "the host never asks who invited you")
	var pal_seen := {}
	for c in get_meta("looks").values(): pal_seen[c] = 1
	_check(pal_seen.size() == 11, "everyone wears a different colour, drawn fresh each party")
	# 같이 가요
	_reset_pics()
	var fa := _find("g1"); var fb := _find("g2")
	var _w6 := clock
	while (fa.busy or fb.busy) and clock - _w6 < 30.0: await _secs(0.1)   # (never forever)
	fb.spot = fa.spot
	var tsp: String = GUEST_SPOTS.filter(func(x): return x != fa.spot and _free_slots(x) >= 2)[0]
	await _go_together(fa, fb, tsp)
	_check(played.has(_vk(fa) + "_w_go") and played.has(_vk(fb) + "_go_yes") and fa.spot == tsp and fb.spot == tsp, "friends move on together: 같이 가요. 네, 좋아요. (you hear it first)")
	_reset_pics()
	var fg := _find("g3")
	for i in 30:
		if not fg.busy: break
		await _secs(0.1)
	fg.busy = false   # (an earlier test can leave them marked busy)
	await _beside(fg)
	for i in 100:   # (until they're not mid-conversation)
		await _secs(0.1)
		if _talk_target() == fg and not fg.busy: break
	_check(talk_btn.visible and not _talk_target().is_empty(), "stand beside someone free: a Talk button (target=%s fg=%s coming=%s doubt=%d asking=%s back=%s)" % [_talk_target().get("id", ""), fg.id, fg.coming, fg.pic.doubt, asking.get("id", ""), back])
	no_ask = true; await _clear_ask(); _talk_to(fg)
	for i in 100:   # (if a chat just started, they finish it first)
		await _secs(0.1)
		if back: break
	_check(back and asking == fg and tile_map.has("같이") and tile_map.has("가요") and not tile_map.has("감사합니다"), "Talk: your turn, with 같이 + 가요 among the pieces")
	fg.pic.ok = true; fg.pic.met = true
	var fol := false
	for tries in 8:
		picked = [["b_go", 0], ["b_go", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
		if fg.following: fol = true; break
		await _secs(0.2); _talk_to(fg)
		for i in 100:
			await _secs(0.1)
			if back: break
	_check(fol and played.has(_vk(fg) + "_go_yes"), "someone who likes you: 같이 가요, 네, 좋아요, and they come with you")
	await _put(player.position + Vector3(4.0, 0, 0)); await _secs(3.0)
	if player.position.distance_to(fg.body.position) > 2.2: await _put(Vector3(-0.5, 0, 6.3)); await _secs(3.0)
	for i in 50:   # (give them a moment more to catch up)
		if player.position.distance_to(fg.body.position) < 2.2: break
		await _secs(0.1)
	_check(fg.following and player.position.distance_to(fg.body.position) < 2.2, "walk off: they keep up, a step behind (%.1f m)" % player.position.distance_to(fg.body.position))
	await _put(Vector3(-0.5, 0, 6.3)); await _secs(5.0)   # somewhere quiet (and they catch up)
	if not asking.is_empty(): _ask_end("walked"); await _secs(0.3)
	_check(comp_btn.visible, "with someone along: a Talk (with you) button (%.1f m, asking=%s)" % [player.position.distance_to(fg.body.position), asking.get("id", "")])
	comp_btn.pressed.emit(); await _secs(0.1)
	_check(back and asking == fg and tile_map.has("감사합니다") and not tile_map.has("같이"), "talk to your companion: you can say 감사합니다 (talking to %s, %s following=%s %.1f m busy=%s)" % [asking.get("id", "nobody"), fg.id, fg.following, player.position.distance_to(fg.body.position), fg.busy])
	picked = [["b_thanks", 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(not fg.following and played.has(_vk(fg) + "_go_bye") and fg.spot != "", "감사합니다: 저 이만 가 볼게요, and back to the party")
	_reset_pics(); fg.pic.doubt = 1
	_check(not _will_follow(fg) and not _will_follow(_find("security")), "someone who doubts you, or security: never")
	var hh := _find("host"); var bb := _find("broker")
	hh.pic.ok = false; bb.pic.ok = false
	_check(range(30).all(func(_i): return not _will_follow(hh) and not _will_follow(bb)), "the host and the broker won't, unless they like you")
	hh.pic.ok = true; bb.pic.ok = true
	_check(range(40).any(func(_i): return _will_follow(hh)) and range(60).any(func(_i): return _will_follow(bb)), "once they like you: the host often comes along, the broker sometimes")
	_reset_pics(); fg.pic.ok = true; fg.pic.met = true
	_start_follow(fg); fg.follow_t = 0.2; await _secs(0.6)
	_check(not fg.following, "after a while they go back to their own evening")
	no_ask = false
	# repair: pass their check
	_reset_pics()
	await _beside(g)
	g.pic.doubt = 2; g.pic.wary = true; g.pic.checked = true; g.pic.told = ["from"]
	_ask(g, [g], "from"); await _secs(0.1); await _wait_free()
	picked = [["yn", 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.doubt == 1 and played.has(_vk(g) + "_x_fine") and not g.pic.checked, "pass their check: 아, 그렇군요, and their doubt drops a step")
	# repair: someone who likes you vouches
	_reset_pics()
	var va := _find("g3"); var vb := _find("g4")
	var _w7 := clock
	while (va.busy or vb.busy) and clock - _w7 < 30.0: await _secs(0.1)   # (never forever)
	vb.spot = va.spot; va.pic.ok = true; vb.pic.doubt = 2; vb.pic.wary = true
	_check(_gossip([va, vb]).any(func(o): return o[0] == "vouch" and o[1][0][0] == va), "someone who likes you, standing with someone who doubts you: they can vouch for you (%s %s / %s %s)" % [va.id, str(va.pic), vb.id, str(vb.pic)])
	await _talk("vouch", [[va, "v_ok"], [vb, "r_really"]])
	_check(vb.pic.doubt == 1 and played.has(_vk(va) + "_v_ok"), "저 분, 괜찮은 분이에요: their doubt drops a step (%s doubt=%d vouched=%s %s)" % [vb.id, vb.pic.doubt, vb.pic.vouched, str(reactions.slice(-4))])
	_check(not _gossip([va, vb]).any(func(o): return o[0] == "vouch"), "a vouch works once per person")
	# repair: keep out of their way
	_reset_pics()
	vb.pic.doubt = 1; vb.pic.wary = true; vb.pic.told = ["job"]
	await _beside(vb); vb.calm_t = COOL - 0.3; await _secs(0.6)
	_check(vb.pic.doubt == 1, "stay near them and nothing cools")
	for far in [Vector3(-0.5, 0, 6.3), Vector3(8.0, 0, 5.5), Vector3(-8.0, 0, -5.0), Vector3(8.5, 0, -5.5), Vector3(-8.5, 0, 5.5)]:
		await _put(far)
		if player.position.distance_to(vb.body.position) > 7.0: break
	vb.calm_t = COOL - 0.3; await _secs(0.6)
	_check(vb.pic.doubt == 0 and "job" in vb.pic.told, "keep away for a while: their doubt cools, but they still know what you said (%.1f m away)" % player.position.distance_to(vb.body.position))
	_reset_pics()
	# silence
	_reset_pics(); for p in people: p.glance = 0.0
	await _put(Vector3(-0.5, 0, 6.3))
	grp = _guest_group(); g = grp[0]; await _beside(g)
	_ask(g, grp); await _secs(0.1); await _wait_free()
	ask_t = 0.05; await _secs(0.3); await _wait_free()
	_check(asking.is_empty() and g.pic.wary, "say nothing and they give up on you, wary (%s asking=%s back=%s doubt=%d busy=%s)" % [g.id, asking.get("id", ""), back, g.pic.doubt, ask_busy])
	# the phone while they wait
	_reset_pics(); for p in people: p.glance = 0.0
	grp = _guest_group(); g = grp[0]; await _beside(g)
	_ask(g, grp); await _secs(0.1); await _wait_free()
	_toggle_phone(); _toggle_phone()
	picked = _right_pieces(ask_fact); await _say_it(); await _secs(0.2); await _wait_free()
	_check(g.pic.met and not g.pic.ok and not g.pic.wary, "look it up on your phone while they wait: right answer, but they don't warm to you")
	_reset_pics()
	# walking off mid-question
	grp = _guest_group(); g = grp[0]; await _beside(g)
	_ask(g, grp); await _secs(0.1)
	await _put(Vector3(-0.5, 0, 6.3)); await _secs(0.2); await _wait_free()
	_check(asking.is_empty() and g.pic.wary, "walk away while they're asking: rude, and they remember")
	_reset_pics()
	# word gets around
	var ga := _find("g1"); var gb := _find("g2")
	ga.pic.told = ["job"]
	_check(_gossip([ga, gb]).any(func(o): return o[1][0][0] == ga and o[1][0][1] == "g_job") and not _gossip([gb, ga]).any(func(o): return o[1][0][0] == gb), "someone who knows your job, standing with someone who doesn't: they can pass it on")
	_reset_pics()
	var _w8 := clock
	while (ga.busy or gb.busy) and clock - _w8 < 30.0: await _secs(0.1)   # (never forever)
	gb.spot = ga.spot
	ga.pic.told = ["from"]; ga.pic.met = true
	await _talk("gossip", [[ga, "g_from"], [gb, "r_really"]])
	_check("from" in gb.pic.told and "from" in gb.pic.second and played.has(_vk(ga) + "_g_from") and played.has(_vk(gb) + "_r_really"), "저 분, LA에서 왔대요: now the other one knows, secondhand")
	_check(gb.glance > 0.0, "and they look over at you")
	var left := Cover.FACTS.filter(func(f): return not (f.k in gb.pic.told))
	_check(not left.any(func(f): return f.k == "from"), "they won't ask you where you're from")
	await _beside(gb)
	_ask(gb, [gb], "from"); await _secs(0.1); await _wait_free()
	_check(ask_label.text == CHECK.from and played.has(_vk(gb) + "_c_from"), "but they may check it: " + ask_label.text)
	picked = [["yn", 0]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(gb.pic.ok and not ("from" in gb.pic.second) and not gb.pic.wary, "네 is enough: now they've heard it from you")
	_reset_pics()
	gb.pic.told = ["job"]; gb.pic.second = ["job"]
	_ask(gb, [gb], "job"); await _secs(0.1); await _wait_free()
	picked = [["yn", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(gb.pic.wary and played.has(_vk(gb) + "_x_differ"), "say 아니요 to what they heard: 네? 다르게 들었는데요, and they're wary")
	_reset_pics()
	ga.pic.wary = true
	var _w9 := clock
	while (ga.busy or gb.busy) and clock - _w9 < 30.0: await _secs(0.1)   # (never forever)
	await _talk("gossip", [[ga, "g_odd"], [gb, "r_really"]])
	_check(gb.pic.wary, "and doubt travels too: 저 분, 좀 이상해요")
	_reset_pics()
	hold = false
	# people come and go
	clock = 34.9; await _secs(0.4)
	var g5 := _find("g5")
	_check(not g5.is_empty() and people.size() == 10 and g5.body.position.distance_to(ELEVATOR) < 3.5, "someone arrives late, out of the lift")
	var leaver: Dictionary = people.filter(func(o): return o.role == "guest" and not o.gone and o.id != "g5")[0]; leaver.busy = false
	leaver.body.position = SPOTS.elevator + Vector3(0.5, 0, 0.5); _leave(leaver)
	for i in 60:
		await _secs(0.1)
		if leaver.gone: break
	_check(leaver.gone, "someone leaves the party through the lift")
	var before := {}
	for p in people:
		if not p.gone and p.role in ["guest", "host"]: before[p.id] = p.body.position
	for p in people:
		if p.role == "guest" and not p.gone: p.timer = 0.0
	var inside := false
	for i in 40:
		await _secs(0.1)
		for p in people:
			if p.gone: continue
			var q: Vector3 = p.body.position
			if absf(q.x + 4.0) < 1.4 and absf(q.z + 1.6) < 0.4: inside = true
			if absf(q.x - 8.2) < 0.3 and absf(q.z + 1.0) < 2.0: inside = true
	var moved := 0
	for id in before:
		var p := _find(id)
		if p and p.body.position.distance_to(before[id]) > 1.0: moved += 1
	_check(moved >= 2 and not inside, "people drift between groups (%d moved), around the furniture" % moved)


func _t_chat() -> void:
	# Talk while they're chatting: they finish, then turn to you
	hold = true
	for p in people: p.busy = false
	_reset_pics(); skip_turn = true
	var tg := _guest_group(); var tw: Dictionary = tg[0]; await _beside(tw)
	var mate: Dictionary = tg[1] if tg.size() > 1 else _find("host")
	_talk("t", [[tw, "sq_cold"], [mate, "sa_cold"]]); await _secs(0.1)
	_check(tw.busy and talk_btn.visible, "they're mid-chat, and you still get a Talk button")
	talk_btn.pressed.emit(); await _secs(0.1)
	_check(not talk_wait.is_empty() or back, "tap it: they finish what they're saying first (or turn to you if they just did)")
	for i in 120:
		await _secs(0.1)
		if back: break
		if talk_wait.is_empty() and asking.is_empty() and _talk_target() == tw: talk_btn.pressed.emit()   # (someone else came up to you meanwhile: tap again)
	_check(back and asking == tw, "then they turn to you: your turn (back=%s asking=%s wait=%s busy=%s %.1f m)" % [back, asking.get("id", ""), talk_wait.get("id", ""), tw.busy, player.position.distance_to(tw.body.position)])
	_back_end(); await _secs(0.2)


func _t_heat() -> void:
	# heat: the more people doubt you, the closer security gets
	_reset_pics(); no_heat = false; heat_stage = 0; hunting = false
	var sh := _find("security"); var gsh := people.filter(func(o): return o.id in ASKERS and not o.gone)
	await _put(Vector3(-0.6, 0, 1.6))
	for i in 2: gsh[i].pic.doubt = 1
	await _secs(0.3)
	_check(heat_stage == 1 and played.has("h_heat1") and not sh.shadow, "a few people doubt you: the handler warns you, people are talking")
	for o in gsh: o.pic.checked = true   # (they'd come over to check you otherwise)
	for i in 2: gsh[i].pic.doubt = 2
	for i in 80:
		await _secs(0.1)
		if sh.shadow and player.position.distance_to(sh.body.position) < 4.0: break
	_check(heat_stage == 2 and sh.shadow and played.has("h_heat2") and player.position.distance_to(sh.body.position) < 4.0, "more of them: security leaves his post and keeps a few steps from you, watching (%.1f m)" % player.position.distance_to(sh.body.position))
	await _shot("g8_shadow")
	for o in gsh: o.pic.doubt = 0
	await _secs(0.3)
	_check(heat_stage == 0 and not sh.shadow and played.has("h_calm"), "it cools off: he backs off to his post")
	await _put(sh.body.position + (Vector3(8, 0, 0) if sh.body.position.x < 0 else Vector3(-8, 0, 0)))   # (far from him, so he can't reach you before we look)
	for i in 6: gsh[i].pic.doubt = 2
	for i in 20:
		await _secs(0.05)
		if heat_stage == 3: break
	_check(hunt_wait > 0.0, "and he takes a moment on his earpiece first: your head start")
	_check(heat_stage == 3 and hunting and played.has("h_heat3"), "the whole room doubts you: he comes for you, get to the lift (stage %d hunting=%s escorting=%s doubt %d)" % [heat_stage, hunting, escorting, _room_doubt()])
	hunting = false; hunted = false; heat_stage = 0; no_heat = true; sh.shadow = false; _send_back(sh); _reset_pics()


func _t_gun() -> void:
	# the pistol: two shots, whoever you hit drops; anyone who sees it panics
	_reset_pics(); hold = true
	for p in people: p.busy = false
	_bag_pick("gun")
	_check(ammo == MAG and gun_prop.visible and hand_btn.text == "Gun\n%d" % MAG, "take the gun from the bag: the hand button says Gun %d" % MAG)
	var sd := _find("security")
	await _put(Vector3(-0.6, 0, 2.0)); sd.body.position = player.position + Vector3(4.5, 0, 0)
	hunting = true; hunted = true; slots_taken.erase("%s:%d" % [sd.spot, sd.slot]); sd.slot = -1
	body_mesh.rotation.y = PI / 2   # (facing away: you still get him, he's the one after you)
	var wit: Array = people.filter(func(o): return not o.gone and o != sd and o.id in ASKERS and o.body.position.distance_to(player.position) < 10.0)
	_act("shoot"); await _secs(0.5)
	_check(sd.gone and "security" in downed and not hunting and ammo == MAG - 1 and played.has("shot"), "shoot: security drops, and he's not coming for you any more")
	_check(sd.body.rotation.x < -1.0, "he's lying on the floor")
	_check(wit.is_empty() or wit.all(func(o): return o.pic.doubt == 3), "everyone who saw it is alarmed (%d of them)" % wit.size())
	_check(played.has("h_shot"), "and your handler: what are you doing?! get out")
	var tg2: Dictionary = _guest_group()[0]; await _put(tg2.body.position + Vector3(0, 0, 3.0)); var to2: Vector3 = tg2.body.position - player.position
	body_mesh.rotation.y = atan2(-to2.x, -to2.z)
	ammo = 1; _act("shoot"); await _secs(0.3)
	_check(downed.size() == 2 and ammo == 0, "the next shot: whoever's in front of you; the last one, and you're out (hit %s)" % [downed])
	await _shot("g9_gun")
	# (put them back up for the rest of the tests)
	for q in downed.map(func(id): return _who_is(id)):
		q.gone = false; q.busy = false; q.body.rotation.x = 0.0; q.body.position.y = 0.0; q.body.collision_layer = 8
		_send_back(q)
	_bag_pick(""); downed.clear(); ammo = MAG; hunting = false; hunted = false; heat_stage = 0; _reset_pics()


func _t_english() -> void:
	# English mode: the words on screen in English (the voices stay Korean)
	_reset_pics(); hold = true; var eg: Dictionary = _guest_group()[0]; await _beside(eg)
	var _we := clock
	while eg.busy and clock - _we < 30.0: await _secs(0.1)
	english = true; ask_busy = false; _ask(eg, [eg], "", "from", 0); await _secs(0.1)
	_check(ask_label.text == "Where are you from?" and tile_box.get_children().any(func(b): return b.text == "from LA"), "English mode: their question and your pieces in English (%s)" % ask_label.text)
	await _shot("g11_english")
	_check(right_btn.visible, "and a Say the right answer button, for testing")
	await _wait_free(); right_btn.pressed.emit(); await _secs(0.2); await _wait_free()
	_check(played.has(_vk(eg) + "_x_ok") and eg.pic.ok, "tap it: you say the right answer, and they take to you (asking=%s back=%s %.1f m)" % [asking.get("id", ""), back, player.position.distance_to(eg.body.position)])
	asking = {}; back = false; ask_ui.visible = false; ask_busy = false; eg.busy = false; english = false; await _secs(0.2); _reset_pics()


func _t_items() -> void:
	no_ask = true   # (nobody interrupts: this is about your hands)
	# your things: the bag, the bartender's wine, the hand button
	_reset_pics(); hold = true; await _wait_free(); asking = {}; back = false; ask_busy = false; ask_ui.visible = false
	_check(hand == "" and inv == ["gun"] and hand_btn.visible and hand_btn.text == "Hand\nempty" and not gun_prop.visible, "your hand's empty, and the gun's in your bag")
	bag_btn.pressed.emit(); await _secs(0.15)
	_check(bag_open and bag_box.visible and not hand_btn.visible and bag_box.get_children().any(func(b): return b.text.begins_with("Gun")) and bag_box.get_children().any(func(b): return b.text == "Back"),
		"open the bag: your things and Back, and the hand button's out of the way")
	_bag_back(); await _secs(0.1)
	_check(not bag_open and hand_btn.visible, "Back: the hand button again")
	var bart := _find("bartender"); await _beside(bart); await _wait_free()
	if not asking.is_empty(): asking.busy = false; asking = {}; ask_ui.visible = false; ask_busy = false
	_check(_talk_target() == bart, "at the bar you can Talk to the bartender")
	_talk_to(bart); await _secs(0.1)
	_check(back and tile_map.has("와인 한 잔") and tile_map.has("주세요") and tile_map.size() == 2, "your pieces: 와인 한 잔 · 주세요")
	picked = [["b_wine", 0], ["b_wine", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(hand == "drink" and sips == SIPS and glass_prop.visible and played.has("bartender_r_wine") and hand_btn.text == "Wine\n10/10", "네, 여기 있습니다: the wine's in your hand (10 sips)")
	await _finger(hand_btn.get_global_rect().get_center(), 0.08)
	_check(sips == SIPS - 1 and played.has("sip"), "a quick tap with a finger on the hand button: a sip (sips=%d ring=%s)" % [sips, ring_open])
	await _finger(hand_btn.get_global_rect().get_center(), 0.7)
	_check(ring_open and sips == SIPS - 1, "hold it with a finger: the ring opens (ring=%s holding=%s hold_t=%.2f)" % [ring_open, holding, hold_t])
	var opt: Button = ring_box.get_children()[0] if ring_box.get_child_count() > 0 else null
	if opt: await _finger(opt.get_global_rect().get_center(), 0.08)
	_check(not ring_open and sips == SIPS - 2, "then tap Sip on the ring with a finger (sips=%d ring=%s)" % [sips, ring_open])
	sips = SIPS - 1
	_ring_show()
	_check(ring_open and ring_box.get_children().map(func(b): return b.text) == ["Sip", "Put down", "Drop", "Throw", "Offer"], "hold it: Sip · Put down · Drop · Throw · Offer")
	await _shot("g13_ring")
	var sip_b: Button = ring_box.get_children()[0]; sip_b.pressed.emit(); await _secs(0.1)
	_check(not ring_open and sips == SIPS - 2, "tap an option on the ring: it does it (Sip)")
	_ring_show(); touch_pos = (ring_box.get_children()[0] as Button).get_global_rect().get_center(); _ring_release(); await _secs(0.1)
	_check(not ring_open and sips == SIPS - 3, "or slide onto one and let go")
	_ring_show(); touch_pos = Vector2(5, 5); _ring_release(); await _secs(0.1)
	_check(ring_open, "let go anywhere else: the ring stays open")
	_world_tap(Vector2(400, 300)); _check(not ring_open, "tap the room: it closes")
	_act("put"); await _secs(0.1)
	_check(hand == "" and not ("drink" in inv) and placed.size() == 1 and placed[0].node.position.y > 1.0, "put it down: on the bar")
	_world_tap(cam.unproject_position(placed[0].node.global_position)); await _secs(0.1)
	_check(hand == "drink" and sips == SIPS - 3 and placed.is_empty(), "tap the glass: it's back in your hand")
	var n_smash := played.count("smash")
	await _clear_ask(); await _act("drop"); await _secs(0.4)
	_check(hand == "" and not ("drink" in inv) and played.count("smash") == n_smash + 1, "drop it: it smashes at your feet")
	inv.append("drink"); hand = "drink"; sips = SIPS; _props()
	var og: Dictionary = _guest_group()[0]; await _beside(og); await _wait_free()
	if not asking.is_empty(): asking.busy = false; asking = {}; ask_ui.visible = false; ask_busy = false
	og.busy = false
	_act("offer"); await _secs(0.1)
	_check(offer_mode and offer_rings.any(func(x): return x[0] == og), "offer: a ring under everyone close enough (%d)" % offer_rings.size())
	_check(not ring_open, "(no ring in the way)")
	_world_tap(cam.unproject_position(og.body.position + Vector3(0, 0.8, 0))); await _secs(0.3)
	_check(not offer_mode and not ("drink" in inv) and (played.has(_vk(og) + "_r_thanks") or og.busy), "tap one: they take it, 감사합니다 (offer=%s inv=%s hand=%s)" % [offer_mode, inv, hand])
	await _wait_free()
	if not asking.is_empty(): asking.busy = false; asking = {}; ask_ui.visible = false; ask_busy = false
	back = false; inv.append("drink"); hand = "drink"; _props(); n_smash = played.count("smash")
	await _act("throw"); await _secs(0.3)
	_check(hand == "" and played.count("smash") == n_smash + 1, "throw it: it smashes over there")
	_bag_show(); _bag_pick("gun")
	_check(hand == "gun" and gun_prop.visible and hand_btn.text.begins_with("Gun"), "from the bag: the gun in your hand")
	_bag_pick(""); _reset_pics(); distract_t = 0.0


func _t_mission() -> void:
	no_ask = false
	# the mission: through the assistant, into the back room, the broker's check, the drive
	_reset_pics(); hold = true; await _wait_free(); asking = {}; back = false; ask_busy = false; ask_ui.visible = false
	for p in people: p.busy = false
	var gasst := _find("assistant"); var gbrk := _find("broker")
	await _beside(gasst); await _wait_free()
	if not asking.is_empty(): asking.busy = false; asking = {}; ask_ui.visible = false; ask_busy = false   # (she'd started asking you something herself)
	back = false; _talk_to(gasst); await _secs(0.1)
	_check(back and tile_map.has("최 사장님하고") and tile_map.has("약속 있어요"), "Talk: you can say 최 사장님하고 약속 있어요")
	picked = [["b_appt", 0], ["b_appt", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(asking == gasst and ask_fact.k == "name", "the assistant checks who you are: " + ask_text)
	picked = _right_pieces(ask_fact); await _say_it()
	for i in 400:
		await _secs(0.1)
		if door_open: break
	_check(played.has("assistant_appt_wait") and gbrk.inside and door_open, "잠깐만요: she fetches him, he goes into the back room, and the door opens")
	await _put(DOOR_IN + Vector3(1.5, 0, 0)); await _secs(0.5)
	_check(played.has("assistant_appt_in"), "she shows you in: 들어가세요")
	await _put(DOOR_IN + Vector3(-0.2, 0, 0))
	for i in 30:
		await _secs(0.1)
		if in_back: break
	_check(in_back and player.position.x < -40.0, "through the door: the back room, and the party's out of sight")
	await _secs(0.6); await _shot("g10_back")
	await _put(gbrk.body.position + Vector3(0, 0, 1.3))
	for i in 60:
		await _secs(0.1)
		if asking == gbrk and deal_ask: break
	_check(asking == gbrk and deal_ask and ask_fact.k == "item" and played.has("broker_deal_hi"), "어서 오세요, and he checks you: " + ask_text)
	for i in 3:
		for j in 60:
			if asking == gbrk and not ask_busy: break
			await _secs(0.1)
		if asking != gbrk: break
		picked = _right_pieces(ask_fact); await _say_it(); await _secs(0.3)
	for i in 60:
		await _secs(0.1)
		if has_drive: break
	_check(has_drive and hand == "drive" and drive_prop.visible and "drive" in inv and played.has("broker_deal_ok") and played.has("h_got"), "all three right: 좋습니다. 여기 있습니다. The drive is yours")
	await _put(BR + Vector3(4.8, 0, 0))
	for i in 30:
		await _secs(0.1)
		if not in_back: break
	_check(not in_back and player.position.x > -10.0, "and back out through the door to the party")
	# wrong, and he shoots you
	has_drive = false; inv.erase("drive"); hand = ""; _props(); deal_step = -1
	await _put(BR_ENTRY); in_back = true
	await _put(gbrk.body.position + Vector3(0, 0, 1.3))
	for i in 60:
		await _secs(0.1)
		if asking == gbrk and deal_ask and not ask_busy: break
	picked = [["price", 0]]; await _say_it()
	for i in 100:
		await _secs(0.1)
		if done and end_ui.visible: break
	_check(killed and played.has("broker_deal_bad") and played.has("killed") and end_text.text.contains("KILLED"), "a wrong answer: 당신, 누구야? and he shoots you")
	print(end_text.text)
	# (back up, back to the party, for the rest of the tests)
	killed = false; done = false; end_ui.visible = false; body_mesh.rotation.x = 0.0; in_back = false; has_drive = false; inv.erase("drive"); hand = ""; _props()
	deal_step = -1; deal_ask = false; gate = ""; gate_by = {}; door_open = false; fade.color.a = 0.0; asking = {}; ask_busy = false; ask_ui.visible = false
	gbrk.away = false; gbrk.inside = false; gbrk.busy = false; gbrk.body.position = DOOR_IN + Vector3(1.0, 0, 0); _send_back(gbrk)
	gasst.usher = false; gasst.busy = false
	await _put(Vector3(-0.6, 0, 2.0)); _reset_pics()
	# the real Eric Shin turns up
	var rasst := _find("assistant"); rasst.busy = false
	real_stage = 0; no_real = false; var c0 := clock
	clock = REAL_WARN + 0.05; await _secs(0.2)
	_check(real_stage == 1 and played.has("h_real1"), "the handler: the real Eric Shin is downstairs, you've got about a minute")
	clock = REAL_AT + 0.05; await _secs(0.3)
	_check(real_stage >= 2 and not real.is_empty() and played.has("h_real2"), "and he steps out of the lift")
	for i in 400:
		await _secs(0.1)
		if blown: break
	_check(blown and played.has("buyer_b_self") and played.has("assistant_real_huh") and rasst.pic.doubt == 3 and played.has("h_blown"),
		"he tells the assistant who he is: 네? 에릭 신 씨는 벌써 오셨는데요... and you're blown")
	await _shot("g12_real")
	# in the back room when it happens: someone tells the broker
	await _put(BR_ENTRY); in_back = true; gbrk.inside = true; gbrk.away = true; gbrk.busy = true; gbrk.body.position = BR_SEAT; has_drive = false
	blow_t = 0.5
	for i in 100:
		await _secs(0.1)
		if done and end_ui.visible: break
	_check(killed and end_text.text.contains("KILLED") and end_text.text.contains("real Eric Shin showed up and blew your cover"), "in the back room without the drive: word reaches him, and he shoots you")
	killed = false; done = false; end_ui.visible = false; body_mesh.rotation.x = 0.0; in_back = false; fade.color.a = 0.0; asking = {}; ask_busy = false; ask_ui.visible = false
	deal_step = -1; deal_ask = false; blown = false; blow_t = 0.0; no_real = true; real_stage = 0; hunting = false; hunted = false
	real.gone = true; real.body.queue_free(); real = {}
	gbrk.away = false; gbrk.inside = false; gbrk.busy = false; gbrk.body.position = DOOR_IN + Vector3(1.0, 0, 0); _send_back(gbrk)
	clock = c0; await _put(Vector3(-0.6, 0, 2.0)); _reset_pics()
	for p in people: p.tell = false; p.errand = false
	await _secs(4.0)   # (an alarm already on its way to security can still land: call him off)
	hunting = false; hunted = false; escorting = false; done = false; end_ui.visible = false
	var s3 := _find("security"); s3.busy = false; s3.shadow = false; _send_back(s3); _reset_pics()
	# the host can take you in too, if she likes you; a guest has no idea what you mean
	var hst2 := _find("host"); await _beside(hst2)
	no_ask = true; await _clear_ask()
	hst2.pic.ok = true; var _w10 := clock
	while (hst2.busy) and clock - _w10 < 30.0: await _secs(0.1)   # (never forever)
	_talk_to(hst2); picked = [["b_appt", 0], ["b_appt", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(played.has("host_appt_go") and gate == "host" and hst2.usher, "the host likes you: 아, 네! 같이 가요, and she takes you to him")
	gate = ""; gate_by = {}; hst2.usher = false; hst2.busy = false; _send_back(hst2); gbrk.away = false; gbrk.busy = false; _send_back(gbrk)
	var gg: Dictionary = _guest_group()[0]; var _w11 := clock
	while (gg.busy) and clock - _w11 < 30.0: await _secs(0.1)   # (never forever)
	await _beside(gg); ask_busy = false; _talk_to(gg); await _secs(0.1); picked = [["b_appt", 0], ["b_appt", 1]]; await _say_it(); await _secs(0.2); await _wait_free()
	_check(played.has(_vk(gg) + "_appt_huh") and gg.pic.doubt >= 1, "say it to a guest: 네? 최 사장님이요? and they wonder about you (%s doubt=%d back=%s asking=%s)" % [gg.id, gg.pic.doubt, back, asking.get("id", "")])
	_reset_pics()


func _t_exit() -> void:
	# leave by the lift: the debrief
	hold = true
	for p in people: p.busy = false
	await _beside(_find("bartender")); _tag("bartender")   # (marks of its own, so this runs alone too)
	await _beside(_find("host")); _tag("host")
	var sch := _find("security"); sch.body.position = Vector3(8.5, 0, -5.5)
	hunting = true; hunted = true; slots_taken.erase("%s:%d" % [sch.spot, sch.slot]); sch.slot = -1
	await _put(Vector3(-6.0, 0, 6.6)); await _secs(0.2)
	_check(leave_btn.visible and hunting, "security's coming, but you made the lift: you can leave (done=%s escorting=%s asking=%s at %s)" % [done, escorting, asking.get("id", ""), str(player.position)])
	_check(player.position.z < 7.0, "and the doors are solid: you can't walk out of the building")
	var lpe: float = (lift_pad.material_override as StandardMaterial3D).emission_energy_multiplier
	_check(lpe != 0.6, "the lift's pad pulses while security's after you")
	await _finish(); await _secs(0.3)
	await _secs(0.2)
	_check(sub.get_global_rect().position.x > 0.0 and sub.get_global_rect().end.x < get_viewport().get_visible_rect().size.x, "the handler's subtitle sits on screen")
	_check(done and end_ui.visible and end_text.text.contains("Debrief") and end_text.text.contains("김 대표님") and end_text.text.contains("right")
		and end_text.text.contains("바텐더 (bartender): right") and end_text.text.contains("not marked"), "the debrief: which of your marks were right")
	_check(end_text.text.contains("You got out before security reached you"), "and the debrief says you got away")
	await _shot("g4_end")
	print(end_text.text)
	# caught: he walks you out
	done = false; end_ui.visible = false; hunted = false
	var sc2 := _find("security")
	await _put(Vector3(-0.6, 0, 2.6)); sc2.busy = false; sc2.body.position = player.position + Vector3(3.0, 0, -1.0)
	hunting = true; hunted = true
	for i in 300:
		await _secs(0.1)
		if done and end_ui.visible: break
	_check(played.has("security_x_stop"), "he reaches you: 잠깐만요, 손님")
	_check(done and end_text.text.contains("Escorted out") and player.position.distance_to(OUT_AT) < 0.6, "and walks you out to the lift: escorted out (done=%s escorting=%s hunting=%s %.1f m from the lift, sec %.1f m away busy=%s, text starts '%s')" % [done, escorting, hunting, player.position.distance_to(OUT_AT), player.position.distance_to(sc2.body.position), sc2.busy, end_text.text.substr(0, 30).replace("
", " ")])
	print(end_text.text)


func _t_danger() -> void:
	# blend in: a glass in your hand (even empty) and a slip only counts half the time
	no_ask = true
	var bg: Dictionary = _guest_group()[0]
	var n_dry := 0; var n_wet := 0
	for i in 80: bg.pic.doubt = 0; _slip(bg); n_dry += bg.pic.doubt
	inv.append("drink"); hand = "drink"; sips = 0; _props()
	for i in 80: bg.pic.doubt = 0; _slip(bg); n_wet += bg.pic.doubt
	_check(n_dry == 80 and n_wet > 20 and n_wet < 60, "a slip always counts; with a glass in hand (even empty) about half the time (%d of 80)" % n_wet)
	_reset_pics()
	# tipsy: one glass and you're fine; after that slower, staggering, the view sways
	drunk = SIPS
	_check(_tipsy() == 0.0, "one glass: you're fine")
	await _put(Vector3(-6.0, 0, 0.0)); var p0 := player.position
	joy_vec = Vector2(1, 0); await _secs(1.0); joy_vec = Vector2.ZERO
	var sober := player.position.distance_to(p0)
	drunk = SIPS * 3
	await _put(Vector3(-6.0, 0, 0.0)); p0 = player.position
	joy_vec = Vector2(1, 0); await _secs(1.0); joy_vec = Vector2.ZERO
	var tipsy_d := player.position.distance_to(p0)
	_check(_tipsy() == 1.0 and tipsy_d < sober * 0.8, "three glasses: you walk slower (%.1f m against %.1f sober)" % [tipsy_d, sober])
	await _secs(0.3)
	_check(absf(cam.rotation.z) > 0.001 and absf(body_mesh.rotation.z) > 0.001, "and you lean, and the view sways (cam roll %.3f)" % cam.rotation.z)
	await _shot("g14_drunk")
	drunk = 0; await _secs(0.2)
	# security's gun: on his hip; fire a shot and it comes out
	var sg := _find("security")
	_check(holster != null and holster.position.y < 0.95, "security has a gun on his hip")
	_bag_pick("gun"); var vg: Dictionary = _guest_group()[0]; await _beside(vg)
	var tv: Vector3 = vg.body.position - player.position; body_mesh.rotation.y = atan2(-tv.x, -tv.z)
	force_hit = 0
	sg.body.position = Vector3(8.5, 0, -5.5); hunting = false   # (he's across the room)
	await _put(Vector3(-6.0, 0, 6.5)); body_mesh.rotation.y = PI   # (by the lift, facing the wall: a shot at nobody in particular)
	ammo = MAG; downed.clear()
	_shoot()
	for i in 40:
		await _secs(0.1)
		if armed: break
	_check(armed and played.has("security_x_freeze") and holster.position.y > 0.95, "fire a shot: 멈춰!, and his gun comes out (target %s)" % [downed])
	for i in 60:
		await _secs(0.1)
		if played.has("miss"): break
	_check(played.has("miss") and hits == 0 and not killed, "he shoots at you (that one missed)")
	force_hit = 1
	for i in 80:
		await _secs(0.1)
		if done and end_ui.visible: break
	_check(shot_dead and hits == 2 and end_text.text.contains("SHOT BY SECURITY"), "two hits: shot by security")
	_check(again_btn.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y and again_btn.is_visible_in_tree(), "the debrief's Again button fits on screen (bottom %.0f of %.0f)" % [again_btn.get_global_rect().end.y, get_viewport().get_visible_rect().size.y])
	await _shot("g15_shot_debrief")
	for id in downed:
		var q := _who_is(id); q.gone = false; q.busy = false; q.body.rotation.x = 0.0; q.body.position.y = 0.0; q.body.collision_layer = 8; _send_back(q)
	await _fresh()
	# walking you out: you can still shoot him
	var se := _find("security"); se.body.position = player.position + Vector3(1.0, 0, 0)
	_caught(se); await _secs(1.5)
	_check(escorting, "(he's walking you out)")
	_bag_pick("gun"); _act("shoot"); await _secs(0.4)
	_check(se.gone and not escorting and not done, "shoot him while he walks you out: he drops, and you're free")
	se.gone = false; se.busy = false; se.body.rotation.x = 0.0; se.body.position.y = 0.0; se.body.collision_layer = 8; _send_back(se); downed.clear()
	no_ask = false


func _fresh() -> void:   # a clean party: nobody in the middle of anything, everyone in their place, you in the middle of the room
	hold = true; no_ask = false
	await _wait_free()
	asking = {}; back = false; ask_busy = false; ask_ui.visible = false; ask_check = false; deal_ask = false; gate_check = false; talk_wait = {}; talk_btn.text = "Talk"
	hunting = false; hunted = false; escorting = false; hunt_wait = 0.0; done = false; killed = false; end_ui.visible = false; fade.color.a = 0.0; body_mesh.rotation.x = 0.0
	heat_stage = 0; distract_t = 0.0; blow_t = 0.0; blown = false; skip_turn = true; english = false; en_btn.text = "English: off"
	in_back = false; door_open = false; gate = ""; gate_by = {}; deal_step = -1; has_drive = false; back_door.position.z = 2.5
	if not real.is_empty() and not real.gone: real.gone = true; real.body.queue_free()
	real = {}; real_stage = 0
	_offer_end(); _ring_close(); bag_open = false; inv = ["gun"]; hand = ""; sips = 0; ammo = MAG; downed.clear(); _props()
	armed = false; hits = 0; shot_dead = false; drunk = 0; force_hit = -1; _holster_hip(); hurt.color.a = 0.0
	for g in placed: g.node.queue_free()
	placed.clear()
	if phone_open: _toggle_phone()
	for p in people:
		if p.gone: continue
		p.busy = false; p.coming = false; p.came = false; p.errand = false; p.tell = false; p.following = false; p.shadow = false
		p.away = false; p.inside = false; p.usher = false; p.glance = 0.0; p.look_t = 0.0; p.speed = 1.4
		p.body.rotation.x = 0.0; p.body.position.y = 0.0; p.body.collision_layer = 8; p.body.velocity = Vector3.ZERO
		if p.leaving: continue
		if p.slot < 0 or p.spot == "": _send_back(p); p.errand = false
		if p.slot >= 0: p.body.position = _slot_pos(p.spot, p.slot)
	_reset_pics()
	await _put(Vector3(-0.5, 0, 6.3)); await _secs(0.2)   # (the empty space by the lift: nobody notices you there)
