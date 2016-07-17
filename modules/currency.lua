
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
L.Currency = CURRENCY;


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Currency";
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
local currencies,currencyName2Id = {},{};
local currencyCache = {};
local currencySession = {};
local currencyList = {}
local currencyList2 = {}
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
	icon_suffix = "_Neutral",
	events = {
		"PLAYER_ENTERING_WORLD",
		"CURRENCY_DISPLAY_UPDATE"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		shortTT = false,
		subTTposition = "AUTO",
		currenciesInTitle = {false,false,false,false},
		favCurrencies = {},
		favMode=false,
		spacer=0,
	},
	config_allowed = {
		subTTposition = {["AUTO"]=true,["TOP"]=true,["LEFT"]=true,["RIGHT"]=true,["BOTTOM"]=true}
	},
	config = {
		{ type="header", label=CURRENCY, align="left", icon=true },
		{ type="separator" },
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
		{ type="toggle", name="favMode", label=L["Favorite mode"], tooltip=L["Display as favorite selected currencies only."], disabled=true },
		{ type="slider", name="spacer",  label=L["Space between currencies"], tooltip=L["Add more space between displayed currencies on broker button"],
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

local function GetEarnLoss(id)
	
end

local function updateCurrency(mode,sessionUpdate)
	local collapsed,_ = {};
	if mode=="full" or mode=="half" then
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
					currencySession[id] = {sessionUpdate and t[cCount] or 0, sessionUpdate and 1 or 0};
				end
				if sessionUpdate then
					--currencySession[id] = {currencySession[id] + t[cCount]};
				end
			end
			currencyList[i] = id or t[cName];
		end
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
					currencySession[id] = {sessionUpdate and t[cCount] or 0, sessionUpdate and 1 or 0};
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
				if sessionUpdate then
					--currencySession[id] = {currencySession[id] + t[cCount]};
				end
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
				tinsert(elems, ns.FormatLargeNumber(c[cCount]).."|T"..c[cIcon]..":0|t");
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

local function createTooltip(self, tt)
	if (not tt.key) or (tt.key~=ttName) then return; end -- don't override other LibQTip tooltips...

	tt:Clear()
	tt:AddHeader(C("dkyellow",CURRENCY))
	if ns.profile[name].shortTT == true then
		tt:AddSeparator()
	end

	for i,v in ipairs(currencyList) do
		if type(v)=="string" and ns.profile[name].shortTT == false then
			local isExpanded = type(currencyList[i+1])=="number";
			tt:AddSeparator(4,0,0,0,0)
			local l=tt:AddLine(C( isExpanded and "ltblue" or "gray",v));
			tt:SetLineScript(l,"OnMouseUp",function()
				ExpandCurrencyList(i, isExpanded and 0 or 1 );
				createTooltip(false, tt);
				if TokenFrame:IsShown() and TokenFrame:IsVisible() then
					TokenFrame_Update();
				end
			end);
			-- tt:SetLineScript(l,"OnEnter",function() 	end);
			if isExpanded then
				tt:AddSeparator()
			end
		elseif currencyCache[v] then
			local t = currencyCache[v];
			local l=tt:AddLine(C("ltyellow",t[cName]),ns.FormatLargeNumber(t[cCount]).."  |T"..t[cIcon]..":14:14:0:0:64:64:4:56:4:56|t");
			local lineObj = tt.lines[l]
			lineObj.currencyIndex = i;

			tt:SetLineScript(l, "OnEnter",function(self)
				local pos = {}
				if (not tt2) then tt2=GameTooltip; end
				tt2:SetOwner(tt,"ANCHOR_NONE")

				if ns.profile[name].subTTposition == "AUTO" then
					local tL,tR,tT,tB = ns.getBorderPositions(tt)
					local uW = UIParent:GetWidth()
					if tB<200 then
						pos = tt2positions["TOP"]
					elseif tL<200 then
						pos = tt2positions["RIGHT"]
					elseif tR<200 then
						pos = tt2positions["LEFT"]
					else
						pos = tt2positions["BOTTOM"]
					end
				else
					pos = tt2positions[ns.profile[name].subTTposition];
				end

				tt2:SetPoint(pos.edgeSelf,tt,pos.edgeParent, pos.x , pos.y)
				-- changes for user choosen direction
				tt2:ClearLines()
				tt2:SetCurrencyToken(self.currencyIndex) -- tokenId / the same index number if needed by GetCurrencyListInfo
				tt2:Show()
			end)

			tt:SetLineScript(l, "OnLeave", function(self)
				if (tt2) then tt2:Hide(); end
			end)
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
	ns.roundupTooltip(self,tt);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	if event=="PLAYER_ENTERING_WORLD" then
		updateCurrency("full",false);
		updateBroker();
		if not self.loaded then
			hooksecurefunc("SetCurrencyUnused",function() updateCurrency("half",false) end);
			hooksecurefunc("ExpandCurrencyList",function() updateCurrency("half",false) end);
			self.loaded = true;
		end
	elseif event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	elseif self.loaded then
		updateCurrency("half",true);
		updateBroker();
		if (tt) and (tt.key) and (tt.key==ttName) and (tt:IsShown()) then
			createTooltip(false, tt)
		end
	end
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttColumns=2;
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT")
	createTooltip(self, tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

--[[ IDEAS: get max count and weekly max count of a currency for displaying caped counts in red. ]]

