"""Record one test line with every free edge-tts voice that can speak Korean, for comparison.
Output: voice-samples/<voice>.mp3  (not part of the game)"""
import asyncio, pathlib
import edge_tts

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "voice-samples"
LINE = "아니요... 할머니가 없어요. 방에 없어요. 마당에도 없어요. 이상해요... 우리 같이 찾아요!"
VOICES = ["ko-KR-SunHiNeural", "ko-KR-InJoonNeural", "ko-KR-HyunsuMultilingualNeural",
          "en-US-AvaMultilingualNeural", "en-US-EmmaMultilingualNeural", "en-US-AndrewMultilingualNeural",
          "en-US-BrianMultilingualNeural", "de-DE-SeraphinaMultilingualNeural", "de-DE-FlorianMultilingualNeural",
          "fr-FR-VivienneMultilingualNeural", "fr-FR-RemyMultilingualNeural", "it-IT-GiuseppeMultilingualNeural",
          "pt-BR-ThalitaMultilingualNeural", "en-AU-WilliamMultilingualNeural"]

async def main():
    OUT.mkdir(exist_ok=True)
    async def one(i, v):
        short = v.split("-")[2].replace("MultilingualNeural", "").replace("Neural", "")
        await edge_tts.Communicate(LINE, v).save(str(OUT / f"{i:02d}-{short}.mp3"))
    await asyncio.gather(*(one(i, v) for i, v in enumerate(VOICES, 1)))
    print("done")

asyncio.run(main())
