
-- saved variables
Broker_Everything_CharacterDB = {}; -- per character data
Broker_Everything_DataDB = {}; -- global data
Broker_Everything_AceDB = {}; -- new config data table controlled by AceDB

-- some usefull namespace to locals
local addon, ns = ...;
local C, L = ns.LC.color, ns.L;
local wipe,ipairs,pairs,type=wipe,ipairs,pairs,type;
local UnitLevel,UnitFactionGroup=UnitLevel,UnitFactionGroup;


-- core event frame --
----------------------
local Broker_Everything = CreateFrame("Frame");

function ns.resetAllSavedVariables()
	wipe(Broker_Everything_DataDB);
	wipe(Broker_Everything_CharacterDB);
	wipe(Broker_Everything_AceDB);
	C_UI.Reload();
end

function ns.resetCollectedData()
	wipe(Broker_Everything_DataDB);
	wipe(Broker_Everything_CharacterDB);
	C_UI.Reload();
end

function ns.resetConfigs()
	wipe(Broker_Everything_AceDB);
	C_UI.Reload();
end

Broker_Everything:SetScript("OnEvent", function (self, event, ...)
	if event == "VARIABLES_LOADED" then
		-- character cache
		local baseData={"name","class","faction","race"};
		if Broker_Everything_CharacterDB==nil then
			Broker_Everything_CharacterDB={order={}};
		elseif Broker_Everything_CharacterDB.order==nil then
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

		-- slash command
		if ns.profile.GeneralOptions.chatCommands then
			ns.RegisterSlashCommand();
		end

		if ns.profile.GeneralOptions.showAddOnLoaded or IsShiftKeyDown() then
			ns:print(L["AddOnLoaded"]);
		end

		ns.eventAddOnLoaded = true;

		self:UnregisterEvent(event);
	elseif event == "DISPLAY_SIZE_CHANGED" then
		ns.ui = {size={UIParent:GetSize()},center={UIParent:GetCenter()}};
	elseif event=="PLAYER_LOGIN" then
		-- start PLAYER_LOGIN event queue for modules
		ns.modulePLQueueInit();

		-- iconset
		ns.I(true);
		ns.updateIcons(true);

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

Broker_Everything:RegisterEvent("VARIABLES_LOADED");
Broker_Everything:RegisterEvent("PLAYER_LOGIN");
Broker_Everything:RegisterEvent("PLAYER_LEVEL_UP");
Broker_Everything:RegisterEvent("DISPLAY_SIZE_CHANGED");
Broker_Everything:RegisterEvent("GET_ITEM_INFO_RECEIVED");
if ns.client_version>=5 then -- mop
	Broker_Everything:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
end
