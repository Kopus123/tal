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
var _lanterns: Array = []


func _ready() -> void:
	_environment()
	_floor(); _walls()
	for z in ARCHES: _arch(z)
	_end_house()
	_yard()
	_make_gate()
	for i in ARCHES.size(): _lantern(Vector3(0.0, 2.95, ARCHES[i] + 0.55), i > 0)   # hanging from each arch; the nearest one has gone out
	_lantern(Vector3(0.9, 2.6, -L + 3.4))
	_ivy()
	_puddles()
	var probe := ReflectionProbe.new(); probe.size = Vector3(W + 2, H + 2, L); probe.position = Vector3(0, H / 2, -L / 2 + 2)
	probe.box_projection = true; probe.update_mode = ReflectionProbe.UPDATE_ONCE; probe.intensity = 1.0; add_child(probe)   # what the wet stone reflects
	cam = Camera3D.new(); cam.position = Vector3(0, 1.55, 1.2); cam.rotation_degrees = Vector3(-3, 0, 0); cam.fov = FOV; add_child(cam); cam.current = true
	torch = SpotLight3D.new(); torch.light_color = Color(1.0, 0.94, 0.82); torch.light_energy = 9.0; torch.spot_range = 26; torch.spot_angle = 20
	torch.spot_attenuation = 0.8; torch.shadow_enabled = true; torch.light_volumetric_fog_energy = 1.4; torch.visible = false; cam.add_child(torch)


## ---------- climbing the right wall: up against it (not in an archway), you can pull yourself up and look over the top
signal climb_changed(can: bool, up: bool)
signal overheard(who: String, ko: String, clear: float)   ## a line from the courtyard, and how much of it you caught (0..1)
signal spotted   ## they saw you: the chase is on
signal grabbed   ## he caught you in the alley
signal got_away  ## you got out of the alley ahead of him   ## whether you're at the wall / up on it (the screen shows the button)
const MEET_Z := -14.0   ## where along the alley the two people are standing, on the other side of the right wall
var up := false
var _can := false
var _busy := false
var _down_at := Vector3.ZERO

func can_climb() -> bool:
	if up or _busy or _chase or _spooked: return false
	if cam.position.x < W / 2 - 0.55: return false
	for z in ARCHES:
		if absf(cam.position.z - z) < 0.9: return false
	return true

func climb(on: bool) -> void:
	if _busy or on == up: return
	_busy = true; _move = Vector2.ZERO
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if on:
		_down_at = cam.position
		var top := Vector3(W / 2 + 0.4, H + 0.68, cam.position.z)   # head and shoulders over the top, leaning out
		t.tween_property(cam, "position", Vector3(cam.position.x, H * 0.55, cam.position.z), 0.6)   # hands on the wall, pulling up
		t.chain().tween_property(cam, "position", top, 0.55)
		_down_yaw = _yaw; _face(-75.0, -15.0, 1.0); _up_yaw = _face_to
	else:
		t.tween_property(cam, "position", Vector3(_down_at.x, H * 0.5, _down_at.z), 0.5)
		t.chain().tween_property(cam, "position", _down_at, 0.4)
		_face(_down_yaw, -3.0, 0.8)   # the way you were facing
	t.chain().tween_callback(func():
		_busy = false; up = on
		if on: _got_up()
		climb_changed.emit(can_climb(), up))


## ---------- the courtyard conversation: a line every few seconds, then a pause, then it starts again.
## Up on the wall near them you hear it clearly; further along, quieter and muffled; from down in the alley, the wall
## swallows most of it. What you catch shows on the paper (the rest as …).
var _voices: Array = []
var _talk: Array = []      ## [{who, ko}]
var _line := 0
var _next := 3.0

func set_talk(lines: Array) -> void: _talk = lines

func clarity() -> float:
	var d := absf(cam.position.z - MEET_Z)
	if not up: return -1.0 if d < 8.0 else 0.0   # down in the alley near them: muffled through the wall (-1)
	return clampf(1.0 - (d - 4.0) / 7.0, 0.0, 1.0)   # within about 4 m of them, every word

func _talk_tick(dt: float) -> void:
	for pl in _voices: pl.bus = _yard_bus() if up or _chase else _wall_bus()   # through a brick wall, only a mumble
	if _talk.is_empty() or _alarm > 0.0: return
	_next -= dt
	if _next > 0: return
	var l: Dictionary = _talk[_line]
	var v: AudioStreamPlayer3D = _voices[0 if l.who == "stranger" else 1]
	var s := Voice.stream_for(l.ko, l.who)
	v.volume_db = lerpf(-4.0, 7.0, clarity()) if up else 4.0   # near them, as loud as anyone talking to you
	v.attenuation_filter_cutoff_hz = lerpf(1200, 7000, clarity()) if up else 2000.0
	if s: v.stream = s; v.play()
	overheard.emit(l.who, l.ko, clarity())
	_line += 1
	if _line >= _talk.size(): _line = 0; _next = 5.0   # a pause before they go over it again
	else: _next = (s.get_length() if s else 2.0) + 0.9


## their voices have a bus of their own that evens them out and lifts them, so a phone's speaker carries every syllable
func _yard_bus() -> String:
	if AudioServer.get_bus_index("Yard") < 0:
		AudioServer.add_bus(); var i := AudioServer.bus_count - 1; AudioServer.set_bus_name(i, "Yard")
		var l := AudioEffectHardLimiter.new(); l.pre_gain_db = 9.0; l.ceiling_db = -1.0; l.release = 0.15; AudioServer.add_bus_effect(i, l)
	return "Yard"


## through the wall: everything that makes words out is gone
func _wall_bus() -> String:
	if AudioServer.get_bus_index("Wall") < 0:
		AudioServer.add_bus(); var i := AudioServer.bus_count - 1; AudioServer.set_bus_name(i, "Wall")
		var f := AudioEffectLowPassFilter.new(); f.cutoff_hz = 480.0; f.resonance = 0.15; f.db = AudioEffectFilter.FILTER_24DB; AudioServer.add_bus_effect(i, f)
		var l := AudioEffectHardLimiter.new(); l.pre_gain_db = 11.0; l.ceiling_db = -3.0; AudioServer.add_bus_effect(i, l)
	return "Wall"


## ---------- photos: what's in the frame (a secret the board keeps), and the click of the shutter
func photo_subject(frame: Rect2) -> String:
	if not up or _chase or _spooked: return ""
	for g in _people:
		var head: Vector3 = g.position + Vector3(0, 1.5, 0)
		if not g.visible or cam.is_position_behind(head) or not frame.has_point(cam.unproject_position(head)): return ""
	return "s_meeting" if absf(cam.position.z - MEET_Z) < 9.0 else ""   # both of them, near enough to make out

func on_shutter() -> void:   # a click in the quiet: one of them looks round
	if _people.is_empty() or _chase or _spooked: return
	if up and _near(): _sus[randi() % _people.size()] += 0.75


## ---------- they get suspicious. Each of them has a meter that fills by itself, at a pace that keeps changing (so they
## look round often, but never like clockwork). A noise adds to it; your light on them fills it in under a second. Full:
## that one turns their head to the wall for a moment, and the meter starts again. If you're up there, in sight, while
## a head is turned, it's only a moment before they notice you; and once they have, they come after you.
signal wary(what: String)      ## "look": a head is turning your way while you're up there; "" = not any more
const PACE := [0.02, 0.11]     ## how much of the meter fills a second, left alone (a new pace every second or three)
const LIT := 1.5               ## ... with your light on them: full in about 0.7 s
const TURN := [1.1, 0.35]      ## seconds to turn a head round: an idle look, startled by a light
const SEE := [1.3, 0.3]        ## how long you can be in sight of a turned head: dark, with your light on
const FIRST_CLIMB := 2.0       ## the first time you get up there, nobody looks round for a couple of seconds unless you give them reason
var _people: Array = []
var _sus := [0.0, 0.0]         ## the meters, 0..1
var _pace := [0.06, 0.06]
var _pace_for := [0.0, 0.0]
var _looking := [0.0, 0.0]     ## how much longer each one's head stays turned
var _turned := [0.0, 0.0]      ## how far round it is, 0..1
var _turn_s := [1.1, 1.1]      ## how fast it's turning this time
var _seen_for := 0.0           ## how long you've been in sight of a turned head
var _calm := 0.0               ## the first climb's head start
var _been_up := false
var _alarm := 0.0              ## how much longer they stay quiet after hearing you
var _steps: AudioStreamPlayer
var _wary := ""

func _near() -> bool: return absf(cam.position.z - MEET_Z) < 14.0

func _set_wary(w: String) -> void:
	if w != _wary: _wary = w; wary.emit(w)

## your light is on that one: up on the wall, pointed at them
func _lit(g: Node3D) -> bool:
	if not (up and torch.visible): return false
	var to: Vector3 = g.global_position + Vector3(0, 1.1, 0) - torch.global_position
	return to.length() < torch.spot_range and (-torch.global_basis.z).angle_to(to) < deg_to_rad(torch.spot_angle + 3.0)

func _notice_tick(dt: float) -> void:
	if _people.is_empty(): return
	_alarm = maxf(0.0, _alarm - dt); _calm = maxf(0.0, _calm - dt)
	var in_sight := false; var lit_any := false; var turning := false
	for k in _people.size():
		var g: Node3D = _people[k]; var lit := _lit(g); lit_any = lit_any or lit
		_pace_for[k] -= dt
		if _pace_for[k] <= 0.0: _pace_for[k] = randf_range(0.8, 3.0); _pace[k] = randf_range(PACE[0], PACE[1])
		if _looking[k] > 0.0:
			_looking[k] -= dt
			if lit: _looking[k] = maxf(_looking[k], 0.8); _turn_s[k] = TURN[1]   # no looking away from a light in your eyes
			_turned[k] = minf(1.0, _turned[k] + dt / _turn_s[k])
			turning = true
			if up and not _busy and _near() and _turned[k] > 0.75: in_sight = true
		else:
			_turned[k] = maxf(0.0, _turned[k] - dt / 0.9)
			var fill: float = _pace[k]
			if lit: fill = LIT
			elif up and torch.visible and _near(): fill *= 3.0   # a light moving about up there, not on them
			elif _calm > 0.0: fill = 0.0
			_sus[k] += fill * dt
			if _sus[k] >= 1.0:
				_sus[k] = randf_range(0.0, 0.25); _looking[k] = randf_range(2.2, 4.0); _turn_s[k] = TURN[1] if lit else TURN[0] * randf_range(0.8, 1.25)
		_pose(g, _turned[k])
	_seen_for = _seen_for + dt if in_sight else maxf(0.0, _seen_for - dt * 2.0)
	if _seen_for > (SEE[1] if lit_any or (up and torch.visible) else SEE[0]): _seen(); return
	_set_wary("look" if turning and up and _near() else "")

## a head (and then the shoulders, a little) coming round from whoever they're talking to, to the top of the wall
func _pose(g: Node3D, k: float) -> void:
	var e := k * k * (3.0 - 2.0 * k); var idle: float = g.get_meta("idle")
	var to := rad_to_deg(atan2(-(cam.position.x - g.position.x), -(cam.position.z - g.position.z))) if up else 90.0
	var off := wrapf(to - idle, -180.0, 180.0)
	g.rotation_degrees.y = idle + off * 0.45 * e
	var h: Node3D = g.get_meta("head"); h.rotation_degrees = Vector3(18.0 * e if up else 0.0, off * 0.55 * e, 0)

## you're up there: the first time, they're deep in conversation
func _got_up() -> void:
	_next = minf(_next, 1.2)
	if not _been_up: _been_up = true; _calm = FIRST_CLIMB; _sus = [randf_range(0.1, 0.4), randf_range(0.1, 0.4)]
	for k in 2: _sus[k] = minf(_sus[k], 0.6)

## running near them: every footfall adds up, and then they go quiet and turn round
func _heard_you() -> void:
	if absf(cam.position.z - MEET_Z) > 7.0 or _alarm > 0.0: return
	for k in _people.size(): _sus[k] += randf_range(0.2, 0.4)
	if _sus.max() < 1.0: return
	_alarm = 4.0; _next = 1.2; _calm = 0.0
	for k in _people.size(): _sus[k] = 0.0; _looking[k] = 4.0; _turn_s[k] = 0.8
	var s := Voice.stream_for("쉿... {누구}{예요|이에요}?", "stranger_b")
	if s: _voices[0].stop(); _voices[1].stream = s; _voices[1].volume_db = 2.0; _voices[1].attenuation_filter_cutoff_hz = 1500; _voices[1].play()

## they've noticed you: a shout, and they run for the gate. You hang there a heartbeat, then drop
func _seen() -> void:
	if _chase or _spooked: return
	_set_wary(""); _seen_for = 0.0; _alarm = 0.0
	_chase = true; _chase_t = 0.0; _gate_open = false
	_chasers = []
	for k in _people.size(): _chaser(_people[k], CHASERS[k])
	_shout("{누구}{예요|이에요}?!", -8.0)
	if up or _busy:
		_busy = true; var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var land := Vector3(W / 2 - 0.45, EYE, cam.position.z)
		t.tween_interval(HANG)
		t.tween_callback(func(): _face(0.0, -3.0, 0.35))
		t.tween_property(cam, "position", land, 0.35)
		t.tween_callback(func(): _busy = false; up = false; climb_changed.emit(false, false))
	spotted.emit()


## ---------- the chase: they run across the courtyard to the gate in the right wall, it bangs open, and they come out
## after you, one then the other, each with a flashlight. Get out of the alley (back past the entrance) before one
## reaches you, and they're too spooked to stay: they go inside. Grabbed: start over.
const GATE_Z := -17.5        ## the gate from the courtyard into the alley (a little past where they stand)
const HANG := 0.55           ## you're frozen up there this long before you let go
const CHASERS := [[0.5, 4.8], [1.0, 4.6]]   ## each: [seconds before they start running, speed]
var _chase := false
var _chase_t := 0.0          ## since they noticed you
var _spooked := false        ## you got away: they've gone in, the courtyard is empty and quiet
var _chasers: Array = []     ## [{n: Node3D, speed, wait, step: AudioStreamPlayer3D, beam, stride, leg}]
var _gate: Node3D            ## the gate's door, on its hinge
var _gate_open := false

func _shout(ko: String, db: float) -> void:
	var s := Voice.stream_for(ko, "stranger")
	if s == null: return
	var v: AudioStreamPlayer3D = _voices[0]; v.stop()
	if not _chasers.is_empty() and v.get_parent() == self: v.reparent(_chasers[0].n, false); v.position = Vector3(0, 1.6, 0)
	v.stream = s; v.volume_db = db; v.attenuation_filter_cutoff_hz = 6000; v.play()

func _chaser(n: Node3D, how: Array) -> void:   # one of the two, light out, about to run
	var beam := SpotLight3D.new(); beam.position = Vector3(0.15, 1.3, -0.2); beam.light_color = Color(1.0, 0.92, 0.75)
	beam.light_energy = 7.0; beam.spot_range = 18; beam.spot_angle = 22; beam.shadow_enabled = true; beam.light_volumetric_fog_energy = 2.0
	beam.rotation_degrees = Vector3(-8, 0, 0); beam.visible = false; n.add_child(beam)
	var st := AudioStreamPlayer3D.new(); st.stream = load("res://sfx/step.wav"); st.unit_size = 3.0; st.volume_db = -10.0; st.max_db = -10.0; st.position = Vector3(0, 0.2, 0); n.add_child(st)
	_chasers.append({"n": n, "wait": how[0], "speed": how[1], "step": st, "beam": beam, "stride": 0.0, "leg": 0, "t": 0.0})

func _chase_tick(dt: float) -> void:
	if not _chase: return
	_chase_t += dt
	for c in _chasers:
		var n: Node3D = c.n
		var me := cam.position - n.position; me.y = 0
		if _chase_t < c.wait:   # staring at you
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-me.x, -me.z), 1.0 - exp(-dt * 12.0)); continue
		c.beam.visible = true
		var h: Node3D = n.get_meta("head"); h.rotation = h.rotation.lerp(Vector3.ZERO, 1.0 - exp(-dt * 8.0))
		# to the gate, through it, then straight at you
		var inside := Vector3(W / 2 + 1.3, 0, GATE_Z); var outside := Vector3(W / 2 - 0.8, 0, GATE_Z)
		var flat := Vector3(n.position.x, 0, n.position.z)
		if c.leg == 0 and flat.distance_to(inside) < 0.3: c.leg = 1; c.t = 0.0
		if c.leg == 1 and n.position.x < W / 2 - 0.5:
			c.leg = 2; c.t = 0.0
			if c == _chasers[0]: _shout("거기 서!", -6.0)
		if not _gate_open and flat.distance_to(inside) < 1.6:   # the first one there throws it open
			_gate_open = true
			var cr := AudioStreamPlayer3D.new(); cr.stream = load("res://sfx/gate.wav"); cr.unit_size = 5.0; cr.position = Vector3(W / 2, 1.2, GATE_Z); add_child(cr); cr.play()
			cr.finished.connect(cr.queue_free)
			create_tween().tween_property(_gate, "rotation_degrees:y", -105.0, 0.4).set_trans(Tween.TRANS_BACK)
		c.t += dt
		if c.leg == 2 and me.length() < 1.0 and c.t > 0.3:   # a hand on your collar (never the instant they appear)
			_end_chase(); grabbed.emit(); return
		var to: Vector3 = (inside if c.leg == 0 else outside if c.leg == 1 else cam.position) - n.position; to.y = 0
		var p: Vector3 = n.position + to.normalized() * minf(float(c.speed) * dt, to.length())
		if c.leg == 2:
			var lim := W / 2 - 0.4
			for z in ARCHES: lim = minf(lim, lerpf((W - 0.9) / 2 - 0.3, W / 2 - 0.4, clampf((absf(p.z - z) - 0.6) / 1.2, 0.0, 1.0)))   # drifting to the middle for an archway
			p.x = move_toward(n.position.x, clampf(p.x, -lim, lim), float(c.speed) * dt)
		c.stride += dt * 12.0; p.y = absf(sin(c.stride)) * 0.07   # running, not strolling
		n.position = p
		if to.length() > 0.05: n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-dt * 14.0))
		if int((c.stride - dt * 12.0) / PI) != int(c.stride / PI): c.step.pitch_scale = randf_range(0.9, 1.05); c.step.play()
	if cam.position.z > 1.0:   # out of the alley
		_end_chase(); _spooked = true; _talk = []
		for g in _people: g.visible = false   # they've gone inside
		_face(0.0, -3.0, 1.0)   # you look back
		got_away.emit()

func _end_chase() -> void:
	_chase = false; _chase_t = 0.0; _gate_open = false
	var v: AudioStreamPlayer3D = _voices[0]
	if v.get_parent() != self: v.reparent(self, false); v.position = Vector3(W / 2 + 5.3, 1.55, MEET_Z + 0.9)
	for c in _chasers:   # back where they were standing
		c.beam.queue_free(); c.step.queue_free()
		c.n.position = c.n.get_meta("home"); _pose(c.n, 0.0)
	_chasers.clear()
	if _gate: _gate.rotation_degrees.y = 0.0

## turn right round (a button, for when there's no time to drag)
func turn_around() -> void:
	if up or _busy or (_turning and _turning.is_running()): return
	_face(_yaw + 180.0, _pitch, 0.3)

## swing the view round to face that way
var _turning: Tween
var _face_to := 0.0
func _face(yaw: float, pitch: float, secs: float) -> void:
	if _turning: _turning.kill()
	var y0 := _yaw; var y1 := _yaw + wrapf(yaw - _yaw, -180.0, 180.0); var p0 := _pitch; _face_to = y1
	_turning = create_tween()
	_turning.tween_method(func(k: float): _yaw = lerpf(y0, y1, k); _pitch = lerpf(p0, pitch, k); _apply_look(), 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE)


## they've already gone inside (you came back to a night where you got chased off)
func spook() -> void:
	_spooked = true; _talk = []
	for g in _people: g.visible = false


## back to the entrance, down off the wall, as if it never happened
func reset() -> void:
	_end_chase()
	if not _spooked:
		for g in _people: g.visible = true
	up = false; _busy = false; _move = Vector2.ZERO; _alarm = 0.0; _been_up = false; _calm = 0.0; _seen_for = 0.0; _sus = [0.0, 0.0]; _looking = [0.0, 0.0]; _turned = [0.0, 0.0]; _set_wary("")
	if _turning: _turning.kill()
	_yaw = 0.0; _pitch = -3.0; _apply_look(); _vel = Vector3.ZERO
	cam.position = Vector3(0, EYE, 1.2)
	for g in _people: _pose(g, 0.0)
	_can = false; climb_changed.emit(false, false)


## ---------- walking: the stick pushes you the way you're facing; walls and the arches' pillars stop you
const WALK := 2.4           ## metres a second with the stick most of the way: quiet
const RUN := 4.3            ## stick all the way: fast, and they can hear it
const RUN_AT := 0.9
const EYE := 1.55
const FOV := 62.0
var _move := Vector2.ZERO
var _vel := Vector3.ZERO
var _stride := 0.0

func set_move(v: Vector2) -> void: _move = v

func _walk(dt: float) -> void:
	var m := _move.length(); var running := m > RUN_AT and not up and not _busy
	cam.fov = lerpf(cam.fov, FOV + (7.0 if running else 0.0), 1.0 - exp(-dt * 5.0))   # the view widens a little as you run
	if up or _busy: _vel = Vector3.ZERO; return
	var c := can_climb()
	if c != _can: _can = c; climb_changed.emit(c, up)
	var want := Vector3.ZERO
	if m >= 0.08:
		var yaw := cam.rotation.y
		var dir := (Vector3(-sin(yaw), 0, -cos(yaw)) * -_move.y + Vector3(cos(yaw), 0, -sin(yaw)) * _move.x) / m
		want = dir * (RUN if running else WALK * minf(m / 0.85, 1.0))
	_vel = _vel.lerp(want, 1.0 - exp(-dt * 9.0))   # you get going, and stop, over a step or so
	var speed := _vel.length()
	if speed < 0.05: cam.position.y = lerpf(cam.position.y, EYE, dt * 6.0); return
	var p := cam.position + _vel * dt
	var half := W / 2 - 0.35
	for z in ARCHES:   # an archway's pillars: solid from the front and back, and you slide along them inside
		var gap := (W - 0.9) / 2 - 0.28; var deep := 0.35 + 0.3
		if absf(p.z - z) < deep and absf(p.x) > gap:
			if absf(cam.position.z - z) >= deep - 0.001: p.z = z + deep * signf(cam.position.z - z); p.x = move_toward(p.x, gap * 0.98 * signf(p.x), 2.2 * dt)   # ... and you scrape round the edge of it
			else: p.x = clampf(p.x, -gap, gap)
	p.x = clampf(p.x, -half, half); p.z = clampf(p.z, -L + 3.0, 2.4 if _chase else 1.6)
	var before := _stride
	_stride += speed * 2.6 * dt
	if int(before / PI) != int(_stride / PI):   # a foot comes down
		if _steps == null: _steps = AudioStreamPlayer.new(); _steps.stream = load("res://sfx/step.wav"); add_child(_steps)
		_steps.volume_db = -20.0 if running else -32.0; _steps.pitch_scale = randf_range(0.9, 1.1); _steps.play()
		if running and not _chase: _heard_you()
	p.y = EYE + sin(_stride) * (0.05 if running else 0.025) * minf(1.0, speed / WALK)   # a bob as you go
	cam.position = p


func _process(dt: float) -> void:   # the lantern flames breathe a little; a light held near the edge turns your head
	_walk(dt); _talk_tick(dt); _chase_tick(dt)
	if not _chase and not _spooked: _notice_tick(dt)
	if torch.visible and _held:
		var push := Vector2.ZERO
		for k in 2:
			var a: float = _aim[k]
			if absf(a) > EDGE: push[k] = signf(a) * (absf(a) - EDGE) / (1.0 - EDGE)
		if push != Vector2.ZERO: _look_by(-push.x * 75.0 * dt, -push.y * 45.0 * dt)
	var t := Time.get_ticks_msec() / 1000.0
	for i in _lanterns.size():
		var l: OmniLight3D = _lanterns[i]
		l.light_energy = 0.75 + 0.09 * sin(t * 7.0 + i * 1.7) + 0.05 * sin(t * 13.0 + i)


## look around (drag with no light), and point the flashlight; hold the light near an edge and the view turns that way
const EDGE := 0.6           ## how far toward the edge (of -1..1) before the view starts to turn
var _yaw := 0.0             ## which way you're facing, in degrees (any: you can turn all the way round)
var _pitch := -3.0          ## up/down
var _down_yaw := 0.0        ## the way you were facing before you climbed
var _up_yaw := -75.0        ## facing straight into the courtyard, up on the wall
var _aim := Vector2.ZERO    ## where the light points on the screen, -1..1
var _held := false          ## a finger is on the picture

func drag(d: Vector2) -> void:   ## move the view by a drag (in -1..1 units): the picture follows your finger
	_look_by(-d.x * 42.0, -d.y * 30.0)

func _look_by(dyaw: float, dpitch: float) -> void:
	_yaw += dyaw; _pitch = clampf(_pitch + dpitch, -40.0, 12.0 if up else 35.0)
	if up: _yaw = clampf(_yaw, _up_yaw - 50.0, _up_yaw + 50.0)   # leaning over the wall, you can't look behind you
	_apply_look()

func _apply_look() -> void: cam.rotation_degrees = Vector3(_pitch, _yaw, 0)

func hold(on: bool) -> void: _held = on

func aim(nx: float, ny: float) -> void:
	nx = clampf(nx, -1.0, 1.0); ny = clampf(ny, -1.0, 1.0)   # a finger past the picture's edge counts as at the edge
	_aim = Vector2(nx, ny)
	var v := tan(deg_to_rad(FOV / 2.0)); var vs := get_viewport().get_visible_rect().size   # right under your finger
	torch.basis = Basis.looking_at(Vector3(nx * v * vs.x / maxf(1.0, vs.y), -ny * v, -1.0))

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
		if side < 0: _box(Vector3(0.5, H, L), Vector3(x, H / 2, -L / 2 + 2), brick)
		else:   # the right wall, with a gap for the gate into the courtyard
			var z0 := 2.0; var z1 := -L + 2.0; var g0 := GATE_Z + 0.7; var g1 := GATE_Z - 0.7
			_box(Vector3(0.5, H, z0 - g0), Vector3(x, H / 2, (z0 + g0) / 2), brick)
			_box(Vector3(0.5, H, g1 - z1), Vector3(x, H / 2, (g1 + z1) / 2), brick)
			_box(Vector3(0.5, H - 2.3, 1.4), Vector3(x, 2.3 + (H - 2.3) / 2, GATE_Z), brick)   # above the gate
		# the tiled cap along the top, overhanging into the alley (a Korean wall's 기와)
		var cap := _box(Vector3(1.1, 0.22, L), Vector3(x - side * 0.15, H + 0.12, -L / 2 + 2), roof)
		cap.rotation_degrees = Vector3(0, 0, side * 14)
		_box(Vector3(0.7, 0.12, L), Vector3(x, H + 0.02, -L / 2 + 2), roof)


## the gate: a plank door on a hinge at its alley-end edge, shut until they come for you
func _make_gate() -> void:
	_gate = Node3D.new(); _gate.position = Vector3(W / 2 + 0.02, 0, GATE_Z + 0.7); add_child(_gate)
	var door := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(0.1, 2.3, 1.4); door.mesh = b
	door.material_override = _mat("dark_planks", Vector3(0.8, 0.8, 0.8), 0.9); door.position = Vector3(0, 1.15, -0.7); _gate.add_child(door)
	var ring := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = 0.035; t.outer_radius = 0.06; ring.mesh = t
	var iron := StandardMaterial3D.new(); iron.albedo_color = Color(0.1, 0.1, 0.1); iron.metallic = 0.8; iron.roughness = 0.4
	ring.material_override = iron; ring.rotation_degrees = Vector3(0, 0, 90); ring.position = Vector3(-0.07, 1.1, -1.1); _gate.add_child(ring)


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


## on the other side of the right wall: someone's courtyard. A hanok with its paper windows lit, a lamp by the step,
## a persimmon tree, and two people talking by the lamp at one spot along the wall (MEET_Z)
func _yard() -> void:
	var x0 := W / 2 + 0.5
	var dirt := _mat("large_grey_tiles", Vector3(0.35, 0.35, 0.35), 0.9)
	dirt.albedo_color = Color(0.45, 0.42, 0.38)
	_box(Vector3(18, 0.2, L), Vector3(x0 + 9, -0.1, -L / 2 + 2), dirt)
	# the house, across the yard, facing the wall
	var hx := x0 + 10.5
	var wood := _mat("dark_planks", Vector3(0.7, 0.7, 0.7), 0.9)
	_box(Vector3(5.0, 3.2, 14), Vector3(hx + 2.5, 1.9, MEET_Z), wood)
	_box(Vector3(6.4, 0.5, 15.4), Vector3(hx + 2.4, 0.25, MEET_Z), _mat("large_grey_tiles", Vector3(0.6, 0.6, 0.6)))   # the stone base
	var roof := _mat("grey_roof_tiles", Vector3(0.8, 0.8, 0.8), 0.8)
	for s in [-1, 1]:
		var r := _box(Vector3(4.6, 0.25, 16.4), Vector3(hx + 2.5 + s * 1.9, 4.25, MEET_Z), roof)
		r.rotation_degrees = Vector3(0, 0, -s * 24)
	var paper := StandardMaterial3D.new(); paper.emission_enabled = true; paper.emission = Color(1.0, 0.72, 0.42); paper.emission_energy_multiplier = 1.6
	paper.albedo_color = Color(1.0, 0.82, 0.6)
	for k in 4:   # lit paper doors along the front
		_box(Vector3(0.06, 2.0, 2.2), Vector3(hx - 0.02, 1.6, MEET_Z - 4.5 + k * 3.0), paper)
	var glow := OmniLight3D.new(); glow.position = Vector3(hx - 1.2, 1.8, MEET_Z); glow.light_color = Color(1.0, 0.68, 0.4)
	glow.light_energy = 1.6; glow.omni_range = 9; glow.shadow_enabled = true; glow.light_volumetric_fog_energy = 1.2; add_child(glow)
	# a lamp on a post by the step, where they're standing
	var lamp_at := Vector3(x0 + 5.6, 0, MEET_Z + 1.6)
	var post := StandardMaterial3D.new(); post.albedo_color = Color(0.08, 0.07, 0.06)
	_box(Vector3(0.1, 2.2, 0.1), lamp_at + Vector3(0, 1.1, 0), post)
	var lampm := StandardMaterial3D.new(); lampm.emission_enabled = true; lampm.emission = Color(1.0, 0.62, 0.3); lampm.emission_energy_multiplier = 2.0
	var lb := _box(Vector3(0.3, 0.4, 0.3), lamp_at + Vector3(0, 2.35, 0), lampm); lb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ll := OmniLight3D.new(); ll.position = lamp_at + Vector3(0, 2.3, 0); ll.light_color = Color(1.0, 0.62, 0.32); ll.light_energy = 1.4
	ll.omni_range = 6; ll.shadow_enabled = true; add_child(ll); _lanterns.append(ll)
	# a persimmon tree
	var bark := StandardMaterial3D.new(); bark.albedo_color = Color(0.12, 0.09, 0.07)
	var trunk := MeshInstance3D.new(); var tm := CylinderMesh.new(); tm.top_radius = 0.12; tm.bottom_radius = 0.2; tm.height = 3.0; trunk.mesh = tm
	trunk.material_override = bark; trunk.position = Vector3(x0 + 3.0, 1.5, MEET_Z - 6); add_child(trunk)
	var leaves := StandardMaterial3D.new(); leaves.albedo_color = Color(0.12, 0.2, 0.1); leaves.roughness = 0.9
	for k in 5:
		var b := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 1.1; sm.height = 1.8; b.mesh = sm; b.material_override = leaves
		b.position = Vector3(x0 + 3.0 + cos(k * 1.3) * 0.9, 3.4 + (k % 2) * 0.5, MEET_Z - 6 + sin(k * 1.3) * 0.9); add_child(b)
	# the two of them, by the lamp
	_people.append(_figure(Vector3(x0 + 4.8, 0, MEET_Z + 0.9), 1.72, -45.0))   # facing each other
	_people.append(_figure(Vector3(x0 + 5.5, 0, MEET_Z + 0.2), 1.6, 135.0))
	# their voices come from where they stand
	for k in 2:
		var v := AudioStreamPlayer3D.new(); v.position = Vector3(x0 + 4.8 + k * 0.7, 1.55, MEET_Z + 0.9 - k * 0.7)
		v.unit_size = 4.0; v.max_db = 6.0; v.bus = _yard_bus(); v.attenuation_filter_cutoff_hz = 4500; v.attenuation_filter_db = -30
		add_child(v); _voices.append(v)


## a person, as a dark shape: body, shoulders, head (detail comes later)
func _figure(at: Vector3, h: float, face: float) -> Node3D:
	var cloth := StandardMaterial3D.new(); cloth.albedo_color = Color(0.06, 0.06, 0.08); cloth.roughness = 0.9
	var g := Node3D.new(); g.position = at; g.rotation_degrees.y = face; add_child(g)
	var body := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.24; cm.height = h * 0.78; body.mesh = cm
	body.material_override = cloth; body.position = Vector3(0, h * 0.42, 0); g.add_child(body)
	var head := Node3D.new(); head.position = Vector3(0, h - 0.13, 0); g.add_child(head); g.set_meta("head", head); g.set_meta("home", at)
	var skull := MeshInstance3D.new(); var hm := SphereMesh.new(); hm.radius = 0.12; hm.height = 0.27; skull.mesh = hm
	skull.material_override = cloth; skull.position = Vector3(0, 0.02, 0.015); head.add_child(skull)
	var skin := StandardMaterial3D.new(); skin.albedo_color = Color(0.78, 0.6, 0.48); skin.roughness = 0.75
	var face_ := MeshInstance3D.new(); var fm := SphereMesh.new(); fm.radius = 0.1; fm.height = 0.22; face_.mesh = fm
	face_.material_override = skin; face_.position = Vector3(0, -0.015, -0.04); head.add_child(face_)   # the front of the head: the face
	var nose := MeshInstance3D.new(); var nm := SphereMesh.new(); nm.radius = 0.018; nm.height = 0.05; nose.mesh = nm
	nose.material_override = skin; nose.position = Vector3(0, -0.02, -0.14); head.add_child(nose)
	g.set_meta("idle", face)
	return g


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
