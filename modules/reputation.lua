
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Reputation"; -- REPUTATION L["ModDesc-Reputation"]
local ttName, ttColumns, tt, module,createTooltip,updateBroker = name.."TT", 6;
local Name,description,standingID,barMin,barMax,barValue,atWarWith,canToggleAtWar,isHeader,isCollapsed,hasRep,isWatched,isChild,factionID,hasBonusRepGain,canBeLFGBonus=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16; -- index list for GetFactionInfo
local barPercent,sessionValue,factionStandingText,friendID,isParagon,hideSession,rewardMin,rewardMax,rewardValue,rewardQuestID,rewardPercent,hasRewardPending,rewardsFinished,rewardSessionValue=30,31,32,33,34,35,36,37,38,39,40,41,42,43,44;

local tinsert,tconcat,ipairs,pairs,unpack=tinsert,table.concat,ipairs,pairs,unpack;
local CTimerAfter,IsFactionParagon,GetFactionParagonInfo = C_Timer.After
local GetFriendshipReputation,GetFactionInfoByID,CTimerNewTicker = GetFriendshipReputation,GetFactionInfoByID,C_Timer.NewTicker;
local ExpandFactionHeader,CollapseFactionHeader,GetWatchedFactionInfo = ExpandFactionHeader,CollapseFactionHeader,GetWatchedFactionInfo;
local GetNumFactions,GetFactionInfo,GetFactionInfoByID = GetNumFactions,GetFactionInfo,GetFactionInfoByID;

local bars,factions,session,spacer,initReputationListTicker = {},{},{},"    ";
local allinone = {faction=85000,friend=43000,bodyguard=31000};
local bodyguards,known_bodyguards = {193,207,216,218,219},{};
local round,collapsedL1,collapsedL2,paragonQuestIDs = false,{},{},{};
local idStr = C("gray"," (%d)");
local formats = {
	["_NONE"]       = "None",
	["Percent"]     = "25.4%",
	["PercentNeed"] = "22.2% need",
	["Number"]      = "1234/3000",
	["NumberNeed"]  = "321 need",
};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\Achievement_Reputation_01", coords={0.1,0.9,0.1,0.9}} --IconName::Reputation--


-- some local functions --
--------------------------
if C_Reputation then
	IsFactionParagon,GetFactionParagonInfo = C_Reputation.GetFactionParagonInfo,C_Reputation.IsFactionParagon
else
	function IsFactionParagon()
		return false;
	end
	function GetFactionParagonInfo()
		return;
	end
end

local function _GetFactionInfoByID(faction_id,paragonOnly)
	local data = {GetFactionInfoByID(faction_id)};

	if data[factionID]==nil then
		data[factionID] = faction_id;
	end

	if data[Name]:find("%\r%\n") then
		data[Name] = data[Name]:gsub("%\r%\n","");
	end

	if data[factionID]>0 then
		if not paragonOnly then
			-- faction standing text
			data[factionStandingText] = _G["FACTION_STANDING_LABEL"..data[standingID]];

			-- IsFriend
			if GetFriendshipReputation then
				local _friendID,friendRep,friendMaxRep,friendName,friendText,friendTexture,friendTextLevel,friendThreshold,nextFriendThreshold = GetFriendshipReputation(data[factionID]);
				if _friendID~=nil then
					data[friendID] = _friendID;
					data[factionStandingText] = friendTextLevel;
					if nextFriendThreshold then
						data[barMin], data[barMax], data[barValue] = friendThreshold, nextFriendThreshold, friendRep;
					else
						data[barMin], data[barMax], data[barValue] = 0, 1, 1;
						data[hideSession] = true
					end
				elseif data[standingID]==8 then
					data[barMin], data[barMax], data[barValue] = 42000, 42999, 42999;
				end
			end
			data[barPercent] = 1;
			if (data[barMax]-data[barMin])~=0 then
				data[barPercent] = (data[barValue]-data[barMin])/(data[barMax]-data[barMin]);
			end

			-- session difference
			data[sessionValue] = 0;
			if not data[hideSession] then
				if data[factionID] and data[barValue] and session[data[factionID]]==nil then
					session[data[factionID]] = data[barValue];
				end
				data[sessionValue] = data[barValue]-session[data[factionID]];
			end
		end

		-- IsParagon
		data[isParagon] = IsFactionParagon(data[factionID]);
		if data[factionID] and data[isParagon] then
			local _value, _threshold, _rewardQuestID, _hasPending = C_Reputation.GetFactionParagonInfo(data[factionID]);
			if _value~=nil then
				C_Reputation.RequestFactionParagonPreloadRewardData(data[factionID]);
				data[rewardQuestID] = _rewardQuestID;
				data[rewardsFinished] = 0;
				paragonQuestIDs[_rewardQuestID] = true;
				if _value > _threshold then
					data[rewardsFinished] = floor(_value/_threshold);
					_value = _value - data[rewardsFinished]*_threshold;
				end
				data[rewardMin],data[rewardMax],data[rewardValue],data[hasRewardPending] = 0,_threshold,mod(_value, _threshold), _hasPending;
				data[rewardPercent] = _value / _threshold;

				-- paragon session difference
				if session[data[factionID].."_paragon"] == nil then
					session[data[factionID].."_paragon"] = _value;
				end
				data[rewardSessionValue] = _value - session[data[factionID].."_paragon"];
			end
		end
	end

	return data;
end

local function initReputationList()
	if round==false then
		return false;
	elseif round<0 then
		-- uncollapse headers
		local collapsed
		if round==-2 then
			collapsedL1 = collapsedL1 or {};
			collapsed = collapsedL1;
		else
			collapsedL2 = collapsedL2 or {};
			collapsed = collapsedL2;
		end
		for i=GetNumFactions(),1,-1 do
			local _,_,_,_,_,_,_,_,_,isCollapsed=GetFactionInfo(i);
			if isCollapsed then
				tinsert(collapsed,1,i);
				ExpandFactionHeader(i);
			end
		end
		round=round+1;
	elseif round==0 then
		-- read factions
		wipe(factions);
		for i=1, GetNumFactions() do
			local fName, desc, standingID, barMin, barMax, barValue, _, _, isHeader, isCollapsed, hasRep, _, isChild, factionID = GetFactionInfo(i);
			tinsert(factions,{id=factionID or -1,isHeader=isHeader,isChild=isChild});
		end
		round=round+1;
	else
		-- collapse headers again
		local collapsed = round==1 and collapsedL2 or collapsedL1;
		if collapsed and #collapsed>0 then
			CollapseFactionHeader(collapsed[1]);
			tremove(collapsed,1);
			if #collapsed==0 then
				round=round+1;
			end
		elseif initReputationListTicker and initReputationListTicker~=true then
			initReputationListTicker:Cancel();
			collapsedL2,collapsedL1 = nil,nil;
			round = false;
		end
	end
end

local function resetSession()
	local _;
	for factionID in pairs(session) do
		_,_,_,_,_,session[factionID] = GetFactionInfoByID(factionID);
	end
	updateBroker();
end

local function updateBodyguards()
	-- collect names of bodyguards
	local glvl = C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_6_0 or Enum.GarrisonType.Type_6_0);
	if UnitLevel("player")>=90 and glvl then
		for i=1,#bodyguards do
			local data = C_Garrison.GetFollowerInfo(bodyguards[i]);
			if(data and data.name)then
				known_bodyguards[data.name]=true;
			end
		end
		return true;
	end
end

function updateBroker()
	local txt = REPUTATION;
	local _, _, _, _, _, _factionID = GetWatchedFactionInfo();

	if _factionID and _factionID>0 then
		local data = _GetFactionInfoByID(_factionID);

		local tmp = {};
		if ns.profile[name].watchedNameOnBroker then
			tinsert(tmp,data[Name]);
		end

		local _Min,_Max,_Value,_Percent
		if data[isParagon] then
			_Min,_Max,_Value,_Percent = data[rewardMin],data[rewardMax],data[rewardValue],data[rewardPercent]*100;
		else
			_Min,_Max,_Value,_Percent = 0,data[barMax]-data[barMin],data[barValue]-data[barMin],data[barPercent]*100;
		end

		if ns.profile[name].watchedCountOnBroker then
			if ns.profile[name].watchedCountPercentOnBroker then
				tinsert(tmp,("%1.1f%%"):format(_Percent));
			else
				tinsert(tmp,ns.FormatLargeNumber(name,_Value).."/"..ns.FormatLargeNumber(name,_Max));
			end
		end

		if ns.profile[name].watchedNeedOnBroker then
			if ns.profile[name].watchedNeedPercentOnBroker then
				tinsert(tmp,("%1.1f%% "..L["need"]):format(100-_Percent));
			else
				tinsert(tmp,ns.FormatLargeNumber(name,_Max-_Value).." "..L["need"]);
			end
		end

		if ns.profile[name].watchedStandingOnBroker then
			tinsert(tmp,data[factionStandingText]);
		end

		if ns.profile[name].watchedSessionBroker and not data[friendID] then
			if tonumber(data[sessionValue]) and data[sessionValue]~=0 then
				if data[sessionValue]>0 then
					tinsert(tmp,C("ltgreen","+"..data[sessionValue]));
				elseif data[sessionValue]<0 then
					tinsert(tmp,C("ltred","-"..data[sessionValue]));
				end
			elseif tonumber(data[rewardSessionValue]) and data[rewardSessionValue]~=0 then
				tinsert(tmp,C("ltgreen","+"..data[rewardSessionValue]));
			end
		end

		if #tmp>0 then
			txt = tconcat(tmp,", ");
		end
	end

	for i=1, #factions do
		local data = _GetFactionInfoByID(factions[i].id,true);
		if data[isParagon] and data[hasRewardPending] then
			txt = txt .. "|TInterface/GossipFrame/VendorGossipIcon:14:14:0:0|t|TInterface/GossipFrame/ActiveQuestIcon:14:14:0:0|t";
			break;
		end
	end

	ns.LDB:GetDataObjectByName(module.ldbName).text = txt;
end

local function updateBars()
	local bgWidth,bgBars = false,ns.profile[name].bgBars;
	for i,v in ipairs(bars)do
		if(v~=nil and v:IsShown() and v.percent)then
			v.BarSingle:Hide();
			v.BarAIO:Hide();
			v.BarAIO_friend:Hide();
			v.BarAIO_bodyguard:Hide();

			if not bgWidth then
				bgWidth=v.Bg:GetWidth();
			end

			if(bgBars=="single")then
				local width = bgWidth*v.percent;
				v.BarSingle:SetWidth(width>1 and width or 1);
				v.BarSingle:Show();
			elseif(bgBars=="allinone")then
				if(v.bodyguard)then
					local totalPercent = v.data[barMax]==1 and 1 or (v.data[barValue] / allinone.bodyguard);
					v.BarAIO_bodyguard:SetTexCoord(0, 916/1024 * totalPercent, 0, 1);
					v.BarAIO_bodyguard:SetWidth((bgWidth * totalPercent)+0.1);
					v.BarAIO_bodyguard:Show();
				elseif(v.friend)then
					local totalPercent = v.data[barMax]==1 and 1 or (v.data[barValue] / allinone.friend);
					v.BarAIO_friend:SetTexCoord(0, 870/1024 * totalPercent, 0, 1);
					v.BarAIO_friend:SetWidth((bgWidth * totalPercent)+0.1);
					v.BarAIO_friend:Show();
				else
					local totalPercent = v.data[standingID]==8 and 1 or ((v.data[barValue] + 42000) / allinone.faction);
					v.BarAIO:SetTexCoord(0, 850/1024 * totalPercent, 0, 1);
					v.BarAIO:SetWidth((bgWidth * totalPercent)+0.1);
					v.BarAIO:Show();
				end
			end
		end
	end
end

local function tooltipOnHide(self)
	for i=1, #bars do
		bars[i]:SetParent(nil);
		bars[i]:ClearAllPoints();
		bars[i]:Hide();
	end
	if self==tt then
		tt:SetScript("OnHide",nil);
	end
end

local function toggleHeader(self,data)
	ns.toon[name].headers[data[factionID]] = ns.toon[name].headers[data[factionID]]==nil and true or nil;
	tooltipOnHide();
	createTooltip(tt);
end

local function factionTooltipOnEnter(self,data)
	local _Min,_Max,_Value,_Percent = 0,data[barMax]-data[barMin],data[barValue]-data[barMin];
	local __value,__max,need = _Value, _Max, _Max-_Value;
	local fstr = "%s/%s (%1.1f%%)";

	GameTooltip:SetOwner(self,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(self,"horizontal",tt));
	GameTooltip:SetText(data[Name],1,1,1);

	GameTooltip:AddLine(" ");
	GameTooltip:AddDoubleLine(data[factionStandingText], fstr:format(__value,__max,data[barPercent]*100));
	if need>0 then
		GameTooltip:AddDoubleLine(" ",need.." "..L["need"]);
	end

	if data[isParagon] then
		--local num = GetNumQuestLogRewards(questID);
		local itemName, itemTexture, quantity, quality, isUsable, itemID = GetQuestLogRewardInfo(1, data[rewardQuestID]);
		if itemName then
			GameTooltip:AddLine(" ");
			GameTooltip:AddLine("|T"..itemTexture..":0|t "..ITEM_QUALITY_COLORS[quality].color:WrapTextInColorCode(itemName));
			GameTooltip:AddDoubleLine(" ",fstr:format(data[rewardValue],data[rewardMax], data[rewardPercent]*100));
		end
		--field = ("%1.1f%%"):format(data[rewardPercent]*100);
		--field = ("%s/%s"):format(ns.FormatLargeNumber(name,data[rewardValue],true),ns.FormatLargeNumber(name,data[rewardMax],true));

		--if data[hasRewardPending] then
			--field = field.." |TInterface/GossipFrame/ActiveQuestIcon:14:14:0:0|t";
		--else
			--field = field.." |TInterface/GossipFrame/VendorGossipIcon:14:14:0:0|t";
		--end

	end

	GameTooltip:Show();
end

function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",REPUTATION));

	local depth,count = 0,0;
	local parentIsCollapsed1,parentIsCollapsed2,mode = false,false,ns.profile[name].numbers;
	for i=1, #factions do
		local show = true;
		if (factions[i].isHeader and not factions[i].isChild) then
			parentIsCollapsed1 = ns.toon[name].headers[factions[i].id]~=nil;
			parentIsCollapsed2 = nil;
		elseif (factions[i].isHeader and factions[i].isChild) and parentIsCollapsed1==false then
			parentIsCollapsed2 = ns.toon[name].headers[factions[i].id]~=nil and true or nil;
		elseif not parentIsCollapsed1 then
			show = not parentIsCollapsed2;
		else
			show = not parentIsCollapsed1;
		end

		if factions[i].isHeader then -- for current headers itself
			depth = factions[i].isChild and 1 or 0;
		end

		if show then
			local data = _GetFactionInfoByID(factions[i].id);
			if data[isHeader] and not data[hasRep] then
				local color,icon = "ltblue","|Tinterface\\buttons\\UI-MinusButton-Up:0|t ";
				if ns.toon[name].headers[data[factionID]] then
					color,icon = "gray","|Tinterface\\buttons\\UI-PlusButton-Up:0|t ";
				end
				local l=tt:AddLine(C(color,spacer:rep(depth)..icon..data[Name]));
				if data[isHeader] then
					tt:SetLineScript(l,"OnMouseUp",toggleHeader,data);
				end
			else
				count = count + 1;

				local inset,line = 0,{};
				local color,icon,inset = "ltyellow","",1+depth;
				if data[isHeader] then
					inset=inset-1;
					color,icon = "ltblue","|Tinterface\\buttons\\UI-MinusButton-Up:0|t ";
					if data[isCollapsed] then
						color,icon = "ltyellow","|Tinterface\\buttons\\UI-PlusButton-Up:0|t ";
					end
				end

				local _Min,_Max,_Value,_Percent = 0,data[barMax]-data[barMin],data[barValue]-data[barMin];

				local id = ns.profile[name].showID and idStr:format(data[factionID]) or "";
				local l=tt:AddLine();

				tt:SetCell(l,1,
					spacer:rep(inset)
					..icon
					..C(color,ns.strCut(tostring(data[Name]),24))
					..id
					..(data[atWarWith] and " |TInterface\\buttons\\UI-Checkbox-SwordCheck:12:12:0:-1:32:32:0:18:0:18|t" or "")
				);

				if(ns.profile[name].standingText)then
					local id = "";
					if ns.profile[name].showID then
						id = idStr:format(data[standingID]);
					end
					tt:SetCell(l,2,data[factionStandingText]..id);
				end

				if(mode=="Percent")then
					tt:SetCell(l,3,("%1.1f%%"):format(data[barPercent]*100));
				elseif(mode=="PercentNeed")then
					tt:SetCell(l,3,("%1.1f%% "..L["need"]):format(100-data[barPercent]*100));
				elseif(mode=="Number")then
					tt:SetCell(l,3,ns.FormatLargeNumber(name,_Value,true).."/"..ns.FormatLargeNumber(name,_Max,true));
				elseif(mode=="NumberNeed")then
					tt:SetCell(l,3,ns.FormatLargeNumber(name,_Max-_Value,true).." "..L["need"]);
				end

				if not data[isParagon] and ns.profile[name].showSession and data[sessionValue]~=0 then
					local col,str = "gray",false,data[sessionValue];
					if data[sessionValue]>0 then
						col,str = "ltgreen","+"..data[sessionValue];
					elseif data[sessionValue]<0 then
						col,str = "ltred",data[sessionValue];
					end
					tt:SetCell(l,4,C(col,str));
				end

				if data[isParagon] and ns.profile[name].rewardBeyondExalted~="_NONE" then
					local field = "";
					if ns.profile[name].rewardBeyondExalted=="percent" then
						field = ("%1.1f%%"):format(data[rewardPercent]*100);
					else
						field = ("%s/%s"):format(ns.FormatLargeNumber(name,data[rewardValue],true),ns.FormatLargeNumber(name,data[rewardMax],true));
					end
					if data[hasRewardPending] then
						field = field.." |TInterface/GossipFrame/ActiveQuestIcon:14:14:0:0|t";
					else
						field = field.." |TInterface/GossipFrame/VendorGossipIcon:14:14:0:0|t";
					end
					tt:SetCell(l,5,field);
					--if ns.profile[name].rewardsFinished then
					--	tt:SetCell(l,6, data[rewardsFinished].." completed");
					--end
				end

				tt:SetLineScript(l,"OnEnter",factionTooltipOnEnter,data);
				tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);

				if data[isHeader] then
					tt:SetLineScript(l,"OnMouseUp",toggleHeader,data);
				end

				if(ns.profile[name].bgBars=="single") or (ns.profile[name].bgBars=="allinone")then
					if(not bars[count])then
						bars[count] = CreateFrame("Frame","BERepurationBar"..count,nil,"BEReputationBarTemplate");
					end
					bars[count]:SetParent(tt.lines[l]);
					bars[count]:SetPoint("TOPLEFT",tt.lines[l],"TOPLEFT",0,1);
					bars[count]:SetPoint("BOTTOMRIGHT",tt.lines[l],"BOTTOMRIGHT",0,-1);
					bars[count]:SetAlpha(0.6);
					bars[count]:Show();
					bars[count].data = data;
					bars[count].standing = data[standingID];
					bars[count].percent = _Max==0 and 1 or (_Value/_Max);
					bars[count].bodyguard = known_bodyguards[data[Name]] or false;
					bars[count].friend = data[friendID]~=nil;
				end

				local darker = 0.72;
				if(ns.profile[name].bgBars=="single")then
					local color = FACTION_BAR_COLORS[ (bars[count].friend and 5) or data[standingID] ];
					bars[count].BarSingle:SetVertexColor(color.r*darker,color.g*darker,color.b*darker,1);
					bars[count].BarSingle:Show();
				end

			end
		end

		if factions[i][2] then
			depth = depth+1; -- for following factions
		end
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);

	if #bars>0 then
		tt:SetScript("OnHide", tooltipOnHide);
	end
	CTimerAfter(0.075,updateBars);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"UPDATE_FACTION",
		-- "QUEST_LOOT_RECEIVED", -- added later; needs client version check
	},
	config_defaults = {
		enabled = false,
		bgBars = "single",
		standingText = true,
		showSession = true,
		showID = false,
		numbers = "Percent",
		watchedNameOnBroker = true,
		watchedStandingOnBroker = true,
		watchedSessionBroker = true,

		watchedCountOnBroker       = true,
		watchedCountPercentOnBroker= true,
		watchedNeedOnBroker        = false,
		watchedNeedPercentOnBroker = false,

		rewardBeyondExalted = "value_max"
	},
	clickOptionsRename = {
		["reputation"] = "1_open_reputation",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["reputation"] = {REPUTATION,"call",{"ToggleCharacter","ReputationFrame"}},
		["menu"] = "OptionMenuCustom"
	}
}

if ns.client_version>4 then
	-- event does not exists on classic_era, _bcc and wotlk clients
	tinsert(module.events,"QUEST_LOOT_RECEIVED")
end

ns.ClickOpts.addDefaults(module,{
	reputation = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			watchedNameOnBroker         = { type="toggle", order=1, name=L["Name of watched faction"], desc=L["Display name of watched faction on broker button"] },
			watchedStandingOnBroker     = { type="toggle", order=2, name=L["Standing of watched faction"], desc=L["Display standing of watched faction on broker button"] },
			watchedSessionBroker        = { type="toggle", order=3, name=L["Earn/loss of watched faction"], desc=L["Display earn/loss reputation of watched faction on broker button"] },
			watchedCountOnBroker        = { type="toggle", order=4, name=L["Count of watched faction"],          desc=L["Display current/max reputation of watched faction on broker button"] },
			watchedCountPercentOnBroker = { type="toggle", order=5, name=L["Percent count of watched faction"],  desc=L["Display percent value of watched faction reputation on broker button"] },
			watchedNeedOnBroker         = { type="toggle", order=6, name=L["Need of watched faction"],           desc=L["Display count of needed reputation to next standing of watched faction on broker button"] },
			watchedNeedPercentOnBroker  = { type="toggle", order=7, name=L["Need (percent) of watched faction"], desc=L["Display percent value of need reputation of watched faction on broker button"] },
		},
		tooltip = {
			standingText={ type="toggle", order=1, name=L["Standing text"], desc=L["Show standing text in tooltip"]},
			numbers={ type="select", order=2, name=L["Numeric format"], desc=L["How would you like to view numeric reputation format."], values=formats },
			showSession={ type="toggle", order=3, name=L["Show session earn/loss"], desc=L["Display session earned/loss reputation in tooltip"]},
			bgBars={ type="select",  order=4,
				name	= L["Background reputation bar mode"],
				desc	= L["How would you like to view the background reputation bar."],
				values	= {
					["_NONE"]       = "None",
					["single"]     = "Single standing level",
					["allinone"] = "All standing level in one",
				},
			},
			showID={ type="toggle", order=5, name=L["Show id's"], desc=L["Display faction and standing id's in tooltip"]},
			rewardBeyondExalted={ type="select",  order=6,
				name = L["Reward beyond exalted"],
				desc = L["Display reputation collecting for rewards beyond exalted"],
				values = {
					["_NONE"] = "None",
					["percent"] = STATUS_TEXT_PERCENT,
					["value_max"] = L["Value/Cap"]
				}
			}
		},
		misc = {
			shortNumbers=true
		},
	},
	{
		watchedNameOnBroker        = "UPDATE_FACTION",
		watchedStandingOnBroker    = "UPDATE_FACTION",
		watchedSessionBroker       = "UPDATE_FACTION",
		watchedCountOnBroker       = "UPDATE_FACTION",
		watchedCountPercentOnBroker= "UPDATE_FACTION",
		watchedNeedOnBroker        = "UPDATE_FACTION",
		watchedNeedPercentOnBroker = "UPDATE_FACTION",

	}
end

function module.OptionMenu(self,button,modName)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:AddConfig(name);
	ns.EasyMenu:AddEntry({separator=true});
	ns.EasyMenu:AddEntry({ label = C("yellow",L["Reset session earn/loss counter"]), func=resetSession, keepShown=false });
	ns.EasyMenu:ShowMenu(self);
end

-- function module.init() end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	end
	if event=="PLAYER_LOGIN" then
		if ns.toon[name]==nil or (ns.toon[name] and ns.toon[name].headers==nil) then
			ns.toon[name] = {headers={[-1]=true}};
		end
	elseif event=="QUEST_LOOT_RECEIVED" and not paragonQuestIDs[arg1] then
		return; -- prevent update broker if quest loot not from paragon quest
	end
	if ns.eventPlayerEnteredWorld then
		if ns.client_version >= 6 and not self.loadedBodyguards then
			self.loadedBodyguards = updateBodyguards();
		end
		if round==false then
			round = -2;
			initReputationListTicker = C_Timer.NewTicker(.3,initReputationList,8);
		end
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "RIGHT", "RIGHT", "RIGHT", "RIGHT"},{false},{self},{OnHide=tooltipOnHide});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button)m end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
