# MRP 档案翻译

**简体中文** | [English](README.en.md)

把其他玩家的 [MyRolePlay](https://www.curseforge.com/wow/addons/my-role-play)（MRP）角色扮演档案翻译成简体中文显示，同时汉化 MyRolePlay 的界面。

> **状态：早期版本。** 全部逻辑已通过离线测试（用 Lua 5.1 模拟 WoW 和 MRP 环境，并在真实的 Windows 剪贴板上测试），但还没有在游戏客户端里实测，也没有调用过真实的翻译接口。遇到问题欢迎反馈。

## 为什么需要剪贴板助手

魔兽世界的插件运行在沙盒里，不能联网，也不能读写任意文件，所以单靠插件没法调用翻译服务。本项目加了一个桌面小程序，用**剪贴板**在游戏和翻译接口之间传递内容：

```
[游戏] 插件把档案原文打包，放进已全选的输入框
   │  ① 你按 Ctrl+C
   ▼
[桌面] 剪贴板助手发现请求 ── ② 调用 Gemini 或 OpenRouter 翻译
   │  ③ 把译文写回剪贴板，并响一声提示音
   ▼
[游戏] ④ 你在同一个输入框按 Ctrl+V → 档案显示中文
```

助手不碰游戏进程，也不模拟按键，两次按键都由你自己按。它只处理以 `<<MRPTR1 REQ>>` 开头的剪贴板内容，你复制的其他东西一概不读，也不会发送到任何地方。

## 功能

- **档案窗口**：翻译头衔、当前状态、场外信息、眼睛、身高、体型、外貌描述、年龄、居住地、出生地、格言、背景故事、一眼印象，以及自定义性格特质的名称。颜色、链接、图标、图片和 MRP 排版标签在翻译时会受到保护，翻译完原样还原。
- **鼠标提示和一眼印象预览框**也会显示已有的译文。
- **鼠标提示批量队列**：鼠标扫过的人会自动排进队列，一次 Ctrl+C / Ctrl+V 就能翻完一批。
- **按原文哈希缓存译文**：档案没改过，下次打开直接显示中文；对方改了哪个字段，就只需重新翻译哪个字段。
- **一键切换**原文和译文。
- **人名**第一次出现时写成「音译（原文）」，例如「艾拉莉亚（Elaria）」。魔兽世界的地名、种族、官方人物等使用国服官方译名。
- **人名对照表**（`names.json`）：让同一个名字在不同档案里的音译保持一致，你也可以手动编辑，指定想要的译法。
- **MyRolePlay 界面汉化**（约 470 条，只在中文客户端生效）。MRP 本身只有英文和法文界面。身高、体重单位会一次性改为厘米、公斤，可以在 MRP 设置里改回。
- 顺带修复了 MRP 截断鼠标提示长文本时会把汉字切成乱码的问题。

## 运行环境

- 魔兽世界，并已安装 [MyRolePlay](https://www.curseforge.com/wow/addons/my-role-play)。TOC 里列出的客户端版本与 MyRolePlay 相同。界面汉化只在中文（zhCN）客户端生效。
- Windows（助手使用 Windows 剪贴板接口）。
- Python 3.10 或更高版本（在 3.14 上开发和测试）。只用标准库，不需要 `pip install`。
- 以下任一接口的 API key：
  - **Google Gemini**（[Google AI Studio](https://aistudio.google.com/)）。默认模型：`gemini-3.8-flash`。
  - **OpenRouter**（[openrouter.ai](https://openrouter.ai/)）。默认模型：`google/gemini-3.8-flash`，也可以换成 OpenRouter 上的任何模型。

## 安装

1. 把 `MRP_Translate` 文件夹复制到 `World of Warcraft\_retail_\Interface\AddOns\`。
2. `MRP_Translate_Helper` 放在任意位置，不需要放进游戏目录。
3. 把 API key 设成环境变量，然后**新开**一个命令行窗口（`setx` 只对新窗口生效）：
   ```
   setx GEMINI_API_KEY "你的key"
   ```
   使用 OpenRouter 的话，改设 `OPENROUTER_API_KEY`，并把 `config.json` 里的 `provider` 改成 `"openrouter"`。
4. 检查 key 和模型是否可用：
   ```
   python mrptr_helper.py --check
   ```

## 使用

1. 启动助手：双击 `启动助手.bat`，或运行 `python mrptr_helper.py`。窗口标题会显示当前状态。
2. 在游戏里打开别人的 MRP 档案，点档案窗口右侧外沿的「**翻译**」。
3. 按 **Ctrl+C**（输入框里的内容已经全选好了）。
4. 等助手响提示音。
5. 回到输入框（如果按过 Esc，先点一下输入框），按 **Ctrl+V**，档案就会切换成中文。

「**原文 / 中文**」按钮可以随时切换显示，鼠标提示和一眼印象预览框会一起切换。

**批量翻译鼠标提示**：鼠标提示没法停下来按 Ctrl+C，所以扫过的人会自动排进队列，攒到 5 人时聊天框会提示一次。之后可以：

- 在「按键设置 → 插件 → MRP 档案翻译 → 翻译鼠标提示队列」里设一个快捷键，或者
- 输入 `/mrptr queue`。

然后一次 Ctrl+C / Ctrl+V 就能翻完整批。

| 命令 | 作用 |
|---|---|
| `/mrptr` | 查看缓存和队列状态 |
| `/mrptr queue` | 翻译鼠标提示队列 |
| `/mrptr clear` | 清空所有译文缓存 |

**建议**：第一次使用时，先把 `config.json` 里的 `provider` 设成 `"test"`。这样助手不调用任何接口，只在原文前加一个标记，可以免费跑通游戏里的整个流程。

## 配置

以下文件都在 `MRP_Translate_Helper/` 里。

| 文件 | 用途 |
|---|---|
| `config.json` | `provider`（`gemini`、`openrouter` 或 `test`）、模型名、`timeout_seconds`（超时秒数）、`beep`（是否响提示音）。`api_key` 也可以写在这里，但更推荐用环境变量。 |
| `prompt.txt` | 发给模型的翻译要求，可以随意修改。 |
| `names.json` | 人名对照表，自动生成。已有的条目不会被模型覆盖，你手动改过的译法会一直保留。 |
| `cache.json` | 译文缓存，自动生成，最多保留 5000 条。删掉它就会全部重新翻译。 |

## 费用

按 Gemini 3.8 Flash 的付费价格计算（每百万 token 输入 $0.75、输出 $3.75，2026 年 12 月 31 日之前有效，2027 年 1 月 1 日起翻倍），一份普通档案大约 **$0.01**。缓存过的档案不再收费。价格可能变动，以服务商的价格页面为准。

## 隐私

- **其他玩家**写的档案内容会发送给你选择的翻译服务商。
- Gemini 免费版会用提交的内容改进 Google 的产品，付费版不会。
- 助手只处理以请求标记开头的剪贴板内容，你复制的其他东西不会被读取，也不会被发送。
- **这个仓库是公开的**，千万不要把 API key 写在 `config.json` 里提交，请用环境变量。

## 项目结构

```
MRP_Translate/                 魔兽世界插件
  MRP_Translate.toc
  Locale_MRP_zhCN.lua          MyRolePlay 界面汉化（只在中文客户端生效）
  Core.lua                     协议、格式标记保护、原文哈希、缓存
  UI.lua                       按钮、复制粘贴小窗、显示挂钩、鼠标提示队列
  Bindings.xml                 鼠标提示队列的快捷键
MRP_Translate_Helper/          桌面剪贴板助手
  mrptr_helper.py
  config.json
  prompt.txt
  启动助手.bat                  双击启动
```

### 译文是怎么显示出来的

MRP 绘制档案窗口、鼠标提示、一眼印象预览框之前，插件先把这个人的字段临时换成缓存里的译文，画完立刻换回原文。这样 MRP 自己的排版、单位换算、一眼印象和性格特质的解析都照常工作，**MyRolePlay 的文件一个都不用改**。万一出错，MRP 会照常显示原文，聊天框只提示一次。

### 剪贴板协议（`MRPTR1`）

```
<<MRPTR1 REQ>>
@player 名字-服务器
@name 角色名
@field DE 0123456789abcdef
正文，格式标记已替换成 {{1}}、{{2}} …… 占位符
@player 另一个名字-服务器
……
<<MRPTR1 END>>
```

- 回包以 `<<MRPTR1 RES>>` 开头，结构相同；没翻成的字段用 `@failed 字段 原因` 标出。
- 出错时回 `<<MRPTR1 ERR>> 原因`。
- 正文里以 `@` 或 `<` 开头的行，会在前面再补一个 `@` 来转义。
- 16 位哈希对应原文的确切内容。字段被改过之后，旧译文不会再显示。

## 已知限制

- 只支持 Windows。
- 尚未在游戏客户端里实测（见开头的状态说明）。
- MyRolePlay 代码里有少数英文是直接写死的（不在它的语言表里），不改 MRP 就没法汉化。
- Haranir 等新种族的名称还没有汉化，会显示英文。

## 致谢

- [MyRolePlay](https://www.curseforge.com/wow/addons/my-role-play)，作者 Etarna Moonshyne、Katorie、Meorawr。
- Mary Sue Protocol（LibMSP）社区。

## 许可证

本项目以 [GNU 通用公共许可证第 3 版（GPLv3）](LICENSE)发布，与 MyRolePlay 一致。界面汉化文件 `Locale_MRP_zhCN.lua` 翻译自 MyRolePlay 的界面文字。
