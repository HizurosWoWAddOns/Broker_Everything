
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Currency";
L.Currency = CURRENCY;
local ldbName,ttName = name,name.."TT";
local tt,tt2,ttColumns,createMenu
local GetCurrencyInfo = GetCurrencyInfo
local currencies,currencies_num,currenciesName2Id = {},0,{};
local UPDATE_LOCK = false;
local tt2positions = {
	["BOTTOM"] = {edgeSelf = "TOP",    edgeParent = "BOTTOM", x =  0, y = -2},
	["LEFT"]   = {edgeSelf = "RIGHT",  edgeParent = "LEFT",   x = -2, y =  0},
	["RIGHT"]  = {edgeSelf = "LEFT",   edgeParent = "RIGHT",  x =  2, y =  0},
	["TOP"]    = {edgeSelf = "BOTTOM", edgeParent = "TOP",    x =  0, y =  2}
}
local currency_params = {blacklist={[141]=true,[483]=true,[484]=true,[692]=true}, cut={[395]=true,[396]=true,[392]=true}, start=42, stop=799}
local currency = nil


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name..'_Neutral']  = {iconfile="Interface\\minimap\\tracking\\BattleMaster", coords={0.1,0.9,0.1,0.9}}	--IconName::Currency_Neutral--
I[name..'_Horde']    = {iconfile="Interface\\PVPFrame\\PVP-Currency-Horde", coords={0.1,0.9,0.1,0.9}}		--IconName::Currency_Horde--
I[name..'_Alliance'] = {iconfile="Interface\\PVPFrame\\PVP-Currency-Alliance", coords={0.1,0.9,0.1,0.9}}	--IconName::Currency_Alliance--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show your different currencies."]
ns.modules[name] = {
	desc = desc,
	icon_suffix = "_Neutral",
	events = {
		"PLAYER_ENTERING_WORLD",
		"KNOWN_CURRENCY_TYPES_UPDATE",
		"CURRENCY_DISPLAY_UPDATE"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		shortTT = false,
		subTTposition = "AUTO",
		currenciesInTitle = {false,false,false,false},
		favCurrencies = {},
		favMode=false
	},
	config_allowed = {
		subTTposition = {["AUTO"]=true,["TOP"]=true,["LEFT"]=true,["RIGHT"]=true,["BOTTOM"]=true}
	},
	config = {
		{ type="header", label=L[name], align="left", icon=true },
		{ type="separator" },
		{ type="toggle", name="shortTT", label=L["short Tooltip"], tooltip=L["display the content of the tooltip shorter"] },
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
		{ type="toggle", name="favMode", label=L["Favorite mode"], tooltip=L["Display as favorite selected currencies only."], disabled=true }
	},
	clickOptions = {
		["1_open_character_info"] = {
			cfg_label = "Open currency pane",
			cfg_desc = "open the currency pane",
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
local function collectData() -- collect currency data
	if (UPDATE_LOCK) then return; end
	UPDATE_LOCK = true;
	local GetCurrencyListInfo = GetCurrencyListInfo;
	local itemname, isHeader, isExpanded, isUnused, isWatched, count, icon, currencyId
	currencies_num = 0
	wipe(currencies);

	local collapsed = {};
	local indexes = {};
	local num = GetCurrencyListSize();
	local invertI = num+1;
	for i=1, GetCurrencyListSize() do
		invertI = invertI-1;
		itemname, isHeader, isExpanded, isUnused, isWatched, count, icon = GetCurrencyListInfo(invertI)
		if (isHeader) then
			collapsed[itemname]=(not isExpanded);
			indexes[itemname]=invertI;
			if (not isExpanded) then
				ExpandCurrencyList(invertI,1);
			end
		end
	end

	local expanded;
	for i=1, GetCurrencyListSize() do
		itemname, isHeader, isExpanded, isUnused, isWatched, count, icon = GetCurrencyListInfo(i)
		currencyId = currency.id[itemname]

		if (isHeader) then
			expanded = (collapsed[itemname]~=true);
		end

		currencies[i] = {
			name = itemname,
			id = currencyId,
			isHeader = isHeader,
			isUnused = isUnused,
			isExpanded = expanded,
			count = count,
			maxCount = currencyId~=nil and currency.total[currencyId] or false,
			maxWeekly = currencyId~=nil and currency.weekly[currencyId] or false,
			icon = icon
		}

		if (itemname) then
			currenciesName2Id[itemname] = i
		end
		if (not isHeader) then
			currencies_num=currencies_num+1
		else
			currencies[i].index = indexes[itemname]
		end
	end

	num = GetCurrencyListSize();
	invertI = num+1;
	for i=1, num do
		invertI = invertI-1;
		itemname, isHeader, isExpanded, isUnused, isWatched, count, icon = GetCurrencyListInfo(invertI)
		if (isHeader) and (collapsed[itemname]==true) then
			ExpandCurrencyList(invertI,0);
		end
	end
	UPDATE_LOCK = false;
end

local function updateTitle()
	local title = {}
	for i, v in ipairs(Broker_EverythingDB[name].currenciesInTitle) do
		if (v) and (currenciesName2Id[v]~=nil) and (currencies[currenciesName2Id[v]]~=nil) then
			local d = currencies[currenciesName2Id[v]]
			if (not d.isUnused) and (d.icon) then
				table.insert(title, d.count .. "|T" .. d.icon .. ":0|t")
			end
		end
	end
	local obj = ns.LDB:GetDataObjectByName(ldbName)
	if #title==0 then
		obj.text = L[name]
	else
		obj.text = table.concat(title," ")
	end
end

local function setInTitle(titlePlace, currencyName, parent)
	if Broker_EverythingDB[name].currenciesInTitle[titlePlace] ~= currencyName then
		for i, v in pairs(Broker_EverythingDB[name].currenciesInTitle) do
			if titlePlace~=i and Broker_EverythingDB[name].currenciesInTitle[i]==currencyName then return end
		end
		Broker_EverythingDB[name].currenciesInTitle[titlePlace] = currencyName
	else
		Broker_EverythingDB[name].currenciesInTitle[titlePlace] = false
	end
	updateTitle()
end

function createMenu(parent)
	if (tt~=nil) and (tt:IsShown()) then tt:Hide(); end

	local inTitle = setmetatable({},{__index=function() return false end})
	collectData()
	for place=1, 4 do
		if Broker_EverythingDB[name].currenciesInTitle[place] then
			inTitle[Broker_EverythingDB[name].currenciesInTitle[place] ] = true
		end
	end

	ns.EasyMenu.InitializeMenu();

	ns.EasyMenu.addEntry({ label=L["Currency in title - menu"], title=true});
	ns.EasyMenu.addEntry({separator=true});

	for place=1, 4 do
		local pList,d;
		local missingCurrency = true;
		if (Broker_EverythingDB[name].currenciesInTitle[place]) then
			local id = currenciesName2Id[Broker_EverythingDB[name].currenciesInTitle[place]];
			d = currencies[id];
			if (d~=nil) then
				pList = ns.EasyMenu.addEntry({
					label = (C("dkyellow","%s%d:").."  |T%s:20:20:0:0|t %s"):format(L["Place"],place,d.icon,C("ltblue",d.name)) .. ((d.isUnused) and C("orange"," ("..UNUSED..")") or ""),
					arg1 = place,
					arg2 = d.name,
					arrow = true;
					func = function()
						setInTitle(place,d.name);
					end
				});
				missingCurrency = false;
			end
		end
		if (missingCurrency) then
			pList = ns.EasyMenu.addEntry({
				label = (C("dkyellow","%s%d:").."  %s"):format(L["Place"],place,L["Add a currency"]),
				arrow = true
			});
		end
		if (d) then
			ns.EasyMenu.addEntry({ label = C("ltred",L["Remove the currency"]), func=function() setInTitle(place,d.name); end }, pList);
			ns.EasyMenu.addEntry({separator=true}, pList);
		end
		local I = 1;
		for k,v in pairs(currencies) do
			if (v.name) and (v.name~=UNUSED) and (not v.isUnused) then
				if (I>1) and (v.isHeader) then
					ns.EasyMenu.addEntry({separator=true},pList);
				end
				local name = v.name;
				if (not inTitle[v.name]) then
					name = C( v.isHeader and "ltblue" or "ltyellow", name)
				end
				ns.EasyMenu.addEntry({
					label = name,
					icon = v.icon,
					title = (v.isHeader),
					disabled = (inTitle[v.name]),
					func = function() setInTitle(place,v.name); end
				}, pList);
				I = I + 1;
			end
		end
	end

	ns.EasyMenu.addConfigElements(name,true);

	ns.EasyMenu.ShowMenu(parent);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	if self then
		updateTitle()
	end
end

ns.modules[name].onevent = function(self,event,msg)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end

	if (currency==nil) then
		-- collect localized names and currencyID's
		currency = {id={},name={},weekly={}, total={}}
		local currencyName, currentAmount, texture, earnedThisWeek, weeklyMax, totalMax, isDiscovered
		local _=function(id,num) if currency_params.cut[id]==true then num=floor(num/100) end return num end
		for i=currency_params.start, currency_params.stop do
			if currency_params.blacklist[i]~=true then
				currencyName, currentAmount, texture, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(i)
				if currencyName~=nil and currencyName~="" then
					currency.id[currencyName] = i
					currency.name[i] = currencyName
					if type(weeklyMax)=="number" and weeklyMax>0 then
						currency.weekly[i] = _(i,weeklyMax)
					end
					if type(totalMax)=="number" and totalMax>0 then
						currency.total[i] = _(i,totalMax)
					end
				end
			end
		end
	end

	local obj = ns.LDB:GetDataObjectByName(ldbName)
	if UnitFactionGroup("player") ~= "Neutral" then
		local i = I(name.."_"..UnitFactionGroup("player"))
		obj.iconCoords = i.coords or {0,1,0,1}
		obj.icon = i.iconfile
	end
	collectData()
	updateTitle()

	if (tt) and (tt.key) and (tt.key==ttName) and (tt:IsShown()) then
		ns.modules[name].ontooltip(tt);
	end
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)
	if (not tt.key) or (tt.key~=ttName) then return; end -- don't override other LibQTip tooltips...
	local l,c;
	tt:Clear()
	tt:AddHeader(C("dkyellow",L[name]))
	if Broker_EverythingDB[name].shortTT == true then
		tt:AddSeparator()
	end

	for i,v in ipairs(currencies) do
		if (not v.isUnused) then
			if (v.isHeader) then
				if Broker_EverythingDB[name].shortTT == false then
					tt:AddSeparator(4,0,0,0,0)
					l,c = tt:AddLine(C("ltblue",v.name))
					tt:SetLineScript(l,"OnMouseUp",function()
						ExpandCurrencyList(v.index, (v.isExpanded) and 0 or 1 );
					end);
					if (v.isExpanded) then
						tt:AddSeparator()
					end
				end
			elseif (v.isExpanded) then
				local line, column = tt:AddLine(C("ltyellow",v.name),v.count.."  |T"..v.icon..":14:14:0:0:64:64:4:56:4:56|t")
				local lineObj = tt.lines[line]
				lineObj.currencyIndex = i

				tt:SetLineScript(line, "OnEnter",function(self)
					local pos = {}
					if (not tt2) then tt2=GameTooltip; end
					tt2:SetOwner(tt,"ANCHOR_NONE")

					if Broker_EverythingDB[name].subTTposition == "AUTO" then
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
						pos = tt2positions[Broker_EverythingDB[name].subTTposition]
					end

					tt2:SetPoint(pos.edgeSelf,tt,pos.edgeParent, pos.x , pos.y)
					-- changes for user choosen direction
					tt2:ClearLines()
					tt2:SetCurrencyToken(self.currencyIndex) -- tokenId / the same index number if needed by GetCurrencyListInfo
					tt2:Show()
				end)

				tt:SetLineScript(line, "OnLeave", function(self)
					if (tt2) then tt2:Hide(); end
				end)
			end
		end
	end

	if (Broker_EverythingDB.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttColumns=2;
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT")
	ns.modules[name].ontooltip(tt)
	ns.createTooltip(self,tt);
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

do
	local dummyEventFunc = function()
		if (UPDATE_LOCK) then return; end
		ns.modules[name].onevent(nil,"BE_DUMMY_EVENT");
	end;
	_G["TokenFramePopupInactiveCheckBox"]:HookScript("OnClick",dummyEventFunc);
	hooksecurefunc("ExpandCurrencyList",dummyEventFunc);
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

--[[ IDEAS: get max count and weekly max count of a currency for displaying caped counts in red. ]]

