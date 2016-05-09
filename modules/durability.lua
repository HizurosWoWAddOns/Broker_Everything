
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...;
local C, L, I = ns.LC.color, ns.L, ns.I;
L.Durability = DURABILITY;


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local _
local name = "Durability";
local ldbName,ttName,tt = name,name.."TT",nil;
local hiddenTooltip,createMenu
local last_repairs = {};
local merchant = {repair=false,costs=0,diff=0,single=0};
local discount = {[5]=0.95,[6]=0.9,[7]=0.85,[8]=0.8};
local slotNames = {
	HEADSLOT,NECKSLOT,SHOULDERSLOT,SHIRTSLOT,CHESTSLOT,WAISTSLOT,LEGSSLOT,FEETSLOT,
	WRISTSLOT,HANDSSLOT,FINGER0SLOT_UNIQUE,FINGER1SLOT_UNIQUE,TRINKET0SLOT_UNIQUE,
	TRINKET1SLOT_UNIQUE,BACKSLOT,MAINHANDSLOT,SECONDARYHANDSLOT,RANGEDSLOT
};
local date_format = "%Y-%m-%d %H:%M";
local date_formats = {
	["%d.%m. %H:%M"]      = "28.07. 16:23",
	["%d.%m. %I:%M %p"]   = "28.07. 04:23 pm",
	["%Y-%m-%d %H:%M"]    = "2099-07-28 16:23",
	["%Y-%m-%d %I:%M %p"] = "2099-07-28 04:23 pm",
	["%d/%m/%Y %H:%M"]    = "28/07/2099 16:23",
	["%d/%m/%Y %I:%M %p"] = "28/07/2099 04:23 pm"
};
local colorSets = setmetatable({values={}},{
	__newindex = function(t,k,v)
		local tb,n = {},0;
		for i,col in ns.pairsByKeys(v) do
			table.insert(tb,C(col,(n<100 and n.."-" or "")..i.."%"));
			n = i+1;
		end
		rawset(t.values,k,table.concat(tb,", "));
		rawset(t,k,v);
	end,
	__call = function(t,d)
		local c,n = nil,0
		local set = t[Broker_EverythingDB[name].colorSet]
		for i,v in ns.pairsByKeys(set) do if d>=n and d<=i then c,n = v,i+1 end end
		return c
	end
})

colorSets.set1 = {[20]="red",[40]="orange",[99]="yellow",[100]="green"};
colorSets.set2 = {[15]="red",[40]="orange",[70]="yellow",[100]="white"};
colorSets.set3 = {[20]="red",[40]="orange",[60]="yellow",[99]="green",[100]="ltblue"};
colorSets.set4 = {[15]="red",[40]="orange",[60]="yellow",[80]="green",[100]="white"};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Minimap\\TRACKING\\Repair",coords={0.05,0.95,0.05,0.95}}; --IconName::Durability--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show durability of your gear and estimated repair costs."]
ns.modules[name] = {
	desc = desc,
	events = {
		"PLAYER_LOGIN",
		"PLAYER_DEAD",
		"PLAYER_REGEN_ENABLED",
		"PLAYER_ENTERING_WORLD",
		"MERCHANT_CLOSED",
		"MERCHANT_SHOW",
		"PLAYER_MONEY",
		"CHAT_MSG_MONEY"
	},
	updateinterval = nil,
	config_defaults = {
		goldColor = false,
		inBroker = "percent",
		colorSet = "set1",
		autorepair = false,
		autorepairbyguild = false,
		listCosts = true,
		saveCosts = true,
		maxCosts = 5,
		dateFormat = "%Y-%m-%d %H:%M",
		showDiscount = true,
		lowestItem = true,
		chatRepairInfo = false,
	},
	config_allowed = {
		inBroker = {["percent"]=true,["costs"]=true,["costs/percent"]=true,["percent/costs"]=true},
		colorSet = {},
		dateFormat = {["%d.%m. %H:%M"] = true,["%d.%m. %I:%M %p"] = true,["%Y-%m-%d %H:%M"] = true,["%Y-%m-%d %I:%M %p"] = true,["%d/%m/%Y %H:%M"] = true,["%d/%m/%Y %I:%M %p"] = true}
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="lowestItem", label=L["Lowest durability"], tooltip=L["Display the lowest item durability in broker."], event=true },
		{ type="toggle", name="showDiscount", label=L["Show discount"], tooltip=L["Show list of reputation discounts in tooltip"] },
		{ type="select", name="inBroker", label=L["Broker format"], tooltip=L["Choose your favorite display format for the broker button."], default="percent", event=true,
			values={
				["percent"]="54%",
				["costs"]="34.23.01",
				["costs/percent"]="32.27.16, 54%",
				["percent/costs"]="54%, 32.27.16"
			}
		},
		{ type="select", name="colorSet", label=L["Percent color set"], tooltip=L["Choose your favorite color set in which the percent text in broker should be displayed."], event=true, default="set1", values=colorSets.values },
		{ type="select", name="dateFormat", label=L["Date format"], tooltip=L["Choose the date format if used in the list of repair costs"], default="%Y-%m-%d %H:%M", values=date_formats, event=true },
		{ type="separator", alpha=0 },
		{ type="header", label=L["Repair options"] },
		{ type="separator" },
		{ type="toggle", name="autorepair", label=L["Enable auto repair"], tooltip=L["Automatically repair your equipment on opening a merchant with repair option."], event=true },
		{ type="toggle", name="autorepairbyguild", label=L["Use guild money"], tooltip=function() return L["Use guild money on auto repair if you can"].. ( (GetGuildInfoText():find("%[noautorepair%]")) and "|n"..C("red",L["Your guild leadership denied the use of guild money for auto repair."]) or ""); end, event=true, --[[disabled=function() return (GetGuildInfoText():find("%[noautorepair%]")); end]] },
		{ type="toggle", name="chatRepairInfo", label=L["Repair info"], tooltip=L["Post repair actions in chatframe"] },
		{ type="toggle", name="listCosts", label=L["List of repair costs"], tooltip=L["Display a list of the last repair costs in tooltip"] },
		{ type="toggle", name="saveCosts", label=L["Save repair costs"], tooltip=L["Save the list of repair costs over the session"] },
		{ type="slider", name="maxCosts", label=L["Max. list entries"], tooltip=L["Choose how much entries the list of repair costs can have."], min=1, max=50, default=5, format="%d" },
	},
	clickOptions = {
		["1_open_character_info"] = {
			cfg_label = "Open character info", -- L["Open character info"]
			cfg_desc = "open the character info", -- L["open the character info"]
			cfg_default = "_LEFT",
			hint = "Open character info", -- L["Open character info"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCharacter","PaperDollFrame");
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self)
			end
		}
	}
};

for i,v in pairs(colorSets) do
	ns.modules[name].config_allowed.colorSet[i] = true;
end

--------------------------
-- some local functions --
--------------------------
local function scanAll()
	local equipped,bags,cost,per,current,maximum,total,_ = 0,0,0,1;
	local _curr,_max,_per,_perSlot,_AvPercent = 0,0,1,nil,1;

	for slot=1, 18 do
		if (GetInventoryItemID("player", slot)) then
			current,maximum = GetInventoryItemDurability(slot); -- durability values
			if (current) and (maximum>0) and (current<maximum) then
				_,_,cost = hiddenTooltip:SetInventoryItem("player", slot); -- repair costs
				equipped = equipped + tonumber(cost or 0);
				_curr,_max = _curr+current,_max+maximum;
				per = current/maximum;
				if (per<_per) then
					_per,_perSlot = per,slot;
				end
			end
		end
	end

	if (_max>0) then
		_AvPercent = _curr/_max;
	end

	for bag=0, NUM_BAG_SLOTS do
		for slot=1, GetContainerNumSlots(bag) do
			if (GetContainerItemID(bag,slot)) then
				current,maximum = GetContainerItemDurability(bag,slot);
				if (current) and (maximum>0) and (current<maximum) then
					_, cost = hiddenTooltip:SetBagItem(bag,slot);
					bags = bags+tonumber(cost or 0);
				end
			end
		end
	end

	if (merchant.repair) then
		total = GetRepairAllCost();
		equipped = equipped + (total-(equipped+bags))
	else
		total = (equipped + bags);
	end

	return total,equipped,bags,_AvPercent*100,_per*100,_perSlot;
end

--[[
	lastRepairs_add
		@param cost       [number]      - repair costs
		@param fund       [true|nil]    - true=guild fund, nil=player fund.
		@param repairType [boolean|nil] - true=autorepair, false=single item repair mode, nil=normal repair all
--]]
local function lastRepairs_add(cost,fund,repairType)
	local t = {};
	table.insert(last_repairs,1,{time(),cost,(fund==true),(repairType==true)});
	for i,v in ipairs(last_repairs) do
		if (#t<50) then table.insert(t,v); end
	end
	last_repairs = t;
	if (Broker_EverythingDB[name].saveCosts) then
		be_durability_db = t;
	end
end

local function AutoRepairAll(costs)
	local chat = Broker_EverythingDB[name].chatRepairInfo;
	if (Broker_EverythingDB[name].autorepairbyguild==true) and (IsInGuild()==true) and (CanGuildBankRepair()==true) and (costs < GetGuildBankWithdrawMoney()) then
		if (not GetGuildInfoText():find("%[noautorepair%]")) then -- auto repair with guild fund allowed by guild leader?
			merchant = {repair=false,costs=0,diff=0,single=0}; -- must be changed befor Repair all items
			RepairAllItems(true);
			lastRepairs_add(costs,true,true);
			if (chat) then
				ns.print(L["Automatically repaired with guild money"]..":" ,ns.GetCoinColorOrTextureString(name,costs));
			end
			return true;
		elseif (chat) then
			ns.print(L["AutoRepair"],L["Your guild leadership denied the use of guild money for auto repair."],L["Try fallback to player money."]);
		end
	end
	if (costs < GetMoney()) then
		merchant = {repair=false,costs=0,diff=0,single=0}; -- must be changed befor Repair all items
		RepairAllItems();
		lastRepairs_add(costs,nil,true);
		if (chat) then
			ns.print(L["Automatically repaired with player money"]..":", ns.GetCoinColorOrTextureString(name,costs));
		end
		return nil;
	end
	return false;
end

local function durabilityTooltip(tt)
	if (not tt.key) or (tt.key~=ttName) then return; end -- don't override other LibQTip tooltips...

	tt:Clear()
	local repairCost, equipCost, bagCost, durabilityA, durabilityL, durabilityLslot = scanAll();
	local repairCostN = repairCost;
	local reputation = UnitReaction("npc", "player");
	if (discount[reputation]) then
		repairCostN = floor(repairCost/discount[reputation]);
	end
	durabilityA = floor(durabilityA);
	durabilityL = floor(durabilityL);

	local a,g,d = Broker_EverythingDB[name].autorepair, Broker_EverythingDB[name].autorepairbyguild;
	local lst = setmetatable({},{__call = function(t,a) rawset(t,#t+1,a) end});

	lst({sep={3,0,0,0,0}});
	lst({c1=C("ltblue",gsub(REPAIR_COST,":","")),c2=ns.GetCoinColorOrTextureString(name,repairCost)});
	lst({sep={1}});
	lst({c1=L["Character"],c2=ns.GetCoinColorOrTextureString(name,equipCost)});
	lst({c1=L["Bags"],c2=ns.GetCoinColorOrTextureString(name,bagCost)});

	if Broker_EverythingDB[name].showDiscount then
		lst({sep={3,0,0,0,0}});
		lst({c0=C("ltblue",L["Reputation discounts"])});
		lst({sep={1}});
		lst({c1=C("white",L["Neutral"]),  c2=ns.GetCoinColorOrTextureString(name,repairCostN)});
		lst({c1=C("white",L["Friendly"]), c2=ns.GetCoinColorOrTextureString(name,ceil(repairCostN * discount[5]))});
		lst({c1=C("white",L["Honoured"]), c2=ns.GetCoinColorOrTextureString(name,ceil(repairCostN * discount[6]))});
		lst({c1=C("white",L["Revered"]),  c2=ns.GetCoinColorOrTextureString(name,ceil(repairCostN * discount[7]))});
		lst({c1=C("white",L["Exalted"]),  c2=ns.GetCoinColorOrTextureString(name,ceil(repairCostN * discount[8]))});
	end

	if (Broker_EverythingDB[name].listCosts) then
		lst({sep={3,0,0,0,0}});
		if (Broker_EverythingDB[name].saveCosts) then
			lst({c0=C("ltblue",L["Last %d repair costs"]:format(Broker_EverythingDB[name].maxCosts))});
		else
			lst({c1=C("ltblue",L["Last %d repair costs"]:format(Broker_EverythingDB[name].maxCosts)),c2=C("ltblue",L["(session only)"])});
		end
		lst({sep={1}});
		if (#last_repairs>0) then
			local indicator = "";
			for i,v in ipairs(last_repairs) do
				if (i<=tonumber(Broker_EverythingDB[name].maxCosts)) then
					indicator = ((v[4]) and "a" or "") .. ((v[3]) and "G" or "P");
					lst({c1=date(date_format,v[1]) .. (strlen(indicator)>0 and " "..indicator or ""), c2=ns.GetCoinColorOrTextureString(name,ceil(v[2]))});
				end
			end
		else
			lst({c0=L["No data found"]});
		end
	end


	tt:AddHeader(C("dkyellow",L[name]));
	tt:AddSeparator();
	local slotName = "";
	if (durabilityLslot) and (durabilityLslot~=0) then
		if (slotNames[durabilityLslot]) then
			slotName = (" (%s)"):format(L[slotNames[durabilityLslot]]);
		end
	end

	tt:AddLine(L["Lowest item"]..slotName,	C(colorSets(durabilityL) or "blue", durabilityL.."%"));
	tt:AddLine(L["Average"],				C(colorSets(durabilityA) or "blue", durabilityA.."%"));

	for i,v in ipairs(lst) do
		if (v.sep~=nil) then
			tt:AddSeparator(unpack(v.sep));
		elseif (v.c0~=nil) then
			local l,c = tt:AddLine();
			tt:SetCell(l,1,v.c0,nil,nil,2);
			if (v.f0~=nil) then
				tt:SetCellScript(l,1,"OnMouseUp",v.f0);
			end
		else
			local l,c = tt:AddLine();
			tt:SetCell(l,1,v.c1);
			tt:SetCell(l,2,v.c2);
		end
	end
	if (Broker_EverythingDB.showHints) then
		tt:AddSeparator(4,0,0,0,0);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
end

function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end

	ns.EasyMenu.InitializeMenu();

	ns.EasyMenu.addConfigElements(name);

	ns.EasyMenu.addEntry({ separator = true });

	ns.EasyMenu.addEntry({
		label = L["Reset last repairs"],
		colorName = "yellow",
		func  = function()
			wipe(last_repairs);
			wipe(be_durability_db);
		end,
		disabled = (false)
	});

	ns.EasyMenu.ShowMenu(self);
end

------------------------------------
-- module (BE internal) functions --
------------------------------------

ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name;

	local empty=true;
	if (be_durability_db) then
		for i,v in pairs(be_durability_db) do empty=false; end
	end

	hiddenTooltip = CreateFrame("GameTooltip", "BE_Durability_ScanTip", nil, "GameTooltipTemplate")
	hiddenTooltip:SetOwner(UIParent, "ANCHOR_NONE")

	date_format = Broker_EverythingDB[name].dateFormat;
	if (be_durability_db==nil) then
		be_durability_db = {};
	end
	if (Broker_EverythingDB[name].saveCosts) then
		last_repairs = be_durability_db;
	end

	_G['MerchantRepairAllButton']:HookScript("OnClick",function(self,button)
		ns.modules[name].onevent({},"BE_EVENT_REPAIRALL_PLAYER");
	end);

	_G['MerchantGuildBankRepairButton']:HookScript("OnClick",function(self,button)
		ns.modules[name].onevent({},"BE_EVENT_REPAIRALL_GUILD");
	end);
end

ns.modules[name].onevent = function(self,event,msg)
	if (event=="MERCHANT_SHOW") then
		local costs, canRepair = GetRepairAllCost();
		if (costs>0) and (canRepair) then
			merchant.repair=true;
			merchant.costs=costs;
			if (Broker_EverythingDB[name].autorepair) then
				if (AutoRepairAll(costs)==false) and (Broker_EverythingDB[name].chatRepairInfo) then
					ns.print(L["AutoRepair"], L["Automatic repair failed. Not enough money..."]);
				end
				return;
			end
		end
	end

	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end

	-- RepairAll - ButtonHooks - custom events
	if (event=="BE_EVENT_REPAIRALL_GUILD") then
		lastRepairs_add(merchant.costs,true);
		if (Broker_EverythingDB[name].chatRepairInfo) then
			ns.print(L["RepairAll"],L["by guild fund"]..":",ns.GetCoinColorOrTextureString(name,merchant.costs));
		end
		merchant.costs=0;
	elseif (event=="BE_EVENT_REPAIRALL_PLAYER") then
		lastRepairs_add(merchant.costs);
		if (Broker_EverythingDB[name].chatRepairInfo) then
			ns.print(L["RepairAll"],L["by player money"]..":",ns.GetCoinColorOrTextureString(name,merchant.costs));
		end
		merchant.costs=0;
	end

	if (merchant.repair) then
		if (InRepairMode()) and (merchant.costs>0) and (event=="PLAYER_MONEY") then
			local costs = GetRepairAllCost();
			merchant.diff = merchant.costs-costs;
			if (merchant.diff>0) then
				merchant.costs = costs;
				merchant.single = merchant.single + merchant.diff; -- single item repair mode, step 1
			end
		end

		if (event=="MERCHANT_CLOSED") then
			if (merchant.single>0) then -- single item repair mode, step 2
				lastRepairs_add(merchant.single, nil, false);
				if (Broker_EverythingDB[name].chatRepairInfo) then
					ns.print(L["SingleRepairSummary"]..":",ns.GetCoinColorOrTextureString(name,merchant.single));
				end
			end
			merchant = {repair=false,costs=0,diff=0,single=0};
		end
	end

	local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName) 
	local repairCosts, equipCost, bagCost, dA, dL, dLSlot, d = scanAll();

	if (Broker_EverythingDB[name].inBroker=="costs") then
		dataobj.text = ns.GetCoinColorOrTextureString(name,repairCosts)
	else
		d = floor((Broker_EverythingDB[name].lowestItem) and dL or dA);
		if (Broker_EverythingDB[name].inBroker=="percent") then
			dataobj.text = C(colorSets(d)or "blue",d.."%");
		elseif (Broker_EverythingDB[name].inBroker=="percent/costs") then
			dataobj.text = C(colorSets(d)or "blue",d.."%")..", "..ns.GetCoinColorOrTextureString(name,repairCosts);
		elseif (Broker_EverythingDB[name].inBroker=="costs/percent") then
			dataobj.text = ns.GetCoinColorOrTextureString(name,repairCosts)..", "..C(colorSets(d) or "blue",d.."%");
		end
	end

	date_format = Broker_EverythingDB[name].dateFormat;
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].ontooltip = function(tt) end
-- ns.modules[name].ondblclick = function(self,button) end

ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	tt = ns.LQT:Acquire(ttName, 2, "LEFT", "RIGHT");
	durabilityTooltip(tt);
	ns.createTooltip(self,tt);
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
end


--[[

untracked issue:
	1. merchant open
	2. enter single repair mode
	3. use complete repair by own money and guild fund
	4. Error message and 3 entries in repairlog with same costs...

]]


