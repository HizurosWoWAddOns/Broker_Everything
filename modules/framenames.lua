
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Framenames" -- L["Framenames"]
local ldbName = name
local tt = nil
local ttName = name.."TT"
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
local lastFrame = nil
local function FrameInfoTooltip(tt,frame)
	if lastFrame==frame then return end

	tt:Clear()

	if frame:IsForbidden() or ( frame:IsProtected() and InCombatLockdown() ) then
		tt:AddLine(L["Name"], (frame:IsForbidden() and "[Forbidden Frame]") or (frame:IsProtected() and "[Protected Frame]") or "[Unknown]")
	else
		tt:AddHeader(frame:GetName() or "<anonym>")
		tt:AddSeparator()
		local tmp
		for i,v in pairs(frame) do
			if i~=0 and ( type(v)=="string" or type(v)=="number" ) then
				if strlen(v)>26 then v = strsub(v,0,23).."..." end
				tt:AddLine(i, v);
			end
		end
		tmp = frame:GetParent()
		tt:AddLine("GetParent", (tmp~=nil and tmp:GetName()) or "nil <anonym?>")
	end

	if lastFrame~=frame then
		lastFrame = frame
	end
end

local lastUnit = nil
local function UnitInfoTooltip(tt)
	local tmp
	local guid = UnitGUID("mouseover")
	local name = UnitName("mouseover")
	if lastUnit==name then return end

	tt:Clear()

	tt:AddLine("UnitName",name)
	tt:AddLine("UnitGUID",guid or "Unknown")

	if lastUnit~=guid then
		lastUnit = name
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	if self then
		local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName)
		dataobj.text = L[name]
	end
end

-- ns.modules[name].onevent = function(self,event,msg) end

ns.modules[name].onupdate = function(self)
	local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName)
	local F = nil
	local f = GetMouseFocus()
	if (not f) then
		if dataobj.text~=L["Unknown"] then
			dataobj.text = L["Unknown"]
		end
	else
		F = (f:IsForbidden() and "[Forbidden Frame]") or (f:IsProtected() and InCombatLockdown() and "[Protected Frame]") or f:GetName()
		if F == nil and type(f.key)=="string" then -- LibQTip tooltips returns nil on GetName but f.key contains the current name
			F = f.key
		end
		if F == nil then
			F = "<anonym>";
			for i,v in pairs(f:GetParent())do
				if(v==f)then
					F = "(parentKey) "..i;
				end
			end
		end
		if dataobj.text ~= F then
			dataobj.text = F
		end
	end
	--[[
	if ( f ) and  IsControlKeyDown() and IsAltKeyDown() then
		if tt==nil then
			tt = ns.LQT:Acquire(ttName, 2, "LEFT", "RIGHT")
		elseif tt.key~=ttName then
			return;
		end

		if UnitName("mouseover") then
			UnitInfoTooltip(tt)
		else
			FrameInfoTooltip(tt,GetMouseFocus())
		end

		local s = UIParent:GetEffectiveScale()
		local x,y = GetCursorPosition()
		local w,h = tt:GetWidth()/s, tt:GetHeight()/s
		tt:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",(x/s)+12,(y/s)-h)
		tt:SetClampedToScreen(true)

		if not tt:IsShown() then tt:Show() end
	elseif tt~=nil and tt.key==ttName then
		tt:ClearAllPoints()
		tt:Hide()
		lastFrame = nil
		lastUnit = nil
	end
	]]
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
