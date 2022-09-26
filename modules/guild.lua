-- module independent variables --
----------------------------------
local addon,ns = ...;
local C,L,I=ns.LC.color,ns.L,ns.I;


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Guild"; -- GUILD L["ModDesc-Guild"]
local ttName,ttName2,ttColumns,ttColumns2,tt,tt2,module = name.."TT", name.."TT2",10,2;
local pattern_FRIEND_OFFLINE = ERR_FRIEND_OFFLINE_S:gsub("%%s","(.*)"):trim();
local pattern_FRIEND_ONLINE = ERR_FRIEND_ONLINE_SS:gsub("[\124:%[%]]","#"):gsub("%%s","(.*)"):trim();
local knownMemberRaces = {}; -- filled by updateBroker
local memberLevels = {}; -- filled by updateBroker
local memberIndex = {}; -- filled by updateBroker
local membersOnline = {}; -- filled by createTooltip
local applicants = {}; -- filled by createTooltip
local tradeskills = {}; -- filled by updateTradeSkills
local bnetFriends = {}; -- filled by updateBattleNetFriends
local flags = {}; -- filled by module.onenter
local ttHooks = {} -- filled by module.onenter
local applScroll = {step=0,stepWidth=3,numLines=5,lines={},lineCols={},slider=false,regionColor={1,.5,0,.15}};
local membScroll = {step=0,stepWidth=5,numLines=15,lines={},lineCols={},slider=false,regionColor={1,.82,0,.11}};
local tradeSkillLock,tradeSkillsUpdateDelay,chatNotificationEnabled,frame = false,0;
local icon_arrow_right = "|T"..ns.icon_arrow_right..":0|t";
local CanViewOfficerNote = CanViewOfficerNote or C_GuildInfo.CanViewOfficerNote;
local BACKDROP_SLIDER_8_8 = BACKDROP_SLIDER_8_8 or { -- classic
	bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
	edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
	tile = true,
	tileEdge = true,
	tileSize = 8,
	edgeSize = 8,
	insets = { left = 3, right = 3, top = 6, bottom = 6 },
};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=135026,coords={0.05,0.95,0.05,0.95}} --IconName::Guild--


-- some local functions --
--------------------------
local function CanUpdateApplicants()
	return (IsGuildLeader() or C_GuildInfo.IsGuildOfficer()) and C_ClubFinder.IsEnabled();
end

local function RequestGuildRosterUpdate(canRequest)
	if canRequest then
		if GuildRoster then
			GuildRoster(); -- for classic // trigger GUILD_ROSTER_UPDATE
		else
			C_GuildInfo.GuildRoster(); -- trigger GUILD_ROSTER_UPDATE
			RequestGuildChallengeInfo(); -- trigger GUILD_CHALLENGE_UPDATED
		end
	end
end

local function GetApplicants()
	if CanUpdateApplicants() then
		local guildClubId = C_Club.GetGuildClubId();
		if guildClubId then
			return (C_ClubFinder.ReturnClubApplicantList(guildClubId) or {});
		end
	end
	return false;
end

local function updateTradeSkills()
	if not IsInGuild() then wipe(tradeskills); return; end
	if (GuildRosterFrame~=nil and GuildRosterFrame:IsShown()) then return; end
	if tradeSkillLock then return end
	tradeSkillLock = true;

	local skillID,isCollapsed,iconTexture,headerName,numOnline,numVisible,numPlayers,playerName,playerFullName,class,online,zone,skill,classFileName,isMobile,isAway,_
	local headers = {};
	local header = {};
	local collapsed = {};

	-- 1. run...
	local num = GetNumGuildTradeSkill();
	for index=num, 1, -1 do
		skillID,isCollapsed,_,headerName = GetGuildTradeSkillInfo(index);
		if headerName and isCollapsed then
			tinsert(collapsed,skillID);
			ExpandGuildTradeSkillHeader(skillID);
		end
	end

	-- 2. run...
	local tmp,skillHeader = {},{};
	local num = GetNumGuildTradeSkill();
	for index=1, num do
		skillID,isCollapsed,iconTexture,headerName,_,_,_,_,playerFullName,_,_,_,skill,classFileName = GetGuildTradeSkillInfo(index);
		if headerName then
			skillHeader = {headerName,iconTexture,skillID};
		elseif playerFullName then
			if tmp[playerFullName]==nil then
				tmp[playerFullName]={};
			end
			tinsert(
				tmp[playerFullName],
				{
					skillHeader[1],
					skillHeader[2] or ns.icon_fallback,
					skill,
					skillHeader[3] or skillID
				}
			);
		end
	end
	tradeskills = tmp;

	-- 3. run... collapse prev. expanded skills
	for i=1, #collapsed do
		CollapseGuildTradeSkillHeader(collapsed[i]);
	end
	tradeSkillLock = false;
end

local function updateBattleNetFriends()
	if ns.client_version<2 then
		return;
	end
	wipe(bnetFriends);
	if BNConnected() then
		for i=1, (BNGetNumFriends()) do
			local accountInfo = ns.C_BattleNet_GetFriendAccountInfo(i);
			if accountInfo and accountInfo.accountName and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.clientProgram=="WoW" and accountInfo.gameAccountInfo.playerGuid then
				bnetFriends[accountInfo.gameAccountInfo.playerGuid] = accountInfo.accountName;
			end
		end
	end
end

local function updateBroker()
	local txt = {};

	if IsInGuild() then
		local numMobile,numMembers,numMembersOnline = 0,GetNumGuildMembers();
		for i=1, numMembers do
			local mFullName,mRank,mRankIndex,mLevel,mClassLocale,mZone,mNote,mOfficerNote,mOnline,mIsAway,mClassFile,_,_,mIsMobile,_,mStanding,mGUID = GetGuildRosterInfo(i);
			local mName, mRealm = strsplit("-",mFullName,2);
			-- race names; must be cached by request GetPlayerInfoByGUID. That could take same time.
			if ns.profile[name].showRace and not knownMemberRaces[mGUID] then
				local _, _, mRaceName = GetPlayerInfoByGUID(mGUID);
				if mRaceName then
					knownMemberRaces[mGUID] = mRaceName;
				end
			end
			if mIsMobile and mOnline then
				numMobile = numMobile + 1;
			end
			-- levelup notification
			if ns.profile[name].showMembersLevelUp and memberLevels[mGUID]~=nil and memberLevels[mGUID]~=mLevel then
				ns:print( C(mClassFile,mName) .." ".. C("green",L["has reached Level %d."]:format(mLevel)) );
			end
			memberLevels[mGUID] = mLevel;
			-- for on/off notification
			memberIndex[mFullName] = i;
		end

		if ns.profile[name].showApplicantsBroker and C_ClubFinder and C_ClubFinder.ReturnClubApplicantList then
			local applicants = GetApplicants();
			if applicants and #applicants>0 then
				tinsert(txt, C("orange",#applicants));
			end
		end

		if ns.client_version>2 and ns.profile[name].showMobileChatterBroker then
			tinsert(txt, C("ltblue",numMobile));
		end

		tinsert(txt,C("green",numMembersOnline));
		if ns.profile[name].showTotalMembersBroker then
			tinsert(txt,C("green",numMembers));
		end
	else
		tinsert(txt,L["No guild"]);
	end

	(ns.LDB:GetDataObjectByName(module.ldbName) or {}).text = table.concat(txt,"/");
end

local function GetMemberRecipes(self,info)
	GetGuildMemberRecipes(info.name,info.id);
end

local function memberInviteOrWhisper(self,memberIndex)
	local mFullName,_,_,_,_,_,_,_,mOnline,_,_,_,_,mIsMobile,_,_,mGUID = GetGuildRosterInfo(memberIndex);
	if IsAltKeyDown() then
		if mIsMobile then
			ns:print(L["GuildErrorInviteMobile"]);
		elseif not mOnline then
			ns:print(L["GuildErrorInviteOffline"]);
		elseif C_PartyInfo.InviteUnit then
			C_PartyInfo.InviteUnit(mFullName);
		elseif InviteUnit then
			InviteUnit(mFullName);
		else
			ns:print(L["GuildErrorInviteMissingFunction"]);
		end
	elseif mOnline then
		SetItemRef("player:"..mFullName, ("|Hplayer:%1$s|h[%1$s]|h"):format(mFullName), "LeftButton");
	else
		ns:print(L["GuildErrorWhisperOffline"]);
	end
end

local function showApplication(self,appIndex)
	if IsInGuild() then
		if (not GuildFrame) then
			GuildFrame_LoadUI();
		end
		if (not GuildFrame:IsShown()) then
			ShowUIPanel(GuildFrame)
		end
		if (not GuildInfoFrameApplicantsContainer:IsVisible()) then
			GuildFrameTab5:Click();
			GuildInfoFrameTab3:Click();
		end
		SetGuildApplicantSelection(appIndex);
		GuildInfoFrameApplicants_Update();
	end
end

local function guildChallengeLineColor(bool)
	if bool then
		return 1,1,1, 0,1,0;
	end
	return 1,1,1, 1,1,1;
end

local function createTooltip3(parent,sel)
	GameTooltip:SetOwner(parent, "ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(parent,"horizontal",tt));
	local show = false;
	if sel=="info" then
		GameTooltip:SetText(GUILD_INFORMATION);
		GameTooltip:AddLine(" ");
		local info = (GetGuildInfoText() or ""):trim();
		if info=="" then
			info = EMPTY;
		else
			info = ns.scm(info);
		end
		GameTooltip:AddLine(info,1,1,1,true);
		show = true;
	elseif sel=="challenges" then
		GameTooltip:AddLine(GUILD_CHALLENGE_LABEL,1,0.82,0);

		local order,numChallenges = {1,4,2,3},GetNumGuildChallenges();
		for i = 1, numChallenges do
			local orderIndex = order[i] or i;
			local index, current, max, gold, maxGold = GetGuildChallengeInfo(orderIndex);
			if index then
				GameTooltip:AddLine(" ");
				local goldSum,goldPerRun = "",GetMoneyString(maxGold * COPPER_PER_SILVER * SILVER_PER_GOLD);
				GameTooltip:AddDoubleLine(
					C("ltblue",_G["GUILD_CHALLENGE_TYPE"..index]),
					("%d/%d"):format(current,max),
					guildChallengeLineColor(current==max)
				);
				GameTooltip:AddDoubleLine(
					goldPerRun,
					goldSum,
					1,1,1, 1,1,1
				);
			end
		end
		show = true;
	end
	GameTooltip:Show();
end

local function createTooltip2(self,memberIndex)
	local tsName, tsIcon, tsValue, tsID = 1,2,3,4;
	local mFullName,mRank,mRankIndex,mLevel,mClassLocale,mZone,mNote,mOfficerNote,mOnline,mIsAway,mClassFile,_,_,mIsMobile,_,mStanding,mGUID = GetGuildRosterInfo(memberIndex);
	local mName, mRealm = strsplit("-",mFullName,2);

	local s,t,_ = "";
	local realm = mRealm or "";

	tt2 = ns.acquireTooltip(
		{ttName2, ttColumns2, "LEFT","RIGHT"},
		{true,true},
		{self, "horizontal", tt}
	);

	if tt2.lines~=nil then tt2:Clear(); end
	tt2:AddHeader(C("dkyellow",NAME), C(mClassFile,ns.scm(mName)));
	tt2:AddSeparator();
	if type(realm)=="string" and realm:len()>0 then
		local _,_realm = ns.LRI:GetRealmInfo(realm);
		if _realm then realm = _realm; end
	end
	tt2:AddLine(C("ltblue",L["Realm"]),C("dkyellow",ns.scm(realm)));
	if ns.profile[name].showRaceInTT2 then
		local mRaceName = knownMemberRaces[mGUID];
		if not mRaceName then
			_, _, mRaceName = GetPlayerInfoByGUID(mGUID);
			if mRaceName then
				knownMemberRaces[mGUID] = mRaceName;
			end
		end
		if mRaceName then
			tt2:AddLine(C("ltblue",RACE),mRaceName);
		end
	end
	if ns.profile[name].showZoneInTT2 then
		tt2:AddLine(C("ltblue",ZONE),mZone);
	end
	if ns.profile[name].showNotesInTT2 then
		tt2:AddLine(C("ltblue",LABEL_NOTE),ns.scm(mNote));
	end
	if ns.profile[name].showONotesInTT2 then
		if mOfficerNote=="" then
			tt2:AddLine(C("ltblue",OFFICER_NOTE_COLON),C("gray","<"..EMPTY..">"));
		else
			tt2:AddLine(C("ltblue",OFFICER_NOTE_COLON),ns.scm(mOfficerNote));
		end
	end
	if ns.profile[name].showRankInTT2 then
		tt2:AddLine(C("ltblue",RANK),ns.scm(mRank));
	end
	if ns.profile[name].showProfessionsInTT2 and tradeskills[mFullName] then
		t=tradeskills[mFullName][1];
		tt2:AddLine(C("ltblue",TRADE_SKILLS),t[tsName].." |T"..t[tsIcon]..":0|t");
		if tradeskills[mFullName][2] then
			t=tradeskills[mFullName][2];
			tt2:AddLine(" ", t[tsName].." |T"..t[tsIcon]..":0|t");
		end
	end
	tt2:AddSeparator(1,0,0,0,0);
	ns.roundupTooltip(tt2);
end

local function ttAddApplicant(lineIndex,applicantInfo)
	if not (tt and tt.key and tt.key==ttName) then return end -- interrupt processing on close tooltip
	local roles = {};

	local isDps,isHealer,isTank = false,false,false;
	for _, specID in ipairs(applicantInfo.specIds) do
		local role = GetSpecializationRoleByID(specID);
		if role=="DAMAGER" and not isDps then
			isDps = true;
			tinsert(roles,DAMAGER);
		elseif role=="HEALER" and not isHealer then
			isHealer = true;
			tinsert(roles,HEALER);
		elseif role=="TANK" and not isTank then
			isTank = true;
			tinsert(roles,TANK);
		end
	end

	local localizedClass, englishClass, localizedRace, englishRace, sex, playerName, realm = GetPlayerInfoByGUID(applicantInfo.playerGUID);

	tt:SetCell(lineIndex,1,applicantInfo.level);
	local toonName = C(englishClass, ns.scm(playerName)) .. ns.showRealmName(name,realm);
	if ns.profile[name].showBattleTag and bnetFriends[applicantInfo.playerGUID] then
		toonName = toonName.." "..C("ltblue","("..ns.scm(bnetFriends[applicantInfo.playerGUID]..")"));
	end
	tt:SetCell(lineIndex,2,toonName);
	tt:SetCell(lineIndex,3,table.concat(roles,", "));
	tt:SetCell(lineIndex,4,date("%Y-%m-%d",applicantInfo.lastUpdatedTime+(86400*30)));
	tt:SetCell(lineIndex,5,(strlen(applicantInfo.message)>0 and ns.scm(ns.strCut(applicantInfo.message,60)) or C("gray","<"..EMPTY..">")),nil,nil,ttColumns-5);
	--tt:SetLineScript(lineIndex,"OnMouseUp",showApplication,applicantIndex);
end

local function ttAddMember(lineIndex,memberIndex)
	if not (tt and tt.key and tt.key==ttName) then return end -- interrupt processing on close tooltip
	local tsName, tsIcon, tsValue, tsID = 1,2,3,4;
	local mFullName,mRank,mRankIndex,mLevel,mClassLocale,mZone,mNote,mOfficerNote,mOnline,mIsAway,mClassFile,_,_,mIsMobile,_,mStanding,mGUID = GetGuildRosterInfo(memberIndex);
	local mName, mRealm = strsplit("-",mFullName,2);

	if not (tt and tt.key and tt.key==ttName) then return end

	local offColor = nil;
	if not mOnline then
		offColor = "gray";
	end

	local status;
	if mIsMobile then
		status = (mIsAway==2 and MOBILE_BUSY_ICON) or (mIsAway==1 and MOBILE_AWAY_ICON) or ChatFrame_GetMobileEmbeddedTexture(73/255, 177/255, 73/255)
	else
		status = ("|T%s:0|t"):format(_G["FRIENDS_TEXTURE_"  .. ((mIsAway==1 and "AFK") or (mIsAway==2 and "DND") or "ONLINE")]);
	end

	local cellIndex = 3;

	-- level
	tt:SetCell(lineIndex,1,mLevel);

	-- status / member name / realm
	local status_name = status .. " " .. C(offColor or mClassFile,ns.scm(mName)) .. ns.showRealmName(name,mRealm,offColor);
	if ns.profile[name].showBattleTag and bnetFriends[mGUID] then
		status_name = status_name.." "..C(offColor or "ltblue","("..ns.scm(bnetFriends[mGUID]..")"));
	end
	tt:SetCell(lineIndex,2,status_name);

	-- race name
	if flags.showRace then
		-- race names; must be cached by request GetPlayerInfoByGUID. That could take same time.
		local mRaceName = knownMemberRaces[mGUID];
		if not mRaceName then
			_, _, mRaceName = GetPlayerInfoByGUID(mGUID);
			if mRaceName then
				knownMemberRaces[mGUID] = mRaceName;
			end
		end
		if offColor then
			mRaceName = C(offColor,mRaceName);
		end
		tt:SetCell(lineIndex,cellIndex,mRaceName or "");
		cellIndex = cellIndex + 1;
	end

	-- zone
	if flags.showZone then
		local color = offColor or (mIsMobile and not mOnline and "cyan") or false;
		local Zone = mZone or "?";
		if color then
			Zone = C(color,Zone);
		end
		--if mIsMobile and not mOnline then
		--	Zone=C(offColor or "cyan",REMOTE_CHAT);
		--end
		tt:SetCell(lineIndex,cellIndex,Zone);
		cellIndex = cellIndex + 1;
	end

	-- notes
	if flags.showNotes then
		local str = ns.scm(mNote);
		tt:SetCell(lineIndex,cellIndex,offColor and C(offColor,str) or str);
		cellIndex = cellIndex + 1;
	end

	-- officer notes
	if flags.showONotes and CanViewOfficerNote() then -- extend if
		local str = ns.scm(mOfficerNote)
		tt:SetCell(lineIndex,cellIndex,offColor and C(offColor,str) or str);
		cellIndex = cellIndex + 1;
	end

	-- rank
	if flags.showRank then
		local rankID="";
		if flags.showRank and flags.showRankID then
			rankID = " "..C("gray","("..mRankIndex..")");
		end
		tt:SetCell(lineIndex,cellIndex,C(offColor or (mRankIndex==0 and "green") or "white",ns.scm(mRank))..rankID);
		cellIndex = cellIndex + 1;
	end

	-- professions / trade skills
	if flags.showProfessions and tradeskills[mFullName] then
		if tradeskills[mFullName][1] then
			tt:SetCell(lineIndex,cellIndex,"|T"..tradeskills[mFullName][1][tsIcon]..":0|t");
			tt:SetCellScript(lineIndex, cellIndex, "OnMouseUp", GetMemberRecipes,{name=mFullName,id=tradeskills[mFullName][1][4]});
			cellIndex = cellIndex + 1;
		end
		if tradeskills[mFullName][2] then
			tt:SetCell(lineIndex,cellIndex,"|T"..tradeskills[mFullName][2][tsIcon]..":0|t");
			tt:SetCellScript(lineIndex, cellIndex, "OnMouseUp", GetMemberRecipes,{name=mFullName,id=tradeskills[mFullName][2][4]});
			cellIndex = cellIndex + 1;
		end
	end

	if mFullName==ns.player.name_realm_short then
		tt:SetLineColor(lineIndex, .5, .5, .5);
	else
		tt:SetLineColor(lineIndex, 0, 0, 0, 0);
	end

	tt:SetLineScript(lineIndex, "OnMouseUp", memberInviteOrWhisper, memberIndex);

	if ns.profile[name].showZoneInTT2 or ns.profile[name].showNotesInTT2 or ns.profile[name].showONotesInTT2 or ns.profile[name].showRankInTT2 or ns.profile[name].showProfessionsInTT2 then
		tt:SetLineScript(lineIndex,"OnEnter",createTooltip2,memberIndex);
	end
end

local ttScrollList

local function slider_OnValueChanged()
	-- TODO: need content
end

function ttScrollList(delta,tbl) -- executed by createTooltip and ttWheelHook
	local scrollInfo,target,new = membScroll,"Members",false;
	scrollInfo.numLines = ns.profile[name].numMembersScroll;
	if tbl==applicants then
		scrollInfo,target = applScroll,"Applicants";
	end
	local start,stop,numEntries = 0,scrollInfo.numLines,#tbl;
	local maxSteps = ceil(numEntries/scrollInfo.stepWidth)-floor(scrollInfo.numLines/scrollInfo.stepWidth);

	if delta == 0 then
		wipe(scrollInfo.lines);
		scrollInfo.step,new = 0,true;
		if not scrollInfo.slider then
			-- create scroll region
			local scrollRegion = CreateFrame("Frame",addon.."Guild"..target.."ScrollRegion",tt,BackdropTemplateMixin and "BackdropTemplate");
			scrollInfo.region = scrollRegion;
			scrollRegion:SetBackdrop({bgFile="interface/buttons/white8x8"});
			scrollRegion:SetBackdropColor(unpack(ns.profile[name].showTableBackground and scrollInfo.regionColor or {0,0,0,0}));
			scrollRegion:SetFrameLevel(tt:GetFrameLevel()+1);
			scrollRegion:SetScript("OnMouseWheel",function(self,delta)
				ttScrollList(-delta, tbl);
			end);
			scrollRegion:EnableMouseWheel(true);

			-- create slider
			local slider = CreateFrame("Slider",addon.."Guild"..target.."ScrollSlider",tt,BackdropTemplateMixin and "BackdropTemplate");
			scrollInfo.slider = slider;
			slider.parent = scrollInfo;
			slider:SetOrientation("VERTICAL");
			slider:SetBackdrop(BACKDROP_SLIDER_8_8);
			slider:SetThumbTexture([[Interface\Buttons\UI-SliderBar-Button-Vertical]]);
			slider:SetWidth(12)
			slider:SetMinMaxValues(0, 1)
			slider:SetValueStep(1)
			slider:SetValue(0)
			slider:SetScript("OnValueChanged", slider_OnValueChanged);
		end
	else
		local newStep = scrollInfo.step + (delta==true and 0 or delta);
		if newStep>maxSteps or numEntries<=scrollInfo.numLines or newStep<0 then
			return; -- update not necessary
		end
		scrollInfo.step = newStep;
		start = newStep*scrollInfo.stepWidth;
		stop = start+scrollInfo.numLines;
	end

	-- clear lines
	if stop>numEntries then
		for i=1, #scrollInfo.lines do
			local line = scrollInfo.lines[i];
			for cell in pairs(tt.lines[line].cells) do
				tt:SetCell(line,cell);
			end
		end
	end

	-- set lines
	local lineIndex = 1;
	for i=1+start, stop do
		if tbl[i] then
			local line = scrollInfo.lines[lineIndex];
			if not line then
				line = tt:AddLine();
				scrollInfo.lines[lineIndex] = line;
			end
			if tbl==applicants then
				ttAddApplicant(line,tbl[i]);
			else
				ttAddMember(line,tbl[i]);
			end
			lineIndex = lineIndex + 1;
		end
	end

	-- update scroll region
	scrollInfo.region:SetParent(tt);
	scrollInfo.region:SetPoint("TOPLEFT",tt.lines[ scrollInfo.lines[1]-2 ],-4,2);
	scrollInfo.region:SetPoint("BOTTOMRIGHT",tt.lines[ scrollInfo.lines[#scrollInfo.lines] ],4,-2);
	scrollInfo.region:SetFrameLevel(tt:GetFrameLevel()+1);
	scrollInfo.region:Show();
	scrollInfo.region.hidden = nil;

	if new and maxSteps>1 then
		-- update slider
		scrollInfo.slider:SetParent(tt);
		scrollInfo.slider:SetPoint("TOPRIGHT",tt.lines[ scrollInfo.lines[1] ],"TOPRIGHT",0,4);
		scrollInfo.slider:SetPoint("BOTTOMRIGHT",tt.lines[ scrollInfo.lines[#scrollInfo.lines] ],"BOTTOMRIGHT",0,-4);
		scrollInfo.slider:SetFrameLevel(tt.lines[1]:GetFrameLevel()+1);
		scrollInfo.slider:SetMinMaxValues(0,maxSteps);
		scrollInfo.slider:Show();
		scrollInfo.slider.hidden = nil;
	end

	scrollInfo.slider:SetValue(scrollInfo.step);
end

local function createTooltip(tt,update)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end

	if (not IsInGuild()) then
		tt:AddHeader(C("dkyellow",GUILD));
		tt:AddSeparator();
		tt:AddLine(C("ltgray",ERR_GUILD_PLAYER_NOT_IN_GUILD));
		ns.roundupTooltip(tt);
		return;
	end

	updateBattleNetFriends();

	local gName, gDesc, pStanding, pStandingMin, pStandingMax, pStandingValue, pStandingText
	if GetGuildFactionInfo then
		gName, gDesc, pStanding, pStandingMin, pStandingMax, pStandingValue = GetGuildFactionInfo();
		pStandingText = _G["FACTION_STANDING_LABEL"..pStanding];
	else -- for classic
		gName = GetGuildInfo("player")
	end

	local _,_,_,gRealm = GetGuildInfo("player");
	if gRealm==nil then
		gRealm=ns.realm;
	end

	local numMembers, numMembersOnline = GetNumGuildMembers();

	-- HEADER
	local l = tt:AddHeader();
	tt:SetCell(l,1,C("dkyellow",GUILD) .. "  " .. C("green",ns.scm(gName)) .. ns.scm(ns.showRealmName(name,gRealm)), nil,"LEFT",ttColumns);

	tt:AddSeparator(4,0,0,0,0);

	-- MOTD
	local sep=false;
	if (ns.profile[name].showMOTD) then
		local l = tt:AddLine(C("ltblue",MOTD_COLON));
		local motd,color = (GetGuildRosterMOTD() or ""):trim(),"ltgreen";
		if motd=="" then
			motd,color = EMPTY,"gray"
		elseif ns.profile.GeneralOptions.scm then
			motd = "***********" -- shorter
		else
			-- motd = ns.scm(ns.strWrap(motd,56),true)
		end
		tt:SetCell(l, 2, C(color,motd), nil, nil, 0, nil, nil, nil, 220);
		-- SetSell(lineNum, colNum, value, font, justification, colSpan, provider, leftPadding, rightPadding, maxWidth, minWidth, ...)
		sep = true;
	end

	-- PLAYER STANDING
	if ns.profile[name].showRep and pStandingValue then
		local l = tt:AddLine(C("ltblue",REPUTATION_ABBR..HEADER_COLON));
		if pStandingMax-pStandingMin>0 then
			pStandingText = ("%s: (%d/%d)"):format(pStandingText, pStandingValue-pStandingMin, pStandingMax-pStandingMin);
		end
		tt:SetCell(l,2,pStandingText, nil, nil, 0);
		sep=true;
	end

	-- guild info
	if ns.profile[name].showInfo then
		local l = tt:AddLine();
		tt:SetCell(l,1,C("ltblue",GUILD_INFORMATION),nil,"LEFT",ttColumns-1);
		tt:SetCell(l,ttColumns,icon_arrow_right,nil,"RIGHT");
		tt:SetLineScript(l,"OnEnter",createTooltip3,"info");
		tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);
		sep=true;
	end

	-- CHALLENGES
	if ns.profile[name].showChallenges and ns.client_version>=6 then
		local l = tt:AddLine();
		tt:SetCell(l,1,C("ltblue",GUILD_CHALLENGE_LABEL),nil,"LEFT",ttColumns-1);
		tt:SetCell(l,ttColumns,icon_arrow_right,nil,"RIGHT");
		tt:SetLineScript(l,"OnEnter",createTooltip3,"challenges");
		tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);
		sep = true;
	end

	if sep then
		tt:AddSeparator(4,0,0,0,0);
	end

	-- applicants
	if ns.profile[name].showApplicants and C_ClubFinder and C_ClubFinder.ReturnClubApplicantList then
		applicants = GetApplicants();
		if applicants and #applicants>0 then
			local line,column = tt:AddLine(
				C("orange",LEVEL),
				C("orange",L["Applicant"]),
				C("orange",COMMUNITY_MEMBER_LIST_DROP_DOWN_ROLES),
				C("orange",RAID_INSTANCE_EXPIRES_EXPIRED),
				C("orange",COMMENT)
			);
			tt:AddSeparator();
			ttScrollList(0,applicants);
			tt:AddLine(" ");
		end
	end

	-- member list header line
	local titles = {
		C("ltyellow",LEVEL), -- [1]
		C("ltyellow",CHARACTER), -- [2]
	};
	if flags.showRace then
		tinsert(titles,C("ltyellow",RACE));
	end
	if flags.showZone then
		tinsert(titles,C("ltyellow",ZONE));
	end
	if flags.showNotes then
		tinsert(titles,C("ltyellow",COMMUNITIES_ROSTER_COLUMN_TITLE_NOTE));
	end
	if flags.showONotes and CanViewOfficerNote() then -- extend if
		tinsert(titles,C("ltyellow",OFFICER_NOTE_COLON));
	end
	if flags.showRank then
		tinsert(titles,C("ltyellow",RANK));
	end
	local l=tt:AddLine(unpack(titles));
	if flags.showProfessions then
		tt:SetCell(l,#titles+1,C("ltyellow",TRADE_SKILLS), nil,nil,2); -- [8,9]
	end

	tt:SetCell(l,ttColumns,"    ");

	tt:AddSeparator();

	wipe(membersOnline);
	for i=1, numMembers do
		local mFullName,mRank,mRankIndex,mLevel,mClassLocale,mZone,mNote,mOfficerNote,mOnline,mIsAway,mClassFile,_,_,mIsMobile,_,mStanding,mGUID = GetGuildRosterInfo(i);
		if mOnline then
			tinsert(membersOnline,i);
		end
	end

	ttScrollList(0,membersOnline);

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0);

		if (ns.profile[name].showApplicants) and applicants and #applicants>0 then
			local l = tt:AddLine();
			tt:SetCell(l,1,C("orange",L["MouseBtn"]).." || "..C("green","Guild applications"),nil,"LEFT",ttColumns);
		end

		if (ttColumns>4) then
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["MouseBtn"]).." || "..C("green",WHISPER) .." - ".. C("ltblue",L["ModKeyA"].."+"..L["MouseBtn"]).." || "..C("green",TRAVEL_PASS_INVITE),nil,"LEFT",ttColumns);
		else
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["MouseBtn"]).." || "..C("green",WHISPER),nil,"LEFT",ttColumns);
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["ModKeyA"].."+"..L["MouseBtn"]).." || "..C("green",TRAVEL_PASS_INVITE),nil,"LEFT",ttColumns);
		end

		if (module.clickHints) then
			local steps,t1,t2=1,{},{};
			if (ttColumns>4) then
				steps=2;
			end
			for i=1, #module.clickHints, steps do
				if (ttColumns>4) then
					t2 = {};
					if (module.clickHints[i]) then tinsert(t2,module.clickHints[i]); end
					if (module.clickHints[i+1]) then tinsert(t2,module.clickHints[i+1]); end
					tinsert(t1,table.concat(t2," - "));
				else
					if (module.clickHints[i]) then
						tinsert(t1,module.clickHints[i]);
					end
				end
			end
			for i,v in ipairs(t1) do
				tt:SetCell(tt:AddLine(),1,v,nil,"LEFT",ttColumns);
			end
		end
	end

	if not update then
		ns.roundupTooltip(tt);
	end
end

local function hideScrollElements()
	for _,si in ipairs({applScroll,membScroll})do
		if si.region and not si.region.hidden then
			si.region:ClearAllPoints();
			si.region:SetParent(frame);
			si.region:Hide();
			si.region.hidden = true
		end
		if si.slider and not si.slider.hidden then
			si.slider:ClearAllPoints();
			si.slider:SetParent(frame);
			si.slider:Hide();
			si.slider.hidden = true
		end
	end
end

local function ttOnShowHook(self)
	if tt and tt.key==ttName then return end
	hideScrollElements(); -- force hide of scroll elements if tooltip owned by another addon or module
end

local function ttOnHideHook(self)
	if tt and tt~=self and tt.key~=ttName then return end
	-- LibQTip reuse tooltips and it is a good practice.
	-- This should respect foreign addon tooltips ;-) after bypassing LibQTips HookScript blocker.
	-- The blocker is good and should stay. A good reminder not to be too careless about using HookScript.
	hideScrollElements();
end

-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"PLAYER_GUILD_UPDATE",

		--"GUILD_MOTD",
		--"GUILD_RANKS_UPDATE",
		"GUILD_ROSTER_UPDATE",
		--"CHAT_MSG_SYSTEM",
	},
	config_defaults = {
		enabled = true,

		-- guild
		showRep = true,
		showMOTD = true,
		showChallenges = true,
		showInfo = true,

		-- guild members
		showRealmNames = true,
		showRace = true,		showRaceInTT2 = false,
		showZone = true,		showZoneInTT2 = false,
		showNotes = true,		showNotesInTT2 = false,
		showONotes = true,		showONotesInTT2 = false,
		showRank = true,		showRankInTT2 = false,
		showRankID = false,
		showProfessions = true,	showProfessionsInTT2 = false,
		showBattleTag = true,
		showTableBackground = true,
		numMembersScroll = 15,

		-- misc
		showApplicants = true,
		showApplicantsBroker = true,
		showMobileChatter = true,
		showMobileChatterBroker = true,
		showTotalMembersBroker = true,
		--splitTables = false, -- deprecated
		showMembersLevelUp = true,
		showMembersNotes = false,
		showMembersOffNotes = false
	},
	clickOptionsRename = {
		["guild"] = "1_open_guild",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["guild"] = "Guild",
		["menu"] = "OptionMenu"
	}
}

if ns.client_version<5 then
	module.config_defaults.showONotes = false
	module.config_defaults.showONotesInTT2 = false
	module.config_defaults.showProfessions = false
	module.config_defaults.showProfessionsInTT2 = false
	module.config_defaults.showApplicants = false
	module.config_defaults.showApplicantsBroker = false
	module.config_defaults.showTableBackground = false;
end

ns.ClickOpts.addDefaults(module,{
	guild = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			showApplicantsBroker    = { type="toggle", order=1, name=L["Applicants"], desc=L["Show applicants on broker button"], hidden=ns.IsClassicClient },
			showMobileChatterBroker = { type="toggle", order=2, name=L["Mobile app user"], desc=L["Show count of mobile chatter on broker button"] },
			showTotalMembersBroker  = { type="toggle", order=3, name=L["Total members count"], desc=L["Show total members count on broker button"] },
		},
		tooltip1 = {
			name = L["Main tooltip options"],
			order = 2,
			showRep           = { type="toggle", order= 1, name=GUILD_REPUTATION, desc=L["Enable/Disable the display of Guild Reputation in tooltip"] },
			showMOTD          = { type="toggle", order= 2, name=L["Guild MotD"], desc=L["Show Guild Message of the Day in tooltip"] },
			showInfo          = { type="toggle", order= 3, name=GUILD_INFORMATION, desc=L["GuildShowInfoDesc"], hidden=ns.IsClassicClient },
			showChallenges    = { type="toggle", order= 4, name=GUILD_CHALLENGE_LABEL, desc=L["GuildShowChallengesDesc"], hidden=ns.IsClassicClient },

			showRealmNames    = 20,
			showRace          = { type="toggle", order=21, name=RACE, desc=L["Show race from guild members in tooltip"]},
			showZone          = { type="toggle", order=22, name=ZONE, desc=L["Show current zone from guild members in tooltip"]},
			showNotes         = { type="toggle", order=23, name=L["Notes"], desc=L["Show notes from guild members in tooltip"]},
			showONotes        = { type="toggle", order=24, name=OFFICER_NOTE_COLON, desc=L["Show officer notes from guild members in tooltip. (This option will be ignored if you have not permission to read the officer notes)"], hidden=ns.IsClassicClient},
			showRank          = { type="toggle", order=25, name=RANK, desc=L["Show rank name from guild members in tooltip"]},
			showRankID        = { type="toggle", order=26, name=RANK.."ID", desc=L["Show rank id from guild members in tooltip"]},
			showProfessions   = { type="toggle", order=27, name=TRADE_SKILLS, desc=L["Show professions from guild members in tooltip"], hidden=ns.IsClassicClient },
			showApplicants    = { type="toggle", order=28, name=L["Applicants"], desc=L["Show applicants in tooltip"], hidden=ns.IsClassicClient },
			showMobileChatter = { type="toggle", order=29, name=L["Mobile app user"], desc=L["Show mobile chatter in tooltip (Armory App users)"] },
			--splitTables       = { type="toggle", order=30, name=L["Separate mobile app user"], desc=L["Display mobile chatter with own table in tooltip"] }, -- deprecated
			showBattleTag     = { type="toggle", order=31, name=BATTLETAG, desc=L["Append the BattleTag of your friends to the character name"], hidden=ns.IsClassicClient },
			showTableBackground={ type="toggle", order=32, name=L["GuildTableBg"], desc=L["GuildTableBgDesc"], hidden=ns.IsClassicClient },
			numMembersScroll  = { type="range", order=33, name=L["NumMembersScroll"], desc=L["NumMembersScrollDesc"], min=15, max=80, step=1},
		},
		tooltip2 = {
			name = L["Secondary tooltip options"],
			order = 3,
			desc                 = { type="description", order=1, name=L["The secondary tooltip will be displayed by moving the mouse over a guild member in main tooltip. The tooltip will be displayed if one of the following options activated."], fontSize="medium"},
			showRaceInTT2        = { type="toggle",      order=2, name=RACE, desc=L["Show race from guild member"]},
			showZoneInTT2        = { type="toggle",      order=2, name=ZONE, desc=L["Show current zone from guild member"]},
			showNotesInTT2       = { type="toggle",      order=3, name=L["Notes"], desc=L["Show notes from guild member"]},
			showONotesInTT2      = { type="toggle",      order=4, name=OFFICER_NOTE_COLON, desc=L["Show officer notes from guild member"], hidden=ns.IsClassicClient},
			showRankInTT2        = { type="toggle",      order=5, name=RANK, desc=L["Show rank from guild member"]},
			showProfessionsInTT2 = { type="toggle",      order=6, name=TRADE_SKILLS, desc=L["Show professions from guild member"], hidden=ns.IsClassicClient}
		},
		misc = {
			order = 4,
			showMembersLevelUp  = { type="toggle", order=1, name=L["Show level up notification"], desc=L["Show guild member level up notification in chat frame. (This is not a gratulation bot!)"]},
			showMembersNotes    = { type="toggle", order=2, name=L["Show notes in login"], desc=L["Display member notes in chat window after his/her login message"] },
			showMembersOffNotes = { type="toggle", order=3, name=L["Show off. notes on login"], desc=L["Display member officer notes in chat window after his/her login message"] },
		},
	},
	{
		showProfessions=true
	}
end

-- function module.init() end

function module.onevent(self,event,msg,...)
	if event=="BE_UPDATE_CFG" and msg and msg:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="BE_UPDATE_CFG" and msg=="showTableBackground" then
		local hide = false;
		if not ns.profile[name].showTableBackground then
			hide = {0,0,0,0};
		end
		if applScroll.region then
			applScroll.region:SetBackdropColor(unpack(hide or applScroll.regionColor));
		end
		if membScroll.region then
			membScroll.region:SetBackdropColor(unpack(hide or membScroll.regionColor));
		end
	elseif event=="PLAYER_LOGIN" or (ns.eventPlayerEnteredWorld and not self.IsLoaded) then
		self.IsLoaded = true;
		frame = self;
		if C_GuildInfo and C_GuildInfo.GuildRoster then
			if ns.client_version>=7 then
				self:RegisterEvent("GUILD_TRADESKILL_UPDATE");
			end
			if C_ClubFinder and C_ClubFinder.RequestApplicantList then
				--self:RegisterEvent("CLUB_FINDER_RECRUITS_UPDATED");
				self:RegisterEvent("CLUB_FINDER_RECRUIT_LIST_CHANGED");
				if CanUpdateApplicants() then
					C_ClubFinder.RequestSubscribedClubPostingIDs(); -- init clubfinder recuits list
					C_ClubFinder.RequestApplicantList(Enum.ClubFinderRequestType.Guild); -- trigger CLUB_FINDER_RECRUITS_UPDATED
				end
			end
		end
		RequestGuildRosterUpdate(true);
	elseif event=="GUILD_TRADESKILL_UPDATE" then
		local t = time();
		if tradeSkillsUpdateDelay+15>=t then
			return;  -- do not update trade skills under 15sec again
		end
		tradeSkillsUpdateDelay = t;
		updateTradeSkills();
	elseif event=="CHAT_MSG_SYSTEM" and (ns.profile[name].showMembersNotes or ns.profile[name].showMembersOffNotes) then
		-- update online status; GUILD_ROSTER_UPDATE/GetGuildRosterInfo trigger too slow real updates
		local state,member = "online",msg:gsub("[\124:%[%]]","#"):match(pattern_FRIEND_ONLINE);
		if not member then
			state,member = "offline",msg:match(pattern_FRIEND_OFFLINE);
		end
		if member and not member:find("-") then
			member = member.."-"..ns.realm_short;
		end
		if member and memberIndex[member] then
			-- On/Off post notes of guild members in general chat.
			local mFullName,_,_,_,_,_,mNote,mOfficerNote,mOnline,_,mClassFile,_,_,mIsMobile = GetGuildRosterInfo(memberIndex[member]);
			local mName = strsplit("-",mFullName,2);
			local txt={};
			if ns.profile[name].showMembersNotes then
				local str = strtrim(mNote);
				if str:len()>0 then
					tinsert(txt,C("ltgray",NOTE_COLON).." "..C("ltblue",str));
				end
			end
			if ns.profile[name].showMembersOffNotes then
				local str = strtrim(mOfficerNote);
				if str:len()>0 then
					tinsert(txt,C("ltgray",GUILD_OFFICERNOTES_LABEL).." "..C("ltblue",str));
				end
			end
			if #txt>0 then
				local mobileIcon = "";
				if mIsMobile then
					mobileIcon = ChatFrame_GetMobileEmbeddedTexture(73/255, 177/255, 73/255)
				end
				tinsert(txt,1,C("ltgray",LFG_LIST_GUILD_MEMBER)..CHAT_HEADER_SUFFIX..C(mClassFile,mName).." "..mobileIcon);
				C_Timer.After(0.1,function()
					-- should prevent display this line before blizzards message
					ns:print(true,table.concat(txt," || "));
				end);
			end
		end
	else -- on events -- BE_DUMMY_EVENT / PLAYER_GUILD_UPDATE / GUILD_ROSTER_UPDATE / CLUB_FINDER_RECRUIT_LIST_CHANGED

		if event=="BE_DUMMY_EVENT" or chatNotificationEnabled==nil then
			-- toggle events
			local doChatNotification =  (ns.profile[name].showMembersNotes or ns.profile[name].showMembersOffNotes);
			if chatNotificationEnabled~=doChatNotification then
				chatNotificationEnabled=doChatNotification;
				if doChatNotification then
					self:RegisterEvent("CHAT_MSG_SYSTEM");
				else
					self:UnregisterEvent("CHAT_MSG_SYSTEM");
				end
			end
		end

		if event=="GUILD_ROSTER_UPDATE" and msg==true then
			RequestGuildRosterUpdate(true);
			return;
		end

		updateBroker();
	end
end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	local ttAlignings = {"LEFT"};
	ttColumns = 1;

	local inGuild = IsInGuild();
	if inGuild then
		ttAlignings = {
			"RIGHT", -- level
			"LEFT" -- name
		};

		wipe(flags);
		if ns.profile[name].showRace then
			tinsert(ttAlignings,"LEFT"); -- race
			flags.showRace=true;
		end
		if ns.profile[name].showZone then
			tinsert(ttAlignings,"CENTER"); -- zone
			flags.showZone=true;
		end
		if ns.profile[name].showNotes then
			tinsert(ttAlignings,"LEFT"); -- notes
			flags.showNotes=true;
		end
		if ns.profile[name].showONotes and CanViewOfficerNote() then -- extend if
			tinsert(ttAlignings,"LEFT"); -- onotes
			flags.showONotes=true;
		end
		if ns.profile[name].showRank then
			tinsert(ttAlignings,"LEFT"); -- rank
			flags.showRank=true;
		end
		if ns.profile[name].showProfessions then
			tinsert(ttAlignings,"CENTER"); -- professions 1
			tinsert(ttAlignings,"CENTER"); -- professions 2
			flags.showProfessions=true;
		end

		tinsert(ttAlignings,"RIGHT"); -- arrow right

		ttColumns = #ttAlignings;

		if ns.profile[name].showApplicants then
			ttColumns = max(ttColumns,5); -- min 5 cols for applicants
		end
	end

	tt = ns.acquireTooltip({ttName, ttColumns,unpack(ttAlignings)},{false},{self});

	createTooltip(tt);

	if inGuild then
		if not ttHooks[tt] then
			ttHooks[tt] = true;
			self.HookScript(tt,"OnHide",ttOnHideHook);
			self.HookScript(tt,"OnShow",ttOnShowHook);
		end
	end
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
