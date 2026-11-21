extends RefCounted
## Screenshot tour: plays the escape room start to finish on screen and saves a picture of each step.
##   godot --path godot --resolution 1544x720 -- --shots C:/some/folder
## (1544x720 is the shape of the S23 Ultra held sideways.) Then look through the pictures instead of tapping by hand.

var main: Control
var dir := ""
var n := 0


func run(m: Control, out_dir: String) -> void:
	main = m
	dir = out_dir if out_dir.is_absolute_path() else ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(0.6); await shot("title_card")
	await cont(); await shot("slam")
	await idle(); await shot("room_dark")
	await tap("Window"); await shot("window")
	await tap("Sign"); await shot("sign"); await idle()
	await back(); await tap("Workbench"); await shot("bench_dark")
	Game.pocket("flashlight"); main.room._aim(main.room.size * Vector2(0.5, 0.25)); await _wait(0.3); await shot("bench_flashlight_note")
	await tap("Note"); await _wait(0.7); await shot("note_leaning_in"); await idle()
	await tap("Drawer"); await idle_to_lock(); await shot("lock")
	var lock: Node = main.room.get_children().filter(func(c): return c.has_signal("tried")).front()
	for i in 4:
		for k in [4, 7, 1, 9][i]: lock._turn(i, 1)
	await _wait(0.2); await shot("lock_4719"); lock._try(); await _wait(0.4); await shot("drawer_open"); await idle()
	main.room._aim(main.room.size * Vector2(0.7, 0.88)); await _wait(0.2)
	await tap("Floorboard"); await idle(); Game.pocket("sh_driver"); await _wait(0.2); await shot("holding_screwdriver")
	await tap("Floorboard"); await idle(); await back()
	await tap("Shelf"); Game.pocket("sh_key"); await tap("Toolbox"); await _wait(0.6); await shot("toolbox"); await idle(); await back()
	await tap("Door"); Game.pocket("sh_oil"); await tap("Top hinge"); await idle()
	Game.pocket("sh_hammer"); await tap("Top hinge"); await _wait(0.6); await shot("hinges_off"); await idle(); await shot("door_open")
	main._word("기름"); await _wait(0.3); await shot("word_page"); _close_overlays()
	main._keyboard(); await _wait(0.3)
	var kb: Node = main.get_children().back()
	for c in "ㄱㅣㄹㅡㅁ": kb._type(c)
	await _wait(0.2); await shot("keyboard_test")
	print("shots: %d saved in %s" % [n, dir])
	main.get_tree().quit()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	main.get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [dir, n, name])


func _wait(s: float) -> void: await main.get_tree().create_timer(s).timeout


func cont() -> void: Game.next(); await _wait(0.3)


## Continue until there's a choice, a lock, or nothing left
func idle() -> void:
	for i in 40:
		var b: Dictionary = Game.beat()
		if b.is_empty() or b.has("ch") or b.get("type", "") == "number": break
		Game.next(); await _wait(0.05)
	await _wait(0.3)


func idle_to_lock() -> void:
	await idle(); await _wait(0.3)


func tap(label: String) -> void:
	await idle()
	for s in Game.spots_now():
		if s.l == label: Game.tap_spot(s); await _wait(0.5); return
	push_error("tour: nothing called " + label)


func back() -> void:
	await idle(); Game.enter(Game.place().back); await _wait(0.4)


func _close_overlays() -> void:
	for c in main.get_children():
		if c is ColorRect and c.color.a < 0.9 and c.color.a > 0.3: c.queue_free()
