
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I

-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Emissary Quests"; -- BOUNTY_BOARD_LOCKED_TITLE L["ModDesc-Emissary Quests"]
local ttName, ttColumns, tt, module = name.."TT", 8
local factions,totalQuests,locked = {},{},false;
local Alliance = UnitFactionGroup("player")=="Alliance";
local spacer,ending = 604800,{};
local expansions = {
	{ name="legion", index=6, zone=630, numBounties=3, minLevel=110},
	{ name="bfa", index=7, zone=Alliance and 876 or 875, numBounties=3, minLevel=120},
}
local questID2factionID = {
	-- legion
	[42170]=1883, [42233]=1828, [42234]=1948, [42420]=1900, [42421]=1859,
	[42422]=1894, [43179]=1090, [48639]=2165, [48641]=2045, [48642]=2170,
	-- bfa
	[50600]=2161, [50601]=2162, [50599]=2160, [50605]=2159, [50603]=2158,
	[50598]=2103, [50602]=2156, [50606]=2157, [50604]=2163, [50562]=2164,
}
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
	if UnitLevel("player")<110 then
		obj.text = ns.profile[name].shortTitle and L["Emissary Quests-ShortCut"] or L[name];
		return
	end

	local Time = time();
	for e=1, #expansions do
		if factions[e] then
			table.sort(factions[e],sortFactions);
			for _,v in ipairs(factions[e]) do
				if ns.profile[name][expansions[e].name.."QuestsBroker"] and v.eventEnding-Time>=0 then
					local toon = ns.toon[name].factions[v.factionID] or {};
					if toon.lastEnding==nil then
						toon.lastEnding = 0;
					end
					if v.eventEnding>toon.lastEnding then
						toon.lastEnding = v.eventEnding;
						toon.numCompleted = 0;
					end
					if toon.numCompleted>v.numTotal then
						toon.numCompleted=v.numTotal;
					end
					local text = toon.numCompleted.."/"..v.numTotal;
					if toon.numCompleted<v.numTotal then
						tinsert(lst,text.." |T"..v.icon..":14:14:0:0:64:64:4:56:4:56|t");
					else
						tinsert(lst,C("gray",text).." |T"..v.icon..":14:14:0:0:64:64:4:56:4:56|t");
					end
				end
			end
		end
	end
	if #lst>0 then
		obj.text = table.concat(lst," ");
	end
end

local function CalculateBountySubObjectives(data,toon)
	local reset = true;
	if data.questID>0 then
		for objectiveIndex = 1, data.numObjectives do
			local objectiveText, _, _, numFulfilled, numRequired = GetQuestObjectiveInfo(data.questID, objectiveIndex, false);
			if objectiveText and #objectiveText > 0 and numRequired > 0 then
				for objectiveSubIndex = 1, numRequired do
					if reset then
						toon.numCompleted = 0;
						data.numTotal = 0;
						reset = false;
					end
					if objectiveSubIndex <= numFulfilled then
						toon.numCompleted = toon.numCompleted + 1;
					end
					data.numTotal = data.numTotal + 1;
					if data.numTotal >= MAX_BOUNTY_OBJECTIVES then
						return;
					end
				end
			end
		end
	end
end

local function unlock()
	locked = false;
end

local function updateData()
	if locked then return end locked = true;

	local Time = time();
	local ending,endings,day = {Time+GetQuestResetTime()+1},{},86400;
	ending[2] = ending[1]+day;
	ending[3] = ending[2]+day;
	ending[4] = ending[3]+day;

	local Time = floor(Time/60)*60;
	for e=1, #expansions do
		endings[e] = {};
		local bounties,location,locked = GetQuestBountyInfoForMapID(expansions[e].zone); -- empty table on chars lower than 110
		for i=1, #bounties do
			local TimeLeft = C_TaskQuest.GetQuestTimeLeftMinutes(bounties[i].questID) or 0;
			bounties[i].expansion = e;
			bounties[i].continent = expansions[e].zone;
			bounties[i].eventEnding = TimeLeft>0 and Time+(TimeLeft*60) or 0;
			bounties[i].factionID = questID2factionID[bounties[i].questID];
			if bounties[i].factionID then
				ns.data[name].factions[bounties[i].factionID] = bounties[i];
				if ns.toon[name].factions[bounties[i].factionID]==nil then
					ns.toon[name].factions[bounties[i].factionID] = {};
				end
				if ns.toon[name].factions[bounties[i].factionID].lastEnding==nil then
					ns.toon[name].factions[bounties[i].factionID].lastEnding=bounties[i].eventEnding;
				end
				CalculateBountySubObjectives(
					ns.data[name].factions[bounties[i].factionID],
					ns.toon[name].factions[bounties[i].factionID]
				);
			end
		end
	end

	wipe(factions);
	local exps = {};
	for i=1, #expansions do
		exps[expansions[i].name] = i;
		exps[expansions[i].zone] = i;
	end
	table.sort(ns.data[name].factions,sortFactions);

	for id, data in pairs(ns.data[name].factions)do
		if (data.extension or data.expansion) and Time < data.eventEnding then
			if data.extension then
				data.expansion = exps[data.extension];
				data.extension = nil;
			elseif type(data.expansion)~="number" then
				data.expansion = exps[data.continent];
			end
			if data.expansion then
				if not factions[data.expansion] then
					factions[data.expansion] = {};
				end
				tinsert(factions[data.expansion],data);
			end
		end
	end

	for e=1, #expansions do
		if factions[e] and expansions[e] and expansions[e].numBounties and #factions[e] < expansions[e].numBounties then
			for i=#factions[e]+1, expansions[e].numBounties do
				tinsert(factions[e],{
					icon = ns.icon_fallback,
					name = UNKNOWN, --.." "..L["EmissaryQuestsMissing"],
					eventEnding = ending[i],
					expansion = e,
					numTotal = 0
				});
			end
		end
	end
	updateBroker();
	C_Timer.After(1,unlock);
end

local function createTooltip(tt)
	local minLevel,Time,level = 999,time(),UnitLevel("player");

	for e=1, #expansions do
		if ns.profile[name][expansions[e].name.."Quests"] and expansions[e].minLevel<minLevel then
			minLevel = expansions[e].minLevel;
		end
	end

	if tt.lines~=nil then tt:Clear(); end
	tt:SetCell(tt:AddLine(),1,C("dkyellow",BOUNTY_BOARD_LOCKED_TITLE),tt:GetHeaderFont(),"LEFT",0);

	tt:AddSeparator(4,0,0,0,0);
	local missing,l=false,tt:AddLine(C("ltblue",FACTION));
	tt:SetCell(l,2,C("ltblue",TIME_REMAINING:gsub(":",""):gsub("：",""):trim()),nil,"RIGHT",0);
	tt:AddSeparator();
	if level>=minLevel then
		local expansion=0;
		for e=1, #expansions do
			table.sort(factions[e],sortFactions);
			for i=1, #factions[e] do
				local v = factions[e][i];
				if ns.profile[name][expansions[v.expansion].name.."Quests"] and v.eventEnding-Time>=0 then
					if expansion~=expansions[v.expansion].index then
						expansion=expansions[v.expansion].index;
						tt:SetCell(tt:AddLine(),1,C("ltgreen",_G["EXPANSION_NAME"..expansions[v.expansion].index]),nil,"LEFT",0);
					end
					local color1,color2 = "ltyellow","white";
					if ns.toon[name].factions[v.factionID] and ns.toon[name].factions[v.factionID].numCompleted==v.numTotal then
						color1,color2 = "gray","gray";
					end
					local l=tt:AddLine("  |T"..v.icon..":14:14:0:0:64:64:4:56:4:56|t "..C(color1,v.factionID and factionName[v.factionID] or v.name or UNKNOWN));
					tt:SetCell(l,2,C(color2,SecondsToTime(v.eventEnding-Time)),nil,"RIGHT",0);
					if not v.factionID then
						missing=true;
					end
				end
			end
		end
	end
	if missing then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("gray",L["World quests status update requires min. level:"]),nil,"LEFT",0);
		for e=1, #expansions do
			if level<expansions[e].minLevel then
				tt:SetCell(tt:AddLine(),1,C("gray",_G["EXPANSION_NAME"..expansions[e].index].." = "..LEVEL.." "..expansions[e].minLevel),nil,"LEFT",0);
			end
		end
	end

	if ns.profile[name].showCharacters then
		tt:AddSeparator(12,0,0,0,0);
		local c,l=ttColumns,tt:AddLine(C("ltblue",CHARACTER));
		for e=#expansions, 1, -1 do
			table.sort(factions[e],sortInvertFactions);
			for i=1, #factions[e] do
				local v = factions[e][i];
				if ns.profile[name][expansions[v.expansion].name.."Quests"] and v.eventEnding-Time>=0 then
					tt:SetCell(l,c,"|T"..v.icon..":24:24:0:0:64:64:4:56:4:56|t",nil,"CENTER");
					c=c-1;
				end
			end
		end

		tt:AddSeparator();
		local chars = 0;
		for i=1, #Broker_Everything_CharacterDB.order do
			local name_realm = Broker_Everything_CharacterDB.order[i];
			local v,cell = Broker_Everything_CharacterDB[name_realm],2;
			local c,realm,_ = strsplit("-",name_realm,2);
			if realm and v.level>=minLevel and v[name] and ns.showThisChar(name,realm,v.faction) then
				local faction = v.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
				if type(realm)=="string" and realm:len()>0 then
					local _,_realm = ns.LRI:GetRealmInfo(realm);
					if _realm then realm = _realm; end
				end
				local c,l=ttColumns,tt:AddLine(C(v.class,ns.scm(c)) .. ns.showRealmName(name,realm) .. faction);
				for e=#expansions, 1, -1 do
					for i=1, #factions[e] do
						local data = factions[e][i];
						if ns.profile[name][expansions[e].name.."Quests"] and data.eventEnding-Time>=0 then
							if v.level>=expansions[e].minLevel then
								local color,text = "gray","?/?";
								if data.factionID and v[name].factions[data.factionID] then
									local toon = v[name].factions[data.factionID];
									if toon.lastEnding==nil then
										toon.lastEnding = 0;
									end
									if data.eventEnding>toon.lastEnding then
										toon.lastEnding = data.eventEnding;
										toon.numCompleted = 0;
									end
									if toon.numCompleted>data.numTotal then
										toon.numCompleted=data.numTotal;
									end
									text = toon.numCompleted.."/"..data.numTotal;
									if toon.numCompleted<data.numTotal then
										color = "white";
									end
								end
								tt:SetCell(l,c,C(color,text),nil,"CENTER");
							end
							c=c-1;
						end
					end
				end
				if name_realm==ns.player.name_realm then
					tt:SetLineColor(l, 1, 1, 1, .4);
				end
				chars = chars+1;
			end
		end
		if chars==0 then
			tt:SetCell(tt:AddLine(), 1, C("gray",L["No chars found for this realm or realm group to display"]), nil, "CENTER", 0);
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
		"PLAYER_LOGIN",
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
		showCharacters = true
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
			showAllFactions=4,
			showRealmNames=5,
			showCharsFrom=6,
		},
		misc = nil,
	}
end

-- function module.init() end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif ns.eventPlayerEnteredWorld then
		if ns.data[name]==nil then
			ns.data[name]={factions={}};
		elseif ns.data[name].factions==nil then
			ns.data[name].factions = {};
		end
		if ns.toon[name]==nil then
			ns.toon[name]={factions={}};
		elseif ns.toon[name].factions==nil then
			ns.toon[name].factions = {};
		end
		updateData();
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
