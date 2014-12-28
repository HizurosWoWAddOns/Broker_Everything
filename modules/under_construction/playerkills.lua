
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
PlayerKillsDB = {}

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "PlayerKills" -- L["PlayerKills"]
local ldbName = name
local player, pet = UnitName("player"), UnitName("pet")
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local db = PlayerKillsDB
local cl_events = {["RANGE_DAMAGE"]=16, ["SPELL_DAMAGE"]=16, ["SWING_DAMAGE"]=13, ["PARTY_KILL"]=true}

-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="interface\\icons\\ability_hunter_snipershot",coords={0.05,0.95,0.05,0.95}}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["description coming soon"],
	events = {
		"COMBAT_LOG_EVENT_UNFILTERED"
	},
	updateinterval = nil, -- 10
	config = nil -- {}
}


--------------------------
-- some local functions --
--------------------------
local function add(killer,data)
	if #db[killer]>=30 then
		local t = {}
--		for i=#db[killer]-30
	end
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local timeStamp,clEvent,_,sGUID,sName,sFlags,_,dGUID,dName,dFlags = ...
		if cl_events[clEvent]~=nil then
			dFlags = bit.band(dFlags,COMBATLOG_OBJECT_TYPE_MASK)
			if dFlags==COMBATLOG_OBJECT_TYPE_PLAYER then
				if player==dName then
					local _, eClass, _, eRace, _, _, eRealm = GetPlayerInfoByGUID(sGUID)
					local killer,eName,eGUID = "killed_me",sName,sGUID
				else
					local _, eClass, _, eRace, _, _, eRealm = GetPlayerInfoByGUID(dGUID)
					local killer,eName,eGUID = "i_killed",dName,dGUID
				end
				if (type(cl_events[clEvent])=="number" and select(cl_events[clEvent],...)>=0) or cl_events[clEvent]==true then
					--add(killer, {time=timeStamp,guid=eGUID,name=eName,class=eClass,race=eRace,realm=eRealm or ns.realm})
					ns.print(killer,timeStamp,eGUID,eName,eClass,eRace,eRealm or ns.realm)
				end
			end
		end
	end
end

--[[ ns.modules[name].onupdate = function(self) end ]]

--[[ ns.modules[name].optionspanel = function(panel) end ]]

--[[ ns.modules[name].onmousewheel = function(self,direction) end ]]

--[[ ns.modules[name].ontooltip = function(tooltip) end ]]


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
--[[ ns.modules[name].onenter = function(self) end ]]

--[[ ns.modules[name].onleave = function(self) end ]]

--[[ ns.modules[name].onclick = function(self,button) end ]]

--[[ ns.modules[name].ondblclick = function(self,button) end ]]

--[[
						text = "Deaths";
						checked = function() return Blizzard_CombatLog_HasEvent (Blizzard_CombatLog_CurrentSettings, "UNIT_DIED", "UNIT_DESTROYED", "UNIT_DISSIPATES"); end;
						keepShownOnClick = true;
						func = function ( self, arg1, arg2, checked )
							Blizzard_CombatLog_MenuHelper ( checked, "UNIT_DIED", "UNIT_DESTROYED", "UNIT_DISSIPATES" );
						end;
					};
	elseif ( event == "PARTY_KILL" ) then	-- Unique Events
	

]]