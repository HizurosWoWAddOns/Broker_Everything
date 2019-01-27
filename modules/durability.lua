
-- module independent variables --
----------------------------------
local addon, ns = ...;
local C, L, I = ns.LC.color, ns.L, ns.I;


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name,_ = "Durability"; -- DURABILITY L["ModDesc-Durability"]
local ttName,tt,module = name.."TT";
local hiddenTooltip
local last_repairs = {};
local merchant,currentDurability = {repair=false,costs=0,diff=0,single=0},{0, 0, 0, 100, 100, false};
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
		local set = t[ns.profile[name].colorSet]
		for i,v in ns.pairsByKeys(set) do if d>=n and d<=i then c,n = v,i+1 end end
		return c
	end
})


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Minimap\\TRACKING\\Repair",coords={0.05,0.95,0.05,0.95}}; --IconName::Durability--


-- some local functions --
--------------------------
local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName) or {};
	local repairCosts, equipCost, bagCost, dA, dL, dLSlot, d = unpack(currentDurability);

	if (ns.profile[name].inBroker=="costs") then
		dataobj.text = ns.GetCoinColorOrTextureString(name,repairCosts)
	else
		d = floor((ns.profile[name].lowestItem) and dL or dA);
		if (ns.profile[name].inBroker=="percent") then
			obj.text = C(colorSets(d)or "blue",d.."%");
		elseif (ns.profile[name].inBroker=="percent/costs") then
			obj.text = C(colorSets(d)or "blue",d.."%")..", "..ns.GetCoinColorOrTextureString(name,repairCosts);
		elseif (ns.profile[name].inBroker=="costs/percent") then
			obj.text = ns.GetCoinColorOrTextureString(name,repairCosts)..", "..C(colorSets(d) or "blue",d.."%");
		end
	end
end

local function nsItemsCallback(updateMode)
	local repairCostInv,repairCostBags,all_current,all_maximum,lowest = 0,0,0,0,{1,false};
	local itemList = ns.items.GetItemlist();

	for itemID, items in pairs(itemList) do
		for i=1, #items do
			if (items[i].itemType==ARMOR or items[i].itemType==WEAPON) and items[i].durability and items[i].durability_max>0 and items[i].durability<items[i].durability_max then
				if items[i].type=="inventory" then
					repairCostInv = repairCostInv + (tonumber(items[i].repairCost) or 0);
					all_current,all_maximum = all_current+items[i].durability,all_maximum+items[i].durability_max;
					local percent = items[i].durability/items[i].durability_max;
					if percent<lowest[1] then
						lowest = {percent,items[i].slot};
					end
				else
					repairCostBags = repairCostBags + (tonumber(items[i].repairCost) or 0);
				end
			end
		end
	end

	local avPercent = 1;
	if all_maximum>0 then
		avPercent = all_current/all_maximum;
	end

	local total = repairCostInv+repairCostBags;
	if merchant.repair then
		total = GetRepairAllCost();
		-- can be different??
	end

	currentDurability = {total, repairCostInv, repairCostBags, avPercent*100, lowest[1]*100, lowest[2]};
	updateBroker();
end

local function lastRepairs_add(cost,fund,repairType)
	local t = {};
	table.insert(last_repairs,1,{time(),cost,(fund==true),(repairType==true)});
	for i,v in ipairs(last_repairs) do
		if (#t<50) then table.insert(t,v); end
	end
	last_repairs = t;
	if (ns.profile[name].saveCosts) then
		ns.toon[name] = t;
	end
end

local function AutoRepairAll(costs)
	local chat = ns.profile[name].chatRepairInfo;
	if (ns.profile[name].autorepairbyguild==true) and (IsInGuild()==true) and (CanGuildBankRepair()==true) and (costs < GetGuildBankWithdrawMoney()) then
		if (not GetGuildInfoText():find("%[noautorepair%]")) then -- auto repair with guild fund allowed by guild leader?
			merchant = {repair=false,costs=0,diff=0,single=0}; -- must be changed befor Repair all items
			RepairAllItems(true);
			lastRepairs_add(costs,true,true);
			if (chat) then
				ns.print(L["Automatically repaired with guild money"]..":",ns.GetCoinColorOrTextureString(name,costs,{color="white"}));
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
			ns.print(L["Automatically repaired with player money"]..":",ns.GetCoinColorOrTextureString(name,costs,{color="white"}));
		end
		return nil;
	end
	return false;
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	local repairCost, equipCost, bagCost, durabilityA, durabilityL, durabilityLslot = unpack(currentDurability);
	local repairCostN = repairCost;
	local reputation = UnitReaction("npc", "player");
	if (discount[reputation]) then
		repairCostN = floor(repairCost/discount[reputation]);
	end
	durabilityA = floor(durabilityA);
	durabilityL = floor(durabilityL);

	local a,g,d = ns.profile[name].autorepair, ns.profile[name].autorepairbyguild;
	local lst = setmetatable({},{__call = function(t,a) rawset(t,#t+1,a) end});

	lst({sep={3,0,0,0,0}});
	lst({c1=C("ltblue",gsub(REPAIR_COST,":","")),c2=ns.GetCoinColorOrTextureString(name,repairCost,{inTooltip=true})});
	lst({sep={1}});
	lst({c1=CHARACTER,c2=ns.GetCoinColorOrTextureString(name,equipCost,{inTooltip=true})});
	lst({c1=L["Bags"],c2=ns.GetCoinColorOrTextureString(name,bagCost,{inTooltip=true})});

	if ns.profile[name].showDiscount then
		lst({sep={3,0,0,0,0}});
		lst({c0=C("ltblue",L["Reputation discounts"])});
		lst({sep={1}});
		lst({c1=C("white",FACTION_STANDING_LABEL4),  c2=ns.GetCoinColorOrTextureString(name,repairCostN,{inTooltip=true})});
		lst({c1=C("white",FACTION_STANDING_LABEL5), c2=ns.GetCoinColorOrTextureString(name,ceil(repairCostN * discount[5]),{inTooltip=true})});
		lst({c1=C("white",FACTION_STANDING_LABEL6), c2=ns.GetCoinColorOrTextureString(name,ceil(repairCostN * discount[6]),{inTooltip=true})});
		lst({c1=C("white",FACTION_STANDING_LABEL7),  c2=ns.GetCoinColorOrTextureString(name,ceil(repairCostN * discount[7]),{inTooltip=true})});
		lst({c1=C("white",FACTION_STANDING_LABEL8),  c2=ns.GetCoinColorOrTextureString(name,ceil(repairCostN * discount[8]),{inTooltip=true})});
	end

	if (ns.profile[name].listCosts) then
		lst({sep={3,0,0,0,0}});
		if (ns.profile[name].saveCosts) then
			lst({c0=C("ltblue",L["Last %d repair costs"]:format(ns.profile[name].maxCosts))});
		else
			lst({c1=C("ltblue",L["Last %d repair costs"]:format(ns.profile[name].maxCosts)),c2=C("ltblue",L["(session only)"])});
		end
		lst({sep={1}});
		if (#last_repairs>0) then
			local indicator = "";
			for i,v in ipairs(last_repairs) do
				if (i<=tonumber(ns.profile[name].maxCosts)) then
					indicator = ((v[4]) and "a" or "") .. ((v[3]) and "G" or "P");
					lst({c1=date(date_format,v[1]) .. (strlen(indicator)>0 and " "..indicator or ""), c2=ns.GetCoinColorOrTextureString(name,ceil(v[2]),{inTooltip=true})});
				end
			end
		else
			lst({c0=L["No data found"]});
		end
	end


	tt:AddHeader(C("dkyellow",DURABILITY));
	tt:AddSeparator();
	local slotName = "";
	if (durabilityLslot) and (durabilityLslot~=0) then
		if (slotNames[durabilityLslot]) then
			slotName = (" (%s)"):format(slotNames[durabilityLslot]);
		end
	end

	tt:AddLine(L["Lowest item"]..slotName,	C(colorSets(durabilityL) or "blue", durabilityL.."%"));
	tt:AddLine(GMSURVEYRATING3,				C(colorSets(durabilityA) or "blue", durabilityA.."%"));

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
	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0);
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"PLAYER_DEAD",
		"PLAYER_REGEN_ENABLED",
		"MERCHANT_CLOSED",
		"MERCHANT_SHOW",
		"PLAYER_MONEY",
		"CHAT_MSG_MONEY"
	},
	config_defaults = {
		enabled = false,
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
		chatRepairInfo = false
	},
	clickOptionsRename = {
		["charinfo"] = "1_open_character_info",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["charinfo"] = "CharacterInfo", -- _LEFT
		["menu"] = "OptionMenuCustom"
	}
};

ns.ClickOpts.addDefaults(module,{
	charinfo = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			lowestItem={ type="toggle", order=1, name=L["Lowest durability"], desc=L["Display the lowest item durability in broker."] },
			inBroker={ type="select", order=2, name=L["Broker format"], desc=L["Choose your favorite display format for the broker button."],
				values={
					["percent"]="54%",
					["costs"]="34.23.01",
					["costs/percent"]="32.27.16, 54%",
					["percent/costs"]="54%, 32.27.16"
				}
			},
		},
		tooltip = {
			showDiscount={ type="toggle", order=1, name=L["Show discount"], desc=L["Show list of reputation discounts in tooltip"] },
			dateFormat={ type="select", order=2, name=L["Date format"], desc=L["Choose the date format if used in the list of repair costs"], values=date_formats },
		},
		misc = {
			colorSet={ type="select", order=1, name=L["Percent color set"], desc=L["Choose your favorite color set in which the percent text in broker should be displayed."], values=colorSets.values, width="double" },
			header={ type="header", order=2, name=L["Repair options"] },
			autorepair={ type="toggle", order=4, name=L["Enable auto repair"], desc=L["Automatically repair your equipment on opening a merchant with repair option."] },
			autorepairbyguild={ type="toggle", order=5, name=L["Use guild money"], desc=function() return L["Use guild money on auto repair if you can"].. ( (GetGuildInfoText():find("%[noautorepair%]")) and "|n"..C("red",L["Your guild leadership denied the use of guild money for auto repair."]) or ""); end, --[[disabled=function() return (GetGuildInfoText():find("%[noautorepair%]")); end]] },
			chatRepairInfo={ type="toggle", order=6, name=L["Repair info"], desc=L["Post repair actions in chatframe"] },
			listCosts={ type="toggle", order=7, name=L["List of repair costs"], desc=L["Display a list of the last repair costs in tooltip"] },
			saveCosts={ type="toggle", order=8, name=L["Save repair costs"], desc=L["Save the list of repair costs over the session"] },
			maxCosts={ type="range", order=9, name=L["Max. list entries"], desc=L["Choose how much entries the list of repair costs can have."], min=1, max=50, step=1 },
		},
	},
	{
		dateFormat=true,
		colorSet=true,
		autorepair=true,
		autorepairbyguild=true
	}
end

function module.OptionMenu(self,button,modName)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end

	ns.EasyMenu:InitializeMenu();

	ns.EasyMenu:AddConfig(name);

	ns.EasyMenu:AddEntry({ separator = true });

	ns.EasyMenu:AddEntry({
		label = L["Reset last repairs"],
		colorName = "yellow",
		func  = function()
			wipe(last_repairs);
			wipe(ns.toon[name]);
		end,
		disabled = (false)
	});

	ns.EasyMenu:ShowMenu(self);
end

function module.init()
	colorSets.set1 = {[20]="red",[40]="orange",[99]="yellow",[100]="green"};
	colorSets.set2 = {[15]="red",[40]="orange",[70]="yellow",[100]="white"};
	colorSets.set3 = {[20]="red",[40]="orange",[60]="yellow",[99]="green",[100]="ltblue"};
	colorSets.set4 = {[15]="red",[40]="orange",[60]="yellow",[80]="green",[100]="white"};

	if not hiddenTooltip then
		hiddenTooltip = CreateFrame("GameTooltip", "BE_Durability_ScanTip", nil, "GameTooltipTemplate")
		hiddenTooltip:SetOwner(UIParent, "ANCHOR_NONE")
		for _,v in ipairs({"OnLoad","OnHide","OnTooltipAddMoney","OnTooltipSetDefaultAnchor","OnTooltipCleared"})do
			hiddenTooltip:SetScript(v,nil);
		end
	end

	date_format = ns.profile[name].dateFormat;

	if (ns.toon[name]==nil) then
		ns.toon[name] = {};
	end

	if (ns.profile[name].saveCosts) then
		last_repairs = ns.toon[name];
	end

	MerchantRepairAllButton:HookScript("OnClick",function(self,button)
		module.onevent({},"BE_EVENT_REPAIRALL_PLAYER");
	end);

	MerchantGuildBankRepairButton:HookScript("OnClick",function(self,button)
		module.onevent({},"BE_EVENT_REPAIRALL_GUILD");
	end);

	ns.items.RegisterCallback(name,nsItemsCallback,"any");
end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" then
		if arg1 and arg1:find("^ClickOpt") then
			ns.ClickOpts.update(name);
			return;
		end
		date_format = ns.profile[name].dateFormat;
	elseif event=="MERCHANT_SHOW" then
		local costs, canRepair = GetRepairAllCost();
		if (costs>0) and (canRepair) then
			merchant.repair=true;
			merchant.costs=costs;
			if (ns.profile[name].autorepair) then
				if (AutoRepairAll(costs)==false) and (ns.profile[name].chatRepairInfo) then
					ns.print(L["AutoRepair"], L["Automatically repair failed. Not enough money..."]);
				end
			end
		end
	elseif ns.eventPlayerEnteredWorld then
		-- RepairAll - ButtonHooks - custom events
		if (event=="BE_EVENT_REPAIRALL_GUILD") then
			lastRepairs_add(merchant.costs,true);
			if (ns.profile[name].chatRepairInfo) then
				ns.print(L["RepairAll"],L["by guild fund"]..":",ns.GetCoinColorOrTextureString(name,merchant.costs,{color="white"}));
			end
			merchant.costs=0;
		elseif (event=="BE_EVENT_REPAIRALL_PLAYER") then
			lastRepairs_add(merchant.costs);
			if (ns.profile[name].chatRepairInfo) then
				ns.print(L["RepairAll"],L["by player money"]..":",ns.GetCoinColorOrTextureString(name,merchant.costs,{color="white"}));
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
					if (ns.profile[name].chatRepairInfo) then
						ns.print(L["SingleRepairSummary"]..":",ns.GetCoinColorOrTextureString(name,merchant.single,{color="white"}));
					end
				end
				merchant = {repair=false,costs=0,diff=0,single=0};
			end
		end
	end
end

-- function module.onclick(self,button) end
-- function module.onmousewheel(self,direction) end
-- function module.optionspanel(panel) end
-- function module.ontooltip(tt) end
-- function module.ondblclick(self,button) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, 2, "LEFT", "RIGHT"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
