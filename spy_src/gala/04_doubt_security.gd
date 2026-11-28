# ---------------------------------------------------------------- what they think of you, word getting round, security

func _doubt(o: Dictionary, n: int) -> void:   # curious (1) · doubtful (2) · alarmed (3)
	if not (o.id in ASKERS): return
	o.pic.doubt = clampi(o.pic.doubt + n, 0, 3); o.pic.wary = o.pic.doubt > 0
	if n > 0: o.pic.ok = false; o.calm_t = 0.0   # something new looked odd
	if o.pic.doubt < 2: o.pic.checked = false
	if o.pic.doubt < 3: o.pic.told_sec = false


func _doubters(dt: float) -> void:   # doubt shows in what people do
	if done: return
	var sec := _find("security")
	for p in people:
		if p.gone or p.leaving or not (p.id in ASKERS) or p.away or p.usher: continue
		if p.following: _follow(p, dt); continue
		var d: int = p.pic.doubt
		if d > 0:   # keep out of their way and it cools, a step at a time; what they heard stays
			if player.position.distance_to(p.body.position) > 6.0:
				p.calm_t += dt
				if p.calm_t >= COOL: p.calm_t = 0.0; _doubt(p, -1); d = p.pic.doubt
			else: p.calm_t = 0.0
		if p.coming:   # doubtful: they come over to check you
			var gap: Vector3 = player.position - p.body.position; gap.y = 0
			p.come_t -= dt
			if d < 2 or p.come_t <= 0.0: _send_back(p); continue
			if gap.length() > 1.3: p.goto = player.position; _walk(p, dt)
			else:
				p.body.velocity = Vector3.ZERO; p.body.rotation.y = atan2(-gap.x, -gap.z)
				if asking.is_empty() and not ask_busy: _come_check(p)
			continue
		if p.tell:   # alarmed, no room by security: they go right up to him
			if not sec or d < 3: p.tell = false; _send_back(p); continue
			var gs: Vector3 = sec.body.position - p.body.position; gs.y = 0
			p.tell_t += dt
			if gs.length() > 2.0 and p.tell_t < 6.0: p.goto = sec.body.position; p.coming = true; _walk(p, dt); p.coming = false   # (or as close as they can get)
			elif not sec.busy and not p.busy: p.tell = false; p.pic.told_sec = true; _tell_sec(p, sec)
			continue
		if p.busy: continue
		if p.errand:
			if not _at(p): _walk(p, dt)
			elif d < 3 or p.pic.told_sec: p.errand = false
		if d == 1 and _at(p) and p.glance == 0.0 and player.position.distance_to(p.body.position) < 6.0 and randf() < dt * 0.5:
			p.glance = randf_range(1.0, 1.8)   # curious: they keep looking you over
		if d == 2 and not p.pic.checked and asking.is_empty() and _at(p):
			p.coming = true; p.come_t = 20.0
			slots_taken.erase("%s:%d" % [p.spot, p.slot]); p.slot = -1
		if d >= 3 and not p.pic.told_sec and sec and _at(p):   # alarmed: they tell security
			if p.spot != sec.spot:
				if _has_room(sec.spot): _go(p, sec.spot); p.errand = true
				else: p.tell = true; p.tell_t = 0.0; slots_taken.erase("%s:%d" % [p.spot, p.slot]); p.slot = -1
			elif _at(sec) and not sec.busy:
				p.pic.told_sec = true; p.errand = false
				_talk("alarm", [[p, "al_sec"], [sec, "r_yes"]])


func _room_doubt() -> int:   # everyone's doubt about you, added up
	var n := 0
	for p in people:
		if not p.gone and p.id in ASKERS: n += p.pic.doubt
	return n


func _heat(dt: float) -> void:   # the more of the room doubts you, the closer security gets
	if done or escorting or no_heat or armed: return
	var sec := _find("security")
	if sec.is_empty(): return
	var h := _room_doubt()
	var st := 0
	for t in HEAT:
		if h >= t: st += 1
	if hunting: st = 3
	if st > heat_stage:
		heat_stage = st
		if st == 1:
			_handler("h_heat1"); sec.glance = 4.0
		elif st == 2:
			_handler("h_heat2"); sec.shadow = true; sec.timer = INF; sec.glance = 4.0
			slots_taken.erase("%s:%d" % [sec.spot, sec.slot]); sec.slot = -1
		elif st == 3 and not hunting:
			_handler("h_heat3"); sec.shadow = false; hunt_wait = 2.0
			hunting = true; hunted = true; sec.timer = INF
			slots_taken.erase("%s:%d" % [sec.spot, sec.slot]); sec.slot = -1
	elif st < heat_stage and st <= 1 and not hunting:   # it's cooled off
		if heat_stage >= 2 and sec.shadow:
			sec.shadow = false; _handler("h_calm"); _send_back(sec)
		heat_stage = st
	if sec.shadow and not sec.busy and distract_t <= 0.0 and not in_back:   # he keeps a few steps off, watching you
		var off: Vector3 = sec.body.position - player.position; off.y = 0
		if off.length() < 0.1: off = Vector3(0, 0, -1)
		var spot: Vector3 = player.position + off.normalized() * 3.0
		var to_me: Vector3 = player.position - sec.body.position; to_me.y = 0
		if off.length() > 3.6:
			sec.goto = spot; sec.speed = 2.2; sec.coming = true; _walk(sec, dt); sec.coming = false
		else:
			sec.body.velocity = Vector3.ZERO
		if to_me.length() > 0.1: sec.body.rotation.y = lerp_angle(sec.body.rotation.y, atan2(-to_me.x, -to_me.z), 1.0 - exp(-5.0 * dt))


func _holster_hip() -> void:
	if holster: holster.position = Vector3(0.33, 0.85, 0.05); holster.rotation = Vector3.ZERO


func _draw_gun(sec: Dictionary) -> void:   # he heard the shot: 멈춰! and the gun comes out
	armed = true; hunting = false; distract_t = 0.0; sec.shadow = false; sec.timer = INF
	if escorting: escorting = false
	if sec.slot >= 0: slots_taken.erase("%s:%d" % [sec.spot, sec.slot]); sec.slot = -1
	if holster: holster.position = Vector3(0.3, 1.05, -0.4); holster.rotation = Vector3(PI / 2, 0, 0)
	sec_fire_t = 1.2
	_plg("%s draws a gun: 멈춰!" % _desc(sec))
	sec.busy = true; await _line(sec, "x_freeze"); sec.busy = false


func _armed_tick(dt: float) -> void:   # he shoots at you, about every second and a half; half of them hit; two and you're dead
	if not armed or done or killed: return
	var sec := _find("security")
	if sec.is_empty(): armed = false; return
	if in_back:   # he won't follow you in: he waits outside the door
		var w: Vector3 = DOOR_IN + Vector3(1.6, 0, 0); var g: Vector3 = w - sec.body.position; g.y = 0
		if g.length() > 0.5: sec.goto = w; sec.speed = HUNT; sec.coming = true; _walk(sec, dt); sec.coming = false
		sec_fire_t = maxf(sec_fire_t, 1.0); return
	var to: Vector3 = player.position - sec.body.position; to.y = 0
	sec.body.velocity = Vector3.ZERO
	if to.length() > 0.1: sec.body.rotation.y = atan2(-to.x, -to.z)
	sec_fire_t -= dt
	if sec_fire_t > 0.0 or sec.busy: return
	sec_fire_t = 1.5
	var snd := AudioStreamPlayer3D.new(); snd.stream = _shot_sound(); snd.position = sec.body.position + Vector3(0, 1, 0); add_child(snd); snd.play()
	var hit := (randf() < 0.5) if force_hit < 0 else force_hit == 1
	if not hit: played.append("miss"); _plg("He fires, and misses."); return
	hits += 1; played.append("hit"); _plg("He fires. You're hit (%d)." % hits)
	hurt.color.a = 0.55; create_tween().tween_property(hurt, "color:a", 0.0, 0.6)
	if hits >= 2: _shot_dead()


func _shot_dead() -> void:
	killed = true; shot_dead = true
	create_tween().tween_property(body_mesh, "rotation:x", -PI / 2, 0.3)
	await get_tree().create_timer(1.4).timeout
	_finish()


func _hunt(dt: float) -> void:   # security comes for you: get to the lift first
	var sec := _find("security")
	if not hunting or done or sec.is_empty() or sec.busy or distract_t > 0.0 or in_back or armed: return
	var gap: Vector3 = player.position - sec.body.position; gap.y = 0
	if hunt_wait > 0.0:   # a hand to his earpiece, eyes on you: go, now
		hunt_wait -= dt; sec.body.velocity = Vector3.ZERO
		if gap.length() > 0.1: sec.body.rotation.y = lerp_angle(sec.body.rotation.y, atan2(-gap.x, -gap.z), 1.0 - exp(-5.0 * dt))
		return
	if gap.length() > 1.1:
		sec.goto = player.position; sec.speed = HUNT; sec.coming = true; _walk(sec, dt); sec.coming = false
	else: _caught(sec)


func _caught(sec: Dictionary) -> void:   # 잠깐만요, 손님: and he walks you out
	hunting = false; escorting = true; sec.busy = true
	if not asking.is_empty(): _ask_end("walked")
	if phone_open: _toggle_phone()
	player.velocity = Vector3.ZERO
	var d: Vector3 = player.position - sec.body.position
	sec.body.rotation.y = atan2(-d.x, -d.z)
	await _line(sec, "x_stop")


func _escort(dt: float) -> void:   # the two of you walk to the lift, his hand at your elbow
	var sec := _find("security")
	var to := OUT_AT - player.position; to.y = 0
	if to.length() < 0.3:
		escorting = false; _finish(true); return
	if sec and sec.busy and sec.get("said", "") != "": return   # he says his piece first
	player.velocity = to.normalized() * 1.4; player.move_and_slide(); player.position.y = 0
	body_mesh.rotation.y = atan2(-to.x, -to.z)
	if sec:
		var at: Vector3 = player.position + to.normalized().rotated(Vector3.UP, PI / 2) * 0.7
		sec.body.position = sec.body.position.lerp(at, 1.0 - exp(-6.0 * dt)); sec.body.rotation.y = body_mesh.rotation.y


func _tell_sec(p: Dictionary, sec: Dictionary) -> void:
	await _talk("alarm", [[p, "al_sec"], [sec, "r_yes"]])
	if not p.gone: _send_back(p)


func _come_check(p: Dictionary) -> void:   # they come back to whatever made them doubt you
	p.coming = false; p.came = true; p.pic.checked = true
	reactions.append("came")
	var c: Dictionary = p.pic.concern
	var k: String = c.get("k", "")
	if k == "invited" and p.role == "host": k = ""   # she knows who she invited
	if k != "" and k in p.pic.told: _ask(p, [p], k); return   # they heard something about it: "so you're…?"
	if k != "": _ask(p, [p], "", k, c.get("q", -1)); return   # the same question again
	_ask(p, [p])   # they don't know what was odd: an ordinary question


func _linger(dt: float) -> void:   # stay by a group for a moment and they react, each in their own way
	var near := ""
	if asking.is_empty():
		for p in people:
			if p.gone or p.leaving or p.spot == "elevator" or p.spot == "" or not _at(p): continue
			if player.position.distance_to(p.body.position) < NOTICE: near = p.spot; break
	if near != linger_spot: linger_spot = near; linger_t = 0.0
	elif near != "": linger_t += dt
	if near != "" and linger_t > LINGER and not reacted.has(near):
		reacted[near] = true; _react(near)
	for s in reacted.keys():   # walk away and come back: they can react again
		if player.position.distance_to(SPOTS[s]) > 4.0: reacted.erase(s)


func _react(spot: String) -> void:
	var m := people.filter(func(o): return not o.gone and not o.leaving and o.spot == spot)
	if m.is_empty(): return
	if m.any(func(o): return o.pic.doubt >= 2):   # someone here doubts you: backs turn, voices drop
		for o in m: o.glance = -4.0
		reactions.append("cold"); return
	if m.any(func(o): return o.pic.doubt == 1):   # curious about you: they look you over, nobody asks
		for o in m.filter(func(o): return o.pic.doubt == 1 and not o.busy): o.glance = 2.5
		reactions.append("look"); return
	var fresh := m.filter(func(o): return not o.pic.met and o.id in ASKERS and not o.busy)
	var r := randf()
	if fresh and r < 0.65:
		var who: Dictionary = fresh.pick_random()
		if who.pic.second and randf() < 0.6: _ask(who, m, who.pic.second.pick_random()); reactions.append("check"); return
		_ask(who, m); reactions.append("ask"); return
	if fresh.is_empty() or r < 0.85:   # a look (or a nod, if they've met you), then back to their talk
		var lookers := m.filter(func(o): return not o.busy); lookers.shuffle()
		for o in lookers.slice(0, randi_range(1, 2)): o.glance = randf_range(1.2, 2.2)
		reactions.append("glance"); return
	reactions.append("ignore")   # they don't care who you are
