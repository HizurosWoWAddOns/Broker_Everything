
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Stuff" -- L["Stuff"] L["ModDesc-Stuff"]
local ttName,module,tt = name.."TT",name


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\stuff"}; --IconName::Stuff--


-- some local functions --
--------------------------
local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	local line, column

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",L[name]))
	tt:AddLine (" ")

	line, column = tt:AddLine(RELOADUI)
	tt:SetLineScript(line, "OnMouseUp", C_UI.Reload); -- Use static Popup to avoid taint.

	if ns.profile.GeneralOptions.showHints then
		tt:AddLine(" ")
		line, column = nil, nil
		tt:AddLine(
			C("copper",L["ModKeyS"].."+"..L["MouseBtnL"]).." || "..C("green",RELOADUI)
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

	if (button=="LeftButton") and (shift) then
		C_UI.Reload();
	end
end

-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
