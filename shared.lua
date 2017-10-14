
-- ====================================== --
-- Shared Functions for Broker_Everything --
-- ====================================== --
local addon, ns = ...;
local L,_ = ns.L;
ns.build = tonumber(gsub(({GetBuildInfo()})[1],"[|.]","")..({GetBuildInfo()})[2]);
ns.icon_fallback = 134400; -- interface\\icons\\INV_MISC_QUESTIONMARK;

ns.LDB = LibStub("LibDataBroker-1.1");
ns.LQT = LibStub("LibQTip-1.0");
ns.LDBI = LibStub("LibDBIcon-1.0");
ns.LSM = LibStub("LibSharedMedia-3.0");
ns.LT = LibStub("LibTime-1.0");
ns.LC = LibStub("LibColors-1.0");
ns.LDDM = LibStub("LibDropDownMenu");
ns.LRI = LibStub("LibRealmInfo");


-- broker_everything colors
ns.LC.colorset({
	["ltyellow"]	= "fff569",
	["dkyellow"]	= "ffcc00",

	["ltorange"]	= "ff9d6a",
	["dkorange"]	= "905d0a",

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
--- misc shared data                    ---
  ---------------------------------------
ns.realm = GetRealmName();
ns.realm_short = ns.realm:gsub(" ",""):gsub("%-","");
ns.media = "Interface\\AddOns\\"..addon.."\\media\\";
ns.locale = GetLocale();
ns.ui = {size={UIParent:GetSize()},center={UIParent:GetCenter()}};


  ---------------------------------------
--- player and twinks dependent data    ---
  ---------------------------------------
function ns.stripRealm(name)
	return name:gsub(" ",""):gsub("%-",""):gsub("'","");
end
ns.player = {
	name = UnitName("player"),
	female = UnitSex("player")==3,
};
ns.player.name_realm = ns.player.name.."-"..ns.realm;
ns.player.name_realm_short = ns.stripRealm(ns.player.name_realm);
_, ns.player.class,ns.player.classId = UnitClass("player");
ns.player.faction,ns.player.factionL  = UnitFactionGroup("player");
L[ns.player.faction] = ns.player.factionL;
ns.player.classLocale = ns.player.female and _G.LOCALIZED_CLASS_NAMES_FEMALE[ns.player.class] or _G.LOCALIZED_CLASS_NAMES_MALE[ns.player.class];
ns.player.raceLocale,ns.player.race = UnitRace("player");
ns.LC.colorset("suffix",ns.LC.colorset[ns.player.class:lower()]);
ns.realms = {};
do
	local function Init()
		local _,_,_,_,_,_,_,_,ids = ns.LRI:GetRealmInfoByGUID(UnitGUID("player"));
		if ids then
			for i=1, #ids do
				local _,name,apiName = ns.LRI:GetRealmInfoByID(ids[i]);
				ns.realms[name] = apiName;
				ns.realms[apiName] = name;
			end
		else
			ns.realms[ns.realm] = ns.realm_short;
			ns.realms[ns.realm_short] = ns.realm;
		end
	end
	setmetatable(ns.realms,{
		__index = function(t,k)
			if Init then Init(); Init=nil; end
			return rawget(t,k) or false;
		end
	});
end

function ns.showThisChar(modName,realm,faction)
	if not ns.profile[modName].showAllFactions and ns.player.faction~=faction then
		return false;
	end
	if ns.profile[modName].showCharsFrom==1 and realm~=ns.realm then -- same realm
		return false;
	elseif ns.profile[modName].showCharsFrom==2 and not ns.realms[realm] then -- connected realms
		return false;
	elseif ns.profile[modName].showCharsFrom==3 then -- battlegroup
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


  ---------------------------------------
--- nice little print function          ---
  ---------------------------------------
ns.debugMode = ("@project-version@"=="@".."project-version".."@"); -- the first part will be replaced by packager.
function ns.print(...)
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

function ns.debug(...)
	if ns.debugMode then
		ns.print("debug",...);
	end
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
		if ns.build>=54800000 and InCombatLockdown() and blacklist[cvar]==true then
			local msg
			-- usefull blacklisted cvars...
			if cvar=="uiScale" or cvar=="useUiScale" then
				msg = "Changing UI scaling while combat nether an good idea."
			else
			-- useless blacklisted cvars...
				msg = "Sorry, CVar "..cvar.." are no longer changeable while combat. Thanks @ Blizzard."
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
local openTooltip, hiddenMouseOver;

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

function ns.tooltipScaling(tooltip)
	if ns.profile.GeneralOptions.tooltipScale == true then
		tooltip:SetScale(tonumber(GetCVar("uiScale")))
	end
end

----------------------------------
-- ttMode [ 1: close on leave broker button (bool/nil) | 2: dont use hiddenMouseOver (bool/nil) ],
-- ttParent [ 1: parent frame element (frame) | 2: anchor direction (string) | 3: alternative anchor target (frame/optional) ]

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
	if ns.profile.GeneralOptions.tooltipScale==true then
		tooltip:SetScale(tonumber(GetCVar("uiScale")));
	end
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
	-- Tiptac Support for LibQTip Tooltips
	if tooltip and _G.TipTac and _G.TipTac.AddModifiedTip then
		-- Pass true as second parameter because hooking OnHide causes C stack overflows
		_G.TipTac:AddModifiedTip(tooltip, true);
	end
	-- AddOnSkins support
	if AddOnSkins and AddOnSkins.SkinTooltip then
		AddOnSkins:SkinTooltip(tooltip);
	end
	tooltip:SetClampedToScreen(true);
	tooltip:SetPoint(ns.GetTipAnchor(unpack(ttParent)));
	return tooltip;
end

function ns.roundupTooltip(tooltip)
	if not tooltip then return end
	tooltip:UpdateScrolling(GetScreenHeight() * (ns.profile.GeneralOptions.maxTooltipHeight/100));
	tooltip:SetClampedToScreen(true);
	if not tooltip:IsShown() then
		tooltip:Show();
	end
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


  ---------------------------------------
--- icon colouring function             ---
  ---------------------------------------
do
	local function updateColor(n)
		local obj = objs[n] or ns.LDB:GetDataObjectByName(n)
		objs[n] = obj
		if obj==nil then return false end
		obj.iconR,obj.iconG,obj.iconB,obj.iconA = unpack(ns.profile.GeneralOptions.iconcolor or ns.LC.color("white","colortable"))
		return true
	end
	function ns.updateIconColor(name)
		if name==true then
			for i,v in pairs(ns.modules) do
				updateColor(i);
			end
		elseif ns.modules[name]~=nil then
			updateColor(name)
		end
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
	local iconset = nil
	local objs = {}
	ns.I = setmetatable({},{
		__index = function(t,k)
			local v = {iconfile=ns.icon_fallback,coords={0.05,0.95,0.05,0.95}}
			rawset(t, k, v)
			return v
		end,
		__call = function(t,a)
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
	function ns.updateIcons()
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
		obj.iconR,obj.iconG,obj.iconB,obj.iconA = unpack(ns.profile.GeneralOptions.iconcolor or ns.LC.color("white","colortable"))
		return true
	end
	function ns.updateIconColor(name)
		local result = true;
		if (name==true) then
			for i,v in pairs(ns.modules) do if (updateIconColor(i)==false) then result=false; end end
		elseif (ns.modules[name]~=nil) then
			result = updateIconColor(name);
		end
		return result;
	end
end


-- ------------------------------ --
-- missing real found function    --
-- ------------------------------ --
function ns.round(num,precision)
	return tonumber(("%."..(tonumber(precision) or 0).."f"):format(num));
end


-- -------------------------------------------------- --
-- Function to Sort a table by the keys               --
-- Sort function fom http://www.lua.org/pil/19.3.html --
-- -------------------------------------------------- --
function ns.pairsByKeys(t, f)
	local a = {}
	for n in pairs(t) do
		table.insert(a, n)
	end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local function iter()   -- iterator function
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end

function ns.reversePairsByKeys(t, f)
	local a = {}
	for n in ipairs(t) do
		table.insert(a,n)
	end
	table.sort(a, f)
	local i = #a
	local function iter()
		i = i - 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end


-- ------------------------------------ --
-- FormatLargeNumber function advanced  --
-- ------------------------------------ --
local suffixes1,suffixes2,floatformat = {"K","M","G","T","P","E"},{},"%0.1f";
function ns.FormatLargeNumber(modName,value,tooltip)
	local shortNumbers,doShortcut = false,true;
	if type(modName)=="boolean" then
		shortNumbers = modName;
	elseif modName and ns.profile[modName] then
		shortNumbers = ns.profile[modName].shortNumbers;
	end
	if tooltip and IsShiftKeyDown() then
		doShortcut = false;
	end
	value = tonumber(value) or 0;
	if shortNumbers and doShortcut then
		local suffix = "";
		if value>=1000 then
			for i=1, #suffixes1 do
				value,suffix = value/1000,suffixes1[i];
				if value<1000 then
					break;
				end
			end
		end
		if floor(value)~=value then
			value = floatformat:format(value)
		end
		value = value..suffix;
	elseif ns.profile.GeneralOptions.separateThousands then
		value = FormatLargeNumber(value);
	end
	return value;
end


-- --------------------- --
-- Some string  function --
-- --------------------- --
function ns.strWrap(text, limit, insetCount, insetChr, insetLastChr)
	if not text then return ""; end
	if text:match("\n") or text:match("%|n") then
		local txt = gsub(text,"%|n","\n");
		local strings,tmp = {strsplit("\n",txt)},{};
		for i=1, #strings do
			tinsert(tmp,ns.strWrap(strings[i], limit, insetCount, insetChr, insetLastChr));
		end
		return table.concat(tmp,"\n");
	end
	if strlen(text)<=limit then return text; end
	local i,result,inset = 1,{},"";
	if type(insetCount)=="number" then
		inset = strrep(insetChr or " ",insetCount - (strlen(insetLastChr or ""))).. (insetLastChr or "");
	end
	for str in string.gmatch(text, "([^ \n]+)") do
		local tmp = (result[i] and result[i].." " or "")..strtrim(str);
		if strlen(tmp)<=limit then
			result[i]=tmp;
		else
			i=i+1;
			result[i]=str;
		end
	end
	return table.concat(result,"|n"..inset)
end

function ns.getBorderPositions(f)
	local us = UIParent:GetEffectiveScale();
	local uw,uh = UIParent:GetWidth(), UIParent:GetHeight();
	local fx,fy = f:GetCenter();
	local fw,fh = f:GetWidth()/2, f:GetHeight()/2;
	-- LEFT, RIGHT, TOP, BOTTOM
	return fx-fw, uw-(fx+fw), uh-(fy+fh),fy-fh;
end

function ns.strCut(str,limit)
	if strlen(str)>limit-3 then str = strsub(str,1,limit-3).."..." end
	return str
end

function ns.strFill(str,pat,count,append)
	local l = (count or 1) - strlen(str);
	if l<=0 then return str; end
	local p = strrep(pat or " ", l);
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
	--- local elements
	local update,d,ticker,_ = false,{ids={}, seen={}, bags={},inv={},item={}, callbacks={any={},bags={},inv={},item={}}, preScanCallbacks={}, linkData={}, tooltipData={}, NeedTooltip={}};
	local GetItemInfoFailed,IsEnabled = false,false;
	local _ITEM_LEVEL = gsub(ITEM_LEVEL,"%%d","(%%d*)");
	local _UPGRADES = gsub(ITEM_UPGRADE_TOOLTIP_FORMAT,": %%d/%%d","");
	local INVTYPES = { -- since 7.1 - GetItemInfo response incorrect itemType for armor and weapons
		INVTYPE_THROWN = WEAPON,INVTYPE_HOLDABLE = WEAPON,INVTYPE_RANGED = WEAPON,INVTYPE_RANGEDRIGHT = WEAPON,INVTYPE_WEAPON = WEAPON,
		INVTYPE_WEAPONMAINHAND = WEAPON,INVTYPE_WEAPONMAINHAND_PET = WEAPON,INVTYPE_WEAPONOFFHAND = WEAPON,INVTYPE_2HWEAPON = WEAPON,
		INVTYPE_BODY = ARMOR,INVTYPE_CHEST = ARMOR,INVTYPE_CLOAK = ARMOR,INVTYPE_FEET = ARMOR,INVTYPE_FINGER = ARMOR,INVTYPE_HAND = ARMOR,
		INVTYPE_HEAD = ARMOR,INVTYPE_LEGS = ARMOR,INVTYPE_NECK = ARMOR,INVTYPE_QUIVER = ARMOR,INVTYPE_ROBE = ARMOR,INVTYPE_SHIELD = ARMOR,
		INVTYPE_SHOULDER = ARMOR,INVTYPE_TABARD = ARMOR,INVTYPE_TRINKET = ARMOR,INVTYPE_WAIST = ARMOR,INVTYPE_WRIST = ARMOR
	}

	-- EMPTY_SOCKET_PRISMATIC and EMPTY_SOCKET_NO_COLOR are identical in some languages... Need only one of it.
	local EMPTY_SOCKETS = {"RED","YELLOW","META","HYDRAULIC","BLUE","PRISMATIC","COGWHEEL","NO_COLOR"};
	if EMPTY_SOCKET_PRISMATIC==EMPTY_SOCKET_NO_COLOR then
		tremove(EMPTY_SOCKETS,8);
	end

	local function GetObjectLinkData(obj)
		if not d.linkData[obj.link] then
			local _,_,_,data = obj.link:match("|c(%x*)|H([^:]*):(%d+):(.+)|h%[([^%[%]]*)%]|h|r");
			d.linkData[obj.link] = {strsplit(":",data or "")};
			--local dataKeys = {"enchantId", "gems", "gems", "gems", "gems" , "suffix", "unique", "linkLvl", "reforging","spelleffect"};
			for i=1, #d.linkData[obj.link] do
				d.linkData[obj.link][i] = tonumber(d.linkData[obj.link][i]) or 0;
				--if dataKeys[i] then
				--	if dataKeys[i]=="gems" then
				--		tinsert(obj[dataKeys[i]],d.linkData[obj.link][i]);
				--	else
				--		obj[dataKeys[i]] = d.linkData[obj.link][i];
				--	end
				--end
			end
		end
		obj.linkData = d.linkData[obj.link];
	end

	local function GetObjectTooltipData(obj,instantMode)
		if instantMode==true then
			if not d.tooltipData[obj.link] then
				local data = ns.ScanTT.query({type="link",link=obj.link,obj=obj},true);
				if #data.lines>0 then
					d.tooltipData[obj.link] = CopyTable(data.lines);
				end
			end
		else
			local scanner;
			if obj.obj then
				scanner = obj;
				obj = obj.obj;
			end
			if not d.tooltipData[obj.link] then
				if not scanner then
					ns.ScanTT.query({type="link",link=obj.link,obj=obj,callback=GetObjectTooltipData});
					return;
				end
				if scanner.lines and #scanner.lines>0 then
					d.tooltipData[obj.link] = CopyTable(scanner.lines);
					-- change flag?
				end
			end
		end

		obj.tooltip = d.tooltipData[obj.link] or {};
		if obj.itemType==ARMOR or obj.itemType==WEAPON then
			for i=2, _G.min(#obj.tooltip,20) do
				local lvl = tonumber(obj.tooltip[i]:match(_ITEM_LEVEL));
				if lvl then
					obj.level=lvl;
				elseif obj.tooltip[i]:find(_UPGRADES) then
					_,obj.upgrades = strsplit(" ",obj.tooltip[i]);
				elseif i>4 and obj.setname==nil and obj.tooltip[i]:find("%(%d*/%d*%)$") then
					obj.setname = strsplit("(",obj.tooltip[i]);
				else
					local socketCount,inLines = 0,{};
					-- detect sockets in tooltip
					for n=1, #EMPTY_SOCKETS do
						if obj.tooltip[i]==_G["EMPTY_SOCKET_"..EMPTY_SOCKETS[n]] then
							socketCount=socketCount+1;
							tinsert(inLines,i);
						end
					end
					-- check sockets
					if socketCount>0 then
						for i=2, 5 do
							obj.gems[i-1]=obj.linkData[i];
							if obj.linkData[i]==0 then
								obj.empty_gem=true;
							end
						end
					end
				end
			end
		end
	end

	local function scanner()
		if not IsEnabled then return end

		local items,seen,bags,inv,callbacks_item = {},{},{},{},{};
		local inv_changed,bags_changed=false,false;
		local _GetItemInfoFailed=GetItemInfoFailed;
		-- get all itemIds from all items in the bags
		for bag=0, NUM_BAG_SLOTS do
			for slot=1, GetContainerNumSlots(bag) do
				local id = GetContainerItemID(bag,slot);
				if (id) then
					if(items[id]==nil)then items[id]={}; end
					local obj = {type="bag", bag=bag, slot=slot, id=id, gems={},empty_gem=false};
					obj.icon, obj.count, obj.locked, _, obj.readable, obj.lootable, obj.link = GetContainerItemInfo(bag, slot);
					obj.name, _, obj.rarity, obj.level, _, obj.itemType, obj.subType, obj.stackCount, obj.itemEquipLoc, _, obj.price = GetItemInfo(obj.link);
					if INVTYPES[obj.itemEquipLoc]~=obj.itemType then
						obj.itemType=INVTYPES[obj.itemEquipLoc]; -- since 7.1 - GetItemInfo response incorrect itemType for armor and weapons
					end
					obj.durability,obj.durability_max = GetContainerItemDurability(bag, slot);
					if obj.name then
						GetObjectLinkData(obj);
						if IsEquippableItem(obj.link) or d.NeedTooltip[id] or (ns.artifactpower_items and ns.artifactpower_items[id]) then -- 7.2 GetItemInfo invalid itemType Bug. @Blizzard: Ha Ha. Dirty trick. Try again :P
							GetObjectTooltipData(obj);
						end
						tinsert(items[id],obj);
						seen[id]=true; bags[bag..":"..slot]=id;
						if d.bags[bag..":"..slot]~=id and d.callbacks.item[id] then
							for i,v in pairs(d.callbacks.item[id]) do
								if(type(v)=="function")then
									callbacks_item[i] = v;
								end
							end
						end
					else
						if GetItemInfoFailed~=false then
							GetItemInfoFailed = GetItemInfoFailed + 1;
						else
							GetItemInfoFailed = 0;
						end
					end
				end
				if d.bags[bag..":"..slot]~=id then
					bags_changed = true;
				end
			end
		end

		-- get all itemIds from equipped items
		local slotNames,_ = {"Head","Neck","Shoulder","Shirt","Chest","Waist","Legs","Feet","Wrist","Hands","Finger0","Finger1","Trinket0","Trinket1","Back","MainHand","SecondaryHand","Range","Tabard"};
		for slotIndex=1, 19 do
			local id, unknown1 = GetInventoryItemID("player",slotIndex);
			if type(id)=="number" then
				if(items[id]==nil)then items[id]={}; end
				local obj,lvl = {type="inventory",slotName=slotNames[slotIndex],slotIndex=slotIndex,slot=slotIndex,durability={},id=id,unknown1=unknown1,gems={},empty_gem=false};
				obj.link = GetInventoryItemLink("player",slotIndex);
				obj.name, _, obj.rarity, obj.level, _, obj.itemType, obj.subType, _, obj.itemEquipLoc, obj.icon, obj.price = GetItemInfo(obj.link);
				if INVTYPES[obj.itemEquipLoc]~=obj.itemType then
					obj.itemType=INVTYPES[obj.itemEquipLoc]; -- since 7.1 - GetItemInfo response incorrect itemType for armor and weapons
				end
				obj.isBroken = GetInventoryItemBroken("player",slotIndex);
				obj.durability, obj.durability_max = GetInventoryItemDurability(slotIndex);
				GetObjectLinkData(obj);
				GetObjectTooltipData(obj);
				tinsert(items[id],obj);
				seen[id]=true;
				inv[slotIndex]=obj;
				if d.callbacks.item[id] and d.inv[slotIndex].link~=obj.link then
					for i,v in pairs(d.callbacks.item[id]) do
						if(type(v)=="function")then
							callbacks_item[i] = v;
						end
					end
				end
				if (not d.inv[slotIndex])~=(not inv[slotIndex]) or (d.inv[slotIndex] and d.inv[slotIndex].link~=obj.link) then
					inv_changed = true;
				end
			end
		end
		d.ids = items;

		-- for any items seen on previous update but not now...
		for id,_ in pairs(d.seen)do
			if not seen[id] then
				if(d.callbacks.item[id])then
					for i,v in pairs(d.callbacks.item[id]) do
						if(type(v)=="function")then
							callbacks_item[i] = v;
						end
					end
				end
			end
		end
		d.seen = seen;
		d.bags = bags;
		d.inv = inv;

		-- execute callback functions for item id's
		for module,func in pairs(callbacks_item) do
			if d.preScanCallbacks[module] then
				d.preScanCallbacks[module]("preScan");
			end
			if(type(func)=="function")then
				func("update.item");
			end
		end

		-- execute callback.bags
		if bags_changed and d.callbacks.bags~=nil then
			for module,func in pairs(d.callbacks.bags)do
				if type(func)=="function" then
					func("update.bags");
				end
			end
		end

		-- execute callback.inv
		if inv_changed and d.callbacks.inv~=nil then
			for module,func in pairs(d.callbacks.inv)do
				if type(func)=="function" then
					func("update.inv");
				end
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

		if GetItemInfoFailed~=false then
			if GetItemInfoFailed>4 then
				GetItemInfoFailed=false;
			elseif ns.pastPEW then
				update = 0.5;
			end
		elseif GetItemInfoFailed==_GetItemInfoFailed then
			GetItemInfoFailed = false;
		end
	end

	--- event and update frame
	local locked,tickerDelay,defaultDelay,f = false,0.3,1.5,CreateFrame("Frame");
	local function updater()
		if update==false or locked then return end
		locked = true;
		update = update - tickerDelay;
		if update<=0 then
			scanner();
			update = false;
			ticker:Cancel();
			ticker = nil;
		end;
		locked = false;
	end
	f:SetScript("OnEvent",function(self,event)
		if event=="PLAYER_ENTERING_WORLD" then
			self.PEW = true;
			ticker = C_Timer.NewTicker(tickerDelay,updater);
			self:UnregisterEvent(event);
		elseif self.PEW then
			update = defaultDelay;
			if not ticker then
				ticker = C_Timer.NewTicker(tickerDelay,updater);
			end
		end
	end);
	f:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	f:RegisterEvent("ITEM_UPGRADE_MASTER_UPDATE");
	f:RegisterEvent("BAG_UPDATE_DELAYED");
	f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	f:RegisterEvent("PLAYER_ENTERING_WORLD");

	--- namespace functions
	ns.items = {};
	function ns.items.RegisterCallback(modName,func,mode,id)
		mode = tostring(mode):lower();
		assert(type(modName)=="string" and ns.modules[modName],"argument #1 (modName) must be a string, got "..type(modName));
		assert(type(func)=="function","argument #2 (function) must be a function, got "..type(func));
		assert(mode=="any" or mode=="inv" or mode=="bags" or mode=="item", "argument #3 must be 'any','inv', 'bags' or 'item'.");
		if (d.callbacks[mode]==nil) then
			d.callbacks[mode] = {};
		end
		if mode=="item" then
			assert(type(id)=="number","argument #4 must be number, got "..type(id));
			if (d.callbacks[mode][id]==nil) then
				d.callbacks[mode][id] = {};
			end
			d.callbacks[mode][id][modName] = func;
		else
			d.callbacks[mode][modName] = func;
		end
		d.callbacks.active = true;
		IsEnabled = true;
	end
	function ns.items.RegisterPreScanCallback(modName,func)
		assert(type(modName)=="string" and ns.modules[modName],"argument #1 (modName) must be a string, got "..type(modName));
		assert(type(func)=="function","argument #3 (function) must be a function, got "..type(func));
		if(d.preScanCallbacks==nil)then
			d.preScanCallbacks={};
		end
		d.preScanCallbacks[modName]=func;
		IsEnabled = true;
	end
	function ns.items.Enable()
		IsEnabled = true;
	end
	function ns.items.RegisterNeedTooltip(id)
		if type(id)=="table" then
			for i=1, #id do
				ns.items.RegisterNeedTooltip(id[i]);
			end
		else
			local id = tonumber(id);
			if id then
				d.NeedTooltip[id]=true;
			end
		end
	end
	function ns.items.exist(itemId)
		return d.ids[itemId] or false;
	end
	function ns.items.GetItemlist()
		return d.ids;
	end
	function ns.items.UpdateNow()
		if not IsEnabled and ns.pastPEW then return end
		update = 1;
	end
	function ns.items.GetBagItems()
		local result = {};
		for _,id in pairs(d.prev_bags)do
			result[id]=d.ids[id];
		end
		return result;
	end
	function ns.items.GetInventoryItems()
		return d.inv;
	end
	function ns.items.GetInventoryItemBySlotIndex(index)
		return d.inv[index] or false;
	end
	function ns.items.GetItemTooltip(obj)
		if obj then
			GetObjectTooltipData(obj,true);
		end
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
		if data._type=="bag" then
			if data.id then
				data.itemName, data.itemLink, data.itemRarity, data.itemLevel, data.itemMinLevel, data.itemType, data.itemSubType, data.itemStackCount, data.itemEquipLoc, data.itemTexture, data.itemSellPrice = GetItemInfo(data.id);
			end
			data.startTime, data.duration, data.isEnabled = GetContainerItemCooldown(data.bag,data.slot);
			data.hasCooldown, data.repairCost = tt:SetBagItem(data.bag,data.slot);
			data.str = "bag"..data.bag..", slot"..data.slot;
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
		elseif data._type=="inventory" then
			data._type="link";
			_,data.hasCooldown, data.repairCost = tt:SetInventoryItem("player", data.slot); -- repair costs
			data.link=data.link or "item:"..data.id;
		elseif data._type=="item" then
			data._type="link";
			data.link=data.link or "item:"..data.id;
		elseif data._type=="quest" then
			data._type="link";
			data.link=data.link or "quest:"..data.id..":"..data.level;
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
				local str = strtrim(v:GetText() or "");
				if strlen(str)>0 then
					tinsert(data.lines,str);
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
	if(type(amount)~="number")then amount=0; end

	if(not opts)then opts={}; end
	if(not opts.sep)then
		opts.sep=" ";
	end
	if(not opts.hideLowerZeros)then
		opts.hideLowerZeros=false;
		if (ns.profile.GeneralOptions.goldHideLowerZeros==true)then
			opts.hideLowerZeros=true;
		end
	end

	if(not opts.hideCopper)then
		opts.hideCopper=false;
		if(ns.profile.GeneralOptions.goldHideCopper==true)then
			opts.hideCopper=true;
		end
	end

	if(not opts.hideSilver)then
		opts.hideSilver=false;
		if(ns.profile.GeneralOptions.goldHideSilver==true)then
			opts.hideSilver=true;
		end
	end

	if(opts.hideSilver)then
		amount = floor(amount/10000)*10000;
	elseif(opts.hideCopper)then
		amount = floor(amount/100)*100;
	end

	local gold, silver, copper, t, i = floor(amount/10000), mod(floor(amount/100),100), mod(floor(amount),100), {}, 1

	if amount==0 or not (opts.hideCopper or (copper==0 and opts.hideLowerZeros))then
		if (ns.profile.GeneralOptions.goldColor==true) then
			tinsert(t,ns.LC.color("copper",(silver>0 or gold>0) and zz:format(copper) or copper));
		else
			tinsert(t,copper .. tex:format("Copper"));
		end
	end

	if amount>0 and not (opts.hideSilver or (copper==0 and silver==0 and opts.hideLowerZeros))then
		if (ns.profile.GeneralOptions.goldColor==true) then
			tinsert(t,1,ns.LC.color("silver",gold>0 and zz:format(silver) or silver));
		else
			tinsert(t,1,silver .. tex:format("Silver"));
		end
	end

	if(gold>0)then
		gold = ns.FormatLargeNumber(modName,gold,opts.inTooltip);
		if (ns.profile.GeneralOptions.goldColor==true) then
			tinsert(t,1,ns.LC.color("gold",gold));
		else
			tinsert(t,1,gold .. tex:format("Gold"));
		end
	end

	local str = table.concat(t,opts.sep);

	if not ns.profile.GeneralOptions.goldColor and type(opts.color)=="string" then
		str = ns.LC.color(opts.color,str);
	end

	return str;
end


-- ----------------------------------------------------- --
-- screen capture mode - string replacement function     --
-- ----------------------------------------------------- --
function ns.scm(str,all)
	if (type(str)=="string") and (strlen(str)>0) and (ns.profile.GeneralOptions.scm==true) then
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

	function ns.hideFrame(frameName)
		local pName = _G[frameName]:GetParent():GetName()
		if pName==nil then
			return false
		end
		hidden.origParent[frameName] = pName
		_G[frameName]:SetParent(hidden)
	end

	function ns.unhideFrame(frameName)
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
	local self = ns.EasyMenu;
	self.menu = {};
	self.controlGroups = {};
	self.IsPrevSeparator = false;
	local cvarTypeFunc = {
		bool = function(D)
			if (type(D.cvar)=="table") then
				--?
			elseif (type(D.cvar)=="string") then
				function D.checked() return (GetCVar(D.cvar)=="1") end;
				function D.func() SetCVar(D.cvar,GetCVar(D.cvar)=="1" and "0" or "1"); end;
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

	function self.InitializeMenu()
		if (not self.frame) then
			self.frame = CreateFrame("Frame", addon.."EasyMenu", UIParent, "LibDropDownMenuTemplate");
		end
		wipe(self.menu);
		return self.frame;
	end

	function self.addEntry(D,P)
		local entry= {};

		if (type(D)=="table") and (#D>0) then -- numeric table = multible entries
			self.IsPrevSeparator = false;
			for i,v in ipairs(D) do
				self.addEntry(v,parent);
			end
			return;

		elseif (D.childs) then -- child elements
			self.IsPrevSeparator = false;
			local parent = self.addEntry({ label=D.label, arrow=true, disabled=D.disabled },P);
			for i,v in ipairs(D.childs) do
				self.addEntry(v,parent);
			end
			return;

		elseif (D.groupName) and (D.optionGroup) then -- similar to childs but with group control
			self.IsPrevSeparator = false;
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
			if self.IsPrevSeparator then
				return;
			end
			self.IsPrevSeparator = true;
			entry = { text = "", dist = 0, isTitle = true, notCheckable = true, isNotRadio = true, sUninteractable = true, iconOnly = true, icon = "Interface\\Common\\UI-TooltipDivider-Transparent", tCoordLeft = 0, tCoordRight = 1, tCoordTop = 0, tCoordBottom = 1, tFitDropDownSizeX = true, tSizeX = 0, tSizeY = 8 };
			entry.iconInfo = entry; -- looks like stupid? is necessary to work. (thats blizzard)

		else
			self.IsPrevSeparator = false;
			entry.isTitle          = D.title     or false;
			entry.hasArrow         = D.arrow     or false;
			entry.disabled         = D.disabled  or false;
			entry.notClickable     = not not D.noclick;
			entry.isNotRadio       = not D.radio;
			entry.keepShownOnClick = true;

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
				--if type(D.checked)=="function" then
				--	entry.checked = D.checked(D);
				--else
					entry.checked = D.checked;
				--end
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

	function self.addConfigElements(modName,separator,noTitle)
		if (separator) then
			self.addEntry({ separator = true });
		end
		if not noTitle and #ns.modules[modName].config>=3 and ns.modules[modName].config[3].type~="header" then
			self.addEntry({ label = OPTIONS, title = true });
		end
		for i,v in ipairs(ns.modules[modName].config) do

			local disabled = v.disabled;
			if (type(disabled)=="function") then
				disabled=disabled();
			end

			if (disabled) or (i==1) or (i==2) then
				-- do nothing
			elseif (v.type=="separator" and v.inMenuInvisible~=true) then
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
					checked = function()
						if v.name=="minimap" then
							return not ns.profile[modName][v.name].hide;
						end
						return ns.profile[modName][v.name];
					end,
					func  = function()
						if v.name=="minimap" then
							ns.profile[modName].minimap.hide = not ns.profile[modName].minimap.hide;
							ns.toggleMinimapButton(modName);
						else
							ns.profile[modName][v.name] = not ns.profile[modName][v.name];
							if v.event and ns.modules[modName].onevent then
								ns.modules[modName].onevent(ns.modules[modName].eventFrame,v.event~=true and v.event or "BE_DUMMY_EVENT");
							end
						end
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
						checked = function()
							return (ns.profile[modName][v.name]==valKey);
						end,
						func = function(self)
							ns.profile[modName][v.name] = valKey;
							if v.event and ns.modules[modName].onevent then
								ns.modules[modName].onevent(ns.modules[modName].eventFrame,v.event~=true and v.event or "BE_DUMMY_EVENT");
							end
							self:GetParent():Hide();
						end
					},p);
				end
			elseif (v.type=="slider") then
				-- currently no idea how i can add a slider into blizzard's dropdown menu.
			end
		end
	end

	function self.ShowMenu(parent, parentX, parentY, callbackOnClose)
		local anchor, x, y, displayMode = "cursor", nil, nil, "MENU"

		if (parent) then
			anchor = parent;
			x = parentX or 0;
			y = parentY or 0;
		end

		self.addEntry({separator=true});
		--self.addEntry({label=CANCEL, func=function() LibDropDownMenu_List1:Hide(); end});
		self.addEntry({label=L["Close menu"], func=function() LibDropDownMenu_List1:Hide(); if callbackOnClose then callbackOnClose() end end});

		if openTooltip then
			ns.hideTooltip(openTooltip,openTooltip.key,true,false,true);
		end

		ns.LDDM.UIDropDownMenu_Initialize(self.frame, ns.LDDM.EasyMenu_Initialize, displayMode, nil, self.menu);
		ns.LDDM.ToggleDropDownMenu(1, nil, self.frame, anchor, x, y, self.menu, nil, nil);
	end

	function self.ShowDropDown(parent)
		local displaymode = nil;

		ns.LDDM.UIDropDownMenu_Initialize(self.frame, ns.LDDM.EasyMenu_Initialize);
		ns.LDDM.ToggleDropDownMenu(nil, nil, self.frame);
	end

	function self.Refresh(level)
		ns.LDDM.UIDropDownMenu_Refresh(self.frame,nil,level);
	end

	function self.RefreshAll()
		ns.LDDM.UIDropDownMenu_RefreshAll(self.frame);
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
	local values = {
		["__NONE"]     = "Disabled",			-- ADDON_DISABLED
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

	ns.clickOptions = {};

	function ns.clickOptions.func(name,self,button)
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
	end

	function ns.clickOptions.update(modName) -- BE_UPDATE_CLICKOPTION
		local mod = ns.modules[modName];
		local db = ns.profile[modName];
		if (not mod.clickOptionsConfigNum) then
			mod.clickOptionsConfigNum={};
			mod.config_click_options={};

			for cfgKey,clickOpts in ns.pairsByKeys(mod.clickOptions) do
				local cfg_entry = {
					type	= "select",
					name	= "clickOptions::"..cfgKey,
					label	= L[clickOpts.cfg_label],
					tooltip	= L["Choose your fav. combination of modifier and mouse key to"].." "..L[clickOpts.cfg_desc],
					values	= values,
					default	= clickOpts.cfg_default or "__NONE",
					event	= "BE_UPDATE_CLICKOPTIONS"
				};
				tinsert(mod.config_click_options,cfg_entry);
				mod.clickOptionsConfigNum[cfgKey] = #mod.config_click_options;

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
	end
	function ns.clickOptions.ttAddHints(tt,name,ttColumns,entriesPerLine)
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
					tt:SetCell(line,1,v,nil,"LEFT",ttColumns or 0);
				else
					tt:AddLine(v);
				end
			end
		end
	end
end


-- --------------------------------------- --
-- shared data for questlog & world quests --
-- --------------------------------------- --
do
	ns.questTags = {
		[QUEST_TAG_GROUP] = "g",
		[QUEST_TAG_PVP] = {"pvp","violet"},
		[QUEST_TAG_DUNGEON] = "d",
		[QUEST_TAG_HEROIC] = "hc",
		[QUEST_TAG_RAID] = "r",
		[QUEST_TAG_RAID10] = "r10",
		[QUEST_TAG_RAID25] = "r25",
		[QUEST_TAG_SCENARIO] = "s",
		[QUEST_TAG_ACCOUNT] = "a",
		[QUEST_TAG_LEGENDARY] = {"leg","orange"},
		TRADE_SKILLS = {"ts","green"},
		WORLD_QUESTS = {"wq","yellow"},
		DUNGEON_MYTHIC = {"myth","ltred"}
	};
	local tradeskills_update;
	local tradeskills_mt = {__call=function(t,k)
		if value then return rawget(t,k); end
		tradeskills_update();
	end};
	ns.tradeskills = setmetatable({},tradeskills_mt);
	local ts_try=0;
	function tradeskills_update()
		if ns.data.tradeskills==nil then
			ns.data.tradeskills = {};
		end
		if ns.data.tradeskills[ns.locale]==nil then
			ns.data.tradeskills[ns.locale]={};
		end
		ns.tradeskills = setmetatable(ns.data.tradeskills[ns.locale],tradeskills_mt);
		ts_try = ts_try+1;
		local fail = false;
		for spellId, spellName in pairs({
			[1804] = "Lockpicking", [2018]  = "Blacksmithing", [2108]  = "Leatherworking", [2259]  = "Alchemy",     [2550]  = "Cooking",     [2575]   = "Mining",
			[2656] = "Smelting",    [2366]  = "Herbalism",     [3273]  = "First Aid",      [3908]  = "Tailoring",   [4036]  = "Engineering", [7411]   = "Enchanting",
			[8613] = "Skinning",    [25229] = "Jewelcrafting", [45357] = "Inscription",    [53428] = "Runeforging", [78670] = "Archaeology", [131474] = "Fishing",
		}) do
			if ns.tradeskills[spellId]==nil then
				local spellLocaleName,_,spellIcon = GetSpellInfo(spellId);
				if spellLocaleName then
					ns.tradeskills[spellLocaleName] = true;
					ns.tradeskills[spellId] = true;
				else
					fail = true;
				end
			end
		end
		if fail and ts_try<=3 then
			C_Timer.After(0.5, function()
				tradeskills_update()
			end);
		end
	end
end

-- -----------------
-- text bar
-- ----------------
-- num, {<max>,<cur>[,<rest>]},{<max>,<cur>[,<rest>]}
function ns.textBar(num,values,colors,Char)
	local iMax,iMin,iRest = 1,2,3;
	local bar,chars,Char = "",{},Char or "=";
	values[iRest] = values[iRest] or 0;
	if values[iMax]==1 then
		values[iMax],values[iMin],values[iRest] = values[iMax]*100,values[iMin]*100,values[iRest]*100;
	end
	local ppc = values[iMax]/num; -- percent per character
	tinsert(chars,{ns.round(values[iMin]/ppc),colors[iMin]});
	tinsert(chars,{values[iMin]<100 and ns.round(values[iRest]/ppc) or 0,colors[iRest]});
	local cur_rest = chars[1][1]+chars[2][1];
	tinsert(chars,{cur_rest>=num and 0 or num-cur_rest,colors[iMax]});
	for i,v in ipairs(chars)do
		if v[1]>0 then
			bar = bar..ns.LC.color(v[2] or "white",strrep(Char,v[1]));
		end
	end
	return bar;
end
