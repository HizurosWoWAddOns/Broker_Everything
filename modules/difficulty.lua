
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<5 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Difficulty" -- L["Difficulty"] L["ModDesc-Difficulty"]
L["ModDesc-"..name] = L["Display current group and instance modes"];

local ttName, ttColumns, tt, module,createTooltip = name.."TT", 4

local groupModes = {
	{name=SOLO,  short="S", color="ltgray"}, -- [1]
	{name=GROUP, short="G", color="quality2"}, -- [2]
	{name=RAID,  short="R", color="quality4"}, -- [3]
}

local diff = {
	dungeons = {
		{id=1,long=PLAYER_DIFFICULTY1,short=L["DifficultyNormalShort"],color="quality2"},
		{id=2,long=PLAYER_DIFFICULTY2,short=L["DifficultyHeroicShort"],color="quality3"},
		--{id=23,long=PLAYER_DIFFICULTY6,short=L["DifficultyMythicShort"],color="quality4"},
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

if ns.client_version==5 then
	tinsert(diff.dungeons,{id=8,long=PLAYER_DIFFICULTY5,short=L["DifficultyChallengeShort"],color="quality4"});
else
	tinsert(diff.dungeons,{id=23,long=PLAYER_DIFFICULTY6,short=L["DifficultyMythicShort"],color="quality4"});
end

local diffIdOrder = { -- order for display in tooltip
	dungeons = {1,2,8,23},
	raids = {14,15,16,9},
	classic = {3,4,5,6}
	-- scenario = {},
	-- delves = {},
};

local instanceTypeInfo = {
	raid =     {isRaid=true,         instanceTypeShort=L["InstaceTypeNameShortR"],   instanceType=RAID, instanceTypeColor="quality4"},
	party =    {isDungeon=true,      instanceTypeShort=L["InstaceTypeNameShortD"],   instanceType=LFG_TYPE_DUNGEON, instanceTypeColor="quality3"},
	szenario = {isSzenario=true,     instanceTypeShort=L["InstaceTypeNameShortSZ"],  instanceType=GUILD_CHALLENGE_TYPE4, instanceTypeColor="quality2"},
	arena =    {isArena=true,        instanceTypeShort=L["InstaceTypeNameShortA"],   instanceType=ARENA, instanceTypeColor="violet"},
	pvp =      {isBattleground=true, instanceTypeShort=L["InstaceTypeNameShortBG"],  instanceType=BATTLEGROUND, instanceTypeColor="violet"},
	world =    {isOpenWorld=true,    instanceTypeShort=L["InstaceTypeNameShortOW"],  instanceType=L["Open World"], instanceTypeColor="quality6"}
}
if DELVE_LABEL then
	-- delves are instanceType szenario with difficultyID = 208...
	instanceTypeInfo.delve =    {isDelve=true,        instanceTypeShort=L["InstaceTypeNameShortDlv"], instanceType=DELVE_LABEL, instanceTypeColor="quality3"}
end
if HOUSING_DASHBOARD_NEIGHBORHOOD_LABEL then
	instanceTypeInfo.neighborhood = {instanceTypeShort=L["InstaceTypeNameShortNH"],  instanceType=HOUSING_DASHBOARD_NEIGHBORHOOD_LABEL:gsub(":",""), instanceTypeColor="quality2"}
end

local difficultyIDInfo = {
	-- dungeons
	[1] ={diffName=PLAYER_DIFFICULTY1,diffNameShort=L["DifficultyNormalShort"],diffColor="quality2",diffType=LFG_TYPE_DUNGEON,},
	[2] ={diffName=PLAYER_DIFFICULTY2,diffNameShort=L["DifficultyHeroicShort"],diffColor="quality3",diffType=LFG_TYPE_DUNGEON},
	[8] ={diffName=PLAYER_DIFFICULTY5,diffNameShort=L["DifficultyChallengeShort"],diffColor="quality4",diffType=LFG_TYPE_DUNGEON},
	[23]={diffName=PLAYER_DIFFICULTY6,diffNameShort=L["DifficultyMythicShort"],diffColor="quality4",diffType=LFG_TYPE_DUNGEON},
	-- raids
	[14]={diffName=PLAYER_DIFFICULTY1,diffNameShort=L["DifficultyNormalShort"],diffColor="quality2",diffType=LFG_TYPE_RAID}, --isRaid=true
	[15]={diffName=PLAYER_DIFFICULTY2,diffNameShort=L["DifficultyHeroicShort"],diffColor="quality3",diffType=LFG_TYPE_RAID}, -- isRaid=true
	[16]={diffName=PLAYER_DIFFICULTY6,diffNameShort=L["DifficultyMythicShort"],diffColor="quality4",diffType=LFG_TYPE_RAID}, -- isRaid=true
	-- 9 = 14
	-- legacy/classic
	[3] ={diffName=RAID_DIFFICULTY1,diffNameShort="10",diffColor="quality2",diffType=LFG_TYPE_RAID}, -- isRaid=true
	[4] ={diffName=RAID_DIFFICULTY2,diffNameShort="25",diffColor="quality3",diffType=LFG_TYPE_RAID}, -- isRaid=true
	-- 5 = 3
	-- 6 = 4
	-- scenario {GUILD_CHALLENGE_TYPE4}
	-- delves {}
	[-1] ={diffName="",diffNameShort=STRING_SCHOOL_CHAOS,diffColor="quality5",diffType=""}, -- unknown
}

difficultyIDInfo[5] = difficultyIDInfo[3]
difficultyIDInfo[6] = difficultyIDInfo[4]
difficultyIDInfo[9] = difficultyIDInfo[14]

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

local secureExecute
do
	local function pCallFunc(todo)
		local func = _G[todo.func];
		local chkArgs = (type(todo.checkArgs)=="table" and todo.checkArgs) or (todo.checkArgs~=nil and {todo.checkArgs}) or {};
		if (type(todo.preCheck)=="function" and not todo.preCheck(unpack(chkArgs))) or (type(todo.preCheck)=="string" and _G[todo.preCheck] and not _G[todo.preCheck](unpack(chkArgs))) then
			return;
		end
		return func(unpack( (type(todo.args)=="table" and todo.args) or (todo.args and {todo.args}) or {} ));
	end
	function secureExecute(...)
		local todo;
		for _,arg in ipairs({...}) do
			if arg.func then
				todo=arg;
				break;
			end
		end
		local result = {pcall(pCallFunc,todo)};
		ns:debug("<secureExecute>",todo.func,unpack(result))
		if tremove(result,1) then
			return unpack(result)
		end
		return false;
	end
end

local function GetInstanceInfoExtended()
	if not IsInInstance() then
		local custom = CopyTable(difficultyIDInfo[-1])
		Mixin(custom,CopyTable(instanceTypeInfo.world))
		return {name=L["Open World"], difficultyID=0, difficultyName=L["Legendary"], maxPlayers=UNKNOWN, isDynamic=true, instanceMapID=0, instanceGroupSize=40, lfgDungeonID=-1, groupType=-1, isHeroic=false, isChallengeMode=false, displayHeroic=false, displayMystic=false, isLFR=true, minPlayers=1, custom=custom}
	end

	local info,_ = {customInfo={}}
	info.name, info.instanceType, info.difficultyID, info.difficultyName, info.maxPlayers, info.dynamicDifficulty, info.isDynamic, info.instanceMapID, info.instanceGroupSize, info.LfgDungeonID = GetInstanceInfo();
	_, info.groupType, info.isHeroic, info.isChallengeMode, info.displayHeroic, info.displayMystic, info.toggleDifficultyID, info.isLFR, info.minPlayers, _ = GetDifficultyInfo(info.difficultyID);

	-- custom infos
	local custom = CopyTable((info.difficultyID==208 and instanceTypeInfo.delve) or instanceTypeInfo[info.instanceType] or instanceTypeInfo.world)
	Mixin(custom,difficultyIDInfo[info.difficultyID] or difficultyIDInfo[-1])
	info.custom = custom

	return info
end

local function updateBroker()
	-- broker text: <GroupMode[ShortName]> / {if instance <instanceType[ShortName]>[, <instanceDifficulty>, <instanceMaxPlayers>] else (<own selected modes>) }
	-- GroupModeShortNames: S, G, R (Solo, Group, Raid)
	--
	-- InstanceTypeSortNames: D, R, S, Dlv, OW (Dungeon, Raid, Szenario, Dlv, OpenWorld)
	-- TODO: number of group members? https://warcraft.wiki.gg/wiki/API:GetNumGroupMembers

	-- TODO: add use of InGuildParty() or IsInGuildGroup() ?

	local brokerText = {}
	local groupMode = (IsInRaid() and 3) or (IsInGroup() and 2) or 1

	-- display current group mode
	local brokerTextGroupMode = C(groupModes[groupMode].color,groupModes[groupMode].short);

	--difficultyIDInfo
	-- old?
	-- if IsInInstance() then
	-- 	local short,roleCountPattern = {},"%s/%s/%s"
	-- 	local roleCount = "";
	-- 	if groupMode>1 then
	-- 		local counts = GetGroupMemberCounts();
	-- 		if counts and counts.TANK and counts.HEALER and counts.DAMAGER then
	-- 			roleCount = roleCountPattern:format(counts.TANK,counts.HEALER,counts.DAMAGER);
	-- 		end
	-- 	end
	-- 	tinsert(short,C(groupModes[groupMode].color,groupModes[groupMode].short)..roleCount);
	-- end

	--local ids = { {"dungeons",GetDungeonDifficultyID()}, {"raids",GetRaidDifficultyID()}, {"classic",GetLegacyRaidDifficultyID()} };

	-- tinsert(brokerTextShort,C(groupModes[groupMode].color,groupModes[groupMode].short));
	-- for _,id in pairs(ids)do
	-- 	for _,v in ipairs(diff[id[1]])do
	-- 		if(mIf(id[2],v.id))then
	-- 			tinsert(brokerText,C(v.color,v.short));
	-- 		end
	-- 	end
	-- end

	local instanceInfo = GetInstanceInfoExtended();
	local brokerTextInstance = C("white",L[""])
	local currentModeSettings
	if instanceInfo then
		brokerTextInstance = {}
		-- display current instance mode
		tinsert(brokerTextInstance,C(instanceInfo.custom.instanceTypeColor,instanceInfo.custom.instanceTypeShort))
		tinsert(brokerTextInstance,C(instanceInfo.custom.diffColor,instanceInfo.custom.diffNameShort))

		if instanceInfo.custom.isRaid then
			-- TODO: add current number of players?
			tinsert(brokerText,instanceInfo.maxPlayers)
		elseif instanceInfo.custom.isDelve then
			local num = GetNumGroupMembers()-1; -- companion (brann)
			if num==1 then
				groupMode = 1;
			else
				local counts = GetGroupMemberCounts();
				if counts and counts.TANK and counts.HEALER and counts.DAMAGER then
					tinsert(brokerTextInstance,C(groupModes[groupMode].color,groupModes[groupMode].short)..("%s/%s/%s"):format(counts.TANK,counts.HEALER,counts.DAMAGER));
				end
			end
		end
		brokerTextInstance = table.concat(brokerTextInstance,",")
	end

	do
		currentModeSettings = {}
		-- list current difficulty modes
		for i,id in ipairs({ GetDungeonDifficultyID(), GetRaidDifficultyID(), GetLegacyRaidDifficultyID() }) do
			local info = difficultyIDInfo[id];
			if info then
				tinsert(currentModeSettings,C(info.diffColor,info.diffNameShort));
			else
				ns:debug("<difficultyIDInfo>",i,id, "missing?")
			end
		end
		if #currentModeSettings>0 then
			currentModeSettings = "("..table.concat(currentModeSettings,",")..")"
		end
	end

	(ns.LDB:GetDataObjectByName(ns.modules[name].ldbName) or {}).text =
		brokerTextGroupMode
		..
		(brokerTextInstance and ", "..brokerTextInstance or "")
		..
		(currentModeSettings and " "..currentModeSettings or "")
		;
end

function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	local groupMode = groupModes[(IsInRaid() and 3) or (IsInGroup() and 2) or 1];
	local dungeonID,raidID,legacyID = GetDungeonDifficultyID(), GetRaidDifficultyID(), GetLegacyRaidDifficultyID();
	local inGroupOrRaid = (IsInGroup() or IsInRaid());
	local enabled = CanChange();

	tt:Clear();

	local l = tt:AddHeader(C("dkyellow",L[name]));
	local info = GetInstanceInfoExtended();

	-- group mode and convert option
	local groupModeName = groupMode.name;
	if enabled and inGroupOrRaid then
		groupModeName = groupModeName.." ["..CONVERT.."]";
		tt:SetCell(l,2, C("ltgray",CONVERT), nil, "RIGHT",0);
		tt:SetCellScript(l,2,"OnMouseUp",switchGroupType);
	else
		tt:SetCell(l,2,C(groupMode.color,groupModeName)..", "..C(info.custom.instanceTypeColor,info.custom.instanceType)..", "..C(info.custom.diffColor,info.custom.diffNameShort),nil,"RIGHT",0);
	end

	--if IsInInstance() then
		if info and info.groupType then
			tt:AddSeparator(4,0,0,0,0)
			tt:AddLine(C("ltblue",L["CurrentType"]),C("ltblue",L["CurrentMode"]),C("ltblue",L["CurrentMaxPlayers"]))
			tt:AddSeparator();
			local line = tt:AddLine(
				C("ltyellow",info.custom.instanceType),
				((info.displayHeroic and PLAYER_DIFFICULTY2) or (info.displayMystic and PLAYER_DIFFICULTY6) or PLAYER_DIFFICULTY1),
				info.maxPlayers
			)

			if info.custom.isDelve then
				--C_DelvesUI.GetActiveDelveTier()
				--C_DelvesUI.GetCompanionInfoForActivePlayer()
			--elseif info.custom.isArena then
			--elseif info.custom.isBattleground then
			--elseif info.custom.isOpenWorld then
			else
			end
		end
	--end

	--l=tt:AddLine(C("ltblue",L["Group leader"]),"?");
	-- group tanks
	-- group assists?

	tt:AddSeparator(4,0,0,0,0);
	l = tt:AddLine(C("ltblue",UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_INSTANCE));
	tt:SetCell(l,3,C(enabled and "ltgray" or "dkgray",RESET_INSTANCES), nil, "RIGHT", 2);
	if enabled then
		tt:SetCellScript(l,3,"OnMouseUp",secureExecute,{func="ResetInstances",preCheck=CanChange});
	end

	tt:AddSeparator();

	local custom_legacy=nil;
	for i,v in ipairs(specials)do
		if(v.rid==raidID and v.cid==legacyID and v.legacy~=nil)then
			custom_legacy=v.legacy;
		end
	end

	--- dungeons
	l = tt:AddLine(C("ltyellow",LFG_TYPE_DUNGEON..HEADER_COLON));
	for i,v in ipairs(diff.dungeons)do
		if not v.hidden then
			local color = enabled and "ltgray" or "dkgray";
			if(mIf(dungeonID,v.id)) then
				color = enabled and v.color or "white";
			end
			tt:SetCell(l,i+1,C(color,v.long));
			if (enabled and not mIf(dungeonID,v.id)) then
				tt:SetCellScript(l,i+1,"OnMouseUp",secureExecute,{func="SetDungeonDifficultyID",preCheck=CanChange,args={v.id}});
			end
		end
	end

	--- raids
	l = tt:AddLine(C("ltyellow",RAID..HEADER_COLON));
	for i,v in ipairs(diff.raids) do
		local color = enabled and "ltgray" or "dkgray";
		if(mIf(raidID,v.id))then
			color = enabled and v.color or "white";
		end
		tt:SetCell(l,i+1,C(color,v.long));
		if (enabled and not mIf(raidID,v.id)) then
			tt:SetCellScript(l,i+1,"OnMouseUp",secureExecute,{func="SetRaidDifficulties",preCheck=CanChange,args={true,v.id}});
		end
	end

	--- legacy raid size
	l = tt:AddLine(C("ltyellow",UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_LEGACY_RAID..HEADER_COLON));
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
			tt:SetCellScript(l,i+1,"OnMouseUp",secureExecute,{func="SetRaidDifficulties",preCheck=CanChange,args={false,v.id}});
		end
		I=i+2;
	end
	if(custom_legacy)then
		tt:SetCell(l,I,C("green",custom_legacy.long));
	end

	--- loot types & loot specialization
	tt:AddSeparator(4,0,0,0,0);
	l = tt:AddLine(C("ltblue",UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_LOOT));
	local optOut = GetOptOutOfLoot();
	tt:SetCell(l,3,C("ltgray",OPT_OUT_LOOT_TITLE:format(C("white", optOut and YES or NO ))),nil,"RIGHT",2);
	tt:SetCellScript(l,3,"OnMouseUp",secureExecute,{func="SetOptOutOfLoot",args={not optOut}});

	tt:AddSeparator();
	l=tt:AddLine(C("ltyellow",SPECIALIZATION..HEADER_COLON));
	local lootSpec = GetLootSpecialization();

	local cell=2;
	for i=1, GetNumSpecializations() do -- add loot specs
		if(cell>ttColumns) then cell=2; l=tt:AddLine(" "); end

		local specId,specName,_,specIcon,_,specRole = C_SpecializationInfo.GetSpecializationInfo(i);
		-- if not specName then
		-- 	_,specName = C_SpecializationInfo.GetSpecializationInfoForSpecID(curSpec)
		-- end

		tt:SetCell(l, cell, C(lootSpec==specId and "green" or "ltgray",specName));

		if(i~=lootSpec)then
			tt:SetCellScript(l, cell, "OnMouseUp",secureExecute,{func="SetLootSpecialization",args={specId}});
		end

		cell=cell+1;
	end

	-- add auto loot spec
	if (cell+1 > ttColumns) then cell=2; l=tt:AddLine(" "); end
	local specName,curSpec,_ = UNKNOWN,C_SpecializationInfo.GetSpecialization();
	if curSpec then _,specName = C_SpecializationInfo.GetSpecializationInfo(curSpec); end
	tt:SetCell(l, cell, C(lootSpec==0 and "green" or "ltgray", LOOT_SPECIALIZATION_DEFAULT:format(specName)), nil, nil, 2);
	if lootSpec~=0 then
		tt:SetCellScript(l,2,"OnMouseUp",secureExecute,{func="SetLootSpecialization",args={0}});
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
	group = L["Instances"],
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
	clickOptions = {
		["rollneed"] = {ROLL..CHAT_HEADER_SUFFIX..NEED, "module", "roll"},
		["rollgreed"] = {ROLL..CHAT_HEADER_SUFFIX..GREED,"module","roll"},
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

local doUpdate = {
	PLAYER_ENTERING_WORLD=true,
	GROUP_ROSTER_UPDATE=true,
	PARTY_LOOT_METHOD_CHANGED=true,
	PLAYER_SPECIALIZATION_CHANGED=true,
	PLAYER_LOOT_SPEC_UPDATED=true,
	PLAYER_DIFFICULTY_CHANGED=true,
	CHAT_MSG_SYSTEM=true,
}
function module.onevent(self,event,...)
	local update = false;
	if event=="BE_UPDATE_CFG" then
		local arg1 = ...;
		if arg1 and arg1:find("^ClickOpt") then
			ns.ClickOpts.update(name);
			return;
		end
	elseif doUpdate[event] then
		updateBroker();
		if tt and tt:IsShown() then
			createTooltip(tt)
		end
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
