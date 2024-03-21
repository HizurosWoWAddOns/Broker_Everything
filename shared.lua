
-- ====================================== --
-- Shared Functions for Broker_Everything --
-- ====================================== --
local addon, ns = ...;
local L,_ = ns.L;

-- Lua API 5.1 functions
local setmetatable,tonumber,rawget,rawset,tinsert=setmetatable,tonumber,rawget,rawset,tinsert;
local tremove,tostring,type,unpack,assert=tremove,tostring,type,unpack,assert;
local securecall,ipairs,pairs,tconcat,tsort=securecall,ipairs,pairs,table.concat,table.sort;
local time,wipe,mod,hooksecurefunc,strsplit=time,wipe,mod,hooksecurefunc,strsplit;

-- WoW Lua API functions
local C_AddOns = C_AddOns or {}
local UnitName,UnitSex,UnitClass,UnitFactionGroup=UnitName,UnitSex,UnitClass,UnitFactionGroup;
local UnitRace,GetRealmName,GetLocale=UnitRace,GetRealmName,GetLocale;
local InCombatLockdown,CreateFrame=InCombatLockdown,CreateFrame;
local GetScreenHeight,GetMouseFocus,GetAddOnInfo=GetScreenHeight,GetMouseFocus,GetAddOnInfo or C_AddOns.GetAddOnInfo;
local GetAddOnEnableState,IsAltKeyDown=GetAddOnEnableState,IsAltKeyDown;
local IsShiftKeyDown,IsControlKeyDown,GetItemInfo=IsShiftKeyDown,IsControlKeyDown,GetItemInfo;
local GetInventoryItemLink,GetInventoryItemID=GetInventoryItemLink,GetInventoryItemID;

-- WoW API functions defined in lua files
local CopyTable,SecondsToTime = CopyTable,SecondsToTime;

-- no longer in retail but in classic client
local GetContainerNumSlots,GetContainerItemCooldown,GetContainerItemLink,GetContainerItemID,GetContainerItemInfo,GetContainerNumFreeSlots=GetContainerNumSlots,GetContainerItemCooldown,GetContainerItemLink,GetContainerItemID,GetContainerItemInfo,GetContainerNumFreeSlots;

-- could be deprecated in future.
local GetCVar,SetCVar = C_CVar and C_CVar.GetCVar or GetCVar,C_CVar and C_CVar.SetCVar or SetCVar

-- Foreign addon functions
local LibStub = _G.LibStub

-- Init shared lib and debug mode
ns.debugMode = "@project-version@"=="@".."project-version".."@";
LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"BE");

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
--- misc shared data                    ---
  ---------------------------------------
ns.icon_fallback = 134400; -- interface\\icons\\INV_MISC_QUESTIONMARK;
ns.icon_arrow_right = "interface\\CHATFRAME\\ChatFrameExpandArrow";
ns.media = "Interface\\AddOns\\"..addon.."\\media\\";
ns.locale = GetLocale();
ns.ui = {size={UIParent:GetSize()},center={UIParent:GetCenter()}};
ns.realm = GetRealmName();
ns.region = ns.LRI:GetCurrentRegion() or ({"US","KR","EU","TW","CN"})[GetCurrentRegion()];
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
	local v1,v2,v3 = strsplit(".",version or "0.0.0");
	ns.client_version = tonumber(v1.."."..v2..v3..build) or 0;
end

---@return boolean
function ns.IsRetailClient()
	return WOW_PROJECT_ID==WOW_PROJECT_MAINLINE;
end

---@return boolean
function ns.IsClassicClient() -- for AceOptions
	return not WOW_PROJECT_ID==WOW_PROJECT_MAINLINE;
end

---@return boolean
function ns.IsClassicEraClient()
	return WOW_PROJECT_ID==WOW_PROJECT_CLASSIC;
end

---@return boolean
function ns.IsClassicWotlkClient()
	return WOW_PROJECT_ID==WOW_PROJECT_WRATH_CLASSIC;
end

---@return boolean
function ns.IsNotClassicClient() -- for AceOptions
	return WOW_PROJECT_ID==WOW_PROJECT_MAINLINE;
end


  ---------------------------------------
--- player and twinks dependent data    ---
  ---------------------------------------
---@param name string
---@return string name
function ns.stripRealm(name)
	name = name:gsub(" ","");
	name = name:gsub("%-","");
	return name;
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
ns.player.classLocale = ns.player.female and _G["LOCALIZED_CLASS_NAMES_FEMALE"][ns.player.class] or _G["LOCALIZED_CLASS_NAMES_MALE"][ns.player.class];
ns.player.raceLocale,ns.player.race,ns.player.raceIndex = UnitRace("player");
ns.LC.colorset("suffix",ns.LC.colorset[ns.player.class:lower()]);
ns.realms = {};
do
	local initFinished = false;
	local function Init()
		if initFinished then return end
		initFinished = true;
		local _,_,_,_,_,_,_,_,ids = ns.LRI:GetRealmInfo(ns.realm,ns.region);
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
			Init();
			return rawget(t,k) or false;
		end
	});
end

---@param name string
---@return string name
function ns.realmCheckOrAppend(name)
	if not name:find("-") then
		name = name.."-"..ns.realm_short;
	end
	return name;
end

---@param modName string module name
---@param realm string realm name
---@param faction string faction name
---@return boolean
function ns.showThisChar(modName,realm,faction)
	if not ns.profile[modName].showAllFactions and ns.player.faction~=faction then
		return false;
	end
	if ns.profile[modName].showCharsFrom=="1" and realm~=ns.realm then -- same realm
		return false;
	elseif ns.profile[modName].showCharsFrom=="2" and not ns.realms[realm] then -- connected realms
		return false;
	end
	return true;
end

---@param modName string module name
---@param name string player name
---@param color string color name or color code
---@param prepDash boolean prepend dash
function ns.showRealmName(modName,name,color,prepDash)
	if not (ns.realm_short==name or ns.realm==name) then
		if ns.profile[modName].showRealmNames then
			if type(name)=="string" and name:len()>0 then
				local _,_name = ns.LRI:GetRealmInfo(name,ns.region);
				if _name then
					return (prepDash~=false and ns.LC.color("white"," - "))..ns.LC.color(color or "dkyellow", ns.scm(name));
				end
			end
		else
			return ns.LC.color(color or "dkyellow"," *");
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
			ns:print(ns.LC.color("ltorange",msg));
		else
			SetCVar(...)
		end
	end
end


  ---------------------------------------
--- Helpful function for extra tooltips ---
  ---------------------------------------
local brokerDragHooks, openTooltip, hiddenMouseOver = {};

---@param frame frame
---@param direction string
---@param parentTT frame
---@return string point
---@return frame|string
---@return string relativePoint
---@return number x
---@return number y
function ns.GetTipAnchor(frame, direction, parentTT)
	local f,u,i,H,h,v,V = {frame:GetCenter()},{},0;
	if f[1]==nil or ns.ui.center[1]==nil then
		return "LEFT", frame, "LEFT", 0, 0;
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

---@param ttData table
---@param ttMode table
---@param ttParent table
---@param ttScripts table
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
	tooltip.mode[1] = tooltip.mode[1]==true or (modifier~="NONE" and ns.tooltipChkOnShowModifier(modifier))
	if hiddenMouseOver==nil then
		hiddenMouseOver = CreateFrame("Frame",addon.."TooltipHideShowFix2",UIParent);
		hiddenMouseOver:SetFrameStrata("BACKGROUND");
	end
	if not tooltip.mode[2] and ttParent[1] and not ttParent[1].parent then
		hiddenMouseOver:SetPoint("TOPLEFT",ttParent[1],"TOPLEFT",0,1);
		hiddenMouseOver:SetPoint("BOTTOMRIGHT",ttParent[1],"BOTTOMRIGHT",0,-1);

		-- TitalPanelAutoHide
		if TitanPanelSetVar and TitanUtils_GetWhichBar then
			local titanBar,current,ldbName = nil,nil,string.match(ttParent[1]:GetName() or "", "TitanPanel(.*)Button");
			if ldbName then
				titanBar = TitanUtils_GetWhichBar(ldbName);
			end
			if titanBar then
				current = TitanPanelGetVar(titanBar.."_Hide"); -- get autohide status
			end
			if current then
				tooltip.TitanBar_AutoHide = titanBar;
				TitanPanelSetVar(titanBar.."_Hide",false);
			end
		end
	end
	tooltip:SetScript("OnUpdate",hideOnUpdate);
	tooltip:SetScript("OnLeave",hideOnLeave);

	local TipTac = _G["TipTac"]
	if TipTac and TipTac.AddModifiedTip then
		TipTac:AddModifiedTip(tooltip, true); -- Tiptac Support for LibQTip Tooltips
	elseif AddOnSkins and AddOnSkins.SkinTooltip then
		AddOnSkins:SkinTooltip(tooltip); -- AddOnSkins support
	end

	tooltip:SetClampedToScreen(true);
	tooltip:SetPoint(ns.GetTipAnchor(unpack(ttParent)));

	if type(ttParent[1])=="table" and ttParent[1]:GetObjectType()=="Button" then
		if not brokerDragHooks[ttParent[1]] then
			-- close tooltips if broker button fire OnDragStart
			ttParent[1]:HookScript("OnDragStart",hookDragStart);
		end
		brokerDragHooks[ttParent[1]]={tooltip.key,tooltip};
	end

	return tooltip;
end

---@param tooltip frame|LibQTipTooltip
---@param ignoreMaxTooltipHeight boolean
function ns.roundupTooltip(tooltip,ignoreMaxTooltipHeight)
	if not tooltip then return end
	if not ignoreMaxTooltipHeight then
		tooltip:UpdateScrolling(GetScreenHeight() * (ns.profile.GeneralOptions.maxTooltipHeight/100));
	end
	tooltip:SetClampedToScreen(true);
	tooltip:Show();
end

---@param tooltip frame|LibQTipTooltip
function ns.hideTooltip(tooltip)
	if type(tooltip)~="table" then return; end
	if type(tooltip.secureButtons)=="table" then
		local f = GetMouseFocus()
		if f and not f:IsForbidden() and (not f:IsProtected() and InCombatLockdown()) and type(f.key)=="string" and type(tooltip.key)=="string" and f.key==tooltip.key then
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

	-- TitalPanelAutoHide
	if tooltip.TitanBar_AutoHide then
		TitanPanelSetVar(tooltip.TitanBar_AutoHide.."_Hide",true);
		tooltip.TitanBar_AutoHide = nil;
	end

	tooltip.parent = nil;
	tooltip.mode = nil;
	tooltip.scripts = nil;
	ns.LQT:Release(tooltip);
end

----------------------------------------

---@param tooltip frame|LibQTipTooltip
---@param func function
function ns.RegisterMouseWheel(tooltip,func)
	tooltip:EnableMouseWheel(1);
	tooltip:SetScript("OnMouseWheel", func);
end

-- L["ModKey" .. ns.tooltipModifiers.<key>.l]
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

---@param bool boolean
---@return boolean|string
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

---@param tooltip frame|LibQTipTooltip
---@param content string
---@param cells table
---@param align string
---@param font string
---@return number line
function ns.AddSpannedLine(tooltip,content,cells,align,font)
	local line = tooltip:AddLine();
	cells = cells or {};
	tooltip:SetCell(line,cells.start or 1,content,font,align,cells.count or 0);
	return line;
end


  --------------------------------------------------------------------------
--- coexistence with other addons                                          ---
--- sometimes it is better to let other addons the control about something ---
  --------------------------------------------------------------------------
do
	local found,list = nil,{
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
	local function search()
		found = {};
		for name in pairs(list) do
			if (GetAddOnInfo(name)) and ((GetAddOnEnableState and GetAddOnEnableState(ns.player.name,name)==2) or (C_AddOns.GetAddOnEnableState and C_AddOns.GetAddOnEnableState(name,ns.player.name)==2) ) then -- TODO: check after patch 10.2
				tinsert(found,name);
			end
		end
	end
	function ns.coexist.IsNotAlone(info)
		if not found then search() end
		local b = #found>0;
		if info and info[#info]:find("Info$") then -- for Ace3 Options (<hidden|disabled>=<thisFunction>)
			return not b;
		end
		return b;
	end
	function ns.coexist.optionInfo()
		if not found then search() end
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
---@param str string
---@return string
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
			if ns.profile==nil then
				return {};
			end

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
-- missing real round function    --
-- ------------------------------ --
---@param num number
---@param precision? number
---@return number
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
	---@param t table
	---@param f? function|true
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
			end
			return a[i], t[a[i]]
		end
		return iter
	end
end

function ns.table2string(tbl)
	local tmp={};
	for k,v in ns.pairsByKeys(tbl) do
		tinsert(tmp,"["..k.."]="..tostring(v));
	end
	return "{"..table.concat(tmp,", ").."}";
end


---@param modName string module name
---@param opts table
---@return function iterationFunction
function ns.pairsToons(modName,opts)
	-- opts = {currentFirst=<bool>,currentHide=<bool>,forceSameRealm=<bool>,forceSameFaction=<bool>}
	-- TODO: add ns.profile options from modules here
	local t = {};
	for index, toonNameRealm in ipairs(ns.toonsDB.order) do
		local name,realm = strsplit("-",toonNameRealm,2);
		if ns.showThisChar(modName,realm,ns.toonsDB[toonNameRealm].faction) then
			if opts.currentHide==true and toonNameRealm==ns.player.name_realm then
				-- ignore
			elseif opts.currentFirst==true and toonNameRealm==ns.player.name_realm then
				tinsert(t,1,index);
			elseif not (opts.forceSameRealm==true and realm~=ns.realm) and not (opts.forceSameFaction==true and ns.faction~=ns.toonsDB[toonNameRealm].faction) then
				tinsert(t,index);
			end
		end
	end
	local i=0;
	local function iter()
		i=i+1;
		local index = t[i];
		if ns.toonsDB.order[index]==nil then
			return nil;
		end
		local toonNameRealm = ns.toonsDB.order[index];
		local toonName,toonRealm = strsplit("-",toonNameRealm,2);
		return index, toonNameRealm, toonName, toonRealm, ns.toonsDB[toonNameRealm], toonNameRealm==ns.player.name_realm;
		-- index, toonNameRealm, toonName, toonRealm, toonData, isCurrent
	end
	return iter;
end


-- ------------------------------------------------------------ --
-- Function to check/create a table structure by given path
-- ------------------------------------------------------------ --
---@param tbl table
---@param a string
---@param ... string
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
	---@param modName string module name
	---@param value number|string
	---@param tooltip frame|LibQTipTooltip
	---@return number|string
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
---@param text string
---@param limit number
---@param insetCount? number
---@param insetChr? string
---@param insetLastChr? string
---@return string
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
		local tmp2 = strtrim(tmp.." "..str);
		if tmp2:len()>=limit then
			tinsert(result,tmp);
			tmp = strtrim(str);
		else
			tmp = tmp2;
		end
	end
	if tmp~="" then
		tinsert(result,tmp);
	end
	return tconcat(result,"|n"..inset)
end

---@param str string
---@param limit number
---@return string
function ns.strCut(str,limit)
	if str:len()>limit-3 then str = strsub(str,1,limit-3).."..." end
	return str
end

---@param str string
---@param pat string
---@param count number
---@param append boolean
---@return string
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
	local sbfObject,sbf = {};
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
			sbf:SetHighlightTexture([[interface\friendsframe\ui-friendsframe-highlightbar-blue]],"ADD");
			sbf:HookScript("OnClick",function(_,button) if type(sbfObject.OnClick)=="function" then sbfObject.OnClick(self,button,sbfObject); end end);
			sbf:HookScript("OnEnter",function() if type(sbfObject.OnEnter)=="function" then sbfObject.OnEnter(self,sbfObject); end end);
			sbf:HookScript("OnLeave",function() if type(sbfObject.OnLeave)=="function" then sbfObject.OnLeave(self,sbfObject); end end);
			sbf:RegisterForClicks("AnyUp","AnyDown"); -- TODO: testing
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
	local itemsByID,itemsBySlot,itemsBySpell,equip,ammo = {},{},{},{},{};
	ns.items = {byID=itemsByID,bySlot=itemsBySlot,bySpell=itemsBySpell,equip=equip,ammo=ammo};

	local hasChanged,updateBags,IsEnabledBags,IsEnabledInv = {bags=false,inv=false,equip=false,ammo=false,items=false,spells=false,item={},itemNum=0},{};
	local callbacks = {any={},inv={},bags={},item={},equip={},prepare={},toys={},ammo={}};
	local cbCounter = {any=0,inv=0,bags=0,item=0,equip=0,prepare=0,toys=0,ammo=0};
	local eventFrame,inventoryDelayed = CreateFrame("Frame");
	local LE_ITEM_CLASS_PROJECTILE = LE_ITEM_CLASS_PROJECTILE or Enum.ItemClass.Projectile or 6;
	local LR_ITEM_CLASS_WEAPON = LR_ITEM_CLASS_WEAPON or Enum.ItemClass.Weapon or 2;
	local LE_ITEM_WEAPON_THROWN = LE_ITEM_WEAPON_THROWN or 16;

	local function doCallbacks(tbl,...)
		if callbacks[tbl]==nil or cbCounter[tbl]==0 then
			return; -- no callbacks registered
		end
		for _,fnc in pairs(callbacks[tbl])do
			fnc(tbl,...);
		end
	end

	local function callbackHandler()
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
					doCallbacks("item",id,locations);
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
		if itemsBySlot[info.sharedSlot] and itemsBySlot[info.sharedSlot].diff==info.diff and info.ammo==0 then
			return false; -- item has not changed; must not be added again.
		end
		if itemsByID[info.id]==nil then
			itemsByID[info.id] = {};
		end
		-- add item info to ByID and BySlot tables
		itemsByID[info.id][info.sharedSlot] = info;
		itemsBySlot[info.sharedSlot] = info;
		-- add to extra table for equipment; inventory and bags. Needed for durability summary calculation.
		if info.equip then
			equip[info.sharedSlot] = true;
			hasChanged.equip = true;
		end
		-- item has 'Use:' effect spell
		local _,itemSpellID = GetItemSpell(info.link);
		if itemSpellID then
			info.spell = itemSpellID;
			if itemsBySpell[info.spell] == nil then
				itemsBySpell[info.spell] = {};
			end
			itemsBySpell[info.spell][info.sharedSlot] = info.count;
		end
		-- ns.ammo_classic defined in modules/ammo_classic.lua
		if ns.ammo_classic and info.ammo~=0 then
			ammo[info.sharedSlot] = true;
			hasChanged.ammo = true;
		end
		if callbacks.item[info.id] then
			hasChanged.item[info.id][info.sharedSlot] = true;
			hasChanged.items = true;
		end
		hasChanged[scanner] = true;
		return true;
	end

	local function removeItem(sharedSlotIndex,scanner)
		local id = itemsBySlot[sharedSlotIndex].id;
		itemsByID[itemsBySlot[sharedSlotIndex].id][sharedSlotIndex] = nil;
		itemsBySlot[sharedSlotIndex] = nil;
		if equip[sharedSlotIndex] then
			equip[sharedSlotIndex] = nil;
			hasChanged.equip = true;
		end
		if ns.ammo_classic and ammo[sharedSlotIndex] then
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
		local retry = false;
		for slotIndex=1, 19 do
			local sharedSlotIndex = -(slotIndex/100);
			local id = tonumber((GetInventoryItemID("player",slotIndex)));
			if id then
				local link = GetInventoryItemLink("player",slotIndex);
				-- back again; need durability for detect changes to trigger update of durability module broker display
				local _, _, _, _, _, itemClassID, itemSubClassID = GetItemInfoInstant(link);
				local durability, durabilityMax = GetInventoryItemDurability(slotIndex);
				addItem({
					bag=-1,
					slot=slotIndex,
					sharedSlot=sharedSlotIndex,
					id=id,
					link=link,
					diff=table.concat({link,durability,durabilityMax},"^"),
					equip=true,
					ammo=(itemClassID==LR_ITEM_CLASS_WEAPON and itemSubClassID==LE_ITEM_WEAPON_THROWN and 2) or 0
				},"inv");
				if link and link:find("%[%]") then
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
			return;
		end
		inventoryDelayed = false;
	end

	local function scanBags()
		for bagIndex,bool in pairs(updateBags) do
			bagIndex=tonumber(bagIndex)
			if bagIndex and bool==true then
				local numBagSlots = (C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots)(bagIndex);
				local numFreeSlots = (C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots)(bagIndex);
				local IndexTabardType =  INVTYPE_TABARD or Enum.InventoryType.IndexTabardType;
				local IndexBodyType =  INVTYPE_BODY or Enum.InventoryType.IndexBodyType;
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
						local itemInfo, count, _, _, _, _, link, _, _, id = (C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo)(bagIndex,slotIndex);
						if not count and type(itemInfo)=="table" then
							count = itemInfo.stackCount;
							link = itemInfo.hyperlink;
						end
						if link and not id then
							id = tonumber((link:match("item:(%d+)"))) or -1;
						end
						if link and id then
							local _, _, _, itemEquipLocation, _, itemClassID, itemSubClassID = GetItemInfoInstant(link); -- equipment in bags; merchant repair all function will be repair it too
							local durability, durabilityMax = (C_Container and C_Container.GetContainerItemDurability or GetContainerItemDurability)(bagIndex,slotIndex)
							local isEquipment = false;
							if not (itemEquipLocation=="" or itemEquipLocation==IndexTabardType or itemEquipLocation==IndexBodyType) then
								isEquipment = true; -- ignore shirts and tabards
							end
							addItem({
								bag=bagIndex,
								slot=slotIndex,
								count=count,
								sharedSlot=sharedSlotIndex,
								id=id,
								link=link,
								diff=table.concat({link,count,durability, durabilityMax},"^"),
								equip=isEquipment,
								ammo=(itemClassID==LE_ITEM_CLASS_PROJECTILE and 1) or (itemClassID==LR_ITEM_CLASS_WEAPON and itemSubClassID==LE_ITEM_WEAPON_THROWN and 2) or 0
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
		end
		wipe(updateBags);
		callbackHandler();
	end

	local inventoryEvents = {
		PLAYER_LOGIN = true,
		PLAYER_EQUIPMENT_CHANGED = true,
		UPDATE_INVENTORY_DURABILITY = true,
		UNIT_INVENTORY_CHANGED = true,
		ITEM_UPGRADE_MASTER_UPDATE = true,
		MERCHANT_CLOSED = true
	};

	local function tableLength(t)
		local c,_ = 0;
		for _ in pairs(t) do
			c=c+1;
		end
		return c;
	end

	local function OnEvent(self,event,...)
		if event=="BAG_UPDATE" and tonumber(...) and (...)<=NUM_BAG_SLOTS then
			updateBags[tostring(...)] = true
		elseif event=="BAG_UPDATE_DELAYED" and tableLength(updateBags)>0 then
			scanBags();
		elseif event=="PLAYER_LOGIN" then
			updateBags["0"] = true; -- BAG_UPDATE fired with 1-12 as bag index (argument) before PLAYER_LOGIN; bag index 0 is missing
			scanBags();
		elseif event=="GET_ITEM_INFO_RECEIVED" and (...)~=nil then
			local id = ...;
			if itemsByID[id] then
				local _, spell = GetItemSpell(id);
				if spell then
					for sharedSlot, info in pairs(itemsByID[...])do
						local _, count, _, _, _, _, _, _, _ = (C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo)(info.bag,info.slot);
						info.spell = spell;
						itemsBySpell[spell][sharedSlot] = count;
					end
				end
			elseif callbacks.toys[id] and PlayerHasToy then
				local toyName, _, _, _, _, _, _, _, _, toyIcon = GetItemInfo(id);
				local hasToy = PlayerHasToy(id);
				local canUse = C_ToyBox.IsToyUsable(id);
				if toyName and hasToy and canUse then
					callbacks.toys[id](id,toyIcon,toyName);
				end
			end
		elseif inventoryEvents[event] and not inventoryDelayed then
			if event=="UNIT_INVENTORY_CHANGED" and (...)~="player" then
				return;
			end
			inventoryDelayed = true;
			C_Timer.After(0.5,scanInventory);
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
			updateBags = {["0"]=true,["1"]=true,["2"]=true,["3"]=true,["4"]=true};
			OnEvent(eventFrame,"BAG_UPDATE_DELAYED");
		end
	end

	local function initInventory()
		if IsEnabledInv then return end
		IsEnabledInv = true;

		-- inventory events
		eventFrame:RegisterEvent("PLAYER_LOGIN")
		eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
		eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY");
		eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED");
		eventFrame:RegisterEvent("MERCHANT_CLOSED");
		if ns.ammo_classic then
			eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED");
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
		assert(type(callbacks[mode])=="table", "argument #3 must be 'any', 'inv', 'bags', 'item', 'spell', 'equip', 'toys' or 'prepare'.");
		if mode=="item" then
			assert(type(id)=="number","argument #4 must be number, got "..type(id));
			if callbacks.item[id]==nil then
				callbacks.item[id] = {};
			end
			callbacks.item[id][modName] = func;
		else
			callbacks[mode][modName] = func;
		end
		cbCounter[mode] = cbCounter[mode] + 1;
		ns.items.Init(mode);
	end

	function ns.items.GetBagSlot(sharedSlotIndex)
		if sharedSlotIndex<0 then
			return false, sharedSlotIndex*100
		end
		local bagIndex,slotIndex = floor(sharedSlotIndex);
		slotIndex = (sharedSlotIndex-bagIndex)*100
		return bagIndex,slotIndex;
	end
end


-- -------------------------------------------------------------- --
-- UseContainerItem hook
-- -------------------------------------------------------------- --
do
	local callback = {};
	local function UseContainerItemHook(bag, slot)
		if bag and slot then
			local itemId = tonumber(((C_Container and C_Container.GetContainerItemLink or GetContainerItemLink)(bag,slot) or ""):match("Hitem:([0-9]+)"));
			if itemId and callback[itemId] then
				for _,entry in pairs(callback[itemId])do
					if type(entry.callback)=="function" then
						entry.callback(bag,slot,itemId,entry.info);
					end
				end
			end
		end
	end
	if C_Container and C_Container.UseContainerItem then
		hooksecurefunc(C_Container,"UseContainerItem",UseContainerItemHook);
	elseif UseContainerItem then
		hooksecurefunc("UseContainerItem",UseContainerItemHook);
	end
	ns.UseContainerItemHook = {
		registerItemID = function(modName,itemId,callbackFunc,info)
			if callback[itemId]==nil then
				callback[itemId] = {};
			end
			callback[itemId][modName] = {callback=callbackFunc,info=info};
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
	local ITEM_UPGRADE_TOOLTIP_1 = strsplit(":",ITEM_UPGRADE_TOOLTIP_FORMAT)..CHAT_HEADER_SUFFIX;
	local ITEM_UPGRADE_TOOLTIP_2 = ITEM_UPGRADE_TOOLTIP_FORMAT_STRING and strsplit(":",ITEM_UPGRADE_TOOLTIP_FORMAT_STRING)..CHAT_HEADER_SUFFIX or false;
	for f, v in pairs({SetScale=0.0001,SetAlpha=0,Hide=true,SetClampedToScreen=false,SetFrameStrata="BACKGROUND",ClearAllPoints=true})do
		QueueModeScanTT[f](QueueModeScanTT,v);
		InstantModeScanTT[f](InstantModeScanTT,v);
	end
	-- remove scripts from tooltip... prevents taint log spamming.
	local badScripts = {"OnLoad","OnHide","OnTooltipSetDefaultAnchor","OnTooltipCleared"};
	if ns.client_version<=9 then
		tinsert(badScripts,"OnTooltipAddMoney");
	end
	for _,v in ipairs(badScripts)do
		QueueModeScanTT:SetScript(v,nil);
		InstantModeScanTT:SetScript(v,nil);
	end

	ns.ScanTT = {};
	local queries = {};
	local ticker = nil;
	local duration = 0.05;
	local try = 0;

	local function GetLinkData(link)
		if not link then return end
		local _,_,_,link = link:match("|c(%x*)|H([^:]*):(%d+):(.+)|h%[([^%[%]]*)%]|h|r");
		link = {strsplit(_G["HEADER_COLON"],link or "")};
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

		tt:SetOwner(UIParent,"ANCHOR_NONE");
		tt:SetPoint("RIGHT",UIParent,"LEFT",0,0);

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
				data.link = (C_Container and C_Container.GetContainerItemLink or GetContainerItemLink)(data.bag,data.slot);
			end
			data.linkData = GetLinkData(data.link);
			data.itemName, data.itemLink, data.itemRarity, data.itemLevel, data.itemMinLevel, data.itemType, data.itemSubType, data.itemStackCount, data.itemEquipLoc, data.itemTexture, data.itemSellPrice = GetItemInfo(data.link);
			data.startTime, data.duration, data.isEnabled = (C_Container and C_Container.GetContainerItemCooldown or GetContainerItemCooldown)(data.bag,data.slot);
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
			if not data.link then
				data.link = "item:"..data.id;
			end
		elseif data._type=="quest" then
			data._type="link";
			if not data.link then
				data.link = "quest:"..data.id.._G["HEADER_COLON"]..(data.level or 0);
			end
		end

		if data._type=="link" and data.link then
			data.str = data.link;
			tt:SetHyperlink(data.link);
		end

		try = try + 1;
		if try>8 then try=0; end

		tt:Show();

		local regions = {tt:GetRegions()};

		data.lines={};
		for _,v in ipairs(regions) do
			if (v~=nil) and (v:GetObjectType()=="FontString")then
				local str = strtrim(v:GetText() or "");
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
				elseif data.lines[i]:find(ITEM_UPGRADE_TOOLTIP_1) then
					data.upgrades = data.lines[i]:gsub(ITEM_UPGRADE_TOOLTIP_1,"")
				elseif ITEM_UPGRADE_TOOLTIP_2 and data.lines[i]:find(ITEM_UPGRADE_TOOLTIP_2) then
					data.upgrades = data.lines[i]:gsub(ITEM_UPGRADE_TOOLTIP_2,"")
				elseif i>4 and data.setname==nil and data.lines[i]:find("%(%d*/%d*%)$") then
					data.setname = strsplit("(",data.lines[i]);
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
	local zz,tex,stop="%02d","|TInterface\\MoneyFrame\\UI-%sIcon:14:14:2:0|t",false;
	opts,amount = opts or {},tonumber(amount) or 0;

	-- color option
	opts.color = (opts.color or ns.profile.GeneralOptions.goldColor):lower();
	local colors = (opts.color=="white" and {"white","white","white"}) or (opts.color=="color" and {"copper","silver","gold"}) or false;

	-- goin icon option
	opts.coins = opts.coins or ns.profile.GeneralOptions.goldCoins;

	-- hide option
	local hideMoney = tonumber(ns.profile.GeneralOptions.goldHide) or 0;
	opts.hideMoney = tonumber(opts.hideMoney or 0);
	if opts.hideMoney>0 then
		hideMoney = opts.hideMoney; -- override general option by module option
	end
	local gold, silver, copper, t = floor(amount/10000), mod(floor(amount/100),100), mod(floor(amount),100), {};
	local showSilver,showCopper = (gold>0 or silver>0),true;

	if hideMoney==1 then -- Hide Copper values
		showCopper = false;
	elseif hideMoney==2 then -- Hide Silver & copper
		showSilver = false;
		showCopper = false;
	elseif hideMoney==3 then -- Hide zeros values
		showSilver = (silver>0);
		showCopper = (not showSilver or copper>0);
	elseif hideMoney==4 then -- show highest value only
		showSilver = (gold==0 and silver>0);
		showCopper = (gold==0 and silver==0 and copper>0);
	end

	if gold>0 then
		local str = tostring(ns.FormatLargeNumber(modName,gold,opts.inTooltip) or "white");
		tinsert(t, (colors and ns.LC.color(colors[3],str) or str) .. (opts.coins and tex:format("Gold") or "") );
		if hideMoney==4 then
			stop = true;
		end
	end

	if showSilver and (not stop) then
		local str = tostring(gold>0 and zz:format(silver) or silver);
		tinsert(t, (colors and ns.LC.color(colors[2],str) or str) .. (opts.coins and tex:format("Silver") or "") );
		if hideMoney==4 then
			stop = true;
		end
	end

	if showCopper and (not stop) then
		local str = tostring((silver>0 or gold>0) and zz:format(copper) or copper);
		tinsert(t, (colors and ns.LC.color(colors[1],str) or str) .. (opts.coins and tex:format("Copper") or "") );
	end

	return tconcat(t,opts.sep or " ");
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
	local EasyMenu = LDDM.Create_DropDownMenu(addon.."_LibDropDownMenu",UIParent);
	ns.EasyMenu = EasyMenu;
	EasyMenu.menu, EasyMenu.controlGroups,EasyMenu.IsPrevSeparator = {},{},false;
	local grpOrder = {"broker","tooltip","misc","ClickOpts"};

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
			local chk,fnc = nil,nil;
			if (d.beModName) then
				function chk() return (ns.profile[d.beModName][d.beKeyName]) end;
				function fnc() ns.profile[d.beModName][d.beKeyName] = not ns.profile[d.beModName][d.beKeyName]; end;
			else
				function chk() return (ns.profile.GeneralOptions[d.beKeyName]) end;
				function fnc() ns.profile.GeneralOptions[d.beKeyName] = not ns.profile.GeneralOptions[d.beKeyName]; end;
			end
			d.checked = chk;
			d.func = fnc;
		end,
		slider = function(...)
		end,
		num = function(D)
			--[[if (D.cvarKey) then
			elseif type(D.cvars)=="table" then

			end]]
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
		local i,_ = 0,nil;
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

	---@param Data table
	---@param Parent? frame
	---@return frame|nil Parent
	function EasyMenu:AddEntry(Data,Parent)
		local entry= {};

		if (type(Data)=="table") and (#Data>0) then -- numeric table = multible entries
			self.IsPrevSeparator = false;
			for _,childEntry in ipairs(Data) do
				self:AddEntry(childEntry,Parent);
			end
			return;

		elseif (Data.childs) then -- child elements
			self.IsPrevSeparator = false;
			local parent = self:AddEntry({ label=Data.label, arrow=true, disabled=Data.disabled },Parent);
			for _,v in ipairs(Data.childs) do
				self:AddEntry(v,parent);
			end
			return;

		elseif (Data.groupName) and (Data.optionGroup) then -- similar to childs but with group control
			self.IsPrevSeparator = false;
			if (self.controlGroups[Data.groupName]==nil) then
				self.controlGroups[Data.groupName] = {};
			else
				wipe(self.controlGroups[Data.groupName])
			end
			local parent = self:AddEntry({ label=Data.label, arrow=true, disabled=Data.disabled },Parent);
			parent.controlGroup=self.controlGroups[Data.groupName];
			for _,v in ipairs(Data.optionGroup) do
				tinsert(self.controlGroups[Data.groupName],self:AddEntry(v,parent));
			end
			return;

		elseif (Data.separator) then -- separator line (decoration)
			if self.IsPrevSeparator then
				return;
			end
			self.IsPrevSeparator = true;
			entry = { text = "", dist = 0, isTitle = true, notCheckable = true, isNotRadio = true, sUninteractable = true, iconOnly = true, icon = "Interface\\Common\\UI-TooltipDivider-Transparent", tCoordLeft = 0, tCoordRight = 1, tCoordTop = 0, tCoordBottom = 1, tFitDropDownSizeX = true, tSizeX = 0, tSizeY = 8 };
			entry.iconInfo = entry;

		else
			self.IsPrevSeparator = false;
			entry.isTitle          = Data.title     or false;
			entry.hasArrow         = Data.arrow     or false;
			entry.disabled         = Data.disabled  or false;
			entry.notClickable     = not not Data.noclick;
			entry.isNotRadio       = not Data.radio;
			entry.keepShownOnClick = true;
			entry.noClickSound     = true;
			entry.showNewLabel     = Data.new or false;

			if (Data.keepShown==false) then
				entry.keepShownOnClick = false;
			end

			if (Data.cvarType) and (Data.cvar) and (type(Data.cvarType)=="string") and (cvarTypeFunc[Data.cvarType]) then
				cvarTypeFunc[Data.cvarType](Data);
			end

			if (Data.beType) and (Data.beKeyName) and (type(Data.beType)=="string") and (beTypeFunc[Data.beType]) then
				beTypeFunc[Data.beType](Data);
			end

			if (Data.checked~=nil) then
				entry.checked = Data.checked;
				if (entry.keepShownOnClick==nil) then
					entry.keepShownOnClick = false;
				end
			else
				entry.notCheckable = true;
			end

			entry.text = Data.label or "";

			if (Data.colorName) then
				entry.colorCode = "|c"..ns.LC.color(Data.colorName);
			elseif (Data.colorCode) then
				entry.colorCode = entry.colorCode;
			end

			if (Data.tooltip) and (type(Data.tooltip)=="table") then
				entry.tooltipTitle = ns.LC.color("dkyellow",Data.tooltip[1]);
				if type(Data.tooltip[2])=="string" and Data.tooltip[2]~="" then
					entry.tooltipText = ns.LC.color("white",Data.tooltip[2]);
				end
				entry.tooltipOnButton=1;
			end

			if (Data.icon) then
				entry.text = entry.text .. "    ";
				entry.icon = Data.icon;
				entry.tCoordLeft, entry.tCoordRight = 0.05,0.95;
				entry.tCoordTop, entry.tCoordBottom = 0.05,0.95;
			end

			if (Data.func) then
				entry.arg1 = Data.arg1;
				entry.arg2 = Data.arg2;
				function entry.func(...)
					Data.func(...)
					if (type(Data.event)=="function") then
						Data.event();
					end
					if (Parent) and (not entry.keepShownOnClick) then
						LibCloseDropDownMenus();
					end
				end;
			end

			if (not Data.title) and (not Data.disabled) and (not Data.arrow) and (not Data.checked) and (not Data.func) then
				entry.disabled = true;
			end
		end

		if (Parent) and (type(Parent)=="table") then
			if (not Parent.menuList) then Parent.menuList = {}; end
			tinsert(Parent.menuList, entry);
			return Parent.menuList[#Parent.menuList];
		else
			tinsert(self.menu, entry);
			return self.menu[#self.menu];
		end
	end
	local function setTooltip(name,desc)
		local tooltip = nil;
		if desc then
			tooltip = {name, desc};
			if type(tooltip[2])=="function" then
				tooltip[2] = tooltip[2]();
			end
		end
		return tooltip
	end
	---@param modName string module name
	---@param key string
	---@param value table
	---@param Parent? table
	function EasyMenu:AddConfigEntry(modName,info,key,value,Parent)
		local info = CopyTable(info)
		local value_name = value.name
		if value_name and type(value_name)=="function" then
			value_name = value_name({key});
		end
		local new_features = ns.modules[modName].new_features and ns.modules[modName].new_features[key];

		if value.type=="separator" then
			self:AddEntry({ separator=true },Parent);
		elseif value.type=="header" then
			self:AddEntry({ separator=true },Parent);
			self:AddEntry({ label=value_name, title=true },Parent);
		elseif value.type=="toggle" and not value_name then
			ns:debug("<EasyMenu>","<AddConfigEntry>","[missing name]",key);
		elseif value.type=="toggle" then
			self:AddEntry({
				label = value_name:gsub("|n"," "),
				new = new_features,
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
				tooltip = setTooltip(value_name,value.desc),
			},Parent);
		elseif value.type=="select" then
			local p = self:AddEntry({
				label = value_name,
				tooltip = setTooltip(value_name,value.desc),
				arrow = true
			},Parent);
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
		elseif value.type=="color" then
			local cur = ns.profile[modName][key]
			local p = self:AddEntry({
				label = value_name,
				new = new_features,
				hasOpacity = value.hasAlpha,
				hasColorSwatch = true,
				r = cur[1],
				g = cur[2],
				b = cur[3],
				opacity = cur[4] or 1,
				swatchFunc = function()
					local r,g,b = ColorPickerFrame:GetColorRGB()
					local colorTable = {r,g,b};
					if value.hasAlpha then
						colorTable[4] = ColorPickerFrame:GetColorAlpha()
					end
					ns.option({modName,"",key},colorTable)
				end,
				cancelFunc = function()
					local colorTable = {
						ColorPickerFrame.previousValues.r,
						ColorPickerFrame.previousValues.g,
						ColorPickerFrame.previousValues.b,
					}
					if value.hasAlpha then
						colorTable[4] = ColorPickerFrame.previousValues.a;
					end
					ns.option({modName,"",key},colorTable)
				end,
				tooltip = setTooltip(value_name,value.desc)
			},Parent);
		elseif value.type=="group" then
			local parent = self:AddEntry({
				label = value_name,
				new = new_features,
				tooltip = setTooltip(value_name,value.desc),
				arrow = true,
			},Parent);
			for _key, _value in pairsByAceOptions(value.args) do
				tinsert(info,_key)
				self:AddConfigEntry(modName,info,_key,_value,parent);
			end
		elseif value.type=="range" then
			-- coming soon
		end
	end

	---@param modName string module name
	---@param noTitle? boolean
	function EasyMenu:AddConfig(modName,noTitle)
		local options,separator = ns.getModOptionTable(modName);
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
						local info = {key}
						local hide = (value.hidden==true) or (value.disabled==true) or false;
						if not hide and type(value.hidden)=="function" then
							hide = value.hidden(info,"EasyMenu");
							if hide==true or hide=="EasyMenu" then
								hide = true;
							end
						end
						if not hide and type(value.disabled)=="function" then
							hide = value.disabled(info);
						end

						if not hide then
							self:AddConfigEntry(modName,info,key,value);
						end
					end

				end
			end
		end
	end

	---@param level number
	function EasyMenu:Refresh(level)
		-- local self = ns.EasyMenu
		if level then
			LDDM.UIDropDownMenu_Refresh(self,nil,level);
		end
		LDDM.UIDropDownMenu_RefreshAll(self);
	end

	function EasyMenu:InitializeMenu()
		wipe(self.menu);
	end

	---@param parent? frame|string
	---@param parentX? number
	---@param parentY? number
	function EasyMenu:ShowMenu(parent, parentX, parentY)
		if openTooltip then
			ns.hideTooltip(openTooltip);
		end

		self:AddEntry({separator=true});
		self:AddEntry({label=L["Close menu"], func=LibCloseDropDownMenus});

		LDDM.EasyMenu(self.menu, self, parent or "cursor", parentX or 0, parentY or 0, "MENU");
	end
end


-- ----------------------- --
-- DurationOrExpireDate    --
-- ----------------------- --
---@param timeLeft number
---@param lastTime number
---@param durationTitle string
---@param expireTitle string
---@return string|osdate
---@return string
---@return string
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
	local iLabel,iSource,iFunction,iPrefix = 1,2,3,4;

	function ns.ClickOpts.func(self,button,modName)
		local mod = ns.modules[modName];
		if not (mod and mod.onclick) then return; end

		-- click(plan)A = combine modifier if pressed with named button (left,right)
		-- click(panl)B = combine modifier if pressed with left or right mouse button without expliced check.
		local clickA,clickB,action,actName="","",nil,nil;

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
			action = mod.clickOptions[actName];
		elseif (mod.onclick[clickB]) then
			actName = mod.onclick[clickB];
			action = mod.clickOptions[actName];
		end

		if action then
			local func
			if action[iSource]=="direct" then
				func = action[iFunction];
			elseif action[iSource]=="module" then
				func = mod[action[iFunction]];
			elseif action[iSource]=="namespace" then
				func = ns[action[iFunction]];
			elseif action[iSource]=="shared" then
				func = shared[action[iFunction]];
			elseif action[iSource]=="call" then
				if type(action[iFunction])=="table" then
					if action[iFunction][1]=="ToggleFrame" then
						securecall("ToggleFrame",_G[action[iFunction][2]]);
						return;
					end
					securecall(unpack(action[iFunction]));
				else
					securecall(action[iFunction]);
				end
				return;
			end
			if func then
				func(self,button,modName,actName);
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
			local action = mod.clickOptions[actName];
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
				local functionType,func = action[iSource];
				if functionType=="direct" then
					func = action[iFunction];
				elseif functionType=="module" then
					func = mod[action[iFunction]];
				elseif functionType=="namespace" then
					func = ns[action[iFunction]];
				elseif functionType=="shared" then
					func = shared[action[iFunction]];
				elseif functionType=="call" then
					func = _G[type(action[iFunction])=="table" and action[iFunction][1] or action[iFunction]];
				end
				if func and type(func)=="function" then
					mod.onclick[key] = actName;
					tinsert(mod.clickHints,ns.LC.color("copper",values[key]).." || "..ns.LC.color("green",L[action[iLabel]]));
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
---@param num number
---@param values table
---@param colors table
---@param Char string
---@return string
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
-- Retail / Classic / BC Classic compatibility
-- -------------------------------

ns.C_QuestLog_GetInfo = (C_QuestLog and C_QuestLog.GetInfo) or function(questLogIndex)
	-- 10/22/2003: Not present in Classic and Classic Era
	local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory, isHidden, isScaling  = GetQuestLogTitle(questLogIndex);
	if type(suggestedGroup)=="string" then
		suggestedGroup = tonumber(suggestedGroup) or 0; -- problem on bc classic client?
	end
	return {
		campaignID = 0, -- dummy
		difficultyLevel = 0, -- dummy
		frequency = frequency,
		hasLocalPOI = hasLocalPOI,
		isAutoComplete = false, -- dummy
		isBounty = false, -- dummy
		isCollapsed = isCollapsed,
		isComplete = isComplete, -- missing in C_QuestLog.GetInfo ?
		isHeader = isHeader,
		isHidden = isHidden,
		isOnMap = isOnMap,
		isScaling = isScaling,
		isStory = isStory,
		isTask = isTask,
		level = level,
		overridesSortOrder = false, -- dummy
		questID = questID,
		questLogIndex = questLogIndex,
		readyForTranslation = false, -- dummy
		startEvent = startEvent,
		suggestedGroup = suggestedGroup,
		title = title,
	};
end

ns.C_QuestLog_GetQuestTagInfo = (C_QuestLog and C_QuestLog.GetQuestTagInfo) or function(questID)
	-- 10/22/2003: Not present in Classic and Classic Era
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(questID);
	return {
		tagID = tagID,
		tagName = tagName,
		-- not found in returned table from C_QuestLog.GetQuestTagInfo
		worldQuestType = worldQuestType,
		rarity = rarity,
		isElite = isElite,
		tradeskillLineIndex = tradeskillLineIndex
	};
end
