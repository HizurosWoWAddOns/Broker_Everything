
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Tracking" -- TRACKING
local tt = nil
local menuOpened = false;


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\minimap\\tracking\\none"}; --IconName::Tracking--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show current tracking list with option to change it"],
	label = TRACKING,
	events = {
		"MINIMAP_UPDATE_TRACKING",
		"PLAYER_LOGIN",
		"PLAYER_ENTERING_WORLD"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		displaySelection = true,
		hideMinimapButton = false
	},
	config_allowed = {
	},
	config_header = {type="header", label=TRACKING, align="left", icon=I[name]},
	config_broker = {
		{ type="toggle", name="displaySelection", label=L["Display selection"], tooltip=L["Display one of the selected tracking options in broker text."], event=true },
	},
	config_tooltip = nil,
	config_misc = {
		{ type="toggle", name="hideMinimapButton", label=L["Hide minimap button"], tooltip=L["Hide blizzard's tracking button on minimap"], event="BE_HIDE_TRACKING", disabled=function()
				if ns.coexist.check() then
					return ns.coexist.optionInfo();
				end
				return false;
			end
		}
	}
}


--------------------------
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

------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules[name].init = function() end

ns.modules[name].onevent = function(self,event,msg)
	if event=="BE_HIDE_TRACKING" then -- custom event on config changed
		if ns.profile[name].hideMinimapButton then
			ns.hideFrame("MiniMapTracking")
		else
			ns.unhideFrame("MiniMapTracking")
		end
	elseif event=="MINIMAP_UPDATE_TRACKING" and menuOpened and LibDropDownMenu_List1:IsShown() then
		ns.EasyMenu.Refresh(1);
	end

	-- broker button text
	local numActive, trackActive = updateTracking()
	local n = TRACKING;
	local dataobj = self.obj or ns.LDB:GetDataObjectByName(ns.modules[name].ldbName)
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

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tooltip)
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
		tt:AddLine(C("copper",L["Click"]).." || "..C("green",L["Open tracking menu"]))
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
-- ns.modules[name].onenter = function(self) end
-- ns.modules[name].onleave = function(self) end

ns.modules[name].onclick = function(self,button)
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

-- ns.modules[name].ondblclick = function(self,button) end

