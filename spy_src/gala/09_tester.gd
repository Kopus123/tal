# ---------------------------------------------------------------- test helpers (the tests themselves are in spy/gala_test.gd)

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok: _fails += 1


func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://").path_join("../build/spy")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(nm + ".png"))


func _secs(t: float) -> void:
	await get_tree().create_timer(t).timeout
	await get_tree().process_frame; await get_tree().process_frame   # (on the fast clock a short wait can be a single frame)


func _put(p: Vector3) -> void:
	player.position = p; cam.position = p + CAM_OFF
	await get_tree().physics_frame; await get_tree().physics_frame


func _beside(p: Dictionary) -> void:   # stand right next to someone, somewhere you actually fit
	for off in [Vector3(0, 0, 0.6), Vector3(0, 0, -0.6), Vector3(0.6, 0, 0), Vector3(-0.6, 0, 0), Vector3(0.45, 0, 0.45), Vector3(-0.45, 0, -0.45)]:
		await _put(p.body.position + off)
		if _nearest() == p: return


func _wait_free() -> void:   # until the person asking you has finished talking
	for i in 200:
		if not ask_busy: return
		await _secs(0.05)


func _right_pieces(f: Dictionary) -> Array:
	var r := []
	for i in f.chunks.size(): r.append([f.k, i])
	return r


func _finger(at: Vector2, hold_for: float) -> void:   # (tester) a real touch, through the screen: down, wait (real time), up
	var t := InputEventScreenTouch.new(); t.index = 0; t.position = at; t.pressed = true; Input.parse_input_event(t)
	await get_tree().create_timer(hold_for, true, false, true).timeout
	var u := InputEventScreenTouch.new(); u.index = 0; u.position = at; u.pressed = false; Input.parse_input_event(u)
	await get_tree().create_timer(0.1, true, false, true).timeout


func _clear_ask() -> void:   # (tester) nobody's in the middle of asking you anything
	await _wait_free()
	if not asking.is_empty(): asking.busy = false
	asking = {}; back = false; ask_ui.visible = false; ask_busy = false


func _reset_pics() -> void:
	for p in people: p.calm_t = 0.0
	for p in people: p.pic = {"met": false, "told": [], "second": [], "ok": false, "wary": false, "doubt": 0, "checked": false, "told_sec": false, "vouched": false, "asked": [], "concern": {}}


func _guest_group() -> Array:   # a guest, and whoever's with them (everyone put in their places first)
	for o in people:
		if not o.gone and not o.leaving and o.slot >= 0 and o.id != "bartender": o.body.position = _slot_pos(o.spot, o.slot)
	var gs := people.filter(func(o): return o.role == "guest" and not o.gone and not o.leaving and o.spot != "elevator")
	gs.shuffle()
	var p: Dictionary = gs[0]
	return [p] + people.filter(func(o): return not o.gone and o.spot == p.spot and o != p)   # the guest first


func _facing_away(p: Dictionary) -> bool:
	var fwd := Vector3(-sin(p.body.rotation.y), 0, -cos(p.body.rotation.y))
	var to_me: Vector3 = player.position - p.body.position; to_me.y = 0
	return fwd.dot(to_me.normalized()) < 0.0


func _run_test() -> void:   # (the tests live in gala_test.gd, which extends this)
	pass
