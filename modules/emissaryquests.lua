
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Emissary Quests";
local ttName, ttColumns, tt, createMenu = name.."TT", 4
local factions,totalQuests,locked = {},{},false;
local continents = {
	1007 -- legion
};
local factionName = setmetatable({},{__index=function(t,k)
	local v = GetFactionInfoByID(k);
	if v then
		rawset(t,k,v);
	end
	return v or k;
end});
L[name] = BOUNTY_BOARD_LOCKED_TITLE;
if L["Emissary Quests-ShortCut"]=="Emissary Quests-ShortCut" then
	L["Emissary Quests-ShortCut"] = "EQ";
end

-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\QuestFrame\\UI-QuestLog-BookIcon",coords={0.05,0.95,0.05,0.95}}; --IconName::Emissary Quests--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show world quests"],
	--icon_suffix = "_Neutral",
	events = {
		"PLAYER_ENTERING_WORLD",
		"QUEST_LOG_UPDATE"
	},
	updateinterval = nil,
	config_defaults = {
		shortTitle = false,
		showAllFactions=true,
		showRealmNames=true,
		showCharsFrom=4
	},
	config_allowed = nil,
	config_header = nil,
	config_broker = {
		{ type="toggle", name="shortTitle", label="Show shorter title", tooltip=L["Display '%s' instead of '%s' on chars under level 110 on broker button"]:format(L["Emissary Quests-ShortCut"],L["Emissary Quests"]), event=true }
	},
	config_tooltip = {
		"showAllFactions",
		"showRealmNames",
		"showCharsFrom"
	},
	config_misc = nil,
	clickOptions = {
		["9_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self);
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function sortFactions(a,b)
	return a.eventEnding<b.eventEnding;
end

local function updateBroker()
	local lst,obj = {},ns.LDB:GetDataObjectByName(ns.modules[name].ldbName);
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
	for c=1, #continents do
		local bounties,location,locked = GetQuestBountyInfoForMapID(continents[c]); -- empty table on chars lower than 110
		for i=1, #bounties do
			local TimeLeft = C_TaskQuest.GetQuestTimeLeftMinutes(bounties[i].questID);
			bounties[i].eventEnding = 0;
			if TimeLeft then
				local timeLeftSeconds = C_TaskQuest.GetQuestTimeLeftMinutes(bounties[i].questID)*60;
				bounties[i].eventEnding = Time+timeLeftSeconds-1;
			end
			bounties[i].continent = continents[c];
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

	wipe(factions);
	for i,v in pairs(ns.data[name].factions)do
		tinsert(factions,v);
	end

	updateBroker();
	C_Timer.After(1,unlock);
end


local function createTooltip(tt)
	local sAR,sAF = ns.profile[name].showAllRealms==true,ns.profile[name].showAllFactions==true;
	local Time = time();
	table.sort(factions,sortFactions);

	if tt.lines~=nil then tt:Clear(); end
	local l=tt:AddLine();
	tt:SetCell(l,1,C("dkyellow",BOUNTY_BOARD_LOCKED_TITLE),tt:GetHeaderFont(),"LEFT",0);

	tt:AddSeparator(4,0,0,0,0);
	local l=tt:AddLine(C("ltblue",FACTION));
	tt:SetCell(l,2,C("ltblue",TIME_REMAINING:gsub(":",""):gsub("：",""):trim()),nil,"RIGHT",3);
	tt:AddSeparator();
	for _,v in pairs(factions)do
		if v.eventEnding-Time>=0 then
			local color1,color2 = "ltyellow","white";
			if ns.toon[name].factions[v.factionID] and ns.toon[name].factions[v.factionID].numCompleted==v.numTotal then
				color1,color2 = "gray","gray";
			end
			local l=tt:AddLine("|T"..v.icon..":14:14:0:0:64:64:4:56:4:56|t "..C(color1,factionName[v.factionID]));
			tt:SetCell(l,2,C(color2,SecondsToTime(v.eventEnding-Time)),nil,"RIGHT",3);
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

	for i=1, #Broker_Everything_CharacterDB.order do
		local name_realm = Broker_Everything_CharacterDB.order[i];
		local v,cell = Broker_Everything_CharacterDB[name_realm],2;
		local c,realm,_ = strsplit("-",name_realm);
		if v.level>=110 and v[name] and ns.showThisChar(name,realm,v.faction) then
			local faction = v.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
			if type(realm)=="string" and realm:len()>0 then
				_,realm = ns.LRI:GetRealmInfo(realm);
			end
			realm = sAR==true and C("dkyellow"," - "..ns.scm(realm)) or "";
			local c,l=2,tt:AddLine(C(v.class,ns.scm(c)) .. realm .. faction);
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
		end
	end

	if ns.profile.GeneralOptions.showHints and false then
		tt:AddSeparator(4,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules[name].init = function() end

ns.modules[name].onevent = function(self,event,...)
	if event=="PLAYER_ENTERING_WORLD" then
		if ns.data[name]==nil then ns.data[name]={}; end
		if ns.toon[name]==nil then ns.toon[name]={}; end
		if ns.data[name].factions==nil then ns.data[name].factions = {}; end
		if ns.toon[name].factions==nil then ns.toon[name].factions = {}; end
		self.PEW=true;
		self:UnregisterEvent(event);
	elseif event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	elseif self.PEW then
		updateData();
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
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "CENTER","CENTER","CENTER","CENTER","CENTER","CENTER"},{true},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end
