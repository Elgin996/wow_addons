"""MRP 档案翻译 · 剪贴板助手

配合魔兽世界插件 MRP_Translate 使用：在游戏里点「翻译」并按 Ctrl+C 后，本程序从剪贴板
读到翻译请求，在后台调用翻译接口，翻好后把译文写回剪贴板并响提示音。不用在游戏里干等：
可以接着翻别的档案，之后打开其中任意一份点「粘贴」、按 Ctrl+V，翻好的档案一次全部写入。

只处理以 <<MRPTR1 REQ>> 开头的剪贴板内容，你复制的其他东西不会被发送到任何地方。

用法：
    双击「启动助手.bat」，或 python mrptr_helper.py     常驻运行，监听剪贴板（Ctrl+C 退出）
    python mrptr_helper.py --check                       用一小段测试文本检查 API key 和模型

配置在同目录的 config.json，翻译要求在 prompt.txt，人名对照表在 names.json，都可以直接改。
API key 建议放在环境变量 GEMINI_API_KEY 或 OPENROUTER_API_KEY 里，不要写进插件目录。
"""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import queue
import re
import sys
import threading
import time
import urllib.error
import urllib.request
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONFIG_PATH = HERE / "config.json"
PROMPT_PATH = HERE / "prompt.txt"
CACHE_PATH = HERE / "cache.json"
NAMES_PATH = HERE / "names.json"

HEADER_REQ = "<<MRPTR1 REQ>>"
HEADER_RES = "<<MRPTR1 RES>>"
HEADER_ERR = "<<MRPTR1 ERR>>"
FOOTER = "<<MRPTR1 END>>"

FIELD_LABELS = {
    "NT": "头衔", "CU": "当前状态", "CO": "场外信息", "AE": "眼睛", "AH": "身高", "AW": "体型",
    "DE": "外貌描述", "AG": "年龄", "HH": "居住地", "HB": "出生地", "MO": "格言", "HI": "背景故事",
    "PE": "一眼印象", "PS": "性格特质",
}

FIELD_LINE = re.compile(r"^@field ([A-Z]{2}) ([0-9a-f]+)\s*$")
PLACEHOLDER = re.compile(r"\{\{(\d+)\}\}")
# 模型偶尔会把占位符写成全角括号，或在括号里加空格
LOOSE_PLACEHOLDER = re.compile(r"[{｛]\s*[{｛]\s*(\d+)\s*[}｝]\s*[}｝]")

DEFAULT_CONFIG = {
    "provider": "gemini",
    "gemini": {"model": "gemini-3.8-flash", "api_key": "", "thinking_level": "low"},
    "openrouter": {"model": "google/gemini-3.8-flash", "api_key": ""},
    "timeout_seconds": 180,
    "beep": True,
    "hotkeys": {"copy": "F2", "paste": "F3"},
}

API_KEY_ENV = {"gemini": "GEMINI_API_KEY", "openrouter": "OPENROUTER_API_KEY"}


class ProtocolError(Exception):
    """剪贴板里的请求格式不对。"""


class TranslateError(Exception):
    """翻译接口调用失败。"""


def log(message: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {message}", flush=True)


def set_title(status: str) -> None:
    """在命令行窗口标题上显示状态，最小化时看任务栏就知道进行到哪了。"""
    try:
        ctypes.windll.kernel32.SetConsoleTitleW(f"MRP 翻译助手 · {status}")
    except (AttributeError, OSError):
        pass


def labels(keys) -> str:
    return "、".join(FIELD_LABELS.get(key, key) for key in keys)


def short_name(player: str) -> str:
    return player.split("-", 1)[0]


# ------------------------------------------------------------------
# 协议：和插件 Core.lua 的 Pack / Parse 一一对应
# ------------------------------------------------------------------

@dataclass
class Field:
    key: str
    hash: str
    body: str  # 受保护的原文（格式标记已换成 {{n}}）


@dataclass
class Block:
    player: str
    name: str | None
    fields: list[Field] = field(default_factory=list)

    @property
    def display_name(self) -> str:
        return self.name or short_name(self.player)


def parse_request(text: str) -> list[Block]:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    start = text.find(HEADER_REQ)
    if start < 0:
        raise ProtocolError("不是翻译请求")
    end = text.find("\n" + FOOTER, start)
    if end < 0:
        raise ProtocolError("请求不完整（缺少结束标记），请回游戏点「重新全选」后再按 Ctrl+C")

    blocks: list[Block] = []
    bodies: list[tuple[Block, str, str, list[str]]] = []
    block = None
    current = None
    for line in text[start + len(HEADER_REQ):end].split("\n")[1:]:
        if re.match(r"^@[a-z]", line):
            match = FIELD_LINE.match(line)
            if line.startswith("@player "):
                block = Block(line[len("@player "):].strip(), None)
                blocks.append(block)
                current = None
            elif match and block is not None:
                current = (block, match.group(1), match.group(2), [])
                bodies.append(current)
            elif line.startswith("@name ") and block is not None:
                block.name = line[len("@name "):].strip()
            continue
        if current is not None:
            if line.startswith(("@@", "@<")):
                line = line[1:]
            current[3].append(line)

    for owner, key, hash_, lines in bodies:
        owner.fields.append(Field(key, hash_, "\n".join(lines).rstrip()))
    blocks = [b for b in blocks if b.player and b.fields]
    if not blocks:
        raise ProtocolError("请求里没有要翻译的字段")
    return blocks


def one_line(text: str) -> str:
    return " ".join(str(text).split())


def escape_line(line: str) -> str:
    return "@" + line if line.startswith(("@", "<")) else line


def format_response(blocks: list[Block], translated: dict, failed: dict) -> str:
    """translated / failed 的键是 (玩家, 字段)。"""
    lines = [HEADER_RES]
    for block in blocks:
        lines.append(f"@player {block.player}")
        if block.name:
            lines.append(f"@name {block.name}")
        for f in block.fields:
            reason = failed.get((block.player, f.key))
            if reason:
                lines.append(f"@failed {f.key} {one_line(reason)}")
        for f in block.fields:
            text = translated.get((block.player, f.key))
            if text is not None:
                lines.append(f"@field {f.key} {f.hash}")
                lines.extend(escape_line(line) for line in text.split("\n"))
    lines.append(FOOTER)
    return "\n".join(lines)


def format_error(message: str) -> str:
    return f"{HEADER_ERR} {one_line(message)}\n{FOOTER}"


def clean_translation(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = LOOSE_PLACEHOLDER.sub(r"{{\1}}", text)
    # 游戏里 | 是格式码的开头，译文里不能出现
    text = text.replace("|", "｜")
    return text.strip()


def placeholders_match(source: str, translated: str) -> bool:
    return Counter(PLACEHOLDER.findall(source)) == Counter(PLACEHOLDER.findall(translated))


# ------------------------------------------------------------------
# 人名对照表
# ------------------------------------------------------------------
# 每次翻译时，模型顺带返回这次用到的人名音译；第一次出现的名字记进 names.json，
# 之后的请求里只要原文提到这个名字，就把已有译名发给模型，要求照用。
# 已有的条目不会被模型覆盖，你可以直接编辑 names.json 指定某个名字的译法。

def load_names() -> dict[str, str]:
    try:
        data = json.loads(NAMES_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except (OSError, ValueError):
        log("names.json 读取失败，本次不使用人名对照表")
        return {}
    return {str(k): str(v) for k, v in data.items()} if isinstance(data, dict) else {}


def save_names(names: dict[str, str]) -> None:
    write_json(NAMES_PATH, dict(sorted(names.items(), key=lambda kv: kv[0].lower())))


def relevant_names(names: dict[str, str], texts: list[str]) -> dict[str, str]:
    joined = "\n".join(texts)
    found = {}
    for original, translation in names.items():
        if re.search(r"(?<![A-Za-z])" + re.escape(original) + r"(?![A-Za-z])", joined):
            found[original] = translation
    return found


def merge_names(names: dict[str, str], entries) -> int:
    added = 0
    for entry in entries if isinstance(entries, list) else []:
        if not isinstance(entry, dict):
            continue
        original = str(entry.get("original", "")).strip()
        # 要的是纯音译；模型偶尔会照正文的写法带上“（原文）”
        translation = re.sub(r"\s*[（(][^（）()]*[)）]\s*$", "", str(entry.get("translation", ""))).strip()
        if not original or not translation or original == translation:
            continue
        if "\n" in original or len(original) > 60 or len(translation) > 60:
            continue
        if original not in names:
            names[original] = translation
            added += 1
    return added


# ------------------------------------------------------------------
# 翻译接口
# ------------------------------------------------------------------

def build_user_message(items: list[dict], known_names: dict[str, str]) -> str:
    payload = {"known_names": known_names, "items": items}
    return (
        "请翻译 items 里每一项的 text。返回 JSON：translations 里每一项对应一个 id 和它的简体中文译文；"
        "names 里列出这次译文中出现的人名及其音译。\n\n"
        + json.dumps(payload, ensure_ascii=False, indent=2)
    )


def post_json(url: str, body: dict, headers: dict[str, str], timeout: float) -> dict:
    request = urllib.request.Request(
        url,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json", **headers},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        try:
            payload = json.loads(detail).get("error")
            message = payload.get("message") if isinstance(payload, dict) else str(payload)
        except (ValueError, AttributeError):
            message = detail[:300]
        raise TranslateError(f"HTTP {error.code}：{message}") from None
    except urllib.error.URLError as error:
        raise TranslateError(f"网络错误：{error.reason}") from None
    except TimeoutError:
        raise TranslateError("请求超时") from None
    except json.JSONDecodeError:
        raise TranslateError("接口返回的内容不是 JSON") from None


def parse_json_object(text: str) -> dict:
    text = text.strip()
    fenced = re.match(r"^```(?:json)?\s*(.*?)\s*```$", text, re.S)
    if fenced:
        text = fenced.group(1)
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        start, end = text.find("{"), text.rfind("}")
        if start < 0 or end <= start:
            raise TranslateError("模型返回的不是 JSON") from None
        try:
            value = json.loads(text[start:end + 1])
        except json.JSONDecodeError:
            raise TranslateError("模型返回的 JSON 无法解析") from None
    if not isinstance(value, dict):
        raise TranslateError("模型返回的 JSON 不是对象")
    return value


def response_schema(upper: bool) -> dict:
    """Gemini 用大写类型名，OpenRouter（JSON Schema）用小写且要求 additionalProperties。"""
    def t(name):
        return name.upper() if upper else name

    def obj(props):
        schema = {"type": t("object"), "properties": props, "required": list(props)}
        if not upper:
            schema["additionalProperties"] = False
        return schema

    return obj({
        "translations": {"type": t("array"), "items": obj({"id": {"type": t("string")}, "text": {"type": t("string")}})},
        "names": {"type": t("array"), "items": obj({"original": {"type": t("string")}, "translation": {"type": t("string")}})},
    })


class GeminiTranslator:
    def __init__(self, model: str, api_key: str, system_prompt: str, timeout: float, thinking_level: str = ""):
        self.model, self.api_key, self.system_prompt, self.timeout = model, api_key, system_prompt, timeout
        self.thinking_level = thinking_level
        self.label = f"Gemini · {model}" + (f" · 思考 {thinking_level}" if thinking_level else "")

    def translate(self, items: list[dict], known_names: dict[str, str]) -> tuple[dict, str]:
        generation_config = {"responseMimeType": "application/json", "responseSchema": response_schema(True)}
        # 不设时模型自己决定思考多久，同一份档案可能思考上万 token、要等一分多钟；翻译用 low 就够了
        if self.thinking_level:
            generation_config["thinkingConfig"] = {"thinkingLevel": self.thinking_level}
        body = {
            "systemInstruction": {"parts": [{"text": self.system_prompt}]},
            "contents": [{"role": "user", "parts": [{"text": build_user_message(items, known_names)}]}],
            "generationConfig": generation_config,
        }
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent"
        data = post_json(url, body, {"x-goog-api-key": self.api_key}, self.timeout)

        block = (data.get("promptFeedback") or {}).get("blockReason")
        if block:
            raise TranslateError(f"Gemini 拒绝了这份档案（{block}）")
        candidates = data.get("candidates") or []
        if not candidates:
            raise TranslateError("Gemini 没有返回结果")
        candidate = candidates[0]
        parts = (candidate.get("content") or {}).get("parts") or []
        text = "".join(part.get("text", "") for part in parts if not part.get("thought"))
        if not text:
            raise TranslateError(f"Gemini 没有返回译文（finishReason={candidate.get('finishReason')}）")
        if candidate.get("finishReason") == "MAX_TOKENS":
            raise TranslateError("译文太长被截断了")

        usage = data.get("usageMetadata") or {}
        usage_text = "输入 {} / 输出 {} / 思考 {} tokens".format(
            usage.get("promptTokenCount", "?"),
            usage.get("candidatesTokenCount", "?"),
            usage.get("thoughtsTokenCount", 0),
        )
        return parse_json_object(text), usage_text


class OpenRouterTranslator:
    URL = "https://openrouter.ai/api/v1/chat/completions"

    def __init__(self, model: str, api_key: str, system_prompt: str, timeout: float):
        self.model, self.api_key, self.system_prompt, self.timeout = model, api_key, system_prompt, timeout
        self.label = f"OpenRouter · {model}"

    def translate(self, items: list[dict], known_names: dict[str, str]) -> tuple[dict, str]:
        body = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": self.system_prompt},
                {"role": "user", "content": build_user_message(items, known_names)},
            ],
            "response_format": {
                "type": "json_schema",
                "json_schema": {"name": "mrp_translation", "strict": True, "schema": response_schema(False)},
            },
        }
        headers = {"Authorization": f"Bearer {self.api_key}", "X-Title": "MRP Translate"}
        data = post_json(self.URL, body, headers, self.timeout)

        if data.get("error"):
            error = data["error"]
            raise TranslateError(f"OpenRouter 报错：{error.get('message', error) if isinstance(error, dict) else error}")
        choices = data.get("choices") or []
        if not choices:
            raise TranslateError("OpenRouter 没有返回结果")
        choice = choices[0]
        if choice.get("error"):
            raise TranslateError(f"OpenRouter 报错：{choice['error'].get('message', choice['error'])}")
        if choice.get("finish_reason") == "length":
            raise TranslateError("译文太长被截断了")
        content = (choice.get("message") or {}).get("content")
        if isinstance(content, list):
            content = "".join(part.get("text", "") for part in content if isinstance(part, dict))
        if not content:
            raise TranslateError(f"OpenRouter 没有返回译文（finish_reason={choice.get('finish_reason')}）")

        usage = data.get("usage") or {}
        usage_text = "输入 {} / 输出 {} tokens".format(
            usage.get("prompt_tokens", "?"), usage.get("completion_tokens", "?"))
        if usage.get("cost") is not None:
            usage_text += f" / ${usage['cost']}"
        return parse_json_object(content), usage_text


class TestTranslator:
    """不调接口，只在原文前加个标记。用来先跑通游戏里的复制粘贴流程，不花钱。"""

    label = "离线测试（不调用接口）"

    def translate(self, items: list[dict], known_names: dict[str, str]) -> tuple[dict, str]:
        translations = [{"id": item["id"], "text": "【测试译文】" + item["text"]} for item in items]
        return {"translations": translations, "names": []}, "未调用接口"


def make_translator(config: dict):
    provider = str(config.get("provider", "gemini")).lower()
    if provider == "test":
        return TestTranslator()
    if provider not in API_KEY_ENV:
        raise SystemExit(f"config.json 里的 provider 只能是 gemini、openrouter 或 test，现在是：{provider}")

    section = config.get(provider) or {}
    model = section.get("model") or DEFAULT_CONFIG[provider]["model"]
    env_name = API_KEY_ENV[provider]
    api_key = os.environ.get(env_name) or section.get("api_key")
    if not api_key:
        raise SystemExit(f"没有找到 API key：请设置环境变量 {env_name}，或填写 config.json 里的 {provider}.api_key")
    if not PROMPT_PATH.exists():
        raise SystemExit(f"找不到翻译要求文件：{PROMPT_PATH}")

    system_prompt = PROMPT_PATH.read_text(encoding="utf-8")
    timeout = float(config.get("timeout_seconds", DEFAULT_CONFIG["timeout_seconds"]))
    if provider == "gemini":
        thinking_level = section.get("thinking_level", DEFAULT_CONFIG["gemini"]["thinking_level"])
        return GeminiTranslator(model, api_key, system_prompt, timeout, thinking_level or "")
    return OpenRouterTranslator(model, api_key, system_prompt, timeout)


def cache_key(player: str, key: str, hash_: str) -> str:
    return f"{player}|{key}|{hash_}"


@dataclass
class Outcome:
    translated: dict = field(default_factory=dict)  # (玩家, 字段) -> 译文
    failed: dict = field(default_factory=dict)      # (玩家, 字段) -> 原因
    usages: list = field(default_factory=list)      # 每次接口调用的用量说明
    names_added: int = 0


def translate_request(blocks: list[Block], translator, cache: dict, names: dict[str, str]) -> Outcome:
    """缓存命中的字段不再请求。所有玩家的字段合在一次请求里发出去。

    第一次请求里占位符对不上或缺字段的，单独再请求一次；第二次还不行就放弃。
    第一次请求本身失败（网络、key、拒绝）直接抛出，由调用方回报给游戏。
    names 是人名对照表，会被就地补充。
    """
    outcome = Outcome()
    todo: dict[str, tuple[Block, Field]] = {}
    for block in blocks:
        for f in block.fields:
            cached = cache.get(cache_key(block.player, f.key, f.hash))
            if cached is not None:
                outcome.translated[(block.player, f.key)] = cached
            else:
                todo[str(len(todo) + 1)] = (block, f)

    for attempt in range(2):
        if not todo:
            break
        items = [
            {"id": item_id, "character_name": block.display_name,
             "field": FIELD_LABELS.get(f.key, f.key), "text": f.body}
            for item_id, (block, f) in todo.items()
        ]
        known = relevant_names(names, [item["text"] for item in items] + [item["character_name"] for item in items])
        try:
            result, usage = translator.translate(items, known)
        except TranslateError as error:
            if attempt == 0:
                raise
            for block, f in todo.values():
                outcome.failed[(block.player, f.key)] = f"重试失败：{error}"
            break
        outcome.usages.append(usage)
        outcome.names_added += merge_names(names, result.get("names"))

        returned = {}
        for entry in result.get("translations") or []:
            if isinstance(entry, dict) and isinstance(entry.get("id"), str) and isinstance(entry.get("text"), str):
                returned[entry["id"]] = entry["text"]

        retry: dict[str, tuple[Block, Field]] = {}
        for item_id, (block, f) in todo.items():
            where = (block.player, f.key)
            value = returned.get(item_id)
            if not value or not value.strip():
                outcome.failed[where] = "模型没有返回这个字段"
                retry[item_id] = (block, f)
                continue
            text = clean_translation(value)
            if placeholders_match(f.body, text):
                outcome.translated[where] = text
                outcome.failed.pop(where, None)
                cache[cache_key(block.player, f.key, f.hash)] = text
            else:
                outcome.failed[where] = "格式占位符对不上"
                retry[item_id] = (block, f)
        todo = retry

    return outcome


# ------------------------------------------------------------------
# 文件
# ------------------------------------------------------------------

def write_json(path: Path, data) -> None:
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    temp.replace(path)


MAX_CACHE_ENTRIES = 5000


def save_cache(cache: dict) -> None:
    # 每次翻译都整份重写，太大会拖慢；超出上限时丢掉最早加入的条目
    while len(cache) > MAX_CACHE_ENTRIES:
        del cache[next(iter(cache))]
    write_json(CACHE_PATH, cache)


def load_cache() -> dict:
    try:
        return json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except (OSError, ValueError):
        log("cache.json 读取失败，本次从空缓存开始")
        return {}


# ------------------------------------------------------------------
# 单键复制粘贴：魔兽窗口在前台时，把 F2 / F3 换成 Ctrl+C / Ctrl+V
# ------------------------------------------------------------------
# 和改键软件一样，一次按键只换成一次按键；按住不放不会连发，其他程序里 F2 / F3 不受影响。

WOW_EXES = {"wow.exe", "wowclassic.exe", "wowt.exe", "wowb.exe", "wowclassict.exe", "wowclassicb.exe"}
VK_CONTROL, VK_C, VK_V = 0x11, 0x43, 0x56


def parse_key(name: str) -> int | None:
    """目前只支持功能键 F1–F24。"""
    match = re.fullmatch(r"[Ff]([1-9]|1[0-9]|2[0-4])", (name or "").strip())
    return 0x70 + int(match.group(1)) - 1 if match else None


def start_key_remap(config: dict) -> None:
    hotkeys = config.get("hotkeys", DEFAULT_CONFIG["hotkeys"]) or {}
    mapping, shown = {}, []
    for action, target in (("copy", VK_C), ("paste", VK_V)):
        name = hotkeys.get(action, "")
        if not name:
            continue
        vk = parse_key(name)
        if vk is None:
            log(f"config.json 里 hotkeys.{action} 的「{name}」认不出来，只支持 F1–F24，这个键没启用。")
            continue
        mapping[vk] = target
        shown.append(f"{name.upper()} = Ctrl+{'C' if target == VK_C else 'V'}")
    if not mapping:
        return
    threading.Thread(target=_key_remap_loop, args=(mapping,), daemon=True).start()
    log(f"魔兽窗口在前台时：{'，'.join(shown)}（在 config.json 的 hotkeys 里可以改，留空就关掉）。")


def _key_remap_loop(mapping: dict[int, int]) -> None:
    from ctypes import wintypes as w

    user32 = ctypes.WinDLL("user32", use_last_error=True)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    LRESULT = ctypes.c_ssize_t

    class KBDLLHOOKSTRUCT(ctypes.Structure):
        _fields_ = [("vkCode", w.DWORD), ("scanCode", w.DWORD), ("flags", w.DWORD),
                    ("time", w.DWORD), ("dwExtraInfo", ctypes.c_size_t)]

    class KEYBDINPUT(ctypes.Structure):
        _fields_ = [("wVk", w.WORD), ("wScan", w.WORD), ("dwFlags", w.DWORD),
                    ("time", w.DWORD), ("dwExtraInfo", ctypes.c_size_t)]

    class MOUSEINPUT(ctypes.Structure):  # 只为了让 INPUT 的大小和系统一致
        _fields_ = [("dx", w.LONG), ("dy", w.LONG), ("mouseData", w.DWORD), ("dwFlags", w.DWORD),
                    ("time", w.DWORD), ("dwExtraInfo", ctypes.c_size_t)]

    class INPUT(ctypes.Structure):
        class _U(ctypes.Union):
            _fields_ = [("ki", KEYBDINPUT), ("mi", MOUSEINPUT)]
        _anonymous_ = ("u",)
        _fields_ = [("type", w.DWORD), ("u", _U)]

    HOOKPROC = ctypes.WINFUNCTYPE(LRESULT, ctypes.c_int, w.WPARAM, w.LPARAM)
    user32.SetWindowsHookExW.argtypes = [ctypes.c_int, HOOKPROC, w.HINSTANCE, w.DWORD]
    user32.SetWindowsHookExW.restype = ctypes.c_void_p
    user32.CallNextHookEx.argtypes = [ctypes.c_void_p, ctypes.c_int, w.WPARAM, w.LPARAM]
    user32.CallNextHookEx.restype = LRESULT
    user32.GetForegroundWindow.restype = w.HWND
    user32.GetWindowThreadProcessId.argtypes = [w.HWND, ctypes.POINTER(w.DWORD)]
    user32.SendInput.argtypes = [w.UINT, ctypes.POINTER(INPUT), ctypes.c_int]
    user32.MapVirtualKeyW.argtypes = [w.UINT, w.UINT]
    user32.GetMessageW.argtypes = [ctypes.POINTER(w.MSG), w.HWND, w.UINT, w.UINT]
    kernel32.GetModuleHandleW.restype = w.HMODULE
    kernel32.OpenProcess.argtypes = [w.DWORD, w.BOOL, w.DWORD]
    kernel32.OpenProcess.restype = w.HANDLE
    kernel32.QueryFullProcessImageNameW.argtypes = [w.HANDLE, w.DWORD, w.LPWSTR, ctypes.POINTER(w.DWORD)]
    kernel32.CloseHandle.argtypes = [w.HANDLE]

    WH_KEYBOARD_LL, LLKHF_INJECTED, KEYEVENTF_KEYUP = 13, 0x10, 0x0002
    KEY_DOWN, KEY_UP = (0x100, 0x104), (0x101, 0x105)
    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000

    def wow_in_front() -> bool:
        pid = w.DWORD()
        user32.GetWindowThreadProcessId(user32.GetForegroundWindow(), ctypes.byref(pid))
        handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid.value)
        if not handle:
            return False
        try:
            buffer, size = ctypes.create_unicode_buffer(1024), w.DWORD(1024)
            if not kernel32.QueryFullProcessImageNameW(handle, 0, buffer, ctypes.byref(size)):
                return False
            return os.path.basename(buffer.value).lower() in WOW_EXES
        finally:
            kernel32.CloseHandle(handle)

    def key(vk: int, up: bool) -> INPUT:
        event = INPUT(type=1)
        event.ki = KEYBDINPUT(wVk=vk, wScan=user32.MapVirtualKeyW(vk, 0), dwFlags=KEYEVENTF_KEYUP if up else 0)
        return event

    def send_ctrl(vk: int) -> None:
        events = (INPUT * 4)(key(VK_CONTROL, False), key(vk, False), key(vk, True), key(VK_CONTROL, True))
        user32.SendInput(4, events, ctypes.sizeof(INPUT))

    held: set[int] = set()

    def on_key(code, w_param, l_param):
        if code == 0:
            info = ctypes.cast(l_param, ctypes.POINTER(KBDLLHOOKSTRUCT)).contents
            target = mapping.get(info.vkCode)
            if target and not info.flags & LLKHF_INJECTED:
                if w_param in KEY_DOWN:
                    if info.vkCode in held:
                        return 1  # 按住不放时的自动重复，吞掉不发
                    if wow_in_front():
                        held.add(info.vkCode)
                        send_ctrl(target)
                        return 1
                elif w_param in KEY_UP and info.vkCode in held:
                    held.discard(info.vkCode)
                    return 1
        return user32.CallNextHookEx(None, code, w_param, l_param)

    proc = HOOKPROC(on_key)  # 留着引用，免得被回收
    if not user32.SetWindowsHookExW(WH_KEYBOARD_LL, proc, kernel32.GetModuleHandleW(None), 0):
        log(f"单键复制粘贴没能启用（错误码 {ctypes.get_last_error()}），照常用 Ctrl+C / Ctrl+V 就行。")
        return
    msg = w.MSG()
    while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) > 0:
        pass


# ------------------------------------------------------------------
# Windows 剪贴板
# ------------------------------------------------------------------

class ClipboardError(Exception):
    pass


class Clipboard:
    CF_UNICODETEXT = 13
    GMEM_MOVEABLE = 0x0002

    def __init__(self):
        from ctypes import wintypes as w

        self.user32 = ctypes.WinDLL("user32", use_last_error=True)
        self.kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        u, k = self.user32, self.kernel32
        u.OpenClipboard.argtypes, u.OpenClipboard.restype = [w.HWND], w.BOOL
        u.CloseClipboard.argtypes, u.CloseClipboard.restype = [], w.BOOL
        u.EmptyClipboard.argtypes, u.EmptyClipboard.restype = [], w.BOOL
        u.GetClipboardData.argtypes, u.GetClipboardData.restype = [w.UINT], w.HANDLE
        u.SetClipboardData.argtypes, u.SetClipboardData.restype = [w.UINT, w.HANDLE], w.HANDLE
        u.IsClipboardFormatAvailable.argtypes, u.IsClipboardFormatAvailable.restype = [w.UINT], w.BOOL
        u.GetClipboardSequenceNumber.argtypes, u.GetClipboardSequenceNumber.restype = [], w.DWORD
        k.GlobalAlloc.argtypes, k.GlobalAlloc.restype = [w.UINT, ctypes.c_size_t], w.HGLOBAL
        k.GlobalLock.argtypes, k.GlobalLock.restype = [w.HGLOBAL], w.LPVOID
        k.GlobalUnlock.argtypes, k.GlobalUnlock.restype = [w.HGLOBAL], w.BOOL
        k.GlobalFree.argtypes, k.GlobalFree.restype = [w.HGLOBAL], w.HGLOBAL

    def sequence(self) -> int:
        return self.user32.GetClipboardSequenceNumber()

    def _open(self) -> bool:
        # 别的程序可能正占着剪贴板，稍等重试
        for _ in range(40):
            if self.user32.OpenClipboard(None):
                return True
            time.sleep(0.05)
        return False

    def read_text(self) -> str | None:
        if not self.user32.IsClipboardFormatAvailable(self.CF_UNICODETEXT):
            return None
        if not self._open():
            return None
        try:
            handle = self.user32.GetClipboardData(self.CF_UNICODETEXT)
            if not handle:
                return None
            pointer = self.kernel32.GlobalLock(handle)
            if not pointer:
                return None
            try:
                return ctypes.wstring_at(pointer)
            finally:
                self.kernel32.GlobalUnlock(handle)
        finally:
            self.user32.CloseClipboard()

    def write_text(self, text: str) -> None:
        data = text.encode("utf-16-le") + b"\x00\x00"
        handle = self.kernel32.GlobalAlloc(self.GMEM_MOVEABLE, len(data))
        if not handle:
            raise ClipboardError("申请内存失败")
        pointer = self.kernel32.GlobalLock(handle)
        if not pointer:
            self.kernel32.GlobalFree(handle)
            raise ClipboardError("锁定内存失败")
        ctypes.memmove(pointer, data, len(data))
        self.kernel32.GlobalUnlock(handle)

        if not self._open():
            self.kernel32.GlobalFree(handle)
            raise ClipboardError("剪贴板被其他程序占用")
        try:
            self.user32.EmptyClipboard()
            # 成功后这块内存归系统管，不能再释放
            if not self.user32.SetClipboardData(self.CF_UNICODETEXT, handle):
                self.kernel32.GlobalFree(handle)
                raise ClipboardError("写入剪贴板失败")
        finally:
            self.user32.CloseClipboard()


# ------------------------------------------------------------------
# 主循环
# ------------------------------------------------------------------

POOL_TTL_SECONDS = 3600
MAX_POOL_PLAYERS = 40


class ReadyPool:
    """翻好的译文先放这里，每次写剪贴板都把整池带上。

    这样连着翻几份档案时，后一份不会把前一份挤掉，回游戏粘贴一次就全拿到。
    不知道游戏里粘贴过没有，所以只按时间清理；重复粘贴同一段译文，插件会跳过。
    """

    def __init__(self):
        self.lock = threading.Lock()
        self.players: dict[str, dict] = {}  # 玩家 -> {"name", "at", "fields": {字段: (哈希, 译文)}}

    def add(self, blocks: list[Block], translated: dict) -> None:
        now = time.time()
        with self.lock:
            for block in blocks:
                for f in block.fields:
                    text = translated.get((block.player, f.key))
                    if text is None:
                        continue
                    entry = self.players.setdefault(block.player, {"name": block.name, "fields": {}})
                    entry["name"] = block.name or entry["name"]
                    entry["at"] = now
                    entry["fields"][f.key] = (f.hash, text)
            self._prune(now)

    def _prune(self, now: float) -> None:
        for player in [p for p, e in self.players.items() if now - e["at"] > POOL_TTL_SECONDS]:
            del self.players[player]
        while len(self.players) > MAX_POOL_PLAYERS:
            del self.players[min(self.players, key=lambda p: self.players[p]["at"])]

    def response(self) -> tuple[str, list[str]]:
        """返回要写进剪贴板的整池译文，以及其中各人的显示名。"""
        with self.lock:
            self._prune(time.time())
            blocks, translated = [], {}
            for player, entry in self.players.items():
                block = Block(player, entry["name"])
                for key, (hash_, text) in entry["fields"].items():
                    block.fields.append(Field(key, hash_, ""))
                    translated[(player, key)] = text
                blocks.append(block)
            return format_response(blocks, translated, {}), [b.display_name for b in blocks]


def beep(config: dict, ok: bool) -> None:
    if not config.get("beep", True):
        return
    import winsound
    winsound.MessageBeep(winsound.MB_OK if ok else winsound.MB_ICONHAND)


def is_ours(text: str | None) -> bool:
    """剪贴板里是不是本程序的东西（请求、译文、报错）。不是的话就是你自己复制的，不能覆盖。"""
    if not text:
        return True
    head = text.lstrip()
    return head.startswith((HEADER_REQ, HEADER_RES, HEADER_ERR))


def handle(config: dict, translator, cache: dict, pool: ReadyPool, outbox: queue.Queue, text: str) -> None:
    """在后台线程里跑：翻译一份请求，结果放进 pool，再通知主线程写剪贴板。"""
    started = time.monotonic()
    try:
        blocks = parse_request(text)
    except ProtocolError as error:
        log(f"请求格式有误：{error}")
        outbox.put(("error", str(error)))
        return

    total = sum(len(b.fields) for b in blocks)
    who = blocks[0].display_name if len(blocks) == 1 else f"{len(blocks)} 人"
    set_title(f"翻译中：{who}")

    names = load_names()
    try:
        outcome = translate_request(blocks, translator, cache, names)
    except TranslateError as error:
        log(f"{who} 翻译失败：{error}")
        outbox.put(("error", str(error)))
        return

    if outcome.usages:
        save_cache(cache)
        for usage in outcome.usages:
            log(f"用量：{usage}")
    else:
        log("全部命中缓存，没有调用接口。")
    if outcome.names_added:
        save_names(names)
        log(f"人名对照表新增 {outcome.names_added} 条（names.json）。")
    for (player, key), reason in outcome.failed.items():
        log(f"{short_name(player)} 的{FIELD_LABELS.get(key, key)}没翻成：{reason}")
    log(f"{who}：完成 {len(outcome.translated)}/{total} 个字段，用时 {time.monotonic() - started:.1f} 秒。")

    if outcome.translated:
        pool.add(blocks, outcome.translated)
        outbox.put(("ready", who))
    else:
        reasons = "；".join(f"{short_name(p)} 的{FIELD_LABELS.get(k, k)}（{v}）" for (p, k), v in outcome.failed.items())
        outbox.put(("error", "所有字段都没能翻译：" + reasons))


def deliver(clipboard: Clipboard, config: dict, pool: ReadyPool, kind: str, detail: str) -> None:
    """只在主线程调用：把整池译文写进剪贴板；池是空的才写报错。"""
    ok = kind != "error"
    response, people = pool.response()
    if ok and not people:
        return
    if not ok and people:
        # 不能拿报错把别人的译文顶掉：照常写回整池，没翻成的那份回游戏再点一次就行
        log("这份没翻成，先前翻好的译文照常写回剪贴板。")
    if not is_ours(clipboard.read_text()):
        log("剪贴板里是你复制的别的东西，没有覆盖。回游戏点档案上的「粘贴」，按 Ctrl+C 再发一次就能拿到。")
        beep(config, ok)
        set_title(f"有译文待取：{len(people)} 人（剪贴板被占用）" if people else "等待中 · 上次失败")
        return
    try:
        clipboard.write_text(response if people else format_error(detail))
    except ClipboardError as error:
        log(f"写回剪贴板失败：{error}")
        return
    beep(config, ok)
    if people:
        log(f"译文已写入剪贴板（{'、'.join(people)}），回游戏打开其中任意一份档案，点「粘贴」再按 Ctrl+V。")
        set_title(f"有译文待粘贴：{len(people)} 人" + ("" if ok else " · 上次失败"))
    else:
        log("错误信息已写入剪贴板。")
        set_title("等待中 · 上次失败")

def run(config: dict) -> None:
    translator = make_translator(config)
    clipboard = Clipboard()
    cache = load_cache()
    pool = ReadyPool()
    requests: queue.Queue[str] = queue.Queue()
    outbox: queue.Queue[tuple[str, str]] = queue.Queue()
    log(f"翻译接口：{translator.label}；缓存里有 {len(cache)} 条译文，人名对照表有 {len(load_names())} 条。")
    log("等待游戏里的翻译请求……（按 Ctrl+C 退出）")
    set_title("等待中")

    # 翻译放在后台线程，一次一份；主线程只管剪贴板，所以翻译期间复制的新请求不会漏掉
    def worker() -> None:
        while True:
            text = requests.get()
            try:
                handle(config, translator, cache, pool, outbox, text)
            except Exception as error:  # 写文件失败之类的意外：记下来，助手接着跑
                log(f"处理请求时出错：{error!r}")
                outbox.put(("error", "助手内部错误"))

    threading.Thread(target=worker, daemon=True).start()
    start_key_remap(config)

    last_sequence = clipboard.sequence()
    while True:
        time.sleep(0.25)
        sequence = clipboard.sequence()
        if sequence != last_sequence:
            last_sequence = sequence
            text = clipboard.read_text()
            if text and text.lstrip().startswith(HEADER_REQ):
                try:
                    blocks = parse_request(text)
                    who = "、".join(b.display_name for b in blocks)
                    fields = sum(len(b.fields) for b in blocks)
                    log(f"收到 {who} 的翻译请求（{fields} 个字段）" + (f"，前面还有 {requests.qsize()} 份在排队" if requests.qsize() else ""))
                except ProtocolError:
                    pass  # 后台线程会再解析一次并回报错误
                requests.put(text)
        while not outbox.empty():
            kind, detail = outbox.get()
            deliver(clipboard, config, pool, kind, detail)
            last_sequence = clipboard.sequence()  # 自己写回的那次不算新请求


def check(config: dict) -> None:
    translator = make_translator(config)
    sample = [Block("Elaria-ArgentDawn", "Elaria Dawnwhisper", [
        Field("CU", "0", "Sitting by the fire in {{1}}Goldshire{{2}}, waiting for Kaelen to return from Stormwind."),
    ])]
    log(f"翻译接口：{translator.label}")
    log(f"原文：{sample[0].fields[0].body}")
    names: dict[str, str] = {}
    try:
        outcome = translate_request(sample, translator, cache={}, names=names)
    except TranslateError as error:
        raise SystemExit(f"检查失败：{error}")
    for usage in outcome.usages:
        log(f"用量：{usage}")
    text = outcome.translated.get(("Elaria-ArgentDawn", "CU"))
    if text is None:
        raise SystemExit(f"检查失败：{outcome.failed.get(('Elaria-ArgentDawn', 'CU'))}")
    log(f"译文：{text}")
    if names:
        log("模型返回的人名：" + "，".join(f"{k} → {v}" for k, v in names.items()))
    log("检查通过。")


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        return dict(DEFAULT_CONFIG)
    try:
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except ValueError as error:
        raise SystemExit(f"config.json 格式有误：{error}")


def main() -> None:
    if os.name != "nt":
        raise SystemExit("目前只支持 Windows。")
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")

    parser = argparse.ArgumentParser(description="MRP 档案翻译 · 剪贴板助手")
    parser.add_argument("--check", action="store_true", help="用一小段测试文本检查 API key 和模型")
    args = parser.parse_args()

    config = load_config()
    try:
        if args.check:
            check(config)
        else:
            run(config)
    except KeyboardInterrupt:
        log("已退出。")


if __name__ == "__main__":
    main()
