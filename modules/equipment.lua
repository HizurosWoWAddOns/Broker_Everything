
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Equipment"; -- BAG_FILTER_EQUIPMENT
local ttName, ttColumns, tt, module, equipPending = name.."TT", 3;
local objLink,objColor,objType,objId,objData,objName,objInfo,objTooltip=1,2,3,4,6,5,7,8;
local itemEnchant,itemGem1,itemGem2,itemGem3,itemGem4=1,2,3,4,5;
local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice=1,2,3,4,5,6,7,8,9,10,11;
local slots = {"HEAD","NECK","SHOULDER","SHIRT","CHEST","WAIST","LEGS","FEET","WRIST","HANDS","FINGER0","FINGER1","TRINKET0","TRINKET1","BACK","MAINHAND","SECONDARYHAND","RANGED"};
local inventory,enchantSlots = {iLevelMin=0,iLevelMax=0},{}; -- (enchantSlots) -1 = [iLevel<600], 0 = both, 1 = [iLevel=>600]
local warlords_crafted,tSetItems = {},{};
local ignoreWeapon = {
	["0"] = L["Do not ignore"],
	["1"] = L["Ignore all"],
	["2"] = L["Ignore artifact weapons"],
};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\equip"}; --IconName::Equipment--


-- some local functions --
--------------------------
-- defined in addon namespace for chatcommand.lua
function ns.toggleEquipment(eSetID)
	if InCombatLockdown() or UnitIsDeadOrGhost("player") then
		equipPending = eSetID
		module.onevent("BE_DUMMY_EVENT")
	else
		C_EquipmentSet.UseEquipmentSet(eSetID);
	end
	ns.hideTooltip(tt);
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local icon,iconCoords,text = I[name].iconfile,{0,1,0,1},{};

	if ns.profile[name].showCurrentSet then
		local numEquipSets = C_EquipmentSet.GetNumEquipmentSets();

		if numEquipSets > 0 then
			local equipName, iconFile, setID, isEquipped, _, _, _, numMissing;
			for i=0, numEquipSets do
				equipName, iconFile, setID, isEquipped, _, _, _, numMissing = C_EquipmentSet.GetEquipmentSetInfo(i);
				if equipName then
					local pending = (equipPending and C("orange",equipPending)) or false;
					if isEquipped then
						iconCoords = {0.05,0.95,0.05,0.95}
						icon = iconFile;
						tinsert(text,pending~=false and pending or equipName);
					end
				end
			end
			if(#text==0)then
				local txt = L["Unknown set"];
				if ns.profile[name].showShorterInfo then
					txt = L["Set?"];
				end
				tinsert(text,pending~=false and pending or C("red",txt));
			end
		else
			local txt = L["No sets found"];
			if ns.profile[name].showShorterInfo then
				txt = L["No sets"];
			end
			tinsert(text,txt);
		end
	elseif pending~=false then
		tinsert(text,pending);
	end

	if(ns.profile[name].showItemLevel)then
		tinsert(text,("%1.1f"):format(select(2,GetAverageItemLevel()) or 0));
	end

	obj.iconCoords = iconCoords;
	obj.icon = icon;
	obj.text = #text>0 and table.concat(text,", ") or BAG_FILTER_EQUIPMENT;
end

local function UpdateInventory()
	local lst,data,lvl = {iLevelMin=0,iLevelMax=0},ns.items.GetInventoryItems();
	for _, d in pairs(data) do
		if d and tonumber(d.slotIndex) and d.slotIndex~=4 and d.slotIndex~=19 then
			lvl = tonumber(d.level) or 0;
			lst[d.slotIndex] = d;
			if lst.iLevelMin==0 or lvl<lst.iLevelMin then
				lst.iLevelMin=lvl;
			end
			if lvl>lst.iLevelMax then
				lst.iLevelMax=lvl;
			end
		end
	end
	inventory = lst;
	updateBroker();
end

local function GetILevelColor(il)
	local colors = {"cyan","green","yellow","orange","red"};
	if not inventory then
		UpdateInventory();
	end

	if (il==inventory.iLevelMax) then return colors[1]; end

	local diff,q = inventory.iLevelMax-inventory.iLevelMin;
	if (diff<=6) then
		if (il==inventory.iLevelMin) then return colors[3]; end
	else
		if (il==inventory.iLevelMin) then return colors[5]; end
		local p=floor(diff/3);
		local p1,p2,p3 = inventory.iLevelMin+p,inventory.iLevelMin+(p*2),inventory.iLevelMin+(p*3);

		if (il>p2) then
			return colors[2];
		elseif (il>p1) then
			return colors[3];
		elseif (il>inventory.iLevelMin) then
			return colors[4];
		end
	end

	return "white";
end

local function InventoryTooltipShow(self,link)
	GameTooltip:SetOwner(self,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(self,"horizontal",tt));

	GameTooltip:ClearLines();
	GameTooltip:SetHyperlink(link);

	GameTooltip:SetFrameLevel(self:GetFrameLevel()+1);
	GameTooltip:Show();
end

local function InventoryTooltipHide()
	GameTooltip:Hide();
end

local function equipOnClick(self,equipSetID)
	if (IsShiftKeyDown()) then
		if (tt) and (tt:IsShown()) then ns.hideTooltip(tt); end
		local main = ns.items.GetInventoryItemBySlotIndex(16);
		if (ns.profile[name].ignoreMainHand=="2" and main and main.rarity==6) or ns.profile[name].ignoreMainHand=="1" then
			C_EquipmentSet.IgnoreSlotForSave(16);
		end
		local off = ns.items.GetInventoryItemBySlotIndex(17);
		if (ns.profile[name].ignoreOffHand=="2" and off and off.rarity==6) or ns.profile[name].ignoreOffHand=="1" then
			C_EquipmentSet.IgnoreSlotForSave(17);
		end
		local setName = C_EquipmentSet.GetEquipmentSetInfo(equipSetID);
		local dialog = StaticPopup_Show('CONFIRM_SAVE_EQUIPMENT_SET', setName);
		if dialog then
			dialog.data = equipSetID;
		end
	elseif (IsControlKeyDown()) then
		if (tt) and (tt:IsShown()) then ns.hideTooltip(tt); end
		local setName = C_EquipmentSet.GetEquipmentSetInfo(equipSetID);
		local dialog = StaticPopup_Show('CONFIRM_DELETE_EQUIPMENT_SET', setName);
		if dialog then
			dialog.data = equipSetID;
		end
	else
		ns.toggleEquipment(equipSetID);
	end
end

local function equipOnEnter(self,equipSetID)
	if equipSetID then
		GameTooltip:SetOwner(self,"ANCHOR_NONE");
		GameTooltip:SetPoint(ns.GetTipAnchor(self,"horizontal",tt));
		GameTooltip:SetEquipmentSet(equipSetID);
		GameTooltip:Show();
	end
end

local function equipOnLeave(self)
	GameTooltip:Hide();
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	local line, column
	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",BAG_FILTER_EQUIPMENT))

	if (ns.profile[name].showSets) then
		-- equipment sets
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",L["Sets"]));
		tt:AddSeparator();
		if (CanUseEquipmentSets) and (not CanUseEquipmentSets()) then  -- prevent error if function removed
			ns.AddSpannedLine(tt,L["Equipment manager is not enabled"]);
			ns.AddSpannedLine(tt,L["Enable it from the character info"]);
		else
			local numEquipSets = C_EquipmentSet.GetNumEquipmentSets()
			if (numEquipSets>0) then
				local eName, icon, setID, isEquipped, numMissing, _;
				for i=0, numEquipSets do
					eName, icon, setID, isEquipped, _, _, _, numMissing = C_EquipmentSet.GetEquipmentSetInfo(i);
					if eName then
						local color = (equipPending and equipPending==i and "orange") or (numMissing>0 and "red") or (isEquipped and "ltyellow") or false
						local formatName = color~=false and C(color,eName) or eName;

						local line = ns.AddSpannedLine(tt, "|T"..(icon or ns.icon_fallback)..":0|t "..formatName);
						tt:SetLineScript(line, "OnMouseUp", equipOnClick,setID);
						tt:SetLineScript(line, "OnEnter", equipOnEnter,setID);
						tt:SetLineScript(line, "OnLeave", equipOnLeave);
					end
				end
				if (ns.profile.GeneralOptions.showHints) then
					tt:AddSeparator();
					ns.AddSpannedLine(tt, C("ltblue",L["MouseBtn"]).." "..C("green",L["to equip"]) .." - ".. C("ltblue",L["ModKeyC"].."+"..L["MouseBtn"]).." "..C("green",L["to delete"]));
					ns.AddSpannedLine(tt, C("ltblue",L["ModKeyS"].."+"..L["MouseBtn"]).." "..C("green",L["to update/save"]));
				end
			else
				ns.AddSpannedLine(tt,L["No equipment sets found"]);
			end
		end
	end

	if (ns.profile[name].showInventory) then
		UpdateInventory();
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(
			C("ltblue",TRADESKILL_FILTER_SLOTS),
			C("ltblue",NAME),
			C("ltblue",LEVEL)
		);
		tt:AddSeparator();
		local none,miss=true,false;
		for _,i in ipairs({1,2,3,15,5,9,10,6,7,8,11,12,13,14,16,17}) do
			if inventory[i] and inventory[i].rarity then
				none=false;
				local tSetItem,setName,enchanted,greenline,upgrades,gems = "","","","","","";
				if ns.profile[name].showNotEnchanted and enchantSlots[i] and (tonumber(inventory[i].linkData[1]) or 0)==0 then
					enchanted=C("red"," #");
					miss=true;
				end
				if ns.profile[name].showEmptyGems and inventory[i].empty_gem then
					gems=C("yellow"," #");
					miss=true;
				end
				if(ns.profile[name].showTSet and tSetItems[inventory[i].id])then
					tSetItem=C("yellow"," T"..tSetItems[inventory[i].id]);
				end
				if(ns.profile[name].showSetName and inventory[i].setname)then
					setName=" "..C("dkgreen",inventory[i].setname);
				end
				if(ns.profile[name].showGreenText and inventory[i].tooltip and type(inventory[i].tooltip[2])=="string" and inventory[i].tooltip[2]:find("\124"))then
					greenline = " "..inventory[i].tooltip[2];
				end
				if(ns.profile[name].showUpgrades and inventory[i].upgrades)then
					local col,cur,max = "ltblue",strsplit("/",inventory[i].upgrades);
					if ns.profile[name].fullyUpgraded and cur==max then
						col="blue";
					end
					upgrades = " "..C(col,inventory[i].upgrades);
				end
				local l = tt:AddLine(
					C("ltyellow",_G[slots[i].."SLOT"]),
					C("quality"..inventory[i].rarity,inventory[i].name) .. greenline .. tSetItem .. setName .. upgrades .. enchanted .. gems,
					C(GetILevelColor(inventory[i].level),inventory[i].level)
				);
				tt:SetLineScript(l,"OnEnter",InventoryTooltipShow, inventory[i].link);
				tt:SetLineScript(l,"OnLeave",InventoryTooltipHide);
			elseif ns.profile[name].showEmptySlots then
				tt:AddLine(
					C("ltyellow",_G[slots[i].."SLOT"]),
					C("gray",EMPTY)
				);
			end
		end
		if none and not ns.profile[name].showEmptySlots then
			local l = tt:AddLine();
			tt:SetCell(l,1,L["All slots are empty"],nil,nil,ttColumns);
		end
		tt:AddSeparator();
		local _, avgItemLevelEquipped = GetAverageItemLevel();
		local avgItemLevelEquippedf = floor(avgItemLevelEquipped);
		local l = tt:AddLine(nil,nil,C(GetILevelColor(avgItemLevelEquipped),"%.1f"):format(avgItemLevelEquipped));
		tt:SetCell(l,1,C("ltblue",STAT_AVERAGE_ITEM_LEVEL),nil,nil,2);
		if (miss) then
			ns.AddSpannedLine(tt,C("red","#")..": "..C("ltgray",L["Item is not enchanted"]) .. " || " .. C("yellow","#")..": "..C("ltgray",L["Item has empty socket"]));
		end
	end

	line, column = nil, nil
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
		"UNIT_INVENTORY_CHANGED",
		"EQUIPMENT_SWAP_FINISHED",
		"EQUIPMENT_SETS_CHANGED",
		"PLAYER_LOGIN",
		"PLAYER_REGEN_ENABLED",
		"PLAYER_ALIVE",
		"PLAYER_UNGHOST",
		"ITEM_UPGRADE_MASTER_UPDATE"
	},
	config_defaults = {
		enabled = true,
		showSets = true,
		showInventory = true,
		showEmptySlots = false,
		showItemLevel = true,
		showCurrentSet = true,
		fullyUpgraded = true,

		showNotEnchanted = true,
		showEmptyGems = true,
		showTSet = true,
		showSetName = true,
		showGreenText = true,
		showUpgrades = true,
		showShorterInfo = true,

		ignoreMainHand = "2",
		ignoreOffHand = "2"
	},
	clickOptionsRename = {
		["charinfo"] = "1_open_character_info",
		["sets"] = "3_open_equipment_sets_tab",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["charinfo"] = "CharacterInfo",
		["sets"] = {"Equipment manager","module","equipMan"}, -- L["Equipment manager"]
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	charinfo = "_LEFT",
	sets = "__NONE",
	menu = "_RIGHT"
});

function module.equipMan(self,button)
	securecall("ToggleCharacter","PaperDollFrame");
	securecall("PaperDollFrame_SetSidebar",nil,3);
end

function module.options()
	return {
		broker = {
			showCurrentSet={ type="toggle", order=1, name=L["Show current set"], desc=L["Display your current equipment set on broker button"]},
			showItemLevel={ type="toggle", order=2, name=L["Show average item level"], desc=L["Display your average item level on broker button"]},
			showShorterInfo={ type="toggle", order=3, name=L["Show shorter Info for 'Unknown set' and more"], desc=L["Display shorter Info on broker button. 'Set?' instead of 'Unknown set'. 'No sets' instead of 'No sets found'."]}
		},
		tooltip = {
			showSets={ type="toggle", order=1, name=L["Show equipment sets"], desc=L["Display a list of your equipment sets"]},
			showInventory={ type="toggle", order=2, name=L["Show inventory"], desc=L["Display a list of currently equipped items"]},
			showEmptySlots={ type="toggle", order=3, name=L["Show emtpy slots"], desc=L["Display empty equipment slots"]},
			showNotEnchanted={ type="toggle", order=4, name=L["Show 'not enchanted' mark"], desc=L["Display a red # on not enchanted/enchantable items"]},
			showEmptyGems={ type="toggle", order=5, name=L["Show 'empty socket' mark"], desc=L["Display a yellow # on items with empty sockets"]},
			showTSet={ type="toggle", order=6, name=L["Show T-Set"], desc=L["Display a T-Set label on items"]},
			showSetName={ type="toggle", order=7, name=L["Show Set name"], desc=L["Display set name on items"]},
			showGreenText={ type="toggle", order=8, name=L["Show green text"], desc=L["Display green text line from item tooltip like titanforged"]},
			showUpgrades={ type="toggle", order=9, name=L["Show upgrade info"], desc=L["Display upgrade info like 2/6"]},
			fullyUpgraded={ type="toggle", order=10, name=L["Darker blue for fully upgraded"], desc=L["Display upgrade counter in darker blue on fully upgraded items"]},
		},
		misc = {
			ignoreMainHand={ type="select", order=1, name=L["Ignore main hand"], desc=L["'Save set' should ignore main hand weapon"], values=ignoreWeapon },
			ignoreOffHand={ type="select", order=2, name=L["Ignore off-hand"], desc=L["'Save set' should ignore off-hand weapon"], values=ignoreWeapon }
		},
	}
end

function module.init()
	if ns.build<6000000 then
		enchantSlots = {
			[1]=1,[5]=1,[6]=1,[8]=1,[9]=1,[10]=1,[11]=1,[12]=1,[15]=1,[16]=1,[17]=1, -- enchanters
			[3]=1, -- inscription
			[7]=1, -- misc trade skills
		};
	elseif ns.build<7000000 then
		enchantSlots = {
			[2]=1,[11]=1,[12]=1,[15]=1,[16]=1 -- enchanters
		};
	else --if ns.build<8000000 then
		enchantSlots = {
			[2]=1,[3]=1,[10]=1,[11]=1,[12]=1,[15]=1 -- enchanters
		}
	end
	warlords_crafted = {
		-- Alchemy
		[122601]=1,[122602]=1,[122603]=1,[122604]=1,
		-- Blacksmithing
		[114230]=1,[114231]=1,[114232]=1,[114233]=1,
		[114234]=1,[114235]=1,[114236]=1,[114237]=1,
		-- Engineering
		[109171]=1,[109172]=1,[109173]=1,[109174]=1,
		-- Jewelcrafting
		[115794]=1,[115796]=1,[115798]=1,[115799]=1,
		[115800]=1,[115801]=1,
		-- Leatherworking
		[116174]=1,[116191]=1,[116193]=1,[116187]=1,
		[116188]=1,[116190]=1,[116194]=1,[116189]=1,
		[116192]=1,[116183]=1,[116176]=1,[116177]=1,
		[116180]=1,[116182]=1,[116179]=1,[116178]=1,
		[116181]=1,[116171]=1,[116175]=1,
		-- Tailoring
		[114809]=1,[114810]=1,[114811]=1,[114812]=1,
		[114813]=1,[114814]=1,[114815]=1,[114816]=1,
		[114817]=1,[114818]=1,[114819]=1,
	}
	tSetItems = {
		-- Tier 1
		[16828]=1,[16829]=1,[16830]=1,[16833]=1,[16831]=1,[16834]=1,[16835]=1,[16836]=1,[16851]=1,[16849]=1,[16850]=1,[16845]=1,[16848]=1,[16852]=1,
		[16846]=1,[16847]=1,[16802]=1,[16799]=1,[16795]=1,[16800]=1,[16801]=1,[16796]=1,[16797]=1,[16798]=1,[16858]=1,[16859]=1,[16857]=1,[16853]=1,
		[16860]=1,[16854]=1,[16855]=1,[16856]=1,[16811]=1,[16813]=1,[16817]=1,[16812]=1,[16814]=1,[16816]=1,[16815]=1,[16819]=1,[16827]=1,[16824]=1,
		[16825]=1,[16820]=1,[16821]=1,[16826]=1,[16822]=1,[16823]=1,[16838]=1,[16837]=1,[16840]=1,[16841]=1,[16844]=1,[16839]=1,[16842]=1,[16843]=1,
		-- Tier 2
		-- Tier 3
		-- Tier 4
		-- Tier 5
		-- Tier 6
		-- Tier 7
		-- Tier 8
		-- Tier 9
		-- Tier 10
		-- Tier 11
		-- Tier 12
		-- Tier 13
		-- Tier 14
		-- Tier 15
		-- Tier 16
		-- Tier 17 (WoD 6.0)
		[115535]=17,[115536]=17,[115537]=17,[115538]=17,[115539]=17,[115540]=17,[115541]=17,[115542]=17,[115543]=17,[115544]=17,[115545]=17,
		[115546]=17,[115547]=17,[115548]=17,[115549]=17,[115550]=17,[115551]=17,[115552]=17,[115553]=17,[115554]=17,[115555]=17,[115556]=17,
		[115557]=17,[115558]=17,[115559]=17,[115560]=17,[115561]=17,[115562]=17,[115563]=17,[115564]=17,[115565]=17,[115566]=17,[115567]=17,
		[115568]=17,[115569]=17,[115570]=17,[115571]=17,[115572]=17,[115573]=17,[115574]=17,[115575]=17,[115576]=17,[115577]=17,[115578]=17,
		[115579]=17,[115580]=17,[115581]=17,[115582]=17,[115583]=17,[115584]=17,[115585]=17,[115586]=17,[115587]=17,[115588]=17,[115589]=17,
		-- Tier 18 (WoD 6.2)
		[124154]=18,[124155]=18,[124156]=18,[124160]=18,[124161]=18,[124162]=18,[124165]=18,[124166]=18,[124167]=18,[124171]=18,[124172]=18,
		[124173]=18,[124177]=18,[124178]=18,[124179]=18,[124246]=18,[124247]=18,[124248]=18,[124255]=18,[124256]=18,[124257]=18,[124261]=18,
		[124262]=18,[124263]=18,[124267]=18,[124268]=18,[124269]=18,[124272]=18,[124273]=18,[124274]=18,[124284]=18,[124292]=18,[124293]=18,
		[124296]=18,[124297]=18,[124301]=18,[124302]=18,[124303]=18,[124307]=18,[124308]=18,[124317]=18,[124318]=18,[124319]=18,[124327]=18,
		[124328]=18,[124329]=18,[124332]=18,[124333]=18,[124334]=18,[124338]=18,[124339]=18,[124340]=18,[124344]=18,[124345]=18,[124346]=18,
		-- Tier 19 (Legion 7.0)
		[138309]=19,[138310]=19,[138311]=19,[138312]=19,[138313]=19,[138314]=19,[138315]=19,[138316]=19,[138317]=19,[138318]=19,[138319]=19,
		[138320]=19,[138321]=19,[138322]=19,[138323]=19,[138324]=19,[138325]=19,[138326]=19,[138327]=19,[138328]=19,[138329]=19,[138330]=19,
		[138331]=19,[138332]=19,[138333]=19,[138334]=19,[138335]=19,[138336]=19,[138337]=19,[138338]=19,[138339]=19,[138340]=19,[138341]=19,
		[138342]=19,[138343]=19,[138344]=19,[138345]=19,[138346]=19,[138347]=19,[138348]=19,[138349]=19,[138350]=19,[138351]=19,[138352]=19,
		[138353]=19,[138354]=19,[138355]=19,[138356]=19,[138357]=19,[138358]=19,[138359]=19,[138360]=19,[138361]=19,[138362]=19,[138363]=19,
		[138364]=19,[138365]=19,[138366]=19,[138367]=19,[138368]=19,[138369]=19,[138370]=19,[138371]=19,[138372]=19,[138373]=19,[138374]=19,
		[138375]=19,[138376]=19,[138377]=19,[138378]=19,[138379]=19,[138380]=19,
		-- Tier 20 (Legion 7.?)
	}
end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="ADDON_LOADED" and arg1=="Blizzard_ArtifactUI" and ArtifactRelicForgeFrame then
		ArtifactRelicForgeFrame:HookScript("OnHide",updateBroker);
	elseif event=="PLAYER_LOGIN" then
		ns.items.RegisterCallback(name,UpdateInventory,"inv");
		hooksecurefunc("UpgradeItem",updateBroker);
	elseif ns.eventPlayerEnteredWorld then
		if (event=="PLAYER_REGEN_ENABLED" or event=="PLAYER_ALIVE" or event=="PLAYER_UNGHOST") and equipPending~=nil then
			C_EquipmentSet.UseEquipmentSet(equipPending);
			equipPending = nil
			updateBroker();
		end
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "LEFT", "RIGHT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
