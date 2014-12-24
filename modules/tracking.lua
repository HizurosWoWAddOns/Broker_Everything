
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Tracking" -- L["Tracking"]
local ldbName = name
local tt = nil
local GetNumTrackingTypes,GetTrackingInfo = GetNumTrackingTypes,GetTrackingInfo

local similar, own, unsave = "%s has a similar option to hide the minimap tracking icon.","%s has its own tracking icon.","%s found. It's unsave to hide the minimap tracking icon without errors.";
-- L["%s has a similar option to hide the minimap tracking icon."] L["%s has its own tracking icon."] L["%s found. It's unsave to hide the minimap tracking icon without errors."]
local coexist_tooltip = {
	["Carbonite"]			= unsave,
	["DejaMinimap"]			= unsave,
	["Chinchilla"]			= similar,
	["Dominos_MINIMAP"]		= similar,
	["gUI4_Minimap"]		= own,
	["LUI"]					= own,
	["MinimapButtonFrame"]	= unsave,
	["SexyMap"]				= similar,
	["SquareMap"]			= unsave,
};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\minimap\\tracking\\none"}; --IconName::Tracking--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show what you are currently tracking. You can also change the tracking types from this broker."]
ns.modules[name] = {
	desc = desc,
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
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="displaySelection", label=L["Display selection"], tooltip=L["Display one of the selected tracking options in broker text."], event=true },
		{ type="toggle", name="hideMinimapButton", label=L["Hide minimap button"], tooltip=L["Hide blizzard's tracking button on minimap"], event="BE_HIDE_TRACKING", disabled=function()
				if (ns.coexist.found~=false) then
					return L["This option is disabled"],L[coexist_tooltip[ns.coexist.found]]:format(ns.coexist.found);
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


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	local numActive, trackActive = updateTracking()
	local n = L[name]
	local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName)

	if Broker_EverythingDB[name].displaySelection then
		if numActive == 0 then 
			n = "None"
		else
			for i = 1, numActive, 1 do
				n = trackActive[i]["Name"]
			end
		end
	end

	if event == "BE_HIDE_TRACKING" then -- custom event on config changed
		if Broker_EverythingDB[name].hideMinimapButton then
			ns.hideFrame("MiniMapTracking")
		else
			ns.unhideFrame("MiniMapTracking")
		end
	end

	dataobj.text = n
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)
	if (ns.tooltipChkOnShowModifier(false)) then tt:Hide(); return; end

	local numActive, trackActive = updateTracking()
	ns.tooltipScaling(tt)
	tt:AddLine(L[name])
	tt:AddLine(" ")

	if numActive == 0 then
		tt:AddLine(C("white",L["No tracking option active."]))
	else
		for i = 1, numActive do 
			tt:AddDoubleLine(C("white",trackActive[i]["Name"]))
			tt:AddTexture(trackActive[i]["Texture"])
		end
	end

	if Broker_EverythingDB.showHints then
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
	ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, self, 0, 0)
end

-- ns.modules[name].ondblclick = function(self,button) end

ns.modules[name].coexist = function()
	if (not ns.coexist.found) and (Broker_EverythingDB[name].hideMinimapButton) then
		ns.hideFrame("MiniMapTracking");
	end
end
