local ADDON_NAME, ns = ...

-- ==========================================
-- MyRolePlay 界面汉化
-- ==========================================
-- MRP 自带的语言只有英文和法文，中文客户端上整个界面都是英文。MRP 的界面文字都从
-- mrp.L 取，这里直接覆盖成中文；MRP 自己的文件一个不改。
--
-- 几处 MRP 在加载时就把英文存走了（下拉框、弹窗、性格滑条名、RP 水平等名称表），
-- 覆盖 mrp.L 之后还要在文件末尾单独补一遍。
--
-- 变形自动切换档案的说明里，“Cat”“Bear”“Worgen” 等形态名必须保持英文：MRP 靠
-- 档案名与这些英文名精确匹配。

if GetLocale() ~= "zhCN" or type(mrp) ~= "table" or type(mrp.L) ~= "table" then return end

local L = mrp.L

-- 带图标的条目：保留 MRP 原来的图标（正式服和怀旧服用的不一样），只换文字
local function WithIcon(key, text)
    local old = rawget(L, key) or ""
    local prefix = old:match("^(|[TA].-|[ta])")
    if prefix then return prefix .. " " .. text end
    local suffix = old:match("(|[TA].-|[ta])$")
    if suffix then return text .. "  " .. suffix end
    return text
end

L["mrp_addon_notes"] = "创建并分享角色扮演档案。"

-- 字段格式
L["opt_displayheight_header"] = "身高显示单位…"
L["cm_format"] = "%d厘米"
L["cm_format_name"] = "厘米（170厘米）"
L["m_format"] = "%.2f米"
L["m_format_name"] = "米（1.70米）"
L["ftin_format_name"] = [[英尺和英寸（5'6"）]]
L["opt_displayweight_header"] = "体重显示单位…"
L["kg_format"] = "%d公斤"
L["kg_format_name"] = "公斤（60公斤）"
L["lb_format"] = "%d磅"
L["lb_format_name"] = "磅（132磅）"
L["stlb_format"] = "%d英石 %d磅"
L["stlb_format_name"] = "英石和磅（9英石 6磅）"
L["opt_defontsize_header"] = "外貌描述 / 背景故事字号"

-- 鼠标提示样式
L["ttstyle_0_name"] = "|cffc0c0c0暴雪默认|r"
L["ttstyle_1_name"] = "简洁（标签式）"
L["ttstyle_2_name"] = "增强（默认）"
L["ttstyle_3_name"] = "紧凑"

L["SPH"] = "选择档案："
L["RPP"] = "RP 水平："
L["FCH"] = "角色状态："

-- RP 水平
L["FR0"] = "（未设置 RP 水平）"
L["FR0t"] = "尚未设置"
L["FR0d"] = "请选择你的角色扮演水平。"

L["FR1"] = "RP 新手"
L["FR1e"] = WithIcon("FR1e", "RP 新手")
L["FR1t"] = WithIcon("FR1t", "新手")
L["FR1d"] = [[你刚接触角色扮演，或者还在摸索这个角色在魔兽世界背景中的样子。

请其他玩家对失误多多包涵。]]

L["FR2"] = "休闲 RP 玩家"
L["FR2t"] = WithIcon("FR2t", "休闲")
L["FR2d"] = [[你有一定的角色扮演经验，基本了解常见的 RP 礼仪。

|cffF1ACE9提示：拿不准选哪个的话，这是个不错的默认选项！]]

L["FR3"] = "资深 RP 玩家"
L["FR3t"] = WithIcon("FR3t", "资深")
L["FR3d"] = "你有丰富的角色扮演经验，对 RP 礼仪了如指掌。"

L["FR4"] = "新人向导"
L["FR4t"] = WithIcon("FR4t", "新人向导")
L["FR4e"] = WithIcon("FR4e", "新人向导")
L["FR4d"] = [[你愿意担任向导，帮助新玩家适应角色扮演环境。

|cffF1ACE9提示：这会在你的鼠标提示里显示一面向导旗帜，其他玩家都能看到！]]

L["FRc"] = "（自定义）"
L["FRct"] = "自定义"
L["FRcd"] = "自定义一个上面没有列出的 RP 水平。"

-- 角色状态
L["FC0"] = "（未设置状态）"
L["FC0t"] = "尚未设置"
L["FC0d"] = "请选择你当前的状态。"
L["FC1"] = "戏外"
L["FC1t"] = "戏外（OOC）"
L["FC1d"] = [[你以玩家本人而不是角色的身份发言。

你在这个状态下的言行，不应被当作角色本人的所作所为。

请记住，在 /说、/表情 或 /大喊 中
不应出现戏外或与奇幻背景无关的对话。]]

L["FC2"] = "戏内"
L["FC2t"] = "戏内（IC）"
L["FC2d"] = [[你的言行都符合角色平时的样子。

其他角色可以与你的角色互动。

|cffF1ACE9提示：如果也欢迎别人主动搭话，请选择|cff99b3cc寻求接触|r！|r]]

L["FC3"] = "寻求接触"
L["FC3t"] = WithIcon("FC3t", "寻求接触（LFC）")
L["FC3d"] = [[与“戏内”类似，但你还欢迎其他玩家主动上前搭话。

|cffF1ACE9提示：任何 RP 插件的鼠标提示里都会显示一个特殊图标，让别人知道你欢迎搭话！|r]]

L["FC4"] = "说书人"
L["FC4t"] = "说书人"
L["FC4d"] = "与“戏内”类似，但你正在主持一段故事，其他角色可以选择加入。"

L["FCc"] = "（自定义）"
L["FCct"] = "自定义"
L["FCcd"] = "自定义一个上面没有列出的角色状态。"

-- 感情状态
L["RS0"] = "未知"
L["RS0t"] = "未设置状态"
L["RS0d"] = [[如果愿意，可以选择角色的感情状态。

不想公开的话，也可以选这一项。]]
L["RS1"] = "单身"
L["RS1t"] = "单身"
L["RS1d"] = "你的角色是单身。"
L["RS2"] = "有伴"
L["RS2t"] = "恋爱中"
L["RS2d"] = "你的角色正在恋爱，但还没有结婚。"
L["RS3"] = "已婚"
L["RS3t"] = "已婚"
L["RS3d"] = "你的角色已婚。"
L["RS4"] = "离异"
L["RS4t"] = "离异"
L["RS4d"] = "你的角色曾经结过婚，现已离婚。"
L["RS5"] = "丧偶"
L["RS5t"] = "丧偶"
L["RS5d"] = "你的角色结过婚，但伴侣已经离世。"

L["level"] = "等级"

-- 字段名和编辑器提示
L["NA"] = "名字"
L["efNA"] = [[你的角色名字，按你希望的样子显示。

可以在这里加上第二个名字，或者随意修改。]]
L["NI"] = "昵称"
L["efNI"] = [[角色的昵称（如果有）。

比如朋友们平时对他/她的称呼。]]
L["NT"] = "头衔"
L["efNT"] = [[角色的头衔，显示在名字下方。

通常是一句话的描述或概括。]]
L["NH"] = "家族"
L["efNH"] = [[角色的“家族名”（如适用）；
只有少数种族会有。]]
L["RS"] = "感情状态"
L["efRS"] = [[角色的感情状态。

不想透露的话，设为“未知”即可。]]
L["PS"] = "性格特质"
L["PSsubheader"] = "点击设置特质…"
L["efPS"] = [[描述角色性格的特质。

滑条表示角色偏向某一特质的程度。

|cffff5533提示：|r大多数角色不会在每一项上
都有强烈的倾向。]]
L["AE"] = "眼睛"
L["efAE"] = "角色眼睛的颜色。"
L["RA"] = "种族"
L["efRA"] = [[角色的种族（如果与游戏中显示的不同）。

|cffff5533警告：|r不建议新手扮演稀有或奇特的种族；
在魔兽世界的背景下，要令人信服地扮演
某些种族可能颇具挑战。

留空则沿用游戏中显示的种族。]]
L["RC"] = "职业"
L["efRC"] = [[角色在戏内的职业
（如果与游戏中显示的不同）。

留空则沿用游戏中显示的职业。

|cffF1ACE9提示：这个字段要放进鼠标提示的一行里，
尽量简短！]]
L["AH"] = "身高"
L["efAH"] = [[角色有多高（或多矮）。

可以填写：
 · 具体身高：
    （以厘米为单位的数字，不带单位）；或者
 · 简短的相对描述（高、矮、中等……）]]
L["AW"] = "体型"
L["efAW"] = [[角色看起来有多重。

可以填写：
 · 具体体重：
    （以公斤为单位的数字，不带单位，例如 60.5）；或者
 · 简短的相对描述（苗条、魁梧、壮实……）]]
L["AG"] = "年龄"
L["efAG"] = [[角色的年龄。

可以填写：
 · 具体年龄：
    （以年为单位的数字，不带单位，例如 45）；或者
 · 简短描述（年轻、年老、中年……）

注意，如果填写具体年龄，
不同种族的衰老速度差别很大。
（例如 300 岁的暗夜精灵才刚刚成年……）]]
L["CU"] = "当前状态"
L["efCU"] = [[如果有人此刻瞥了你的角色一眼：
他们首先会注意到什么？

角色是开心？难过？疲惫？多疑？
手里拿着东西？浑身是血？在购物？心不在焉？

|cffF1ACE9提示：这个字段会显示在鼠标提示里，尽量简短！]]
L["CO"] = "场外信息（OOC）"
L["efCO"] = [[关于你作为玩家的相关信息，与角色无关。

常见用途包括：你多久 RP 一次、
对哪些类型的 RP 感兴趣（或不感兴趣）、角色插画等。

|cffF1ACE9提示：这个字段会显示在鼠标提示里，尽量简短！]]
L["COabb"] = "OOC"
L["PE"] = "一眼印象"
L["efPE"] = [[这些是关于你角色的*简短*笔记。

最多可以设置 5 条，每条可以配一个图标。

|cffF1ACE9提示：每条最多一段话左右，
因为它们会显示在鼠标提示里！]]
L["PN"] = "代词"
L["efPN"] = [[可以列出角色偏好的代词。
它们会同时显示在你的档案和鼠标提示中。

留空则档案和鼠标提示中都不显示这一行。]]
L["PV"] = "声音参考"
L["PVshort"] = "声音"
L["efPV"] = [[可以为角色列出一个声音参考。
这个字段会显示在鼠标提示中。

留空则档案和鼠标提示中都不显示这一行。]]
L["DE"] = "外貌描述"
L["efDE"] = [[描述角色的外貌，就像别人看到他/她时
一眼就能看到的样子。

想想文字冒险游戏或小说会怎样
描写这个角色。

请|cffff5533避免|r以下内容：
 · 讲述角色的经历；那些可以写在
   背景故事里；
 · 规定其他角色对他/她的反应
   （别的角色怎么反应，最好交给
     各自的玩家决定）；
 · 任何与外貌无关的内容；
 · 任何违反规则或服务器政策的内容。

记住，这里只写外貌描述。]]
L["HH"] = "居住地"
L["efHH"] = "角色目前居住的地方（如果有）。"
L["HB"] = "出生地"
L["efHB"] = "角色的出生地。"
L["MO"] = "格言"
L["efMO"] = [[可以是：

 · 角色的格言；
 · 他/她对人生态度的概括；或者
 · 你觉得最能代表这个角色的
   一句口头禅。]]
L["HI"] = "背景故事"
L["efHI"] = [[如果愿意，可以在这里概述角色的
经历和背景。

与其写一份完整的传记，不如只写一些
关于角色的公开信息（比如传闻）——
很多玩家更喜欢通过与你实际互动
来发现这些内容。

给他们尝一口，而不是整块馅饼！]]
L["FR"] = "RP 风格"
L["efFR"] = "你为这个角色偏好的角色扮演风格。"
L["FC"] = "角色状态"
L["efFC"] = [[你当前是戏内还是戏外，
是否寻求接触，或者正在当说书人。]]

-- 编辑器
L["editor_clicktoedit"] = "|cff4466ee点击|cffcccccc编辑。|r"
L["editor_icon_button"] = "图标"
L["editor_icon_button_tt_active"] = "当前图标：（点击更换）"
L["editor_icon_button_tt_inactive"] = "为你的档案设置一个图标。"
L["editor_music_button"] = "音乐"
L["editor_music_button_tt_active"] = "当前选中的音乐："
L["editor_music_button_tt_inactive"] = "设置角色主题音乐。"
L["profile_settings_button"] = "档案设置…"
L["editor_newprofile_button"] = "|A:communities-chat-icon-plus:16:16:0:0|a新建档案"
L["editor_newprofile_popup"] = "请输入新档案的名称："
L["editor_renameprofile_button"] = "|A:UI-HUD-MicroMenu-GuildCommunities-GuildColor-Mouseover:16:16:0:0|a重命名当前档案"
L["editor_renameprofile_popup"] = "请为这个档案输入新名称："
L["editor_deleteprofile_button"] = "|A:communities-chat-icon-minus:16:16:0:0|a|cffFF0000删除当前档案|r"
L["editor_opensettings_button"] = "|TInterface\\Buttons\\UI-OptionsButton:14:14:0:0|t打开 MRP 设置面板"
L["editor_openchangelog_button"] = "|A:Profession:16:16:-5:0|a打开更新日志"
L["editor_deleteprofile_button_default"] = "销毁你所有的档案，恢复为默认状态。"
L["editor_deleteprofile_popup"] = "确定要删除这个档案吗？其中的所有信息都会被清除。"
L["editor_deleteallprofiles_popup"] = "|cffFF0000*** 重要 ***|r\n\n|cffFF0000删除默认档案会删除你所有的档案数据！确定吗？此操作无法撤销！|r"
L["editor_settings_button"] = "更改 MRP 设置。"
L["editor_reportbug_button"] = "|TInterface\\HELPFRAME\\HelpIcon-Bug:18:18:-5:0|t报告错误"
L["editor_reportbug_button_tt"] = "显示 MyRolePlay 问题反馈页面的链接，可以在那里报告错误。"
L["editor_changelog_button"] = "查看更新日志 / 补丁说明。"
L["editor_changelog_button_tt"] = "查看 MyRolePlay 最近的更新，了解新功能和改动。"
L["editor_glance_headers"] = "标题 / 详情"
L["editor_glanceclear_button"] = "清空这条一眼印象，并把图标恢复为默认。"
L["editor_inherited_label"] = "继承自默认档案。"
L["editor_namecolour_button"] = "更改颜色"
L["editor_namecolour_button_tt"] = "更改名字的颜色。"
L["editor_eyecolour_button"] = "更改眼睛颜色"
L["editor_eyecolour_button_tt"] = "更改眼睛的颜色。"
L["editor_restorecolour_button"] = "恢复默认颜色"
L["editor_restorecolour_button_tt"] = "把颜色恢复为默认档案的颜色。"
L["editor_locationautopick_button_tt"] = "用你在游戏中的当前位置填写这个字段。"
L["editor_inherit_button"] = "继承"
L["editor_inherit_button_tt"] = "取消所有改动，使用与默认档案相同的内容。"
L["editor_insertcolour_button"] = "颜色"
L["editor_insertcolour_tt_title"] = "插入颜色代码。"
L["editor_insertcolour_tt_1"] = "用取色器选择颜色。点击“确定”后，会在输入框中光标所在的位置插入一对颜色代码。把要上色的文字放在这两个标签之间即可。"
L["editor_insertcolour_tt_2"] = "{col:ff0000}德莱尼人长着蹄子。{/col}"
L["editor_insertlink_button"] = "链接"
L["editor_insertlink_tt_title"] = "在档案中插入链接。"
L["editor_insertlink_tt_1"] = "用这个按钮插入链接模板，然后把“your.url.here”换成你要的网址，把“Your text here”换成可点击的链接文字。"
L["editor_insertlink_tt_2"] = "示例：\n{link*http://www.worldofwarcraft.com/*魔兽世界官网}"
L["editor_inserticon_button"] = "图标"
L["editor_inserticon_tt_title"] = "插入图标。"
L["editor_inserticon_tt_1"] = "用图标选择器选择图标。档案编辑器中光标所在的位置会出现一个包含该图标的链接，图标本身会显示在你的档案里。（可以点击预览按钮查看效果。）"
L["editor_insertheader_button"] = "标题"
L["editor_insertheader_tt_title"] = "插入标题。"
L["editor_insertheader_tt_1"] = "在下拉菜单中选择标题大小和对齐方式，然后把文字放在标签之间。"
L["editor_insertheader_tt_2"] = "示例：\n{h1:c}我的标题文字{/h1}"
L["editor_insertparagraph_button"] = "段落"
L["editor_insertparagraph_tt_title"] = "插入对齐的段落。"
L["editor_insertparagraph_tt_1"] = "在下拉菜单中选择对齐方式，然后把文字放在标签之间。"
L["editor_insertparagraph_tt_2"] = "示例：\n{p:c}我的段落文字{/p}"
L["editor_insertimage_button"] = "图片"
L["editor_insertimage_tt_title"] = "插入图片。"
L["editor_insertimage_tt_1"] = "用图片选择器插入图片。档案编辑器中光标所在的位置会出现一个包含该图片的链接，图片本身会显示在你的档案里。（可以用预览按钮查看效果）"
L["add_aligned_paragraph"] = "添加对齐段落…"
L["add_leftaligned_paragraph"] = "左对齐"
L["add_centrealigned_paragraph"] = "居中对齐"
L["add_rightaligned_paragraph"] = "右对齐"
L["large_headers_header"] = "大标题…"
L["medium_headers_header"] = "中标题…"
L["small_headers_header"] = "小标题…"
L["editor_formattingtools_header"] = "格式工具 - 插入…"
L["editor_previewprofile_button"] = "预览"
L["editor_previewprofile_tt_1"] = "预览你的档案。"
L["editor_previewprofile_tt_2"] = "显示所有颜色/图标/链接标签排好版之后的档案，让你看到其他玩家眼中的样子。"
L["editor_profilepreview"] = "档案预览"
L["editor_returntoeditor_button"] = "返回"
L["editor_returntoeditor_tt_1"] = "返回档案编辑器。点击保存之前，改动不会生效。"
L["editor_addpersonalitytrait"] = "添加性格特质"
L["editor_customtrait"] = "添加自定义特质"
L["editor_deletetrait"] = "删除特质。"
L["editor_mrptab_tt"] = "编辑你的角色扮演档案。"
L["editor_import_button"] = "导入"
L["editor_import_tt_title"] = "从其他插件导入 RP 档案。"
L["editor_import_tt_1_active"] = "你同时加载了另一个 RP 插件，可以从中导入这个角色的档案。\n\n警告：除了导入档案之外，-绝对不要-同时运行两个 RP 插件，否则会产生冲突和错误。"
L["editor_import_tt_2_active"] = "除了复制档案之外，同一时间只能运行一个 RP 插件。导入完成后请禁用冲突的插件。"
L["editor_import_tt_1_inactive"] = "你可以与 MyRolePlay 一起加载 TRP3 或 XRP 等兼容的 RP 插件，从中导入档案。"
L["editor_largeprofilewarningtitle"] = "档案过长警告"
L["editor_largeprofilewarningtooltip"] = "你档案的这个字段已经相当长了，超过 %d 个字符。\n\n可以超出这个长度，但请记住这个字段是为了放进鼠标提示而设计的。"

-- 图标 / 音乐 / 图片选择器
L["editor_search"] = "搜索"
L["editor_matches"] = " 个结果"
L["editor_play"] = "播放"
L["editor_stop"] = "停止"
L["editor_clearicon"] = "清除"
L["editor_clearmusic"] = "清除音乐"

L["save_button"] = "保存"
L["save_button_tt"] = "把你所做的改动保存到档案。"
L["cancel_button"] = "取消"
L["cancel_button_tt"] = "取消所有改动，恢复原样。"

-- MRP 按钮
L["button_unlocked"] = "MRP 按钮已解锁，现在可以随意拖动。再次右键点击可锁定位置。"
L["button_locked"] = "MRP 按钮已锁定位置。"
L["button_click_to_show"] = "|cffaabbcc左键点击|r显示角色扮演档案。"
L["button_rightclick_to_lock"] = "|cffaabbcc右键点击|r把这个按钮锁定在原位。"
L["button_rightclick_to_unlock"] = "|cffaabbcc右键点击|r解锁这个按钮，以便移动。"

-- 内置性格特质
L["lefttrait1"] = "混乱"
L["righttrait1"] = "守序"
L["lefttrait2"] = "贞洁"
L["righttrait2"] = "好色"
L["lefttrait3"] = "宽容"
L["righttrait3"] = "记仇"
L["lefttrait4"] = "无私"
L["righttrait4"] = "自私"
L["lefttrait5"] = "诚实"
L["righttrait5"] = "狡诈"
L["lefttrait6"] = "温和"
L["righttrait6"] = "残暴"
L["lefttrait7"] = "迷信"
L["righttrait7"] = "理性"
L["lefttrait8"] = "叛逆"
L["righttrait8"] = "楷模"
L["lefttrait9"] = "谨慎"
L["righttrait9"] = "冲动"
L["lefttrait10"] = "苦修"
L["righttrait10"] = "享乐"
L["lefttrait11"] = "英勇"
L["righttrait11"] = "懦弱"

-- 档案窗口
L["browser_playmusic_button"] = "点击播放角色主题音乐："
L["browser_notesnone_button"] = "为这个档案添加笔记"
L["browser_notespresent_button"] = "这个档案的笔记："
L["browser_loading_nonewdata"] = "没有变化。"
L["browser_loading_inprogress"] = "|cFFFFFF00档案加载中："
L["browser_loading_complete"] = "|cFF33FF11加载完成。"
L["browser_loading_error"] = "|cFFFF0000传输错误。"
L["browser_tab1"] = "外貌"
L["browser_tab1_tt"] = "角色外貌的描述。"
L["browser_tab2"] = "性格"
L["browser_tab2_tt"] = "角色的性格特质。"
L["browser_tab3"] = "传记"
L["browser_tab3_tt"] = "传记和背景信息。"

-- 命令用法（命令本身保持英文，游戏只认这些）
L["commandusage"] = [[用法：|cff99ffff/mrp|r |cffaaaa00<命令>|r
可用命令：
	|cff99ffffc / curr / currently|r |cffaaaa00<当前状态文字>|r - 更新“当前状态”字段。
    |cff99ffffshow|r - 显示目标的 RP 档案（如果有）
    |cff99ffffshow|r |cffaaaa00<角色名>|r - 显示某人的 RP 档案（如果有）
    |cff99ffffbrowser reset|r - 把档案窗口恢复为默认大小和位置
    |cff99ffffprofile|r |cffaaaa00<档案名>|r - 切换到另一个档案（按名称）
    |cff99ffffedit|r - 打开档案编辑器
    |cff99ffffoptions|r - 打开设置面板
    |cff99ffffbutton on|r/|cff99ffffoff|r - 在目标头像旁显示/隐藏“MRP”按钮，用来浏览对方的 RP 档案
    |cff99ffffbutton reset|r - 把 MRP 按钮恢复到目标头像旁的默认位置
    |cff99fffftooltip on|r/|cff99ffffoff|r - 是否让 MRP 增强玩家鼠标提示，显示档案信息
    |cff99ffffenable|r/|cff99ffffdisable|r - 完全启用/禁用 MyRolePlay
    |cff99ffffversion|r - 显示版本信息]]

-- 设置面板
L["opt_basicfunctionality_header"] = "基本功能"
L["opt_chatsettings_header"] = "聊天设置"
L["opt_rpnamesinchat_header"] = "在以下频道显示 RP 名字…"
L["opt_enable"] = "启用"
L["opt_enable_tt"] = "完全开启或关闭 MyRolePlay。"
L["opt_tooltipdesign_header"] = "鼠标提示设置"
L["opt_maxtooltiplines_header"] = "鼠标提示最大行数"
L["opt_tooltipstyle_header"] = "鼠标提示样式："
L["opt_headercolour_label"] = "    设置标题颜色"
L["opt_headercolour_popup"] = "|cffFFDD33MyRolePlay\n|cffFFFFFF更改标题颜色后，需要重载界面才能生效。"
L["opt_tt"] = "增强鼠标提示"
L["opt_tt_tt"] = [[在玩家鼠标提示中加入角色扮演信息。

很实用，但如果你不喜欢这种样式，
或者它与其他修改玩家鼠标提示的插件冲突，
可以关闭。]]
L["opt_mrpbutton"] = "显示 MRP 按钮"
L["opt_mrpbutton_tt"] = [[选中装有兼容插件的玩家时，在目标头像旁显示一个“MRP”按钮。

左键点击浏览角色档案。
右键点击锁定/解锁，以便把它拖到别处。]]
L["opt_allowcolours"] = "启用颜色"
L["opt_allowcolours_tt"] = "在整个插件中|cffff8040完全|r启用或禁用颜色。"
L["opt_tooltipclasscolours"] = "自定义职业颜色（鼠标提示 / 聊天）"
L["opt_tooltipclasscolours_tt"] = [[启用后，在鼠标提示和聊天名字中显示玩家自选的职业颜色。

禁用则显示游戏默认的职业颜色。]]
L["opt_increasecolourcontrast"] = "提高颜色对比度"
L["opt_increasecolourcontrast_tt"] = [[在鼠标提示 / 聊天框中提亮较暗的名字和职业颜色。

颜色会不那么准确，但更容易看清。]]
L["opt_showglancepreview"] = "显示一眼印象预览框"
L["opt_showglancepreview_tt"] = "如果玩家设置了一眼印象，显示一个预览框。"
L["opt_profilevieweresc"] = "按 ESC 关闭档案"
L["opt_profilevieweresc_tt"] = "按 ESC 键时关闭档案窗口。"
L["opt_showintooltip_header"] = "在鼠标提示中显示…"
L["opt_classnames"] = "自定义 RP 职业"
L["opt_classnames_tt"] = [[显示其他玩家设置的自定义职业名，而不是游戏中的职业。

禁用则恢复显示游戏中的职业名。]]
L["opt_showooc"] = "场外信息（OOC）"
L["opt_showooc_tt"] = [[在玩家鼠标提示中显示场外 / 其他信息字段。

注意这会让鼠标提示明显变大。禁用即可隐藏。]]
L["opt_showtarget"] = "目标"
L["opt_showtarget_tt"] = "在鼠标提示中显示你指向的玩家当前的目标。"
L["opt_hidettinencounters"] = "战斗中隐藏"
L["opt_hidettinencounters_tt"] = "战斗中隐藏 MRP 增强鼠标提示。"
L["opt_showlegacylevel"] = "旧式等级显示"
L["opt_showlegacylevel_tt"] = "像旧版本那样，把等级显示在种族 / 职业那一行。"
L["opt_showpronouns"] = "代词"
L["opt_showpronouns_tt"] = "在鼠标提示中显示角色偏好的代词。"
L["opt_showvoicereference"] = "声音参考"
L["opt_showvoicereference_tt"] = "在鼠标提示中显示角色的声音参考。"
L["opt_showiconintt"] = "图标"
L["opt_showiconintt_tt"] = "在鼠标提示中显示玩家自选的图标。"
L["opt_autoplaymusic"] = "自动播放档案音乐"
L["opt_autoplaymusic_tt"] = "自动播放玩家档案中的音乐。"
L["opt_showversion"] = "RP 插件 / 目标行"
L["opt_showversion_tt"] = "在鼠标提示中显示你指向的玩家所用的 RP 插件。"
L["opt_showfullversiontext"] = "完整版本信息"
L["opt_showfullversiontext_tt"] = "在插件名称后显示完整的版本号。"
L["opt_showguildnames"] = "公会会阶"
L["opt_showguildnames_tt"] = "在鼠标提示的公会名旁显示公会会阶。"
L["opt_maxlinesslider"] = "鼠标提示行数"
L["opt_maxlinesslider_tt"] = "当前状态 / 场外信息部分显示的行数。"

local CHAT_NAME_NOTE = "\n\n注意：开启此选项后，偶尔可能无法通过右键点击聊天框中的名字来选中玩家。如果出现这种情况，试着关闭再重新开启这个选项，或者 /reload。"
L["opt_rpchatnamesay"] = "|cffffffff/说|r"
L["opt_rpchatnamesay_tt"] = "在 /说 中显示 RP 名字（如果已知）。" .. CHAT_NAME_NOTE
L["opt_rpchatnamewhisper"] = "|cffff80ff/密语|r"
L["opt_rpchatnamewhisper_tt"] = "在 /密语 中显示 RP 名字（如果已知）。" .. CHAT_NAME_NOTE
L["opt_rpchatnameemote"] = "|cffff8040/表情|r"
L["opt_rpchatnameemote_tt"] = "在 /表情 中显示 RP 名字（如果已知）。" .. CHAT_NAME_NOTE
L["opt_rpchatnameyell"] = "|cffff4040/大喊|r"
L["opt_rpchatnameyell_tt"] = "在 /大喊 中显示 RP 名字（如果已知）。" .. CHAT_NAME_NOTE
L["opt_rpchatnameparty"] = "|cffaaaaff/小队|r"
L["opt_rpchatnameparty_tt"] = "在 /小队 中显示 RP 名字（如果已知）。" .. CHAT_NAME_NOTE
L["opt_rpchatnameraid"] = "|cffff7f00/团队|r"
L["opt_rpchatnameraid_tt"] = "在 /团队 中显示 RP 名字（如果已知）。" .. CHAT_NAME_NOTE
L["opt_rpchatnameguild"] = "|cff40fb40/公会 + /官员|r"
L["opt_rpchatnameguild_tt"] = "在 /公会 和 /官员 中显示 RP 名字（如果已知）。"

local CHAT_ADDON_NOTE = "\n\n|cffff8040注意：检测到 ElvUI、Prat、Listener 等可能冲突的聊天插件时，此功能会自动禁用。|r"
L["opt_highlightemotes"] = "高亮聊天中的 |cffff8040*动作*|r|r"
L["opt_highlightemotes_tt"] = "高亮聊天频道中用 |cffff8040*动作*|r 包起来的动作描写。" .. CHAT_ADDON_NOTE
L["opt_highlightooc"] = "高亮聊天中的 |cffaaaaaa((OOC))|r|r"
L["opt_highlightooc_tt"] = "高亮聊天频道中用 |cffaaaaaa((OOC))|r 包起来的场外发言。" .. CHAT_ADDON_NOTE
L["opt_showiconsinchat"] = "在聊天中显示图标"
L["opt_showiconsinchat_tt"] = "在聊天框中玩家名字旁显示其自选的图标。"

L["opt_disp_header"] = "档案显示"
L["opt_biog"] = "显示传记标签页"
L["opt_biog_tt"] = [[在档案窗口中显示还是隐藏“传记”标签页。

喜欢多看信息就启用。
喜欢通过互动去发现角色背景就禁用。]]
L["opt_traits"] = "显示性格标签页"
L["opt_traits_tt"] = "在档案窗口中显示还是隐藏“性格”标签页。"
L["opt_glanceposition_header"] = "一眼印象显示在…"
L["glance_position_right"] = "右侧"
L["glance_position_left"] = "左侧"
L["opt_ahunit"] = "身高显示单位…"
L["opt_awunit"] = "体重显示单位…"
L["opt_ac_header"] = "在以下情况自动切换档案…"

-- 变形自动切换档案。引号里的形态名必须保持英文。
L["opt_formac"] = "变形"
L["opt_formac_tt"] = "变换形态时自动切换到另一个档案。\n"
L["opt_formac_tt_disabled"] = L["opt_formac_tt"] .. "（这个角色没有可用的形态变化，所以此选项不起作用。）"
L["opt_formac_tt_enabled1"] = L["opt_formac_tt"] .. "\n按以下名称命名档案（名称必须完全一致，保持英文）：\n"
L["opt_formac_tt_suffix"] = [[  （|cffff9090不要|r带引号；档案名|cffff9090区分大小写|r！）

变回原来的形态时，会切换回原来的档案。

非默认档案请用“|cffffff00档案名:形态|r”，例如：
· 选中“|cffffff00Tuxedo|r” -> 变成狼人 -> 尝试自动切换到“|cffffff00Tuxedo:Worgen|r”
   （……不含裁缝修理费。效果因人而异™。）
]]
L["opt_formac_tt_worgensuffix"] = [[

|cffffa0a0注意：|r可惜人类/狼人形态的检测并不完美（暴雪的疏漏）。
施放狼人技能（|cff80c0c0Darkflight|r、|cff80c0c0Running Wild|r）或|cff80c0c0进入战斗|r可以尝试修正。]]

local WORGEN_LINE = "· “|cffffff00Worgen|r”或“|cffffff00Human|r”二选一；\n   （……设置你认为不是“默认”的那个形态即可，只需要一个）\n"
local DRUID_LINES = [[· “|cffffff00Cat|r”（猎豹形态）；
· “|cffffff00Bear|r”（熊形态）；
· “|cffffff00Travel|r”（或“|cffffff00Cheetah|r”，旅行形态）；
· “|cffffff00Flight|r”（或“|cffffff00Bird|r”，飞行形态）；
· “|cffffff00Aquatic|r”（或“|cffffff00Seal|r”、“|cffffff00Sealion|r”，水栖形态）；
· “|cffffff00Moonkin|r”（或“|cffffff00Owlkin|r”，枭兽形态，如适用）；以及
· “|cffffff00Tree|r”（树形态，如适用）。
]]
local SHAMAN_LINE = "· “|cffffff00Ghost Wolf|r”（或简写“|cffffff00Wolf|r”，幽魂之狼）。\n"
local SHADOW_LINE = "· “|cffffff00Shadow|r”（暗影形态）。\n"
local DEMON_LINE = "· “|cffffff00Demon|r”（恶魔形态，取决于你的专精）。\n"

L["opt_formac_tt_worgen"] = L["opt_formac_tt_enabled1"] .. WORGEN_LINE .. L["opt_formac_tt_suffix"] .. L["opt_formac_tt_worgensuffix"]
L["opt_formac_tt_worgendruid"] = L["opt_formac_tt_enabled1"] .. WORGEN_LINE .. DRUID_LINES .. L["opt_formac_tt_suffix"] .. L["opt_formac_tt_worgensuffix"]
L["opt_formac_tt_druid"] = L["opt_formac_tt_enabled1"] .. DRUID_LINES .. L["opt_formac_tt_suffix"]
L["opt_formac_tt_shaman"] = L["opt_formac_tt_enabled1"] .. SHAMAN_LINE .. L["opt_formac_tt_suffix"]
-- MRP 用到了这一条却没定义，英文界面下会直接显示键名
L["opt_formac_tt_worgenshaman"] = L["opt_formac_tt_enabled1"] .. WORGEN_LINE .. SHAMAN_LINE .. L["opt_formac_tt_suffix"] .. L["opt_formac_tt_worgensuffix"]
L["opt_formac_tt_priest"] = L["opt_formac_tt_enabled1"] .. SHADOW_LINE .. L["opt_formac_tt_suffix"]
L["opt_formac_tt_worgenpriest"] = L["opt_formac_tt_enabled1"] .. WORGEN_LINE .. SHADOW_LINE .. [[（注意：你可能还需要“|cffffff00Shadow:Human|r”和/或“|cffffff00Shadow:Worgen|r”
            （或者反过来），因为你可以同时处于暗影形态
            和人类/狼人形态……）
]] .. L["opt_formac_tt_suffix"] .. L["opt_formac_tt_worgensuffix"]
L["opt_formac_tt_warlock"] = L["opt_formac_tt_enabled1"] .. DEMON_LINE .. L["opt_formac_tt_suffix"]
L["opt_formac_tt_worgenwarlock"] = L["opt_formac_tt_enabled1"] .. WORGEN_LINE .. DEMON_LINE .. L["opt_formac_tt_suffix"] .. L["opt_formac_tt_worgensuffix"]

L["opt_equipac"] = "更换装备方案"
L["opt_equipac_tt"] = [[更换装备方案时自动切换到另一个档案。

用装备方案的名字命名档案（|cffff9090区分大小写|r）。

很适合在不同的 RP 服装之间切换描述。]]

-- 种族（UnitRace 的第二个返回值）和职业
L["Human"] = "人类"
L["Orc"] = "兽人"
L["Dwarf"] = "矮人"
L["NightElf"] = "暗夜精灵"
L["Scourge"] = "亡灵"
L["Tauren"] = "牛头人"
L["Gnome"] = "侏儒"
L["Troll"] = "巨魔"
L["Goblin"] = "地精"
L["BloodElf"] = "血精灵"
L["Draenei"] = "德莱尼"
L["Worgen"] = "狼人"
L["Pandaren"] = "熊猫人"
L["Nightborne"] = "夜之子"
L["HighmountainTauren"] = "至高岭牛头人"
L["VoidElf"] = "虚空精灵"
L["LightforgedDraenei"] = "光铸德莱尼"
L["ZandalariTroll"] = "赞达拉巨魔"
L["KulTiran"] = "库尔提拉斯人"
L["DarkIronDwarf"] = "黑铁矮人"
L["Vulpera"] = "狐人"
L["MagharOrc"] = "玛格汉兽人"
L["Mechagnome"] = "机械侏儒"
L["Dracthyr"] = "龙希尔"
L["EarthenDwarf"] = "土灵"

L["MAGE"] = "法师"
L["WARRIOR"] = "战士"
L["PALADIN"] = "圣骑士"
L["HUNTER"] = "猎人"
L["ROGUE"] = "潜行者"
L["PRIEST"] = "牧师"
L["DEATHKNIGHT"] = "死亡骑士"
L["DEMONHUNTER"] = "恶魔猎手"
L["EVOKER"] = "唤魔师"
L["SHAMAN"] = "萨满祭司"
L["WARLOCK"] = "术士"
L["MONK"] = "武僧"
L["DRUID"] = "德鲁伊"

L["CLIENT_UNSUPPORTED_WARNING_TEXT"] = "你正在 |cffff0000*%2$s*|r 版魔兽世界客户端上运行 MyRolePlay |cffffcc00*%1$s*|r。|n|n请从 CurseForge 或 WoWInterface 下载并安装对应的版本。"
L["CLIENT_TYPE_CLASSIC"] = "怀旧服"
L["CLIENT_TYPE_MAINLINE"] = "正式服"

-- MRP 代码里直接拿英文原句当键名的条目
L[" |cff994d4d<Busy>|r"] = " |cff994d4d<忙碌>|r"
L[" |cff994d4d<DND>|r"] = " |cff994d4d<勿扰>|r"
L[" |cffff9933<AFK>|r"] = " |cffff9933<暂离>|r"
L[" |cffff9933<Away>|r"] = " |cffff9933<离开>|r"
L["%s created by |cffffc1fbEtarna Moonshyne|r. Currently developed by |cffffc1fbKatorie|r."] = "%s 由 |cffffc1fbEtarna Moonshyne|r 创建，目前由 |cffffc1fbKatorie|r 开发。"
L["%s doesn’t have a roleplay addon installed."] = "%s 没有安装角色扮演插件。"
L["%s field cleared."] = "已清空字段：%s。"
L["%s of <%s>"] = "<%2$s> %1$s"
L["%s: Flagged as %s."] = "%s：已设为 %s。"
L["(Boss)"] = "（首领）"
L["|cffffffff(Boss)"] = "|cffffffff（首领）"
L["<Out of Phase / Shard>"] = "<不在同一相位 / 位面>"
L["<Trial Account>"] = "<试玩账号>"
L["Browse Character Profile"] = "浏览角色档案"
L["Call /run mrp:HardReset(true) to delete ALL YOUR MRP PROFILES AND SETTINGS!"] = "输入 /run mrp:HardReset(true) 可删除你所有的 MRP 档案和设置！"
L["Changes may not be visible for other users until they next disconnect or reload."] = "其他玩家可能要在下次断线重连或重载界面后才能看到改动。"
L["Class colour"] = "职业颜色"
L["Current profile is: %s"] = "当前档案：%s"
L["Disabling %s"] = "正在禁用 %s"
L["Enabling %s"] = "正在启用 %s"
L["Edit your roleplaying profiles."] = "编辑你的角色扮演档案。"
L["Hard reset! All profiles wiped, all settings returned to default."] = "已彻底重置！所有档案已清除，所有设置已恢复默认。"
L["I’m sorry, I haven’t a clue what you mean. Try |cff90ffff/mrp help|r for valid commands."] = "抱歉，看不懂这个命令。输入 |cff90ffff/mrp help|r 查看可用命令。"
L["Large Profile Warning"] = "档案过长警告"
L["MRP browser rescued; automatically reset to default size & position as it was offscreen. Try /mrp browser reset if this persists."] = "MRP 档案窗口跑到了屏幕外，已自动恢复为默认大小和位置。如果反复出现，请输入 /mrp browser reset。"
L["MRP browser reset to default size & position."] = "MRP 档案窗口已恢复为默认大小和位置。"
L["MRP button position reset to default."] = "MRP 按钮已恢复到默认位置。"
L["MRP glance frame rescued; automatically reset to default position as it was offscreen."] = "MRP 一眼印象框跑到了屏幕外，已自动恢复到默认位置。"
L["MRP will enhance player tooltips."] = "MRP 将增强玩家鼠标提示。"
L["MRP will no longer handle player tooltips."] = "MRP 不再接管玩家鼠标提示。"
L["MRP will no longer show a button near the target frame for players with an RP profile."] = "MRP 不再在目标头像旁为有 RP 档案的玩家显示按钮。"
L["MRP will show a button near the target frame for players with an RP profile."] = "MRP 将在目标头像旁为有 RP 档案的玩家显示按钮。"
L["MyRolePlay Contributor"] = "MyRolePlay 贡献者"
L["MyRolePlay Developer"] = "MyRolePlay 开发者"
L["Player selected (default)"] = "玩家自选（默认）"
L["PvP status / faction"] = "PvP 状态 / 阵营"
L["Requesting details from %s."] = "正在向 %s 请求档案。"
L["Sending request, please wait…"] = "正在发送请求，请稍候…"
L["Switching profile to: %s"] = "切换档案：%s"
L["There’s no profile called %s."] = "没有名为 %s 的档案。"
L["This profile has music available. Click to play."] = "这个档案有背景音乐，点击播放。"
L["Tooltip name colour:"] = "鼠标提示中名字的颜色："
L["Tooltip style changed to %s."] = "鼠标提示样式已改为 %s。"
L["Usage: /mrp button toggle/on/off/reset"] = "用法：/mrp button toggle/on/off/reset"
L["Usage: /mrp profile <profilename>"] = "用法：/mrp profile <档案名>"
L["Usage: /mrp show (<charactername>)"] = "用法：/mrp show (<角色名>)"
L["Usage: /mrp tooltip toggle/on/off"] = "用法：/mrp tooltip toggle/on/off"
L["Who do I show?"] = "要显示谁的档案？"
L["You can’t rename the default profile!"] = "不能重命名默认档案！"
L["Your version of MyRolePlay is extremely out of date, and may cause compatibility issues. |cffc878e0%s|r is the current version. You are running |cffc878e0%s|r. Please update to ensure the best experience."] = "你的 MyRolePlay 版本已严重过时，可能导致兼容问题。最新版本是 |cffc878e0%s|r，你正在使用 |cffc878e0%s|r。请更新以获得最佳体验。"
L["|cff78c8ffHey! Listen! Your version of MyRolePlay is out of date. Update soon to version|r %s |cff78c8ffvia CurseForge, Wago or WoWInterface!|r"] = "|cff78c8ff嘿！听我说！你的 MyRolePlay 已经过时了，请尽快通过 CurseForge、Wago 或 WoWInterface 更新到|r %s |cff78c8ff版本！|r"

-- ------------------------------------------
-- 补上 MRP 加载时就存走的英文
-- ------------------------------------------

-- 内置性格滑条的两端名称
if type(mrp.DEFAULT_TRAITS_MAPPING) == "table" then
    for i, trait in pairs(mrp.DEFAULT_TRAITS_MAPPING) do
        if type(trait) == "table" and rawget(L, "lefttrait" .. i) then
            trait.LT = L["lefttrait" .. i]
            trait.RT = L["righttrait" .. i]
        end
    end
end

-- 档案编辑器里 RP 水平 / 角色状态 / 感情状态的下拉框
local combos = mrp.comboboxfields
if type(combos) == "table" then
    for _, entry in ipairs(combos.FR or {}) do
        local v = entry.value
        if v then
            entry.text = (v == 0 and L["FR0"]) or (v == 4 and L["FR4e"]) or L["FR" .. v .. "t"]
            entry.tooltipTitle = L["FR" .. v .. "t"]
            entry.tooltipText = L["FR" .. v .. "d"]
        end
    end
    for _, entry in ipairs(combos.FC or {}) do
        local v = entry.value
        if v then
            local icon = type(entry.text) == "string" and entry.text:match("^(|T.-|t)") or ""
            entry.text = icon .. L["FC" .. v]
            entry.tooltipTitle = L["FC" .. v .. "t"]
            entry.tooltipText = L["FC" .. v .. "d"]
        end
    end
    for _, entry in ipairs(combos.RS or {}) do
        local v = entry.value
        if v then
            entry.text = L["RS" .. v]
            entry.tooltipTitle = L["RS" .. v .. "t"]
            entry.tooltipText = L["RS" .. v .. "d"]
        end
    end
end

-- 设置面板里的下拉框
local optionCombos = mrp.optionscomboboxfields
if type(optionCombos) == "table" then
    local keys = {
        glanceposition = { "glance_position_right", "glance_position_left" },
        ahunit = { "cm_format_name", "m_format_name", "ftin_format_name" },
        awunit = { "kg_format_name", "lb_format_name", "stlb_format_name" },
        ttstyle = { "ttstyle_0_name", "ttstyle_1_name", "ttstyle_2_name", "ttstyle_3_name" },
        ttnamecolour = { "Player selected (default)", "PvP status / faction", "Class colour" },
    }
    for name, list in pairs(keys) do
        for i, entry in ipairs(optionCombos[name] or {}) do
            if list[i] then entry.text = L[list[i]] end
        end
    end
end

-- 确认弹窗
local popups = {
    MRP_DELETE_PROFILE = L["editor_deleteprofile_popup"],
    MRP_CLEAR_PROFILE = L["editor_deleteallprofiles_popup"],
    MRP_NEW_PROFILE = L["editor_newprofile_popup"],
    MRP_RENAME_PROFILE = L["editor_renameprofile_popup"],
    MRP_CUSTOM_RP_STATUS = "输入自定义的角色状态",
    MRP_CUSTOM_RP_STYLE = "输入自定义的 RP 水平",
    MRP_IMPORT_PROFILE = "检测到另一个 RP 插件。要把这个角色在那边的档案复制到 MRP 的新档案里吗？",
    MRP_GLANCE_PREVIEW_HIDDEN = "|cffFFDD33MyRolePlay\n|cffFFFFFF一眼印象预览框已隐藏。随时可以在 MRP 设置面板里重新打开。|r",
}
for name, text in pairs(popups) do
    if StaticPopupDialogs[name] then StaticPopupDialogs[name].text = text end
end
if StaticPopupDialogs.MRP_IMPORT_PROFILE then
    StaticPopupDialogs.MRP_IMPORT_PROFILE.button1 = YES
    StaticPopupDialogs.MRP_IMPORT_PROFILE.button2 = NO
end

-- 快捷键设置里的名称
BINDING_HEADER_MYROLEPLAY = L["MyRolePlay"]
BINDING_NAME_CHARACTER_SHEET = L["Browse Character Profile"]

-- RP 水平 / 角色状态 / 感情状态的显示名称：MRP 在加载时把它们存进了自己文件里的局部表，
-- 改不到，只能把用到这些表的三个显示函数换掉。
if type(mrp.Display) == "table" then
    for _, spec in ipairs({ { key = "FR", max = 4 }, { key = "FC", max = 4 }, { key = "RS", max = 5 } }) do
        local original = mrp.Display[spec.key]
        if type(original) == "function" then
            local names = {}
            for i = 0, spec.max do
                names[tostring(i)] = L[spec.key .. i]
            end
            mrp.Display[spec.key] = function(contents)
                if contents == nil or contents == "" then return names["0"] end
                return names[contents] or original(contents)
            end
            -- 已经按旧函数生成的缓存清掉，下次用到时按新函数重新生成
            for _, tbl in ipairs({ mrp.DisplayBrowser, mrp.DisplayTooltip, mrp.DisplayChat }) do
                if type(tbl) == "table" then rawset(tbl, spec.key, nil) end
            end
        end
    end
end

-- 默认单位改成公制。已有的设置在 UI.lua 里按需改一次，这里只管以后“恢复默认”时的值。
if type(mrp.DefaultOptions) == "table" then
    mrp.DefaultOptions.HeightUnit = 0
    mrp.DefaultOptions.WeightUnit = 0
end
