
--[[
Name: LibTime-1.0
Revision: $Revision: 1 $
Author: Hizuro (hizuro@gmx.de)
Website: http://www.curseforge.com/projects/libtime-1-0/
Description: A little library around date, time and GetGameTime and more...
Dependencies: LibStub
License: GPL v2
]]

local MAJOR, MINOR = "LibTime-1.0", 1;
local lib = LibStub:NewLibrary(MAJOR, MINOR);

if not lib then return; end

local GetGameTime,date,time = GetGameTime,date,time;
local frame = CreateFrame("frame");
local sync = false;
local syncIt = false;
local minute = false;
local elapsed = 0;
local interval = 0.5;
local playedHide = false;
local playedEvent = false;
local playedTotal = 0;
local playedLevel = 0;
local playedSession = 0;
local playedTimeout = 20;
local playedTimeoutEvent = false;
local zf = function(n) return ("%02d"):format(n); end -- zerofilled
local orig_ChatFrame_DisplayTimePlayed = _G.ChatFrame_DisplayTimePlayed;

lib.countries = false;
lib.countriesBy = false;
lib.GetGameTime = nil;

--
-- event and update frame
--

_G.ChatFrame_DisplayTimePlayed = function(self,event,...)
	if (playedHide) then
		playedHide=false;
		_G.ChatFrame_DisplayTimePlayed = orig_ChatFrame_DisplayTimePlayed;
		return;
	end
	return orig_ChatFrame_DisplayTimePlayed(self,event,...);
end

frame:SetScript("OnUpdate",function(self,elapse)
	if (elapsed>=interval) then
		elapsed = 0
		if (lib.GetGameTime~=nil) then
			syncIt = true
			lib.GetGameTime()
		end
	end
	if (playedTimeoutEvent==true) and (playedTimeout~=false) then
		playedTimeout = playedTimeout - elapse;
		if playedTimeout<=0 then
			playedTimeout=false;
			playedHide = true;
			RequestTimePlayed();
		end
	end
	elapsed = elapsed + elapse
end)

frame:SetScript("OnEvent",function(self,event,...)
	if (event=="TIME_PLAYED_MSG") then
		playedTotal, playedLevel = ...
		playedSession = time()
		playedTimeout = false;
	elseif (event=="PLAYER_ENTERING_WORLD") then
		if (playedTimeoutEvent==false) then
			playedTimeoutEvent=true;
		end
	end
end)
frame:RegisterEvent("TIME_PLAYED_MSG")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")


--
-- library functions
--

--[[
	GetGameTime
	@return hours, minutes, seconds
	# hours [string] - zerofilled
	# minutes [string] - zerofilled
	# seconds [string] - zerofilled
]]
lib.GetGameTime = function()
	local hours, minutes, seconds = GetGameTime();

	if (seconds~=nil) then -- surprise. blizzard provide server side time with seconds? [maybe in future ^^]
		frame:SetScript("OnUpdate",nil);
		lib.GetGameTime = GetGameTime;
		return zf:format(hours), zf:format(minutes), zf:format(seconds);
	end

	if (minute==false) then
		minute = minutes;
	end

	if (syncIt==true) and (minute~=minutes) then
		interval = 1;
		minute = minutes;
		sync = time();
		syncIt = false;
	end

	return zf(hours), zf(minutes), zf( sync~=false and time()-sync or 0 )
end


--[[
	GetLocalTime
	@return hours, minutes, seconds
	# hours [string] - zerofilled
	# minutes [string] - zerofilled
	# seconds [string] - zerofilled
]]
lib.GetLocalTime = function()
	return date("%H"), date("%M"), date("%S");
end


--[[
	GetUTCTime
	@param time [number,optional]
	@return hours, minutes, seconds
	# hours [string] - zerofilled
	# minutes [string] - zerofilled
	# seconds [string] - zerofilled
]]
lib.GetUTCTime = function()
	return date("!%H"), date("!%M"), date("!%S");
end


--[[
	GetCountryTime
	@param country [string|number]
	@return hour, minute, second, daydiff, country name
	# hours [string] - zerofilled
	# minutes [string] - zerofilled
	# seconds [string] - zerofilled
	# daydiff [number] - -1 = yesterday. 1 = tomorrow. 0 = today
	# country name [string] - 
]]
lib.GetCountryTime = function(countryId)
	local cdata;
	if (lib.countries[countryId]~=nil) then
		cdata = lib.countries[country];
	end
	assert(type(cdata)=="table", "usage: <LibTime-1.0>.GetCountryTime(<countryId>)");
	
	local hours, minutes, seconds = lib.GetUTCTime();
	local x = date("*t");
	local t = ((hours*60*60) + (minutes*60) + seconds) + (3600*cdata[2]);
	if (x.isdst==true) and (cdata[3]==0) then
		t = t - 3600;
	end
	local daydiff = 0;
	if (t < 0) then
		t = t + 86400;
		daydiff = -1;
	elseif (t > 86400) then
		t = t - 86400;
		daydiff = 1;
	end

	local H = floor(t/60/60);
	local h = H*60*60;
	local M = floor((t-h)/60);
	local m = M*60;
	local S = t-h-m;

	return zf(H), zf(M), zf(S), daydiff, cdata[1];
end

--[[
	ListCountries
	@return [table|string]
]]
lib.ListCountries = function(id)
	local tmp={};
	for i,v in ipairs(lib.countries) do
		tinsert(tmp,v[1]);
	end
	return tmp;
end

--[[
	GetPlayedTime
	@return playedTotal, playedLevel, playedSession
]]
lib.GetPlayedTime = function()
	if (playedTimeoutEvent~=nil) then
		local session = time()-playedSession;
		return playedTotal + session, playedLevel + session, session; -- played time without use of RequestTimePlayed()
	else
		return false;
	end
end

--[[
	GetTimeString
	@param name of time   <GetGameTime|GetLocalTime|GetUTCTime|GetCountryTime>
	@param countryId      [number]  - only for use with GetCountryTime
	@param 24hours        [boolean] - optional, default = true
	@param displaySeconds [boolean] - optional, default = false
]]

lib.GetTimeString = function(...)
	local name,countryId,b24hours,displaySeconds

	name = ...
	if name == "GetCountryTime" then
		name,countryId,b24hours,displaySeconds = ...
	else
		name,b24hours,displaySeconds = ...
	end

	assert(lib[name]~=nil,"usage: <LibTime-1.0>.GetTimeString(<GetGameTime|GetLocalTime|GetUTCTime|GetCountryTime>[, <CountryId>][,<24hours boolean>[, <displaySeconds boolean>]])")

	local h,m,s = lib[name](countryId)

	local a = nil
	if b24hours==false then
		h = tonumber(h)
		a = "AM"
		if h >= 12 then h,a = h-12,"PM" end
		if h == 0 then h = 12 end
	end

	if displaySeconds==true then
		return (b24hours and "%02d:%02d:%02s" or "%02d:%02d:%02s %s"):format(h,m,s,a)
	else
		return (b24hours and "%02d:%02d" or "%02d:%02d %s"):format(h,m,a)
	end
end
