
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
function crap.info()
	if ns.profile[name].autoCrapSellingInfo and not crap.ERR_VENDOR_DOESNT_BUY and crap.sum>0 then
		ns.print(L["Auto crap selling - Summary"]..":",ns.GetCoinColorOrTextureString(name,crap.sum,{color="white"}));
	end
end

function crap.sell()
	local num = #crap.items;
	for i=1, min(num,crap.limit) do
		if crap.ERR_VENDOR_DOESNT_BUY then
			return;
		end
		local I=num-(i-1);
		local bag,slot,price = unpack(crap.items[I]);
		crap.sum = crap.sum+price;
		UseContainerItem(bag, slot);
		tremove(crap.items,I);
	end
	if crap.ERR_VENDOR_DOESNT_BUY then
		return;
	end
	if #crap.items==0 then
		C_Timer.After(0.314159,crap.info);
		return;
	end
	C_Timer.After(0.314159,crap.sell);
end

function crap.search()
	for bag=0, NUM_BAG_SLOTS do
		if GetContainerNumSlots(bag) ~= GetContainerNumFreeSlots(bag) then
			for slot=1, GetContainerNumSlots(bag) do
				local link = GetContainerItemLink(bag,slot);
				if link then
					local _,count = GetContainerItemInfo(bag, slot);
					local _,_,quality,_,_,_,_,_,_,_,price = GetItemInfo(link);
					if quality==0 and price>0 then
						tinsert(crap.items,{bag,slot,price*count});
					end
				end
			end
		end
	end
	if #crap.items>0 then
		crap.sell();
	end
end

function GetLocaleBagType(id,en)
	local _, _, _, _, _, _, itemSubTypeLocale = GetItemInfo(id);
	if itemSubTypeLocale then
		L[en] = itemSubTypeLocale;
	end
end

-- Function to determine the total number of bag slots and the number of free bag slots.
local function BagsFreeUsed()
	local T,F = (GetContainerNumSlots(0) or 0),(GetContainerNumFreeSlots(0) or 0);
	local total,free = {[1]=T,ammo=0},{[1]=F,ammo=0},0,0;
	--for i=2, 11 do total[i] = 0; end

	if total[1]==0 then
		return 0,0,free,total; -- error
	end

	for slotIndex=1,NUM_BAG_SLOTS do
		local link, typeID, subTypeID = GetInventoryItemLink("player", slotIndex+19);
		if link then
			local _, _, _, _, _, x, y, _, _, _, _, itemClassID, itemSubClassID  = GetItemInfo(link);
			if not itemSubClassID then
				itemSubClassID = 0;
			end

			local t,f = (GetContainerNumSlots(slotIndex)),(GetContainerNumFreeSlots(slotIndex));
			if itemClassID==LE_ITEM_CLASS_QUIVER then -- quiver / ammo pouch
				total.ammo, free.ammo = total.ammo+t, free.ammo+f;
			else
				itemSubClassID = itemSubClassID+1; -- itemSubClassID starts with 0
				if not total[itemSubClassID] then
					total[itemSubClassID], free[itemSubClassID] = t,f;
				else
					total[itemSubClassID] = total[itemSubClassID]+t;
					free[itemSubClassID] = free[itemSubClassID]+f;
				end
				T,F = T+t,F+f;
			end
		end
	end
	return F,T, free, total;
end

local function itemQuality()
	local price, sum, _ = {[99]=0},{[99]=0};
	for i in pairs(ITEM_QUALITY_COLORS) do
		price[i],sum[i]=0,0;
	end
	for index,entry in pairs(ns.items.bags)do
		local _,itemCount,_,itemQuality = GetContainerItemInfo(entry.bag,entry.slot);
		local itemName, _, _, _, _, _, _, _, _, _, itemPrice = GetItemInfo(entry.link);
		if itemName and itemCount then
			itemQuality = itemQuality or 99; -- unknown quality [nil]
			sum[itemQuality] = sum[itemQuality] + itemCount;
			if itemPrice then
				price[itemQuality] = price[itemQuality] + (itemPrice*itemCount);
			end
		end
	end
	return price, sum;
end

local function countAmmo()
	local sum,counts,data,_ = 0,{},{};
	for index,entry in pairs(ns.items.ammo) do
		if not data[entry.id] then
			data[entry.id],counts[entry.id] = {},0;
			data[entry.id].name, _, data[entry.id].quality = GetItemInfo(entry.id);
		end
		counts[entry.id] = counts[entry.id] + entry.count;
		sum = sum + entry.count;
	end
	return sum,counts,data;
end

local function updateBroker()
	local txt = {};

	local u,p = 0,0;
	local f, t = BagsFreeUsed();
	if t and t>0 then
		u = t - f;
		p = u / t;
	end

	local c = "white"
	if f<=tonumber(ns.profile[name].critLowFree) then
		c = "red"
	elseif f<=tonumber(ns.profile[name].warnLowFree) then
		c = "yellow"
	end

	if ns.profile[name].freespace then
		tinsert(txt,C(c,(t - u) .. " ".. L["Free"]));
	else
		tinsert(txt,C(c,u .. "/" .. t));
	end

	if ns.player.class=="HUNTER" then
		local ammoInUse = GetInventoryItemID("player",0);
		local ammoSum,ammoCounts,ammoData = countAmmo();
		tinsert(txt,C((ammoInUse and ammoData[ammoInUse] and "quality"..ammoData[ammoInUse].quality or "red"),ammoSum.." "..AMMOSLOT));
	elseif ns.player.class=="WARLOCK" then
		--
	end

	(ns.LDB:GetDataObjectByName(module.ldbName) or {}).text = table.concat(txt,", ");
end

local function sortAmmo(a,b)
	return a.name>b.name;
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",L[name]));

	if ns.profile[name].showByBagTypes then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue","Type"));
		tt:AddSeparator(1);
	else
		tt:AddSeparator(1);
		tt:AddLine(C("ltyellow",L["Free slots"]),"",C("white",free));
		tt:AddLine(C("ltyellow",L["Total slots"]),"",C("white",total));
	end

	if ns.client_version<2 then
		if ns.player.class=="HUNTER" then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Ammo Pouch"]));
			tt:AddSeparator(1);
			if tTotal.ammo==0 then
				tt:AddLine(C("ltgray",L["No ammo pouch found..."]));
			else
				tt:AddLine(C("ltyellow",L["Free slots"]),"",C("white",tFree.ammo));
				tt:AddLine(C("ltyellow",L["Total slots"]),"",C("white",tTotal.ammo));
				tt:AddSeparator(1);

				local ammoInUse = GetInventoryItemID("player",0);
				local ammoSum,ammoCounts,ammoData = countAmmo();
				table.sort(ammoData,sortAmmo);
				for id,ammo in pairs(ammoData)do
					tt:AddLine(C("quality"..ammo.quality,ammo.name),(ammoInUse==id and C("green",CONTRIBUTION_ACTIVE) or ""),C("white",ammoCounts[id]));
				end
			end
		elseif ns.player.class=="WARLOCK" then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Soul Pouch"]));
			tt:AddSeparator(1);
			if tTotal.ammo==0 then
				tt:AddLine(C("ltgray",L["No soul pouch found..."]));
			else
				tt:AddLine(C("ltyellow",L["Free slots"]),"",C("white",tFree.soul));
				tt:AddLine(C("ltyellow",L["Total slots"]),"",C("white",tTotal.soul));
			end
		end

		--tt:AddSeparator(4,0,0,0,0);
		--tt:AddLine(C("ltblue",KEYRING));
		--tt:AddSeparator(1);
		--
	end

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
					ns.FormatLargeNumber(name,sum[i],true)
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
		"MERCHANT_SHOW",
		"MERCHANT_CLOSED",
		"UI_ERROR_MESSAGE",
		"GET_ITEM_INFO_RECEIVED"
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
		["menu"] = "3_open_menu"
	},
	clickOptions = {
		["bags"] = {"Open all bags","call","ToggleAllBags"}, -- L["Open all bags"]
		["menu"] = "OptionMenu"
	}
}

if ns.client_version<2 then
	module.config_defaults.autoCrapSelling = false;
	module.config_defaults.autoCrapSellingInfo = false;
end

ns.ClickOpts.addDefaults(module,{
	bags = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			freespace={ type="toggle", order=1, name=L["Show freespace"],                  desc=L["Show bagspace instead used and max. bagslots in broker button"] },
		},
		tooltip = {
			showQuality={ type="toggle", order=1, name=L["Show item summary by quality"],    desc=L["Display an item summary list by qualities in tooltip"], width="double" },
			qualityMode={ type="select", order=2, name=L["Item summary by quality mode"],    desc=L["Choose your favorite"], values=qualityModeValues, width="double" },
		},
		misc = {
			critLowFree={ type="range", order=1, name=L["Critical low free slots"],         desc=L["Select the maximum free slot count to coloring in red."], min=1, max=50, step=1 },
			warnLowFree={ type="range", order=2, name=L["Warn low free slots"],             desc=L["Select the maximum free slot count to coloring in yellow."], min=2, max=100, step=1 },
			shortNumbers=3,
			header={ type="header", order=4, name=L["Crap selling options"] },
			autoCrapSelling={ type="toggle", order=5, name=L["Enable auto crap selling"], desc=L["Enable automatically crap selling on opening a mergant frame"], hidden=ns.IsClassicClient },
			autoCrapSellingInfo={ type="toggle", order=6, name=L["Summary of earned gold in chat"], desc=L["Post summary of earned gold in chat window"], hidden=ns.IsClassicClient },
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
	ns.items.RegisterCallback(name,updateBroker,"bags");
end

function module.onevent(self,event,...)
	local arg1 = ...;
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="BE_UPDATE_CFG" then
		updateBroker();
	elseif event=="PLAYER_LOGIN" and ns.client_version<2 then
		C_Timer.After(5,function()
			GetLocaleBagType(2102,"Ammo Pouch");
			GetLocaleBagType(22243,"Soul Pouch");
		end);
	elseif event=="MERCHANT_SHOW" and ns.profile[name].autoCrapSelling then
		IsMerchantOpen = true;
		C_Timer.After(0.314159,crap.search);
	elseif event=="MERCHANT_CLOSED" then
		IsMerchantOpen = false;
		C_Timer.After(1.5,function()
			crap.ERR_VENDOR_DOESNT_BUY = nil;
		end);
	elseif IsMerchantOpen and event=="UI_ERROR_MESSAGE" then
		local messageType, message = ...; -- 41, ERR_VENDOR_DOESNT_BUY
		if message==ERR_VENDOR_DOESNT_BUY then
			crap.ERR_VENDOR_DOESNT_BUY = true;
		end
	elseif event=="GET_ITEM_INFO_RECEIVED" then
		local en,id = nil,...; -- Get localized item names from classic client
		if id==2102 then
			en = "Ammo Pouch";
		elseif id==22243 then
			en = "Soul Pouch"
		end
		if en then
			GetLocaleBagType(id, en);
		end
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
