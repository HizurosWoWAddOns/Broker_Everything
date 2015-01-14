
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
local ldbName = name
local tt = nil
local ttName = name.."TT"
local GetCVar,RegisterCVar = GetCVar,RegisterCVar
local ttColumns = 5



local nameplateStatus = {
	{ FRIENDLY },
	{ L["Names"], false },
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
	{ L["Names"], false },
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
	{ UNIT_NAME_NONCOMBAT_CREATURE,	"UnitNameNonCombatCreatureName", 1},
	{ UNIT_NAME_OWN,				"UnitNameOwn", 2},
	{ UNIT_NAME_PLAYER_TITLE,		"UnitNamePlayerPVPTitle", 2},
	{ UNIT_NAME_GUILD,				"UnitNamePlayerGuild", 1},
	{ UNIT_NAME_GUILD_TITLE,		"UnitNameGuildTitle", 2},
	{ UNIT_NAME_NPC,				"UnitNameNPC", 2},
	{ SHOW_CLASS_COLOR_IN_V_KEY,	"ShowClassColorInNameplate",1 },
	{ UNIT_NAME_HIDE_MINUS,			"UnitNameForceHideMinus", 4 },
}


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\nameplates"}; --IconName::Nameplates--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to allow you to toggle the various nameplates. Eg, friendly or hostile."],
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



------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	if not obj then return end
	obj = obj.obj or ns.LDB:GetDataObjectByName(ldbName) 
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
		dataobj.text = L["None"]
	end
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...

	tt:Clear()
	local line, column = tt:AddHeader(C("dkyellow",L[name]))
	tt:AddSeparator(1,0,0,0,0) -- transparent

	local depend, dependName,color = 3,"","gray"
	local _, line, cell = nil,false,1
	for _, v in ipairs(nameplateStatus) do

		if (type(v[1])=="string") and (v[1]:find("\124")) then
			v[1]=gsub(v[1],"\124T.+\124t","");
		end
		if v[1]==true then
			tt:AddSeparator(1,0,0,0,0) -- transparent
			line = false
		elseif type(v[1])=="string" and v[2]==nil then
			line, column = tt:AddLine()
			tt:SetCell(line, 1, C("ltblue",v[1]), nil, nil, ttColumns)
			tt:AddSeparator()
			line = false
		elseif v[2] == false then
			line, column = tt:AddLine()
			tt:SetCell(line, 1, C("ltyellow",v[1]), nil, nil, 1)
			cell = 2
		elseif v[3]~=nil and type(v[3])=="number" then
			local shown, toggle = getCVarSettings(v[2])
			if line == false then
				cell = 1
				line, column = tt:AddLine()
			end
			tt:SetCell(line, cell, C(toggle==1 and "gray" or "white",v[1]), nil, nil, v[3])
			tt:SetCellScript(line, cell, "OnEnter", function(self) tt:SetLineColor(line, 1,192/255, 90/255, 0.3) end )
			tt:SetCellScript(line, cell, "OnLeave", function(self) tt:SetLineColor(line, 0,0,0,0) end)
			tt:SetCellScript(line, cell, "OnMouseUp", function(self)
				ns.SetCVar(v[2], toggle, v[2])
				tt:Clear()
				ns.modules[name].ontooltip(tt)
			end)
			cell = cell + v[3]
			if cell > ttColumns then
				line = false
				cell = 1
			end
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
				line, column = tt:AddLine()
			end
			if v[3]==true then
				tt:SetCell(line, 1, C(toggle==1 and "gray" or "white",v[1]), nil, nil, 5)
				tt:SetCellScript(line, 1, "OnEnter", function(self) tt:SetLineColor(line, 1,192/255, 90/255, 0.3) end )
				tt:SetCellScript(line, 1, "OnLeave", function(self) tt:SetLineColor(line, 0,0,0,0) end)
				line = false
			else
				if depend == 0 then
					color = toggle==1 and "gray" or "white"
				elseif depend == 1 then
					color = toggle==1 and "dkgray" or "gray"
				elseif depend == 3 then
					color = toggle==1 and "gray" or "white"
				end
				tt:SetCell(line, cell, C(color,v[1]), nil, nil, 1)
				tt:SetCellScript(line, cell, "OnEnter", function(self) tt:SetLineColor(line, 1,192/255, 90/255, 0.3) end )
				tt:SetCellScript(line, cell, "OnLeave", function(self) tt:SetLineColor(line, 0,0,0,0) end)
				tt:SetCellScript(line, cell, "OnMouseUp", function(self)
					ns.SetCVar(v[2], toggle, v[2])
					tt:Clear()
					ns.modules[name].ontooltip(tt)
				end)
				cell = cell + 1
			end
		end
	end

	if Broker_EverythingDB.showHints then
		tt:AddLine(" ")

		line, column = tt:AddLine()
		tt:SetCell(line, 1, C("ltblue",L["Click"]).." || "..C("green",L["Names/Nameplates on/off"]), nil, nil, ttColumns)
	end
	line, column = nil, nil
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "LEFT","LEFT","LEFT","LEFT","LEFT")
	ns.createTooltip(self,tt)
	ns.modules[name].ontooltip(tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

