
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Stuff" -- L["Stuff"] L["ModDesc-Stuff"]
local ttName,module,tt = name.."TT"


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\stuff"}; --IconName::Stuff--


-- some local functions --
--------------------------
local function toggleFullscreen()
	C_CVar.SetCVar("gxMaximize",C_CVar.GetCVar("gxMaximize")=="1" and "0" or "1");
	RestartGx();
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	local line

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",L[name]))
	tt:AddLine(" ")

	line = tt:AddLine(L["ReloadUI"])
	tt:SetLineScript(line, "OnMouseUp", C_UI.Reload); -- Use static Popup to avoid taint.

	tt:AddLine(" ")

	line = tt:AddLine(L["StuffToggleFullScreen"])
	tt:SetLineScript(line,"OnMouseUp", toggleFullscreen);

	if ns.profile.GeneralOptions.showHints then
		tt:AddLine(" ")
		line = nil
		tt:AddLine(
			C("copper",L["ModKeyS"].."+"..L["MouseBtnL"]).." || "..C("green",L["ReloadUI"])
		)
		tt:AddLine(
			C("copper",L["ModKeyS"].."+"..L["MouseBtnR"]).." || "..C("green",L["StuffToggleFullScreen"])
		)
	end
	ns.roundupTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {},
	config_defaults = {
		enabled = false,
	},
}

-- function module.options() return {} end
-- function module.init() end
-- function module.onevent(self,event,msg) end
-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, 1, "LEFT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end

function module.onclick(self,button)
	if ns.profile[name].disableOnClick then return end
	local shift = IsShiftKeyDown()

	if button=="LeftButton" and shift then
		C_UI.Reload();
	elseif button=="RightButton" and shift then
		toggleFullscreen();
	end
end

-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
