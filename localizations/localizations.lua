
local addon, ns = ...
Broker_EverythingDB = {}
-- ----------------------------------------------------------------- --
-- Localization metatable function                                   --
-- Instructions for Non-Ace3 method taken from Phanx at WowInterface --
-- http://www.wowinterface.com/portal.php?&id=224&pageid=250         --
-- ================================================================= --
-- Extended version by Hizuro to use some localization strings       --
-- from Blizzard                                                     --
-- ----------------------------------------------------------------- --

--[[
ns.L = setmetatable({ }, { __index = function(t, k)
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })
]]

do
	local _G = _G
	local exclude = {["ITEM_UPGRADE"]=true, ["REAL_ID"]=true, ["HOME"]=true, ["GOLD"] = true}

	local function strReplace(pattern,replace,value)
		return table.concat({strsplit(pattern,value)},replace)
	end

	local function checkGlobalStrings(k)
		if not Broker_EverythingDB.useBlizzGStings then return end
		-- first try to get the localization from blizzard
		-- all localized strings in GlobalStrings.lua are
		-- looks like faction standing ^

		local test1 = strReplace(" ","_",k):upper()
		if exclude[test1]==true then return false end

		if type(_G[test1])=="string" then return _G[test1] end

		local test2 = strReplace(":","_COLON",test1)
		if type(_G[test2])=="string" then return _G[test2] end

		local test = strReplace(":","",test1)
		if type(_G[test])=="string" then return _G[test] end

		local try = {
			"FACTION_"..test, test.."_LABEL", "MONTH_"..test, "CHAT_MSG_"..test,
			"FACIAL_HAIR_"..test, "COMBAT_TEXT_"..test, "ITEM_"..test,
			"ITEM_MOD_"..test.."_SHORT", test.."_AMOUNT", "WEEKDAY_"..test,
			"STRING_ENVIRONMENTAL_DAMAGE_"..test
		}

		for i,v in pairs(try) do if type(_G[v])=="string" then return _G[v] end end

		return false
	end

	ns.L = setmetatable({}, {
		__index = function(t, k)
			--local blizz = checkGlobalStrings(k)
			--if blizz then return blizz end
			local v=tostring(k);
			if (not v) or (strlen(v)==0) then
				v = "?";
			else
				rawset(t, k, v);
			end
			return v;
		end
	})

	if (FACTION_STANDING_LABEL1~="Hated") then
		ns.L["Hated"]         = FACTION_STANDING_LABEL1
		ns.L["Hostile"]       = FACTION_STANDING_LABEL2
		ns.L["Unfriendly"]    = FACTION_STANDING_LABEL3
		ns.L["Neutral"]       = FACTION_STANDING_LABEL4
		ns.L["Friendly"]      = FACTION_STANDING_LABEL5
		ns.L["Honoured"]      = FACTION_STANDING_LABEL6
		ns.L["Revered"]       = FACTION_STANDING_LABEL7
		ns.L["Exalted"]       = FACTION_STANDING_LABEL8
		ns.L["Inn"]           = HOME_INN
		ns.L["Officer notes"] = gsub(OFFICER_NOTE_COLON,":","");
	end

end
