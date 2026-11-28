# ---------------------------------------------------------------- start up, every frame

func _ready() -> void:
	test = Array(OS.get_cmdline_user_args()).any(func(x): return x == "--test" or x.begins_with("--test="))
	playing = "--play" in OS.get_cmdline_user_args()
	_en_map()
	if playing: test = true
	randomize()
	hvoice = AudioStreamPlayer.new(); add_child(hvoice)
	me_voice = AudioStreamPlayer.new(); add_child(me_voice)
	_room()
	_screen()
	_cast()
	leave_at = randf_range(95.0, 130.0)
	if playing: _run_play()
	elif test: _run_test()
	else:
		await get_tree().create_timer(1.0).timeout
		_handler("h_in")


func _clip(id: String) -> AudioStream:
	if not clips.has(id): clips[id] = load("res://voice/gala/%s.mp3" % id)
	return clips[id]


func _mine(id: String) -> AudioStream:   # your own voice (Eric), from the car
	if not clips.has("me_" + id): clips["me_" + id] = load("res://voice/cover/%s.mp3" % id)
	return clips["me_" + id]


func _vk(p: Dictionary) -> String:   # whose voice: guests by name, everyone else by role
	return p.id if p.role == "guest" else p.role


func _physics_process(dt: float) -> void:
	clock += dt
	if not hold: _people(dt)
	else:   # (tester) nobody walks off, but they still turn to look
		for p in people:
			if p.gone or p.busy: continue
			p.glance = maxf(0.0, p.glance - dt) if p.glance > 0.0 else minf(0.0, p.glance + dt)
			if _at(p) and not p.coming and not p.errand and not p.tell and not p.following and not p.shadow and not p.away and not p.usher and not (hunting and p.role == "security") and not (distract_t > 0.0 and p.role == "security"): _walk(p, dt)
	_doubters(dt)
	_gate_tick(dt)
	_real_tick(dt)
	_waiter(dt)
	_distract(dt)
	_heat(dt)
	_hunt(dt)
	if escorting: _escort(dt); return
	if done or killed: return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dir.y += 1
	if joy_vec.length() > 0.12: dir = joy_vec
	dir = dir.limit_length(1.0)
	player.velocity = Vector3(dir.x, 0, dir.y) * SPEED
	player.move_and_slide(); player.position.y = 0
	if dir.length() > 0.12: body_mesh.rotation.y = atan2(-dir.x, -dir.y)


func _process(dt: float) -> void:
	var focus := player.position + (Vector3(3.4, 0, 0) if phone_open else Vector3.ZERO)   # the phone covers the right: keep you in view
	cam.position = cam.position.lerp(focus + CAM_OFF, 1.0 - exp(-6.0 * dt)); cam.look_at(cam.position - CAM_OFF, Vector3.UP)
	throw_btn.visible = false
	shoot_btn.visible = false
	_items_ui()
	if not talk_wait.is_empty():   # you asked for them: they turn to you as soon as they're free
		var tw: Dictionary = talk_wait
		if tw.gone or done or not asking.is_empty() or back or player.position.distance_to(tw.body.position) > 3.2: talk_wait = {}; talk_btn.text = "Talk"
		elif not tw.busy: talk_wait = {}; talk_btn.text = "Talk"; _talk_to(tw)
	talk_cd -= dt
	if talk_cd <= 0.0:
		_maybe_talk(); talk_cd = randf_range(1.5, 3.5)
	for p in people:   # right beside them you can make out the words (in Korean); otherwise you only hear them
		if p.gone: continue
		var line: String = p.get("line", "")
		var d := player.position.distance_to(p.body.position)
		var said: String = p.get("said", "")
		if d >= READ: p.ko.text = ""
		elif line != "" and LINES.has(line): p.ko.text = _en(LINES[line][0])
		else: p.ko.text = _en(said)
		p.audio.volume_db = -12.0 if p.pic.wary and d < 4.5 else 0.0   # wary of you: they lower their voices
	sub_t -= dt
	if sub_t <= 0.0: sub.text = ""
	goal.text = "Marked: %d of 5" % guesses.size()
	var n := _nearest() if phone_open and not done else {}
	ring.visible = not n.is_empty()
	if ring.visible: ring.position = n.body.position + Vector3(0, 0.05, 0)
	for r in role_btns: role_btns[r].disabled = n.is_empty()
	talk_btn.visible = (not _talk_target().is_empty() or not talk_wait.is_empty()) and not phone_open
	comp_btn.visible = not _companion().is_empty() and not phone_open
	leave_btn.visible = not done and not escorting and asking.is_empty() and player.position.z > 5.3 and absf(player.position.x + 6.0) < 1.2
	var lmat: StandardMaterial3D = lift_pad.material_override   # pulses when you need to get out
	lmat.emission_energy_multiplier = (1.4 + 1.2 * sin(clock * 6.0)) if (hunting or heat_stage >= 2) and not done else 0.6
	if done: return
	_doors(); _deal_tick()
	if not in_back and not no_ask: _linger(dt)
	if not asking.is_empty():
		var who: Dictionary = asking
		if player.position.distance_to(who.body.position) > 3.2: _ask_end("walked")      # walking off mid-question
		elif not ask_busy:
			ask_t -= dt
			if ask_t <= 0.0: _ask_end("silent")
