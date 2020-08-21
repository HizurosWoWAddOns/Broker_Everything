
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<2 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Currency"; -- CURRENCY L["ModDesc-Currency"]
local ttName,ttColumns,tt,tt2,module = name.."TT",5;
local currencies,currencySession,faction = {},{},UnitFactionGroup("player");
local BrokerPlacesMax,createTooltip = 4;
local Currencies,CurrenciesHorde = {},{};
local headers = {
	HIDDEN_CURRENCIES = "Hidden currencies", -- L["Hidden currencies"]
	DUNGEON_AND_RAID = "Dungeon and Raid", -- L["Dungeons and Raids"]
	PLAYER_V_PLAYER = PLAYER_V_PLAYER,
	MISCELLANEOUS = MISCELLANEOUS,
}


-- register icon names and default files --
-------------------------------------------
I[name..'_Neutral']  = {iconfile="Interface\\minimap\\tracking\\BattleMaster", coords={0.1,0.9,0.1,0.9}}	--IconName::Currency_Neutral--
I[name..'_Horde']    = {iconfile="Interface\\PVPFrame\\PVP-Currency-Horde", coords={0.1,0.9,0.1,0.9}}		--IconName::Currency_Horde--
I[name..'_Alliance'] = {iconfile="Interface\\PVPFrame\\PVP-Currency-Alliance", coords={0.1,0.9,0.1,0.9}}	--IconName::Currency_Alliance--


-- some local functions --
--------------------------
local function CapColor(colors,str,nonZero,count,mCount,count2,mCount2)
	local col,c = nonZero and colors[1] or "gray",0;
	if nonZero then
		if mCount>0 then
			c = mCount-count;
		end
		if count2 and mCount2 then
			local tmp=mCount2-count2;
			if mCount==0 or tmp<c then
				mCount=mCount2;
				c=tmp;
			end
		end
		if mCount>0 then
			local c2,c3,c4 = .25,.125,.05; -- 25%, 12.5%, 5%
			if mCount<=100 then
				c2,c3,c4 = .3,.2,.1; -- 30%, 20%, 10%
			end
			if c<ceil(mCount*c4) then
				col=colors[4];
			elseif c<ceil(mCount*c3) then
				col=colors[3];
			elseif c<ceil(mCount*c2) then
				col=colors[2];
			end
		end
	end
	return C(col,str);
end

local function resetCurrencySession()
	local _
	for _,id in ipairs(Currencies)do
		if tonumber(id) then
			if faction=="Horde" and CurrenciesHorde[id] then
				id = CurrenciesHorde[id];
			end
			local currencyInfo = ns.C_CurrencyInfo_GetCurrencyInfo(id);
			currencySession[id] = currencyInfo.quantity;
			--_, currencySession[id] = GetCurrencyInfo(id); -- TODO: removed in shadowlands
		end
	end
end

local function updateBroker()
	local elems,obj = {},ns.LDB:GetDataObjectByName(module.ldbName)
	if faction~="Neutral" then
		local i = I(name.."_"..faction);
		obj.iconCoords = i.coords or {0,1,0,1};
		obj.icon = i.iconfile;
	end
	for i, id in ipairs(ns.profile[name].currenciesInTitle) do
		if tonumber(id) then
			if faction=="Horde" and CurrenciesHorde[id] then
				id = CurrenciesHorde[id];
			end
			local currencyInfo = ns.C_CurrencyInfo_GetCurrencyInfo(id);
			--local Name, count, icon, earnedThisWeek, weeklyMax, totalMax, isDiscovered, rarity = GetCurrencyInfo(id); -- TODO: removed in shadowlands
			if currencyInfo.discovered then
				local str = ns.FormatLargeNumber(name,currencyInfo.quantity);
				if ns.profile[name].showCapBroker and currencyInfo.maxQuantity>0 then
					str = str.."/"..ns.FormatLargeNumber(name,currencyInfo.maxQuantity);
				end
				if ns.profile[name].showCapColorBroker and (currencyInfo.maxQuantity>0 or currencyInfo.maxWeeklyQuantity>0) then
					local t = {{"green","yellow","orange","red"},str,currencyInfo.quantity>0,currencyInfo.quantity,currencyInfo.maxQuantity};
					if currencyInfo.maxWeeklyQuantity>0 then
						tinsert(t,currencyInfo.quantityEarnedThisWeek);
						tinsert(t,currencyInfo.maxWeeklyQuantity);
					end
					str = CapColor(unpack(t));
				end
				tinsert(elems, str.."|T"..currencyInfo.iconFileID..":0|t");
			end
		end
	end
	if #elems==0 then
		obj.text = CURRENCY;
	else
		local space = " ";
		if ns.profile[name].spacer>0 then
			space = strrep(" ",ns.profile[name].spacer);
		end
		obj.text = table.concat(elems,space);
	end
end

local function setInTitle(titlePlace, currencyId)
	if currencyId and currencySession[currencyId] then
		ns.profile[name].currenciesInTitle[titlePlace] = currencyId;
	else
		ns.profile[name].currenciesInTitle[titlePlace] = nil;
	end
	updateBroker()
end

local function toggleCurrencyHeader(self,headerString)
	ns.toon[name].headers[headerString] = ns.toon[name].headers[headerString]==nil or nil;
	createTooltip(tt,true);
end

local function tooltip2Show(self,id)
	local pos = {};
	if (not tt2) then
		tt2=GameTooltip;
	end
	tt2:SetOwner(tt,"ANCHOR_NONE");
	tt2:SetPoint(ns.GetTipAnchor(self,"horizontal",tt));
	tt2:ClearLines();
	tt2:SetCurrencyByID(id);
	tt2:Show();
end

local function tooltip2Hide(self)
	if tt2 then
		tt2:Hide();
	end
end

function createTooltip(tt,update)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",CURRENCY))
	if ns.profile[name].shortTT == true then
		tt:AddSeparator(4,0,0,0,0);
		local c,l = 3,tt:AddLine(C("ltblue",COMMUNITIES_SETTINGS_NAME_LABEL));
		tt:AddSeparator()
	end

	local parentIsCollapsed,empty = false,nil;
	for i=1, #Currencies do
		if not tonumber(Currencies[i]) then
			if empty==true and not parentIsCollapsed then
				tt:SetCell(tt:AddLine(),1,C("gray",L["No currencies discovered..."]),nil,nil,0);
			end
			empty = true;
			parentIsCollapsed = ns.toon[name].headers[Currencies[i]]~=nil;
			local l=tt:AddLine();
			if not parentIsCollapsed then
				tt:SetCell(l,1,C("ltblue","|Tinterface\\buttons\\UI-MinusButton-Up:0|t "..headers[Currencies[i]]),nil,nil,0);
				tt:AddSeparator();
			else
				tt:SetCell(l,1,C("gray","|Tinterface\\buttons\\UI-PlusButton-Up:0|t "..headers[Currencies[i]]),nil,nil,0);
			end
			tt:SetLineScript(l,"OnMouseUp", toggleCurrencyHeader,Currencies[i]);
		elseif not parentIsCollapsed then
			local currencyId = Currencies[i];
			if faction=="Horde" and CurrenciesHorde[currencyId] then
				currencyId = CurrenciesHorde[currencyId];
			end
			local currencyInfo = ns.C_CurrencyInfo_GetCurrencyInfo(currencyId);
			--local Name, count, icon, earnedThisWeek, weeklyMax, totalMax, isDiscovered, rarity = GetCurrencyInfo(currencyId); -- TODO: removed in shadowlands
			if currencyInfo and currencyInfo.name and currencyInfo.discovered then
				local str = ns.FormatLargeNumber(name,currencyInfo.quantity,true);

				-- cap
				if ns.profile[name].showTotalCap and currencyInfo.maxQuantity>0 then
					str = str .."/".. ns.FormatLargeNumber(name,currencyInfo.maxQuantity,true);

					-- cap coloring
					if ns.profile[name].showCapColor then
						str = CapColor(currencyInfo.maxWeeklyQuantity>0 and {"dkgreen","dkyellow","dkorange","dkred"} or {"green","yellow","orange","red"},str,currencyInfo.quantity>0,currencyInfo.quantity,currencyInfo.maxQuantity);
					end
				end

				-- weekly cap
				if ns.profile[name].showWeeklyCap and currencyInfo.maxWeeklyQuantity>0 then
					local wstr = "("..ns.FormatLargeNumber(name,currencyInfo.quantityEarnedThisWeek,true).."/"..ns.FormatLargeNumber(name,currencyInfo.maxWeeklyQuantity,true)..")";

					-- cap coloring
					if ns.profile[name].showCapColor then
						wstr = CapColor({"green","yellow","orange","red"},wstr,currencyInfo.quantity>0,currencyInfo.quantityEarnedThisWeek,currencyInfo.maxWeeklyQuantity);
					end

					str = wstr.." "..str;
				end

				-- show currency id
				local id = "";
				if ns.profile[name].showIDs then
					id = C("gray"," ("..currencyId..")");
				end

				local l = tt:AddLine(
					"    "..C(currencyInfo.discovered==0 and "gray" or "ltyellow",currencyInfo.name)..id,
					str.."  |T"..currencyInfo.iconFileID..":14:14:0:0:64:64:4:56:4:56|t"
				);

				-- session earn/loss
				if ns.profile[name].showSession and currencySession[currencyId] then
					local color,num = false,currencyInfo.quantity-currencySession[currencyId];
					if num>0 then
						color,num = "ltgreen","+"..num;
					elseif num<0 then
						color = "ltred";
					end
					if color and num then
						tt:SetCell(l,3,C(color,num));
					end
				end
				tt:SetLineScript(l, "OnEnter", tooltip2Show, currencyId);
				tt:SetLineScript(l, "OnLeave", tooltip2Hide);
				empty = false;
			end
		end
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.ClickOpts.ttAddHints(tt,name);
	end

	ns.roundupTooltip(tt);
end

local aceValuesCurrencyOrder = {};
local function AceOptOnBroker(info,value)
	local place=tonumber((info[#info]:gsub("currenciesInTitle","")));
	if value~=nil then
		local _,id = strsplit(":",value);
		id = tonumber(id);
		if id then
			ns.profile[name].currenciesInTitle[place] = id;
		end
		module.onevent(module.eventFrame,"BE_UPDATE_CFG",info[#info]);
	end
	local id = ("%05d"):format(ns.profile[name].currenciesInTitle[place]);
	return aceValuesCurrencyOrder[id]..":"..id;
end

local function AceOptOnBrokerValues(info)
	local place=tonumber(info[#info]:match("(%d+)$"));
	local id = ns.profile[name].currenciesInTitle[place];
	local list,n = {},1;
	wipe(aceValuesCurrencyOrder);
	for i=1, #Currencies do
		if tonumber(Currencies[i]) then
			local currencyId = Currencies[i];
			if faction=="Horde" and CurrenciesHorde[currencyId] then
				currencyId = CurrenciesHorde[currencyId];
			end
			local currencyInfo = ns.C_CurrencyInfo_GetCurrencyInfo(currencyId);
			--local Name, _, Icon, _, _, _, isDiscovered = GetCurrencyInfo(currencyId); -- TODO: removed in shadowlands
			if currencyInfo and currencyInfo.name then
				if not currencyInfo.discovered then
					currencyInfo.name = C("orange",currencyInfo.name);
				end
				local order,id = ("%04d"):format(n),("%05d"):format(Currencies[i]);
				list[order..":"..id] = "|T"..Icon..":0|t "..currencyInfo.name;
				aceValuesCurrencyOrder[id] = order;
				n=n+1;
			end
		end
	end
	return list;
end


-- module functions and variables --
------------------------------------
module = {
	icon_suffix = "_Neutral",
	events = {
		"PLAYER_LOGIN",
		"CURRENCY_DISPLAY_UPDATE",
		"CHAT_MSG_CURRENCY"
	},
	config_defaults = {
		enabled = false,
		shortTT = false,
		currenciesInTitle = {},
		showTotalCap = true,
		showWeeklyCap = true,
		showCapColor = true,
		showCapBroker = true,
		showCapColorBroker = true,
		showSession = true,
		spacer=0,
		showIDs = false
	},
	clickOptionsRename = {
		["charinfo"] = "1_open_character_info",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["charinfo"] = "CharacterInfo", -- _LEFT
		["menu"] = "OptionMenuCustom"
	}
}

ns.ClickOpts.addDefaults(module,{
	charinfo = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			showCapBroker={ type="toggle", order=1, name=L["Show total/weekly cap"], desc=L["Display currency total cap in tooltip."] },
			showCapColorBroker={ type="toggle", order=2, name=L["Coloring total/weekly cap"], desc=L["Display total/weekly caps in different colors"] },
			spacer={ type="range", order=3, name=L["Space between currencies"], desc=L["Add more space between displayed currencies on broker button"], min=0, max=10, step=1 },
--@do-not-package@
			header={ type="header", order=4, name=L["Currency on broker"] },
			currenciesInTitle1 = {type="select", order=5, name=L["CurrencyOnBrokerPlace1"], desc=L["CurrencyOnBrokerDesc"], values=AceOptOnBrokerValues, get=AceOptOnBroker, set=AceOptOnBroker },
			currenciesInTitle2 = {type="select", order=6, name=L["CurrencyOnBrokerPlace2"], desc=L["CurrencyOnBrokerDesc"], values=AceOptOnBrokerValues, get=AceOptOnBroker, set=AceOptOnBroker },
			currenciesInTitle3 = {type="select", order=7, name=L["CurrencyOnBrokerPlace3"], desc=L["CurrencyOnBrokerDesc"], values=AceOptOnBrokerValues, get=AceOptOnBroker, set=AceOptOnBroker },
			currenciesInTitle4 = {type="select", order=8, name=L["CurrencyOnBrokerPlace4"], desc=L["CurrencyOnBrokerDesc"], values=AceOptOnBrokerValues, get=AceOptOnBroker, set=AceOptOnBroker },
--@end-do-not-package@
		},
		tooltip = {
			showTotalCap={ type="toggle", order=1, name=L["Show total cap"], desc=L["Display currency total cap in tooltip."] },
			showWeeklyCap={ type="toggle", order=2, name=L["Show weekly cap"], desc=L["Display currency weekly earned and cap in tooltip."] },
			showCapColor={ type="toggle", order=3, name=L["Coloring total cap"], desc=L["Coloring limited currencies by total and/or weekly cap."] },
			showSession={ type="toggle", order=4, name=L["Show session earn/loss"], desc=L["Display session profit in tooltip"] },
			showIDs={ type="toggle", order=5, name=L["Show currency id's"], desc=L["Display the currency id's in tooltip"] },
			shortTT={ type="toggle", order=6, name=L["Short Tooltip"], desc=L["Display the content of the tooltip shorter"] },
		},
		misc = {
			shortNumbers=1,
		},
	}, nil, true
end

function module.OptionMenu(parent)
	if (tt~=nil) and (tt:IsShown()) then tt:Hide(); end

	ns.EasyMenu:InitializeMenu();

	ns.EasyMenu:AddEntry({ label=L["Currency on broker - menu"], title=true});

	for place=1, BrokerPlacesMax do
		local pList,pList2,d;
		local id = ns.profile[name].currenciesInTitle[place];

		if tonumber(id) then
			local currencyInfo = ns.C_CurrencyInfo_GetCurrencyInfo(talentid);
			--local Name, count, icon, earnedThisWeek, weeklyMax, totalMax, isDiscovered, rarity = GetCurrencyInfo(id);  -- TODO: removed in shadowlands
			if currencyInfo and currencyInfo.name then
				pList = ns.EasyMenu:AddEntry({
					arrow = true,
					label = (C("dkyellow","%s%d:").."  |T%s:20:20:0:0|t %s"):format(L["Place"],place,currencyInfo.iconFileID,C("ltblue",currencyInfo.name)),
				});
				ns.EasyMenu:AddEntry({ label = C("ltred",L["Remove the currency"]), func=function() setInTitle(place, false); end }, pList);
				ns.EasyMenu:AddEntry({separator=true}, pList);
			end
		end

		if not pList then
			pList = ns.EasyMenu:AddEntry({
				arrow = true,
				label = (C("dkyellow","%s%d:").."  %s"):format(L["Place"],place,L["Add a currency"])
			});
		end

		for i=1, #Currencies do
			if tonumber(Currencies[i]) then
				local currencyInfo = ns.C_CurrencyInfo_GetCurrencyInfo(Currencies[i]);
				--local Name, count, icon, earnedThisWeek, weeklyMax, totalMax, isDiscovered, rarity = GetCurrencyInfo(Currencies[i]); -- TODO: removed in shadowlands
				if currencyInfo and currencyInfo.name then
					local nameStr,disabled = currencyInfo.name,true;
					if ns.profile[name].currenciesInTitle[place]~=Currencies[i] then
						nameStr,disabled = C("ltyellow",nameStr),false;
					end
					ns.EasyMenu:AddEntry({
						label = nameStr,
						icon = currencyInfo.iconFileID,
						disabled = disabled,
						func = function() setInTitle(place,Currencies[i]); end
					}, pList2);
				end
			else
				pList2 = ns.EasyMenu:AddEntry({label=C("ltblue",headers[Currencies[i]]), arrow=true}, pList);
			end
		end
	end

	ns.EasyMenu:AddConfig(name,true);

	ns.EasyMenu:ShowMenu(parent);
end

function module.init()
	local strs = {
		deDE = {"Dungeon und Schlachtzug","Versteckt"},			esES = {"Mazmorra y banda","Moneda de Oculto"},
		esMX = {"Mazmorra y banda","Moneda de Oculto"},			frFR = {"Donjons & Raids","Monnaies Caché"},
		itIT = {"Spedizioni e Incursioni","Valuta: Nascosto"},	ptBR = {"Masmorras e Raides","Moeda de Escondido"},
		ptPT = {"Masmorras e Raides","Moeda de Escondido"},		ruRU = {"Подземелья и рейды","Валюты Невидимые чары"},
		koKR = {"던전 및 공격대","숨김 화폐들"},					zhCN = {"地下城与团队副本","隐藏货币"},
		zhTW = {"地下城与团队副本","隐藏货币"}
	}
	for k,v in pairs(strs)do
		if _G["LOCALE_"..k] then
			headers.DUNGEON_AND_RAID = v[1];
			headers.HIDDEN_CURRENCIES = v[2];
			break;
		end
	end
	for i=1, EXPANSION_LEVEL or 0 do
		local n = "EXPANSION_NAME"..i;
		headers[n] = _G[n];
	end
	Currencies = {
		"EXPANSION_NAME7",1803,1755,1719,1721,1718,1717 --[[1716]],1299,1560,1580,1587,1710,1565,1553,
		"DUNGEON_AND_RAID",1166,
		"PLAYER_V_PLAYER",391,
		"MISCELLANEOUS",402,81,515,1388,1401,1379,
		"EXPANSION_NAME6",1149,1533,1342,1275,1226,1220,1273,1155,1508,1314,1154,1268,
		"EXPANSION_NAME5",823,824,1101,994,1129,944,980,910,1020,1008,1017,999,
		"EXPANSION_NAME4",697,738,776,752,777,789,
		"EXPANSION_NAME3",416,615,614,361,
		"EXPANSION_NAME2",241,61,
		"EXPANSION_NAME1",1704,
		--"HIDDEN_CURRENCIES",1599,1325,1506,1171,1703,1579,1602,1559,1600,1324,1541,1349,1347,1350,1592,1593,1594,1595,1598,1191,1596,1705,1714,1540,1501,1597,1585,1586,
	};
	CurrenciesHorde = {
		[1717]=1716,
	}
end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGIN" then
		if ns.toon[name]==nil or (ns.toon[name] and ns.toon[name].headers==nil) then
			ns.toon[name] = {headers={}};
		end
		resetCurrencySession();
	elseif event=="CHAT_MSG_CURRENCY" then -- detecting new currencies
		local id = tonumber(arg1:match("currency:(%d*)"));
		if id and not currencySession[id] then
			local currencyInfo = ns.C_CurrencyInfo_GetCurrencyInfo(id);
			currencySession[id] = currencyInfo.quantity;
			--local _
			--_, currencySession[id] = GetCurrencyInfo(id); -- TODO: removed in shadowlands
		end
	end
	if ns.eventPlayerEnteredWorld then
		updateBroker();
		if (tt) and (tt.key) and (tt.key==ttName) and (tt:IsShown()) then
			createTooltip(tt,true);
		end
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "RIGHT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;

