
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
	desc = L["Broker to show names of frames under the mouse"],
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
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
	if self then
		ldbObject = ldbObject or ns.LDB:GetDataObjectByName(ldbName);
		ldbObject.text = L[name];
	end
end

-- ns.modules[name].onevent = function(self,event,msg) end

ns.modules[name].onupdate = function(self)
	ldbObject = ldbObject or ns.LDB:GetDataObjectByName(ldbName);
	local F,O,P,A = nil,"Blizzard","","" -- Frame, Owner, Prepend, Append
	local f = GetMouseFocus();
	if (not f) then
		if ldbObject.text~=UNKNOWN then
			ldbObject.text = UNKNOWN
		end
	else
		if f:IsForbidden() then
			F = "<Forbidden Frame>";
		elseif f:IsProtected() and InCombatLockdown() then
			F = "<Protected Frame>";
		else
			F = f:GetName();

			if F then
				local secure, taint = issecurevariable(_G,F);
				O = secure and "Blizzard" or taint;
			end

			if F=="WorldFrame" then
				local guid,id,_ = UnitGUID("mouseover");
				local uName = UnitName("mouseover");
				if guid and uName then
					O = false;
					P,_,_,_,_,id = strsplit("-",guid);
					F = uName;
					if IsShiftKeyDown() and P=="Creature" and id~=nil then
						P = P.. ", id:"..id;
					end
				end
			end

			if F == nil and type(f.key)=="string" then -- LibQTip tooltips returns nil on GetName but f.key contains the current name
				O = "?";
				F = f.key;
			end

			if F == nil then
				F = "<anonym>";
				for i,v in pairs(f:GetParent() or {})do
					if(v==f)then
						P = "parentKey";
						F = i;
						local secure, taint = issecurevariable(f,i);
						O = secure and "Blizzard" or taint;
						break;
					end
				end
			end
		end

		local str = F;

		if P and P~="" then
			str = "("..P..") "..str;
		end

		if A and A~="" then
			str = str .. " ("..A..")";
		end

		if O~=false and IsShiftKeyDown() then
			str = "["..O.."] "..str;
		end

		ldbObject.text = str;
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
