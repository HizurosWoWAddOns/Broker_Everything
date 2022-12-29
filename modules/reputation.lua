
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Reputation"; -- REPUTATION L["ModDesc-Reputation"]
local ttName, ttColumns, tt, module, createTooltip, updateBroker = name.."TT",6;

local tinsert,tconcat,ipairs=tinsert,table.concat,ipairs;
local GetFactionInfoByID = GetFactionInfoByID;
local GetNumFactions,GetFactionInfo,GetFactionInfoByID = GetNumFactions,GetFactionInfo,GetFactionInfoByID;

local bars,factions,sessionInfo,spacer,initReputationListTicker = {},{},{},"    ";
local allinone = {faction=85000,friend=43000,bodyguard=31000,major=false};
local bodyguards,paragonFactions = {[193]=1,[207]=1,[216]=1,[218]=1,[219]=1},{};
local round,collapsedL1,collapsedL2 = nil,{},{};
local missingFactionID = -1;
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
local C_Reputation_GetFactionInfo,C_Reputation_GetFactionInfoByID
do
	-- faction to currency; for missing renown max level value from major faction info function
	local faction2Currency = {
		-- dragonflight
		[2503] = 2002,
		[2507] = 2021,
		[2510] = 2088,
		[2511] = 2087,
	};
	local function normalizeValues(i,a,b,c)
		a,b = i[a]-i[c],i[b]-i[c];
		return a>0 and a or 1, b>0 and b or 1;
	end
	local function _GetFactionInfo(f,faction,extended)
		local info = {};
		info.name, info.description, info.standingID, info.barMin, info.barMax, info.barValue, info.atWarWith, info.canToggleAtWar,
		info.isHeader, info.isCollapsed, info.hasRep, info.isWatched, info.isChild, info.factionID, info.hasBonusRepGain, info.canBeLFGBonus = f(faction);
		if info.factionID==nil then
			-- there area 2 header entries without factionID. Misc and Inactive.
			info.factionID = missingFactionID;
			missingFactionID = missingFactionID - 1;
		end

		if info.name then
			-- remove line brake; no good idea from blizzard...
			info.name = info.name:gsub("%-%\r%\n","");
		end

		if not extended or info.factionID<0 then
			return info;
		end

		info.shortInfo = {max=1,value=1,percent=1};

		if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
			local friendInfo = C_GossipInfo.GetFriendshipReputation(info.factionID);
			if friendInfo and friendInfo.friendshipFactionID~=0 then
				info.friendInfo = friendInfo;
				friendInfo.standingID = C_GossipInfo.GetFriendshipReputationRanks(info.factionID);
			end
		end

		if C_Reputation and C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(info.factionID) then
			info.majorFactionInfo = C_MajorFactions.GetMajorFactionData(info.factionID);
		end

		if info.majorFactionInfo then
			if faction2Currency[info.factionID] then
				local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(faction2Currency[info.factionID]);
				if currencyInfo then
					-- missing entry in major faction info
					info.majorFactionInfo.renownLevelMax = currencyInfo.maxQuantity;
				end
			end
			if info.majorFactionInfo.renownLevelThreshold then
				info.shortInfo.max = info.majorFactionInfo.renownLevelThreshold;
				info.shortInfo.value = info.majorFactionInfo.renownReputationEarned;
			end
			info.shortInfo.standingID = info.majorFactionInfo.renownLevel;
			info.shortInfo.standingStr = MAJOR_FACTION_RENOWN_LEVEL_TOAST:format(info.majorFactionInfo.renownLevel);
			info.type = "major"
		elseif info.friendInfo then
			if info.friendInfo.nextThreshold then
				info.shortInfo.max, info.shortInfo.value = normalizeValues(info.friendInfo,"nextThreshold","standing","reactionThreshold");
			end
			info.shortInfo.standingID = info.friendInfo.standingID.currentLevel; -- currently wrong!
			info.shortInfo.standingStr = info.friendInfo.reaction;
			info.type = "friend"
		else
			info.shortInfo.max, info.shortInfo.value = normalizeValues(info,"barMax","barValue","barMin");
			if info.shortInfo.value==0 then info.shortInfo.value=1; end
			info.shortInfo.standingID = info.standingID;
			info.shortInfo.standingStr = _G["FACTION_STANDING_LABEL"..info.standingID] or UNKNOWN;
			info.type = "faction"
		end

		-- paragon
		if C_Reputation and C_Reputation.IsFactionParagon and C_Reputation.IsFactionParagon(info.factionID) then
			info.paragonInfo = {};
			info.paragonInfo.value, info.paragonInfo.threshold, info.paragonInfo.rewardQuestID, info.paragonInfo.hasPending, info.paragonInfo.tooLowLevelForParagon = C_Reputation.GetFactionParagonInfo(info.factionID);
			info.rewardInfo = {
				max = info.paragonInfo.threshold,
				value = mod(info.paragonInfo.value,info.paragonInfo.threshold),
				standingStr = info.shortInfo.standingStr,
				standingID = floor(info.paragonInfo.value/info.paragonInfo.threshold)
			};
			info.rewardInfo.percent = info.rewardInfo.value/info.rewardInfo.max;
			info.rewardInfo.need = info.rewardInfo.max - info.rewardInfo.value;
			paragonFactions[info.factionID] = true;
			info.type = "paragon"
		end

		-- session
		local short = info.rewardInfo or info.shortInfo;
		local session = sessionInfo[info.factionID];

		if not session then
			sessionInfo[info.factionID] = {
				--type=info.type,
				standingID=short.standingID,
				value=short.value,
				max=short.max,
				diff=0
			};
			session = sessionInfo[info.factionID];
		else
			if session.standingID~=short.standingID then
				session.standingID = short.standingID;
				session.value = short.value - session.max;
				session.max = short.max;
			end
			if short.value~=session.value then
				session.diff = short.value - session.value;
			end
		end

		return info;
	end

	function C_Reputation_GetFactionInfo(...)
		return _GetFactionInfo(GetFactionInfo,...);
	end

	function C_Reputation_GetFactionInfoByID(faction_id)
		return _GetFactionInfo(GetFactionInfoByID,faction_id,true);
	end
end

local function initReputationList()
	if round==nil then
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
		for i = (C_Reputation and C_Reputation.GetNumFactions or GetNumFactions)(),1,-1 do
			local info = (C_Reputation and C_Reputation.GetFactionInfo or C_Reputation_GetFactionInfo)(i);
			if info.isCollapsed then
				tinsert(collapsed,1,i);
				(C_Reputation and C_Reputation.ExpandFactionHeader or ExpandFactionHeader)(i);
			end
		end
		round=round+1;
	elseif round==0 then
		-- read factions
		wipe(factions);
		for i=1, (C_Reputation and C_Reputation.GetNumFactions or GetNumFactions)() do
			local info = (C_Reputation and C_Reputation.GetFactionInfo or C_Reputation_GetFactionInfo)(i,true);
			tinsert(factions,{
				factionID=info.factionID,
				name=info.name,
				isHeader=info.isHeader,
				isChild=info.isChild,
				hasRep=info.hasRep
			});
		end
		round=round+1;
	else
		-- collapse headers again
		local collapsed = round==1 and collapsedL2 or collapsedL1;
		if collapsed and #collapsed>0 then
			(C_Reputation and C_Reputation.CollapseFactionHeader or CollapseFactionHeader)(collapsed[1]);
			tremove(collapsed,1);
			if #collapsed==0 then
				round=round+1;
			end
		elseif initReputationListTicker and initReputationListTicker~=true then
			initReputationListTicker:Cancel();
			collapsedL2,collapsedL1 = nil,nil;
			round = nil;
		end
	end
end

local function resetSession()
	for factionID in ipairs(sessionInfo) do
		sessionInfo[factionID]=nil;
		C_Reputation_GetFactionInfoByID(factionID);
	end
	updateBroker();
end

local function updateBodyguards()
	-- collect locale names of bodyguards
	if UnitLevel("player")>=GetMaxLevelForExpansionLevel(6) and C_Garrison.GetGarrisonInfo(Enum.GarrisonType.Type_6_0) then
		for follower in pairs(bodyguards) do
			if type(follower)=="number" then
				local followerInfo = C_Garrison.GetFollowerInfo(follower);
				if followerInfo and followerInfo.name then
					bodyguards[followerInfo.name] = true;
					bodyguards[follower] = nil;
				end
			end
		end
	end
end

function updateBroker()
	local txt = REPUTATION;
	local _, _, _, _, _, watchedFactionID = GetWatchedFactionInfo();

	if watchedFactionID and watchedFactionID>0 then
		local info = C_Reputation_GetFactionInfoByID(watchedFactionID);
		if not info then return end

		local tmp = {};
		if ns.profile[name].watchedNameOnBroker then
			tinsert(tmp,info.name);
		end

		local short = info.rewardInfo or info.shortInfo;

		if ns.profile[name].watchedCountOnBroker then
			if ns.profile[name].watchedCountPercentOnBroker then
				tinsert(tmp,short.percent==1 and "100%" or ("%1.1f%%"):format(short.percent*100));
			elseif short.max>1 then
				tinsert(tmp,ns.FormatLargeNumber(name,short.value).."/"..ns.FormatLargeNumber(name,short.max));
			else
				tinsert(tmp,COMPLETE);
			end
		end

		if ns.profile[name].watchedNeedOnBroker then -- TODO: merge into single option (select)
			if ns.profile[name].watchedNeedPercentOnBroker then
				tinsert(tmp,("%1.1f%% "..L["need"]):format( (1-short.percent)*100 ));
			elseif short.max>1 then
				tinsert(tmp,ns.FormatLargeNumber(name,short.max-short.value).." "..L["need"]);
			else
				tinsert(tmp,COMPLETE);
			end
		end

		if ns.profile[name].watchedStandingOnBroker then
			tinsert(tmp,info.shortInfo.standingStr);
		end

		if ns.profile[name].watchedSessionBroker and sessionInfo[info.factionID] then
			local session,color,prefix = sessionInfo[info.factionID],"ltgreen","+";
			if sessionInfo[info.factionID].diff~=0 then
				if sessionInfo[info.factionID].diff < 0 then
					color,prefix = "ltred","-";
				end
				tinsert(tmp,C(color,prefix..sessionInfo[info.factionID].diff));
			end
		end

		if #tmp>0 then
			txt = tconcat(tmp,", ");
		end
	end

	for factionID in pairs(paragonFactions) do
		local _, _, _, hasPending = C_Reputation.GetFactionParagonInfo(factionID);
		if hasPending then
			txt = txt .. "|TInterface/GossipFrame/VendorGossipIcon:14:14:0:0|t|TInterface/GossipFrame/ActiveQuestIcon:14:14:0:0|t";
			break;
		end
	end

	ns.LDB:GetDataObjectByName(module.ldbName).text = txt;
end

local function updateBars(index)
	if not index then
		for i=1, #bars do
			if bars[i]:IsShown() then
				updateBars(i);
			end
		end
	else
		local bar,info = bars[index],bars[index].info;
		local short = info.rewardInfo or info.shortInfo;
		local bgWidth,bgBars = bar.Bg:GetWidth(), ns.profile[name].bgBars;
		bgBars = "single"; -- TODO: allinone currently disablsed

		if bgBars=="single" then
			local width = bgWidth * (short.value/short.max);
			bar.BarSingle:SetWidth(width>1 and width or 2);
			-- coloring
			local color;
			if info.type=="paragon" then
				color = ITEM_QUALITY_COLORS[4];
				color.GetRGB = NORMAL_FONT_COLOR.GetRGB; -- missing function
			elseif info.type=="friend" then
				color = FACTION_BAR_COLORS[5];
			elseif info.type=="major" then
				color = ITEM_QUALITY_COLORS[3];--FRIENDS_BNET_BACKGROUND_COLOR;
				color.GetRGB = NORMAL_FONT_COLOR.GetRGB; -- missing function
			else
				color = FACTION_BAR_COLORS[ info.standingID ] or FACTION_BAR_COLORS[ 8 ];
			end
			if color then
				local r,g,b = color:GetRGB();
				bar.BarSingle:SetVertexColor(r,g,b,.82);
				bar.Bg:SetVertexColor(r,g,b,.6);
			end
			bar.BarSingle:Show();
			-- hide other textures
			bar.BarAIO:Hide();
			bar.BarAIO_friend:Hide();
			bar.BarAIO_bodyguard:Hide();
		elseif bgBars=="allinone" then
			if bar.bodyguard then
				local totalPercent = bar.info.shortInfo.max==1 and 1 or (bar.info.shortInfo.value / allinone.bodyguard);
				bar.BarAIO_bodyguard:SetTexCoord(0, 916/1024 * totalPercent, 0, 1);
				bar.BarAIO_bodyguard:SetWidth((bgWidth * totalPercent)+0.1);
				bar.BarAIO_bodyguard:Show();
			elseif(bar.friend or bar.major)then
				local totalPercent = bar.info.shortInfo.max==1 and 1 or (bar.info.shortInfo.value / allinone.friend);
				bar.BarAIO_friend:SetTexCoord(0, 870/1024 * totalPercent, 0, 1);
				bar.BarAIO_friend:SetWidth((bgWidth * totalPercent)+0.1);
				bar.BarAIO_friend:Show();
			else
				local totalPercent = bar.info.standingID==8 and 1 or ((bar.info.shortInfo.value + 42000) / allinone.faction);
				bar.BarAIO:SetTexCoord(0, 850/1024 * totalPercent, 0, 1);
				bar.BarAIO:SetWidth((bgWidth * totalPercent)+0.1);
				bar.BarAIO:Show();
			end
			-- hide other textures
			bar.BarSingle:Hide();
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
	ns.toon[name].headers[data.factionID] = ns.toon[name].headers[data.factionID]==nil and true or nil;
	tooltipOnHide();
	createTooltip(tt);
end

local function factionTooltipOnEnter(self,info)
	local fstr = "%s/%s (%1.1f%%)";
	local percent = info.shortInfo.value/info.shortInfo.max*100;
	local need = info.shortInfo.max - info.shortInfo.value;

	local GameTooltip = _G["GameTooltip"];

	GameTooltip:SetOwner(self,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(self,"horizontal",tt));
	GameTooltip:SetText(info.name,1,1,1);

	GameTooltip:AddLine(" ");
	if info.shortInfo.max>1 then
		GameTooltip:AddDoubleLine(info.shortInfo.standingStr, fstr:format(info.shortInfo.value,info.shortInfo.max,percent));
	else
		GameTooltip:AddDoubleLine(" ",info.shortInfo.standingStr);
	end
	if need>0 then
		GameTooltip:AddDoubleLine(" ",need.." "..L["need"]);
	end

	-- TODO: add session earning info

	if info.paragonInfo then
		local rewardName = " ... ";
		local itemName, itemTexture, _, quality, _, _ = GetQuestLogRewardInfo(1, info.paragonInfo.rewardQuestID);
		if itemName then
			rewardName = "|T"..itemTexture..":0|t "..ITEM_QUALITY_COLORS[quality].color:WrapTextInColorCode(itemName);
		else
			C_Timer.After(0.1,function() factionTooltipOnEnter(self,info) end);
		end

		local percent = info.rewardInfo.value/info.rewardInfo.max*100;
		local need = info.rewardInfo.max - info.rewardInfo.value;
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(rewardName);
		GameTooltip:AddDoubleLine(" ",fstr:format(info.rewardInfo.value,info.rewardInfo.max, percent));
		GameTooltip:AddDoubleLine(" ",need.." "..L["need"]);
		if info.paragonInfo.hasPending then
			GameTooltip:AddLine("|TInterface/GossipFrame/ActiveQuestIcon:14:14:0:0|t "..BOUNTY_TUTORIAL_BOUNTY_FINISHED,0,0.9,0,1);
		end
	end

	GameTooltip:Show();
end

function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",REPUTATION));

	local depth,count = 0,0;
	local parentIsCollapsed1,parentIsCollapsed2,mode = false,false,ns.profile[name].numbers;

	for i,faction in ipairs(factions) do
		local show = true;
		if (faction.isHeader and not faction.isChild) then
			parentIsCollapsed1 = ns.toon[name].headers[faction.factionID]~=nil;
			parentIsCollapsed2 = false;
		elseif (faction.isHeader and faction.isChild) and parentIsCollapsed1==false then
			parentIsCollapsed2 = ns.toon[name].headers[faction.factionID]~=nil;
		elseif not parentIsCollapsed1 then
			show = not parentIsCollapsed2;
		else
			show = not parentIsCollapsed1;
		end

		if faction.isHeader then -- for current headers itself
			depth = faction.isChild and 1 or 0;
		end

		if show then
			local info
			if faction and faction.isHeader and not faction.hasRep then
				local color,icon = "ltblue","|Tinterface\\buttons\\UI-MinusButton-Up:0|t ";
				if ns.toon[name].headers[faction.factionID] then
					color,icon = "gray","|Tinterface\\buttons\\UI-PlusButton-Up:0|t ";
				end
				local l=tt:AddLine(C(color,spacer:rep(depth)..icon..faction.name));
				if faction.isHeader then
					tt:SetLineScript(l,"OnMouseUp",toggleHeader,faction);
				end
			else
				info = C_Reputation_GetFactionInfoByID(faction.factionID);
			end
			if info and info.name then
				count = count + 1;

				local inset = 0;
				local color,icon,inset,_ = "ltyellow","",1+depth,nil;
				if info.isHeader then
					inset = inset-1;
					color,icon = "ltblue","|Tinterface\\buttons\\UI-MinusButton-Up:0|t ";
					if info.isCollapsed then
						color,icon = "ltyellow","|Tinterface\\buttons\\UI-PlusButton-Up:0|t ";
					end
				end

				local id = ns.profile[name].showID and idStr:format(info.factionID) or "";
				local l=tt:AddLine();

				tt:SetCell(l,1,
					spacer:rep(inset)
					..icon
					..C(color,ns.strCut(tostring(info.name),24))
					..id
					..(info.atWarWith and " |TInterface\\buttons\\UI-Checkbox-SwordCheck:12:12:0:-1:32:32:0:18:0:18|t" or "")
				);

				if(ns.profile[name].standingText)then
					local id = "";
					if ns.profile[name].showID and not info.majorFactionInfo then
						id = idStr:format(info.shortInfo.standingID);
					end
					tt:SetCell(l,2,(info.shortInfo.standingStr or "?")..id);
				end

				local shortInfo = info.shortInfo;
				if info.paragonInfo and ns.profile[name].rewardBeyondExalted~="_NONE" then
					shortInfo = info.rewardInfo;
					tt:SetCell(l,4,"|TInterface/GossipFrame/"..(info.paragonInfo.hasPending and "ActiveQuest" or "VendorGossip") .. "Icon:14:14:0:0|t");
				end

				local percent = shortInfo.value/shortInfo.max*100;
				local need = shortInfo.max - shortInfo.value;

				if(mode=="Percent")then
					tt:SetCell(l,3,("%1.1f%%"):format(percent));
				elseif(mode=="PercentNeed")then
					tt:SetCell(l,3,("%1.1f%% "..L["need"]):format(100-percent));
				elseif(mode=="Number" and shortInfo.max>1)then
					tt:SetCell(l,3,ns.FormatLargeNumber(name,shortInfo.value,true).."/"..ns.FormatLargeNumber(name,shortInfo.max,true));
				elseif(mode=="NumberNeed" and need>0)then
					tt:SetCell(l,3,ns.FormatLargeNumber(name,need,true).." "..L["need"]);
				end

				if ns.profile[name].showSession and sessionInfo[info.factionID] then
					local session,color,prefix = sessionInfo[info.factionID],"ltgreen","+";
					if sessionInfo[info.factionID].diff~=0 then
						if sessionInfo[info.factionID].diff < 0 then
							color,prefix = "ltred","-";
						end
						tt:SetCell(l,5,C(color,prefix..sessionInfo[info.factionID].diff));
					end
				end

				tt:SetLineScript(l,"OnEnter",factionTooltipOnEnter,info);
				tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);

				if info.isHeader then
					tt:SetLineScript(l,"OnMouseUp",toggleHeader,info);
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
					bars[count].info = info;
				end
			end
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

	C_Timer.After(0.075,updateBars);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"UPDATE_FACTION",
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
	end
	if ns.eventPlayerEnteredWorld then
		if ns.client_version >= 6 and not self.loadedBodyguards then
			self.loadedBodyguards = updateBodyguards();
		end
		if round==nil then
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
