"""Record every game line with Microsoft neural voices (edge-tts).

Usage:  python tools/build_audio.py
Input:  tools/lines.json  - list of "voice|text" keys (dump it from the game with allLines() in the browser console)
Output: audio/<hash>.mp3 for each line, plus audio/clips.js mapping each key to its file.
Clips that already exist are skipped, so re-running only records new lines.
"""
import asyncio, hashlib, json, pathlib
import edge_tts

ROOT = pathlib.Path(__file__).resolve().parent.parent
AUDIO = ROOT / "audio"

F, M, M2 = "ko-KR-SunHiNeural", "ko-KR-InJoonNeural", "ko-KR-HyunsuMultilingualNeural"
VOICES = {  # voice, rate, pitch
    "sujin":   (F,  "+0%",  "+0Hz"),
    "yuna":    (F,  "+8%",  "+25Hz"),
    "minsu":   (M,  "+0%",  "+0Hz"),
    "ajeossi": (M,  "-6%",  "-18Hz"),
    "staff":   (F,  "-3%",  "-12Hz"),
    "bus":     (M2, "-5%",  "+0Hz"),
    "you":     (M2, "-8%",  "+0Hz"),
    "word":    (F,  "-15%", "+0Hz"),
    "sign":    (F,  "-10%", "+0Hz"),
}

def fname(key):
    return hashlib.md5(key.encode("utf-8")).hexdigest()[:10] + ".mp3"

async def record(key, sem):
    who, text = key.split("|", 1)
    out = AUDIO / fname(key)
    if out.exists() and out.stat().st_size > 0:
        return
    voice, rate, pitch = VOICES.get(who, VOICES["sign"])
    spoken = text.replace("~", "").replace("→", ",").replace("↑", "").replace("·", ",")
    async with sem:
        for attempt in range(3):
            try:
                await edge_tts.Communicate(spoken, voice, rate=rate, pitch=pitch).save(str(out))
                return
            except Exception as e:  # network hiccup: retry
                if attempt == 2:
                    print("FAILED", key, e)
                await asyncio.sleep(1.5)

async def main():
    AUDIO.mkdir(exist_ok=True)
    keys = json.loads((ROOT / "tools" / "lines.json").read_text(encoding="utf-8"))
    sem = asyncio.Semaphore(6)
    await asyncio.gather(*(record(k, sem) for k in keys))
    mapping = {k: "audio/" + fname(k) for k in keys if (AUDIO / fname(k)).exists()}
    (AUDIO / "clips.js").write_text("window.AUDIO=" + json.dumps(mapping, ensure_ascii=False) + ";\n", encoding="utf-8")
    print(f"{len(mapping)}/{len(keys)} clips ready")

asyncio.run(main())
