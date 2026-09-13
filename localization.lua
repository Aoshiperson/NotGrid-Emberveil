local L = AceLibrary("AceLocale-2.2"):new("NotGrid")

L:RegisterTranslations("enUS", function()
    return {
        ["Dead"] = true,
        ["Ghost"] = true,
        ["Scroll Me!"] = true,

        ["Unit Width"] = true,
        ["Unit Height"] = true,
        ["Unit Border"] = true,
        -- ["Unit Padding"] = true,
        ["Space between left and right"] = true,
        ["Space between top and bottom"] = true,
        ["Font"] = true,
        ["Texture"] = true,
        ["Name Color"] = true,
        ["Name Size"] = true,
        ["Name Length"] = true,
        ["Health Color"] = true,
        ["Health Threshold"] = true,
        ["Highlight Target"] = true,
        ["Aggro Warning"] = true,
        ["Mana Warning"] = true,
        ["Healcomm Bar"] = true,
        ["Healcomm Text"] = true,
        ["Top Left Icon"] = true,
        ["Top Icon"] = true,
        ["Top Right Icon"] = true,
        ["Right Icon"] = true,
        ["Bottom Right Icon"] = true,
        ["Bottom Icon"] = true,
        ["Bottom Left Icon"] = true,
        ["Left Icon"] = true,
        ["Icon Size"] = true,
        ["Proximity Leeway"] = true,
        ["Use Map Proximity"] = true,
        ["Smart Center"] = true,
        -- ["Show the notgraid"] = true,
        ["Show the party's index"] = true,
        ["Show While Solo"] = true,
        ["Show In Party"] = true,
        ["Show Party In Raid"] = true,
        ["Disable Tooltip In Combat"] = true,
        ["Health Orientation"] = true,
        ["Show Blizz Frames In Party"] = true,
        ["Show Blizz Frames In Raid"] = true,
        ["Growth Direction"] = true,
        ["Show Power Bar"] = true,
        ["Power Position"] = true,
        ["Power Size"] = true,
        ["Config Mode"] = true,
        ["Background"] = true,
        ["Show Pets"] = true,
        ["Custom Pet Color"] = true,
        ["TBC Shaman Color"] = true,
        ["Proximity Rate"] = true,
        ["Health Background"] = true,
        ["Clique Hook"] = true,
        ["Power Background"] = true,
        ["Position"] = true,
        ["Border Artwork"] = true,
        ["Name Position"] = true,
        ["Healcomm Text Position"] = true,
        ["Version Checking"] = true,
        ["Draggable"] = true,

        ["CombatEvents"] = {
            ["CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS"] = "(%a+) gains %a.+", --%a on the last just to make sure its not a digit
            ["CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE"] = "(%a+) is afflicted by .+",
            ["CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS"] = "(%a+) gains %a.+",
            ["CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE"] = "(%a+) is afflicted by .+",

            ["CHAT_MSG_SPELL_PARTY_BUFF"] = "(%a+) begins .+", --I don't get this message for party members? Only friendly?
            ["CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF"] = "(%a+) begins .+",
            ["CHAT_MSG_SPELL_PARTY_DAMAGE"] = "(%a+) begins .+",
            ["CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE"] = "(%a+) begins .+",

            ["CHAT_MSG_SPELL_AURA_GONE_PARTY"] = ".+ fades from (%a+)%.",
            ["CHAT_MSG_SPELL_AURA_GONE_OTHER"] = ".+ fades from (%a+)%.", -- will pick up hostile fades as well as freind, but I won't have them in rosterlib so whatevs

            ["CHAT_MSG_SPELL_SELF_BUFF"] = "Your .+ heals (%a+) for .+"
        },

        --------------
        -- Tooltips --
        --------------

        ["pet_tooltip"] = "Note: Prone to visual errors.",
        ["classcolor_tooltip"] = "Toggle for class color.",
        ["smartcenter_tooltip"] =
        "As your group expands the frames stay horizontally centered on the original group placement.",
        ["healththreshold_tooltip"] = "Health percentage before name is replaced with health deficit.",
        ["manathreshhold_tooltip"] = "Mana percentage before border color changes.",
        ["proximityleeway_tooltip"] = "Amount of seconds to be considered \"In Range\" after a positive confirmation.",
        ["proximityrate_tooltip"] = "Amount of seconds between proximity checks.",
        ["cliquehook_tooltip"] =
        "Hooks the Clique spellcast function to use NG instead for proximity checking beyond 28 yards within instances. Toggling will reload UI.",
        ["powercolor_tooltip"] = "Toggle for power color.",
        ["position_tooltip"] = "Shift+Ctrl = 100\nShift = 10",
        ["draggable_tooltip"] = "Note: Possible client crash bug\n           Smart Center disabled",
        ["icon_tooltip"] = "Toggle to invert icon display.",

        --------------------------------------------------------
        -- 以下为debuff魔法类型，在中文端也显示英文，请勿修改 --
        --------------------------------------------------------

        ["Magic"] = true,
        ["Poison"] = true,
        ["Curse"] = true,
        ["Disease"] = true,
    }
end)

L:RegisterTranslations("zhCN", function()
    return {
        ["Dead"] = "死亡",
        ["Ghost"] = "灵魂",
        ["Scroll Me!"] = "滚动我",
        -- ["Show the notgraid"] = "开启团队框架",
        ["Unit Width"] = "框架宽度",
        ["Unit Height"] = "框架高度",
        ["Unit Border"] = "框架边框",
        -- ["Unit Padding"] = "框架填充",
        ["Space between left and right"] = "左右间距",
        ["Space between top and bottom"] = "上下间距",
        ["Font"] = "字体",
        ["Texture"] = "纹理",
        ["Name Color"] = "姓名颜色",
        ["Name Size"] = "姓名尺寸",
        ["Name Length"] = "姓名长度",
        ["Health Color"] = "血条颜色",
        ["Health Threshold"] = "血量阈值",
        ["Highlight Target"] = "高亮目标",
        ["Aggro Warning"] = "仇恨报警",
        ["Mana Warning"] = "低蓝量报警",
        ["Healcomm Bar"] = "血量预估条",
        ["Healcomm Text"] = "治疗预估文本",
        ["Top Left Icon"] = "左上角图标",
        ["Top Icon"] = "上图标",
        ["Top Right Icon"] = "右上图标",
        ["Right Icon"] = "右图标",
        ["Bottom Right Icon"] = "右下图标",
        ["Bottom Icon"] = "下图标",
        ["Bottom Left Icon"] = "左下图标",
        ["Left Icon"] = "左图标",
        ["Icon Size"] = "图标尺寸",
        ["Proximity Leeway"] = "同步刷新速度",
        ["Use Map Proximity"] = "使用地图刷新率",
        ["Smart Center"] = "智能中心",
        ["Show the party's index"] = "显示小队编号",
        ["Show While Solo"] = "单人时显示框架",
        ["Show In Party"] = "队伍中显示框架",
        ["Show Party In Raid"] = "在团队中显示小队",
        ["Disable Tooltip In Combat"] = "战斗中不显示鼠标提示",
        ["Health Orientation"] = "血条方向",
        ["Show Blizz Frames In Party"] = "显示暴雪小队框架(队伍中)",
        ["Show Blizz Frames In Raid"] = "显示暴雪小队框架(团队中)",
        ["Growth Direction"] = "生长方向",
        ["Show Power Bar"] = "显示能量/怒气/蓝条",
        ["Power Position"] = "能量/怒气/蓝条位置",
        ["Power Size"] = "能量/怒气/蓝条尺寸",
        ["Config Mode"] = "配置模式",
        ["Background"] = "背景",
        ["Show Pets"] = "显示宠物",
        ["Custom Pet Color"] = "自定义宠物颜色",
        ["TBC Shaman Color"] = "TBC萨满颜色",
        ["Proximity Rate"] = "刷新率",
        ["Health Background"] = "血条背景",
        ["Clique Hook"] = "可以使用Clique组合键",
        ["Power Background"] = "能量/怒气/蓝条背景",
        ["Position"] = "位置",
        ["Border Artwork"] = "边框材质",
        ["Name Position"] = "姓名位置",
        ["Healcomm Text Position"] = "预估文本位置",
        ["Version Checking"] = "版本检查",
        ["Draggable"] = "可拖动",

        ["CombatEvents"] = {
            ["CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS"] = "(%a+)获得了%a.+的效果",
            ["CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE"] = "(%a+)受到了.+效果的影响",
            ["CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS"] = "(%a+)获得了%a.+",
            ["CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE"] = "(%a+)受到了.+效果的影响",

            ["CHAT_MSG_SPELL_PARTY_BUFF"] = "(%a+)开始.+",
            ["CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF"] = "(%a+)开始.+",
            ["CHAT_MSG_SPELL_PARTY_DAMAGE"] = "(%a+)开始.+",
            ["CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE"] = "(%a+)开始.+",

            ["CHAT_MSG_SPELL_AURA_GONE_PARTY"] = ".+效果从(%a+)身上消失。",
            ["CHAT_MSG_SPELL_AURA_GONE_OTHER"] = ".+效果从(%a+)身上消失。",
            ["CHAT_MSG_SPELL_SELF_BUFF"] = "你的.+治疗了(%a+).+点生命值。"
        },

        --------------
        -- Tooltips --
        --------------

        ["pet_tooltip"] = "注意:容易出现视觉错误。",
        ["classcolor_tooltip"] = "显示职业颜色",
        ["smartcenter_tooltip"] = "随着队伍的增加，始终保持整个框架的水平中心点在设定的位置。",
        ["healththreshold_tooltip"] = "姓名之前的百分比替换为健康不足。",
        ["manathreshhold_tooltip"] = "边框颜色变化前的法力百分比。",
        ["proximityleeway_tooltip"] = "在肯定确认后被视为“在范围内”的秒数。",
        ["proximityrate_tooltip"] = "两次接近检查之间的秒数。",
        ["cliquehook_tooltip"] = "可以使用Clique的组合键施法，在实例中28码以外使用NG进行检查。切换将重新加载UI。",
        ["powercolor_tooltip"] = "显示能量/怒气/蓝条的颜色",
        ["position_tooltip"] = "Shift+Ctrl = 100\nShift = 10",
        ["draggable_tooltip"] = "注意:可能引起客户端崩溃错误(如发生请禁用智能中心)",
        ["icon_tooltip"] = "切换以反转图标显示。",

        --------------------------------------------------------
        -- 以下为debuff魔法类型，在中文端也显示英文，请勿修改 --
        --------------------------------------------------------
        ["Magic"] = "魔法",
        ["Poison"] = "中毒",
        ["Curse"] = "诅咒",
        ["Disease"] = "疾病",
    }
end)
