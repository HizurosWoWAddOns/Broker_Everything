
-- saved variables
Broker_Everything_ProfileDB = {}; -- config data [DEPRECATED]
Broker_Everything_CharacterDB = {}; -- per character data
Broker_Everything_DataDB = {}; -- global data
Broker_Everything_AceDB = {}; -- new config data table controlled by AceDB

-- some usefull namespace to locals
local addon, ns = ...;
local C, L = ns.LC.color, ns.L;


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
	wipe(Broker_Everything_ProfileDB);
	wipe(Broker_Everything_DataDB);
	wipe(Broker_Everything_AceDB);
	ReloadUI();
end

Broker_Everything:SetScript("OnEvent", function (self, event, ...)
	if event == "ADDON_LOADED" and ... == addon then
		-- character cache
		local baseData={"name","class","faction","race"};
		if(Broker_Everything_CharacterDB==nil)then
			Broker_Everything_CharacterDB={order={}};
		end
		if(Broker_Everything_CharacterDB.order==nil)then
			Broker_Everything_CharacterDB.order={};
		end
		local names = {};
		for i=1, #Broker_Everything_CharacterDB.order do
			names[Broker_Everything_CharacterDB.order[i]]=1;
		end
		for name,v in pairs(Broker_Everything_CharacterDB)do
			if name~="order" and not names[name] then
				Broker_Everything_CharacterDB[name] = nil;
			end
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
		ns.data = Broker_Everything_DataDB;

		-- init ace option panel
		ns.RegisterOptions()

		-- modules
		ns.moduleInit();

		if ns.profile.GeneralOptions.showAddOnLoaded then
			ns.print(L["AddOnLoaded"]);
		end

		ns.eventAddOnLoaded = true;

		self:UnregisterEvent(event);
	elseif event == "ADDON_LOADED" and addonName == "Blizzard_ItemUpgradeUI" then
		ItemUpgradeFrameUpgradeButton:HookScript("OnClick",ns.items.UpdateNow);
		hooksecurefunc(_G,"ItemUpgradeFrame_UpgradeClick",ns.items.UpdateNow);
	elseif event == "DISPLAY_SIZE_CHANGED" then
		ns.ui = {size={UIParent:GetSize()},center={UIParent:GetCenter()}};
	elseif event=="PLAYER_LOGIN" then
		-- iconset
		ns.I(true);
		ns.updateIcons();

		ns.eventPlayerEnteredWorld=true;
	elseif event=="PLAYER_LEVEL_UP" then
		local lvl = UnitLevel("player");
		if lvl~=ns.toon.level then
			ns.toon.level=lvl;
		else
			C_Timer.After(1,function()
				-- sometimes this function return old level directly on levelup event
				ns.toon.level = UnitLevel("player");
			end);
		end
	elseif event=="NEUTRAL_FACTION_SELECT_RESULT" then
		ns.player.faction, ns.player.factionL  = UnitFactionGroup("player");
		L[ns.player.faction] = ns.player.factionL;

		ns.toon.faction = ns.player.faction;
	end
	if event=="PLAYER_LOGIN" or event=="GET_ITEN_INFO_RECEIVED" then
		ns.LocalizationsOnEvent(event,...);
	end
end)

Broker_Everything:RegisterEvent("ADDON_LOADED");
Broker_Everything:RegisterEvent("PLAYER_LOGIN");
Broker_Everything:RegisterEvent("PLAYER_LEVEL_UP");
Broker_Everything:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
Broker_Everything:RegisterEvent("DISPLAY_SIZE_CHANGED");
Broker_Everything:RegisterEvent("GET_ITEM_INFO_RECEIVED");
