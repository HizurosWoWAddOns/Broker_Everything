
local addon, ns = ...
-- ----------------------------------------------------------------- --
-- Localization metatable function                                   --
-- Instructions for Non-Ace3 method taken from Phanx at WowInterface --
-- http://www.wowinterface.com/portal.php?&id=224&pageid=250         --
-- ----------------------------------------------------------------- --

local L = {};
--[[
ns.L = setmetatable(L,{
	__index = function(t,k)
		local k=tostring(k);
		rawset(t,k,k);
		return k;
	end
});
--]]

local debugMode = "@project-version@"=="@".."project-version".."@";
ns.L = setmetatable({}, {
	__newindex = function(t,k,v)
		L[tostring(k)]=tostring(v);
	end,
	__index = function(t, k)
		local k=tostring(k);
--@do-not-package@
		if debugMode then
			if k=="nil" then
				ns.debug("localization","<FIXME:NilKey>",debugstack());
			end
			return L[k] or "<"..k..">";
		end
--@end-do-not-package@
		return L[k] or k;
	end
});


-- localization by Blizzard - step 1
L["Achievements"] = ACHIEVEMENTS
L["Archaeology"] = PROFESSIONS_ARCHAEOLOGY
L["ChatChannels"] = CHAT_CHANNELS
L["Clock"] = TIMEMANAGER_TITLE
L["Currency"] = CURRENCY
L["Dungeon"] = LFG_TYPE_DUNGEON
L["Dungeons"] = DUNGEONS
L["Durability"] = DURABILITY
L["Emissary Quests"] = BOUNTY_BOARD_LOCKED_TITLE
L["Equipment"] = BAG_FILTER_EQUIPMENT
L["Exalted"] = FACTION_STANDING_LABEL8
L["Followers"] = GARRISON_FOLLOWERS
L["Friendly"] = FACTION_STANDING_LABEL5
L["Friends"] = FRIENDS
L["Game Menu"] = MAINMENU_BUTTON
L["Garrison"] = GARRISON_LOCATION_TOOLTIP
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
L["Speed"] = SPEED
L["System"] = CHAT_MSG_SYSTEM
L["Tracking"] = TRACKING
L["Unfriendly"] = FACTION_STANDING_LABEL3
L["Volume"] = VOLUME
L["Wardrobe"] = WARDROBE
L["WorkOrders"] = CAPACITANCE_WORK_ORDERS
L["XP"] = XP

--@do-not-package@
-- found in globalstrings by script
--L["Active"] = CONTRIBUTION_ACTIVE; -- Active
--L["Average"] = GMSURVEYRATING3; -- Average
--L["Completed"] = GOAL_COMPLETED; -- Completed
--L["Hide"] = HIDE; -- Hide
--L["Name"] = COMMUNITIES_SETTINGS_NAME_LABEL; -- Name
--L["Note"] = COMMUNITIES_ROSTER_COLUMN_TITLE_NOTE; -- Note
--L["PvE"] = TRANSMOG_SET_PVE; -- PvE
--L["PvP"] = TRANSMOG_SET_PVP; -- PvP
--L["Solo"] = SOLO; -- Solo
--L["Rested"] = TUTORIAL_TITLE26; -- Rested
--L["Sets"] = WARDROBE_SETS; -- Sets
--L["Roles"] = COMMUNITY_MEMBER_LIST_DROP_DOWN_ROLES; -- Roles
--@end-do-not-package@

-- localization by Blizzard - step 2
L["FPS"] = FRAMERATE_LABEL:gsub(":",""):gsub("：",""):trim();
L["Home"], L["World"] = MAINMENUBAR_LATENCY_LABEL:match("%((.*)%).*%((.*)%)");
L["Officer notes"] = OFFICER_NOTE_COLON:gsub(":",""):gsub("：",""):trim();
L["Realm"] = FRIENDS_LIST_REALM:gsub(":",""):gsub("：",""):trim(); -- "Realm: "

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

L[addon.."_Shortcut"] = "BE";

-- last step: localization filled by curse packager
--@localization(locale="enUS", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@

