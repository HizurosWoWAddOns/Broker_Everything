
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Tanaan Jungle Dailies"; -- L["Tanaan Jungle Dailies"]
local ldbName, ttName, ttColumns, tt, createMenu = name, name.."TT", 2;
--local ttName2, ttColumns2, tt2 = name.."TT2", 2;
local try,dailiesReset,weekliesReset,namesCount,completed,numCompleted,names,questlog,numQuestlog = 6,0,0,0,{},{},{},{},{};
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
	false,
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
	desc = L["Display a list of solved tanaan jungle bosses and dailys."],
	--icon_suffix = "",
	events = {
		"PLAYER_ENTERING_WORLD",
		"PLAYER_REGEN_ENABLED",
		"QUEST_LOG_UPDATE",
	},
	updateinterval = false, -- 10
	config_defaults = {
		showQuestIDs = false,
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
		{ type="toggle", name="showQuestIDs", label=L["Show QuestIDs"], tooltip=L["Show/Hide QuestIDs in tooltip"] }
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
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function updateLocaleNames()
	local failed,tmp,c = false,{},0;
	-- collect locale quest titles
	for id,v in pairs(ids)do
		if v~=1 then
			local data,count = ns.GetLinkData("quest:"..id);
			if count>0 and type(data[1])=="string" and strlen(data[1])>0 then
				tmp[id] = data[1];
				c=c+1;
			else
				failed=true;
			end
		end
	end

	-- collect locale npc names
	for nID,qID in pairs(npcs)do
		local data, count = ns.GetLinkData("unit:Creature-0-0-0-0-"..nID.."-0");
		if count>0 and type(data[1])=="string" and strlen(data[1])>0 then
			tmp[qID] = data[1];
			c=c+1;
		else
			failed=true;
		end
	end

	-- for slow connections
	if failed and try>0 then
		C_Timer.After(2,updateLocaleNames);
		try = try - 1;
		return
	end

	if not failed then
		names = tmp;
		namesCount = c;
		return
	end
end

local function updateQuestStatus()
	local t,c,nC,Q,cQ = time(),{},{},0,0;
	--wipe(completed); wipe(numCompleted);
	for id,v in pairs(ids)do
		Q=Q+1;
		if c[id]==nil then
			c[id]=0;
		end
		if nC[v]==nil then
			nC[v]=0;
		end
		local index = GetQuestLogIndexByID(id) or 0;
		if IsQuestFlaggedCompleted(id) then
			c[id]=t;
			nC[v]=nC[v]+1;
			cQ=cQ+1;
		elseif index>0 then
			questlog[id]=true;
		end
	end
	if cQ<Q then
		completed,numCompleted=c,nC;
		be_character_cache[ns.player.name_realm].tanaanjungle.completed = c;
		be_character_cache[ns.player.name_realm].tanaanjungle.questlog = questlog;

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
	local showIDs = Broker_EverythingDB[name].showQuestIDs;
	for _,i in ipairs(typeOrder) do
		local num=0;
		TT:AddSeparator(4,0,0,0,0);

		TT:AddLine(C(colorIDTypes[i],L[titles[i][1]]), C(colorIDTypes[i], numCompleted[i]) .. "/" .. C(colorIDTypes[i], numIDTypes[i]));
		TT:AddSeparator();
		for id,qType in pairs(ids)do
			if qType==i then
				local color,state = false,false;
				if completed[id]>dailiesReset then
					color,state = "green",L["Completed"];
				elseif questlog[id]==true then
					color,state = "yellow",L["In Questlog"];
				elseif qType==1 or qType==4 or qType==6 then
					color,state = "white",L["Available"];
				end
				if color then
					TT:AddLine((showIDs and C("gray",id).." " or "") .. C("ltyellow",names[id]),C(color,state));
					num=num+1;
				end
			end
		end
		if num==0 then
			local l = TT:AddLine();
			TT:SetCell(l,1,C("ltgray",L["No quests completed or in your quest log..."]),nil,nil,TTColumns);
		end
	end
end

--[[
local function getTooltip2(Class,Name,Realm,Data)
	if (tt2) and (tt2.key) and (tt2.key~=ttName2) then return end -- don't override other LibQTip tooltips...
	tt:Clear();
	local l = tt:AddHeader();
	tt:SetCell(l,1,C("dkyellow",L[name]) .." ".. C("orange",L["(Experimental)"]),nil,nil,ttColumns);

	if(namesCount==0)then
		tt:AddLine(L["Oops, i try to collect localized names.|nPlease try again later... :)"]);
		return;
	end

	listQuests(tt2,{},Data.completed,Data.numCompleted);
end
--]]

local function getTooltip()
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	tt:Clear();
	local l = tt:AddHeader();
	tt:SetCell(l,1,C("dkyellow",L[name]) .." ".. C("orange",L["(Experimental)"]),nil,nil,ttColumns);

	if(namesCount==0)then
		tt:AddLine(L["Oops, i try to collect localized names.|nPlease try again later... :)"]);
		return;
	end

	if IsShiftKeyDown() then
		tt:AddSeparator(4,0,0,0,0);
		for i=1, #be_character_cache.order do
			local v = be_character_cache[be_character_cache.order[i]];
			local c,r = strsplit("-",be_character_cache.order[i]);
			if v.level>=100 and v.tanaanjungle then
				local bbt = {}; -- broker button text
				for _,i in ipairs(typeOrder) do
					tinsert(bbt,C(colorIDTypes[i], numCompleted[i]) .. "/" .. C(colorIDTypes[i], numIDTypes[i]));
				end
				local l=tt:AddLine(C(v.class,ns.scm(c)),table.concat(bbt,", "));
				--[[
				tt:SetLineScript(l,"OnEnter",function(self)
					tt2 = ns.LQT:Acquire(ttName2, ttColumns2, "LEFT", "RIGHT", "CENTER", "RIGHT", "LEFT");
					getTooltip2(v.class,c,r,v.tanaanjungle);
					ns.createTooltip(self,tt2)
				end);
				tt:SetLineScript(l,"OnLeave",function(self)
					if(tt2)then ns.hideTooltip(tt2,ttName2,true,true); end
				end);
				--]]
			end
		end
	else
		updateQuestStatus();
		listQuests(tt,questlog,completed,numCompleted);
	end

	if Broker_EverythingDB.showHints then
		tt:AddSeparator(3,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
		local l=tt:AddLine();
		tt:SetCell(l,1,C("copper",L["Hold shift"]).." || "..C("green",L["Show your other chars"]));
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name;
end

ns.modules[name].onevent = function(self,event,...)
	if event=="PLAYER_ENTERING_WORLD" then
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

		if be_character_cache[ns.player.name_realm]==nil then
			be_character_cache[ns.player.name_realm]={};
		end

		be_character_cache[ns.player.name_realm].tanaanjungle = nil;

		if be_character_cache[ns.player.name_realm].tanaanjungle==nil then
			be_character_cache[ns.player.name_realm].tanaanjungle={};
		end

		C_Timer.After(12, updateLocaleNames);
	elseif event=="PLAYER_REGEN_ENABLED" then
		C_Timer.After(15, function()
			elapse,update=0,true;
		end);
	elseif event=="QUEST_LOG_UPDATE" then
		elapse,update=0,true;
	end
end

ns.modules[name].onupdate = function(self,elapsed)
	if update then
		elapse = elapse + elapsed;
		if elapse>=updateTimeout then
			update=false;
			updateQuestStatus();
		end
	end
end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------

ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT", "CENTER", "RIGHT", "LEFT");
	getTooltip(self,tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if(tt)then
		ns.hideTooltip(tt,ttName,false,true);
	end
end








--[=[

1. könnte das modul zum allgemeinen quest tracker umwandeln.
	1.1. wenn ja, könnte man neben vordefinierten quests auch selber welche eintragen.

2. täglich gemachten quests der charaktere speichern und auf den andern chars als verfügbar anzeigen wo es random quests gibt.

3. einen zweiten tooltip anzeigen, mit welchen chars man den schon gemacht hat.

4. einen indikator für das vorhandensein eines zweiten tooltips... arrow? oder ein schräges i

--]=]





-- hide
	--/run local x;print("faction dailies");for k,v in pairs({Kiljaedens_Thron={38585,38586},Daemonenschmiede={38441,38440},Eisenfausthafen={37891,37940},Ruinen_von_Kranak={38250,38252},Das_Blutende_Auge={38045,38044},Eisernen_Front={38046,38047},Temple_von_Shanar={37968,38449}}) do x=nil for i,id in ipairs(v)do if IsQuestFlaggedCompleted(id) then x=1 end end print(format("%s: \124cFF%s00\124|r", k, x and "FF00Completed" or "00FFNot completed yet")) end

	--/run local x;print("hidden quests");for k,v in pairs({Kiljaedens_Thron={38587,38588},Daemonenschmiede={37970,38439},Eisenfausthafen={37865,37866},Ruinen_von_Kranak={37938,38009},Das_Blutende_Auge={38043,38040},Eisernen_Front={38051,38054},Temple_von_Shanar={37966,38020}}) do x=nil for i,id in ipairs(v)do if IsQuestFlaggedCompleted(id) then x=1 end end print(format("%s: \124cFF%s00\124|r", k, x and "FF00Completed" or "00FFNot completed yet")) end

	--/run local x;print("bonus dailies");for k,v in pairs({Kiljaedens_Thron={39453,39454},Daemonenschmiede={39445,39446},Eisenfausthafen={39451,39452},Ruinen_von_Kranak={39447,39448},Das_Blutende_Auge={39441,39442},Eisernen_Front={39443,39444},Temple_von_Shanar={39450,39449}}) do x=nil for i,id in ipairs(v)do if IsQuestFlaggedCompleted(id) then x=1 end end print(format("%s: \124cFF%s00\124|r", k, x and "FF00Completed" or "00FFNot completed yet")) end

	--[[
	-- Assault in the Throne of Kil'jaeden
	38585,38586 -- faction dailies
	38587,38588 -- hidden quests
	39453,39454 -- bonus dailies

	-- Assault on the Fel Forge
	38441,38440 -- faction dailies
	37970,38439 -- hidden quests
	39445,39446 -- bonus dailies

	-- Assault on Ironhold Harbor
	37891,37940 -- faction dailies
	37865,37866 -- hidden quests
	39451,39452 -- bonus dailies

	-- Assault on the Ruins of Kra'nak
	38250,38252 -- faction dailies
	37938,38009 -- hidden quests
	39447,39448 -- bonus dailies

	-- Bleeding the Bleeding Hollow
	38045,38044 -- faction dailies
	38043,38040 -- hidden quests
	39441,39442 -- bonus dailies

	-- Battle at the Iron Front
	38046,38047 -- faction dailies
	38051,38054 -- hidden quests
	39443,39444 -- bonus dailies

	-- Assault on the Temple of Sha'naar
	37968,38449 -- faction dailies
	37966,38020 -- hidden quests
	39450,39449 -- bonus dailies

	/run local x;
	for k,v in pairs({
	Kiljaedens_Thron={38585,39453,39454,38586},
	Daemonenschmiede={39445,39446,38440,38441},
	Eisenfausthafen={39451,39452,37891,37940},
	Ruinen_von_Kranak={39447,39448,38250,38252},
	Das_Blutende_Auge={39441,38044,38045,39442},
	Eisernen_Front={39443,39444,38046,38047},
	Temple_von_Shanar={37968,37966,38020,39449,39450,38449}
	}) do
	x=false for i,id in ipairs(v)do if IsQuestFlaggedCompleted(id) then x=true end end print(format("%s: %s", k, x and "\124cFFFF0000Completed\124r" or "\124cFF00FF00Not completed yet\124r"))
	end
	]]

	--[[
	/run for k,v in pairs({Daemonenschmiede=38440,Eisenfausthafen=37891,Ruinen_von_Kranak=38250,Temple_von_Shanar=37968,Kiljaedens_Thron=38585,Schlacht_an_der_Eisernen_Front=38046,Lasst_das_Blutende_Auge_bluten=38045}) do print(format("%s: %s", k, IsQuestFlaggedCompleted(v) and "\124cFFFF0000Completed\124r" or "\124cFF00FF00Not completed yet\124r")) end
	--]]

	--[[
	Kiljaedens_Thron={38585,38587,38588,39453,39454,38586},
	Daemonenschmiede={37970,38439,39445,39446,38440,38441},
	Eisenfausthafen={37865,37866,39451,39452,37891,37940},
	Ruinen_von_Kranak={37938,38009,39447,39448,38250,38252},
	Das_Blutende_Auge={39441,38043,38044,38045,38040,39442},
	Eisernen_Front={38051,38054,39443,39444,38046,38047},
	Temple_von_Shanar={37968,37966,38020,39449,39450,38449
	format("%s: %s", k, x and "\124cFFFF0000Completed\124r" or "\124cFF00FF00Not completed yet\124r"))
	--]]
