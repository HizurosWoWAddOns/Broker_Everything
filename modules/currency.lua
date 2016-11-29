
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Currency"; -- CURRENCY
local ldbName,ttName = name,name.."TT";
local tt,tt2,ttColumns,createMenu
local GetCurrencyInfo,GetCurrencyListInfo,GetCurrencyListLink = GetCurrencyInfo,GetCurrencyListInfo,GetCurrencyListLink
local tt2positions = {
	["BOTTOM"] = {edgeSelf = "TOP",    edgeParent = "BOTTOM", x =  0, y = -2},
	["LEFT"]   = {edgeSelf = "RIGHT",  edgeParent = "LEFT",   x = -2, y =  0},
	["RIGHT"]  = {edgeSelf = "LEFT",   edgeParent = "RIGHT",  x =  2, y =  0},
	["TOP"]    = {edgeSelf = "BOTTOM", edgeParent = "TOP",    x =  0, y =  2}
}
local cName, cIcon, cCount, cEarnedThisWeek, cWeeklyMax, cTotalMax, cIsUnused = 1,2,3,4,5,6,7,8,9,10,11;
local currencies,currencyName2Id,createTooltip = {},{};
local currencyCache = {};
local currencySession = {};
local currencyList = {}
local currencyList2 = {}
local last = 0;
local BrokerPlacesMax = 4;


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name..'_Neutral']  = {iconfile="Interface\\minimap\\tracking\\BattleMaster", coords={0.1,0.9,0.1,0.9}}	--IconName::Currency_Neutral--
I[name..'_Horde']    = {iconfile="Interface\\PVPFrame\\PVP-Currency-Horde", coords={0.1,0.9,0.1,0.9}}		--IconName::Currency_Horde--
I[name..'_Alliance'] = {iconfile="Interface\\PVPFrame\\PVP-Currency-Alliance", coords={0.1,0.9,0.1,0.9}}	--IconName::Currency_Alliance--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show your currencies"],
	label = CURRENCY,
	icon_suffix = "_Neutral",
	events = {
		"PLAYER_ENTERING_WORLD",
		"CURRENCY_DISPLAY_UPDATE",
		"CHAT_MSG_CURRENCY"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		shortTT = false,
		subTTposition = "AUTO",
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
	},
	config_allowed = {
		subTTposition = {["AUTO"]=true,["TOP"]=true,["LEFT"]=true,["RIGHT"]=true,["BOTTOM"]=true}
	},
	config = {
		{ type="header", label=CURRENCY, align="left", icon=true },
		{ type="separator", alpha=0 },
		{ type="header", label=L["Broker button options"] },
		{ type="separator", inMenuInvisible=true },
		{ type="toggle", name="showCapBroker", label=L["Show total/weekly cap"], tooltip=L["Display currency total cap in tooltip."], event=true },
		{ type="toggle", name="showCapColorBroker", label=L["Coloring total/weekly cap"], tooltip=L["..."], event=true },
		{ type="separator", alpha=0 },
		{ type="header", label=L["Tooltip options"] },
		{ type="separator", inMenuInvisible=true },
		{ type="toggle", name="showTotalCap", label=L["Show total cap"], tooltip=L["Display currency total cap in tooltip."] },
		{ type="toggle", name="showWeeklyCap", label=L["Show weekly cap"], tooltip=L["Display currency weekly earned and cap in tooltip."] },
		{ type="toggle", name="showCapColor", label=L["Coloring total cap"], tooltip=L["Coloring limited currencies by total and/or weekly cap. If weekly cap not shown then will be colored total value by value which is near on cap."] },
		{ type="toggle", name="showSession", label=L["Show session earn/loss"], tooltip=L["Display session profit in tooltip"] },
		{ type="toggle", name="shortTT", label=L["Short Tooltip"], tooltip=L["Display the content of the tooltip shorter"] },
		{ type="select", name="subTTposition", label=L["Second tooltip"], tooltip=L["Where does the second tooltip for a single currency are displayed from the first tooltip"],
			values	= {
				["AUTO"]    = L["Auto"],
				["TOP"]     = L["Over"],
				["LEFT"]    = L["Left"],
				["RIGHT"]   = L["Right"],
				["BOTTOM"]  = L["Under"]
			},
			default = "BOTTOM"
		},
		{ type="slider", name="spacer",     label=L["Space between currencies"], tooltip=L["Add more space between displayed currencies on broker button"],
			min			= 0,
			max			= 10,
			default		= 0,
			format		= "%d",
			event = "BE_DUMMY_EVENT"
		},
	},
	clickOptions = {
		["1_open_character_info"] = {
			cfg_label = "Open currency pane", -- L["Open currency pane"]
			cfg_desc = "open the currency pane", -- L["open the currency pane"]
			cfg_default = "_LEFT",
			hint = "Open currency pane",
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCharacter","TokenFrame");
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "_RIGHT",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self)
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
local function GetSign(d)
	return (d==1 and "|Tinterface\\buttons\\ui-microstream-green:14:14:0:0:32:32:6:26:26:6|t") or (d==-1 and "|Tinterface\\buttons\\ui-microstream-red:14:14:0:0:32:32:6:26:6:26|t") or "";
end

local function CapColor(colors,str,count,mCount,count2,mCount2)
	local col,c = colors[1],0;
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
		if mCount<=100 then
			if c<ceil(mCount*.1) then -- 10%
				col=colors[4];
			elseif c<ceil(mCount*.2) then -- 20%
				col=colors[3];
			elseif c<ceil(mCount*.3) then -- 30%
				col=colors[2];
			end
		else
			if c<ceil(mCount*.05) then -- 5%
				col=colors[4];
			elseif c<ceil(mCount*.125) then -- 10%
				col=colors[3];
			elseif c<ceil(mCount*.25) then -- 25%
				col=colors[2];
			end
		end
	end
	return C(col,str);
end

local function updateCurrency(mode)
	local collapsed,_ = {};

	wipe(currencyList);
	local num = GetCurrencyListSize();
	for i=1, num do
		local t,id,isHeader,isExpanded = {};
		t[cName], isHeader, isExpanded, t[cIsUnused], _, t[cCount], t[cIcon], t[cTotalMax], t[cWeeklyMax], t[cEarnedThisWeek] = GetCurrencyListInfo(i);
		if isHeader and not isExpanded then
			tinsert(collapsed,i);
		end
		if not isHeader then
			id = tonumber(GetCurrencyListLink(i):match("currency:(%d+)"));
			currencyName2Id[t[cName]] = id;
			currencyCache[id] = t;
			if currencySession[id]==nil then
				currencySession[id] = t[cCount];
			end
		end
		currencyList[i] = id or t[cName];
	end

	if mode=="full" then
		wipe(currencyList2);
		local tmp = {};
		for i=#collapsed, 1, -1 do
			ExpandCurrencyList(collapsed[i],1);
		end
		local num = GetCurrencyListSize();
		for i=1, num do
			local t,id,isHeader = {};
			t[cName], isHeader, _, t[cIsUnused], _, t[cCount], t[cIcon], t[cTotalMax], t[cWeeklyMax], t[cEarnedThisWeek] = GetCurrencyListInfo(i);
			if not isHeader then
				id = tonumber(GetCurrencyListLink(i):match("currency:(%d+)"));
				currencyName2Id[t[cName]] = id;
				if currencySession[id]==nil then
					currencySession[id] = t[cCount];
				end
				tmp[id]=t;
			end
			currencyList2[i] = id or t[cName];
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
	local obj = ns.LDB:GetDataObjectByName(ldbName)
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
				local str = ns.FormatLargeNumber(c[cCount]);
				if ns.profile[name].showCapBroker and c[cTotalMax]>0 then
					str = str.."/"..ns.FormatLargeNumber(c[cTotalMax]);
				end
				if ns.profile[name].showCapColorBroker and (c[cTotalMax]>0 or c[cWeeklyMax]) then
					str = CapColor({"green","yellow","orange","red"},str,c[cCount],tonumber(c[cTotalMax]),tonumber(c[cEarnedThisWeek]),tonumber(c[cWeeklyMax]));
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

function createMenu(parent)
	if (tt~=nil) and (tt:IsShown()) then tt:Hide(); end

	ns.EasyMenu.InitializeMenu();

	ns.EasyMenu.addEntry({ label=L["Currency in title - menu"], title=true});

	for place=1, BrokerPlacesMax do
		local pList,d;
		local id = ns.profile[name].currenciesInTitle[place];

		if type(id)=="string" then
			id = currencyName2Id[id];
		end

		if id then
			local d = currencyCache[id];
			if d then
				pList = ns.EasyMenu.addEntry({
					arrow = true,
					label = (C("dkyellow","%s%d:").."  |T%s:20:20:0:0|t %s"):format(L["Place"],place,d[cIcon],C("ltblue",d[cName])),
				});
				ns.EasyMenu.addEntry({ label = C("ltred",L["Remove the currency"]), func=function() setInTitle(place, false); end }, pList);
				ns.EasyMenu.addEntry({separator=true}, pList);
			end
		end

		if not pList then
			pList = ns.EasyMenu.addEntry({
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
				ns.EasyMenu.addEntry({
					label = n,
					icon = currencyCache[v][cIcon],
					disabled = d,
					func = function() setInTitle(place,v); end
				}, pList);
			else
				if i>1 then
					ns.EasyMenu.addEntry({separator=true},pList);
				end
				ns.EasyMenu.addEntry({label=C("ltblue",v),title=true}, pList);
			end
		end
	end

	ns.EasyMenu.addConfigElements(name,true);

	ns.EasyMenu.ShowMenu(parent);
end

local function toggleCurrencyHeader(self)
	ExpandCurrencyList(self.currency[1],self.currency[2]);
	createTooltip(tt,true);
	if TokenFrame:IsShown() and TokenFrame:IsVisible() then
		TokenFrame_Update();
	end
end

local function tooltip2Show(self)
	local pos = {};
	if (not tt2) then
		tt2=GameTooltip;
	end
	tt2:SetOwner(tt,"ANCHOR_NONE");

	if ns.profile[name].subTTposition == "AUTO" then
		local tL,tR,tT,tB = ns.getBorderPositions(tt);
		local uW = UIParent:GetWidth();
		if tB<200 then
			pos = tt2positions["TOP"];
		elseif tL<200 then
			pos = tt2positions["RIGHT"];
		elseif tR<200 then
			pos = tt2positions["LEFT"];
		else
			pos = tt2positions["BOTTOM"];
		end
	else
		pos = tt2positions[ns.profile[name].subTTposition];
	end

	tt2:SetPoint(pos.edgeSelf,tt,pos.edgeParent, pos.x , pos.y);
	-- changes for user choosen direction
	tt2:ClearLines();
	tt2:SetCurrencyToken(self.currencyIndex); -- tokenId / the same index number if needed by GetCurrencyListInfo
	tt2:Show();
end

local function tooltip2Hide(self)
	if tt2 then
		tt2:Hide();
	end
end

function createTooltip(tt,update)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	tt:Clear()
	tt:AddHeader(C("dkyellow",CURRENCY))
	if ns.profile[name].shortTT == true then
		tt:AddSeparator(4,0,0,0,0);
		local c,l = 3,tt:AddLine(C("ltblue",L["Name"]));
		if ns.profile[name].showWeeklyCap then
			tt:SetCell(l,c,C("ltblue",L["Weekly"]));
			c=c+1;
		end
		if ns.profile[name].showTotalCap then
			tt:SetCell(l,c,C("ltblue",L["Max."]));
			c=c+1;
		end
		if ns.profile[name].showSession then
			tt:SetCell(l,c,C("ltblue",L["Session"]));
		end
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
				--[[
				if ns.profile[name].showWeeklyCap then
					tt:SetCell(l,c,C("ltblue",L["Weekly"]));
					c=c+1;
				end
				--]]
				tt:AddSeparator();
			end
			tt.lines[l].currency = {i,isExpanded and 0 or 1};
			tt:SetLineScript(l,"OnMouseUp", toggleCurrencyHeader);
		elseif currencyCache[v] then
			local t,c = currencyCache[v],3;
			local str = ns.FormatLargeNumber(t[cCount]);
			if ns.profile[name].showTotalCap and t[cTotalMax]>0 then
				str = str .."/".. ns.FormatLargeNumber(t[cTotalMax]);
			end
			if ns.profile[name].showCapColor and (t[cTotalMax]>0 or t[cWeeklyMax]) then
				local params = {t[cCount],tonumber(t[cTotalMax])};
				if not ns.profile[name].showWeeklyCap and t[cWeeklyMax] then
					tinsert(params,tonumber(t[cEarnedThisWeek]));
					tinsert(params,tonumber(t[cWeeklyMax]));
				end
				str = CapColor({"green","yellow","orange","red"},str,unpack(params));
			end
			local l = tt:AddLine(
				"    "..C("ltyellow",t[cName]),
				str.."  |T"..t[cIcon]..":14:14:0:0:64:64:4:56:4:56|t"
			);
			if ns.profile[name].showWeeklyCap then
				if tonumber(t[cEarnedThisWeek]) and tonumber(t[cWeeklyMax]) then
					tt:SetCell(l,c,CapColor({"green","yellow","orange","red"},t[cEarnedThisWeek].."/"..t[cWeeklyMax],tonumber(t[cEarnedThisWeek]),tonumber(t[cWeeklyMax])));
				end
				c=c+1;
			end
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
			tt.lines[l].currencyIndex = i;
			tt:SetLineScript(l, "OnEnter", tooltip2Show);
			tt:SetLineScript(l, "OnLeave", tooltip2Hide);
		end
	end

	if #currencyList==0 then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgray",L["No currencies found..."]),nil,nil,ttColumns);
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
	if not update then
		ns.roundupTooltip(tt);
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	if event=="PLAYER_ENTERING_WORLD" then
		updateCurrency("full");
		updateBroker();
		hooksecurefunc("SetCurrencyUnused",updateCurrency);
		hooksecurefunc("ExpandCurrencyList",updateCurrency);
		self:UnregisterEvent(event);
	elseif event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	else
		local id;
		if event=="CHAT_MSG_CURRENCY" then -- detecting new currencies
			id = tonumber(msg:lower():match("hcurrency:(%d*)"));
		end
		updateCurrency( id and currencyCache[id]==nil and "full" or nil );
		updateBroker();
		if (tt) and (tt.key) and (tt.key==ttName) and (tt:IsShown()) then
			createTooltip(tt,true);
		end
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttColumns=5;
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "RIGHT"},{false},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

--[[ IDEAS: get max count and weekly max count of a currency for displaying caped counts in red. ]]
