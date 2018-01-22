
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Bags" -- L["Bags"]
local ttName,ttColumns,tt,module = name.."TT",3;
local IsMerchantOpen,G = false,{};
local crap = {limit=3,sum=0,items={}};
local qualityModeValues,qualityModes = {},{};
local expansionModeValues,expansionModes,expansions,expansionMaxItemIDs = {},{},{},{};


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

local function itemExpansion()
	local price,sum = {},{};
	for i=1, #expansions do
		price[i],sum[i]=0,0;
	end
	for _, entries in pairs(ns.items.GetItemlist()) do
		for _, entry in ipairs(entries)do
			if entry.bag then
				local exp = #expansions;
				for i=1, #expansionMaxItemIDs do
					if expansionMaxItemIDs[i][1] and entry.id <= expansionMaxItemIDs[i][1] then
						exp = expansionMaxItemIDs[i][2];
						break;
					end
				end
				sum[exp] = sum[exp]+1;
				if entry.price then
					price[exp] = price[exp]+(entry.price*entry.count);
				end
			end
		end
	end
	return price,sum;
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
		goldColor = false,
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
			autoCrapSellingInfo={ type="toggle", order=4, name=L["Earned money summary in chat"], desc=L["Post earned money in chat frame"] },
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

	qualityModeValues = {
		["1"]=L["Qualities"],
		["2"]=L["Qualities with vendor price"],
		["3"]=L["Qualities (hide empty)"],
		["4"]=L["Qualities with vendor price (hide empty)"],
		["5"]=L["Poor only"],
		["6"]=L["Poor only with vendor price"],
		["7"]=L["Poor and common"],
		["8"]=L["Poor and common with vendor price"]
	}
	qualityModes = {
		["1"] = {empty=true,  vendor=false, max=7},
		["2"] = {empty=true,  vendor=true,  max=7},
		["3"] = {empty=false, vendor=false, max=7},
		["4"] = {empty=false, vendor=true,  max=7},
		["5"] = {empty=true,  vendor=false, max=0},
		["6"] = {empty=true,  vendor=true,  max=0},
		["7"] = {empty=true,  vendor=false, max=1},
		["8"] = {empty=true,  vendor=true,  max=1}
	}
	expansionModeValues = {
		["1"]=L["WoW Expansions"],
		["2"]=L["WoW Expansions with vendor price"],
		["3"]=L["WoW Expansions (hide empty)"],
		["4"]=L["WoW Expansions with vendor price (hide empty)"],
	}
	expansionModes = {
		["1"] = {empty=true,  vendor=false},
		["2"] = {empty=true,  vendor=true},
		["3"] = {empty=false, vendor=false},
		["4"] = {empty=false, vendor=true},
	};
	expansions = {
		"Vanilla",--1.0
		"Burning Crusade", --2.0
		"Wrath of the Lich King", -- 3.0
		"Cataclysm", -- 4.0
		"Mists of Pandaria", -- 5.0
		"Warlords of Draenor", -- 6.0
		"Legion" -- 7.0
	}
	expansionMaxItemIDs = {
		{23668,1},

		-- mixed ids between bc and lk? inconsistant use of item id.
		{20976,2},{20978,3},{22779,2},{22781,3},{23816,2},{23817,3},{28042,2},{28045,3},{29204,2},{29206,3},{32999,2},{33004,3},{33083,2},{33084,3},{33096,2},
		{33099,3},{33108,2},{33109,3},{33110,2},{33111,3},{33117,2},{33120,3},{33122,2},{33123,3},{33127,2},{33129,3},{33163,2},{33164,3},{33186,2},{33188,3},
		{33189,2},{33190,3},{33219,2},{33221,3},{33237,2},{33238,3},{33277,2},{33278,3},{33281,2},{33282,3},{33283,2},{33284,3},{33287,2},{33290,3},{33307,2},
		{33308,3},{33309,2},{33312,3},{33313,2},{33314,3},{33317,2},{33321,3},{33322,2},{33323,3},{33329,2},{33330,3},{33334,2},{33352,3},{33354,2},{33355,3},
		{33386,2},{33387,3},{33389,2},{33420,3},{33432,2},{33445,3},{33446,2},{33452,3},{33453,2},{33454,3},{33455,2},{33462,3},{33469,2},{33470,3},{33471,2},
		{33472,3},{33476,2},{33477,3},{33484,2},{33488,3},{33540,2},{33551,3},{33552,2},{33556,3},{33557,2},{33558,3},{33559,2},{33563,3},{33566,2},{33576,3},
		{33580,2},{33581,3},{33599,2},{33621,3},{33622,2},{33639,3},{33771,2},{33781,3},{33792,2},{33796,3},{33805,2},{33806,3},{33818,2},{33819,3},{33956,2},
		{33962,3},{33999,2},{34003,3},{34012,2},{34013,3},{34022,2},{34027,3},{34029,2},{34032,3},{34033,2},{34044,3},{34050,2},{34057,3},{34068,2},{34070,3},
		{34075,2},{34076,3},{34077,2},{34084,3},{34087,2},{34088,3},{34089,2},{34091,3},{34100,2},{34102,3},{34109,2},{34112,3},{34114,2},{34128,3},{34130,2},
		{34137,3},{34141,2},{34142,3},{34220,2},{34226,3},{34234,2},{34239,3},{34386,2},{34387,3},{34448,2},{34468,3},{34493,2},{34494,3},{34497,2},{34498,3},
		{34504,2},{34519,3},{34595,2},{34598,3},{34599,2},{34600,3},{34616,2},{34621,3},{34622,2},{34624,3},{34625,2},{34661,3},{34667,2},{34669,3},{34686,2},
		{34688,3},{34689,2},{34695,3},{34708,2},{34779,3},{34780,2},{34782,3},{34783,2},{34787,3},{34799,2},{34806,3},{34810,2},{34815,3},{34829,2},{34830,3},
		{34841,2},{34842,3},{34843,2},{34844,3},{34868,2},{34871,3},{34896,2},{34897,3},{34907,2},{34909,3},{34912,2},{34913,3},{34914,2},{34915,3},{34919,2},
		{34920,3},{34947,2},{34948,3},{34953,2},{34954,3},{34955,2},{34984,3},{35115,2},{35127,3},{35187,2},{35188,3},{35221,2},{35222,3},{35223,2},{35224,3},
		{35227,2},{35228,3},{35233,2},{35234,3},{35271,2},{35272,3},{35275,2},{35276,3},{35277,2},{35278,3},{35280,2},{35281,3},{35287,2},{35289,3},{35292,2},
		{35293,3},{35350,2},{35355,3},{35395,2},{35401,3},{35478,2},{35486,3},{35488,2},{35493,3},{35505,2},{35506,3},{35569,2},{35580,3},{35582,2},{35690,3},
		{35691,2},{35692,3},{35700,2},{35701,3},{35703,2},{35706,3},{35708,2},{35711,3},{35717,2},{35718,3},{35725,2},{35726,3},{35733,2},{35747,3},{35769,2},
		{35827,3},{35828,2},{35905,3},{35906,2},{35944,3},{35945,2},{36546,3},{36547,2},{36736,3},{36737,2},{36747,3},{36748,2},{36798,3},{36799,2},{36875,3},
		{36877,2},{36940,3},{36941,2},{37010,3},{37012,2},{37125,3},{37128,2},{37147,3},{37148,2},{37294,3},{37297,2},{37495,3},{37497,2},{37570,3},{37571,2},
		{37581,3},{37586,2},{37587,3},{37588,2},{37595,3},{37599,2},{37603,3},{37606,2},{37675,3},{37676,2},{37708,3},{37710,2},{37718,3},{37719,2},{37749,3},
		{37750,2},{37815,3},{37816,2},{37826,3},{37829,2},{37862,3},{37865,2},{37901,3},{37905,2},{37913,3},{37915,2},{37925,3},{37929,2},{37933,3},{37934,2},
		{38049,3},{38050,2},{38081,3},{38082,2},{38088,3},{38091,2},{38157,3},{38163,2},{38174,3},{38175,2},{38181,3},{38186,2},{38224,3},{38225,2},{38228,3},
		{38229,2},{38232,3},{38233,2},{38274,3},{38280,2},{38284,3},{38291,2},{38293,3},{38301,2},{38305,3},{38314,2},{38319,3},{38320,2},{38326,3},{38329,2},
		{38426,3},{38432,2},{38465,3},{38466,2},{38505,3},{38506,2},{38517,3},{38518,2},{38544,3},{38548,2},{38575,3},{38577,2},{38586,3},{38587,2},{38605,3},
		{38606,2},{38624,3},{38626,2},{38627,3},{38628,2},{38629,3},{38630,2},{39475,3},{39477,2},{39655,3},{39656,2},{43515,3},{43516,2},{43597,3},{43599,2},
		{57148,3},

		{78889,4},
		{105868,5},
		{133598,6},
		{false,7}
	};
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
