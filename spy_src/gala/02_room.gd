# ---------------------------------------------------------------- the rooms

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; return m


func _box(pos: Vector3, size: Vector3, c: Color, solid := true) -> Node3D:
	var n: Node3D
	if solid:
		var b := StaticBody3D.new(); b.collision_layer = 1; b.collision_mask = 0
		var s := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; s.shape = sh; b.add_child(s); n = b
	else: n = Node3D.new()
	n.position = pos + Vector3(0, size.y / 2, 0)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = _mat(c); n.add_child(mi)
	add_child(n); return n


func _glow(pos: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.position = pos + Vector3(0, size.y / 2, 0)
	var m := _mat(c); m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = 1.2; mi.material_override = m; add_child(mi)


func _sign(text: String, size: int, pos: Vector3, parent: Node3D) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font_size = size; l.pixel_size = 0.006; l.outline_size = size / 5
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.position = pos; l.no_depth_test = true; parent.add_child(l); return l


func _room() -> void:
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.03, 0.04, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.85, 0.78, 0.7); e.ambient_light_energy = 0.75
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-65), deg_to_rad(20), 0); sun.light_energy = 0.6; sun.shadow_enabled = true; add_child(sun)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = ROOM; fl.mesh = pm; fl.material_override = _mat(Color(0.55, 0.5, 0.45)); add_child(fl)
	_box(Vector3(3.6, 0, 3.6), Vector3(4.2, 0.02, 3.4), Color(0.45, 0.2, 0.2), false)                      # rug in the lounge
	var hw := ROOM.x / 2; var hd := ROOM.y / 2; var wc := Color(0.18, 0.18, 0.22)
	_box(Vector3(0, 0, -hd), Vector3(ROOM.x, 1.4, 0.3), wc)
	_box(Vector3(-8.4, 0, hd), Vector3(3.2, 1.4, 0.3), wc); _box(Vector3(2.4, 0, hd), Vector3(15.2, 1.4, 0.3), wc)   # a gap for the lift
	_box(Vector3(-hw, 0, 0), Vector3(0.3, 1.4, ROOM.y), wc); _box(Vector3(hw, 0, 0), Vector3(0.3, 1.4, ROOM.y), wc)
	for i in 9:   # the city through the windows
		_glow(Vector3(-8.5 + i * 2.1, 1.4, -hd - 0.05), Vector3(1.8, 0.12, 0.12), Color(1.0, 0.8, 0.45))
		_glow(Vector3(-8.5 + i * 2.1 + randf_range(-0.5, 0.5), 1.6, -hd - 0.4), Vector3(0.2, 0.2, 0.2), Color(0.6, 0.8, 1.0))
	_box(Vector3(-6.0, 0, hd + 0.05), Vector3(1.6, 1.9, 0.2), Color(0.6, 0.6, 0.65))                       # elevator doors
	lift_pad = MeshInstance3D.new(); var lpm := BoxMesh.new(); lpm.size = Vector3(2.2, 0.03, 1.5); lift_pad.mesh = lpm
	lift_pad.position = Vector3(-6.0, 0.02, hd - 0.9)
	var lm := _mat(Color(0.95, 0.85, 0.45)); lm.emission_enabled = true; lm.emission = Color(0.95, 0.8, 0.35); lm.emission_energy_multiplier = 0.6
	lift_pad.material_override = lm; add_child(lift_pad)
	_sign("LIFT  ·  엘리베이터", 56, Vector3(-6.0, 1.3, hd - 1.2), self)
	back_door = _box(Vector3(-hw + 0.1, 0, 2.5), Vector3(0.2, 1.9, 1.3), Color(0.35, 0.22, 0.14), false)   # the back room's door, shut
	_back_room()
	_box(Vector3(8.2, 0, -1.0), Vector3(0.8, 1.1, 4.2), Color(0.25, 0.15, 0.1))                             # bar
	for i in 6: _glow(Vector3(9.6, 1.2, -2.8 + i * 0.7), Vector3(0.12, 0.35, 0.12), Color(0.5, 0.9, 0.6) if i % 2 else Color(0.9, 0.5, 0.3))
	_box(Vector3(-4.0, 0, -1.6), Vector3(3.0, 0.9, 1.0), Color(0.9, 0.9, 0.88))                             # buffet
	_box(Vector3(2.0, 0, 3.6), Vector3(0.9, 0.6, 2.6), Color(0.3, 0.3, 0.35)); _box(Vector3(5.2, 0, 3.6), Vector3(0.9, 0.6, 2.6), Color(0.3, 0.3, 0.35))   # sofas
	_box(Vector3(3.6, 0, 3.6), Vector3(1.0, 0.4, 1.0), Color(0.2, 0.15, 0.12))                              # low table
	for p in [Vector3(-8.8, 0, -6.2), Vector3(9.0, 0, -6.2), Vector3(-1.5, 0, -6.2)]: _box(p, Vector3(0.6, 1.2, 0.6), Color(0.2, 0.45, 0.25))   # plants
	player = CharacterBody3D.new(); player.collision_layer = 4; player.collision_mask = 1; add_child(player)
	var ps := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.5; ps.shape = cap; ps.position.y = 0.75; player.add_child(ps)
	body_mesh = _look(Color(0.25, 0.5, 0.95)); player.add_child(body_mesh)
	phone_prop = MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(0.14, 0.03, 0.24); phone_prop.mesh = pb
	var pmat := _mat(Color(0.4, 0.8, 1.0)); pmat.emission_enabled = true; pmat.emission = Color(0.3, 0.6, 0.9); phone_prop.material_override = pmat
	phone_prop.position = Vector3(0, 1.05, -0.4); phone_prop.visible = false; body_mesh.add_child(phone_prop)
	glass_prop = MeshInstance3D.new(); glass_prop.mesh = _glass_mesh(); glass_prop.material_override = _glass_mat()
	glass_prop.position = Vector3(0.34, 1.0, -0.15); body_mesh.add_child(glass_prop); glass_prop.visible = false
	gun_prop = MeshInstance3D.new(); var gb := BoxMesh.new(); gb.size = Vector3(0.08, 0.1, 0.42); gun_prop.mesh = gb
	gun_prop.material_override = _mat(Color(0.08, 0.08, 0.09)); gun_prop.position = Vector3(0.34, 1.0, -0.3); body_mesh.add_child(gun_prop)
	drive_prop = MeshInstance3D.new(); var db := BoxMesh.new(); db.size = Vector3(0.1, 0.04, 0.2); drive_prop.mesh = db
	var dm := _mat(Color(0.2, 0.6, 1.0)); dm.emission_enabled = true; dm.emission = Color(0.2, 0.6, 1.0); dm.emission_energy_multiplier = 2.0; drive_prop.material_override = dm
	drive_prop.position = Vector3(-0.34, 1.0, -0.2); drive_prop.visible = false; body_mesh.add_child(drive_prop)
	var ear := AudioListener3D.new(); ear.position.y = 1.5; player.add_child(ear); ear.make_current()   # you hear from where you stand
	player.position = START
	ring = MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.42; tm.outer_radius = 0.55; ring.mesh = tm
	var rm := _mat(Color(1, 0.85, 0.3)); rm.emission_enabled = true; rm.emission = Color(1, 0.75, 0.2); rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm; ring.visible = false; add_child(ring)
	cam = Camera3D.new(); cam.fov = 34; add_child(cam); cam.position = START + CAM_OFF; cam.look_at(START, Vector3.UP)


func _look(c: Color) -> Node3D:   # a grey-box person
	var n := Node3D.new()
	var mi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.3; cm.height = 1.5
	mi.mesh = cm; mi.position.y = 0.75; mi.material_override = _mat(c); n.add_child(mi)
	var nose := MeshInstance3D.new(); var nb := BoxMesh.new(); nb.size = Vector3(0.18, 0.13, 0.28)
	nose.mesh = nb; nose.position = Vector3(0, 1.2, -0.3); nose.material_override = _mat(c.darkened(0.55)); n.add_child(nose)
	return n


func _back_room() -> void:   # where the deal happens: rich people's room, behind the brown door
	var c := BR; var w := 10.0; var d := 8.0
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(w, d); fl.mesh = pm; fl.material_override = _mat(Color(0.22, 0.13, 0.09)); fl.position = c; add_child(fl)
	var wc := Color(0.14, 0.1, 0.12)
	_box(c + Vector3(0, 0, -d / 2), Vector3(w, 1.6, 0.3), wc); _box(c + Vector3(0, 0, d / 2), Vector3(w, 1.6, 0.3), wc)
	_box(c + Vector3(-w / 2, 0, 0), Vector3(0.3, 1.6, d), wc)
	_box(c + Vector3(w / 2, 0, -2.6), Vector3(0.3, 1.6, 2.8), wc); _box(c + Vector3(w / 2, 0, 2.6), Vector3(0.3, 1.6, 2.8), wc)   # a gap for the door
	_box(c + Vector3(w / 2 + 0.05, 0, 0), Vector3(0.2, 1.9, 2.4), Color(0.35, 0.22, 0.14), false)      # the door back out
	var gold := Color(0.95, 0.75, 0.25)
	_box(c + Vector3(-1.5, 0, 0), Vector3(5.2, 0.02, 4.2), Color(0.45, 0.08, 0.1), false)              # a red rug, gold border
	for z in [-2.12, 2.12]: _glow(c + Vector3(-1.5, 0.02, z), Vector3(5.2, 0.02, 0.08), gold)
	for x in [-4.12, 1.12]: _glow(c + Vector3(x, 0.02, 0), Vector3(0.08, 0.02, 4.2), gold)
	var velvet := Color(0.4, 0.06, 0.12)
	for z in [-2.4, 2.4]:   # two velvet sofas facing each other, gold feet
		_box(c + Vector3(-1.5, 0, z), Vector3(3.4, 0.55, 1.0), velvet)
		_box(c + Vector3(-1.5, 0, z + signf(z) * 0.45), Vector3(3.4, 1.05, 0.25), velvet)
		for x in [-3.1, 0.1]: _glow(c + Vector3(x, 0, z + 0.4), Vector3(0.12, 0.12, 0.12), gold)
	_box(c + Vector3(-4.3, 0, 0), Vector3(1.0, 0.55, 2.4), velvet)                                       # an armchair at the end
	_glow(c + Vector3(-1.5, 0, 0), Vector3(1.8, 0.42, 1.0), gold)                                        # gold coffee table
	_glow(c + Vector3(-1.9, 0.42, 0.1), Vector3(0.3, 0.3, 0.3), Color(0.3, 0.7, 0.95))                   # a crystal bowl
	for x in [-1.2, -0.9]: _glow(c + Vector3(x, 0.42, -0.15), Vector3(0.07, 0.25, 0.07), Color(0.95, 0.9, 0.7))   # champagne
	for p in [Vector3(-4.5, 0, -3.5), Vector3(-4.5, 0, 3.5), Vector3(3.7, 0, -3.5), Vector3(3.7, 0, 3.5)]:   # gold vases on stands
		_box(c + p, Vector3(0.5, 0.8, 0.5), Color(0.1, 0.08, 0.08)); _glow(c + p + Vector3(0, 0.8, 0), Vector3(0.3, 0.55, 0.3), gold)
	_glow(c + Vector3(-1.5, 0.5, -3.8), Vector3(3.2, 1.0, 0.06), gold); _box(c + Vector3(-1.5, 0.6, -3.76), Vector3(2.9, 0.8, 0.06), Color(0.15, 0.25, 0.3), false)   # a painting in a gold frame
	_box(c + Vector3(3.2, 0, 0), Vector3(0.8, 1.0, 2.0), Color(0.2, 0.12, 0.08)); _glow(c + Vector3(3.2, 1.0, 0), Vector3(0.7, 0.05, 1.9), gold)   # a sideboard with food
	for i in 4: _glow(c + Vector3(3.2, 1.05, -0.7 + i * 0.45), Vector3(0.25, 0.08, 0.25), [Color(0.9, 0.4, 0.3), Color(0.95, 0.85, 0.5), Color(0.5, 0.75, 0.4), Color(0.9, 0.6, 0.7)][i])
	var lamp := OmniLight3D.new(); lamp.position = c + Vector3(-1.5, 3.0, 0); lamp.light_color = Color(1.0, 0.8, 0.5); lamp.light_energy = 2.5; lamp.omni_range = 9.0; add_child(lamp)
	waiter = _look(Color(0.95, 0.95, 0.95)); waiter.position = c + Vector3(2.4, 0, 1.0); add_child(waiter)   # a waiter with a tray
	var tray := MeshInstance3D.new(); var tm := CylinderMesh.new(); tm.top_radius = 0.3; tm.bottom_radius = 0.3; tm.height = 0.04; tray.mesh = tm
	var tmat := _mat(gold); tmat.emission_enabled = true; tmat.emission = gold; tmat.emission_energy_multiplier = 0.8; tray.material_override = tmat
	tray.position = Vector3(0.4, 1.1, -0.2); waiter.add_child(tray)
	var bow := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.25, 0.08, 0.06); bow.mesh = bm; bow.material_override = _mat(Color(0.05, 0.05, 0.05)); bow.position = Vector3(0, 1.38, -0.28); waiter.add_child(bow)
	var lbl := _sign("최 사장님 · 방", 40, c + Vector3(-1.5, 2.2, -3.6), self); lbl.modulate = Color(1, 0.85, 0.4)


func _waiter(dt: float) -> void:   # he brings food round: to you if you're in, else between the sofas and the sideboard
	if waiter == null: return
	waiter_t += dt
	var to: Vector3 = (player.position + Vector3(0.9, 0, 0.6)) if in_back and waiter_t > 4.0 else BR + Vector3(2.4, 0, 1.0 + sin(waiter_t * 0.4) * 1.5)
	var g := to - waiter.position; g.y = 0
	if g.length() > 0.3: waiter.position += g.normalized() * minf(1.2 * dt, g.length()); waiter.rotation.y = atan2(-g.x, -g.z)
	elif in_back:
		var m := player.position - waiter.position; waiter.rotation.y = atan2(-m.x, -m.z)
