# ---------------------------------------------------------------- play mode (godot gala.tscn -- --play): an outside player, by text

# Commands go in build/agent/cmd.txt, one per line; what you see and hear comes out in build/agent/log.txt.
# The party only moves while a command runs (10x fast); between commands it's frozen.

const PLACES := {"bar": "at the bar", "buffet": "by the buffet", "window_l": "at the left window", "window_r": "at the right window",
	"balcony": "by the balcony doors", "lounge": "on the lounge sofas", "middle": "in the middle of the room", "door": "by the back-room door", "elevator": "by the lift"}
var tags := {}     # person id -> the letter you know them by
var seen := {}     # what you last saw each person doing


func _plg(t: String) -> void:
	if not playing or plog == null: return
	plog.store_line("[%5.1f s] %s" % [clock, t]); plog.flush()


func _desc(p: Dictionary) -> String:
	if p.is_empty(): return "someone"
	return "%s (a %s in %s)" % [tags.get(p.id, "?"), "woman" if p.id in FEMALE else "man", look_names.get(p.id, "dark clothes")]


func _perceive(p: Dictionary, text: String) -> void:   # what you'd catch of a line, from where you stand
	if not playing or text == "" or p.gone: return
	var d := player.position.distance_to(p.body.position)
	if d < READ: _plg("%s says, right beside you (the words show on screen): %s" % [_desc(p), text])
	elif d < 5.0: _plg("%s says, %.0f m away (you hear it; no text on screen): %s" % [_desc(p), d, text])
	elif d < 10.0: _plg("%s is talking, %.0f m away: too far to make out" % [_desc(p), d])


func _place(pos: Vector3) -> String:
	var best := ""; var bd := INF
	for sp in SPOTS:
		var d: float = pos.distance_to(SPOTS[sp])
		if d < bd: bd = d; best = sp
	return PLACES[best] if bd < 3.0 else "walking across the room"


func _look_log() -> void:
	var t := "You look around. You are %s. You see:" % _place(player.position)
	for p in people:
		if p.gone: continue
		var d := player.position.distance_to(p.body.position)
		var doing := "talking" if p.busy else "standing"
		var fwd := Vector3(-sin(p.body.rotation.y), 0, -cos(p.body.rotation.y)); var to_me: Vector3 = player.position - p.body.position; to_me.y = 0
		if to_me.length() > 0.1 and fwd.dot(to_me.normalized()) > 0.7: doing += ", facing you"
		t += "\n  %s, %s, %.0f m away, %s" % [_desc(p), _place(p.body.position), d, doing]
	if guesses: t += "\n  Your phone marks: " + ", ".join(guesses.keys().map(func(r): return "%s = %s" % [ROLE_NAME[r][1], tags.get(guesses[r], "?")]))
	_plg(t)


func _watch() -> void:   # things you'd notice people doing
	for p in people:
		if p.gone: continue
		var d := player.position.distance_to(p.body.position)
		var now := {"look": signf(p.glance), "coming": p.coming, "hunt": hunting and p.role == "security", "follow": p.following}
		var was: Dictionary = seen.get(p.id, {"look": 0.0, "coming": false, "hunt": false})
		if d < 10.0:
			if now.look > 0 and was.look <= 0: _plg("%s looks over at you" % _desc(p))
			if now.look < 0 and was.look >= 0: _plg("%s turns away from you" % _desc(p))
			if now.coming and not was.coming: _plg("%s leaves their group and walks toward you" % _desc(p))
		if now.follow and not was.get("follow", false): _plg("%s walks along with you" % _desc(p))
		if was.get("follow", false) and not now.follow: _plg("%s leaves you and goes back to the party" % _desc(p))
		if now.hunt and not was.hunt: _plg("%s leaves his post and walks toward you, fast" % _desc(p))
		if p.leaving and not was.get("leaving", false) and d < 10.0: _plg("%s heads for the lift to leave" % _desc(p))
		now["leaving"] = p.leaving
		seen[p.id] = now


func _run_play() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().position = Vector2i(60, 60); get_window().always_on_top = true   # on your screen, so you can watch it play
	get_window().title = "Spy box: the playtest agent is playing"
	var dir := ProjectSettings.globalize_path("res://").path_join("../build/agent")
	DirAccess.make_dir_recursive_absolute(dir)
	plog = FileAccess.open(dir.path_join("log.txt"), FileAccess.WRITE)
	var cmd_path := dir.path_join("cmd.txt")
	if not FileAccess.file_exists(cmd_path): FileAccess.open(cmd_path, FileAccess.WRITE).close()
	var letters := "ABCDEFGHIJKLMN".split("")
	var order := people.duplicate(); order.shuffle()
	for i in order.size(): tags[order[i].id] = letters[i]
	Engine.physics_ticks_per_second = int(60 * FAST); Engine.max_physics_steps_per_frame = int(8 * FAST)
	_plg("You step out of the lift into the party. Commands: look | wait N | goto LETTER | away | lift | talk | talkwith | say piece|piece|... | done | mark ROLE (host broker assistant security bartender) | leave | shot NAME | quit")
	Engine.time_scale = FAST; await _secs(1.0); _handler("h_in"); await _secs(0.5); Engine.time_scale = 0.0
	var done_n := 0
	while true:
		await get_tree().create_timer(0.15, true, false, true).timeout   # (real seconds: the party is frozen)
		var all := FileAccess.get_file_as_string(cmd_path).split("\n", false)
		while done_n < all.size():
			var c := all[done_n].strip_edges(); done_n += 1
			if c == "": continue
			_plg("> " + c)
			Engine.time_scale = FAST
			await _do(c)
			_watch()
			Engine.time_scale = 0.0
			if c == "quit": plog.close(); get_tree().quit(); return
		if arrivals.size() > 0 and clock > arrivals[0][0]:
			for p in people:
				if not tags.has(p.id): tags[p.id] = letters[tags.size()]


func _do(c: String) -> void:
	var w := c.split(" ", false)
	match w[0]:
		"look": _look_log()
		"wait":
			var n := float(w[1]) if w.size() > 1 else 2.0
			var until := clock + n
			while clock < until:
				await get_tree().create_timer(0.2).timeout; _watch()
				for p in people:
					if not tags.has(p.id): tags[p.id] = "ABCDEFGHIJKLMN"[tags.size()]; _plg("%s steps out of the lift" % _desc(p))
		"goto":
			for p in people:
				if not p.gone and tags.get(p.id, "") == (w[1] if w.size() > 1 else ""): await _beside(p); _plg("You walk over and stand beside %s" % _desc(p)); break
		"away": await _put(Vector3(-0.5, 0, 6.3)); _plg("You walk off to the empty space near the lift")
		"lift":
			await _put(Vector3(-6.0, 0, 6.6)); await _secs(0.3)
			_plg("You're at the lift doors. " + ("A Leave button shows." if leave_btn.visible else "No Leave button right now."))
		"say":
			var pcs := c.substr(4).split("|", false)
			picked.clear()
			for pc in pcs:
				var k := pc.strip_edges()
				if tile_map.has(k): picked.append(tile_map[k])
				else: _plg("(there's no piece '%s')" % k)
			if picked.is_empty() or asking.is_empty(): _plg("(nobody's waiting on you)"); return
			_plg("You say: " + _joined(picked))
			await _say_it(); await _secs(0.4); await _wait_free(); await _secs(0.3)
		"done":
			if back: _back_end(); _plg("You smile and let them get back to their talk")
		"talk":
			var tt := _talk_target()
			if tt.is_empty(): _plg("(no Talk button: nobody free right beside you)")
			else: _plg("You tap Talk beside %s" % _desc(tt)); _talk_btn()
		"talkwith":
			var cc := _companion()
			if cc.is_empty(): _plg("(nobody walking with you right now)")
			else: _plg("You turn to %s, walking with you" % _desc(cc)); _talk_to(cc)
		"mark":
			var r := w[1] if w.size() > 1 else ""
			if not ROLE_NAME.has(r): _plg("(roles: host broker assistant security bartender)"); return
			var n := _nearest()
			if n.is_empty(): _plg("(nobody close enough to mark)"); return
			_tag(r); _plg("You mark %s on your phone as %s?" % [_desc(n), ROLE_NAME[r][1]])
		"leave":
			if leave_btn.visible: await _finish(); await _secs(1.5)
			else: _plg("(no Leave button here: go to the lift first)")
		"shot": await _shot("agent_" + (w[1] if w.size() > 1 else "x")); _plg("(screenshot saved: build/spy/agent_%s.png)" % (w[1] if w.size() > 1 else "x"))
		"shoot":   # at someone (by letter), or whoever's in front of you
			if ammo <= 0: _plg("(no shots left)"); return
			for p in people:
				if not p.gone and w.size() > 1 and tags.get(p.id, "") == w[1]:
					var to: Vector3 = p.body.position - player.position; body_mesh.rotation.y = atan2(-to.x, -to.z)
			_shoot(); await _secs(0.5)
		"use":   # use sip · put · drop · throw · offer · shoot (what's in your hand)
			var a := w[1] if w.size() > 1 else ""
			if not _actions().any(func(x): return x[1] == a): _plg("(you can't %s with %s in your hand; you can: %s)" % [a, hand if hand != "" else "nothing", ", ".join(_actions().map(func(x): return x[1]))]); return
			await _act(a); await _secs(0.4)
		"bag":   # bag ITEM: put it in your hand (gun · drink · drive · free)
			var it := w[1] if w.size() > 1 else "free"
			if it == "free": _bag_pick("")
			elif it in inv: _bag_pick(it)
			else: _plg("(your bag has: %s)" % ", ".join(inv))
		"give":   # give LETTER: (while offering) tap that person
			for p in people:
				if not p.gone and w.size() > 1 and tags.get(p.id, "") == w[1]: _world_tap(cam.unproject_position(p.body.position + Vector3(0, 0.8, 0)))
			await _secs(0.4)
		"take":   # tap the nearest glass you put down
			if placed: _world_tap(cam.unproject_position(placed[0].node.global_position))
			await _secs(0.2)
		"throw":   # throw toward someone (by letter), or straight ahead
			if hand != "drink": _plg("(no glass in your hand: the bartender will give you one)"); return
			var at := Vector3.INF
			for p in people:
				if not p.gone and w.size() > 1 and tags.get(p.id, "") == w[1]: at = p.body.position
			_plg("You throw your glass" + (" toward " + w[1] if at != Vector3.INF else " ahead of you"))
			await _throw(at); await _secs(0.5)
		"quit": pass
		"heat": _plg("(debug) room doubt %d, heat stage %d, hunting=%s, security shadow=%s | " % [_room_doubt(), heat_stage, hunting, _find("security").get("shadow", false)] + ", ".join(people.filter(func(p): return p.id in ASKERS and not p.gone).map(func(p): return "%s=%d" % [tags.get(p.id, "?"), p.pic.doubt])))
		_: _plg("(unknown command)")
