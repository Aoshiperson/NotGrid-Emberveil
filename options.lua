local L = NotGridLocale

local DefaultOptions = {
	["minimapAngle"] = 180, -- 按钮位置
	["version"] = 1.129, -- will be the commit number from now on.
	["versionchecking"] = true,	-- 版本检查

	["unitwidth"] = 45,			-- 框架宽度
	["unitheight"] = 30,		-- 框架高度
	["unitborder"] = 2,		-- 框架边框
	-- ["unitpadding"] = -13,		-- 框架填充
    ["space_left_and_right"] = 2,     -- 左右间距
    ["space_top_and_bottom"] = 2,     -- 上下间距
	["unitbgcolor"] = {0,0,0,0.4},		-- 背景颜色
	["unitbordercolor"] = {0,0,0,0.8},	-- 框架边框背景颜色
	["unithealthorientation"] = 2,		-- 血条方向
	["unithealthbartexture"] = 3,		-- 纹理
	["unithealthbarcolor"] = {39/255,186/255,42/255,1},
	["unithealthbarbgcolor"] = {0,0,0,0.1},
	["unithealthbarbgtexture"] = "Interface\\Buttons\\WHITE8X8",
	["unitfont"] = STANDARD_TEXT_FONT,
	["unitnamehealthtextcolor"] = {1,1,1,1},
	["unitnamehealthtextsize"] = 13.5, 	-- 姓名尺寸
	["unithealcommbarcolor"] = {32/255,112/255,11/255,1},	-- 血量预估条颜色
	["unithealcommtextcolor"] = {39/255,186/255,42/255,1},	-- 血量预估文本颜色
	["unithealcommtextsize"] = 10,	-- 血量预估文本大小
	["unithealcommtextoffx"] = 0,	-- 血量预估文本x偏移量
	["unithealcommtextoffy"] = -10,	-- 血量预估文本y偏移量
	["unittrackingiconsize"] = 6,	-- 图标尺寸
	["unittrackingiconborder"] = 1,	-- 图标边框?
	["unittrackingiconbordercolor"] = {0,0,0,1},	-- 图标颜色?

	["showpowerbar"] = true, 		-- 显示能量/怒气/蓝条
	["powersize"] = 5, 				-- 能量/怒气/蓝条尺寸, 如果玩家选择将其设置为“垂直”，则为宽度；如果玩家选择“水平”，则将为高度
	["powerposition"] = 2, 			-- 1=top,2=bottom,3=left,4=right 能量/怒气/蓝条位置
	["colorpowerbarbgbytype"] = false,		-- 能量/怒气/蓝条背景
	["unitpowerbarbgcolor"] = {0,0,0,0.1},	-- 背景颜色

	["trackingicon1"] = {"回春术","愈合","恢复",}, -- 将auraname/spelltype作为关键字可能会更好，但这会带来其他需要解决的问题
	["trackingicon1invert"] = false,
	["trackingicon1color"] = {0.37,0.83,0.38},
	["trackingicon2"] = {"",},
	["trackingicon2invert"] = false,
	["trackingicon2color"] = {0.20,0.60,1.00},
	["trackingicon3"] = {"魔法",},
	["trackingicon3invert"] = false,
	["trackingicon3color"] = {0.20,0.60,1.00},
	["trackingicon4"] = {"中毒",},
	["trackingicon4invert"] = false,
	["trackingicon4color"] = {0.00,0.60,0},
	["trackingicon5"] = {"诅咒",},
	["trackingicon5invert"] = false,
	["trackingicon5color"] = {0.60,0.00,1.00},
	["trackingicon6"] = {"疾病",},
	["trackingicon6invert"] = false,
	["trackingicon6color"] = {0.60,0.40,0},
	["trackingicon7"] = {"致死打击","重伤","暗影迷雾","死木诅咒","血性狂暴","致伤毒药","虚弱妖术",},
	["trackingicon7invert"] = false,
	["trackingicon7color"] = {0.80,0,0},
	["trackingicon8"] = {"",},
	["trackingicon8invert"] = false,
	["trackingicon8color"] = {0.20,0.60,1.00},

	["showOnlyDispellableDebuffs"] = false, -- 只显示可驱散的Debuff

	["trackaggro"] = true,	-- 仇恨报警
	["aggrowarningcolor"] = {150/255,10/255,10/255,0.8},	-- 仇恨报警颜色
	["trackmana"] = true,	-- 低蓝量报警
	["manawarningcolor"] = {42/255,69/255,117/255,0.8},	-- 低蓝量报警颜色

	["tracktarget"] = true,			-- 高亮目标
	["targetcolor"] = {1,1,1,0.8},	-- 高亮颜色

	["containerpoint"] = "TOPLEFT",	-- 锚点位置
	["containeroffx"] = 40,	-- x偏移量
	["containeroffy"] = -400,	-- y偏移量

	["unitnamehealthoffx"] = 0,	-- 名字x偏移量
	["unitnamehealthoffy"] = 0,	-- 名字y偏移量


	["healththreshhold"] = 1,	-- 血量阈值
	["manathreshhold"] = 20,	-- 低蓝量报警阈值
	["namelength"] = 6,			-- 名字长度

	["ooralpha"] = 0.5,			-- 超出距离透明度

	["useproximity"] = true,
	["proximityrate"] = 1,		-- 刷新率
	["proximityleeway"] = 4,	-- 同步刷新速度

	["colorunitnamehealthbyclass"] = true,	-- 姓名颜色
	["colorunithealthbarbyclass"] = true,	-- 血条颜色
	["colorunithealthbarbgbyclass"] = true,-- 血条背景颜色
	["usetbcshamancolor"] = true,			-- TBC萨满颜色
	["usepetcolor"] = true,					-- 自定义宠物颜色
	["petcolor"] = {1,0.74,0},				-- 宠物颜色


	["smartcenter"] = false,		-- 智能中心
	["showhealcommtext"] = true,	-- 显示治疗预估文本
	["showhealcommbar"] = true,		-- 显示治疗预估条
	["usemapdistances"] = true,		-- 使用地图刷新率

	["ShowPartyIndex"] = true,		-- 显示小队编号
	["showwhilesolo"] = false,		-- 单人时显示框架
	["showinparty"] = true,			-- 队伍中显示框架
	["showpartyinraid"] = false,	-- 在团队中显示小队
	["showpets"] = false,			-- 显示宠物
    ["showblizzframesInParty"] = false, -- 显示暴雪小队框架（在队伍中）
	["showblizzframesInRaid"] = false,	-- 显示暴雪小队框架（在团队中）

	["growthdirection"] = 1, 	-- 1: Group Left to Right, 2: Group Right to Left, 3: Group Top to Bottom, 4: Group Bottom to Top, 5: Unit Top to Bottom.. etc
								-- 生长方向

	["cliquehook"] = false, 	-- keep default false to avoid confusion from new users
								-- 可以使用Clique组合键

	["configmode"] = false,		-- 配置模式
	["disablemouseoverincombat"] = false,	-- 战斗中不显示鼠标提示

	["borderartwork"] = false,	-- 边框材质?

	["draggable"] = true,		-- 可拖动
	["showmenuhint"] = true,	-- 配置模式
	
	["showdungeonrole"] = false,	-- 显示职责图标（Tank/Healer/DPS）
	["manualroles"] = {},		-- 手动设置的角色
	["dungeonrolesize"] = 14,	-- 职责图标大小
	["dungeonroleoffx"] = -2,	-- 职责图标x偏移量
	["dungeonroleoffy"] = -2,	-- 职责图标y偏移量
}

function NotGrid:ResetDefaultOptions()
	NotGridOptions = DefaultOptions
	ReloadUI()
end

-- 不再有持久化存档，每次登录/重载都直接用 DefaultOptions 填充，
-- 想改设置直接改上面的 DefaultOptions 表就行
function NotGrid:SetDefaultOptions()
	NotGridOptions = DefaultOptions
end

--------------------
-- Slash Commands --
--------------------

SLASH_NOTGRID1 = "/notgrid"
SLASH_NOTGRID2 =  "/ng"
function SlashCmdList.NOTGRID(msg, editbox)
	if msg == "reset" then
		for key,value in pairs(DefaultOptions) do
			NotGridOptions[key] = value
		end
		ReloadUI() -- we have to reloadui to make the config menu update as well
	elseif msg == "grid" then
		NotGrid.o.unithealthbartexture = "Interface\\AddOns\\NotGrid\\media\\GridGradient"
		NotGrid.o.unithealthbarbgtexture = "Interface\\AddOns\\NotGrid\\media\\GridGradient"
		NotGrid.o.unithealthbarcolor = {0,0,0,0.65}
		NotGrid.o.unithealthbarbgcolor = {0,0,0,1}
		NotGrid.o.colorunithealthbarbyclass = false
		NotGrid.o.colorunithealthbarbgbyclass = true
		ReloadUI()
	else
		DEFAULT_CHAT_FRAME:AddMessage("NotGrid: 可用命令 /ng reset (恢复默认设置) 或 /ng grid (切换为Grid风格血条)")
	end
end
