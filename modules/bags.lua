
-- TODO: auto sell trash on vendor as option

----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Bags" -- L["Bags"]
local ldbName,ttName,ttColumns,tt,createMenu = name,name.."TT",3;
local ContainerIDToInventoryID,GetInventoryItemLink = ContainerIDToInventoryID,GetInventoryItemLink
local GetItemInfo,GetContainerNumSlots,GetContainerNumFreeSlots = GetItemInfo,GetContainerNumSlots,GetContainerNumFreeSlots
local qualityModeValues = {
	["1"]=L["All qualities"],
	["2"]=L["All qualities (+ vendor price)"],
	["3"]=L["Non empty qualities"],
	["4"]=L["Non empty qualities (+ vendor price)"],
	["5"]=L["poor only"],
	["6"]=L["poor only (+ vendor price)"],
	["7"]=L["poor and common"],
	["8"]=L["poor and common (+ vendor price)"]
}
local qualityModes = {
	["1"] = {empty=true,  vendor=false, max=7},
	["2"] = {empty=true,  vendor=true,  max=7},
	["3"] = {empty=false, vendor=false, max=7},
	["4"] = {empty=false, vendor=true,  max=7},
	["5"] = {empty=true,  vendor=false, max=0},
	["6"] = {empty=true,  vendor=true,  max=0},
	["7"] = {empty=true,  vendor=false, max=1},
	["8"] = {empty=true,  vendor=true,  max=1}
}

local G = {}
for i=0, 7 do G["ITEM_QUALITY"..i.."_DESC"] = _G["ITEM_QUALITY"..i.."_DESC"] end
G.ITEM_QUALITY99_DESC = L["Unknown"];


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="Interface\\icons\\inv_misc_bag_08",coords={0.05,0.95,0.05,0.95}}; --IconName::Bags--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show filled, total and free count of blag slots"];
ns.modules[name] = {
	desc = desc,
	events = {
		"PLAYER_LOGIN",
		"BAG_UPDATE",
		"UNIT_INVENTORY_CHANGED"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		freespace = true,
		critLowFree = 5,
		warnLowFree = 15,
		showQuality = true,
		goldColor = false,
		qualityMode = "1",
	--	crapSellingEnabled = false,
	--	crapSellingAuto = false,
	--	crapSellingInfo = true,
	},
	config_allowed = {
		qualityMode = {["1"]=true,["2"]=true,["3"]=true,["4"]=true,["5"]=true,["6"]=true,["7"]=true,["8"]=true}
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="freespace",         label=L["Show freespace"],          tooltip=L["Show bagspace instead used and max. bagslots in broker button"], event=true },
		{ type="toggle", name="showQuality",       label=L["Show quality"],            tooltip=L["Display a list of item qualities"], event=true },
		{ type="select", name="qualityMode",       label=L["Quality list"],            tooltip=L["Choose your favorite"], default="1", values=qualityModeValues },
		{ type="slider", name="critLowFree",       label=L["Critical low free slots"], tooltip=L["Select the maximum free slot count to coloring in red."], min=1, max=50, default=5, format = "%d", event=true },
		{ type="slider", name="warnLowFree",       label=L["Warn low free slots"],     tooltip=L["Select the maximum free slot count to coloring in yellow."], min=2, max=100, default=15, format = "%d", event=true },

		--{ type="separator", alpha=0 },
		--{ type="header", label=L["Crap selling options"] },
		--{ type="separator" },
		--{ type="toggle", name="crapSellingEnabled", label=L["Enabled"], tooltip=L["Enable crap/junk selling on opening a mergant frame."] },
		--{ type="toggle", name="crapSellingAuto", label=L["Automatic"], tooltip=L["Automatic crap/junk selling on opening a mergant frame."] },
		--{ type="toggle", name="crapSellingInfo", label=L["Chat info"], tooltip=L["Post earned money in general chat frame."] },
	},
	clickOptions = {
		["1_open_bags"] = {
			cfg_label = "Open bags", -- L["Open bags"]
			cfg_desc = "open your bags", -- L["open your bags"]
			cfg_default = "_LEFT",
			hint = "Open bags", -- L["Open bags"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleBackpack");
			end
		},
		["2_toggle_freespace"] = {
			cfg_label = "Switch display",
			cfg_desc = "Toggle between free and used/max bagslots in broker button",
			cfg_default = "_RIGHT",
			hint = "Switch display",
			func = function(self,button)
				local _mod=name;
				Broker_EverythingDB[name].freespace = not Broker_EverythingDB[name].freespace;
				ns.modules[name].onevent(self)
			end
		},
		["3_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "__NONE",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self);
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------

function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

-- Function to determine the total number of bag slots and the number of free bag slots.
local function BagsFreeUsed()
	local t = GetContainerNumSlots(0);
	local f = GetContainerNumFreeSlots(0);

	for i=1,NUM_BAG_SLOTS do
		local idtoinv = ContainerIDToInventoryID(i);
		local il = GetInventoryItemLink("player", idtoinv);
		if il then
			local st = select(7, GetItemInfo(il));
			if(st ~= "Soul Bag" and st ~= "Ammo Pouch" and st ~= "Quiver")then
				t = t + GetContainerNumSlots(i);
				f = f + GetContainerNumFreeSlots(i);
			end
		end
	end
	return f, t;
end

local function itemQuality()
	local price, sum, _ = {[0]=0,0,0,0,0,0,0,0,[99]=0},{[0]=0,0,0,0,0,0,0,0,[99]=0};
	for _, entries in pairs(ns.items.GetItemlist()) do
		for _,entry in ipairs(entries) do
			if entry.bag then
				entry.rarity = (sum[entry.rarity]~=nil) and entry.rarity or 99;
				sum[entry.rarity] = sum[entry.rarity] + entry.count;
				price[entry.rarity] = price[entry.rarity] + (entry.price*entry.count);
			end
		end
	end
	return price, sum;
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name;
end

ns.modules[name].init_configs = function()
	if (Broker_EverythingDB[name].freespace==nil) then
		Broker_EverythingDB[name].freespace = true;
	end
end

ns.modules[name].onevent = function(self,event,msg)
	local f, t = BagsFreeUsed()
	local u = t - f
	local p = u / t
	local txt = u .. "/" .. t
	local c = "white"
	local min1 = tonumber(Broker_EverythingDB[name].critLowFree)
	local min2 = tonumber(Broker_EverythingDB[name].warnLowFree)

	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end

	if Broker_EverythingDB[name].freespace == false then
		txt = u .. "/" .. t
	elseif Broker_EverythingDB[name].freespace == true then
		txt = (t - u) .. " ".. L["free"]
	end

	if f<=min1 then
		c = "red"
	elseif f<=min2 then
		c = "dkyellow"
	end

	local obj = self.obj or ns.LDB:GetDataObjectByName(ldbName) or {}
	obj.text = C(c,txt)
end

-- ns.modules[name].onupdate =  function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...
	local f, total = BagsFreeUsed()

	tt:AddHeader(C("dkyellow",L[name]));
	tt:AddSeparator(1);
	tt:AddLine(C("ltyellow",L["Free slots"] .. " :"),"",C("white",f).." ");
	tt:AddLine(C("ltyellow",L["Total slots"] .. " :"),"",C("white",total).." ");

	if Broker_EverythingDB[name].showQuality then
		local mode=qualityModes[Broker_EverythingDB[name].qualityMode];
		local price,sum=itemQuality();
		tt:AddSeparator(3,0,0,0,0);
		tt:AddLine(
			C("ltblue",L["Quality"]),
			mode.vendor and C("ltblue",L["Vendor price"]) or "",
			C("ltblue",L["Count"])
		);
		tt:AddSeparator(1);
		for i=0,#sum do
			if (i<=mode.max) and ((mode.empty and sum[i]>=0) or sum[i]>0) then
				local sumStr = sum[i];
				if(Broker_EverythingDB.separateThousands)then
					sumStr = FormatLargeNumber(sum[i]);
				end
				tt:AddLine(
					C("quality"..i,G["ITEM_QUALITY"..i.."_DESC"]),
					(price[i]>0 and mode.vendor) and ns.GetCoinColorOrTextureString(name,price[i]) or "",
					sumStr.." "
				);
			end
		end
	end
	if Broker_EverythingDB.showHints then
		tt:AddSeparator(3,0,0,0,0);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT", "RIGHT")
	ns.modules[name].ontooltip(tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

