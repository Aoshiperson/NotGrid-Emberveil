local L = NotGridLocale

-- ============================================================
-- NotGrid 主对象 + 原生事件/计时器系统（不再依赖 Ace2）
-- ============================================================
NotGrid = {}
NotGrid._handlers = {} -- [eventName] = handlerNameOrFunc
NotGrid._timers   = {} -- [timerName]  = {remaining=, interval=, repeating=, callback=}

local NotGridFrame = CreateFrame("Frame")

local function NotGrid_Dispatch(handler, ...)
    if type(handler) == "function" then
        return handler(NotGrid, ...)
    elseif type(handler) == "string" then
        local fn = NotGrid[handler]
        if fn then return fn(NotGrid, ...) end
    end
end

-- 真实游戏事件走 frame:RegisterEvent；自定义/虚拟事件(比如 RosterLib_RosterChanged)
-- 注册会失败(不是合法的游戏事件名)，用 pcall 吞掉，当作只能靠 TriggerEvent 手动触发的虚拟事件
function NotGrid:RegisterEvent(event, handler)
    self._handlers[event] = handler or event
    pcall(function() NotGridFrame:RegisterEvent(event) end)
end

function NotGrid:UnregisterEvent(event)
    self._handlers[event] = nil
    pcall(function() NotGridFrame:UnregisterEvent(event) end)
end

-- 虚拟事件：参数按普通 Lua 参数传给处理函数
function NotGrid:TriggerEvent(event, ...)
    local h = self._handlers[event]
    if h then NotGrid_Dispatch(h, ...) end
end

-- 真实游戏事件：本服客户端的事件参数走全局变量 event/arg1..arg9 传递，
-- 处理函数内部本来就是读这些全局变量，这里不需要转发任何参数
NotGridFrame:SetScript("OnEvent", function()
    local h = NotGrid._handlers[event]
    if h then NotGrid_Dispatch(h) end
end)

-- 计时器：用一个 OnUpdate 驱动，替代 ScheduleEvent/ScheduleRepeatingEvent/CancelScheduledEvent
-- 注意：这个客户端的 OnUpdate 脚本读不到 (self, elapsed) 参数，跟 OnEvent 一样得走
-- 全局变量 arg1 来拿距上一帧的时间间隔（1.12 时代的老式约定）
NotGridFrame:SetScript("OnUpdate", function()
    local elapsed = arg1
    for name, tm in pairs(NotGrid._timers) do
        tm.remaining = tm.remaining - elapsed
        if tm.remaining <= 0 then
            if tm.repeating then
                tm.remaining = tm.remaining + tm.interval
                if tm.remaining <= 0 then tm.remaining = tm.interval end
            else
                NotGrid._timers[name] = nil
            end
            tm.callback()
        end
    end
end)

-- :ScheduleEvent(name, delay)              -- 到时触发同名虚拟事件
-- :ScheduleEvent(name, callback, delay)    -- 到时调用 callback
function NotGrid:ScheduleEvent(name, a, b)
    local callback, delay
    if type(a) == "function" then
        callback, delay = a, b
    else
        delay = a
        callback = function() NotGrid:TriggerEvent(name) end
    end
    self._timers[name] = { remaining = delay or 0, interval = delay or 0, repeating = false, callback = callback }
end

function NotGrid:ScheduleRepeatingEvent(name, a, b)
    local callback, interval
    if type(a) == "function" then
        callback, interval = a, b
    else
        interval = a
        callback = function() NotGrid:TriggerEvent(name) end
    end
    interval = interval or 1
    self._timers[name] = { remaining = interval, interval = interval, repeating = true, callback = callback }
end

function NotGrid:CancelScheduledEvent(name)
    self._timers[name] = nil
end

-- 生命周期：ADDON_LOADED(本插件) -> OnInitialize -> OnEnable
-- (两个函数在下面才定义，但这里只是注册一个事件监听，真正调用要等 ADDON_LOADED 触发时，
--  那时整个插件的所有文件早就加载完了，所以晚定义没关系)
local NotGridLifecycle = CreateFrame("Frame")
NotGridLifecycle:RegisterEvent("ADDON_LOADED")
NotGridLifecycle:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "NotGrid" then
        if NotGrid.OnInitialize then NotGrid:OnInitialize() end
        if NotGrid.OnEnable then NotGrid:OnEnable() end
        NotGridLifecycle:UnregisterEvent("ADDON_LOADED")
    end
end)

-- ============================================================
-- RosterLib 替代：自己扫描花名册变化，触发 RosterLib_RosterChanged / RosterLib_UnitChanged
-- ============================================================
local NotGridRoster = { snapshot = {} }

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

local function NotGridRoster_ReadUnit(unit)
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

function NotGridRoster:GetUnitIDFromName(name)
    if not name then return nil end
    for _, unit in ipairs(ROSTER_UNITS) do
        local info = self.snapshot[unit]
        if info and info.name == name then
            return unit
        end
    end
    -- 兜底：花名册缓存没命中时现场查一遍
    for _, unit in ipairs(ROSTER_UNITS) do
        if UnitExists(unit) and UnitName(unit) == name then
            return unit
        end
    end
    return nil
end

local function NotGridRoster_Scan(fireEvents)
    local changedList = {}
    for _, unit in ipairs(ROSTER_UNITS) do
        local newInfo = NotGridRoster_ReadUnit(unit)
        local oldInfo = NotGridRoster.snapshot[unit]

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
            NotGridRoster.snapshot[unit] = newInfo

            if fireEvents then
                NotGrid:TriggerEvent("RosterLib_UnitChanged",
                    entry.unitid, entry.name, entry.class, entry.subgroup, entry.rank,
                    entry.oldname, entry.oldunitid, entry.oldclass, entry.uldsubgroup, entry.oldrank)
            end
        end
    end

    if fireEvents and #changedList > 0 then
        NotGrid:TriggerEvent("RosterLib_RosterChanged", changedList)
    end
end

local NotGridRosterFrame = CreateFrame("Frame")
NotGridRosterFrame:RegisterEvent("RAID_ROSTER_UPDATE")
NotGridRosterFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
NotGridRosterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
NotGridRosterFrame:SetScript("OnEvent", function()
    -- 每次都正常触发事件（包括登录后的第一次），这样玩家自己的血条/能量条
    -- 才会在登录时就被填上初始值，而不是要等到下一次花名册变化才刷新
    NotGridRoster_Scan(true)
end)

-- ============================================================
-- Compost 替代：简单对象池(不做真正的对象复用，只保证接口语义正确)
-- ============================================================
local NotGridCompost = {}
function NotGridCompost:Acquire(...)
    local t = {}
    local n = select('#', ...)
    for i = 1, n do
        t[i] = select(i, ...)
    end
    return t
end
function NotGridCompost:Reclaim(t)
    if type(t) == "table" then
        for k in pairs(t) do t[k] = nil end
    end
end

-- ============================================================
-- HealComm 替代（安全桩）：真正的跨玩家治疗预测需要全团队都用同一套通信协议
-- 互相广播读条信息，这里没有实现那一套，只保证接口不报错——治疗预估条/文本
-- 会一直是0，是刻意的功能降级，不是遗漏。以后想要真预测，需要单独做一套基于
-- SendAddonMessage 的私服内部协议。
-- ============================================================
local NotGridHealComm = setmetatable({}, { __index = function() return function() end end })
function NotGridHealComm:getHeal(name) return 0 end
function NotGridHealComm:UnitisResurrecting(name) return false end

NotGridOptions = {} -- 不持久化保存，每次登录都从 DefaultOptions 重新填充(见 options.lua)

-- 职业角色图标纹理坐标（Tank/Healer/DPS）
local ROLE_TEX_COORDS = {
    TANK = {0, 19/64, 22/64, 41/64},      -- 坦克（盾牌）
    HEALER = {20/64, 39/64, 1/64, 20/64}, -- 治疗（十字）
    DAMAGER = {20/64, 39/64, 22/64, 41/64} -- DPS（剑）
}

-- 极简仇恨数据存储
NotGrid.ThreatData = {}  -- 存储有仇恨的玩家，值为时间戳

-- 兼容性包装：获取单位的LFG角色
local function GetUnitLFGRole(unit)
    -- 检查团队中的主坦克/主助攻设置
    local index = NotGrid.raid_indexes and NotGrid.raid_indexes[unit]
    if index then
        local role = select(10, GetRaidRosterInfo(index))
        if role == "MAINTANK" then
            return "TANK"
        elseif role == "MAINASSIST" then
            return "DAMAGER"  -- 主助攻通常是DPS
        end
    end
    
    -- 检查小队中的主坦克/主助攻
    if GetPartyAssignment then
        if GetPartyAssignment("MAINTANK", unit) then
            return "TANK"
        elseif GetPartyAssignment("MAINASSIST", unit) then
            return "DAMAGER"
        end
    end
    
    return nil
end

function NotGrid:IsLeader(playerName)
	-- 检查是否有团队管理权限
    if GetNumRaidMembers() > 0 then
        -- 在团队中，检查是否为团长或助理
        for i = 1, GetNumRaidMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name == playerName and (rank == 2 or rank == 1) then
                return true
            end
        end
    elseif GetNumPartyMembers() > 0 then
        -- 在小队中，检查是否为队长
        if IsPartyLeader() then
            return true
        end
    end
	return false
end

-- 添加权限检查辅助函数
function NotGrid:CanSetRole(unitid)
    local playerName = UnitName("player")
    local targetName = UnitName(unitid)
    
    -- 玩家可以设置自己的职责
    if playerName == targetName then
        return true
    end
    
    local result = self:IsLeader(playerName)
    
    return result
end

function NotGrid:OnInitialize()
	self.HealComm = NotGridHealComm
	self.RosterLib = NotGridRoster
	self.Compost = NotGridCompost
	self.UnitFrames = {}
	self.PartyIndexFrames = {}
	self.ManualRoles = {} -- 手动设置的角色
	self.raid_indexes = {} -- 团队成员索引映射 (unitid -> raidIndex)
	--
	self.IdenticalUnits = {} -- will hold pairs of party/player/raidids that are the same effective unit. For use with rosterlib & healcomm stuff
	--proximity stuff
	self.ProximityVars = {} -- will hold vars related to proximity handling. Mostly world map stuff
	self:GetFortyYardSpell() -- queries the player's action bars for a 40 yard spell to use in proximity checking
	self:GetMapSizes() -- populate ProximityVars with mapsizes of server
	--
	self:CreateFrames()
    
    -- 初始化乌龟服TWT仇恨系统
    self:InitTWTThreatSystem()
end

-- 初始化乌龟服TWT仇恨系统
function NotGrid:InitTWTThreatSystem()
    -- 创建仇恨数据接收框架
    self.ThreatFrame = CreateFrame("Frame")
    self.ThreatFrame:RegisterEvent("CHAT_MSG_ADDON")
    
    self.ThreatFrame:SetScript("OnEvent", function()
        if event == "CHAT_MSG_ADDON" then
            -- arg1 = prefix, arg2 = message, arg3 = channel, arg4 = sender
            if arg1 == "TWT" and string.find(arg2, "TWTv4=") then
                NotGrid:HandleTWTThreatData(arg2)
            end
        end
    end)
end

-- 处理TWT仇恨数据（极简版）
function NotGrid:HandleTWTThreatData(data)
    -- TWTv4=格式: TWTv4=name1:threat1,percent1;name2:threat2,percent2;...
    local threatPart = string.gsub(data, "TWTv4=", "")
    local currentTime = GetTime()
    
    -- 解析数据，记录所有有仇恨的玩家
    for unitData in string.gmatch(threatPart, "([^;]+)") do
        local name = string.match(unitData, "([^:]+):")
        if name then
            -- 只需要记录更新时间，表示该玩家有仇恨
            self.ThreatData[name] = currentTime
        end
    end
    
    -- 清理过期数据（超过5秒未更新）
    for name, time in pairs(self.ThreatData) do
        if currentTime - time > 5 then
            self.ThreatData[name] = nil
        end
    end
    
    -- 更新所有边框状态
    self:UpdateAllThreatBorders()
end

-- 检查单位是否有仇恨（极简版）
function NotGrid:HasThreat(unitid)
    local name = UnitName(unitid)
    if not name then return false end
    
    -- 有记录且5秒内更新过就算有仇恨
    return self.ThreatData[name] ~= nil
end

-- 更新所有单位的边框状态
function NotGrid:UpdateAllThreatBorders()
    for unitid, _ in pairs(self.UnitFrames) do
        self:UNIT_BORDER(unitid)
    end
end

function NotGrid:OnEnable()
	self:SetDefaultOptions() -- 不再有存档，直接用 DefaultOptions 填充 NotGridOptions
	self.o = NotGridOptions
	self:ConfigUnitFrames()
	self:ConfigPartyIndexFrames()
	--proximity stuff
	self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "GetFortyYardSpell")
	for key in pairs(L.CombatEvents) do
		self:RegisterEvent(key, "CombatEventHandle")
	end
	--
	--
    self:UpdateLeaderIcon()
    self:UpdateDungeonRoleIcons()
    
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA","UpdateProximityMapVars")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED","BlizzFrameHandler")
	self:RegisterEvent("RAID_ROSTER_UPDATE","BlizzFrameHandler")
	self:RegisterEvent("UNIT_PET","BlizzFrameHandler")
	--RosterLib
	self:RegisterEvent("RosterLib_RosterChanged")
	self:RegisterEvent("RosterLib_UnitChanged")
	--Healcomm
	self:RegisterEvent("HealComm_Healupdate","HealCommHandler")
	self:RegisterEvent("HealComm_Ressupdate","HealCommHandler")
	--Proximity
	self:RegisterEvent("NG_UNIT_PROXIMITY","UNIT_PROXIMITY")
	self:ScheduleRepeatingEvent("NG_UNIT_PROXIMITY", self.o.proximityrate)

	self:RegisterEvent("CHAT_MSG_SYSTEM")

	-- 注册团队标记更新事件
    self:RegisterEvent("RAID_TARGET_UPDATE", "UpdateRaidMarkers")

    self:RegisterEvent("PARTY_LEADER_CHANGED","UpdateLeaderIcon")

	-- 注册队伍变化事件
	-- self:RegisterEvent("PARTY_MEMBERS_CHANGED", "HandlePartyChange")
	-- self:RegisterEvent("RAID_ROSTER_UPDATE", "HandlePartyChange")
	
	-- 初始化队伍状态
	self.wasInParty = (GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)
end

-- 过滤逻辑：在获取Debuff时，根据玩家职业判断该Debuff类型是否可驱散：
-- 牧师：可驱散魔法、疾病
-- 圣骑士：可驱散中毒、疾病、魔法
-- 萨满：可驱散中毒、疾病
-- 德鲁伊：可驱散中毒、诅咒
-- 法师：可驱散诅咒
function NotGrid:IsDebuffDispellableByPlayer(spelltype)
    if not spelltype then return false end
    
    local _, class = UnitClass("player")
    
    -- 根据TBC职业驱散能力判断
    if class == "PRIEST" then
        return spelltype == "Magic" or spelltype == "Disease"
    elseif class == "PALADIN" then
        return spelltype == "Poison" or spelltype == "Disease" or spelltype == "Magic"
    elseif class == "SHAMAN" then
        return spelltype == "Poison" or spelltype == "Disease"
    elseif class == "DRUID" then
        return spelltype == "Poison" or spelltype == "Curse"
    elseif class == "MAGE" then
        return spelltype == "Curse"
    end
    
    return false
end

---------------
-- UNIT_MAIN -- Handles the healthbar, healthtext, healcommbar, healcommtext, ressurection, nametext, classcolor..
---------------

function NotGrid:UNIT_MAIN(unitid)
	local o = self.o
	local f = self.UnitFrames[unitid]
	if o.configmode then
		unitid = "player"
	end

	if f and UnitExists(unitid) then
		DEFAULT_CHAT_FRAME:AddMessage("UNIT_MAIN调用: unit="..tostring(unitid).." 血量="..tostring(UnitHealth(unitid)).."/"..tostring(UnitHealthMax(unitid)).." 在线="..tostring(UnitIsConnected(unitid)))
		local name = UnitName(unitid)
		local _,class = UnitClass(unitid)
		local powertype = UnitPowerType(unitid)
		local pcolor = ManaBarColor[powertype]
		local color = {}

		if o.configmode then
			local c = {"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"}
			local id = string.sub(f.unit, -1)
			id = tonumber(id)
			if id == 0 then id = 1 end
			if id == 1 then
				pcolor = ManaBarColor[1]
			elseif id == 4 then
				pcolor = ManaBarColor[3]
			else
				pcolor = ManaBarColor[0]
			end
			class = c[id]
		end

		if f.pet and o.usepetcolor then
			color.r,color.g,color.b = unpack(o.petcolor)
		elseif class and class == "SHAMAN" then
			color = {r=0.14,g=0.35,b=1}
		elseif class then
			color = RAID_CLASS_COLORS[class]
		else
			color = {r=1,g=0,b=1}
		end

		--update some stuff
		f.name = name
		--handle coloring text
			f.healthbar:SetStatusBarColor(color.r, color.g, color.b, o.unithealthbarcolor[4])
			f.nametext:SetTextColor(color.r, color.g, color.b, o.unitnamehealthtextcolor[4])
--			f.hptext:SetTextColor(color.r, color.g, color.b, o.unitnamehealthtextcolor[4])
			f.healthbar.bgtex:SetVertexColor(color.r, color.g, color.b)
		    	f.powerbar:SetStatusBarColor(pcolor.r, pcolor.g, pcolor.b)
			f.powerbar.bgtex:SetVertexColor(pcolor.r, pcolor.g, pcolor.b)

		if UnitIsConnected(unitid) then
			local healamount, currhealth, maxhealth, deficit, healtext, currpower, maxpower
			if o.configmode then
				currhealth = UnitHealth(unitid)/2
				maxhealth = UnitHealthMax(unitid)
				deficit = maxhealth - currhealth
				currpower = UnitManaMax(unitid)/2
				maxpower = UnitManaMax(unitid)
				healamount = maxhealth/4
			else
				currhealth = UnitHealth(unitid)
				maxhealth = UnitHealthMax(unitid)
				deficit = maxhealth - currhealth
				currpower = UnitMana(unitid)
				maxpower = UnitManaMax(unitid)
				healamount = self.HealComm:getHeal(name)
			end


			healtext = string.format("+%d", healamount)
			
			f.healthbar:SetMinMaxValues(0, maxhealth)
			f.healthbar:SetValue(currhealth)

			f.powerbar:SetMinMaxValues(0, maxpower)
			f.powerbar:SetValue(currpower)

-- 死亡 / 灵魂状态
if UnitIsDead(unitid) then
    self:UnitHealthZero(f, L["Dead"])
	f.hptext:SetFont("Fonts\\FZLTLC.TTF", 12, "OUTLINE")


elseif UnitIsGhost(unitid) or (deficit >= maxhealth) then
    self:UnitHealthZero(f, L["Ghost"])
f.hptext:SetFont("Fonts\\FZLTLC.TTF", 12, "OUTLINE")


else
    -- 永远显示血量亏损（绿色）
    local deficittext = string.format("-%d", deficit)

    if deficit > 0 then
        f.hptext:SetText(deficittext)
    else
        f.hptext:SetFont("Fonts\\ledfont.TTF", 12, "OUTLINE")
        f.hptext:SetText("") -- 满血时清空
    end

    f.hptext:SetTextColor(0, 1, 0)
end

-- 姓名（保持 shortname）
f.nametext:SetText(name)
	

			if healamount > 0 then
	
					self:SetIncHealFrame(f, healamount, currhealth, maxhealth)
					f.healcommtext:SetText(healtext)
					f.healcommtext:Show()

			else
				f.incheal:SetBackdropColor(0,0,0,0) -- instead of hiding the frame, which is parent to healthtext&inchealtext, I set its opacity to 0
				f.healcommtext:Hide()
			end

			if self.HealComm:UnitisResurrecting(name) then
				f.incres:Show()
			else
				f.incres:Hide()
			end
		else
			self:UnitHealthZero(f, "离线")
		end
	end
end

function NotGrid:UnitHealthZero(f, state)
	f.hptext:SetText(state)
	f.incheal:SetBackdropColor(0,0,0,0) -- instead of hiding the frame, which is parent to healthtext&inchealtext, I set its opacity to 0
	f.healthbar:SetMinMaxValues(0, 1)
	f.healthbar:SetValue(0)
	f.powerbar:SetMinMaxValues(0, 1)
	f.powerbar:SetValue(0)
	f.healcommtext:Hide()
end

function NotGrid:SetIncHealFrame(f, healamount, currhealth, maxhealth) -- well this was easier than I was expecting it to be
	local o = self.o

		local modifier = maxhealth/o.unitwidth
		local healwidth = healamount/modifier
		local currwidth = currhealth/modifier
		local maxwidth = o.unitwidth-currwidth
		if maxwidth == 0 then return end
		if healwidth >= maxwidth then healwidth = maxwidth end
		f.incheal:SetWidth(healwidth)
		f.incheal:ClearAllPoints()
		f.incheal:SetPoint("LEFT",currwidth,0)

	local color = o.unithealcommbarcolor
	f.incheal:SetBackdropColor(color[1],color[2],color[3],color[4]) -- instead of hide/show I set opacity. Note that I can't use SetAlpha cause it will hide the child elements
end

---------------
-- UNIT_AURA --
---------------
function NotGrid:UNIT_AURA(unitid)
    local o = self.o
    local f = self.UnitFrames[unitid]
    if not (f and UnitExists(unitid)) then return end

   ---------------------------------------------------------
    -- 可驱散类型颜色
    ---------------------------------------------------------
    local dispelColors = {
        Magic   = {0.20, 0.60, 1.00},  -- 蓝
        Curse   = {0.60, 0.00, 1.00},  -- 紫
        Poison  = {0.00, 0.60, 0.00},  -- 绿
        Disease = {0.60, 0.40, 0.00},  -- 黄棕
    }

    ---------------------------------------------------------
    -- 清空旧图标
    ---------------------------------------------------------
    for i = 1, 4 do
        f.buffs[i]:Hide()
        f.debuffs[i]:Hide()
    end
    f.dispelFrame:Hide()

    ---------------------------------------------------------
    -- 扫描 Debuff
    ---------------------------------------------------------
    local debuffSlots = 0
    local buffSlots = 0
    local dispelType = nil

    for i = 1, 16 do
        if debuffSlots == 4 then break end

        local texture, count, debuffType = UnitDebuff(unitid, i)
        if not texture then break end

        debuffSlots = debuffSlots + 1
        f.debuffs[debuffSlots].texture:SetTexture(texture)
        f.debuffs[debuffSlots]:Show()

    if debuffType then
        local c = dispelColors[dispelType]
	f.dispel:SetTexture("Interface\\Buttons\\WHITE8x8")
        f.dispelFrame:SetVertexColor(c[1], c[2], c[3], 1)
        f.dispelFrame:Show()
    else
        f.dispelFrame:Hide()
    end
    end

    ---------------------------------------------------------
    -- 显示可驱散颜色框
    ---------------------------------------------------------

local ImportantTextures = {
    ["Interface\\Icons\\Spell_Holy_Excorcism"] = true,
    ["Interface\\Icons\\Spell_Nature_NullifyDisease"] = true,
    ["Interface\\Icons\\Spell_Holy_PowerWordShield"] = true,
    ["Interface\\Icons\\Spell_Holy_Renew"] = true,
}
-- 显示 Buff（填满剩余空位）
for i = 1, 32 do
    if buffSlots == 4 then break end

    local texture, name = UnitBuff(unitid, i)
    if not texture then break end

    if ImportantTextures[texture] then
        buffSlots = buffSlots + 1

        f.buffs[buffSlots].texture:SetTexture(texture)
        f.buffs[buffSlots]:Show()
    end
end
end

function NotGrid:CheckAura(i, auratable)
end

-----------------
-- UNIT_BORDER --
-----------------

function NotGrid:UNIT_BORDER(unitid)
	local o = self.o
	local f = self.UnitFrames[unitid]
	if f and UnitExists(unitid) then
		local name = UnitName(unitid)
		local targetname = UnitName("Target") -- could get erronous with pets
		local currmana = UnitMana(unitid)
		local maxmana = UnitManaMax(unitid)
		
		if  targetname and targetname == name then
			f.border:SetBackdropBorderColor(unpack(o.targetcolor))
			f.border.middleart:SetVertexColor(unpack(o.targetcolor))
		elseif o.trackaggro and self:HasThreat(unitid) then
			-- 使用原来的aggrowarningcolor
			f.border:SetBackdropBorderColor(unpack(o.aggrowarningcolor))
			f.border.middleart:SetVertexColor(unpack(o.aggrowarningcolor))
		elseif o.trackmana and UnitPowerType(unitid) == 0 and currmana/maxmana*100 < o.manathreshhold and not UnitIsDeadOrGhost(unitid) then
			f.border:SetBackdropBorderColor(unpack(o.manawarningcolor))
			f.border.middleart:SetVertexColor(unpack(o.manawarningcolor))
		else
			f.border:SetBackdropBorderColor(unpack(o.unitbordercolor))
			f.border.middleart:SetVertexColor(unpack(o.unitbordercolor))
		end
	end
end

-------------------
-- On Unit Click --
-------------------

-- 自定义菜单初始化函数，集成职责设置到标准UnitPopup菜单
function NotGrid:UnitPopup_Initialize(dropdownMenu)
    -- 获取当前菜单信息
    local unit = dropdownMenu.unit
    local name = dropdownMenu.name
    local unitName = UnitName(unit)
    local level = UIDROPDOWNMENU_MENU_LEVEL or 1
    
    -- 首先调用标准的菜单初始化（所有level都需要）
local menuType

-- 1. 自己
if unit == "player" then
    menuType = "SELF"
-- 2. 队伍成员
elseif string.match(unit, "^party%d+$") then
    menuType = "PARTY"
-- 3. 团队成员
elseif string.match(unit, "^raid%d+$") then
    menuType = "RAID"
-- 4. 目标是玩家（例如 target 指向玩家）
elseif UnitIsPlayer(unit) then
    menuType = "PLAYER"
-- 5. 其他情况（怪物、自定义单位 ng1/ng2）不显示菜单
else
    return
end
UnitPopup_ShowMenu(dropdownMenu, menuType, unit)
    
    -- 只在第一层菜单添加自定义选项
    if level == 1 then
        -- 检查是否有权限设置职责
        local canSetRole = self:CanSetRole(unit)
        
        -- 如果无权设置职责，直接返回
        if not canSetRole then
            return
        end

        -- 添加分隔线
        local info = {}
        info.text = ""
        info.isTitle = nil
        info.notCheckable = 1
        info.disabled = 1
        UIDropDownMenu_AddButton(info, level)
        
        -- 发起职责确认
		if NotGrid:IsLeader(UnitName("player")) then
			info = {}
			info.text = "  发起职责确认"
			info.func = function()
				if GetNumRaidMembers() > 0 then
					SendAddonMessage("NotGrid", "ROLESELECT", "RAID")
				elseif GetNumPartyMembers() > 0 then
					SendAddonMessage("NotGrid", "ROLESELECT", "PARTY")
				end
			end
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)
		end

        -- 添加分隔线
        info = {}
        info.text = ""
        info.isTitle = nil
        info.notCheckable = 1
        info.disabled = 1
        UIDropDownMenu_AddButton(info, level)
        
        -- 添加职责设置标题
        info = {}
        info.text = "设置职责"
        info.isTitle = 1
        info.notCheckable = 1
        UIDropDownMenu_AddButton(info, level)
        
        -- 设置职责函数
        local function SetRole(role)
            self.ManualRoles[unitName] = role
            self.o.manualroles[unitName] = role
            self:UpdateDungeonRoleIcons()
            
            -- 发送同步消息
            local message = "ROLE:" .. unitName .. ":" .. role
            if GetNumRaidMembers() > 0 then
                SendAddonMessage("NotGrid", message, "RAID")
            elseif GetNumPartyMembers() > 0 then
                SendAddonMessage("NotGrid", message, "PARTY")
            end
        end

        local _, class = UnitClass(unit)
		if not class then return end
		class = string.lower(class)
		
		-- 坦克选项
		if not (class == 'priest' or class == 'mage' or class == 'warlock' or class == 'hunter' or class == 'rogue') then
			info = {}
			info.text = " 坦克"
			info.func = function() SetRole("TANK") end
			info.checked = (self.ManualRoles[unitName] == "TANK")
			UIDropDownMenu_AddButton(info, level)
		end

		-- 治疗选项
		if not (class == 'warrior' or class == 'mage' or class == 'warlock' or class == 'hunter' or class == 'rogue') then
			info = {}
			info.text = " |cff00ff00治疗|r"
			info.func = function() SetRole("HEALER") end
			info.checked = (self.ManualRoles[unitName] == "HEALER")
			UIDropDownMenu_AddButton(info, level)
		end

        -- 伤害输出选项
        info = {}
        info.text = " |cfff40000伤害输出|r"
        info.func = function() SetRole("DAMAGER") end
        info.checked = (self.ManualRoles[unitName] == "DAMAGER")
        UIDropDownMenu_AddButton(info, level)
        
    end
end

-- 修改ClickHandle函数，集成到标准UnitPopup菜单
function NotGrid:ClickHandle(button)
    local unit = this and this.unit
    if not unit or not UnitExists(unit) then
        -- 点到的格子没有对应的实际单位(比如空的团队/小队槽位)，
        -- 之前这里不做检查直接 TargetUnit()/开菜单，在这个私服客户端上
        -- 对一个不存在的unit操作会直接把整个游戏搞崩，所以先挡住
        return
    end

    -- 如果正在施法目标，右键松开取消
    if button == "RightButton" and SpellIsTargeting() then
        SpellStopTargeting()
        return
    end

    -- 左键松开：选中单位
    if button == "LeftButton" then
        TargetUnit(unit)
        return
    end

    -- 右键松开：打开菜单
    if button == "RightButton" then
        local name = UnitName(unit)
        local menuFrame = FriendsDropDown

        menuFrame.displayMode = "MENU"
        menuFrame.unit = unit
        menuFrame.name = name

        menuFrame.initialize = function()
            self:UnitPopup_Initialize(_G[UIDROPDOWNMENU_OPEN_MENU])
        end

        ToggleDropDownMenu(1, nil, menuFrame, "cursor")
    end
end

----------------------------------
-- Miscellaneous Event Handling --
----------------------------------

-- Healcomm

function NotGrid:HealCommHandler(name) -- be nice if it sent us the unitid instead
	local unitid = self.RosterLib:GetUnitIDFromName(name)
	self:UNIT_MAIN(unitid)
	if self.IdenticalUnits[unitid] then
		self:UNIT_MAIN(self.IdenticalUnits[unitid])
	end
end

-- Roster

--blizz roster events fire for all sorts of frivilous(in our case) reasons creating unnecessary updates
--rosterlib cycles through units and sends ones that have changed, with what has changed, and we filter it from there as to whether we want to do anything with our frames
function NotGrid:RosterLib_RosterChanged(updatedUnits)
	-- 更新 raid_indexes 映射
	self:UpdateRaidIndexes()
	
	for _,val in ipairs(updatedUnits) do
		if not (val.unitid and string.find(val.unitid, "raidpet")) and not (val.oldunitid and string.find(val.oldunitid, "raidpet")) then -- if not raidpet, because we have no unitframes for them
			self:GetIdenticalUnits()
			self:ClearIndexFramePoint()
			
			self:PositionFrames()
			break -- break out of the loop after finding at least one unit we have a frame for
		end
	end
end

-- 更新团队成员索引映射
function NotGrid:UpdateRaidIndexes()
	wipe(self.raid_indexes)
	for i = 1, GetNumRaidMembers() do
		local unit = "raid" .. i
		if UnitExists(unit) then
			self.raid_indexes[unit] = i
		end
	end
end

function NotGrid:GetIdenticalUnits() -- party/raid pets?
	if GetNumRaidMembers() > 0 then
		self.Compost:Reclaim(self.IdenticalUnits)
		self.IdenticalUnits = self.Compost:Acquire()
		local playername = UnitName("player")
		for i=1,40 do
			if UnitExists("raid"..i) then
				local raidid = "raid"..i
				local raidname = UnitName(raidid)
				if playername == raidname then
					self.IdenticalUnits[raidid] = "player"
					self.IdenticalUnits["player"] = raidid
				end
				for i=1,4 do
					if UnitExists("party"..i) then
						local partyid = "party"..i
						local partyname = UnitName(partyid)
						if partyname == raidname then
							self.IdenticalUnits[raidid] = partyid -- store them both as their own keys referencing eachother
							self.IdenticalUnits[partyid] = raidid
						end
					end
				end
			end
		end
	elseif next(self.IdenticalUnits) then -- if theres data in the table, but we're not in raid, then wipe the table
		self.Compost:Reclaim(self.IdenticalUnits)
		self.IdenticalUnits = self.Compost:Acquire()
	end
end

function NotGrid:RosterLib_UnitChanged(unitid, name, class, subgroup, rank, oldname, oldunitid, oldclass, uldsubgroup, oldrank)
	if unitid and self.UnitFrames[unitid] then
		self:UNIT_MAIN(unitid)
		self:UNIT_BORDER(unitid)
		self:UNIT_AURA(unitid)
		if self.IdenticalUnits[unitid] then
			self:UNIT_MAIN(self.IdenticalUnits[unitid])
			self:UNIT_BORDER(self.IdenticalUnits[unitid])
			self:UNIT_AURA(self.IdenticalUnits[unitid])
		end
	end
	-- 如果rank发生变化，更新队长标记
	if rank ~= oldrank then
		self:UpdateLeaderIcon()
	end
	-- 更新职业角色图标
	self:UpdateDungeonRoleIcons()
end


-- Blizz Events

function NotGrid:PLAYER_ENTERING_WORLD() -- when they login,reloadui,or zone in/out of instances

	self:UpdateProximityMapVars() -- zoning into an instance won't trigger a zonechange event if the outdoors name is the same name as the indoors. This ensures the vars update.
	self:BlizzFrameHandler()
end

function NotGrid:CHAT_MSG_ADDON()
	if arg1 == "NotGrid" then
		if self.o.versionchecking and tonumber(arg2) then
			if tonumber(arg2) > self.o.version and not self.versionalreadyshown then
				DEFAULT_CHAT_FRAME:AddMessage("|cff0ccca6NotGrid:|r A newer version may be available.")
				self.versionalreadyshown = true
			end
		elseif string.find(arg2, "ROLE:") then
			-- 处理角色同步消息：格式为 "ROLE:玩家名字:角色类型"
			local _, _, name, role = string.find(arg2, "ROLE:(.+):(.+)")
			if name then
				local hasPermission = false
				
				-- 情况1：是自己发送的消息（本地回显）
				if arg4 == UnitName("player") then
					hasPermission = true
				-- 情况2：发送者在设置自己的角色（允许）
				elseif arg4 == name then
					hasPermission = true
				-- 情况3：发送者是队长/团长/助理（允许设置他人角色）
				else
					if GetNumRaidMembers() > 0 then
						-- 在团队中，检查 rank
						for i = 1, GetNumRaidMembers() do
							local raidName, rank = GetRaidRosterInfo(i)
							if raidName == arg4 and (rank == 2 or rank == 1) then
								hasPermission = true
								break
							end
						end
					elseif GetNumPartyMembers() > 0 then
						-- 在小队中，检查是否为队长
						for i = 1, GetNumPartyMembers() do
							if UnitName("party"..i) == arg4 and UnitIsPartyLeader("party"..i) then
								hasPermission = true
								break
							end
						end
						-- 检查玩家自己是否是队长
						if UnitName("player") == arg4 and IsPartyLeader() then
							hasPermission = true
						end
					end
				end
				
				if hasPermission then
					if role == "nil" then
						-- 清除角色设置
						self.ManualRoles[name] = nil
						self.o.manualroles[name] = nil
					elseif role == "TANK" or role == "HEALER" or role == "DAMAGER" then
						-- 设置角色
						self.ManualRoles[name] = role
						self.o.manualroles[name] = role
					end
					self:UpdateDungeonRoleIcons()
				end
			end
		elseif string.find(arg2, "ROLESELECT") then
			if self.o.showdungeonrole then
				if not NotGridRoleSelectionFrame then
					self:CreateRoleSelectionWindow()
				end
				NotGridRoleSelectionFrame:ShowWithCountdown()
			end
		end
	end
end

--have to handle the blizzframes seperately because rosterlib only fires if a member changed, wheras PARTY_MEMBERS_CHANGED fires for loot and other reasons as well
function NotGrid:BlizzFrameHandler() -- called by PLAYER_ENTERING_WORLD,PARTY_MEMBER_CHANGED,RAID_ROSTER_UPDATE,UNIT_PET,and NotGridOptionChange()
	for i=1,GetNumPartyMembers() do -- this isn't perfect because, for example, if partycount were at 0 it just wouldn't run and wouldn't hide any remaining frames. But blizz's code handles hiding it natively on member leave so I won't worry about it.
		if (GetNumRaidMembers() > 0) then
            if self.o.showblizzframesInRaid then
                _G["PartyMemberFrame"..i]:Show();
            else
                _G["PartyMemberFrame"..i]:Hide();
            end
        else
            if self.o.showblizzframesInParty then
                _G["PartyMemberFrame"..i]:Show();
            else
                _G["PartyMemberFrame"..i]:Hide();
            end
        end
	end
    self:UpdateLeaderIcon()
    self:UpdateDungeonRoleIcons()
	self:HandlePartyChange()
end

local leaderUnit = nil

function NotGrid:UpdateLeaderIcon()
    local raidCount = GetNumRaidMembers()
    local partyCount = GetNumPartyMembers()
    if raidCount > 0 then
        for i=1, raidCount do
            local name, rank = GetRaidRosterInfo(i)
            local uf = self.UnitFrames["raid"..i]
            if uf and uf.leader then
                if rank == 2 then
                    uf.leader:Show()
                else
                    uf.leader:Hide()
                end
            end
        end
    else
        if partyCount > 0 then
			-- 只使用下面if中的else部分会有bug，必须配合CHAT_MSG_SYSTEM事件更新leaderUnit才行。
			local playerFrame = self.UnitFrames["player"]
			if leaderUnit then
				if playerFrame and playerFrame.leader then playerFrame.leader:Hide() end
				for i=1, partyCount do
					local uf = self.UnitFrames["party"..i]
					if uf and uf.leader then uf.leader:Hide() end
				end
				local leaderFrame = self.UnitFrames[leaderUnit]
				if leaderFrame and leaderFrame.leader then leaderFrame.leader:Show() end
			else
				if playerFrame and playerFrame.leader then
					if IsPartyLeader() then
						playerFrame.leader:Show()
					else
						playerFrame.leader:Hide()
					end
				end
				for i=1, partyCount do
					local uf = self.UnitFrames["party"..i]
					if uf and uf.leader then
						if UnitIsPartyLeader("Party"..i) then
							uf.leader:Show()
						else
							uf.leader:Hide()
						end
					end
				end
			end
		end
	end
end

function NotGrid:CHAT_MSG_SYSTEM()
	if GetNumRaidMembers() > 0 or (string.find(arg1,"离开了队伍") and GetNumPartyMembers() == 0) then
		leaderUnit = nil
		return
	end
	if not string.find(arg1, "现在是队长") then return end
	leaderName = string.gsub(arg1,"现在是队长", "")
	if leaderName == "你" then
		leaderUnit = "player"
	else
		for i=1,GetNumPartyMembers() do
			if UnitName("party"..i) == leaderName then
				leaderUnit = "party"..i
			end
		end
	end
	-- 队长变更后立即更新图标
	self:UpdateLeaderIcon()
end

function NotGrid:UpdateRaidMarkers()
    for unitid, f in pairs(self.UnitFrames) do
        if UnitExists(unitid) then
            -- self:UNIT_MAIN(unitid)  -- 调用 UNIT_MAIN 函数更新标记
            -- 新增团队标记更新逻辑
        local markerIndex = GetRaidTargetIndex(unitid)
        if markerIndex then
            local markerTexture = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
            local markerTexCoord = {
                [1] = {0, 0.25, 0, 0.25},  	-- 星星
                [2] = {0.25, 0.5, 0, 0.25},	-- 大饼
                [3] = {0.5, 0.75, 0, 0.25},	-- 三角
                [4] = {0.75, 1, 0, 0.25},  	-- 月亮
                [5] = {0, 0.25, 0.25, 0.5},	-- 方块
                [6] = {0.25, 0.5, 0.25, 0.5},	-- 红叉
                [7] = {0.5, 0.75, 0.25, 0.5},	-- 紫菱
                [8] = {0.75, 1, 0.25, 0.5}		-- 骷髅
            }
            local texCoord = markerTexCoord[markerIndex] or {0, 0, 0, 0}
            f.healthbar.raidmarker:SetTexture(markerTexture)
            f.healthbar.raidmarker:SetTexCoord(unpack(texCoord))
            f.healthbar.raidmarker:SetAlpha(0.8)
            f.healthbar.raidmarker:Show()
        else
            f.healthbar.raidmarker:Hide()
        end
        end
    end
end

-- 获取单位的角色（优先使用手动设置）
function NotGrid:GetUnitRole(unitid)
    local name = UnitName(unitid)
    
    -- 1. 优先使用手动设置的角色
    if name and self.ManualRoles and self.ManualRoles[name] then
        return self.ManualRoles[name]
    end
    
    -- 2. 尝试从 LFG 系统获取角色（Turtle WoW 自定义功能）
    local lfgRole = GetUnitLFGRole(unitid)
    if lfgRole then
        return lfgRole
    end
    
    return nil
end

-- 同步角色设置到团队
function NotGrid:SyncRoleToRaid(name, role)
	if not name or not role then return end
	
	-- 构造消息：ROLE:玩家名字:角色类型
	local message = "ROLE:" .. name .. ":" .. role
	
	-- 发送到团队或小队
	if GetNumRaidMembers() > 0 then
		SendAddonMessage("NotGrid", message, "RAID")
	elseif GetNumPartyMembers() > 0 then
		SendAddonMessage("NotGrid", message, "PARTY")
	end
end

-- 更新职业角色图标（Tank/Healer/DPS）
function NotGrid:UpdateDungeonRoleIcons()
    local o = self.o
    if not o then return end  -- 安全检查
    
    if not o.showdungeonrole then
        -- 如果禁用，隐藏所有图标
        for unitid, f in pairs(self.UnitFrames) do
            if f.dungeon_role then f.dungeon_role:Hide() end
        end
        return
    end
    
    for unitid, f in pairs(self.UnitFrames) do
        if f and f.dungeon_role then  -- 添加 f 的检查
            if UnitExists(unitid) then
                local role = self:GetUnitRole(unitid)
                if role then
                    local coords = ROLE_TEX_COORDS[role]
                    if coords then
                        f.dungeon_role.icon:SetTexCoord(unpack(coords))
                        f.dungeon_role:Show()
                    else
                        f.dungeon_role:Hide()
                    end
                else
                    f.dungeon_role:Hide()
                end
            else
                f.dungeon_role:Hide()
            end
        end
    end
end

--渐隐按钮
function NotGrid:EnableAutohide(frame, timeout)
	if not frame then return end

	frame.hover = frame.hover or CreateFrame("Frame", frame:GetName() .. "Autohide", frame)
	frame.hover:SetParent(frame)
	frame.hover:SetAllPoints(frame)
	frame.hover.parent = frame
	frame.hover:Show()

	local timeout = timeout
	frame.hover:SetScript("OnUpdate", function()
		if MouseIsOver(this, 50, -50, -50, 50) then
			this.activeTo = GetTime() + timeout
			this.parent:SetAlpha(1)
		elseif this.activeTo then
			if this.activeTo < GetTime() and this.parent:GetAlpha() > 0 then
				this.parent:SetAlpha(this.parent:GetAlpha() - 0.1)
			end
		else
			this.activeTo = GetTime() + timeout
		end
	end)
end


function checkRoleCompatibility(role)
	local ROLE_BAD_TOOLTIP = '您的职业可能无法完成这个职位.'
	local _, class = UnitClass("player")
	if not class then return end
	class = string.lower(class)
	if role == 'TANK' and (class == 'priest' or class == 'mage' or class == 'warlock' or class == 'hunter' or class == 'rogue') then
		GameTooltip:AddLine(ROLE_BAD_TOOLTIP, 1, 0, 0);
	end
	if role == 'HEALER' and (class == 'warrior' or class == 'mage' or class == 'warlock' or class == 'hunter' or class == 'rogue') then
		GameTooltip:AddLine(ROLE_BAD_TOOLTIP, 1, 0, 0);
	end
end

-- 创建职责选择窗口
function NotGrid:CreateRoleSelectionWindow()
	local f = CreateFrame("Frame", "NotGridRoleSelectionFrame", UIParent)
	f:SetWidth(300)
	f:SetHeight(200)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
		tile = true, tileSize = 16, edgeSize = 16, 
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	f:SetBackdropColor(0, 0, 0, 0.9)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	
	-- 标题
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.title:SetPoint("TOP", f, "TOP", 0, -15)
	f.title:SetText("选择你的职责")
	
	-- 倒计时文本
	f.countdown = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.countdown:SetPoint("TOP", f.title, "BOTTOM", 0, -10)
	f.countdown:SetText("剩余时间: 20秒")
	
	-- 职责按钮容器
	f.buttonContainer = CreateFrame("Frame", nil, f)
	f.buttonContainer:SetWidth(250)
	f.buttonContainer:SetHeight(80)
	f.buttonContainer:SetPoint("CENTER", f, "CENTER", 0, 0)
	
	-- 职责按钮
	local roles = {
		{text = "坦克", role = "TANK", texCoord = {0, 19/64, 22/64, 41/64}, path = "Interface\\AddOns\\NotGrid\\media\\tank", tooltip = '职位：坦克.'},
		{text = "治疗", role = "HEALER", texCoord = {20/64, 39/64, 1/64, 20/64}, path = "Interface\\AddOns\\NotGrid\\media\\healer", tooltip = '职位：治疗.'},
		{text = "伤害输出", role = "DAMAGER", texCoord = {20/64, 39/64, 22/64, 41/64}, path = "Interface\\AddOns\\NotGrid\\media\\damage", tooltip = '职位:伤害输出.'}
	}
	
	

	f.roleButtons = {}
	f.checkButtons = {}
	
	for i, roleInfo in ipairs(roles) do
		-- 创建按钮容器
		local container = CreateFrame("Frame", nil, f.buttonContainer)
		container:SetWidth(70)
		container:SetHeight(70)
		container:SetPoint("LEFT", f.buttonContainer, "LEFT", (i-1)*80 + 5, 0)
		
		-- 创建图标按钮
		local btn = CreateFrame("Button", nil, container)
		btn:SetWidth(60)
		btn:SetHeight(60)
		btn:SetPoint("CENTER", container, "CENTER", 0, 0)
		btn:SetID(i)
		
		-- 图标
		btn.icon = btn:CreateTexture(nil, "ARTWORK")
		btn.icon:SetTexture(roleInfo.path)
		btn.icon:SetAllPoints()
		
		-- 文本
		btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		btn.text:SetPoint("BOTTOM", btn, "BOTTOM", 0, -15)
		btn.text:SetText(roleInfo.text)
		
		-- 高亮效果
		btn:SetScript("OnEnter", function()
			if f.selectedRole ~= this:GetID() then
				-- btn.icon:SetVertexColor(1, 1, 0.7)
				GameTooltip:SetOwner(this,"ANCHOR_RIGHT")
				GameTooltip:SetText(roles[this:GetID()].tooltip)
				checkRoleCompatibility(roles[this:GetID()].role)
				GameTooltip:Show()
			end
		end)
		
		btn:SetScript("OnLeave", function()
			if f.selectedRole ~= this:GetID() then
				-- btn.icon:SetVertexColor(1, 1, 1)
				GameTooltip:Hide()
			end
		end)
		
		btn:SetScript("OnClick", function()
			container:SelectRole(this:GetID())
		end)
		
		-- 创建CheckButton
		local checkBtn = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
		checkBtn:SetWidth(20)
		checkBtn:SetHeight(20)
		checkBtn:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
		checkBtn:SetID(i)
		-- 设置CheckButton的纹理
		checkBtn:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
		checkBtn:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
		checkBtn:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
		checkBtn:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
		checkBtn:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
		
		checkBtn:SetScript("OnClick", function()
			container:SelectRole(this:GetID())
		end)
		
		-- 容器的选择函数
		container.SelectRole = function(self, roleIndex)
			f:SelectRole(roleIndex)
		end
		
		btn.roleIndex = i
		checkBtn.roleIndex = i
		container.roleIndex = i
		
		f.roleButtons[i] = btn
		f.checkButtons[i] = checkBtn
	end


	
	-- 确认按钮
	f.confirmBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.confirmBtn:SetWidth(80)
	f.confirmBtn:SetHeight(25)
	f.confirmBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
	f.confirmBtn:SetText("确认")
	f.confirmBtn:SetScript("OnClick", function()
		f:ConfirmSelection()
	end)
	
	-- 取消按钮
	f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.cancelBtn:SetWidth(80)
	f.cancelBtn:SetHeight(25)
	f.cancelBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
	f.cancelBtn:SetText("取消")
	f.cancelBtn:SetScript("OnClick", function()
		f:CancelSelection()
	end)

	-- 选择职责函数
	f.SelectRole = function(self, index)
		-- 更新选中状态
		f.selectedRole = index
		
		-- 更新所有CheckButton和图标状态
		for i, checkBtn in ipairs(f.checkButtons) do
			local btn = f.roleButtons[i]
			if i == index then
				-- 选中状态
				checkBtn:SetChecked(true)
				-- btn.icon:SetVertexColor(1, 1, 0.5) -- 高亮颜色
			else
				-- 未选中状态
				checkBtn:SetChecked(false)
				-- btn.icon:SetVertexColor(1, 1, 1) -- 正常颜色
			end
		end
	end

	-- 确认选择函数
	f.ConfirmSelection = function(self)
		if self.selectedRole then
			local playerName = UnitName("player")
			local roles = {"TANK", "HEALER", "DAMAGER"}
			local selectedRole = roles[self.selectedRole]
			
			-- 使用原有的ROLE消息格式
			local message = "ROLE:" .. playerName .. ":" .. selectedRole
			
			-- 发送到团队或小队
			if GetNumRaidMembers() > 0 then
				SendAddonMessage("NotGrid", message, "RAID")
			elseif GetNumPartyMembers() > 0 then
				SendAddonMessage("NotGrid", message, "PARTY")
			end
			
			-- 设置本地角色
			NotGrid.ManualRoles[playerName] = selectedRole
			NotGrid.o.manualroles[playerName] = selectedRole
			NotGrid:UpdateDungeonRoleIcons()
		end
		self:Hide()
		NotGrid:CancelScheduledEvent("RoleSelectionCountdown")
	end
	
	-- 取消选择函数
	f.CancelSelection = function(self)
		-- local playerName = UnitName("player")
		
		-- -- 使用原有的ROLE消息格式，表示清除角色设置
		-- local message = "ROLE:" .. playerName .. ":nil"

		-- -- 发送到团队或小队
		-- if GetNumRaidMembers() > 0 then
		-- 	SendAddonMessage("NotGrid", message, "RAID")
		-- elseif GetNumPartyMembers() > 0 then
		-- 	SendAddonMessage("NotGrid", message, "PARTY")
		-- end
		
		-- -- 清除本地角色设置
		-- NotGrid.ManualRoles[playerName] = nil
		-- NotGrid.o.manualroles[playerName] = nil
		-- NotGrid:UpdateDungeonRoleIcons()
		
		self:Hide()

		NotGrid:CancelScheduledEvent("RoleSelectionCountdown")
	end

	-- 显示并开始倒计时（含职业过滤）
	f.ShowWithCountdown = function(self)
		self:Show()
		self.timeLeft = 20
		local playerName = UnitName("player")
		local _, class = UnitClass("player")

		-- 1) 本职业可担任哪些职责
		local available = {}
		if class == "WARRIOR" then
			available.TANK = true
			available.DAMAGER = true
		elseif class == "PRIEST" then
			available.HEALER = true
			available.DAMAGER = true
		elseif class == "DRUID" then
			available.TANK = true
			available.HEALER = true
			available.DAMAGER = true
		elseif class == "PALADIN" then
			available.TANK = true
			available.HEALER = true
			available.DAMAGER = true
		elseif class == "SHAMAN" then
			available.HEALER = true
			available.DAMAGER = true
		elseif class == "MAGE" or class == "WARLOCK" or class == "ROGUE" or class == "HUNTER" then
			available.DAMAGER = true
		else
			-- 未知职业默认只能打 DPS
			available.DAMAGER = true
		end

		-- 2) 把“可选”映射到索引
		local roles = {"TANK", "HEALER", "DAMAGER"}
		local idxAvailable = {}
		for i, r in ipairs(roles) do idxAvailable[i] = available[r] end

		-- 3) 如果之前手动选了一个本职业干不了的，清掉并同步
		local currRole = NotGrid.ManualRoles[playerName]
		if currRole and not available[currRole] then
			NotGrid.ManualRoles[playerName] = nil
			NotGrid.o.manualroles[playerName] = nil
			local nilMsg = "ROLE:" .. playerName .. ":nil"
			if GetNumRaidMembers() > 0 then
				SendAddonMessage("NotGrid", nilMsg, "RAID")
			elseif GetNumPartyMembers() > 0 then
				SendAddonMessage("NotGrid", nilMsg, "PARTY")
			end
			NotGrid:UpdateDungeonRoleIcons()
		end

		-- 4) 重置界面：灰掉不可选，解锁可选
		self.selectedRole = nil
		for i = 1, 3 do
			local btn   = self.roleButtons[i]
			local check = self.checkButtons[i]
			if idxAvailable[i] then
				-- 可用
				btn.icon:SetVertexColor(1, 1, 1)
				btn:EnableMouse(true)
				btn:Enable()
				check:Enable()
				check:SetAlpha(1)
			else
				-- 不可用
				btn.icon:SetVertexColor(0.35, 0.35, 0.35)   -- 灰度
				-- btn:EnableMouse(false)
				btn:Disable()
				check:Disable()
				check:SetAlpha(0.4)
				check:SetChecked(false)
			end
			check:SetChecked(false)   -- 先全部不勾选
		end

		-- 5) 开始 20 s 倒计时
		NotGrid:CancelScheduledEvent("RoleSelectionCountdown")
		self.countdown:SetText("剩余时间: 20秒")
		NotGrid:ScheduleRepeatingEvent("RoleSelectionCountdown", function()
			self.timeLeft = self.timeLeft - 1
			if self.timeLeft > 0 then
				self.countdown:SetText("剩余时间: " .. self.timeLeft .. "秒")
			else
				self:CancelSelection()   -- 超时自动取消
			end
		end, 1)
	end

	f:Hide()
	return f
end

--------------------------------------------------
-- 1. 统一清除所有手动职责（自己+被他人设置）
--------------------------------------------------
function NotGrid:ClearAllManualRoles()
    -- 内存表
    self.ManualRoles = {}
    -- 存档表
    if self.o and self.o.manualroles then
        self.o.manualroles = {}
    end
    self:UpdateDungeonRoleIcons()
end

--------------------------------------------------
-- 2. 离队触发
--------------------------------------------------
function NotGrid:HandlePartyChange()
    local wasInParty = self.wasInParty or false
    local isInParty  = (GetNumPartyMembers()>0) or (GetNumRaidMembers()>0)

    if wasInParty and not isInParty then
        -- 离开队伍/团队：清掉全部手动职责
        self:ClearAllManualRoles()
    elseif not wasInParty and isInParty then
        -- 刚加入：弹出选择窗口（只在显示职责图标时）
        self:ScheduleEvent("ShowRoleSelection", function()
            if self.o.showdungeonrole then
                if not NotGridRoleSelectionFrame then
                    self:CreateRoleSelectionWindow()
                end
                NotGridRoleSelectionFrame:ShowWithCountdown()
            end
        end, 1)
    end
    self.wasInParty = isInParty
end
