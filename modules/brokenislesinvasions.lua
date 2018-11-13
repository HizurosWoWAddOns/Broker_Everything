
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Broken Isles Invasions";
local ttName, ttColumns, tt, module = name.."TT", 3;

local nextInvasionStart,lastInvasionStart,currentInvasion,timeStamp
local oldStart, interval, length = 1517644800, 66600, 21600;
if GetCurrentRegionName()=="EU" then
	oldStart = 1517682600;
end
local uiMapIDs = {
	619,
};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\Ability_DemonHunter_FieryBrand", coords={.05,.95,.05,.95}, size={64,64}}; --IconName::Broken Isles Invasions--


-- some local functions --
--------------------------
local function updateInvasionState()
	timeStamp = time();
	lastInvasionStart = mod(timeStamp-oldStart,interval); -- seconds since start of last invasion
	nextInvasionStart = interval-lastInvasionStart;

	if lastInvasionStart <= length and (not WorldMapFrame:IsShown()) and (not currentInvasion) then
		for i=1, #uiMapIDs do
			C_Map.RequestPreloadMap(uiMapIDs[i]);
			local areaPOIs = C_AreaPoiInfo.GetAreaPOIForMap(uiMapIDs[i]);
			if areaPOIs and #areaPOIs>0 then
				for i=1, #areaPOIs do
					local areaPoiID = areaPOIs[i];
					local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(uiMapIDs[i], areaPoiID);
					if poiInfo and poiInfo.atlasName=="legioninvasion-map-icon-portal" then
						currentInvasion = poiInfo.description;
					end
				end
			end
		end
	elseif currentInvasion and lastInvasionStart > length then
		currentInvasion = nil;
	end
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	updateInvasionState();
	if lastInvasionStart < length then
		obj.text = C("green",ACTIVE_PETS) .. " " .. SecondsToTime(length-lastInvasionStart);
		return;
	end
	obj.text = L["InvasionsNextIn"] .. " " ..  SecondsToTime(nextInvasionStart);
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end
	local l = tt:AddHeader(C("dkyellow",L[name]));

	if lastInvasionStart <= length and currentInvasion then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("orange",currentInvasion),nil,"CENTER",0);
		tt:SetCell(tt:AddLine(),1,C("ltgreen",BRAWL_TOOLTIP_ENDS:format(SecondsToTime(length-lastInvasionStart))),nil,"CENTER",0);
	end

	tt:AddSeparator(4,0,0,0,0);
	tt:AddLine(C("ltblue",L["InvasionsNext"]));
	tt:AddSeparator();
	for i=1, 5 do
		local n = (timeStamp-lastInvasionStart)+(interval*i);
		--tt:SetCell(tt:AddLine(),1,date("%Y-%m-%d %H:%M",n),nil,"CENTER",0);
		tt:AddLine(C("ltyellow",date("%Y-%m-%d",n)),C("ltgreen",date("%H:%M",n)));
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
		enabled = false
	},
	clickOptionsRename = {},
	clickOptions = {
		--["menu"] = "OptionMenuCustom"
	}
};

ns.ClickOpts.addDefaults(module,"menu","_RIGHT");

-- function module.options() return {broker = {},tooltip = {}}; end

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
	if event=="BE_UPDATE_CFG" and (...) and (...):find("^ClickOpt") then
		--ns.ClickOpts.update(name);
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


--@do-not-package@
--[[
function scanPOI()
	local poiInfo;
	for i=5000, 5500 do
		poiInfo = C_WorldMap.GetAreaPOIInfo(1007,i,0);
		if poiInfo and poiInfo.name=="Angriff der Legion" then
			ns.debug(poiInfo.name,poiInfo.description,poiInfo.poiID);
		end
	end
end
]]
--@end-do-not-package@
