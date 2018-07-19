
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I

-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Emissary Quests";
local ttName, ttColumns, tt, module = name.."TT", 6
local factions,totalQuests,locked = {},{},false;
local continents = {
	--1007, -- legion
	--1184, -- argus
	619, -- legion (new uiMapID)
	905, -- argus (new uiMapID)
};
local icon2factionID = {
	[1708507] = 2045,
	[1708506] = 2165,
	[1708505] = 2170,
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

local function updateBroker()
	local lst,obj = {},ns.LDB:GetDataObjectByName(module.ldbName);
	if UnitLevel("player")<110 then
		obj.text = ns.profile[name].shortTitle and L["Emissary Quests-ShortCut"] or L[name];
		return
	end

	local Time = time();
	table.sort(factions,sortFactions);
	for _,v in pairs(factions)do
		if v.eventEnding-Time>=0 then
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
	obj.text = table.concat(lst," ");
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
	local Time = ceil(time()/60)*60;
	local endings = {};
	for c=1, #continents do
		local bounties,location,locked = GetQuestBountyInfoForMapID(continents[c]); -- empty table on chars lower than 110
		for i=1, #bounties do
			local TimeLeft = C_TaskQuest.GetQuestTimeLeftMinutes(bounties[i].questID);
			bounties[i].eventEnding = 0;
			if TimeLeft then
				local timeLeftSeconds = TimeLeft*60;
				bounties[i].eventEnding = Time+timeLeftSeconds-1;
				local hours = floor(TimeLeft/60);
				endings[hours] = bounties[i].questID;
				bounties[i].eventEndingHours = hours;
			end
			bounties[i].continent = continents[c];
			if bounties[i].factionID==0 then
				bounties[i].factionID = icon2factionID[bounties[i].icon];
			end
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
	for i,v in pairs(ns.data[name].factions)do
		if not v.eventEndingHours then
			v.eventEndingHours = floor((v.eventEnding-Time)/3600);
		end
		if endings[v.eventEndingHours] and endings[v.eventEndingHours]~=v.questID then
			v.eventEnding=0;
		end
		tinsert(factions,v);
	end

	updateBroker();
	C_Timer.After(1,unlock);
end

local function createTooltip(tt)
	local Time = time();
	table.sort(factions,sortFactions);

	if tt.lines~=nil then tt:Clear(); end
	local l=tt:AddLine();
	tt:SetCell(l,1,C("dkyellow",BOUNTY_BOARD_LOCKED_TITLE),tt:GetHeaderFont(),"LEFT",0);

	tt:AddSeparator(4,0,0,0,0);
	local l=tt:AddLine(C("ltblue",FACTION));
	tt:SetCell(l,2,C("ltblue",TIME_REMAINING:gsub(":",""):gsub("：",""):trim()),nil,"RIGHT",0);
	tt:AddSeparator();
	for _,v in pairs(factions)do
		if v.eventEnding-Time>=0 then
			local color1,color2 = "ltyellow","white";
			if ns.toon[name].factions[v.factionID] and ns.toon[name].factions[v.factionID].numCompleted==v.numTotal then
				color1,color2 = "gray","gray";
			end
			local l=tt:AddLine("|T"..v.icon..":14:14:0:0:64:64:4:56:4:56|t "..C(color1,factionName[v.factionID]));
			tt:SetCell(l,2,C(color2,SecondsToTime(v.eventEnding-Time)),nil,"RIGHT",0);
		end
	end
	if UnitLevel("player")<110 then
		local l=tt:AddLine();
		tt:SetCell(l,1,C("gray",L["World quests status update|nneeds level 110 or higher"]),nil,"CENTER",0);
	end

	tt:AddSeparator(12,0,0,0,0);
	local c,l=2,tt:AddLine(C("ltblue",L["Characters"]));
	for i,v in pairs(factions)do
		if v.eventEnding-Time>=0 then
			tt:SetCell(l,c,"|T"..v.icon..":24:24:0:0:64:64:4:56:4:56|t",nil,"CENTER");
			c=c+1;
		end
	end
	if c<4 then
		for I=1, 3 do
			tt:SetCell(l,c,"|T"..ns.icon_fallback..":24:24:0:0:64:64:4:56:4:56|t",nil,"CENTER");
			c=c+1;
			if c==4 then
				break;
			end
		end
	end

	tt:AddSeparator();

	local chars = 0;
	for i=1, #Broker_Everything_CharacterDB.order do
		local name_realm = Broker_Everything_CharacterDB.order[i];
		local v,cell = Broker_Everything_CharacterDB[name_realm],2;
		local c,realm,_ = strsplit("-",name_realm,2);
		if realm and v.level>=110 and v[name] and ns.showThisChar(name,realm,v.faction) then
			local faction = v.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
			if type(realm)=="string" and realm:len()>0 then
				local _,_realm = ns.LRI:GetRealmInfo(realm);
				if _realm then realm = _realm; end
			end
			local c,l=2,tt:AddLine(C(v.class,ns.scm(c)) .. ns.showRealmName(name,realm) .. faction);
			for _,data in pairs(factions)do
				if data.eventEnding-Time>=0 then
					local toon = v[name].factions[data.factionID] or {};
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
					local color,text = "gray",toon.numCompleted.."/"..data.numTotal;
					if toon.numCompleted<data.numTotal then
						color = "white";
					end
					tt:SetCell(l,c,C(color,text),nil,"CENTER");
					c=c+1;
				end
			end
			if c<4 then
				for I=1, 3 do
					tt:SetCell(l,c,C("gray","?/?"),nil,"CENTER");
					c=c+1;
					if c==4 then
						break;
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
		showCharsFrom="2"
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
			shortTitle={ type="toggle", order=1, name="Show shorter title", desc=L["Display '%s' instead of '%s' on chars under level 110 on broker button"]:format(L["Emissary Quests-ShortCut"],L["Emissary Quests"]) }
		},
		tooltip = {
			showAllFactions=1,
			showRealmNames=2,
			showCharsFrom=3,
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
