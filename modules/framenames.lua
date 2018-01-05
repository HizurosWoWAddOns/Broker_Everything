
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Framenames" -- L["Framenames"]
local ttName,ldbObject,module = name.."TT"
local lastFrame,lastMod,lastCombatState,ticker = false,false,false;


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\equip"}; --IconName::Framenames--


-- some local functions --
--------------------------
local function ownership(p,f)
	local secure, taint = issecurevariable(p,f);
	return secure==true and "Blizzard" or taint;
end


-- module functions and variables --
------------------------------------
module = {
	events = {},
	onupdate_interval = 0.12,
	config_defaults = {
		enabled = false,
		ownership = "shift",
		creatureid = "shift"
	},
}

function module.options()
	local values = {none=ADDON_DISABLED, shift=L["On hold shift key"], always=ALWAYS };
	return {
		broker = {
			sep = {type="separator", order=1 },
			ownership={ type="select", order=2, name=L["Show ownership"], desc=L["Display ownership on broker button"], values=values},
			creatureid={ type="select", order=3, name=L["Show ownership"], desc=L["Display creature id on broker button"], values=values},
		}
	}
end

-- function module.onevent(self,event,msg) end

function module.onupdate()
	local f = GetMouseFocus();
	local mod = IsShiftKeyDown();
	local combat = InCombatLockdown();

	if f~=WorldFrame and f==lastFrame and mod==lastMod and combat==lastCombatState then
		return
	end

	local F,O,P,A = nil,"?","","" -- Frame, Owner, Prepend, Append
	local ldbObject = ns.LDB:GetDataObjectByName(module.ldbName);
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

-- function module.init() end
-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end

function module.ontooltip(tt)
	tt:Hide();
end

function module.onenter(self) end -- prevent displaying tt

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
