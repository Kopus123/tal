class_name Voice
extends Node
## The recorded voices (godot/voice/, copied from the web version's audio/ by tools/export_godot.py).
## Each clip is filed under who says it and the line: "sujin|안녕하세요! 저는 수진이에요." ("sign|..." for written
## things and anyone without a voice of their own, "word|..." for single words, "you|..." for what you say).

var on := true
var _index: Dictionary = {}
var _player: AudioStreamPlayer


func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://voice/index.json"))
	if d is Dictionary: _index = d
	_player = AudioStreamPlayer.new(); add_child(_player)
	if AudioServer.get_bus_index("Voice") < 0:   # its own bus, so slowing it down can keep the pitch right
		AudioServer.add_bus(); var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Voice"); AudioServer.add_bus_effect(i, AudioEffectPitchShift.new())
	_player.bus = "Voice"
	apply()


## your settings: voices on or off, normal or slow
func apply() -> void:
	on = Settings.get_("voices") == 1
	var slow := Settings.get_("slow") == 1
	_player.pitch_scale = 0.8 if slow else 1.0
	var fx := AudioServer.get_bus_effect(AudioServer.get_bus_index("Voice"), 0) as AudioEffectPitchShift
	if fx: fx.pitch_scale = 1.25 if slow else 1.0
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Voice"), 0, slow)


## the same clean-up the web version used when it recorded them
static func norm(s: String) -> String:
	var t := Story.plain(s)
	for c in ["📸", "🏮", "^", "♡", "✖", "📞", "🔔", "💙"]: t = t.replace(c, "")
	t = t.replace("/", ", ")
	return Story.R("\\s+").sub(t, " ", true).strip_edges()


func key(text: String, who: String) -> String:
	var v: String = who if who in ["you", "word"] or Game.ST.get("cast", {}).get(who, {}).get("voice", false) else "sign"
	return v + "|" + norm(text)


func say(text: String, who: String) -> void:
	if not on or text == "": return
	var f: String = _index.get(key(text, who), "")
	if f == "": return
	var s := load("res://voice/" + f) as AudioStream
	if s: _player.stream = s; _player.play()


func stop() -> void: _player.stop()


## say it, then do something (your line plays before the story moves on); right away if there's no recording
func say_then(text: String, who: String, then: Callable) -> void:
	var f: String = _index.get(key(text, who), "") if on else ""
	if f == "": then.call(); return
	say(text, who)
	await _player.finished
	then.call()
