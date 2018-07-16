
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Currency"; -- CURRENCY
local ttName,ttColumns,tt,tt2,module = name.."TT",5;
local cName, cIcon, cCount, cEarnedThisWeek, cWeeklyMax, cTotalMax, cIsUnused, cID = 1,2,3,4,5,6,7,8,9,10,11,12;
local currencyList,currencyList2,currencyCache,currencySession,currencyName2Id = {},{},{},{},{};
local BrokerPlacesMax,createTooltip = 4;


-- register icon names and default files --
-------------------------------------------
I[name..'_Neutral']  = {iconfile="Interface\\minimap\\tracking\\BattleMaster", coords={0.1,0.9,0.1,0.9}}	--IconName::Currency_Neutral--
I[name..'_Horde']    = {iconfile="Interface\\PVPFrame\\PVP-Currency-Horde", coords={0.1,0.9,0.1,0.9}}		--IconName::Currency_Horde--
I[name..'_Alliance'] = {iconfile="Interface\\PVPFrame\\PVP-Currency-Alliance", coords={0.1,0.9,0.1,0.9}}	--IconName::Currency_Alliance--


-- some local functions --
--------------------------
local function GetSign(d)
	return (d==1 and "|Tinterface\\buttons\\ui-microstream-green:14:14:0:0:32:32:6:26:26:6|t") or (d==-1 and "|Tinterface\\buttons\\ui-microstream-red:14:14:0:0:32:32:6:26:6:26|t") or "";
end

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

local function GetCurrency(index)
	local t,isHeader,isExpanded,_={};
	t[cName], isHeader, isExpanded, t[cIsUnused], _, t[cCount], t[cIcon], t[cTotalMax], t[cWeeklyMax], t[cEarnedThisWeek] = GetCurrencyListInfo(index);
	if not isHeader then
		t[cID] = tonumber(GetCurrencyListLink(index):match("currency:(%d+)"));
		_,_,_,_,t[cWeeklyMax] = GetCurrencyInfo(t[cID]); -- missing weekly max as numeric value from GetCurrencyListInfo...
		currencyName2Id[t[cName]] = t[cID];
		if currencySession[t[cID]]==nil then
			currencySession[t[cID]] = t[cCount];
		end
	end
	return t, isHeader, isExpanded;
end

local function updateCurrency(mode)
	local collapsed,_ = {};

	wipe(currencyList);
	local num = GetCurrencyListSize();
	for i=1, num do
		local t,isHeader,isExpanded = GetCurrency(i);
		if isHeader and not isExpanded then
			tinsert(collapsed,i);
		end
		if not isHeader then
			currencyCache[t[cID]] = t;
		end
		currencyList[i] = t[cID] or t[cName];
	end

	if mode=="full" then
		wipe(currencyList2);
		local tmp = {};
		for i=#collapsed, 1, -1 do
			ExpandCurrencyList(collapsed[i],1);
		end
		local num = GetCurrencyListSize();
		for i=1, num do
			local t,isHeader = GetCurrency(i);
			if not isHeader then
				tmp[t[cID]]=t;
			end
			currencyList2[i] = t[cID] or t[cName];
		end
		for i=1, #collapsed do
			ExpandCurrencyList(collapsed[i],0);
		end
		currencyCache = tmp;
	else
		for id,v in pairs(currencyCache) do
			if not currencyCache[id][cIsHeader] then
				_, currencyCache[id][cCount], _, currencyCache[id][cEarnedThisWeek] = GetCurrencyInfo(id);
			end
		end
	end
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName)
	local elems = {};
	local faction = UnitFactionGroup("player");
	if faction~="Neutral" then
		local i = I(name.."_"..faction);
		obj.iconCoords = i.coords or {0,1,0,1};
		obj.icon = i.iconfile;
	end
	for i, id in ipairs(ns.profile[name].currenciesInTitle) do
		if id then
			if type(id)=="string" then
				local Name = id;
				id = currencyName2Id[Name];
				ns.profile[name].currenciesInTitle[i] = id;
			end
			local c = currencyCache[id];
			if c and c[cIcon] then
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
	if currencyId and currencyCache[currencyId] then
		ns.profile[name].currenciesInTitle[titlePlace] = currencyId;
	else
		ns.profile[name].currenciesInTitle[titlePlace] = false;
	end
	updateBroker()
end

local function toggleCurrencyHeader(self,currency)
	ExpandCurrencyList(currency[1],currency[2]);
	createTooltip(tt,true);
	if TokenFrame:IsShown() and TokenFrame:IsVisible() then
		TokenFrame_Update();
	end
end

local function tooltip2Show(self,currencyIndex)
	local pos = {};
	if (not tt2) then
		tt2=GameTooltip;
	end
	tt2:SetOwner(tt,"ANCHOR_NONE");
	tt2:SetPoint(ns.GetTipAnchor(self,"horizontal",tt));
	tt2:ClearLines();
	tt2:SetCurrencyToken(currencyIndex); -- tokenId / the same index number if needed by GetCurrencyListInfo
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

	for i,v in ipairs(currencyList) do
		if type(v)=="string" and ns.profile[name].shortTT == false then
			local isExpanded = type(currencyList[i+1])=="number";
			tt:AddSeparator(4,0,0,0,0);
			local color,str,c = "ltblue","|Tinterface\\buttons\\UI-MinusButton-Up:0|t "..v,3;
			if not isExpanded then
				color,str = "gray","|Tinterface\\buttons\\UI-PlusButton-Up:0|t "..v;
			end
			local l=tt:AddLine(C( isExpanded and "ltblue" or "gray",str));
			if isExpanded then
				tt:AddSeparator();
			end
			tt:SetLineScript(l,"OnMouseUp", toggleCurrencyHeader,{i,isExpanded and 0 or 1});
		elseif currencyCache[v] then
			local t,c = currencyCache[v],3;
			local str = ns.FormatLargeNumber(name,t[cCount],true);

			-- cap
			if ns.profile[name].showTotalCap and t[cTotalMax]>0 then
				str = str .."/".. ns.FormatLargeNumber(name,t[cTotalMax],true);

				-- cap coloring
				if ns.profile[name].showCapColor then
					str = CapColor(t[cWeeklyMax]>0 and {"dkgreen","dkyellow","dkorange","dkred"} or {"green","yellow","orange","red"},str,t[cCount]>0,t[cCount],t[cTotalMax]);
				end
			end

			-- weekly cap
			if ns.profile[name].showWeeklyCap and t[cWeeklyMax]>0 then
				local wstr = "("..ns.FormatLargeNumber(name,t[cEarnedThisWeek],true).."/"..ns.FormatLargeNumber(name,t[cWeeklyMax],true)..")";

				-- cap coloring
				if ns.profile[name].showCapColor then
					wstr = CapColor({"green","yellow","orange","red"},wstr,t[cCount]>0,t[cEarnedThisWeek],t[cWeeklyMax]);
				end

				str = wstr.." "..str;
			end

			-- show currency id
			local id = "";
			if ns.profile[name].showIDs then
				id = C("gray"," ("..v..")");
			end

			local l = tt:AddLine(
				"    "..C(t[cCount]==0 and "gray" or "ltyellow",t[cName])..id,
				str.."  |T"..t[cIcon]..":14:14:0:0:64:64:4:56:4:56|t"
			);

			-- session earn/loss
			if ns.profile[name].showSession then
				local color,num = false,t[cCount]-currencySession[v];
				if num>0 then
					color,num = "ltgreen","+"..num;
				elseif num<0 then
					color = "ltred";
				end
				if color then
					tt:SetCell(l,c,C(color,num));
				end
			end
			tt:SetLineScript(l, "OnEnter", tooltip2Show, i);
			tt:SetLineScript(l, "OnLeave", tooltip2Hide);
		end
	end

	if #currencyList==0 then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgray",L["No currencies found..."]),nil,nil,ttColumns);
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.ClickOpts.ttAddHints(tt,name);
	end

	if not update then
		ns.roundupTooltip(tt);
	end
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
		currenciesInTitle = {false,false,false,false},
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
			showCapColor={ type="toggle", order=3, name=L["Coloring total cap"], desc=L["Coloring limited currencies by total and/or weekly cap. If weekly cap not shown then will be colored total value by value which is near on cap."] },
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

		if type(id)=="string" then
			id = currencyName2Id[id];
		end

		if id then
			local d = currencyCache[id];
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

		for i,v in ipairs(currencyList2) do
			if currencyCache[v] then
				local n,d = currencyCache[v][cName],true;
				if ns.profile[name].currenciesInTitle[place]~=v then
					n,d = C("ltyellow",n),false;
				end
				ns.EasyMenu:AddEntry({
					label = n,
					icon = currencyCache[v][cIcon],
					disabled = d,
					func = function() setInTitle(place,v); end
				}, pList2);
			else
				pList2 = ns.EasyMenu:AddEntry({label=C("ltblue",v), arrow=true}, pList);
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
		updateCurrency("full");
		updateBroker();
		hooksecurefunc("SetCurrencyUnused",updateCurrency);
		hooksecurefunc("ExpandCurrencyList",updateCurrency);
	elseif ns.eventPlayerEnteredWorld then
		local id;
		if event=="CHAT_MSG_CURRENCY" then -- detecting new currencies
			id = tonumber(arg1:match("currency:(%d*)"));
			if not currencyCache[id] then
				id = "full"
			end
		end
		updateCurrency(id);
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
