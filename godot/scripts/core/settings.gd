class_name Settings
extends RefCounted
## Your settings (user://settings.json): how the game sounds and how big the Korean is. Kept apart from the save,
## so starting over doesn't reset them.

const PATH := "user://settings.json"
const DEFAULTS := {"auto": 1, "slow": 0, "size": 1, "sound": 1, "music": 2, "amb": 2, "voices": 1, "glow": 1}
static var v: Dictionary = {}


static func get_(k: String) -> int:
	if v.is_empty(): load_()
	return int(v.get(k, DEFAULTS.get(k, 0)))


static func set_(k: String, val: int) -> void:
	if v.is_empty(): load_()
	v[k] = val; save_()


static func load_() -> void:
	v = DEFAULTS.duplicate()
	if FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary: v.merge(d, true)


static func save_() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(v))


## Korean text size: small / medium / large
static func text_scale() -> float: return [0.85, 1.0, 1.2][clampi(get_("size"), 0, 2)]
