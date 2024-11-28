
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
local BrokerPlacesMax,FavPlacesMax,createTooltip = 10,10;
local Currencies,CurrenciesFav,CurrenciesHidden,CovenantCurrencies,covenantID,profSkillLines,tradeSkillNames,CurrenciesDefault,profSkillLine2Currencies = {},{},{},{},0,{},{};
local currency2skillLine,profIconReplace,knownCurrencies,hiddenCurrencies = {},{},{}
local CurrenciesReplace,CurrenciesRename,hiddenCurrenciesSel,hiddenCurrenciesCategories,hiddenCurrenciesCategoriesPattern = {},{},{},{},{}
local hidden2section = {}
local headers = {
	HIDDEN_CURRENCIES = "Hidden currencies", -- L["Hidden currencies"]
	DUNGEON_AND_RAID = "Dungeon and Raid", -- L["Dungeons and Raids"]
	PLAYER_V_PLAYER = PLAYER_V_PLAYER,
	MISCELLANEOUS = MISCELLANEOUS,
	FAVORITES = FAVORITES,
}
local currencyCounter = {}
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

local function setFunction(self)
	local id = tonumber(self.arg1.currencyId);
	if id then
		ns.profile[name][self.arg1.section][self.arg1.place] = self.arg1.currencyId;
	else
		ns.profile[name][self.arg1.section][self.arg1.place] = nil;
	end
	LibStub("AceConfigRegistry-3.0"):NotifyChange(addon); -- force update ace3 option panel
end

local function toggleCurrencyHeader(self,headerString)
	ns.toon[name].headers[headerString] = not ns.toon[name].headers[headerString];
	createTooltip(tt);
end

local function tooltip2Show(self,id)
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

local function createTooltip_AddCurrencies(currencyList)
	local empty,parentIsCollapsed
	-- loop table
	for index=1, #currencyList do
		-- header
		if type(currencyList[index])=="string" then
			local headerStr = currencyList[index];
			if empty==true and not parentIsCollapsed then
				tt:SetCell(tt:AddLine(),1,C("gray",L["No currencies discovered..."]),nil,nil,0);
			end
			local counter = "";
				counter = " "..C("ltgray",(currencyCounter[headerStr] or "?"));
			if headerStr:match("HIDDEN_CURRENCIES") then
				if ns.toon[name].headers[headerStr]==nil then
					ns.toon[name].headers[headerStr] = true;
				end
			end
			empty,parentIsCollapsed =  true,ns.toon[name].headers[headerStr];
			local l=tt:AddLine();
			if not parentIsCollapsed then
				tt:SetCell(l,1,C("ltblue","|Tinterface\\buttons\\UI-MinusButton-Up:0|t "..headers[headerStr]));
				if counter~="" then
					tt:SetCell(l,2,counter);
				end
				tt:AddSeparator();
			else
				tt:SetCell(l,1,C("gray","|Tinterface\\buttons\\UI-PlusButton-Up:0|t "..headers[headerStr]));
				if counter~="" then
					tt:SetCell(l,2,counter);
				end
			end
			tt:SetLineScript(l,"OnMouseUp", toggleCurrencyHeader,headerStr);
		else
			local currencyId, currencyInfo
			if validateID(currencyList[index]) then
				currencyId, currencyInfo = GetCurrency(currencyList[index]);
			end

			if (currencyInfo and currencyInfo.name and currencyInfo.discovered) then
				empty = false;
			end

			if not parentIsCollapsed then
				CountCorrection(currencyId,currencyInfo);
				local showSeasonCap = ns.profile[name].showSeasonCap and currencyInfo.useTotalEarnedForMaxQty;
				local str = ns.FormatLargeNumber(name,currencyInfo.quantity,true);

				-- cap
				if ns.profile[name].showTotalCap and currencyInfo.maxQuantity>0 then
					str = str .. (not showSeasonCap and "/".. ns.FormatLargeNumber(name,currencyInfo.maxQuantity,true) or "");

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

				-- season cap
				if showSeasonCap then
					local wstr = "("..ns.FormatLargeNumber(name,currencyInfo.totalEarned,true).."/"..ns.FormatLargeNumber(name,currencyInfo.maxQuantity,true)..")";

					-- cap coloring
					if ns.profile[name].showCapColor then
						wstr = CapColor(currencyInfo.capInvert and {"red","orange","yellow","green"} or {"green","yellow","orange","red"},wstr,{nonZero=currencyInfo.quantity>0,count=currencyInfo.totalEarned,maxCount=currencyInfo.maxQuantity,capInvert=currencyInfo.capInvert});
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

				-- mouse over tooltip
				tt:SetLineScript(l, "OnEnter", tooltip2Show, currencyId);
				tt:SetLineScript(l, "OnLeave", tooltip2Hide);
			end
		end

	end
end

function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",CURRENCY))
	if ns.profile[name].shortTT == true then
		tt:AddSeparator(4,0,0,0,0);
		local c,l = 3,tt:AddLine(C("ltblue",COMMUNITIES_SETTINGS_NAME_LABEL));
		tt:AddSeparator()
	end

	local hasHeader = false;
	if ns.profile[name].favs and #ns.profile[name].favs>0 then
		createTooltip_AddCurrencies({"FAVORITES",unpack(ns.profile[name].favs)})
	end

	createTooltip_AddCurrencies(Currencies)

	if ns.profile[name].showHidden then
		createTooltip_AddCurrencies(CurrenciesHidden)
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

local hiddenCurrenciesAddCategory
do
	local currentCat;
	function hiddenCurrenciesAddCategory(index,info,category)
		if not category then
			for cat,values in pairs(hiddenCurrenciesCategoriesPattern) do
				for _,pattern in ipairs(values) do
					if pattern and info.name:match(pattern) then
						return hiddenCurrenciesAddCategory(index,info,cat)
					end
				end
			end
			for cat, values in pairs(hiddenCurrenciesSel) do
				if values[index] then
					return hiddenCurrenciesAddCategory(index,info,cat)
				end
			end
			return false;
		end

		--tinsert(hiddenCurrencies,index)
		local section = hidden2section[index];
		if section then
			if not hiddenCurrenciesCategories[section] then
				hiddenCurrenciesCategories[section] = {}
			end
			tinsert(hiddenCurrenciesCategories[section],index)
		else
			if not hiddenCurrenciesCategories[category] then
				hiddenCurrenciesCategories[category] = {}
			end
			tinsert(hiddenCurrenciesCategories[category],index)
		end
		return true;
	end
end

local function updateCurrencies()
	currencyCounter.FAVORITES = #ns.profile[name].favs;

	-- default currencies
	if #Currencies==0 then
		local tmp = {}
		for i=1, #CurrenciesDefault do
			local group = CurrenciesDefault[i];

			-- add header
			tinsert(tmp,group.h);
			currencyCounter[group.h] = #group;

			-- add normal currencies
			for g=1, #group do
				local id = get_currency(group[g]);
				if id then
					tinsert(tmp,id);
					knownCurrencies[id] = true;
				end
			end

			-- add covenant currencies
			if covenantID>0 and CovenantCurrencies[group.h] then
				for currencyID, covenant in pairs(CovenantCurrencies[group.h]) do
					if covenant==covenantID then
						tinsert(tmp,currencyID)
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
							tinsert(tmp,t[n]);
							knownCurrencies[t[n]] = true
							currency2skillLine[t[n]] = profSkillLines[i][2];
							currencyCounter[group.h] = currencyCounter[group.h] + 1;
						end
					end
				end
			end
		end
		Currencies = tmp;
	end

	-- hidden currencies
	if CurrenciesHidden then
		local ignore,tmpH = {["n/a"]=1,["UNUSED"]=1},{};
		hiddenCurrenciesCategories = {}

		for cat,values in pairs(hiddenCurrenciesCategoriesPattern) do
			if not headers["HIDDEN_CURRENCIES_"..strupper(cat)] then
				headers["HIDDEN_CURRENCIES_"..strupper(cat)] = headers.HIDDEN_CURRENCIES.." - "..(values[2] or L[cat]);
			end
		end

		for i=42, 9999 do
			if not knownCurrencies[i] then
				local info = C_CurrencyInfo.GetCurrencyInfo(i);
				if info and info.name and not (ignore[info.name] or info.name:find("zzold") or info.name:find("Test") or info.name:find("Prototype")) then
					if ns.isArchaeologyCurrency(i) then
						hiddenCurrenciesAddCategory(i,info,"Archaeology") -- add archaeology currencies to category Archaeology
					elseif not hiddenCurrenciesAddCategory(i,info) then -- add currencies by pattern to corresponding categories
						hiddenCurrenciesAddCategory(i,info,"Misc"); -- add the rest to category misc.
					end
				end
			end
		end

		tinsert(tmpH,"HIDDEN_CURRENCIES");
		currencyCounter["HIDDEN_CURRENCIES"] = #hiddenCurrenciesCategories.Misc;
		for i=1, #hiddenCurrenciesCategories.Misc do
			tinsert(tmpH,hiddenCurrenciesCategories.Misc[i]);
		end
		local last = nil;
		for cat, currencies in pairs(hiddenCurrenciesCategories) do
			if cat~="Misc" then
				local catUpper = strupper(cat);
				if last~=cat then
					tinsert(tmpH,"HIDDEN_CURRENCIES_"..catUpper);
					currencyCounter["HIDDEN_CURRENCIES_"..catUpper] = #currencies;
					last=cat;
				end
				for i=1, #currencies do
					tinsert(tmpH,currencies[i]);
				end
				if hiddenCurrenciesSel[cat] and #hiddenCurrenciesSel[cat]>0 then
					currencyCounter["HIDDEN_CURRENCIES_"..catUpper] = (currencyCounter["HIDDEN_CURRENCIES_"..catUpper] or 0) + #hiddenCurrenciesSel[cat]>0;
					for i=1, #hiddenCurrenciesSel[cat] do
						tinsert(tmpH,hiddenCurrenciesSel[cat][i])
					end
				end
			end
		end
		CurrenciesHidden = tmpH
	end
end

local CurrencyMenu
do
	local parent0,page = nil,{}

	local function CurrencyMenu_Paging()
		local header = page.currentHeader;
		local label = headers[header];
		if page.headers[header] then
			page.pageNum = page.pageNum + 1;
			label = label .." - ".. PAGE_NUMBER:format(page.pageNum+1);
		else
			page.pageNum=0;
			page.headers[header] = true;
		end
		page.counter=0;
		page.parent = ns.EasyMenu:AddEntry({label=C("ltblue",label), arrow=true}, page.parent);
	end

	local function CurrencyMenu_AddEntry(section,place,currencyId,currencyInfo)
		CountCorrection(currencyId,currencyInfo);
		local nameStr,disabled,tooltip = ns.strCut(currencyInfo.name,32),true;
		if nameStr~=currencyInfo.name then
			tooltip = {currencyInfo.name,""};
		end
		if ns.profile[name][section][place]~=currencyId then
			nameStr,disabled = C("ltyellow",nameStr),false;
		end

		if ns.debugMode then
			nameStr = nameStr .. C("white"," ("..currencyId..")")
		end

		ns.EasyMenu:AddEntry({
			label = nameStr,
			tooltip = tooltip,
			icon = currencyInfo.iconFileID or ns.icon_fallback,
			disabled = disabled,
			keepShown = false,
			func=setFunction,
			arg1={section=section, place=place, currencyId=currencyId}
		}, page.parent);
	end

	local function CurrencyMenu_AddEntries(section,place,CurrencyList,Parent)
		for _,currencyId in ipairs(CurrencyList) do
			local tCurrency, currencyInfo = type(currencyId)

			if tCurrency=="string" then
				-- first header/page
				page.counter=0;
				page.currentHeader = currencyId;
				page.parent=Parent;
				CurrencyMenu_Paging() -- next page
			elseif tCurrency=="number" then
				currencyId,currencyInfo = GetCurrency(currencyId);
			end
			if currencyInfo and currencyInfo.name then
				if page.currentHeader then
					page.counter = page.counter + 1;
					if page.counter > page.limit then
						page.parent=Parent;
						CurrencyMenu_Paging() -- next page
					end
				end

				CurrencyMenu_AddEntry(section,place,currencyId,currencyInfo)
			end
		end
	end

	function CurrencyMenu(section, place, parent)
		if type(place)=="string" then
			-- place as label
			parent0 = ns.EasyMenu:AddEntry({ label=place, arrow=true});
			for p=1, section=="favs" and FavPlacesMax or BrokerPlacesMax do
				CurrencyMenu(section,p,parent0)
			end
			return;
		end

		local id,currencyId,currencyInfo = ns.profile[name][section][place];
		if validateID(id) then
			currencyId,currencyInfo = GetCurrency(id);
		end

		local hasCurrency = currencyId and currencyInfo and currencyInfo.name~=nil
		if parent==true then
			-- in open panel
			parent0,parent = nil,nil;
			if hasCurrency then
				-- remove
				ns.EasyMenu:AddEntry({label = C("ltred",L["Remove the currency"]), keepShown=false, func=setFunction, arg1={section=section, place=place} });
				ns.EasyMenu:AddEntry({separator=true});
			else
				-- add
				ns.EasyMenu:AddEntry({title = true,label = (C("dkyellow","%s %d:").."  %s"):format(L["Place"],place,L["Add a currency"])});
				ns.EasyMenu:AddEntry({separator=true});
			end
		else
			-- submenu on broker button option menu
			if hasCurrency and parent and parent.menuList~=nil then
				-- sub menu
				parent = ns.EasyMenu:AddEntry({arrow = true,label = (C("dkyellow","%s %d:").."  |T%s:20:20:0:0|t %s"):format(L["Place"],place,(currencyInfo.iconFileID or ns.icon_fallback),C("ltblue",currencyInfo.name)),},parent0);
				-- remove option in sub menu
				ns.EasyMenu:AddEntry({label = C("ltred",L["Remove the currency"]), keepShown=false, func=setFunction, arg1={section=section, place=place} }, parent);
				ns.EasyMenu:AddEntry({separator=true}, parent);
			else
				-- sub menu
				parent = ns.EasyMenu:AddEntry({arrow = true,label = (C("dkyellow","%s %d:").."  %s"):format(L["Place"],place,L["Add a currency"])},parent0);
			end
		end

		page = {parent=parent,limit=40,counter=0,pageNum=0,currentHeader=false,headers={}};
		-- normal currencies
		CurrencyMenu_AddEntries(section,place,Currencies,parent)

		-- hidden currencies
		if ns.profile[name].showHiddenInMenu then
			CurrencyMenu_AddEntries(section,place,CurrenciesHidden,parent)-- hiddenCurrencies
		end
	end
end

local function optionButtonName(info)
	local key = info[#info];
	local section,index = key:match("^([a-zA-Z]*)(%d+)$"); index = tonumber(index);
	local label = L["Place"].." "..index;
	if ns.profile[name][section][index] then
		local _,cInfo = GetCurrency(ns.profile[name][section][index]);
		if cInfo then
			label = label .. ": ".. cInfo.name;
		end
	end
	return label;
end

local function optionButtonMenu(info)
	local key = info[#info];
	local section,index = key:match("^(.*)(%d+)$"); index = tonumber(index);
	local place = tonumber((key:match("(%d+)$")));

	ns.EasyMenu:InitializeMenu();
	CurrencyMenu(section, place, true)
	ns.EasyMenu:ShowMenu();
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
		favs = {},
		showTotalCap = true,
		showWeeklyCap = true,
		showCapColor = true,
		showCapBroker = true,
		showCapColorBroker = true,
		showSeasonCap = true,
		showSession = true,
		spacer=0,
		showIDs = false,
		showHidden = false,
		showHiddenInMenu = false, -- TODO: implement
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

	local tooltip = {
		showTotalCap  = { type="toggle", order=1, name=L["CurrencyCapTotal"], desc=L["CurrencyCapTotalDesc"] },
		showWeeklyCap = { type="toggle", order=2, name=L["CurrencyCapWeekly"], desc=L["CurrencyCapWeeklyDesc"] },
		showCapColor  = { type="toggle", order=3, name=L["Coloring total cap"], desc=L["Coloring limited currencies by total and/or weekly cap."] },
		showSeasonCap = { type="toggle", order=4, name=L["Season cap"], desc=L["Display season cap in tooltip"] },
		showSession   = { type="toggle", order=5, name=L["Show session earn/loss"], desc=L["Display session profit in tooltip"] },
		showIDs       = { type="toggle", order=6, name=L["Show currency id's"], desc=L["Display the currency id's in tooltip"] },
		shortTT       = { type="toggle", order=7, name=L["Short Tooltip"], desc=L["Display the content of the tooltip shorter"] },
		showHidden    = { type="toggle", order=8, name=L["CurrenyHidden"], desc=L["CurrencyHiddenDesc"], hidden=ns.IsClassicClient },
		header        = { type="header", order=20, name=L["CurrencyFavorites"], hidden=isHidden },
		info          = { type="description", order=21, name=L["CurrencyFavoritesInfo"], fontSize="medium", hidden=true },
	}

	for i=1, BrokerPlacesMax do
		broker["currenciesInTitle"..i] = {
			type = "execute", order = 4+(i>4 and i+1 or i),
			name = optionButtonName,
			desc = L["CurrencyOnBrokerDesc"],
			func = optionButtonMenu
		}
	end

	for i=1, FavPlacesMax do
		tooltip["favs"..i] = {
			type = "execute", order = 22+(i>4 and i+1 or i),
			name = optionButtonName,
			desc = L["CurrencyFavoritesDesc"],
			func = optionButtonMenu
		}
	end

	return {
		broker = broker,
		tooltip = tooltip,
		misc = {
			shortNumbers=1,
			showHiddenInMenu={type="toggle",order=2, name=L["CurrencyHiddenMenu"], desc=L["CurrencyHiddenMenuDesc"], hidden=ns.IsClassicClient },
		},
	}, nil, true
end

function module.OptionMenu(parent)
	if (tt~=nil) and (tt:IsShown()) then tt:Hide(); end

	ns.EasyMenu:InitializeMenu();

	ns.EasyMenu:AddEntry({ label=L["Broker & Favorites"], title=true});
	if false then
		ns.EasyMenu:AddEntry({ label="Temporary disabled", disabled=true});
	else
		CurrencyMenu("currenciesInTitle",L["Currency on broker - menu"])
		CurrencyMenu("favs",             L["Favorites in tooltip - menu"])
	end

	ns.EasyMenu:AddConfig(name,true);

	ns.EasyMenu:ShowMenu(parent);
end

function module.init()
	headers.DUNGEON_AND_RAID = L["Dungeons and raids"];
	headers.HIDDEN_CURRENCIES = L["Hidden currencies"];
	headers.HIDDEN_CURRENCIES_ARCHAEOLOGY = L["Hidden currencies"].." - "..PROFESSIONS_ARCHAEOLOGY;

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
		{h="MISCELLANEOUS",3100,2588,2032,1401,1388,1379,515,402,81},
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

	hiddenCurrenciesCategoriesPattern={
		-- TableKey = {<locale name>, <english name>, (more optional pattern) ... }
		Archaeology={ARCHAEOLOGY,"Archaeology"},
		Torghast={L["Torghast"],"Torghast"},
		Timewalking={PLAYER_DIFFICULTY_TIMEWALKER,"Timewalking"},
		DragonRacing={L["DragonRacing"],"Dragon Racing"},
		Delves={DELVES_LABEL,"Delves"},
		Professions={TRADE_SKILLS,"Professions" --[[,PROFESSIONS_TRACKER_HEADER_PROFESSION]]},
		PvP={PVP,"PvP"},
		--Shadowlands={EXPANSION_NAME9},
		--DragonFlight={EXPANSION_NAME10},
	}

	for k,v in pairs({
		PvP={103,104,121,122,123,124,125,126,181,221,301,321,483,484,692,1324,1325,1356,1357,1585,1703,2235,2237},
		Professions={2023,2024,2025,2026,2027,2028,2029,2033,2035,2169,2170,2172,2174,2175,2786,2788,2789,2790,2791,2792,2793,2794,3040,3042,3043,3044,3045,3047,3048,3049,3050,3051,3052,3053},
		Delves={2533},
		--Shadowlands={},
		--DragonFlight={},
	})do
		hiddenCurrenciesSel[k] = {}
		for i=1, #v do
			hiddenCurrenciesSel[k][v[i]] = 1;
		end
	end
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

