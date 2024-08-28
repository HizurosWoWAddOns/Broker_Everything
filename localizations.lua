
local L, addon, ns = {}, ...;

-- ----------------------------------------------------------------- --
-- Localization metatable function                                   --
-- Instructions for Non-Ace3 method taken from Phanx at WowInterface --
-- http://www.wowinterface.com/portal.php?&id=224&pageid=250         --
-- ----------------------------------------------------------------- --

-- Do you want to help localize this addon?
-- https://www.curseforge.com/wow/addons/@cf-project-name@/localization

ns.L = setmetatable({},{
	__index=function(t,k)
		if L[k] then
			return L[k];
		end
		local v = tostring(k);
--@do-not-package@
		local kType = type(k);
		if kType~="string" then
			ns.debug("localization","<FIXME:WrongKeyType>",kType,v,debugstack());
		end
		if "@project-version@" == "@".."project-version".."@" then
			return "<"..k..">"; -- makes untranslated entries visible
		end
--@end-do-not-package@
		L[k] = v;
		return v;
	end,
	__newindex = function(t,k,v)
		L[k] = v;
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
L["WoWProjectId2"] = EXPANSION_NAME0;

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
L["FPS"] = FRAMERATE_LABEL:gsub(HEADER_COLON,""):gsub("：",""):trim();
L["Home"], L["World"] = MAINMENUBAR_LATENCY_LABEL:match("%((.*)%).*%((.*)%)");
L["Officer notes"] = OFFICER_NOTE_COLON:gsub(HEADER_COLON,""):gsub("：",""):trim();
L["Realm"] = FRIENDS_LIST_REALM:gsub(HEADER_COLON,""):gsub("：",""):trim(); -- "Realm: "

-- localization by Blizzard - step 3 (by events)
local byItemId = {
	-- [<itemId>] = "<english name>",
	[113340] = "Blood Card"
};

local frame = CreateFrame("Frame");
frame:SetScript("OnEvent",function(_,event,id)
	if event=="PLAYER_LOGIN" then
		local name;
		for ID, key in pairs(byItemId) do
			name = (C_Item and C_Item.GetItemInfo or GetItemInfo)(ID);
			if name then
				L[key] = name;
			end
		end
	elseif event=="GET_ITEM_INFO_RECEIVED" and byItemId[id] then
		L[byItemId[id]] = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id);
	end
end);
frame:RegisterEvent("PLAYER_LOGIN");
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED");

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

-- last step: localization filled by BigWigsMods packager (source curseforge; see above if you want to help localize this addon)

--@localization(locale="enUS", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@

if LOCALE_deDE then
--@localization(locale="deDE", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_esES then
--@localization(locale="esES", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_esMX then
--@localization(locale="esMX", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_frFR then
--@localization(locale="frFR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_itIT then
--@localization(locale="itIT", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_koKR then
--@localization(locale="koKR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_ptBR or LOCALE_ptPT then
--@localization(locale="ptBR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_ruRU then
--@localization(locale="ruRU", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_zhCN then
--@localization(locale="zhCN", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_zhTW then
--@localization(locale="zhTW", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end
