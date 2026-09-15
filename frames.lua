---------------------
-- Creating Frames --
---------------------

function NotGrid:CreateFrames()
    self.Container = self:CreateContainerFrame()
    for i = 1, 40 do
        self.UnitFrames["raid" .. i] = self:CreateUnitFrame("raid" .. i, i)
    end
    for i = 1, 4 do
        self.UnitFrames["party" .. i] = self:CreateUnitFrame("party" .. i)
    end
    for i = 1, 4 do
        self.UnitFrames["partypet" .. i] = self:CreateUnitFrame("partypet" .. i)
    end
    self.UnitFrames["player"] = self:CreateUnitFrame("player")
    self.UnitFrames["pet"] = self:CreateUnitFrame("pet")
    for i = 1, 10 do
        self.PartyIndexFrames["partyindex" .. i] = self:CreatePartyIndexFrame("partyindex" .. i)
    end
end

function NotGrid:CreateContainerFrame()
    local f = CreateFrame("Frame", "NotGridContainer", UIParent)
    f:SetWidth(1)
    f:SetHeight(1)
    -- f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = true, tileSize = 16, edgeSize = 10})
    f:SetMovable(true)
    f:SetPoint("CENTER", 40, -40)
    return f
end

function NotGrid:CreatePartyIndexFrame(partyindex)
    local f = CreateFrame("Frame", "$parent" .. partyindex, self.Container) -- self.Container)
    f.TextString = f:CreateFontString("partyindex", "OVERLAY")
f.TextString:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    local index = tonumber(string.match(partyindex, "%d+"))
    f.index = index
    return f
end

function NotGrid:ToggleFrameShowHide()
    local f = getglobal("NotGridContainer")
    if f:IsVisible() then
        f:Hide()
    else
        f:Show()
    end
end

function NotGrid:CreateUnitFrame(unitid, raidindex)
    local f = CreateFrame("Button", "$parent" .. unitid, self.Container)
    f.unit = unitid
    f.lastseen = GetTime()      -- we set this at creation, so we don't have to config frame as out of range alpha by default
    if raidindex then
        f.raidindex = raidindex -- :^)
    end
    if string.find(unitid, "pet") then
        f.pet = true -- so I have a boolean to check against
    end
   --[[ 
    -- 强化 NotGrid 单位框的鼠标指向高亮
local hl = f:CreateTexture(nil, "OVERLAY", nil, 7)
hl:SetTexture("Interface\\Buttons\\WHITE8x8")
hl:SetVertexColor(1, 1, 0, 0.25)
f:SetHighlightTexture(hl)
]]--

    f.border = CreateFrame("Frame", "$parentborder", f) -- make a seperate frame for the edgefile/border for better customization possibilities
    f.border.middleart = f.border:CreateTexture("NGArtworkMiddle", "ARTWORK")

    f.healthbar = CreateFrame("StatusBar", "$parenthealthbar", f)
    f.healthbar.bgtex = f.healthbar:CreateTexture("$parentbgtex", "BACKGROUND")

    -- 新增团队标记
    f.healthbar.raidmarker = f.healthbar:CreateTexture("$parentraidmarker", "OVERLAY")
    f.healthbar:EnableMouse(false)

    f.powerbar = CreateFrame("StatusBar", "$parenthealthbar", f)
    f.powerbar:EnableMouse(false)
    f.powerbar.bgtex = f.powerbar:CreateTexture("$parentbgtex", "BACKGROUND")

    f.incres = CreateFrame("Frame", "$parentresicon", f.healthbar)
    f.incres.bgtex = f.incres:CreateTexture("$parentbgtex", "BACKGROUND")

    f.incheal = CreateFrame("Frame", "$parenthealcommbar", f.healthbar) -- Was using a statusbar behind the health frame but when the frame's alpha is low this would be seen through it

    -- I was having problems with incheal covering up these fontstrings. My soluction is to parent them to the incheal, but set the relative point to the healthbar. And instead of hide/show the incheal I just lower/higher its color opacity
    f.nametext = f.incheal:CreateFontString("$parentnamehealthtext", "OVERLAY")
    f.hptext = f.incheal:CreateFontString("$parentnamehealthtext", "OVERLAY")
    f.healcommtext = f.incheal:CreateFontString("$parenthealcommtext", "OVERLAY")

    f.leader = CreateFrame("Frame", "$parentleader", f)
    f.leader.icon = f.leader:CreateTexture("leaderIcon", "OVERLAY")

    -- 新增：职责图标（Tank/Healer/DPS）
    f.dungeon_role = CreateFrame("Frame", "$parentdungeonrole", f)
    f.dungeon_role.icon = f.dungeon_role:CreateTexture("dungeonroleIcon", "OVERLAY")


-- 创建一个独立的图标框体
f.dispelFrame = CreateFrame("Frame", nil, f)
f.dispelFrame:SetFrameStrata("TOOLTIP")   -- 永远在最上层
f.dispelFrame:SetWidth(6)
f.dispelFrame:SetHeight(6)
f.dispelFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

-- 图标贴图
f.dispel = f.dispelFrame:CreateTexture(nil, "ARTWORK")
f.dispel:SetAllPoints()
f.dispel:SetTexture("Interface\\Buttons\\WHITE8x8")
--f.dispel:SetTexture("Interface\\Icons\\Spell_Holy_Excorcism")
--f.dispel:SetVertexColor(0, 0.4, 1, 1)   -- 染成蓝色
--f.dispel:texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
f.dispelFrame:Hide()


f.buffs = {}
for i = 1, 4 do
	local b = CreateFrame("Button", nil, f)
		b:SetFrameStrata("TOOLTIP")
		b:SetWidth(8)
		b:SetHeight(8)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(i*8-8))

		b.texture = b:CreateTexture(nil, "ARTWORK")
		b.texture:SetAllPoints(b)
		b.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

--		b.count = b:CreateFontString(nil, "OVERLAY")
--		b.count:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
--		b.count:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:Hide()
	f.buffs[i] = b
	end


f.debuffs = {}
for i = 1, 4 do
    local d = CreateFrame("Button", nil, f)
    d:SetFrameStrata("TOOLTIP")
    d:SetWidth(8)
    d:SetHeight(8)

    -- 右下角开始，向左排列
    d:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(i*8-8), 2)

    d.texture = d:CreateTexture(nil, "ARTWORK")
    d.texture:SetAllPoints(d)
    d.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    d:Hide()
    f.debuffs[i] = d
end

    --scripts and stuff
    f:RegisterForClicks("LeftButtonDown", "RightButtonDown", "MiddleButtonDown", "Button4Down", "Button5Down") -- somehow I recall this not matterign?
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnClick", function()
            -- 用 pcall 包一层，避免这里万一出问题直接把整个客户端带崩
            local ok, err = pcall(function() self:ClickHandle(arg1) end)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NotGrid点击处理出错:|r " .. tostring(err))
            end
    end)
    f:SetScript("OnEnter", function()
        if UnitAffectingCombat("player") and self.o.disablemouseoverincombat then
            return
        end

        UnitFrame_OnEnter() -- a blizzard function that handles the tooltip for the unit
    end)
    f:SetScript("OnLeave", function()
        UnitFrame_OnLeave() -- blizz function that handles tooltip for units
    end)

    f:SetScript("OnDragStart", function() -- on drag of any unit frame will drag the NotGridContainer frame
        if self.o.draggable then
            self.Container:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function()
        if self.o.draggable then
            self.Container:StopMovingOrSizing()
            local _, _, _, x, y = self.Container:GetPoint()
            self.o.containeroffx = math.floor(x)
            self.o.containeroffy = math.floor(y)
        end
    end)

    --we can split these up into their own relative frames & functions later
    --might as well
    f:RegisterEvent("UNIT_NAME_UPDATE")
    f:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    --healthbar
    f:RegisterEvent("UNIT_HEALTH")
    f:RegisterEvent("UNIT_MAXHEALTH")
    --manabar
    f:RegisterEvent("UNIT_MANA")
    f:RegisterEvent("UNIT_RAGE")
    f:RegisterEvent("UNIT_FOCUS")
    f:RegisterEvent("UNIT_ENERGY")
    f:RegisterEvent("UNIT_HAPPINESS")
    f:RegisterEvent("UNIT_MAXMANA")
    f:RegisterEvent("UNIT_MAXRAGE")
    f:RegisterEvent("UNIT_MAXFOCUS")
    f:RegisterEvent("UNIT_MAXENERGY")
    f:RegisterEvent("UNIT_MAXHAPPINESS")
    f:RegisterEvent("UNIT_DISPLAYPOWER")
    --aura
    f:RegisterEvent("UNIT_AURA")
    --used for highlight target feature
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    --raid target markers
    f:RegisterEvent("RAID_TARGET_UPDATE")
    --banzai/healcomm are registered in core on enable
    -- f:RegisterEvent("PARTY_LEADER_CHANGED")

    f:SetScript("OnEvent", function()
        if arg1 and arg1 == this.unit then -- if an event has coniditions specific to a unit, then only specified unit will update
            if event == "UNIT_AURA" then
                self:UNIT_AURA(this.unit)
            else
                self:UNIT_MAIN(this.unit)
                self:UNIT_BORDER(this.unit)
            end
        elseif event == "PLAYER_TARGET_CHANGED" then -- all units will update their border
            self:UNIT_BORDER(this.unit)
        elseif event == "RAID_TARGET_UPDATE" then -- update raid markers for this unit
            self:UpdateRaidMarkers()
            -- elseif event == "PARTY_LEADER_CHANGED" then
            -- 	self:UpdateLeaderIcon()
        end
    end)

    return f
end

-------------------
-- Config Frames --
-------------------

function NotGrid:ConfigPartyIndexFrames()
    local o = self.o
    for key, f in pairs(self.PartyIndexFrames) do
        f.TextString:SetFont(o.unitfont, o.unitnamehealthtextsize, "OUTLINE")
        if f.index == 10 then
            f.TextString:SetText("宠物")
        elseif f.index == 9 then
            f.TextString:SetText("自己队")
        else
            f.TextString:SetText("小队" .. f.index)
        end
        f:Hide()
    end
end

function NotGrid:ClearIndexFramePoint()
    for key, f in pairs(self.PartyIndexFrames) do
        f:ClearAllPoints()
        f:Hide()
    end
end

function NotGrid:ConfigUnitFrames() -- this can get called on every setting change, instead of doing some wierd roundabout way. Hurray!
    local o = self.o
    for _, f in pairs(self.UnitFrames) do
        --f:SetAlpha(self.o.ooralpha) -- we set lastseen at frame creation instead. doing it like this makes config mode weird, and would obstruct disabling prox checking
        local width, height
        if o.showpowerbar and o.powerposition <= 2 then -- factor in a modifier for the powerbar width/height
            width = o.unitwidth
            height = o.unitheight + o.powersize + 1
        elseif o.showpowerbar and o.powerposition >= 3 then
            width = o.unitwidth + o.powersize + 1
            height = o.unitheight
        else
            width = o.unitwidth
            height = o.unitheight
        end
        f:SetWidth(width)
        f:SetHeight(height)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", tile = true, tileSize = 16 })
        f:SetBackdropColor(unpack(o.unitbgcolor))

        if o.borderartwork then
            f.border:SetWidth(width + o.unitborder) -- the way edgefile works is it basically sits on the center of the edge of the frame and expands both inward and outward. So to compensate asthetically for that I ahve to increase the size of my frame double the desired width of the edgefile/border
            f.border:SetHeight(height + o.unitborder)
            f.border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
        else
            f.border:SetWidth(width + o.unitborder * 2) -- the way edgefile works is it basically sits on the center of the edge of the frame and expands both inward and outward. So to compensate asthetically for that I ahve to increase the size of my frame double the desired width of the edgefile/border
            f.border:SetHeight(height + o.unitborder * 2)
            f.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = o.unitborder })
        end
        f.border:SetBackdropBorderColor(unpack(o.unitbordercolor))
        f.border:SetPoint("CENTER", 0, 0)
        f.border:SetFrameLevel(f:GetFrameLevel() + 2)
        f.border.middleart:SetTexture("Interface/TargetingFrame/UI-TargetingFrame")
        if o.powerposition <= 2 then
            f.border.middleart:SetTexCoord((58 / 256) + (1 / 256 / 2), (82 / 256) + (1 / 256 / 2),
                (39 / 128) + (1 / 128 / 2),
                (44 / 128) + (1 / 128 / 2))
            f.border.middleart:SetVertexColor(unpack(o.unitbordercolor))
        else
            f.border.middleart:SetTexCoord((26 / 256) + (1 / 256 / 2), (32 / 256) + (1 / 256 / 2),
                (27 / 128) + (1 / 128 / 2),
                (34 / 128) + (1 / 128 / 2))
            f.border.middleart:SetVertexColor(unpack(o.unitbordercolor))
        end

        f.healthbar:SetWidth(o.unitwidth)
        f.healthbar:SetHeight(o.unitheight)

        local dir = "Interface\\AddOns\\NotGrid\\media\\"
        f.healthbar:SetStatusBarTexture(dir .. "3.tga")
        f.healthbar:SetStatusBarColor(unpack(o.unithealthbarcolor))
--        f.healthbar.bgtex:SetTexture(dir .. "1.tga")
        f.healthbar.bgtex:SetVertexColor(unpack(o.unithealthbarbgcolor))
        f.healthbar.bgtex:SetAllPoints()

        --position health and powerbar
        f.healthbar:ClearAllPoints()
        f.powerbar:ClearAllPoints()
        f.border.middleart:ClearAllPoints()
        
                f.healthbar:SetPoint("TOP", 0, 0)
                f.powerbar:SetPoint("BOTTOM", 0, 0)
                f.border.middleart:SetPoint("TOP", f.powerbar, 0, 4)
                f.powerbar:SetWidth(o.unitwidth)
                f.powerbar:SetHeight(o.powersize)
                f.powerbar:SetOrientation("HORIZONTAL")
                f.border.middleart:SetWidth(width)
                f.border.middleart:SetHeight(6)
                
            f.powerbar:Show()
                f.border.middleart:Hide()
            
        f.powerbar:SetStatusBarTexture(dir .. "3.tga")
        f.powerbar.bgtex:SetTexture(dir .. o.unithealthbartexture)
        f.powerbar.bgtex:SetVertexColor(unpack(o.unitpowerbarbgcolor))
        f.powerbar.bgtex:SetAllPoints()
        --f.powerbar:SetStatusBarColor(unpack(o.unithealthbarcolor))

        f.incres:SetWidth(o.unitheight) -- yep, so it stays square under most common sizes. Think of a mathematical way in the future
        f.incres:SetHeight(o.unitheight)
        f.incres:ClearAllPoints()
        f.incres:SetPoint("CENTER", 0, 0)
        f.incres.bgtex:SetTexture("Interface\\AddOns\\NotGrid\\media\\res")
        f.incres.bgtex:SetAllPoints()
        f.incres:Hide()

        f.incheal:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = true, tileSize = 16, edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
        f.incheal:SetBackdropColor(0, 0, 0, 0)
        f.incheal:SetBackdropBorderColor(0, 0, 0, 0) -- mostly just so its 0 opacity
        f.incheal:SetWidth(o.unitwidth)
        f.incheal:SetHeight(o.unitheight)

        f.leader:SetWidth(8)  --o.unitheight)
        f.leader:SetHeight(8) --o.unitheight)
        f.leader:ClearAllPoints()
        f.leader:SetPoint("TOPLEFT", -2, 2)
        f.leader.icon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        f.leader.icon:SetAllPoints()
        f.leader:Hide()

        -- 配置职责图标
        f.dungeon_role:SetWidth(o.dungeonrolesize)
        f.dungeon_role:SetHeight(o.dungeonrolesize)
        f.dungeon_role:ClearAllPoints()
        f.dungeon_role:SetPoint("TOPRIGHT", o.dungeonroleoffx, o.dungeonroleoffy)  -- 使用配置的偏移量
        f.dungeon_role:SetFrameLevel(f:GetFrameLevel() + 3)  -- 设置层级高于边框
        f.dungeon_role.icon:SetTexture("Interface\\AddOns\\NotGrid\\media\\ui-lfg-icon-portraitroles")
        f.dungeon_role.icon:SetAllPoints()
        f.dungeon_role:Hide()

        f.healthbar.raidmarker:SetWidth(8)
        f.healthbar.raidmarker:SetHeight(8)
        f.healthbar.raidmarker:SetAlpha(0.8)
        f.healthbar.raidmarker:SetPoint("TOPLEFT", f.healthbar, "TOPLEFT", -2, 2) -- 将标记放置在血条上方

-- nametext
f.nametext:SetShadowColor(0, 0, 0, 0.8)
f.nametext:SetShadowOffset(1, -1)
f.nametext:ClearAllPoints()
f.nametext:SetTextColor(1,1,1,1)
f.nametext:SetFont("Fonts\\FZLTLC.TTF", 9, "OUTLINE")
f.nametext:SetPoint("TOP", f.healthbar, "TOP", 0, 2)
-- hptext
f.hptext:SetShadowColor(0, 0, 0, 0.8)
f.hptext:SetShadowOffset(1, -1)
f.hptext:ClearAllPoints()
f.hptext:SetTextColor(0,1,0)
f.hptext:SetFont("Fonts\\FZLTLC.TTF", 12, "OUTLINE")
f.hptext:SetPoint("TOP", f.nametext, "BOTTOM", 0, -2)
-- healcommtext
f.healcommtext:SetShadowColor(0, 0, 0, 0.8)
f.healcommtext:SetShadowOffset(1, -1)
f.healcommtext:ClearAllPoints()
f.healcommtext:SetTextColor(0.8, 0.2, 1)
f.healcommtext:SetFont("Fonts\\ledfont.TTF", 12, "OUTLINE")
f.healcommtext:SetPoint("CENTER", f.healthbar, "CENTER", o.unithealcommtextoffx, 1)

if not o.showhealcommtext then
    f.healcommtext:Hide()
end
        --  -- 移除Backdrop设置，改为设置纹理属性,调整纹理坐标，去除边缘 by 武藤纯子酱 2025.8.22
        -- for i, point in { "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT" } do
        --     local fi = f.healthbar["trackingicon" .. i]
        --     fi:SetWidth(o.unittrackingiconsize)
        --     fi:SetHeight(o.unittrackingiconsize)
        --     fi:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        --     -- fi:SetBackdrop({
        --     --     bgFile = "Interface\\Buttons\\WHITE8X8",
        --     --     edgeFile = "Interface\\Buttons\\WHITE8X8",
        --     --     tile = true,
        --     --     tileSize =
        --     --         o.unittrackingiconsize,
        --     --     edgeSize = o.unittrackingiconborder
        --     -- })
        --     -- fi:SetBackdropBorderColor(o.unittrackingiconbordercolor)
        --     -- fi:SetBackdropColor(unpack(o["trackingicon" .. i .. "color"]))
        --     fi:ClearAllPoints()
        --     fi:SetPoint(point, 0, 0)
        --     fi:Hide()
        -- end

        -- 修改：只调整图标大小和位置，不重新创建
   end
end

---------------------
-- Position Frames --
---------------------
function NotGrid:PositionPartyIndexFrames(index, SubGroupCount, TotalUnits, TotalGroups, powermodx, powermody)
    local o = self.o
    if not o.ShowPartyIndex then return end
    local v = self.PartyIndexFrames["partyindex" .. index]
    if v.index == index and SubGroupCount == 0 then
        v.TextString:ClearAllPoints()
        if o.growthdirection == 1 then
            v.TextString:SetPoint("BOTTOM", "NotGridContainer", "TOP",
                (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * TotalGroups,
                o.unitheight + o.unitnamehealthoffy)
        elseif o.growthdirection == 2 then
            v.TextString:SetPoint("BOTTOM", "NotGridContainer", "TOP",
                -(o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * TotalGroups,
                o.unitheight + o.unitnamehealthoffy)
        elseif o.growthdirection == 3 then
            v.TextString:SetPoint("CENTER", "NotGridContainer", "CENTER", -o.unitwidth,
                -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * TotalGroups)
        elseif o.growthdirection == 4 then
            v.TextString:SetPoint("CENTER", "NotGridContainer", "CENTER", -o.unitwidth,
                (o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * TotalGroups)
        elseif o.growthdirection == 5 then
            v.TextString:SetPoint("CENTER", "NotGridContainer", "CENTER", -o.unitwidth,
                -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * TotalUnits)
        elseif o.growthdirection == 6 then
            v.TextString:SetPoint("CENTER", "NotGridContainer", "CENTER", -o.unitwidth,
                (o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * TotalUnits)
        elseif o.growthdirection == 7 then
            v.TextString:SetPoint("BOTTOM", "NotGridContainer", "TOP",
                (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * TotalUnits,
                o.unitheight + o.unitnamehealthoffy)
        elseif o.growthdirection == 8 then
            v.TextString:SetPoint("BOTTOM", "NotGridContainer", "TOP",
                -(o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * TotalUnits,
                o.unitheight + o.unitnamehealthoffy)
        elseif o.growthdirection == 9 then
            if (TotalGroups < 4) then -- 因为是从0开始计数的
                v.TextString:SetPoint("BOTTOM", "NotGridContainer", "TOP",
                    (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * TotalGroups,
                    o.unitheight + o.unitnamehealthoffy)
            elseif (TotalGroups < 8) then
                v.TextString:SetPoint("BOTTOM", "NotGridContainer", "TOP",
                    (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * (TotalGroups - 4),
                    -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * 5.2 + o.unitnamehealthoffy)
            elseif (TotalGroups == 8) then
                v.TextString:SetPoint("BOTTOM", "NotGridContainer", "TOP",
                    (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * (TotalGroups - 4),
                    o.unitheight + o.unitnamehealthoffy)
            elseif (TotalGroups == 9) then
                v.TextString:SetPoint("BOTTOM", "NotGridContainer", "TOP",
                    (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * (TotalGroups - 4-1),
                    -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * 5.2 + o.unitnamehealthoffy)
            end
        end
        v:Show()
    end
end

function NotGrid:PositionFrames()
    local partycount = GetNumPartyMembers()
    local raidcount = GetNumRaidMembers()

    local SubGroupCounts = self.Compost:Acquire(0, 0, 0, 0, 0, 0, 0, 0, 0, 0) -- reset it every time
    local TotalGroups = 0                                                     -- 小队总数
    local TotalUnits = 0                                                      -- 总人数
    local o = self.o

    local powermodx = 0 -- so I can interject the width of the powerbar into the positioning calcs without doing a million more conditionals
    local powermody = 0
    if o.showpowerbar then
        if o.powerposition <= 2 then
            powermody = o.powersize + 1
        else
            powermodx = o.powersize + 1
        end
    end
    ---------------------------------------------------------------
    -- local GroupsIndex = CreateFrame("GroupsIndex",nil,nil)


    ---------------------------------------------------------------

    -- 40是小队编号字体宽度，加上单位框架一半的宽度 才能保证小队编号显示在屏幕内。
    local tmpwidth = 40 + math.ceil(o.unitwidth / 2);
    if o.growthdirection == 3 or o.growthdirection == 4 then
        if o.containeroffx < tmpwidth then
            o.containeroffx = tmpwidth
        end
    else
        if o.containeroffx < 40 then
            o.containeroffx = 40
        end
    end

    -- handle all the unitframes and subgroups
    for i = 1, 10 do -- 1-8 is raid, 9 is party, 10 is partypet
        for key, f in pairs(self.UnitFrames) do
            if UnitExists(f.unit) or o.configmode then
                -- first get the subgroup
                local subgroup = nil
                if f.raidindex then                                       -- if a frame with raid unitid
                    if o.configmode then
                        subgroup = (math.ceil(math.abs(f.raidindex / 5))) -- doing it like this does mean it loops and calcs this 10 times for all the unitframes, though
                    else
                        _, _, subgroup = GetRaidRosterInfo(f.raidindex)
                    end
                elseif (string.find(f.unit, "party%d") or (f.unit == "player")) and ((raidcount > 0 and o.showpartyinraid) or (raidcount == 0 and partycount > 0 and o.showinparty and not o.configmode) or (raidcount == 0 and partycount == 0 and o.showwhilesolo and not o.configmode) or (o.configmode and o.showpartyinraid)) then
                    subgroup = 9
                elseif (string.find(f.unit, "partypet%d") or (f.unit == "pet")) and ((raidcount > 0 and o.showpartyinraid and o.showpets) or (raidcount == 0 and partycount > 0 and o.showinparty and o.showpets and not o.configmode) or (raidcount == 0 and partycount == 0 and o.showwhilesolo and o.showpets and not o.configmode) or (o.configmode and o.showpartyinraid and o.showpets)) then
                    subgroup = 10
                else
                    f:Hide() -- I won't set a subgroup so it will fail the next check, wont position, and won't get counted into subgroup/totalgroups
                end
                --then do all the positioning
                if subgroup == i then
                    f:ClearAllPoints()
                    if o.growthdirection == 1 then
                        f:SetPoint("CENTER", (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) *
                            TotalGroups, -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) *
                            SubGroupCounts[i])
                    elseif o.growthdirection == 2 then
                        f:SetPoint("CENTER", -(o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) *
                            TotalGroups, -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) *
                            SubGroupCounts[i]) -- i do subgroup -1 so group 1 will be 0 and be at 0 offset
                    elseif o.growthdirection == 3 then
                        f:SetPoint("CENTER",
                            (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * SubGroupCounts[i],
                            -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * TotalGroups)
                    elseif o.growthdirection == 4 then
                        f:SetPoint("CENTER",
                            (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * SubGroupCounts[i],
                            (o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * TotalGroups)
                    elseif o.growthdirection == 5 then -- single top to bottom
                        f:SetPoint("CENTER", 0,
                            -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * TotalUnits)
                    elseif o.growthdirection == 6 then -- single bottom to top
                        f:SetPoint("CENTER", 0, (o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) *
                            TotalUnits)
                    elseif o.growthdirection == 7 then -- single left to right
                        f:SetPoint("CENTER", (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) *
                            TotalUnits, 0)
                    elseif o.growthdirection == 8 then -- single right to left
                        f:SetPoint("CENTER", -(o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) *
                            TotalUnits, 0)
                    elseif o.growthdirection == 9 then -- first line: 1234 second line: 5678
                        if (TotalGroups < 4) then      -- 因为是从0开始计数的
                            f:SetPoint("CENTER",
                                (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * TotalGroups,
                                -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * SubGroupCounts[i])
                        elseif (TotalGroups < 8) then
                            f:SetPoint("CENTER",
                                (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * (TotalGroups - 4),
                                -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) *
                                (5.8 + SubGroupCounts[i]))
                        elseif (TotalGroups == 8) then      -- 因为是从0开始计数的
                            f:SetPoint("CENTER",
                                (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * (TotalGroups - 4),
                                -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * SubGroupCounts[i])
                        elseif (TotalGroups == 9) then
                            f:SetPoint("CENTER",
                                (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) * (TotalGroups - 4 - 1),
                                -(o.unitheight + powermody + o.unitborder * 2 + o.space_top_and_bottom) * (5.8 + SubGroupCounts[i]))
                        end
                    end
                    self:PositionPartyIndexFrames(i, SubGroupCounts[i], TotalUnits, TotalGroups, powermodx, powermody)
                    f:Show()
                    TotalUnits = TotalUnits + 1
                    SubGroupCounts[i] = SubGroupCounts[i] + 1
                    --DEFAULT_CHAT_FRAME:AddMessage(f.unit .. " positioned")
                end
            else
                f:Hide()
            end
        end

        if SubGroupCounts[i] > 0 then
            TotalGroups = TotalGroups + 1
        end
    end

    --handle the container frame
    if not o.draggable then
        self.Container:ClearAllPoints()
        -- if o.smartcenter == true and o.growthdirection == 1 then
        --     self.Container:SetPoint(o.containerpoint,
        --         o.containeroffx - (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) / 2 * (TotalGroups - 1),
        --         o.containeroffy)
        -- elseif o.smartcenter == true and o.growthdirection == 2 then
        --     self.Container:SetPoint(o.containerpoint,
        --         o.containeroffx + (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) / 2 * (TotalGroups - 1),
        --         o.containeroffy)
        -- elseif o.smartcenter == true and (o.growthdirection == 3 or o.growthdirection == 4) then
        --     table.sort(SubGroupCounts)
        --     self.Container:SetPoint(o.containerpoint,
        --         o.containeroffx - (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) / 2 * (SubGroupCounts[10] - 1),
        --         o.containeroffy)
        -- elseif o.smartcenter == true and o.growthdirection == 7 then
        --     self.Container:SetPoint(o.containerpoint,
        --         o.containeroffx - (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) / 2 * (TotalUnits - 1),
        --         o.containeroffy)
        -- elseif o.smartcenter == true and o.growthdirection == 8 then
        --     self.Container:SetPoint(o.containerpoint,
        --         o.containeroffx + (o.unitwidth + powermodx + o.unitborder * 2 + o.space_left_and_right) / 2 * (TotalUnits - 1),
        --         o.containeroffy)
        -- else
            self.Container:SetPoint(o.containerpoint, o.containeroffx, o.containeroffy)
        -- end
    end

    self.Compost:Reclaim(SubGroupCounts)
end

-----------------------
-- 小地图按钮 --
-----------------------
--[[function NotGrid:CreateMinimapButton()
    
    -- 创建按钮
    local button = CreateFrame("Button", "NotGridMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- 图标
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 1)
    icon:SetTexture("Interface\\AddOns\\NotGrid\\media\\battlenet-portrait")  -- 使用金币图标
    button.icon = icon
    
    -- 边框
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    -- 拖动功能
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    local function UpdatePosition()
        local angle = NotGridOptions.minimapAngle or 180
        local x = 80 * cos(angle)
        local y = 80 * sin(angle)
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    button:SetScript("OnDragStart", function()
        this:LockHighlight()
        this:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            
            local angle = math.deg(math.atan2(py - my, px - mx))
            NotGridOptions.minimapAngle = angle

            UpdatePosition()
        end)
    end)
    
    button:SetScript("OnDragStop", function()
        this:SetScript("OnUpdate", nil)
        this:UnlockHighlight()
    end)
    
    -- 点击事件（设置菜单已移除，左键仅提示可用的斜杠命令）
    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            DEFAULT_CHAT_FRAME:AddMessage("NotGrid: 可用命令 /ng reset (恢复默认设置) 或 /ng grid (切换为Grid风格血条)")
        elseif arg1 == "RightButton" then
            NotGrid:ToggleFrameShowHide()
        end
    end)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("NotGrid 团队框架")
        GameTooltip:AddLine("左键：打开设置，命令 /ng", 1, 1, 1)
        GameTooltip:AddLine("右键：显示/隐藏团队框架", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- 初始位置
    UpdatePosition()
    button:Show()
    
    self.MinimapButton = button
end
]]--
