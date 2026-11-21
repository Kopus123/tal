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
