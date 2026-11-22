extends Node
## The soundscape: the place's music ("music calm / tense / festival / none") and its background sound ("sound birds,
## room, market, night, river, wind, bus"), each looping and crossfading when you move. Volumes from your settings.

const MUSIC_DB := [-80.0, -24.0, -15.0]   ## off / low / on
const AMB_DB := [-80.0, -26.0, -17.0]

var _music: Array = []    ## two players each, so one can fade out while the other fades in
var _amb: Array = []
var _now := {"music": "", "amb": ""}


func _ready() -> void:
	for i in 2:
		var m := AudioStreamPlayer.new(); m.volume_db = -80; add_child(m); _music.append(m)
		var a := AudioStreamPlayer.new(); a.volume_db = -80; add_child(a); _amb.append(a)


func _stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path): return null
	return load(path) as AudioStream   # they loop by themselves (set when imported: tools/make_music.py's files)


## call whenever the place (or the settings) might have changed
func update(pl: Dictionary) -> void:
	var mood: String = pl.get("music", "none"); var bed: String = pl.get("sound", "")
	_swap(_music, "music", mood if mood != "none" else "", "res://music/%s.wav", MUSIC_DB[clampi(Settings.get_("music"), 0, 2)])
	_swap(_amb, "amb", bed, "res://amb/%s.wav", AMB_DB[clampi(Settings.get_("amb"), 0, 2)])


func _swap(pair: Array, kind: String, name: String, pattern: String, db: float) -> void:
	var cur: AudioStreamPlayer = pair[0]
	if name == _now[kind]:   # same piece: just follow the volume setting
		if cur.playing: create_tween().tween_property(cur, "volume_db", db, 0.4)
		return
	_now[kind] = name
	var nxt: AudioStreamPlayer = pair[1]
	pair.reverse()   # the new one is in front now
	if cur.playing:
		var t := create_tween(); t.tween_property(cur, "volume_db", -80.0, 1.6); t.tween_callback(cur.stop)
	if name == "": return
	var s := _stream(pattern % name)
	if s == null: return
	nxt.stream = s; nxt.volume_db = -60.0; nxt.play()
	create_tween().tween_property(nxt, "volume_db", db, 1.6)
