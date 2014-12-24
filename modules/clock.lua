
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Clock";
L.Clock = TIMEMANAGER_TITLE;
local ldbName,ttName = name,name.."TT"
local GetGameTime = GetGameTime
local tt,GetGameTime2,createMenu
local countries = {}
local played = false
local clock_diff = nil

-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\clock"}; --IconName::Clock--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show realm or local time"]
ns.modules[name] = {
	desc = desc,
	events = {"TIME_PLAYED_MSG"},
	updateinterval = 1,
	timeout = 30,
	timeoutAfterEvent = "PLAYER_ENTERING_WORLD",
	config_defaults = {
		format24 = true,
		timeLocal = true,
		showSeconds = false
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle",name="format24", label=TIMEMANAGER_24HOURMODE, tooltip=L["Switch between time format 24 hours and 12 hours with AM/PM"] },
		{ type="toggle", name="timeLocal", label=L["Local or server time"], tooltip=L["Switch between local and server time in broker button"] },
		{ type="toggle", name="showSeconds", label=L["Show seconds"], tooltip=L["Display the time with seconds in broker button and tooltip"] }
	},
	clickOptions = {
		["1_timemanager"] = {
			cfg_label = "Open time manager", -- L["Open time manager"]
			cfg_desc = "open the time manager", -- L["open the time manager"]
			cfg_default = "_LEFT",
			hint = "Open time manager", -- L["Open time manager"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleTimeManager");
			end
		},
		["2_toggle_time"] = {
			cfg_label = "Local or server time",
			cfg_desc = "switch between local and server time",
			cfg_default = "_RIGHT",
			hint = "Local or server time",
			func = function(self,button)
				local _mod=name;
				Broker_EverythingDB[name].timeLocal = not Broker_EverythingDB[name].timeLocal;
				ns.modules[name].onupdate(self)
			end
		},
		["3_calendar"] = {
			cfg_label = "Open calendar",
			cfg_desc = "open the calendar",
			cfg_default = "SHIFTRIGHT",
			hint = "Open calendar",
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCalendar");
			end
		},
		["4_hours_mode"] = {
			cfg_label = "12 / 24 hours mode",
			cfg_desc = "switch between 12 and 24 time format",
			cfg_default = "SHIFTLEFT",
			hint = "12 / 24 hours mode",
			func = function(self,button)
				local _mod=name;
				Broker_EverythingDB[name].format24 = not Broker_EverythingDB[name].format24;
				ns.modules[name].onupdate(self)
			end
		},
		["5_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self);
			end
		},
		-- open blizzards stopwatch?
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function generateTooltip(tt)
	local h24 = Broker_EverythingDB[name].format24
	local dSec = Broker_EverythingDB[name].showSeconds
	local pT,pL,pS = ns.LT.GetPlayedTime()

	tt:Clear()
	tt:AddHeader(C("dkyellow",L[name]))
	tt:AddSeparator()

	tt:AddLine(C("ltyellow",L["Local Time"]),	C("white",ns.LT.GetTimeString("GetLocalTime",h24,dSec)))
	tt:AddLine(C("ltyellow",L["Server Time"]),	C("white",ns.LT.GetTimeString("GetGameTime",h24,dSec)))
	tt:AddLine(C("ltyellow",L["UTC Time"]),		C("white",ns.LT.GetTimeString("GetUTCTime",h24,dSec)))

	tt:AddSeparator(3,0,0,0,0)

	tt:AddLine(C("ltblue",L["Playtime"]))
	tt:AddSeparator()
	tt:AddLine(C("ltyellow",L["Total"]),C("white",SecondsToTime(pT)))
	tt:AddLine(C("ltyellow",L["Level"]),C("white",SecondsToTime(pL)))
	tt:AddLine(C("ltyellow",L["Session"]),C("white",SecondsToTime(pS)))

	if Broker_EverythingDB.showHints then
		tt:AddSeparator(3,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name);
	end

end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,...)
	if event=="TIME_PLAYED_MSG" then
		played = true
	end
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].onupdate = function(self)
	if not self then self = {} end
	self.obj = self.obj or ns.LDB:GetDataObjectByName(ldbName)

	local h24 = Broker_EverythingDB[name].format24
	local dSec = Broker_EverythingDB[name].showSeconds

	self.obj.text = Broker_EverythingDB[name].timeLocal and ns.LT.GetTimeString("GetLocalTime",h24,dSec) or ns.LT.GetTimeString("GetGameTime",h24,dSec)

	if tt~=nil and tt.key==name.."TT" and tt:IsShown() then
		generateTooltip(tt)
	end
end

ns.modules[name].ontimeout = function(self)
	if played==false then
		--RequestTimePlayed()
	end
end

ns.modules[name].ontooltip = function(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...
	ns.tooltipScaling(tt)
	local h24 = Broker_EverythingDB[name].format24
	local dSec = Broker_EverythingDB[name].showSeconds
	tt:ClearLines()

	tt:AddLine(L[name])
	tt:AddLine(" ")

	tt:AddDoubleLine(C("white",L["Local Time"]), C("white",ns.LT.GetTimeString("GetLocalTime",h24,dSec)))
	tt:AddDoubleLine(C("white",L["Server Time"]), C("white",ns.LT.GetTimeString("GetGameTime",h24,dSec)))

	if Broker_EverythingDB.showHints then
		tt:AddLine(" ")
		ns.clickOptions.ttAddHints(tt,name);
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	tt = ns.LQT:Acquire(ttName, 2 , "LEFT", "RIGHT" )
	generateTooltip(tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
	if (tt2) then ns.hideTooltip(tt2,ttName2,true); end --?
end

-- ns.modules[name].ondblclick = function(self,button) end

