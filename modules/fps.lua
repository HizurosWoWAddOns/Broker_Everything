
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "FPS" -- L["FPS"]
local ldbName = name
local tt,tt2,tt3 = nil,nil,nil
local ttName, tt2Name, tt3Name = name.."TT", name.."TT2", name.."TT3"
local GetFramerate = GetFramerate
local _, playerClass = UnitClass("player")
local _minmax = {[1] = nil,[2] = nil}
local graph_maxValues,graph_maxHeight = 50,50
local fpsHistory = {};
local fps = 0
local minmax_delay = 3
local gfxRestart = {}
local gameRestart = {}


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name..'_yellow'] = {iconfile="Interface\\Addons\\"..addon.."\\media\\fps_yellow"}	--IconName::FPS_yellow--
I[name..'_red']    = {iconfile="Interface\\Addons\\"..addon.."\\media\\fps_red"}	--IconName::FPS_red--
I[name..'_blue']   = {iconfile="Interface\\Addons\\"..addon.."\\media\\fps_blue"}	--IconName::FPS_blue--
I[name..'_green']  = {iconfile="Interface\\Addons\\"..addon.."\\media\\fps_green"}	--IconName::FPS_green--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show your frames per second."],
	icon_suffix = "_blue",
	events = {},
	updateinterval = 1,
	config_defaults = nil,
	config_allowed = nil,
	config = { { type="header", label=L[name], align="left", icon=I[name..'_blue'] } }
}


--------------------------
-- some local functions --
--------------------------
local function minmax(f)
	if minmax_delay~=0 then minmax_delay = minmax_delay - 1 return end
	if (not _minmax[1]) or _minmax[1] > f then _minmax[1]=f end
	if (not _minmax[2]) or _minmax[2] < f then _minmax[2]=f end
end

local function fps_color(f)
	if not f then return {"","","?"} end
	local c = (f<20 and {"_red","red"}) or (f<30 and {"_yellow","dkyellow"}) or (f<100 and {"_green","green"}) or {"_blue","ltblue"}
	table.insert(c,C(c[2],f)..ns.suffixColour("fps"));
	return c
end

local function fpsTooltip(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...

	local l, c, cell
	tt:Clear()
	tt:AddHeader(C("dkyellow",L[name]))
	tt:AddSeparator()
	tt:AddLine(L["Current"]..":",fps_color(fps)[3])
	tt:AddSeparator(3,0,0,0,0)
	tt:AddLine(L["Min."]..":",fps_color(_minmax[1])[3])
	tt:AddLine(L["Max."]..":",fps_color(_minmax[2])[3])

	--if Broker_EverythingDB.showHints then
	if false then
		tt:AddLine(" ")
		tt:AddLine(C("copper",L["Click"]).." ||",C("green",L["Open graphics set manager"]))
		tt:AddLine(C("copper",L["Right-Click"]).." ||",C("green",L["Open graphics menu"]))
	end

	if(#fpsHistory>0)then
		--ns.graphTT.Update(tt,fpsHistory);
	end
end

local function graphicsSetManager(_self)
	if (tt) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end

	local l,c
	tt2 = ns.LQT:Acquire(name.."TT2", 1, "LEFT")
	ns.createTooltip(_self,tt2)
	tt2:SetScript('OnEnter', function()
	end)
	tt2:Clear()

	tt2:AddHeader(C("ltblue","Graphics set manager"))
	tt2:AddSeparator()
	tt2:AddLine(L["No set found"])

	if Broker_EverythingDB.showHints then
		tt2:AddLine(" ")
		line, column = tt:AddLine()
		tt2:SetCell(line, 1,
			C("ltblue",L["Click"]).." || "..C("green",L["Use a set"])
			.."|n"..
			C("ltblue",L["Shift+Click"]).." || "..C("green",L["Update/save a set"])
			.."|n"..
			C("ltblue",L["Ctrl+Click"]).." || "..C("green",L["Delete a set"])
			, nil, nil, 1)
		
	end
end

local function checkSelection(selName)
	local bool,cvars=true,{}
	for i,v in ipairs(options[selName]) do
		bool=true
		for I,V in pairs(v) do
			if I~="label" and I~="check" then
				if selName=="gfxapi" then
					if cvars[I]==nil then cvars[I] = strlower(GetCVar(I)) end -- reduce call of GetCVar
					V=strlower(V)
				else
					if cvars[I]==nil then cvars[I] = tonumber(GetCVar(I)) end -- reduce call of GetCVar
				end
				if cvars[I]~=V then bool=false end
			end
		end
		if bool==true then
			return v.label
		end
	end
	return C("gray",VIDEO_QUALITY_LABEL6)
end

local function setSelection(selName,index)
end

local function graphicsMenuSelection(self,selName)
	local l,c
	if tt3==nil or (tt3~=nil and tt3.key~=tt3Name) then
		tt3 = ns.LQT:Acquire(tt3Name,1,"LEFT")
	end
	tt3:SetScript('OnEnter', function()
		tt3:SetScript('OnLeave', function()
			ns.hideTooltip(tt2,ttName2,true);
			ns.hideTooltip(tt3,ttName3,true);
		end)
	end)
	tt3:Clear()

	for i,v in ipairs(options[selName]) do
		if v.label~=nil then
			l,c = tt3:AddLine(v.label)
			tt3:SetLineScript(l,"OnMouseUp",function()
				setSelection(selName,i)
			end)
		end
	end

	ns.createTooltip(self,tt3)
	tt3:ClearAllPoints()
	tt3:SetPoint("LEFT",tt2,"RIGHT",-15,0)
	tt3:SetPoint("TOP",self,"TOP",0,5)
	tt3:SetFrameLevel(tt2:GetFrameLevel()+3)
end

local function graphicsMenu(_self)
	if (tt) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	local l,c
	tt2 = ns.LQT:Acquire(name.."TT2", 2, "LEFT", "RIGHT")
	tt2:Clear()

	for i,v in ipairs(tt2_normal) do
		if v.head~=nil then
			tt2:AddLine(C("ltblue",v.head))
		elseif v.sep==true then
			tt2:AddSeparator()
		elseif v.sep~=nil then
			tt2:AddSeparator(unpack(v.sep))
		elseif v.label~=nil then
			l,c = tt2:AddLine()
			tt2:SetCell(l,1,C("ltyellow",v.label))
			if v.boolean~=nil then
				tt2:SetCell(l,2, GetCVar(v.boolean)=="1" and C("green",VIDEO_OPTIONS_ENABLED) or C("red",VIDEO_OPTIONS_DISABLED))
				tt2:SetLineScript(l,"OnMouseUp",function(self,button) ns.SetCVar(v.boolean,GetCVar(v.boolean)=="1" and "0" or "1") graphicsMenu(_self) end)
			elseif v.option~=nil then
				tt2:SetCell(l,2,checkSelection(v.option))
				tt2:SetLineScript(l,"OnEnter",function(__self)
					graphicsMenuSelection(__self,v.option)
				end)
				tt2:SetLineScript(l,"OnLeave", function(__self)
					ns.hideTooltip(tt3,ttName3);
				end)
			else
				tt2:SetCell(l,2,C("gray","?"))
			end
		end
	end

	ns.createTooltip(_self,tt2)
	tt2:SetScript('OnLeave', function() ns.hideTooltip(tt2,ttName2) end)
end

local function getSettings()
	
end

local function createMenu(parent)
	if (tt) and (tt.key) and (tt.key==ttName) then ns.hideTooltip(tt,ttName,true) end

	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addEntries(gfxMenu);
	ns.EasyMenu.ShowMenu(parent);
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

-- ns.modules[name].onevent = function(self,event,msg) end

ns.modules[name].onupdate = function(self)
	fps = floor(GetFramerate())
	local c = fps_color(fps)
	local d = self.obj or ns.LDB:GetDataObjectByName(ldbName)

	minmax(fps);

	tinsert(fpsHistory,1,fps);
	if(#fpsHistory==51)then tremove(fpsHistory,51); end
	if(tt and tt.key and tt.key==ttName)then
		--ns.graphTT.Update(tt,fpsHistory);
	end

	local icon = I(name..c[1])
	d.iconCoords = icon.coords or {0,1,0,1}
	d.icon = icon.iconfile
	d.text = c[3]

	--if tt then
	if tt~=nil and tt.key~=nil and tt.key==ttName and tt:IsShown() then
		fpsTooltip(tt)
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontt = function(tt) end

-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	if tt2~=nil and tt2.key==tt2Name and tt2:IsShown() then return end

	tt = ns.LQT:Acquire(ttName, 2, "LEFT", "RIGHT")
	fpsTooltip(tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
end

ns.modules[name].onclick = function(self,button)
	if button == "LeftButton" then
		--graphicsSetManager(self)
	elseif button == "RightButton" then
		--graphicsMenu(self)
		--createMenu(self);
	end
end

-- ns.modules[name].ondblclick = function(self,button) end

