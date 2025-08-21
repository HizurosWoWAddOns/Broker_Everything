
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

-- It is not nice to read from a user the own addon or module offer more than implemented
-- and a look into the code pointing on a globalstring from Blizzard.
-- It sounds like another addon has changed the globalstring.
-- Or Blizzard has changed the globalstring? Maybe...

local lang = GetLocale();
local info,correct = {},{
	RELOADUI = ({--[[enUS="Reload UI",]]deDE="Neu laden",esES="Reiniciar IU",esMX="Recargar",frFR="Recharger",itIT="Riavvio IU",koKR="UI 재시작",ptBR="Recarregar IU",ptPT="Recarregar IU",ruRU="Перезагрузка",zhCN="重新加载UI",zhTW="重新載入"})[lang] or "Reload UI"
};
local function GetGlobalString(string)
	local result, warning, secure, foreign = _G[string], nil, issecurevariable(_G,string)
	local isChanged = correct[string]~=nil and _G[string]~=correct[string];
	if not secure and not info[string] then
		local str = {L["Info: Globalstring \"%2\" was %3 by \"%1\"."]:format(foreign,string,isChanged and "modified" or "touched")};
		info[string]=true;
	end
	if isChanged then
		result=correct[string];
		if secure then
			ns:debugPrint("Warning: Blizzard has changed globalstring",string,"Old: "..correct[string],"New: ".._G[string])
		end
	end
	return result;
end

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
L["ReloadUI"] = GetGlobalString("RELOADUI");


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
local byItemIdCount = 0;

local frame = CreateFrame("Frame");
frame:SetScript("OnEvent",function(_,event,id)
	if event=="PLAYER_LOGIN" then
		local name;
		for ID, key in pairs(byItemId) do
			name = C_Item.GetItemInfo(ID);
			if name then
				L[key] = name;
			else
				byItemIdCount = byItemIdCount+1;
			end
		end
		if byItemIdCount>0 then
			frame:RegisterEvent("GET_ITEM_INFO_RECEIVED");
		end
		print("L",event,byItemIdCount)
	elseif event=="GET_ITEM_INFO_RECEIVED" and byItemId[id] then
		L[byItemId[id]] = C_Item.GetItemInfo(id);
		byItemIdCount=byItemIdCount-1;
		if byItemIdCount==0 then
			frame:UnregisterEvent(event)
		end
	end
end);
frame:RegisterEvent("PLAYER_LOGIN");

-- localization by ;) - step 3
local locale = GetLocale();
L["WoWToken"]=({deDE="WoW-Marke",esES="Ficha de WoW",esMX="Ficha de WoW",frFR="Jeton WoW",itIT="Gettone WoW",koKR="WoW 토큰",ptBR="Ficha de WoW",ptPT="Ficha de WoW",ruRU="Жетон WoW",zhCN="魔兽世界时光徽章",zhTW="魔獸代幣"})[locale] or "WoW Token";
L["Dungeons and raids"]=({deDE="Dungeons und Schlachtzüge",esES="Mazmorra y banda",esMX="Mazmorra y banda",frFR="Donjons & Raids",itIT="Spedizioni e Incursioni",ptBR="Masmorras e Raides",ptPT="Masmorras e Raides",ruRU="Подземелья и рейды",koKR="던전 및 공격대",zhCN="地下城与团队副本",zhTW="地下城与团队副本"})[locale] or "Dungeons and raids";
L["Hidden currencies"]=({deDE="Versteckte Währungen",esES="Monedas ocultas",esMX="Kaŝaj valutoj",frFR="Monnaies cachées",itIT="Valute nascoste",ptBR="Moedas ocultas",ptPT="Moedas ocultas",ruRU="Скрытые валюты",koKR="숨겨진 통화",zhCN="隐藏的货币",zhTW="隱藏的貨幣"})[locale] or "Hidden currencies";
L["Torghast"]=({frFR="Tourment",itIT="Torgast",ptBR="Thanator",ptPT="Thanator",ruRU="Торгаст",koKR="토르가스트",zhCN="托加斯特",zhTW="托加斯特"})[locale] or "Torghast"
L["DragonRacing"]=({deDE="Drachenrennen",esES="Carreras de dragones",esMX="Carreras de dragones",frFR="Course de Dragons",itIT="Corsa dei Draghi",ptBR="Corrida de Dragões",ptPT="Corrida de Dragões",ruRU="Гонки драконов"})[locale] or "DragonRacing"

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
