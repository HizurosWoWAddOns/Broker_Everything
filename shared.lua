
-- ====================================== --
-- Shared Functions for Broker_Everything --
-- ====================================== --
local addon, ns = ...
local upper,format,type = upper,format,type
local GetPlayerMapPosition,GetRealZoneText,GetSubZoneText = GetPlayerMapPosition,GetRealZoneText,GetSubZoneText
local GetZonePVPInfo,GetBindLocation = GetZonePVPInfo,GetBindLocation
local L = ns.L
local _
ns.build = tonumber(gsub(({GetBuildInfo()})[1],"[|.]","")..({GetBuildInfo()})[2])

ns.LDB = LibStub("LibDataBroker-1.1")
ns.LQT = LibStub("LibQTip-1.0")
ns.LDBI = LibStub("LibDBIcon-1.0")
ns.LSM = LibStub("LibSharedMedia-3.0")

ns.LT = LibStub("LibTime-1.0")
ns.LC = LibStub("LibColors-1.0")

-- broker_everything colors
ns.LC.colorset({
	["ltyellow"]	= "fff569",
	["dkyellow"]	= "ffcc00",
	["ltorange"]	= "ff9d6a",
	["dkorange"]	= "905d0a",
	["dkred"]		= "c41f3b",
	["ltred"]		= "ff8080",
	["dkred"]		= "800000",
	["violet"]		= "f000f0",
	["ltviolet"]	= "f060f0",
	["dkviolet"]	= "800080",
	["ltblue"]		= "69ccf0",
	["dkblue"]		= "000088",
	["ltcyan"]		= "80ffff",
	["dkcyan"]		= "008080",
	["ltgreen"]		= "80ff80",
	["dkgreen"]		= "00aa00",

	["dkgray"]		= "404040",
	["ltgray"]		= "b0b0b0",

	["gold"]		= "ffd700",
	["silver"]		= "eeeeef",
	["copper"]		= "f0a55f",

	["unknown"]		= "ee0000",
})


  ---------------------------------------
--- misc shared data                    ---
  ---------------------------------------
ns.realm = GetRealmName();
ns.media = "Interface\\AddOns\\"..addon.."\\media\\";
ns.locale = GetLocale();


  ---------------------------------------
--- player and twinks dependent data    ---
  ---------------------------------------
ns.player = {
	name = UnitName("player"),
	female = UnitSex("player")==3,
};
ns.player.name_realm = ns.player.name.."-"..ns.realm;
_, ns.player.class,ns.player.classId = UnitClass("player");
ns.player.faction,ns.player.factionL  = UnitFactionGroup("player");
L[ns.player.faction] = ns.player.factionL;
ns.player.classLocale = ns.player.female and _G.LOCALIZED_CLASS_NAMES_FEMALE[ns.player.class] or _G.LOCALIZED_CLASS_NAMES_MALE[ns.player.class];
ns.player.raceLocale,ns.player.race = UnitRace("player");
ns.LC.colorset("suffix",ns.LC.colorset[ns.player.class:lower()]);


  -----------------------------------------
--- SetCVar hook                          ---
--- Thanks at blizzard for blacklisting   ---
--- some cvars on combat...               ---
  -----------------------------------------
do
	local blacklist = {alwaysShowActionBars = true, bloatnameplates = true, bloatTest = true, bloatthreat = true, consolidateBuffs = true, fullSizeFocusFrame = true, maxAlgoplates = true, nameplateMotion = true, nameplateOverlapH = true, nameplateOverlapV = true, nameplateShowEnemies = true, nameplateShowEnemyGuardians = true, nameplateShowEnemyPets = true, nameplateShowEnemyTotems = true, nameplateShowFriendlyGuardians = true, nameplateShowFriendlyPets = true, nameplateShowFriendlyTotems = true, nameplateShowFriends = true, repositionfrequency = true, showArenaEnemyFrames = true, showArenaEnemyPets = true, showPartyPets = true, showTargetOfTarget = true, targetOfTargetMode = true, uiScale = true, useCompactPartyFrames = true, useUiScale = true}
	ns.SetCVar = function(...)
		local cvar = ...
		if ns.build>=54800000 and InCombatLockdown() and blacklist[cvar]==true then
			local msg
			-- usefull blacklisted cvars...
			if cvar=="uiScale" or cvar=="useUiScale" then
				msg = "Changing UI scaling while combat nether an good idea."
			else
			-- useless blacklisted cvars...
				msg = "Sorry, CVar "..cvar.." are no longer changeable while combat. Thanks @ Blizzard."
			end
			print("|cffff6600"..addon..": "..msg.."|r")
		else
			SetCVar(...)
		end
	end
end


  ---------------------------------------
--- Helpful function for extra tooltips ---
  ---------------------------------------
ns.GetTipAnchor = function(frame, menu)
	local x, y = frame:GetCenter()
	if (not x) or (not y) then return "TOPLEFT", "BOTTOMLEFT"; end

	local hhalf = (x > UIParent:GetWidth() * 2 / 3) and "RIGHT" or (x < UIParent:GetWidth() / 3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"

	local X = (hhalf=="LEFT") and -3 or 3
	local Y = (vhalf=="BOTTOM") and -3 or 3

	return vhalf .. hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf, X,Y
end

local function SmartAnchorTo(self,frame)
	if not frame then
		error("Invalid frame provided.", 2)
	end
	self:ClearAllPoints()
	self:SetClampedToScreen(true)
	self:SetPoint(ns.GetTipAnchor(frame))
end

ns.tooltipScaling = function(tooltip)
	if Broker_EverythingDB.tooltipScale == true then
		tooltip:SetScale(tonumber(GetCVar("uiScale")))
	end
end

ns.hideTooltip = function(tooltip,ttName,ttForce,ttSetOnLeave)
	local modifier=Broker_EverythingDB.ttModifierKey2;
	ttForce = not not ttForce;
	if (tooltip) then
		if (not ttForce) and (modifier~="NONE") and (ns.tooltipChkOnShowModifier(modifier,false)) then
			ttForce=true;
		end
		if (not ttForce) then
			if (tooltip.key) and (tooltip.key==ttName) and (MouseIsOver(tooltip)) then
				if (ttSetOnLeave) then
					tooltip:SetScript("OnLeave",function(self)
						ns.hideTooltip(tooltip,ttName);
					end);
				end
				return;
			end
			local f = GetMouseFocus()
			if (f) and (not f:IsForbidden()) and (not f:IsProtected() and InCombatLockdown()) and (type(f.key)=="string") and (type(ttName)=="string") and (f.key==ttName) then
				return; -- why that? tooltip can't be closed in combat with securebuttons as child elements. results in addon_action_blocked... 
			end
		elseif (tooltip.slider) and (tooltip.slider:IsShown()) then
			ns.hideTooltip(tooltip,ttName,false,true);
			return;
		end
		if type(tooltip.secureButtons)=="table" then
			for i,v in ipairs(tooltip.secureButtons)do
				ns.secureButton2Hide(v)
			end
			ns.secureButton(false);
		end
		tooltip:SetScript("OnUpdate",nil);
		ns.LQT:Release(tooltip)
		tooltip.key=nil;
		return true;
	end
end

ns.createTooltip = function(frame, tooltip, SetOnLeave)
	local eclipsed = 0;
	if (Broker_EverythingDB.tooltipScale==true) then
		tooltip:SetScale(tonumber(GetCVar("uiScale")))
	end
	if (frame) then
		SmartAnchorTo(tooltip,frame)
	end
	if (SetOnLeave) then
		tooltip:SetScript("OnLeave", function(self)
			ns.hideTooltip(self,self.key);
		end)
	end
	tooltip:SetScript("OnUpdate", function(self,eclipse)
		if (self.eclipsed==nil) then self.eclipsed=0; end
		self.eclipsed = self.eclipsed + eclipse;
		if (self.eclipsed>0.5) and (GetMouseFocus()==WorldFrame) then
			ns.hideTooltip(self,self.key,true);
		end
	end);

	-- Tiptac Support for LibQTip Tooltips
	if _G.TipTac and _G.TipTac.AddModifiedTip then
		-- Pass true as second parameter because hooking OnHide causes C stack overflows
		_G.TipTac:AddModifiedTip(tooltip, true)
	end

	tooltip:UpdateScrolling(GetScreenHeight() * (Broker_EverythingDB.maxTooltipHeight/100));
	tooltip:Show()
end

ns.RegisterMouseWheel = function(self,func)
	self:EnableMouseWheel(1) 
	self:SetScript("OnMouseWheel", func)
end

ns.tooltipModifiers = {
	SHIFT      = {l=L["Shift"],       f="Shift"},
	LEFTSHIFT  = {l=L["Left shift"],  f="LeftShift"},
	RIGHTSHIFT = {l=L["Right shift"], f="RightShift"},
	ALT        = {l=L["Alt"],         f="Alt"},
	LEFTALT    = {l=L["Left alt"],    f="LeftAlt"},
	RIGHTALT   = {l=L["Right alt"],   f="RightAlt"},
	CTRL       = {l=L["Ctrl"],        f="Control"},
	LEFTCTRL   = {l=L["Left ctrl"],   f="LeftControl"},
	RIGHTCTRL  = {l=L["Right ctrl"],  f="RightControl"}
}

ns.tooltipChkOnShowModifier = function(bool)
	local modifier = Broker_EverythingDB.ttModifierKey1;
	if (modifier~="NONE") then
		modifier = (ns.tooltipModifiers[modifier]) and _G["Is"..ns.tooltipModifiers[modifier].f.."KeyDown"]();
		if (bool) then
			return modifier;
		else
			return not modifier;
		end
	end
	return false;
end

ns.AddSpannedLine = function(tt,content,ttColumns,start)
	start = start or 1;
	local l = tt:AddLine();
	tt:SetCell(l,start,content,nil,nil,ttColumns);
	return l;
end


  ---------------------------------------
--- icon colouring function             ---
  ---------------------------------------
do
	local objs = {}
	ns.updateIconColor = function(name)
		local f = function(n)
			local obj = objs[n] or ns.LDB:GetDataObjectByName(n)
			objs[n] = obj
			if obj==nil then return false end
			obj.iconR,obj.iconG,obj.iconB,obj.iconA = unpack(Broker_EverythingDB.iconcolor or ns.LC.color("white","colortable"))
			return true
		end
		if name==true then
			for i,v in pairs(ns.modules) do f(i) end
		elseif ns.modules[name]~=nil then
			f(name)
		end
	end
end


  ---------------------------------------
--- nice little print function          ---
  ---------------------------------------
ns.print = function (...)
	local colors,t,c = {"0099ff","00ff00","ff6060","44ffff","ffff00","ff8800","ff44ff","ffffff"},{},1;
	for i,v in ipairs({...}) do
		v = tostring(v);
		if i==1 and v~="" then
			tinsert(t,"|cff0099ff"..addon.."|r:"); c=2;
		end
		if not v:match("||c") then
			v,c = "|cff"..colors[c]..v.."|r", c<#colors and c+1 or 1;
		end
		tinsert(t,v);
	end
	print(unpack(t));
end
ns.Print = ns.print

ns.print_r = function(title,obj)
	assert(type(title)=="string","argument 1# must be a string ("..type(title).." given).")
	assert(type(obj)=="table","argument 2# must be a table ("..type(obj).." given)")
	for k,v in pairs(obj) do
		if type(v) ~= "string" and type(v)~="number" then v = "<"..type(v)..">" end
		ns.print(title,k,"=",v)
	end
end

ns.print_t = ns.print_r


  ---------------------------------------
--- suffix colour function              ---
  ---------------------------------------
ns.suffixColour = function(str)
	if (Broker_EverythingDB.suffixColour) then
		str = ns.LC.color("suffix",str);
	end
	return str;
end


  ------------------------------------------
--- Icon provider and framework to support ---
--- use of external iconset                ---
  ------------------------------------------
do
	local iconset = nil
	local objs = {}
	ns.I = setmetatable({},{
		__index = function(t,k)
			local v = {iconfile="interface\\icons\\inv_misc_questionmark",coords={0.05,0.95,0.05,0.95}}
			rawset(t, k, v)
			return v
		end,
		__call = function(t,a)
			if a==true then
				if Broker_EverythingDB.iconset~="NONE" then
					iconset = ns.LSM:Fetch((addon.."_Iconsets"):lower(),Broker_EverythingDB.iconset) or iconset
				end
				return
			end
			assert(type(a)=="string","argument #1 must be a string, got "..type(a))
			return (type(iconset)=="table" and iconset[a]) or t[a]
		end
	})
	ns.updateIcons = function()
		for i,v in pairs(ns.modules) do
			local obj = ns.LDB:GetDataObjectByName(i)
			if obj~=nil then 
				local d = ns.I(i .. (v.icon_suffix or ""))
				obj.iconCoords = d.coords or {0,1,0,1}
				obj.icon = d.iconfile
			end
		end
	end
	local function updateIconColor(name)
		local obj = ns.LDB:GetDataObjectByName(name);
		if (obj==nil) then return false end
		obj.iconR,obj.iconG,obj.iconB,obj.iconA = unpack(Broker_EverythingDB.iconcolor or ns.LC.color("white","colortable"))
		return true
	end
	ns.updateIconColor = function(name)
		local result = true;
		if (name==true) then
			for i,v in pairs(ns.modules) do if (updateIconColor(i)==false) then result=false; end end
		elseif (ns.modules[name]~=nil) then
			result = updateIconColor(name);
		end
		return result;
	end
end


-- -------------------------------------------------- --
-- Function to Sort a table by the keys               --
-- Sort function fom http://www.lua.org/pil/19.3.html --
-- -------------------------------------------------- --
ns.pairsByKeys = function(t, f)
	local a = {}
	for n in pairs(t) do
		table.insert(a, n)
	end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end

ns.reversePairsByKeys = function(t,f)
	local a = {}
	for n in ipairs(t) do
		table.insert(a,n)
	end
	table.sort(a, f)
	local i = #a
	local iter = function()
		i = i - 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end


-- -------------------------------------------------------------- --
-- Function to split a string                                     --
-- http://stackoverflow.com/questions/1426954/split-string-in-lua --
-- Because mucking around with strings makes my head hurt.        --
-- -------------------------------------------------------------- --
ns.splitText = function(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	local i = 1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = strtrim(str) .. sep
		i=i+1
	end
	return table.concat(t, "|n")
end

ns.splitTextToHalf = function(inputstr, sep)
	local t = {}
	local i = 1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] =strtrim(str) .. " "
		i=i+1
	end
	local h,a,b = ceil(i/2),"",""
	for i, v in pairs(t) do
		if i < h then a = a .. v else b = b .. v end
	end
	return a.."|n"..b
end

ns.split = function(iStr,splitBy,opts)
	-- escapes sollten temporär ersetzt werden...
	if splitBy=="length" then
		assert(type(opts.length)=="number","opts.length must be a number, "..type(opts.length).."given.")
	elseif splitBy=="half" then
	elseif splitBy=="sepcount" then
		assert(type(opts.count)=="number","opts.count must be a number, "..type(opts.count).."given.")
	elseif splitBy=="sep" then
		
	end
end

ns.getBorderPositions = function(f)
	local us = UIParent:GetEffectiveScale()
	local uw,uh = UIParent:GetWidth(), UIParent:GetHeight()
	local fx,fy = f:GetCenter()
	local fw,fh = f:GetWidth()/2, f:GetHeight()/2
	-- LEFT, RIGHT, TOP, BOTTOM
	return fx-fw, uw-(fx+fw), uh-(fy+fh),fy-fh
end

ns.strLimit = function(str,limit)
	if strlen(str)>limit then str = strsub(str,1,limit).."..." end
	return str
end


-- -------------------------------------------------------------- --
-- module independent bags and inventory scanner                  --
-- event driven with delayed execution                            --
-- -------------------------------------------------------------- --
do
	--- local elements
	local d = {
		ids = {}, callbacks = {}, preScanCallbacks={}, links={},
		delay = 1.75,
		elapsed = 0,
		update = true
	}

	local function scanner()
		local items = {};
		local callbacks = {};

		-- get all itemIds from all items in the bags
		for bag=0, NUM_BAG_SLOTS do
			for slot=1, GetContainerNumSlots(bag) do
				local id,_,count,rarity,price = GetContainerItemID(bag,slot);
				if (id) then
					if(items[id]==nil)then items[id]={}; end
					local obj = {bag=bag, slot=slot};
					_, obj.count = GetContainerItemInfo(bag, slot);
					_, _, obj.rarity, _, _, _, _, _, _, _, obj.price = GetItemInfo(id);
					tinsert(items[id],obj);
					if(d.callbacks[id])then
						for i,v in pairs(d.callbacks[id]) do
							if(type(v)=="function")then
								callbacks[i] = v;
							end
						end
					end
				end
			end
		end

		-- get all itemIds from equipped items
		local slots = {"Back","Chest","Feet","Finger0","Finger1","Hands","Head","Legs","MainHand","Neck","SecondaryHand","Shirt","Shoulder","Tabard","Trinket0","Trinket1","Waist","Wrist"};
		for _,slot in ipairs(slots) do
			local id = GetInventoryItemID("player",slot.."Slot");
			if (id) then
				if(items[id]==nil)then items[id]={}; end
				local obj = {inv=slot,durability={}};
				obj.slotId, obj.icon = GetInventorySlotInfo(slot.."Slot");
				obj.isBroken = GetInventoryItemBroken("player",slot.."Slot");
				obj.rarity = GetInventoryItemQuality("player",slot.."Slot");
				obj.gems = {GetInventoryItemGems(obj.slotId)};
				obj.durability.current, obj.durability.max = GetInventoryItemDurability(obj.slotId);
				tinsert(items[id],obj);
				if(d.callbacks[id])then
					for i,v in pairs(d.callbacks[id]) do
						if(type(v)=="function")then
							callbacks[i] = v;
						end
					end
				end
			end
		end

		d.ids = items;

		-- execute callback functions by itemId
		for module,func in pairs(callbacks) do
			if d.preScanCallbacks[module] then
				d.preScanCallbacks[module]("preScan");
			end
			if(type(func)=="function")then
				func("update");
			end
		end

		-- execute callback.any functions for any update
		if(d.callbacks.any~=nil)then
			for module,func in pairs(d.callbacks.any)do
				if d.preScanCallbacks[module] then
					d.preScanCallbacks[module]("preScan");
				end
				if(type(func)=="function")then
					func("update.any");
				end
			end
		end
	end

	--- event and update frame
	local f = CreateFrame("Frame");
	f:SetScript("OnUpdate",function(self,elapse)
		if(d.update)then
			d.elapsed=d.elapsed+elapse;
			if(d.elapsed>=d.delay)then
				d.elapsed=0;
				d.update=false;
				scanner();
			end
		end
	end);
	f:SetScript("OnEvent",function(self,event,...)
		d.update=true;
	end);
	f:RegisterEvent("BAG_UPDATE_DELAYED");
	f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	f:RegisterEvent("PLAYER_ENTERING_WORLD");

	--- namespace functions
	ns.items = {};
	ns.items.RegisterCallBack = function(modName,itemId,func)
		assert(type(modName)=="string" and ns.modules[modName],"argument #1 (modName) must be a string, got "..type(modName));
		assert(type(itemId)=="number","argument #2 (itemId) must be a number, got "..type(itemId));
		assert(type(func)=="function","argument #3 (function) must be a function, got "..type(func));
		if (d.callbacks[itemId]==nil) then
			d.callbacks[itemId] = {};
		end
		if (d.callbacks[itemId][modName]==nil)then
			d.callbacks[itemId][modName] = func;
		end
		d.callbacks.active = true;
	end;
	ns.items.RegisterCallBackForAnyItem = function(modName,func)
		assert(type(modName)=="string" and ns.modules[modName],"argument #1 (modName) must be a string, got "..type(modName));
		assert(type(func)=="function","argument #3 (function) must be a function, got "..type(func));
		if (d.callbacks.any==nil) then
			d.callbacks.any = {};
		end
		d.callbacks.any[modName] = func;
		d.callbacks.active = true;
	end;
	ns.items.RegisterPreScanCallBack  = function(modName,func)
		assert(type(modName)=="string" and ns.modules[modName],"argument #1 (modName) must be a string, got "..type(modName));
		assert(type(func)=="function","argument #3 (function) must be a function, got "..type(func));
		if(d.preScanCallbacks==nil)then
			d.preScanCallbacks={};
		end
		d.preScanCallbacks[modName]=func;
	end;
	ns.items.exist = function(itemId)
		return d.ids[itemId] or false;
	end;
	ns.items.GetItemlist = function()
		return d.ids;
	end;
end


-- ----------------------------------------
-- secure button as transparent overlay
-- http://wowpedia.org/SecureActionButtonTemplate
-- be careful...
-- 
-- @param self UI_ELEMENT 
-- @param obj  TABLE
--		obj = {
--			{
--				typeName  STRING  | see "Modified attributes"
--				typeValue STRING  | see "Action types" "Type"-column
--				attrName  STRING  | see "Action types" "Used attributes"-column
--				attrValue ~mixed~ | see "Action types" "Behavior"-column. 
--				                  | Note: if typeValue is click then attrValue must
--										  be a ui element with :Click() function like
--										  buttons. thats a good way to open frames
--										  like spellbook without risk tainting it by
--										  an addon.
--			},
--			{ ... }
--		}
-- ----------------------------------------
-- [=[
do
	local sbf = nil -- change to array
	ns.secureButton = function(self,obj)
		if self==nil or  InCombatLockdown() then return end

		if sbf~=nil and self==false then
			sbf:SetParent(UIParent)
			sbf:ClearAllPoints()
			sbf:Hide()
			return 
		end

		if type(obj)~="table" then
			return
		end

		sbf = sbf or CreateFrame("Button",addon.."_SecureButton",UIParent,"SecureActionButtonTemplate")
		sbf:SetParent(self)
		sbf:SetPoint("CENTER")
		sbf:SetWidth(self:GetWidth())
		sbf:SetHeight(self:GetHeight())
		sbf:SetHighlightTexture([[interface\friendsframe\ui-friendsframe-highlightbar-blue]],true)

		for i,v in pairs(obj) do
			if type(v.typeName)=="string" and type(v.typeValue)=="string" then
				sbf:SetAttribute(v.typeName,v.typeValue)
			end
			if type(v.attrName)=="string" and v.attrValue~=nil then
				sbf:SetAttribute(v.attrName,v.attrValue)
			end
		end

		sbf:Show()
	end

	local sb = {}
	local sbFrame = CreateFrame("frame")
	ns.secureButton2 = function(self,obj,name)
		if type(obj)~="table" then return end
		local sbf = nil

		if sb[name]==nil then
			--sb[name] = CreateFrame("Button",nil,self,"BE_SecureWrapper")
			sb[name] = CreateFrame("Frame","BE_SF_"..name,sbFrame,"BE_SecureFrame")
		end

		sb[name]:SetPoint("TOPLEFT",self,"TOPLEFT",0,0)
		sb[name]:SetPoint("BOTTOMRIGHT",self,"BOTTOMRIGHT",0,0)

		for i,v in pairs(obj) do
			if type(v.typeName)=="string" and type(v.typeValue)=="string" then
				sb[name].button:SetAttribute(v.typeName,v.typeValue)
			end
			if type(v.attrName)=="string" and v.attrValue~=nil then
				sb[name].button:SetAttribute(v.attrName,v.attrValue)
			end
		end

		sb[name]:Show()
	end
	ns.secureButton2Hide = function(name)
		if sb[name]~=nil and sb[name]:IsShown() then
			sb[name]:ClearAllPoints()
			sb[name]:Hide()
		end
	end
end
--]=]


-- --------------------- --
-- scanTooltip functions --
-- --------------------- --
do
	local scanTooltip = CreateFrame("GameTooltip",addon.."_ScanTooltip",UIParent,"GameTooltipTemplate")
	scanTooltip:SetScale(0.0001)
	scanTooltip:Hide()

	-- ------------------------------------------- --
	-- GetItemData                                 --
	-- a 2in1 function to fetch item informations  --
	-- for use in other addons                     --
	-- ------------------------------------------- --
	function ns.GetItemData(id,bag,slot)
		assert(type(id)=="number","argument #1 (id) must be a number, got "..type(id))
		local data,line,_ = {},0
		data.id,data.tooltip = id,{};
		data.itemName, data.itemLink, data.itemRarity, data.itemLevel, data.itemMinLevel, data.itemType, data.itemSubType, data.itemStackCount, data.itemEquipLoc, data.itemTexture, data.itemSellPrice = GetItemInfo(id);
		scanTooltip:ClearLines();
		scanTooltip:Show();
		scanTooltip:SetOwner(UIParent,"LEFT",0,0);
		if (bag~=nil) and (slot~=nil) then
			assert(type(bag)=="number","argument #2 (bag) must be a number, got "..type(bag));
			assert(type(slot)=="number","argument #3 (slot) must be a number, got "..type(slot));
			data.startTime, data.duration, data.isEnabled = GetContainerItemCooldown(bag,slot);
			data.hasCooldown, data.repairCost = scanTooltip:SetBagItem(bag,slot);
		else
			scanTooltip:SetHyperlink("item:"..id);
		end
		for _,v in ipairs({scanTooltip:GetRegions()}) do
			if (v~=nil) and (v:GetObjectType()=="FontString") and (v:GetText()~=nil) then
				tinsert(data.tooltip,v:GetText());
			end
		end
		scanTooltip:ClearLines();
		scanTooltip:Hide();
		return data;
	end
	function ns.GetLinkData(link)
		assert(type(link)=="string","argument #1 must be a string, got "..type(link));
		local data,line,_ = {},0
		scanTooltip:Show();
		scanTooltip:SetOwner(UIParent,"LEFT",0,0);
		scanTooltip:SetHyperlink(link);
		for _,v in ipairs({scanTooltip:GetRegions()}) do
			if (v~=nil) and (v:GetObjectType()=="FontString") and (v:GetText()~=nil) then
				tinsert(data,v:GetText());
			end
		end
		scanTooltip:ClearLines();
		scanTooltip:Hide();
		return data, #data;
	end
end


-- --------------------------------------- --
-- GetRealFaction2PlayerStanding           --
-- retrun standingID of a faction          --
-- if faction unknown or argument nil then --
-- returns this function the standingID 4  --
-- --------------------------------------- --
do
	function ns.GetFaction2PlayerStanding(faction) -- FactionID or FactionName
		local collapsed, standing = {},4
		if faction~=nil then
			for i=GetNumFactions(), 1, -1 do -- 1. round: expand all collapsed headers
				local name, _, _, _, _, _, _, _, isHeader, isCollapsed, _, _, _, _, _, _ = GetFactionInfo(i)
				if isHeader and isCollapsed then
					collaped[name] = true
					ExpandFactionHeader(i)
				end
			end
			for i=1, GetNumFactions() do -- 2. round: search faction and note his standing
				local name, _, standingID, _, _, _, _, _, _, _, _, _, _, factionID, _, _ = GetFactionInfo(i)
				if faction==name or faction==factionID then
					standing = standingID
				end
			end
			for i=GetNumFactions(), 1, -1 do -- 3. round: collapsed all by this function expanded headers. 
				local name, _, _, _, _, _, _, _, isHeader, isCollapsed, _, _, _, _, _, _ = GetFactionInfo(i)
				if isHeader and collapsed[name] then
					CollapseFactionHeader(i)
				end
			end
		end
		return standing
	end
	-- TODO: need review. maybe performance increasements...
	--[[
		add a table for found factions.
			if table not nil, use table instead recrawle through the faction list.
		add an event-frame for faction update event.
			if event triggered, wipe faaction table.
		~ more memory usage vs. scanning faction list on any request of this function...
	]]

	-- ----------------
	-- UnitFaction
	-- ----------------
	function ns.UnitFaction(unit)
		scanTooltip:SetUnit(unit)
		scanTooltip:Show()
		local reg,_next,faction = {scanTooltip:GetRegions()},false,nil
		scanTooltip:Hide()
		for i,v in ipairs(reg) do
			if v:GetObjectType()=="FontString" then
				v = v:GetText() or ""
				if _next==false and v:match("^"..TOOLTIP_UNIT_LEVEL) then
					_next = true
				elseif _next==true then
					faction = v
					_next = nil
				end
			end
		end
		return faction, ns.GetFaction2PlayerStanding(faction)
	end
end


-- ----------------------------------------------------- --
-- goldColor function to display amount of gold          --
-- in colored strings or with coin textures depending on --
-- a per module and a addon wide toggle.                 --
-- ----------------------------------------------------- --
function ns.GetCoinColorOrTextureString(modName,amount,opts)
	local zz="%02d";
	if(type(amount)~="number")then amount=0; end

	if(not opts)then opts={}; end
	if(not opts.sep)then
		if Broker_EverythingDB.separateThousands and LARGE_NUMBER_SEPERATOR=="." then
			opts.sep=" ";
		else
			opts.sep=".";
		end
	end
	if(not opts.hideLowerZeros)then
		opts.hideLowerZeros=false;
		if (Broker_EverythingDB.goldHideLowerZeros==true)then
			opts.hideLowerZeros=true;
		end
	end

	if(not opts.hideCopper)then
		opts.hideCopper=false;
		if(Broker_EverythingDB.goldHideCopper==true)then
			opts.hideCopper=true;
		end
	end

	if(not opts.hideSilver)then
		opts.hideSilver=false;
		if(Broker_EverythingDB.goldHideSilver==true)then
			opts.hideSilver=true;
		end
	end

	if(opts.hideSilver)then
		amount = floor(amount/10000)*10000;
	elseif(opts.hideCopper)then
		amount = floor(amount/100)*100;
	end

	if (Broker_EverythingDB[modName].goldColor==true) or (Broker_EverythingDB.goldColor==true) then

		local gold, silver, copper, t, i = floor(amount/10000), mod(floor(amount/100),100), mod(floor(amount),100), {}, 1

		if amount==0 or not (opts.hideCopper or (copper==0 and opts.hideLowerZeros))then
			tinsert(t,ns.LC.color("copper",(silver>0 or gold>0) and zz:format(copper) or copper));
		end

		if amount>0 and not (opts.hideSilver or (copper==0 and silver==0 and opts.hideLowerZeros))then
			tinsert(t,1,ns.LC.color("silver",gold>0 and zz:format(silver) or silver));
		end

		if(gold>0)then
			if Broker_EverythingDB.separateThousands then
				gold = FormatLargeNumber(gold);
			end
			tinsert(t,1,ns.LC.color("gold",gold));
		end

		return table.concat(t,opts.sep);
	else
		return GetCoinTextureString(amount)
	end
end


-- ----------------------------------------------------- --
-- screen capture mode - string replacement function     --
-- ----------------------------------------------------- --
ns.scm = function(str,all)
	if (type(str)=="string") and (strlen(str)>0) and (Broker_EverythingDB.scm==true) then
		if (all) then
			return strrep("*",(strlen(str)));
		else
			return strsub(str,1,1)..strrep("*",(strlen(str)-1));
		end
	else
		return str;
	end
end


-- ------------------------ --
-- Hide blizzard elements   --
-- ------------------------ --
do
	local hidden = CreateFrame("Frame",addon.."_HideFrames")
	hidden.origParent = {}
	hidden:Hide()

	ns.hideFrame = function(frameName)
		local pName = _G[frameName]:GetParent():GetName()
		if pName==nil then
			return false
		end
		hidden.origParent[frameName] = pName
		_G[frameName]:SetParent(hidden)
	end

	ns.unhideFrame = function(frameName)
		if hidden.origParent[frameName]~=nil then
			_G[frameName]:SetParent(hidden.origParent[frameName])
			hidden.origParent[frameName] = nil
		end
	end
end


-- ---------------- --
-- EasyMenu wrapper --
-- ---------------- --
do
	ns.EasyMenu = {};
	local UIDropDownMenuDelegate = CreateFrame("FRAME");
	local UIDROPDOWNMENU_MENU_LEVEL;
	local UIDROPDOWNMENU_MENU_VALUE;
	local UIDROPDOWNMENU_OPEN_MENU;
	local self = ns.EasyMenu;
	self.menu = {};
	self.controlGroups = {};
	local cvarTypeFunc = {
		bool = function(D)
			if (type(D.cvar)=="table") then
				--?
			elseif (type(D.cvar)=="string") then
				D.checked = function() return (GetCVar(D.cvar)=="1") end;
				D.func = function() SetCVar(D.cvar,GetCVar(D.cvar)=="1" and "0" or "1"); end;
			end
		end,
		slider = function(...)
		end,
		num = function(...)
			
		end,
		str = function(...)
		end
	};

	local beTypeFunc = {
		bool = function(d)
			if (d.beModName) then
				d.checked = function() return (Broker_EverythingDB[d.beModName][d.beKeyName]) end;
				d.func = function() Broker_EverythingDB[d.beModName][d.beKeyName] = not Broker_EverythingDB[d.beModName][d.beKeyName]; end;
			else
				d.checked = function() return (Broker_EverythingDB[d.beKeyName]) end;
				d.func = function() Broker_EverythingDB[d.beKeyName] = not Broker_EverythingDB[d.beKeyName]; end;
			end
		end,
		slider = function(...)
		end,
		num = function(D)
			if (D.cvarKey) then
			elseif (D.cvars) and (type(cvars)=="table") then
				
			end
		end,
		str = function(...)
		end
	};

	self.InitializeMenu = function()
		if (not self.frame) then
			self.frame = CreateFrame("Frame", addon.."EasyMenu", UIParent, "UIDropDownMenuTemplate");
		end
		wipe(self.menu);
	end

	self.addEntry = function(D,P)
		local entry= {};

		if (type(D)=="table") and (#D>0) then -- numeric table = multible entries
			for i,v in ipairs(D) do
				self.addEntry(v,parent);
			end
			return;

		elseif (D.childs) then -- child elements
			local parent = self.addEntry({ label=D.label, arrow=true, disabled=D.disabled },P);
			for i,v in ipairs(D.childs) do
				self.addEntry(v,parent);
			end
			return;

		elseif (D.groupName) and (D.optionGroup) then -- similar to childs but with group control
			if (self.controlGroups[D.groupName]==nil) then
				self.controlGroups[D.groupName] = {};
			else
				wipe(self.controlGroups[D.groupName])
			end
			local parent = self.addEntry({ label=D.label, arrow=true, disabled=D.disabled },P);
			parent.controlGroup=self.controlGroups[D.groupName];
			for i,v in ipairs(D.optionGroup) do
				tinsert(self.controlGroups[D.groupName],self.addEntry(v,parent));
			end
			return;

		elseif (D.separator) then -- separator line (decoration)
			entry = { text = "", dist = 0, isTitle = true, notCheckable = true, isNotRadio = true, sUninteractable = true, iconOnly = true, icon = "Interface\\Common\\UI-TooltipDivider-Transparent", tCoordLeft = 0, tCoordRight = 1, tCoordTop = 0, tCoordBottom = 1, tFitDropDownSizeX = true, tSizeX = 0, tSizeY = 8 };
			entry.iconInfo = entry; -- looks like stupid? is necessary to work. (thats blizzard)

		else
			entry.isTitle          = D.title     or false;
			entry.hasArrow         = D.arrow     or false;
			entry.disabled         = D.disabled  or false;
			entry.notClickable     = not not D.noclick;
			entry.isNotRadio       = not D.radio;
			entry.keepShownOnClick = (D.keepShown~=nil) and D.keepShown or nil;

			if (D.cvarType) and (D.cvar) and (type(D.cvarType)=="string") and (cvarTypeFunc[D.cvarType]) then
				cvarTypeFunc[D.cvarType](D);
			end

			if (D.beType) and (D.beKeyName) and (type(D.beType)=="string") and (beTypeFunc[D.beType]) then
				beTypeFunc[D.beType](D);
			end

			if (D.checked~=nil) then
				entry.checked      = D.checked;
				if (entry.keepShownOnClick==nil) then
					entry.keepShownOnClick = 1;
				end
			else
				entry.notCheckable = true;
			end

			entry.text = D.label or "";

			if (D.colorName) then
				entry.colorCode = "|c"..ns.LC.color(D.colorName);
			elseif (D.colorCode) then
				entry.colorCode = entry.colorCode;
			end

			if (D.tooltip) and (type(D.tooltip)=="table") then
				entry.tooltipTitle = ns.LC.color("dkyellow",D.tooltip[1]);
				entry.tooltipText = ns.LC.color("white",D.tooltip[2]);
				entry.tooltipOnButton=1;
			end

			if (D.icon) then
				entry.text = entry.text .. "    ";
				entry.icon = D.icon;
				entry.tCoordLeft, entry.tCoordRight = 0.05,0.95;
				entry.tCoordTop, entry.tCoordBottom = 0.05,0.95;
			end

			if (D.func) then
				entry.arg1 = D.arg1;
				entry.arg2 = D.arg2;
				entry.func = function(...)
					D.func(...)
					if (type(D.event)=="function") then
						D.event();
					end
					if (P) and (not entry.keepShownOnClick) then
						if (_G["DropDownList1"]) then _G["DropDownList1"]:Hide(); end
					end
				end;
			end

			-- gxRestart
			-- gameRestart

			if (not D.title) and (not D.disabled) and (not D.arrow) and (not D.checked) and (not D.func) then
				entry.disabled = true;
			end
		end

		if (P) and (type(P)=="table") then
			if (not P.menuList) then P.menuList = {}; end
			tinsert(P.menuList, entry);
			return P.menuList[#P.menuList];
		else
			tinsert(self.menu, entry);
			return self.menu[#self.menu];
		end
		return false;
	end

	self.addEntries = self.addEntry;

	self.addConfigElements = function(modName,separator)
		if (separator) then
			self.addEntry({ separator = true });
		end
		self.addEntry({ label = L["Options"], title = true });
		self.addEntry({ separator = true });
		for i,v in ipairs(ns.modules[modName].config) do

			local disabled = v.disabled;
			if (type(disabled)=="function") then
				disabled=disabled();
			end

			if (disabled) or (i==1) or (i==2) then
				-- do nothing
			elseif (v.type=="separator") then
				self.addEntry({ separator=true });
			elseif (v.type=="header") then
				self.addEntry({ label=v.label, title=true });
			elseif (v.type=="toggle") then
				local tooltip = v.tooltip;
				if (type(tooltip)=="function") then
					tooltip = v.tooltip();
				end
				self.addEntry({
					label = gsub(L[v.label],"|n"," "),
					checked = function() return Broker_EverythingDB[modName][v.name]; end,
					func  = function()
						Broker_EverythingDB[modName][v.name] = not Broker_EverythingDB[modName][v.name];
						if (v.event) then ns.modules[modName].onevent({},"BE_DUMMY_EVENT"); end
					end,
					tooltip = {v.label,tooltip},
				});
			elseif (v.type=="select") then
				local p = self.addEntry({
					label = L[v.label],
					tooltip = {v.label,v.tooltip},
					arrow = true
				});
				for valKey,valLabel in ns.pairsByKeys(v.values) do
					self.addEntry({
						label = L[valLabel],
						radio = valKey,
						keepShown = false,
						checked = function() return (Broker_EverythingDB[modName][v.name]==valKey); end,
						func = function(self)
							Broker_EverythingDB[modName][v.name] = valKey;
							ns.modules[modName].onevent({},"BE_UPDATE_CLICKOPTIONS");
							self:GetParent():Hide();
						end
					},p);
				end
			elseif (v.type=="slider") then
				-- currently no idea how i can add a slider into blizzard's dropdown menu.
			end
		end
	end

	self.ShowMenu = function(parent, parentX, parentY)
		local anchor, x, y, displayMode = "cursor", nil, nil, "MENU"

		if (parent) then
			anchor = parent;
			x = parentX or 0;
			y = parentY or 0;
		end

		self.addEntry({separator=true});
		self.addEntry({label=CANCEL.." / "..CLOSE, func=function() end});

		UIDropDownMenu_Initialize(self.frame, EasyMenu_Initialize, displayMode, nil, self.menu);
		ToggleDropDownMenu(1, nil, self.frame, anchor, x, y, self.menu, nil, nil);
	end

	self.ShowDropDown = function(parent)
		local displaymode = nil;

		UIDropDownMenu_Initialize(self.frame, EasyMenu_Initialize);
		ToggleDropDownMenu(nil, nil, self.frame);
	end

	self.Refresh = function(level)
		UIDropDownMenu_Refresh(self.frame,nil,level);
	end

	self.RefreshAll = function()
		UIDropDownMenu_RefreshAll(self.frame);
	end
end


-- ----------------------- --
-- DurationOrExpireDate    --
-- ----------------------- --
ns.DurationOrExpireDate = function(timeLeft,lastTime,durationTitle,expireTitle)
	local mod = "shift";
	timeLeft = timeLeft or 0;
	if (type(lastTime)=="number") then
		timeLeft = timeLeft - (time()-lastTime);
	end
	if (IsShiftKeyDown()) then
		return date("%Y-%m-%d %H:%M",time()+timeLeft), expireTitle, mod;
	end
	return SecondsToTime(timeLeft), durationTitle, mod;
end


-- ------------------------ --
-- clickOptions System      --
-- ------------------------ --
do
	local values = {
		["__NONE"]     = "Disabled",			-- L["Disabled"]
		["_CLICK"]     = "Click",				-- L["Click"]
		["_LEFT"]      = "Left-click",			-- L["Left-click"]
		["_RIGHT"]     = "Right-click",			-- L["Right-click"]
		["ALTCLICK"]   = "Alt+Click",			-- L["Alt+Click"]
		["ALTLEFT"]    = "Alt+Left-click",		-- L["Alt+Left-click"]
		["ALTRIGHT"]   = "Alt+Right-click",		-- L["Alt+Right-click"]
		["SHIFTCLICK"] = "Shift+Click",			-- L["Shift+Click"]
		["SHIFTLEFT"]  = "Shift+Left-click",	-- L["Shift+Left-click"]
		["SHIFTRIGHT"] = "Shift+Right-click",	-- L["Shift+Right-click"]
		["CTRLCLICK"]  = "Ctrl+Click",			-- L["Ctrl+Click"]
		["CTRLLEFT"]   = "Ctrl+Left-click",		-- L["Ctrl+Left-click"]
		["CTRLRIGHT"]  = "Ctrl+Right-click",	-- L["Ctrl+Right-click"]
	};
	ns.clickOptions = {
		func =  function(name,self,button)
			if not ((ns.modules[name]) and (ns.modules[name].onclick)) then return; end

			-- click(plan)A = combine modifier if pressed with named button (left,right)
			-- click(panl)B = combine modifier if pressed with left or right mouse button without expliced check.
			local clickA,clickB="","";

			-- check modifier
			if (IsAltKeyDown()) then		clickA=clickA.."ALT";   clickB=clickB.."ALT"; end
			if (IsShiftKeyDown()) then		clickA=clickA.."SHIFT"; clickB=clickB.."SHIFT"; end
			if (IsControlKeyDown()) then	clickA=clickA.."CTRL";  clickB=clickB.."CTRL"; end

			-- no modifier used... add an undercore (for dropdown menu entry sorting)
			if (clickA=="") then clickA=clickA.."_"; end
			if (clickB=="") then clickB=clickB.."_"; end

			-- check which mouse button is pressed
			if (button=="LeftButton") then
				clickA=clickA.."LEFT";
			elseif (button=="RightButton") then
				clickA=clickA.."RIGHT"; 
			--elseif () then
			--	clickA=clickA.."";
			-- more mouse buttons?
			end

			-- planB
			clickB=clickB.."CLICK";

			if (ns.modules[name].onclick[clickA]) then
				ns.modules[name].onclick[clickA](self,button);
			elseif (ns.modules[name].onclick[clickB]) then
				ns.modules[name].onclick[clickB](self,button);
			end
		end,
		update = function(mod,db) -- BE_UPDATE_CLICKOPTION
			assert(type(mod)=="table","not a table");
			assert(type(mod.clickOptions)=="table","missing clickOptions");

			if (not mod.clickOptionsConfigNum) then
				mod.clickOptionsConfigNum={};

				tinsert(mod.config,{type="separator",alpha=0});
				tinsert(mod.config,{type="header", label=L["Broker button options"]});
				tinsert(mod.config,{type="separator"});

				for cfgKey,clickOpts in ns.pairsByKeys(mod.clickOptions) do
					local cfg_entry = {
						type	= "select",
						name	= "clickOptions::"..cfgKey,
						label	= L[clickOpts.cfg_label],
						tooltip	= L["Choose your fav. combination of modifier and mouse key to "]..L[clickOpts.cfg_desc],
						values	= values,
						default	= clickOpts.cfg_default or "__NONE",
						event	= "BE_UPDATE_CLICKOPTIONS"
					};
					tinsert(mod.config,cfg_entry);
					mod.clickOptionsConfigNum[cfgKey] = #mod.config;

					if (db["clickOptions::"..cfgKey]==nil) then
						db["clickOptions::"..cfgKey] = clickOpts.cfg_default or "__NONE";
					end
				end
			end

			mod.onclick = {};
			mod.clickHints = {};
			for cfgKey,opts in ns.pairsByKeys(mod.clickOptions) do
				if (db["clickOptions::"..cfgKey]) and (db["clickOptions::"..cfgKey]~="__NONE") then
					mod.onclick[db["clickOptions::"..cfgKey]] = opts.func;
					tinsert(mod.clickHints,ns.LC.color("copper",L[values[db["clickOptions::"..cfgKey]]]).." || "..ns.LC.color("green",L[opts.hint]));
				end
			end

			return (#mod.clickHints>0);
		end,
		ttAddHints=function(tt,name,ttColumns,entriesPerLine)
			local _lines = {};
			if (type(entriesPerLine)~="number") then entriesPerLine=1; end
			if (ns.modules[name].clickHints) then
				for i=1, #ns.modules[name].clickHints, entriesPerLine do
					if (ns.modules[name].clickHints[i]) then
						tinsert(_lines,{});
						for I=1, entriesPerLine do
							if (ns.modules[name].clickHints[i+I-1]) then
								tinsert(_lines[#_lines],ns.modules[name].clickHints[i+I-1]);
							end
						end
					end
				end
			end
			for i,v in ipairs(_lines) do
				if (v) then
					v = table.concat(v," - ");
					if (type(tt.SetCell)=="function") then
						local line = tt:AddLine();
						tt:SetCell(line,1,v,nil,"LEFT",ttColumns);
					else
						tt:AddLine(v);
					end
				end
			end
		end
	};
end

-- ----------------
-- tooltip graph (unstable)
-- ----------------
do
	local width,height,space,count = 2,50,1,50;
	local graphWidth=width*count+(space*count-1);

	local g = CreateFrame("Frame",nil, UIParent);
	g.bars={};g.elapsed=0;
	g:SetScript("OnEvent",function(self,event)
		if(event=="PLAYER_ENTERING_WORLD")then
			local b = GameTooltip:GetBackdrop()
			g:SetBackdrop(b)
			if(b)then
				g:SetBackdropColor(GameTooltip:GetBackdropColor())
				g:SetBackdropBorderColor(GameTooltip:GetBackdropBorderColor())
			end
			g:SetScale(GameTooltip:GetScale())
			g:SetAlpha(1);
			g:SetFrameStrata("TOOLTIP");
			g:SetWidth(graphWidth+12);
			g:SetHeight(height+12);
			g:Hide();

			g.anchor = g:CreateTexture();
			g.anchor:SetWidth(1); g.anchor:SetHeight(height);
			g.anchor:SetPoint("LEFT",6+graphWidth+1,0);

			for i=1, count do
				g.bars[i] = g:CreateTexture();
				g.bars[i]:SetTexture(1,1,1,0.8);
				g.bars[i]:SetWidth(width); g.bars[i]:SetHeight(1);
				g.bars[i]:SetPoint("BOTTOMRIGHT",i==1 and g.anchor or g.bars[i-1],"BOTTOMLEFT",-space,0);
			end

			g.Min = g:CreateFontString(nil,"ARTWORK","GameFontNormalSmall");
			g.Max = g:CreateFontString(nil,"ARTWORK","GameFontNormalSmall");
			g.Min:SetPoint("LEFT",g.anchor,"BOTTOMRIGHT",6,3);
			g.Max:SetPoint("LEFT",g.anchor,"TOPRIGHT",6,-3);
		end
	end);
	g:RegisterEvent("PLAYER_ENTERING_WORLD");

	g.trackHideParent = function(self,elapse)
		self.elapsed=self.elapsed+elapse;
		if(self.elapsed<0.3)then return end
		if(g.parent)then
			if(not g.parent:IsShown())then
				g:Hide();
				g:ClearAllPoints();
				g.parent=false;
			end
		end
	end
	
	g.Update = function(parent,values,opts)
		opts = opts or {};
		if(g.parent~=parent)then
			g.parent=parent;
			g:SetPoint("TOP",parent,"BOTTOM",0,-2);
			g:SetScript("OnUpdate",g.trackHideParent);
			g:Show();
		end
		local minV,maxV=values[1],0;
		for i,v in ipairs(values)do
			if(v<minV)then minV=v; end
			if(v>maxV)then maxV=v; end
		end
		local x = height/(maxV-minV);
		for i,v in ipairs(ns.graphTT.bars)do
			if(values[i])then
				local h = (values[i]-minV)*x;
				v:SetHeight(h);
				v:SetAlpha(0.7);
			else
				v:SetAlpha(0);
			end
		end
		g.Min:SetText(ceil(minV));
		g.Max:SetText(ceil(maxV));
		local wMin,wMax=g.Min:GetWidth(),g.Max:GetWidth()
		g:SetWidth(6+graphWidth+6+((wMin>wMax) and wMin or wMax)+6);
	end

	ns.graphTT = g;
end
