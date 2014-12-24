
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
notesDB, notesGlobalDB = {}, {}


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Notes" -- L["Notes"]
local ldbName = name


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="Interface\\icons\\inv_misc_note_03",coords={0.05,0.95,0.05,0.95}}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["..."],
	events = {},
	updateinterval = nil, -- 10
	config_defaults = {},
	config_allowed = {},
	config = nil
}


--------------------------
-- some local functions --
--------------------------


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

--[[ ns.modules[name].onevent = function(self,event,...)  end ]]

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

	[BrokerButton]
		[tooltip1]
			L[name]
			-------------
			<list of notes> (20 per page)
			-------------
			<page toggles>

			<list of notes entry>
				[tooltip2:mouseover]
					<name of note>
					-------------------
					<content of note>
					-------------------
					[space]
					L[Options]
					----------------
					L[Post in] >
						[tooltip3:mouseover]
							Say
							Group
							Guild
							Raid
							RaidWarning
							Instance
							Whisper to target
					L[Run as Macro]
					L[Edit]
					L[Delete]
 

]]