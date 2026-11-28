# ---------------------------------------------------------------- the screen, the phone, the debrief

func _label(size: int) -> Label:
	var l := Label.new(); l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 8); l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8)); return l


func _btn(text: String, size: int, min: Vector2) -> Button:
	var b := Button.new(); b.text = text; b.add_theme_font_size_override("font_size", size); b.custom_minimum_size = min; return b


func _style(a := 0.95) -> StyleBoxFlat:
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.06, 0.07, 0.1, a); st.set_corner_radius_all(14); st.set_content_margin_all(16); return st


func _screen() -> void:
	var ui := CanvasLayer.new(); add_child(ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	joy_draw = Control.new(); joy_draw.set_anchors_preset(Control.PRESET_FULL_RECT); joy_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(joy_draw)
	joy_draw.draw.connect(_draw_joy)
	goal = _label(26); goal.position = Vector2(24, 20); root.add_child(goal)
	en_btn = _btn("English: on" if english else "English: off", 18, Vector2(150, 48)); en_btn.position = Vector2(24, 64); root.add_child(en_btn); en_btn.pressed.connect(_toggle_en)
	sub = _label(26); sub.anchor_left = 0.5; sub.anchor_right = 0.5; sub.anchor_top = 1; sub.anchor_bottom = 1
	sub.offset_left = -420; sub.offset_right = 420; sub.offset_top = -80; sub.offset_bottom = -40
	sub.custom_minimum_size = Vector2(840, 0); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(sub)
	phone_btn = _btn("Phone", 26, Vector2(150, 70)); phone_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	phone_btn.position = Vector2(-174, 20); root.add_child(phone_btn); phone_btn.pressed.connect(_toggle_phone)
	throw_btn = _btn("Throw glass", 24, Vector2(150, 70)); throw_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	throw_btn.position = Vector2(-174, 104); root.add_child(throw_btn); throw_btn.pressed.connect(func(): _throw()); throw_btn.visible = false
	shoot_btn = _btn("Shoot (%d)" % MAG, 24, Vector2(150, 70)); shoot_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shoot_btn.position = Vector2(-174, 104); root.add_child(shoot_btn); shoot_btn.pressed.connect(func(): _shoot()); shoot_btn.visible = false
	hand_btn = _btn(_hand_text(), 24, Vector2(150, 110)); root.add_child(hand_btn)
	hand_btn.anchor_left = 1; hand_btn.anchor_right = 1; hand_btn.anchor_top = 1; hand_btn.anchor_bottom = 1
	hand_btn.offset_left = -240; hand_btn.offset_right = -90; hand_btn.offset_top = -400; hand_btn.offset_bottom = -290
	hand_btn.button_down.connect(func(): holding = true; hold_t = 0.0)
	hand_btn.button_up.connect(_hand_up)
	bag_btn = _btn("Bag", 22, Vector2(70, 110)); root.add_child(bag_btn); bag_btn.pressed.connect(_bag_show)
	bag_btn.anchor_left = 1; bag_btn.anchor_right = 1; bag_btn.anchor_top = 1; bag_btn.anchor_bottom = 1
	bag_btn.offset_left = -84; bag_btn.offset_right = -14; bag_btn.offset_top = -400; bag_btn.offset_bottom = -290
	bag_box = HBoxContainer.new(); bag_box.add_theme_constant_override("separation", 8); root.add_child(bag_box)
	bag_box.anchor_left = 1; bag_box.anchor_right = 1; bag_box.anchor_top = 1; bag_box.anchor_bottom = 1
	bag_box.offset_left = -760; bag_box.offset_right = -14; bag_box.offset_top = -400; bag_box.offset_bottom = -300
	bag_box.alignment = BoxContainer.ALIGNMENT_END; bag_box.visible = false
	ring_box = Control.new(); ring_box.set_anchors_preset(Control.PRESET_FULL_RECT); ring_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(ring_box); ring_box.visible = false   # (its buttons still take taps)
	talk_btn = _btn("Talk", 34, Vector2(200, 110)); root.add_child(talk_btn); talk_btn.pressed.connect(_talk_btn)   # walk up to someone and talk
	talk_btn.anchor_left = 1; talk_btn.anchor_right = 1; talk_btn.anchor_top = 1; talk_btn.anchor_bottom = 1
	talk_btn.offset_left = -240; talk_btn.offset_right = -30; talk_btn.offset_top = -170; talk_btn.offset_bottom = -40; talk_btn.visible = false
	comp_btn = _btn("Talk (with you)", 24, Vector2(210, 80)); root.add_child(comp_btn); comp_btn.pressed.connect(func(): _talk_to(_companion()))   # whoever's walking with you
	comp_btn.anchor_left = 1; comp_btn.anchor_right = 1; comp_btn.anchor_top = 1; comp_btn.anchor_bottom = 1
	comp_btn.offset_left = -240; comp_btn.offset_right = -30; comp_btn.offset_top = -270; comp_btn.offset_bottom = -185; comp_btn.visible = false
	phone_ui = PanelContainer.new(); phone_ui.add_theme_stylebox_override("panel", _style(0.97)); root.add_child(phone_ui)
	phone_ui.anchor_left = 1; phone_ui.anchor_right = 1; phone_ui.anchor_top = 0; phone_ui.anchor_bottom = 1
	phone_ui.offset_left = -520; phone_ui.offset_right = -16; phone_ui.offset_top = 100; phone_ui.offset_bottom = -16
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; phone_ui.add_child(sc)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 8); sc.add_child(box)
	var t := _label(28); t.text = "Who's who"; box.add_child(t)
	var h := _label(18); h.text = "Stand next to someone (they light up), then mark who you think they are. You can change it."; h.modulate = Color(0.8, 0.8, 0.8)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(h)
	for r in ROLES:
		var b := _btn("%s  ·  %s" % ROLE_NAME[r], 24, Vector2(0, 58)); b.pressed.connect(_tag.bind(r)); box.add_child(b); role_btns[r] = b
	var c := _label(22); c.text = "Your cover: Eric Shin"; c.modulate = Color(1, 0.8, 0.4); box.add_child(c)
	for f in Cover.FACTS:
		var k := _label(22); k.text = "%s   %s" % [f.ko, f.en]; k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(k)
	var dl := _label(22); dl.text = "The deal: get the USB"; dl.modulate = Color(1, 0.8, 0.4); box.add_child(dl)
	for f in Cover.DEAL + [{"ko": Cover.APPT[0], "en": Cover.APPT[1]}]:
		var k2 := _label(22); k2.text = "%s   %s" % [f.ko, f.en]; k2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(k2)
	phone_ui.visible = false
	leave_btn = _btn("Leave", 30, Vector2(170, 80)); leave_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	leave_btn.position = Vector2(-85, -110); root.add_child(leave_btn); leave_btn.pressed.connect(_finish); leave_btn.visible = false
	_ask_screen(root)
	fade = ColorRect.new(); fade.color = Color(0, 0, 0, 0); fade.set_anchors_preset(Control.PRESET_FULL_RECT); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(fade)
	hurt = ColorRect.new(); hurt.color = Color(0.8, 0.0, 0.0, 0.0); hurt.set_anchors_preset(Control.PRESET_FULL_RECT); hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hurt)
	end_ui = PanelContainer.new(); end_ui.add_theme_stylebox_override("panel", _style()); root.add_child(end_ui)   # the debrief: the text scrolls, the buttons always fit
	end_ui.anchor_left = 0.5; end_ui.anchor_right = 0.5; end_ui.anchor_top = 0.0; end_ui.anchor_bottom = 1.0
	end_ui.offset_left = -340; end_ui.offset_right = 340; end_ui.offset_top = 24; end_ui.offset_bottom = -24
	var eb := VBoxContainer.new(); eb.add_theme_constant_override("separation", 14); end_ui.add_child(eb)
	var es := ScrollContainer.new(); es.size_flags_vertical = Control.SIZE_EXPAND_FILL; es.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; eb.add_child(es)
	end_text = _label(24); end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; es.add_child(end_text)
	var again := _btn("Again", 30, Vector2(0, 80)); eb.add_child(again); again.pressed.connect(func(): get_tree().reload_current_scene()); again_btn = again
	var car := _btn("Back to the car", 24, Vector2(0, 64)); eb.add_child(car); car.pressed.connect(func(): get_tree().change_scene_to_file("res://cover.tscn"))
	end_ui.visible = false


func _draw_joy() -> void:
	if joy_touch == -1: return
	joy_draw.draw_circle(joy_center, 90, Color(1, 1, 1, 0.12))
	joy_draw.draw_circle(joy_center + joy_vec * 90, 38, Color(1, 1, 1, 0.45))


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag or ev is InputEventMouse: touch_pos = ev.position
	if done: return
	if ev is InputEventScreenTouch:
		var vs := get_viewport().get_visible_rect().size
		var on_panel: bool = ask_ui.visible and ev.position.y > vs.y - 330.0   # tapping your answer pieces isn't walking
		if ev.pressed and joy_touch == -1 and not on_panel and ev.position.x < vs.x * 0.45:
			joy_touch = ev.index; joy_center = ev.position; joy_vec = Vector2.ZERO
		elif not ev.pressed and ev.index == joy_touch:
			joy_touch = -1; joy_vec = Vector2.ZERO
		joy_draw.queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == joy_touch:
		joy_vec = ((ev.position - joy_center) / 90.0).limit_length(1.0); joy_draw.queue_redraw()


func _handler(id: String) -> void:
	hvoice.stream = _clip(id); hvoice.play(); played.append(id); last_handler = id
	_plg("Handler, in your ear (English): " + HANDLER[id])
	sub.text = "Handler: " + HANDLER[id]; sub_t = 3.5


func _toggle_phone() -> void:
	phone_open = not phone_open
	phone_ui.visible = phone_open; phone_prop.visible = phone_open
	if phone_open and not asking.is_empty(): ask_phone = true   # they're waiting, and they see you look it up
	phone_btn.text = "Put away" if phone_open else "Phone"
	sub.offset_left = -630.0 if phone_open else -420.0; sub.offset_right = sub.offset_left + 840.0   # out from under the phone
	create_tween().tween_property(body_mesh.get_child(0), "rotation:x", -0.35 if phone_open else 0.0, 0.25)


func _nearest() -> Dictionary:
	var best := {}; var bd := TAG_RANGE
	for p in people:
		if p.gone: continue
		var d := player.position.distance_to(p.body.position)
		if d < bd: best = p; bd = d
	return best


func _tag(role: String) -> void:   # your guess, nothing more: nobody tells you if it's right
	if done: return
	var p := _nearest()
	if p.is_empty(): return
	if guesses.has(role):   # moving a mark to someone else
		var old := _find(guesses[role])
		if old: old.tag.visible = false
	for r in guesses.keys():   # one mark per person
		if guesses[r] == p.id: guesses.erase(r); role_btns[r].text = "%s  ·  %s" % ROLE_NAME[r]
	guesses[role] = p.id
	p.tag.text = ROLE_NAME[role][1] + "?"; p.tag.visible = true
	role_btns[role].text = "%s  ·  %s   (marked)" % ROLE_NAME[role]


func _finish(walked_out := false) -> void:   # into the lift: the debrief
	if done: return
	done = true
	if not asking.is_empty(): _ask_end("walked")
	if phone_open: _toggle_phone()
	leave_btn.visible = false
	sub.offset_left = -420.0; sub.offset_right = 420.0
	if not asking.is_empty() or ask_ui.visible: ask_ui.visible = false
	_handler("h_out")
	await get_tree().create_timer(1.2).timeout
	var t := "Debrief\n\n"
	if shot_dead: t += "SHOT BY SECURITY.\nMission failed.\n\n"
	elif killed: t += "KILLED.\nThe broker didn't believe you were the buyer. Your body's in the corner of his back room.\nMission failed.\n\n"
	elif has_drive: t += "MISSION DONE: you got the drive out.\n\n"
	else: t += "Mission failed: no drive.\n\n"
	if walked_out: t += "Escorted out.\n\n"
	if real_stage >= 2: t += "The real Eric Shin showed up%s.\n\n" % (" and blew your cover" if blown else "")
	if downed: t += "You took down: %s.\n\n" % ", ".join(downed.map(func(id): var q := _who_is(id); return ("the real Eric Shin" if q.role == "buyer" else "a guest") if not ROLE_NAME.has(q.role) else ROLE_NAME[q.role][1]))
	elif hunted: t += "You got out before security reached you.\n\n"
	var right := 0
	for r in ROLES:
		var line := "%s (%s): " % [ROLE_NAME[r][1], ROLE_NAME[r][0].to_lower()]
		if not guesses.has(r): line += "not marked"
		else:
			var p := _who_is(guesses[r])
			if p.role == r: line += "right"; right += 1
			else: line += "wrong, that was " + (("the real Eric Shin" if p.role == "buyer" else "a guest") if not ROLE_NAME.has(p.role) else ROLE_NAME[p.role][1])
		t += line + "\n"
	var ok := people.filter(func(o): return o.pic.ok).size()
	var wary := people.filter(func(o): return o.pic.wary).size()
	t += "\n%d of 5 right. %d:%02d at the party.\n%d took to you, %d are wary of you." % [right, int(clock) / 60, int(clock) % 60, ok, wary]
	end_text.text = t
	end_ui.visible = true
	_plg("THE END. Screen shows:\n" + t)


func _who_is(id: String) -> Dictionary:   # anyone, even someone who's left
	for p in people:
		if p.id == id: return p
	return {}


func _ask_screen(root: Control) -> void:   # answering someone: build it from your cover pieces
	ask_ui = PanelContainer.new(); ask_ui.add_theme_stylebox_override("panel", _style(0.92)); root.add_child(ask_ui)
	ask_ui.anchor_left = 0; ask_ui.anchor_right = 1; ask_ui.anchor_top = 1; ask_ui.anchor_bottom = 1
	ask_ui.offset_left = 16; ask_ui.offset_right = -16; ask_ui.offset_top = -300; ask_ui.offset_bottom = -10
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); ask_ui.add_child(row)
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.add_theme_constant_override("separation", 10); row.add_child(left)
	var qrow := HBoxContainer.new(); qrow.add_theme_constant_override("separation", 14); left.add_child(qrow)
	ask_label = _label(38); ask_label.modulate = Color(0.75, 0.85, 1.0); qrow.add_child(ask_label)
	var hear := _btn("Hear", 22, Vector2(90, 54)); qrow.add_child(hear)
	hear.pressed.connect(_hear_q); hear_btn = hear
	var arow := HBoxContainer.new(); arow.add_theme_constant_override("separation", 14); left.add_child(arow)
	ans_label = _label(36); ans_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; arow.add_child(ans_label)
	var clr := _btn("Clear", 22, Vector2(100, 54)); arow.add_child(clr); clr.pressed.connect(func(): picked.clear(); _show_pick())
	right_btn = _btn("Say the right answer", 20, Vector2(230, 54)); arow.add_child(right_btn); right_btn.visible = false   # (English mode: for testing)
	right_btn.pressed.connect(func(): if not back and not asking.is_empty() and not ask_busy: picked = _right_pieces(ask_fact); _show_pick(); _say_it())
	done_btn = _btn("Done", 22, Vector2(100, 54)); arow.add_child(done_btn); done_btn.visible = false
	done_btn.pressed.connect(func(): if back and not ask_busy: _back_end())
	tile_box = HBoxContainer.new(); tile_box.add_theme_constant_override("separation", 8); left.add_child(tile_box)
	say_btn = _btn("Say it", 34, Vector2(180, 120)); say_btn.size_flags_vertical = Control.SIZE_SHRINK_END; row.add_child(say_btn); say_btn.pressed.connect(_say_it)
	var gs := StyleBoxFlat.new(); gs.bg_color = Color(0.2, 0.55, 0.3); gs.set_corner_radius_all(10); say_btn.add_theme_stylebox_override("normal", gs)
	ask_ui.visible = false


func _en_map() -> void:   # every Korean line and piece, to its English
	for l in LINES.values(): EN[l[0]] = l[1]
	for l in REACT.values(): EN[l[0]] = l[1]
	for f in Cover.FACTS + Cover.DEAL + [Cover.YN]:
		if f.has("ko"): EN[f.ko] = f.en
		for q in f.get("qs", []): EN[q[0]] = q[1]
		for c in f.chunks: EN[c[0].trim_prefix("~")] = c[1]
	for k in EN_MORE: EN[k] = EN_MORE[k]
	english = FileAccess.file_exists("user://english")


func _en(ko: String) -> String:
	if not english or ko == "": return ko
	return EN.get(ko, EN.get(ko.trim_suffix("."), ko))


func _toggle_en() -> void:
	english = not english
	if english: FileAccess.open("user://english", FileAccess.WRITE).store_string("1")
	elif FileAccess.file_exists("user://english"): DirAccess.remove_absolute("user://english")
	en_btn.text = "English: on" if english else "English: off"
	if not asking.is_empty():
		if back: _turn_ui()
		else: ask_label.text = _en(ask_text); _show_pick(); right_btn.visible = english
