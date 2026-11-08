# 탈 · Cheongsol Village

A mystery game for learning Korean. Live at https://kopus123.github.io/tal/

## What lives where

| Part | File | What you change there |
|---|---|---|
| World | `story/world.story` | Chapter list, characters, every word and its picture, the village map. No plot. |
| Chapters | `story/prologue.story` etc. | Each chapter's plot, places, clues, case questions, hints. Plain text. **Spoilers.** |
| Engine | `js/engine.js` | How the game works: screens, notebook, case board, voice, saving |
| Scene art | `js/art.js` | Drawings for each place |
| Word pictures | `js/icons.js` | The picture for each word, and the past/future/not badges |
| Characters | `js/people.js` | Portrait faces and the five expressions (each character's look is set in the story's cast list) |
| Look | `index.html` | Colors, fonts, layout (the CSS at the top) |
| Voices | `audio/` | Recorded automatically. Don't edit by hand |

## After changing the story

```
python tools/build_audio.py
```

This records any new or changed lines and deletes clips nobody uses anymore. Then check everything still works:

```
python tools/check_story.py
python tools/playtest.py
```

`check_story.py` looks for broken jumps, words with no picture, flags that are never set, evidence nobody hands you, and lines with no recording. `playtest.py` plays each route in `tests/` (a full solution, **spoilers**) in a hidden Chrome window by pressing the real buttons, and says exactly where it got stuck if something broke.

Then bump `VERSION` in `sw.js` and push, and the installed app updates itself the next time it opens with internet.

## Saves

Saves carry a format version (`SAVE_V` in `js/engine.js`). When the save format changes, bump it and add a step to `MIGRATE` so older saves upgrade instead of breaking.

## Try it locally

```
python -m http.server 8765
```

Then open http://localhost:8765
