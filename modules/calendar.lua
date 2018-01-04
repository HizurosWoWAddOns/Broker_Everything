
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Calendar" -- L["Calendar"]
local ttName,ttColumns,tt,module,calendar_weekend_texture_ids = name.."TT",2;


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\calendar"}; --IconName::Calendar--
I[name.."_pending"] = {iconfile="Interface\\Addons\\"..addon.."\\media\\calendar_pending"}; --IconName::Calendar_pending--


-- some local functions --
--------------------------
local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local num = CalendarGetNumPendingInvites();

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
		hideMinimapCalendar = false,
		shortBroker = false,
		shortEvents = true,
		showEvents = true,
		singleLineEvents = false
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
			showEvents={ type="toggle", order=1, name=L["Show events"], desc=L["Display a list of events in tooltip"]},
			shortEvents={ type="toggle", order=2, name=L["Shorter Events"], desc=L["Reduce event list height in tooltip"] },
			singleLineEvents={ type="toggle", order=3, name=L["One event per line"], desc=L["Display event title and start/end date in a single line in tooltip"]}
		},
		misc = {
			hideMinimapCalendar={ type="toggle", order=1, name=L["Hide calendar button"], desc=L["Hide Blizzard's minimap calendar button"], disabled=ns.coexist.check },
			hideMinimapCalendarInfo={ type="description", order=2, name=ns.coexist.optionInfo, fontSize="medium", hidden=ns.coexist.check }
		},
	}
end

function module.init()
	calendar_weekend_texture_ids = { -- Calendar_Weekend(.*)
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
	if ns.coexist.check() and ns.profile[name].hideMinimapCalendar then
		GameTimeFrame:Hide();
		GameTimeFrame.Show = dummyFunc;
	end
end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="BE_UPDATE_CFG" then
		if ns.coexist.check() then
			if ns.profile[name].hideMinimapCalendar then
				GameTimeFrame:Hide();
				GameTimeFrame.ShowOrig = GameTimeFrame.Show
				GameTimeFrame.Show = dummyFunc;
			else
				GameTimeFrame.Show = GameTimeFrame.ShowOrig
				GameTimeFrame.ShowOrig = nil;
				GameTimeFrame:Show();
			end
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
