
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Latency" -- L["Latency"]
local ldbName,ttName = name,name.."TT";
local tt = nil
local GetNetStats = GetNetStats
local suffix = "ms"
local latency = { Home = 0, World = 0 }
-- http://wowpedia.org/Latency
-- the copy of a bluepost from Brianl are interesting.


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\latency"}; --IconName::Latency--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show your current latency. Can be configured to show both Home and/or World latency."];
ns.modules[name] = {
	desc = desc,
	events = {
		"PLAYER_ENTERING_WORLD"
	},
	updateinterval = 10,
	config_defaults = {
		showHome = true,
		showWorld = true
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showHome",  label=L["Show home"],  tooltip = L["Enable/Disable the display of the latency to the home realm"] },
		{ type="toggle", name="showWorld", label=L["Show world"], tooltip = L["Enable/Disable the display of the latency to the world realms"] }
	}
}


--------------------------
-- some local functions --
--------------------------

local function createMenu(self)
	if (tt) then tt:Hide(); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addEntries({
		{
			label = L["Options"],
			title = true,
		},
		{ separator = true },
		{
			label = L["Show home"],
			beType = "bool",
			beModName = name,
			beKeyName = "showHome",
			event = function() ns.modules[name].onupdate(self); end
		},
		{
			label = L["Show world"],
			beType = "bool",
			beModName = name,
			beKeyName = "showWorld",
			event = function() ns.modules[name].onupdate(self); end
		},
		{
			label = L["Suffix coloring"],
			beType = "bool",
			beModName = nil,
			beKeyName = "suffixColour",
			event = function() ns.modules[name].onupdate(self); end
		},
	});
	ns.EasyMenu.ShowMenu(self);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name;
end

ns.modules[name].onevent = function(self,event,msg)
	ns.modules[name].onupdate(self);
end

ns.modules[name].onupdate = function(self)
	local _, _, lHome, lWorld = GetNetStats()
	local text = {};
	local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName);
	local suffix = ns.suffixColour(suffix);
	local showHome, showWorld = Broker_EverythingDB[name].showHome, Broker_EverythingDB[name].showWorld;
	latency.Home,latency.World = lHome,lWorld;
	
	 -- Colour the latencies
	for k, v in pairs(latency) do
		if v <= 250 then 
			latency[k] = C("green",v);
		elseif v > 250 and v <= 400 then
			latency[k] = C("dkyellow",v);
		elseif v > 400 then
			latency[k] = C("red",v);
		end
	end

	if (showWorld) then
		tinsert(text, (showHome and C("white"," W:") or "") .. latency.World .. suffix);
	end

	if (showHome) then
		tinsert(text, (showWorld and C("white"," H:") or "") .. latency.Home .. suffix);
	end

	dataobj.text = (#text>0) and table.concat(text," ") or L[name];
end

-- ns.modules[name].optionspanel = function(panel) end

ns.modules[name].ontooltip = function(_tt)
	tt=_tt;
	if (ns.tooltipChkOnShowModifier(false)) then tt:Hide(); return; end

	ns.tooltipScaling(tt);
	tt:AddLine(L[name]);
	tt:AddLine(" ");
	tt:AddDoubleLine(C("white",L["Home"] .. " :"), latency.Home .. suffix);
	tt:AddDoubleLine(C("white",L["World"] .. " :"), latency.World .. suffix);

	if (Broker_EverythingDB.showHints) then
		tt:AddLine(" ");
		tt:AddLine(C("copper",L["Right-click"]).." || "..C("green",L["Open option menu"]));
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
-- ns.modules[name].onenter = function(self) end
-- ns.modules[name].onleave = function(self) end

ns.modules[name].onclick = function(self,button)
	if button == "RightButton" then
		createMenu(self);
	end
end

-- ns.modules[name].ondblclick = function(self,button) end

