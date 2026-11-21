extends SceneTree
## Plays the escape room through from start to finish without drawing anything (story logic only).
##   godot --headless --path godot -s tests/test_shed.gd
## Same steps as tests/shed.route in the web version.

var g: Node
var steps := 0
var failed := false


func _init() -> void:
	g = load("res://scripts/core/game.gd").new()
	root.add_child(g)
	await process_frame
	_run()
	print("PASS  shed: %d steps" % steps if not failed else "FAIL")
	quit(1 if failed else 0)


func fail(msg: String) -> void:
	if failed: return
	failed = true
	printerr("FAIL step %d: %s   (at %s, beat %s)" % [steps, msg, g.loc, g.node])


func expect(c: String) -> void:
	steps += 1
	if not g.cond(c): fail("expected " + c)


## Continue through beats until there's a choice, a number lock, or nothing left
func idle() -> void:
	for i in 60:
		if g.node == "" or failed: return
		var b: Dictionary = g.beat()
		if b.has("ch") or b.get("type", "") == "number": return
		g.next()
	fail("never finished the scene")


func tap(label: String) -> void:
	idle(); steps += 1
	for s in g.spots_now():
		if s.l == label: g.tap_spot(s); return
	fail("nothing called %s to tap (here: %s)" % [label, ", ".join(g.spots_now().map(func(s): return s.l))])


func back() -> void:
	idle(); steps += 1
	if not g.place().has("back"): fail("no way back here"); return
	g.enter(g.place().back)


func pocket(id: String) -> void:
	idle(); steps += 1
	if not g.pockets().any(func(e): return e.id == id): fail(id + " isn't in your pockets"); return
	g.pocket(id)


func choose(text: String) -> void:
	idle(); steps += 1
	for o in g.beat().get("ch", []):
		if (o.get("en", "") + o.get("ko", "")).contains(text) and g.cond(o.c): g.choose(o); return
	fail("no choice " + text)


func number(v: String) -> void:
	idle(); steps += 1
	if g.beat().get("type", "") != "number": fail("no number lock here"); return
	g.answer(v)


func _run() -> void:
	g.start("shed.story")
	if not g.ch.warnings.is_empty(): fail("story lines not understood: " + str(g.ch.warnings)); return
	idle(); expect("@shed&!free&time:night&ev_flashlight&!lit")
	tap("Door"); tap("Handle"); idle(); back()
	tap("Window"); tap("Latch"); idle(); tap("Glass"); idle(); tap("Sign"); idle(); expect("sawSign"); back()
	tap("Workbench"); tap("Drawer"); idle()
	pocket("flashlight"); expect("lit")
	tap("Note"); idle(); expect("ev_sh_note")
	tap("Drawer"); number("1234"); idle(); expect("!drawerOpen")
	tap("Drawer"); number("4719"); idle(); expect("drawerOpen&ev_sh_driver")
	tap("Floorboard"); idle(); pocket("sh_driver"); expect("hold:sh_driver")
	tap("Floorboard"); idle(); expect("ev_sh_key&!hold:sh_driver"); back()
	tap("Shelf"); pocket("sh_key"); tap("Toolbox"); idle(); expect("ev_sh_oil&ev_sh_hammer"); back()
	tap("Window"); pocket("sh_oil"); tap("Latch"); idle(); expect("latchOiled"); back()
	tap("Door"); pocket("sh_hammer"); tap("Top hinge"); idle(); expect("!oiled&!free")
	pocket("sh_oil"); tap("Bottom hinge"); idle(); expect("oiled")
	pocket("sh_hammer"); tap("Top hinge"); idle(); expect("free")
	tap("Doorway"); idle()
