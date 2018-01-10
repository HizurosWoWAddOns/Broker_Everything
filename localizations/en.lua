
local addon, ns = ...
-- ----------------------------------------------------------------- --
-- Localization metatable function                                   --
-- Instructions for Non-Ace3 method taken from Phanx at WowInterface --
-- http://www.wowinterface.com/portal.php?&id=224&pageid=250         --
-- ================================================================= --
-- Extended version by Hizuro to use some localization strings       --
-- from Blizzard                                                     --
-- ----------------------------------------------------------------- --

local L = {};

ns.L = setmetatable({}, {
	__newindex = function(t,k,v)
		L[k] = v;
	end,
	__index = function(t, k)
		local k=tostring(k);
		if ns.debugMode then
--@do-not-package@
			if k=="nil" then
				ns.debug("<FIXME:Localization:NilKey>",debugstack());
			end
--@end-do-not-package@
			return L[k] or "<"..k..">";
		end
		return L[k] or k;
	end
});


-- localization by Blizzard - step 1
L["Achievements"] = ACHIEVEMENTS;
L["Archaeology"] = PROFESSIONS_ARCHAEOLOGY
L["Clock"] = TIMEMANAGER_TITLE
L["Currency"] = CURRENCY
L["Dungeon"] = LFG_TYPE_DUNGEON
L["Dungeons"] = DUNGEONS
L["Durability"] = DURABILITY
L["Equipment"] = BAG_FILTER_EQUIPMENT
L["Exalted"] = FACTION_STANDING_LABEL8
L["Followers"] = GARRISON_FOLLOWERS
L["Friendly"] = FACTION_STANDING_LABEL5
L["Game Menu"] = MAINMENU_BUTTON
L["Garrison"] = GARRISON_LOCATION_TOOLTIP
L["General"] = GENERAL
L["Gold"] = BONUS_ROLL_REWARD_MONEY
L["Guild"] = GUILD
L["Hated"] = FACTION_STANDING_LABEL1
L["Honoured"] = FACTION_STANDING_LABEL6
L["Hostile"] = FACTION_STANDING_LABEL2
L["Inn"] = HOME_INN
L["Mail"] = BUTTON_LAG_MAIL
L["Missions"] = GARRISON_MISSIONS
L["Neutral"] = FACTION_STANDING_LABEL4
L["OptGeneral"] = GENERAL
L["OptMisc"] = AUCTION_SUBCATEGORY_OTHER
L["Professions"] = TRADE_SKILLS
L["Quest Log"] = QUESTLOG_BUTTON
L["Raids"] = RAIDS
L["Reputation"] = REPUTATION
L["Revered"] = FACTION_STANDING_LABEL7
L["Ships"] = GARRISON_SHIPYARD_FOLLOWERS
L["System"] = CHAT_MSG_SYSTEM
L["Tracking"] = TRACKING
L["Unfriendly"] = FACTION_STANDING_LABEL3
L["Volume"] = VOLUME
L["Wardrobe"] = WARDROBE
L["XP"] = XP
L["Disabled"] = ADDON_DISABLED
L["Misc"] = AUCTION_SUBCATEGORY_OTHER or CALENDAR_TYPE_OTHER


-- localization by Blizzard - step 2
L["FPS"] = FRAMERATE_LABEL:gsub(":",""):gsub("：",""):trim();
L["Home"], L["World"] = MAINMENUBAR_LATENCY_LABEL:match("%((.*)%).*%((.*)%)");
L["Officer notes"] = OFFICER_NOTE_COLON:gsub(":",""):gsub("：",""):trim();

-- localization by Blizzard - step 3 (by events)
local byItemId = {
	-- [<itemId>] = "<english name>",
};

function ns.LocalizationsOnEvent(event,...) -- executed by core.lua > Broker_Everything:SetScript("OnEvent"...
	if event=="ADDON_LOADED" and addon==... then
		local name;
		for id, key in pairs(byItemId) do
			name = GetItemInfo(id);
			if name then
				L[key] = name;
			end
		end
	elseif event=="GET_ITEM_INFO_RECEIVED" then
		local id = ...;
		if byItemId[id] then
			L[byItemId[id]] = GetItemInfo(id);
		end
	end
end

-- localization by ;) - step 3
local locale = GetLocale();
L["WoWToken"] = ({
	deDE="WoW-Marke",
	esES="Ficha de WoW",
	esMX="Ficha de WoW",
	frFR="Jeton WoW",
	itIT="Gettone WoW",
	koKR="WoW 토큰",
	ptBR="Ficha de WoW",
	ptPT="Ficha de WoW",
	ruRU="Жетон WoW",
	zhCN="魔兽世界时光徽章",
	zhTW="魔獸代幣"
})[locale] or "WoW Token";

-- last step: localization filled by curse packager
--@localization(locale="enUS", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@

