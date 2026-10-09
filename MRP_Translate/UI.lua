local ADDON_NAME, ns = ...

-- ==========================================
-- 界面：显示译文、档案窗口上的按钮、复制粘贴小窗、鼠标提示批量队列
-- ==========================================
-- 显示译文的办法：MRP 每次画档案窗口、鼠标提示、一眼印象预览框之前，把这个人的字段
-- 临时换成译文，画完立刻换回原文。MRP 自己的排版、单位换算、截断、一眼印象和性格
-- 滑条的解析因此全部照常工作，不用一个个控件去覆盖。MRP 的文件一行不改。

local gsub, match = string.gsub, string.match

local PREFIX = "|cffffc1fb[MRP翻译]|r "
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

local warned = false
local function Warn(err)
    if warned then return end
    warned = true
    Print("出错了，翻译功能可能和当前版本的 MRP 不兼容：" .. tostring(err))
end

local function Showing()
    return MRPTR_DB and MRPTR_DB.showTranslated ~= false
end

-- 统一成 msp 用的“名字-服务器”，免得同一个人在缓存里出现两份。
-- NameMergedRealm 遇到不合规的输入会直接报错，这里出错就当没有玩家，交给 MRP 自己处理。
local function Key(player)
    if type(player) ~= "string" or player == "" then return nil end
    if AddOn_Chomp and AddOn_Chomp.NameMergedRealm then
        local ok, merged = pcall(AddOn_Chomp.NameMergedRealm, player)
        return ok and merged or nil
    end
    return player
end

local function IsSelf(player)
    return player == Key(UnitName("player"))
end

local function FieldTable(player)
    if not player or type(msp) ~= "table" or not msp.char then return nil end
    return msp.char[player].field
end

local function CurrentOriginal(player, key)
    local fields = FieldTable(player)
    return fields and rawget(fields, key)
end

local function Labels(keys)
    local out = {}
    for i, key in ipairs(keys) do
        out[i] = ns.FIELD_LABELS[key] or key
    end
    return table.concat(out, "、")
end

local function Short(player)
    return Ambiguate(player, "short")
end

-- 还没翻译的字段，以及已有有效译文的字段数。只能在字段没被换成译文时调用。
local function Scan(player, keys)
    local pending, done = {}, 0
    local fields = FieldTable(player)
    if not fields or IsSelf(player) then return pending, done end
    for _, key in ipairs(keys or ns.FIELDS) do
        local original = rawget(fields, key)
        if ns.GetTranslation(player, key, original) then
            done = done + 1
        elseif ns.NeedsTranslation(key, original) then
            pending[#pending + 1] = key
        end
    end
    return pending, done
end

-- 按过 Ctrl+C 发给助手、译文还没粘贴回来的档案。player 要先过 Key()。
local function Sent(player)
    local job = player and MRPTR_DB.jobs[player]
    return job and job.sent and type(job.fields) == "table" and next(job.fields) ~= nil
end

local function CleanName(name)
    if not name or name == "" then return nil end
    name = gsub(name, "|+c%x%x%x%x%x%x%x%x", "")
    name = gsub(name, "|+r", "")
    name = gsub(name, "|", "")
    name = match(name, "^[ \t\n]*(.-)[ \t\n]*$")
    return name ~= "" and name or nil
end

-- ------------------------------------------
-- 临时把字段换成译文
-- ------------------------------------------

local swapped = {} -- 正被换成译文的玩家；MRP 的函数会互相调用，同一个人不重复换

local function pack(...)
    return { n = select("#", ...), ... }
end

-- 先把要换的都算好，再一口气赋值：中途出错也不会留下换了一半的字段
local function SwapIn(player, keys)
    if not player or swapped[player] or not Showing() or IsSelf(player) then return nil end
    local fields = FieldTable(player)
    if not fields then return nil end

    local originals, translations
    for _, key in ipairs(keys) do
        local original = rawget(fields, key)
        local translated = ns.GetTranslation(player, key, original)
        if translated then
            originals = originals or {}
            translations = translations or {}
            originals[key] = original
            translations[key] = translated
        end
    end
    if not originals then return nil end

    for key, translated in pairs(translations) do
        fields[key] = translated
    end
    swapped[player] = true
    return originals
end

local function SwapOut(player, originals)
    local fields = FieldTable(player)
    for key, original in pairs(originals) do
        fields[key] = original
    end
    swapped[player] = nil
end

local function CallTranslated(player, keys, fn, ...)
    local ok, originals = pcall(SwapIn, player, keys)
    if not ok then
        Warn(originals)
        originals = nil
    end
    if not originals then return fn(...) end

    local result = pack(pcall(fn, ...))
    SwapOut(player, originals)
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
end

-- 把 mrp[name] 换成：先把 keys 里的字段换成译文 → 调原函数 → 换回 → 再跑 after。
-- 只换这个函数用得到的字段：鼠标提示刷新得很勤，没必要每次核对外貌描述、背景故事。
local function WrapMRP(name, playerOf, keys, after)
    local original = mrp[name]
    if type(original) ~= "function" then return false end
    mrp[name] = function(self, ...)
        local player = Key(playerOf(...))
        local result = pack(CallTranslated(player, keys, original, self, ...))
        if after then
            local ok, err = pcall(after, player)
            if not ok then Warn(err) end
        end
        return unpack(result, 1, result.n)
    end
    return true
end

-- MRP 截断鼠标提示里的长字段时按字节截，中文会被切成乱码；给它的显示函数套一层修补
local function FixDisplayTable(tbl)
    if type(tbl) ~= "table" then return end
    local function wrap(fn)
        return function(...)
            local text = fn(...)
            if type(text) == "string" then return ns.FixUtf8(text) end
            return text
        end
    end
    for key, fn in pairs(tbl) do
        if type(fn) == "function" then tbl[key] = wrap(fn) end
    end
    local meta = getmetatable(tbl)
    local index = meta and meta.__index
    if type(index) == "function" then
        meta.__index = function(t, key)
            local fn = index(t, key)
            if type(fn) == "function" then
                fn = wrap(fn)
                rawset(t, key, fn)
            end
            return fn
        end
    end
end

-- ------------------------------------------
-- 档案窗口上的按钮
-- ------------------------------------------
-- MRP 窗口默认只有 338 像素宽，标题行居中，按钮放在里面会挡字；左右外沿是一眼印象图标栏，
-- 所以接在底边「外貌/性格/传记」标签页的右边，排成一行。

local translateButton, toggleButton

-- 档案窗口开着时，按 F1 等于点「翻译 / 粘贴」按钮；窗口关掉后 F1 恢复原来的功能（默认是选中自己）。
-- 想换键就改这里。战斗中不允许改键位，所以战斗里打开的档案要等脱战后 F1 才生效。
local HOTKEY = "F1"
local hotkeyOwner = CreateFrame("Frame")

local function SyncHotkey()
    if InCombatLockdown() then return end
    ClearOverrideBindings(hotkeyOwner)
    local bf = MyRolePlayBrowseFrame
    if HOTKEY and translateButton and bf and bf:IsShown() then
        SetOverrideBindingClick(hotkeyOwner, true, HOTKEY, "MRPTR_TranslateButton")
    end
end
hotkeyOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
hotkeyOwner:SetScript("OnEvent", SyncHotkey)

local function MakeButton(name, parent, text)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetSize(64, 22)
    button:SetText(text)
    return button
end

local function ShowTranslateTooltip(self)
    local player = Key(mrp.BFShown)
    local pending, done = Scan(player)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if #pending > 0 and Sent(player) then
        GameTooltip:SetText("粘贴译文", 1, 0.82, 0)
        GameTooltip:AddLine("这份档案已经发给助手了。听到提示音后点这里，再按 Ctrl+V；其他翻好的档案会一起写入。", 1, 1, 1, true)
        GameTooltip:AddLine("快捷键：" .. HOTKEY, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
        return
    end
    GameTooltip:SetText("翻译这份档案", 1, 0.82, 0)
    if #pending > 0 then
        GameTooltip:AddLine("待翻译：" .. Labels(pending), 1, 1, 1, true)
    else
        GameTooltip:AddLine("没有需要翻译的内容。", 1, 1, 1, true)
    end
    if done > 0 then
        GameTooltip:AddLine(("已有译文的字段：%d 个"):format(done), 0.7, 0.7, 0.7, true)
    end
    GameTooltip:AddLine("档案可能还在加载，之后新收到的字段可以再点一次补译。", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("快捷键：" .. HOTKEY, 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

local function RefreshDisplays(players)
    local function wanted(player)
        local key = Key(player)
        return key and (players == nil or players[key])
    end
    if MyRolePlayBrowseFrame and MyRolePlayBrowseFrame:IsShown() and wanted(mrp.BFShown) then
        mrp:UpdateBrowseFrame(mrp.BFShown)
    end
    if MyRolePlayGlanceFrame and MyRolePlayGlanceFrame:IsShown() and wanted(mrp.GFShown) then
        mrp:UpdateGlanceFrame(mrp.GFShown)
    end
    if GameTooltip:IsShown() and wanted(mrp.TTShown) then
        mrp:UpdateTooltip(mrp.TTShown)
    end
end

local function EnsureButtons(bf)
    if translateButton then return end

    translateButton = MakeButton("MRPTR_TranslateButton", bf, "翻译")
    translateButton:SetScript("OnClick", function() ns.StartRequest(Key(mrp.BFShown)) end)
    translateButton:SetScript("OnEnter", ShowTranslateTooltip)
    translateButton:SetScript("OnLeave", GameTooltip_Hide)

    toggleButton = MakeButton("MRPTR_ToggleButton", bf, "原文")
    toggleButton:SetPoint("LEFT", translateButton, "RIGHT", 4, 0)
    toggleButton:SetScript("OnClick", function()
        MRPTR_DB.showTranslated = not Showing()
        RefreshDisplays(nil)
    end)
    toggleButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(Showing() and "显示原文" or "显示译文", 1, 0.82, 0)
        GameTooltip:AddLine("鼠标提示和一眼印象预览框也会一起切换。", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    toggleButton:SetScript("OnLeave", GameTooltip_Hide)

    bf:HookScript("OnShow", SyncHotkey)
    bf:HookScript("OnHide", SyncHotkey)
    SyncHotkey()
end

-- 旧版标签页模板两端各有约 15 像素透明边，MRP 自己排标签页时也是叠 -15。
local TAB_GAP = (C_XMLUtil and C_XMLUtil.GetTemplateInfo
    and C_XMLUtil.GetTemplateInfo("CharacterFrameTabTemplate")) and 4 or -11

-- 标签页宽度随文字变，「性格」「传记」还能在 MRP 设置里隐藏，所以每次刷新都重新找最后一个可见的。
local function AnchorButtons(bf)
    translateButton:ClearAllPoints()
    for i = 3, 1, -1 do
        local tab = _G["MyRolePlayBrowseFrameTab" .. i]
        if tab and tab:IsShown() then
            translateButton:SetPoint("LEFT", tab, "RIGHT", TAB_GAP, 0)
            return
        end
    end
    translateButton:SetPoint("TOPLEFT", bf, "BOTTOMLEFT", 11, -2)
end

local function UpdateButtons(player)
    local pending, done = Scan(player)
    if #pending > 0 and Sent(Key(player)) then
        translateButton:SetText("粘贴")
    else
        translateButton:SetText(done > 0 and "补译" or "翻译")
    end
    translateButton:SetEnabled(#pending > 0)
    if done > 0 then
        toggleButton:SetText(Showing() and "原文" or "中文")
        toggleButton:Show()
    else
        toggleButton:Hide()
    end
end

-- ------------------------------------------
-- 鼠标提示批量队列
-- ------------------------------------------
-- 鼠标提示没法停下来按 Ctrl+C，所以扫过的人先记下来，攒一批一起翻。只在本次登录有效：
-- 别人的档案数据 reload 后就没了，留着也翻不了。

local MAX_QUEUE = 40
local queue, queueOrder = {}, {}
local hinted = false

local function RemoveFromQueue(player)
    if not queue[player] then return end
    queue[player] = nil
    for i, name in ipairs(queueOrder) do
        if name == player then
            table.remove(queueOrder, i)
            break
        end
    end
end

local function QueueIfNeeded(player)
    if not player or IsSelf(player) or queue[player] then return end
    if #Scan(player, ns.QUEUE_FIELDS) == 0 then return end

    queue[player] = true
    queueOrder[#queueOrder + 1] = player
    if #queueOrder > MAX_QUEUE then
        queue[table.remove(queueOrder, 1)] = nil
    end
    if not hinted and #queueOrder >= 5 then
        hinted = true
        Print(("鼠标提示里已有 %d 人的状态没翻译。按快捷键（在按键设置的“插件”分类里设置）或输入 /mrptr queue 一次翻译。"):format(#queueOrder))
    end
end

-- ------------------------------------------
-- 复制粘贴小窗
-- ------------------------------------------

local copyFrame

local STATUS_COLORS = {
    info = { 1, 0.82, 0 },
    warn = { 1, 0.6, 0.2 },
    error = { 1, 0.3, 0.3 },
}

local function SetStatus(text, level)
    local color = STATUS_COLORS[level] or STATUS_COLORS.info
    copyFrame.status:SetText(text)
    copyFrame.status:SetTextColor(color[1], color[2], color[3])
    copyFrame:SetHeight(copyFrame.status:GetStringHeight() + 34)
end

local function SelectAll()
    copyFrame.edit:SetFocus()
    copyFrame.edit:HighlightText()
end

local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true,
    SHIFT = true, CTRL = true, ALT = true, META = true,
}

-- 插件写不了剪贴板，只能把请求放进输入框选中，由玩家按 Ctrl+C。请求原文没必要给人看，
-- 所以这里只是按钮下面的一条小提示，输入框只露一行；按完 Ctrl+C / Ctrl+V 就自己收起。
local function CreateCopyFrame()
    local f = CreateFrame("Frame", "MRPTR_CopyFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(260, 50)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:Hide()
    tinsert(UISpecialFrames, "MRPTR_CopyFrame") -- Esc 关闭

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.status:SetPoint("TOPLEFT", 10, -9)
    f.status:SetPoint("TOPRIGHT", -10, -9)
    f.status:SetJustifyH("LEFT")

    -- 输入框必须显示着、有焦点、文字选中，Ctrl+C 才复制得到；外面套一层只露一行
    local clip = CreateFrame("Frame", nil, f)
    clip:SetPoint("BOTTOMLEFT", 10, 8)
    clip:SetPoint("BOTTOMRIGHT", -10, 8)
    clip:SetHeight(14)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    clip:EnableMouse(true)
    clip:SetScript("OnMouseDown", SelectAll)

    local edit = CreateFrame("EditBox", "MRPTR_CopyEditBox", clip)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontDisableSmall)
    edit:SetPoint("TOPLEFT")
    edit:SetPoint("TOPRIGHT")
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    edit:SetScript("OnEditFocusGained", edit.HighlightText)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then ns.HandlePaste(self:GetText()) end
    end)
    edit:SetScript("OnKeyDown", function(_, key)
        local ctrl = IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())
        if ctrl and key == "C" then
            -- 按下 C 时 Ctrl 一定还按着，松键先后因人而异，所以在这里判断。
            -- 复制在这次按键里才完成，稍等一下再收起，免得把输入框提前收掉。
            local players = f.players
            C_Timer.After(0.1, function()
                ns.MarkSent(players)
                if f.players == players then f:Hide() end
            end)
        elseif not ctrl and not MODIFIER_KEYS[key] then
            -- 按了别的键（多半是想走路）：收起提示，把键盘还给游戏
            f:Hide()
        end
    end)
    f.edit = edit

    f:SetScript("OnHide", function() edit:ClearFocus() end)
    copyFrame = f
end

local function ShowCopyFrame(packed, status, players)
    if not copyFrame then CreateCopyFrame() end
    copyFrame.players = players
    copyFrame:ClearAllPoints()
    if translateButton and translateButton:IsVisible() then
        copyFrame:SetPoint("TOPLEFT", translateButton, "BOTTOMLEFT", 0, -2)
        if not copyFrame.followsButton then
            -- 档案窗口关掉时提示也跟着收起，不留在半空
            translateButton:HookScript("OnHide", function() copyFrame:Hide() end)
            copyFrame.followsButton = true
        end
    else
        copyFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
    copyFrame.edit:SetText(packed)
    copyFrame.edit:SetCursorPosition(0)
    SetStatus(status, "info")
    copyFrame:Show()
    SelectAll()
end

-- ------------------------------------------
-- 发起请求、处理粘贴
-- ------------------------------------------

local function BuildBlock(player, keys)
    local fields = FieldTable(player)
    local items, originals = {}, {}
    for _, key in ipairs(keys) do
        local original = rawget(fields, key)
        local body = ns.ProtectField(key, original)
        items[#items + 1] = { key = key, hash = ns.Hash(original), body = body }
        originals[key] = original
    end
    ns.RememberJob(player, originals)
    return { player = player, name = CleanName(rawget(fields, "NA")) or Short(player), items = items }
end

function ns.StartRequest(player)
    local pending = Scan(player)
    if #pending == 0 then
        Print("这份档案没有需要翻译的内容。")
        return
    end
    local status = Sent(player)
        and "按 Ctrl+V 粘贴译文（没听到提示音的话，按 Ctrl+C 重发）"
        or "按 Ctrl+C 发给翻译助手"
    local packed = ns.Pack({ BuildBlock(player, pending) })
    ShowCopyFrame(packed, status, { player })
end

function ns.MarkSent(players)
    local names = {}
    for _, player in ipairs(players or {}) do
        local job = MRPTR_DB.jobs[player]
        if job then
            job.sent = time()
            names[#names + 1] = Short(player)
        end
    end
    if #names == 0 then return end
    local who = #names <= 3 and table.concat(names, "、") or ("%d 人"):format(#names)
    Print(("已发给助手：%s。不用等，听到提示音后打开档案点「粘贴」，按 Ctrl+V。"):format(who))
    if translateButton and mrp.BFShown then UpdateButtons(mrp.BFShown) end
end

function ns.StartQueueRequest()
    local blocks, players = {}, {}
    for _, player in ipairs({ unpack(queueOrder) }) do
        local pending = Scan(player, ns.QUEUE_FIELDS)
        if #pending > 0 then
            blocks[#blocks + 1] = BuildBlock(player, pending)
            players[#players + 1] = player
        else
            RemoveFromQueue(player) -- 已经在别处翻过了
        end
    end
    if #blocks == 0 then
        Print("翻译队列是空的：鼠标扫过有 RP 档案的玩家后，他们的状态会自动排进来。")
        return
    end
    ShowCopyFrame(ns.Pack(blocks), ("按 Ctrl+C 把 %d 人的鼠标提示发给翻译助手"):format(#blocks), players)
end

function MRPTR_TranslateQueue()
    ns.StartQueueRequest()
end

BINDING_HEADER_MRPTR = "MRP 档案翻译"
BINDING_NAME_MRPTR_TRANSLATE_QUEUE = "翻译鼠标提示队列"

function ns.HandlePaste(text)
    local parsed = ns.Parse(text)
    if not parsed then
        SetStatus("没有识别到译文。听到助手提示音后，再按 Ctrl+V。", "info")
        return
    end
    if parsed.kind == "REQ" then
        SetStatus("粘贴的还是原文请求：助手还没写回译文。听到提示音后再按 Ctrl+V。", "warn")
        copyFrame.edit:HighlightText()
        return
    end
    if parsed.kind == "ERR" then
        SetStatus("助手报错：" .. parsed.message, "error")
        Print("助手报错：" .. parsed.message)
        return
    end
    if parsed.truncated then
        SetStatus("译文不完整（缺少结束标记），请重新粘贴。", "error")
        return
    end

    local single = #parsed.players == 1
    local savedPlayers, savedFields, savedNames, alreadyPlayers, refresh = 0, 0, {}, 0, {}
    for _, block in ipairs(parsed.players) do
        local saved, stale, broken, already = ns.ApplyResponse(block, CurrentOriginal)
        local who = block.player and block.player ~= "" and Short(block.player) or "?"
        if #saved > 0 then
            savedPlayers = savedPlayers + 1
            savedFields = savedFields + #saved
            savedNames[#savedNames + 1] = who
            refresh[block.player] = true
            RemoveFromQueue(block.player)
            if single then
                Print(("已保存 %s 的译文：%s"):format(who, Labels(saved)))
            end
        elseif #already > 0 then
            alreadyPlayers = alreadyPlayers + 1
            RemoveFromQueue(block.player)
        end
        if #stale > 0 then
            Print(("%s 的这些字段在翻译期间被改过，需要重新翻译：%s"):format(who, Labels(stale)))
        end
        if #broken > 0 then
            Print(("%s 的这些字段格式标记对不上，没有采用：%s"):format(who, Labels(broken)))
        end
        for _, failed in ipairs(block.failed) do
            Print(("助手没能翻译 %s 的%s：%s"):format(who, ns.FIELD_LABELS[failed.key] or failed.key, failed.reason))
        end
    end
    if not single and savedPlayers > 0 then
        Print(("已保存 %d 人、%d 个字段的译文：%s"):format(savedPlayers, savedFields, table.concat(savedNames, "、")))
    end

    if savedPlayers > 0 then
        MRPTR_DB.showTranslated = true
        copyFrame:Hide()
        RefreshDisplays(refresh)
        if translateButton and mrp.BFShown then UpdateButtons(mrp.BFShown) end
    elseif alreadyPlayers > 0 then
        Print("剪贴板里的译文之前都已经粘贴过了。")
        copyFrame:Hide()
    else
        SetStatus("没有可用的译文，详情见聊天框。", "error")
    end
end

-- ------------------------------------------
-- 挂到 MRP 上
-- ------------------------------------------

local function AfterBrowseFrame(player)
    local bf = MyRolePlayBrowseFrame
    if not bf or not player then return end
    EnsureButtons(bf)
    AnchorButtons(bf)
    UpdateButtons(player)
end

local function CountCached()
    local n = 0
    for _ in pairs(MRPTR_DB.cache) do n = n + 1 end
    return n
end

local function RegisterSlashCommand()
    SLASH_MRPTRANSLATE1 = "/mrptr"
    SlashCmdList.MRPTRANSLATE = function(msg)
        msg = (match(msg or "", "^[ \t]*(.-)[ \t]*$") or ""):lower()
        if msg == "queue" or msg == "q" then
            ns.StartQueueRequest()
        elseif msg == "clear" then
            wipe(MRPTR_DB.cache)
            wipe(MRPTR_DB.jobs)
            Print("译文缓存已清空。")
            RefreshDisplays(nil)
        else
            Print(("已缓存 %d 人的译文，翻译队列里有 %d 人。"):format(CountCached(), #queueOrder))
            Print("/mrptr queue 翻译鼠标提示队列；/mrptr clear 清空译文缓存。")
        end
    end
end

-- 中文客户端上把 MRP 的身高体重单位改成厘米、公斤。只改一次，之后玩家自己改回去不再动。
local function ApplyMetricOnce()
    if GetLocale() ~= "zhCN" or MRPTR_DB.metricApplied then return end
    MRPTR_DB.metricApplied = true
    local options = type(mrpSaved) == "table" and mrpSaved.Options
    if type(options) ~= "table" then return end
    -- 只改 MRP 英式默认值（英尺英寸、英石）；已经主动选了别的单位（比如磅）就不动
    local changed = false
    if options.HeightUnit == 2 then options.HeightUnit, changed = 0, true end
    if options.WeightUnit == 2 then options.WeightUnit, changed = 0, true end
    if changed then
        Print("已把 MRP 的身高、体重单位改为厘米、公斤，可以在 MRP 设置里改回。")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")

    ns.InitDB()
    RegisterSlashCommand()

    if type(mrp) ~= "table" or type(mrp.UpdateBrowseFrame) ~= "function" then
        Print("没有找到可用的 MyRolePlay，翻译功能不可用。")
        return
    end
    ApplyMetricOnce()

    FixDisplayTable(mrp.DisplayTooltip)
    FixDisplayTable(mrp.DisplayBrowser)
    FixDisplayTable(mrp.DisplayChat)

    WrapMRP("UpdateBrowseFrame", function(player) return player or mrp.BFShown end, ns.FIELDS, AfterBrowseFrame)
    WrapMRP("UpdateHTMLText", function() return mrp.BFShown end, { "DE", "HI" })
    WrapMRP("UpdateTooltip", function(player) return player or mrp.TTShown end, { "NT", "CU", "CO" }, QueueIfNeeded)
    WrapMRP("UpdateGlanceFrame", function(player) return player or mrp.GFShown end, { "PE" }, QueueIfNeeded)
end)
