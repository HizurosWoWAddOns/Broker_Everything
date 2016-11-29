
-- saved variables
Broker_Everything_ProfileDB = {}; -- config data
Broker_Everything_CharacterDB = {}; -- per character data
Broker_Everything_DataDB = {}; -- global data
Broker_EverythingDB = nil;  -- deprecated
Broker_EverythingGlobalDB = nil; -- deprecated
be_character_cache = nil; -- deprecated

-- some usefull namespace to locals
local addon, ns = ...;
local C, L = ns.LC.color, ns.L;
ns.coexist = { names = { "Carbonite", "DejaMinimap", "Chinchilla", "Dominos_MINIMAP", "gUI4_Minimap", "LUI", "MinimapButtonFrame", "SexyMap", "SquareMap" }, found = false };

local function profile_change(name,action)
	if action=="del" then
		local new = nil;
		if Broker_Everything_ProfileDB.use_default_profile then
			if Broker_Everything_ProfileDB.default_profile==name then
				ns.print(L["Error"],L["Default profiles can not be deleted"]);
				return;
			else
				new = Broker_Everything_ProfileDB.default_profile;
			end
		end
		Broker_Everything_ProfileDB.profiles[name]=new;
		for i,v in pairs(Broker_Everything_ProfileDB.use_profile)do
			if v==name then
				Broker_Everything_ProfileDB.use_profile[i]=new;
			end
		end
	elseif action=="switch" then
		Broker_Everything_ProfileDB.use_profile[ns.player.name_realm] = name;
		ReloadUI();
	elseif action=="rename" then
		if Broker_Everything_ProfileDB.profiles[name]~=nil then
			ns.print(L["Error"], L["This profile name are already exists"]);
			return;
		end
		local oldName = Broker_Everything_ProfileDB.use_profile[ns.player.name_realm];
		Broker_Everything_ProfileDB.profiles[name] = Broker_Everything_ProfileDB.profiles[oldName];
		Broker_Everything_ProfileDB.profiles[oldName] = nil;
		for i,v in pairs(Broker_Everything_ProfileDB.use_profile)do
			if v == oldName then
				Broker_Everything_ProfileDB.use_profile[i] = name;
			end
		end
	elseif action=="new" then
		if Broker_Everything_ProfileDB.profiles[name]~=nil then
			ns.print(L["Error"], L["This profile name are already exists"]);
			return;
		end
		Broker_Everything_ProfileDB.profiles[name]={};
		Broker_Everything_ProfileDB.use_profile[ns.player.name_realm] = name;
		ReloadUI();
	elseif action=="copy" then
		Broker_Everything_ProfileDB.profiles[Broker_Everything_ProfileDB.use_profile[ns.player.name_realm]] = CopyTable(Broker_Everything_ProfileDB.profiles[name]);
		ReloadUI();
	elseif action=="default" then
		local oldDefault = Broker_Everything_ProfileDB.default_profile;
		Broker_Everything_ProfileDB.default_profile = name;
		for i,v in pairs(Broker_Everything_ProfileDB.use_profile)do
			if v==oldDefault then
				Broker_Everything_ProfileDB.use_profile[i]=name;
			end
		end
	end
end


------------------
-- core options --
------------------

local ttModifierValues = {NONE = L["Default (no modifier)"]};
for i,v in pairs(ns.tooltipModifiers) do ttModifierValues[i] = v.l; end

local function getIconSets()
	local t = {NONE=NONE}
	local l = ns.LSM:List((addon.."_Iconsets"):lower())
	if type(l)=="table" then
		for i,v in pairs(l) do
			t[v] = v
		end
	end
	return t
end

ns.defaultGeneralOptions = {
	suffixColour = true,
	tooltipScale = false,
	showHints = true,
	libdbicon = false,
	iconset = "NONE",
	iconcolor = C("white","colortable"),
	goldColor = false,
	usePrefix = false,
	maxTooltipHeight = 60,
	scm = false,
	ttModifierKey1 = "NONE",
	ttModifierKey2 = "NONE",
	goldHideCopper = false,
	goldHideSilver = false,
	goldHideLowerZeros = false,
	separateThousands = true,
	showAddOnLoaded = true
};

ns.coreOptions = { -- option panel builder table
	{type="separator", alpha=0, height=7 },

	{type="header",    label=L["Profiles"]},
	{type="separator", alpha=1 },
	{type="select", label=L["Select a profile"], tooltip=C("orange",L["This will be automatically perform an UI reload!"]),
		get=function()
			local current, values = Broker_Everything_ProfileDB.use_profile[ns.player.name_realm],{};
			for name,data in pairs(Broker_Everything_ProfileDB.profiles)do
				values[name] = {label=name,title=(name==current)};
			end
			return current, values, NONE;
		end,
		set=function(v)
			profile_change(v,"switch");
		end,
		keepShown=false
	},
	--[[
	{type="input",  label=L["Rename profile"], tooltip=L["Rename profile"],
		get=function() return ""; end,
		set=function(v) profile_change(v,"rename"); end
	},
	--]]
	{type="input",  label=L["Create new profile"], tooltip=C("orange",L["This will be automatically perform an UI reload!"]),
		get=function() return ""; end,
		set=function(v) profile_change(v,"new"); end
	},
	{type="select", label=L["Copy profile data"],   tooltip={L["Choose an exists profile to copy its data into the current profile"],C("orange",L["This will be automatically perform an UI reload!"])},
		get=function()
			local current,values = Broker_Everything_ProfileDB.use_profile[ns.player.name_realm],{};
			for name,data in pairs(Broker_Everything_ProfileDB.profiles)do
				values[name] = {label=name,disabled=(name==current)};
			end
			return "", values, "";
		end,
		set=function(v) profile_change(v,"copy"); end,
		keepShown=false
	},
	{type="select", label=L["Delete a profile"], tooltip=L["Choose an exists profile to delete it"],
		get=function()
			local current,values,default = Broker_Everything_ProfileDB.use_profile[ns.player.name_realm],{};
			for name,data in pairs(Broker_Everything_ProfileDB.profiles)do
				values[name] = {label=name,disabled=(name==current or name==Broker_Everything_ProfileDB.default_profile)};
			end
			return "", values, "";
		end,
		set=function(v) profile_change(v,"del"); end,
		keepShown=false
	},
	{type="toggle", label=L["Use default profile"], tooltip=L["Use default profile for new characters"],
		get=function() return Broker_Everything_ProfileDB.use_default_profile; end,
		set=function(v) Broker_Everything_ProfileDB.use_default_profile=v; end
	},
	{type="select", label=L["Select default profile"], tooltip=L["Choose an exists profile as default profile"],
		get=function()
			local current,values = Broker_Everything_ProfileDB.default_profile,{};
			for name,data in pairs(Broker_Everything_ProfileDB.profiles)do
				values[name] = {label=name,title=(name==current)};
			end
			return current, values, "";
		end,
		set=function(v) profile_change(v,"default"); end,
		keepShown=false
	},

	{type="separator", alpha=0 },

	{type="header",    label=L["Misc options"]},
	{type="separator", alpha=1 },
	{type="toggle",    name="suffixColour",   label=L["Suffix coloring"], tooltip=L["Enable/Disable class coloring of the information display suffixes. (eg, ms, fps etc)"]},
	{type="toggle",    name="showAddOnLoaded",label=L["Show 'AddOn Loaded...'"], tooltip=L["Show 'AddOn Loaded...' message on logins and UI reloads"]},

	{type="separator", alpha=0 },

	{type="header",    label=L["Money display options"]},
	{type="separator", alpha=1 },
	{type="toggle",    name="goldColor",          label=L["Gold coloring"],      tooltip=L["Use colors instead of icons for gold, silver and copper"]},
	{type="toggle",    name="goldHideCopper",     label=L["Hide copper"],        tooltip=L["Hide copper values of your money"]},
	{type="toggle",    name="goldHideSilver",     label=L["Hide silver"],        tooltip=L["Hide copper and silver values of your money"]},
	{type="toggle",    name="goldHideLowerZeros", label=L["Hide lower zeros"],   tooltip=L["Hide lower zero values of your money"]},
	{type="toggle",    name="separateThousands",  label=L["Separate thousands"], tooltip=L["Separate thousands on displayed gold and other numeric values"]},

	{type="separator", alpha=0 },

	{type="header",    label=L["DataBroker options"]},
	{type="separator", alpha=1 },
	{type="toggle",    name="usePrefix",      label=L["Use prefix"], tooltip=L["Use prefix 'BE..' on module registration at LibDataBroker. This fix problems with other addons with same broker names but effect your current settings in panel addons like Bazooka or Titan Panel."]},
	{type="toggle",    name="libdbicon",      label=L["Broker as Minimap Buttons"], tooltip=L["Use LibDBIcon to add Broker to Minimap"]},

	{type="separator", alpha=0 },

	{type="header",    label=L["Tooltip options"]},
	{type="separator", alpha=1 },
	{type="toggle",    name="tooltipScale",   label=L["Tooltip Scaling"], tooltip=L["Scale the tooltips with your UIScale."]},
	{type="toggle",    name="scm",            label=L["Screen capture mode"], tooltip=L["The screen capture mode replaces all characters of a name with wildcards (*) without the first. Your chars in XP, your friends battleTags/RealID and there character names and the character names in your guild and there notes."]},
	{type="toggle",    name="showHints",      label=L["Show hints"], tooltip=L["Show hints in tooltips."]},
	{type="slider",    name="maxTooltipHeight", min=10, max=90, default=60, format="%d", pat="%d%%", label=L["Max. Tooltip height"], tooltip=L["Adjust the maximum of tooltip height in percent of your screen height."]},
	{type="select",    name="ttModifierKey1", values=ttModifierValues, default="NONE", label=L["Show tooltip"], tooltip=L["Hold modifier key to display tooltip"]},
	{type="select",    name="ttModifierKey2", values=ttModifierValues, default="NONE", label=L["Allow mouseover"], tooltip=L["Hold modifier key to use mouseover in tooltip"]},

	{type="separator", alpha=0 },

	{type="header",    label=L["Icon options"]},
	{type="separator", alpha=1 },
	{type="select",    name="iconset", values=getIconSets(), default="NONE", label=L["Iconsets"], tooltip=L["Choose an custom iconset"]},
	{type="color",     name="iconcolor", default=C("white","colortable"), opacity=true, label=L["Icon color"], tooltip=L["Change the color of the icons"]},
	{type="separator", alpha=0, height=20 },
};


----------------------
-- core event frame --
----------------------
local Broker_Everything = CreateFrame("Frame");

function ns.resetAllSavedVariables()
	local sv={"Broker_EverythingGlobalDB","Broker_EverythingDB","Broker_Everything_ProfileDB","Broker_Everything_DataDB","be_durability_db"};
	for i,v in ipairs(sv) do
		if (type(_G[v])=="table") then
			wipe(_G[v]);
		end
	end
end

function ns.resetConfigs()
	if Broker_EverythingDB~=nil then
		wipe(Broker_EverythingDB);
	end
	if Broker_EverythingGlobalDB~=nil then
		wipe(Broker_EverythingGlobalDB);
	end
	wipe(Broker_Everything_ProfileDB);
	wipe(Broker_Everything_DataDB);
end

Broker_Everything:SetScript("OnEvent", function (self, event, addonName)
	if event == "ADDON_LOADED" and addonName == addon then
		local migrate = false;

		if Broker_Everything_ProfileDB==nil then
			Broker_Everything_ProfileDB = {};
		end

		for k,v in pairs({
			use_default_profile=false,
			default_profile=DEFAULT,
			profiles={[DEFAULT]={}},
			use_profile={}
		})do
			if Broker_Everything_ProfileDB[k]==nil or type(Broker_Everything_ProfileDB[k])==type(v) then
				Broker_Everything_ProfileDB[k]=v;
				if k=="profiles" then
					migrate = true;
				end
			end
		end

		--- migration from old saved variables ---
		if migrate then
			if(type(Broker_EverythingGlobalDB)=="table" and Broker_EverythingGlobalDB.global==true)then
				Broker_Everything_ProfileDB.use_default_profile=true;
				Broker_Everything_ProfileDB.profiles[Broker_Everything_ProfileDB.default_profile] = CopyTable(Broker_EverythingGlobalDB);
				Broker_Everything_ProfileDB.use_profile[ns.player.name_realm] = DEFAULT;
			elseif Broker_Everything_ProfileDB.profiles[ns.player.name_realm]==nil then
				if type(Broker_EverythingDB)=="table" then
					Broker_Everything_ProfileDB.profiles[ns.player.name_realm] = CopyTable(Broker_EverythingDB);
				else
					Broker_Everything_ProfileDB.profiles[ns.player.name_realm] = {};
				end
				Broker_Everything_ProfileDB.use_profile[ns.player.name_realm] = ns.player.name_realm;
			end
		end
		if Broker_EverythingDB~=nil then
			Broker_EverythingDB=nil;
		end
		if Broker_EverythingGlobalDB~=nil then
			Broker_EverythingGlobalDB=nil;
		end
		---

		if Broker_Everything_ProfileDB.use_profile[ns.player.name_realm]==nil then
			Broker_Everything_ProfileDB.use_profile[ns.player.name_realm] = Broker_Everything_ProfileDB.use_default_profile and Broker_Everything_ProfileDB.default_profile or ns.player.name_realm;
		end

		if Broker_Everything_ProfileDB.profiles[Broker_Everything_ProfileDB.use_profile[ns.player.name_realm]]==nil then
			Broker_Everything_ProfileDB.profiles[Broker_Everything_ProfileDB.use_profile[ns.player.name_realm]] = {};
		end

		ns.profile = Broker_Everything_ProfileDB.profiles[Broker_Everything_ProfileDB.use_profile[ns.player.name_realm]];

		if ns.profile.GeneralOptions==nil then
			ns.profile.GeneralOptions = {};
		end

		for i,v in pairs(ns.defaultGeneralOptions) do
			if ns.profile.GeneralOptions[i]==nil then
				if ns.profile[i]~=nil then
					ns.profile.GeneralOptions[i] = ns.profile[i];
					ns.profile[i]=nil;
				else
					ns.profile.GeneralOptions[i] = v;
				end
			end
		end

		local test=ns.profile.GeneralOptions.maxTooltipHeight;
		if (test>0) and (test<1) then
			ns.profile.GeneralOptions.maxTooltipHeight = test*100;
		end

		-- character cache
		local baseData={"name","class","faction","race"};
		if be_character_cache~=nil then
			Broker_Everything_CharacterDB = be_character_cache;
			be_character_cache=nil;
		end
		if(Broker_Everything_CharacterDB==nil)then
			Broker_Everything_CharacterDB={order={}};
		end
		if(Broker_Everything_CharacterDB.order==nil)then
			Broker_Everything_CharacterDB.order={};
		end
		if(not Broker_Everything_CharacterDB[ns.player.name_realm])then
			tinsert(Broker_Everything_CharacterDB.order,ns.player.name_realm);
			Broker_Everything_CharacterDB[ns.player.name_realm] = {orderId=#Broker_Everything_CharacterDB.order};
		end
		for i,v in ipairs(baseData)do
			if(ns.player[v] and Broker_Everything_CharacterDB[ns.player.name_realm][v]~=ns.player[v])then
				Broker_Everything_CharacterDB[ns.player.name_realm][v] = ns.player[v];
			end
		end
		Broker_Everything_CharacterDB[ns.player.name_realm].level = UnitLevel("player");
		ns.toon = Broker_Everything_CharacterDB[ns.player.name_realm];

		-- data cache
		if Broker_Everything_DataDB==nil then
			Broker_Everything_DataDB = {realms={}};
		end
		if Broker_Everything_DataDB.realms==nil then
			Broker_Everything_DataDB.realms={};
		end
		Broker_Everything_DataDB.realms[ns.realm] = gsub(ns.realm," ","");
		ns.data = Broker_Everything_DataDB;

		-- modules
		ns.moduleInit();

		if ns.profile.GeneralOptions.showAddOnLoaded then
			ns.print(L["AddOn loaded..."]);
		end

		ns.pastAL = true;

		self:UnregisterEvent("ADDON_LOADED");
	elseif event == "ADDON_LOADED" and addonName == "Blizzard_ItemUpgradeUI" then
		ItemUpgradeFrameUpgradeButton:HookScript("OnClick",ns.items.UpdateNow);
		hooksecurefunc(_G,"ItemUpgradeFrame_UpgradeClick",ns.items.UpdateNow);
	elseif event == "DISPLAY_SIZE_CHANGED" then
		ns.ui = {size={UIParent:GetSize()},center={UIParent:GetCenter()}};
	elseif event=="PLAYER_ENTERING_WORLD" then
		-- iconset
		ns.I(true);
		ns.updateIcons();

		-- panels for broker and config
		ns.be_option_panel = ns.optionpanel();
		ns.be_data_panel = ns.datapanel();

		-- coexist with other addons
		for _,name in pairs(ns.coexist.names) do
			if (ns.coexist.found==false) and (GetAddOnInfo(name)) and (GetAddOnEnableState(ns.player.name,name)==2) then
				ns.coexist.found = name;
			end
		end
		ns.moduleCoexist();

		ns.pastPEW = true;

		self:UnregisterEvent(event);
	elseif(event=="PLAYER_LEVEL_UP")then
		ns.toon.level = UnitLevel("player");
	elseif (event=="NEUTRAL_FACTION_SELECT_RESULT") then
		ns.player.faction, ns.player.factionL  = UnitFactionGroup("player");
		L[ns.player.faction] = ns.player.factionL;

		ns.toon.faction = ns.player.faction;
	end
end)

Broker_Everything:RegisterEvent("ADDON_LOADED");
Broker_Everything:RegisterEvent("PLAYER_ENTERING_WORLD");
Broker_Everything:RegisterEvent("PLAYER_LEVEL_UP");
Broker_Everything:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
Broker_Everything:RegisterEvent("DISPLAY_SIZE_CHANGED");
