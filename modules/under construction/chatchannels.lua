
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "ChatChannels" -- L["ChatChannels"]
local ldbName = name
local tt


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="Interface\\chatframe\\ui-chatwhispericon"}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Display chat channels with a list of users."],
	--icon_suffix = '',
	events = {
		"PLAYER_ENTERING_WORLD",
		"PARTY_LEADER_CHANGED",
		"GROUP_ROSTER_UPDATE",
		"CHANNEL_UI_UPDATE",
		"MUTELIST_UPDATE",
		"IGNORELIST_UPDATE",
		--"CHANNEL_FLAGS_UPDATED",
		--"CHANNEL_VOICE_UPDATE",
		"CHANNEL_COUNT_UPDATE",
		"CHANNEL_ROSTER_UPDATE"
	},
	updateinterval = false, -- 10
	config_defaults = {},
	config_allowed = {},
	config = nil -- {}
}


--------------------------
-- some local functions --
--------------------------

local function updateChannels(x,y)
end

local function updateList()
end

local function updateRoster(chan)
end

local function update()
	local id = GetSelectedDisplayChannel()
	updateList()
	updateRoster(id)
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,...)
	local arg1, arg2, arg3 = ...
	if ({PLAYER_ENTERING_WORLD=1,CHANNEL_UI_UPDATE=1,PARTY_LEADER_CHANGED=1,GROUP_ROSTER_UPDATE=1})[event]==1 then
		update()
	--elseif event=="CHANNEL_FLAGS_UPDATED" then
	--elseif event=="CHANNEL_VOICE_UPDATE" then
	elseif event=="CHANNEL_COUNT_UPDATE" then
		updateChannels(arg1,arg2)
	elseif event=="CHANNEL_ROSTER_UPDATE" then
		updateRoster(arg1)
	elseif ({MUTELIST_UPDATE=1,IGNORELIST_UPDATE=1})[event]==1 then
		updateRoster(GetSelectedDisplayChannel())
	end
end

--[[ ns.modules[name].onupdate = function(self,elapsed) end ]]

--[[ ns.modules[name].optionspanel = function(panel) end ]]

--[[ ns.modules[name].onmousewheel = function(self,direction) end ]]

--[[ ns.modules[name].ontooltip = function(tooltip) end ]]


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(name.."TT", 2, "LEFT", "RIGHT")
	--getTooltip(self,tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if tt then 
		ns.hideTooltip(tt,name)
	end
end

ns.modules[name].onclick = function(self,button)
	if button=="LeftButton" then
	elseif button=="RightButton" then
	end
end

--[[ ns.modules[name].ondblclick = function(self,button) end ]]


