
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Calendar" -- L["Calendar"]
local ttName,ttColumns,tt,createMenu = name.."TT",2;
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
local calendar_weekend_texture_ids = { -- Calendar_Weekend(.*)
	[1129666] = "ApexisEnd",
	[1129667] = "ApexisOngoing",
	[1129668] = "ApexisStart",
	[1129669] = "BattlegroundsEnd",
	[1129670] = "BattlegroundsOngoing",
	[1129671] = "BattlegroundsStart",
	[1663861] = "BlackTempleStart",
	[1129672] = "BurningCrusadeEnd",
	[1129673] = "BurningCrusadeOngoing",
	[1129674] = "BurningCrusadeStart",
	[1304686] = "CataclysmEnd",
	[1304687] = "CataclysmOngoing",
	[1304688] = "CataclysmStart",
	[1467045] = "LegionEnd",
	[1467046] = "LegionOngoing",
	[1467047] = "LegionStart",
	[1530588] = "MistsofPandariaEnd",
	[1530589] = "MistsofPandariaOngoing",
	[1530590] = "MistsofPandariaStart",
	[1129675] = "PetBattlesEnd",
	[1129676] = "PetBattlesOngoing",
	[1129677] = "PetBattlesStart",
	[1129678] = "PvPSkirmishEnd",
	[1129679] = "PvPSkirmishOngoing",
	[1129680] = "PvPSkirmishStart",
	[1129681] = "WarlordsOfDraenorEnd",
	[1129682] = "WarlordsOfDraenorOngoing",
	[1129683] = "WarlordsOfDraenorStart",
	[1467048] = "WorldQuestEnd",
	[1467049] = "WorldQuestOngoing",
	[1467050] = "WorldQuestStart",
	[1129684] = "WrathOfTheLichKingEnd",
	[1129685] = "WrathOfTheLichKingOngoing",
	[1129686] = "WrathOfTheLichKingStart",
}

-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\calendar"}; --IconName::Calendar--
I[name.."_pending"] = {iconfile="Interface\\Addons\\"..addon.."\\media\\calendar_pending"}; --IconName::Calendar_pending--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show calendar events and invitations"],
	events = {
		"CALENDAR_UPDATE_PENDING_INVITES",
		"PLAYER_ENTERING_WORLD"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		hideMinimapCalendar = false,
		shortBroker = false,
		shortEvents = true,
		showEvents = true,
		singleLineEvents = false
	},
	config_allowed = nil,
	config_header = nil, -- use default header
	config_broker = {
		{ type="toggle", name="shortBroker", label=L["Shorter Broker"], tooltip=L["Reduce the broker text to a number without text"], event=true },
	},
	config_tooltip = {
		{ type="toggle", name="showEvents",  label=L["Show events"], tooltip=L["Display a list of events in tooltip"]},
		{ type="toggle", name="shortEvents", label=L["Shorter Events"], tooltip=L["Reduce event list height in tooltip"] },
		{ type="toggle", name="singleLineEvents", label=L["One event per line"], tooltip=L["Display event title and start/end date in a single line in tooltip"]}
	},
	config_misc = {
		{ type="toggle", name="hideMinimapCalendar", label=L["Hide calendar button"], tooltip=L["Hide Blizzard's minimap calendar button"],
			disabled = function()
				if (ns.coexist.found~=false) then
					return L["This option is disabled"],L[coexist_tooltip[ns.coexist.found]]:format(ns.coexist.found);
				end
				return false;
			end
		},
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

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	local _=function(y,m,d) return y*10000+m*100+d; end
	if (ns.tooltipChkOnShowModifier(false)) then tooltip:Hide(); return; end

	local numInvites = CalendarGetNumPendingInvites()
	local weekday, month, day, year = CalendarGetDate();
	local today=_(year,month,day);

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",L[name]),C("ltgreen",(" %d-%02d-%02d"):format(year,month,day)));
	tt:AddSeparator();

	if numInvites == 0 then
		tt:AddLine(C("ltgray",L["No invitations found"].."."));
	else
		tt:AddLine(C("white",numInvites.." "..(numInvites==1 and L["Invitation"] or L["Invitations"])));
	end

	if ns.profile[name].showEvents then
		--- collect events of this month
		local holidays = {};
		local NameToIndex={};
		local fDate = "%04d-%02d-%02d %02d:%02d";
		for i,monthOffset in ipairs({-1,0,1})do
			local month, year, numDays, firstWeekday = CalendarGetMonth(monthOffset);
			for day=1, numDays do
				local numEvents = CalendarGetNumDayEvents(monthOffset, day);
				for eIndex=1, numEvents do
					local title, hour, minute, calendarType, sequenceType, eventType, eventTexture = CalendarGetDayEvent(monthOffset, day, eIndex);
					if(title)then
						local u = (type(eventTexture)=="string" and eventTexture:match("calendar_weekend(.*)"))
							or calendar_weekend_texture_ids[eventTexture]
							or false;
						local unique = u and title..u or false;
						if(sequenceType=="START")then
							tinsert(holidays,{
								title=title,
								startStr=fDate:format(year,month,day,hour,minute),
								startNum=_(year,month,day),
								stopStr="",
								stopNum=0,
								state=4,
								unique = unique
							});
							NameToIndex[unique or title]=#holidays;
						end
						if(sequenceType=="END" and NameToIndex[unique or title])then
							local I = NameToIndex[unique or title];
							holidays[I].stopStr=fDate:format(year,month,day,hour,minute);
							holidays[I].stopNum=_(year,month,day);

							if(today>holidays[I].stopNum)then
								holidays[I].state=0; -- past
							elseif(today>=holidays[I].startNum and today<=holidays[I].stopNum)then
								holidays[I].state=1; -- current
							else
								holidays[I].state=2; -- future
							end

							NameToIndex[unique or title]=nil;
						end
					end
				end
			end
		end

		if #holidays>0 then
			local separator,soon = false;
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("dkyellow",EVENTS_LABEL));
			tt:AddSeparator();
			for i,v in ipairs(holidays)do
				if(v.state>0)then
					if(ns.profile[name].shortEvents)then
						if ns.profile[name].singleLineEvents then
							tt:AddLine(
								C("ltblue",v.title).." "..( (v.state==1 and C("green",L["(current)"])) or (v.state==2 and not soon and C("yellow",L["(soon)"])) or " " ),
								C("ltyellow",v.startStr.." "..L["to"].." "..v.stopStr)
							);
						else
							if separator then
								tt:AddSeparator(1,.64,.64,.64,1);
							end
							tt:SetCell(tt:AddLine(),1,C("ltblue",v.title).." "..( (v.state==1 and C("green",L["(current)"])) or (v.state==2 and not soon and C("yellow",L["(soon)"])) or " " ),nil,nil,ttColumns);
							tt:AddLine(C("ltyellow",v.startStr),C("ltyellow",v.stopStr));
						end
					else
						if ns.profile[name].singleLineEvents then
							if separator then
								tt:AddSeparator(4,0,0,0,0);
							end
							tt:AddLine(C("ltblue",v.title),C("ltyellow",v.startStr));
							tt:AddLine( (v.state==1 and C("green",L["(current)"])) or (v.state==2 and not soon and C("yellow",L["(soon)"])) or " ",C("ltyellow",L["to"].." "..v.stopStr));
						else
							if separator then
								tt:AddSeparator(1,.64,.64,.64,1);
							end
							tt:SetCell(tt:AddLine(),1,C("ltblue",v.title),nil,nil,ttColumns);
							tt:AddLine(C("ltyellow",v.startStr),C("ltyellow",v.stopStr));
						end
					end
					if(v.state==2)then
						soon=1;
					end
					separator = true;
				end
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		ns.clickOptions.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules[name].init = function() end

ns.modules[name].onevent = function(self,event,msg)
	self.obj = self.obj or ns.LDB:GetDataObjectByName(ns.modules[name].ldbName);
	local num = CalendarGetNumPendingInvites();

	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	end

	local icon = I(name..(num~=0 and "_pending" or ""))
	self.obj.iconCoords = icon.coords
	self.obj.icon = icon.iconfile

	-- %d |4Invite:Invites; ?
	local inv = " "..L[ num==1 and "Invite" or "Invites" ]
	if (ns.profile[name].shortBroker) then
		inv = ""
	end

	if num==0 then
		self.obj.text = num..inv;
	else
		self.obj.text = C("green",num..inv);
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT"},{true},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self) end
-- ns.modules[name].ondblclick = function(self,button) end

ns.modules[name].coexist = function()
	if (not ns.coexist.found) and (ns.profile[name].hideMinimapCalendar) then
		GameTimeFrame:Hide();
		GameTimeFrame.Show = dummyFunc;
	end
end
