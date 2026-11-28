# ---------------------------------------------------------------- the mission: getting to the broker, the back room, the real buyer

func _appt(who: Dictionary) -> void:   # "최 사장님하고 약속 있어요": only two people at the party can take you to him
	if gate != "" or has_drive: await _line(who, "x_cool"); _back_end(); return
	match who.role:
		"assistant":   # it's her job: she checks who you are
			if who.pic.doubt >= 2: await _line(who, "appt_no"); _back_end(); return
			_back_end(); who.busy = true
			gate_by = who; gate_check = true
			_ask(who, [who], "", "name")
		"host":   # she threw this party for the deal: she'll take you, if she likes you
			if who.pic.ok and who.pic.doubt == 0: await _line(who, "appt_go"); _back_end(); _open_gate(who)
			else: await _line(who, "appt_meh"); _back_end()
		"broker": await _line(who, "appt_asst"); _back_end()
		_: await _line(who, "appt_huh"); _doubt(who, 1); _back_end()   # a guest: no idea what you're on about


func _gate_result(how: String) -> void:   # the assistant heard your name
	var a: Dictionary = gate_by
	gate_check = false; asking = {}; ask_ui.visible = false; ask_busy = true
	if how == "good":
		await _line(a, "appt_wait"); ask_busy = false; _open_gate(a); return
	_doubt(a, 1); await _line(a, "appt_no")
	a.busy = false; ask_busy = false; gate_by = {}


func _open_gate(p: Dictionary) -> void:   # they fetch the broker: he goes into the back room, and they show you the door
	gate = p.role; gate_by = p; p.usher = true; p.busy = true; p.said_in = false
	if p.slot >= 0: slots_taken.erase("%s:%d" % [p.spot, p.slot]); p.slot = -1
	var br := _find("broker")
	if br.is_empty(): return
	if asking == br: _ask_end("walked")
	br.away = true; br.busy = true; br.following = false
	if br.slot >= 0: slots_taken.erase("%s:%d" % [br.spot, br.slot]); br.slot = -1


func _gate_tick(dt: float) -> void:   # the broker walks to the door and through it; they wait by the door for you
	if gate == "" or done: return
	var br := _find("broker")
	if br and br.away and not br.inside:
		var g: Vector3 = DOOR_IN - br.body.position; g.y = 0
		if g.length() > 0.6: br.goto = DOOR_IN; br.speed = 1.8; br.coming = true; _walk(br, dt); br.coming = false
		else:
			br.inside = true; br.body.velocity = Vector3.ZERO; br.body.position = BR_SEAT; br.body.rotation.y = PI
			door_open = true; create_tween().tween_property(back_door, "position:z", back_door.position.z + 1.25, 0.6)
	var u: Dictionary = gate_by
	if u and u.usher and not u.gone:
		var at: Vector3 = DOOR_IN + Vector3(0.7, 0, 1.2)
		var to: Vector3 = at - u.body.position; to.y = 0
		if to.length() > 0.4: u.goto = at; u.speed = 1.8; u.coming = true; _walk(u, dt); u.coming = false
		else:
			u.body.velocity = Vector3.ZERO
			var m: Vector3 = player.position - u.body.position; m.y = 0
			if m.length() > 0.1: u.body.rotation.y = lerp_angle(u.body.rotation.y, atan2(-m.x, -m.z), 1.0 - exp(-5.0 * dt))
		if door_open and not u.said_in and not in_back and player.position.distance_to(u.body.position) < 3.5: u.said_in = true; _line(u, "appt_in")


func _doors() -> void:   # walk into the door: from one room to the other
	if done or killed or escorting or not asking.is_empty() or back: return
	if not in_back and door_open and player.position.x < -9.15 and absf(player.position.z - 2.5) < 0.9: _through(true)
	elif in_back and player.position.x > BR.x + 4.6 and absf(player.position.z - BR.z) < 1.1: _through(false)


func _through(going_in: bool) -> void:
	in_back = going_in
	fade.color.a = 1.0
	player.velocity = Vector3.ZERO
	player.position = BR_ENTRY if going_in else DOOR_IN + Vector3(0.8, 0, 0)
	body_mesh.rotation.y = PI / 2 if going_in else -PI / 2
	cam.position = player.position + CAM_OFF
	create_tween().tween_property(fade, "color:a", 0.0, 0.45)
	_plg("You go through the door, into %s" % ("the back room. The party's out of sight behind you." if going_in else "the party again."))
	if going_in:
		for p in people:   # nobody comes in after you
			if p.following: _end_follow(p)
		var u: Dictionary = gate_by
		if u and u.usher: u.usher = false; u.busy = false; _send_back(u)
		if blown and not has_drive: blow_t = 8.0


func _real_tick(dt: float) -> void:   # the real Eric Shin is coming: warned, then he's here, then he tells them who he is
	if done or killed: return
	if not no_real:
		if real_stage == 0 and clock >= REAL_WARN: real_stage = 1; _handler("h_real1")
		elif real_stage == 1 and clock >= REAL_AT: _real_arrive()
	if real_stage == 2: _real_walk(dt)
	if blow_t > 0.0:
		blow_t -= dt
		if blow_t <= 0.0: _broker_learns()


func _real_arrive() -> void:
	real_stage = 2
	real = _spawn("buyer", Color(0.45, 0.7, 1.0), true)
	real.role = "buyer"; real.usher = true; real.busy = true
	if real.slot >= 0: slots_taken.erase("%s:%d" % [real.spot, real.slot]); real.slot = -1
	_handler("h_real2"); _plg("Someone steps out of the lift: a man in light blue. The real Eric Shin.")


func _real_target() -> Dictionary:   # he asks for Choi's assistant, or failing her, the host
	for r in ["assistant", "host"]:
		var t := _find(r)
		if t and not t.away: return t
	return {}


func _real_walk(dt: float) -> void:
	var t := _real_target()
	if t.is_empty() or real.gone: return
	var g: Vector3 = t.body.position - real.body.position; g.y = 0
	if g.length() > 1.4:
		real.goto = t.body.position; real.speed = 1.8; real.coming = true; _walk(real, dt); real.coming = false
	elif not t.busy or t.usher:
		real_stage = 3; _real_reveal(t)


func _real_reveal(t: Dictionary) -> void:   # "I'm Eric Shin, I have an appointment" — "...Eric Shin's already here"
	if t.usher: t.usher = false
	if asking == t: _ask_end("walked")
	await _talk("real", [[real, "b_self"], [t, "real_huh"]])
	blown = true; _handler("h_blown")
	for o in people:   # she knows, and so does anyone close enough to hear
		if o.gone or not (o.id in ASKERS): continue
		if o == t or o.body.position.distance_to(t.body.position) < 5.0: _doubt(o, 3); o.glance = 4.0
	if in_back and not has_drive: blow_t = 8.0   # someone goes in to tell him
	real.busy = false


func _broker_learns() -> void:   # a knock, a word in his ear: he knows you're not the buyer
	var br := _find("broker")
	if br.is_empty() or not in_back or has_drive or killed or done: return
	if asking == br: asking = {}; ask_ui.visible = false; deal_ask = false
	ask_busy = true
	_plg("Someone slips into the back room and whispers to the broker.")
	await _line(br, "deal_bad")
	_killed(br)


func _deal_tick() -> void:   # step up to him and he starts: what you're after, the price, did you bring it
	if not in_back or deal_step != -1 or done or killed: return
	var br := _find("broker")
	if br and br.inside and player.position.distance_to(br.body.position) < 2.8:
		deal_step = 0; _deal()


func _deal() -> void:
	var br := _find("broker")
	ask_busy = true
	var d: Vector3 = player.position - br.body.position; br.body.rotation.y = atan2(-d.x, -d.z)
	await _line(br, "deal_hi")
	ask_busy = false
	_deal_ask()


func _deal_ask() -> void:
	var br := _find("broker")
	if br.is_empty() or done: return
	deal_ask = true
	_ask(br, [br], "", Cover.DEAL[deal_step].k, 0)


func _deal_answer(how: String) -> void:   # right, and he moves on; wrong, and you know too much to leave
	var br: Dictionary = asking
	asking = {}; ask_ui.visible = false; deal_ask = false; ask_busy = true
	if how == "good":
		deal_step += 1
		if deal_step < Cover.DEAL.size(): ask_busy = false; _deal_ask(); return
		await _line(br, "deal_ok")
		has_drive = true; inv.append("drive"); hand = "drive"; _props(); ask_busy = false; br.busy = true
		_handler("h_got"); _plg("He slides a USB drive across the table. You have the drive.")
		return
	await _line(br, "deal_bad")
	_killed(br)


func _killed(br: Dictionary) -> void:   # he shoots you, and your body goes in the corner
	killed = true
	var d: Vector3 = player.position - br.body.position; br.body.rotation.y = atan2(-d.x, -d.z)
	var snd := AudioStreamPlayer3D.new(); snd.stream = _shot_sound(); snd.position = br.body.position + Vector3(0, 1, 0); add_child(snd); snd.play()
	played.append("killed"); _plg("He pulls a gun and shoots you.")
	create_tween().tween_property(body_mesh, "rotation:x", -PI / 2, 0.3)
	await get_tree().create_timer(0.9).timeout
	var tw := create_tween(); tw.tween_property(fade, "color:a", 1.0, 0.5); await tw.finished
	player.position = BR + Vector3(-4.4, 0, 3.4); cam.position = player.position + CAM_OFF   # in the corner, behind the armchair
	create_tween().tween_property(fade, "color:a", 0.0, 0.8)
	await get_tree().create_timer(1.2).timeout
	_finish()
