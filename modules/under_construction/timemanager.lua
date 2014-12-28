
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
calendarDB = {}


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Time manager" -- L["Time manager"]
local ldbName = name
local dayStart,dayStop,dayN = time({year=0,month=0,day=0,hour=0,min=0,sec=0}),time({year=0,month=0,day=0,hour=23,min=59,sec=59}),86400
local GetGameTime,CalendarGetMonth = GetGameTime,CalendarGetMonth
local CalendarGetNumDayEvents, CalendarGetDayEvent = CalendarGetNumDayEvents, CalendarGetDayEvent
local scanTooltip = CreateFrame("GameTooltip",addon.."_"..name.."_ScanTooltip",UIParent,"GameTooltipTemplate")
scanTooltip:SetScale(0.0001)
scanTooltip:Hide()
local player, tt, tt2, tt3, counter
local ttName, ttName2 = name.."TT", name.."TT2"
local numDungeons, numRaids, numChallenges, numUnknown
local instances, bosses = {},{}
local timer,counter = {},{}
local eTypes = {
	[CALENDAR_EVENTTYPE_RAID]    = L["Raid"],
	[CALENDAR_EVENTTYPE_DUNGEON] = L["Dungeon"],
	[CALENDAR_EVENTTYPE_PVP]     = L["PvP"],
	[CALENDAR_EVENTTYPE_MEETING] = L["Meeting"],
	[CALENDAR_EVENTTYPE_OTHER]   = L["Other"]
}
local iTypes = {
	[CALENDAR_INVITESTATUS_INVITED]      = L["Invited"],
	[CALENDAR_INVITESTATUS_ACCEPTED]     = L["Accepted"],
	[CALENDAR_INVITESTATUS_DECLINED]     = L["Declined"],
	[CALENDAR_INVITESTATUS_CONFIRMED]    = L["Confirmed"],
	[CALENDAR_INVITESTATUS_OUT]          = L["Out"],
	[CALENDAR_INVITESTATUS_STANDBY]      = L["Standby"],
	[CALENDAR_INVITESTATUS_SIGNEDUP]     = L["Signedup"],
	[CALENDAR_INVITESTATUS_NOT_SIGNEDUP] = L["Not signedup"],
	[CALENDAR_INVITESTATUS_TENTATIVE]    = L["Tentative"]
}
local custom_cTypes = {
	WORLDBOSS_KILL    = true,
	WORLDBOSS_BONUS   = true,
	RAIDBOSS_KILL     = true,
	RAIDBOSS_BONUS    = true
}


---------------------------------------
-- module variables for registration --
---------------------------------------
I[name] = {iconfile=[[interface\icons\inv_misc_pocketwatch_01]],coords={0.05,0.95,0.05,0.95}}

ns.modules[name] = {
	desc = L["-"],
	events = {
		--"CALENDAR_ACTION_PENDING",
		--"CALENDAR_CLOSE_EVENT",
		"CALENDAR_EVENT_ALARM",
		"CALENDAR_NEW_EVENT",
		"CALENDAR_OPEN_EVENT",
		"CALENDAR_UPDATE_EVENT",
		"CALENDAR_UPDATE_EVENT_LIST",
		"CALENDAR_UPDATE_GUILD_EVENTS",
		"CALENDAR_UPDATE_INVITE_LIST",
		"CALENDAR_UPDATE_PENDING_INVITES",
		"PLAYER_ENTERING_WORLD"
	},
	updateinterval = 10,
	timeout = 20,
	timeout_used = false,
	timeout_args = nil,
	config_defaults = {
		format24 = true,
		showSeconds = false
	},
	config_allowed = {},
	config = {
		height = 62,
		elements = {
			{
				type = "check",
				name = "format24",
				label = L["24 hours mode"], -- TIMEMANAGER_24HOURMODE
				desc = L["Switch between time format 24 hours and 12 hours with AM/PM"],
			},
			{
				type = "check",
				name = "showSeconds",
				label = L["Show seconds"],
				desc = L["Display the time with seconds in broker button and tooltip"]
			},
		}
	}
}


--------------------------
-- some local functions --
--------------------------
local function scanInstances()
	numDungeons, numRaids,numChallenges,numUnknown = 0,0,0,0
	for i=1, GetNumSavedInstances() do
		local instanceName, instanceID, instanceReset, instanceDifficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)
		if instanceReset>0 then
			scanTooltip:Show()
			scanTooltip:SetOwner(UIParent,"LEFT",0,0)
			scanTooltip:SetInstanceLockEncountersComplete(i)
			local reg,data,line = {scanTooltip:GetRegions()},{},1
			local n,nc
			for k,v in pairs(reg) do
				if v~=nil and v:GetObjectType()=="FontString" and v:GetText()~=nil then
					if line>1 then
						if line/2==floor(line/2) then
							n = v:GetText()
						else
							tinsert(data,{n,({v:GetTextColor()})[0]~=0})
						end
					end
					line = line + 1
				end
			end
			scanTooltip:ClearLines()
			scanTooltip:Hide()
			if instanceDifficulty<=2 then
				numDungeons = numDungeons+1
			elseif instanceDifficulty==8 then
				numChallenges = numChallenges+1
			elseif instanceDifficulty<=9 then
				numRaids = numRaids+1
			else
				numUnknown = numUnknown+1
				ns.print(name,"unknown",numUnknown)
			end
			if instances[instanceDifficulty]==nil then instances[instanceDifficulty]={} end
			instances[instanceDifficulty][instanceID] = {
				instanceName		= instanceName,
				instanceReset		= instanceReset,
				extended			= extended,
				maxPlayers			= maxPlayers,
				difficultyName		= difficultyName,
				numEncounters		= numEncounters~=0 and numEncounters or "a",
				encounterProgress	= numEncounters~=0 and encounterProgress or "n",
				encounters			= data
			}
		end
	end
end

local function scanBosses()
	bosses = {}
	for i=1, GetNumSavedWorldBosses() do
		local n,id,r = GetSavedWorldBossInfo(i)
		local d = {name=n,id=id,reset=r}
		if type(r)=="number" and r>0 then
			tinsert(bosses,d)
		end
	end
end

local function cleanOutdated()
	local outoftime = time() - (60*60*24) -- 24 hours

	if calendarDB.charCalendar~=nil then
		for charName,charEntries in pairs(calendarDB.charCalendar) do
			for I,V in pairs(charEntries) do
				
			end
		end
	end

end

local function scanCalendar() -- scan calendar of current character
	local weekday, _month, day, year = CalendarGetDate()
	local t,h = {},{}

	-- catch all events from blizzards calendar
	for mOffset=0, 3 do
		local month, year, numdays, firstday = CalendarGetMonth(mOffset)
		for dayI = mOffset==0 and day or 1, numdays do
			for eventI=1, CalendarGetNumDayEvents(mOffset,dayI) do
				local title, hour, minute, calendarType, sequenceType, eventType, _, _, inviteStatus, invitedBy, _, inviteType, _, _, _ = CalendarGetDayEvent(mOffset, dayI, eventI)
				if calendarType~="HOLIDAY" and calendarType~="RAID_LOCKOUT" then
					local timeStamp = time({year=year, month=month, day=dayI, hour=hour, min=minute, sec=0})
					local id = year..month..dayI..title

					--tinsert(t,{
					calendarDB["charCalendar"][player][id] = {
						title     = title,
						cType     = calendarType,
						eType     = eventType,
						iStatus   = inviteStatus,
						iBy       = invitedBy,
						iType     = inviteType,
						timeStamp = timeStamp
					} --)

					if timer[timeStamp]==nil then timer[timeStamp] = {} end
					tinsert(timer[timeStamp],player)

					local YMD = ("%d-%d-%d"):format(year,month,dayI)
					if counter[player]==nil then counter[player] = {[YMD]=0} end
					if counter[player][YMD]==nil then counter[player][YMD]=0 end
					counter[player][YMD] = counter[player][YMD] + 1
				end
			end
		end
	end

	cleanOutdated()
end

local function getCount(field)
	scanInstances()
	scanBosses()

	if     field=="ev" then -- events
		
	elseif field=="ge" then -- guild events
		
	elseif field=="ga" then -- guild announcements
		
	elseif field=="wb" then -- world boss
		return #bosses
	elseif field=="ra" then -- raid (10/25/40)
		return numRaids
	elseif field=="rb" then -- raid (browser)
		-- coming soon?
	elseif field=="rf" then -- raid (flexibel)
		-- coming soon?
	elseif field=="du" then -- dungeon
		return numDungeons
	elseif field=="cm" then -- challenge mode
		return  numChallenges
	elseif field=="unknown" then
		return numUnknown
	end

	return "n/a"
end

local function makeTooltip2(self, objType, obj, subobj)
	local l,c,_,setup
	local count, cells = 0,4

	if objType=="c" then
		cells=5
		setup = {name.."TT2", 5, "LEFT", "LEFT", "LEFT", "RIGHT", "RIGHT"}
	else

		setup = {name.."TT2", 4, "LEFT", "LEFT", "CENTER", "RIGHT"}
	end

	tt2 = ns.LQT:Acquire(unpack(setup))
	tt2:Clear()

	l,c = tt2:AddLine()
	tt2:SetCell(l,1,C("dkyellow",
		(obj=="ev" and "Events")              or
		(obj=="ge" and "Guild events")        or
		(obj=="ga" and "Guild announcements") or
		(obj=="wb" and "World bosses")        or
		(obj=="ra" and "Raids")               or
		(obj=="rb" and "Raids (LFR)")         or
		(obj=="rf" and "Raids (Flex)")        or
		(obj=="du" and "Dungeons")            or
		(obj=="cm" and "Challenge mode")      or
		"Unknown"
	),tt2:GetHeaderFont(),nil,cells)
	tt2:AddSeparator(3,0,0,0,0)

	if objType=="c" then
		tt2:AddLine(C("ltblue",L["Title"]), C("ltblue",L["Invited with"]), C("ltblue",L["My status"]), C("ltblue",L["Invite status"]), C("ltblue",L["Time to event"]))
		tt2:AddSeparator()

		if subobj==0 then
		--[[ today ]]
			-- 1 -- Event title
			-- 2 -- Invited Chars
			-- 3 -- My status
			-- 4 -- Invite status (<accepted>/<unstable>/<denied>/<invited>)
			-- 5 -- SecondsToTime ^^
		elseif subobj==1 then
		--[[ Future ]]
			-- 1 -- Event title
			-- 2 -- Invited Chars
			-- 3 -- My status
			-- 4 -- Invite status (<accepted>/<unstable>/<denied>/<invited>)
			-- 5 -- Date/Time
		end

		if count==0 then
			tt2:AddLine(L["Nothing..."])
		end

	elseif objType=="b" then
		tt2:AddLine(C("ltblue",L["Name"]),"","",C("ltblue",L["Reset in"]))
		tt2:AddSeparator()

		for i,v in ipairs(bosses) do
			if count>0 then tt2:AddSeparator() end
			tt2:AddLine(v.name,"","",SecondsToTime(v.reset))
			count=count+1
		end
		if count==0 then
			tt2:AddLine(L["Nothing found..."])
		end

	elseif objType=="i" then
		tt2:AddLine(C("ltblue",L["Name"]),C("ltblue",L["Type"]),C("ltblue",L["Bosses"]),C("ltblue",L["Reset in"]))
		tt2:AddSeparator()

		local selection = ( (obj=="ra" and {3,4,5,6,7,9}) or
							(obj=="du" and {1,2}) or
							(obj=="cm" and {8}) or
							{} )

		for _,I in ipairs(selection) do
			if type(instances[I])=="table" then
				for i,v in pairs(instances[I]) do
					if count>0 then tt2:AddSeparator() end
					tt2:AddLine(C("ltyellow",v.instanceName),v.difficultyName,("%s/%s"):format(v.encounterProgress,v.numEncounters),SecondsToTime(v.instanceReset))
					count=count+1
				end
			end
		end
		if count==0 then
			tt2:AddLine(L["Nothing found..."])
		end
	end

	ns.createTooltip(self, tt2)
	tt2:ClearAllPoints()
	tt2:SetPoint("TOP",self,"TOP",0,0)

	local tL,tR,tT,tB = ns.getBorderPositions(tt)
	local uW = UIParent:GetWidth()
	if tR<(uW/2) then
		tt2:SetPoint("RIGHT",tt,"LEFT",-2,0)
	else
		tt2:SetPoint("LEFT",tt,"RIGHT",2,0)
	end
end

local function leave_tt2(self)
	if tt2 then 
		if MouseIsOver(tt2) then
			ns.hideTooltip(tt2)
			tt2:SetScript('OnLeave', ns.hideTooltip)
		else
			ns.hideTooltip(tt2,ttName2)
		end
	end
end

local function makeTooltip()
	if not (tt~=nil and tt.key~=nil and tt.key==name.."TT") then return end
	local h24 = Broker_EverythingDB[name].format24
	local dSec = Broker_EverythingDB[name].showSeconds
	local l,c
	local clocks = {
		l = ns.LT.GetTimeString("GetLocalTime",h24,dSec),
		s = ns.LT.GetTimeString("GetGameTime",h24,dSec),
		u = ns.LT.GetTimeString("GetUTCTime",h24,dSec)
	}

	tt:Clear()

	tt:AddHeader(C("dkyellow",L[name]))

	local ttlines = {
		{sep={3,0,0,0,0}},
		{line={C("ltblue",L["Time"])}},
		{sep={1}},
		{lines={C("ltyellow",L["Locale:"]),	clocks.l}},
		{lines={C("ltyellow",L["Server:"]),	clocks.s}},
		{lines={C("ltyellow",L["UTC:"]),	clocks.u}},

		{sep={3,0,0,0,0}},
		{lines={C("ltblue",L["Today"]),C("ltblue",date("%Y-%m-%d"))}},
		{sep={1}},
		{lines={C("ltyellow",L["Events"]),              getCount("ev",0)}, tt2={nil,"c","ev",0}},
		{lines={C("ltyellow",L["Guild events"]),        getCount("ge",0)}, tt2={nil,"c","ge",0}},
		{lines={C("ltyellow",L["Guild announcements"]), getCount("ga",0)}, tt2={nil,"c","ga",0}},

		{sep={3,0,0,0,0}},
		{lines={C("ltblue",L["Future"])}},
		{sep={1}},
		{lines={C("ltyellow",L["Events"]),              getCount("ev",2)}, tt2={nil,"c","ev",1}},
		{lines={C("ltyellow",L["Guild events"]),        getCount("ge",2)}, tt2={nil,"c","ge",1}},
		{lines={C("ltyellow",L["Guild announcements"]), getCount("ga",2)}, tt2={nil,"c","ga",1}},

		{sep={3,0,0,0,0}},
		{lines={C("ltblue",L["ID's"]),C(ns.player.class,ns.player.name)}},
		{sep={1}},
		{lines={C("ltyellow",L["Worldbosses"]),         getCount("wb")}, tt2={nil,"b","wb"}},
		{lines={C("ltyellow",L["Raids (10/25)"]),       getCount("ra")}, tt2={nil,"i","ra"}},
		--{lines={C("ltyellow",L["Raids (Flex)"]),        getCount("fl")}, tt2={nil,"i","rf"}},
		--{lines={C("ltyellow",L["Raids (LFR)"]),         getCount("rb")}, tt2={nil,"i","rb"}},
		{lines={C("ltyellow",L["Dungeons"]),            getCount("du")}, tt2={nil,"i","du"}},
		--{lines={C("ltyellow",L["Challenge mode"]),      getCount("du")}, tt2={nil,"i","cm"}},
	}

	for i,v in ipairs(ttlines) do
		if v.sep~=nil then
			tt:AddSeparator(unpack(v.sep))
		elseif v.line~=nil then
			tt:AddLine(unpack(v.line))
		elseif v.lines~=nil then
			local l,c = tt:AddLine()
			for i,v in pairs(v.lines) do
				tt:SetCell(l,i,v,header==true and tt:GetHeaderFont() or nil)
			end
			if v.tt2 then
				tt:SetLineScript(l,"OnEnter",function(self) v.tt2[1]=self; makeTooltip2(unpack(v.tt2)); end)
				tt:SetLineScript(l,"OnLeave",leave_tt2)
			end
		end
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	if obj~=nil then return end
	player = GetUnitName("player", true)
end

ns.modules[name].onevent = function(self,event,...)
	if event == "PLAYER_ENTERING_WORLD" then
		for i,v in pairs({charCalendar={[player]={}},raidids={},worldbossids={},flexbossids={},lfrbossids={},dungeonids={},lastchanged={}})
		do if calendarDB[i]==nil then calendarDB[i] = v end end
		if calendarDB["charCalendar"][player]==nil then calendarDB["charCalendar"][player]={} end
		GameTimeFrame:Click()
		GameTimeFrame:Click()
	--elseif iEventDetails~=false and event=="BE_CALENDAR_OPEN_EVENT_NEXT" then
		--[[
		local obj = iEventDetails[iEventDetailsIndex]
		if CalendarFrame~=nil and not CalendarFrame:IsShown() then
			wipe(iEventDetails)
			iEventDetailsIndex = false
		else
			CalendarOpenEvent(obj.month,obj.day,obj.eIndex)
		end
		]]
	--elseif event=="CALENDAR_OPEN_EVENT" then
		--catchInvites()
	else --if iEventDetailsIndex==false then
		scanCalendar()
	end
end

ns.modules[name].onupdate = function(self)
	if tt~=nil and tt.key==name.."TT" then
		makeTooltip(tt)
	end
end

--[[ ns.modules[name].optionspanel = function(panel) end ]]

--[[ ns.modules[name].onmousewheel = function(self,direction) end ]]

--[[ ns.modules[name].ontooltip = function(tooltip) end ]]


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(name.."TT", 2, "LEFT", "RIGHT")
	makeTooltip(tt)
	ns.createTooltip(self, tt)
end

ns.modules[name].onleave = function(self)
	if tt then 
		ns.hideTooltip(tt,ttName)
	end
end

--[[ ns.modules[name].onclick = function(self,button) end ]]

--[[ ns.modules[name].ondblclick = function(self,button) end ]]


--[=[
	

notes:
	time manager
		sep
		clock + date
			sep
			ServerTime: | <number>
			LocalTime:  | <number>
		calendar
			(realm/char independent calendar)
		worldbossloots
		raidid's (subTT: bosskills per raid?)
		char level playtime? ^^
]=]


--[[

-- init value
	CALENDAR_INVITESTATUS_INVITED      = 1	yellow

-- user changes
	CALENDAR_INVITESTATUS_TENTATIVE    = 9	orange
	CALENDAR_INVITESTATUS_DECLINED     = 3	red
	CALENDAR_INVITESTATUS_ACCEPTED     = 2	green

-- mod changes [ mod ...StatusContextMenu ]
	CALENDAR_INVITESTATUS_CONFIRMED    = 4	green
	CALENDAR_INVITESTATUS_OUT          = 5	red
	CALENDAR_INVITESTATUS_SIGNEDUP     = 7	green
	CALENDAR_INVITESTATUS_NOT_SIGNEDUP = 8	red
	CALENDAR_INVITESTATUS_STANDBY      = 6	orange

]]

--[[

calendardb[calendar][<%Y%m%d>_<char>_<title>] = {
	["iStatus"] = 
	["title"] = 
	["iBy"] = 
	["cType"] = 
	["timeStamp"] =
	["eType"] = 
	["iType"] = 
}

]]
