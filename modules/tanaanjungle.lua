
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Tanaan Jungle Dailies"; -- L["Tanaan Jungle Dailies"]
local ldbName, ttName, ttName2, ttColumns, ttColumns2, tt, tt2, createMenu = name, name.."TT",name.."TT2", 2, 2;
--local ttName2, ttColumns2, tt2 = name.."TT2", 2;
local try,dailiesReset,weekliesReset,namesCount,namesNeed,completed,numCompleted,names,questlog,numQuestlog = 6,0,0,0,0,{},{},{},{},{};
local dubs,elapse,update,updateTimeout = {},0,false,10;
-- [<questId>] = <number> ( 1=bosses, 2=zone dailies, 3=hidden zone dailies, 4=bonus zone dailies, 5=random dailies, 6=weeklies )
--[=[
what the difference between zone, hidden and bonus dailys?
you get the zone daily from the table in your faction tanaan jungle hub.
if you have the zone daily in your log and fly into the zone you will automatically get the hidden quest.
you can see it through blizzards objective tracker under the minimap. note: the hidden quest contains all subtargets to complete the quest.
the bonus quest you get by fly or walk into zone without a active zone daily in questlog.
--]=]
local ids = ns.player.faction=="Alliance" and {
	[39287]=1,[39288]=1,[39289]=1,[39290]=1, -- bosses
	[38585]=2,[38587]=3,[39453]=4,-- Assault on the Throne of Kil'jaeden
	[38441]=2,[37970]=3,[39445]=4,-- Assault on the Fel Forge
	[37891]=2,[37865]=3,[39451]=4,-- Assault on Ironhold Harbor
	[38250]=2,[37938]=3,[39447]=4,-- Assault on the Ruins of Kra'nak
	[38045]=2,[38043]=3,[39441]=4,-- Bleeding the Bleeding Hollow
	[38046]=2,[38051]=3,[39443]=4,-- Battle at the Iron Front
	[37968]=2,[37966]=3,[39450]=4,-- Assault on the Temple of Sha'naar
	[39433]=5,-- npc 95424
	[39581]=5,[39582]=5,[39586]=5, -- npc 96147
	[39567]=5,[39568]=5,[39570]=5,[39574]=5,[39573]=5,[39571]=5,[39569]=5, -- npc 90974
	[39565]=6 -- npc 92805
} or {
	[39287]=1,[39288]=1,[39289]=1,[39290]=1,-- bosses
	[38586]=2,[38588]=3,[39454]=4,-- Assault on the Throne of Kil'jaeden
	[38440]=2,[38439]=3,[39446]=4,-- Assault on the Fel Forge
	[37940]=2,[37866]=3,[39452]=4,-- Assault on Ironhold Harbor
	[38252]=2,[38009]=3,[39448]=4,-- Assault on the Ruins of Kra'nak
	[38044]=2,[38040]=3,[39442]=4,-- Bleeding the Bleeding Hollow
	[38047]=2,[38054]=3,[39444]=4,-- Battle at the Iron Front
	[38449]=2,[38020]=3,[39449]=4,-- Assault on the Temple of Sha'naar
	[39433]=5,-- npc 95424
	[39519]=5,[39529]=5,[39532]=5,-- npc 93396
	[39511]=5,[39509]=5,[39510]=5,[39512]=5,[39526]=5,[39514]=5,[39513]=5,-- npc 96014
	[39565]=6-- npc 92805
};
local zone2hidden = {
	[38585]=38587,[38441]=37970,[37891]=37865,[38250]=37938,
	[38045]=38043,[38046]=38051,[37968]=37966,[38586]=38588,
	[38440]=38439,[37940]=37866,[38252]=38009,[38044]=38040,
	[38047]=38054,[38449]=38020,
};
local numIDTypes = {
	4, -- bosses
	1, -- random zone daily
	1, -- hidden zone daily
	7, -- bonus dailies
	4, -- random dailies
	1, -- weeklies
};
local colorIDTypes = {
	"ltblue",
	"green",
	"red",
	"yellow",
	"orange",
	"violet",
}
local typeOrder = {1,6,5,2,4};
local npcs = { -- [<npcID>] = <questID>
	[95053]=39287,[95044]=39288,[95056]=39289,[95054]=39290
};
local groupIds = {
	--[39432] = 
};
local titles = { -- {"<title>", <maxQuestCount>}
	{"Rare bosses",4}, -- L["Rare bosses"]
	{"Random zone daily",1}, -- L["Random zone dailies"]
	{"Hidden random zone dailies",3}, -- L["Hidden random zone dailies"]
	{"Daily zone bonus",7}, -- L["Daily zone bonus"]
	{"Reputation dailies",4}, -- L["Reputation dailies"]
	{"Reputation weeklies",1} -- L["Reputation weeklies"]
}



-------------------------------------------
-- register icon names and default files --
-------------------------------------------
--I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\LFG-Eye-Green", coords={0.5 , 0.625 , 0 , 0.25}}
I[name] = {iconfile="interface\\icons\\Achievement_Zone_Tanaanjungle", coords={.15,.55,.15,.55}, size={64,64}};


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show a list of solved/solvable tanaan jungle bosses, dailys, weeklys and bonus zones"],
	--icon_suffix = "",
	events = {
		"PLAYER_ENTERING_WORLD",
		"PLAYER_REGEN_ENABLED",
		"QUEST_LOG_UPDATE"
	},
	updateinterval = 10,
	config_defaults = {
		showQuestIDs = false,
		showChars = true,
		showAllRealms = true,
		showAllFactions = true,
		--showLatest = true,
		--showCategory = true,
		--showWatchlist = true,
		--showProgressBars = true,
		--showCompleted = true
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=true },
		{ type="separator" },
		{ type="toggle", name="showQuestIDs", label=L["Show QuestIDs"],   tooltip=L["Show/Hide QuestIDs in tooltip"] },
		{ type="toggle", name="showChars",    label=L["Show characters"], tooltip=L["Show a list of your characters with count of ready and available targets in tooltip"] },
		{ type="toggle", name="showAllRealms", label=L["Show all realms"], tooltip=L["Show characters from all realms in tooltip."] },
		{ type="toggle", name="showAllFactions", label=L["Show all factions"], tooltip=L["Show characters from all factions in tooltip."] },
	},
	clickOptions = {
		["1_open_questlog"] = {
			cfg_label = "Open questlog", -- L["Open questlog"]
			cfg_desc = "open your bags", -- L["open your questlog"]
			cfg_default = "_LEFT",
			hint = "Open questlog", -- L["Open questlog"]
			func = function(self,button)
			end
		},
		["2_open_menu"] = {
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

local function updateResetTimes()
	if dailiesReset>0 then return end

	dailiesReset = time() + GetQuestResetTime() - 86400;
	local wday,reset = tonumber(date("%w"));
	
	if(wday==0)then
		reset = 4*86400;
	elseif(wday>3)then
		reset = wday*86400;
	elseif(wday<3)then
		reset = (3+wday)*86400;
	end
	weekliesReset = dailiesReset - wday;
end

local function callbackLocaleNames(data)
	if data.type=="quest" or data.type=="unit" then 
		if type(data.lines[1])=="string" and strlen(data.lines[1])>0 then
			if data.type=="unit" then
				names[data.id2] = data.lines[1];
			else
				names[data.id] = data.lines[1];
			end
			namesCount = namesCount + 1;
		end
	end
end

local function updateLocaleNames()
	local failed,tmp,c = false,{},0;
	local locale=GetLocale();

	if Broker_Everything_DataDB.locale~=locale then
		Broker_Everything_DataDB.locale=locale;
		Broker_Everything_DataDB.localeNames={};
	end

	names = Broker_Everything_DataDB.localeNames;

	-- collect locale quest titles
	for id,v in pairs(ids)do
		if v~=1 and v~=3 then
			if names[id]==nil then
				ns.ScanTT.query({type="quest",id=id,level=100,callback=callbackLocaleNames});
			else
				namesCount = namesCount + 1;
			end
			namesNeed = namesNeed + 1;
		end
	end

	-- collect locale npc names
	for nID,qID in pairs(npcs)do
		if names[qID]==nil then
			ns.ScanTT.query({type="unit",id=nID,id2=qID,callback=callbackLocaleNames});
		else
			namesCount = namesCount + 1;
		end
		namesNeed = namesNeed + 1;
	end
end

local function updateQuestStatus()
	local t,c,nC,Q,cQ = time(),{},{},0,0;
	for id,v in pairs(ids)do
		Q=Q+1;
		if c[id]==nil then c[id]=0; end
		if nC[v]==nil then nC[v]=0; end
		local index = GetQuestLogIndexByID(id) or 0;
		if IsQuestFlaggedCompleted(id)==true then
			c[id]=t; nC[v]=nC[v]+1; cQ=cQ+1;
		elseif index>0 then
			questlog[id]=true;
		end
	end
	if cQ<Q then
		completed,numCompleted=c,nC;
		if ns.toon.tanaanjungle==nil then
			ns.toon.tanaanjungle={};
		end
		ns.toon.tanaanjungle.completed = c;
		ns.toon.tanaanjungle.questlog = questlog; --?

		local bbt = {}; -- broker button text
		for _,i in ipairs(typeOrder) do
			tinsert(bbt,C(colorIDTypes[i], numCompleted[i]) .. "/" .. C(colorIDTypes[i], numIDTypes[i]));
		end
		ns.LDB:GetDataObjectByName(ldbName).text = table.concat(bbt,", ");
	else
		C_Timer.After(1, function()
			elapse,update=0,true;
		end);
	end
end

local function listQuests(TT,questlog,completed,numCompleted)
	for _,i in ipairs(typeOrder) do
		local num=0;
		TT:AddSeparator(4,0,0,0,0);

		TT:AddLine(C(colorIDTypes[i],L[titles[i][1]]), C(colorIDTypes[i], numCompleted[i]) .. "/" .. C(colorIDTypes[i], numIDTypes[i]));
		TT:AddSeparator();
		for id,qType in pairs(ids)do
			if qType==i then
				local color,state = false,false;
				if completed[id]~=nil and completed[id]>dailiesReset then
					color,state = "green",L["Completed"];
				elseif questlog[id]==true then
					color,state = "yellow",L["In Questlog"];
					if (i>=2 and i<=4) then
						state = format("%s |cff00ccff(%d%%)|r",state,GetQuestProgressBarPercent(zone2hidden[id] or id));
					end
				elseif qType==1 or qType==4 or qType==6 then
					color,state = "white",AVAILABLE;
					if (i>=2 and i<=4) then
						state = format("%s |cff00ccff(%d%%)|r",state,GetQuestProgressBarPercent(zone2hidden[id] or id));
					end
				end
				if color then
					TT:AddLine((ns.profile[name].showQuestIDs and C("gray",id).." " or "") .. C("ltyellow",names[id]),C(color,state));
					num=num+1;
				end
			end
		end
		if num==0 then
			local l = TT:AddLine();
			TT:SetCell(l,1,C("ltgray",L["No quests completed or in your quest log..."]),nil,nil,ttColumns);
		end
	end
end

local function createTooltip2(self,tt2,Class,Name,Realm,Data)
	if (tt2) and (tt2.key) and (tt2.key~=ttName2) then return end -- don't override other LibQTip tooltips...
	tt2 = ns.acquireTooltip({ttName2, ttColumns2, "LEFT", "RIGHT", "CENTER", "RIGHT", "LEFT"},{true},{self,"horizontal",tt});
	tt2:Clear();
	--[[
	local l = tt:AddHeader();
	tt:SetCell(l,1,C("dkyellow",L[name]) .." ".. C("orange",L["(Experimental)"]),nil,nil,ttColumns);
	--]]
	listQuests(tt2,{},Data.completed,Data.numCompleted);
	ns.roundupTooltip(tt2);
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	tt:Clear();
	local l = tt:AddHeader();
	tt:SetCell(l,1,C("dkyellow",L[name]),nil,nil,ttColumns);

	if(namesCount~=namesNeed)then
		local l=tt:AddLine();
		tt:SetCell(l,1,L["This module is waiting for some localized names."],nil,nil,2);
		tt:AddLine(L["Count of data to collect:"],namesCount.." / "..namesNeed);
		ns.roundupTooltip(tt);
		return;
	end

	updateResetTimes();
	updateQuestStatus();

	if ns.profile[name].showChars then
		tt:AddSeparator(4,0,0,0,0);
		local l=tt:AddLine( C("ltblue", L["Characters"]) ); -- 1
		tt:AddSeparator();
		for i=1, #Broker_Everything_CharacterDB.order do
			local name_realm = Broker_Everything_CharacterDB.order[i];
			local v = Broker_Everything_CharacterDB[name_realm];
			local c,r = strsplit("-",name_realm);
			if (v.level>=100 and v.tanaanjungle) and not ((ns.profile[name].showAllRealms~=true and realm~=ns.realm) or (ns.profile[name].showAllFactions~=true and v.faction~=ns.player.faction)) then
				local bbt = {}; -- broker button text
				for _,i in ipairs(typeOrder) do
					local num = 0;
					if v.tanaanjungle.completed then
						for I,v in pairs(v.tanaanjungle.completed)do
							if ids[I]==numIDTypes[i] and v>dailiesReset then
								num=num+1;
							end
						end
					end
					tinsert(bbt,C(colorIDTypes[i], num) .. "/" .. C(colorIDTypes[i], numIDTypes[i]));
				end
				local l=tt:AddLine(C(v.class,ns.scm(c)),table.concat(bbt,", "));
				if(name_realm==ns.player.name_realm)then
					tt:SetLineColor(l, 0.1, 0.3, 0.6);
				end
			end
		end
	end

	listQuests(tt,questlog,completed,numCompleted);

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(3,0,0,0,0)
		ns.AddSpannedLine(tt,C("copper",L["Hold shift"]).." || "..C("green",L["Show your other chars"]));
		ns.clickOptions.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name;
end

ns.modules[name].onevent = function(self,event,...)
	if event=="PLAYER_ENTERING_WORLD" then
		updateResetTimes();

		if ns.toon==nil then
			ns.toon={};
		end

		ns.toon.tanaanjungle = nil;

		if ns.toon.tanaanjungle==nil then
			ns.toon.tanaanjungle={};
		end

		C_Timer.After(3, updateLocaleNames);
		C_Timer.NewTicker(ns.modules[name].updateinterval,function() update=true; updateQuestStatus() end);
		self:UnregisterEvent(event);
	elseif event=="PLAYER_REGEN_ENABLED" then
		C_Timer.After(3, function()
			elapse,update=0,true;
		end);
	elseif event=="QUEST_LOG_UPDATE" then
		elapse,update=0,true;
	elseif event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	end
end
-- ns.modules[name].onupdate = function(self,elapse) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------

ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "CENTER", "RIGHT", "LEFT"},{false},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end



