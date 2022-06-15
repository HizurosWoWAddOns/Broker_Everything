
-- module independent variables --
----------------------------------
local addon, ns = ...
if ns.client_version<6 then return end
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local nameC,nameF,nameS = "FollowersCore","Followers","Ships"; -- GARRISON_FOLLOWERS, GARRISON_SHIPYARD_FOLLOWERS L["ModDesc-Followers"] L["ModDesc-Ships"]
local ttNameF, ttColumnsF, ttF, moduleF = nameF.."TT", 7;
local ttNameS, ttColumnsS, ttS, moduleS = nameS.."TT" ,7;
local moduleC
local clickOptionsRename = {
	["1_open_garrison_report"] = "garrreport",
	["2_open_menu"] = "OptionMenu"
};
local  clickOptions = {
	["garrreport"] = "GarrisonReport",
	["menu"] = "OptionMenu"
};
local clickOptionsDefaults = {
	garrreport = "__NONE",
	menu = "_RIGHT"
};
local FOLLOWERS,SHIPS = GARRISON_FOLLOWERS,GARRISON_SHIPYARD_FOLLOWERS;
local CHAMPIONS,TROOPS = FOLLOWERLIST_LABEL_CHAMPIONS,FOLLOWERLIST_LABEL_TROOPS;
local COMPANIONS = COVENANT_MISSIONS_FOLLOWERS;
local ttInset1,ttInset2,ttHasStatusHeader,ttHasExpansionHeader = "  ","    ",false,false;

local typeListF = {
	{type="Type_9_0",exp=8,label=COMPANIONS,hasCombatSpells=true},
	{type="Type_8_0",exp=7,label=CHAMPIONS,labelTroops=TROOPS},
	{type="Type_7_0",exp=6,label=CHAMPIONS,labelTroops=TROOPS},
	{type="Type_6_0",exp=5,label=FOLLOWERS},
};

local typeListS = {
	{type="Type_6_2",exp=5,label=SHIPS},
};

local status2index = {
	-- 1 = available
	[GARRISON_FOLLOWER_ON_MISSION] = 2, -- onmission
	[GARRISON_FOLLOWER_EXHAUSTED] = 3, -- exhausted
	[GARRISON_FOLLOWER_WORKING] = 4, -- working
	[GARRISON_FOLLOWER_INACTIVE] = 5, -- inactive
};

-- tooltipStatusColors by statusIndex
local tooltipStatusColors = {"green","yellow","ltblue","orange","red"};
local qualityColors = {"white","ff1eaa00","ff0070dd","ffa335ee","ffff8000","ffB3965D"};

local tooltipStatusLabel = {
	C("green",AVAILABLE),
	C("yellow",GARRISON_FOLLOWER_ON_MISSION),
	C("orange",GARRISON_FOLLOWER_WORKING),
	C("ltblue",CHALLENGE_MODE_KEYSTONE_DEPLETED),--GARRISON_FOLLOWER_EXHAUSTED
	C("red",ADDON_DISABLED),
};

-- available, onmission, working, exhausted, disabled, aftermission

local traitIconStringPattern = {"Trade_","INV_Misc_Gem_01","Ability_HanzandFranz_ChestBump","INV_Misc_Pelt_Wolf_01","INV_Inscription_Tradeskill01"};

local traitIconFildIDs = {
	[136240] = true, -- Trade_Alchemy
	[136241] = true, -- Trade_BlackSmithing
	[136242] = true, -- Trade_BrewPoison
	[136243] = true, -- Trade_Engineering
	[136244] = true, -- Trade_Engraving
	[136245] = true, -- Trade_Fishing
	[136246] = true, -- Trade_Herbalism
	[136247] = true, -- Trade_LeatherWorking
	[136248] = true, -- Trade_Mining
	[136249] = true, -- Trade_Tailoring
	[134071] = true, -- INV_Misc_Gem_01
	[1037260] = true, -- Ability_HanzandFranz_ChestBump
	[134366] = true, -- INV_Misc_Pelt_Wolf_01
	[237171] = true, -- INV_Inscription_Tradeskill01
};

local config_defaults = {
	enabled = false,

	-- broker options
	--[[ -- filled by function
	showBroker_<Type_%d_%d> = true,
	]]

	-- tooltip options
	--[[ -- filled by function
	showTooltip_<Type_%d_%d> = false,
	showTooltip_<Type_%d_%d>t = false, -- troops
	showSummary_<Type_%d_%d> = false,
	--]]

	-- tooltip status tables
	showStatus1 = true, -- available
	showStatus2 = true, -- on mission
	showStatus3 = true, -- exhausted
	showStatus4 = false, -- working
	showStatus5 = false, -- inactive
	bgColoredStatus = false,

	-- tooltip alt/twink options
	showAllInOne = false,
	showHeaderInfo = true,
};

-- register icon names and default files --
-------------------------------------------
I[nameF]  = {iconfile="Interface\\Icons\\Achievement_GarrisonFolLower_Rare", coords={0.1,0.9,0.1,0.9} }; --IconName::Follower--
I[nameS]  = {iconfile="Interface\\Icons\\Achievement_GarrisonFolLower_Rare", coords={0.1,0.9,0.1,0.9} }; --IconName::Ships--


-- some local functions --
--------------------------
local sortKey;
do -- creates a string with big number for sorting
	local sortKeyFormat = "%02d%02d%03d%04d%04d";
	function sortKey(count,level,xp,quality,iLevel)
		return sortKeyFormat:format(100-level,10 --[[-quality]],100-ceil(xp),9999-iLevel,count);
	end
end

local function isTrait(icon)
	if traitIconFildIDs[icon] then
		return true;
	elseif type(icon)=="string" then
		-- fallback for old icon path strings
		ns:debug("follow.lua:isTrait","icon is a string");
		for i=1, #traitIconStringPattern do
			if icon:find(traitIconStringPattern) then
				return true;
			end
		end
	end
	return false;
end

-- for broker only
local function updateFollowers(name,Table,forTooltip)
	-- get garrison/shipyard level
	local garrLevel,name = false,nameF;
	if Table.type=="Type_6_2" then
		Table.garrLevel = (C_Garrison.GetOwnedBuildingInfoAbbrev(98) or 0) - 204;
		name = nameS;
	else
		Table.garrLevel = C_Garrison.GetGarrisonInfo(Enum.GarrisonType[Table.type]) or 0;
	end
	if Table.garrLevel<1 then
		-- garrison / shipyard not enabled
		return false;
	end
	-- reset / prepare some entries
	Table.follower_num = 0;
	if Table.labelTroops then
		Table.troop_num = 0;
	end
	for i=1, 5 do
		Table["status"..i] = {};
		Table["status"..i.."_num"] = 0;
	end

	local follower,troop,data,entryInfo,_ = {},{},C_Garrison.GetFollowers(Enum.GarrisonFollowerType["Follower"..Table.type]) or {};

	for i=1, #data do
		entryInfo = data[i];
		if entryInfo.isCollected then
			entryInfo.statusIndex = status2index[entryInfo.status] or 1; -- available
			if entryInfo.statusIndex==2 then -- onmission
				entryInfo.missionEnd = time()+C_Garrison.GetFollowerMissionTimeLeftSeconds(entryInfo.followerID);
			end
			if forTooltip then
				entryInfo.classColor = "red";
				if type(entryInfo.classAtlas)=="string" then -- has classAtlas
					_,entryInfo.classColor = strsplit("-",entryInfo.classAtlas);
				end
				if strlen(entryInfo.name)==0 then
					entryInfo.name = "["..UNKNOWN.."]";
				end
				entryInfo.xpPercent = 100;
				if entryInfo.levelXP>0 then
					entryInfo.xpPercent = entryInfo.xp/entryInfo.levelXP*100;
					entryInfo.xpPercentStr = ("%1.1f"):format(entryInfo.xpPercent).."%";
				end
				if entryInfo.isTroop then
					entryInfo.durabilityIconStr = "";
					local t = {};
					for i=1, entryInfo.maxDurability do
						if i<=entryInfo.durability then
							tinsert(t,"|T1384099:11:12:0:0:256:256:1:16:1:14|t"); --"GarrisonTroops-Health"
						else
							tinsert(t,"|T1384099:11:12:0:0:256:256:18:33:1:14|t"); --"GarrisonTroops-Health-Consume"
						end
					end
					entryInfo.durabilityIconStr = table.concat(t," ");
				end
			end
			if entryInfo.isTroop and Table.labelTroops then
				-- for broker button
				Table.troop_num = Table.troop_num + 1;

				-- sortable entries for tooltip
				if forTooltip then
					troop[ sortKey(Table.troop_num, entryInfo.level, entryInfo.xpPercent, entryInfo.quality, entryInfo.iLevel) ] = entryInfo;
				end
			elseif not entryInfo.isTroop then
				-- for broker button
				Table["status"..entryInfo.statusIndex.."_num"] = Table["status"..entryInfo.statusIndex.."_num"] + 1;
				Table.follower_num = Table.follower_num + 1;

				-- sortable entries for tooltip
				if forTooltip then
					follower[ sortKey(Table.follower_num, entryInfo.level, entryInfo.xpPercent, entryInfo.quality, entryInfo.iLevel) ] = entryInfo;
				end

				-- for alts/twink display in tooltip
				ns.toon[name][Table.type][entryInfo.garrFollowerID or entryInfo.followerID] = entryInfo.missionEnd or entryInfo.statusIndex; -- n < 10 == statusIndex; n > 10 == mission ending time
			end
		end
	end

	if forTooltip then
		return follower,troop;
	end
end

local function updateBroker(name)
	local text,Table = {},name==nameF and typeListF or typeListS;

	local status = {};
	for _, entry in ipairs(Table) do
		if ns.profile[name]["showBroker_"..entry.type] then
			if ns.profile[name].showAllInOne then
				for i=1, 4 do
					status[i] = (status[i] or 0)+(entry["status"..i.."_num"] or 0);
				end
				status[0] = (status[0] or 0)+(entry.follower_num or 0);
			else
				tinsert(text, ("%s/%s/%s/%s"):format(
					C("ltblue",(entry.status4_num or 0)),
					C("yellow",(entry.status2_num or 0)+(entry.status3_num or 0)),
					C("green",(entry.status1_num or 0)),
					(entry.follower_num or 0)
				));
			end
		end
	end

	if ns.profile[name].showAllInOne then
		tinsert(text, ("%s/%s/%s/%s"):format(
			C("ltblue",(status[4] or 0)),
			C("yellow",(status[2] or 0)+(status[3] or 0)),
			C("green",(status[1] or 0)),
			(status[0] or 0)
		));
	end

	-- fallback
	if #text==0 then
		if name==nameS then
			tinsert(text,GARRISON_SHIPYARD_FOLLOWERS);
		else
			tinsert(text,GARRISON_FOLLOWERS);
		end
	end

	(ns.LDB:GetDataObjectByName(ns.modules[name].ldbName) or {}).text = table.concat(text,", ");
end

local function addEntries(tt,name,entriesList,statusIndex,statusLabel,Table)
	for _,entryInfo in ns.pairsByKeys(entriesList) do
		if entryInfo.statusIndex==statusIndex then
			-- add status header
			if not ttHasStatusHeader then
				local entries = {statusLabel,C("ltblue",TYPE),C("ltblue",XP),C("ltblue",ABILITIES)};
				if name==nameF then
					tinsert(entries,4,C("ltblue",L["iLevel"]));
				end
				tt:AddSeparator(4,0,0,0,0);
				tt:AddLine(unpack(entries));
				tt:AddSeparator();
				ttHasStatusHeader = true;
			end

			-- add expansion header
			if not ttHasExpansionHeader then
				tt:AddLine(ttInset1..C("gray",_G["EXPANSION_NAME"..Table.exp]));
				tt:AddSeparator(1.1, 1,1,1, .4);
				ttHasExpansionHeader = true;
			end

			-- followerID string
			local id = "";
			--if ns.profile[name].showFollowerID then
			if true then
				local fID = tonumber(entryInfo.garrFollowerID or entryInfo.followerID);
				if fID then
					id = " "..C("ltgray","(".. fID ..")");
				end
			end

			-- abilities / combatSpells
			local abilities,abilityIcons,traitIcons,combatSpellIcons = {},{},{},{};
			for _,at in ipairs((C_Garrison.GetFollowerAbilities(entryInfo.followerID))) do
				if at.icon then
					tinsert(isTrait(at.icon) and traitIcons or abilityIcons,"|T"..at.icon..":14:14:0:0:64:64:4:56:4:56|t");
				end
			end
			if #abilityIcons>0 then
				tinsert(abilities,table.concat(abilityIcons," "));
			end
			if #traitIcons>0 then
				tinsert(abilities,table.concat(traitIcons," "));
			end
			if Table.hasCombatSpells then
				for _,cs in ipairs((C_Garrison.GetFollowerAutoCombatSpells(entryInfo.followerID,entryInfo.level)))do
					if cs.icon then
						tinsert(combatSpellIcons,"|T"..cs.icon..":14:14:0:0:64:64:4:56:4:56|t");
					end
				end
				if #combatSpellIcons>0 then
					tinsert(abilities,table.concat(combatSpellIcons," "));
				end
			end
			abilities = table.concat(abilities," || ");

			-- tooltip line
			local line
			if name==nameF then
				line = tt:AddLine(
					ttInset2 .. C(entryInfo.classColor,entryInfo.name) .. id,
					entryInfo.level.." ",
					entryInfo.xpPercentStr or C("gray","100%"),
					entryInfo.iLevel,
					abilities
				);
			else
				line = tt:AddLine(
					ttInset2 .. C(entryInfo.classColor,entryInfo.name) .. id,
					entryInfo.className.." ",
					entryInfo.xpPercentStr or C("gray","100%"),
					abilities,
					entryInfo.durabilityIconStr
				);
			end

			-- add color backdrop
			if entryInfo.quality>1 then
				local color = C(qualityColors[entryInfo.quality],"colortable");
				tt.lines[line].cells[1]:SetBackdrop({bgFile=ns.media.."rowbg", tile=false, insets={ left=0, right=0, top=1, bottom=0 }})
				tt.lines[line].cells[1]:SetBackdropColor(color[1],color[2],color[3],.5);
			end
			if ns.profile[name].bgColoredStatus then
				local color = C(tooltipStatusColors[statusIndex] or "red","colortable");
				tt.lines[line]:SetBackdrop({bgFile=ns.media.."rowbg", tile=false, insets={ left=0, right=0, top=1, bottom=0 }})
				tt.lines[line]:SetBackdropColor(color[1],color[2],color[3],.21);
			end
		end
	end
end

local clientShortcut
do
	local list = {"C","BC","WotLK","Cata","MoP","WoD","Legion","BfA","SL"};
	function clientShortcut(Type)
		local version = tonumber((Type:gsub("Type_(%d+)_%d+","%1")));
		if version and list[version] then
			return C("ltgray",list[version]);
		end
		return "";
	end
end

local function createTooltip(tt,name,ttName)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	local ttColumns = ttColumnsF;
	if name==nameS then
		tt:AddHeader(C("dkyellow",GARRISON_SHIPYARD_FOLLOWERS));
		ttColumns = ttColumnsS;
	elseif ns.client_version>7 then
		tt:AddHeader(C("dkyellow",("%s, %s, %s"):format(GARRISON_FOLLOWERS,FOLLOWERLIST_LABEL_CHAMPIONS,FOLLOWERLIST_LABEL_TROOPS)));
	else
		tt:AddHeader(C("dkyellow",GARRISON_FOLLOWERS));
	end

	if ns.profile[name].showChars then
		tt:AddSeparator(4,0,0,0,0);

		local l=tt:AddLine( C("ltblue",CHARACTER) ); -- 1
		local showHeaderInfo = ns.profile[name].showHeaderInfo;
		if IsShiftKeyDown() then
			tt:SetCell(l, 2, C("ltblue",L["Back from missions"])..(showHeaderInfo and "|n"..L["next"].." / "..SPELL_TARGET_TYPE12_DESC or ""), nil, "RIGHT", 3);
		else
			tt:SetCell(l, 2, C("ltblue",GARRISON_FOLLOWER_ON_MISSION)..(showHeaderInfo and "|n".. C("green",GOAL_COMPLETED) .." / ".. C("yellow",GARRISON_SHIPYARD_MSSION_INPROGRESS_TOOLTIP) or ""), nil, "RIGHT", 3);
		end
		tt:SetCell(l, 5, C("ltblue",L["Without missions"])..(showHeaderInfo and "|n".. C("green",L["Chilling"]) .." / ".. C("yellow",GARRISON_FOLLOWER_WORKING) or ""), nil, "RIGHT", 2);
		tt:SetCell(l, 7, C("ltblue",GARRISON_FOLLOWERS)..(showHeaderInfo and "|n" .. C("cyan",COLLECTED) .." / ".. C("green",CONTRIBUTION_ACTIVE) .." / ".. C("yellow",GARRISON_FOLLOWER_INACTIVE) or ""));

		tt:AddSeparator();
		local t = time();
		for index, toonNameRealm, toonName, toonRealm, toonData, isCurrent in ns.pairsToons(name,{currentFirst=true,forceSameRealm=true}) do
			-- available, onmission, working, exhausted, disabled, aftermission
			local countStatus,collected,cMission,cWorking,cCollected,clients,show = {},{},{},{},{},{};
			local nextMissionEnding,activeMission = 0,0;
			for _,e in ipairs(name==nameF and typeListF or typeListS) do
				local Type = e.type;
				if ns.profile[name]["showSummary_"..Type] and toonData[name] and toonData[name][Type] then
					local ExpansionFollowers = toonData[name][Type];
					countStatus[Type],collected[Type] = {0,0,0,0,0,0},0;
					for followerID, followerStatus in pairs(ExpansionFollowers)do
						if followerStatus>10 then
							if followerStatus>t and (nextMissionEnding==0 or followerStatus<nextMissionEnding) then
								nextMissionEnding = followerStatus;
							end
							if followerStatus>activeMission then
								activeMission = followerStatus;
							end
							followerStatus = followerStatus>t and 2 or 6;
						end
						countStatus[Type][followerStatus] = countStatus[Type][followerStatus] + 1;
						collected[Type] = collected[Type] + 1;
						show = true
					end
					tinsert(clients,    clientShortcut(Type));
					tinsert(cMission,   (countStatus[Type][6]==0 and "−" or C("green",countStatus[Type][6])) .."/".. (countStatus[Type][2]==0 and "−" or C("yellow",countStatus[Type][2])) );
					tinsert(cWorking,   (countStatus[Type][4]==0 and "−" or C("green",countStatus[Type][4])) .."/".. (countStatus[Type][3]==0 and "−" or C("yellow",countStatus[Type][3])) );
					tinsert(cCollected, C("cyan",collected[Type]) .. "/" .. C("green",collected[Type]-countStatus[Type][5]) .. "/" .. C("yellow",countStatus[Type][5]) );
				end
			end
			if show then
				local faction,str,l = toonData.faction and " |TInterface\\PVPFrame\\PVP-Currency-"..toonData.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";

				if IsShiftKeyDown() then
					str = SecondsToTime(nextMissionEnding-t) .. " / " .. SecondsToTime(activeMission-t);
				else
					str = table.concat(cMission,"|n");
				end

				l = tt:AddLine(C(toonData.class,ns.scm(toonName)) .. ns.showRealmName(name,toonRealm) .. faction );
				tt:SetCell(l, 2, table.concat(clients,"|n"), nil, "CENTER");
				tt:SetCell(l, 3, str, nil, "RIGHT", 2);
				tt:SetCell(l, 5, table.concat(cWorking, "|n"), nil, "RIGHT", 2);
				tt:SetCell(l, 7, table.concat(cCollected, "|n") );

				if isCurrent then -- highlight current toon
					tt:SetLineColor(l, 0.1, 0.3, 0.6);
				end
			end
		end
	end

	local followerList,troopList,tableList = {},{},{},{};
	for i, Table in ipairs(name==nameF and typeListF or typeListS) do
		if ns.profile[name]["showTooltip_"..Table.type] then
			local follower,troop = updateFollowers(name,Table,true);
			if follower then
				tinsert(tableList,Table);
				followerList[#tableList] = follower;
				if troop and ns.profile[name]["showTooltip_"..Table.type.."t"] then
					troopList[#tableList] = troop;
				end
			end
		end
	end

	-- order: status, expansion, followers
	ttHasStatusHeader,ttHasExpansionHeader = false,false;
	for _,statusIndex in ipairs({2,3,4,1,5})do
		local statusLabel = tooltipStatusLabel[statusIndex];
		if ns.profile[name]["showStatus"..statusIndex] then
			ttHasStatusHeader = false;
			for index,Table in ipairs(tableList) do -- loop tables (expansions)
				ttHasExpansionHeader = false;
				-- followers / ships
				addEntries(tt,name,followerList[index],statusIndex,statusLabel,Table);
				-- troops
				if troopList[index] and ns.profile[name]["showTooltip_"..Table.type.."t"] then
					addEntries(tt,name,troopList[index],statusIndex,statusLabel,Table);
				end
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltblue",L["MouseBtn"]).." || "..C("green",L["Activate specialization"]),nil,"LEFT",ttColumns);
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
moduleC = {
	isHiddenModule = true,
	events = {
		"PLAYER_LOGIN",
		"GARRISON_FOLLOWER_LIST_UPDATE",
		"GARRISON_FOLLOWER_UPGRADED",
		"GARRISON_FOLLOWER_XP_CHANGED",
		"GARRISON_FOLLOWER_REMOVED",
	},
	config_defaults = {
		enabled = false, -- autoenabled by other modules
	},
	--clickOptionsRename = {},
	--clickOptions = {}
};

moduleF = {
	events = {"PLAYER_LOGIN"},
	config_defaults = CopyTable(config_defaults),
	clickOptionsRename = clickOptionsRename,
	clickOptions = clickOptions
};

moduleS = {
	events = {"PLAYER_LOGIN"},
	config_defaults = CopyTable(config_defaults),
	clickOptionsRename = clickOptionsRename,
	clickOptions = clickOptions
};

ns.ClickOpts.addDefaults(moduleF,clickOptionsDefaults);
ns.ClickOpts.addDefaults(moduleS,clickOptionsDefaults);

local initOptions
do
	local optTooltip,optBroker = {},{};
	local sharedOptTooltip = {
		showChars={1,true},
		showAllFactions=2,
		showRealmNames=3,
		showCharsFrom=4,
		bgColoredStatus = { type="toggle", order=5, name=L["FollowersBgColorStatus"], desc=L["FollowersBgColorStatusDesc"] },
		showHeaderInfo = { type="toggle", order=6, name=L["FollowersHeaderInfo"], desc=L["FollowersHeaderInfoDesc"]:format(C("cyan",COLLECTED) .." / ".. C("green",CONTRIBUTION_ACTIVE) .." / ".. C("yellow",GARRISON_FOLLOWER_INACTIVE)) },
		statusHeader = { type="group", order=10, name=STATUS, args={} },
		expansionHeader = { type="header", order = 20, name=EXPANSION_FILTER_TEXT },
	}
	local sharedOptBroker = {
		showAllInOne = { type="toggle", order=1, name=L["Show all in one"],       desc=L["FollowersAIODesc"]},
		expansions = { type="header", order=20, name=EXPANSION_FILTER_TEXT },
	}
	local hide = {
		ShipsNew_broker_showAllInOne = true,
		ShipsNew_broker_expansions = true
	}
	local replace = {
		bgColoredStatus = {[nameF]=GARRISON_FOLLOWERS,[nameS]=GARRISON_SHIPYARD_FOLLOWERS}
	}

	local function CopyOptEntry(modName,Entry)
		if type(Entry)=="table" then
			local entry = CopyTable(Entry);
			if type(entry.name)=="string" and entry.name:match("%%s") then
				entry.name = entry.name:format(L[modName])
			end
			if type(entry.desc)=="string" and entry.desc:match("%%s") then
				entry.desc = entry.desc:format(L[modName])
			end
			return entry;
		end
		return Entry;
	end

	local function isSummaryEnabled(modName)
		return not ns.profile[modName].showChars;
	end

	local function addTypeListOpt(modName,entry,c)
		local expansionLabel = _G["EXPANSION_NAME"..entry.exp];
		optTooltip[modName]["exp_"..entry.exp] = {
			type = "group", order = c, inline = true, name = expansionLabel,
			args = {
				["showTooltip_"..entry.type]      = { type="toggle", order=1, name=entry.label, desc=L["Show %s in tooltip"]:format(entry.label)},
				["showSummary_"..entry.type]      = { type="toggle", order=3, name=OVERVIEW,    desc=L["FollowersSummaryDesc"]:format(expansionLabel), width="double", disabled=function() return isSummaryEnabled(modName) end},
			}
		};
		if entry.labelTroops then
			optTooltip[modName]["exp_"..entry.exp].args["showTooltip_"..entry.type.."t"] = { type="toggle", order=2, name=TROOPS,      desc=L["Show troops in tooltip"], width="half"};
		end
		local bbLabel = string.format("%s (%s)",expansionLabel,entry.label);
		optBroker[modName]["showBroker_"..entry.type] = { type="toggle", order=c, name=bbLabel, desc=L["Show %s in broker button"]:format(bbLabel) };
	end

	function initOptions()
		for _, modName in ipairs({nameF,nameS})do
			-- update config defaults
			local m,t = moduleF,typeListF;
			if modName==nameS then
				m,t = moduleS,typeListS;
			end
			local cfgDef,state = m.config_defaults,true;
			for _, e in ipairs(t)do -- typeListF / typeListS
				cfgDef["showBroker_"..e.type] = state;
				cfgDef["showTooltip_"..e.type] = state;
				if e.labelTroops then
					cfgDef["showTooltip_"..e.type.."t"] = state;
				end
				cfgDef["showSummary_"..e.type] = state;
				-- only the first (current expansion) will be enabled by default
				state = false;
			end

			-- copy shared options
			optBroker[modName] = {};
			for optKey,optEntry in pairs(sharedOptBroker)do
				if not hide[modName.."_broker_"..optKey] then
					optBroker[modName][optKey] = CopyOptEntry(modName,optEntry);
				end
			end
			optTooltip[modName] = {};
			for optKey,optEntry in pairs(sharedOptTooltip)do
				if not hide[modName.."_tooltip_"..optKey] then
					optTooltip[modName][optKey] = CopyOptEntry(modName,optEntry);
					if replace[optKey] then
						optTooltip[modName][optKey].desc = optTooltip[modName][optKey].desc:format(replace[optKey][modName]);
					end
				end
			end
		end

		-- clean shared option tables
		sharedOptBroker,sharedOptTooltip = nil,nil;

		-- add more options [status labels]
		local c = 11;
		for i,statusLabel in ipairs(tooltipStatusLabel)do
			optTooltip[nameF].statusHeader.args["showStatus"..i] = { type="toggle", order=c, name=statusLabel, desc=L["FollowersStatusLabelDesc"]:format(statusLabel) };
			optTooltip[nameS].statusHeader.args["showStatus"..i] = optTooltip[nameF].statusHeader.args["showStatus"..i];
			c=c+1;
		end

		local c = 21;
		for _,entry in ipairs(typeListF) do
			addTypeListOpt(nameF,entry,c)
			c=c+1;
		end
		c = 21;
		for _,entry in ipairs(typeListS)do
			addTypeListOpt(nameS,entry,c)
			c=c+1;
		end
	end

	function moduleF.options()
		if initOptions then
			initOptions();
			initOptions=nil;
		end
		return {broker=optBroker[nameF],tooltip=optTooltip[nameF],misc=nil};
	end

	function moduleS.options()
		if initOptions then
			initOptions();
			initOptions=nil;
		end
		return {broker=optBroker[nameS],tooltip=optTooltip[nameS],misc=nil};
	end
end

-- function module.init() end

function moduleC.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" then
		if arg1 and arg1:find("^ClickOpt") then
			if moduleF.isEnabled then
				ns.ClickOpts.update(nameF);
			end
			if moduleS.isEnabled then
				ns.ClickOpts.update(nameS);
			end
			return;
		end
	end
	if moduleF.isEnabled then
		if ns.toon[nameF]==nil then
			ns.toon[nameF] = {};
		end
		for _,Table in pairs(typeListF)do
			if ns.toon[nameF][Table.type]==nil then
				ns.toon[nameF][Table.type] = {};
			end
			updateFollowers(nameF,Table);
		end
		updateBroker(nameF);
	end
	if moduleS.isEnabled then
		if ns.toon[nameS]==nil then
			ns.toon[nameS] = {};
		end
		for _,Table in pairs(typeListS)do
			if ns.toon[nameS][Table.type]==nil then
				ns.toon[nameS][Table.type] = {};
			end
			updateFollowers(nameS,Table);
		end
		updateBroker(nameS);
	end
end

local function onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" then
		if arg1 and arg1:find("^ClickOpt") then
			--ns.ClickOpts.update(name);
			return
		end
		-- update broker on config changes
		if self.eventframe==moduleF.eventframe then
			if moduleF.isEnabled then
				updateBroker(nameF);
			end
		else
			if moduleS.isEnabled then
				updateBroker(nameS);
			end
		end
	elseif event=="PLAYER_LOGIN" and not moduleC.isEnabled then
		ns.moduleInit(nameC,true);
	end
end

moduleF.onevent = onevent;
moduleS.onevent = onevent;

-- function module.onmousewheel(self,direction) end
-- function module.optionspanel(panel) end
-- function module.ontooltip(tt) end

function moduleF.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttF = ns.acquireTooltip({ttNameF, ttColumnsF, "LEFT", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "RIGHT"},{true},{self});
	createTooltip(ttF, nameF, ttNameF)
end

function moduleS.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttS = ns.acquireTooltip({ttNameS, ttColumnsS, "LEFT", "LEFT", "CENTER", "CENTER", "CENTER", "RIGHT","RIGHT"},{true},{self});
	createTooltip(ttS, nameS)
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[nameC] = moduleC;
ns.modules[nameF] = moduleF;
ns.modules[nameS] = moduleS;
