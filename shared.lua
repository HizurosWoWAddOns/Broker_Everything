
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


-- ---------------------------------- --
-- misc shared data                   --
-- ~Hizuro                            --
-- ---------------------------------- --
ns.realm = GetRealmName();
ns.media = "Interface\\AddOns\\"..addon.."\\media\\";


-- ----------------------------------- --
-- player and twinks dependent data    --
-- ~Hizuro                             --
-- ----------------------------------- --
ns.player = {
	name = UnitName("player"),
	female = UnitSex("player")==3
};
_, ns.player.class,ns.player.classId = UnitClass("player");
ns.player.faction,ns.player.factionL  = UnitFactionGroup("player");
L[ns.player.faction] = ns.player.factionL
ns.player.classLocale = ns.player.female and _G.LOCALIZED_CLASS_NAMES_FEMALE[ns.player.class] or _G.LOCALIZED_CLASS_NAMES_MALE[ns.player.class]
ns.LC.colorset("suffix",ns.LC.colorset[ns.player.class:lower()]) -- 

be_twink_db = {}
do
	local f = CreateFrame("Frame")
	f:SetScript("OnEvent",function(self,event,...)
		if event=="ADDON_LOADED" then
			be_twink_db[ns.realm.." - "..ns.player.name] = ns.player
			f:UnregisterEvent(event)
		end
	end)
	f:RegisterEvent("ADDON_LOADED")
end

ns.twink = function(name,realm)
	if realm == nil then realm = ns.realm end
	if realm ~= false then
		local key = realm.." - "..name
		return (be_twink_db[key]~=nil and be_twink_db[key]) or false
	else
		local twinks = {}
		for i,v in pairs(be_twink_db) do
			
		end
	end
end


-- ----------------------------------- --
-- SetCVar hook
-- Thanks at blizzard for blacklisting some cvars on combat...
-- ~Hizuro
-- ----------------------------------- --
do
	local blacklist = {alwaysShowActionBars = true, bloatnameplates = true, bloatTest = true, bloatthreat = true, consolidateBuffs = true, fullSizeFocusFrame = true, maxAlgoplates = true, nameplateMotion = true, nameplateOverlapH = true, nameplateOverlapV = true, nameplateShowEnemies = true, nameplateShowEnemyGuardians = true, nameplateShowEnemyPets = true, nameplateShowEnemyTotems = true, nameplateShowFriendlyGuardians = true, nameplateShowFriendlyPets = true, nameplateShowFriendlyTotems = true, nameplateShowFriends = true, repositionfrequency = true, showArenaEnemyFrames = true, showArenaEnemyPets = true, showPartyPets = true, showTargetOfTarget = true, targetOfTargetMode = true, uiScale = true, useCompactPartyFrames = true, useUiScale = true}
	ns.SetCVar = function(...)
		local cvar = ...
		if ns.build>=54800000 and InCombatLockdown() and blacklist[cvar]==true then
			local msg
			-- usefull blacklisted cvars..
			if cvar=="uiScale" or cvar=="useUiScale" then
				msg = "Changing UI scaling while combat nether an good idea."
			else
			-- useless blacklisted cvars...
				msg = "Sorry, CVar "..cvar.." are no longer changeable while combat. Thanks @ Blizzard."
			end
			print("|cffff8800"..addon..": "..msg.."|r")
		else
			SetCVar(...)
		end
	end
end


-- ----------------------------------- --
-- Helpful function for extra tooltips --
-- ----------------------------------- --
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
	tooltip:UpdateScrolling(GetScreenHeight() * (Broker_EverythingDB.maxTooltipHeight/100));
	tooltip:Show()
end

ns.RegisterMouseWheel = function(self,func)
	self:EnableMouseWheel(1) 
	self:SetScript("OnMouseWheel", func)
end

ns.tooltipModifiers = {
	SHIFT      = {l=L["Shift"],       f=IsShiftKeyDown},
	LEFTSHIFT  = {l=L["Left shift"],  f=IsLeftShiftKeyDown},
	RIGHTSHIFT = {l=L["Right shift"], f=IsRightShiftKeyDown},
	ALT        = {l=L["Alt"],         f=IsAltKeyDown},
	LEFTALT    = {l=L["Left alt"],    f=IsLeftAltKeyDown},
	RIGHTALT   = {l=L["Right alt"],   f=IsRightAltKeyDown},
	CTRL       = {l=L["Ctrl"],        f=IsControlKeyDown},
	LEFTCTRL   = {l=L["Left ctrl"],   f=IsLeftControlKeyDown},
	RIGHTCTRL  = {l=L["Right ctrl"],  f=IsRightControlKeyDown}
}

ns.tooltipChkOnShowModifier = function(bool)
	local modifier = Broker_EverythingDB.ttModifierKey1;
	if (modifier~="NONE") then
		modifier = (ns.tooltipModifiers[modifier]) and ns.tooltipModifiers[modifier].f();
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


-- -------------------------- --
-- icon colouring function    --
-- ~Hizuro                    --
-- -------------------------- --
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


-- -------------------------- --
-- nice little print function --
-- ~Hizuro                    --
-- -------------------------- --
ns.print = function (...)
	local colors,t = {"red","green","ltblue","yellow","orange","violet"},{}
	for i,v in ipairs({addon..":",...}) do
		if type(v)=="string" and v:match("||c") then
			tinsert(t,v)
		else
			tinsert(t,ns.LC.color(colors[i] or "white",v))
		end
	end
	print(unpack(t))
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


-- ------------------------- --
-- suffix colour function    --
-- ~Hizuro                   --
-- ------------------------- --
ns.suffixColour = function(str)
	if (Broker_EverythingDB.suffixColour) then
		str = ns.LC.color("suffix",str);
	end
	return str;
end


-- -------------------------------------------------- --
-- Icon provider and framework to support             --
-- use of external iconset                            --
-- -------------------------------------------------- --
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
-- module independent bag scan width interval                     --
-- ~Hizuro                                                        --
-- -------------------------------------------------------------- --
do
	ns.bagScan = {items={},last=time(),interval=10,active=false,resets={},updates={}}

	ns.bagScan.RegisterId = function(modName,itemId,foundFunc,resetFunc,updateFunc)
		assert(type(modName)=="string" and ns.modules[modName],"argument #1 (modName) must be a string, got "..type(modName))
		assert(type(itemId)=="number","argument #2 (itemId) must be a number, got "..type(itemId))
		assert(type(foundFunc)=="function","argument #3 (foundFunc) must be a function, got "..type(foundFunc))
		assert(type(resetFunc)=="function","argument #4 (resetFunc) must be a function, got "..type(resetFunc))
		assert(type(updateFunc)=="function","argument #5 (updateFunc) must be a function, got "..type(updateFunc))

		if ns.bagScan.items[itemId]==nil then
			ns.bagScan.items[itemId] = {}
		end
		ns.bagScan.items[itemId][modName] = foundFunc
		ns.bagScan.resets[modName] = resetFunc
		ns.bagScan.updates[modName] = updateFunc
		ns.bagScan.active = true
	end

	ns.bagScan.Update = function(now)
		-- prevent full usage of the function if no item/module registered.
		if ns.bagScan.active~=true then return end

		-- limit bagscan to a fix timeout. see ns.bagScan.interval
		if now~=true then
			if (time()-ns.bagScan.last)<ns.bagScan.interval then return end
			ns.bagScan.last = time()
		end

		-- reset tables in the registered modules
		for i,v in pairs(ns.bagScan.resets) do
			if type(v)=="function" then v() end
		end

		-- scan the bag and execute the foundFunc for all matching items
		for bag = 0, NUM_BAG_SLOTS do
			for slot = 1, GetContainerNumSlots(bag) do
				local item_id = GetContainerItemID(bag,slot)
				if ns.bagScan.items[item_id]~=nil then
					for i,v in pairs(ns.bagScan.items[item_id]) do v(item_id,bag,slot) end
				end
			end
		end

		-- trigger all updateFunc from all registered modules - mostly to update the broker button text
		for i,v in pairs(ns.bagScan.updates) do
			if type(v)=="function" then v() end
		end
	end
end


-- ----------------------------------------
-- secure button as transparent overlay
-- http://wowpedia.org/SecureActionButtonTemplate
-- be careful...
-- ~Hizuro
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
	-- ~Hizuro                                     --
	-- ------------------------------------------- --
	function ns.GetItemData(id,bag,slot)
		assert(type(id)=="number","argument #1 (id) must be a number, got "..type(id))
		local data,line,reg,_ = {},1
		data.itemName, data.itemLink, data.itemRarity, data.itemLevel, data.itemMinLevel, data.itemType, data.itemSubType, data.itemStackCount, data.itemEquipLoc, data.itemTexture, data.itemSellPrice = GetItemInfo(id)
		scanTooltip:Show();
		scanTooltip:SetOwner(UIParent,"LEFT",0,0);
		if (bag~=nil) and (slot~=nil) then
			assert(type(bag)=="number","argument #2 (bag) must be a number, got "..type(bag));
			assert(type(slot)=="number","argument #3 (slot) must be a number, got "..type(slot));
			data.startTime, data.duration, data.isEnabled = GetContainerItemCooldown(bag,slot);
			scanTooltip:SetBagItem(bag,slot);
		else
			scanTooltip:SetHyperlink("item:"..id);
		end
		reg = {scanTooltip:GetRegions()};
		for _,v in pairs(reg) do
			if (v~=nil) and (v:GetObjectType()=="FontString") and (v:GetText()~=nil) then
				data["tooltipLine"..line] = v:GetText();
				line = line + 1;
			end
		end
		scanTooltip:ClearLines();
		scanTooltip:Hide();
		return data;
	end

	function ns.GetLinkData(link)
		assert(type(link)=="string","argument #1 must be a string, got "..type(link));
		scanTooltip:Show();
		scanTooltip:SetOwner(UIParent,"LEFT",0,0);
		scanTooltip:SetHyperlink(link);
		reg = {scanTooltip:GetRegions()};
		for _,v in pairs(reg) do
			if (v~=nil) and (v:GetObjectType()=="FontString") and (v:GetText()~=nil) then
				data["tooltipLine"..line] = v:GetText();
				line = line + 1;
			end
		end
		scanTooltip:ClearLines();
		scanTooltip:Hide();
		return data;
	end

	-- --------------------------------------- --
	-- GetRealFaction2PlayerStanding           --
	-- retrun standingID of a faction          --
	-- if faction unknown or argument nil then --
	-- returns this function the standingID 4  --
	-- --------------------------------------- --
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


-- ----------------
-- tooltip graph (unstable)
-- ~Hizuro
-- ----------------
do
	local modData = {}
	ns.tooltipGraph = function(modName, maxValues, maxHeight, noScale)
		local s, barWidth, barSpace = UIParent:GetEffectiveScale(), 1, 1
		if noScale==true then s = 1 end

		local fN = ("%s_%s_ttGraph"):format(addon,modName)
		local f = f or _G[fN] or CreateFrame("frame",fN)
		if f.bars==nil then
			do
				f.bars = {}
				local n = f
				for i=1, maxValues do
					f.bars[i] = CreateFrame("frame",nil,f)
					f.bars[i]:SetWidth(barWidth * s)
					f.bars[i]:SetBackdrop({bgFile=[[Interface\Buttons\WHITE8X8]], Tile=false})
					if type(Broker_EverythingDB[modName].barColor)=="table" then
						f.bars[i]:SetBackdropColor(Broker_EverythingDB[modName].barColor)
					end
					f.bars[i]:SetPoint("BOTTOMLEFT", n, f==n and "BOTTOMLEFT" or "BOTTOMRIGHT", f==n and 0 or barSpace * s, 0)
					n=f.bars[i]
				end
			end
		end

		f:SetHeight(maxHeight)
		f:SetWidth(#modData[modName] * (barWidth+barSpace))

		local minV,maxV = 9999,0
		for i, v in ipairs(modData[modName]) do
			if v<minV then minV = v; end --min value
			if v>maxV then maxV = v; end --max value
		end

		local v
		for i=maxValues, 1, -1 do
			if modData[modName][i]==nil then
				v = 1;
			else
				v = (modData[modName][i] - minV) / ((maxV - minV) / maxHeight);
			end
			f.bars[maxValues - i + 1]:SetHeight(ceil(v) * s)
		end

		return f
	end
	ns.tooltipGraphAddValue = function(modName,value,maxValues)
		local t = {}
		if modData[modName]==nil then modData[modName] = {} end
		table.insert(t,tonumber(value))
		for i,v in ipairs(modData[modName]) do
			if (#t < maxValues) then
				table.insert(t,v)
			end
		end
		modData[modName] = t
	end
end


-- ----------------------------------------------------- --
-- goldColor function to display amount of gold          --
-- in colored strings or with coin textures depending on --
-- a per module and a addon wide toggle.                 --
-- ~Hizuro                                               --
-- ----------------------------------------------------- --
function ns.GetCoinColorOrTextureString(modName,amount,sep)
	local hideCopper = false;
	if (Broker_EverythingDB.goldHideCopper==true) then
		if (floor(amount/100)>0) then
			amount = floor(amount/100) * 100;
			hideCopper=true;
		end
	end
	if (Broker_EverythingDB[modName].goldColor==true) or (Broker_EverythingDB.goldColor==true) then
		if (not sep) then sep = "." end
		local gold, silver, copper, t, i = floor(amount / 10000), mod(floor(amount / 100), 100), mod(floor(amount), 100), {}, 1
		if gold>0 then t[i]=ns.LC.color("gold",gold) silver=("%02d"):format(silver) i=i+1 end
		if tonumber(silver)>0 or silver=="00" then t[i]=ns.LC.color("silver",silver) copper=("%02d"):format(copper) i=i+1 end
		if (not hideCopper) then
			t[i] = ns.LC.color("copper",copper)
		end
		return table.concat(t,sep)
	else
		return GetCoinTextureString(amount)
	end
end


-- ----------------------------------------------------- --
-- screen capture mode - string replacement function     --
-- ~Hizuro                                               --
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
-- ~Hizuro                  --
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
-- ~Hizuro          --
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
			local parent = self.addEntry({ label=D.label, arrow=true },P);
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
			local parent = self.addEntry({ label=D.label, arrow=true },P);
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
end


-- ----------------------- --
-- DurationOrExpireDate    --
-- ~Hizuro                 --
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
-- ~Hizuro                  --
-- ------------------------ --

ns.clickOptions = {
	values = {
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
	},
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
					values	= ns.clickOptions.values,
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
				tinsert(mod.clickHints,ns.LC.color("copper",L[ns.clickOptions.values[db["clickOptions::"..cfgKey]]]).." || "..ns.LC.color("green",L[opts.hint]));
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

