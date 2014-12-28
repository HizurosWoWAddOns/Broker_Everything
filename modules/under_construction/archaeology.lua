
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Archaeology" -- L["Archaeology"]
L[name] = GetArchaeologyInfo()
local ldbName = name
local tt -- tooltip
local skill
local races = {}
local maxFragments = 200

-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name]  = {iconfile="Interface\\Addons\\"..addon.."\\media\\icon-Neutral"}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show your archaeology artifacts."],
	icon_suffix = "_Neutral",
	events = {
		"PLAYER_ENTERING_WORLD",
		"KNOWN_CURRENCY_TYPES_UPDATE",
		"ARTIFACT_UPDATE",
		"ARTIFACT_COMPLETE",
		"CURRENCY_DISPLAY_UPDATE",
		"CHAT_MSG_SKILL"
	},
	updateinterval = nil,
	config_defaults = {
		inTitle = {}
	},
	config_allowed = {
		subTTposition = {["AUTO"]=true,["TOP"]=true,["LEFT"]=true,["RIGHT"]=true,["BOTTOM"]=true}
	},
	config = nil
	--[[
	config = {
		height = 52,
		elements = {
			{
				type	= "dropdown",
				name	= "subTTposition",
				label	= L["Second tooltip"],
				desc	= L["Where does the second tooltip for a single currency are displayed from the first tooltip"],
				values	= {
					["AUTO"]    = L["Auto"],
					["TOP"]     = L["Over"],
					["LEFT"]    = L["Left"],
					["RIGHT"]   = L["Right"],
					["BOTTOM"]  = L["Under"]
				},
				default = "AUTO",
				disabled = true
			}
		}
	}
	]]
}


--------------------------
-- some local functions --
--------------------------
function updateFragments()
	local raceName, raceTexture, raceItemID, numFragmentsCollected, numFragmentsRequired
	local numRaces = GetNumArchaeologyRaces()
	for i=1, numRaces do
		raceName, raceTexture, raceItemID, numFragmentsCollected, numFragmentsRequired = GetArchaeologyRaceInfo(i)
		races[i] = {
			name = raceName,
			icon = raceTexture,
			keystone = raceItemID,
			count = numFragmentsCollected,
			need = numFragmentsRequired
		}
	end
end

function updateTooltip()
end

function updateBroker()
--	local obj = ns.LDB:GetDataObjectByName(ldbName)
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)

	local skillLevel, maxSkillLevel,_
	local arch = select(3,GetProfessions())
	if (arch) then
		_, _, skillLevel, maxSkillLevel = GetProfessionInfo(arch)
		--updateFragments()
		--updateTooltip()
		--updateBroker()
	end

	local obj = ns.LDB:GetDataObjectByName(ldbName)
	obj.text = (skillLevel) and ("%d/%d"):format(skillLevel,maxSkillLevel) or L[name];

end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)

	tt:Clear()
	tt:AddHeader(C("dkyellow",L[name]), C("white","?/?"))
	tt:AddSeparator()

	local currencyName, currentAmount, texture, earnedThisWeek, weeklyMax, totalMax, isDiscovered
	local arch = select(3,GetProfessions())
	if (arch) then
		local name, icon, skill, maxSkill = GetProfessionInfo(arch);
		print(name, x, skill, maxSkill);
	end
--	for i,v in pairs(currency.archaeology) do
--		currencyName, currentAmount, texture, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(i)
--		tt:AddLine(C("ltyellow",currencyName),currentAmount.." |T"..texture..":0|t")
--	end

	if false and Broker_EverythingDB.showHints then -- disabled
		tt:AddSeparator(3,0,0,0,0)
		local l,c = tt:AddLine()
		tt:SetCell(l,1,
			C("copper",L["Left-click"]).." || "..C("green",L["Open currency pane"])
			.."|n"..
			C("copper",L["Right-click"]).." || "..C("green",L["Currency in title - menu"]),
			nil,
			nil,
			2)
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(name.."TT", 2, "LEFT", "RIGHT")
	tt:Clear()
	ns.modules[name].ontooltip(tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if tt then
		ns.hideTooltip(tt,ttName)
	end
end

ns.modules[name].onclick = function(self,button)
	if button == "LeftButton" then
		--securecall("ToggleCharacter","TokenFrame")
		-- archaeology frame?
		-- check if loaded
			-- load addon
		--toggle frame...
	else
		if menu==nil then
			makeMenu(self)
		else
			menu:Hide()
			menu = nil
		end
	end
end

--[[ ns.modules[name].ondblclick = function(self,button) end ]]




--[[
IDEAS:
* get max count and weekly max count of a currency for displaying caped counts in red.

]]

--[[

brainstorming: (sry, german ^^)
	* eine manuelle list mit den currencyId's führen
	* nicht in der list befindliche currencies bekommen eine temporäre id in einer extra table
	* 

todo:
	[ ] existierende currency in title von name auf ID umstellen
	[ ] broker button anzeige auf nutzung von id's umstellen
	[ ] 

]]