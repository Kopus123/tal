# 탈 · Cheongsol Village

A mystery game for learning Korean. Live at https://kopus123.github.io/tal/

## What lives where

| Part | File | What you change there |
|---|---|---|
| World | `story/world.story` | Chapter list, characters, every word and its picture, the village map. No plot. |
| Chapters | `story/prologue.story` etc. | Each chapter's plot, places, clues, case questions, hints. Plain text. **Spoilers.** |
| Engine | `js/core/`, `js/ui/`, `js/audio.js`, `js/boot.js` | How the game works (see the list below) |
| Scene art | `js/art.js` | Drawings for each place |
| Word pictures | `js/icons.js` | The picture for each word, and the past/future/not badges |
| Characters | `js/people.js` | Portrait faces and the five expressions (each character's look is set in the story's cast list) |
| Look | `index.html` | Colors, fonts, layout (the CSS at the top) |
| Voices | `audio/` | Recorded automatically. Don't edit by hand |

## The engine, file by file

Plain scripts loaded in this order by `index.html`. No build step; functions are global.

| File | What it holds |
|---|---|
| `js/core/parse.js` | Reads `.story` files. The format is documented at the top of `story/world.story` |
| `js/core/state.js` | The save: what's in it, `SAVE_V`, `MIGRATE`, loading and storing |
| `js/core/rules.js` | Effects (`! set ...`) and conditions (`if ...`): `defEffect`, `defCond`, `cond`, `runFx` |
| `js/core/world.js` | What carries on between chapters: day, time of day, money, friendship, things you own |
| `js/core/words.js` | Tappable words: colors, mastery tracking, close-enough matching, names |
| `js/audio.js` | Voices, sound effects, vibration |
| `js/core/flow.js` | Moving through the story: beats, choices, typed and number answers, rewinds, chapters |
| `js/ui/render.js` | The main screen: scene window and the paper sheet |
| `js/ui/overlays.js` | Menu, settings, log, chapter list, map, title screen, toasts |
| `js/ui/notebook.js` | Word page and notebook |
| `js/ui/caseboard.js` | Case board: deductions, proof, evidence, statements |
| `js/ui/phone.js` | The phone |
| `js/boot.js` | Loads the story and the save, starts the game |
| `js/autotest.js` | The automatic playthrough and Jump ahead (only loaded when needed) |

To give story files a new effect or condition, add a `defEffect` / `defCond` line (`js/core/world.js` shows how). The checker picks it up by itself.

## After changing the story

```
python tools/build_audio.py
```

This records any new or changed lines and deletes clips nobody uses anymore. Then check everything still works:

```
python tools/check_story.py
python tools/playtest.py
```

`check_story.py` looks for broken jumps, words with no picture, flags that are never set, evidence nobody hands you, effects and conditions the game doesn't have, and lines with no recording. It reads the list of effects, conditions, sections and beats from the game's own code, so it can't fall behind.

`playtest.py` plays each route in `tests/` in a hidden Chrome window by pressing the real buttons, and says exactly where it got stuck if something broke. `tests/ch1.route` is a full solution (**spoilers**). `tests/engine.route` tests the engine itself: the rules, the world state, and old saves in `tests/saves/` upgrading.

Then bump `VERSION` in `sw.js` and push, and the installed app updates itself the next time it opens with internet.

## Saves

Saves carry a format version (`SAVE_V` in `js/core/state.js`). When the save format changes, bump it, add a step to `MIGRATE` so older saves upgrade instead of breaking, and add a save in the old format to `tests/saves/` with an `oldsave` check in `tests/engine.route`.

## Try it locally

```
python -m http.server 8765
```

Then open http://localhost:8765
