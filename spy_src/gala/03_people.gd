# ---------------------------------------------------------------- the people: where they go, what they say to each other

func _cast() -> void:   # who wears what is shuffled every party: you can't learn people by colour
	var pal := PALETTE.duplicate(); pal.shuffle()
	var looks := {}
	var ids := ["host", "broker", "assistant", "security", "bartender", "g1", "g2", "g3", "g4", "g5", "g6"]
	for i in ids.size(): looks[ids[i]] = pal[i][0]; look_names[ids[i]] = pal[i][1]
	for id in ["host", "broker", "assistant", "security", "bartender", "g1", "g2", "g3", "g4"]:
		_spawn(id, looks[id], false)
	set_meta("looks", looks)


func _spawn(id: String, c: Color, late: bool) -> Dictionary:
	var b := CharacterBody3D.new(); b.collision_layer = 8; b.collision_mask = 1; add_child(b)
	var s := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.28; cap.height = 1.5; s.shape = cap; s.position.y = 0.75; b.add_child(s)
	var look := _look(c); b.add_child(look)
	var au := AudioStreamPlayer3D.new(); au.position.y = 1.5; au.unit_size = 2.4; au.max_distance = 18.0; au.max_db = 2.0
	au.attenuation_filter_cutoff_hz = 2500.0; au.attenuation_filter_db = -30.0; b.add_child(au)   # far voices go muffled
	var ko := _sign("", 40, Vector3(0, 2.4, 0), b)
	var tag := _sign("", 30, Vector3(0, -0.15, 0), b); tag.modulate = Color(1, 0.85, 0.3); tag.visible = false
	var role := id if id in ROLES else "guest"
	var p := {"id": id, "role": role, "body": b, "look": look, "audio": au, "ko": ko, "tag": tag, "spot": "", "slot": -1,
		"timer": randf_range(2.0, 12.0), "veer": 0.0, "veer_t": 0.0, "coming": false, "came": false, "errand": false, "goto": Vector3.ZERO, "come_t": 0.0, "calm_t": 0.0, "tell": false, "chk_t": 0.0, "tell_t": 0.0, "speed": 1.4, "following": false, "follow_t": 0.0, "shadow": false, "away": false, "inside": false, "usher": false, "said_in": false, "look_t": 0.0, "look_pt": Vector3.ZERO, "chk_d": INF, "stuck": 0, "busy": false, "leaving": false, "gone": false, "glance": 0.0,
		"pic": {"met": false, "told": [], "second": [], "ok": false, "wary": false, "doubt": 0, "checked": false, "told_sec": false, "vouched": false, "asked": [], "concern": {}}}   # their picture of you
	people.append(p)
	if id == "security":   # a gun on his hip, always
		holster = MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(0.08, 0.24, 0.16); holster.mesh = hb
		holster.material_override = _mat(Color(0.05, 0.05, 0.05)); look.add_child(holster); _holster_hip()
	if late:
		b.position = ELEVATOR; _go(p, "elevator")
		p.timer = randf_range(3.0, 5.0)
	elif id == "bartender":
		b.position = Vector3(9.1, 0, -1.0); p.spot = "bar"; p.slot = 9; p.timer = INF
	else:
		var sp: String = _pick_spot(p)
		_go(p, sp); b.position = _slot_pos(sp, p.slot)
	return p


func _slot_pos(spot: String, i: int) -> Vector3:
	if spot == "bar":   # along the front of the counter
		return Vector3(7.1, 0, -2.4 + i * 0.9) if i < 4 else Vector3(9.1, 0, -1.0)
	var r := 1.15 if spot == "buffet" else 0.85
	if spot == "buffet":   # on the open sides of the table
		return SPOTS.buffet + [Vector3(-2.1, 0, 0), Vector3(2.1, 0, 0), Vector3(-0.8, 0, 1.0), Vector3(0.8, 0, 1.0)][i]
	if spot == "lounge":   # between the sofas
		return SPOTS.lounge + [Vector3(0, 0, -1.6), Vector3(0, 0, 1.6), Vector3(-0.9, 0, -1.7), Vector3(0.9, 0, 1.7)][i]
	return SPOTS[spot] + Vector3(r, 0, 0).rotated(Vector3.UP, PI / 4 + i * PI / 2)


func _go(p: Dictionary, spot: String) -> void:
	slots_taken.erase("%s:%d" % [p.spot, p.slot])
	var free := -1
	for i in 4:
		if not slots_taken.has("%s:%d" % [spot, i]): free = i; break
	if free == -1: return   # full: stay put
	p.spot = spot; p.slot = free; slots_taken["%s:%d" % [spot, free]] = p.id


func _at(p: Dictionary) -> bool:
	if p.spot == "" or p.slot < 0: return false   # with you, or between places
	return Vector2(p.body.position.x, p.body.position.z).distance_to(Vector2(_slot_pos(p.spot, p.slot).x, _slot_pos(p.spot, p.slot).z)) < 0.25


func _find(id: String) -> Dictionary:
	for p in people:
		if p.id == id and not p.gone: return p
	return {}


func _pick_spot(p: Dictionary) -> String:   # where each kind of person wants to be next
	var br := _find("broker")
	match p.role:
		"host":   # works the room: goes where the guests are
			var best := ""; var most := -1
			for sp in GUEST_SPOTS:
				var n := 0
				for o in people:
					if not o.gone and o.spot == sp and o.role == "guest": n += 1
				if sp != p.spot and n > most and _has_room(sp): best = sp; most = n
			return best if best != "" else "middle"
		"broker": return ["lounge", "window_r", "balcony", "middle"].filter(func(s): return s != p.spot and _has_room(s)).pick_random()
		"assistant": return br.spot if br and _has_room(br.spot, p) else p.spot
		"security":
			var opts := ["door", "elevator"]
			if br: opts.append(br.spot)
			opts = opts.filter(func(s): return s != p.spot and _has_room(s))
			return opts.pick_random() if opts else p.spot
	var g := GUEST_SPOTS.filter(func(s): return s != p.spot and _has_room(s))
	return g.pick_random() if g else p.spot


func _has_room(spot: String, me: Dictionary = {}) -> bool:
	if spot == "": return false
	for i in 4:
		var who = slots_taken.get("%s:%d" % [spot, i], "")
		if who == "" or (me and who == me.id): return true
	return false


func _walk(p: Dictionary, dt: float) -> void:   # straight there, or veer round whatever's in the way
	var b: CharacterBody3D = p.body
	var dest: Vector3 = p.goto if p.coming else _slot_pos(p.spot, p.slot)
	var to := dest - b.position; to.y = 0
	if to.length() < 0.2 and not p.coming:
		p.chk_t = 0.0; p.chk_d = INF; p.stuck = 0
		b.velocity = Vector3.ZERO
		var c: Vector3 = SPOTS[p.spot] if p.spot != "bar" else Vector3(8.0, 0, b.position.z)
		if p.id == "bartender": c = Vector3(7.1, 0, -1.0)
		var d := c - b.position
		var mine := player.position - b.position; mine.y = 0
		if p.look_t > 0.0: d = p.look_pt - b.position; d.y = 0                       # what was that?
		elif p.glance > 0.0: d = mine                                                   # a look at you
		elif p.glance < 0.0 or (p.pic.doubt >= 2 and mine.length() < 3.5): d = -mine   # their back to you
		if d.length() > 0.1: b.rotation.y = lerp_angle(b.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-5.0 * dt))
		return
	p.chk_t += dt
	if p.chk_t >= 2.0:   # every couple of seconds: are they getting anywhere?
		if p.chk_d - to.length() < 0.3 and (not p.coming or p.following):
			p.stuck += 1
			if p.stuck >= 2 or to.length() < 1.5: b.position = dest; b.velocity = Vector3.ZERO; p.stuck = 0; return   # step in
			p.veer = [1.5, -1.5].pick_random(); p.veer_t = 1.2   # try round the other way
		else: p.stuck = 0
		p.chk_t = 0.0; p.chk_d = to.length()
	var dir := to.normalized()
	p.veer_t = p.get("veer_t", 0.0) - dt
	var tries: Array = [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.1, -2.1]
	if p.veer_t > 0.0: tries.push_front(p.veer)   # keep going round the same side, don't flip back and forth
	var found := false
	for a in tries:
		var dd := dir.rotated(Vector3.UP, a)
		if not b.test_move(b.global_transform, dd * 0.4):
			dir = dd; found = true
			if a != 0.0 and (p.veer_t <= 0.0 or a != p.veer): p.veer = a; p.veer_t = 0.8
			break
	if not found: b.velocity = Vector3.ZERO; return   # boxed in: wait a moment
	b.velocity = dir * minf(p.speed, to.length() / dt); b.move_and_slide(); b.position.y = 0
	b.rotation.y = lerp_angle(b.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * dt))


func _people(dt: float) -> void:
	for p in people.duplicate():
		if p.gone: continue
		p.glance = maxf(0.0, p.glance - dt) if p.glance > 0.0 else minf(0.0, p.glance + dt)
		if p.coming or p.errand or p.tell or p.following or p.shadow or p.away or p.usher or ((hunting or armed) and p.role == "security") or (distract_t > 0.0 and p.role == "security"): continue   # on their way to you, or to security, or with you
		if not p.busy: _walk(p, dt)
		if p.leaving and p.spot == "elevator" and _at(p):   # into the lift and gone
			p.gone = true; slots_taken.erase("%s:%d" % [p.spot, p.slot]); p.body.queue_free(); continue
		if p.busy or not _at(p): continue
		p.timer -= dt
		if p.timer <= 0.0:
			var sp := _pick_spot(p)
			var mate := _mate(p)
			if sp != p.spot and not mate.is_empty() and randf() < 0.35 and _free_slots(sp) >= 2: _go_together(p, mate, sp)
			elif sp != p.spot: _go(p, sp)
			p.timer = {"host": randf_range(16, 26), "broker": randf_range(28, 42), "assistant": 3.0, "security": randf_range(18, 30)}.get(p.role, randf_range(10, 18))
	for a in arrivals.duplicate():   # late arrivals step out of the lift, and the host goes to greet them
		if clock >= a[0]:
			arrivals.erase(a); var np := _spawn(a[1], get_meta("looks")[a[1]], true)
			var h := _find("host")
			if h and not h.busy and _has_room("elevator", h): _go(h, "elevator"); h.timer = 14.0
	if leave_at > 0.0 and clock >= leave_at:   # someone calls it a night
		leave_at = -1.0
		var gs := people.filter(func(o): return not o.gone and o.role == "guest" and not o.busy)
		if gs: _leave(gs.pick_random())


func _leave(p: Dictionary) -> void:
	p.leaving = true; p.timer = INF
	slots_taken.erase("%s:%d" % [p.spot, p.slot])
	p.spot = "elevator"; p.slot = 3 if not slots_taken.has("elevator:3") else 2


func _together() -> Dictionary:   # who's standing with whom right now
	var g := {}
	for p in people:
		if p.gone or p.busy or p.leaving or not _at(p): continue
		if not g.has(p.spot): g[p.spot] = []
		g[p.spot].append(p)
	return g


func _who(members: Array, roles: Array) -> Array:
	return members.filter(func(m): return (m.role in roles) or (m.id in roles))


func _options() -> Array:   # every conversation that could start now: [kind, [[person, line], ...]]
	var out := []
	var gs := _together()
	for spot in gs:
		var m: Array = gs[spot]
		var guests := _who(m, ["guest"]); var host := _who(m, ["host"]); var br := _who(m, ["broker"])
		var asst := _who(m, ["assistant"]); var sec := _who(m, ["security"]); var bt := _who(m, ["bartender"])
		var talkers := m.filter(func(x): return x.id in TALKERS)
		# business stays private: not with a stranger standing right there, unless he or his people have taken to you
		var stranger: bool = player.position.distance_to(SPOTS[spot]) < 4.0 and not (br and br[0].pic.ok) and not (asst and asst[0].pic.ok)
		if talkers.size() >= 2:
			talkers.shuffle()
			var topics := SMALL if talkers[0].role == "guest" and talkers[1].role == "guest" else SMALL.filter(func(x): return x != "know")   # the host and the broker's people know everyone
			var t: String = topics.pick_random()
			out.append(["small", [[talkers[0], "sq_" + t], [talkers[1], "sa_" + t]]])
		if host and guests:
			var g = guests.pick_random()
			if randf() < 0.5: out.append(["host", [[g, ["h1", "h3"].pick_random()], [host[0], "r_thanks"]]])
			else: out.append(["host", [[host[0], "h2"], [g, "r_thanks"]]])
		if br and (guests or host):
			out.append(["broker", [[(guests + host).pick_random(), "b2"], [br[0], "r_good"]]])
		if br and asst and not stranger: out.append(["boss", [[asst[0], "b1"], [br[0], "a1"], [asst[0], "r_yes"]]])
		if br and sec and not stranger: out.append(["room", [[sec[0], "b3"], [br[0], "r_yes"]]])
		if host and sec: out.append(["hostsec", [[host[0], "s2"], [sec[0], "r_yes"]]])
		if bt and guests:
			var g2 = guests.pick_random()
			if randf() < 0.5: out.append(["bar", [[bt[0], "t2"], [g2, "t1"], [bt[0], "r_wine"]]])
			else: out.append(["bar", [[g2, "t1"], [bt[0], "r_wine"]]])
		for o in _gossip(m): out.append(o)
		if asst: out.append(["phone", [[asst[0], "a2"]]])
		if sec: out.append(["radio", [[sec[0], "s1"]]])
	return out


func _gossip(m: Array) -> Array:   # someone here knows something about you the others don't: they pass it on
	var out := []
	for p in m:
		if not (p.id in ASKERS): continue
		for o in m:
			if o == p or not (o.id in ASKERS): continue
			if p.pic.wary and not o.pic.wary: out.append(["gossip", [[p, "g_odd"], [o, "r_really"]]])
			for k in p.pic.told:
				if not (k in o.pic.told) and o.pic.doubt < 2 and not (k == "invited" and o.role == "host"): out.append(["gossip", [[p, "g_" + k], [o, "r_really"]]])
	for p in m:   # someone who's taken to you speaks up for you
		if not (p.id in ASKERS) or not p.pic.ok or p.pic.doubt > 0: continue
		for o in m:
			if o != p and o.id in ASKERS and o.pic.doubt > 0 and not o.pic.vouched: out.append(["vouch", [[p, "v_ok"], [o, "r_really"]]])
	return out


func _spread(p: Dictionary, k: String) -> void:   # everyone standing there heard it
	for o in people:
		if o == p or o.gone or o.spot != p.spot: continue
		if k == "odd":
			if o.pic.doubt == 0:   # hearsay makes them curious, no more, and they don't know what was odd
				_doubt(o, 1); o.pic.concern = {"why": "heard_odd", "k": "", "q": -1, "src": "heard"}
		elif not (k in o.pic.told): o.pic.told.append(k); o.pic.second.append(k)
		o.glance = 3.0   # and they all look over at you


func _mate(p: Dictionary) -> Dictionary:   # a guest standing with them who might tag along
	if p.role != "guest": return {}
	var m := people.filter(func(o): return o != p and o.role == "guest" and not o.gone and not o.busy and not o.leaving and o.spot == p.spot and _at(o))
	return m.pick_random() if m else {}


func _free_slots(spot: String) -> int:
	var n := 0
	for i in 4:
		if not slots_taken.has("%s:%d" % [spot, i]): n += 1
	return n


func _go_together(p: Dictionary, m: Dictionary, sp: String) -> void:   # "같이 가요." "네, 좋아요."
	await _talk("go", [[p, "w_go"], [m, "go_yes"]])
	if p.gone or m.gone or p.following or m.following: return
	_go(p, sp); _go(m, sp); m.timer = p.timer


func _send_back(p: Dictionary) -> void:   # back to the party
	p.coming = false; p.slot = -1
	for sp in [_pick_spot(p)] + GUEST_SPOTS:
		if _has_room(sp): _go(p, sp); break
	p.errand = true; p.timer = randf_range(10.0, 18.0)


func _maybe_talk() -> void:
	if talks >= 2: return
	var opts := _options()
	if opts.is_empty(): return
	var gossip := opts.filter(func(o): return o[0] == "gossip" or o[0] == "vouch")
	if gossip and randf() < 0.7:
		var g: Array = gossip.pick_random(); _talk(g[0], g[1]); return
	var fresh := opts.filter(func(o): return o[0] != "small" and not (o[0] in recent))
	var smalls := opts.filter(func(o): return o[0] == "small")
	var pick: Array
	if fresh and (randf() < 0.45 or smalls.is_empty()): pick = fresh.pick_random()
	elif smalls: pick = smalls.pick_random()
	else: pick = opts.pick_random()
	recent.append(pick[0])
	if recent.size() > 3: recent.pop_front()
	_talk(pick[0], pick[1])


func _talk(kind: String, lines: Array) -> void:
	talks += 1; talk_count += 1
	var who := []
	for l in lines:
		if not l[0] in who: who.append(l[0])
	for p in who: p.busy = true
	for l in lines:
		var p: Dictionary = l[0]
		if p.gone: break
		for o in who:   # face whoever's speaking (the speaker faces the group)
			if o != p and not o.gone and is_instance_valid(o.body):
				var d: Vector3 = p.body.position - o.body.position
				o.body.rotation.y = atan2(-d.x, -d.z)
		if who.size() > 1 and not (who[1] if who[0] == p else who[0]).gone:   # (they might have left mid-chat)
			var other: Dictionary = who[1] if who[0] == p else who[0]
			var d2: Vector3 = other.body.position - p.body.position
			p.body.rotation.y = atan2(-d2.x, -d2.z)
		if l[1].begins_with("g_"):   # talking about you: a look your way
			var dm: Vector3 = player.position - p.body.position
			p.body.rotation.y = atan2(-dm.x, -dm.z)
		var voice_id: String = _vk(p) + "_" + l[1]
		p.audio.stream = _clip(voice_id); p.audio.play(); played.append(voice_id)
		p["line"] = l[1]
		if LINES.has(l[1]): _perceive(p, LINES[l[1]][0])
		await _wait_line(p.audio)
		p["line"] = ""
		if l[1].begins_with("g_") and not p.gone: _spread(p, l[1].trim_prefix("g_"))
		if l[1] == "v_ok":   # they take it from someone they trust
			for o in people:
				if o == p or o.gone or o.spot != p.spot: continue
				if o.pic.doubt > 0 and not o.pic.vouched: o.pic.vouched = true; _doubt(o, -1)
				o.glance = 3.0
		if l[1] == "al_sec":   # security looks your way, and so does everyone there
			for o in people:
				if not o.gone and (o.spot == p.spot or o.role == "security"): o.glance = 4.0
			var sc := _find("security")
			if sc and not hunting and not done:
				hunting = true; hunted = true; sc.timer = INF
				slots_taken.erase("%s:%d" % [sc.spot, sc.slot]); sc.slot = -1
		await get_tree().create_timer(0.45).timeout
	for p in who: p.busy = false
	talks -= 1
