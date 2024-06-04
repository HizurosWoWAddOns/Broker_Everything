
-- saved variables
Broker_Everything_CharacterDB = {}; -- per character data
Broker_Everything_DataDB = {forcePrefix=true}; -- global data
Broker_Everything_AceDB = {}; -- config data table controlled by AceDB

-- some usefull namespace to locals
local addon, ns = ...;
local C, L = ns.LC.color, ns.L;
local wipe,ipairs,pairs,type=wipe,ipairs,pairs,type;
local UnitLevel,UnitFactionGroup=UnitLevel,UnitFactionGroup;


-- core event frame --
----------------------
local Broker_Everything = CreateFrame("Frame");

function ns.resetAllSavedVariables()
	Broker_Everything_DataDB=nil
	Broker_Everything_CharacterDB=nil
	Broker_Everything_AceDB=nil
	Broker_Everything_DataDB.forcePrefix=true
	C_UI.Reload();
end

function ns.resetCollectedData()
	Broker_Everything_DataDB=nil
	Broker_Everything_CharacterDB=nil
	C_UI.Reload();
end

function ns.resetConfigs()
	Broker_Everything_AceDB=nil
	Broker_Everything_DataDB.forcePrefix=true
	C_UI.Reload();
end

Broker_Everything:SetScript("OnEvent", function (self, event, ...)
	if event == "ADDON_LOADED" and addon==... then
		-- character cache
		local baseData={"name","class","faction","race"};
		ns.toonsDB = Broker_Everything_CharacterDB;
		if ns.toonsDB.order==nil then
			ns.toonsDB.order={};
		end
		local names = {};
		for i=1, #ns.toonsDB.order do
			names[ns.toonsDB.order[i]]=1;
		end
		for name in pairs(ns.toonsDB)do
			if name~="order" and not names[name] then
				ns.toonsDB[name] = nil;
			end
		end
		if(not ns.toonsDB[ns.player.name_realm])then
			tinsert(ns.toonsDB.order,ns.player.name_realm);
			ns.toonsDB[ns.player.name_realm] = {orderId=#ns.toonsDB.order};
		end
		for _,v in ipairs(baseData)do
			if(ns.player[v] and ns.toonsDB[ns.player.name_realm][v]~=ns.player[v])then
				ns.toonsDB[ns.player.name_realm][v] = ns.player[v];
			end
		end
		ns.toonsDB[ns.player.name_realm].level = UnitLevel("player");
		ns.toon = ns.toonsDB[ns.player.name_realm];

		-- data cache
		ns.data = Broker_Everything_DataDB
		if ns.data.realms==nil then
			ns.data.realms = {};
		end

		if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID(424143) then
			ns.IsMoPRemix = true;
		end

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
end)

Broker_Everything:RegisterEvent("ADDON_LOADED");
Broker_Everything:RegisterEvent("PLAYER_LOGIN");
Broker_Everything:RegisterEvent("PLAYER_LEVEL_UP");
Broker_Everything:RegisterEvent("DISPLAY_SIZE_CHANGED");
if ns.client_version>=5 then -- mop
	Broker_Everything:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
end
