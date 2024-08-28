
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<2 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name,tt,module = "Tracking" -- TRACKING L["ModDesc-Tracking"]


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\minimap\\tracking\\none"}; --IconName::Tracking--


-- some local functions --
--------------------------

local C_Minimap_GetTrackingInfo
if ns.IsClassicClient() then
	function C_Minimap_GetTrackingInfo(id)
		local info = {}
		info.name, info.texture, info.active, info.type, info.subType, info.spellID = C_Minimap.GetTrackingInfo(id)
		return info;
	end
else
	C_Minimap_GetTrackingInfo = C_Minimap.GetTrackingInfo
end

local function updateTracking()
	local tActive = 0
	local n = {}

	for i = 1, C_Minimap.GetNumTrackingTypes() do
		local info = C_Minimap_GetTrackingInfo(i)
		if info.active then
			tActive = tActive + 1
			n[tActive] = {["Name"] = info.name, ["Texture"] = info.texture}
		end
	end

	return tActive, n
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
	config_defaults = {
		enabled = false,
		displaySelection = true,
		hideMinimapButton = false
	}
}

function module.options()
	return {
		broker = {
			displaySelection={ type="toggle", name=L["Display selection"], desc=L["Display one of the selected tracking options in broker text."] },
		},
		tooltip = nil,
		misc = {
			hideMinimapButton={ type="toggle", order=1, name=L["Hide minimap button"], desc=L["Hide blizzard's tracking button on minimap"], width="full", disabled=ns.coexist.IsNotAlone },
			hideMinimapButtonInfo={ type="description", order=2, name=ns.coexist.optionInfo, fontSize="medium", hidden=ns.coexist.IsNotAlone }
		}
	}
end

function module.init()
	if (not ns.coexist.IsNotAlone()) and ns.profile[name].hideMinimapButton then
		ns.hideFrames("MiniMapTracking",true);
		ns.hideFrames("MiniMapTrackingButton",true);
	end
end

function module.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		if not ns.coexist.IsNotAlone() then
			ns.hideFrames("MiniMapTracking",ns.profile[name].hideMinimapButton);
			ns.hideFrames("MiniMapTrackingButton",ns.profile[name].hideMinimapButton);
		end
	elseif event=="MINIMAP_UPDATE_TRACKING" and _G.LibDropDownMenu_List1:IsShown() then
		ns.EasyMenu:Refresh();
	end

	updateBroker();
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end

function module.ontooltip(tooltip)
	tt=tooltip;
	if (ns.tooltipChkOnShowModifier(false)) then tt:Hide(); return; end

	local numActive, trackActive = updateTracking()
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

local function trackingMenuOnClick(button)
	local info = C_Minimap_GetTrackingInfo(button.arg1);
	C_Minimap.SetTracking(button.arg1,not info.active);
end

local function trackingIsActive(button)
	local info = C_Minimap_GetTrackingInfo(button.arg1);
	return active or info.active;
end

function module.onclick(self,button)
	if tt then tt:Hide(); end
	local info, category
	local list,count = {},C_Minimap.GetNumTrackingTypes();
	local _, class = UnitClass("player");

	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:AddEntry({label=L["Tracking options"], title=true});
	ns.EasyMenu:AddEntry({label=MINIMAP_TRACKING_NONE, checked=MiniMapTrackingDropDown_IsNoTrackingActive, func=C_Minimap.ClearAllTracking });
	ns.EasyMenu:AddEntry({separator=true});

	local numTracking,hunterHeader,townHeader = 0,false;
	for id=1, count do
		info = C_Minimap_GetTrackingInfo(id);
		if info.subType==-1 then
			local entry={label=info.name, icon=info.texture, arg1=id, checked=trackingIsActive, func=trackingMenuOnClick};
			if info.category=="spell" then
				entry.tCoordLeft = 0.0625;
				entry.tCoordRight = 0.9;
				entry.tCoordTop = 0.0625;
				entry.tCoordBottom = 0.9;
			end
			ns.EasyMenu:AddEntry(entry);
		end
		tinsert(list,info);
	end

	for id=1, #list do
		local entry;
		if list[id].subType==HUNTER_TRACKING and class == "HUNTER" then
			if not hunterHeader then
				ns.EasyMenu:AddEntry({separator=true});
				ns.EasyMenu:AddEntry({label=HUNTER_TRACKING_TEXT, title=true});
				hunterHeader=true;
			end

			entry = {label=list[id].name, icon=list[id].texture, arg1=id, checked=trackingIsActive, func=trackingMenuOnClick};
		elseif list[id].subType==TOWNSFOLK_TRACKING  then
			if not townHeader then
				ns.EasyMenu:AddEntry({separator=true});
				ns.EasyMenu:AddEntry({label=TOWNSFOLK_TRACKING_TEXT, title=true});
				townHeader=true
			end
			entry = {label=list[id].name, icon=list[id].texture, arg1=id, checked=trackingIsActive, func=trackingMenuOnClick};
		end
		if entry then
			if info.type=="spell" then
				entry.tCoordLeft = 0.0625;
				entry.tCoordRight = 0.9;
				entry.tCoordTop = 0.0625;
				entry.tCoordBottom = 0.9;
			end
			ns.EasyMenu:AddEntry(entry);
		end
	end

	ns.EasyMenu:ShowMenu(self,-20);
end

-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
