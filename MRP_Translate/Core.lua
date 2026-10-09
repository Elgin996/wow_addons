local ADDON_NAME, ns = ...

-- ==========================================
-- 协议、标记保护与译文缓存
-- ==========================================
-- 这个文件不碰任何界面，也不直接读 MRP 的数据：需要的东西都由 UI.lua 传进来，
-- 这样整套打包/解析逻辑可以脱离游戏单独测试。

local byte, concat, find, format, gmatch, gsub, lower, match, sub =
    string.byte, table.concat, string.find, string.format, string.gmatch, string.gsub,
    string.lower, string.match, string.sub
local floor = math.floor

ns.HEADER_REQ = "<<MRPTR1 REQ>>"
ns.HEADER_RES = "<<MRPTR1 RES>>"
ns.HEADER_ERR = "<<MRPTR1 ERR>>"
ns.FOOTER = "<<MRPTR1 END>>"

-- 要翻译的字段，按打包顺序排列。人名（NA、NI）和代码类字段（FR、FC、RS）不翻。
ns.FIELDS = { "NT", "CU", "CO", "AE", "AH", "AW", "DE", "AG", "HH", "HB", "MO", "HI", "PE", "PS" }

-- 鼠标提示和一眼印象预览框里会出现的字段：鼠标扫过就记进批量队列
ns.QUEUE_FIELDS = { "NT", "CU", "CO", "PE" }

ns.FIELD_LABELS = {
    NT = "头衔", CU = "当前状态", CO = "场外信息", AE = "眼睛", AH = "身高", AW = "体型",
    DE = "外貌描述", AG = "年龄", HH = "居住地", HB = "出生地", MO = "格言", HI = "背景故事",
    PE = "一眼印象", PS = "性格特质",
}

local MAX_CACHED_PLAYERS = 1000
local MAX_JOBS = 60

-- ------------------------------------------
-- 哈希
-- ------------------------------------------
-- 判断"对方的档案改没改过"用。两个 32 位以内的多项式哈希拼成 16 位十六进制，
-- 全程用整数范围内的浮点运算，不依赖 bit 库，也不用 %x 格式化超过 2^31 的数
-- （部分客户端的 Lua 会在那里溢出）。
local function hex32(n)
    return format("%04x%04x", floor(n / 65536), n % 65536)
end

-- MRP 加载档案、刷新鼠标提示时都要核对各字段的哈希。同一段原文只算一次；
-- 记住的条目够多就整张丢掉重来（键是 MRP 本来就存着的字符串，不额外占内存）。
local MAX_HASH_MEMO = 256
local hashMemo, hashMemoSize = {}, 0

function ns.Hash(s)
    local known = hashMemo[s]
    if known then return known end

    local h1, h2 = 5381, 0
    for i = 1, #s do
        local b = byte(s, i)
        h1 = (h1 * 33 + b) % 4294967296
        h2 = (h2 * 131 + b) % 2147483647
    end
    local hash = hex32(h1) .. hex32(h2)

    if hashMemoSize >= MAX_HASH_MEMO then
        hashMemo, hashMemoSize = {}, 0
    end
    hashMemo[s] = hash
    hashMemoSize = hashMemoSize + 1
    return hash
end

-- ------------------------------------------
-- UTF-8 修补
-- ------------------------------------------
-- MRP 截断鼠标提示里的长字段时按字节截（strsub），碰上中文会把一个汉字切成两半，
-- 显示成乱码。去掉不完整的多字节序列，其余原样保留。
function ns.FixUtf8(s)
    if not find(s, "[\128-\255]") then return s end
    return (gsub(s, "([\192-\255])([\128-\191]*)", function(lead, rest)
        local b = byte(lead)
        local need = b >= 240 and 3 or b >= 224 and 2 or 1
        if #rest < need then return "" end
    end))
end

-- ------------------------------------------
-- 标记保护
-- ------------------------------------------
-- 档案里的格式标记换成 {{n}} 占位符再交给翻译，回来后原样换回。规则必须是确定的：
-- 粘贴译文时会用原文重新跑一遍 Protect 来拿到同一套标记，不需要另存映射。
--
-- 受保护的东西：
--   |c........ |r |n |T..|t |A..|a |H..|h |K..|k..|k 以及任何剩下的 |（输入框会把
--   | 当格式码渲染，复制出去的内容就不可控了，所以一个都不留）
--   {h1:c}、{/p}、{img:...} 等所有花括号组，以及落单的 { }
--   [文字](网址) 里的 "[" 和 "](网址)"，中间的文字照常翻译
--   http:// https:// 网址
--   行首的 # 和单独一行的 ---：一眼印象靠它们分出标题和条目
--   TRP3 发来的两段英文分节标题：MRP 显示时会把它们删掉，译掉就删不掉了

local LITERALS = { "#Physical Description\n\n", "---\n\n#Personality Traits" }

function ns.Protect(text)
    text = gsub(text, "\r\n?", "\n")
    local tokens, out = {}, {}
    local function keep(s)
        tokens[#tokens + 1] = s
        out[#out + 1] = "{{" .. #tokens .. "}}"
    end

    local closeAt = {} -- markdown 链接里 "]" 的位置 -> "](网址)" 结束的位置
    local i, len = 1, #text
    while i <= len do
        local c = sub(text, i, i)
        local stop = i
        local lineStart = i == 1 or sub(text, i - 1, i - 1) == "\n"
        local literal
        for _, lit in ipairs(LITERALS) do
            if sub(text, i, i + #lit - 1) == lit then
                literal = lit
                break
            end
        end

        if literal then
            stop = i + #literal - 1
            keep(literal)
        elseif closeAt[i] then
            stop = closeAt[i]
            keep(sub(text, i, stop))
        elseif lineStart and c == "#" then
            keep(c)
        elseif lineStart and sub(text, i, i + 2) == "---" and (i + 3 > len or sub(text, i + 3, i + 3) == "\n") then
            stop = i + 2
            keep("---")
        elseif c == "|" then
            local j = find(text, "[^|]", i) or (len + 1) -- 第一个不是 | 的字符
            local nc = sub(text, j, j)
            stop = j - 1 -- 默认只保护这一串 |
            if nc == "c" and find(text, "^%x%x%x%x%x%x%x%x", j + 1) then
                stop = j + 8
            elseif nc == "r" or nc == "n" then
                stop = j
            elseif nc == "T" or nc == "A" or nc == "H" or nc == "K" then
                local _, e = find(text, "|+" .. lower(nc), j + 1)
                if e and nc == "K" then
                    local _, e2 = find(text, "|+k", e + 1)
                    e = e2 or e
                end
                stop = e or stop
            end
            keep(sub(text, i, stop))
        elseif c == "{" then
            local _, e = find(text, "^%b{}", i)
            stop = e or i
            keep(sub(text, i, stop))
        elseif c == "}" then
            keep(c)
        elseif c == "[" then
            local s, e, inner = find(text, "^%[([^%]]+)%]%([^%)]*%)", i)
            if s then
                closeAt[i + 1 + #inner] = e
                keep(c)
            else
                out[#out + 1] = c
            end
        elseif c == "h" and find(text, "^https?://[^ \t\n%)%]|{}]", i) then
            local _, e = find(text, "^https?://[^ \t\n%)%]|{}]+", i)
            stop = e
            keep(sub(text, i, stop))
        else
            out[#out + 1] = c
        end
        i = stop + 1
    end
    return concat(out), tokens
end

-- 性格特质（PS）是一串 [trait left-name="Brave" left-icon="..." value="0.3"]，
-- 只有自定义特质两端的名称需要翻译，其余全部保护起来。
local function ProtectTraits(text)
    local tokens, out = {}, {}
    local function keep(s)
        if s == "" then return end
        tokens[#tokens + 1] = s
        out[#out + 1] = "{{" .. #tokens .. "}}"
    end
    local pos = 1
    while true do
        local _, e = find(text, '%-name="', pos)
        local close = e and find(text, '"', e + 1, true)
        if not close then break end
        keep(sub(text, pos, e))
        -- 名称里万一带了颜色码之类，同样换成占位符，编号接在后面
        local protected, inner = ns.Protect(sub(text, e + 1, close - 1))
        local base = #tokens
        for _, token in ipairs(inner) do
            tokens[#tokens + 1] = token
        end
        out[#out + 1] = gsub(protected, "{{(%d+)}}", function(n) return "{{" .. (base + tonumber(n)) .. "}}" end)
        pos = close
    end
    keep(sub(text, pos))
    return concat(out), tokens
end

-- 占位符一个不能少、一个不能多，否则颜色、链接、排版会错乱，宁可不用这份译文。
function ns.Restore(translated, tokens)
    translated = gsub(translated, "\r\n?", "\n")
    -- 译文里本不该有 |；万一有，换成全角，免得被当成格式码
    translated = gsub(translated, "|", "｜")
    local seen, bad = {}, false
    local result = gsub(translated, "{{(%d+)}}", function(n)
        n = tonumber(n)
        local token = tokens[n]
        if not token or seen[n] then
            bad = true
            return ""
        end
        seen[n] = true
        return token
    end)
    for n = 1, #tokens do
        if not seen[n] then
            bad = true
            break
        end
    end
    if bad then return nil end
    return result
end

function ns.ProtectField(key, text)
    if key == "PS" then return ProtectTraits(text) end
    return ns.Protect(text)
end

function ns.RestoreField(key, translated, tokens)
    if key == "PS" then
        -- 特质名放在 "..." 里、整条特质放在 [...] 里，译文里不能出现这几个字符；名称也不该换行
        translated = gsub(translated, '"', "”")
        translated = gsub(translated, "%[", "【")
        translated = gsub(translated, "%]", "】")
        translated = gsub(translated, "[\r\n]+", " ")
    end
    local result = ns.Restore(translated, tokens)
    if result and key == "PE" then
        -- MRP 要求一眼印象的标题紧跟在行首的 # 后面；模型偶尔会在占位符后面加空格或换行
        result = gsub(result, "\n#[ \t\n]+", "\n#")
        result = gsub(result, "^#[ \t\n]+", "#")
    end
    return result
end

-- 字段里有没有值得翻的文字。纯数字（身高 180、年龄 27）、已经是中文的内容、
-- 只有内置特质的性格滑条，都不送去翻译。
function ns.NeedsTranslation(key, original)
    if not original or original == "" then return false end
    if key ~= "PS" and #original > 200 then return true end
    local stripped = gsub(ns.ProtectField(key, original), "{{%d+}}", "")
    return find(stripped, "[A-Za-z]") ~= nil
end

-- ------------------------------------------
-- 打包与解析
-- ------------------------------------------
-- 一份请求可以有好几个玩家（批量翻译鼠标提示时）：
--   @player 名字-服务器     开始一个玩家
--   @name 角色名            这个玩家的角色名（给翻译当上下文）
--   @field 字段 哈希        开始一个字段，下面的行都是正文
--   @failed 字段 原因       （只在回包里）这个字段没翻成
-- 正文里以 @ 或 < 开头的行前面补一个 @，所以"@ 加小写字母"开头的行一定是指令。

local function EscapeBody(body)
    return (gsub(body, "[^\n]+", function(line)
        if find(line, "^[@<]") then return "@" .. line end
    end))
end

local function OneLine(s)
    return (gsub(s or "", "[\r\n]+", " "))
end

-- blocks: { { player = "名字-服务器", name = "角色名", items = { { key, hash, body }, ... } }, ... }
function ns.Pack(blocks)
    local lines = { ns.HEADER_REQ }
    for _, block in ipairs(blocks) do
        lines[#lines + 1] = "@player " .. OneLine(block.player)
        if block.name and block.name ~= "" then
            lines[#lines + 1] = "@name " .. OneLine(block.name)
        end
        for _, item in ipairs(block.items) do
            lines[#lines + 1] = "@field " .. item.key .. " " .. item.hash
            lines[#lines + 1] = EscapeBody(item.body)
        end
    end
    lines[#lines + 1] = ns.FOOTER
    return concat(lines, "\n")
end

-- 这里和下面都只认 ASCII 空白：%s、%a 之类会随系统区域设置变化，有的设置下会把
-- UTF-8 中文的某个字节当成空白或字母，去尾空白时就可能切坏最后一个汉字。
local function Trim(s)
    return match(s, "^[ \t\n]*(.-)[ \t\n]*$")
end

local function FinishField(field)
    if field then
        field.body = gsub(concat(field.lines, "\n"), "[ \t\n]+$", "")
        field.lines = nil
    end
end

-- 找协议标记。正文里恰好写了这串字的行已被转义成 "@<<MRPTR1 ..."，要跳过。
local function FindMarker(text, marker, init)
    local pos = init or 1
    while true do
        local s = find(text, marker, pos, true)
        if not s or s == 1 or sub(text, s - 1, s - 1) ~= "@" then return s end
        pos = s + 1
    end
end

-- 粘贴的内容不一定只有译文：光标没全选时，译文会插在原来那份请求的中间。
-- 所以优先找 RES，而且在整段文字里找，不要求从开头开始。
function ns.Parse(text)
    if not text then return nil end
    text = gsub(text, "\r\n?", "\n")

    local resStart = FindMarker(text, ns.HEADER_RES)
    if resStart then
        local bodyStart = resStart + #ns.HEADER_RES
        local footer = find(text, "\n" .. ns.FOOTER, bodyStart, true)
        if not footer then
            return { kind = "RES", truncated = true }
        end

        local result = { kind = "RES", players = {} }
        local block, field
        for line in gmatch(sub(text, bodyStart, footer), "([^\n]*)\n") do
            if find(line, "^@[a-z]") then
                local key, hash = match(line, "^@field ([A-Z][A-Z]) ([0-9a-f]+)[ \t]*$")
                local player = match(line, "^@player (.*)$")
                if player then
                    FinishField(field)
                    field = nil
                    block = { player = Trim(player), fields = {}, failed = {} }
                    result.players[#result.players + 1] = block
                elseif block and key then
                    FinishField(field)
                    field = { key = key, hash = hash, lines = {} }
                    block.fields[#block.fields + 1] = field
                elseif block and match(line, "^@name ") then
                    block.name = Trim(sub(line, 7))
                elseif block then
                    local failedKey, reason = match(line, "^@failed ([A-Z][A-Z])[ \t]*(.-)[ \t]*$")
                    if failedKey then
                        block.failed[#block.failed + 1] = { key = failedKey, reason = reason }
                    end
                end
            elseif field then
                if find(line, "^@[@<]") then line = sub(line, 2) end
                field.lines[#field.lines + 1] = line
            end
        end
        FinishField(field)
        return result
    end

    local errStart = FindMarker(text, ns.HEADER_ERR)
    if errStart then
        local message = sub(text, errStart + #ns.HEADER_ERR)
        local footer = find(message, ns.FOOTER, 1, true)
        if footer then message = sub(message, 1, footer - 1) end
        message = Trim(message)
        return { kind = "ERR", message = message ~= "" and message or "未知错误" }
    end

    if FindMarker(text, ns.HEADER_REQ) then
        return { kind = "REQ" }
    end
    return nil
end

-- ------------------------------------------
-- 缓存
-- ------------------------------------------
-- MRPTR_DB.cache[玩家].fields[字段] = { h = 原文哈希, t = 译文 }
-- MRPTR_DB.jobs[玩家].fields[字段] = 发出请求时的原文
-- jobs 存原文是为了在 Ctrl+C 和 Ctrl+V 之间 /reload 也不丢：MRP 收到的别人
-- 的档案不进存档，reload 之后要重新请求才有。

function ns.InitDB()
    MRPTR_DB = type(MRPTR_DB) == "table" and MRPTR_DB or {}
    MRPTR_DB.cache = type(MRPTR_DB.cache) == "table" and MRPTR_DB.cache or {}
    MRPTR_DB.jobs = type(MRPTR_DB.jobs) == "table" and MRPTR_DB.jobs or {}
    if MRPTR_DB.showTranslated == nil then MRPTR_DB.showTranslated = true end
    ns.Prune(MRPTR_DB.cache, MAX_CACHED_PLAYERS)
    ns.Prune(MRPTR_DB.jobs, MAX_JOBS)
end

-- 只留最近用过的 max 个玩家
function ns.Prune(tbl, max)
    local list = {}
    for player, entry in pairs(tbl) do
        list[#list + 1] = { player = player, at = type(entry) == "table" and entry.at or 0 }
    end
    if #list <= max then return end
    table.sort(list, function(a, b) return a.at > b.at end)
    for i = max + 1, #list do
        tbl[list[i].player] = nil
    end
end

function ns.GetTranslation(player, key, original)
    if not original or original == "" then return nil end
    local entry = MRPTR_DB and MRPTR_DB.cache[player]
    local field = entry and entry.fields and entry.fields[key]
    if field and field.h == ns.Hash(original) then
        return field.t
    end
    return nil
end

function ns.SaveTranslation(player, key, hash, text)
    local entry = MRPTR_DB.cache[player]
    if not entry then
        entry = { fields = {} }
        MRPTR_DB.cache[player] = entry
    end
    entry.at = time()
    entry.fields[key] = { h = hash, t = text }
end

-- 合并而不是覆盖：同一个人可能先单独翻了外貌描述还没粘贴，又进了批量队列
function ns.RememberJob(player, originals)
    local job = MRPTR_DB.jobs[player]
    if type(job) ~= "table" or type(job.fields) ~= "table" then
        job = { fields = {} }
        MRPTR_DB.jobs[player] = job
    end
    for key, original in pairs(originals) do
        job.fields[key] = original
    end
    job.at = time()
    ns.Prune(MRPTR_DB.jobs, MAX_JOBS)
end

-- 按字段核对哈希、还原标记、写入缓存。block 是 Parse 结果里的一个玩家。
-- currentOriginal(player, key) 返回 MRP 当前收到的原文，用于 jobs 里没有的情况。
-- 返回四张表：已保存、档案已变（哈希对不上）、占位符不符、之前已粘贴过。
-- 助手每次都把一小时内翻好的译文整批带上，所以同一段译文可能粘贴好几次，已有的直接跳过。
function ns.ApplyResponse(block, currentOriginal)
    local saved, stale, broken, already = {}, {}, {}, {}
    local player = block.player
    if not player or player == "" then return saved, stale, broken, already end
    local job = MRPTR_DB.jobs[player]

    for _, field in ipairs(block.fields) do
        local original
        local fromJob = job and job.fields and job.fields[field.key]
        local entry = MRPTR_DB.cache[player]
        local have = entry and entry.fields and entry.fields[field.key]
        local dup = have and have.h == field.hash
        if dup then
            already[#already + 1] = field.key
            if fromJob and ns.Hash(fromJob) == field.hash then job.fields[field.key] = nil end
        elseif fromJob and ns.Hash(fromJob) == field.hash then
            original = fromJob
        else
            local current = currentOriginal(player, field.key)
            if current and current ~= "" and ns.Hash(current) == field.hash then
                original = current
            end
        end

        if dup then
            -- 上面已经记进 already
        elseif not original then
            stale[#stale + 1] = field.key
        else
            local _, tokens = ns.ProtectField(field.key, original)
            local text = field.body ~= "" and ns.RestoreField(field.key, field.body, tokens) or nil
            if text then
                ns.SaveTranslation(player, field.key, field.hash, text)
                saved[#saved + 1] = field.key
                -- 这段原文用完了，不必再占着存档
                if fromJob == original then job.fields[field.key] = nil end
            else
                broken[#broken + 1] = field.key
            end
        end
    end
    if job and job.fields and next(job.fields) == nil then
        MRPTR_DB.jobs[player] = nil
    end
    return saved, stale, broken, already
end
