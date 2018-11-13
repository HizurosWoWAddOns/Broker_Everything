
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Currency"; -- CURRENCY
local ttName,ttColumns,tt,tt2,module = name.."TT",5;
local cName, cIcon, cCount, cEarnedThisWeek, cWeeklyMax, cTotalMax, cIsUnused, cRarity, cID = 1,2,3,4,5,6,7,8,9,10,11,12,13;
local currencies,currencySession,faction = {},{},UnitFactionGroup("player");
local BrokerPlacesMax,createTooltip = 4;


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

local function initCurrencies()
	wipe(currencies);
	local collapsed,num={},GetCurrencyListSize();
	for index=num, 1, -1 do
		local Name, isHeader, isExpanded = GetCurrencyListInfo(index);
		if isHeader and not isExpanded then
			tinsert(collapsed,index);
			ExpandCurrencyList(index,1);
		end
	end
	local num = GetCurrencyListSize();
	local Name,isHeader,count,link,id,_;
	for index=1, num do
		Name, isHeader, _, _, _, count = GetCurrencyListInfo(index);
		id = tonumber(tostring(GetCurrencyListLink(index)):match("currency:(%d+)"));
		tinsert(currencies,{name=Name,isHeader=isHeader,id=id});
		if id and currencySession[id]==nil then
			currencySession[id] = count;
		end
	end
	for index=1, #collapsed do
		ExpandCurrencyList(collapsed[index],0);
	end
end

local function resetCurrency()
	local _
	for id in pairs(currencySession)do
		_, currencySession[id] = GetCurrencyInfo(id);
	end
end

local function GetCurrencyByID(id)
	local t = {}; t[cID], t[cName], t[cCount], t[cIcon], t[cEarnedThisWeek], t[cWeeklyMax], t[cTotalMax], _, t[cRarity] = id, GetCurrencyInfo(id);
	return t;
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
			local c = GetCurrencyByID(id);
			local str = ns.FormatLargeNumber(name,c[cCount]);
			if ns.profile[name].showCapBroker and c[cTotalMax]>0 then
				str = str.."/"..ns.FormatLargeNumber(name,c[cTotalMax]);
			end
			if ns.profile[name].showCapColorBroker and (c[cTotalMax]>0 or c[cWeeklyMax]>0) then
				local t = {{"green","yellow","orange","red"},str,c[cCount]>0,c[cCount],c[cTotalMax]};
				if c[cWeeklyMax]>0 then
					tinsert(t,c[cEarnedThisWeek]);
					tinsert(t,c[cWeeklyMax]);
				end
				str = CapColor(unpack(t));
			end
			tinsert(elems, str.."|T"..c[cIcon]..":0|t");
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
	ns.toon[name].headers[headerString] = ns.toon[name].headers[headerString]==nil and true or nil;
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
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",CURRENCY))
	if ns.profile[name].shortTT == true then
		tt:AddSeparator(4,0,0,0,0);
		local c,l = 3,tt:AddLine(C("ltblue",L["Name"]));
		tt:AddSeparator()
	end

	local parentIsCollapsed,empty = false,true;
	for i=1, #currencies do
		if currencies[i].isHeader and ns.profile[name].shortTT==false then
			parentIsCollapsed = ns.toon[name].headers[currencies[i].name]~=nil;
			local l=tt:AddLine();
			if not parentIsCollapsed then
				tt:SetCell(l,1,C("ltblue","|Tinterface\\buttons\\UI-MinusButton-Up:0|t "..currencies[i].name),nil,nil,0);
				tt:AddSeparator();
			else
				tt:SetCell(l,1,C("gray","|Tinterface\\buttons\\UI-PlusButton-Up:0|t "..currencies[i].name),nil,nil,0);
			end
			tt:SetLineScript(l,"OnMouseUp", toggleCurrencyHeader,currencies[i].name);
		elseif not parentIsCollapsed then
			local c,currency = 3,GetCurrencyByID(currencies[i].id);
			local str = ns.FormatLargeNumber(name,currency[cCount],true);

			-- cap
			if ns.profile[name].showTotalCap and currency[cTotalMax]>0 then
				str = str .."/".. ns.FormatLargeNumber(name,currency[cTotalMax],true);

				-- cap coloring
				if ns.profile[name].showCapColor then
					str = CapColor(currency[cWeeklyMax]>0 and {"dkgreen","dkyellow","dkorange","dkred"} or {"green","yellow","orange","red"},str,currency[cCount]>0,currency[cCount],currency[cTotalMax]);
				end
			end

			-- weekly cap
			if ns.profile[name].showWeeklyCap and currency[cWeeklyMax]>0 then
				local wstr = "("..ns.FormatLargeNumber(name,currency[cEarnedThisWeek],true).."/"..ns.FormatLargeNumber(name,currency[cWeeklyMax],true)..")";

				-- cap coloring
				if ns.profile[name].showCapColor then
					wstr = CapColor({"green","yellow","orange","red"},wstr,currency[cCount]>0,currency[cEarnedThisWeek],currency[cWeeklyMax]);
				end

				str = wstr.." "..str;
			end

			-- show currency id
			local id = "";
			if ns.profile[name].showIDs then
				id = C("gray"," ("..currencies[i].id..")");
			end

			local l = tt:AddLine(
				"    "..C(currency[cCount]==0 and "gray" or "ltyellow",currency[cName])..id,
				str.."  |T"..currency[cIcon]..":14:14:0:0:64:64:4:56:4:56|t"
			);

			-- session earn/loss
			if ns.profile[name].showSession then
				local color,num = false,currency[cCount]-currencySession[currencies[i].id];
				if num>0 then
					color,num = "ltgreen","+"..num;
				elseif num<0 then
					color = "ltred";
				end
				if color then
					tt:SetCell(l,c,C(color,num));
				end
			end
			tt:SetLineScript(l, "OnEnter", tooltip2Show, currencies[i].id);
			tt:SetLineScript(l, "OnLeave", tooltip2Hide);
			empty = false;
		end
	end

	if empty then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgray",L["No currencies found..."]),nil,nil,ttColumns);
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.ClickOpts.ttAddHints(tt,name);
	end

	ns.roundupTooltip(tt);
end

local function inBrokerValues(info)
	local key=info[#info];
	return {};
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
		favCurrencies = {},
		favMode=false,
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
			--header={ type="header", order=4, name=L["CurrencyHeadInBroker"] },
			--inBroker1 = {type="select", order=5, name=L["CurrencyInBroker1"], desc=L["CurrencyInBroker1Desc"], values=inBrokerValues },
			--inBroker2 = {type="select", order=6, name=L["CurrencyInBroker2"], desc=L["CurrencyInBroker2Desc"], values=inBrokerValues },
			--inBroker3 = {type="select", order=7, name=L["CurrencyInBroker3"], desc=L["CurrencyInBroker3Desc"], values=inBrokerValues },
			--inBroker4 = {type="select", order=8, name=L["CurrencyInBroker4"], desc=L["CurrencyInBroker4Desc"], values=inBrokerValues },
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

	ns.EasyMenu:AddEntry({ label=L["Currency in title - menu"], title=true});

	for place=1, BrokerPlacesMax do
		local pList,pList2,d;
		local id = ns.profile[name].currenciesInTitle[place];

		if id then
			local d = GetCurrencyByID(id);
			if d then
				pList = ns.EasyMenu:AddEntry({
					arrow = true,
					label = (C("dkyellow","%s%d:").."  |T%s:20:20:0:0|t %s"):format(L["Place"],place,d[cIcon],C("ltblue",d[cName])),
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

		for i=1, #currencies do
			if currencies[i].id then
				local d = GetCurrencyByID(currencies[i].id);
				local nameStr,disabled = d[cName],true;
				if ns.profile[name].currenciesInTitle[place]~=currencies[i].id then
					nameStr,disabled = C("ltyellow",nameStr),false;
				end
				ns.EasyMenu:AddEntry({
					label = nameStr,
					icon = d[cIcon],
					disabled = disabled,
					func = function() setInTitle(place,currencies[i].id); end
				}, pList2);
			else
				pList2 = ns.EasyMenu:AddEntry({label=C("ltblue",currencies[i].name), arrow=true}, pList);
			end
		end
	end

	ns.EasyMenu:AddConfig(name,true);

	ns.EasyMenu:ShowMenu(parent);
end

-- function module.init() end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGIN" then
		if ns.toon[name]==nil or (ns.toon[name] and ns.toon[name].headers==nil) then
			ns.toon[name] = {headers={[-1]=true}};
		end
		initCurrencies();
		hooksecurefunc("SetCurrencyUnused",initCurrencies);
	elseif event=="CHAT_MSG_CURRENCY" then -- detecting new currencies
		local id = tonumber(arg1:match("currency:(%d*)"));
		if id and not currencySession[id] then
			initCurrencies();
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
