
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
if ns.build>70000000 then return end
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Dualspec" -- L["Dualspec"]
local tt = nil
local unspent = 0
local specs = {}


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=134942,coords={0.05,0.95,0.05,0.95}}; --IconName::Dualspec--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show and switch your character specializations"],
	events = {
		"PLAYER_LOGIN",
		"ACTIVE_TALENT_GROUP_CHANGED",
		"PLAYER_ENTERING_WORLD",
		"SKILL_LINES_CHANGED",
		"CHARACTER_POINTS_CHANGED",
		"PLAYER_TALENT_UPDATE",
	},
	updateinterval = nil, -- 10
	config_defaults = {
		
	},
	config_allowed = nil,
	config_header = nil, -- use default header
	config_broker = nil,
	config_tooltip = nil,
	config_misc = nil,
}


--------------------------
-- some local functions --
--------------------------



------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules[name].init = function() end

ns.modules[name].onevent = function(self,event,msg)
	local specName = L["No Spec!"]
	local icon = I(name)
	local spec = GetSpecialization()
	local _ = nil
	local dataobj = self.obj or ns.LDB:GetDataObjectByName(ns.modules[name].ldbName)
	unspent = GetNumUnspentTalents()

	if spec ~= nil then
		 _, specName, _, icon.iconfile, _, _ = GetSpecializationInfo(spec)
	end

	dataobj.iconCoords = icon.coords
	dataobj.icon = icon.iconfile

	if unspent~=0 then
		dataobj.text = C("ltred",UNSPENT_TALENT_POINTS:format(unspent))
	else
		dataobj.text = specName
	end

end

-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].optionspanel = function(panel) end

ns.modules[name].ontooltip = function(tt)
	if (ns.tooltipChkOnShowModifier(false)) then tt:Hide(); return; end

	ns.tooltipScaling(tt)
	tt:AddLine(TALENTS)

	local activeSpec = GetSpecialization()
	local numberSpecs = GetNumSpecializations()
	local specs = { }
		
	for i=1, numberSpecs do
		specs["spec" .. i] = GetSpecialization(false,false,i)
	end

	if specs.spec1 == nil and specs.spec2 == nil then
		tt:AddLine(L["No specialisation found"])
	else
		for k, v in pairs(specs) do
			local _, specName, _, icon, _, _ = GetSpecializationInfo(v)
			if v == activeSpec then
				tt:AddDoubleLine(specName, L["Active"])
			else
				tt:AddDoubleLine(specName, "")
			end

			tt:AddTexture(icon)
		end
	end

	if unspent ~= 0 then
		tt:AddLine(" ")
		tt:AddLine(C("ltred",string.format(unspent==1 and L["%d unspent talent"] or L["%d unspent talents"],unspent)))
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddLine(" ")
		tt:AddLine(C("copper",L["Left-click"]).." || "..C("green",L["Open talents pane"]))
		tt:AddLine(C("copper",L["Right-click"]).." || "..C("green",L["Switch spec."]))
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
-- ns.modules[name].onenter = function(self) end
-- ns.modules[name].onleave = function(self) end

ns.modules[name].onclick = function(self,button)
	if button == "RightButton" then
		securecall("SetActiveSpecGroup",abs(GetActiveSpecGroup()-3))
	else
		if not PlayerTalentFrame then UIParentLoadAddOn("Blizzard_TalentUI") end
		securecall("ToggleTalentFrame")
	end
end

-- ns.modules[name].ondblclick = function(self,button) end
