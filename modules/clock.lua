
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
L.Clock = TIMEMANAGER_TITLE;


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Clock"; -- TIMEMANAGER_TITLE
local ttName,ttColumns, tt, createMenu,module = name.."TT", 2;
local countries,month_short = {},{};
local played,initialized,clock_diff = false,false;


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\clock"}; --IconName::Clock--


-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function date(dateStr)
	local m = tonumber(_G.date("%m"));
	local M = _G["MONTH_".._G.date("%B"):upper()];
	if dateStr:find("_mm_") then
		dateStr = gsub(dateStr,"_mm_",M);
	end
	if dateStr:find("_m_") then
		dateStr = gsub(dateStr,"_m_",_G.date("%b."));
	end
	return _G.date(dateStr);
end

local function createTooltip(tt,update)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	local h24 = ns.profile[name].format24;
	local dSec = ns.profile[name].showSeconds;
	local pT,pL,pS = ns.LT.GetPlayedTime();

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",TIMEMANAGER_TITLE));
	tt:AddSeparator();

	if ns.profile[name].showDate then
		tt:AddLine(C("ltyellow",L["Date"]),		C("white",date(ns.profile[name].dateFormat)));
	end
	tt:AddLine(C("ltyellow",L["Local time"]),	C("white",ns.LT.GetTimeString("LocalTime",h24,dSec)));
	tt:AddLine(C("ltyellow",L["Realm time"]),	C("white",ns.LT.GetTimeString("GameTime",h24,dSec)));
	tt:AddLine(C("ltyellow",L["UTC time"]),		C("white",ns.LT.GetTimeString("UTCTime",h24,dSec)));

	--tt:AddSeparator(3,0,0,0,0);
	--tt:AddLine(C("ltblue",L["Additional time zones"]));
	--tt:AddSeparator();
	--tt:AddLine(C("gray","coming soon"));

	tt:AddSeparator(3,0,0,0,0);
	tt:AddLine(C("ltblue",L["Playtime"]));
	tt:AddSeparator();
	tt:AddLine(C("ltyellow",TOTAL),C("white",SecondsToTime(pT)));
	tt:AddLine(C("ltyellow",LEVEL),C("white",SecondsToTime(pL)));
	tt:AddLine(C("ltyellow",L["Session"]),C("white",SecondsToTime(pS)));

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(3,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name);
	end
	if not update then
		ns.roundupTooltip(tt);
	end
end

local function updater(self)
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local h24 = ns.profile[name].format24;
	local dSec = ns.profile[name].showSeconds;
	obj.text = ns.profile[name].timeLocal and ns.LT.GetTimeString("LocalTime",h24,dSec) or ns.LT.GetTimeString("GameTime",h24,dSec)
	if tt~=nil and tt.key==name.."TT" and tt:IsShown() then
		createTooltip(tt,true);
	end
end


-- module functions and variables --
------------------------------------
module = {
	desc = L["Broker to show local and/or realm time"],
	label = TIMEMANAGER_TITLE,
	events = {"PLAYER_LOGIN","TIME_PLAYED_MSG"},
	updateinterval = 1,
	timeout = 30,
	timeoutAfterEvent = "PLAYER_ENTERING_WORLD",
	config_defaults = {
		format24 = true,
		timeLocal = true,
		showSeconds = false,
		showDate = true,
		dateFormat = "%Y-%m-%d"
	},
	config_allowed = nil,
	config_header = {type="header", label=TIMEMANAGER_TITLE, align="left", icon=I[name]},
	config_broker = {
		{ type="toggle", name="timeLocal",   label=L["Local or realm time"], tooltip=L["Switch between local and realm time in broker button"] },
	},
	config_tooltip = {
		{ type="toggle", name="showSeconds", label=L["Show seconds"], tooltip=L["Display the time with seconds in broker button and tooltip"] },
		{ type="toggle", name="showDate",    label=L["Show date"], tooltip=L["Display date in tooltip"] },
	},
	config_misc = {
		{ type="toggle", name="format24",    label=TIMEMANAGER_24HOURMODE, tooltip=L["Switch between time format 24 hours and 12 hours with AM/PM"] },
		{ type="select", name="dateFormat",  label=L["Date format"], tooltip=L["Choose your favorite date format"],
			values = {
				["%Y-%m-%d"] = "yyyy-mm-dd",
				["%Y.%m.%d"] = "yyyy.mm.dd",
				["%Y.%d.%m"] = "yyyy.dd.mm",
				["%d.%m.%Y"] = "dd.mm.yyyy",
				["%d/%m/%Y"] = "dd/mm/yyyy",
				["%m/%d/%Y"] = "mm/dd/yyyy",
				["%d. _mm_ %Y"] = "dd. mmmm yyyy",
				["%d. _mm_ %y"] = "dd. mmmm yy",
				["%d. _m_ %Y"] = "dd. mmm yyyy",
				["%Y _mm_ %d."] = "yyyy mm dd.",
			}
		},
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
			cfg_label = "Local or realm time", -- L["Local or realm time"]
			cfg_desc = "switch between local and realm time", -- L["switch between local and realm time"]
			cfg_default = "_RIGHT",
			hint = "Local or realm time",
			func = function(self,button)
				local _mod=name;
				ns.profile[name].timeLocal = not ns.profile[name].timeLocal;
			end
		},
		["3_calendar"] = {
			cfg_label = "Open calendar", -- L["Open calendar"]
			cfg_desc = "open the calendar", -- L["open the calendar"]
			cfg_default = "SHIFTRIGHT",
			hint = "Open calendar",
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCalendar");
			end
		},
		["4_hours_mode"] = {
			cfg_label = "12 / 24 hours mode", -- L["12 / 24 hours mode"]
			cfg_desc = "switch between 12 and 24 time format", -- L["switch between 12 and 24 time format"]
			cfg_default = "SHIFTLEFT",
			hint = "12 / 24 hours mode",
			func = function(self,button)
				local _mod=name;
				ns.profile[name].format24 = not ns.profile[name].format24;
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

function module.init()
	for i,v in pairs(module.config_misc[2].values)do
		module.config_misc[2].values[i] = date(i)..C("gray","("..v..")");
	end
end

function module.onevent(self,event,...)
	if event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(module,ns.profile[name]);
	elseif event=="PLAYER_LOGIN" then
		C_Timer.NewTicker(module.updateinterval,updater);
	elseif event=="TIME_PLAYED_MSG" then
		played = true
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end

function module.ontimeout(self)
	if played==false then
		--RequestTimePlayed()
	end
end

-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns , "LEFT", "RIGHT"},{true},{self})
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
