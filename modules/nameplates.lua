
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Nameplates" -- L["Nameplates"] L["ModDesc-Nameplates"]
local ttName,ttColumns,tt,createTooltip,module = name.."TT",5
local nameplateStatus = {};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\nameplates"}; --IconName::Nameplates--


-- some local functions --
--------------------------
local function toggleCVar(self,v)
	ns.debug("<toggleCVar>",v.type,v.cvar,v.state);
	if v.type=="single" then
		ns.SetCVar(v.cvar, v.state and 0 or 1, v.cvar);
	elseif v.type=="group" then
		for cvar, value in pairs(v.cvar)do
			if type(cvar)=="string" and  GetCVar(cvar)~=value then
				ns.SetCVar(cvar, value, cvar);
			end
		end
	end
	if v.cvar and type(v.onChange)=="function" then
		v.onChange();
	end
	createTooltip(tt);
end

function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	local l = tt:AddHeader()
	tt:SetCell(l, 1, C("dkyellow",L[name]), nil, nil, ttColumns);
	tt:AddSeparator(1,0,0,0,0) -- transparent

	local depend, dependName,color = 3,"","gray"
	local _, line, cell = nil,false,1

	for _,row in ipairs(nameplateStatus)do
		local l=tt:AddLine();
		local cell = 1;
		for i,v in ipairs(row) do
			local color = "white";
			if v.txt and v.txt:find("\124") then
				v.txt=gsub(v.txt,"\124T.+\124t","");
			end
			v.txt = gsub(v.txt,"\n"," ");
			if v.cvar then
				v.state,v.dstate=nil,nil; -- cvar state, dependency cvar state
				if v.type=="single" then
					v.state = GetCVarBool(v.cvar);
				elseif v.type=="group" then
					v.state = true;
					for cvar, value in pairs(v.cvar)do
						if type(cvar)=="string" and  GetCVar(cvar)~=value then
							v.state = false;
						end
					end
				end
				if v.cvar_depend then
					v.dstate = GetCVarBool(v.cvar_depend);
				elseif v.cvar_depend_inv then
					v.dstate = not GetCVarBool(v.cvar_depend_inv);
				end
			end
			local tColors = type(v.colors);
			if tColors=="table" then
				local cIndex = v.state and 1 or 2;
				if v.dstate==false then
					cIndex = cIndex+2;
				end
				color = v.colors[cIndex];
			elseif tColors=="string" then
				color = v.colors;
			elseif v.state~=nil then
				color = v.state and "white" or "ltgray";
			end
			tt:SetCell(l,cell,C(color,v.txt:trim()), nil, nil, v.rows);
			if v.cvar then
				tt:SetCellScript(l, cell, "OnMouseUp", toggleCVar, v);
			end
			cell = cell + (v.rows or 1);
		end
		if row.separator then
			if row.separator==1 then
				tt:AddSeparator();
			else
				tt:AddSeparator(row.separator,0,0,0,0);
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(), 1, C("ltblue",L["MouseBtn"]).." || "..C("green",L["Names/Nameplates on/off"]), nil, nil, ttColumns)
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"CVAR_UPDATE"
	},
	config_defaults = {
		enabled = false
	}
}

-- function module.options() return {} end

function module.init()
	ttColumns = 6;
	local colors1,colors2,colors3 = {"white","gray"},{"white","gray","gray","dkgray"},{"dkgray","black","white","gray"};
	local UNML = InterfaceOptionsNamesPanelUnitNameplatesMakeLarger
	local UpdateNamePlateOptions = function() NamePlateDriverFrame:UpdateNamePlateOptions() end
	nameplateStatus = {
		{{txt=PLAYER,colors="ltblue"}, {txt=FRIENDLY,colors="ltgreen",rows=2}, {txt=ENEMY,colors="ltred",rows=3}, separator=1},
		{
			{txt=NAMES_LABEL, colors="ltyellow" },
			{txt=PLAYER,					type="single", cvar="UnitNameFriendlyPlayerName",	colors=colors1 },
			{txt=UNIT_NAME_FRIENDLY_MINIONS,type="single", cvar="UnitNameFriendlyMinionName",	colors=colors2,	cvar_depend="UnitNameFriendlyPlayerName" },
			{txt=PLAYER,					type="single", cvar="UnitNameEnemyPlayerName",		colors=colors1 },
			{txt=UNIT_NAME_ENEMY_MINIONS,	type="single", cvar="UnitNameEnemyMinionName",		colors=colors2,	cvar_depend="UnitNameEnemyPlayerName" },
		},
		{
			{txt=L["Nameplates"], colors="ltyellow" },
			{txt=PLAYER,								type="single", cvar="nameplateShowFriends",			colors=colors1 },
			{txt=UNIT_NAMEPLATES_SHOW_FRIENDLY_MINIONS,	type="single", cvar="nameplateShowFriendlyMinions",	colors=colors2,	cvar_depend="nameplateShowFriends" },
			{txt=PLAYER,								type="single", cvar="nameplateShowEnemies",			colors=colors1 },
			{txt=UNIT_NAMEPLATES_SHOW_ENEMY_MINIONS,	type="single", cvar="nameplateShowEnemyMinions",	colors=colors2,		cvar_depend="nameplateShowEnemies" },
			{txt=UNIT_NAMEPLATES_SHOW_ENEMY_MINUS,		type="single", cvar="nameplateShowEnemyMinus",		colors=colors2,		cvar_depend="nameplateShowEnemies" },
		},

		{separator=4},

		{{txt=UNIT_NAME_NPC,colors="ltblue"}, separator=1},
		{
			{txt=NPC_NAMES_DROPDOWN_ALL,type="single", cvar="UnitNameNPC",						colors=colors1 },
			{txt=L["Interactive NPCs"],	type="single", cvar="UnitNameInteractiveNPC",			colors=colors2,	cvar_depend_inv="UnitNameNPC", rows=2},
			{txt=L["Special NPCs"],		type="single", cvar="UnitNameFriendlySpecialNPCName",	colors=colors2,	cvar_depend_inv="UnitNameNPC", rows=2},
			{txt=L["Hostile NPCs"],		type="single", cvar="UnitNameHostleNPC",				colors=colors2,	cvar_depend_inv="UnitNameNPC"},
		},

		{separator=4},

		{{txt=L["More names"],	colors="ltblue" },separator=1},
		{
			{txt=UNIT_NAME_OWN,		type="single", cvar="UnitNameOwn", colors=colors1 },
			{txt=UNIT_NAME_NONCOMBAT_CREATURE,	type="single", cvar="UnitNameNonCombatCreatureName", colors=colors1, rows=3},
		},

		{separator=4},

		{{txt=L["More nameplate options"],	colors="ltblue" },separator=1},
		{
			{ txt=L["Nameplate size"], colors="dkyellow" },

			{ txt=PLAYER_DIFFICULTY1,
				colors=colors1,
				onChange=UpdateNamePlateOptions,
				type="group", cvar={NamePlateHorizontalScale=tostring(UNML.normalHorizontalScale),   NamePlateVerticalScale=tostring(UNML.normalVerticalScale)} -- 1, 1.4
			},
			{ txt=VIDEO_OPTIONS_FAIR,
				colors=colors1,
				onChange=UpdateNamePlateOptions,
				type="group", cvar={NamePlateHorizontalScale="1.18", NamePlateVerticalScale="1.9"}
			},
			{ txt=LARGE,
				colors=colors1,
				onChange=UpdateNamePlateOptions,
				type="group", cvar={NamePlateHorizontalScale=tostring(UNML.largeHorizontalScale), NamePlateVerticalScale=tostring(UNML.largeVerticalScale)} -- 1.4, 2.7
			},
			{ txt=L["Larger"], colors=colors1,
				onChange=UpdateNamePlateOptions,
				type="group", cvar={NamePlateHorizontalScale="1.9", NamePlateVerticalScale="3.8"}
			},
			{ txt=L["Even larger"], colors=colors1,
				row=2,
				onChange=UpdateNamePlateOptions,
				type="group", cvar={NamePlateHorizontalScale="2.6", NamePlateVerticalScale="5.2"}
			},
		},
		{
			{txt=L["Nameplates out of combat"],  type="single", cvar="nameplateShowAll", colors=colors1, rows=1},
			{txt=SHOW_NAMEPLATE_LOSE_AGGRO_FLASH,  type="single", cvar="ShowNamePlateLoseAggroFlash", colors=colors1, rows=4},
		},

		{separator=4},

		{{txt=DISPLAY_PERSONAL_RESOURCE,colors="ltblue" },separator=1},
		{{txt=DISPLAY_PERSONAL_RESOURCE,type="single", cvar="nameplateShowSelf", colors=colors1,rows=ttColumns}},
		{{txt=DISPLAY_PERSONAL_RESOURCE_ON_ENEMY,type="single", cvar="nameplateResourceOnTarget", colors=colors1, rows=ttColumns}},

		{separator=4},

		{{txt=AUCTION_SUBCATEGORY_OTHER,colors="ltblue"},separator=1},
		{{txt=L["Show quest unit circles"],type="single", cvar="ShowQuestUnitCircles", colors=colors1,rows=ttColumns}}
	};
end

function module.onevent(self,event,msg,msg2)
	local dataobj = ns.LDB:GetDataObjectByName(module.ldbName)
	local allFriends, friends = GetCVar("nameplateShowFriends"), GetCVar("UnitNameFriendlyPlayerName")
	local allEnemies, enemy = GetCVar("nameplateShowEnemies"), GetCVar("UnitNameEnemyPlayerName")

	if (friends == "1" or allFriends == "1") and (enemy == "1" or allEnemies == "1") then
		dataobj.text = FRIENDLY .. " & " .. ENEMY
	elseif (friends == "1" or allFriends == "1") then
		dataobj.text = FRIENDLY
	elseif (enemy == "1" or allEnemies == "1") then
		dataobj.text = ENEMY
	else
		dataobj.text = NONE
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "LEFT","LEFT","LEFT","LEFT","LEFT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
