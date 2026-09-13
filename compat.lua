--[[
    compat.lua —— NotGrid 专用 Ace2 兼容层（脱库版）

    背景：NotGrid 原本依赖一整套 Ace2 库（AceLibrary/AceAddon-2.0/AceEvent-2.0/
    AceLocale-2.2/RosterLib-2.0/Compost-2.0/HealComm-1.0/Gratuity-2.0）。
    在 Emberveil 这类私服客户端上通常没有额外安装这套老库，
    于是加载 menus.lua 等文件时会报 "attempt to call global 'AceLibrary' (a nil value)"。

    本文件不是一个通用的 Ace2 替代实现，而是**只针对 NotGrid 实际用到的那部分 API**
    做的最小化、可用的替代，务必放在 NotGrid.toc 里除 localization.lua 外最先加载
    （即第一行），这样后续文件里的 AceLibrary(...) 调用才不会是 nil。

    注：NotGrid 源码里还散落着几处更早期(Lua4/Ace2 时代)的遗留写法
    "for x in someTable do ... end"（没有 pairs()/ipairs()），在标准 Lua 5.1 环境下
    会直接报 "attempt to call a table value"。这与 Ace2 库缺失无关，是另一处独立的老代码问题，
    已经在 core.lua / frames.lua / menus.lua / options.lua / proximity.lua 里顺手改成了
    pairs()/ipairs()，不影响任何原有逻辑。

    覆盖的库与方法：
      AceLibrary("AceLocale-2.2"):new(name)         -> :RegisterTranslations(locale, func)
      AceLibrary("AceAddon-2.0"):new("AceEvent-2.0")-> :RegisterEvent / :TriggerEvent /
                                                        :ScheduleEvent / :ScheduleRepeatingEvent /
                                                        :CancelScheduledEvent / OnInitialize / OnEnable 生命周期
      AceLibrary("RosterLib-2.0")                   -> :GetUnitIDFromName(name)
                                                        + 内部自动追踪花名册变化，
                                                          触发 RosterLib_RosterChanged / RosterLib_UnitChanged
      AceLibrary("Compost-2.0")                     -> :Acquire(...) / :Reclaim(t)   （简单对象池，无需真实回收也不影响正确性）
      AceLibrary("HealComm-1.0")                    -> :getHeal(name) / :UnitisResurrecting(name)
                                                        【桩实现，见下方说明】
      AceLibrary("Gratuity-2.0")                    -> 空占位（NotGrid 实际未调用其方法）

    HealComm 说明：
      真正的 HealComm-1.0 依赖同一支库在全团队所有人客户端间通过插件消息同步"预计治疗量"，
      如果团队里没有人都在用同一套实现，预测本身也没有意义。这里给出的是一个"安全桩"：
      不会报错，只是治疗预估条/文本永远显示为 0（即这部分视觉效果被优雅降级，其余功能不受影响）。
      如果以后需要真正的跨玩家治疗预测，需要额外实现一套基于 SendAddonMessage 的私服内部协议，
      这是一个独立的、工作量不小的功能，可以后续单独做。
]]

-- ============================================================
-- 给一个表加上"访问不存在的方法时返回空函数而不是报错"的兜底，
-- 用于给桩库(HealComm/Gratuity等)兜底，防止漏实现的方法导致报错崩溃插件
local function WithNoOpFallback(t)
    return setmetatable(t, {
        __index = function()
            return function() end
        end
    })
end

-- ============================================================
-- 小工具：SetSize(frame, w, h)
-- menus.lua 里有一处把 SetSize 当成全局函数调用，但 3.3.5 客户端的 frame
-- 并没有 :SetSize() 方法（那是后来版本才加的），也没有这个全局函数。
-- 这里补一个等价实现，与 Ace2 无关，纯粹是让代码本身能跑起来。
-- ============================================================
function SetSize(frame, w, h)
    frame:SetWidth(w)
    frame:SetHeight(h)
end

-- ============================================================
-- AceLocale-2.2 shim
-- ============================================================
local LocaleTables = {} -- [addonName] = 共享的 L 表

local function AceLocale_new(_, addonName)
    local L = LocaleTables[addonName]
    if L then
        return L
    end

    L = {}
    LocaleTables[addonName] = L

    -- L:RegisterTranslations("enUS", function() return {...} end)
    L.RegisterTranslations = function(self, localeName, tableFunc)
        local clientLocale = GetLocale and GetLocale() or "enUS"
        -- enUS 作为兜底基础翻译表，之后如果客户端语言恰好匹配才会覆盖/补充
        if localeName == "enUS" or localeName == clientLocale then
            local translated = tableFunc()
            for k, v in pairs(translated) do
                rawset(self, k, v)
            end
        end
    end

    return L
end

-- ============================================================
-- AceAddon-2.0 + 内嵌 AceEvent-2.0 shim
-- ============================================================
local function AceAddon_new(_, ...)
    local addon = {}
    addon._handlers = {}   -- [eventName] = handlerNameOrFunc
    addon._timers   = {}   -- [timerName]  = {remaining=, interval=, repeating=, callback=}

    local frame = CreateFrame("Frame")
    addon._frame = frame

    -- 事件：真实游戏事件走 frame:RegisterEvent，虚拟/自定义事件(如 RosterLib_RosterChanged)
    -- 用 pcall 包住，注册失败(说明不是合法的游戏事件)也没关系，只当作虚拟事件使用，
    -- 靠 TriggerEvent 手动触发
    function addon:RegisterEvent(event, handler)
        self._handlers[event] = handler or event
        pcall(function() frame:RegisterEvent(event) end)
    end

    function addon:UnregisterEvent(event)
        self._handlers[event] = nil
        pcall(function() frame:UnregisterEvent(event) end)
    end

    local function dispatch(handler, ...)
        if type(handler) == "function" then
            return handler(addon, ...)
        elseif type(handler) == "string" then
            local fn = addon[handler]
            if fn then return fn(addon, ...) end
        end
    end

    -- 虚拟事件：直接把参数当普通 Lua 参数传给处理函数
    function addon:TriggerEvent(event, ...)
        local h = self._handlers[event]
        if h then dispatch(h, ...) end
    end

    -- 真实游戏事件：3.3.5 客户端仍然通过全局变量 event/arg1..arg9 传参，
    -- 处理函数内部本来就是读这些全局变量（和插件原代码风格一致），这里不需要转发任何参数
    frame:SetScript("OnEvent", function()
        local h = addon._handlers[event]
        if h then dispatch(h) end
    end)

    -- 计时器：用一个 OnUpdate 驱动，替代 ScheduleEvent/ScheduleRepeatingEvent/CancelScheduledEvent
    frame:SetScript("OnUpdate", function(_, elapsed)
        for name, tm in pairs(addon._timers) do
            tm.remaining = tm.remaining - elapsed
            if tm.remaining <= 0 then
                if tm.repeating then
                    tm.remaining = tm.remaining + tm.interval
                    if tm.remaining <= 0 then tm.remaining = tm.interval end
                else
                    addon._timers[name] = nil
                end
                tm.callback()
            end
        end
    end)

    -- :ScheduleEvent(name, delay)                 -- 到时触发同名虚拟事件
    -- :ScheduleEvent(name, callback, delay)        -- 到时调用 callback
    function addon:ScheduleEvent(name, a, b)
        local callback, delay
        if type(a) == "function" then
            callback, delay = a, b
        else
            delay = a
            callback = function() addon:TriggerEvent(name) end
        end
        addon._timers[name] = { remaining = delay or 0, interval = delay or 0, repeating = false, callback = callback }
    end

    function addon:ScheduleRepeatingEvent(name, a, b)
        local callback, interval
        if type(a) == "function" then
            callback, interval = a, b
        else
            interval = a
            callback = function() addon:TriggerEvent(name) end
        end
        interval = interval or 1
        addon._timers[name] = { remaining = interval, interval = interval, repeating = true, callback = callback }
    end

    function addon:CancelScheduledEvent(name)
        addon._timers[name] = nil
    end

    -- 生命周期：ADDON_LOADED(本插件) -> OnInitialize -> OnEnable
    -- (与经典 Ace2 AceAddon-2.0 行为一致：SavedVariables 在 ADDON_LOADED 触发前就已经就绪)
    local lifecycle = CreateFrame("Frame")
    lifecycle:RegisterEvent("ADDON_LOADED")
    lifecycle:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "NotGrid" then
            if addon.OnInitialize then addon:OnInitialize() end
            if addon.OnEnable then addon:OnEnable() end
            lifecycle:UnregisterEvent("ADDON_LOADED")
        end
    end)

    return addon
end

-- ============================================================
-- Compost-2.0 shim —— 简单对象池（不做真正的对象复用，
-- 只保证 :Acquire(...)/: Reclaim(t) 的语义正确，对正确性没有影响，只是没有极致的GC优化）
-- ============================================================
local Compost = {}
function Compost:Acquire(...)
    local t = {}
    local n = select('#', ...)
    for i = 1, n do
        t[i] = select(i, ...)
    end
    return t
end
function Compost:Reclaim(t)
    if type(t) == "table" then
        for k in pairs(t) do
            t[k] = nil
        end
    end
end

-- ============================================================
-- RosterLib-2.0 shim —— 用原生 API 自己扫描花名册变化，
-- 触发 RosterLib_RosterChanged / RosterLib_UnitChanged
-- ============================================================
local RosterLib = {}
RosterLib.snapshot = {}

local ROSTER_UNITS = {}
do
    table.insert(ROSTER_UNITS, "player")
    table.insert(ROSTER_UNITS, "pet")
    for i = 1, 4 do
        table.insert(ROSTER_UNITS, "party" .. i)
        table.insert(ROSTER_UNITS, "partypet" .. i)
    end
    for i = 1, 40 do
        table.insert(ROSTER_UNITS, "raid" .. i)
    end
end

local function readUnitInfo(unit)
    if not UnitExists(unit) then return nil end
    local name = UnitName(unit)
    local _, classToken = UnitClass(unit)
    local subgroup, rank = 1, 0

    local raidIndex = tonumber(string.match(unit, "^raid(%d+)$"))
    if raidIndex then
        local _, r, sg = GetRaidRosterInfo(raidIndex)
        rank = r or 0
        subgroup = sg or 1
    elseif unit == "player" then
        rank = IsPartyLeader() and 2 or 0
    elseif string.match(unit, "^party%d$") then
        rank = UnitIsPartyLeader(unit) and 2 or 0
    end

    return { name = name, class = classToken, subgroup = subgroup, rank = rank }
end

function RosterLib:GetUnitIDFromName(name)
    if not name then return nil end
    for _, unit in ipairs(ROSTER_UNITS) do
        local info = self.snapshot[unit]
        if info and info.name == name then
            return unit
        end
    end
    -- 兜底：花名册缓存没有命中时，直接现场查一遍
    for _, unit in ipairs(ROSTER_UNITS) do
        if UnitExists(unit) and UnitName(unit) == name then
            return unit
        end
    end
    return nil
end

local rosterInitialized = false
local function ScanRoster(fireEvents)
    local changedList = {}
    for _, unit in ipairs(ROSTER_UNITS) do
        local newInfo = readUnitInfo(unit)
        local oldInfo = RosterLib.snapshot[unit]

        local isDifferent = false
        if (newInfo == nil) ~= (oldInfo == nil) then
            isDifferent = true
        elseif newInfo and oldInfo then
            if newInfo.name ~= oldInfo.name or newInfo.class ~= oldInfo.class
                or newInfo.subgroup ~= oldInfo.subgroup or newInfo.rank ~= oldInfo.rank then
                isDifferent = true
            end
        end

        if isDifferent then
            local entry = {
                unitid      = newInfo and unit or nil,
                name        = newInfo and newInfo.name or nil,
                class       = newInfo and newInfo.class or nil,
                subgroup    = newInfo and newInfo.subgroup or nil,
                rank        = newInfo and newInfo.rank or nil,
                oldname     = oldInfo and oldInfo.name or nil,
                oldunitid   = oldInfo and unit or nil,
                oldclass    = oldInfo and oldInfo.class or nil,
                uldsubgroup = oldInfo and oldInfo.subgroup or nil,
                oldrank     = oldInfo and oldInfo.rank or nil,
            }
            table.insert(changedList, entry)
            RosterLib.snapshot[unit] = newInfo

            if fireEvents and _G.NotGrid and _G.NotGrid.TriggerEvent then
                _G.NotGrid:TriggerEvent("RosterLib_UnitChanged",
                    entry.unitid, entry.name, entry.class, entry.subgroup, entry.rank,
                    entry.oldname, entry.oldunitid, entry.oldclass, entry.uldsubgroup, entry.oldrank)
            end
        end
    end

    if fireEvents and #changedList > 0 and _G.NotGrid and _G.NotGrid.TriggerEvent then
        _G.NotGrid:TriggerEvent("RosterLib_RosterChanged", changedList)
    end
end

local rosterFrame = CreateFrame("Frame")
rosterFrame:RegisterEvent("RAID_ROSTER_UPDATE")
rosterFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
rosterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
rosterFrame:SetScript("OnEvent", function()
    if not rosterInitialized then
        ScanRoster(false) -- 第一次先静默建立基线，避免登录瞬间触发一堆虚假的"变化"
        rosterInitialized = true
    else
        ScanRoster(true)
    end
end)

-- ============================================================
-- HealComm-1.0 shim（安全桩，见文件头说明）
-- ============================================================
local HealComm = WithNoOpFallback({})
function HealComm:getHeal(name) return 0 end
function HealComm:UnitisResurrecting(name) return false end

-- ============================================================
-- Gratuity-2.0 shim（NotGrid 实际未调用其方法，占位即可）
-- ============================================================
local Gratuity = WithNoOpFallback({})

-- ============================================================
-- AceLibrary 全局入口
-- ============================================================
function AceLibrary(name)
    if name == "AceLocale-2.2" then
        return { new = AceLocale_new }
    elseif name == "AceAddon-2.0" then
        return { new = AceAddon_new }
    elseif name == "HealComm-1.0" then
        return HealComm
    elseif name == "Gratuity-2.0" then
        return Gratuity
    elseif name == "RosterLib-2.0" then
        return RosterLib
    elseif name == "Compost-2.0" then
        return Compost
    else
        -- 未知库：给个万能空表兜底，避免直接报错让整个插件崩掉
        return WithNoOpFallback({})
    end
end
