
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Calendar" -- L["Calendar"]
local ldbName = name
local tt,createMenu
local similar, own, unsave = "%s has a similar option to hide the minimap mail icon.","%s has its own mail icon.","%s found. It's unsave to hide the minimap mail icon without errors.";
-- L["%s has a similar option to hide the minimap mail icon."] L["%s has its own mail icon."] L["%s found. It's unsave to hide the minimap mail icon without errors."]
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


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\calendar"}; --IconName::Calendar--
I[name.."_pending"] = {iconfile="Interface\\Addons\\"..addon.."\\media\\calendar_pending"}; --IconName::Calendar_pending--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show invitations"]
ns.modules[name] = {
	desc = desc,
	events = {
		"CALENDAR_UPDATE_PENDING_INVITES",
		"PLAYER_ENTERING_WORLD"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		hideMinimapCalendar = false,
		shortBroker = false,
		shortEvents = true
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="hideMinimapCalendar", label=L["Hide calendar button"], tooltip=L["Hide Blizzard's minimap calendar button"],
			disabled = function()
				if (ns.coexist.found~=false) then
					return L["This option is disabled"],L[coexist_tooltip[ns.coexist.found]]:format(ns.coexist.found);
				end
				return false;
			end
		},
		{ type="toggle", name="shortBroker", label=L["Shorter Broker"], tooltip=L["Reduce the broker text to a number without text"], event=true },
		{ type="toggle", name="shortEvents", label=L["Shorter Events"], tooltip=L["Reduce event list height in tooltip"] }
	},
	clickOptions = {
		["1_open_character_info"] = {
			cfg_label = "Open calendar", -- L["Open calendar"]
			cfg_desc = "open the calendar", -- L["open the calendar"]
			cfg_default = "_LEFT",
			hint = "Open calendar", -- L["Open calendar"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCalendar");
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self)
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) then tt:Hide(); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end
ns.modules[name].onevent = function(self,event,msg)
	self.obj = self.obj or ns.LDB:GetDataObjectByName(ldbName);
	local num = CalendarGetNumPendingInvites();

	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end

	local icon = I(name..(num~=0 and "_pending" or ""))
	self.obj.iconCoords = icon.coords
	self.obj.icon = icon.iconfile

	-- %d |4Invite:Invites; ?
	local inv = " "..L[ num==1 and "Invite" or "Invites" ]
	if (Broker_EverythingDB[name].shortBroker) then
		inv = ""
	end

	if num==0 then
		self.obj.text = num..inv;
	else
		self.obj.text = C("green",num..inv);
	end
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tooltip)
	local _=function(y,m,d) return y*10000+m*100+d; end
	if (ns.tooltipChkOnShowModifier(false)) then tooltip:Hide(); return; end
	tt=tooltip;

	local x = CalendarGetNumPendingInvites()
	local weekday, month, day, year = CalendarGetDate();
	local today=_(year,month,day);

	ns.tooltipScaling(tt)
	tt:AddDoubleLine(L[name],C("ltgray",(" %d-%02d-%02d"):format(year,month,day)))
	tt:AddLine(" ")
	if x == 0 then
		tt:AddLine(C("white",L["No invitations found"].."."))
	else
		tt:AddLine(C("white",x.." "..(x==1 and L["Invitation"] or L["Invitations"]).."."))
	end

	--- collect events of this month
	local holidays = {};
	local NameToIndex={};
	local fDate = "%04d-%02d-%02d %02d:%02d";
	for i,monthOffset in ipairs({-1,0,1})do
		--local monthOffset=1;
		local month, year, numDays, firstWeekday = CalendarGetMonth(monthOffset);
		for day=1, numDays do
			local numEvents = CalendarGetNumDayEvents(monthOffset, day);
			for eIndex=1, numEvents do
				local title, hour, minute, calendarType, sequenceType = CalendarGetDayEvent(monthOffset, day, eIndex);
				if(title)then
					if(sequenceType=="START")then
						tinsert(holidays,{
							title=title,
							startStr=fDate:format(year,month,day,hour,minute),
							startNum=_(year,month,day),
							stopStr="",
							stopNum=0,
							state=4
						});
						NameToIndex[title]=#holidays;
					end
					if(sequenceType=="END" and NameToIndex[title])then
						local I = NameToIndex[title];
						holidays[I].stopStr=fDate:format(year,month,day,hour,minute);
						holidays[I].stopNum=_(year,month,day);

						if(today>holidays[I].stopNum)then
							holidays[I].state=0; -- past
						elseif(today>=holidays[I].startNum and today<=holidays[I].stopNum)then
							holidays[I].state=1; -- current
						else
							holidays[I].state=2; -- future
						end

						NameToIndex[title]=nil;
					end
				end
			end
		end
	end

	if(#holidays>0)then
		local x,soon=nil,nil;
		tt:AddLine(" ")
		tt:AddLine(C("dkyellow",L["Events"]));
		for i,v in ipairs(holidays)do
			if(v.state>0)then
				if(Broker_EverythingDB[name].shortEvents)then
					tt:AddDoubleLine(
						C("ltblue",v.title)
						.." "..
						( (v.state==1 and C("green",L["(current)"])) or (v.state==2 and not soon and C("yellow",L["(soon)"])) or " " ),
						C("ltyellow",v.startStr.." "..L["to"].." "..v.stopStr)
					);
				else
					if(x)then
						tt:AddLine(" ");
					end
					tt:AddDoubleLine(C("ltblue",v.title),C("ltyellow",v.startStr));
					tt:AddDoubleLine( (v.state==1 and C("green",L["(current)"])) or (v.state==2 and not soon and C("yellow",L["(soon)"])) or " ",C("ltyellow",L["to"].." "..v.stopStr));
				end
				if(v.state==2)then
					soon=1;
				end
				x=1;
			end
		end
	end

	if Broker_EverythingDB.showHints then
		tt:AddLine(" ")
		ns.clickOptions.ttAddHints(tt,name);
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
-- ns.modules[name].onenter = function(self) end
-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self) end
-- ns.modules[name].ondblclick = function(self,button) end

ns.modules[name].coexist = function()
	if (not ns.coexist.found) and (Broker_EverythingDB[name].hideMinimapCalendar) then
		GameTimeFrame:Hide();
		GameTimeFrame.Show = dummyFunc;
	end
end

--[=[
note:
	broker text can extend with accepted entries today

	tt can be extend with accepted today. (time, title) description are zoo much for tt.
	can be display in second tt on mouseover
]=]