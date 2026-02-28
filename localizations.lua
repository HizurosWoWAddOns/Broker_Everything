
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
			return "<"..v..">"; -- makes untranslated entries visible
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
do
	local lang = GetLocale();
	local localizedStrings = {
		-- {<key>,<en>,<de>,<es>,<mx>,<fr>,<it>,<br>,<pt>,<ru>,<kr>,<cn>,<tw>}
		"WoWToken:WoW Token:WoW-Marke:Ficha de WoW:Ficha de WoW:Jeton WoW:Gettone WoW:Ficha de WoW:Ficha de WoW:Жетон WoW:WoW 토큰:魔兽世界时光徽章:魔獸代幣",
		"Dungeons and raids:Dungeons and raids:Dungeons und Schlachtzüge:Mazmorra y banda:Mazmorra y banda:Donjons & Raids:Spedizioni e Incursioni:Masmorras e Raides:Masmorras e Raides:Подземелья и рейды:던전 및 공격대:地下城与团队副本:地下城与团队副本",
		"Hidden currencies:Hidden currencies:Versteckte Währungen:Monedas ocultas:Kaŝaj valutoj:Monnaies cachées:Valute nascoste:Moedas ocultas:Moedas ocultas:Скрытые валюты:숨겨진 통화:隐藏的货币:隱藏的貨幣",
		"Torghast:Torghast:Torghast:Torghast:Torghast:Tourment:Torgast:Thanator:Thanator:Торгаст:토르가스트:托加斯特:托加斯特",
		"DragonRacing:Dragon Racing:Drachenrennen:Carreras de dragones:Carreras de dragones:Course de Dragons:Corsa dei Draghi:Corrida de Dragões:Corrida de Dragões:Гонки драконов:용 경주:巨龙竞速:飛龍競速"
	};
	local t = {}
	for _, str in ipairs(localizedStrings) do
		t.key,t.enUS,t.deDE,t.esES,t.esMX,t.frFR,t.itIT,t.ptBR,t.ptPT,t.ruRU,t.koKR,t.zhCN,t.zhTW = strsplit(":",str);
		L[t.key] = t[lang] or t.enUS;
	end
	localizedStrings,t,lang=nil;
end

-- localization by Blizzard - step 2
L["FPS"] = FRAMERATE_LABEL:gsub(HEADER_COLON,""):gsub("：",""):trim();
L["Home"], L["World"] = MAINMENUBAR_LATENCY_LABEL:match("%((.*)%).*%((.*)%)");
L["Officer notes"] = OFFICER_NOTE_COLON:gsub(HEADER_COLON,""):gsub("：",""):trim();
L["Realm"] = FRIENDS_LIST_REALM:gsub(HEADER_COLON,""):gsub("：",""):trim(); -- "Realm: "
L["Latency"] = MAINMENUBAR_LATENCY_LABEL:gsub(HEADER_COLON,""):gsub("：",""):trim();

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
	elseif event=="GET_ITEM_INFO_RECEIVED" and byItemId[id] then
		L[byItemId[id]] = C_Item.GetItemInfo(id);
		byItemIdCount=byItemIdCount-1;
		if byItemIdCount==0 then
			frame:UnregisterEvent(event)
		end
	end
end);
frame:RegisterEvent("PLAYER_LOGIN");

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
