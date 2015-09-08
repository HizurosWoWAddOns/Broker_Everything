
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Game Menu" -- L["Game Menu"]
local ldbName = name
local tt,tt2 = nil
local ttName,tt2Name = name.."TT",name.."TT2"
local last_click = 0
local iconCoords = "16:16:0:-1:64:64:4:56:4:56" --"16:16:0:-1:64:64:3:58:3:58"
local link = "|T%s:%s|t %s"
local link_disabled = "|T%s:%s:66:66:66|t "..C("gray", "%s")
local gmticket = {}
local customTitle = L[name]
local clickActions = {
	{"Do you really want to logout from this character?",function() securecall('Logout'); end}, -- L["Do you really want to logout from this character?"]
	{"Do you really want to left the game?",function() securecall('Quit'); end}, -- L["Do you really want to left the game?"]
	{"Do you really want to reload the UI?",function() securecall('ReloadUI'); end}, -- L["Do you really want to reload the UI?"]
	{"Do you really want to switch display mode?",function() SetCVar('gxWindow', 1 - GetCVar('gxWindow')); securecall('RestartGx'); end}, -- L["Do you really want to switch display mode?"]
}
local timeout=5;
local timeout_counter=0;

local menu = { --section 1
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
		--setIcon=function()
		--SetSmallGuildTabardTextures("player",
		--end,
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
	{name=VIDEO_OPTIONS_WINDOWED.."/"..VIDEO_OPTIONS_FULLSCREEN, 				iconName="Fullscreen",			macro="/script SetCVar('gxWindow', 1 - GetCVar('gxWindow')) RestartGx()",	taint=true,	--[[, view=IsMacClient()~=true]]},
	{name=L["Reload UI"],			iconName="ReloadUi",			macro="/reload",																taint=true},
	{name=LOGOUT,					iconName="Logout",				macro="/logout",																taint=true},
	{name=EXIT_GAME,				iconName="ExitGame",			macro="/quit",																	taint=true}
}


-------------------------------------------
-- register icon names and default files --
-------------------------------------------

-- broker button icon
I[name]              = {iconfile="Interface\\Addons\\"..addon.."\\media\\stuff"}; --IconName::Game Menu--

-- game menu entry icons
local ClassIconCoords={
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
}

I["gm_Character-neutral"] = {iconfile="Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes", coordsStr=ClassIconCoords[ns.player.class]};						--IconName::gm_Character-neutral--
--I["gm_Character-neutral"] = {iconfile="Interface\\buttons\\ui-microbutton-"..ns.player.class, coordsStr="16:16:0:-1:64:64:5:54:32:59"};						--IconName::gm_Character-neutral--

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
I["gm_Help"]              = {iconfile="Interface\\ICONS\\inv_misc_questionmark"}																			--IconName::gm_Help--
I["gm_SysOpts"]           = {iconfile="Interface\\ICONS\\inv_gizmo_02"}																						--IconName::gm_SysOpts--
I["gm_KeyBinds"]          = {iconfile="interface\\macroframe\\macroframe-icon"}																				--IconName::gm_KeyBinds--
I["gm_UiOpts"]            = {iconfile="Interface\\ICONS\\inv_gizmo_02"}																						--IconName::gm_UiOpts--
I["gm_Macros"]            = {iconfile="interface\\macroframe\\macroframe-icon"}																				--IconName::gm_Macros--
I["gm_MacOpts"]           = {iconfile="Interface\\ICONS\\inv_gizmo_02"}																						--IconName::gm_MacOpts--
I["gm_Addons"]            = {iconfile="Interface\\ICONS\\inv_misc_enggizmos_30"}																			--IconName::gm_Addons--
I["gm_Fullscreen"]        = {iconfile="Interface\\Addons\\"..addon.."\\media\\stuff", coordsStr="16:16:0:-1:16:16:0:16:0:16"}								--IconName::gm_Fullscreen--
I["gm_ReloadUi"]          = {iconfile="Interface\\ICONS\\achievement_guildperk_quick and dead"}																--IconName::gm_ReloadUi--
I["gm_Logout"]            = {iconfile="Interface\\icons\\racechange"}																						--IconName::gm_Logout--
I["gm_ExitGame"]          = {iconfile="Interface\\ICONS\\inv_misc_enggizmos_27"}																			--IconName::gm_ExitGame--
I["gm_gmticket"]          = {iconfile="Interface\\CHATFRAME\\UI-CHATICON-BLIZZ", coordsStr="0:2"}															--IconName::gm_gmticket--
I["gm_gmticket_edit"]     = {iconfile="Interface\\ICONS\\inv_misc_note_05"}																					--IconName::gm_gmticket_edit--
I["gm_gmticket_cancel"]   = {iconfile="Interface\\buttons\\ui-grouploot-pass-up",coordsStr="16:16:0:-1:32:32:2:32:2:32"}									--IconName::gm_gmticket_cancel--
I["gm_Heirlooms"]         = {iconfile="Interface\\Icons\\inv_misc_enggizmos_19", coordsStr="16:16:0:-1:16:16:1:14:1:14"}									--IconName::gm_heirlooms--
I["gm_Challenges"]        = {iconfile="Interface\\Icons\\Achievement_ChallengeMode_ArakkoaSpires_Hourglass",coordsStr="16:16:0:-1:16:16:1:14:1:14"}			--IconName::gm_Challenges--



---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["A broker that merge blizzards game menu, microbutton bar and more into one tooltip with clickable elements. It is not recommented to use it in combat."]
ns.modules[name] = {
	desc = desc,
	events = {
		"UPDATE_WEB_TICKET"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		customTitle = "",
		hideSection2 = false,
		hideSection3 = false,
		disableOnClick = false,
		customTooltipTitle = false,
		showGMTicket = true,
		showTaintingEntries = false
	},
	config_allowed = nil,
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="hideSection2", label=L["Hide section 2"], tooltip=L["Hide section 2 in tooltip"] },
		{ type="toggle", name="hideSection3", label=L["Hide section 3"], tooltip=L["Hide section 3 in tooltip"] },
		{ type="toggle", name="disableOnClick", label=L["Disable Click options"], tooltip=L["Disable the click options on broker button"] },
		{ type="input",  name="customTitle", label=L["Custom title"], tooltip=L["Set your own Title instead of 'Game Menu'"], event=true },
		{ type="toggle", name="customTooltipTitle", label=L["Custom title in tooltip"], tooltip=L["Use custom title as tooltip title"] },
		{ type="toggle", name="showGMTicket", label=L["Show GMTicket"], tooltip=L["Show GMTickets in tooltip and average wait time in broker button"] },
		{ type="toggle", name="showTaintingEntries", label=L["Show tainting entries"], tooltip=L["Show all entries there taint the environment. Be carefull. Can produce error in combat."] }
	}
}


--------------------------
-- some local functions --
--------------------------
StaticPopupDialogs["CONFIRM"] = {
	text = L["Are you sure you want to Reload the UI?"],
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function()
		ReloadUI()
	end,
	timeout = 20,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 5,
}

local function updateGMTicket()
	local obj = ns.LDB:GetDataObjectByName(ldbName)
	if Broker_EverythingDB[name].showGMTicket and gmticket.hasTicket and gmticket.ticketStatus~=LE_TICKET_STATUS_OPEN then
		local icon = I("gm_gmticket")
		obj.text = C("cyan",(gmticket.waitTime) and SecondsToTime(gmticket.waitTime*60) or L["Open GM Ticket"]) .. link:format(icon.iconfile,(icon.coordsStr or iconCoords),"")
	else
		gmticket.hasTicket = false
		ns.modules[name].onevent("BE_DUMMY_EVENT")
	end
end

local function pushedTooltip(parent,id,msg)
	if (tt) and (tt.key) and (tt.key==ttName) then ns.hideTooltip(tt,ttName,true); end
	tt2 = ns.LQT:Acquire(tt2Name, 1, "LEFT");
	ns.createTooltip(parent,tt2);

	tt2:Clear();
	tt2:AddLine(C("orange",L[msg]));
	tt2:AddSeparator();
	tt2:AddLine(C("yellow",L["Then push again..."]).." "..timeout_counter);

	if (id==nextAction) then
		timeout_counter = timeout_counter - 1;
		C_Timer.After(1,function()
			if (timeout_counter==0) or (nextAction==nil) then
				ns.hideTooltip(tt2,tt2Name,true);
				tt2=nil;
			elseif (id==nextAction) then
				pushedTooltip(parent,id,msg);
			end
		end);
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------

ns.modules[name].init = function()
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	local obj = ns.LDB:GetDataObjectByName(ldbName)
	if Broker_EverythingDB[name].customTitle~="" and type(Broker_EverythingDB[name].customTitle)=="string" then
		customTitle = Broker_EverythingDB[name].customTitle
	end
	if obj~=nil then
		obj.text = customTitle
	end
end

ns.modules[name].onevent = function(self, ...)
	local event, _ = ...

	if event == "UPDATE_WEB_TICKET" then
		_, gmticket.hasTicket, gmticket.numTickets, gmticket.ticketStatus, gmticket.caseIndex, gmticket.waitTime, gmticket.waitMsg = ...
		updateGMTicket()
	elseif event == "BE_DUMMY_EVENT" then
		local obj = ns.LDB:GetDataObjectByName(ldbName)
		customTitle = Broker_EverythingDB[name].customTitle~="" and type(Broker_EverythingDB[name].customTitle)=="string" and Broker_EverythingDB[name].customTitle or L[name]
		if obj~=nil then
			obj.text = customTitle
		end
	end
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self, direction) end

ns.modules[name].ontooltip = function(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...

	local line, column
	local section, secHide = 1, false
	local oneCell = Broker_EverythingDB[name].hideSection2 and Broker_EverythingDB[name].hideSection3
	local cell = 1

	tt.secureButtons = {}

	tt:Clear()

	if Broker_EverythingDB[name].customTooltipTitle then
		tt:AddHeader(C("dkyellow", customTitle))
	else
		tt:AddHeader(C("dkyellow", L[name]))
	end
	tt:AddSeparator()

	for i, v in ipairs(menu) do
		if (v.taint) and (not Broker_EverythingDB[name].showTaintingEntries) then
			-- nothing
		elseif v.sep==true then
			section = section + 1
			secHide = (section==2 and Broker_EverythingDB[name].hideSection2) or (section==3 and Broker_EverythingDB[name].hideSection3)

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
					if m=="class" and I["gm_"..v.iconName].iconfile=="interface\\icons\\inv_misc_questionmark" then
						v.iconName = "Character-neutral"
					end
				end
				local icon = I("gm_"..v.iconName)
				tt:SetCell(line, cell, (v.disabled and link_disabled or link):format((icon.iconfile or "interface\\icons\\inv_misc_questionmark"), (icon.coordsStr or iconCoords), v.name), nil, nil, oneCell and 2 or 1)
				if (not v.disabled) or not (InCombatLockdown() and (v.secure or v.click or v.macro)) then
					local e, f
					if v.secure~=nil then
						e, f = "OnEnter", function(self)
							ns.secureButton(self, { {typeName="type", typeValue="click", attrName="clickbutton", attrValue=""}, {typeName="type", typeValue="onmouseup", attrName="_onmouseup", attrValue=v.secure} }, v.name)
							tinsert(tt.secureButtons,v.name)
						end
					elseif v.click~=nil then
						e, f = "OnEnter", function(self)
							ns.secureButton(self, { {typeName="type", typeValue="click", attrName="clickbutton", attrValue=_G[v.click]} }, v.name)
							tinsert(tt.secureButtons,v.name)
						end
					elseif v.macro~=nil then
						e, f = "OnEnter", function(self)
							ns.secureButton(self, { {typeName="type", typeValue="macro", attrName="macrotext", attrValue=v.macro} }, v.name)
							tinsert(tt.secureButtons,v.name)
						end
					else
						e, f = "OnMouseUp", function()
							ns.hideTooltip(tt,ttName,true)
							v.func()
						end
					end
					tt:SetCellScript(line, cell, e, f)
				end
				if not oneCell then
					if cell==1 then cell=2 else cell=1 end
				end
			end
		end
	end

	-- Open GM Ticket info Area
	if Broker_EverythingDB[name].showGMTicket and gmticket.hasTicket and (gmticket.ticketStatus~=LE_TICKET_STATUS_RESPONSE or gmticket.ticketStatus~=LE_TICKET_STATUS_SURVEY) then
		waitTime, waitMsg, ticketStatus = gmticket.waitTime,gmticket.waitMsg,gmticket.ticketStatus
		tt:AddSeparator(5,0,0,0,0)
		line, column = tt:AddLine()
		local icon = I("gm_gmticket")
		tt:SetCell(line,1,link:format(icon.iconfile,(icon.coordsStr or iconCoords),C("ltblue",TICKET_STATUS)),tt:GetHeaderFont(),nil,2)
		tt:AddSeparator()
		line,column = tt:AddLine()
		local edit,cancel = I("gm_gmticket_edit"),I("gm_gmticket_cancel")
		tt:SetCell(line,1,link:format(edit.iconfile,(edit.coordsStr or iconCoords),L["Edit ticket"]))
		tt:SetCell(line,2,link:format(cancel.iconfile,(cancel.coordsStr or iconCoords),L["Cancel ticket"]))
		tt:SetCellScript(line,1,"OnMouseUp",function(self,button)
			HelpFrame_ShowFrame(HELPFRAME_SUBMIT_TICKET)
			if gmticket.caseIndex then
				HelpBrowser:OpenTicket(gmticket.caseIndex)
			end
		end)
		tt:SetCellScript(line,2,"OnMouseUp",function(self,button)
			if not StaticPopup_Visible("HELP_TICKET_ABANDON_CONFIRM") then
				StaticPopup_Show("HELP_TICKET_ABANDON_CONFIRM")
			end
		end)
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

	if Broker_EverythingDB[name].disableOnClick or (not Broker_EverythingDB.showHints) then return end

	tt:AddSeparator(4, 0, 0, 0, 0)
	line, column = tt:AddLine()
	tt:SetCell(line, 1,
		C("copper", L["Left-click"]).." || "..C("green", L["Logout"])
		.."|n"..
		C("copper", L["Right-click"]).." || "..C("green", L["Quit game"])
		.."|n"..
		C("copper", L["Shift+Left-click"]).." || "..C("green", L["Reload UI"])
	, nil, nil, 2)

end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	tt = ns.LQT:Acquire(ttName, 2, "LEFT", "LEFT")
	ns.modules[name].ontooltip(tt)
	ns.createTooltip(self, tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

ns.modules[name].onclick = function(self, button)
	if Broker_EverythingDB[name].disableOnClick then return end

	local shift = IsShiftKeyDown()

	local _= function(id)
		local a = clickActions[id] or {"Error",function() end};
		if (id~=nextAction) then
			nextAction=id;
			timeout_counter=timeout;
			pushedTooltip(self,id,a[1]);
			C_Timer.After(timeout, function()
				if (id==nextAction) then
					nextAction=nil;
				end
			end);
		elseif (id==nextAction) then
			a[2]();
		end
	end

	if (button=="LeftButton") and (not shift) then
		_(1); -- logout
	elseif (button=="RightButton") and (not shift) then
		_(2); -- quit
	elseif (button=="LeftButton") and (shift) then
		_(3); -- reload
	elseif (button=="RightButton") and (shift) then
		-- _(4); -- display mode
	end
end

-- ns.modules[name].ondblclick = function(self, button) end

