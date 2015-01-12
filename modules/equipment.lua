
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
local objLink,objColor,objType,objId,objData,objName,objInfo=1,2,3,4,6,5,7;
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
		"UNIT_INVENTORY_CHANGED",
		"EQUIPMENT_SETS_CHANGED"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		showSets = true,
		showInventory = true,
		--showEnchants = true,
		--showMissingEnchants = false
	},
	config_allowed = nil,
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showSets",            label=L["Show Equipment sets"],            tooltip=L["Display a list of your equipment sets."]},
		{ type="toggle", name="showInventory" ,      label=L["Show inventory"],                 tooltip=L["Display a list of currently equipped items."]},
		--{ type="toggle", name="showEnchants",        label=L["Show enchantments"]      ,        tooltip=L["Display a list of enchantable items and there enchantments or a missing info."]},
		--{ type="toggle", name="showMissingEnchants", label=L["Show missing enchantments only"], tooltip=L["Reduce the list of enchantable item to items without enchantments only."]}
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
	if InCombatLockdown() then 
		equipPending = eName
		ns.modules[name].onevent("BE_DUMMY_EVENT")
	else
		securecall("UseEquipmentSet",eName);
	end
	ns.hideTooltip(tt,ttName,true);
end

local function CheckInventory()
	wipe(inventory);
	inventory.iLevelMin,inventory.iLevelMax = 9999,0;
	local unit,objs,obj,_="player",{};
	for i,slotIndex in ipairs({1,2,3,15,5,9,10,6,7,8,11,12,13,14,16,17}) do
		obj = {[objLink]=GetInventoryItemLink(unit,slotIndex)};
		if (obj[objLink]) then
			_,_,obj[objColor],obj[objType],obj[objId],obj[objData],obj[objName],obj[objInfo] = obj[objLink]:find("|c(%x*)|H([^:]*):(%d+):(.+)|h%[([^%[%]]*)%]|h|r");
			obj[objData] = {strsplit(":",obj[objData])};
			obj[objInfo] = {GetItemInfo(obj[objLink])}
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
	if (event=="PLAYER_REGEN_ENABLED") and (equipPending~=nil) then
		UseEquipmentSet(equipPending)
		equipPending = nil
	end

	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end

	if (event=="UNIT_INVENTORY_CHANGED") and (arg1~="player") then
		return
	end

	local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName)

	local numEquipSets = GetNumEquipmentSets()

	if numEquipSets >= 1 then 
		for i = 1, GetNumEquipmentSets() do 
			local equipName, iconFile, _, isEquipped, _, _, _, numMissing = GetEquipmentSetInfo(i)
			local pending = (equipPending~=nil and C("orange",equipPending)) or false
			if isEquipped then 
				dataobj.iconCoords = {0.05,0.95,0.05,0.95}
				dataobj.icon = iconFile
				dataobj.text = pending~=false and pending or equipName
				return
			else 
				dataobj.icon = I(name).iconfile
				dataobj.text = pending~=false and pending or C("red",L["Unknown Set"])
			end
		end
	else
		dataobj.text = L["No sets found"]
	end
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
				none=false;
				local enchanted = nil;
				if (enchantSlots[i]~=nil) and ( (v[objInfo][itemLevel]>=600 and enchantSlots[i]>=0) or (v[objInfo][itemLevel]<600 and enchantSlots[i]<=0) ) and (tonumber(v[objData][itemEnchant])==0) then
					enchanted=false;
					miss=true;
				end
				local l = tt:AddLine(
					C("ltyellow",_G[slots[i].."SLOT"]),
					C(v[objColor],v[objName]) .. (enchanted==false and C("red"," #") or ""),
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

	--[=[
	if (Broker_EverythingDB[name].showEnchants) then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(
			C("ltblue",TRADESKILL_FILTER_SLOTS),
			C("ltblue",NAME)
		);
		tt:AddSeparator();
		local none = true;
		for _,i in ipairs({1,2,3,15,5,9,10,6,7,8,11,12,13,14,16,17}) do
			local v = inventory[i];
			if (enchantSlots[i]~=nil) and (v) and ( (v[objInfo][itemLevel]>=600 and enchantSlots[i]>=0) or (v[objInfo][itemLevel]<600 and enchantSlots[i]<=0) ) then
				none=false;
				local color,label="red",L["Not enchanted!"];
				if (tonumber(v[objData][itemEnchant])>0) then
					color,label = "white",v[objData][itemEnchant];
				end
				local l = tt:AddLine( C("ltyellow",_G[slots[i].."SLOT"]), C(color,label) );
				if (tonumber(v[objData][itemEnchant])>0) then
					--tt:SetLineScript(l,"OnEnter",function(self) InventoryTooltip(self,false,v[objData][itemEnchant]) end);
					--tt:SetLineScript(l,"OnLeave",function(self) InventoryTooltip(false) end);
				end
			end
		end
	end
	--]=]

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


