extends RefCounted
## Screenshot tour: plays a playthrough file on screen (scripts/tools/route_runner.gd) and saves a picture after each step.
##   godot --path godot --resolution 1544x720 -- --shots C:/some/folder [ROUTE] [STOP]
## ROUTE = a file in tests/routes (default: shed); STOP = stop at that "#@ checkpoint" (default: the end; at most 60
## pictures). At the end: the notebook, the case board and the phone, open. (1544x720 = the S23 Ultra held sideways.)

var main: Control
var dir := ""
var n := 0
const MAX := 60


func run(m: Control, out_dir: String, route := "shed", stop := "") -> void:
	main = m
	dir = out_dir if out_dir.is_absolute_path() else ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	Game.testing = true
	var r := RouteRunner.new(Game)
	r.stop_at = stop
	r.after_step = func(cmd: String, arg: String) -> void:
		if n >= MAX or cmd in ["expect", "fx", "saved", "encounters", "noboard", "nospot", "done", "shown"]: return
		await _wait(0.45)
		await shot("%s_%s" % [cmd, arg.left(18)])
		if cmd == "pocket" and main.room.set3 and Game.F.get("lit", 0):   # a 3D place: hold the light at the right edge
			main.room.set3.hold(true); main.room.set3.aim(0.95, 0.1); await _wait(1.4); await shot("light_at_edge"); main.room.set3.hold(false)
			main.room.set3.aim(0, 0); main.room.set3.drag(Vector2(-10, 0)); main.room.set3.drag(Vector2(0.0, 0.0))
			main.room.set3._look = Vector2.ZERO; main.room.set3._apply_look()
			main.room.stick.moved.emit(Vector2(0, -1)); await _wait(4.0); main.room.stick.moved.emit(Vector2.ZERO); await _wait(0.3); await shot("walked_forward")
			var s3 = main.room.set3
			if s3.has_method("climb"):
				s3.cam.position = Vector3(s3.W / 2 - 0.4, 1.55, s3.MEET_Z + 3.0); await _wait(0.4); await shot("at_the_wall")
				s3.climb(true); await _wait(1.8); await shot("climbed_up")
				await _wait(9.0); await shot("overheard_close")
				main._log_sheet(); await _wait(0.4); await shot("log_heard"); _close_sheets()
				s3.climb(false); await _wait(2.0)
				s3.cam.position = Vector3(s3.W / 2 - 0.4, 1.55, -8.0); s3.climb(true); await _wait(1.8); await _wait(16.0); await shot("overheard_further_away")
				s3.climb(false); await _wait(1.3)
		if cmd == "photo":   # show the viewfinder where that photo was taken
			var n := arg.split(" ", false); var rm: Control = main.room
			rm.camera(true); await _wait(0.1)
			rm.frame.position = Vector2(float(n[0]), float(n[1])) / 100.0 * rm.size; rm.frame.size = Vector2(float(n[2]), float(n[3])) / 100.0 * rm.size
			rm._still = 1.0; rm._focused = true; rm.frame.modulate.a = 1.0; rm.veil.queue_redraw()
			await _wait(0.3); await shot("viewfinder"); rm.camera(false)
		if cmd == "phone":   # show the phone itself, open on that thread
			main._open("phone"); await _wait(0.3); await shot("phone_list"); _close_sheets()
	await _wait(0.5)
	var ok: bool = await r.run(route)
	await _wait(2.6); await shot("end" if ok else "FAILED_here")   # past the title card
	if not main.cork.visible and not Game.board().cards.is_empty():   # open the board from the top bar
		main.board_view = true; main._refresh(); await _wait(0.4); await shot("board_open")
	if main.cork.visible:   # the case board: a card picked, a string in hand, the menu over the board
		var ids: Array = Game.board().cards.keys()
		main.cork.pick(ids[0]); await _wait(0.3); await shot("board_card")
		main.card_big(ids[0]); await _wait(0.3); await shot("board_card_big"); _close_big()
		var loose := ids.filter(func(i): return not Game.is_pinned(i))
		if not loose.is_empty(): main.cork.pick(loose[0]); await _wait(0.3); await shot("board_loose")
		var pinned := ids.filter(func(i): return Game.is_pinned(i))
		if pinned.size() >= 2: main.cork.carry(pinned[0]); main.cork.pick(pinned[1]); await _wait(0.3); await shot("board_carry")
		main.cork.drop(); main._menu(); await _wait(0.3); await shot("board_menu"); _close_sheets()
		main._box(); await _wait(0.3); await shot("board_box"); _close_sheets()
	var nb = load("res://scripts/ui/notebook.gd")
	for t in ["words", "gram", "pat", "num", "key"]:
		nb.tab = t; main._open("notebook"); await _wait(0.4); await shot("notebook_" + t); _close_sheets()
	main._settings(); await _wait(0.3); await shot("settings"); _close_sheets()
	if not Game.jobs_today().is_empty() or not Game.job_on().is_empty():
		main._open("jobs"); await _wait(0.3); await shot("jobs"); _close_sheets()
	main._log_sheet(); await _wait(0.5); await shot("log"); _close_sheets()
	for what in ["board", "phone"]:
		if what == "phone" and not Game.has_phone(): continue
		main._open(what); await _wait(0.4); await shot("open_" + what); _close_sheets()
	print("shots: %d saved in %s%s" % [n, dir, "" if ok else "  (the route failed: see FAILED_here)"])
	main.get_tree().quit()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	var safe := Story.R("[^\\w가-힣]+").sub(name, "_", true)
	main.get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [dir, n, safe])


func _wait(s: float) -> void: await main.get_tree().create_timer(s).timeout


func _close_big() -> void:
	for c in main.get_children():
		if c is ColorRect and c.color.a > 0.8: c.queue_free()


func _close_sheets() -> void:
	for c in main.get_children():
		if c is ColorRect and c.color.a > 0.5 and c.color.a < 0.75: c.queue_free()
