"""Play the game by commands, on screen (for an AI player). What it sees is what a player sees.
  python tools/gd_agent.py start                 opens the game (a new story, 30 minutes) and prints the screen
  python tools/gd_agent.py "next" "tap 3"        one or more commands, in order; prints what happened and the screen
Commands: next | tap N | tap WORDS | ring N | at X Y | card N | box | frame X Y | type 한글 | write TEXT | word 단어 |
          swipe down/up | back | look | screen | say THOUGHT (a caption) | note TEXT (into playtest/ai-notes.md) | done"""
import json, pathlib, subprocess, sys, time
sys.stdout.reconfigure(encoding="utf-8")
GODOT = r"C:\Users\2006a\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
ROOT = pathlib.Path(__file__).resolve().parent.parent
D = ROOT / "playtest"
a = sys.argv[1:]
if a == ["start"]:
    D.mkdir(exist_ok=True)
    for f in list(D.glob("out_*")) + list(D.glob("cmd*")) + list(D.glob("look_*")) + [D / "ready.txt"]: f.unlink(missing_ok=True)
    stamp = time.strftime("%b %d, %H:%M")
    for n, t in [("ai-notes.md", "# What the AI player noticed"), ("ai-actions.md", "# Everything the AI player did")]:
        p = D / n
        if p.exists(): p.rename(D / (p.stem + time.strftime("-%m%d-%H%M") + ".md"))
        p.write_text(f"{t} ({stamp})\n\n", encoding="utf-8")
    subprocess.Popen([GODOT, "--path", str(ROOT / "godot"), "--resolution", "1286x600", "--position", "60,60", "--audio-driver", "Dummy",
                      "--", "--agent", D.as_posix()], stdout=open(D / "game.log", "wb"), stderr=subprocess.STDOUT, creationflags=0x00000008 | 0x00000200)
    for i in range(300):
        if (D / "ready.txt").exists(): print((D / "ready.txt").read_text(encoding="utf-8")); sys.exit()
        time.sleep(0.1)
    print("the game didn't start:", (D / "game.log").read_text(encoding="utf-8", errors="replace")[-800:]); sys.exit(1)
i = str(int(time.time() * 1000))
(D / "cmd.tmp").write_text(json.dumps({"id": i, "cmds": a}, ensure_ascii=False), encoding="utf-8"); (D / "cmd.tmp").replace(D / "cmd.json")
o = D / f"out_{i}.txt"
for _ in range(900):
    if o.exists():
        time.sleep(0.02); print(o.read_text(encoding="utf-8")); o.unlink(); sys.exit()
    time.sleep(0.1)
(D / "cmd.json").unlink(missing_ok=True)
print("no answer for 90 s: the game has stopped (time up, closed, or frozen)"); sys.exit(1)
