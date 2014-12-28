
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Difficulty" -- L["Difficulty"]
local ldbName = name
local tt
local is = {}
local diff = {raid=0,dungeon=0}
local diffs = { -- by select(3,GetInstanceInfo())
	{name=DUNGEON_DIFFICULTY1,	short="5",   color="green"},	-- 1 = 5 men
	{name=DUNGEON_DIFFICULTY2,	short="5H",  color="blue"},		-- 2 = 5 men (Heroic)
	{name=RAID_DIFFICULTY1,		short="10",  color="blue"},		-- 3 = 10 men
	{name=RAID_DIFFICULTY2,		short="25",  color="blue"},		-- 4 = 25 men
	{name=RAID_DIFFICULTY3,		short="10H", color="violett"},	-- 5 = 10 men (Heroic)
	{name=RAID_DIFFICULTY4,		short="25H", color="violett"},	-- 6 = 25 men (Heroic)
	{name="Unknown",			short="n/a", color="red"},		-- 7 = unused?
	{name=CHALLENGE_MODE,		short="5CM", color="orange"}	-- 8 = 5 men (challenge mode)
}
local mode = 0
local modes = {
	{name=L["Solo"],  short="S", color="ltgray"},
	{name=L["Group"], short="G", color="quality2"},
	{name=L["Raid"],  short="R", color="quality4"},
	{name=L["Flex"],  short="F", color="quality3"},		-- ?
	{name=L["Mystic"],short="M", color="quality5"},	-- in future
}


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\LFG-Eye-Green", coords={0.5 , 0.625 , 0 , 0.25}}
I[name] = {iconfile="interface\\lfgframe\\ui-lfg-icon-heroic", coords={0,0.55,0,0.55}}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Display informations about the group mode"],
	--icon_suffix = "",
	events = {
		"GROUP_ROSTER_UPDATE",
		"PARTY_LEADER_CHANGED",
		"PARTY_LOOT_METHOD_CHANGED",
		"PLAYER_ENTERING_WORLD",
		"PLAYER_FLAGS_CHANGED",
		"PARTY_CONVERTED_TO_RAID",
		"PLAYER_DIFFICULTY_CHANGED",
		"CHAT_MSG_SYSTEM"
	},
	updateinterval = false, -- 10
	config_defaults = {},
	config_allowed = {},
	config = nil --[[{
		height = 53,
		elements = {
			{
				type = "dropdown",
				label = L["In broker"],
				desc = L["Choose..."],
				default = "1",
				values = {
					["1"] = "T H D",
					["2"] = "0/n 0/n 0/n",
					["3"] = "av. wait time"
				}
			}
		}
	}]]
}


--------------------------
-- some local functions --
--------------------------
local function getTooltip()
	local text = {}
	--tinsert(text,C(mode_color[mode],L_mode[mode]))
	--tinsert(text,L_diff[diff.dungeon])
	--tinsert(text,L_diff[diff.raid])
	
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,...)
	local update = false

	if event == "PLAYER_ENTERING_WORLD" then
		update = true
	elseif event == "GROUP_ROSTER_UPDATE" then
		update = true
	elseif event == "PARTY_LOOT_METHOD_CHANGED" then
		-- ?
	elseif event == "PLAYER_DIFFICULTY_CHANGED" then
		local nameA, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID, instanceGroupSize = GetInstanceInfo();
		local nameB, groupType, isHeroic, isChallengeMode, toggleDifficultyID = GetDifficultyInfo(difficultyID);
		update="INSTANCE"
	elseif event == "CHAT_MSG_SYSTEM" then
		update = true
	end

	if update==true then
		local obj = ns.LDB:GetDataObjectByName(ldbName)
		local short = {}

		mode = --[[ (IsInMystic() and 4) or ]] (IsInRaid() and 3) or (IsInGroup() and 2) or 1
		local m=modes[mode]
		tinsert(short,C(m.color,m.short))

		local d = GetDungeonDifficultyID()
		if d~=nil and diffs[d]~=nil and diffs[d].short~=nil then
			diff.dungeon = d
			tinsert(short,diffs[d].short)
		elseif d~=nil then
			tinsert(short,"["..d.."]")
		else
			tinsert(short,"?")
		end

		local d = GetRaidDifficultyID()
		if d~=nil and diffs[d]~=nil and diffs[d].short~=nil then
			diff.raid = d
			tinsert(short,diffs[d].short)
		elseif d~=nil then
			tinsert(short,"["..d.."]")
		else
			tinsert(short,"?")
		end

		obj.text = table.concat(short,", ")
	elseif update=="INSTANCE" then
		local obj = ns.LDB:GetDataObjectByName(ldbName)
		local short = {}
		
		mode = --[[ (IsInMystic() and 4) or ]] (IsInRaid() and 3) or (IsInGroup() and 2) or 1
		local m=modes[mode]
		tinsert(short,C(m.color,m.short))
		
		ns.print(nameA, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID, instanceGroupSize, nameB, groupType, isHeroic, isChallengeMode, toggleDifficultyID)

	end
end

--[[ ns.modules[name].onupdate = function(self,elapsed) end ]]

--[[ ns.modules[name].optionspanel = function(panel) end ]]

--[[ ns.modules[name].onmousewheel = function(self,direction) end ]]

--[[ ns.modules[name].ontooltip = function(tooltip) end ]]


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(name.."TT", 2, "LEFT", "RIGHT")
	getTooltip(self,tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if tt then 
		ns.hideTooltip(tt,name)
	end
end

ns.modules[name].onclick = function(self,button)
	if button=="LeftButton" then
		
	elseif button=="RightButton" then
		if IsShiftKeyDown() then
			StaticPopup_Show("CONFIRM_RESET_INSTANCES");
		else
			RandomRoll(1,100)
		end
	end
end

--[[ ns.modules[name].ondblclick = function(self,button) end ]]

--[[


difficultyID = GetDungeonDifficultyID()
difficultyID = GetRaidDifficultyID()

name, groupType, isHeroic, isChallengeMode, toggleDifficultyID = GetDifficultyInfo(id)


    GetDungeonDifficultyID() - Returns the player's current Dungeon Difficulty setting (1, 2, 8).
    SetDungeonDifficultyID(difficulty) - Sets the player's Dungeon Difficulty setting (for the 5-man instances).
    GetRaidDifficultyID() - Returns the player's current Raid Difficulty setting (1-14).


SetDungeonDifficultyID(difficultyIndex)



    difficultyIndex 
        Number

            1 → 5 Player
            2 → 5 Player (Heroic)
            8 → Challenge Mode

SetRaidDifficultyID(difficultyIndex)


UnitPopupButtons["DUNGEON_DIFFICULTY"] = { text = DUNGEON_DIFFICULTY, dist = 0,  nested = 1, defaultDifficultyID = 1 };
UnitPopupButtons["DUNGEON_DIFFICULTY1"] = { text = DUNGEON_DIFFICULTY1, dist = 0, checkable = 1, difficultyID = 1 };
UnitPopupButtons["DUNGEON_DIFFICULTY2"] = { text = DUNGEON_DIFFICULTY2, dist = 0, checkable = 1, difficultyID = 2 };
UnitPopupButtons["DUNGEON_DIFFICULTY3"] = { text = CHALLENGE_MODE, dist = 0, checkable = 1, difficultyID = 8 };

UnitPopupButtons["RAID_DIFFICULTY"] = { text = RAID_DIFFICULTY, dist = 0,  nested = 1, defaultDifficultyID = 3 };
UnitPopupButtons["RAID_DIFFICULTY1"] = { text = RAID_DIFFICULTY1, dist = 0, checkable = 1, difficultyID = 3 };
UnitPopupButtons["RAID_DIFFICULTY2"] = { text = RAID_DIFFICULTY2, dist = 0, checkable = 1, difficultyID = 4 };
UnitPopupButtons["RAID_DIFFICULTY3"] = { text = RAID_DIFFICULTY3, dist = 0, checkable = 1, difficultyID = 5 };
UnitPopupButtons["RAID_DIFFICULTY4"] = { text = RAID_DIFFICULTY4, dist = 0, checkable = 1, difficultyID = 6 };





SetLootMethod("method"{,"masterPlayer" or ,threshold}) 
		"group", "freeforall", "master", "needbeforegreed", "roundrobin".

SetLootThreshold(threshold)
		0 - Poor
		1 - Common
		2 - Uncommon
		3 - Rare
		4 - Epic
		5 - Legendary
		6 - Artifact

lootmethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod()

threshold = GetLootThreshold()

ConvertToParty() - Conv

ConvertToRaid() - Converts a pa

RandomRoll(low, high) - Does a random roll between the two values.

]]