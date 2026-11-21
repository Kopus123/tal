class_name Hangul
extends RefCounted
## Joins letters into Korean syllable blocks as you type, the way a Korean keyboard does: ㅎ ㅏ ㄴ -> 한.
##   var h := Hangul.new(); h.add("ㅎ"); h.add("ㅏ"); h.add("ㄴ"); h.text() == "한"
## A typed consonant after a final consonant moves to the next block when a vowel follows: 한 + ㅏ -> 하나.

const CHO := ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
const JUNG := ["ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"]
const JONG := ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
## two vowels that make one (ㅗ + ㅏ = ㅘ), two final consonants that make one (ㄹ + ㄱ = ㄺ)
const VOWEL_PAIRS := {"ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ", "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ", "ㅡㅣ": "ㅢ"}
const FINAL_PAIRS := {"ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ"}

var done := ""          ## finished text
var cho := ""           ## the block being typed: first consonant, vowel, final consonant
var jung := ""
var jong := ""


static func is_vowel(j: String) -> bool: return j in JUNG


func _split_pair(pairs: Dictionary, j: String) -> Array:   ## ㄺ -> [ㄹ, ㄱ]
	for k in pairs:
		if pairs[k] == j: return [k[0], k[1]]
	return []


func _block() -> String:
	if cho != "" and jung != "":
		return char(0xAC00 + (CHO.find(cho) * 21 + JUNG.find(jung)) * 28 + JONG.find(jong))
	return cho + jung + jong


func _commit() -> void:
	done += _block(); cho = ""; jung = ""; jong = ""


func add(j: String) -> void:
	if j == " ":
		_commit(); done += " "; return
	if is_vowel(j):
		if jong != "":                         # the final consonant moves on to start the next block
			var parts := _split_pair(FINAL_PAIRS, jong)
			var moved := jong
			if not parts.is_empty(): jong = parts[0]; moved = parts[1]
			else: jong = ""
			if not (moved in CHO): _commit(); jung = j; return
			_commit(); cho = moved; jung = j
		elif cho != "" and jung == "": jung = j
		elif jung != "" and VOWEL_PAIRS.has(jung + j): jung = VOWEL_PAIRS[jung + j]
		else: _commit(); jung = j
	else:
		if cho != "" and jung != "" and jong == "" and j in JONG: jong = j
		elif jong != "" and FINAL_PAIRS.has(jong + j): jong = FINAL_PAIRS[jong + j]
		else: _commit(); cho = j


func backspace() -> void:
	if jong != "":
		var parts := _split_pair(FINAL_PAIRS, jong); jong = parts[0] if not parts.is_empty() else ""
	elif jung != "":
		var parts := _split_pair(VOWEL_PAIRS, jung); jung = parts[0] if not parts.is_empty() else ""
	elif cho != "": cho = ""
	elif done != "": done = done.substr(0, done.length() - 1)


func text() -> String: return done + _block()


func clear() -> void: done = ""; cho = ""; jung = ""; jong = ""
