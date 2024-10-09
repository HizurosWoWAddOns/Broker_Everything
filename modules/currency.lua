
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<5 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Currency"; -- CURRENCY L["ModDesc-Currency"]
local ttName,ttColumns,tt,tt2,module = name.."TT",5;
local currencySession = {};
local BrokerPlacesMax,createTooltip = 10;
local Currencies,CovenantCurrencies,covenantID,profSkillLines,tradeSkillNames,CurrenciesDefault,profSkillLine2Currencies = {},{},0,{},{};
local currency2skillLine,profIconReplace,knownCurrencies,hiddenCurrencies = {},{},{}
local CurrenciesReplace,CurrenciesRename = {},{}
local headers = {
	HIDDEN_CURRENCIES = "Hidden currencies", -- L["Hidden currencies"]
	DUNGEON_AND_RAID = "Dungeon and Raid", -- L["Dungeons and Raids"]
	PLAYER_V_PLAYER = PLAYER_V_PLAYER,
	MISCELLANEOUS = MISCELLANEOUS,
	FAVORITES = FAVORITES,
}
local CurrenciesRenameFormat = {
	w = PROFESSIONS_CRAFTING_ORDERS_TAB_NAME.." - %s"
}
local countCorrectionList = {
	[1822] = 1, -- Renown; currency value 1 count lower than display for players
}


-- register icon names and default files --
-------------------------------------------
I[name..'_Neutral']  = {iconfile="Interface\\minimap\\tracking\\BattleMaster", coords={0.1,0.9,0.1,0.9}}	--IconName::Currency_Neutral--
I[name..'_Horde']    = {iconfile="Interface\\PVPFrame\\PVP-Currency-Horde", coords={0.1,0.9,0.1,0.9}}		--IconName::Currency_Horde--
I[name..'_Alliance'] = {iconfile="Interface\\PVPFrame\\PVP-Currency-Alliance", coords={0.1,0.9,0.1,0.9}}	--IconName::Currency_Alliance--


-- some local functions --
--------------------------
local function CountCorrection(id,info)
	local v = countCorrectionList[id];
	if v then
		info.quantity = info.quantity + v;
		if info.maxQuantity>0 then
			info.maxQuantity = info.maxQuantity + v;
		end
	end
end

local function CapColor(colors,str,opts) -- nonZero,count,mCount,count2,mCount2
	local col,c = opts.nonZero and colors[1] or "gray",0;
	local mCount,mCount2 = opts.maxCount,opts.maxCount2;
	if opts.nonZero then
		if mCount>0 then
			c = mCount-opts.count;
		end
		if opts.count2 and mCount2 then
			local tmp=mCount2-opts.count2;
			if mCount==0 or tmp<c then
				mCount=mCount2;
				c=tmp;
			end
		end
		if mCount>0 then
			local c2,c3,c4 = .25,.125,.05; -- 25%, 12.5%, 5%
			if opts.capInvert then
				c2,c3,c4 = .75,.5,.25;
			elseif mCount<=100 then
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
			local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(id);
			CountCorrection(id,currencyInfo);
			currencySession[id] = currencyInfo.quantity;
		end
	end
end

local function validateID(id)
	return tonumber(id) or tostring(id):find("^prof:[kw]:%d*:%d*$");
end

local function GetCurrency(currencyId,skillLineID)
	local currencyInfo,_;
	if tonumber(currencyId) then
		currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyId);
		if not currencyInfo.iconFileID and profIconReplace[currencyId] then
			local info = C_CurrencyInfo.GetCurrencyInfo(profIconReplace[currencyId]);
			currencyInfo.iconFileID = info.iconFileID;
		end
		local replace = CurrenciesReplace[currencyId];
		if replace then
			for k,v in pairs(replace) do
				currencyInfo[k] = v;
			end
		end
		if CurrenciesCapInvert[currencyId] then
			currencyInfo.capInvert = true;
		end
		local rename = CurrenciesRename[currencyId];
		if rename and CurrenciesRenameFormat[rename] and currency2skillLine[currencyId] and tradeSkillNames[currency2skillLine[currencyId]] then
			currencyInfo.name = CurrenciesRenameFormat[rename]:format(tradeSkillNames[currency2skillLine[currencyId]])
		end
	end
	return currencyId,currencyInfo
end

local function updateBroker()
	local elems,obj = {},ns.LDB:GetDataObjectByName(module.ldbName)
	if ns.player.faction~="Neutral" then
		local i = I(name.."_"..ns.player.faction);
		obj.iconCoords = i.coords or {0,1,0,1};
		obj.icon = i.iconfile;
	end
	for i=1, BrokerPlacesMax do
		local obj,currencyId,currencyInfo = ns.profile[name].currenciesInTitle[i];
		if obj and validateID(obj) then
			currencyId,currencyInfo = GetCurrency(obj);
		end
		if currencyId and currencyInfo and currencyInfo.discovered then
			CountCorrection(currencyId,currencyInfo);
			local str = ns.FormatLargeNumber(name,currencyInfo.quantity);
			if ns.profile[name].showCapBroker and currencyInfo.maxQuantity>0 then
				str = str.."/"..ns.FormatLargeNumber(name,currencyInfo.maxQuantity);
			end
			if ns.profile[name].showCapColorBroker and (currencyInfo.maxQuantity>0 or currencyInfo.maxWeeklyQuantity>0) then
				local opts = {nonZero=currencyInfo.quantity>0,count=currencyInfo.quantity,maxCount=currencyInfo.maxQuantity,capInvert=currencyInfo.capInvert};
				if currencyInfo.maxWeeklyQuantity>0 then
					opts.count2 = currencyInfo.quantityEarnedThisWeek;
					opts.maxCount2 = currencyInfo.maxWeeklyQuantity;
				end
				str = CapColor(currencyInfo.capInvert and {"red","orange","yellow","green"} or {"green","yellow","orange","red"},str,opts);
			end
			tinsert(elems, str.."|T"..(currencyInfo.iconFileID or ns.icon_fallback)..":0|t");
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
	local empty,hiddenSection,parentIsCollapsed = false,false,false;

	for i=1, #Currencies do
		if Currencies[i]=="HIDDEN_CURRENCIES" and not ns.profile[name].showHidden then
			break;
		elseif not validateID(Currencies[i]) then
			if Currencies[i]=="HIDDEN_CURRENCIES" then
				hiddenSection = true;
			end
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
			local currencyId,currencyInfo = GetCurrency(Currencies[i]);
			if currencyId and currencyInfo and currencyInfo.name and (currencyInfo.discovered or hiddenSection) then
				CountCorrection(currencyId,currencyInfo);

				local str = ns.FormatLargeNumber(name,currencyInfo.quantity,true);

				-- cap
				if ns.profile[name].showTotalCap and currencyInfo.maxQuantity>0 then
					str = str .."/".. ns.FormatLargeNumber(name,currencyInfo.maxQuantity,true);

					-- cap coloring
					if ns.profile[name].showCapColor then
						local colors = currencyInfo.capInvert and {"red","orange","yellow","green"} or {"green","yellow","orange","red"};
						if currencyInfo.maxWeeklyQuantity>0 then
							colors = currencyInfo.capInvert and {"dkred","dkorange","dkyellow","dkgreen"} or {"dkgreen","dkyellow","dkorange","dkred"};
						end
						str = CapColor(colors,str,{nonZero=currencyInfo.quantity>0,count=currencyInfo.quantity,maxCount=currencyInfo.maxQuantity,capInvert=currencyInfo.capInvert});
					end
				end

				-- weekly cap
				if ns.profile[name].showWeeklyCap and currencyInfo.maxWeeklyQuantity>0 then
					local wstr = "("..ns.FormatLargeNumber(name,currencyInfo.quantityEarnedThisWeek,true).."/"..ns.FormatLargeNumber(name,currencyInfo.maxWeeklyQuantity,true)..")";

					-- cap coloring
					if ns.profile[name].showCapColor then
						wstr = CapColor(currencyInfo.capInvert and {"red","orange","yellow","green"} or {"green","yellow","orange","red"},wstr,{nonZero=currencyInfo.quantity>0,count=currencyInfo.quantityEarnedThisWeek,maxCount=currencyInfo.maxWeeklyQuantity,capInvert=currencyInfo.capInvert});
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
					str.."  |T"..(currencyInfo.iconFileID or ns.icon_fallback)..":14:14:0:0:64:64:4:56:4:56|t"
				);

				-- session earn/loss
				if ns.profile[name].showSession and currencySession[currencyId] then
					local color,num,prefix = nil,currencyInfo.quantity-currencySession[currencyId],"";
					if num>0 then
						color,prefix = "ltgreen","+";
					elseif num<0 then
						color = "ltred";
					end
					if color and num then
						tt:SetCell(l,3,C(color,prefix..num));
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

local aceCurrencies = {values={},order={},created=false};

local function isHidden(info,isEasyMenu)
	return isEasyMenu; -- only for easymenu
end

local function AceOptOnBroker(info,value)
	local place=tonumber((info[#info]:gsub("currenciesInTitle","")));
	if type(value)=="string" and place then
		local _,id = strsplit(":",value);
		if validateID(id) then
			ns.profile[name].currenciesInTitle[place] = id;
		end
		module.onevent(module.eventFrame,"BE_UPDATE_CFG",info[#info]);
	end
	local id = ("%05d"):format(ns.profile[name].currenciesInTitle[place]);
	if aceCurrencies.order[id] then
		return aceCurrencies.order[id]..":"..id;
	end
	return false;
end

local function aceOptOnBrokerValues(info)
	-- generate currencies list one time per AceOptions creation/refresh. one table for all select fields.
	if info[#info]=="currenciesInTitle1" or not aceCurrencies.created then
		aceCurrencies.created = true;
		local id = ns.profile[name].currenciesInTitle[tonumber((info[#info]:gsub("currenciesInTitle","")))];
		local list,orderList,n = {},{},1;
		wipe(aceCurrencies.values);
		wipe(aceCurrencies.order);
		aceCurrencies.values[false] = NONE;
		for i=1, #Currencies do
			if Currencies[i]=="HIDDEN_CURRENCIES" and not ns.profile[name].showHidden then
				break;
			elseif validateID(Currencies[i]) then
				local currencyId,currencyInfo = GetCurrency(Currencies[i]);
				if currencyInfo and currencyInfo.name then
					local color = "white";
					if not currencyInfo.discovered then
						color = "ltgray";
					end
					local order,id = ("%04d"):format(n),("%05d"):format(currencyId);
					aceCurrencies.values[order..":"..id] = C(color,currencyInfo.name);
					aceCurrencies.order[id] = order;
					n=n+1;
				end
			end
		end
	end
	return aceCurrencies.values;
end

local function updateProfessions()
	local temp = {}
	local profs = {GetProfessions()};
	for index=1, 2 do
		local tradeSkillName,skillLine,_;
		if profs[index] then
			tradeSkillName, _, _, _, _, _, skillLine = GetProfessionInfo(profs[index]);
		end
		if skillLine then
			tinsert(temp,{tradeSkillName,skillLine});
			tradeSkillNames[skillLine] = tradeSkillName;
		end
	end
	if #temp~=#profSkillLines then
		profSkillLines = temp;
		return true;
	end
	return false;
end

local function get_currency(t)
	local f,id=ns.player.faction;
	if type(t)=="table" then
		id = t[(f=="Alliance" and 1) or (f=="Horde" and 2) or --[[Neutral]] 3] or nil;
	else
		id = t;
	end
	return id;
end

local function updateCurrencies()
	wipe(Currencies);

	-- Favs
	if type(ns.profile[name].favs)=="table" and #ns.profile[name].favs>0 then
		tinsert(Currencies,"FAVORITES");
		for _, fav in ipairs(ns.profile[name].favs) do
			local id = get_currency(fav);
			if id then
				tinsert(Currencies,id);
			end
		end
	end

	-- default currencies
	for i=1, #CurrenciesDefault do
		local group = CurrenciesDefault[i];

		-- add header
		tinsert(Currencies,group.h);

		-- add normal currencies
		for g=1, #group do
			local id = get_currency(group[g]);
			if id then
				tinsert(Currencies,id);
				knownCurrencies[id] = true;
			end
		end

		-- add covenant currencies
		if covenantID>0 and CovenantCurrencies[group.h] then
			for currencyID, covenant in pairs(CovenantCurrencies[group.h]) do
				if covenant==covenantID then
					tinsert(Currencies,currencyID)
				end
			end
		end

		-- add profession currencies
		if profSkillLine2Currencies[group.h] then
			if #profSkillLines==0 then
				updateProfessions()
			end
			for i=1, #profSkillLines do
				local t = profSkillLine2Currencies[group.h][profSkillLines[i][2]]
				if t then
					for n=1, #t do
						tinsert(Currencies,t[n]);
						knownCurrencies[t[n]] = true
						currency2skillLine[t[n]] = profSkillLines[i][2];
					end
				end
			end
		end
	end

	-- hidden currencies
	if not hiddenCurrencies then
		local ignore = {["n/a"]=1,["UNUSED"]=1};
		hiddenCurrencies = {}
		for i=42, 9999 do
			if not knownCurrencies[i] and not ns.isArchaeologyCurrency(i) then
				local info = C_CurrencyInfo.GetCurrencyInfo(i);
				if info and info.name and not (ignore[info.name] or info.name:find("zzold") or info.name:find("Test") or info.name:find("Prototype") --[[or info.name:find("Scoreboard")]]) then -- (and not info.isHeader)
					tinsert(hiddenCurrencies,i);
				end
			end
		end
	end

	if hiddenCurrencies then
		tinsert(Currencies,"HIDDEN_CURRENCIES");
		for h=1, #hiddenCurrencies do
			tinsert(Currencies,hiddenCurrencies[h]);
		end
	end
end


-- module functions and variables --
------------------------------------
module = {
	icon_suffix = "_Neutral",
	events = {
		"PLAYER_LOGIN",
		"CURRENCY_DISPLAY_UPDATE",
		"CHAT_MSG_CURRENCY",
		"NEUTRAL_FACTION_SELECT_RESULT",
		"SKILL_LINES_CHANGED",
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
		showIDs = false,
		showHidden = false,
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
	local broker = {
		showCapBroker={ type="toggle", order=1, name=L["Show total/weekly cap"], desc=L["Display currency total cap in tooltip."] },
		showCapColorBroker={ type="toggle", order=2, name=L["Coloring total/weekly cap"], desc=L["Display total/weekly caps in different colors"] },
		spacer={ type="range", order=3, name=L["Space between currencies"], desc=L["Add more space between displayed currencies on broker button"], min=0, max=10, step=1 },
		header={ type="header", order=4, name=L["Currency on broker"], hidden=isHidden },
		info={ type="description", order=9, name=L["CurrencyBrokerInfo"], fontSize="medium", hidden=true },
	};

	for i=1, BrokerPlacesMax do
		broker["currenciesInTitle"..i] = {type="select", order=4+(i>4 and i+1 or i), name=L["Place"].." "..i, desc=L["CurrencyOnBrokerDesc"], values=aceOptOnBrokerValues, get=AceOptOnBroker, set=AceOptOnBroker, hidden=isHidden };
	end

	return {
		broker = broker,
		tooltip = {
			showTotalCap  = { type="toggle", order=1, name=L["CurrencyCapTotal"], desc=L["CurrencyCapTotalDesc"] },
			showWeeklyCap = { type="toggle", order=2, name=L["CurrencyCapWeekly"], desc=L["CurrencyCapWeeklyDesc"] },
			showCapColor  = { type="toggle", order=3, name=L["Coloring total cap"], desc=L["Coloring limited currencies by total and/or weekly cap."] },
			showSession   = { type="toggle", order=4, name=L["Show session earn/loss"], desc=L["Display session profit in tooltip"] },
			showIDs       = { type="toggle", order=5, name=L["Show currency id's"], desc=L["Display the currency id's in tooltip"] },
			shortTT       = { type="toggle", order=6, name=L["Short Tooltip"], desc=L["Display the content of the tooltip shorter"] },
		},
		misc = {
			shortNumbers=1,
			showHidden = {type="toggle", order=2, name=L["CurrenyHidden"], desc=L["CurrencyHiddenDesc"], hidden=ns.IsClassicClient }
		},
	}, nil, true
end

local function addMenuSubPage(pList,page)
	local pageIsTable = type(page)=="table";
	local i = (pageIsTable and page.currentHeader) or page;
	local label = headers[Currencies[i]];
	if pageIsTable and page.headers[Currencies[i]] then
		page.num = page.num + 1;
		label = label .." - ".. PAGE_NUMBER:format(page.num);
	end
	return ns.EasyMenu:AddEntry({label=C("ltblue",label), arrow=true}, pList);
end

function module.OptionMenu(parent)
	if (tt~=nil) and (tt:IsShown()) then tt:Hide(); end

	ns.EasyMenu:InitializeMenu();

	ns.EasyMenu:AddEntry({ label=L["Currency on broker - menu"], title=true});

	for place=1, BrokerPlacesMax do
		local pList,pList2,d;
		local id = ns.profile[name].currenciesInTitle[place];

		if validateID(id) then
			local currencyId,currencyInfo = GetCurrency(id);
			if currencyId and currencyInfo and currencyInfo.name then
				pList = ns.EasyMenu:AddEntry({
					arrow = true,
					label = (C("dkyellow","%s %d:").."  |T%s:20:20:0:0|t %s"):format(L["Place"],place,(currencyInfo.iconFileID or ns.icon_fallback),C("ltblue",currencyInfo.name)),
				});
				ns.EasyMenu:AddEntry({ label = C("ltred",L["Remove the currency"]), func=function() setInTitle(place, false); end }, pList);
				ns.EasyMenu:AddEntry({separator=true}, pList);
			end
		end

		if not pList then
			pList = ns.EasyMenu:AddEntry({
				arrow = true,
				label = (C("dkyellow","%s %d:").."  %s"):format(L["Place"],place,L["Add a currency"])
			});
		end

		local page = {limit=40,counter=0,num=0,currentHeader=false,headers={["HIDDEN_CURRENCIES"]=true}};
		for i=1, #Currencies do
			if Currencies[i]=="HIDDEN_CURRENCIES" and not ns.profile[name].showHidden then
				break;
			elseif validateID(Currencies[i]) then
				--isHidden = Currencies[i]=="HIDDEN_CURRENCIES";
				local currencyId,currencyInfo = GetCurrency(Currencies[i]);
				if currencyId and currencyInfo and currencyInfo.name then
					CountCorrection(currencyId,currencyInfo);
					local nameStr,disabled = currencyInfo.name,true;
					if ns.profile[name].currenciesInTitle[place]~=Currencies[i] then
						nameStr,disabled = C("ltyellow",nameStr),false;
					end
					ns.EasyMenu:AddEntry({
						label = nameStr, --.." ("..currencyId..")",
						icon = currencyInfo.iconFileID or ns.icon_fallback,
						disabled = disabled,
						keepShown = false,
						func = function() setInTitle(place,Currencies[i]); end
					}, pList2);
					-- next page
					if page.currentHeader and page.headers[ Currencies[page.currentHeader] ] then
						page.counter = page.counter + 1;
						if page.counter == page.limit then
							page.counter = 0;
							--pList2 = ns.EasyMenu:AddEntry({label=C("ltblue",label), arrow=true}, pList);
							pList2 = addMenuSubPage(pList,page);
						end
					end
				end
			else
				-- headers with paging
				if page.currentHeader~=i and page.headers[Currencies[i]] then
					page.currentHeader = i;
					pList2 = addMenuSubPage(pList,page);
				else -- without paging
					page.currentHeader = false;
					pList2 = addMenuSubPage(pList,i);
				end
			end
		end
	end

	ns.EasyMenu:AddConfig(name,true);

	ns.EasyMenu:ShowMenu(parent);
end

function module.init()
	local strs = ({
		deDE = {"Dungeon und Schlachtzug","Versteckte Währungen"}, esES = {"Mazmorra y banda","Monedas ocultas"},
		esMX = {"Mazmorra y banda","Kaŝaj valutoj"},               frFR = {"Donjons & Raids","Monnaies cachées"},
		itIT = {"Spedizioni e Incursioni","Valute nascoste"},      ptBR = {"Masmorras e Raides","Moedas ocultas"},
		ptPT = {"Masmorras e Raides","Moedas ocultas"},            ruRU = {"Подземелья и рейды","Скрытые валюты"},
		koKR = {"던전 및 공격대","숨겨진 통화"},                     zhCN = {"地下城与团队副本","隐藏的货币"},
		zhTW = {"地下城与团队副本","隱藏的貨幣"}
	})[GetLocale()];
	headers.DUNGEON_AND_RAID = strs and strs[1] or "Dungeons and raids";
	headers.HIDDEN_CURRENCIES = strs and strs[2] or "Hidden currencies";

	for i=1, 99 do
		local n = "EXPANSION_NAME"..i;
		if _G[n] then
			headers[n] = _G[n];
		else
			break;
		end
	end

	local KY,NL,NF,VE,NX = 1,4,3,2,0; -- covenant ids
	CovenantCurrencies = {
		["EXPANSION_NAME9"] = {
			-- unsorted covenant currencies
			[1794]=NX,[1804]=NX,[1805]=NX,[1806]=NX,[1807]=NX,[1837]=NX,[1839]=NX,[1840]=NX,[1841]=NX,[1843]=NX,[1844]=NX,
			[1845]=NX,[1846]=NX,[1849]=NX,[1850]=NX,[1851]=NX,[1852]=NX,[1880]=NX,[1884]=NX,[1887]=NX,[1888]=NX,

			-- kyrianer currencies
			[1867]=KY,[1871]=KY,[1819]=KY,[1847]=KY,[1848]=KY,

			-- night fae currencies
			[1869]=NF,[1873]=NF,[1853]=NF,

			-- necrolords currencies
			[1870]=NL,[1874]=NL,[1842]=NL,[1878]=NL,

			-- venthyr currencies
			[1868]=VE,[1872]=VE,[1838]=VE,
		}
	};

	CurrenciesDefault = {
		{h="EXPANSION_NAME10",2815,2813,3056,2803,3008, 2914,2915,2917,2916, 3093,3028,3055, 3089},
		{h="EXPANSION_NAME9",2806,2807,2809,2812,2777,2709,2708,2707,2706,2650,2651,2594,2245,2118,2003,2122,2045,2011,2134,2105},
		{h="DUNGEON_AND_RAID",1166},
		{h="PLAYER_V_PLAYER",2123,391,1792,1586,1602},
		{h="MISCELLANEOUS",2588,2032,1401,1388,1379,515,402,81},
		{h="EXPANSION_NAME8",2009,1979,1931,1904,1906,1977,1822,1813,1810,1828,1767,1885,1877,1883,1889,1808,1802,1891,1754,1820,1728,1816,1191},
		{h="EXPANSION_NAME7",1803,1755,1719,1721,1718,{1717,1716},1299,1560,1580,1587,1710,1565,1553},
		{h="EXPANSION_NAME6",1149,1533,1342,1275,1226,1220,1273,1155,1508,1314,1154,1268},
		{h="EXPANSION_NAME5",2778,823,824,1101,994,1129,944,980,910,1020,1008,1017,999},
		{h="EXPANSION_NAME4",697,738,776,752,777,789},
		{h="EXPANSION_NAME3",416,615,614,361},
		{h="EXPANSION_NAME2",241,61},
		{h="EXPANSION_NAME1",1704},
	}

	profSkillLine2Currencies = {
		-- dragonflight
		["EXPANSION_NAME9"] = {
			-- [<skillLineID>] = {<Knowledge>,<Workorder>,<Concentration>}
			[171] = {2024,2170}, -- Alchemy
			[164] = {2023,2165}, -- Blacksmithing
			[333] = {2030,2173}, -- Enchanting
			[202] = {2027,2172}, -- Engineering
			[773] = {2028,2175}, -- Inscription
			[755] = {2029,2174}, -- Jewelcrafting
			[165] = {2025,2169}, -- Leatherworking
			[197] = {2026,2171}, -- Tailoring
			[393] = {2033}, -- Skinning
			[182] = {2034}, -- Herbalism
			[186] = {2035}, -- Mining

		},
		-- the war within
		["EXPANSION_NAME10"] = {
			[171] = {2785,2170,3045}, -- Alchemy
			[164] = {2786,2165,3040}, -- Blacksmithing
			[333] = {2787,2173,3046}, -- Enchanting
			[202] = {2788,2172,3044}, -- Engineering
			[773] = {2790,2175,3043}, -- Inscription
			[755] = {2791,2174,3013}, -- Jewelcrafting
			[165] = {2792,2169,3042}, -- Leatherworking
			[197] = {2795,2171,3041}, -- Tailoring
			[393] = {2794}, -- Skinning
			[182] = {2789}, -- Herbalism
			[186] = {2793}, -- Mining

		}
		-- Note: It looks like dragonflight and the war within sharing workorder weekly cap
	}

	CurrenciesRename = {
		[2170]="w",[2165]="w",[2173]="w",[2172]="w",[2175]="w",[2174]="w",[2169]="w",[2171]="w",
	}

	-- invert colored cap on broker button and in tooltip
	CurrenciesCapInvert = {
		-- concentration
		[3040]=1,[3041]=1,[3042]=1,[3043]=1,[3044]=1,[3045]=1,[3046]=1,
		-- workorders df/tww
		[2170]=1,[2165]=1,[2173]=1,[2172]=1,[2175]=1,[2174]=1,[2169]=1,[2171]=1,
	}

	profIconReplace = {
		[2170]=2024, -- Alchemy
		[2165]=2023, -- Blacksmithing
		[2173]=2030, -- Enchanting
		[2172]=2027, -- Engineering
		[2175]=2028, -- Inscription
		[2174]=2029, -- Jewelcrafting
		[2169]=2025, -- Leatherworking
		[2171]=2026, -- Tailoring
	}
end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="BE_UPDATE_CFG" and arg1 and arg1:find("showHidden") then
		aceCurrencies.created = false; -- recreate currency tables
	elseif event=="PLAYER_LOGIN" then
		if ns.toon[name]==nil or (ns.toon[name] and ns.toon[name].headers==nil) then
			ns.toon[name] = {headers={}};
		end
		resetCurrencySession();

		-- covenant
		covenantID = C_Covenants.GetActiveCovenantID() or 0;
		if covenantID==0 then
			-- covenant not choosen; wait  for event
			self:RegisterEvent("COVENANT_CHOSEN");
		end
	elseif event=="COVENANT_CHOSEN" then
		-- update Covenant currencies
		covenantID = C_Covenants.GetActiveCovenantID() or 0;
	elseif event=="CHAT_MSG_CURRENCY" then -- detecting new currencies
		local id = tonumber(arg1:match("currency:(%d*)"));
		if id and not currencySession[id] then
			local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(id);
			CountCorrection(id,currencyInfo);
			currencySession[id] = currencyInfo.quantity;
		end
	end

	if event=="PLAYER_LOGIN" or event=="NEUTRAL_FACTION_SELECT_RESULT" or event=="COVENANT_CHOSEN" or (event=="SKILL_LINES_CHANGED" and updateProfessions()) then
		updateCurrencies();
	end

	if ns.eventPlayerEnteredWorld then
		updateBroker();
		if (tt) and (tt.key) and (tt.key==ttName) and (tt:IsShown()) then
			createTooltip(tt,true);
		end
	end
end

--[[
-- C_Covenants.GetCovenantIDs(); -- only a little table with 4 entries
-- C_Covenants.GetCovenantData(id); -- to get names for comment line
{
 1, -- kyrian
 2, -- venthyr
 3, -- nightfae
 4, -- necrolords
}
--]]

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

