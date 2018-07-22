
-- module independent variables --
----------------------------------
local addon,ns = ...;
local C,L,I=ns.LC.color,ns.L,ns.I;


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Guild"; -- GUILD
local ttName,ttName2,ttColumns,ttColumns2,tt,tt2,module = name.."TT", name.."TT2",10,2;
local off,on = strtrim(ERR_FRIEND_OFFLINE_S:gsub("%%s","(.*)")),strtrim(ERR_FRIEND_ONLINE_SS:gsub("[\124:%[%]]","#"):gsub("%%s","(.*)"));
local tradeskillsLockUpdate,tradeskillsLastUpdate,tradeskillsUpdateTimeout = false,0,20;
local guild, player, members, membersName2Index, mobile, tradeskills, applicants = {},{},{},{},{},{},{};
local doGuildUpdate,doMembersUpdate, doTradeskillsUpdate, doApplicantsUpdate, doUpdateTooltip,updaterLocked = false,false,false,false,false,false;
local gName, gDesc, gRealm, gRealmNoSpacer, gMotD, gNumMembers, gNumMembersOnline, gNumMobile, gNumApplicants = 1,2,3,4,5,6,7,8,9;
local pStanding, pStandingText, pStandingMin, pStandingMax, pStandingValue = 1,2,3,4,5;
local mFullName, mName, mRealm, mRank, mRankIndex, mLevel, mClassLocale, mZone, mNote, mOfficerNote, mOnline, mIsAway, mClassFile, mAchievementPoints, mAchievementRank, mIsMobile, mCanSoR, mStanding, mGUID, mStandingText, mRaceId = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21;
local tsName, tsIcon, tsValue, tsID = 1,2,3,4;
local app_index, app_name, app_realm, app_level, app_class, app_bQuest, app_bDungeon, app_bRaid, app_bPvP, app_bRP, app_bWeekdays, app_bWeekends, app_bTank, app_bHealer, app_bDamage, app_comment, app_timeSince, app_timeLeft = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18; -- applicants table entry indexes
local raceCache,raceById,flags = {},{},{};
local MOBILE_BUSY_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat-BusyMobile:14:14:0:0:16:16:0:16:0:16|t";
local MOBILE_AWAY_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat-AwayMobile:14:14:0:0:16:16:0:16:0:16|t";
local last,membersUpdateTicker = {};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=135026,coords={0.05,0.95,0.05,0.95}} --IconName::Guild--


-- some local functions --
--------------------------
local function updateGuild()
	if not IsInGuild() then wipe(guild); return; end
	local tmp,_={};
	tmp[gName], tmp[gDesc], player[pStanding], player[pStandingMin], player[pStandingMax], player[pStandingValue] = GetGuildFactionInfo();
	player[pStandingText] = _G["FACTION_STANDING_LABEL"..player[pStanding]];
	_,_,_,tmp[gRealm] = GetGuildInfo("player");
	if tmp[gRealm]==nil then
		tmp[gRealm]=ns.realm;
	end
	tmp[gRealmNoSpacer] = gsub(tmp[gRealm]," ","");
	tmp[gMotD] = GetGuildRosterMOTD();
	tmp[gNumMembers], tmp[gNumMembersOnline] = GetNumGuildMembers();
	tmp[gNumApplicants] = GetNumGuildApplicants();
	tmp[gNumMobile] = 0;
	if tmp[gNumApplicants]>0 then
		doApplicantsUpdate = true;
	end
	if guild[gNumMembers]~=tmp[gNumMembers] then
		doTradeskillsUpdate = true;
	end
	guild = tmp;
end

local function updateMembers()
	if not IsInGuild() then wipe(members); wipe(membersName2Index); return; end
	local tmp,tmpNames,missingData,_ = {},{},{};
	guild[gNumMobile] = 0;
	for i=1, guild[gNumMembers] do
		local m,old,RaceName,_ = {};
		m[mFullName], m[mRank], m[mRankIndex], m[mLevel], m[mClassLocale], m[mZone], m[mNote], m[mOfficerNote], m[mOnline], m[mIsAway], m[mClassFile], _, _, m[mIsMobile], _, m[mStanding], m[mGUID] = GetGuildRosterInfo(i);
		tmpNames[m[mFullName]]=i;
		m[mName], m[mRealm] = strsplit("-",m[mFullName],2);
		m[mStandingText] = _G["FACTION_STANDING_LABEL"..m[mStanding]];
		if m[mIsMobile] and m[mOnline] then
			guild[gNumMobile] = guild[gNumMobile]+1;
		end
		if m[mGUID] then
			if raceCache[m[mGUID]] then
				m[mRaceId] = raceCache[m[mGUID]];
			else
				_, _, RaceName, m[mRaceId] = GetPlayerInfoByGUID(m[mGUID]);
				if RaceName then
					raceById[m[mRaceId]] = RaceName;
					raceCache[m[mGUID]] = m[mRaceId];
				else
					tinsert(missingData,m[mGUID]);
				end
			end
		end
		if not m[mRealm] then
			m[mRealm] = ns.realm_short;
		end
		if membersName2Index[m[mFullName]] and members[membersName2Index[m[mFullName]]] then
			old = members[membersName2Index[m[mFullName]]];
			if m[mZone]~=old[mZone] then
				doUpdateTooltip = true;
			end
			if ns.profile[name].showMembersLevelUp and m[mFullName]~=ns.player.name_realm_short and old[mLevel]~=nil and m[mLevel]~=old[mLevel] then
				ns.print( C(m[mClassFile],m[mName]) .." ".. C("green",L["has reached Level %d."]:format(m[mLevel])) );
				doUpdateTooltip = true;
			end
		end
		tinsert(tmp,m);
	end
	if #missingData>0 then
		C_Timer.After(1,function()
			for i=1, #missingData do
				local _, _, RaceName, RaceId = GetPlayerInfoByGUID(missingData[i]);
				if RaceName then
					raceById[RaceId] = RaceName;
					raceCache[missingData[i]] = RaceId;
				end
			end
		end);
	end
	members = tmp;
	membersName2Index = tmpNames;
end

local function updateTradeSkills()
	if not IsInGuild() then wipe(tradeskills); return; end
	if (tradeSkillsLockUpdate) or (time()-tradeskillsLastUpdate<=tradeskillsUpdateTimeout) or (GuildRosterFrame~=nil and GuildRosterFrame:IsShown() and GetCVar("guildRosterView")=="tradeskill") then return; end
	tradeskillsLockUpdate = true;
	doTradeskillsUpdate = false;

	local skillID,isCollapsed,iconTexture,headerName,numOnline,numVisible,numPlayers,playerName,playerFullName,class,online,zone,skill,classFileName,isMobile,isAway = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16; -- GetGuildTradeSkillInfo
	local headers = {};
	local header = {};
	local collapsed = {};

	-- 1. run...
	local num = GetNumGuildTradeSkill();
	for index=num, 1, -1 do
		local d = {GetGuildTradeSkillInfo(index)};
		if d[headerName] and d[isCollapsed] then
			tinsert(collapsed,d[skillID]);
			ExpandGuildTradeSkillHeader(d[skillID]);
		end
	end

	-- 2. run...
	local tmp,skillHeader = {},{};
	local num = GetNumGuildTradeSkill();
	for index=1, num do
		local d = {GetGuildTradeSkillInfo(index)};
		if (d[headerName]) then
			skillHeader = {d[headerName],d[iconTexture],d[skillID]};
		elseif (d[playerFullName]) then
			if (tmp[d[playerFullName]]==nil) then
				tmp[d[playerFullName]]={};
			end
			tinsert(
				tmp[d[playerFullName]],
				{
					skillHeader[1],
					skillHeader[2] or ns.icon_fallback,
					d[skill],
					skillHeader[3] or d[skillID]
				}
			); -- a nil value?
		end
	end
	tradeskills = tmp;

	-- 3. run... collapse prev. expanded skills
	for i=1, #collapsed do
		CollapseGuildTradeSkillHeader(collapsed[i]);
	end

	tradeskillsLastUpdate = time();
	tradeskillsLockUpdate = false;
end

local function updateApplicants()
	local temp = {};
	guild[gNumApplicants] = GetNumGuildApplicants();
	for index=1, guild[gNumApplicants] do
		local applicant,Realm = {GetGuildApplicantInfo(index)};
		tinsert(applicant,1,index);
		applicant[app_name], Realm = strsplit("-",applicant[app_name],2);
		tinsert(applicant,app_realm,Realm or guild[gRealmNoSpacer]);
		tinsert(temp,applicant);
	end
	applicants = temp;
	if #temp~=guild[gNumApplicants] then
		doApplicantsUpdate = true;
	end
end

local function updateBroker()
	local broker = ns.LDB:GetDataObjectByName(module.ldbName);
	if guild[gName] then
		local txt = {};
		if (ns.profile[name].showApplicantsBroker) and (guild[gNumApplicants]>0) then
			tinsert(txt, C("orange",guild[gNumApplicants]));
		end
		if (ns.profile[name].showMobileChatterBroker) then
			tinsert(txt, C("ltblue",guild[gNumMobile]));
		end
		tinsert(txt,C("green",guild[gNumMembersOnline]));
		if (ns.profile[name].showTotalMembersBroker) then
			tinsert(txt,C("green",guild[gNumMembers]));
		end
		broker.text = table.concat(txt,"/");
	else
		broker.text = L["No guild"];
	end
end

local function GetMemberRecipes(self,info)
	GetGuildMemberRecipes(info.name,info.id);
end

local function memberInviteOrWhisper(self,info)
	if IsAltKeyDown() then
		if not info[mIsMobile] then
			InviteUnit(info[mFullName]);
		end
	else
		SetItemRef("player:"..info[mFullName], ("|Hplayer:%1$s|h[%1$s]|h"):format(info[mFullName]), "LeftButton");
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

local function createTooltip2(self,info)
	local v,s,t,_ = info,"";
	local realm = v[mRealm] or "";

	tt2 = ns.acquireTooltip(
		{ttName2, ttColumns2, "LEFT","RIGHT"},
		{true,true},
		{self, "horizontal", tt}
	);

	if tt2.lines~=nil then tt2:Clear(); end
	tt2:AddHeader(C("dkyellow",NAME), C(v[mClassFile],ns.scm(v[mName])));
	tt2:AddSeparator();
	if type(realm)=="string" and realm:len()>0 then
		local _,_realm = ns.LRI:GetRealmInfo(realm);
		if _realm then realm = _realm; end
	end
	tt2:AddLine(C("ltblue",L["Realm"]),C("dkyellow",ns.scm(realm)));
	if ns.profile[name].showRaceInTT2 and v[mRaceId] and racebyId[v[mRaceId]] then
		tt2:AddLine(C("ltblue",RACE),racebyId[v[mRaceId]]);
	end
	if ns.profile[name].showZoneInTT2 then
		tt2:AddLine(C("ltblue",ZONE),v[mZone]);
	end
	if ns.profile[name].showNotesInTT2 then
		tt2:AddLine(C("ltblue",LABEL_NOTE),ns.scm(v[mNote]));
	end
	if ns.profile[name].showONotesInTT2 then
		if v[mOfficerNote]=="" then
			tt2:AddLine(C("ltblue",OFFICER_NOTE_COLON),C("gray","<"..EMPTY..">"));
		else
			tt2:AddLine(C("ltblue",OFFICER_NOTE_COLON),ns.scm(v[mOfficerNote]));
		end
	end
	if ns.profile[name].showRankInTT2 then
		tt2:AddLine(C("ltblue",RANK),ns.scm(v[mRank]));
	end
	if ns.profile[name].showProfessionsInTT2 and tradeskills[v[mFullName]] then
		t=tradeskills[v[mFullName]][1];
		tt2:AddLine(C("ltblue",TRADE_SKILLS),t[tsName].." |T"..t[tsIcon]..":0|t ["..t[tsValue].."]");
		if tradeskills[v[mFullName]][2] then
			t=tradeskills[v[mFullName]][2];
			tt2:AddLine(" ", t[tsName].." |T"..t[tsIcon]..":0|t ["..t[tsValue].."]");
		end
	end
	tt2:AddSeparator(1,0,0,0,0);
	ns.roundupTooltip(tt2, nil, "horizontal", tt);
end

local function tooltipAddLine(v,flags)
	if not (tt and tt.key and tt.key==ttName) then return end

	local status;
	if v[mIsMobile] then
		status = (v[mIsAway]==2 and MOBILE_BUSY_ICON) or (v[mIsAway]==1 and MOBILE_AWAY_ICON) or ChatFrame_GetMobileEmbeddedTexture(73/255, 177/255, 73/255)
	else
		status = ("|T%s:0|t"):format(_G["FRIENDS_TEXTURE_"  .. ((v[mIsAway]==1 and "AFK") or (v[mIsAway]==2 and "DND") or "ONLINE")]);
	end

	local line = {
		v[mLevel],
		status .. " " .. C(v[mClassFile],ns.scm(v[mName])) .. ns.showRealmName(name,v[mRealm]),
	};

	if flags.showRace then
		tinsert(line,v[mRaceId] and raceById[v[mRaceId]] and raceById[v[mRaceId]] or ""); -- race
	end
	if flags.showZone then
		local Zone = v[mZone] or "?";
		if v[mIsMobile] and not v[mOnline] then
			Zone=C("cyan",REMOTE_CHAT);
		end
		tinsert(line,Zone); -- zone
	end
	if flags.showNotes then
		tinsert(line,ns.scm(v[mNote])); -- notes
	end
	if flags.showONotes and CanViewOfficerNote() then -- extend if
		tinsert(line,ns.scm(v[mOfficerNote])); -- onotes
	end
	if flags.showRank then
		local rankID="";
		if flags.showRank and flags.showRankID then
			rankID = " "..C("gray","("..v[mRankIndex]..")");
		end
		tinsert(line,C(v[mRankIndex]==0 and "green" or "white",ns.scm(v[mRank]))..rankID); -- rank
	end
	if flags.showProfessions then
		local ts1, ts2 = "","";
		if ns.profile[name].showProfessions and tradeskills[v[mFullName]] then
			if tradeskills[v[mFullName]][1] then
				local t = tradeskills[v[mFullName]][1];
				ts1 = "|T"..t[tsIcon]..":0|t "..t[tsValue];
			end
			if tradeskills[v[mFullName]][2] then
				local t = tradeskills[v[mFullName]][2];
				ts2 = "|T"..t[tsIcon]..":0|t "..t[tsValue];
			end
		end
		tinsert(line,ts1); -- professions 1
		tinsert(line,ts2); -- professions 2
	end

	local l=tt:AddLine(unpack(line));

	if tradeskills[v[mFullName]] and tradeskills[v[mFullName]][1] then
		tt:SetCellScript(l, #line-1, "OnMouseUp", GetMemberRecipes,{name=v[mFullName],id=tradeskills[v[mFullName]][1][4]});
	end

	if tradeskills[v[mFullName]] and tradeskills[v[mFullName]][2] then
		tt:SetCellScript(l, #line, "OnMouseUp", GetMemberRecipes,{name=v[mFullName],id=tradeskills[v[mFullName]][2][4]});
	end

	if v[mFullName]==ns.player.name_realm_short then
		tt:SetLineColor(l, .5, .5, .5);
	end

	tt:SetLineScript(l, "OnMouseUp", memberInviteOrWhisper, v);

	if ns.profile[name].showZoneInTT2 or ns.profile[name].showNotesInTT2 or ns.profile[name].showONotesInTT2 or ns.profile[name].showRankInTT2 or ns.profile[name].showProfessionsInTT2 then
		tt:SetLineScript(l,"OnEnter",createTooltip2,v);
	end
end

local function createTooltip(tt,update)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end

	if (not IsInGuild()) then
		tt:AddHeader(C("dkyellow",GUILD));
		tt:AddSeparator();
		tt:AddLine(C("ltgray",ERR_GUILD_PLAYER_NOT_IN_GUILD));
		ns.roundupTooltip(tt);
		return;
	end

	local l = tt:AddHeader();
	tt:SetCell(l,1,C("dkyellow",GUILD) .. "  " .. C("green",ns.scm(guild[gName])) .. ns.showRealmName(name,guild[gRealm]), nil,"LEFT",ttColumns);

	tt:AddSeparator(4,0,0,0,0);

	local sep=false;
	if (ns.profile[name].showMOTD) then
		local l = tt:AddLine(C("ltblue",MOTD_COLON));
		tt:SetCell(l, 2, C("ltgreen",ns.scm(ns.strWrap(guild[gMotD],56),true)), nil, nil, ttColumns-1)
		sep = true;
	end

	if (ns.profile[name].showRep) then
		local l = tt:AddLine(("%s: "):format(C("ltblue",REPUTATION_ABBR)));
		tt:SetCell(l,2,("%s: (%d/%d)"):format(player[pStandingText], player[pStandingValue]-player[pStandingMin], player[pStandingMax]-player[pStandingMin]), nil, nil, ttColumns - 1);
		sep=true;
	end

	if (sep) then
		tt:AddSeparator(4,0,0,0,0);
	end

	if (ns.profile[name].showApplicants) and type(guild[gNumApplicants])=="number" and (guild[gNumApplicants]>0) then
		local line,column = tt:AddLine(
			C("orange",LEVEL),
			C("orange",L["Applicant"]),
			C("orange",L["Roles"]),
			C("orange",RAID_INSTANCE_EXPIRES_EXPIRED),
			C("orange",COMMENT)
		);
		tt:AddSeparator();
		for i, a in ipairs(applicants) do
			if not (tt and tt.key and tt.key==ttName) then return end -- interupt processing on close tooltip
			local roles = {};
			if a[app_bTank] then table.insert(roles,TANK); end
			if a[app_bHealer] then table.insert(roles,HEALER); end
			if a[app_bDamage] then table.insert(roles,DAMAGER); end

			local l = tt:AddLine(
				a[app_level],
				C(a[app_class], ns.scm(a[app_name])) .. ns.showRealmName(name,a[app_realm]),
				table.concat(roles,", "),
				date("%Y-%m-%d",time()+a[app_timeLeft])
			);
			tt:SetCell(l,5,(strlen(a[app_comment])>0 and ns.scm(ns.strCut(a[app_comment],60)) or L["No Text"]),nil,nil,ttColumns-4);

			tt:SetLineScript(l,"OnMouseUp",showApplication,a[app_index]);
		end
		tt:AddSeparator(4,0,0,0,0);
	end

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
		tinsert(titles,C("ltyellow",LABEL_NOTE));
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

	tt:AddSeparator();

	for i,v in ipairs(members)do
		if not (tt and tt.key and tt.key==ttName) then return end -- interupt processing on close tooltip
		if v[mOnline] and ((not v[mIsMobile]) or (ns.profile[name].showMobileChatter and v[mIsMobile] and not ns.profile[name].splitTables)) then
			tooltipAddLine(v,flags);
		end
	end

	if ns.profile[name].showMobileChatter and ns.profile[name].splitTables and guild[gNumMobile]>0 then
		tt:AddSeparator();
		for i,v in ipairs(members)do
			if not (tt and tt.key and tt.key==ttName) then return end -- interupt processing on close tooltip
			if v[mOnline] and v[mIsMobile] then
				tooltipAddLine(v,flags);
			end
		end
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0);

		if (ns.profile[name].showApplicants) and guild[gNumApplicants] and (guild[gNumApplicants]>0) then
			local l = tt:AddLine();
			tt:SetCell(l,1,C("orange",L["MouseBtn"]).." || "..C("green","Guild applications"),nil,"LEFT",ttColumns);
		end

		if (ttColumns>4) then
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["MouseBtn"]).." || "..C("green",L["Whisper"]) .." - ".. C("ltblue",L["ModKeyA"].."+"..L["MouseBtn"]).." || "..C("green",L["Group invite"]),nil,"LEFT",ttColumns);
		else
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["MouseBtn"]).." || "..C("green",L["Whisper"]),nil,"LEFT",ttColumns);
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["ModKeyA"].."+"..L["MouseBtn"]).." || "..C("green",L["Group invite"]),nil,"LEFT",ttColumns);
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

local function updater()
	if doGuildUpdate then
		doGuildUpdate = false;
		updateGuild();
	end
	if doMembersUpdate then
		doMembersUpdate = false;
		updateMembers();
	end
	if doTradeskillsUpdate then
		updateTradeSkills();
	end
	if doApplicantsUpdate then
		doApplicantsUpdate = false;
		updateApplicants();
	end
	updateBroker();
	if doUpdateTooltip and tt and tt.key and tt.key==ttName and tt:IsShown() then
		doUpdateTooltip = false;
		createTooltip(tt,true);
	end
	updaterLocked = false;
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"PLAYER_GUILD_UPDATE",
	},
	config_defaults = {
		enabled = true,

		-- guild
		showRep = true,
		showMOTD = true,

		-- guild members
		showRealmNames = true,
		showRace = true,		showRaceInTT2 = false,
		showZone = true,		showZoneInTT2 = false,
		showNotes = true,		showNotesInTT2 = false,
		showONotes = true,		showONotesInTT2 = false,
		showRank = true,		showRankInTT2 = false,
		showRankID = false,
		showProfessions = true,	showProfessionsInTT2 = false,

		-- misc
		showApplicants = true,
		showApplicantsBroker = true,
		showMobileChatter = true,
		showMobileChatterBroker = true,
		showTotalMembersBroker = true,
		splitTables = false,
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

ns.ClickOpts.addDefaults(module,{
	guild = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			showApplicantsBroker    = { type="toggle", order=1, name=L["Applicants"], desc=L["Show applicants on broker button"] },
			showMobileChatterBroker = { type="toggle", order=2, name=L["Mobile app user"], desc=L["Show count of mobile chatter on broker button"]},
			showTotalMembersBroker  = { type="toggle", order=3, name=L["Total members count"], desc=L["Show total members count on broker button"] },
		},
		tooltip1 = {
			name = L["Main tooltip options"],
			order = 2,
			showRep           = { type="toggle", order= 1, name=GUILD_REPUTATION, desc=L["Enable/Disable the display of Guild Reputation in tooltip"] },
			showMOTD          = { type="toggle", order= 2, name=L["Guild MotD"], desc=L["Show Guild Message of the Day in tooltip"] },
			showRealmNames    = 3,
			showRace          = { type="toggle", order= 4, name=RACE, desc=L["Show race from guild members in tooltip"]},
			showZone          = { type="toggle", order= 5, name=ZONE, desc=L["Show current zone from guild members in tooltip"]},
			showNotes         = { type="toggle", order= 6, name=L["Notes"], desc=L["Show notes from guild members in tooltip"]},
			showONotes        = { type="toggle", order= 7, name=OFFICER_NOTE_COLON, desc=L["Show officer notes from guild members in tooltip. (This option will be ignored if you have not permission to read the officer notes)"]},
			showRank          = { type="toggle", order= 8, name=RANK, desc=L["Show rank name from guild members in tooltip"]},
			showRankID        = { type="toggle", order= 9, name=RANK.."ID", desc=L["Show rank id from guild members in tooltip"]},
			showProfessions   = { type="toggle", order=10, name=TRADE_SKILLS, desc=L["Show professions from guild members in tooltip"] },
			showApplicants    = { type="toggle", order=11, name=L["Applicants"], desc=L["Show applicants in tooltip"] },
			showMobileChatter = { type="toggle", order=12, name=L["Mobile app user"], desc=L["Show mobile chatter in tooltip (Armory App users)"] },
			splitTables       = { type="toggle", order=13, name=L["Separate mobile app user"], desc=L["Display mobile chatter with own table in tooltip"] },

		},
		tooltip2 = {
			name = L["Secondary tooltip options"],
			order = 3,
			desc                 = { type="description", order=1, name=L["The secondary tooltip will be displayed by moving the mouse over a guild member in main tooltip. The tooltip will be displayed if one of the following options activated."], fontSize="medium"},
			showRaceInTT2        = { type="toggle",      order=2, name=RACE, desc=L["Show race from guild member"]},
			showZoneInTT2        = { type="toggle",      order=2, name=ZONE, desc=L["Show current zone from guild member"]},
			showNotesInTT2       = { type="toggle",      order=3, name=L["Notes"], desc=L["Show notes from guild member"]},
			showONotesInTT2      = { type="toggle",      order=4, name=OFFICER_NOTE_COLON, desc=L["Show officer notes from guild member"]},
			showRankInTT2        = { type="toggle",      order=5, name=RANK, desc=L["Show rank from guild member"]},
			showProfessionsInTT2 = { type="toggle",      order=6, name=TRADE_SKILLS, desc=L["Show professions from guild member"]}
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
	elseif event=="PLAYER_LOGIN" or event=="LF_GUILD_RECRUIT_LIST_CHANGED" then
		RequestGuildApplicantsList();
	elseif event=="CHAT_MSG_SYSTEM" then
		msg = msg:gsub("[\124:%[%]]","#");
		local On,Off = (msg:match(on)),(msg:match(off));
		if On or Off then
			local Name = tostring(On or Off);
			if not Name:find("-") then
				Name = Name .."-".. ns.realm_short;
			end
			if membersName2Index[Name] then
				local i = membersName2Index[Name];
				-- update online status; GUILD_ROSTER_UPDATE/GetGuildRosterInfo trigger too slow real uodates
				members[i][mOnline] = (On~=nil);
				if On then
					-- On/Off post notes of guild members in general chat.
					local t={};
					if ns.profile[name].showMembersNotes then
						local str = strtrim(members[i][mNote]);
						if str:len()>0 then
							tinsert(t,C("ltgray",NOTE_COLON).." "..C("ltblue",str));
						end
					end
					if ns.profile[name].showMembersOffNotes then
						local str = strtrim(members[i][mOfficerNote]);
						if str:len()>0 then
							tinsert(t,C("ltgray",GUILD_OFFICERNOTES_LABEL).." "..C("ltblue",str));
						end
					end
					if #t>0 then
						tinsert(t,1,C("ltgray",LFG_LIST_GUILD_MEMBER)..": "..C(members[i][mClassFile],members[i][mName]));
						ns.print(true,table.concat(t," || "));
					end
				end
			end
			return;
		end
	elseif event=="GUILD_ROSTER_UPDATE" or event=="LF_GUILD_RECRUITS_UPDATED" or event=="BE_DUMMY_EVENT" then
		doGuildUpdate = true;
		doMembersUpdate = true;
	elseif event=="GUILD_TRADESKILL_UPDATE" then
		doTradeskillsUpdate = true;
	end
	if event=="PLAYER_LOGIN" or ns.eventPlayerEnteredWorld then
		if not IsInGuild() then
			wipe(guild);
			wipe(tradeskills);
			wipe(applicants);
			wipe(player);
			wipe(members);
			self:UnregisterEvent("GUILD_RANKS_UPDATE");
			self:UnregisterEvent("GUILD_MOTD");
			self:UnregisterEvent("GUILD_ROSTER_UPDATE");
			self:UnregisterEvent("GUILD_TRADESKILL_UPDATE");
			self:UnregisterEvent("LF_GUILD_RECRUIT_LIST_CHANGED");
			self:UnregisterEvent("LF_GUILD_RECRUITS_UPDATED");
			self:UnregisterEvent("CHAT_MSG_SYSTEM");
		else
			self:RegisterEvent("GUILD_RANKS_UPDATE");
			self:RegisterEvent("GUILD_MOTD");
			self:RegisterEvent("GUILD_ROSTER_UPDATE");
			self:RegisterEvent("GUILD_TRADESKILL_UPDATE");
			self:RegisterEvent("LF_GUILD_RECRUIT_LIST_CHANGED");
			self:RegisterEvent("LF_GUILD_RECRUITS_UPDATED");
			self:RegisterEvent("CHAT_MSG_SYSTEM");
			doGuildUpdate      = true;
			doMembersUpdate    = true;
			doApplicantsUpdate = true;
		end
	end
	if updaterLocked==false and (doGuildUpdate or doMembersUpdate or doTradeskillsUpdate or doApplicantsUpdate or doUpdateTooltip) then
		updaterLocked = true;
		GuildRoster();
		C_Timer.After(0.1570595,updater); -- sometimes blizzard firing GUILD_ROSTER_UPDATE twice.
	end
end

-- function module.onmousewheel(self,direction) end
-- function module.optionspanel(panel) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	local ttAlignings = {"LEFT"};
	ttColumns = 1;

	if IsInGuild() then
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
			tinsert(ttAlignings,"LEFT"); -- professions 1
			tinsert(ttAlignings,"LEFT"); -- professions 2
			flags.showProfessions=true;
		end

		ttColumns = #ttAlignings;
		if ns.profile[name].showApplicants then
			ttColumns = max(ttColumns,5); -- min 5 cols for applicants
		end
	end

	tt = ns.acquireTooltip({ttName, ttColumns,unpack(ttAlignings)},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
