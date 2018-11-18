
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Calendar" -- L["Calendar"] L["ModDesc-Calendar"]
local ttName,ttColumns,tt,module = name.."TT",4;
local zf="%02d";
local state2string = {
	C("orange",L["(ends soon)"]), -- [1]
	C("yellow",L["(starts soon)"]), -- [2]
	C("green",L["(current)"]), -- [3]
};

-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\calendar"}; --IconName::Calendar--
I[name.."_pending"] = {iconfile="Interface\\Addons\\"..addon.."\\media\\calendar_pending"}; --IconName::Calendar_pending--


-- some local functions --
--------------------------
local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local num = C_Calendar.GetNumPendingInvites();

	local icon = I(name..(num~=0 and "_pending" or ""))
	obj.iconCoords = icon.coords
	obj.icon = icon.iconfile

	-- %d |4Invite:Invites; ?
	local inv = " "..L[ num==1 and "Invite" or "Invites" ]
	if (ns.profile[name].shortBroker) then
		inv = ""
	end

	if num==0 then
		obj.text = num..inv;
	else
		obj.text = C("green",num..inv);
	end
end

local function GetDateNumeric(eventDate)
	return tonumber(eventDate.year..zf:format(eventDate.month)..zf:format(eventDate.monthDay)..zf:format(eventDate.hour)..zf:format(eventDate.minute));  -- a simple yyyymmddhhii
end

local fDateString = C("ltyellow","%04d-%02d-%02d ")..C("ltgray","%02d:%02d");
local function GetDateString(eventDate)
	return string.format(fDateString,eventDate.year,eventDate.month,eventDate.monthDay,eventDate.hour,eventDate.minute);
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	local _=function(y,m,d) return y*10000+m*100+d; end
	if (ns.tooltipChkOnShowModifier(false)) then tooltip:Hide(); return; end

	local numInvites = C_Calendar.GetNumPendingInvites()
	local dateNumeric = tonumber(date("%Y%m%d%H%M"));

	local _time = time();
	local endsSoonNumeric = tonumber(date("%Y%m%d%H%M",_time - 10800)); -- 3hrs
	local startsSoonNumeric = tonumber(date("%Y%m%d%H%M",_time + 43200)); -- 12hrs
	ns.debug(dateNumeric,endsSoonNumeric,startsSoonNumeric);

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",L[name]),C("ltgreen",date("%Y-%m-%d")));
	tt:AddSeparator();

	if numInvites == 0 then
		tt:AddLine(C("ltgray",L["No invitations found"].."."));
	else
		tt:AddLine(C("white",numInvites.." "..(numInvites==1 and L["Invitation"] or L["Invitations"])));
	end

	local showEvents = tonumber(ns.profile[name].showEvents);
	if showEvents>0 then
		--- collect events of this month
		local holidays = {};
		for i,monthOffset in ipairs({-1,0,1})do
			local monthInfo = C_Calendar.GetMonthInfo(monthOffset);
			for day=1, monthInfo.numDays do
				local numEvents = C_Calendar.GetNumDayEvents(monthOffset, day);
				for eIndex=1, numEvents do
					local event = C_Calendar.GetDayEvent(monthOffset, day, eIndex);
					if event and event.title then
						if event.sequenceType=="START" or event.numSequenceDays==1 then
							event.startNumeric = GetDateNumeric(event.startTime);
							event.startString = GetDateString(event.startTime);
							event.endNumeric = GetDateNumeric(event.endTime);
							event.endString = GetDateString(event.endTime);
							event.state=4; -- future
							if event.endNumeric < dateNumeric then
								event.state=0; -- past
							elseif event.endNumeric <= endsSoonNumeric then
								event.state=1; -- ends soon
							elseif event.startNumeric >= dateNumeric and event.startNumeric <= startsSoonNumeric then
								event.state=2; -- starts soon
							elseif event.startNumeric <= dateNumeric then
								event.state=3; -- current
							end
							tinsert(holidays,event);
						end
					end
				end
			end
		end

		if #holidays>0 then
			local separator = false;
			tt:AddSeparator(4,0,0,0,0);
			if showEvents==2 then
				tt:AddLine(C("dkyellow",EVENTS_LABEL),C("ltblue",L["Starts"]),"",C("ltblue",L["Ends"]));
			else
				tt:AddLine(C("dkyellow",EVENTS_LABEL));
			end
			tt:AddSeparator();
			for i,v in ipairs(holidays)do
				local title = C("ltblue",v.title);
				if(v.state>0)then
					local state = state2string[v.state] or "";
					if showEvents==2 then
						tt:AddLine(title.." "..state,v.startString,"-",v.endString);
					else
						if separator then
							tt:AddSeparator(1,.64,.64,.64,1);
						end
						tt:AddLine(title,v.startString);
						tt:AddLine(state,"- "..v.endString);
					end
					separator = true;
				end
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"CALENDAR_UPDATE_PENDING_INVITES",
		"PLAYER_LOGIN"
	},
	config_defaults = {
		enabled = false,
		hideMinimapCalendar = false,
		shortBroker = false,
		showEvents = 1
	},
	clickOptionsRename = {
		["charinfo"] = "1_open_character_info",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["calendar"] = {"Calendar","call","ToggleCalendar"},
		["charinfo"] = "CharacterInfo",
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	calendar = "_LEFT",
	charinfo = "__NONE",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			shortBroker={ type="toggle", order=1, name=L["Shorter Broker"], desc=L["Reduce the broker text to a number without text"]},
		},
		tooltip = {
			showEvents={
				type = "select", order=1, name=L["Show events"], desc=L["Display a list of events in tooltip"], width="full",
				values = {
					[0]=L["No events"],
					[1]=L["Show events"],
					[2]=L["One event per line"]
				}
			}
		},
		misc = {
			hideMinimapCalendar={ type="toggle", order=1, name=L["Hide calendar button"], desc=L["Hide Blizzard's minimap calendar button"], width="full", disabled=ns.coexist.IsNotAlone },
			hideMinimapCalendarInfo={ type="description", order=2, name=ns.coexist.optionInfo, fontSize="medium", hidden=ns.coexist.IsNotAlone }
		},
	}
end

function module.init()
	if (not ns.coexist.IsNotAlone()) and ns.profile[name].hideMinimapCalendar then
		ns.hideFrames("GameTimeFrame",true);
	end
	if type(ns.profile[name].showEvents)=="boolean" then
		if ns.profile[name].showEvents then
			if ns.profile[name].singleLineEvents or ns.profile[name].shortEvents then
				ns.profile[name].showEvents = 2;
			else
				ns.profile[name].showEvents = 1;
			end
		else
			ns.profile[name].showEvents = 0;
		end
		ns.profile[name].singleLineEvents = nil;
		ns.profile[name].shortEvents = nil;
	end
end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="BE_UPDATE_CFG" then
		if not ns.coexist.IsNotAlone() then
			ns.hideFrames("GameTimeFrame",ns.profile[name].hideMinimapCalendar);
		end
	else
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
