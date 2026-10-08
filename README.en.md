# MRP Translate

[简体中文](README.md) | **English**

Read other players' [MyRolePlay](https://www.curseforge.com/wow/addons/my-role-play) (MRP) roleplay profiles in Simplified Chinese, and use MyRolePlay with a Chinese interface.

> **Status: early version.** All logic passes offline tests (Lua 5.1 + a simulated WoW/MRP environment, plus the real Windows clipboard), but it has not yet been tested in a live game client or against the real translation APIs. Please report problems you run into.

## Why a clipboard helper?

World of Warcraft addons run in a sandbox: they cannot access the network or read and write arbitrary files. An addon alone therefore cannot call a translation service. This project adds a small desktop program and uses the **clipboard** as the bridge:

```
[Game]     Addon packs the profile text into a pre-selected text box
              │  ① you press Ctrl+C
              ▼
[Desktop]  Clipboard helper sees the request ── ② calls Gemini / OpenRouter
              │  ③ writes the translation back to the clipboard and beeps
              ▼
[Game]     ④ you press Ctrl+V in the same box → the profile is shown in Chinese
```

The helper never touches the game process and never sends keystrokes: you press both keys yourself. It only reacts to clipboard text that starts with `<<MRPTR1 REQ>>`; anything else you copy is ignored and never sent anywhere.

## Features

- **Profile window**: translates title, currently, OOC info, eyes, height, weight, description, age, home, birthplace, motto, history, glances (at-a-glance notes) and custom personality trait names. Formatting is preserved: colors, links, icons, images and MRP layout tags are protected during translation and restored afterwards.
- **Tooltips and glance preview** show cached translations too.
- **Tooltip batch queue**: players you hover over are queued automatically. Translate a whole batch with one Ctrl+C / Ctrl+V.
- **Cache keyed by content hash**: an unchanged profile is shown in Chinese instantly next time. When its owner edits a field, only that field needs translating again.
- **One-click toggle** between original text and translation.
- **Character names** are transliterated with the original in brackets on first mention, e.g. 艾拉莉亚（Elaria）. Official Warcraft names (places, races, lore characters) use the official Chinese (zhCN) translations.
- **Name glossary** (`names.json`) keeps transliterations consistent across profiles. You can edit it to set your preferred spelling.
- **Chinese interface for MyRolePlay** (about 470 strings) on zhCN clients. MRP itself ships only English and French. Height and weight units are switched to centimetres and kilograms once; you can change them back in MRP's settings.
- Also fixes MRP cutting Chinese characters in half when it truncates long tooltip text.

## Requirements

- World of Warcraft with [MyRolePlay](https://www.curseforge.com/wow/addons/my-role-play) installed. The TOC lists the same client versions as MyRolePlay. The interface localization only applies on zhCN clients.
- Windows (the helper uses the Windows clipboard API).
- Python 3.10 or later (developed and tested with 3.14). Only the standard library is used; no `pip install` is needed.
- An API key for one of:
  - **Google Gemini** ([Google AI Studio](https://aistudio.google.com/)). Default model: `gemini-3.8-flash`.
  - **OpenRouter** ([openrouter.ai](https://openrouter.ai/)). Default model: `google/gemini-3.8-flash`. Any model on OpenRouter can be used.

## Installation

1. Copy the `MRP_Translate` folder into `World of Warcraft\_retail_\Interface\AddOns\`.
2. Put `MRP_Translate_Helper` anywhere you like. It does not go into the game folder.
3. Set your API key as an environment variable, then open a **new** terminal window (`setx` only affects new ones):
   ```
   setx GEMINI_API_KEY "your-key"
   ```
   For OpenRouter, use `OPENROUTER_API_KEY` and set `"provider": "openrouter"` in `config.json`.
4. Check that the key and model work:
   ```
   python mrptr_helper.py --check
   ```

## Usage

1. Start the helper: double-click `启动助手.bat`, or run `python mrptr_helper.py`. The window title shows its status.
2. In game, open someone's MRP profile and click **翻译** (Translate) on the right edge of the profile window.
3. Press **Ctrl+C**. The text in the box is already selected.
4. Wait for the beep from the helper.
5. Click back into the box if needed, then press **Ctrl+V**. The profile switches to Chinese.

The **原文 / 中文** button toggles between the original and the translation. The toggle also applies to tooltips and the glance preview.

**Batch-translating tooltips.** Tooltips cannot pause for Ctrl+C, so players you hover over are queued. After 5 players you get a hint in chat. Then either:

- bind a key under *Key Bindings → AddOns → MRP 档案翻译 → 翻译鼠标提示队列*, or
- type `/mrptr queue`.

A single Ctrl+C / Ctrl+V then translates the whole batch.

| Command | Action |
|---|---|
| `/mrptr` | Show cache and queue status |
| `/mrptr queue` | Translate the tooltip queue |
| `/mrptr clear` | Clear all cached translations |

**Tip:** set `"provider": "test"` in `config.json` first. The helper then marks text as translated without calling any API, so you can try the in-game workflow for free.

## Configuration

All files are in `MRP_Translate_Helper/`.

| File | Purpose |
|---|---|
| `config.json` | `provider` (`gemini`, `openrouter` or `test`), model names, `timeout_seconds`, `beep`. `api_key` can be set here, but environment variables are recommended. |
| `prompt.txt` | Translation instructions sent to the model. Edit freely. |
| `names.json` | Name glossary, created automatically. Existing entries are never overwritten by the model, so your manual edits stick. |
| `cache.json` | Translation cache, created automatically and capped at 5000 entries. Delete it to force fresh translations. |

## Cost

With Gemini 3.8 Flash at paid-tier prices ($0.75 per 1M input tokens and $3.75 per 1M output tokens through 2026-12-31, doubling on 2027-01-01), a typical profile costs about **$0.01**. Cached profiles cost nothing. Prices change, so check the provider's pricing page.

## Privacy

- Profile text written by **other players** is sent to the translation provider you choose.
- Gemini's free tier uses submitted content to improve Google's products; the paid tier does not.
- The helper only processes clipboard text that starts with the request header. Nothing else you copy is read or sent.
- **This repository is public.** Never commit an API key in `config.json`; use environment variables.

## Project structure

```
MRP_Translate/                 WoW addon
  MRP_Translate.toc
  Locale_MRP_zhCN.lua          Chinese interface for MyRolePlay (zhCN clients only)
  Core.lua                     Protocol, markup protection, content hashing, cache
  UI.lua                       Buttons, copy/paste window, display hooks, tooltip queue
  Bindings.xml                 Key binding for the tooltip queue
MRP_Translate_Helper/          Desktop clipboard helper
  mrptr_helper.py
  config.json
  prompt.txt
  启动助手.bat                  Double-click launcher
```

### How translations are displayed

Right before MRP draws the profile window, a tooltip or the glance preview, the addon temporarily swaps that player's fields for their cached translations. It swaps them back immediately after drawing. MRP's own formatting, unit conversion, glance parsing and trait parsing therefore work unchanged, and **no MyRolePlay file is modified**. If something goes wrong, MRP falls back to the original text and a single warning is printed in chat.

### Clipboard protocol (`MRPTR1`)

```
<<MRPTR1 REQ>>
@player Name-Realm
@name Character Name
@field DE 0123456789abcdef
Body text, with markup replaced by {{1}}, {{2}} … placeholders
@player Another-Realm
…
<<MRPTR1 END>>
```

- The response uses `<<MRPTR1 RES>>` with the same layout, plus `@failed FIELD reason` lines for fields that could not be translated.
- Errors are sent as `<<MRPTR1 ERR>> message`.
- Body lines starting with `@` or `<` are escaped by prefixing another `@`.
- The 16-digit hash identifies the exact original text, so a translation is never shown for a field that has since changed.

## Known limitations

- Windows only.
- Not yet tested in a live game client (see Status above).
- A few English strings that are hard-coded in MyRolePlay's code (not in its locale table) cannot be localized without modifying MRP.
- The Haranir race name has no Chinese translation yet.

## Acknowledgements

- [MyRolePlay](https://www.curseforge.com/wow/addons/my-role-play) by Etarna Moonshyne, Katorie and Meorawr.
- The Mary Sue Protocol (LibMSP) community.

## License

Released under the [GNU General Public License v3 (GPLv3)](LICENSE), the same license as MyRolePlay. The interface localization file `Locale_MRP_zhCN.lua` is a translation of MyRolePlay's interface strings.
