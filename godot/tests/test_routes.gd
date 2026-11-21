extends SceneTree
## Plays the web version's playthrough files (tests/routes/*.route) through the Godot engine (scripts/tools/route_runner.gd).
##   godot --headless --path godot -s tests/test_routes.gd                (every route)
##   godot --headless --path godot -s tests/test_routes.gd -- ch1 jobs    (some)


func _init() -> void:
	var g: Node = load("res://scripts/core/game.gd").new()
	g.testing = true
	root.add_child(g)
	await process_frame
	var w: Array = g.warnings()
	if not w.is_empty():
		printerr("FAIL story lines the Godot version doesn't understand:
  " + "
  ".join(w)); quit(1); return
	var names := OS.get_cmdline_user_args()
	if names.is_empty():
		for f in DirAccess.get_files_at("res://tests/routes"):
			if f.ends_with(".route"): names.append(f.get_basename())
	var bad := 0
	var r := RouteRunner.new(g)
	for n in names:
		if not await r.run(n): bad += 1
	print("PASS" if bad == 0 else "FAIL (%d of %d routes)" % [bad, names.size()])
	quit(1 if bad else 0)
