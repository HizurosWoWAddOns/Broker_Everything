
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<7 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Invasions"; -- L["ModDesc-Invasions"]
local ttName, ttColumns, tt, module = name.."TT", 3;
local regionLabel,region,timeStamp = {L["North america / Brazil / Oceania"],L["Korea"],L["Europe / Russia"],L["Taiwan"],L["China"]};
local events = {--- 1491375600000
	{ enabled=true, icon=nil, label=SPLASH_LEGION_PREPATCH_FEATURE1_TITLE.." ("..EXPANSION_NAME6..")", start1=1491337800, start3=1491375600, interval=66600, length=21600, achievement=11544, zoneOrder={641,634,630,650,634,650,641,630,634,641,650,630} },
	{ enabled=true, icon=nil, label=SPLASH_BATTLEFORAZEROTH_8_1_FEATURE2_TITLE.." ("..EXPANSION_NAME7..")", start1=1544612400, start3=1544580000, interval=68400, length=25200, achievement=13283, zoneOrder={942,864,896,862,895,863} },
}

do
	region = ns.LRI:GetCurrentRegion();
	if region then
		region = ({NA=1,US=1,KO=2,EU=3,TW=4,CN=5})[region];
	end
	if not region then
		region = GetCurrentRegion() or 1;
	end
end


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\Garrison_Building_SparringArena", coords={.05,.95,.05,.95}, size={64,64}}; --IconName::Invasions--


-- some local functions --
--------------------------
local function updateInvasionsList(noTimer)
	local currentTime,nextUpdate,ev,timerRegion = time(),1800;
	for i=1, #events do
		ev = events[i];
		if not ev.start then
			timerRegion = ns.profile[name].timerRegion;
			if timerRegion==0 then
				timerRegion = (ev["start"..region] and region) or 1;
			end
			ev.start = ev["start"..timerRegion];
		end
		ev.numStarts = floor( (currentTime-ev.start) / ev.interval );
		ev.lastStart = ev.start + (ev.numStarts*ev.interval);
		ev.lastStartEnds = ev.lastStart + ev.length;
		ev.lastStartZone = (ev.numStarts % #ev.zoneOrder) + 1;
		if not ev.zoneNames then
			ev.zoneNames={};
			for z=1, #ev.zoneOrder do
				local mapInfo = C_Map.GetMapInfo(ev.zoneOrder[z]) or {};
				if mapInfo and mapInfo.name then
					ev.zoneNames[z] = mapInfo.name;
				end
			end
		end
		if ev.lastStartEnds >= currentTime then
			nextUpdate = min(nextUpdate,ev.lastStartEnds-currentTime+1);
		else
			nextUpdate = min(nextUpdate,(ev.lastStart+ev.interval)-currentTime+1);
		end
	end
	if noTimer~=true then
		C_Timer.After(nextUpdate,updateInvasionsList);
	end
end

local function updateBroker()
	local t,nextUpdate,inv,ev,seconds=time(),300,{};
	for i=1, #events do
		ev = events[i];
		if ns.profile[name]["event"..i.."bb"] then
			if ev.lastStartEnds >= t then
				seconds = ev.lastStartEnds-t;
				tinsert(inv,C("green",ev.zoneNames[ev.lastStartZone]) .. " " .. SecondsToTime(seconds));
			else
				seconds = (ev.lastStart+ev.interval) - t;
				tinsert(inv,L["InvasionsNextIn"] .. " " ..  SecondsToTime(seconds));
			end
			if seconds<=60 then
				nextUpdate = 1;
			elseif seconds<=600 then
				nextUpdate = min(nextUpdate,60);
			end
		end
	end
	(ns.LDB:GetDataObjectByName(module.ldbName) or {}).text = table.concat(inv,", ");
	C_Timer.After(nextUpdate,updateBroker);
end

local function AddLine(tt,currentTime,timeStart,eventLength,zoneStr,timeStrType,timeColor,zoneColor)
	local timeStr
	if IsShiftKeyDown() or timeStrType==2 then
		timeStr = date("%Y-%m-%d %H:%M",timeStart).." - "..date("%H:%M",timeStart+eventLength);
	elseif timeStrType==1 then
		timeStr = BRAWL_TOOLTIP_ENDS:format(SecondsToTime(timeStart+eventLength-currentTime));
	else
		timeStr = L["InvasionsNextIn"] .. " " ..  SecondsToTime(timeStart-currentTime);
	end
	tt:AddLine(C(timeColor,timeStr),"   ",C(zoneColor,zoneStr));
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end
	local l = tt:AddHeader(C("dkyellow",L[name]));
	local empty = true;

	local currentTime,ev = time();
	for i=1, #events do
		ev = events[i];
		if ns.profile[name]["event"..i.."tt"] then
			local numNext,numZones = ns.profile[name].numNext+1,#ev.zoneNames;
			tt:AddSeparator(4,0,0,0,0);
			tt:SetCell(tt:AddLine(),1,C("ltblue",ev.label),nil,"LEFT",0);
			tt:AddSeparator();
			local nx,timeStart,timeColor,zoneColor,zoneStr,timeStrType = 2,ev.lastStart,"dkgreen","ltgreen",ev.zoneNames[ev.lastStartZone],1;
			if ev.lastStartEnds < currentTime then
				local zoneIndex = (ev.lastStartZone+1) % numZones;
				if zoneIndex==0 then
					zoneIndex = numZones;
				elseif zoneIndex>numZones then
					zoneIndex = 1;
				end
				nx,numNext,timeStart,timeColor,zoneColor,zoneStr,timeStrType = 3,numNext+1,timeStart+ev.interval,"dkyellow","ltyellow",ev.zoneNames[zoneIndex],0;
			end
			AddLine(tt,currentTime,timeStart,ev.length,zoneStr,timeStrType,timeColor,zoneColor);
			for n=nx, numNext do
				local zoneIndex = (ev.numStarts+n) % numZones;
				if zoneIndex==0 then
					zoneIndex = numZones;
				elseif zoneIndex>numZones then
					zoneIndex = 1;
				end
				AddLine(tt,currentTime,ev.lastStart + (n*ev.interval),ev.length,ev.zoneNames[zoneIndex],2,"gray","ltgray");
			end
			empty = false;
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0)
		tt:SetCell(tt:AddLine(),1,C("ltblue",L["Hold shift"]).." || "..C("green",L["Date instead of duration time"]),nil,"LEFT",0);
		ns.ClickOpts.ttAddHints(tt,name);
	end

	ns.roundupTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
	},
	config_defaults = {
		enabled = false,
		event1bb = true, event1tt = true,
		event2bb = true, event2tt = true,
		timerRegion = 0, -- 0 = automatically
		numNext = 3,
	},
	clickOptionsRename = {},
	clickOptions = {
		--["menu"] = "OptionMenuCustom"
	}
};

ns.ClickOpts.addDefaults(module,"menu","_RIGHT");

function module.options()
	local tbl = {
		broker={},
		tooltip={
			numNext = { type="range", order=-1, name=L["InvasionsNumNext"], --[[desc=L["InvasionsNumNextDesc"],]] min=1, step=1, max=20, width="full" },
		},
		misc={
			timerRegion = { type="select", order=2, name=L["InvasionsTimerRegion"], --[[desc=L["InvasionsTimerRegionDesc"],]] values={}, width="full" },
		}
	};
	if region then
		tbl.misc.timerRegion.values[0] = L["InvasionsTimerRegionAuto"]:format(L["RegionLabel"..region]);
	else
		tbl.misc.timerRegion.values[0] = L["InvasionsTimerRegionAuto"]:format(L["RegionLabel1"]);
		region = 1;
	end
	for i=1, 5 do
		tbl.misc.timerRegion.values[i] = L["RegionLabel"..i];
	end
	for i=1, #events do
		tbl.broker["event"..i.."bb"] = { type="toggle", order=i, name=events[i].label, desc=L["InvasionsBBDesc"] };
		tbl.tooltip["event"..i.."tt"] = { type="toggle", order=i, name=events[i].label, desc=L["InvasionsTTDesc"] };
	end
	return tbl;
end

function module.OptionMenu(self,button,modName)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:AddConfig(name);
	ns.EasyMenu:AddEntry({separator=true});
	ns.EasyMenu:AddEntry({ label = C("yellow",L["Reset session earn/loss counter"]), func=resetSessionCounter, keepShown=false });
	ns.EasyMenu:ShowMenu(self);
end

-- function module.init() end

function module.onevent(self,event,...)
	if event=="BE_UPDATE_CFG" then
		--if (...) and (...):find("^ClickOpt") then
		--	ns.ClickOpts.update(name);
		--end
		if ns.eventPlayerEnteredWorld then
			for i=1, #events do
				events[i].start=nil;
			end
			updateInvasionsList(true);
			updateBroker();
		end
	elseif event=="PLAYER_LOGIN" then
--@do-not-package@
		ns.profileSilenceFIXME=true;
--@end-do-not-package@
		if ns.profile[name].exp6tt then
			for new,old in pairs({event1bb="exp6bb",event2bb="exp7bb",event1tt="exp6tt",event2tt="exp7tt"})do
				ns.profile[name][new] = ns.profile[name][old];
				ns.profile[name][old] = nil;
			end
		end
		updateInvasionsList();
		C_Timer.After(2,updateBroker);
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "RIGHT", "LEFT"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
