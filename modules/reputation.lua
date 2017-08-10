
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Reputation"; -- REPUTATION
local ttName, ttColumns, tt, createMenu,createTooltip,updateBroker = name.."TT", 6;
local Name,description,standingID,barMin,barMax,barValue,atWarWith,canToggleAtWar,isHeader,isCollapsed,hasRep,isWatched,isChild,factionID,hasBonusRepGain,canBeLFGBonus=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16; -- index list for GetFactionInfo
local factionStandingText,rewardPercent,rewardValue,rewardMax,hasRewardPending,rewardCount=17,18,19,20,21,22;

local bars,wasShown = {},false;
local allinone = 85000;
local allinone_friend = 43000;
local allinone_bodyguard = 31000;
local session,initSessionTicker = {};
local collapsed,round = {},-1;
local bodyguards,known_bodyguards = {193,207,216,218,219},{};
local idStr = C("gray"," (%d)");
local formats = {
	["_NONE"]       = "None",
	["Percent"]     = "25.4%",
	["PercentNeed"] = "22.2% need",
	["Number"]      = "1234/3000",
	["NumberNeed"]  = "321 need",
};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\Achievement_Reputation_01", coords={0.1,0.9,0.1,0.9}} --IconName::Reputation--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show faction standing of your character"],
	label = REPUTATION,
	--icon_suffix = "",
	events = {
		"PLAYER_ENTERING_WORLD",
		"UPDATE_FACTION"
	},
	updateinterval = nil, --0.5, -- 10
	config_defaults = {
		bgBars = "single",
		standingText = true,
		showSession = true,
		showID = false,
		numbers = "Percent",
		watchedNameOnBroker = true,
		watchedStandingOnBroker = true,
		watchedSessionBroker = true,
		watchedFormatOnBroker = "Percent",
		rewardBeyondExalted = "value_max"
	},
	config_allowed = nil,
	config_header = {type="header", label=REPUTATION, align="left", icon=true},
	config_broker = {
		{ type="toggle", name="watchedNameOnBroker", label=L["Name of watched faction"], tooltip=L["Display name of watched faction on broker button"], event="UPDATE_FACTION" },
		{ type="toggle", name="watchedStandingOnBroker", label=L["Standing of watched faction"], tooltip=L["Display standing of watched faction on broker button"], event="UPDATE_FACTION" },
		{ type="toggle", name="watchedSessionBroker", label=L["Earn/loss of watched faction"], tooltip=L["Display earn/loss reputation of watched faction on broker button"], event="UPDATE_FACTION" },
		{ type="select", name="watchedFormatOnBroker", label=L["Format of watched faction"], tooltip=L["Choose display format of watched faction"],
			values = formats,
			default = "Percent",
			event="UPDATE_FACTION"
		},
		--{ type="toggle", name="favsOnly", label=L["Favorites only"], tooltip=L["Show favorites only in tooltip"] }
	},
	config_tooltip = {
		{ type="select",
			name	= "numbers",
			label	= L["Numeric format"],
			tooltip	= L["How would you like to view numeric reputation format."],
			values	= formats,
			default = "Percent",
		},
		{ type="toggle", name="standingText", label=L["Standing text"], tooltip=L["Show standing text in tooltip"]},
		{ type="toggle", name="showSession", label=L["Show session earn/loss"], tooltip=L["Display session earned/loss reputation in tooltip"]},
		{ type="select",
			name	= "bgBars",
			label	= L["Background reputation bar mode"],
			tooltip	= L["How would you like to view the background reputation bar."],
			values	= {
				["_NONE"]       = "None",
				["single"]     = "Single standing level",
				["allinone"] = "All standing level in one",
			},
			default = "single",
		},
		{ type="toggle", name="showID", label=L["Show id's"], tooltip=L["Display faction and standing id's in tooltip"]},
		{ type="select",
			name = "rewardBeyondExalted",
			label = L["Reward beyond exalted"],
			tooltip = L["Display reputation collecting for rewards beyond exalted"],
			values = {
				["_NONE"] = "None",
				["percent"] = L["Percent"],
				["value_max"] = L["Value/Cap"]
			}
		}
	},
	config_misc = {"shortNumbers"},
	clickOptions = {
		["1_open_reputation"] = {
			cfg_label = "Open reputation pane", -- L["Open reputation pane"]
			cfg_desc = "open the reputation pane", -- L["open the reputation pane"]
			cfg_default = "_LEFT",
			hint = "Open reputation pane",
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCharacter","ReputationFrame");
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
local function resetSession()
	local _;
	for i,v in pairs(session) do
		_,_,_,_,_,session[i] = GetFactionInfoByID(i);
	end
	updateBroker();
end

function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.addEntry({separator=true});
	ns.EasyMenu.addEntry({ label = C("yellow",L["Reset session earn/loss reputation"]), func=resetSession, keepShown=false });
	ns.EasyMenu.ShowMenu(self);
end

local function GetSession(factionID,current)
	if not session[factionID] then
		return "";
	end
	local col,str,diff = "gray",false,current-session[factionID];
	if diff>0 then
		col,str = "ltgreen","+"..diff;
	elseif diff<0 then
		col,str = "ltred",diff;
	end
	if str then
		return C(col,str);
	end
	return "";
end

function updateBroker()
	local txt,mode = REPUTATION,ns.profile[name].watchedFormatOnBroker;
	local Name, standingId, barMin, barMax, barValue, factionID = GetWatchedFactionInfo();
	barMax = standingId==8 and 999 or (barMax - barMin);
	local barValue2 = barValue - barMin;
	barMin = 0;

	if Name then
		local tmp = {};
		if ns.profile[name].watchedNameOnBroker then
			tinsert(tmp,Name);
		end
		if(mode=="Percent")then
			tinsert(tmp,("%1.1f%%"):format(barValue2/barMax*100));
		elseif(mode=="PercentNeed")then
			tinsert(tmp,("%1.1f%% "..L["need"]):format(100-(barValue2/barMax*100)));
		elseif(mode=="Number")then
			tinsert(tmp,ns.FormatLargeNumber(name,barValue2).."/"..ns.FormatLargeNumber(name,barMax));
		elseif(mode=="NumberNeed")then
			tinsert(tmp,ns.FormatLargeNumber(name,barMax-barValue2).." "..L["need"]);
		end
		if ns.profile[name].watchedStandingOnBroker then
			tinsert(tmp,_G["FACTION_STANDING_LABEL"..standingId]);
		end
		if ns.profile[name].watchedSessionBroker then
			local val = GetSession(factionID,barValue);
			if val~="" then
				tinsert(tmp,val);
			end
		end
		if #tmp>0 then
			txt = table.concat(tmp,", ");
		end
	end

	ns.LDB:GetDataObjectByName(ns.modules[name].ldbName).text = txt;
end

local function updateBars()
	local bgWidth = false;
	for i,v in ipairs(bars)do
		if(v~=nil and v:IsShown() and v.percent)then
			v.BarSingle:Hide();
			v.BarAIO:Hide();
			v.BarAIO_friend:Hide();
			v.BarAIO_bodyguard:Hide();

			if not bgWidth then
				bgWidth=v.Bg:GetWidth();
			end

			if(ns.profile[name].bgBars=="single")then
				local width = bgWidth*v.percent;
				v.BarSingle:SetWidth(width>1 and width or 1);
				v.BarSingle:Show();
			elseif(ns.profile[name].bgBars=="allinone")then
				if(v.bodyguard)then
					local totalPercent = (v.data[barValue] / allinone_bodyguard);
					if v.data[barMax]==1 then totalPercent = 1; end
					v.BarAIO_bodyguard:SetTexCoord(0, 916/1024 * totalPercent, 0, 1);
					v.BarAIO_bodyguard:SetWidth((bgWidth * totalPercent)+0.1);
					v.BarAIO_bodyguard:Show();
				elseif(v.friend)then
					local totalPercent = (v.data[barValue] / allinone_friend);
					if v.data[barMax]==1 then totalPercent = 1; end
					v.BarAIO_friend:SetTexCoord(0, 870/1024 * totalPercent, 0, 1);
					v.BarAIO_friend:SetWidth((bgWidth * totalPercent)+0.1);
					v.BarAIO_friend:Show();
				else
					local totalPercent = ((v.data[barValue] + 42000) / allinone);
					v.BarAIO:SetTexCoord(0, 850/1024 * totalPercent, 0, 1);
					v.BarAIO:SetWidth((bgWidth * totalPercent)+0.1);
					v.BarAIO:Show();
				end
			end
		end
	end
end

local function tooltipOnHide()
	for i=1, #bars do
		bars[i]:SetParent(nil);
		bars[i]:ClearAllPoints();
		bars[i]:Hide();
	end
end

local function toggleHeader(self)
	if (self.isCollapsed) then
		ExpandFactionHeader(self.index);
	else
		CollapseFactionHeader(self.index);
	end
	tooltipOnHide();
	createTooltip(tt);
end

local function ttAddLine(tt,mode,data,count,childLevel)
	local inset,line,_barMax,_barValue = 0, {}, data[barMax]-data[barMin], data[barValue]-data[barMin];
	if(data[standingID]==8)then _barMax=999; end
	local percent = _barValue/_barMax;

	local color,icon,inset = "ltyellow","",1+childLevel;
	if data[isHeader] then
		inset=inset-1;
		color,icon = "ltblue","|Tinterface\\buttons\\UI-MinusButton-Up:0|t ";
		if data[isCollapsed] then
			color,icon = "ltyellow","|Tinterface\\buttons\\UI-PlusButton-Up:0|t ";
		end
	end

	local id = "";
	if ns.profile[name].showID then
		id = idStr:format(data[factionID]);
	end

	tinsert(line,
		strrep("    ",inset)..icon..
		C(color,ns.strCut(tostring(data[Name]),24))..id..
		(data[atWarWith] and " |TInterface\\buttons\\UI-Checkbox-SwordCheck:12:12:0:-1:32:32:0:18:0:18|t" or "")
	);

	if(ns.profile[name].standingText)then
		local id = "";
		if ns.profile[name].showID then
			id = idStr:format(data[standingID]);
		end
		tinsert(line,data[factionStandingText]..id);
	end

	if(mode=="Percent")then
		tinsert(line,("%1.1f%%"):format(_barValue/_barMax*100));
	elseif(mode=="PercentNeed")then
		tinsert(line,("%1.1f%% "..L["need"]):format(100-(_barValue/_barMax*100)));
	elseif(mode=="Number")then
		tinsert(line,ns.FormatLargeNumber(name,_barValue,true).."/"..ns.FormatLargeNumber(name,_barMax,true));
	elseif(mode=="NumberNeed")then
		tinsert(line,ns.FormatLargeNumber(name,_barMax-_barValue,true).." "..L["need"]);
	end

	if not data[rewardPercent] and ns.profile[name].showSession and data[barValue] and session[data[factionID]] then
		tinsert(line,GetSession(data[factionID],data[barValue]));
	end

	if data[rewardPercent] and ns.profile[name].rewardBeyondExalted~="_NONE" then
		tinsert(line," ");
		local field = "";
		if ns.profile[name].rewardBeyondExalted=="percent" then
			field = ("%1.1f%%"):format(data[rewardPercent]);
		else
			field = ("%d/%d"):format(data[rewardValue],data[rewardMax]);
		end
		if data[hasRewardPending] then
			field = field.." |TInterface/GossipFrame/ActiveQuestIcon:14:14:0:0|t";
		else
			field = field.." |TInterface/GossipFrame/VendorGossipIcon:14:14:0:0|t";
		end
		tinsert(line,field);
	end

	for i=#line, ttColumns do
		tinsert(line," ");
	end

	local l=tt:AddLine(unpack(line));

	if data[isHeader] then
		tt.lines[l].isCollapsed = data[isCollapsed];
		tt.lines[l].index = data.index;
		tt:SetLineScript(l,"OnMouseUp",toggleHeader);
	end

	if(ns.profile[name].bgBars=="single") or (ns.profile[name].bgBars=="allinone")then
		if(not bars[count])then
			bars[count] = CreateFrame("Frame","BERepurationBar"..count,nil,"BEReputationBarTemplate");
		end
		bars[count]:SetParent(tt.lines[l]);
		bars[count]:SetPoint("TOPLEFT",tt.lines[l].cells[1],"TOPLEFT",0,1);
		bars[count]:SetPoint("BOTTOMRIGHT",tt.lines[l].cells[#tt.lines[l].cells],"BOTTOMRIGHT",0,-1);
		bars[count]:SetAlpha(0.6);
		bars[count]:Show();
		bars[count].data = data;
		bars[count].standing = data[standingID];
		bars[count].percent = (_barValue/_barMax);
		bars[count].bodyguard = known_bodyguards[data[Name]] or false;
		bars[count].friend = data[factionStandingText]~=_G["FACTION_STANDING_LABEL"..data[standingID]];
	end

	local darker = 0.72;
	if(ns.profile[name].bgBars=="single")then
		local color = FACTION_BAR_COLORS[data[standingID]];
		bars[count].BarSingle:SetVertexColor(color.r*darker,color.g*darker,color.b*darker,1);
		bars[count].BarSingle:Show();
	end
end

local function tooltipOnHide(self)
	for i,v in ipairs(bars)do
		v:SetParent(nil);
		v:ClearAllPoints();
		v:Hide();
	end
	self:SetScript("OnHide",nil);
end

function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",REPUTATION));

	local count,countHeader,childLevel,num,margoss,firstHeader = 0,0,0,GetNumFactions();

	for i=1, num do
		local data = {GetFactionInfo(i)};
		data.index = i;
		if i==1 and data[isHeader] then
			firstHeader = data[isCollapsed];
		end

		if data[Name] and data[barMax]>0 then
			data[factionStandingText] = _G["FACTION_STANDING_LABEL"..data[standingID]];

			if data[factionID] and data[barValue] and session[data[factionID]]==nil then
				session[data[factionID]] = data[barValue];
			end

			local friendID,friendRep,friendMaxRep,friendName,friendText,friendTexture,friendTextLevel,friendThreshold,nextFriendThreshold = GetFriendshipReputation(data[factionID]);
			if friendID~=nil then
				data[factionStandingText] = friendTextLevel;
				if ( nextFriendThreshold ) then
					data[barMin], data[barMax], data[barValue] = friendThreshold, nextFriendThreshold, friendRep;
				else
					data[barMin], data[barMax], data[barValue] = 0, 1, 1;
				end
			elseif data[standingID]==8 then
				data[barValue] = data[barValue]+999;
			end

			if data[factionID] and C_Reputation.IsFactionParagon(data[factionID]) then
				local rewardCurrentValue, rewardThreshold, rewardQuestID, _hasRewardPending = C_Reputation.GetFactionParagonInfo(data[factionID]);
				if rewardCurrentValue~=nil then
					if rewardCurrentValue > rewardThreshold then
						rewardCurrentValue = rewardCurrentValue - rewardThreshold;
					end
					data[rewardMax] = rewardThreshold;
					data[rewardValue] = mod(rewardCurrentValue, rewardThreshold);
					data[rewardPercent] = (data[rewardValue]/data[rewardMax])*100;
					data[hasRewardPending] = _hasRewardPending;
				end
			end

			if data[isHeader] then
				tt:AddSeparator(4,0,0,0,0);
				childLevel = data[isChild] and 1 or 0;
				if data[hasRep] then
					count=count+1;
					ttAddLine(tt,ns.profile[name].numbers,data,count,childLevel);
				else
					local color,icon,prefix = "ltblue","|Tinterface\\buttons\\UI-MinusButton-Up:0|t ",strrep("    ",childLevel);
					if data[isCollapsed] then
						color,icon = "gray","|Tinterface\\buttons\\UI-PlusButton-Up:0|t ";
					end
					local l=tt:AddLine(C(color,prefix..icon..data[Name]));
					if data[isHeader] then
						tt.lines[l].isCollapsed = data[isCollapsed];
						tt.lines[l].index = data.index;
						tt:SetLineScript(l,"OnMouseUp",toggleHeader);
					end
				end
				if not data[isCollapsed] then
					tt:AddSeparator();
				end
			else
				count=count+1;
				ttAddLine(tt,ns.profile[name].numbers,data,count,childLevel);
			end
		end

	end
	wasShown=true;

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);

	if #bars>0 then
		tt:SetScript("OnHide", tooltipOnHide);
	end
	C_Timer.After(0.1,updateBars);
end

local function initSessionCurrencies()
	if round==-1 then
		for i=GetNumFactions(),1,-1 do
			local _,_,_,_,_,_,_,_,_,isCollapsed=GetFactionInfo(i);
			if isCollapsed then
				tinsert(collapsed,1,i);
				ExpandFactionHeader(i);
			end
		end
	elseif round==0 then
		for i=1, GetNumFactions() do
			local _, _, standingID, _, _, barValue, _, _, _, _, _, _, _, factionID = GetFactionInfo(i);
			if factionID and barValue and session[factionID]==nil then
				session[factionID] = barValue + (standingID==8 and 999 or 0);
			end
		end
	else
		if not collapsed[round] then
			initSessionTicker:Cancel();
			return;
		end
		CollapseFactionHeader(collapsed[round]);
	end
	round=round+1;
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules[name].init = function() end

ns.modules[name].onevent = function(self,event,...)
	if event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	elseif not self.loadedBodyguards then
		local glvl = C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_6_0);
		if UnitLevel("player")>=90 and glvl then
			for i=1,#bodyguards do
				local data = C_Garrison.GetFollowerInfo(bodyguards[i]);
				if(data and data.name)then
					known_bodyguards[data.name]=true;
				end
			end
			self.loadedBodyguards=true;
		end
	end
	if not self.loadedSession then
		initSessionTicker = C_Timer.NewTicker(.3,initSessionCurrencies);
		self.loadedSession=true;
	end
	updateBroker();
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "LEFT", "RIGHT", "CENTER", "RIGHT", "RIGHT", "RIGHT"},{false},{self},{OnHide=tooltipOnHide});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button)m end
-- ns.modules[name].ondblclick = function(self,button) end
