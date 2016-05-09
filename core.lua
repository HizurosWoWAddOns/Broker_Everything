
-- saved variables
Broker_EverythingDB = {};
Broker_EverythingGlobalDB = {};
be_character_cache = {};

-- some usefull namespace to locals
local addon, ns = ...;
local C, L = ns.LC.color, ns.L;
ns.coexist = { names = { "Carbonite", "DejaMinimap", "Chinchilla", "Dominos_MINIMAP", "gUI4_Minimap", "LUI", "MinimapButtonFrame", "SexyMap", "SquareMap" }, found = false };


------------------
-- core options --
------------------

local ttModifierValues = {NONE = L["Default (no modifier)"]};
for i,v in pairs(ns.tooltipModifiers) do ttModifierValues[i] = v.l; end

local function getIconSets()
	local t = {NONE=L["None"]}
	local l = ns.LSM:List((addon.."_Iconsets"):lower())
	if type(l)=="table" then
		for i,v in pairs(l) do
			t[v] = v
		end
	end
	return t
end

ns.coreOptionDefaults = {
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
	separateThousands = true
};

ns.coreOptions = { -- option panel builder table
	{type="separator", alpha=0, height=7 },
	{type="header", label=L["Misc options"]},
	{type="separator", alpha=1 },
	{type="toggle", name="suffixColour",       label=L["Suffix coloring"], tooltip=L["Enable/Disable class coloring of the information display suffixes. (eg, ms, fps etc)"]},
	{type="toggle", name="global",             label=L["Use global profile"], tooltip=L["Enable/Disable use of global Broker_Everything profile across all of your characters."], set=function(value)
		if value == true and Broker_EverythingGlobalDB["Clock"] == nil then
			Broker_EverythingGlobalDB = Broker_EverythingDB
		end
		Broker_EverythingGlobalDB.global = value
	end, get=function() return Broker_EverythingDB.global end, default=false},

	{type="separator", alpha=0 },

	{type="header", label=L["Money display options"]},
	{type="separator", alpha=1 },
	{type="toggle", name="goldColor",          label=L["Gold coloring"], tooltip=L["Use colors instead of icons for gold, silver and copper"]},
	{type="toggle", name="goldHideCopper",     label=L["Hide copper"], tooltip=L["Hide copper values of your money"]},
	{type="toggle", name="goldHideSilver",     label=L["Hide silver"], tooltip=L["Hide copper and silver values of your money"]},
	{type="toggle", name="goldHideLowerZeros", label=L["Hide lower zeros"], tooltip=L["Hide lower zero values of your money"]},
	{type="toggle", name="separateThousands",  label=L["Separate thousands"], tooltip=L["Separate thousands on displayed gold and other numeric values"]},

	{type="separator", alpha=0 },

	{type="header", label=L["DataBroker options"]},
	{type="separator", alpha=1 },
	{type="toggle", name="usePrefix",      label=L["Use prefix"], tooltip=L["Use prefix 'BE..' on module registration at LibDataBroker. This fix problems with other addons with same broker names but effect your current settings in panel addons like Bazooka or Titan Panel."]},
	{type="toggle", name="libdbicon",      label=L["Broker as Minimap Buttons"], tooltip=L["Use LibDBIcon to add Broker to Minimap"]},

	{type="separator", alpha=0 },

	{type="header", label=L["Tooltip options"]},
	{type="separator", alpha=1 },
	{type="toggle", name="tooltipScale",   label=L["Tooltip Scaling"], tooltip=L["Scale the tooltips with your UIScale."]},
	{type="toggle", name="scm",            label=L["Screen capture mode"], tooltip=L["The screen capture mode replaces all characters of a name with wildcards (*) without the first. Your chars in XP, your friends battleTags/RealID and there character names and the character names in your guild and there notes."]},
	{type="toggle", name="showHints",      label=L["Show hints"], tooltip=L["Show hints in tooltips."]},
	{type="slider", name="maxTooltipHeight", min=10, max=90, default=60, format="%d", pat="%d%%", label=L["Max. Tooltip height"], tooltip=L["Adjust the maximum of tooltip height in percent of your screen height."]},
	{type="select", name="ttModifierKey1", values=ttModifierValues, default="NONE", label=L["Show tooltip"], tooltip=L["Hold modifier key to display tooltip"]},
	{type="select", name="ttModifierKey2", values=ttModifierValues, default="NONE", label=L["Allow mouseover"], tooltip=L["Hold modifier key to use mouseover in tooltip"]},

	{type="separator", alpha=0 },

	{type="header", label=L["Icon options"]},
	{type="separator", alpha=1 },
	{type="select", name="iconset", values=getIconSets(), default="NONE", label=L["Iconsets"], tooltip=L["Choose an custom iconset"]},
	{type="color",  name="iconcolor", default=C("white","colortable"), opacity=true, label=L["Icon color"], tooltip=L["Change the color of the icons"]},
	{type="separator", alpha=0, height=20 },
};


----------------------
-- core event frame --
----------------------

local Broker_Everything = CreateFrame("Frame");

Broker_Everything:SetScript("OnUpdate",function(self,elapsed)
	for name, data in pairs(ns.updateList) do
		if data.interval~=nil then
			if data.interval == false then
				data.func(ns.modules[name],elapsed)
			elseif data.elapsed>=data.interval then
				data.elapsed = 0
				data.func(ns.modules[name],elapsed)
			else
				data.elapsed = data.elapsed + elapsed
			end
		end
	end
	for name, data in pairs(ns.timeoutList) do
		if data~=nil and (data.run) then
			if data.elapsed>=data.timeout then
				data.func(ns.modules[name])
				ns.timeoutList[name] = nil
			else
				data.elapsed = data.elapsed + elapsed
			end
		end
	end
end)

function ns.resetAllSavedVariables()
	local sv={"Broker_EverythingGlobalDB","Broker_EverythingDB","be_durability_db"};
	for i,v in ipairs(sv) do
		if (type(_G[v])=="table") then
			wipe(_G[v]);
		end
	end
end

function ns.resetConfigs()
	wipe(Broker_EverythingDB);
	wipe(Broker_EverythingGlobalDB);
end

Broker_Everything:SetScript("OnEvent", function (self, event, addonName)
	if event == "ADDON_LOADED" and addonName == addon then
		if (Broker_EverythingDB.reset==true) then
			ns.resetAllSavedVariables();
			Broker_EverythingDB["reset"] = false;
			ns.Print(L["Warning"], L["saved variables have been reset."]);
		end
		if (Broker_EverythingGlobalDB.global==true) then
			Broker_EverythingDB = Broker_EverythingGlobalDB;
		end

		for i,v in pairs(ns.coreOptionDefaults) do
			if (Broker_EverythingDB[i]==nil) then
				Broker_EverythingDB[i] = v;
			end
		end

		local test=Broker_EverythingDB.maxTooltipHeight;
		if (test>0) and (test<1) then
			Broker_EverythingDB.maxTooltipHeight = test*100;
		end

		-- character cache
		if(be_character_cache==nil)then
			be_character_cache={order={}};
		end
		if(be_character_cache.order==nil)then
			be_character_cache.order={};
		end

		local baseData={"name","class","faction","race"};

		if(not be_character_cache[ns.player.name_realm])then
			tinsert(be_character_cache.order,ns.player.name_realm);
			be_character_cache[ns.player.name_realm] = {orderId=#be_character_cache.order};
		end

		for i,v in ipairs(baseData)do
			if(ns.player[v] and be_character_cache[ns.player.name_realm][v]~=ns.player[v])then
				be_character_cache[ns.player.name_realm][v] = ns.player[v];
			end
		end

		be_character_cache[ns.player.name_realm].level = UnitLevel("player");

		-- modules
		ns.moduleInit();

		self:UnregisterEvent("ADDON_LOADED");
	elseif (event=="PLAYER_ENTERING_WORLD") then

		-- iconset
		ns.I(true);
		ns.updateIcons();

		-- panels for broker and config
		ns.be_option_panel = ns.optionpanel();
		ns.be_data_panel = ns.datapanel();
		ns.be_profile_panel = ns.profilepanel();
		ns.be_info_panel = ns.infopanel();

		-- coexist with other addons
		for _,name in pairs(ns.coexist.names) do
			if (ns.coexist.found==false) and (GetAddOnInfo(name)) and (GetAddOnEnableState(ns.player.name,name)==2) then
				ns.coexist.found = name;
			end
		end
		ns.moduleCoexist();

		self:UnregisterEvent("PLAYER_ENTERING_WORLD");
	elseif(event=="PLAYER_LEVEL_UP")then
		be_character_cache[ns.player.name_realm].level = UnitLevel("player");

	elseif (event=="NEUTRAL_FACTION_SELECT_RESULT") then
		ns.player.faction, ns.player.factionL  = UnitFactionGroup("player");
		L[ns.player.faction] = ns.player.factionL;

		be_character_cache[ns.player.name_realm].faction = ns.player.faction;
	end
end)

Broker_Everything:RegisterEvent("ADDON_LOADED");
Broker_Everything:RegisterEvent("PLAYER_ENTERING_WORLD");
Broker_Everything:RegisterEvent("PLAYER_LEVEL_UP");
Broker_Everything:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");

