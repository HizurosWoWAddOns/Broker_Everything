
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Game Menu"; -- MAINMENU_BUTTON L["ModDesc-Game Menu"]
local ttName,tt,module = name.."TT"
local last_click = 0
local iconCoords = "16:16:0:-1:64:64:4:56:4:56" --"16:16:0:-1:64:64:3:58:3:58"
local link = "|T%s:%s|t %s"
local link_disabled = "|T%s:%s:66:66:66|t "..C("gray", "%s")
local gmticket = {}
local customTitle = MAINMENU_BUTTON
local ClassIconCoords=5,0;
local IsBlizzCon = IsBlizzCon or function() return false; end -- Legion Fix
local menu = {};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\stuff"}; --IconName::Game Menu--


-- some local functions --
--------------------------
local function updateGMTicket()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName)
	if ns.profile[name].showGMTicket and gmticket.hasTicket and gmticket.ticketStatus~=LE_TICKET_STATUS_OPEN then
		local icon = I("gm_gmticket")
		obj.text = C("cyan",(gmticket.waitTime) and SecondsToTime(gmticket.waitTime*60) or L["Open GM Ticket"]) .. link:format(icon.iconfile,(icon.coordsStr or iconCoords),"")
	else
		gmticket.hasTicket = false
		module.onevent("BE_DUMMY_EVENT")
	end
end

local function tooltipCellScript_OnAction(self,info)
	if info.click~=nil then
		ns.secureButton(self, { attributes={type="click", clickbutton=_G[info.click]} }, info.name);
		tinsert(tt.secureButtons,info.name);
	elseif info.macro~=nil then
		ns.secureButton(self, { attributes={type="macro", macrotext=info.macro} }, info.name);
		tinsert(tt.secureButtons,info.name);
	elseif type(info.func)=="function" then
		ns.hideTooltip(tt);
		info.func();
	end
end

local function showGMTicket()
	HelpFrame_ShowFrame(HELPFRAME_SUBMIT_TICKET)
	if gmticket.caseIndex then
		HelpBrowser:OpenTicket(gmticket.caseIndex)
	end
end

local function deleteGMTicket()
	if not StaticPopup_Visible("HELP_TICKET_ABANDON_CONFIRM") then
		StaticPopup_Show("HELP_TICKET_ABANDON_CONFIRM")
	end
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	local line, column
	local section, secHide = 1, false
	local oneCell = ns.profile[name].hideSection2 and ns.profile[name].hideSection3
	local cell = 1

	tt.secureButtons = {}

	if tt.lines~=nil then tt:Clear(); end

	if ns.profile[name].customTooltipTitle then
		tt:AddHeader(C("dkyellow", customTitle))
	else
		tt:AddHeader(C("dkyellow", MAINMENU_BUTTON))
	end
	tt:AddSeparator()

	for i, v in ipairs(menu) do
		if (v.taint) and (not ns.profile[name].showTaintingEntries) then
			-- nothing
		elseif v.sep==true then
			section = section + 1
			secHide = (section==2 and ns.profile[name].hideSection2) or (section==3 and ns.profile[name].hideSection3)

			if not secHide then
				tt:AddSeparator()
				cell=1
			end
		elseif secHide then
			-- nothing
		else
			if v.get~=nil then v.get(v) end
			if v.disabled==nil then v.disabled=false end
			if v.view==nil then v.view=true end
			if v.name~=nil and v.view then
				if cell==1 then line, column = tt:AddLine() end
				local m=v.iconName:match("-%{(.*)%}")
				if m then
					v.iconName = string.gsub(v.iconName, "%{"..m.."%}", ns.player[m]:lower())
					local V = I("gm_"..v.iconName)
					if m=="class" and I["gm_"..v.iconName].iconfile==ns.icon_fallback then
						v.iconName = "Character-neutral"
					end
				end
				local icon = I("gm_"..v.iconName)
				tt:SetCell(line, cell, (v.disabled and link_disabled or link):format((icon.iconfile or ns.icon_fallback), (icon.coordsStr or iconCoords), v.name), nil, nil, oneCell and 2 or 1)
				if (not v.disabled) or not (InCombatLockdown() and (v.click or v.macro)) then
					tt:SetCellScript(line,cell, (v.click or v.macro) and "OnEnter" or "OnMouseUp",tooltipCellScript_OnAction, v);
				end
				if not oneCell then
					if cell==1 then cell=2 else cell=1 end
				end
			end
		end
	end

	-- Open GM Ticket info Area
	if ns.profile[name].showGMTicket and gmticket.hasTicket and (gmticket.ticketStatus~=LE_TICKET_STATUS_RESPONSE or gmticket.ticketStatus~=LE_TICKET_STATUS_SURVEY) then
		local waitTime, waitMsg, ticketStatus = gmticket.waitTime,gmticket.waitMsg,gmticket.ticketStatus
		tt:AddSeparator(5,0,0,0,0)
		line, column = tt:AddLine()
		local icon = I("gm_gmticket")
		tt:SetCell(line,1,link:format(icon.iconfile,(icon.coordsStr or iconCoords),C("ltblue",TICKET_STATUS)),tt:GetHeaderFont(),nil,2)
		tt:AddSeparator()
		line,column = tt:AddLine()
		local edit,cancel = I("gm_gmticket_edit"),I("gm_gmticket_cancel")
		tt:SetCell(line,1,link:format(edit.iconfile,(edit.coordsStr or iconCoords),HELP_TICKET_EDIT))
		tt:SetCell(line,2,link:format(cancel.iconfile,(cancel.coordsStr or iconCoords),HELP_TICKET_ABANDON))
		tt:SetCellScript(line,1,"OnMouseUp", showGMTicket);
		tt:SetCellScript(line,2,"OnMouseUp", deleteGMTicket);
		if (ticketStatus == LE_TICKET_STATUS_NMI) then -- ticketStatus = 3
			line,column = tt:AddLine()
			tt:SetCell(line,1,TICKET_STATUS_NMI,nil,nil,2)
		elseif (ticketStatus == LE_TICKET_STATUS_OPEN) then -- ticketStatus = 1
			line,column = tt:AddLine()
			if (waitMsg and waitTime > 0) then
				tt:SetCell(line,1,waitMsg:format(SecondsToTime(waitTime*60)),nil,nil,2)
			elseif (waitMsg) then
				tt:SetCell(line,1,waitMsg,nil,nil,2)
			elseif (waitTime > 120) then
				tt:SetCell(line,1,GM_TICKET_HIGH_VOLUME,nil,nil,2)
			elseif (waitTime > 0) then
				tt:SetCell(line,1,format(GM_TICKET_WAIT_TIME, SecondsToTime(waitTime*60)),nil,nil,2)
			else
				tt:SetCell(line,1,GM_TICKET_UNAVAILABLE,nil,nil,2)
			end
		elseif (ticketStatus == LE_TICKET_STATUS_SURVEY) then -- ticketStatus = 2
		elseif (ticketStatus == LE_TICKET_STATUS_RESPONSE) then -- ticketStatus = 4

		end
	end
	--

	if ns.profile.GeneralOptions.showHints and ns.profile[name].disableOnClick then
		tt:AddSeparator(4, 0, 0, 0, 0)
		line, column = tt:AddLine()
		tt:SetCell(line, 1,
			C("copper", L["MouseBtnL"]).." || "..C("green", LOGOUT)
			.."|n"..
			C("copper", L["MouseBtnR"]).." || "..C("green", EXIT_GAME)
			.."|n"..
			C("copper", L["ModKeyS"].."+"..L["MouseBtnL"]).." || "..C("green", RELOADUI)
		, nil, nil, 2);
	end
	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"UPDATE_WEB_TICKET"
	},
	config_defaults = {
		enabled = false,
		customTitle = "",
		hideSection2 = false,
		hideSection3 = false,
		disableOnClick = false,
		customTooltipTitle = false,
		showGMTicket = true,
		showTaintingEntries = false
	},
}

function module.options()
	return {
		broker = {
			disableOnClick={ type="toggle", order=1, name=L["Disable Click options"], desc=L["Disable the click options on broker button"] },
			customTitle={ type="input", order=2, name=L["Custom title"], desc=L["Set your own Title instead of 'Game Menu'"] },
		},
		tooltip = {
			hideSection2={ type="toggle", order=1, name=L["Hide section 2"], desc=L["Hide section 2 in tooltip"] },
			hideSection3={ type="toggle", order=2, name=L["Hide section 3"], desc=L["Hide section 3 in tooltip"] },
			customTooltipTitle={ type="toggle", order=3, name=L["Custom title in tooltip"], desc=L["Use custom title as tooltip title"] },
			showGMTicket={ type="toggle", order=4, name=L["Show GMTicket"], desc=L["Show GMTickets in tooltip and average wait time in broker button"] },
			showTaintingEntries={ type="toggle", order=5, name=L["Show tainting entries"], desc=L["Show all entries their tainting the environment. Be carefull. Can produce error in combat."] }
		},
		misc = nil,
	}
end

function module.init()
	ClassIconCoords={
		["WARRIOR"] = "16:16:0:-1:256:256:5:59:5:59",
		["MAGE"] = "16:16:0:-1:256:256:69:122:5:59",
		["ROGUE"] = "16:16:0:-1:256:256:132:185:5:59",
		["DRUID"] = "16:16:0:-1:256:256:195:248:5:59",
		["HUNTER"] = "16:16:0:-1:256:256:5:59:69:123",
		["SHAMAN"] = "16:16:0:-1:256:256:69:122:69:123",
		["PRIEST"] = "16:16:0:-1:256:256:132:185:69:123",
		["WARLOCK"] = "16:16:0:-1:256:256:195:248:69:123",
		["PALADIN"] = "16:16:0:-1:256:256:5:59:133:187",
		["DEATHKNIGHT"] = "16:16:0:-1:256:256:69:123:133:187",
		["MONK"] = "16:16:0:-1:256:256:133:184:133:187",
	};

	I["gm_Character-neutral"] = {iconfile="Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes", coordsStr=ClassIconCoords[ns.player.class]};						--IconName::gm_Character-neutral--
	I["gm_Spellbook"]         = {iconfile="Interface\\ICONS\\inv_misc_book_09"}																					--IconName::gm_Spellbook--
	I["gm_Talents"]           = {iconfile="Interface\\ICONS\\ability_marksmanship"}																				--IconName::gm_Talents--
	I["gm_Achievments"]       = {iconfile="Interface\\buttons\\ui-microbutton-achievement-up", coordsStr="16:16:0:-1:64:64:5:54:32:59"}							--IconName::gm_Achievments--
	I["gm_Questlog"]          = {iconfile="interface\\lfgframe\\lfgicon-quest"}																					--IconName::gm_Questlog--
	I["gm_LFGuild"]           = {iconfile="Interface\\buttons\\UI-MicroButton-Guild-Disabled-"..ns.player.faction, coordsStr="16:16:0:-1:64:64:8:54:32:59"}		--IconName::gm_FLGuild--
	I["gm_Guild"]             = {iconfile="Interface\\buttons\\UI-MicroButton-Guild-Disabled-"..ns.player.faction, coordsStr="16:16:0:-1:64:64:8:54:32:59"}		--IconName::gm_Guild--
	I["gm_Friends"]           = {iconfile="Interface\\ICONS\\achievement_guildperk_everybodysfriend"}															--IconName::gm_Friends--
	I["gm_PvP-neutral"]       = {iconfile="Interface\\minimap\\tracking\\BattleMaster", coordsStr="16:16:0:-1:16:16:0:16:0:16"}									--IconName::gm_PvP-neutral--
	I["gm_PvP-alliance"]      = {iconfile="interface\\pvpframe\\pvp-currency-Alliance", coordsStr="16:16:0:-1:16:16:0:16:0:16"}									--IconName::gm_PvP-alliance--
	I["gm_PvP-horde"]         = {iconfile="interface\\pvpframe\\pvp-currency-Horde", coordsStr="16:16:0:-1:16:16:0:16:0:16"}									--IconName::gm_PvP-horde--
	I["gm_Raidfinder"]        = {iconfile="Interface\\ICONS\\inv_helmet_06"}																					--IconName::gm_Raidfinder--
	I["gm_LFDungeon"]         = {iconfile="Interface\\ICONS\\levelupicon-lfd"}																					--IconName::gm_LFDungeon--
	I["gm_Mounts"]            = {iconfile="Interface\\ICONS\\mountjournalportrait"}																				--IconName::gm_Mounts--
	I["gm_Pets"]              = {iconfile="Interface\\ICONS\\inv_box_petcarrier_01"}																			--IconName::gm_Pets--
	I["gm_ToyBox"]            = {iconfile="Interface\\ICONS\\Trade_Archaeology_chestoftinyglassanimals"}														--IconName::gm_ToyBox--
	I["gm_EJ"]                = {iconfile="Interface\\buttons\\UI-MicroButton-EJ-Up", coordsStr="16:16:0:-1:64:64:8:54:32:59"}									--IconName::gm_EJ--
	I["gm_Store"]             = {iconfile="Interface\\ICONS\\WoW_Store"}																						--IconName::gm_Store--
	I["gm_Help"]              = {iconfile=ns.icon_fallback}																										--IconName::gm_Help--
	I["gm_SysOpts"]           = {iconfile="Interface\\ICONS\\inv_gizmo_02"}																						--IconName::gm_SysOpts--
	I["gm_KeyBinds"]          = {iconfile="interface\\macroframe\\macroframe-icon"}																				--IconName::gm_KeyBinds--
	I["gm_UiOpts"]            = {iconfile="Interface\\ICONS\\inv_gizmo_02"}																						--IconName::gm_UiOpts--
	I["gm_Macros"]            = {iconfile="interface\\macroframe\\macroframe-icon"}																				--IconName::gm_Macros--
	I["gm_MacOpts"]           = {iconfile="Interface\\ICONS\\inv_gizmo_02"}																						--IconName::gm_MacOpts--
	I["gm_Addons"]            = {iconfile="Interface\\ICONS\\inv_misc_enggizmos_30"}																			--IconName::gm_Addons--
	I["gm_ReloadUi"]          = {iconfile="Interface\\ICONS\\achievement_guildperk_quick and dead"}																--IconName::gm_ReloadUi--
	I["gm_gmticket"]          = {iconfile="Interface\\CHATFRAME\\UI-CHATICON-BLIZZ", coordsStr="0:2"}															--IconName::gm_gmticket--
	I["gm_gmticket_edit"]     = {iconfile="Interface\\ICONS\\inv_misc_note_05"}																					--IconName::gm_gmticket_edit--
	I["gm_gmticket_cancel"]   = {iconfile="Interface\\buttons\\ui-grouploot-pass-up",coordsStr="16:16:0:-1:32:32:2:32:2:32"}									--IconName::gm_gmticket_cancel--
	I["gm_Heirlooms"]         = {iconfile="Interface\\Icons\\inv_misc_enggizmos_19", coordsStr="16:16:0:-1:16:16:1:14:1:14"}									--IconName::gm_heirlooms--
	I["gm_Challenges"]        = {iconfile="Interface\\Icons\\Achievement_ChallengeMode_ArakkoaSpires_Hourglass",coordsStr="16:16:0:-1:16:16:1:14:1:14"}			--IconName::gm_Challenges--

	menu = { --section 1
		{name=CHARACTER_BUTTON,		iconName="Character-{class}",	func=function() securecall("ToggleCharacter", "PaperDollFrame") end },
		{name=SPELLBOOK,			iconName="Spellbook",			click='SpellbookMicroButton',			disabled=IsBlizzCon(), taint=true},
		{name=TALENTS,				iconName="Talents",				click='TalentMicroButton',				disabled=UnitLevel("player")<10, taint=true},
		{name=ACHIEVEMENT_BUTTON,	iconName="Achievments",			click='AchievementMicroButton',		taint=true},
		{name=QUESTLOG_BUTTON,		iconName="Questlog",			click='QuestLogMicroButton',			taint=true},
		{
			name=LOOKINGFORGUILD,
			iconName="LFGuild",
			click='GuildMicroButton',
			disabled=(IsTrialAccount() or IsBlizzCon()),
			get=function(v)
				if ns.player.faction=="Neutral" then
					v.disabled=true;
					v.iconName="Help";
				end
				if not v.disabled and IsInGuild() then
					v.name=GUILD;
					v.iconName = "Guild";
				end
			end,
			taint=true
		},
		{name=SOCIAL_BUTTON,		iconName="Friends",			func=function() securecall("ToggleFriendsFrame", 1) end,		disabled=IsTrialAccount()},

		{name=GROUP_FINDER,			iconName="PvP-{faction}",	func=function() securecall("PVEFrame_ToggleFrame","GroupFinderFrame"); end, disabled=(UnitLevel("player")<SHOW_LFD_LEVEL or IsBlizzCon())},
		{name=PLAYER_V_PLAYER,		iconName="LFDungeon",		func=function() securecall("PVEFrame_ToggleFrame","PVPUIFrame"); end, disabled=(UnitLevel("player")<SHOW_PVP_LEVEL or IsBlizzCon())},
		{name=CHALLENGES,			iconName="Challenges",		func=function() securecall("PVEFrame_ToggleFrame","ChallengesFrame"); end, disabled=(UnitLevel("player")<SHOW_LFD_LEVEL or IsBlizzCon())},

		{name=MOUNTS,				iconName="Mounts",			func=function() if not CollectionsJournal then LoadAddOn("Blizzard_Collections") end ShowUIPanel(CollectionsJournal); securecall("CollectionsJournal_SetTab", CollectionsJournal, 1) end,		taint=true},
		{name=PET_JOURNAL,			iconName="Pets",			func=function() if not CollectionsJournal then LoadAddOn("Blizzard_Collections") end ShowUIPanel(CollectionsJournal); securecall("CollectionsJournal_SetTab", CollectionsJournal, 2) end,		taint=true},
		{name=TOY_BOX,				iconName="ToyBox",			func=function() if not CollectionsJournal then LoadAddOn("Blizzard_Collections") end ShowUIPanel(CollectionsJournal); securecall("CollectionsJournal_SetTab", CollectionsJournal, 3) end,		taint=true},
		{name=HEIRLOOMS,			iconName="Heirlooms",		func=function() if not CollectionsJournal then LoadAddOn("Blizzard_Collections") end ShowUIPanel(CollectionsJournal); securecall("CollectionsJournal_SetTab", CollectionsJournal, 4) end,		taint=true},

		{name=ENCOUNTER_JOURNAL,	iconName="EJ",				func=function() securecall("ToggleEncounterJournal") end,														iconCoords=""},
		{name=BLIZZARD_STORE,		iconName="Store",			click='StoreMicroButton',															disabled=IsTrialAccount(), taint=true},
		{sep=true}, -- section 2
		{name=GAMEMENU_HELP,		iconName="Help",			func=function() securecall("ToggleHelpFrame") end,		},
		{name=SYSTEMOPTIONS_MENU,	iconName="SysOpts",			func=function() securecall("VideoOptionsFrame_Toggle") end,		},
		{name=KEY_BINDINGS,			iconName="KeyBinds",		func=function() securecall("KeyBindingFrame_LoadUI") securecall("ShowUIPanel", KeyBindingFrame) end,		taint=true},
		{name=UIOPTIONS_MENU,		iconName="UiOpts",			func=function() securecall("InterfaceOptionsFrame_Show") end,		},
		{name=MACROS,				iconName="Macros",			func=function() securecall("ShowMacroFrame") end,		},
		{name=MAC_OPTIONS,			iconName="MacOpts",			func=function() securecall("ShowUIPanel", MacOptionsFrame) end,		 view=IsMacClient()==true},
		{name=ADDONS,				iconName="Addons",			view=( (IsAddOnLoaded("OptionHouse")) or (IsAddOnLoaded("ACP")) or (IsAddOnLoaded("Ampere")) or (IsAddOnLoaded("stAddonManager")) or (_G.AddonList) ),
		func=function()
			if (IsAddOnLoaded("OptionHouse")) then
				OptionHouse:Open(1);
			elseif (IsAddOnLoaded("ACP")) then
				ACP:ToggleUI();
			elseif (IsAddOnLoaded("Ampere")) then
				InterfaceOptionsFrame_OpenToCategory("Ampere");
			elseif (IsAddOnLoaded("stAddonManager")) then
				stAddonManager:LoadWindow()
			elseif (_G.AddonList) then
				AddonList:Show();
			end
		end},
		{sep=true, taint=true}, -- section 3
		{name=RELOADUI,			iconName="ReloadUi",			macro="/reload",																taint=true},
	}
end

function module.onevent(self, event, arg1, ...)
	if event == "UPDATE_WEB_TICKET" then
		local _
		_, gmticket.hasTicket, gmticket.numTickets, gmticket.ticketStatus, gmticket.caseIndex, gmticket.waitTime, gmticket.waitMsg = ...
		updateGMTicket()
	elseif event=="PLAYER_LOGIN" then
		local label = MAINMENU_BUTTON;
		if type(ns.profile[name].customTitle)=="string" and ns.profile[name].customTitle~="" then
			label = ns.profile[name].customTitle;
		end
		ns.LDB:GetDataObjectByName(module.ldbName).text = label;
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self, direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, 2, "LEFT", "LEFT"},{false},{self})
	createTooltip(tt);
end

-- function module.onleave(self) end

function module.onclick(self, button)
	if ns.profile[name].disableOnClick then return end

	local shift = IsShiftKeyDown()

	if (button=="LeftButton") and (shift) then
		C_UI.Reload();
	end
end

-- function module.ondblclick(self, button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
