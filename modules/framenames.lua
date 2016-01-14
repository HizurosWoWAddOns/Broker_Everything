
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Framenames" -- L["Framenames"]
local ldbName,ttName,ldbObject = name,name.."TT"
local string = string


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\equip"}; --IconName::Framenames--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show names of frames under the mouse."],
	enabled = false,
	events = {},
	updateinterval = 0.05,
	config_defaults = nil,
	config_allowed = nil,
	config = { { type="header", label=L[name], align="left", icon=I[name] } }
}


--------------------------
-- some local functions --
--------------------------


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	if self then
		ldbObject = ldbObject or ns.LDB:GetDataObjectByName(ldbName);
		ldbObject.text = L[name];
	end
end

-- ns.modules[name].onevent = function(self,event,msg) end

ns.modules[name].onupdate = function(self)
	ldbObject = ldbObject or ns.LDB:GetDataObjectByName(ldbName);
	local F = nil
	local f = GetMouseFocus()
	if (not f) then
		if ldbObject.text~=L["Unknown"] then
			ldbObject.text = L["Unknown"]
		end
	else
		if f:IsForbidden() then
			F = "[Forbidden Frame]";
		elseif f:IsProtected() and InCombatLockdown() then
			F = "[Protected Frame]";
		else
			F = f:GetName();
			if F == nil and type(f.key)=="string" then -- LibQTip tooltips returns nil on GetName but f.key contains the current name
				F = f.key
			end
			if F == nil then
				F = "<anonym>";
				for i,v in pairs(f:GetParent() or {})do
					if(v==f)then
						F = "(parentKey) "..i;
					end
				end
			end
			if f:GetName() then
				local secure, taint = issecurevariable(_G,f:GetName());
				if IsShiftKeyDown() then
					F = "[" .. (secure and "Blizzard" or taint) .. "] " .. F;
				end
			end
		end
		if ldbObject.text ~= F then
			ldbObject.text = F
		end
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)
	--if (ns.tooltipChkOnShowModifier(false)) then tt:Hide(); return; end
	tt:Hide();
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self) end -- prevent displaying tt

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

--[=[ use frame instead of tooltip ]=]
