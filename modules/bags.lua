
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Bags" -- L["Bags"] L["ModDesc-Bags"]
local ttName,ttColumns,tt,module,createTooltip = name.."TT",3;
local IsMerchantOpen,G = false,{};
local crap,bags,bagTypes,retry = {limit=2,sum=0,items={}},{sumFree=0,sumTotal=0,byTypeFree={},byTypeTotal={}},{};
local LE_ITEM_CLASS_CONTAINER = LE_ITEM_CLASS_CONTAINER or Enum.ItemClass.Container;
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
local bbModeValues = {
	L["BagsItemsOfSpace"], -- Total items / Total space
	L["BagsFreeOfSpace"], -- Free space / Total space
	L["BagsFreeSpace"], -- Free space
}

-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=133633,coords={0.07,0.93,0.07,0.93}}; --IconName::Bags--


-- some local functions --
--------------------------
function crap.info()
	if ns.profile[name].autoCrapSellingInfo and not crap.ERR_VENDOR_DOESNT_BUY and crap.sum>0 then
		ns:print(L["CrapSellingSummary"]..HEADER_COLON,ns.GetCoinColorOrTextureString(name,crap.sum,{color="white"}));
	end
end

function crap.sell()
	local numItems,sum = #crap.items,0;
	for i=1, min(numItems,crap.limit) do
		if crap.ERR_VENDOR_DOESNT_BUY then
			return;
		end
		local I=numItems-(i-1);
		local bag,slot,price = unpack(crap.items[I]);
		sum = sum + price;
		C_Container.UseContainerItem(bag, slot);
		tremove(crap.items,I);
	end
	crap.sum = crap.sum + sum;
	if crap.ERR_VENDOR_DOESNT_BUY then
		return;
	end
	if #crap.items==0 then
		C_Timer.After(0.314159,crap.info);
		return;
	end
	C_Timer.After(0.314159,crap.sell);
end

local checkSellThisItemList = {
	--{ optKey="<string>", item=<number>|range={<number>,<number>}, do="sell|hold" }
	{optKey="autoCrapSellingBloodCards", itemIdRange={113340, 113354}, todo="sell"},
	{optKey="autoCrapSellingWeapons", itemClass=2, itemSubClassAll=true, todo="hold", msg="CrapSellingWeaponsHold"},
	{optKey="autoCrapSellingArmor", itemClass=4, itemSubClassRange={1,6}, todo="hold", msg="CrapSellingArmorHold"},
}
crap.holdMessages = {};

local function inRange(number,range)
	return number>=range[1] and number<=range[2];
end

local function checkSellThisItem(itemId,link,classID,subClassID,quality)
	for _,entry in ipairs(checkSellThisItemList) do
		local optValue = ns.profile[name][entry.optKey];
		local itemMatchList = false;
		if (entry.itemIdRange and inRange(itemId,entry.itemIdRange)) -- by itemId range
		or (entry.itemIdList and tContains(entry.itemIdList,itemId)) -- by itemId list
		or (entry.itemClass==classID and entry.itemSubClassAll)
		or (entry.itemClass==classID and entry.itemSubClass==subClassID)
		or (entry.itemClass==classID and entry.itemSubClassRange and inRange(subClassID,entry.itemSubClassRange))
		or (entry.item and entry.item==itemId) -- by single itemID
		then
			itemMatchList = true;
		end
		if optValue==true and itemMatchList==true then
			if entry.todo=="hold" and entry.quality~=0 then
				return; -- is not crap; ignore
			end
			if entry.todo=="hold" and entry.msg then
				if crap.holdMessages[entry.msg]==nil then
					crap.holdMessages[entry.msg] = {};
				end
				tinsert(crap.holdMessages[entry.msg],link);
			end
			return entry.todo;
		end
	end
	return quality==0 and "sell";
end

function crap.search()
	wipe(crap.holdMessages);
	for bag=0, NUM_BAG_SLOTS do
		local numSlots = C_Container.GetContainerNumSlots(bag);
		local numFreeSlots = C_Container.GetContainerNumFreeSlots(bag);
		if numSlots ~= numFreeSlots then
			for slot=1, numSlots do
				local link,itemId,itemInfo,count,quality,price,classID,subClassID,_ = C_Container.GetContainerItemLink(bag,slot);
				if link then
					itemId = tonumber((link:match("item:(%d+)")));
				end
				if link and itemId then
					itemInfo,count = C_Container.GetContainerItemInfo(bag, slot);
					if not count and itemInfo then
						count = itemInfo.stackCount;
					end
					_,_,quality,_,_,_,_,_,_,_,price,classID,subClassID = C_Item.GetItemInfo(link);
					if price>0 and itemId and checkSellThisItem(itemId,link,classID,subClassID,quality)=="sell" then
						tinsert(crap.items,{bag,slot,price*count});
					end
				end
			end
		end
	end
	if select("#",crap.holdMessages)>0 then
		for msg, items in pairs(crap.holdMessages) do
			if #items>2 then
				ns:print(L["CrapSelling"],"",L[msg],items[1],LFG_LIST_AND_MORE:format(#items-1));
			else
				ns:print(L["CrapSelling"],"",L[msg],table.concat(items,", "));
			end
		end
	end
	if #crap.items>0 then
		crap.sum = 0;
		crap.sell();
	end
end

local function updateBagTypes()
	bagTypes[LE_ITEM_CLASS_CONTAINER..":0"] = {name=L["Bags"],icon=133633};
	for i=1, 11 do
		local n = C_Item.GetItemSubClassInfo(LE_ITEM_CLASS_CONTAINER,i);
		bagTypes[LE_ITEM_CLASS_CONTAINER..HEADER_COLON..i] = {name=n,icon=0};
	end
end

local function chkBagTypes()
	local values = {general=false,single={}};
	for key, value in pairs(bagTypes) do
		if key~="1:0" and value.name then
			local v = ns.profile[name]["showBagTypeBB-"..key];
			if v then
				values.general=true;
			end
			values.single[key] = v;
		end
	end
	return values;
end

local function itemQuality()
	local price, sum, _ = {[99]=0},{[99]=0};
	local failed = false;
	for i in pairs(ITEM_QUALITY_COLORS) do
		price[i],sum[i]=0,0;
	end
	for itemID,items in pairs(ns.items.byID)do
		local itemPrice,itemName,itemQuality;
		for sharedSlot, item in pairs(items) do
			if item.bag>=0 then
				if not itemPrice then
					itemName, _, itemQuality, _, _, _, _, _, _, _, itemPrice = C_Item.GetItemInfo(item.link);
					if not itemName then
						failed = true;
					end
				end
				local itemInfo,count = C_Container.GetContainerItemInfo(item.bag,item.slot);
				if not count and itemInfo then
					count = itemInfo.stackCount;
				end
				itemQuality = itemQuality or 99; -- unknown quality [nil]
				if count and itemPrice then
					price[itemQuality] = price[itemQuality] + (itemPrice*count);
				end
				if count then
					sum[itemQuality] = sum[itemQuality] + count;
				end
			end
		end
	end
	if failed then
		C_Timer.After(0.7,function()
			createTooltip(tt)
		end);
	end
	return price, sum;
end

local function colorLowFree(free)
	local color = "white";
	if free<=tonumber(ns.profile[name].critLowFree) then
		color = "red";
	elseif free<=tonumber(ns.profile[name].warnLowFree) then
		color = "yellow";
	end
	return color;
end

local function sortBags(a,b)
	local a1,a2 = strsplit(":",a); a = tonumber(a1:trim())*100+tonumber(a2:trim());
	local b1,b2 = strsplit(":",b); b = tonumber(b1:trim())*100+tonumber(b2:trim());
	return a < b;
end

local function bagStr(free,total)
	local mode = ns.profile[name].bbMode;
	local color = colorLowFree(free);
	if mode==2 then
		return C(color,free .. "/" .. total);
	elseif mode==3 then
		return C(color,free .. " ".. L["Free"]);
	end
	return C(color,(total - free) .. "/" .. total);
end

local function updateBroker()
	local txt, free, total = {},bags.sumFree,bags.sumTotal,0;
	if total==0 or total==nil then
		return;
	end

	local dbBagTypes = chkBagTypes();

	if dbBagTypes.general then
		for key,value in ns.pairsByKeys(bagTypes,sortBags)do
			if dbBagTypes.single[key] and bags.byTypeTotal[key] and bags.byTypeTotal[key]>0 then
				local f,t = bags.byTypeFree[key],bags.byTypeTotal[key];
				total,free = total-t,free-f;
				tinsert(txt,"|T"..value.icon..":0|t"..bagStr(f,t))
			end
		end
	end

	tinsert(txt,1,bagStr(free,total));

	(ns.LDB:GetDataObjectByName(module.ldbName) or {}).text = table.concat(txt,", ");
end

function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",L[name]));

	if ns.profile[name].showBagTypes then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue","Type"),C("ltblue",L["Free slots"]),C("ltblue",L["Total slots"]));
		tt:AddSeparator(1);
		for key,value in ns.pairsByKeys(bagTypes,sortBags) do
			if bags.byTypeTotal[key] and bags.byTypeTotal[key]>0 then
				tt:AddLine("|T"..(value.icon or 133633)..":0|t "..C("ltyellow",value.name),bags.byTypeFree[key],bags.byTypeTotal[key]);
			end
		end
	else
		tt:AddSeparator(1);
		tt:AddLine(C("ltyellow",L["Free slots"]),"",C("white",bags.sumFree));
		tt:AddLine(C("ltyellow",L["Total slots"]),"",C("white",bags.sumTotal));
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

local updateBags
local function updateBagsRetry(delay,msg)
	if type(delay)=="number" and retry==nil then
		retry = 0;
		for i=1, #msg do
			if type(msg[i])=="string" then
				msg[i] = msg[i]:gsub("\124","¦");
			end
		end
		C_Timer.After(delay,updateBagsRetry);
	elseif retry~=nil and retry<5 then
		retry = retry + 1;
		updateBags();
	end
end

-- Function to determine the total number of bag slots and the number of free bag slots.
function updateBags()
	local backpackSlots = C_Container.GetContainerNumSlots(0) or 0;
	if backpackSlots==0 then -- api return invalid value
		updateBagsRetry(.5,{"<retry>","<invalid api value>","zero backpack slots are invalid"});
		return;
	end

	local backpackFreeSlots = C_Container.GetContainerNumFreeSlots(0) or 0;
	local totalSlots,freeSlots = {["1:0"]=backpackSlots},{["1:0"]=backpackFreeSlots};
	local sum = {backpackSlots,backpackFreeSlots};

	for bagIndex=1, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS) do
		local itemIcon, itemClassID, itemSubClassID, _, link = 0, 1, 0;
		if bagIndex>0 and C_Container.GetContainerNumSlots(bagIndex)>0 then
			link = GetInventoryItemLink("player", ns.deprecated.C_Container.ContainerIDToInventoryID(bagIndex));
		end
		if link then
			_, _, _, _, _, _, _, _, _, itemIcon, _, itemClassID, itemSubClassID = C_Item.GetItemInfo(link);
			if not itemIcon then
				updateBagsRetry(.5,{"<retry>","<invalid item info>",link,tostring(itemIcon)});
				return;
			end
		end
		if itemIcon and itemClassID and itemSubClassID then
			local bagSlots = C_Container.GetContainerNumSlots(bagIndex);
			local bagSlotsFree = C_Container.GetContainerNumFreeSlots(bagIndex);
			local bT = itemClassID..":"..itemSubClassID;
			if not totalSlots[bT] then
				totalSlots[bT], freeSlots[bT] = bagSlots,bagSlotsFree;
			else
				totalSlots[bT] = totalSlots[bT]+bagSlots;
				freeSlots[bT] = freeSlots[bT]+bagSlotsFree;
			end
			if not (bagTypes[bT] and bagTypes[bT].icon) then
				local n = C_Item.GetItemSubClassInfo(itemClassID,itemSubClassID);
				bagTypes[bT] = {name=n,icon=itemIcon};
			elseif bagTypes[bT].icon < itemIcon then
				bagTypes[bT].icon = itemIcon;
			end
			sum[1],sum[2] = sum[1]+bagSlots,sum[2]+bagSlotsFree;
		end
	end

	bags = {sumFree=sum[2],sumTotal=sum[1],byTypeFree=freeSlots,byTypeTotal=totalSlots};

	retry = nil;
	updateBroker();
	createTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		"MERCHANT_SHOW",
		"MERCHANT_CLOSED",
		"UI_ERROR_MESSAGE",
		"BAG_UPDATE_DELAYED",
		"PLAYER_ENTERING_WORLD"
	},
	config_defaults = {
		enabled = true,
		critLowFree = 5,
		warnLowFree = 15,
		showQuality = true,
		qualityMode = "1",
		showBagTypes = true,
		bbMode = 3,

		autoCrapSelling = false,
		autoCrapSellingInfo = true,
		autoCrapSellingBloodCards = false,
		autoCrapSellingWeapons = true,
		autoCrapSellingArmor = true,

		-- "showBagTypeBB-1:1" -- filled by function
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

if ns.client_version<4 then
	module.config_defaults.autoCrapSelling = false;
	module.config_defaults.autoCrapSellingInfo = false;
end

ns.ClickOpts.addDefaults(module,{
	bags = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	local options = {
		broker = {
			bbMode     = { type="select", order=1, name=L["BagsBBMode"], desc=L["BagsBBModeDesc"], values = bbModeValues, width="double"},
			header     = { type="header", order=2, name=L["Show separate bag types"] },
			desc       = { type="description", order=3, name=L["Display other bag types like herbalism or mining bags separated on broker button"] },
			-- list of bag types filled by function
		},
		tooltip = {
			showQuality={ type="toggle", order=1, name=L["Show item summary by quality"],    desc=L["Display an item summary list by qualities in tooltip"], width="double" },
			qualityMode={ type="select", order=2, name=L["Item summary by quality mode"],    desc=L["Choose your favorite"], values=qualityModeValues, width="double" },
			showBagTypes = { type="toggle", order=3, name=L["Show bags by type"], desc=L["Display a list of bag by types with free and total summary in tooltip"], width="double" },
		},
		misc = {
			critLowFree={ type="range", order=1, name=L["Critical low free slots"],         desc=L["Select the maximum free slot count to coloring in red."], min=1, max=50, step=1 },
			warnLowFree={ type="range", order=2, name=L["Warn low free slots"],             desc=L["Select the maximum free slot count to coloring in yellow."], min=2, max=100, step=1 },
			shortNumbers=3,
			autoCrapSelling = {
				type = "group", order=4, hidden=ns.IsClassicClient,
				name = C("ltblue",L["CrapSellingOpts"]),
				args = {
					autoCrapSelling={ type="toggle", order=1, name=L["CrapSellingEnable"], desc=L["CrapSellingEnableDesc"] },
					autoCrapSellingInfo={ type="toggle", order=2, name=L["CrapSellingChatInfo"], desc=L["CrapSellingChatInfoDesc"] },
					include = { type="header", order=10, name=L["Include"] },
					autoCrapSellingBloodCards={ type="toggle", order=11, name=function() return L["Blood Card"] end, desc=L["CrapSellingBloodCardsDesc"]},
					exclude = { type="header", order=60, name=CHAT_BAN },
					autoCrapSellingWeapons={ type="toggle",order=61,name=AUCTION_CATEGORY_WEAPONS,desc=L["CrapSellingWeaponsDesc"] },
					autoCrapSellingArmor={ type="toggle",order=62,name=AUCTION_CATEGORY_ARMOR,desc=L["CrapSellingArmorDesc"] }
				}
			}

		},
	};

	updateBagTypes();
	for key, value in pairs(bagTypes) do
		if key~="1:0" and value.name then
			options.broker["showBagTypeBB-"..key] = { type="toggle", order=4, name=value.name };
			module.config_defaults["showBagTypeBB-"..key] = key=="11:3" or key=="1:1" or key=="1:11";
		end
	end

	return options, {
		showQuality=true,
		critLowFree=true,
		warnLowFree=true
	};
end

function module.init()
	for i=0, 7 do G["ITEM_QUALITY"..i.."_DESC"] = _G["ITEM_QUALITY"..i.."_DESC"] end
	G.ITEM_QUALITY99_DESC = UNKNOWN;

	-- init ns.items
	ns.items.Init("bags");

	if ns.profile[name].freespace~=nil then
		ns.profile[name].bbMode = ns.profile[name].freespace and 3 or 1;
		ns.profile[name].freespace = nil
	end
end

function module.onevent(self,event,...)
	local arg1 = ...;
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="BE_UPDATE_CFG" then
		updateBroker();
	elseif event=="BAG_UPDATE_DELAYED" or event=="PLAYER_ENTERING_WORLD" then
		retry = nil;
		updateBags();
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
