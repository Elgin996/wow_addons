# MRP Translate

[简体中文](README.md) | **English**

Read other players' [MyRolePlay](https://www.curseforge.com/wow/addons/my-role-play) (MRP) roleplay profiles in Simplified Chinese, and use MyRolePlay with a Chinese interface.

> **Status: early version.** Profiles have been translated in a live game client with the real Gemini API, including background translation and pasting several profiles at once. The new prompt bar and the F1–F3 hotkeys are still being tried out. Please report problems you run into.

## Why a clipboard helper?

World of Warcraft addons run in a sandbox: they cannot access the network, cannot read or write arbitrary files, and cannot put text on the clipboard. An addon alone therefore cannot call a translation service. This project adds a small desktop program and uses the **clipboard** as the bridge:

```
[Game]     Open a profile and press F1 (or click 翻译): the addon packs the text
           into a pre-selected text box
              │  ① you press F2 (or Ctrl+C) — the prompt closes; carry on playing
              ▼     or send more profiles
[Desktop]  Clipboard helper queues and translates in the background ── ② Gemini / OpenRouter
              │  ③ after each profile, writes ALL finished translations to the clipboard and beeps
              ▼
[Game]     ④ whenever you like, open any of those profiles, press F1 (or click 粘贴),
              then F3 (or Ctrl+V) → every finished profile is shown in Chinese
```

You press copy and paste yourself: the addon cannot write to the clipboard, it can only select the text and wait for your Ctrl+C. The helper never reads or writes the game process. The only keyboard-related part is the optional **F2 / F3 single-key mapping**: while the WoW window is in front, the helper turns a press of F2 / F3 into Ctrl+C / Ctrl+V, one keypress for one keypress, just like a key-remapping tool. You can turn it off in `config.json` and use Ctrl+C / Ctrl+V instead.

The helper only reacts to clipboard text that starts with `<<MRPTR1 REQ>>`; anything else you copy is ignored and never sent anywhere. If you copy something else while it is translating, it will not overwrite your clipboard.

## Features

- **Profile window**: translates title, currently, OOC info, eyes, height, weight, description, age, home, birthplace, motto, history, glances (at-a-glance notes) and custom personality trait names. Formatting is preserved: colors, links, icons, images and MRP layout tags are protected during translation and restored afterwards.
- **No waiting in game**: copy and walk away. The helper translates in the background and keeps finished translations for an hour; one paste later applies every profile finished in the meantime.
- **Single-key workflow**: while a profile window is open, F1 = the 翻译 / 粘贴 (Translate / Paste) button; F2 / F3 = copy / paste.
- **Tooltips and glance preview** show cached translations too.
- **Tooltip batch queue**: players you hover over are queued automatically. Translate a whole batch with one copy and one paste.
- **Cache keyed by content hash**: an unchanged profile is shown in Chinese instantly next time. When its owner edits a field, only that field needs translating again.
- **One-click toggle** between original text and translation.
- **Character names** are written with the original in brackets on first mention, e.g. 艾拉莉亚（Elaria）. Multi-part names are translated part by part, and surnames with an obvious meaning are translated the way official zhCN names are (e.g. Hawkstride → 鹰行者). Official Warcraft names (places, races, lore characters) use the official Chinese (zhCN) translations; the prompt includes a glossary of common ones.
- **Name glossary** (`names.json`) keeps names consistent across profiles. You can edit it to set your preferred spelling.
- **Chinese interface for MyRolePlay** (about 470 strings) on zhCN clients. MRP itself ships only English and French. Height and weight units are switched to centimetres and kilograms once; you can change them back in MRP's settings.
- Also fixes MRP cutting Chinese characters in half when it truncates long tooltip text.

## Requirements

- World of Warcraft with [MyRolePlay](https://www.curseforge.com/wow/addons/my-role-play) installed. The TOC lists the same client versions as MyRolePlay. The interface localization only applies on zhCN clients.
- Windows (the helper uses the Windows clipboard API).
- Python 3.10 or later (developed and tested with 3.14). Only the standard library is used; no `pip install` is needed.
- An API key for one of:
  - **Google Gemini** ([Google AI Studio](https://aistudio.google.com/)). Default model: `gemini-3.5-flash-lite` with thinking level `low`; a profile usually takes 2–8 seconds. For steadier official names, switch to `gemini-3.8-flash` (also with `low`; roughly twice as slow).
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

1. Start the helper: double-click `启动助手.bat`, or run `python mrptr_helper.py`. The window title shows its status (translating, how many profiles are waiting to be pasted).
2. In game, open someone's MRP profile and press **F1**, or click **翻译** (Translate) to the right of the tabs at the bottom of the profile window. A small prompt appears below the button.
3. Press **F2** (or Ctrl+C). The prompt closes and chat confirms the request was sent. You can now do something else, or send more profiles.
4. The helper beeps each time a profile is done. Whenever you like, open any of those profiles; the button now reads **粘贴** (Paste). Press **F1** (or click it), then **F3** (or Ctrl+V). Every profile finished in the meantime is applied at once, so the others show in Chinese when you open them.

Pressing Esc or any ordinary key (for example to walk) closes the prompt and gives the keyboard back to the game.

The **原文 / 中文** button toggles between the original and the translation. The toggle also applies to tooltips and the glance preview.

**About F1–F3**

- F1 is only the 翻译 / 粘贴 button while a profile window is open; when the window closes, F1 goes back to its usual function (target self by default). Key bindings cannot change during combat, so for a profile opened in combat F1 starts working once combat ends. To use another key, change `HOTKEY` near the top of `UI.lua`.
- F2 / F3 only act while the helper is running and the WoW window is in front; during that time their usual functions (target party members by default) are unavailable. Other programs are not affected at all. To change or disable them, edit `hotkeys` in `config.json` (F1–F24 are supported; leave empty to disable).

**If you copy something else while waiting**, the clipboard no longer holds the translations and the helper will not overwrite it. Press F1 → F2 in game to send again: the translations are cached, so the beep comes right away. Then press F1 → F3 to paste.

**Batch-translating tooltips.** Tooltips cannot pause for copying, so players you hover over are queued. After 5 players you get a hint in chat. Then either:

- bind a key under *Key Bindings → AddOns → MRP 档案翻译 → 翻译鼠标提示队列*, or
- type `/mrptr queue`.

Open the queue and press F2 to send the whole batch. After the beep, open the queue again (or open any of those profiles and press F1) and press F3 to paste.

| Command | Action |
|---|---|
| `/mrptr` | Show cache and queue status |
| `/mrptr queue` | Translate the tooltip queue |
| `/mrptr clear` | Clear all cached translations |

**Tip:** set `"provider": "test"` in `config.json` first. The helper then marks text as translated without calling any API, so you can try the in-game workflow for free.

## Configuration

All files are in `MRP_Translate_Helper/`. Restart the helper after editing them.

| File | Purpose |
|---|---|
| `config.json` | `provider` (`gemini`, `openrouter` or `test`), model names, `thinking_level` (Gemini thinking level, default `low`; leave empty to let the model decide, which can take over a minute for one profile), `timeout_seconds`, `beep`, `hotkeys` (single-key copy/paste, default `F2` / `F3`, empty to disable). `api_key` can be set here, but environment variables are recommended. |
| `prompt.txt` | Translation instructions and official-name glossary sent to the model. Edit freely. |
| `names.json` | Name glossary, created automatically. Existing entries are never overwritten by the model, so your manual edits stick. |
| `cache.json` | Translation cache, created automatically and capped at 5000 entries. Delete it (and run `/mrptr clear` in game) to force fresh translations. |

## Cost

With Gemini 3.8 Flash at paid-tier prices ($0.75 per 1M input tokens and $3.75 per 1M output tokens through 2026-12-31, doubling on 2027-01-01), a typical profile costs about **$0.01**. The default Flash-Lite model has lower per-token prices; check the provider's pricing page. The prompt includes an official-name glossary, which adds about 3,000 input tokens per request. Cached profiles cost nothing.

## Privacy

- Profile text written by **other players** is sent to the translation provider you choose.
- Gemini's free tier uses submitted content to improve Google's products; the paid tier does not.
- The helper only processes clipboard text that starts with the request header. Nothing else you copy is read or sent.
- The F2 / F3 mapping uses a Windows keyboard hook. It only looks at F2 and F3, only acts while the WoW window is in front, and passes every other key through untouched. Nothing is logged or sent.
- **This repository is public.** Never commit an API key in `config.json`; use environment variables.

## Project structure

```
MRP_Translate/                 WoW addon
  MRP_Translate.toc
  Locale_MRP_zhCN.lua          Chinese interface for MyRolePlay (zhCN clients only)
  Core.lua                     Protocol, markup protection, content hashing, cache
  UI.lua                       Buttons, copy/paste prompt, F1 hotkey, display hooks, tooltip queue
  Bindings.xml                 Key binding for the tooltip queue
MRP_Translate_Helper/          Desktop clipboard helper
  mrptr_helper.py              Background translation, ready pool, F2 / F3 mapping
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
- A response carries every translation the helper finished in the last hour (the ready pool), not just the latest request. The addon silently skips translations it has already applied.
- Errors are sent as `<<MRPTR1 ERR>> message`, but only when the ready pool is empty, so an error never pushes other players' translations off the clipboard.
- Body lines starting with `@` or `<` are escaped by prefixing another `@`.
- The 16-digit hash identifies the exact original text, so a translation is never shown for a field that has since changed.

## Known limitations

- Windows only.
- The ready pool lives in memory and is lost when the helper restarts. Finished profiles are still cached, so sending again (F1 → F2) gets them back immediately.
- A few English strings that are hard-coded in MyRolePlay's code (not in its locale table) cannot be localized without modifying MRP.
- The Haranir race name has no Chinese translation yet.

## Acknowledgements

- [MyRolePlay](https://www.curseforge.com/wow/addons/my-role-play) by Etarna Moonshyne, Katorie and Meorawr.
- The Mary Sue Protocol (LibMSP) community.

## License

Released under the [GNU General Public License v3 (GPLv3)](LICENSE), the same license as MyRolePlay. The interface localization file `Locale_MRP_zhCN.lua` is a translation of MyRolePlay's interface strings.
