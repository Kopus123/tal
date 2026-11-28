# ---------------------------------------------------------------- your things: the bag, the hand button, the drink, the gun

func _glass_mesh() -> CylinderMesh:
	var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.04; cm.height = 0.2; return cm


func _glass_mat() -> StandardMaterial3D:
	var m := _mat(Color(0.75, 0.15, 0.25)); m.emission_enabled = true; m.emission = Color(0.5, 0.05, 0.12); m.emission_energy_multiplier = 0.5; return m


func _throw(at := Vector3.INF) -> void:   # the glass flies ahead of you and smashes: everyone looks there, security goes to see
	if hand != "drink" or done or escorting or not asking.is_empty() or back: return
	inv.erase("drink"); hand = ""; _props()
	if at == Vector3.INF:
		var fwd := Vector3(-sin(body_mesh.rotation.y), 0, -cos(body_mesh.rotation.y))
		at = player.position + fwd * 6.0
	at.y = 0; at.x = clampf(at.x, -ROOM.x / 2 + 0.6, ROOM.x / 2 - 0.6); at.z = clampf(at.z, -ROOM.y / 2 + 0.6, ROOM.y / 2 - 0.6)
	for o in people:   # anyone right beside you sees you do it
		if o.gone or player.position.distance_to(o.body.position) > 2.5: continue
		_doubt(o, 1); o.glance = 3.0
	var g := MeshInstance3D.new(); g.mesh = _glass_mesh(); g.material_override = _glass_mat(); add_child(g)
	var from: Vector3 = player.position + Vector3(0, 1.1, 0)
	g.position = from
	var tw := create_tween()
	tw.tween_method(func(k: float): g.position = from.lerp(at + Vector3(0, 0.1, 0), k) + Vector3(0, 2.4 * k * (1.0 - k), 0); g.rotation.x = k * 9.0, 0.0, 1.0, 0.55)
	await tw.finished
	g.queue_free()
	_smash(at)


func _smash(at: Vector3) -> void:
	played.append("smash"); noise_at = at
	_plg("CRASH: your glass smashes on the floor %s. Everyone turns to look." % _place(at))
	for i in 7:   # shards, and a splash of red
		var sh := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(randf_range(0.04, 0.1), 0.02, randf_range(0.04, 0.1)); sh.mesh = bm
		sh.material_override = _glass_mat(); sh.position = at + Vector3(randf_range(-0.45, 0.45), 0.02, randf_range(-0.45, 0.45)); sh.rotation.y = randf() * TAU; add_child(sh)
	var sp := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.5; cy.bottom_radius = 0.5; cy.height = 0.01; sp.mesh = cy
	sp.material_override = _mat(Color(0.45, 0.05, 0.1)); sp.position = at + Vector3(0, 0.01, 0); add_child(sp)
	var snd := AudioStreamPlayer3D.new(); snd.stream = _smash_sound(); snd.position = at + Vector3(0, 0.5, 0); snd.unit_size = 8.0; add_child(snd); snd.play()
	for p in people:
		if p.gone or p.busy or p.body.position.distance_to(at) > 11.0: continue
		p.look_t = randf_range(2.0, 3.5); p.look_pt = at; p.glance = 0.0
	var sec := _find("security")
	if sec and not sec.busy and not escorting and not done:
		distract_go = true; distract_t = sec.body.position.distance_to(at) / HUNT + 4.5
		if not hunting and not sec.shadow: slots_taken.erase("%s:%d" % [sec.spot, sec.slot]); sec.slot = -1


func _smash_sound() -> AudioStreamWAV:   # breaking glass, made on the spot
	var rate := 22050; var n := int(rate * 0.7)
	var data := PackedByteArray(); data.resize(n * 2)
	var tone := 0.0
	for i in n:
		var t := float(i) / rate
		if randf() < 0.002: tone = randf_range(2500.0, 5200.0)   # bits of glass ringing
		var v := (randf() * 2.0 - 1.0) * exp(-t * 10.0) * 0.75 + sin(t * TAU * tone) * exp(-t * 6.0) * 0.25
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.data = data; return w


func _distract(dt: float) -> void:   # heads turn to the noise; security goes over to look at the mess
	for p in people:
		if p.look_t > 0.0: p.look_t -= dt
	if distract_t <= 0.0: return
	var sec := _find("security")
	if sec.is_empty() or sec.busy or done or escorting: distract_t = 0.0; return
	distract_t -= dt
	var gap: Vector3 = noise_at - sec.body.position; gap.y = 0
	if distract_go and gap.length() > 1.0:
		sec.goto = noise_at; sec.speed = HUNT; sec.coming = true; _walk(sec, dt); sec.coming = false
	else:
		distract_go = false; sec.body.velocity = Vector3.ZERO
		if gap.length() > 0.1: sec.body.rotation.y = lerp_angle(sec.body.rotation.y, atan2(-gap.x, -gap.z), 1.0 - exp(-5.0 * dt))
	if distract_t <= 0.0 and not hunting and not sec.shadow: _send_back(sec)   # back to his post


func _blending() -> bool:   # a glass in your hand (even an empty one): you look like everyone else
	return hand == "drink"


func _slip(o: Dictionary) -> void:   # a small slip: it counts against you, but with a glass in your hand only half the time
	if not _blending() or randf() < 0.5: _doubt(o, 1)


func _tipsy() -> float:   # one glass and you're fine; it builds from there, at its worst from three glasses on
	return clampf(float(drunk - SIPS) / float(2 * SIPS), 0.0, 1.0)


func _aim() -> Dictionary:   # who you'd hit: security first if he's after you, else whoever's in front of you, else whoever's nearest
	var sec := _find("security")
	if sec and (hunting or sec.shadow or escorting or armed) and player.position.distance_to(sec.body.position) < 14.0: return sec
	var fwd := Vector3(-sin(body_mesh.rotation.y), 0, -cos(body_mesh.rotation.y))
	var best := {}; var bd := INF
	for p in people:
		if p.gone: continue
		var to: Vector3 = p.body.position - player.position; to.y = 0
		var d := to.length()
		if d > 14.0 or d < 0.05: continue
		var score := d if fwd.dot(to / d) > 0.75 else d + 100.0   # in front of you counts first
		if score < bd: bd = score; best = p
	if bd > 100.0 and bd - 100.0 > 8.0: return {}
	return best


func _shoot() -> void:   # pfft: they drop. Anyone who sees it panics, and security comes for you
	if ammo <= 0 or done or killed or not asking.is_empty() or back: return
	var p := _aim()
	ammo -= 1
	var to: Vector3 = (p.body.position if p else player.position + Vector3(-sin(body_mesh.rotation.y), 0, -cos(body_mesh.rotation.y)) * 5.0) - player.position
	body_mesh.rotation.y = atan2(-to.x, -to.z)
	var flash := MeshInstance3D.new(); var fm := SphereMesh.new(); fm.radius = 0.12; fm.height = 0.24; flash.mesh = fm
	var fmat := _mat(Color(1.0, 0.85, 0.4)); fmat.emission_enabled = true; fmat.emission = Color(1.0, 0.7, 0.3); fmat.emission_energy_multiplier = 4.0; flash.material_override = fmat
	flash.position = gun_prop.position + Vector3(0, 0, -0.3); body_mesh.add_child(flash)
	get_tree().create_timer(0.08).timeout.connect(flash.queue_free)
	var snd := AudioStreamPlayer3D.new(); snd.stream = _shot_sound(); snd.position = player.position + Vector3(0, 1.0, 0); add_child(snd); snd.play()
	played.append("shot")
	if p.is_empty():
		_plg("You fire. Nobody there.")
		var sc0 := _find("security")
		if sc0 and not armed: _draw_gun(sc0)
		return
	_plg("You fire at %s. They drop." % _desc(p))
	_drop(p)
	_handler("h_shot")
	var sec := _find("security")
	for o in people:   # everyone who saw: alarmed, and they look at you
		if o.gone or o.body.position.distance_to(player.position) > 10.0: continue
		_doubt(o, 3); o.glance = 5.0; o.look_t = 0.0
	if sec and not armed and not done: _draw_gun(sec)   # he heard it: his gun comes out


func _drop(p: Dictionary) -> void:   # down on the floor, out of the party
	if asking == p: _ask_end("walked")
	p.gone = true; p.busy = true; p.following = false; p.shadow = false; p.coming = false
	if p.slot >= 0: slots_taken.erase("%s:%d" % [p.spot, p.slot])
	downed.append(p.id)
	var b: CharacterBody3D = p.body
	b.velocity = Vector3.ZERO; b.collision_layer = 0; p.audio.stop(); p.ko.text = ""
	if p.role == "security": hunting = false; distract_t = 0.0; escorting = false; armed = false
	create_tween().tween_property(b, "rotation:x", -PI / 2, 0.35)
	var pos := b.position; create_tween().tween_property(b, "position:y", 0.3, 0.35).from(pos.y)


func _shot_sound() -> AudioStreamWAV:   # a suppressed shot: a hard thump and a hiss
	var rate := 22050; var n := int(rate * 0.3)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := sin(t * TAU * 90.0) * exp(-t * 30.0) * 0.9 + (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.data = data; return w


func _props() -> void:   # what you're holding shows in your hand
	glass_prop.visible = hand == "drink"; gun_prop.visible = hand == "gun"; drive_prop.visible = hand == "drive"
	if hand_btn: hand_btn.text = _hand_text()


func _hand_text() -> String:
	match hand:
		"drink": return "Wine\n%d/%d" % [sips, SIPS] if sips > 0 else "Glass\nempty"
		"gun": return "Gun\n%d" % ammo
		"drive": return "USB"
	return "Hand\nempty"


func _item_text(it: String) -> String:
	match it:
		"drink": return "Wine (%d/%d)" % [sips, SIPS]
		"gun": return "Gun (%d)" % ammo
		"drive": return "USB"
	return it


func _actions() -> Array:   # what you can do with what's in your hand: [label, action]; the first is the tap
	match hand:
		"drink": return [["Sip", "sip"], ["Put down", "put"], ["Drop", "drop"], ["Throw", "throw"], ["Offer", "offer"]]
		"gun": return [["Shoot", "shoot"]]
	return []


func _hand_up() -> void:   # let go: over a ring option, or a plain tap
	holding = false
	if ring_open: _ring_release()
	else: _hand_tap()


func _hand_tap() -> void:
	var a := _actions()
	if a: _act(a[0][1])


func _act(a: String) -> void:
	if done or killed or not asking.is_empty() or back: return
	match a:
		"sip":
			if hand != "drink" or sips <= 0: return
			sips -= 1; drunk += 1; played.append("sip"); _plg("You sip your wine (%d left)." % sips)
			var tw := create_tween(); tw.tween_property(glass_prop, "position:y", 1.45, 0.2); tw.tween_property(glass_prop, "position:y", 1.0, 0.25)
		"put": _put_down()
		"drop": await _drop_glass()
		"throw": await _throw()
		"offer": _offer_start()
		"shoot": _shoot()
	_props()


func _put_down() -> void:   # on the nearest table if there's one in reach, or on the floor at your feet
	if hand != "drink": return
	var at: Vector3 = player.position + Vector3(-sin(body_mesh.rotation.y), 0, -cos(body_mesh.rotation.y)) * 0.5; at.y = 0.0
	var bd := 1.6
	for sf in SURFACES:
		var c: Vector3 = sf[0]; var h: Vector2 = sf[1]
		var q := Vector3(clampf(player.position.x, c.x - h.x + 0.1, c.x + h.x - 0.1), sf[2], clampf(player.position.z, c.z - h.y + 0.1, c.z + h.y - 0.1))
		var d := Vector2(q.x - player.position.x, q.z - player.position.z).length()
		if d < bd: bd = d; at = q
	var g := MeshInstance3D.new(); g.mesh = _glass_mesh(); g.material_override = _glass_mat(); g.position = at + Vector3(0, 0.1, 0); add_child(g)
	placed.append({"node": g, "sips": sips})
	inv.erase("drink"); hand = ""
	_plg("You put your glass down %s." % ("on the floor" if at.y == 0.0 else "on the table"))


func _drop_glass() -> void:   # straight down from your hand, and it smashes
	if hand != "drink": return
	inv.erase("drink"); hand = ""; _props()
	var at: Vector3 = player.position; at.y = 0.0
	var g := MeshInstance3D.new(); g.mesh = _glass_mesh(); g.material_override = _glass_mat(); g.position = at + Vector3(0, 1.0, 0); add_child(g)
	var tw := create_tween(); tw.tween_property(g, "position:y", 0.1, 0.3); await tw.finished
	g.queue_free(); _smash(at)


func _offer_start() -> void:   # rings under everyone close enough: tap the one to give it to
	if hand != "drink": return
	_offer_end()
	for p in people:
		if p.gone or p.away or player.position.distance_to(p.body.position) > 2.6: continue
		var r := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.42; tm.outer_radius = 0.55; r.mesh = tm
		var m := _mat(Color(0.4, 1.0, 0.5)); m.emission_enabled = true; m.emission = Color(0.3, 0.9, 0.4); r.material_override = m
		r.position = p.body.position + Vector3(0, 0.05, 0); add_child(r); offer_rings.append([p, r])
	if offer_rings.is_empty(): sub.text = "Nobody close enough to offer it to"; sub_t = 2.0; return
	offer_mode = true; sub.text = "Tap who to give it to"; sub_t = 3.0
	_plg("OFFER: tap who to give it to: " + ", ".join(offer_rings.map(func(x): return _desc(x[0]))))


func _offer_end() -> void:
	for x in offer_rings: x[1].queue_free()
	offer_rings.clear(); offer_mode = false


func _give(p: Dictionary) -> void:   # they take your glass: 감사합니다
	_offer_end()
	if hand != "drink" or p.gone: return
	inv.erase("drink"); hand = ""; _props()
	var g := MeshInstance3D.new(); g.mesh = _glass_mesh(); g.material_override = _glass_mat(); g.position = Vector3(0.34, 1.0, -0.15); p.look.add_child(g)
	var d: Vector3 = player.position - p.body.position; p.body.rotation.y = atan2(-d.x, -d.z)
	_plg("You hand your glass to %s." % _desc(p))
	if not p.busy: _line(p, "r_thanks")


func _world_tap(pos: Vector2) -> void:   # a tap on the room: whoever you're offering to, or a glass to pick up
	if ring_open: _ring_close(); return
	if offer_mode:
		var best := {}; var bd := 110.0
		for x in offer_rings:
			var sp := cam.unproject_position(x[0].body.position + Vector3(0, 0.8, 0))
			if sp.distance_to(pos) < bd: bd = sp.distance_to(pos); best = x[0]
		if best: _give(best)
		else: _offer_end()
		return
	for g in placed:
		var sp := cam.unproject_position(g.node.global_position)
		if sp.distance_to(pos) > 80.0: continue
		if player.position.distance_to(Vector3(g.node.position.x, 0, g.node.position.z)) > 2.6: sub.text = "Too far: walk up to it"; sub_t = 1.5; return
		if hand == "drink" or "drink" in inv: sub.text = "You've already got a glass"; sub_t = 1.5; return
		sips = g.sips; g.node.queue_free(); placed.erase(g)
		inv.append("drink"); hand = "drink"; _props(); _plg("You pick the glass back up."); return


func _on_button(pos: Vector2) -> bool:   # is that spot on one of the buttons? (then it isn't a tap on the room)
	var bs: Array = [hand_btn, bag_btn, talk_btn, comp_btn, phone_btn, en_btn, leave_btn] + ring_box.get_children() + bag_box.get_children()
	for b in bs:
		if b and b.is_visible_in_tree() and b.get_global_rect().grow(6.0).has_point(pos): return true
	return false


func _unhandled_input(ev: InputEvent) -> void:   # short taps on the room (not on buttons)
	if done or not (ev is InputEventMouseButton) or ev.button_index != MOUSE_BUTTON_LEFT: return
	if _on_button(ev.position): return
	if ev.pressed: tap_at = ev.position; tap_t = Time.get_ticks_msec() / 1000.0
	elif ev.position.distance_to(tap_at) < 24.0 and Time.get_ticks_msec() / 1000.0 - tap_t < 0.4: _world_tap(ev.position)


func _ring_show() -> void:   # hold the hand button: a ring of everything you can do with it
	var a := _actions()
	if a.is_empty(): return
	for c in ring_box.get_children(): ring_box.remove_child(c); c.queue_free()
	var centre: Vector2 = hand_btn.get_global_rect().get_center()
	for i in a.size():
		var ang: float = deg_to_rad(175.0 + 100.0 * (float(i) / maxf(1.0, float(a.size() - 1)))) if a.size() > 1 else PI   # an arc, left and up from your thumb (clear of Talk)
		var b := _btn(a[i][0], 22, Vector2(124, 64)); b.set_meta("act", a[i][1]); b.pressed.connect(_ring_pick.bind(a[i][1]))
		b.position = centre + Vector2(cos(ang), sin(ang)) * 270.0 - Vector2(62, 32)
		b.position.y = maxf(b.position.y, 100.0); ring_box.add_child(b)
	ring_open = true; ring_box.visible = true


func _ring_release() -> void:   # let go over an option to do it; let go anywhere else and the ring stays open to tap
	var chosen := ""
	for b in ring_box.get_children():
		if b.get_global_rect().has_point(touch_pos): chosen = b.get_meta("act")
	if chosen != "": _ring_pick(chosen)


func _ring_pick(a: String) -> void:
	_ring_close(); _act(a)


func _ring_close() -> void:
	ring_open = false; ring_box.visible = false
	for c in ring_box.get_children(): ring_box.remove_child(c); c.queue_free()


func _bag_show() -> void:   # the bag open: your items and Back, the hand button out of the way
	for c in bag_box.get_children(): c.queue_free()
	for it in inv:
		var b := _btn(_item_text(it), 22, Vector2(130, 90)); b.pressed.connect(_bag_pick.bind(it)); bag_box.add_child(b)
	var fb := _btn("Hands free", 22, Vector2(130, 90)); fb.pressed.connect(_bag_pick.bind("")); bag_box.add_child(fb)
	var bk := _btn("Back", 22, Vector2(100, 90)); bk.pressed.connect(_bag_back); bag_box.add_child(bk)
	bag_open = true


func _bag_pick(it: String) -> void:   # that one, in your hand
	hand = it; bag_open = false; _props()
	_plg("You take %s in your hand." % (_item_text(it) if it != "" else "nothing: hands free"))


func _bag_back() -> void:
	bag_open = false


func _items_ui() -> void:   # bottom right, above Talk: the hand button and the bag
	_props()
	var show := not done and not killed and not phone_open and asking.is_empty() and not back and not ask_ui.visible
	hand_btn.visible = show and not bag_open
	bag_btn.visible = show and not bag_open
	bag_box.visible = show and bag_open
	if not show and ring_open: _ring_close()
	if holding:
		hold_t += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		if hold_t > 0.4 and not ring_open: _ring_show()
	if ring_open:
		var pos := touch_pos
		for b in ring_box.get_children(): b.modulate = Color(1.3, 1.3, 0.8) if b.get_global_rect().has_point(pos) else Color(1, 1, 1, 0.85)
