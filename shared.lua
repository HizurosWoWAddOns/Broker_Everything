
-- ====================================== --
-- Shared Functions for Broker_Everything --
-- ====================================== --
local addon, ns = ...;
local L,_ = ns.L;
local UnitName,UnitSex,UnitClass,UnitFactionGroup=UnitName,UnitSex,UnitClass,UnitFactionGroup;
local UnitRace,GetRealmName,GetLocale,UnitGUID=UnitRace,GetRealmName,GetLocale,UnitGUID;
local InCombatLockdown,CreateFrame=InCombatLockdown,CreateFrame;
local GetScreenHeight,GetMouseFocus,GetAddOnInfo=GetScreenHeight,GetMouseFocus,GetAddOnInfo;
local GetAddOnEnableState,GetSpellInfo,IsAltKeyDown=GetAddOnEnableState,GetSpellInfo,IsAltKeyDown;
local IsShiftKeyDown,IsControlKeyDown,GetItemInfo=IsShiftKeyDown,IsControlKeyDown,GetItemInfo;
local GetContainerItemCooldown,GetContainerItemLink=GetContainerItemCooldown,GetContainerItemLink;
local GetInventoryItemDurability,GetInventoryItemBroken=GetInventoryItemDurability,GetInventoryItemBroken;
local GetInventoryItemLink,GetInventoryItemID,GetContainerNumSlots=GetInventoryItemLink,GetInventoryItemID,GetContainerNumSlots;
local GetContainerItemID,GetContainerItemInfo,SecondsToTime=GetContainerItemID,GetContainerItemInfo,SecondsToTime;
local GetContainerItemDurability,IsEquippableItem,CopyTable=GetContainerItemDurability,IsEquippableItem,CopyTable;
local setmetatable,tonumber,rawget,rawset,tinsert=setmetatable,tonumber,rawget,rawset,tinsert;
local tremove,tostring,type,print,unpack,assert=tremove,tostring,type,print,unpack,assert;
local securecall,ipairs,pairs,tconcat,tsort=securecall,ipairs,pairs,table.concat,table.sort;
local time,wipe,mod,hooksecurefunc,strsplit=time,wipe,mod,hooksecurefunc,strsplit;

-- could be deprecated in future.
local GetCVar,SetCVar = C_CVar and C_CVar.GetCVar or GetCVar,C_CVar and C_CVar.SetCVar or SetCVar

  -------------
--- Libraries ---
  -------------
ns.LDB = LibStub("LibDataBroker-1.1");
ns.LQT = LibStub("LibQTip-1.0");
ns.LDBI = LibStub("LibDBIcon-1.0");
ns.LSM = LibStub("LibSharedMedia-3.0");
ns.LT = LibStub("LibTime-1.0");
ns.LC = LibStub("LibColors-1.0");
ns.LRI = LibStub("LibRealmInfo");

-- broker_everything colors
ns.LC.colorset({
	["ltyellow"]	= "fff569",
	["dkyellow"]	= "ffcc00",
	["dkyellow2"]	= "bbbb00",

	["ltorange"]	= "ff9d6a",
	["dkorange"]	= "905d0a",
	["dkorange2"]	= "c06d0a",

	--["dkred"]		= "c41f3b",
	["ltred"]		= "ff8080",
	["dkred"]		= "800000",

	["violet"]		= "f000f0",
	["ltviolet"]	= "f060f0",
	["dkviolet"]	= "800080",

	["ltblue"]		= "69ccf0",
	["dkblue"]		= "000088",
	["dailyblue"]	= "00b3ff",

	["ltcyan"]		= "80ffff",
	["dkcyan"]		= "008080",

	["ltgreen"]		= "80ff80",
	["dkgreen"]		= "00aa00",

	["dkgray"]		= "404040",
	["gray2"]		= "A0A0A0",
	["ltgray"]		= "b0b0b0",

	["gold"]		= "ffd700",
	["silver"]		= "eeeeef",
	["copper"]		= "f0a55f",

	["unknown"]		= "ee0000",
});


  ---------------------------------------
--- nice little print function          ---
  ---------------------------------------
do
	local addon_short = L[addon.."_Shortcut"];
	local colors = {"0099ff","00ff00","ff6060","44ffff","ffff00","ff8800","ff44ff","ffffff"};
	local function colorize(...)
		local t,c,a1 = {tostringall(...)},1,...;
		if type(a1)=="boolean" then tremove(t,1); end
		if a1~=false then
			tinsert(t,1,"|cff0099ff"..((a1==true and addon_short) or (a1=="||" and "||") or addon).."|r"..(a1~="||" and HEADER_COLON or ""));
			c=2;
		end
		for i=c, #t do
			if not t[i]:find("\124c") then
				t[i],c = "|cff"..colors[c]..t[i].."|r", c<#colors and c+1 or 1;
			end
		end
		return unpack(t);
	end
	function ns.print(...)
		print(colorize(...));
	end
	function ns.debug(name,...)
		ConsolePrint(date("|cff999999%X|r"),colorize("<debug::"..name..">",...));
	end
	if ("@project-version@" == "@".."project-version".."@") then
		local function GetNamespace()
			return ns;
		end
		_G[addon.."_GetNS"] = GetNamespace
	end
end


  ---------------------------------------
--- misc shared data                    ---
  ---------------------------------------
ns.icon_fallback = 134400; -- interface\\icons\\INV_MISC_QUESTIONMARK;
ns.icon_arrow_right = "interface\\CHATFRAME\\ChatFrameExpandArrow";
ns.media = "Interface\\AddOns\\"..addon.."\\media\\";
ns.locale = GetLocale();
ns.ui = {size={UIParent:GetSize()},center={UIParent:GetCenter()}};
ns.realm = GetRealmName();
do
	local pattern = "^"..(ns.realm:gsub("(.)","[%1]*")).."$";
	for i,v in ipairs(GetAutoCompleteRealms()) do
		if v:match(pattern) then
			ns.realm_short = v;
			break;
		end
	end
	if not ns.realm_short then
		ns.realm_short = ns.realm:gsub(" ",""):gsub("%-","");
	end
end


  -----------------------
-- Client version checks --
  -----------------------
do
	local version,build = GetBuildInfo();
	local v1,v2,v3 = strsplit(".",version);
	ns.client_version = tonumber(v1.."."..v2..v3..build);
end

function ns.IsClassicClient() -- for AceOptions
	return ns.client_version<2;
end

function ns.IsNotClassicClient() -- for AceOptions
	return ns.client_version>=2;
end


  ---------------------------------------
--- player and twinks dependent data    ---
  ---------------------------------------
function ns.stripRealm(name)
	return name:gsub(" ",""):gsub("%-","");
end
ns.player = {
	name = UnitName("player"),
	female = UnitSex("player")==3,
};
ns.player.name_realm = ns.player.name.."-"..ns.realm;
ns.player.name_realm_short = ns.player.name.."-"..ns.realm_short;
_, ns.player.class,ns.player.classId = UnitClass("player");
ns.player.faction,ns.player.factionL  = UnitFactionGroup("player");
L[ns.player.faction] = ns.player.factionL;
ns.player.classLocale = ns.player.female and _G.LOCALIZED_CLASS_NAMES_FEMALE[ns.player.class] or _G.LOCALIZED_CLASS_NAMES_MALE[ns.player.class];
ns.player.raceLocale,ns.player.race,ns.player.raceIndex = UnitRace("player");
ns.LC.colorset("suffix",ns.LC.colorset[ns.player.class:lower()]);
ns.realms = {};
do
	local function Init()
		local _,_,_,_,_,_,_,_,ids = ns.LRI:GetRealmInfoByGUID(UnitGUID("player"));
		if type(ids)=="table" then
			for i=1, #ids do
				local _,name,apiName = ns.LRI:GetRealmInfoByID(ids[i]);
				if type(name)=="string" and type(apiName)=="string" then
					ns.realms[name] = apiName;
					if apiName~=name then
						ns.realms[apiName] = name;
					end
				end
			end
		else
			ns.realms[ns.realm] = ns.realm_short;
			if ns.realm~=ns.realm_short then
				ns.realms[ns.realm_short] = ns.realm;
			end
		end
	end
	setmetatable(ns.realms,{
		__index = function(t,k)
			if Init then Init(); Init=nil; end
			return rawget(t,k) or false;
		end
	});
end

function ns.realmCheckOrAppend(str)
	if type(str)=="string" and not str:find("-") then
		return str.."-"..ns.realm_short;
	end
	return str;
end

function ns.showThisChar(modName,realm,faction)
	if not ns.profile[modName].showAllFactions and ns.player.faction~=faction then
		return false;
	end
	if ns.profile[modName].showCharsFrom=="1" and realm~=ns.realm then -- same realm
		return false;
	elseif ns.profile[modName].showCharsFrom=="2" and not ns.realms[realm] then -- connected realms
		return false;
	elseif ns.profile[modName].showCharsFrom=="3" then -- battlegroup
		local _,_,_,_,_,battlegroup = ns.LRI:GetRealmInfo(realm);
		if not ns.player.battlegroup then
			_,_,_,_,_,ns.player.battlegroup = ns.LRI:GetRealmInfoByGUID(UnitGUID("player"));
		end
		if ns.player.battlegroup~=battlegroup then
			return false;
		end
	end
	return true;
end

function ns.showRealmName(mod,name,color,prepDash)
	if not (ns.realm_short==name or ns.realm==name) then
		if ns.profile[mod].showRealmNames then
			if type(name)=="string" and name:len()>0 then
				local _,_name = ns.LRI:GetRealmInfo(name);
				if _name then
					return (prepDash~=false and ns.LC.color("white"," - "))..ns.LC.color(color or "dkyellow", ns.scm(name));
				end
			end
		else
			return ns.LC.color("dkyellow"," *");
		end
	end
	return "";
end


  -----------------------------------------
--- SetCVar hook                          ---
--- Thanks at blizzard for blacklisting   ---
--- some cvars on combat...               ---
  -----------------------------------------
do
	local blacklist = {alwaysShowActionBars = true, bloatnameplates = true, bloatTest = true, bloatthreat = true, consolidateBuffs = true, fullSizeFocusFrame = true, maxAlgoplates = true, nameplateMotion = true, nameplateOverlapH = true, nameplateOverlapV = true, nameplateShowEnemies = true, nameplateShowEnemyGuardians = true, nameplateShowEnemyPets = true, nameplateShowEnemyTotems = true, nameplateShowFriendlyGuardians = true, nameplateShowFriendlyPets = true, nameplateShowFriendlyTotems = true, nameplateShowFriends = true, repositionfrequency = true, showArenaEnemyFrames = true, showArenaEnemyPets = true, showPartyPets = true, showTargetOfTarget = true, targetOfTargetMode = true, uiScale = true, useCompactPartyFrames = true, useUiScale = true}
	function ns.SetCVar(...)
		local cvar = ...
		if ns.client_version>5.48 and InCombatLockdown() and blacklist[cvar]==true then
			local msg
			-- usefull blacklisted cvars...
			if cvar=="uiScale" or cvar=="useUiScale" then
				msg = L["CVarScalingInCombat"];
			else
			-- useless blacklisted cvars...
				msg = L["CVarInCombat"]:format(cvar);
			end
			ns.print(ns.LC.color("ltorange",msg));
		else
			SetCVar(...)
		end
	end
end


  ---------------------------------------
--- Helpful function for extra tooltips ---
  ---------------------------------------
local brokerDragHooks, openTooltip, hiddenMouseOver, currentBroker = {};

function ns.GetTipAnchor(frame, direction, parentTT)
	if not frame then return end
	local f,u,i,H,h,v,V = {frame:GetCenter()},{},0;
	if f[1]==nil or ns.ui.center[1]==nil then
		return "LEFT";
	end
	h = (f[1]>ns.ui.center[1] and "RIGHT") or "LEFT";
	v = (f[2]>ns.ui.center[2] and "TOP") or "BOTTOM";
	u[4]=ns.ui.center[1]/4; u[5]=ns.ui.center[2]/4; u[6]=(ns.ui.center[1]*2)-u[4]; u[7]=(ns.ui.center[2]*2)-u[5];
	H = (f[1]>u[6] and "RIGHT") or (f[1]<u[4] and "LEFT") or "";
	V = (f[2]>u[7] and "TOP") or (f[2]<u[5] and "BOTTOM") or "";
	if parentTT then
		local p,ph,pv,pH,pV = {parentTT:GetCenter()};
		ph,pv = (p[1]>ns.ui.center[1] and "RIGHT") or "LEFT", (p[2]>ns.ui.center[2] and "TOP") or "BOTTOM";
		pH = (p[1]>u[6] and "RIGHT") or (p[1]<u[4] and "LEFT") or "";
		pV = (p[2]>u[7] and "TOP") or (p[2]<u[5] and "BOTTOM") or "";
		if direction=="horizontal" then
			return pV..ph, parentTT, pV..(ph=="LEFT" and "RIGHT" or "LEFT"), ph=="LEFT" and i or -i, 0;
		end
		return pv..pH, parentTT, (pv=="TOP" and "BOTTOM" or "TOP")..pH, 0, pv=="TOP" and i or -i;
	else
		if direction=="horizontal" then
			return V..h, frame, V..(h=="LEFT" and "RIGHT" or "LEFT"), h=="LEFT" and i or -i, 0;
		end
		return v..H, frame, (v=="TOP" and "BOTTOM" or "TOP")..H, 0, v=="TOP" and i or -i;
	end
end


----------------------------------
-- ttMode [ 1: close on leave broker button (bool/nil) | 2: dont use hiddenMouseOver (bool/nil) ],
-- ttParent [ 1: parent frame element (frame) | 2: anchor direction (string) | 3: alternative anchor target (frame/optional) ]

local function MouseIsOver(region, topOffset, bottomOffset, leftOffset, rightOffset)
	if region and region.IsMouseOver then -- stupid blizzard does not check if exists...
		return region:IsMouseOver(topOffset, bottomOffset, leftOffset, rightOffset);
	end
end

local function hideOnLeave(self)
	local _, hiddenMouseOverAnchor = hiddenMouseOver:GetPoint();
	if self.parent and self.parent[1] and (MouseIsOver(self.parent[1]) or (self.parent[1]==hiddenMouseOverAnchor and MouseIsOver(hiddenMouseOver))) then return end -- mouse is over broker and/or extended broker button area
	if MouseIsOver(self) and ( (self.slider and self.slider:IsShown()) or (self.mode and self.mode[1]~=true) ) then return end -- tooltip with active scrollframe or mouse over tooltip with clickable elements
	if self.OnHide then
		self.OnHide(self);
		self.OnHide = nil;
	end
	ns.hideTooltip(self);
end

local function hideOnUpdate(self, elapse)
	if not self:IsShown() then
		self:SetScript("OnUpdate",nil);
		return;
	end
	if (self.elapsed or 1)>0 then
		self.elapsed = 0;
		hideOnLeave(self);
	else
		self.elapsed = (self.elapsed or 0) + elapse;
	end
end

local function hookDragStart(self)
	if brokerDragHooks[self] and brokerDragHooks[self][1]==brokerDragHooks[self][2].key and brokerDragHooks[self][2]:IsShown() then
		ns.hideTooltip(brokerDragHooks[self][2]);
	end
end

function ns.acquireTooltip(ttData,ttMode,ttParent,ttScripts)
	if openTooltip and openTooltip.key~=ttData[1] and openTooltip.parent and not (ttParent[1]==openTooltip or (ttParent[3] and ttParent[3]==openTooltip)) then
		ns.hideTooltip(openTooltip);
	end
	if ns.LQT:IsAcquired(ttData[1]) then
		openTooltip = ns.LQT:Acquire(ttData[1])
		return openTooltip;
	end
	local modifier = ns.profile.GeneralOptions.ttModifierKey2;
	local tooltip = ns.LQT:Acquire(unpack(ttData)); openTooltip = tooltip;

	tooltip.parent,tooltip.mode,tooltip.scripts = ttParent,ttMode,ttScripts;
	tooltip.mode[1] = tooltip.mode[1]==true or (modifier~="NONE" and ns.tooltipChkOnShowModifier(modifier,false))
	if hiddenMouseOver==nil then
		hiddenMouseOver = CreateFrame("Frame",addon.."TooltipHideShowFix2",UIParent);
		hiddenMouseOver:SetFrameStrata("BACKGROUND");
	end
	if not tooltip.mode[2] and ttParent[1] and not ttParent[1].parent then
		hiddenMouseOver:SetPoint("TOPLEFT",ttParent[1],"TOPLEFT",0,1);
		hiddenMouseOver:SetPoint("BOTTOMRIGHT",ttParent[1],"BOTTOMRIGHT",0,-1);
	end
	tooltip:SetScript("OnUpdate",hideOnUpdate);
	tooltip:SetScript("OnLeave",hideOnLeave);

	if _G.TipTac and _G.TipTac.AddModifiedTip then
		_G.TipTac:AddModifiedTip(tooltip, true); -- Tiptac Support for LibQTip Tooltips
	elseif AddOnSkins and AddOnSkins.SkinTooltip then
		AddOnSkins:SkinTooltip(tooltip); -- AddOnSkins support
	end

	tooltip:SetClampedToScreen(true);
	tooltip:SetPoint(ns.GetTipAnchor(unpack(ttParent)));

	if type(ttParent[1])=="table" and ttParent[1]:GetObjectType()=="Button" then
		currentBroker = ttParent;
		if not brokerDragHooks[ttParent[1]] then
			-- close tooltips if broker button fire OnDragStart
			ttParent[1]:HookScript("OnDragStart",hookDragStart);
		end
		brokerDragHooks[ttParent[1]]={tooltip.key,tooltip};
	end

	return tooltip;
end

function ns.roundupTooltip(tooltip,ignoreMaxTooltipHeight)
	if not tooltip then return end
	if not ignoreMaxTooltipHeight then
		tooltip:UpdateScrolling(GetScreenHeight() * (ns.profile.GeneralOptions.maxTooltipHeight/100));
	end
	tooltip:SetClampedToScreen(true);
	tooltip:Show();
end

function ns.hideTooltip(tooltip)
	if type(tooltip)~="table" then return; end
	if type(tooltip.secureButtons)=="table" then
		local f = GetMouseFocus()
		if f and not f:IsForbidden() and (not f:IsProtected() and InCombatLockdown()) and type(f.key)=="string" and type(ttName)=="string" and f.key==ttName then
			return; -- why that? tooltip can't be closed in combat with securebuttons as child elements. results in addon_action_blocked...
		end
		ns.secureButton(false);
	end
	tooltip:SetScript("OnLeave",nil);
	tooltip:SetScript("OnUpdate",nil);
	hiddenMouseOver:ClearAllPoints();
	if tooltip.scripts and type(tooltip.scripts.OnHide)=="function" then
		tooltip.scripts.OnHide(tooltip);
	end
	tooltip.parent = nil;
	tooltip.mode = nil;
	tooltip.scripts = nil;
	ns.LQT:Release(tooltip);
	return;
end

----------------------------------------

function ns.RegisterMouseWheel(self,func)
	self:EnableMouseWheel(1);
	self:SetScript("OnMouseWheel", func);
end

-- L["ModKey" .. ns.tooltipModifiers.<key>.l]
--@do-not-package@
--[[
L["ModKeyS"] L["ModKeyLS"] L["ModKeyRS"]
L["ModKeyA"] L["ModKeyRA"] L["ModKeyLA"]
L["ModKeyC"] L["ModKeyLC"] L["ModKeyRC"]
--]]
--@end-do-not-package@
ns.tooltipModifiers = {
	SHIFT      = {l="S",  f="Shift"},
	LEFTSHIFT  = {l="LS", f="LeftShift"},
	RIGHTSHIFT = {l="RS", f="RightShift"},
	ALT        = {l="A",  f="Alt"},
	LEFTALT    = {l="LA", f="LeftAlt"},
	RIGHTALT   = {l="RA", f="RightAlt"},
	CTRL       = {l="C",  f="Control"},
	LEFTCTRL   = {l="LC", f="LeftControl"},
	RIGHTCTRL  = {l="RC", f="RightControl"}
}

function ns.tooltipChkOnShowModifier(bool)
	local modifier = ns.profile.GeneralOptions.ttModifierKey1;
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

function ns.AddSpannedLine(tt,content,cells,align,font)
	local cells,l = cells or {},tt:AddLine();
	tt:SetCell(l,cells.start or 1,content,font,align,cells.count or 0);
	return l;
end

function ns.getBorderPositions(f)
	local us = UIParent:GetEffectiveScale();
	local uw,uh = UIParent:GetWidth(), UIParent:GetHeight();
	local fx,fy = f:GetCenter();
	local fw,fh = f:GetWidth()/2, f:GetHeight()/2;
	-- LEFT, RIGHT, TOP, BOTTOM
	return fx-fw, uw-(fx+fw), uh-(fy+fh),fy-fh;
end


  --------------------------------------------------------------------------
--- coexistence with other addons                                          ---
--- sometimes it is better to let other addons the control about something ---
  --------------------------------------------------------------------------
do
	local found,list = false,{
		-- ["<addon name>"] = "<msg>",
		["Carbonite"]			= "CoExistUnsave",
		["DejaMinimap"]			= "CoExistUnsave",
		["Chinchilla"]			= "CoExistSimilar",
		["Dominos_MINIMAP"]		= "CoExistSimilar",
		["gUI4_Minimap"]		= "CoExistOwn",
		["LUI"]					= "CoExistOwn",
		["MinimapButtonFrame"]	= "CoExistUnsave",
		["SexyMap"]				= "CoExistSimilar",
		["SquareMap"]			= "CoExistUnsave",
		-- L["CoExistUnsave"] L["CoExistSimilar"] L["CoExistOwn"]
	};
	ns.coexist = {};
	function ns.coexist.IsNotAlone(info)
		if found==false then
			found = {};
			for name in pairs(list) do
				if (GetAddOnInfo(name)) and (GetAddOnEnableState(ns.player.name,name)==2) then
					tinsert(found,name);
				end
			end
		end
		local b = #found>0;
		if info and info[#info]:find("Info$") then -- for Ace3 Options (<hidden|disabled>=<thisFunction>)
			return not b;
		end
		return b;
	end

	function ns.coexist.optionInfo()
		-- This option is disabled because:
		-- <addon> >> <msg>
		local msgs = {};
		for i=1, #found do
			tinsert(msgs, ns.LC.color("ltblue",found[i]).."\n"..ns.LC.color("ltgray"," >> ")..L[list[found[i]]]);
		end
		return ns.LC.color("orange",L["CoExistDisabled"]).."\n"
			.. tconcat(msgs,"\n");
	end
end


  ---------------------------------------
--- suffix colour function              ---
  ---------------------------------------
function ns.suffixColour(str)
	if (ns.profile.GeneralOptions.suffixColour) then
		str = ns.LC.color("suffix",str);
	end
	return str;
end


  ------------------------------------------
--- Icon provider and framework to support ---
--- use of external iconset                ---
  ------------------------------------------
do
	ns.I = setmetatable({},{
		__index = function(t,k)
			local v = {iconfile=ns.icon_fallback,coords={0.05,0.95,0.05,0.95}}
			rawset(t, k, v)
			return v
		end,
		__call = function(t,a)
			local iconset
			if a==true then
				if ns.profile.GeneralOptions.iconset~="NONE" then
					iconset = ns.LSM:Fetch((addon.."_Iconsets"):lower(),ns.profile.GeneralOptions.iconset) or iconset
				end
				return
			end
			assert(type(a)=="string","argument #1 must be a string, got "..type(a))
			return (type(iconset)=="table" and iconset[a]) or t[a]
		end
	})
	function ns.updateIcons(name,part)
		if name==true then
			local result = true;
			for modName,mod in pairs(ns.modules) do
				if mod.isEnabled and ns.updateIcons(modName,part)==false then
					result = false;
				end
			end
			return result;
		elseif type(name)=="string" and ns.modules[name] and ns.modules[name].isEnabled and ns.modules[name].obj then
			local mod = ns.modules[name];
			if part=="color" or part==nil then
				mod.obj.iconR,mod.obj.iconG,mod.obj.iconB,mod.obj.iconA = unpack(ns.profile.GeneralOptions.iconcolor or ns.LC.color("white","colortable"));
			end
			if part=="icon" or part==nil then
				local icon = ns.I(mod.iconName .. (mod.icon_suffix or ""));
				mod.obj.iconCoords = icon.coords or {0,1,0,1};
				mod.obj.icon = icon.iconfile;
			end
			return true;
		end
		return false;
	end
end


-- ------------------------------ --
-- missing real found function    --
-- ------------------------------ --
function ns.round(num,precision)
	return tonumber(("%."..(tonumber(precision) or 0).."f"):format(num or 0)) or 0;
end


-- -------------------------------------------------- --
-- Function to Sort a table by the keys               --
-- Sort function fom http://www.lua.org/pil/19.3.html --
-- -------------------------------------------------- --
do
	local function invert(a,b)
		return a>b;
	end
	function ns.pairsByKeys(t, f)
		local a = {}
		for n in pairs(t) do
			tinsert(a, n)
		end
		if f==true then
			f = invert;
		end
		tsort(a, f)
		local i = 0      -- iterator variable
		local function iter()   -- iterator function
			i = i + 1
			if a[i] == nil then
				return nil
			else
				return a[i], t[a[i]]
			end
			return a[i], t[a[i]]
		end
		return iter
	end
end

function ns.pairsToons(currentFirst,currentRealm)
	currentFirst,currentRealm = not not currentFirst,not not currentRealm;
	local t={};
	for index,name in ipairs(Broker_Everything_CharacterDB.order) do
		local _,r = strsplit("-",name,2);
		if currentFirst and name==ns.player.name_realm then
			tinsert(t,1,index);
		elseif (not currentRealm) or (currentRealm and r==ns.realm) then
			tinsert(t,index);
		end
	end
	local i=0;
	local function iter()
		i=i+1;
		local index = t[i];
		if Broker_Everything_CharacterDB.order[index]==nil then
			return nil;
		end
		local name = Broker_Everything_CharacterDB.order[index];
		local toonName,toonRealm = strsplit("-",name,2);
		return index, toonName, toonRealm, Broker_Everything_CharacterDB[name], name==ns.player.name_realm; -- index, toonName, toonRealm, toonData, isCurrent
	end
	return iter;
end


-- ------------------------------------------------------------ --
-- Function to check/create a table structure by given path
-- ------------------------------------------------------------ --

function ns.tablePath(tbl,a,...)
	if type(a)~="string" then return end
	if type(tbl[a])~="table" then tbl[a]={}; end
	if (...) then ns.tablePath(tbl[a],...); end
end


-- ------------------------------------ --
-- FormatLargeNumber function advanced  --
-- ------------------------------------ --
do
	-- L["SizeSuffix-10E18"] L["SizeSuffix-10E15"] L["SizeSuffix-10E12"] L["SizeSuffix-10E9"] L["SizeSuffix-10E6"] L["SizeSuffix-10E3"]
	local floatformat,sizes = "%0.1f",{
		18,15,12,9,6,3 -- Qi Qa T B M K (Qi Qa Tr Bi Mi Th?)
	};
	function ns.FormatLargeNumber(modName,value,tooltip)
		local shortNumbers,doShortcut = false, not (tooltip and IsShiftKeyDown());
		if type(modName)=="boolean" then
			shortNumbers = modName;
		elseif modName and ns.profile[modName] then
			shortNumbers = ns.profile[modName].shortNumbers;
		end
		value = tonumber(value) or 0;
		if shortNumbers and doShortcut then
			for i=1, #sizes do
				if value>=(10^sizes[i]) then
					value = floatformat:format(value/(10^sizes[i]))..L["SizeSuffix-10E"..sizes[i]];
					break;
				end
			end
		elseif ns.profile.GeneralOptions.separateThousands then
			value = FormatLargeNumber(value);
		end
		return value;
	end
end


-- --------------------- --
-- Some string  function --
-- --------------------- --
function ns.strWrap(text, limit, insetCount, insetChr, insetLastChr)
	if not text then return ""; end
	if text:match("\n") or text:match("%|n") then
		local txt = text:gsub("%|n","\n");
		local strings,tmp = {strsplit("\n",txt)},{};
		for i=1, #strings do
			tinsert(tmp,ns.strWrap(strings[i], limit, insetCount, insetChr, insetLastChr));
		end
		return tconcat(tmp,"\n");
	end
	if text:len()<=limit then return text; end
	local tmp,result,inset = "",{},"";
	if type(insetCount)=="number" then
		inset = (insetChr or " "):rep(insetCount-(insetLastChr or ""):len())..(insetLastChr or "");
	end
	for str in text:gmatch("([^ \n]+)") do
		local tmp2 = (tmp.." "..str):trim();
		if tmp2:len()>=limit then
			tinsert(result,tmp);
			tmp = str:trim();
		else
			tmp = tmp2;
		end
	end
	if tmp~="" then
		tinsert(result,tmp);
	end
	return tconcat(result,"|n"..inset)
end

function ns.strCut(str,limit)
	if str:len()>limit-3 then str = strsub(str,1,limit-3).."..." end
	return str
end

function ns.strFill(str,pat,count,append)
	local l = (count or 1) - str:len();
	if l<=0 then return str; end
	local p = (pat or " "):rep(l);
	if append then return str..p; end
	return p..str;
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
do
	local sbf_hooks,sbfObject,sbf,_sbf = false,{};
	function ns.secureButton(self,obj)
		if self==nil or InCombatLockdown() then
			return;
		end

		if sbf~=nil and self==false then
			sbf:Hide();
			return;
		end

		if type(obj)~="table" then
			return;
		end

		sbfObject = obj;

		if not sbf then
			sbf = CreateFrame("Button",addon.."_SecureButton",UIParent,"SecureActionButtonTemplate, SecureHandlerEnterLeaveTemplate, SecureHandlerShowHideTemplate");
			sbf:SetHighlightTexture([[interface\friendsframe\ui-friendsframe-highlightbar-blue]],true);
			sbf:HookScript("OnClick",function(_,button) if type(sbfObject.OnClick)=="function" then sbfObject.OnClick(self,button,sbfObject); end end);
			sbf:HookScript("OnEnter",function() if type(sbfObject.OnEnter)=="function" then sbfObject.OnEnter(self,sbfObject); end end);
			sbf:HookScript("OnLeave",function() if type(sbfObject.OnLeave)=="function" then sbfObject.OnLeave(self,sbfObject); end end);
		end

		sbf:SetParent(self);
		sbf:SetPoint("CENTER");
		sbf:SetSize(self:GetSize());

		for k,v in pairs(obj.attributes) do
			if type(k)=="string" and v~=nil then
				sbf:SetAttribute(k,v);
			end
		end

		sbf:SetAttribute("_onleave","self:Hide()");
		sbf:SetAttribute("_onhide","self:SetParent(UIParent);self:ClearAllPoints();");

		sbf:Show();
	end
end


-- -------------------------------------------------------------- --
-- module independent bags and inventory scanner                  --
-- event driven with delayed execution                            --
-- -------------------------------------------------------------- --
do
	local itemsByID,itemsBySlot,equip,ammo = {},{},{},{};
	ns.items = {byID=itemsByID,bySlot=itemsBySlot,equip=equip,ammo=ammo};

	local hasChanged,updateBags,IsEnabledBags,IsEnabledInv = {bags=false,inv=false,equip=false,ammo=false,items=false,item={},itemNum=0},{};
	local callbacks = {any={},inv={},bags={},item={},equip={},prepare={}};
	local eventFrame = CreateFrame("Frame");

	local function doCallbacks(...)
		local tbl = ...;
		if callbacks[tbl.."Num"]==0 then
			return; -- no callbacks registered
		end
		for modName,fnc in pairs(callbacks[tbl])do
			fnc(...);
		end
	end

	local function callbackHandler(changedItems)
		-- execute callback functions

		if hasChanged.bags or hasChanged.inv or hasChanged.equip or hasChanged.items or hasChanged.ammo then
			-- 'prepare' callbacks
			doCallbacks("prepare",hasChanged);

			-- 'any' callbacks
			doCallbacks("any",hasChanged);
		end

		-- 'item' callbacks
		if hasChanged.items then
			for id,locations in pairs(hasChanged.item)do
				if callbacks.item[id] and #callbacks.item[id] then
					doCallbacks("item",id,location);
				end
			end
			wipe(hasChanged.item);
			hasChanged.items = false;
		end

		-- callbacks by type
		for _, cbType in ipairs({"bags","inv","equip","ammo"}) do
			if hasChanged[cbType] then
				doCallbacks(cbType);
				hasChanged[cbType] = false;
			end
		end
	end

	local function addItem(info,scanner)
		if itemsBySlot[info.sharedSlot] and itemsBySlot[info.sharedSlot].diff==diffStr then
			return false; -- item has not changed; must be added again.
		end
		if itemsByID[info.id]==nil then
			itemsByID[info.id] = {};
		end
		itemsByID[info.id][info.sharedSlot] = info;
		itemsBySlot[info.sharedSlot] = info;
		if info.equip then
			equip[info.sharedSlot] = true;
			hasChanged.equip = true;
		end
		if ns.client_version<2 then
			if info.ammo then
				ammo[info.sharedSlot] = true;
				hasChanged.ammo = true;
			end
			-- souls?
		end
		if callbacks.item[id] then
			hasChanged.item[id][info.sharedSlot] = true;
			hasChanged.items = true;
		end
		hasChanged[scanner] = true;
		return true;
	end

	local function removeItem(sharedSlotIndex,scanner)
		itemsByID[itemsBySlot[sharedSlotIndex].id][sharedSlotIndex] = nil;
		itemsBySlot[sharedSlotIndex] = nil;
		if equip[sharedSlotIndex] then
			equip[sharedSlotIndex] = nil;
			hasChanged.equip = true;
		end
		if ns.client_version<2 and ammo[sharedSlotIndex] then
			ammo[sharedSlotIndex] = nil;
			hasChanged.ammo = true;
		end
		if callbacks.item[id] then
			hasChanged.item[id][sharedSlotIndex] = true;
			hasChanged.items = true;
		end
		hasChanged[scanner] = true;
	end

	local scanInventory
	function scanInventory()
		local retry,removeItems = false,false;
		for slotIndex=1, 19 do
			local sharedSlotIndex = -(slotIndex/100);
			local id = tonumber((GetInventoryItemID("player",slotIndex)));
			if id then
				local link = GetInventoryItemLink("player",slotIndex);
				local d,dM = GetInventoryItemDurability(slotIndex);
				local diffStr = table.concat({link,d or 0,dm or 0},"^");
				addItem({
					bag=-1,
					slot=slotIndex,
					sharedSlot=sharedSlotIndex,
					id=id,
					link=link,
					durability = d or 0,
					durabilityMax = dM or 0,
					diff=diffStr,
					equip=true
				},"inv");
				if link:find("%[%]") then
					retry = true; -- Query heirloom item info looks like unstable. too often return invalid item links
				end
			elseif itemsBySlot[sharedSlotIndex] then
				-- no item in inventory slot
				removeItem(sharedSlotIndex,"inv");
			end
		end
		callbackHandler();
		if retry then
			-- retry on heirloom link bug
			C_Timer.After(1.2,scanInventory);
		end
	end

	local function scanBags()
		for _,bagIndex in ipairs(updateBags) do
			local numBagSlots = GetContainerNumSlots(bagIndex);
			local numFreeSlots = GetContainerNumFreeSlots(bagIndex);
			if numBagSlots~=numFreeSlots then -- do not scan empty bag ;-)
				--[[
				local isSoul = false; -- currently could not test. have no warlock on classic realms.
				if ns.client_version<2 then
					local _, _, _, _, _, itemClassID, itemSubClassID = GetItemInfoInstant(GetInventoryItemLink("player", bagIndex+19));
					if itemSubClassID==1 then -- soul pouch
						isSoul = true;
					end
				end
				--]]
				for slotIndex=1, numBagSlots do
					local sharedSlotIndex = bagIndex+(slotIndex/100);
					local _, count, _, _, _, _, link, _, _, id = GetContainerItemInfo(bagIndex,slotIndex);
					if id then
						local _, _, _, itemEquipLocation, _, itemClassID, itemSubClassID = GetItemInfoInstant(link); -- equipment in bags; merchant repair all function will be repair it too
						local d,dM = GetContainerItemDurability(bagIndex,slotIndex);
						local diffStr = table.concat({link,d or 0,dM or 0,count},"^");
						local isEquipment = false;
						if not (itemEquipLocation=="" or itemEquipLocation==(INVTYPE_TABARD or Enum.InventoryType.IndexTabardType) or itemEquipLocation==(INVTYPE_BODY or Enum.InventoryType.IndexBodyType)) then
							isEquipment = true; -- ignore shirts and tabards
						end
						local changed = addItem({
							bag=bagIndex,
							slot=slotIndex,
							sharedSlot=sharedSlotIndex,
							id=id,
							link=link,
							durability = d or 0,
							durabilityMax = dM or 0,
							diff=diffStr,
							equip=isEquipment,
							ammo=itemClassID==LE_ITEM_CLASS_PROJECTILE
						},"bags");
					elseif itemsBySlot[sharedSlotIndex] then
						removeItem(sharedSlotIndex,"bags");
					end
				end
			else
				-- bag is empty but previosly it had items
				for slotIndex=1, numBagSlots do
					local sharedSlotIndex = bagIndex+(slotIndex/100);
					if itemsBySlot[sharedSlotIndex] then
						removeItem(sharedSlotIndex,"bags");
					end
				end
			end
		end
		wipe(updateBags);
		callbackHandler();
	end

	local function afterItemUpgrade()
		-- TODO: get item id, or inv slot or bag slot for faster update
	end

	local firstBagUpdateDelay,inventoryEvents = true,{
		PLAYER_LOGIN = true,
		PLAYER_EQUIPMENT_CHANGED = true,
		UPDATE_INVENTORY_DURABILITY = true,
		ITEM_UPGRADE_MASTER_UPDATE = true
	};

	local function OnEvent(self,event,...)
		if event=="ADDON_LOADED" and (...)=="Blizzard_ItemUpgradeUI" then
			ItemUpgradeFrameUpgradeButton:HookScript("OnClick",afterItemUpgrade);
			hooksecurefunc(_G,"ItemUpgradeFrame_UpgradeClick",afterItemUpgrade);
			eventFrame:UnregisterEvent(event);
		elseif event=="BAG_UPDATE" and tonumber(...) and ... <= NUM_BAG_SLOTS then
			tinsert(updateBags,...);
		elseif event=="BAG_UPDATE_DELAYED" and #updateBags>0 then
			if firstBagUpdateDelay then
				firstBagUpdateDelay = nil;
				tinsert(updateBags,1,0); -- BAG_UPDATE does not fire argument1 = 0 (for backpack) on login
			end
			scanBags();
		elseif inventoryEvents[event] then
			scanInventory();
		end
	end
	eventFrame:SetScript("OnEvent",OnEvent);

	local function initBags()
		if IsEnabledBags then return end
		IsEnabledBags = true;

		-- bag events
		eventFrame:RegisterEvent("BAG_UPDATE");
		eventFrame:RegisterEvent("BAG_UPDATE_DELAYED");

		if ns.eventPlayerEnteredWorld then
			-- module registered after PLAYER_ENTERING_WORLD
			updateBags = {0,1,2,3,4};
			OnEvent(eventFrame,"BAG_UPDATE_DELAYED");
		end
	end

	local function initInventory()
		if IsEnabledInv then return end
		IsEnabledInv = true;

		-- inventory events
		eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
		eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY");

		if ns.client_version>2 then
			eventFrame:RegisterEvent("ITEM_UPGRADE_MASTER_UPDATE");
			if IsAddOnLoaded("Blizzard_ItemUpgradeUI") then
				OnEvent(eventFrame,"ADDON_LOADED","Blizzard_ItemUpgradeUI");
			else
				eventFrame:RegisterEvent("ADDON_LOADED");
			end
		end

		if ns.eventPlayerEnteredWorld then
			-- module registered after PLAYER_ENTERING_WORLD
			OnEvent(eventFrame,"PLAYER_EQUIPMENT_CHANGED");
		end
	end

	function ns.items.Init(initType)
		assert(initType,"Missing argument initType");
		if initType~="inv" then
			initBags();
		end
		if initType~="bags" then
			initInventory();
		end
	end

	function ns.items.RegisterCallback(modName,func,mode,id)
		mode = tostring(mode):lower();
		assert(type(modName)=="string" and ns.modules[modName],"argument #1 (modName) must be a string, got "..type(modName));
		assert(type(func)=="function","argument #2 (function) must be a function, got "..type(func));
		assert(type(callbacks[mode])=="table", "argument #3 must be 'any', 'inv', 'bags', 'item', 'equip' or 'prepare'.");
		if mode=="item" then
			assert(type(id)=="number","argument #4 must be number, got "..type(id));
			if callbacks.item[id]==nil then
				callbacks.item[id] = {};
			end
			callbacks.item[id][modName] = func;
		else
			callbacks[mode][modName] = func;
		end
		callbacks[mode.."Num"] = (callbacks[mode.."Num"] or 0) + 1;
		ns.items.Init(mode);
	end
end


-- -------------------------------------------------------------- --
-- UseContainerItem hook
-- -------------------------------------------------------------- --
do
	local callback = {};
	hooksecurefunc("UseContainerItem",function(bag,slot)
		if bag and slot then
			local itemId = tonumber((GetContainerItemLink(bag,slot) or ""):match("Hitem:([0-9]+)"));
			if itemid and callback[itemId] then
				for i,v in pairs(callback[itemId])do
					if type(v[1])=="function" then v[1]("UseContainerItem",itemId,v[2]); end
				end
			end
		end
	end);
	ns.UseContainerItemHook = {
		registerItemID = function(modName,itemId,callbackFunc,info)
			if callback[itemId]==nil then
				callback[itemId] = {};
			end
			callback[itemId][modName] = {callbackFunc,info};
		end
	};
end


-- --------------------- --
-- scanTooltip functions --
-- --------------------- --
do
	local QueueModeScanTT = CreateFrame("GameTooltip",addon.."ScanTooltip",UIParent,"GameTooltipTemplate");
	local InstantModeScanTT = CreateFrame("GameTooltip",addon.."ScanTooltip2",UIParent,"GameTooltipTemplate");
	local _ITEM_LEVEL = ITEM_LEVEL:gsub("%%d","(%%d*)");
	local _UPGRADES = ITEM_UPGRADE_TOOLTIP_FORMAT:gsub(CHAT_HEADER_SUFFIX.."%%d/%%d","");
	-- EMPTY_SOCKET_PRISMATIC and EMPTY_SOCKET_NO_COLOR are identical in some languages... Need only one of it.
	local EMPTY_SOCKETS = {"RED","YELLOW","META","HYDRAULIC","BLUE","PRISMATIC","COGWHEEL"};
	if EMPTY_SOCKET_PRISMATIC~=EMPTY_SOCKET_NO_COLOR then
		tinsert(EMPTY_SOCKETS,"NO_COLOR");
	end
	QueueModeScanTT:SetScale(0.0001);
	InstantModeScanTT:SetScale(0.0001);
	QueueModeScanTT:SetAlpha(0);
	InstantModeScanTT:SetAlpha(0);
	QueueModeScanTT:Hide();
	InstantModeScanTT:Hide();
	-- remove scripts from tooltip... prevents taint log spamming.
	for _,v in ipairs({"OnLoad","OnHide","OnTooltipAddMoney","OnTooltipSetDefaultAnchor","OnTooltipCleared"})do
		QueueModeScanTT:SetScript(v,nil);
		InstantModeScanTT:SetScript(v,nil);
	end

	ns.ScanTT = {};
	local queries = {};
	local ticker = nil;
	local duration = 0.05;
	local try = 0;

	local function GetLinkData(link)
		local _,_,_,link = link:match("|c(%x*)|H([^:]*):(%d+):(.+)|h%[([^%[%]]*)%]|h|r");
		link = {strsplit(HEADER_COLON,link or "")};
		for i=1, #link do
			link[i] = tonumber(link[i]) or 0;
		end
		return link;
	end

	local function collect(tt,Data)
		local data,_;
		if not Data then
			if #queries==0 then
				if(ticker)then
					ticker:Cancel();
					ticker=nil;
				end
				tt:Hide();
				return;
			end
			data = queries[1];
		else
			data = Data;
		end

		local success,num,regions = false,0;
		tt:SetOwner(UIParent,"ANCHOR_LEFT");

		if not data._type then
			data._type=data.type;
		end
		if data.try==nil then
			data.try=1;
		else
			data.try=data.try+1;
		end
		if data._type=="bag" or data._type=="bags" then
			if data.link==nil then
				data.link = GetContainerItemLink(data.bag,data.slot);
			end
			data.linkData = GetLinkData(data.link);
			data.itemName, data.itemLink, data.itemRarity, data.itemLevel, data.itemMinLevel, data.itemType, data.itemSubType, data.itemStackCount, data.itemEquipLoc, data.itemTexture, data.itemSellPrice = GetItemInfo(data.link);
			data.startTime, data.duration, data.isEnabled = GetContainerItemCooldown(data.bag,data.slot);
			data.hasCooldown, data.repairCost = tt:SetBagItem(data.bag,data.slot);
		elseif data._type=="inventory" or data._type=="inv" then
			if data.link==nil then
				data.link = GetInventoryItemLink("player",data.slot);
			end
			data.linkData = GetLinkData(data.link);
			_,data.hasCooldown, data.repairCost = tt:SetInventoryItem("player", data.slot); -- repair costs
		elseif data._type=="unit" then
			-- https://wow.gamepedia.com/API_UnitGUID
			data._type = "link";
			if data.unit=="Creature" or data.unit=="Pet" or data.unit=="GameObject" or data.unit=="Vehicle" then
				-- unit:<Creature|Pet|GameObject|Vehicle>-0-<server>-<instance>-<zone>-<id>-<spawn>
				data.link = "unit:"..data.unit.."-0-0-0-0-"..data.id.."-0";
			elseif data.unit=="Player" then
				-- unit:Player-<server>-<playerUniqueID>
			elseif data.unit=="Vignette" then
				-- unit:Vignette-0-<server>-<instance>-<zone>-0-<spawn>
			end
		elseif data._type=="item" then
			data._type="link";
			data.link=data.link or "item:"..data.id;
		elseif data._type=="quest" then
			data._type="link";
			data.link=data.link or "quest:"..data.id..HEADER_COLON..(data.level or 0);
		end

		if data._type=="link" and data.link then
			data.str = data.link;
			tt:SetHyperlink(data.link);
		end

		try = try + 1;
		if try>8 then try=0; end

		tt:Show();

		regions = {tt:GetRegions()};

		data.lines={};
		for _,v in ipairs(regions) do
			if (v~=nil) and (v:GetObjectType()=="FontString")then
				local str = (v:GetText() or ""):trim();
				if str:len()>0 then
					tinsert(data.lines,str);
				end
			end
		end

		if data._type=="inventory" or data._type=="inv" or data._type=="bag" or data._type=="bags" then
			for i=2, min(#data.lines,20) do
				local lvl = tonumber(data.lines[i]:match(_ITEM_LEVEL));
				if lvl then
					data.level=lvl;
				elseif data.lines[i]:find(_UPGRADES) then
					_,data.upgrades = strsplit(" ",data.lines[i]);
				elseif i>4 and data.setname==nil and data.lines[i]:find("%(%d*/%d*%)$") then
					data.setname = strsplit("(",data.lines[i]);
				else
					local socketCount,inLines = 0,{};
					-- detect sockets in tooltip
					for n=1, #EMPTY_SOCKETS do
						if data.lines[i]==_G["EMPTY_SOCKET_"..EMPTY_SOCKETS[n]] then
							socketCount=socketCount+1;
							tinsert(inLines,i);
						end
					end
					-- check sockets
					if socketCount>0 then
						data.gems = {};
						for i=2, 5 do
							data.gems[i-1]=data.linkData[i];
							if data.linkData[i]==0 then
								data.empty_gem=true;
							end
						end
					end
				end
			end
		end

		tt:Hide();

		if Data then
			return data;
		end

		if(#data.lines>0)then
			data.callback(data);
			tremove(queries,1);
		elseif data.try>5 then
			tremove(queries,1);
		end
	end
	--[[
		ns.ScanTT.query({
			type = "bag|link",
			calllback = [func],

			-- if type bag
			bag = <number>
			slot = <number>

			-- if type item
			id = <number>

			-- if type link
			link = <string>

			-- if type unit
			id = <number>
			unit = <creature|player|?>
		})
	--]]
	function ns.ScanTT.query(data,instant)
		if data.type=="bag" then
			assert(type(data.bag)=="number","bag must be a number, got "..type(data.bag));
			assert(type(data.slot)=="number","slot must be a number, got "..type(data.slot));
		elseif data.type=="item" or data.type=="quest" or data.type=="unit" then
			assert(type(data.id)=="number","id must be a number, got "..type(data.id));
		elseif data.type=="link" then
			assert(type(data.link)=="string","link must be a string, got "..type(data.link));
		elseif data.type=="unit" then
			assert(type(data.id)=="number","id must be a number, got "..type(data.id));
			assert(type(data.unit),"unit (type) must be a string, got "..type(data.unit));
		end
		if instant then
			return collect(InstantModeScanTT,data);
		else
			assert(type(data.callback)=="function","callback must be a function. got "..type(data.callback));
			tinsert(queries,data);
			if ticker==nil then
				ticker = C_Timer.NewTicker(duration,function() collect(QueueModeScanTT); end);
			end
		end
	end
end


-- ----------------------------------------------------- --
-- goldColor function to display amount of gold          --
-- in colored strings or with coin textures depending on --
-- a per module and a addon wide toggle.                 --
-- ----------------------------------------------------- --
function ns.GetCoinColorOrTextureString(modName,amount,opts)
	local zz,tex="%02d","|TInterface\\MoneyFrame\\UI-%sIcon:14:14:2:0|t";
	amount = tonumber(amount) or 0;
	opts = opts or {};
	opts.sep = opts.sep or " ";
	opts.hideMoney = opts.hideMoney or tonumber(ns.profile.GeneralOptions.goldHide);
	opts.color = (opts.color or ns.profile.GeneralOptions.goldColor):lower();
	if not opts.coins then
		opts.coins = ns.profile.GeneralOptions.goldCoins;
	end

	if opts.hideMoney==1 then
		amount = floor(amount/100)*100;
		opts.hideCopper = true;
	elseif opts.hideMoney==2 then
		amount = floor(amount/10000)*10000;
		opts.hideSilver = true;
		opts.hideCopper = true;
	end

	local colors = (opts.color=="white" and {"white","white","white"}) or (opts.color=="color" and {"copper","silver","gold"}) or false;
	local gold, silver, copper, t = floor(amount/10000), mod(floor(amount/100),100), mod(floor(amount),100), {};

	if opts.hideMoney==3 then
		opts.hideSilver = (silver==0);
		opts.hideCopper = (copper==0);
	end

	if gold>0 then
		local str = ns.FormatLargeNumber(modName,gold,opts.inTooltip);
		tinsert(t, (colors and ns.LC.color(colors[3],str) or str) .. (opts.coins and tex:format("Gold") or "") );
	end

	if (gold==0 and silver>0) or (silver>0 and (not opts.hideSilver)) then
		local str = gold>0 and zz:format(silver) or silver;
		tinsert(t, (colors and ns.LC.color(colors[2],str) or str) .. (opts.coins and tex:format("Silver") or "") );
	end

	if amount<100 or (not opts.hideCopper) then
		local str = (silver>0 or gold>0) and zz:format(copper) or copper;
		tinsert(t, (colors and ns.LC.color(colors[1],str) or str) .. (opts.coins and tex:format("Copper") or "") );
	end

	return tconcat(t,opts.sep);
end


-- ----------------------------------------------------- --
-- screen capture mode - string replacement function     --
-- ----------------------------------------------------- --
function ns.scm(str,all,str2)
	if str==nil then return "" end
	str2,str = (str2 or "*"),tostring(str);
	local length = str:len();
	if length>0 and ns.profile.GeneralOptions.scm==true then
		str = all and str2:rep(length) or strsub(str,1,1)..str2:rep(length-1);
	end
	return str;
end


-- ------------------------ --
-- Hide blizzard elements   --
-- ------------------------ --
do
	local hideFrames = CreateFrame("Frame",addon.."_HideFrames",UIParent);
	hideFrames.origParent = {};
	hideFrames:Hide();

	function ns.hideFrames(frameName,hideIt)
		local frame = _G[frameName];
		if frame and hideIt then
			local parent = frame:GetParent();
			if parent==nil or parent==hideFrames then
				return false
			end
			hideFrames.origParent[frameName] = parent;
			frame:SetParent(hideFrames);
		elseif frame and hideFrames.origParent[frameName] then
			frame:SetParent(hideFrames.origParent[frameName]);
			hideFrames.origParent[frameName] = nil;
		end
	end
end


-- ---------------- --
-- EasyMenu wrapper --
-- ---------------- --
do
	local LDDM = LibStub("LibDropDownMenu");
	ns.EasyMenu = LDDM.Create_DropDownMenu(addon.."_LibDropDownMenu",UIParent);
	ns.EasyMenu.menu, ns.EasyMenu.controlGroups,ns.EasyMenu.IsPrevSeparator = {},{},false;
	local grpOrder,pat = {"broker","tooltip","misc","ClickOpts"},"%06d%s";

	local cvarTypeFunc = {
		bool = function(D)
			if (type(D.cvar)=="table") then
				--?
			elseif (type(D.cvar)=="string") then
				function D.checked() return (GetCVar(D.cvar)=="1") end;
				function D.func() SetCVar(D.cvar,GetCVar(D.cvar)=="1" and "0" or "1",D.cvarEvent); end;
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
				function d.checked() return (ns.profile[d.beModName][d.beKeyName]) end;
				function d.func() ns.profile[d.beModName][d.beKeyName] = not ns.profile[d.beModName][d.beKeyName]; end;
			else
				function d.checked() return (ns.profile.GeneralOptions[d.beKeyName]) end;
				function d.func() ns.profile.GeneralOptions[d.beKeyName] = not ns.profile.GeneralOptions[d.beKeyName]; end;
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

	local function pairsByAceOptions(t)
		local a,f = {},"%06d;%s";
		for k,v in pairs(t) do
			tinsert(a,f:format(v.order or 100,k));
		end
		tsort(a);
		local i = 0;
		local function iter()
			i=i+1;
			if a[i]==nil then
				return nil;
			end
			local _,k = strsplit(";",a[i],2);
			return k, t[k];
		end
		return iter;
	end

	local function pairsByOptionGroup(t)
		local a = {}
		for n in pairs(t) do
			for i,v in ipairs(grpOrder)do
				if n:find("^"..v) then
					n = i.."."..n;
					break;
				end
			end
			tinsert(a, n);
		end
		tsort(a);
		local i,_ = 0;
		local function iter()
			i = i + 1
			if a[i] == nil then
				return nil
			end
			_,a[i] = strsplit(".",a[i],2);
			return a[i], t[a[i]];
		end
		return iter
	end

	local function LibCloseDropDownMenus()
		LDDM.CloseDropDownMenus();
		CloseMenus();
	end

	function ns.EasyMenu:AddEntry(D,P)
		local entry= {};

		if (type(D)=="table") and (#D>0) then -- numeric table = multible entries
			self.IsPrevSeparator = false;
			for i,v in ipairs(D) do
				self:AddEntry(v,parent);
			end
			return;

		elseif (D.childs) then -- child elements
			self.IsPrevSeparator = false;
			local parent = self:AddEntry({ label=D.label, arrow=true, disabled=D.disabled },P);
			for i,v in ipairs(D.childs) do
				self:AddEntry(v,parent);
			end
			return;

		elseif (D.groupName) and (D.optionGroup) then -- similar to childs but with group control
			self.IsPrevSeparator = false;
			if (self.controlGroups[D.groupName]==nil) then
				self.controlGroups[D.groupName] = {};
			else
				wipe(self.controlGroups[D.groupName])
			end
			local parent = self:AddEntry({ label=D.label, arrow=true, disabled=D.disabled },P);
			parent.controlGroup=self.controlGroups[D.groupName];
			for i,v in ipairs(D.optionGroup) do
				tinsert(self.controlGroups[D.groupName],self:AddEntry(v,parent));
			end
			return;

		elseif (D.separator) then -- separator line (decoration)
			if self.IsPrevSeparator then
				return;
			end
			self.IsPrevSeparator = true;
			entry = { text = "", dist = 0, isTitle = true, notCheckable = true, isNotRadio = true, sUninteractable = true, iconOnly = true, icon = "Interface\\Common\\UI-TooltipDivider-Transparent", tCoordLeft = 0, tCoordRight = 1, tCoordTop = 0, tCoordBottom = 1, tFitDropDownSizeX = true, tSizeX = 0, tSizeY = 8 };
			entry.iconInfo = entry;

		else
			self.IsPrevSeparator = false;
			entry.isTitle          = D.title     or false;
			entry.hasArrow         = D.arrow     or false;
			entry.disabled         = D.disabled  or false;
			entry.notClickable     = not not D.noclick;
			entry.isNotRadio       = not D.radio;
			entry.keepShownOnClick = true;
			entry.noClickSound     = true;

			if (D.keepShown==false) then
				entry.keepShownOnClick = false;
			end

			if (D.cvarType) and (D.cvar) and (type(D.cvarType)=="string") and (cvarTypeFunc[D.cvarType]) then
				cvarTypeFunc[D.cvarType](D);
			end

			if (D.beType) and (D.beKeyName) and (type(D.beType)=="string") and (beTypeFunc[D.beType]) then
				beTypeFunc[D.beType](D);
			end

			if (D.checked~=nil) then
				entry.checked = D.checked;
				if (entry.keepShownOnClick==nil) then
					entry.keepShownOnClick = false;
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
				function entry.func(...)
					D.func(...)
					if (type(D.event)=="function") then
						D.event();
					end
					if (P) and (not entry.keepShownOnClick) then
						LibCloseDropDownMenus();
					end
				end;
			end

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

	function ns.EasyMenu:AddConfig(modName,noTitle)
		local noFirstSep,options,separator = true,ns.getModOptionTable(modName);
		if noTitle==nil then
			noTitle = false;
		elseif noTitle==true then
			separator=true
		end
		if options then
			for _,optGrp in pairsByOptionGroup(options)do
				if optGrp and type(optGrp.args)=="table" then
					-- add group header
					if separator then
						self:AddEntry({ separator=true });
					else
						if not noTitle then
							self:AddEntry({ label = L[modName], title = true });
							self:AddEntry({ separator=true });
							noTitle=false;
						end
						separator=true
					end
					self:AddEntry({ label=optGrp.name, title=true });

					-- replace shared option entries
					for key, value in pairs(optGrp)do
						if ns.sharedOptions[key] then
							local order = tonumber(value);
							optGrp[key] = CopyTable(ns.sharedOptions[key]);
							optGrp[key].order = order;
						end
					end

					-- sort group table
					for key, value in pairsByAceOptions(optGrp.args)do
						local hide = (value.hidden==true) or (value.disabled==true) or false;
						if not hide and type(value.hidden)=="function" then
							hide = value.hidden();
						end
						if not hide and type(value.disabled)=="function" then
							hide = value.disabled();
						end

						if not hide then
							if value.type=="separator" then
								self:AddEntry({ separator=true });
							elseif value.type=="header" then
								self:AddEntry({ separator=true });
								self:AddEntry({ label=value.name, title=true });
							elseif value.type=="toggle" then
								local tooltip = nil;
								if value.desc then
									tooltip = {value.name, value.desc};
									if type(tooltip[2])=="function" then
										tooltip[2] = tooltip[2]();
									end
								end
								self:AddEntry({
									label = value.name:gsub("|n"," "),
									checked = function()
										if key=="minimap" then
											return not ns.profile[modName][key].hide;
										end
										return ns.profile[modName][key];
									end,
									func = function()
										local info = {modName,"",key};
										if key=="minimap" then
											ns.option(info,ns.profile[modName].minimap.hide);
										else
											ns.option(info,not ns.profile[modName][key]);
										end
									end,
									tooltip = tooltip,
								});
							elseif value.type=="select" then
								local tooltip = {value.name, value.desc};
								if type(tooltip[2])=="function" then
									tooltip[2] = tooltip[2]();
								end
								local p = self:AddEntry({
									label = value.name,
									tooltip = tooltip,
									arrow = true
								});
								local values = value.values;
								if type(values)=="function" then
									values = values({modName,"",key});
								end
								for valKey,valLabel in ns.pairsByKeys(values) do
									self:AddEntry({
										label = valLabel,
										radio = valKey,
										keepShown = false,
										checked = function()
											return (ns.profile[modName][key]==valKey);
										end,
										func = function(self)
											ns.option({modName,"",key},valKey);
											self:GetParent():Hide();
										end
									},p);
								end
							elseif value.type=="range" then
							end
						end
					end

				end
			end
		end
	end

	function ns.EasyMenu:Refresh(level)
		if level then
			LDDM.UIDropDownMenu_Refresh(self,nil,level);
		end
		LDDM.UIDropDownMenu_RefreshAll(self);
	end

	function ns.EasyMenu:InitializeMenu()
		wipe(self.menu);
	end

	function ns.EasyMenu:ShowMenu(parent, parentX, parentY, initializeFunction)
		local anchor, x, y = "cursor"

		if (parent) then
			anchor = parent;
			x = parentX or 0;
			y = parentY or 0;
		end

		if openTooltip then
			ns.hideTooltip(openTooltip,openTooltip.key,true,false,true);
		end

		self:AddEntry({separator=true}, pList);
		self:AddEntry({label=L["Close menu"], func=LibCloseDropDownMenus});

		LDDM.EasyMenu(self.menu, self,anchor, x, y, "MENU");
	end
end


-- ----------------------- --
-- DurationOrExpireDate    --
-- ----------------------- --
function ns.DurationOrExpireDate(timeLeft,lastTime,durationTitle,expireTitle)
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
	ns.ClickOpts = {prefix="ClickOpt:"};
	local shared,values = {},{
		["__NONE"]     = ADDON_DISABLED,
		["_CLICK"]     = L["MouseBtn"],
		["_LEFT"]      = L["MouseBtnL"],
		["_RIGHT"]     = L["MouseBtnR"],
		["ALTCLICK"]   = L["ModKeyA"].."+"..L["MouseBtn"],
		["ALTLEFT"]    = L["ModKeyA"].."+"..L["MouseBtnL"],
		["ALTRIGHT"]   = L["ModKeyA"].."+"..L["MouseBtnR"],
		["SHIFTCLICK"] = L["ModKeyS"].."+"..L["MouseBtn"],
		["SHIFTLEFT"]  = L["ModKeyS"].."+"..L["MouseBtnL"],
		["SHIFTRIGHT"] = L["ModKeyS"].."+"..L["MouseBtnR"],
		["CTRLCLICK"]  = L["ModKeyC"].."+"..L["MouseBtn"],
		["CTRLLEFT"]   = L["ModKeyC"].."+"..L["MouseBtnL"],
		["CTRLRIGHT"]  = L["ModKeyC"].."+"..L["MouseBtnR"],
	};
	function shared.OptionMenu(self,button,modName)
		if (openTooltip~=nil) and (openTooltip:IsShown()) then ns.hideTooltip(openTooltip); end
		ns.EasyMenu:InitializeMenu();
		ns.EasyMenu:AddConfig(modName);
		ns.EasyMenu:ShowMenu(self);
	end
	local sharedClickOptions = {
		OptionMenu  = {"ClickOptMenu","shared","OptionMenu"}, -- L["ClickOptMenu"]
		OptionMenuCustom = {"ClickOptMenu","module","OptionMenu"},
		OptionPanel = {"ClickOptPanel","namespace","ToggleBlizzOptionPanel"}, -- L["ClickOptPanel"]
		CharacterInfo = {CHARACTER_INFO,"call",{"ToggleCharacter","PaperDollFrame"}},
		GarrisonReport = {GARRISON_LANDING_PAGE_TITLE,"call","GarrisonLandingPage_Toggle"}, --"ClickOptGarrReport"
		Guild = {GUILD,"call","ToggleGuildFrame"}, -- "ClickOptGuild"
		Currency = {CURRENCY,"call",{"ToggleCharacter","TokenFrame"}}, -- "ClickOptCurrency"
		QuestLog = {QUEST_LOG,"call","ToggleQuestLog"} -- "ClickOptQuestLog"
	};
	local iLabel,iSrc,iFnc,iPrefix = 1,2,3,4;

	function ns.ClickOpts.func(self,button,modName)
		local mod = ns.modules[modName];
		if not (mod and mod.onclick) then return; end

		-- click(plan)A = combine modifier if pressed with named button (left,right)
		-- click(panl)B = combine modifier if pressed with left or right mouse button without expliced check.
		local clickA,clickB,act,actName="","";

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

		if (mod.onclick[clickA]) then
			actName = mod.onclick[clickA];
			act = mod.clickOptions[actName];
		elseif (mod.onclick[clickB]) then
			actName = mod.onclick[clickB];
			act = mod.clickOptions[actName];
		end

		if act then
			local fnc
			if act[iSrc]=="direct" then
				fnc = act[iFnc];
			elseif act[iSrc]=="module" then
				fnc = mod[act[iFnc]];
			elseif act[iSrc]=="namespace" then
				fnc = ns[act[iFnc]];
			elseif act[iSrc]=="shared" then
				fnc = shared[act[iFnc]];
			elseif act[iSrc]=="call" then
				if type(act[iFnc])=="table" then
					securecall(unpack(act[iFnc]));
				else
					securecall(act[iFnc]);
				end
				return;
			end
			if fnc then
				fnc(self,button,modName,actName);
			end
		end
	end

	function ns.ClickOpts.update(modName) -- executed on event BE_UPDATE_CFG from active modules
		-- name, desc, default, func
		local mod = ns.modules[modName];
		if not (mod and type(mod.clickOptions)=="table") then return end
		local hasOptions = false;
		mod.onclick = {};
		mod.clickHints = {};

		local order = mod.clickOptionsOrder or {};
		if #order==0 then
			for actName, actData in ns.pairsByKeys(mod.clickOptions) do
				if actData then
					tinsert(order,actName);
				end
			end
		end

		for _, actName in ipairs(order)do
			local act = mod.clickOptions[actName];
			local cfgKey = ns.ClickOpts.prefix..actName;
			if mod.clickOptionsRename and mod.clickOptionsRename[cfgKey] then
				local altKey = mod.clickOptionsRename[cfgKey];
				if ns.profile[modName](altKey)~=nil then
					ns.profile[modName][cfgKey] = ns.profile[modName][altKey];
					ns.profile[modName][altKey] = nil;
				end
			end
			local key = ns.profile[modName][cfgKey];
			if key and key~="__NONE" then
				local fSrc,func = act[iSrc];
				if fSrc=="direct" then
					func = act[iFnc];
				elseif fSrc=="module" then
					func = mod[act[iFnc]];
				elseif fSrc=="namespace" then
					func = ns[act[iFnc]];
				elseif fSrc=="shared" then
					func = shared[act[iFnc]];
				elseif fSrc=="call" then
					func = _G[type(act[iFnc])=="table" and act[iFnc][1] or act[iFnc]];
				end
				if func and type(func)=="function" then
					mod.onclick[key] = actName;
					tinsert(mod.clickHints,ns.LC.color("copper",values[key]).." || "..ns.LC.color("green",L[act[iLabel]]));
					hasOptions = true;
				end
			end
		end
		return hasOptions;
	end

	function ns.ClickOpts.createOptions(modName,modOptions) -- executed by ns.Options_AddModuleOptions()
		local mod = ns.modules[modName];
		if not (mod and type(mod.clickOptions)=="table") then return end

		-- generate option panel entries
		for cfgKey,clickOpts in ns.pairsByKeys(mod.clickOptions) do
			if modOptions.ClickOpts==nil then
				modOptions.ClickOpts = {};
			end
			if type(clickOpts)=="string" and sharedClickOptions[clickOpts] then
				-- copy shared entry
				mod.clickOptions[cfgKey] = sharedClickOptions[clickOpts];
				clickOpts = mod.clickOptions[cfgKey];
			end
			if clickOpts then
				local optKey = ns.ClickOpts.prefix..cfgKey;
				-- ace option table entry
				modOptions.ClickOpts[optKey] = {
					type	= "select",
					name	= L[clickOpts[iLabel]],
					desc	= L["ClickOptDesc"].." "..L[clickOpts[iLabel]],
					values	= values
				};
			end
		end
	end

	function ns.ClickOpts.ttAddHints(tt,name,ttColumns,entriesPerLine)
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
				v = tconcat(v," - ");
				if (type(tt.SetCell)=="function") then
					local line = tt:AddLine();
					tt:SetCell(line,1,v,nil,"LEFT",ttColumns or 0);
				else
					tt:AddLine(v);
				end
			end
		end
	end

	function ns.ClickOpts.getShared(name)
		return sharedClickOptions[name];
	end

	function ns.ClickOpts.addDefaults(module,key,value)
		assert(module);
		local tKey = type(key);
		if tKey=="table" then
			for k,v in pairs(key) do
				ns.ClickOpts.addDefaults(module,k,v);
			end
		elseif tKey=="string" then
			module.config_defaults[ns.ClickOpts.prefix..key] = value;
		end
	end
end


-- --------------------------------------- --
-- shared data for questlog & world quests --
-- --------------------------------------- --
do
	if ns.client_version>=9 then
		-- TODO: shadowlands update -- LE_QUEST_TAG_TYPE_ vs. Enum.QuestTag
		local Enum = Enum
		if not (Enum and Enum.QuestTag) then
			if not Enum.QuestTag then
				Enum.QuestTag = {}
			end
			Enum.QuestTag.Group     = LE_QUEST_TAG_TYPE_GROUP     or QUEST_TAG_GROUP     or 1 -- "grp"
			Enum.QuestTag.PvP       = LE_QUEST_TAG_TYPE_PVP       or QUEST_TAG_PVP       or 41 -- "pvp"
			Enum.QuestTag.Dungeon   = LE_QUEST_TAG_TYPE_DUNGEON   or QUEST_TAG_DUNGEON   or 81 -- "d"
			Enum.QuestTag.Heroic    = LE_QUEST_TAG_TYPE_HEROIC    or QUEST_TAG_HEROIC    or 85 -- "hc" -- missing in bfa
			Enum.QuestTag.Raid      = LE_QUEST_TAG_TYPE_RAID      or QUEST_TAG_RAID      or 63 -- "r"
			Enum.QuestTag.Raid10    = LE_QUEST_TAG_TYPE_RAID10    or QUEST_TAG_RAID10    or 88 -- "r10"  -- missing in bfa
			Enum.QuestTag.Raid25    = LE_QUEST_TAG_TYPE_RAID25    or QUEST_TAG_RAID25    or 89 -- "r25" -- missing in bfa
			Enum.QuestTag.Scenario  = LE_QUEST_TAG_TYPE_SCENARIO  or QUEST_TAG_SCENARIO  or 98 -- "s"  -- missing in bfa
			Enum.QuestTag.Account   = LE_QUEST_TAG_TYPE_ACCOUNT   or QUEST_TAG_ACCOUNT   or 102 -- "a"  -- missing in bfa
			Enum.QuestTag.Legendary = LE_QUEST_TAG_TYPE_LEGENDARY or QUEST_TAG_LEGENDARY or 83 -- "leg"  -- missing in bfa
		end
		if Enum.QuestTag.Pvp then -- pre shadowlands
			Enum.QuestTag.PvP = Enum.QuestTag.Pvp;
		end
		ns.questTags = {
			[Enum.QuestTag.Group]     = L["QuestTagGRP"],
			[Enum.QuestTag.PvP or Enum.QuestTag.Pvp]       = {L["QuestTagPVP"],"violet"},
			[Enum.QuestTag.Dungeon]   = L["QuestTagND"],
			[Enum.QuestTag.Heroic]    = L["QuestTagHD"],
			[Enum.QuestTag.Raid]      = L["QuestTagR"],
			[Enum.QuestTag.Raid10]    = L["QuestTagR"]..10,
			[Enum.QuestTag.Raid25]    = L["QuestTagR"]..25,
			[Enum.QuestTag.Scenario]  = L["QuestTagS"],
			[Enum.QuestTag.Account]   = L["QuestTagACC"],
			[Enum.QuestTag.Legendary] = {L["QuestTagLEG"],"orange"},
			TRADE_SKILLS              = {L["QuestTagTS"],"green"},
			WORLD_QUESTS              = {L["QuestTagWQ"],"yellow"},
			DUNGEON_MYTHIC            = {L["QuestTagMD"],"ltred"}
		};
		ns.questTagsLong = {
			[Enum.QuestTag.Group]     = GROUP,
			[Enum.QuestTag.PvP or Enum.QuestTag.Pvp]       = {PVP,"violet"},
			[Enum.QuestTag.Dungeon]   = LFG_TYPE_DUNGEON,
			[Enum.QuestTag.Heroic]    = LFG_TYPE_HEROIC_DUNGEON,
			[Enum.QuestTag.Raid]      = LFG_TYPE_RAID,
			[Enum.QuestTag.Raid10]    = LFG_TYPE_RAID.." (10)",
			[Enum.QuestTag.Raid25]    = LFG_TYPE_RAID.." (25)",
			[Enum.QuestTag.Scenario]  = TRACKER_HEADER_SCENARIO,
			[Enum.QuestTag.Account]   = ITEM_BIND_TO_ACCOUNT,
			[Enum.QuestTag.Legendary] = TRACKER_HEADER_CAMPAIGN_QUESTS,
			TRADE_SKILLS              = {TRADE_SKILLS,"green"},
			WORLD_QUESTS              = {WORLD_QUEST_BANNER,"yellow"},
			DUNGEON_MYTHIC            = {LFG_TYPE_DUNGEON.." ("..PLAYER_DIFFICULTY6..")","ltred"}
		}
	else
		local QUEST_TAG_GROUP     = LE_QUEST_TAG_TYPE_GROUP     or QUEST_TAG_GROUP     or "grp" -- missing in bfa
		local QUEST_TAG_PVP       = LE_QUEST_TAG_TYPE_PVP       or QUEST_TAG_PVP       or "pvp"
		local QUEST_TAG_DUNGEON   = LE_QUEST_TAG_TYPE_DUNGEON   or QUEST_TAG_DUNGEON   or "d"
		local QUEST_TAG_HEROIC    = LE_QUEST_TAG_TYPE_HEROIC    or QUEST_TAG_HEROIC    or "hc" -- missing in bfa
		local QUEST_TAG_RAID      = LE_QUEST_TAG_TYPE_RAID      or QUEST_TAG_RAID      or "r"
		local QUEST_TAG_RAID10    = LE_QUEST_TAG_TYPE_RAID10    or QUEST_TAG_RAID10    or "r10"  -- missing in bfa
		local QUEST_TAG_RAID25    = LE_QUEST_TAG_TYPE_RAID25    or QUEST_TAG_RAID25    or "r25" -- missing in bfa
		local QUEST_TAG_SCENARIO  = LE_QUEST_TAG_TYPE_SCENARIO  or QUEST_TAG_SCENARIO  or "s"  -- missing in bfa
		local QUEST_TAG_ACCOUNT   = LE_QUEST_TAG_TYPE_ACCOUNT   or QUEST_TAG_ACCOUNT   or "a"  -- missing in bfa
		local QUEST_TAG_LEGENDARY = LE_QUEST_TAG_TYPE_LEGENDARY or QUEST_TAG_LEGENDARY or "leg"  -- missing in bfa

		ns.questTags = {
			[QUEST_TAG_GROUP]     = L["QuestTagGRP"],
			[QUEST_TAG_PVP]       = {L["QuestTagPVP"],"violet"},
			[QUEST_TAG_DUNGEON]   = L["QuestTagND"],
			[QUEST_TAG_HEROIC]    = L["QuestTagHD"],
			[QUEST_TAG_RAID]      = L["QuestTagR"],
			[QUEST_TAG_RAID10]    = L["QuestTagR"]..10,
			[QUEST_TAG_RAID25]    = L["QuestTagR"]..25,
			[QUEST_TAG_SCENARIO]  = L["QuestTagS"],
			[QUEST_TAG_ACCOUNT]   = L["QuestTagACC"],
			[QUEST_TAG_LEGENDARY] = {L["QuestTagLEG"],"orange"},
			TRADE_SKILLS          = {L["QuestTagTS"],"green"},
			WORLD_QUESTS          = {L["QuestTagWQ"],"yellow"},
			DUNGEON_MYTHIC        = {L["QuestTagMD"],"ltred"}
		};
	end
end


-- -----------------
-- text bar
-- ----------------
-- num, {<max>,<cur>[,<rest>]},{<max>,<cur>[,<rest>]}
function ns.textBar(num,values,colors,Char)
	local iMax,iMin,iRest = 1,2,3;
	values[iRest] = (values[iRest] and values[iRest]>0) and values[iRest] or 0;
	if values[iMax]==1 then
		values[iMax],values[iMin],values[iRest] = values[iMax]*100,values[iMin]*100,values[iRest]*100;
	end
	local Char,resting,ppc,earned,tonextlvl = Char or "=",0;
	ppc = values[iMax]/num; -- percent per character
	earned = ns.round(values[iMin]/ppc); -- number of characters of earned experience
	if values[iMin]<100 then
		resting = ns.round(values[iRest]/ppc); -- number of characters of resting bonus
	end
	tonextlvl = num-(earned+resting); -- number of characters of open experience to the next level
	return ns.LC.color(colors[iMin]  or "white",Char:rep(earned))
		.. (resting>0 and ns.LC.color(colors[iRest] or "white",Char:rep(resting)) or "")
		.. (tonextlvl>0 and ns.LC.color(colors[iMax] or "white",Char:rep(tonextlvl)) or "");
end



-- -------------------------------
-- Retail / Classic compatibility
-- -------------------------------

function ns.C_CurrencyInfo_GetCurrencyInfo(currency)
	local info
	if GetCurrencyInfo then
		local name, currentAmount, texture, earnedThisWeek, weeklyMax, totalMax, isDiscovered, rarity = GetCurrencyInfo(currency); -- classic and bfa
		if name then
			info = {
				-- from GetCurrencyInfo
				name = name,
				quantity = currentAmount,
				iconFileID = texture,
				quantityEarnedThisWeek = earnedThisWeek,
				maxWeeklyQuantity = weeklyMax,
				maxQuantity = totalMax,
				discovered = isDiscovered,
				quality = rarity,
				-- ??
				-- canEarnPerWeek
				-- isHeaderExpanded
				-- isTradeable
				-- isHeader
				-- isTypeUnused
				-- isShowInBackpack
			};
		end
	elseif C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
		info = C_CurrencyInfo.GetCurrencyInfo(currency); -- added with shadowlands
	end
	return info
end

function ns.C_CurrencyInfo_GetCurrencyListInfo(index)
	-- GetCurrencyListInfo
	local info
	if GetCurrencyListInfo then
		local name, isHeader, isExpanded, isUnused, isWatched, count, icon, maximum, hasWeeklyLimit, currentWeeklyAmount, unknown, itemID = GetCurrencyListInfo(index)
		local _, _, _, earnedThisWeek, weeklyMax, _, isDiscovered, rarity = GetCurrencyInfo(itemID);
		info = {
			canEarnPerWeek = earnedThisWeek,
			quantityEarnedThisWeek = currentWeeklyAmount,
			isHeaderExpanded = isExpanded,
			--isTradeable = ,
			maxQuantity = maximum,
			maxWeeklyQuantity = weeklyMax,
			isHeader = isHeader,
			name = name,
			isTypeUnused = isUnused,
			--isShowInBackpack = ,
			discovered = isDiscovered,
			quantity = count,
			quality = rarity,
		}
	elseif C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListInfo then
		info = C_CurrencyInfo.GetCurrencyListInfo(index); -- added with shadowlands
		--/run XYDB.GetCurrencyListInfo = C_CurrencyInfo.GetCurrencyListInfo(1)
	end
	return info;
end

function ns.C_QuestLog_GetInfo(questLogIndex)
	local info
	if GetQuestLogTitle then
		local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory, isHidden, isScaling  = GetQuestLogTitle(questLogIndex);
		info = {
			--difficultyLevel = 0,
			hasLocalPOI = hasLocalPOI,
			--isAutoComplete = false,
			--isBounty = false,
			isCollapsed = isCollapsed,
			isHeader = isHeader,
			isHidden = isHidden,
			isOnMap = isOnMap,
			isScaling = isScaling,
			isStory = isStory,
			isTask = isTask,
			level = level,
			--overridesSortOrder = false,
			questID = questID,
			questLogIndex = questLogIndex,
			--readyForTranslation = false,
			startEvent = startEvent,
			suggestedGroup = suggestedGroup,
			title = title,
			--
			frequency = frequency,
			isComplete = isComplete,
		}
	elseif C_QuestLog.GetInfo then
		info = C_QuestLog.GetInfo(questLogIndex);
		info.isComplete = C_QuestLog.IsComplete(info.questID);
		-- frequency?
		-- isComplete?
	end
	return info;
end

function ns.C_QuestLog_GetQuestTagInfo(questID)
	local info
	if GetQuestTagInfo then
		local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(questID);
		info = {
			tagID = tagID,
			tagName = tagName,

			-- not found in returned table from C_QuestLog.GetQuestTagInfo
			worldQuestType = worldQuestType,
			rarity = rarity,
			isElite = isElite,
			tradeskillLineIndex = tradeskillLineIndex
		};
	elseif C_QuestLog.GetQuestTagInfo then
		info = C_QuestLog.GetQuestTagInfo(questID)
	end
	return info;
end

function ns.IsQuestWatched(questLogIndex)
	if IsQuestWatched then
		return IsQuestWatched(questLogIndex);
	elseif C_QuestLog.GetQuestWatchType then
		local info = C_QuestLog.GetInfo(questLogIndex);
		return C_QuestLog.GetQuestWatchType(info.questID) ~= nil;
	end
end

function ns.GetQuestLogPushable(questLogIndex)
	if GetQuestLogPushable then
		return GetQuestLogPushable(questLogIndex);
	elseif C_QuestLog.IsPushableQuest then
		local info = C_QuestLog.GetInfo(questLogIndex);
		return C_QuestLog.IsPushableQuest(info.questID);
	end
end

function ns.GetTalentTierLevel(tier)
	if CLASS_TALENT_LEVELS then
		return (CLASS_TALENT_LEVELS[ns.player.class] or CLASS_TALENT_LEVELS.DEFAULT)[tier];
	elseif GetTalentTierInfo then
		local tierAvailable, selectedTalent, tierUnlockLevel = GetTalentTierInfo(tier, 1, false, "player");
		return tierUnlockLevel
	end
end
