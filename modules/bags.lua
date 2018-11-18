
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Bags" -- L["Bags"] L["ModDesc-Bags"]
local ttName,ttColumns,tt,module = name.."TT",3;
local IsMerchantOpen,G = false,{};
local crap = {limit=3,sum=0,items={}};
local qualityModeValues = {
	["1"]=L["BagsQualityAll"],
	["2"]=L["BagsQualityAll"].." + "..L["BagsQualityVendor"],
	["3"]=L["BagsQualityAll"].." + "..L["BagsQualityNoEmpty"],
	["4"]=L["BagsQualityAll"].." + "..L["BagsQualityVendor"].." + "..L["BagsQualityNoEmpty"],
	["5"]=L["BagsQualityJunk"],
	["6"]=L["BagsQualityJunk"].." + "..L["BagsQualityVendor"],
	["7"]=L["BagsQualityCommon"],
	["8"]=L["BagsQualityCommon"].." + "..L["BagsQualityVendor"]
};
local qualityModes = {
	["1"] = {empty=true,  vendor=false, max=7},
	["2"] = {empty=true,  vendor=true,  max=7},
	["3"] = {empty=false, vendor=false, max=7},
	["4"] = {empty=false, vendor=true,  max=7},
	["5"] = {empty=true,  vendor=false, max=0},
	["6"] = {empty=true,  vendor=true,  max=0},
	["7"] = {empty=true,  vendor=false, max=1},
	["8"] = {empty=true,  vendor=true,  max=1}
};

-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\icons\\inv_misc_bag_08",coords={0.05,0.95,0.05,0.95}}; --IconName::Bags--


-- some local functions --
--------------------------
function crap:info()
	if ns.profile[name].autoCrapSellingInfo and self.sum>0 then
		ns.print(L["Auto crap selling - Summary"]..":",ns.GetCoinColorOrTextureString(name,self.sum,{color="white"}));
	end
end

function crap:sell()
	local num = #self.items;
	for i=1, min(num,self.limit) do
		local I=num-(i-1);
		local bag,slot,price = unpack(self.items[I]);
		self.sum = self.sum+price;
		UseContainerItem(bag, slot);
		tremove(self.items,I);
	end
	if #self.items==0 then
		C_Timer.After(0.15,function()self:info();end);
		return;
	end
	C_Timer.After(0.35,function()self:sell();end);
end

function crap:search()
	for bag=0, NUM_BAG_SLOTS do
		for slot=1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag,slot);
			if link then
				local _,count = GetContainerItemInfo(bag, slot);
				local _,_,quality,_,_,_,_,_,_,_,price = GetItemInfo(link);
				if quality==0 and price>0 then
					tinsert(self.items,{bag,slot,price*count});
				end
			end
		end
	end
	if #self.items>0 then
		self:sell();
	end
end

-- Function to determine the total number of bag slots and the number of free bag slots.
local function BagsFreeUsed()
	local t = GetContainerNumSlots(0) or 0; -- new: sometimes returns nil on startup
	local f = GetContainerNumFreeSlots(0) or 0;
	if t==0 then
		return 0,0;
	end

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
				if entry.price then
					price[entry.rarity] = price[entry.rarity] + (entry.price*entry.count);
				end
			end
		end
	end
	return price, sum;
end

local function updateBroker()
	local f, t = BagsFreeUsed()
	local u = t - f
	local p = u / t
	local txt = u .. "/" .. t
	local c = "white"
	local min1 = tonumber(ns.profile[name].critLowFree)
	local min2 = tonumber(ns.profile[name].warnLowFree)
	if ns.profile[name].freespace == false then
		txt = u .. "/" .. t
	elseif ns.profile[name].freespace == true then
		txt = (t - u) .. " ".. L["Free"]
	end

	if f<=min1 then
		c = "red"
	elseif f<=min2 then
		c = "dkyellow"
	end

	local obj = ns.LDB:GetDataObjectByName(module.ldbName) or {}
	obj.text = C(c,txt)
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	local f, total = BagsFreeUsed()

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",L[name]));
	tt:AddSeparator(1);
	tt:AddLine(C("ltyellow",L["Free slots"] .. " :"),"",C("white",f).." ");
	tt:AddLine(C("ltyellow",L["Total slots"] .. " :"),"",C("white",total).." ");

	if ns.profile[name].showQuality then
		local mode=qualityModes[ns.profile[name].qualityMode];
		local price,sum=itemQuality();
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(
			C("ltblue",L["Item summary|nby quality"]),
			mode.vendor and C("ltblue",L["Vendor price"]) or "",
			C("ltblue",L["Count"])
		);
		tt:AddSeparator(1);
		for i=0,#sum do
			if (i<=mode.max) and ((mode.empty and sum[i]>=0) or sum[i]>0) then
				tt:AddLine(
					C("quality"..i,G["ITEM_QUALITY"..i.."_DESC"]),
					(price[i]>0 and mode.vendor) and ns.GetCoinColorOrTextureString(name,price[i],{inTooltip=true}) or "",
					ns.FormatLargeNumber(name,sum[i],true).." "
				);
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"BAG_UPDATE",
		"UNIT_INVENTORY_CHANGED",
		"MERCHANT_SHOW",
		"MERCHANT_CLOSED"
	},
	config_defaults = {
		enabled = true,
		freespace = true,
		critLowFree = 5,
		warnLowFree = 15,
		showQuality = true,
		qualityMode = "1",

		autoCrapSelling = false,
		autoCrapSellingInfo = true
	},
	clickOptionsRename = {
		["bags"] = "1_open_bags",
		["space"] = "2_toggle_freespace",
		["menu"] = "3_open_menu"
	},
	clickOptions = {
		["bags"] = {"Open all bags","call","ToggleAllBags"}, -- L["Open all bags"]
		["space"] = {"Switch (free or used/max bag space)","module","switch"}, -- L["Switch (free or used/max bag space)"]
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	bags = "_LEFT",
	space = "_RIGHT",
	menu = "__NONE"
});

function module.switch(self,button)
	ns.profile[name].freespace = not ns.profile[name].freespace;
	module.onevent(self,"BE_DUMMY_EVENT");
end


function module.options()
	return {
		broker = {
			freespace={ type="toggle", order=1, name=L["Show freespace"],                  desc=L["Show bagspace instead used and max. bagslots in broker button"] },
		},
		tooltip = {
			showQuality={ type="toggle", order=1, name=L["Show item summary by quality"],    desc=L["Display an item summary list by qualities in tooltip"], width="double" },
			qualityMode={ type="select", order=2, name=L["Item summary by quality mode"],    desc=L["Choose your favorite"], values=qualityModeValues, width="double" },
			critLowFree={ type="range", order=3, name=L["Critical low free slots"],         desc=L["Select the maximum free slot count to coloring in red."], min=1, max=50, step=1 },
			warnLowFree={ type="range", order=4, name=L["Warn low free slots"],             desc=L["Select the maximum free slot count to coloring in yellow."], min=2, max=100, step=1 },
		},
		misc = {
			shortNumbers=1,
			header={ type="header", order=2, name=L["Crap selling options"] },
			autoCrapSelling={ type="toggle", order=3, name=L["Enable auto crap selling"], desc=L["Enable automatically crap selling on opening a mergant frame"] },
			autoCrapSellingInfo={ type="toggle", order=4, name=L["Summary of earned gold in chat"], desc=L["Post summary of earned gold in chat window"] },
		},
	},
	{
		showQuality=true,
		critLowFree=true,
		warnLowFree=true
	}
end

function module.init()
	for i=0, 7 do G["ITEM_QUALITY"..i.."_DESC"] = _G["ITEM_QUALITY"..i.."_DESC"] end
	G.ITEM_QUALITY99_DESC = UNKNOWN;
end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="MERCHANT_SHOW" and ns.profile[name].autoCrapSelling then
		IsMerchantOpen = true;
		C_Timer.After(0.5,function() crap:search() end);
	elseif event=="MERCHANT_CLOSED" then
		IsMerchantOpen = false;
	elseif ns.eventPlayerEnteredWorld then
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
