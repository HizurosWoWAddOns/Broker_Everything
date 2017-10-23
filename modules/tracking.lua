
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Tracking" -- TRACKING
local menuOpened,tt,module = false;


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\minimap\\tracking\\none"}; --IconName::Tracking--


-- some local functions --
--------------------------
local function updateTracking()
	local tActive = 0
	local n = {}

	for i = 1, GetNumTrackingTypes() do
		local name, tex, active, category = GetTrackingInfo(i)
		if (active) then
			tActive = tActive + 1
			n[tActive] = {["Name"] = name, ["Texture"] = tex}
		end
	end

	return tActive, n
end

local function menuClosed()
	menuOpened=true;
end

local function updateBroker()
	-- broker button text
	local numActive, trackActive = updateTracking()
	local n = TRACKING;
	local dataobj = ns.LDB:GetDataObjectByName(module.ldbName)
	if ns.profile[name].displaySelection then
		if numActive == 0 then
			n = "None";
		else
			for i = 1, numActive, 1 do
				n = trackActive[i]["Name"];
			end
		end
	end
	dataobj.text = n;
end

-- module variables for registration --
---------------------------------------
module = {
	events = {
		"MINIMAP_UPDATE_TRACKING",
		"PLAYER_LOGIN"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		displaySelection = true,
		hideMinimapButton = false
	},
}

function module.options()
	return {
		broker = {
			displaySelection={ type="toggle", name=L["Display selection"], desc=L["Display one of the selected tracking options in broker text."] },
		},
		tooltip = nil,
		misc = {
			hideMinimapButton={ type="toggle", order=1, name=L["Hide minimap button"], desc=L["Hide blizzard's tracking button on minimap"], disabled=ns.coexist.check },
			hideMinimapButtonInfo={ type="description", order=2, name=ns.coexist.optionInfo, fontSize="medium", hidden=ns.coexist.check }
		}
	}
end

function module.init()
	if ns.coexist.check() and ns.profile[name].hideMinimapButton then
		ns.hideFrame("MiniMapTracking");
	end
end

function module.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		if ns.coexist.check() then
			if ns.profile[name].hideMinimapButton then
				ns.hideFrame("MiniMapTracking");
			else
				ns.unhideFrame("MiniMapTracking");
			end
		end
	elseif event=="MINIMAP_UPDATE_TRACKING" and menuOpened and LibDropDownMenu_List1:IsShown() then
		ns.EasyMenu.Refresh(1);
	end

	updateBroker();
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end

function module.ontooltip(tooltip)
	tt=tooltip;
	if (ns.tooltipChkOnShowModifier(false)) then tt:Hide(); return; end

	local numActive, trackActive = updateTracking()
	ns.tooltipScaling(tt)
	tt:AddLine(TRACKING)
	tt:AddLine(" ")

	if numActive == 0 then
		tt:AddLine(C("white",L["No tracking option active."]))
	else
		for i = 1, numActive do
			tt:AddDoubleLine("|T"..trackActive[i]["Texture"]..":16:16:0:0:64:64:4:60:4:60|t "..C("white",trackActive[i]["Name"]))
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddLine(" ")
		tt:AddLine(C("copper",L["MouseBtn"]).." || "..C("green",L["Open tracking menu"]))
	end
end

-- function module.onenter(self) end
-- function module.onleave(self) end

function module.onclick(self,button)
	if tt then tt:Hide(); end
	local Name, texture, active, category, nested, Type = 1,2,3,4,5,6;
	local list,count = {},GetNumTrackingTypes();
	local _, class = UnitClass("player");

	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addEntries({label=L["Tracking options"], title=true});
	ns.EasyMenu.addEntries({ label=MINIMAP_TRACKING_NONE, checked=MiniMapTrackingDropDown_IsNoTrackingActive, func=function() ClearAllTracking(); end });
	ns.EasyMenu.addEntries({separator=true});

	local numTracking,hunterHeader,townHeader = 0,false;
	for id=1, count do
		local tmp={GetTrackingInfo(id)};
		local Name, texture, active, category, nested = unpack(tmp);
		if nested~=HUNTER_TRACKING and nested~=TOWNSFOLK then
			local entry={ label=Name, icon=texture, arg1=id, checked=MiniMapTrackingDropDownButton_IsActive, func=function() SetTracking(id,not select(3,GetTrackingInfo(id))); end };
			if category=="spell" then
				entry.tCoordLeft = 0.0625;
				entry.tCoordRight = 0.9;
				entry.tCoordTop = 0.0625;
				entry.tCoordBottom = 0.9;
			end
			ns.EasyMenu.addEntries(entry);
		end
		tinsert(list,tmp);
	end

	for id=1, #list do
		local Name, texture, active, category, nested = unpack(list[id]);
		local entry;
		if nested == HUNTER_TRACKING and class == "HUNTER" then
			if not hunterHeader then
				ns.EasyMenu.addEntries({separator=true});
				ns.EasyMenu.addEntries({label=HUNTER_TRACKING_TEXT, title=true});
				hunterHeader=true;
			end

			entry = {label=Name,icon=texture, arg1=id, checked=MiniMapTrackingDropDownButton_IsActive, func=function() SetTracking(id,not select(3,GetTrackingInfo(id))); end};
		elseif nested == TOWNSFOLK then
			if not townHeader then
				ns.EasyMenu.addEntries({separator=true});
				ns.EasyMenu.addEntries({label=TOWNSFOLK_TRACKING_TEXT, title=true});
				townHeader=true
			end
			entry = {label=Name,icon=texture, arg1=id, checked=MiniMapTrackingDropDownButton_IsActive, func=function() SetTracking(id,not select(3,GetTrackingInfo(id))); end};
		end
		if entry then
			if category=="spell" then
				entry.tCoordLeft = 0.0625;
				entry.tCoordRight = 0.9;
				entry.tCoordTop = 0.0625;
				entry.tCoordBottom = 0.9;
			end
			ns.EasyMenu.addEntries(entry);
		end
	end

	menuOpened=true;
	ns.EasyMenu.ShowMenu(self,-20,nil,menuClosed);
end

-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
