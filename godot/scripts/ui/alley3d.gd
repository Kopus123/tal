extends Node3D
## The alley at night, as a real 3D set: dark brick walls with tiled Korean wall caps, a row of brick archways with
## ivy hanging from them, wet stone paving, paper lanterns that light the bricks and throw shadows, a warm lit doorway
## at the end, a cool moon, and fog that thickens into the distance. Materials: CC0 from Poly Haven (textures/).
## Units are metres. You stand at z = 0 looking down the alley (-z).

const W := 3.4          ## alley width
const H := 4.2          ## wall height
const L := 34.0         ## alley length
const ARCHES := [-5.5, -12.5, -19.5]

var cam: Camera3D
var torch: SpotLight3D  ## your flashlight
var _base_rot := Vector3(-3, 0, 0)
var _lanterns: Array = []


func _ready() -> void:
	_environment()
	_floor(); _walls()
	for z in ARCHES: _arch(z)
	_end_house()
	for i in ARCHES.size(): _lantern(Vector3(0.0, 2.95, ARCHES[i] + 0.55), i > 0)   # hanging from each arch; the nearest one has gone out
	_lantern(Vector3(0.9, 2.6, -L + 3.4))
	_ivy()
	_puddles()
	var probe := ReflectionProbe.new(); probe.size = Vector3(W + 2, H + 2, L); probe.position = Vector3(0, H / 2, -L / 2 + 2)
	probe.box_projection = true; probe.update_mode = ReflectionProbe.UPDATE_ONCE; probe.intensity = 1.0; add_child(probe)   # what the wet stone reflects
	cam = Camera3D.new(); cam.position = Vector3(0, 1.55, 1.2); cam.rotation_degrees = _base_rot; cam.fov = 62; add_child(cam); cam.current = true
	torch = SpotLight3D.new(); torch.light_color = Color(1.0, 0.94, 0.82); torch.light_energy = 9.0; torch.spot_range = 26; torch.spot_angle = 20
	torch.spot_attenuation = 0.8; torch.shadow_enabled = true; torch.light_volumetric_fog_energy = 1.4; torch.visible = false; cam.add_child(torch)


func _process(dt: float) -> void:   # the lantern flames breathe a little; a light held near the edge turns your head
	if torch.visible and _held:
		var push := Vector2.ZERO
		for k in 2:
			var a: float = _aim[k]
			if absf(a) > EDGE: push[k] = signf(a) * (absf(a) - EDGE) / (1.0 - EDGE)
		if push != Vector2.ZERO: _look = (_look + push * dt * 1.1).clamp(Vector2(-1, -1), Vector2(1, 1)); _apply_look()
	var t := Time.get_ticks_msec() / 1000.0
	for i in _lanterns.size():
		var l: OmniLight3D = _lanterns[i]
		l.light_energy = 0.75 + 0.09 * sin(t * 7.0 + i * 1.7) + 0.05 * sin(t * 13.0 + i)


## look around (drag with no light), and point the flashlight; hold the light near an edge and the view turns that way
const EDGE := 0.6           ## how far toward the edge (of -1..1) before the view starts to turn
var _look := Vector2.ZERO   ## where you're looking, -1..1 each way
var _aim := Vector2.ZERO    ## where the light points on the screen, -1..1
var _held := false          ## a finger is on the picture

func drag(d: Vector2) -> void:   ## move the view by a drag (in -1..1 units)
	_look = (_look + d).clamp(Vector2(-1, -1), Vector2(1, 1)); _apply_look()

func _apply_look() -> void:
	cam.rotation_degrees = _base_rot + Vector3(-_look.y * 8.0, -_look.x * 20.0, 0)

func hold(on: bool) -> void: _held = on

func aim(nx: float, ny: float) -> void:
	_aim = Vector2(nx, ny)
	torch.rotation_degrees = Vector3(-ny * 20.0, -nx * 28.0, 0)

func set_torch(on: bool) -> void: torch.visible = on


# ---------------------------------------------------------------- materials
func _mat(name: String, uv: Vector3, rough := 1.0, tri := true, albedo := "albedo") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/%s/%s.jpg" % [name, albedo])
	m.normal_enabled = true; m.normal_texture = load("res://textures/%s/normal.jpg" % name); m.normal_scale = 1.2
	m.roughness_texture = load("res://textures/%s/rough.jpg" % name); m.roughness = rough
	m.uv1_scale = uv
	if tri: m.uv1_triplanar = true; m.uv1_world_triplanar = true
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	var mi := MeshInstance3D.new(); mi.mesh = b; mi.position = pos; mi.material_override = mat; add_child(mi)
	return mi


# ---------------------------------------------------------------- the set
func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.015, 0.02, 0.05); sm.sky_horizon_color = Color(0.06, 0.08, 0.14); sm.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sm.ground_horizon_color = Color(0.05, 0.06, 0.1); sm.sun_angle_max = 2.0; sky.sky_material = sm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.13, 0.17, 0.3); env.ambient_light_energy = 0.05
	env.tonemap_mode = Environment.TONE_MAPPER_AGX; env.tonemap_exposure = 0.85
	env.glow_enabled = true; env.glow_intensity = 0.9; env.glow_bloom = 0.08; env.glow_hdr_threshold = 0.9
	env.ssr_enabled = true; env.ssr_max_steps = 48; env.ssr_fade_in = 0.1
	env.ssao_enabled = true; env.ssao_intensity = 1.6
	env.volumetric_fog_enabled = true; env.volumetric_fog_density = 0.06; env.volumetric_fog_albedo = Color(0.5, 0.58, 0.78)
	env.volumetric_fog_emission = Color(0.003, 0.004, 0.009); env.volumetric_fog_anisotropy = 0.3; env.volumetric_fog_length = 40
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var moon := DirectionalLight3D.new(); moon.light_color = Color(0.5, 0.62, 1.0); moon.light_energy = 0.16
	moon.rotation_degrees = Vector3(-38, 35, 0); moon.shadow_enabled = true; moon.light_volumetric_fog_energy = 0.6; add_child(moon)


func _floor() -> void:
	var m := _mat("large_grey_tiles", Vector3(0.55, 0.55, 0.55), 0.55)   # damp stone
	m.albedo_color = Color(0.7, 0.72, 0.78)
	_box(Vector3(W + 2, 0.2, L), Vector3(0, -0.1, -L / 2 + 2), m)


func _walls() -> void:
	var brick := _mat("dark_brick_wall", Vector3(0.7, 0.7, 0.7), 1.0, true, "albedo_black")
	var roof := _mat("grey_roof_tiles", Vector3(0.9, 0.9, 0.9), 0.8)
	for side in [-1, 1]:
		var x: float = side * (W / 2 + 0.25)
		_box(Vector3(0.5, H, L), Vector3(x, H / 2, -L / 2 + 2), brick)
		# the tiled cap along the top, overhanging into the alley (a Korean wall's 기와)
		var cap := _box(Vector3(1.1, 0.22, L), Vector3(x - side * 0.15, H + 0.12, -L / 2 + 2), roof)
		cap.rotation_degrees = Vector3(0, 0, side * 14)
		_box(Vector3(0.7, 0.12, L), Vector3(x, H + 0.02, -L / 2 + 2), roof)


## a brick archway across the alley: a block with a round-topped opening cut out
func _arch(z: float) -> void:
	var brick := _mat("dark_brick_wall", Vector3(0.7, 0.7, 0.7), 1.0, true, "albedo_black")
	var c := CSGCombiner3D.new(); c.position = Vector3(0, 0, z); add_child(c)
	var block := CSGBox3D.new(); block.size = Vector3(W + 1.0, H + 0.6, 0.7); block.position = Vector3(0, (H + 0.6) / 2, 0); block.material = brick; c.add_child(block)
	var hole_w := W - 0.9
	var low := CSGBox3D.new(); low.operation = CSGShape3D.OPERATION_SUBTRACTION; low.size = Vector3(hole_w, 2.2, 1.0); low.position = Vector3(0, 1.1, 0); c.add_child(low)
	var top := CSGCylinder3D.new(); top.operation = CSGShape3D.OPERATION_SUBTRACTION; top.radius = hole_w / 2; top.height = 1.0; top.sides = 32
	top.rotation_degrees = Vector3(90, 0, 0); top.position = Vector3(0, 2.2, 0); c.add_child(top)
	var cap := _box(Vector3(W + 1.4, 0.2, 1.0), Vector3(0, H + 0.7, z), _mat("grey_roof_tiles", Vector3(0.9, 0.9, 0.9), 0.8))
	cap.name = "archcap"


## the end of the alley: a wooden door in a lit doorway, warm light spilling out onto the wet stone
func _end_house() -> void:
	var z := -L + 2.2
	_box(Vector3(W + 1, H + 0.6, 0.5), Vector3(0, (H + 0.6) / 2, z), _mat("dark_brick_wall", Vector3(0.7, 0.7, 0.7), 1.0, true, "albedo_black"))
	var wood := _mat("dark_planks", Vector3(0.6, 0.6, 0.6), 0.9)
	_box(Vector3(0.75, 2.1, 0.08), Vector3(-0.45, 1.05, z + 0.3), wood)                     # one door leaf open
	var glow := StandardMaterial3D.new(); glow.emission_enabled = true; glow.emission = Color(1.0, 0.7, 0.38); glow.emission_energy_multiplier = 3.0
	glow.albedo_color = Color(1.0, 0.75, 0.45)
	_box(Vector3(0.75, 2.1, 0.05), Vector3(0.3, 1.05, z + 0.26), glow)                       # the lit room beyond
	var spill := OmniLight3D.new(); spill.position = Vector3(0.3, 1.3, z + 1.2); spill.light_color = Color(1.0, 0.68, 0.36)
	spill.light_energy = 2.2; spill.omni_range = 5; spill.shadow_enabled = true; spill.light_volumetric_fog_energy = 2.0; add_child(spill)


## a paper lantern on a short wire: a glowing body, and the light it throws (with shadows)
func _lantern(p: Vector3, lit := true) -> void:
	var paper := StandardMaterial3D.new(); paper.albedo_color = Color(0.95, 0.35, 0.2); paper.emission_enabled = true
	paper.emission = Color(1.0, 0.5, 0.25); paper.emission_energy_multiplier = 1.0 if lit else 0.0
	if not lit: paper.albedo_color = Color(0.35, 0.14, 0.1); paper.roughness = 0.8
	var body := MeshInstance3D.new(); var cap := CapsuleMesh.new(); cap.radius = 0.2; cap.height = 0.55; body.mesh = cap
	body.material_override = paper; body.position = p; body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(body)   # its own light is inside it
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.05, 0.04, 0.04)
	for dy in [0.29, -0.29]:
		var ring := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.12; cy.bottom_radius = 0.12; cy.height = 0.05; ring.mesh = cy
		ring.material_override = dark; ring.position = p + Vector3(0, dy, 0); ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(ring)
	_box(Vector3(0.015, H + 0.3 - p.y, 0.015), Vector3(p.x, (H + 0.3 + p.y) / 2 + 0.3, p.z), dark)   # the wire up to the wall cap
	if not lit: return
	var l := OmniLight3D.new(); l.position = p + Vector3(0, -0.1, 0); l.light_color = Color(1.0, 0.6, 0.33); l.light_energy = 0.75
	l.omni_range = 4.2; l.omni_attenuation = 1.3; l.shadow_enabled = true; l.light_volumetric_fog_energy = 1.6; add_child(l)
	_lanterns.append(l)


## ivy hanging from the archways and spilling over the wall tops: many small leaves, each a cut-out quad
func _ivy() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8); img.fill(Color(0, 0, 0, 0))
	for y in 64:
		for x in 64:
			var u := (x - 32) / 32.0; var v := (y - 34) / 30.0
			if absf(u) < 0.95 * (1.0 - v * v) * (0.7 if v < 0 else 1.0) and absf(v) < 1.0:
				var shade := 0.75 + 0.25 * (1.0 - absf(u))
				img.set_pixel(x, y, Color(0.26 * shade, 0.5 * shade, 0.2 * shade, 1.0))
	var leaf := StandardMaterial3D.new(); leaf.albedo_texture = ImageTexture.create_from_image(img)
	leaf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; leaf.cull_mode = BaseMaterial3D.CULL_DISABLED; leaf.roughness = 0.55
	leaf.backlight_enabled = true; leaf.backlight = Color(0.35, 0.5, 0.2)   # light through the leaves
	var quad := QuadMesh.new(); quad.size = Vector2(0.21, 0.21)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = quad
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var spots: Array = []
	for z in ARCHES:   # curtains of ivy down the face of each arch, and over its top
		for k in 44:
			var x := rng.randf_range(-W / 2 - 0.4, W / 2 + 0.4); var hang := rng.randf_range(0.4, 1.9) * (1.3 if absf(x) > W / 2 - 0.6 else 0.6)
			for j in int(hang / 0.07):
				spots.append(Vector3(x + rng.randf_range(-0.06, 0.06), H + 0.4 - j * 0.07, z + 0.37 + rng.randf_range(0, 0.05)))
	for side in [-1, 1]:   # tumbling over the walls here and there
		for k in 34:
			var z := rng.randf_range(-L + 4, 1.0); var hang := rng.randf_range(0.5, 2.4)
			for j in int(hang / 0.07):
				spots.append(Vector3(side * (W / 2 - 0.02) - side * rng.randf_range(0, 0.04), H - j * 0.07, z + rng.randf_range(-0.12, 0.12)))
	mm.instance_count = spots.size()
	for i in spots.size():
		var b := Basis(Vector3.UP, rng.randf_range(-0.8, 0.8)).rotated(Vector3.RIGHT, rng.randf_range(-0.6, 0.6)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
		mm.set_instance_transform(i, Transform3D(b, spots[i]))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = leaf; add_child(mi)


## standing water in the dips: a mirror for the lanterns, with a ragged natural edge
func _puddles() -> void:
	var n := FastNoiseLite.new(); n.seed = 3; n.frequency = 0.045; n.fractal_octaves = 3
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := Vector2(x - 64, y - 64).length() / 64.0
			var a := 1.0 if (1.0 - d) + n.get_noise_2d(x, y) * 0.9 > 0.35 else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var wet := StandardMaterial3D.new(); wet.albedo_texture = ImageTexture.create_from_image(img); wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	wet.albedo_color = Color(0.09, 0.1, 0.13); wet.roughness = 0.04; wet.metallic = 0.2; wet.metallic_specular = 0.9
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	for i in 9:
		var p := MeshInstance3D.new(); var pm := PlaneMesh.new(); var k := rng.randf_range(0.7, 1.7); pm.size = Vector2(k, k * rng.randf_range(0.6, 1.2)); p.mesh = pm
		p.material_override = wet; p.position = Vector3(rng.randf_range(-1.0, 1.0), 0.005, rng.randf_range(-22, -1)); p.rotation_degrees.y = rng.randf_range(0, 180); add_child(p)
