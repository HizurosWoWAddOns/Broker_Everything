
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Framenames" -- L["Framenames"]
local ttName,ldbObject = name.."TT"
local lastFrame,lastMod,lastCombatState,ticker = false,false,false;


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
	events = {"PLAYER_LOGIN"},
	updateinterval = 1/12,
	config_defaults = {
		ownership = "shift",
		creatureid = "shift"
	},
	config_allowed = nil,
	config_header = nil, -- use default header
	config_broker = {
		"minimapButton",
		{ type="select", name="ownership", label=L["Show ownership"], tooltip=L["Display ownership on broker button"], values={none=ADDON_DISABLED, shift=L["On hold shift key"], always=ALWAYS }, default="shift" },
		{ type="select", name="creatureid", label=L["Show ownership"], tooltip=L["Display creature id on broker button"], values={none=ADDON_DISABLED, shift=L["On hold shift key"], always=ALWAYS }, default="shift" },
	},
	config_tooltip = nil,
	config_misc = nil,
}


--------------------------
-- some local functions --
--------------------------
local function ownership(p,f)
	local secure, taint = issecurevariable(p,f);
	return secure==true and "Blizzard" or taint;
end

local function updater()
	local f = GetMouseFocus();
	local mod = IsShiftKeyDown();
	local combat = InCombatLockdown();

	if f~=WorldFrame and f==lastFrame and mod==lastMod and combat==lastCombatState then
		return
	end

	local F,O,P,A = nil,"?","","" -- Frame, Owner, Prepend, Append
	local ldbObject = ns.LDB:GetDataObjectByName(ns.modules[name].ldbName);
	lastFrame,lastMod,lastCombatState=f,mod,combat;

	if (not f) then
		if ldbObject.text~=UNKNOWN then
			ldbObject.text = UNKNOWN
		end
	else
		if f:IsForbidden() then
			F = "<Forbidden Frame>";
		elseif f:IsProtected() and combat then
			F = "<Protected Frame>";
		else
			F = f:GetName();

			if F then
				O = ownership(_G,F);
			end

			if F=="WorldFrame" then
				local guid,id,_ = UnitGUID("mouseover");
				local uName = UnitName("mouseover");
				if guid and uName then
					O = false;
					P,_,_,_,_,id = strsplit("-",guid);
					F = uName or "?";
					if ((ns.profile[name].creatureid=="shift" and mod) or ns.profile[name].creatureid=="always") and P=="Creature" and id~=nil then
						P = P.. ", id:"..id;
					end
				end
			end

			if F == nil and type(f.key)=="string" then -- LibQTip tooltips returns nil on GetName but f.key contains the current name
				O = "LibQTip";
				F = f.key;
			end

			if F == nil then
				F = "<anonym>";
				for i,v in pairs(f:GetParent() or {})do
					if(v==f)then
						P = "parentKey";
						F = i;
						O = ownership(f,i);
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

		if O~=false and ((ns.profile[name].ownership=="shift" and mod) or ns.profile[name].ownership=="always") then
			str = "["..O.."] "..str;
		end

		ldbObject.text = str;
	end
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules[name].init = function() end

ns.modules[name].onevent = function(self,event,msg)
	if not ticker and event=="PLAYER_LOGIN" then
		ticker = C_Timer.NewTicker(ns.modules[name].updateinterval,updater);
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)
	tt:Hide();
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self) end -- prevent displaying tt

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end
