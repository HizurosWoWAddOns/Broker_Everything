
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Equipment"; -- BAG_FILTER_EQUIPMENT L["ModDesc-Equipment"]
local ttName, ttColumns, tt, module, equipPending = name.."TT", 3;
local objLink,objColor,objType,objId,objData,objName,objInfo,objTooltip=1,2,3,4,6,5,7,8;
local itemEnchant,itemGem1,itemGem2,itemGem3,itemGem4=1,2,3,4,5;
local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice=1,2,3,4,5,6,7,8,9,10,11;
local slots = {"HEAD","NECK","SHOULDER","SHIRT","CHEST","WAIST","LEGS","FEET","WRIST","HANDS","FINGER0","FINGER1","TRINKET0","TRINKET1","BACK","MAINHAND","SECONDARYHAND","RANGED","TABARD"};
local inventory,enchantSlots = {iLevelMin=0,iLevelMax=0},{}; -- (enchantSlots) -1 = [iLevel<600], 0 = both, 1 = [iLevel=>600]
local warlords_crafted,tSetItems = {},{};
local extendedItemInfos,isRegistered = {};
local ignoreWeapon = {
	["0"] = L["Do not ignore"],
	["1"] = L["Ignore all"],
	["2"] = L["Ignore artifact weapons"],
};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\ICONS\\INV_Chest_Chain", coords={0.1,0.9,0.1,0.9}}; --IconName::Equipment--

-- some local functions --
--------------------------

local function pairsEquipmentSets()
	local equipSetIDs = C_EquipmentSet.GetEquipmentSetIDs() or {};
	local i = 0;
	return function()
		i = i + 1;
		if equipSetIDs[i] then
			return C_EquipmentSet.GetEquipmentSetInfo(equipSetIDs[i]);
		end
		return nil;
	end
end

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
	local icon,iconCoords,text = I[name].iconfile,{0.1,0.9,0.1,0.9},{};
	local pending = (equipPending and C("orange",equipPending)) or false;

	if ns.profile[name].showCurrentSet and C_EquipmentSet then
		for equipName, iconFileID, setID, isEquipped, _, _, _, numMissing in pairsEquipmentSets() do
			if equipName and isEquipped then
				icon,iconCoords = iconFileID,{0.05,0.95,0.05,0.95};
				tinsert(text,equipPending==setID and pending or equipName);
			end
		end
		if #text==0 then
			local txt = L["No sets found"];
			if ns.profile[name].showShorterInfo then
				txt = L["No sets"];
			end
			tinsert(text,pending or txt);
		end
	elseif pending~=false then
		tinsert(text,pending);
	end

	if ns.profile[name].showItemLevel and GetAverageItemLevel then
		local _, ilevel = GetAverageItemLevel();
		tinsert(text,("%1.1f"):format(ilevel or 0));
	end

	obj.iconCoords = iconCoords;
	obj.icon = icon;
	obj.text = #text>0 and table.concat(text,", ") or BAG_FILTER_EQUIPMENT;
end

local function UpdateInvSlotTooltip(data)
	extendedItemInfos[data.slot] = data;
end

local function UpdateInventory()
	local lst,lvl={iLevelMin=0,iLevelMax=0};
	for _, d in pairs(ns.items.bySlot)do
		if d and d.bag==-1 then
			local obj,_ = CopyTable(d);
			obj.type = "inv";
			ns.ScanTT.query(obj,true);
			lst[d.slot] = obj;
			if ns.client_version>=6 and d.slot~=4 and d.slot~=19 then
				obj.level = obj.level or 0;
				if lst.iLevelMin==0 or obj.level<lst.iLevelMin then
					lst.iLevelMin=obj.level;
				end
				if obj.level>lst.iLevelMax then
					lst.iLevelMax=obj.level;
				end
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

local function InventoryTooltipShow(self,slot)
	GameTooltip:SetOwner(self,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(self,"horizontal",tt));

	GameTooltip:ClearLines();
	GameTooltip:SetInventoryItem("player", slot);

	GameTooltip:SetFrameLevel(self:GetFrameLevel()+1);
	GameTooltip:Show();
end

local function equipOnClick(self,equipSetID)
	if (IsShiftKeyDown()) then
		if (tt) and (tt:IsShown()) then ns.hideTooltip(tt); end
		local main = ns.items.bySlot[-0.16];
		if (ns.profile[name].ignoreMainHand=="2" and main and main.quality==6) or ns.profile[name].ignoreMainHand=="1" then
			C_EquipmentSet.IgnoreSlotForSave(16);
		end
		local off = ns.items.bySlot[-0.17];
		if (ns.profile[name].ignoreOffHand=="2" and off and off.quality==6) or ns.profile[name].ignoreOffHand=="1" then
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

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	local line, column, hasSets
	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",BAG_FILTER_EQUIPMENT))

	if (ns.profile[name].showSets) and C_EquipmentSet then
		-- equipment sets
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",WARDROBE_SETS));
		tt:AddSeparator();
		if (CanUseEquipmentSets) and (not CanUseEquipmentSets()) then  -- prevent error if function removed
			ns.AddSpannedLine(tt,L["Equipment manager is not enabled"]);
			ns.AddSpannedLine(tt,L["Enable it from the character info"]);
		else
			for eName, icon, setID, isEquipped, _, _, _, numMissing in pairsEquipmentSets() do
				if eName then
					local color = (equipPending and equipPending==setID and "orange") or (numMissing>0 and "red") or (isEquipped and "ltyellow") or false
					local formatName = color~=false and C(color,eName) or eName;

					local line = ns.AddSpannedLine(tt, "|T"..(icon or ns.icon_fallback)..":0|t "..formatName);
					tt:SetLineScript(line, "OnMouseUp", equipOnClick,setID);
					tt:SetLineScript(line, "OnEnter", equipOnEnter,setID);
					tt:SetLineScript(line, "OnLeave", GameTooltip_Hide);
					hasSets = true;
				end
			end
			if not hasSets then
				ns.AddSpannedLine(tt, L["No equipment sets found"]);
			elseif ns.profile.GeneralOptions.showHints then
				tt:AddSeparator();
				ns.AddSpannedLine(tt, C("ltblue",L["MouseBtn"]).." "..C("green",L["to equip"]) .." - ".. C("ltblue",L["ModKeyC"].."+"..L["MouseBtn"]).." "..C("green",L["to delete"]));
				ns.AddSpannedLine(tt, C("ltblue",L["ModKeyS"].."+"..L["MouseBtn"]).." "..C("green",L["to update/save"]));
			end
		end
	end

	if (ns.profile[name].showInventory) then
		UpdateInventory();
		tt:AddSeparator(4,0,0,0,0);
		local l=tt:AddLine(
			C("ltblue",TRADESKILL_FILTER_SLOTS),
			C("ltblue",NAME)
		);
		if ns.client_version>=6 then
			tt:SetCell(l,3,C("ltblue",LEVEL));
		end

		tt:AddSeparator();

		local prof1, prof2, prof1SkillLine, prof2SkillLine, _;
		if GetProfessions then
			prof1, prof2 = GetProfessions();
		end
		if prof1 then
			_,_,_,_,_,_,prof1SkillLine = GetProfessionInfo(prof1);
		end
		if prof2 then
			_,_,_,_,_,_,prof2SkillLine = GetProfessionInfo(prof2);
		end
		--ns:debugPrint(name,prof1SkillLine,prof2SkillLine)

		local none,miss=true,false;
		local iSlots = {1,2,3,15,5,9,10,6,7,8,11,12,13,14,16,17};
		if ns.profile[name].showShirt then
			tinsert(iSlots,6,4);
		end
		if ns.profile[name].showTabard then
			tinsert(iSlots,6,19);
		end
		for _,i in ipairs(iSlots) do
			local obj = ns.items.bySlot[-(i/100)];
			if obj and inventory[obj.slot] then
				none=false;

				-- nice blizzard. Query heirloom item info's. very unstable/slow...
				local itemName, _, itemQuality, itemLevel, _, itemType, subType = GetItemInfo(obj.link);
				if not itemName then
					tt:AddLine(
						C("ltyellow",_G[slots[i].."SLOT"]),
						C("gray",L["Pending item info request..."])
					);
				else
					local itemInfo = inventory[obj.slot];
					local tSetItem,setName,enchanted,greenline,upgrades,gems = "","","","","","";
					itemQuality = itemQuality or itemInfo.quality or "black";
					itemName = itemName or obj.link:match("%[(.*)%]");

					local canEnchant = false;
					if type(enchantSlots[i])=="table" then -- tradeSkillID table
						for profSkillLine in pairs(enchantSlots[i]) do
							if profSkillLine==prof1SkillLine or profSkillLine==prof2SkillLine then
								canEnchant = true;
							end
						end
					elseif i==17 and itemType==LE_ITEM_CLASS_WEAPON then -- has equipped weapon in off-hand
						canEnchant = enchantSlots[16]==true;
					else
						canEnchant = enchantSlots[i]==true;
					end

					if ns.profile[name].showNotEnchanted and obj.id~=158075 --[[ hearth of azeroth can't be enchanted ]] and canEnchant and (tonumber(itemInfo.linkData[1]) or 0)==0 then
						enchanted=C("red"," #");
						miss=true;
					end

					if ns.profile[name].showEmptyGems and itemInfo.empty_gem then
						gems=C("yellow"," #");
						miss=true;
					end

					if ns.profile[name].showSetName and itemInfo.setname then
						setName=" "..C("dkgreen",itemInfo.setname);
					end

					if(ns.profile[name].showGreenText and itemInfo.lines and type(itemInfo.lines[2])=="string" and itemInfo.lines[2]:find("\124"))then
						greenline = " "..itemInfo.lines[2];
					end

					if ns.profile[name].showUpgrades and itemInfo.upgrades then
						local col,cur,max = "ltblue",strsplit("/",itemInfo.upgrades);
						if ns.profile[name].fullyUpgraded and cur==max then
							col="blue";
						end
						upgrades = " "..C(col,itemInfo.upgrades);
					end

					if ns.client_version>=6 and itemInfo.level then
						itemLevel = C(GetILevelColor(itemInfo.level),itemInfo.level);
					else
						itemLevel = "";
					end

					if ns.profile[name].showTSet and tSetItems[obj.id] then
						tSetItem=C("yellow"," T"..tSetItems[obj.id]);
					end

					if i==19 or i==4 then
						itemLevel = "";
					end

					local l = tt:AddLine(
						C("ltyellow",_G[slots[i].."SLOT"]),
						C("quality"..itemQuality,itemName) .. greenline .. tSetItem .. setName .. upgrades .. enchanted .. gems,
						itemLevel
					);

					tt:SetLineScript(l,"OnEnter",InventoryTooltipShow, obj.slot);
					tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);
				end
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
		if ns.client_version>=6 and GetAverageItemLevel then
			local _, avgItemLevelEquipped = GetAverageItemLevel();
			local l = tt:AddLine(nil,nil,C(GetILevelColor(avgItemLevelEquipped),"%.1f"):format(avgItemLevelEquipped));
			tt:SetCell(l,1,C("ltblue",STAT_AVERAGE_ITEM_LEVEL),nil,nil,2);
		end
		if (miss) then
			ns.AddSpannedLine(tt,C("red","#")..CHAT_HEADER_SUFFIX..C("ltgray",L["Item is not enchanted"]) .. " || " .. C("yellow","#")..CHAT_HEADER_SUFFIX..C("ltgray",L["Item has empty socket"]));
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
		"PLAYER_LOGIN",
		"PLAYER_REGEN_ENABLED",
		"PLAYER_ALIVE",
		"PLAYER_UNGHOST",
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
		showTabard = false,
		showShirt = false,

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
		["sets"] = {EQUIPMENT_MANAGER,"module","equipMan"},
		["menu"] = "OptionMenu"
	}
}

if ns.client_version>=6 then
	tinsert(module.events,"EQUIPMENT_SWAP_FINISHED");
	--tinsert(module.events,"ITEM_UPGRADE_MASTER_UPDATE"); -- TODO: removed in 9.1.5
	tinsert(module.events,"EQUIPMENT_SETS_CHANGED");
end

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
			showCurrentSet={ type="toggle", order=1, name=L["CurrentSet"], desc=L["CurrentSetDesc"], hidden=ns.IsClassicClient},
			showItemLevel={ type="toggle", order=2, name=L["AvItemLvl"], desc=L["AvItemLvlDesc"], hidden=ns.IsClassicClient},
			showShorterInfo={ type="toggle", order=3, name=L["ShorterSetInfo"], desc=L["ShorterSetInfoDesc"], hidden=ns.IsClassicClient},
		},
		tooltip = {
			showSets={ type="toggle", order=1, name=L["EquipSets"], desc=L["EquipSetsDesc"], hidden=ns.IsClassicClient},
			showInventory={ type="toggle", order=2, name=L["Show inventory"], desc=L["Display a list of currently equipped items"]},
			showEmptySlots={ type="toggle", order=3, name=L["Show emtpy slots"], desc=L["Display empty equipment slots"]},
			showNotEnchanted={ type="toggle", order=4, name=L["Show 'not enchanted' mark"], desc=L["Display a red # on not enchanted/enchantable items"]},
			showEmptyGems={ type="toggle", order=5, name=L["Show 'empty socket' mark"], desc=L["Display a yellow # on items with empty sockets"]},
			showTSet={ type="toggle", order=6, name=L["Show T-Set"], desc=L["Display a T-Set label on items"], hidden=ns.IsClassicClient},
			showSetName={ type="toggle", order=7, name=L["Show Set name"], desc=L["Display set name on items"], hidden=ns.IsClassicClient},
			showGreenText={ type="toggle", order=8, name=L["Show green text"], desc=L["Display green text line from item tooltip like titanforged"], hidden=ns.IsClassicClient},
			showUpgrades={ type="toggle", order=9, name=L["Show upgrade info"], desc=L["Display upgrade info like 2/6"], hidden=ns.IsClassicClient},
			fullyUpgraded={ type="toggle", order=10, name=L["Darker blue for fully upgraded"], desc=L["Display upgrade counter in darker blue on fully upgraded items"], hidden=ns.IsClassicClient},
			showTabard={ type="toggle", order=11, name=L["ShowTabard"], desc=L["ShowTabardDesc"]},
			showShirt={ type="toggle", order=12, name=L["ShowShirt"], desc=L["ShowShirtDesc"]},
		},
		misc = {
			ignoreMainHand={ type="select", order=1, name=L["Ignore main hand"], desc=L["'Save set' should ignore main hand weapon"], values=ignoreWeapon, hidden=ns.IsClassicClient },
			ignoreOffHand={ type="select", order=2, name=L["Ignore off-hand"], desc=L["'Save set' should ignore off-hand weapon"], values=ignoreWeapon, hidden=ns.IsClassicClient }
		},
	}
end

function module.init()
	--[[
	profession skill line id
	171 -- Alchemy
	164 -- Blacksmithing
	333 -- Enchanting
	202 -- Engineering
	773 -- Inscription
	755 -- Jewelcrafting
	165 -- Leatherworking
	197 -- Tailoring
	--]]

	if ns.client_version<3 then -- classic
		enchantSlots = {
			[8]=true, [9]=true,[5]=true,[10]=true,[15]=true,[17]=true,[16]=true, -- enchanters
		}
	elseif ns.client_version<6 then -- pre wod
		enchantSlots = {
			[1]=true,[5]=true,[6]=true,[8]=true,[9]=true,[10]=true,[11]=true,[12]=true,[15]=true,[16]=true,[17]=true, -- enchanters
			[3]=true, -- inscription
			[7]=true, -- misc trade skills
		};
	elseif ns.client_version<7 then -- pre legion
		enchantSlots = {
			[2]=true,[11]=true,[12]=true,[15]=true,[16]=true -- enchanters
		};
	elseif ns.client_version<8 then -- pre bfa
		enchantSlots = {
			[2]=true,[3]=true,[10]=true,[11]=true,[12]=true,[15]=true -- enchanters
		};
	elseif ns.client_version<9 then -- bfa
		enchantSlots = {
			[9]=true,[6]={[202]=true},[9]={[333]=true},[10]=true,[11]=true,[12]=true,[15]=true,[16]=true -- enchanters
		};
	else-- if ns.client_version<10 then -- sl
		-- idea: [<invSlot>] = true | { [<tradeSkillID>]=true, ... }
		enchantSlots = {
			[5]=true,[6]={[202]=true},[8]=true,[9]=true,[10]=true,[11]=true,[12]=true,[15]=true,[16]=true -- enchanters
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
	if not isRegistered then
		ns.items.RegisterCallback(name,updateBroker,"inv");
		isRegistered = true;
	end
end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" then
		if arg1 and arg1:find("^ClickOpt") then
			ns.ClickOpts.update(name);
			return;
		end
		updateBroker();
	elseif event=="ADDON_LOADED" and arg1=="Blizzard_ArtifactUI" and ArtifactRelicForgeFrame then
		ArtifactRelicForgeFrame:HookScript("OnHide",updateBroker);
		self:UnregisterEvent("ADDON_LOADED");
	elseif event=="PLAYER_LOGIN" then
		if not isRegistered then
			ns.items.RegisterCallback(name,UpdateInventory,"inv");  -- oops. register twice
			isRegistered = true;
		end
		if UpgradeItem then
			hooksecurefunc("UpgradeItem",updateBroker);
		end
		self:RegisterEvent("ADDON_LOADED");
	elseif (event=="PLAYER_REGEN_ENABLED" or event=="PLAYER_ALIVE" or event=="PLAYER_UNGHOST") and equipPending~=nil then
		if C_EquipmentSet then
			C_EquipmentSet.UseEquipmentSet(equipPending);
		end
		equipPending = nil
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
