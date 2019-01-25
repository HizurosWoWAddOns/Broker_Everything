
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Invasions"; -- L["ModDesc-Invasions"]
local ttName, ttColumns, tt, module = name.."TT", 3;

local eu,timeStamp = GetCurrentRegionName()=="EU";
local regions = {
	{ exp=6, map=619,       start=eu and 1517682600 or 1517644800, int=66600, len=21600, atlas="legioninvasion-map-icon-portal",                       maps={630,641,650,634,680},     achievement=11544 },
	{ exp=7, map={876,875}, start=eu and 1544716800 or 1544785200, int=68400, len=25200, atlas={"HordeWarfrontMapBanner","AllianceWarfrontMapBanner"}, maps={895,896,942,862,863,864}, achievement=13283, poi={5964,5973,5896,5970,5969,5966} },
};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\Garrison_Building_SparringArena", coords={.05,.95,.05,.95}, size={64,64}}; --IconName::Invasions--


-- some local functions --
--------------------------
local function updateInvasionState()
	--if WorldMapFrame:IsShown() then return end
	timeStamp = time();
	for i=1, #regions do
		if ns.data[name] and ns.data[name]["exp"..regions[i].exp.."start"] then
			regions[i].start = ns.data[name]["exp"..regions[i].exp.."start"];
		end
		regions[i].last = mod(timeStamp-regions[i].start,regions[i].int); -- seconds since start of last invasion
		regions[i].lastX = timeStamp-regions[i].last;
		regions[i].next = regions[i].int-regions[i].last;
		regions[i].mapNames = {};
		for I=1, #regions[i].maps do
			local m = C_Map.GetMapInfo(regions[i].maps[I]);
			if m then
				tinsert(regions[i].mapNames,"("..m.name..")");
			end
		end
		if not eu and regions[i].poi then
			local seconds;
			for p=1, #regions[i].poi do
				local sec = C_AreaPoiInfo.GetAreaPOISecondsLeft(regions[i].poi[p]);
				if sec and sec>0 and sec<=regions[i].len  then
					seconds = sec;
					break;
				end
			end
			if seconds then
				local start = timeStamp - seconds;
				if start ~= regions[i].start then
					if ns.data[name]==nil then
						ns.data[name] = {};
					end
					ns.data[name]["exp"..regions[i].exp.."start"] = start;

				end
			end
		end
		if regions[i].last <= regions[i].len and (not regions[i].desc) then
			local map,areaPOIs,atlas = regions[i].map,{};
			if type(map)=="table" then
				for m=1, #map do
					C_Map.RequestPreloadMap(map[m]);
					areaPOIs = C_AreaPoiInfo.GetAreaPOIForMap(map[m]) or {};
					if #areaPOIs>0 then
						map = map[m];
						atlas = regions[i].atlas[m]
						break;
					end
				end
			else
				C_Map.RequestPreloadMap(regions[i].map);
				areaPOIs = C_AreaPoiInfo.GetAreaPOIForMap(regions[i].map) or {};
				atlas = regions[i].atlas;
			end
			for aI=1, #areaPOIs do
				local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(map, areaPOIs[aI]);
				if poiInfo then
					if atlas==poiInfo.atlasName then
						regions[i].desc = poiInfo.description;
						for I=1, #regions[i].mapNames do
							local m = poiInfo.description:match(regions[i].mapNames[I]);
							if m then
								regions[i].mapName = m;
								break;
							end
						end
					end
				end
			end
		elseif regions[i].desc and regions[i].last > regions[i].len then
			regions[i].desc = nil;
		end
	end
end

local function updateBroker()
	updateInvasionState();
	local inv = {};
	for i=1, #regions do
		if ns.profile[name]["exp"..regions[i].exp.."bb"] then
			if regions[i].last < regions[i].len then
				tinsert(inv,C("green",regions[i].mapName or ACTIVE_PETS) .. " " .. SecondsToTime(regions[i].len-regions[i].last));
			else
				tinsert(inv,L["InvasionsNextIn"] .. " " ..  SecondsToTime(regions[i].next));
			end
		end
	end
	(ns.LDB:GetDataObjectByName(module.ldbName) or {}).text = table.concat(inv,", ");
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end
	local l = tt:AddHeader(C("dkyellow",L[name]));
	tt:AddSeparator();
	local empty = true;

	for i=1, #regions do
		if ns.profile[name]["exp"..regions[i].exp.."tt"] then
			tt:AddLine(C("gray",_G["EXPANSION_NAME"..regions[i].exp]));
			if regions[i].last <= regions[i].len and regions[i].desc then
				tt:SetCell(tt:AddLine(),1,"   "..C("orange",regions[i].desc),nil,"LEFT",0);
				tt:SetCell(tt:AddLine(),1,"   "..C("ltgreen",BRAWL_TOOLTIP_ENDS:format(SecondsToTime(regions[i].len-regions[i].last))),nil,"LEFT",0);
			else
				tt:SetCell(tt:AddLine(),1,C("ltgray","   "..L["InvasionsNextIn"] .. " " ..  SecondsToTime(regions[i].next)),nil,"LEFT",0);
			end
			empty = false;
		end
	end

	tt:AddSeparator(4,0,0,0,0);
	tt:AddLine(C("ltblue",L["InvasionsNext"]));
	tt:AddSeparator();
	for i=1, #regions do
		if ns.profile[name]["exp"..regions[i].exp.."tt"] then
			tt:AddLine(C("gray",_G["EXPANSION_NAME"..regions[i].exp]));
			for I=1, 5 do
				local n = (timeStamp-regions[i].last)+(regions[i].int*I);
				tt:AddLine("   "..C("ltyellow",date("%Y-%m-%d",n)),C("ltgreen",date("%H:%M",n)));
			end
			empty = false;
		end
	end

	--if ns.profile.GeneralOptions.showHints then
		--tt:AddSeparator(4,0,0,0,0)
		--ns.ClickOpts.ttAddHints(tt,name);
	--end

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
		exp6bb = true,
		exp7bb = true,
		exp6tt = true,
		exp7tt = true,
	},
	clickOptionsRename = {},
	clickOptions = {
		--["menu"] = "OptionMenuCustom"
	}
};

ns.ClickOpts.addDefaults(module,"menu","_RIGHT");

function module.options()
	return {
		broker = {
			exp6bb = { type="toggle", order=1, name=_G["EXPANSION_NAME6"], desc=L["InvasionsBBDesc"] },
			exp7bb = { type="toggle", order=2, name=_G["EXPANSION_NAME7"], desc=L["InvasionsBBDesc"] },
		},
		tooltip = {
			exp6tt = { type="toggle", order=1, name=_G["EXPANSION_NAME6"], desc=L["InvasionsTTDesc"] },
			exp7tt = { type="toggle", order=2, name=_G["EXPANSION_NAME7"], desc=L["InvasionsTTDesc"] },
		}
	};
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
		updateBroker();
	elseif event=="PLAYER_LOGIN" then
		C_Timer.NewTicker(30,updateBroker);
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "RIGHT", "LEFT"},{false},{self},{OnHide=tooltipOnHide});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
