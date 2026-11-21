extends SceneTree
## Checks the keyboard's letter-joining.   godot --headless --path godot -s tests/test_hangul.gd

func _init() -> void:
	var cases := {"ㅎㅏㄴ": "한", "ㅎㅏㄴㅏ": "하나", "ㄱㅣㄹㅡㅁ": "기름", "ㅁㅏㅇㅊㅣ": "망치", "ㅁㅓㄴㅈㅓ": "먼저", "ㅇㅕㄹㅅㅚ": "열쇠",
		"ㅇㅕㄹㅅㅗㅣ": "열쇠", "ㄷㅏㄹㄱ": "닭", "ㄷㅏㄹㄱㅣ": "달기", "ㅇㅓㅂㅅㅓ": "업서", "ㅇㅓㅂㅅ": "없", "ㅎㅏㄹㅁㅓㄴㅣ": "할머니", "ㅅㅏ ㅈㅣㄴ": "사 진", "ㅏ": "ㅏ", "ㄱ": "ㄱ"}
	var bad := 0
	for k in cases:
		var h := Hangul.new()
		for c in k: h.add(c)
		if h.text() != cases[k]: bad += 1; printerr("FAIL %s -> %s (expected %s)" % [k, h.text(), cases[k]])
	var h2 := Hangul.new()
	for c in "ㄷㅏㄹㄱ": h2.add(c)
	h2.backspace()
	if h2.text() != "달": bad += 1; printerr("FAIL backspace 닭 -> %s" % h2.text())
	print("PASS  hangul: %d cases" % (cases.size() + 1) if bad == 0 else "FAIL hangul")
	quit(1 if bad else 0)
