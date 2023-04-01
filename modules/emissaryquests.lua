
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<7 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Emissary Quests"; -- BOUNTY_BOARD_LOCKED_TITLE L["ModDesc-Emissary Quests"]
local ttName, ttColumns, tt, module = name.."TT", 8
local factions,totalQuests,locked = {},{},false;
local Alliance = UnitFactionGroup("player")=="Alliance";
local spacer,ending,endings = 604800,{},{};

local expansions = {
	--[0] = false, -- vanilla
	[1] = false, -- bc
	[2] = false, -- wotlk
	[3] = false, -- cata
	[4] = false, -- mop
	[5] = false, -- wod
	[6] = { name="legion", zone=630, numBounties=3 },
	[7] = { name="bfa", zone=Alliance and 876 or 875, numBounties=3 },
	--{ name="sl", zone=0, numBounties=3, minLevel=60 },
}
local questID2factionID = {
	-- legion
	[42170]=1883, [42233]=1828, [42234]=1948, [42420]=1900, [42421]=1859,
	[42422]=1894, [43179]=1090, [48639]=2165, [48641]=2045, [48642]=2170,
	-- bfa
	[50600]=2161, [50601]=2162, [50599]=2160, [50605]=2159, -- alliance
	[50603]=2158, [50598]=2103, [50602]=2156, [50606]=2157, -- horde
	[50604]=2163, [50562]=2164, -- neutral
	-- bfa 8.2
	[56119]=2400, -- alliance
	[56120]=2373, -- horde
	-- bfa 8.3
	--[0]=2415, -- Rajani
	--[0]=2417, -- Uldum Accord
}
local foreignFactions = Alliance and {
	-- list of horde factions to hide on alliance characters
	[2103]=2160, -- zandalari (zuldazar)
	[2156]=2162, -- talanji (nazmir)
	[2158]=2161, -- voldunai (voldun)
	[2157]=2159, -- Honorbound (kultiras)
	[2373]=2400, -- Unshackled (nazjatar)
} or {
	[2160]=2103, -- Proudmoore Admiralty (Tiragarde Sound)
	[2162]=2156, -- Storm's Wake (Stormsong Valley)
	[2161]=2158, -- Order of Embers (drustvar)
	[2159]=2157, -- 7th Legion (Zandalar)
	[2400]=2373, -- Waveblade Ankoan (nazjatar)
};

local factionName = setmetatable({},{__index=function(t,k)
	local v = GetFactionInfoByID(k);
	if v then
		rawset(t,k,v);
	end
	return v or k;
end});

L[name] = BOUNTY_BOARD_LOCKED_TITLE;
if not rawget(L,"Emissary Quests-ShortCut") then
	L["Emissary Quests-ShortCut"] = "EQ";
end


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\QuestFrame\\UI-QuestLog-BookIcon",coords={0.05,0.95,0.05,0.95}}; --IconName::Emissary Quests--


-- some local functions --
--------------------------
local function sortFactions(a,b)
	return a.eventEnding<b.eventEnding;
end

local function sortInvertFactions(a,b)
	return not sortFactions(a,b);
end

local function updateBroker()
	local lst,obj = {},ns.LDB:GetDataObjectByName(module.ldbName);
	if UnitLevel("player")<GetMaxLevelForExpansionLevel(6) then
		obj.text = ns.profile[name].shortTitle and L["Emissary Quests-ShortCut"] or L[name];
		return
	end
	local Time = time();
	for e=1, #expansions do
		if expansions[e] and ns.profile[name][expansions[e].name.."QuestsBroker"] then
			for _,ending in ipairs(endings) do
				local bounties = ns.data[name].bounties[ending][e];
				if bounties and bounties[ns.player.faction] and bounties.totalQuests then
					local completed = ns.toon[name].bounties[ending][e];
					local icon = "|T"..(bounties[ns.player.faction.."Icon"] or ns.icon_fallback)..":14:14:0:0:64:64:4:56:4:56|t";
					if completed==true then
						tinsert(lst,C("gray",bounties.totalQuests.."/"..bounties.totalQuests).." "..icon);
					elseif completed then
						local text = completed.."/"..bounties.totalQuests;
						if completed == bounties.totalQuests then
							tinsert(lst,C("green",text).."|T132048:14:14:0:0|t"..icon);
						else
							tinsert(lst,text.." "..icon);
						end
					end
				end
			end
		end
	end
	if #lst>0 then
		obj.text = table.concat(lst," ");
	end
end

local function GetBountyObjectivesSum(questID,numObjectives)
	local numCompleted,numTotal,err = 0,0,true;
	if questID>0 then
		for objectiveIndex = 1, numObjectives do
			local objectiveText, _, _, numFulfilled, numRequired = GetQuestObjectiveInfo(questID, objectiveIndex, false);
			if objectiveText and #objectiveText > 0 and numRequired > 0 then
				err=false;
				numCompleted, numTotal = numCompleted+numFulfilled, numTotal+numRequired;
			end
		end
	end
	return numCompleted, numTotal, err;
end

local function unlock()
	locked = false;
end


--[[

ns.toon[name].bounties = {
	[<ending>] = {
		[<expansionIndex>] = <numWorldQuests[int]|questFlaggedCompleted[true]>
	},
}

ns.data[name].bounties = {
	[<ending>] = { [<expansionIndex>] = { alliance=<factionID_Alliance[int]>, horde=<factionID_Horde[int]>, totalQuests=<maxWorldQuests[int]> } }
}

--]]

local function floorTime(_time)
	return floor(_time/60)*60;
end

local function ceilTime(_time)
	return ceil(_time/60)*60;
end

local function updateData()
	local day,Time = 86400,time();
	local endsToday = ceilTime( Time+GetQuestResetTime() );
	endings = {endsToday};
	for i=1, 4 do
		tinsert(endings,endsToday+(day*i));
	end

	-- check / create entries in tables
	for i=1,#endings do
		if ns.data[name].bounties[endings[i]]==nil then
			ns.data[name].bounties[endings[i]] = {}
		end
		if ns.toon[name].bounties[endings[i]]==nil then
			ns.toon[name].bounties[endings[i]] = {}
		end
	end

	for ending,data in pairs(ns.data[name].bounties) do
		if data then
			for expIndex,expData in pairs(data) do
				if expData then
					expData.dirty = true;
				end
			end
		end
	end

	for e=1, #expansions do
		local exp = expansions[e];
		if exp then
			local bounties
			if GetQuestBountyInfoForMapID then
				bounties = GetQuestBountyInfoForMapID(exp.zone); -- empty table on chars lower than 110
			elseif C_QuestLog.GetBountiesForMapID then
				bounties = C_QuestLog.GetBountiesForMapID(exp.zone);
			end
			 -- TODO: removed in shadowlands
			if type(bounties)=="table" then
				for b=1, #bounties do
					local bty = bounties[b];
					C_TaskQuest.RequestPreloadRewardData(bty.questID);
					local TimeLeft = C_TaskQuest.GetQuestTimeLeftMinutes(bty.questID);
					local factionID = questID2factionID[bty.questID];
					if TimeLeft and factionID then
						local ending = TimeLeft>0 and floorTime(Time)+(TimeLeft*60) or 0;
						local m = date("%M",ending);
						if m=="01" or m=="31" then
							ending = ending - 60;
						end
						if ns.data[name].bounties[ending] then
							if ns.data[name].bounties[ending][e]==nil then
								ns.data[name].bounties[ending][e] = {}
							end
							local completed,total = GetBountyObjectivesSum(bty.questID,bty.numObjectives);
							ns.data[name].bounties[ending][e][ns.player.faction] = factionID;
							ns.data[name].bounties[ending][e][ns.player.faction.."Icon"] = bty.icon;
							ns.data[name].bounties[ending][e].totalQuests = total;
							ns.data[name].bounties[ending][e].dirty = nil;

							if C_QuestLog.IsQuestFlaggedCompleted(bty.questID) then
								ns.toon[name].bounties[ending][e] = true;
							else -- if not flagged completed but 4/4 quests. player can travel to questgiver
								ns.toon[name].bounties[ending] = ns.toon[name].bounties[ending] or {};
								ns.toon[name].bounties[ending][e] = completed or -1;
							end
						end
					end
				end
			end
		end
	end

	for ending,data in pairs(ns.data[name].bounties) do
		if data then
			for expIndex,expData in pairs(data) do
				if expData and expData.dirty then
					if ns.toon[name].bounties and ns.toon[name].bounties[ending] and ns.toon[name].bounties[ending][expIndex] then
						ns.toon[name].bounties[ending][expIndex] = true;
					end
					expData.dirty = nil;
				end
			end
		end
	end

	updateBroker();
	C_Timer.After(0.314159,unlock);
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	local minLevel,Time,level = 999,time(),UnitLevel("player");

	for e=1, #expansions do
		local expMaxLevel = GetMaxLevelForExpansionLevel(e);
		if expansions[e] and ns.profile[name][expansions[e].name.."Quests"] and expMaxLevel<minLevel then
			minLevel = expMaxLevel;
		end
	end

	if tt.lines~=nil then tt:Clear(); end
	tt:SetCell(tt:AddLine(),1,C("dkyellow",BOUNTY_BOARD_LOCKED_TITLE),tt:GetHeaderFont(),"LEFT",0);

	tt:AddSeparator(4,0,0,0,0);
	local missing,l=false,tt:AddLine(C("ltblue",FACTION));
	tt:SetCell(l,2,C("ltblue",TIME_REMAINING:gsub(HEADER_COLON,""):gsub("：",""):trim()),nil,"RIGHT",0);
	tt:AddSeparator();

	local toon,factions = {},{};
	local exp = 0;

	for e=1, #expansions do
		if expansions[e] and ns.profile[name][expansions[e].name.."Quests"] then
			for _,ending in ipairs(endings) do
				local bounties = ns.data[name].bounties[ending][e];
				if bounties and bounties.totalQuests then
					local faction = UNKNOWN;
					if bounties[ns.player.faction] then
						faction = GetFactionInfoByID(bounties[ns.player.faction]);
					else
						missing = true;
					end
					if exp~=e then
						exp = e;
						tt:SetCell(tt:AddLine(),1,C("ltgreen",_G["EXPANSION_NAME"..e]),nil,"LEFT",0);
					end
					local color1,color2 = "ltyellow","white";
					if ns.toon[name].bounties[ending] then
						if ns.toon[name].bounties[ending][e]==true then
							color1,color2 = "ltgray","ltgray";
						elseif ns.toon[name].bounties[ending][e]==bounties.totalQuests then
							color1,color2 = "green","white";
							faction = faction .. " |T132048:14:14:0:0|t"; -- add question mark for finished quest
						end
					end
					if ns.profile[name].showID and bounties[ns.player.faction] then
						faction = faction .. C("gray"," ("..bounties[ns.player.faction]..")");
					end
					local l=tt:AddLine("  |T"..(bounties[ns.player.faction.."Icon"] or ns.icon_fallback)..":14:14:0:0:64:64:4:56:4:56|t "..C(color1,faction));
					tt:SetCell(l,2,C(color2,SecondsToTime(ending-Time)),nil,"RIGHT",0);
					tinsert(factions,bounties[ns.player.faction.."Icon"] or ns.icon_fallback);
				end
			end
		end
	end

	if level<minLevel and missing then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("gray",L["World quests status update requires min. level:"]),nil,"LEFT",0);
		for e=1, #expansions do
			if expansions[e] and level<expansions[e].minLevel then
				tt:SetCell(tt:AddLine(),1,C("gray",_G["EXPANSION_NAME"..expansions[e].index].." = "..LEVEL.." "..expansions[e].minLevel),nil,"LEFT",0);
			end
		end
	end

	if ns.profile[name].showCharacters then
		tt:AddSeparator(12,0,0,0,0);
		local c,l=2,tt:AddLine(C("ltblue",CHARACTER));

		for e=1, #expansions do
			for _,ending in ipairs(endings) do
				if expansions[e] and ns.profile[name][expansions[e].name.."Quests"] and ns.data[name].bounties[ending] and ns.data[name].bounties[ending][e] then
					tt:SetCell(l,c,"|T"..(ns.data[name].bounties[ending][e][ns.player.faction.."Icon"] or ns.icon_fallback)..":24:24:0:0:64:64:4:56:4:56|t",nil,"CENTER");
					c=c+1;
				end
			end
		end

		tt:AddSeparator();

		local chars,_ = 0;
		for i,toonNameRealm,toonName,toonRealm,toonData,isCurrent in ns.pairsToons(name,{currentFirst=true,forceSameRealm=true}) do
			local cell,line = 2;
			if toonData.level>=minLevel then
				local faction = toonData.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..toonData.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
				if type(toonRealm)=="string" and toonRealm:len()>0 then
					local _,_realm = ns.LRI:GetRealmInfo(toonRealm);
					if _realm then toonRealm = _realm; end
				end

				cell,line = 2,tt:AddLine(C(toonData.class,ns.scm(toonName)) .. ns.showRealmName(name,toonRealm) .. faction);

				if isCurrent then
					tt:SetLineColor(line, .25, .25, .25); -- highlight current toon
				end

				for e=1, #expansions do
					for _,ending in ipairs(endings) do
						if expansions[e] and toonData.level>=GetMaxLevelForExpansionLevel(e) and ns.profile[name][expansions[e].name.."Quests"] and ns.data[name].bounties[ending] and ns.data[name].bounties[ending][e] then
							local cellContent,completed,total = "",0,ns.data[name].bounties[ending][e].totalQuests;
							if toonData[name] and toonData[name].bounties and toonData[name].bounties[ending] and toonData[name].bounties[ending][e] then -- error?
								completed = toonData[name].bounties[ending][e] or 0;
							end
							if not completed then
								cellContent = C("gray","?/?");
							elseif completed==true then
								cellContent = C("gray",total.."/"..total);
							else
								cellContent = C("white",completed.."/"..total);
							end
							tt:SetCell(line,cell,cellContent,nil,"CENTER");
							cell=cell+1;
						end
					end
				end
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0)
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"VARIABLES_LOADED",
		"QUEST_LOG_UPDATE"
	},
	config_defaults = {
		enabled = false,
		shortTitle = false,
		showAllFactions=true,
		showRealmNames=true,
		showCharsFrom="2",
		legionQuestsBroker = false,
		legionQuests = true,
		bfaQuestsBroker = true,
		bfaQuests = true,
		showCharacters = true,
		showID = false,
	},
	clickOptionsRename = {
		["menu"] = "9_open_menu"
	},
	clickOptions = {
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,"menu","_RIGHT");

function module.options()
	return {
		broker = {
			shortTitle={ type="toggle", order=1, name=L["Show shorter title"], desc=L["Display '%s' instead of '%s' on chars under level 110 on broker button"]:format(L["Emissary Quests-ShortCut"],BOUNTY_BOARD_LOCKED_TITLE) },
			legionQuestsBroker = { type="toggle", order=2, name=BOUNTY_BOARD_LOCKED_TITLE.." ("..EXPANSION_NAME6..")", desc=L["Display the progress of your emissary quests on broker button"], width="full" },
			bfaQuestsBroker = { type="toggle", order=3, name=BOUNTY_BOARD_LOCKED_TITLE.." ("..EXPANSION_NAME7..")", desc=L["Display the progress of your emissary quests on broker button"], width="full" },
		},
		tooltip = {
			legionQuests = { type="toggle", order=1, name=BOUNTY_BOARD_LOCKED_TITLE.." ("..EXPANSION_NAME6..")", desc=L["Display the progress of your emissary quests in tooltip"], width="full" },
			bfaQuests = { type="toggle", order=2, name=BOUNTY_BOARD_LOCKED_TITLE.." ("..EXPANSION_NAME7..")", desc=L["Display the progress of your emissary quests in tooltip"], width="full" },
			showCharacters = { type="toggle", order=3, name=L["Show characters"], desc=L["Display a list of your other characters and there emissary quest progress in tooltip"] },
			showID = { type="toggle", order=4, name=L["Show id's"], desc=L["Display faction id's in tooltip"]},
			showAllFactions=5,
			showRealmNames=6,
			showCharsFrom=7,
		},
		misc = nil,
	}
end

-- function module.init() end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="VARIABLES_LOADED" then
		local day,Time = 86400,time();
		-- check / create tables
		if ns.data[name]==nil then
			ns.data[name] = {};
		end
		if ns.data[name].bounties==nil then
			ns.data[name].bounties = {};
		end
		if ns.toon[name]==nil then
			ns.toon[name] = {}
		end
		if ns.toon[name].bounties==nil then
			ns.toon[name].bounties = {};
		end
		-- remove older entries from tables
		local _time = Time-day;
		for k in pairs(ns.data[name].bounties)do
			if k<_time then
				ns.data[name].bounties[k] = nil;
			end
		end
		for k in pairs(ns.toon[name].bounties)do
			if k<_time then
				ns.toon[name].bounties[k] = nil;
			end
		end
	elseif ns.eventPlayerEnteredWorld and not locked then
		locked = true;
		C_Timer.After(0.314159,updateData);
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "CENTER","CENTER","CENTER","CENTER","CENTER","CENTER"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
