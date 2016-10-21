
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
local NAMEPLATES = NAMEPLATES or "Nameplates"

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Nameplates" -- L["Nameplates"]
local ldbName,ttName,ttColumns,tt,createTooltip = name,name.."TT",5

local nameplateStatus = {
	{ FRIENDLY },
	{ NAMES_LABEL, false },
	{ PLAYER,						"UnitNameFriendlyPlayerName"},
	{ UNIT_NAME_FRIENDLY_PETS,		"UnitNameFriendlyPetName", ""},
	{ UNIT_NAME_FRIENDLY_GUARDIANS, "UnitNameFriendlyGuardianName", ""},
	{ UNIT_NAME_FRIENDLY_TOTEMS,	"UnitNameFriendlyTotemName", ""},
	{ true },

	{ L["Nameplates"], false },
	{ PLAYER,						"nameplateShowFriends"},
	{ UNIT_NAME_FRIENDLY_PETS,		"nameplateShowFriendlyPets", "nameplateShowFriends"},
	{ UNIT_NAME_FRIENDLY_GUARDIANS, "nameplateShowFriendlyGuardians", "nameplateShowFriends"},
	{ UNIT_NAME_FRIENDLY_TOTEMS,	"nameplateShowFriendlyTotems", "nameplateShowFriends"},
	{ true },

	{ ENEMY },
	{ NAMES_LABEL, false },
	{ PLAYER,						"UnitNameEnemyPlayerName"},
	{ UNIT_NAME_ENEMY_PETS,			"UnitNameEnemyPetName", ""},
	{ UNIT_NAME_ENEMY_GUARDIANS,	"UnitNameEnemyGuardianName", ""},
	{ UNIT_NAME_ENEMY_TOTEMS,		"UnitNameEnemyTotemName", ""},
	{ true },

	{ L["Nameplates"], false },
	{ PLAYER,						"nameplateShowEnemies"},
	{ UNIT_NAME_ENEMY_PETS,			"nameplateShowEnemyPets", "nameplateShowEnemies"},
	{ UNIT_NAME_ENEMY_GUARDIANS,	"nameplateShowEnemyGuardians", "nameplateShowEnemies"},
	{ UNIT_NAME_ENEMY_TOTEMS,		"nameplateShowEnemyTotems", "nameplateShowEnemies"},
	{ true },

	{ L["Misc"] },
	{ UNIT_NAME_NONCOMBAT_CREATURE,	"UnitNameNonCombatCreatureName",	1},
	{ UNIT_NAME_OWN,				"UnitNameOwn",						2},
	{ UNIT_NAME_PLAYER_TITLE,		"UnitNamePlayerPVPTitle",			2},
	{ UNIT_NAME_GUILD,				"UnitNamePlayerGuild",				1},
	{ UNIT_NAME_GUILD_TITLE,		"UnitNameGuildTitle",				2},
	{ UNIT_NAME_NPC,				"UnitNameNPC",						2},
	{ SHOW_CLASS_COLOR_IN_V_KEY,	"ShowClassColorInNameplate",		1},
	{ UNIT_NAME_HIDE_MINUS,			"UnitNameForceHideMinus",			4},
};
if ns.build>70000000 then -- Legion
	ttColumns = 6;
	nameplateStatus = {
		{{txt=PLAYER,colors="ltblue"}, {txt=FRIENDLY,colors="ltgreen",rows=2}, {txt=ENEMY,colors="ltred",rows=3}, separator=1},
		{
			{txt=NAMES_LABEL, colors="ltyellow" },
			{txt=PLAYER,						cvar="UnitNameFriendlyPlayerName"	},
			{txt=UNIT_NAME_FRIENDLY_MINIONS,	cvar="UnitNameFriendlyMinionName",	colors={"white","gray","gray","dkgray"},	cvar_depend="UnitNameFriendlyPlayerName" },
			{txt=PLAYER,						cvar="UnitNameEnemyPlayerName",		colors={"white","gray"} },
			{txt=UNIT_NAME_ENEMY_MINIONS,		cvar="UnitNameEnemyMinionName",		colors={"white","gray","gray","dkgray"},		cvar_depend="UnitNameEnemyPlayerName" },
		},
		{
			{txt=L["Nameplates"], colors="ltyellow" },
			{txt=PLAYER,								cvar="nameplateShowFriends",		colors={"white","gray"} },
			{txt=UNIT_NAMEPLATES_SHOW_FRIENDLY_MINIONS,	cvar="nameplateShowFriendlyMinions",colors={"white","gray","gray","dkgray"},	cvar_depend="nameplateShowFriends" },
			{txt=PLAYER,								cvar="nameplateShowEnemies",		colors={"white","gray"} },
			{txt=UNIT_NAMEPLATES_SHOW_ENEMY_MINIONS,	cvar="nameplateShowEnemyMinions",	colors={"white","gray","gray","dkgray"},		cvar_depend="nameplateShowEnemies" },
			{txt=UNIT_NAMEPLATES_SHOW_ENEMY_MINUS,		cvar="nameplateShowEnemyMinus",		colors={"white","gray","gray","dkgray"},		cvar_depend="nameplateShowEnemies" },
		},

		{separator=4},

		{{txt=UNIT_NAME_NPC,colors="ltblue"}, separator=1},
		{
			{txt=ALL,					cvar="UnitNameNPC" },
			{txt=L["Interactive NPCs"],	cvar="UnitNameInteractiveNPC",			colors={"dkgray","black","white","gray"},	cvar_depend="UnitNameNPC", rows=2},
			{txt=L["Special NPCs"],		cvar="UnitNameFriendlySpecialNPCName",	colors={"dkgray","black","white","gray"},	cvar_depend="UnitNameNPC", rows=2},
			{txt=L["Hostle NPCs"],		cvar="UnitNameHostleNPC",				colors={"dkgray","black","white","gray"},	cvar_depend="UnitNameNPC"},
		},

		{separator=4},

		{{txt=L["More names"],	colors="ltblue" },separator=1},
		{
			{txt=UNIT_NAME_OWN,		cvar="UnitNameOwn" },
			{txt=UNIT_NAME_NONCOMBAT_CREATURE,	cvar="UnitNameNonCombatCreatureName", rows=3},
		},

		{separator=4},

		{{txt=L["More nameplate options"],	colors="ltblue" },separator=1},
		{
			{ txt=C("ltyellow",L["Nameplate size"]) },
			{ txt=PLAYER_DIFFICULTY1,
				rows=2,
				onChange=function() NamePlateDriverFrame:UpdateNamePlateOptions() end,
				cvar={NamePlateHorizontalScale="1",   NamePlateVerticalScale="1"}
			},
			{ txt=LARGE,
				rows=2,
				onChange=function() NamePlateDriverFrame:UpdateNamePlateOptions() end,
				cvar={NamePlateHorizontalScale="1.4", NamePlateVerticalScale="2.7"}
			},
			{ txt=L["Larger"],
				--rows=ttColumns,
				onChange=function() NamePlateDriverFrame:UpdateNamePlateOptions() end,
				cvar={NamePlateHorizontalScale="1.9", NamePlateVerticalScale="4.5"}
			},
		},
		{
			{txt=L["Nameplates out of combat"],  cvar="nameplateShowAll", rows=1},
			{txt=SHOW_NAMEPLATE_LOSE_AGGRO_FLASH,  cvar="ShowNamePlateLoseAggroFlash", rows=4},
		},

		{separator=4},

		{{txt=DISPLAY_PERSONAL_RESOURCE,colors="ltblue" },separator=1},
		{{txt=DISPLAY_PERSONAL_RESOURCE,cvar="nameplateShowSelf",rows=ttColumns}},
		{{txt=DISPLAY_PERSONAL_RESOURCE_ON_ENEMY,  cvar="nameplateResourceOnTarget", rows=ttColumns}},

		{separator=4},

		{{txt=L["Misc"],colors="ltblue"},separator=1},
		{{txt=L["Show quest unit circles"],cvar="ShowQuestUnitCircles",rows=ttColumns}}
	};
end


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\nameplates"}; --IconName::Nameplates--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show clickable nameplates options"],
	events = {
		"VARIABLES_LOADED",
		"CVAR_UPDATE"
	},
	updateinterval = nil, -- 10
	config_defaults = nil, -- {}
	config_allowed = nil,
	config = { { type="header", label=L[name], align="left", icon=I[name] } }
}


--------------------------
-- some local functions --
--------------------------


-- Function to get the Nameplate CVar status
local function getCVarSettings(cVarName)
	local shown
	local toggle = 1
	if GetCVar(cVarName) == "1" then
		shown = C("white",L["Shown"])
		toggle = 0
	elseif GetCVar(cVarName) == nil then
		RegisterCVar(cVarName, 0)
		shown = C("gray",L["Hidden"])
	else
		shown = C("gray",L["Hidden"])
	end
	return shown, toggle
end

local function ttSetCVar(self)
	ns.SetCVar(unpack(self.info));
	createTooltip(tt);
end

function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	tt:Clear()
	local l = tt:AddHeader()
	tt:SetCell(l, 1, C("dkyellow",L[name]), nil, nil, ttColumns);
	tt:AddSeparator(1,0,0,0,0) -- transparent

	local depend, dependName,color = 3,"","gray"
	local _, line, cell = nil,false,1

	if ns.build>70000000 then
		for _,row in ipairs(nameplateStatus)do
			local l=tt:AddLine();
			local cell,cellFunction = 1;
			for i,v in ipairs(row) do
				local color = "white";
				if v.txt and v.txt:find("\124") then
					v.txt=gsub(v.txt,"\124T.+\124t","");
				end
				v.txt = gsub(v.txt,"\n"," ");
				if v.cvar then
					local state,dstate;
					if type(v.cvar)=="string" then
						state = GetCVarBool(v.cvar);
						if v.cvar_depend then
							dstate = GetCVarBool(v.cvar_depend);
						end
						cellFunction=function()
							ns.SetCVar(v.cvar, state and 0 or 1, v.cvar);
							createTooltip(tt)
						end;
					elseif type(v.cvar)=="table" then
						state = true;
						if v.cvar[0] and v.cvar[1] then
							for cvar, value in pairs(v.cvar[1])do
								if type(cvar)=="string" and  GetCVar(cvar)~=value then
									state = false;
								end
							end
						else
							for cvar, value in pairs(v.cvar)do
								if type(cvar)=="string" and  GetCVar(cvar)~=value then
									state = false;
								end
							end
						end
						if v.cvar_depend then
							dstate = GetCVarBool(v.cvar_depend);
						end
						cellFunction=function()
							if v.cvar[0] and v.cvar[1] then
								for cvar, value in pairs(v.cvar[state and 0 or 1])do
									if type(cvar)=="string" and  GetCVar(cvar)~=value then
										ns.SetCVar(cvar, value, cvar);
									end
								end
							else
								for cvar, value in pairs(v.cvar)do
									if type(cvar)=="string" and  GetCVar(cvar)~=value then
										ns.SetCVar(cvar, value, cvar);
									end
								end
							end
							if type(v.onChange) then
								v.onChange();
							end
							createTooltip(tt)
						end;
					end
					if v.colors then
						color = v.colors[state and 1 or 2];
					else
						color = state and "white" or "ltgray"
					end
					if dstate==false then
						color = v.colors[state and 3 or 4];
					end

				elseif type(v.colors)=="string" then
					color = v.colors;
				end
				tt:SetCell(l,cell,C(color,strtrim(v.txt)), nil, nil, v.rows);
				if cellFunction then
					tt:SetCellScript(l, cell, "OnMouseUp", cellFunction);
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
	else
		for _, v in ipairs(nameplateStatus) do
			if (type(v[1])=="string") and (v[1]:find("\124")) then
				v[1]=gsub(v[1],"\124T.+\124t","");
			end
			if v[1]==true then
				tt:AddSeparator(1,0,0,0,0) -- transparent
				line = false
			elseif type(v[1])=="string" and v[2]==nil then
				line = tt:AddLine()
				tt:SetCell(line, 1, C("ltblue",v[1]), nil, nil, ttColumns)
				tt:AddSeparator()
				line = false
			elseif v[2] == false then
				line = tt:AddLine()
				tt:SetCell(line, 1, C("ltyellow",v[1]), nil, nil, 1)
				cell = 2
			elseif v[3]~=nil and type(v[3])=="number" then
				local shown, toggle = getCVarSettings(v[2])
				if cell>1 and cell>ttColumns then
					line = false
				end
				if line == false then
					cell = 1
					line = tt:AddLine()
				end
				tt.lines[line].cells[cell].info = {v[2], toggle, v[2]};
				tt:SetCell(line, cell, C(toggle==1 and "gray" or "white",v[1]), nil, nil, v[3])
				tt:SetCellScript(line, cell, "OnMouseUp", ttSetCVar);
				cell = cell + v[3];
			else
				local shown, toggle = getCVarSettings(v[2])
				if type(v[3])=="string" and dependName~=v[3] then
					_, depend = getCVarSettings(v[3])
					dependName = v[3]
				elseif v[3]==nil then
					depend, dependName = 3,""
				end
				if line == false then
					cell = 1
					line = tt:AddLine()
				end
				if v[3]==true then
					tt:SetCell(line, 1, C(toggle==1 and "gray" or "white",v[1]), nil, nil, 5)
					line = false
				else
					if depend == 0 then
						color = toggle==1 and "gray" or "white"
					elseif depend == 1 then
						color = toggle==1 and "dkgray" or "gray"
					elseif depend == 3 then
						color = toggle==1 and "gray" or "white"
					end
					tt.lines[line].cells[cell].info = {v[2], toggle, v[2]};
					tt:SetCell(line, cell, C(color,v[1]), nil, nil, 1)
					tt:SetCellScript(line, cell, "OnMouseUp", ttSetCVar);
					cell = cell + 1
				end
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddLine(" ")
		tt:SetCell(tt:AddLine(), 1, C("ltblue",L["Click"]).." || "..C("green",L["Names/Nameplates on/off"]), nil, nil, ttColumns)
	end
	ns.roundupTooltip(tt);
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg,msg2)
	local dataobj = ns.LDB:GetDataObjectByName(ldbName) 
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

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "LEFT","LEFT","LEFT","LEFT","LEFT"},{false},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

