
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
local ttColumns;

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Equipment";
L.Equipment = BAG_FILTER_EQUIPMENT;
local ldbName = name
local ttName = name.."TT"
local tt,createMenu,equipPending
local inventory = {};
local objLink,objColor,objType,objId,objData,objName,objInfo,objTooltip=1,2,3,4,6,5,7,8;
local itemEnchant,itemGem1,itemGem2,itemGem3,itemGem4=1,2,3,4,5;
local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice=1,2,3,4,5,6,7,8,9,10,11;
local slots = {"HEAD","NECK","SHOULDER","SHIRT","CHEST","WAIST","LEGS","FEET","WRIST","HANDS","FINGER0","FINGER1","TRINKET0","TRINKET1","BACK","MAINHAND","SECONDARYHAND","RANGED"};
local enchantSlots = { -- -1 = [iLevel<600], 0 = both, 1 = [iLevel=>600]
	-- enchanters
	[1]  = -1,	-- Head
	[2]  =  1,	-- Neck
	[5]  = -1,	-- Chest
	[6]  = -1,	-- Waist
	[8]  = -1,	-- Feet
	[9]  = -1,	-- Wrist
	[10] = -1,	-- Hands
	[11] =  0,	-- Ring
	[12] =  0,	-- Ring
	[15] =  0,	-- Back
	[16] =  0,	-- Weapons
	[17] = -1,	-- shieldhand

	-- inscription
	[3]  = -1,	-- Shoulder

	-- misc trade skills
	[7]  = -1,	-- legs
}
local warlords_crafted = {
	--[[ Alchemy        ]] [122601]=1,[122602]=1,[122603]=1,[122604]=1,
	--[[ Blacksmithing  ]] [114230]=1,[114231]=1,[114232]=1,[114233]=1,[114234]=1,[114235]=1,[114236]=1,[114237]=1,
	--[[ Engineering    ]] [109171]=1,[109172]=1,[109173]=1,[109174]=1,
	--[[ Jewelcrafting  ]] [115794]=1,[115796]=1,[115798]=1,[115799]=1,[115800]=1,[115801]=1,
	--[[ Leatherworking ]] [116174]=1,[116191]=1,[116193]=1,[116187]=1,[116188]=1,[116190]=1,[116194]=1,[116189]=1,[116192]=1,[116183]=1,[116176]=1,[116177]=1,[116180]=1,[116182]=1,[116179]=1,[116178]=1,[116181]=1,[116171]=1,[116175]=1,
	--[[ Tailoring      ]] [114809]=1,[114810]=1,[114811]=1,[114812]=1,[114813]=1,[114814]=1,[114815]=1,[114816]=1,[114817]=1,[114818]=1,[114819]=1,
}
local tSetItems = {
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
}


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\equip"}; --IconName::Equipment--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show, equip, delete, update and save equipment sets"],
	events = {
		"UNIT_INVENTORY_CHANGED",
		"EQUIPMENT_SETS_CHANGED",
		"PLAYER_ENTERING_WORLD",
		"PLAYER_REGEN_ENABLED",
		"PLAYER_ALIVE",
		"PLAYER_UNGHOST",
		"UNIT_INVENTORY_CHANGED",
		"EQUIPMENT_SETS_CHANGED"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		showSets = true,
		showInventory = true,
		showItemLevel = true,
		showCurrentSet = true,
	},
	config_allowed = nil,
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showSets",            label=L["Show Equipment sets"],            tooltip=L["Display a list of your equipment sets."]},
		{ type="toggle", name="showInventory" ,      label=L["Show inventory"],                 tooltip=L["Display a list of currently equipped items."]},
		{ type="toggle", name="showCurrentSet",      label=L["Show current set"],               tooltip=L["Display your current equipment set on broker button"], event="BE_DUMMY_EVENT"},
		{ type="toggle", name="showItemLevel",       label=L["Show average item level"],        tooltip=L["Display your average item level on broker button"], event="BE_DUMMY_EVENT"},
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
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end


ns.toggleEquipment = function(eName)
	if InCombatLockdown() or UnitIsDeadOrGhost("player") then
		equipPending = eName
		ns.modules[name].onevent("BE_DUMMY_EVENT")
	else
		securecall("UseEquipmentSet",eName);
	end
	ns.hideTooltip(tt,ttName,true);
end

local OBJX = {};
local function CheckInventory()
	wipe(inventory);
	inventory.iLevelMin,inventory.iLevelMax = 9999,0;
	local unit,obj,_="player",{};
	for i,slotIndex in ipairs({1,2,3,15,5,9,10,6,7,8,11,12,13,14,16,17}) do
		obj = {[objLink]=GetInventoryItemLink(unit,slotIndex)};
		if (obj[objLink]) then
			_,_,obj[objColor],obj[objType],obj[objId],obj[objData],obj[objName],obj[objInfo] = obj[objLink]:find("|c(%x*)|H([^:]*):(%d+):(.+)|h%[([^%[%]]*)%]|h|r");
			obj[objId] = tonumber(obj[objId]);
			obj[objData] = {strsplit(":",obj[objData])};
			obj[objInfo] = {GetItemInfo(obj[objLink])}
			obj[objTooltip] = ns.GetLinkData(obj[objLink]);
			inventory[slotIndex]=obj;
			if (obj[objInfo][itemLevel]>inventory.iLevelMax) then
				inventory.iLevelMax=obj[objInfo][itemLevel];
			end
			if (obj[objInfo][itemLevel]<inventory.iLevelMin) then
				inventory.iLevelMin=obj[objInfo][itemLevel];
			end
		end
	end
end

local function GetILevelColor(il)
	local colors = {"cyan","green","yellow","orange","red"};
	
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

local function InventoryTooltip(self,link)
	if (self) then
		GameTooltip:SetOwner(self,"ANCHOR_NONE");
		if (select(1,self:GetCenter()) > (select(1,UIParent:GetWidth()) / 2)) then
			GameTooltip:SetPoint("RIGHT",tt,"LEFT",-2,0);
		else
			GameTooltip:SetPoint("LEFT",tt,"RIGHT",2,0);
		end
		GameTooltip:SetPoint("TOP",self,"TOP", 0, 4);

		GameTooltip:ClearLines();
		GameTooltip:SetHyperlink(link);

		GameTooltip:SetFrameLevel(self:GetFrameLevel()+1);
		GameTooltip:Show();
	else
		GameTooltip:Hide();
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,arg1,...)
	if (event=="PLAYER_REGEN_ENABLED" or event=="PLAYER_ALIVE" or event=="PLAYER_UNGHOST") and (equipPending~=nil) then
		UseEquipmentSet(equipPending)
		equipPending = nil
	end

	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end

	if (event=="UNIT_INVENTORY_CHANGED") and (arg1~="player") then
		return
	end

	local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName);
	local icon,iconCoords,text = I[name].iconfile,{0,1,0,1},{};

	if Broker_EverythingDB[name].showCurrentSet then
		local numEquipSets = GetNumEquipmentSets()

		if numEquipSets >= 1 then 
			for i = 1, GetNumEquipmentSets() do 
				local equipName, iconFile, _, isEquipped, _, _, _, numMissing = GetEquipmentSetInfo(i)
				local pending = (equipPending~=nil and C("orange",equipPending)) or false
				if isEquipped then 
					iconCoords = {0.05,0.95,0.05,0.95}
					icon = iconFile;
					tinsert(text,pending~=false and pending or equipName);
				end
			end
			if(#text==0)then
				--dataobj.icon = I(name).iconfile
				tinsert(text,pending~=false and pending or C("red",L["Unknown Set"]));
			end
		else
			tinsert(text,L["No sets found"]);
		end
	elseif pending~=false then
		tinsert(text,pending);
	end

	if(Broker_EverythingDB[name].showItemLevel)then
		tinsert(text,("%1.1f"):format(select(2,GetAverageItemLevel()) or 0));
	end

	dataobj.iconCoords = iconCoords;
	dataobj.icon = icon;
	dataobj.text = #text>0 and table.concat(text,", ") or L[name];

end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...
	
	local line, column
	tt:Clear()
	tt:AddHeader(C("dkyellow",L[name]))
	CheckInventory();

	if (Broker_EverythingDB[name].showSets) then
		-- equipment sets
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",L["Sets"]));
		tt:AddSeparator();
		if (CanUseEquipmentSets) and (not CanUseEquipmentSets()) then  -- prevent error if function removed
			ns.AddSpannedLine(tt,L["Equipment manager is not enabled"],ttColumns);
			ns.AddSpannedLine(tt,L["Enable it from the character info"],ttColumns);
		else
			local numEquipSets = GetNumEquipmentSets()

			if (numEquipSets>0) then
				for i = 1, numEquipSets do 
					local eName, icon, _, isEquipped, _, _, _, numMissing = GetEquipmentSetInfo(i)
					local color = (equipPending==eName and "orange") or (numMissing>0 and "red") or (isEquipped and "ltyellow") or false
					local formatName = color~=false and C(color,eName) or eName

					local line = ns.AddSpannedLine(tt, "|T"..icon..":0|t "..formatName, ttColumns);
					tt:SetLineScript(line, "OnMouseUp", function(self) 
						if (IsShiftKeyDown()) then 
							if (tt) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
							local dialog = StaticPopup_Show('CONFIRM_SAVE_EQUIPMENT_SET', eName);
							dialog.data = eName;
						elseif (IsControlKeyDown()) then
							if (tt) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
							local dialog = StaticPopup_Show('CONFIRM_DELETE_EQUIPMENT_SET', eName);
							dialog.data = eName;
						else
							ns.toggleEquipment(eName)
						end 
					end)
				end

				if (Broker_EverythingDB.showHints) then
					tt:AddSeparator();
					ns.AddSpannedLine(tt, C("ltblue",L["Click"]).." "..C("green",L["to equip"]) .." - ".. C("ltblue",L["Ctrl+Click"]).." "..C("green",L["to delete"]), ttColumns);
					ns.AddSpannedLine(tt, C("ltblue",L["Shift+Click"]).." "..C("green",L["to update/save"]), ttColumns);
				end
			else
				ns.AddSpannedLine(tt,L["No equipment sets found"],ttColumns);
			end
		end
	end

	if (Broker_EverythingDB[name].showInventory) then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(
			C("ltblue",TRADESKILL_FILTER_SLOTS),
			C("ltblue",NAME),
			C("ltblue",L["iLevel"])
		);
		tt:AddSeparator();
		local none,miss=true,false;
		for _,i in ipairs({1,2,3,15,5,9,10,6,7,8,11,12,13,14,16,17}) do
			local v = inventory[i];
			if (v) then
				local itemId=v[objId];
				none=false;
				local tSetItem,enchanted,greenline = "","","";
				if (enchantSlots[i]~=nil) and ( (v[objInfo][itemLevel]>=600 and enchantSlots[i]>=0) or (v[objInfo][itemLevel]<600 and enchantSlots[i]<=0) ) and (tonumber(v[objData][itemEnchant])==0) then
					enchanted=C("red"," #");
					miss=true;
				end
				if(tSetItems[itemId])then
					tSetItem=C("yellow"," T"..tSetItems[itemId]);
				end
				if(v[objTooltip]~=nil and type(v[objTooltip][2])=="string" and v[objTooltip][2]:find("\124"))then
					greenline = " "..v[objTooltip][2];
				end
				local l = tt:AddLine(
					C("ltyellow",_G[slots[i].."SLOT"]),
					C(v[objColor],v[objName]) .. greenline .. tSetItem .. enchanted,
					C(GetILevelColor(v[objInfo][itemLevel]),v[objInfo][itemLevel])
				);
				tt:SetLineScript(l,"OnEnter",function(self) InventoryTooltip(self,v[objLink]) end);
				tt:SetLineScript(l,"OnLeave",function(self) InventoryTooltip(false) end);
			end
		end
		if (none) then
			local l = tt:AddLine();
			tt:SetCell(l,1,L["All slots are empty"],nil,nil,ttColumns);
		end
		tt:AddSeparator();
		local _, avgItemLevelEquipped = GetAverageItemLevel();
		local avgItemLevelEquippedf = floor(avgItemLevelEquipped);
		local l = tt:AddLine(nil,nil,C(GetILevelColor(avgItemLevelEquippedf),"%.1f"):format(avgItemLevelEquipped));
		tt:SetCell(l,1,C("ltblue",STAT_AVERAGE_ITEM_LEVEL),nil,nil,2);
		if (miss) then
			ns.AddSpannedLine(tt,C("red","#")..": "..C("ltgray",L["Item is not enchanted."]),ttColumns);
		end
	end

	line, column = nil, nil
	if (Broker_EverythingDB.showHints) then
		tt:AddSeparator(4,0,0,0,0);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttColumns=3;
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "LEFT", "RIGHT")
	ns.modules[name].ontooltip(tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end


