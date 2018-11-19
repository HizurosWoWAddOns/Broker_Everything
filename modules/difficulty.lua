
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Difficulty" -- L["Difficulty"] L["ModDesc-Difficulty"]
L["ModDesc-"..name] = L["Display current group and instance modes"];

local ttName, ttColumns, tt, module,createTooltip = name.."TT", 4
local mode = 0;
local modes = {
	{name=SOLO,  short="S", color="ltgray"},	-- 1
	{name=GROUP, short="G", color="quality2"},		-- 2
	{name=RAID,  short="R", color="quality4"},		-- 3
}
local diff = {
	dungeons = {
		{id=1,long=PLAYER_DIFFICULTY1,short=L["DifficultyNormalShort"],color="quality2"},
		{id=2,long=PLAYER_DIFFICULTY2,short=L["DifficultyHeroicShort"],color="quality3"},
		{id=23,long=PLAYER_DIFFICULTY6,short=L["DifficultyMythicShort"],color="quality4"}
	},
	raids = {
		{id=14,long=PLAYER_DIFFICULTY1,short=L["DifficultyNormalShort"],color="quality2"}, -- 9 / 14
		{id=15,long=PLAYER_DIFFICULTY2,short=L["DifficultyHeroicShort"],color="quality3"},
		{id=16,long=PLAYER_DIFFICULTY6,short=L["DifficultyMythicShort"],color="quality4"},
	},
	classic = {
		{id=3,altId=5,long=RAID_DIFFICULTY1,short="10",color="quality2"}, -- 3 / 5
		{id=4,altId=6,long=RAID_DIFFICULTY2,short="25",color="quality3"}, -- 4 / 6
	}
};
local specials = {
	{rid=9,cid=5,legacy={long=RAID_DIFFICULTY_40PLAYER,short="40",color="quality4"}},
}


-- register icon names and default files --
-------------------------------------------
--I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\LFG-Eye-Green", coords={0.5 , 0.625 , 0 , 0.25}}
I[name] = {iconfile="interface\\lfgframe\\ui-lfg-icon-heroic", coords={0,0.55,0,0.55}}


-- some local functions --
--------------------------
local function mIf(a,b,c)
	if(type(b)=="table")then
		for i,v in ipairs(b)do
			if (a==v) then return true; end
		end
	elseif (a==b) then return true;
	elseif (c and a==c) then return true; end
	return false;
end

local function CanChange()
	local inGroupOrRaid = (IsInGroup() or IsInRaid());
	return not inGroupOrRaid or (inGroupOrRaid and  UnitIsGroupLeader("player"));
end

local function switchGroupType(self, disabled, button)
	securecall(IsInRaid() and "ConvertToParty" or "ConvertToRaid");
end

local function instanceReset(self)
	if CanChange() then
		securecall("ResetInstances");
	end
end

local function _SetDungeonDifficultyID(self,id)
	if CanChange() then
		securecall("SetDungeonDifficultyID",id);
	end
end

local function _SetRaidDifficulties(self,values)
	if CanChange() then
		securecall("SetRaidDifficulties",unpack(values));
	end
end

local function _SetOptOutOfLoot(self,optOut)
	securecall("SetOptOutOfLoot", not optOut );
end

local function _SetLootSpecialization(self,specId)
	securecall("SetLootSpecialization",specId);
end

function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end
	local mode = modes[(IsInRaid() and 3) or (IsInGroup() and 2) or 1];
	local dungeonID,raidID,legacyID = GetDungeonDifficultyID(), GetRaidDifficultyID(), GetLegacyRaidDifficultyID();
	local inInstance, instanceType = IsInInstance();
	local inGroupOrRaid = (IsInGroup() or IsInRaid());
	local enabled = CanChange();

	tt:Clear();

	local l = tt:AddHeader(C("dkyellow",L[name]));

	-- group mode and convert option
	local groupMode = mode.name;
	if enabled and inGroupOrRaid then
		groupMode = groupMode.." ["..CONVERT.."]";
		tt:SetCell(l,2, C("ltgray",CONVERT), nil, "RIGHT",0);
		tt:SetCellScript(l,2,"OnMouseUp",switchGroupType);
	else
		tt:SetCell(l,2,C(mode.color,groupMode),nil,"RIGHT",0);
	end

	--l=tt:AddLine(C("ltblue",L["Group leader"]),"?");
	-- group tanks
	-- group assists?

	tt:AddSeparator(4,0,0,0,0);
	l = tt:AddLine(C("ltblue",UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_INSTANCE));
	tt:SetCell(l,3,C(enabled and "ltgray" or "dkgray",RESET_INSTANCES), nil, "RIGHT", 2);
	if enabled then
		tt:SetCellScript(l,3,"OnMouseUp",instanceReset);
	end

	tt:AddSeparator();

	local custom_instance,custom_raid,custom_legacy=nil,nil,nil;
	for i,v in ipairs(specials)do
		if(v.rid==raidID and v.cid==legacyID and v.legacy~=nil)then
			custom_legacy=v.legacy;
		end
	end

	--- dungeons
	l = tt:AddLine(C("ltyellow",LFG_TYPE_DUNGEON..":"));
	for i,v in ipairs(diff.dungeons)do
		local color = enabled and "ltgray" or "dkgray";
		if(mIf(dungeonID,v.id)) then
			color = enabled and v.color or "white";
		end
		tt:SetCell(l,i+1,C(color,v.long));
		if (enabled and not mIf(dungeonID,v.id)) then
			tt:SetCellScript(l,i+1,"OnMouseUp",_SetDungeonDifficultyID,v.id);
		end
	end

	--- raids
	l = tt:AddLine(C("ltyellow",RAID..":"));
	for i,v in ipairs(diff.raids) do
		local color = enabled and "ltgray" or "dkgray";
		if(mIf(raidID,v.id))then
			color = enabled and v.color or "white";
		end
		tt:SetCell(l,i+1,C(color,v.long));
		if (enabled and not mIf(raidID,v.id)) then
			tt:SetCellScript(l,i+1,"OnMouseUp",_SetRaidDifficulties,{true,v.id});
		end
	end

	--- legacy raid size
	l = tt:AddLine(C("ltyellow",UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_LEGACY_RAID..":"));
	local I=0;
	for i,v in ipairs(diff.classic) do
		local color = enabled and "ltgray" or "dkgray";
		local _mIf = mIf(legacyID,v.id,v.altId);
		if(custom_legacy and _mIf)then
			color = enabled and "dkgreen" or "ltgray";
		elseif(_mIf)then
			color = enabled and "green" or "white";
		end
		tt:SetCell(l,i+1,C(color,v.long));
		if ((enabled and not _mIf) or custom_legacy) then
			tt:SetCellScript(l,i+1,"OnMouseUp",_SetRaidDifficulties,{false,v.id});
		end
		I=i+2;
	end
	if(custom_legacy)then
		tt:SetCell(l,I,C("green",custom_legacy.long));
	end

	--- loot types & loot specialization
	tt:AddSeparator(4,0,0,0,0);
	l = tt:AddLine(C("ltblue",UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_LOOT));
	local optOut = (GetOptOutOfLoot());
	tt:SetCell(l,3,C("ltgray",OPT_OUT_LOOT_TITLE:format(C("white", optOut and YES or NO ))),nil,"RIGHT",2);
	tt:SetCellScript(l,3,"OnMouseUp",_SetOptOutOfLoot,optOut);

	tt:AddSeparator();
	l=tt:AddLine(C("ltyellow",SPECIALIZATION..":"));
	local lootSpec = GetLootSpecialization();

	local cell=2;
	for i=1, GetNumSpecializations() do -- add loot specs
		if(cell>ttColumns) then cell=2; l=tt:AddLine(" "); end

		local specId,specName,_,specIcon,_,specRole = GetSpecializationInfo(i);
		tt:SetCell(l, cell, C(lootSpec==specId and "green" or "ltgray",specName));

		if(i~=lootSpec)then
			tt:SetCellScript(l, cell, "OnMouseUp",_SetLootSpecialization,specId);
		end

		cell=cell+1;
	end

	-- add auto loot spec
	if (cell+1 > ttColumns) then cell=2; l=tt:AddLine(" "); end
	local specName,curSpec,_ = UNKNOWN,GetSpecialization();
	if curSpec then _,specName = GetSpecializationInfo(curSpec); end
	tt:SetCell(l, cell, C(lootSpec==0 and "green" or "ltgray", LOOT_SPECIALIZATION_DEFAULT:format(specName)), nil, nil, 2);
	if lootSpec~=0 then
		tt:SetCellScript(l,2,"OnMouseUp",_SetLootSpecialization,0);
	end


	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	--icon_suffix = "",
	events = {
		"GROUP_ROSTER_UPDATE",
		"PARTY_LEADER_CHANGED",
		"PARTY_LOOT_METHOD_CHANGED",
		"PLAYER_ENTERING_WORLD",
		"PLAYER_FLAGS_CHANGED",
		"PLAYER_DIFFICULTY_CHANGED",
		"PLAYER_SPECIALIZATION_CHANGED",
		"PLAYER_LOOT_SPEC_UPDATED",
		"CHAT_MSG_SYSTEM"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		enabled = false
	},
	clickOptionsRename = nil,
	clickOptions = {
		["rollneed"] = {ROLL..": "..NEED, "module", "roll"},
		["rollgreed"] = {ROLL..": "..GREED,"module","roll"},
		["resetinstances"] = {RESET_INSTANCES,"module","instanceReset"},
	}
}

ns.ClickOpts.addDefaults(module,{
	rollneed = "_RIGHT",
	rollgreed = "_LEFT",
	instanceReset = "__NONE",
	resetinstances = "__NONE",
});

function module.roll(self,button,...)
	if button=="LeftButton" then
		RandomRoll(1,50); -- greed
	elseif button=="RightButton" then
		RandomRoll(1,100); -- need
	end
end

module.instanceReset = instanceReset;

-- function module.options() return {}; end
-- function module.init() end

function module.onevent(self,event,...)
	local update = false;

	if (event=="PLAYER_ENTERING_WORLD") then
		update = true
	elseif (event=="GROUP_ROSTER_UPDATE") then
		update = true
	elseif (event=="PARTY_LOOT_METHOD_CHANGED") then
		update = true;
	elseif (event=="PLAYER_SPECIALIZATION_CHANGED") then
		update = true
	elseif (event=="PLAYER_LOOT_SPEC_UPDATED") then
		update = true;
	elseif (event=="PLAYER_DIFFICULTY_CHANGED") then
		local nameA, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID, instanceGroupSize = GetInstanceInfo();
		local nameB, groupType, isHeroic, isChallengeMode, displayHeroic, displayMystic, toggleDifficultyID = GetDifficultyInfo(difficultyID);
		update="INSTANCE"
	elseif (event=="CHAT_MSG_SYSTEM") then
		update = true
	end

	if update==true then
		local obj = ns.LDB:GetDataObjectByName(ns.modules[name].ldbName)
		local short = {}
		local mode = modes[(IsInRaid() and 3) or (IsInGroup() and 2) or 1];
		local ids = { {"dungeons",GetDungeonDifficultyID()}, {"raids",GetRaidDifficultyID()}, {"classic",GetLegacyRaidDifficultyID()} };
		local dungeonID,raidID,legacyID = GetDungeonDifficultyID(), GetRaidDifficultyID(), GetLegacyRaidDifficultyID();
		local inInstance, instanceType = IsInInstance();

		tinsert(short,C(mode.color,mode.short));
		for _,id in pairs(ids)do
			for _,v in ipairs(diff[id[1]])do
				if(mIf(id[2],v.id))then
					tinsert(short,C(v.color,v.short));
				end
			end
		end

		if(#short>0)then
			obj.text = table.concat(short,", ")
		else
			obj.text = L[name];
		end
	elseif update=="INSTANCE" then
		local obj = ns.LDB:GetDataObjectByName(ns.modules[name].ldbName)
		local short = {}
		local mode = (IsInRaid() and 3) or (IsInGroup() and 2) or 1
		local m=modes[mode]
		tinsert(short,C(m.color,m.short))
	end

	if (update) and (tt) then
		createTooltip(tt)
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "LEFT", "LEFT", "LEFT", "LEFT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end

ns.modules[name] = module;
