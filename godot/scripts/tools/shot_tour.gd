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
		if cmd == "phone":   # show the phone itself, open on that thread
			main._open("phone"); await _wait(0.3); await shot("phone_list"); _close_sheets()
	await _wait(0.5)
	var ok: bool = await r.run(route)
	await _wait(0.4); await shot("end" if ok else "FAILED_here")
	if main.cork.visible:   # the case board: a card picked, a string in hand, the menu over the board
		var ids: Array = Game.board().cards.keys()
		main.cork.sel = ids[0]; main.cork.selected.emit(ids[0]); await _wait(0.3); await shot("board_card")
		main.cork.carry(ids[0]); main.cork.sel = ids[1]; main.cork.selected.emit(ids[1]); await _wait(0.3); await shot("board_carry")
		main.cork.drop(); main._menu(); await _wait(0.3); await shot("board_menu"); _close_sheets()
	for what in ["notebook", "board", "phone"]:
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


func _close_sheets() -> void:
	for c in main.get_children():
		if c is ColorRect and c.color.a > 0.5 and c.color.a < 0.75: c.queue_free()
