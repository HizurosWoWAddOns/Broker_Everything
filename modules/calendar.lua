
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<3 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Calendar" -- L["Calendar"] L["ModDesc-Calendar"]
local ttName,ttColumns,tt,module = name.."TT",4;
local events={PLAYER={}, GUILD_ANNOUNCEMENT={}, GUILD_EVENT={}, COMMUNITY_EVENT={}, HOLIDAY={},numPendingInvites=0,numInvites=0};
local state2string = {C("orange",L["(ends soon)"]),C("yellow",L["(starts soon)"]),C("green",L["(current)"])};
local copyEventKeys = {"title","startTime","calendarType","inviteStatus","clubID"};
local eventTimeString = C("ltyellow","%04d-%02d-%02d").." "..C("ltgray","%02d:%02d");
local calendarTypes = {
	{type="PLAYER",             label=L["CalendarInvites"],            cfg="showPlayerInvites"},
	{type="GUILD_ANNOUNCEMENT", label=L["CalendarGuildAnnouncements"], cfg="showGuildEvents"},
	{type="GUILD_EVENT",	    label=L["CalendarGuildEvents"],        cfg="showGuildEvents"},
	{type="COMMUNITY_EVENT",    label=L["CalendarCommunityEvents"],    cfg="showCommunityEvents"},
};
local inviteStatusString = {};
for i,v in ipairs(CALENDAR_INVITESTATUS_INFO)do
	tinsert(inviteStatusString,v.color:WrapTextInColorCode(v.name));
end
local IS_TODAY = C("green","("..COMMUNITIES_CHAT_FRAME_TODAY_NOTIFICATION..") ");
local IS_TOMORROW = C("dkyellow","("..L["Tomorrow"]..") ");


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\calendar"}; --IconName::Calendar--
I[name.."_pending"] = {iconfile="Interface\\Addons\\"..addon.."\\media\\calendar_pending"}; --IconName::Calendar_pending--


-- some local functions --
--------------------------
local function updateEventTime(eventTime)
	eventTime.day = eventTime.monthDay;
	eventTime.unix = time(eventTime);
	eventTime.string = eventTimeString:format(eventTime.year,eventTime.month,eventTime.day,eventTime.hour,eventTime.minute);
end

local function sortByCommunity(a,b)
	return a.clubID<b.clubID;
end

local function updateEvents()
	local currentTime = time();
	local tomorrow = date("*t",currentTime+86400);
	local endsSoon = currentTime - 10800; -- 3hrs
	local startsSoon = currentTime + 43200; -- 12hrs
	local today = date("*t");

	for k,v in pairs(events)do
		if type(v)=="table" then
			wipe(events[k]);
		else
			events[k] = 0;
		end
	end

	for i,monthOffset in ipairs({-1,0,1})do
		local monthInfo = C_Calendar.GetMonthInfo(monthOffset);
		for day=1, monthInfo.numDays do
			local numEvents = C_Calendar.GetNumDayEvents(monthOffset, day);
			for eIndex=1, numEvents do
				local event,Event = {},C_Calendar.GetDayEvent(monthOffset, day, eIndex);
				if Event and Event.title and events[Event.calendarType] then
					for _,k in ipairs(copyEventKeys)do
						event[k] = Event[k];
					end
					updateEventTime(event.startTime);
					if event.calendarType=="HOLIDAY" and (Event.sequenceType=="START" or Event.numSequenceDays==1) then
						event.endTime = Event.endTime;
						updateEventTime(event.endTime);
						event.state=4; -- future
						if event.endTime.unix < currentTime then
							event.state=0; -- past
						elseif event.endTime.unix <= endsSoon then
							event.state=1; -- ends soon
						elseif event.startTime.unix >= currentTime and event.startTime.unix <= startsSoon then
							event.state=2; -- starts soon
						elseif event.startTime.unix <= currentTime then
							event.state=3; -- current
						end
						tinsert(events[event.calendarType],event);
					elseif event.calendarType~="HOLIDAY" and events[event.calendarType] and event.startTime.unix>=currentTime then
						if event.startTime.year==today.year and event.startTime.month==today.month and event.startTime.day==today.day then
							event.isToday = true;
						elseif event.startTime.year==tomorrow.year and event.startTime.month==tomorrow.month and event.startTime.day==tomorrow.day then
							event.isTomorrow = true;
						end
						event.invitedBy = Event.invitedBy;
						if event.calendarType~="GUILD_ANNOUNCEMENT" then
							events.numInvites = events.numInvites+1;
							if event.inviteStatus==CALENDAR_INVITESTATUS_INVITED then
								events.numPendingInvites = events.numPendingInvites+1;
							end
						end
						tinsert(events[event.calendarType],event);
					end
				end
			end
		end
	end
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local numPending,text = events.numPendingInvites;
	text = numPending;
	if not ns.profile[name].shortBroker then
		text = text .. " " .. L[ numPending==1 and "Invite" or "Invites" ];
	end
	if numPending>0 then
		text = C("green",text);
	end
	obj.text = text;

	local icon = I(name..(numPending==0 and "" or "_pending"));
	obj.iconCoords = icon.coords
	obj.icon = icon.iconfile
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	local _=function(y,m,d) return y*10000+m*100+d; end
	if (ns.tooltipChkOnShowModifier(false)) then tt:Hide(); return; end

	if tt.lines~=nil then tt:Clear(); end

	local l=tt:AddHeader(C("dkyellow",L[name]));
	tt:SetCell(l,2,C("ltgreen",date("%Y-%m-%d")),tt:GetHeaderFont(),"RIGHT",0);

	for _, value in ipairs(calendarTypes) do
		if ns.profile[name][value.cfg] and events[value.type] and #events[value.type]>0 then
			tt:AddSeparator(4,0,0,0,0);
			local invStatus = ""
			if value.type~="GUILD_ANNOUNCEMENT" then
				invStatus = C("ltblue",L["CalendarInviteStatus"]);
			end
			local club,inset,l = 0,"",tt:AddLine(C("dkyellow",value.label),C("ltblue",L["Starts"]),"",invStatus);
			tt:AddSeparator();
			if value.type=="COMMUNITY_EVENT" then
				table.sort(events.COMMUNITY_EVENT,sortByCommunity);
				inset = "   ";
			end
			for _, event in ipairs(events[value.type])do
				if value.type=="COMMUNITY_EVENT" and club~=event.clubID then
					local clubInfo = C_Club.GetClubInfo(event.clubID);
					tt:SetCell(tt:AddLine(),1,C("ltgray",clubInfo.name),nil,"LEFT",0);
					club = event.clubID;
				end
				local todayOrTomorrow = (event.isToday and IS_TODAY) or (event.isTomorrow and IS_TOMORROW) or "";
				local l = tt:AddLine(inset..C("ltblue",event.title),todayOrTomorrow..event.startTime.string,"");
				if invStatus~="" then
					tt:SetCell(l,4,inviteStatusString[event.inviteStatus],nil,"LEFT");
				end
			end
		end
	end

	if ns.profile[name].showHolidayEvents and #events.HOLIDAY>0 then
		local separator = false;
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("dkyellow",EVENTS_LABEL),C("ltblue",L["Starts"]),"",C("ltblue",L["Ends"]));
		tt:AddSeparator();
		for i,v in ipairs(events.HOLIDAY)do
			if v.state>0 then
				tt:AddLine(C("ltblue",v.title),(state2string[v.state] or "").." "..v.startTime.string,"-",v.endTime.string);
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
		"PLAYER_LOGIN",
		"CALENDAR_UPDATE_EVENT_LIST",
	},
	config_defaults = {
		enabled = false,
		hideMinimapCalendar = false,
		shortBroker = false,
		showPlayerInvites    = true,
		showGuildEvents      = true,
		showCommunityEvents  = true,
		showHolidayEvents    = true,
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
			showPlayerInvites   = { type="toggle", order=1, name=L["CalendarInvites"],         desc=L["CalendarInvitesDesc"]},
			showGuildEvents     = { type="toggle", order=2, name=L["CalendarGuildEvents"],     desc=L["CalendarGuildEventsDesc"]},
			showCommunityEvents = { type="toggle", order=3, name=L["CalendarCommunityEvents"], desc=L["CalendarCommunityEventsDesc"]},
			showHolidayEvents   = { type="toggle", order=4, name=L["CalendarBlizzardEvents"],  desc=L["CalendarBlizzardEventsDesc"]}
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
end

function module.onevent(self,event,...)
	if event=="BE_UPDATE_CFG" then
		local a1 = ...;
		if a1 and a1:find("^ClickOpt") then
			ns.ClickOpts.update(name);
		elseif not ns.coexist.IsNotAlone() then
			ns.hideFrames("GameTimeFrame",ns.profile[name].hideMinimapCalendar);
		end
	elseif event=="PLAYER_LOGIN" then
		C_Timer.After(4,function()
			local currentCalendarTime = C_DateAndTime.GetCurrentCalendarTime();
			C_Calendar.SetAbsMonth(currentCalendarTime.month, currentCalendarTime.year);
			C_Calendar.OpenCalendar();
		end);
	end
	updateEvents();
	updateBroker();
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

