
----------------------------------
-- module independent variables --
----------------------------------
local addon,ns = ...;
local C,L,I=ns.LC.color,ns.L,ns.I;
L["Guild"] = GUILD;


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Guild";
local ldbName, ttName, ttName2,ttColumns,ttColumns2 = name, name.."TT", name.."TT2",9,2;
local tt,tt2,ttParent,createMenu;
local off, on = strtrim(gsub(ERR_FRIEND_OFFLINE_S,"%%s","")), strtrim(gsub(ERR_FRIEND_ONLINE_SS,"\124Hplayer:%%s\124h%[%%s%]\124h",""));
local tradeskillsLockUpdate,tradeskillsLastUpdate,tradeskillsUpdateTimeout = false,0,20;
local guild, player, members, membersName2Index, mobile, tradeskills, applicants = {},{},{},{},{},{},{};
local doMembersUpdate, doTradeskillsUpdate, doApplicantsUpdate, doUpdateTooltip = false,false,false,false;
local gName, gDesc, gRealm, gRealmNoSpacer, gMotD, gNumMembers, gNumMembersOnline, gNumMobile, gNumApplicants = 1,2,3,4,5,6,7,8,9;
local pStanding, pStandingText, pStandingMin, pStandingMax, pStandingValue = 1,2,3,4,5;
local mFullName, mName, mRealm, mRank, mRankIndex, mLevel, mClassLocale, mZone, mNote, mOfficerNote, mOnline, mIsAway, mClassFile, mAchievementPoints, mAchievementRank, mIsMobile, mCanSoR, mStanding, mStandingText,mIsMobileClosed = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20;
local tsName, tsIcon, tsValue, tsID = 1,2,3,4;
local app_index, app_name, app_realm, app_level, app_class, app_bQuest, app_bDungeon, app_bRaid, app_bPvP, app_bRP, app_bWeekdays, app_bWeekends, app_bTank, app_bHealer, app_bDamage, app_comment, app_timeSince, app_timeLeft = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18; -- applicants table entry indexes
local MOBILE_BUSY_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat-BusyMobile:14:14:0:0:16:16:0:16:0:16|t";
local MOBILE_AWAY_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat-AwayMobile:14:14:0:0:16:16:0:16:0:16|t";


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=GetItemIcon(5976),coords={0.05,0.95,0.05,0.95}} --IconName::Guild--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show guild message of the day, your guild reputation, guild members, applicants and mobile app users"],
	events = {
		"PLAYER_ENTERING_WORLD",
		"PLAYER_GUILD_UPDATE",
	},
	updateinterval = 1,
	config_defaults = {
		-- guild
		showRep = true,
		showMOTD = true,

		-- guild members
		showRealmname = true,
		showZone = true,		showZoneInTT2 = false,
		showNotes = true,		showNotesInTT2 = false,
		showONotes = true,		showONotesInTT2 = false,
		showRank = true,		showRankInTT2 = false,
		showProfessions = true,	showProfessionsInTT2 = false,
		
		-- misc
		showApplicants = true,
		showMobileChatter = true,
		showMobileChatterBroker = true,
		splitTables = false,
		showMembersLevelUp = true
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=GUILD, align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showRep",				label=L["Show guild reputation"],		tooltip=L["Enable/Disable the display of Guild Reputation in the Guild data broker tooltip."] },
		{ type="toggle", name="showMOTD",				label=L["Show Guild MotD"],				tooltip=L["Show Guild Message of the Day in tooltip"] },
		{ type="toggle", name="showRealmname",			label=L["Show realm name"],				tooltip=L["Show realm names behind guild and character names. Guilds and characters from connected-realms gets an asterisk behind the names if this option is unchecked."] },
		{ type="toggle", name="showZone",				label=L["Show zone"],					tooltip=L["Show current zone from guild members"]},
		{ type="toggle", name="showNotes",				label=L["Show notes"],					tooltip=L["Show notes from guild members"]},
		{ type="toggle", name="showONotes",				label=L["Show officer notes"],			tooltip=L["Show officer notes from guild members. (This option will be ignored if you have not permission to read the officer notes)"]},
		{ type="toggle", name="showRank",				label=L["Show rank"],					tooltip=L["Show rank name from guild members"]},
		{ type="toggle", name="showProfessions",		label=L["Show professions"],			tooltip=L["Show professions from guild members"], event = true },
		{ type="toggle", name="showApplicants",			label=L["Show applicants"],				tooltip=L["Show applicants in broker and tooltip"], event = true },
		{ type="toggle", name="showMobileChatter",		label=L["Show mobile chatter"],			tooltip=L["Show mobile chatter in tooltip (Armory App users)"] },
		{ type="toggle", name="showMobileChatterBroker",label=L["Show mobile chatter in broker"], tooltip=L["Show count of mobile chatter in broker button"], event = true },
		{ type="toggle", name="splitTables",			label=L["Separate mobile chatter"],		tooltip=L["Display mobile chatter with own table in tooltip"] },
		{ type="toogle", name="showMembersLevelUp",		label=L["Show level ups"],				tooltip=L["Show guild member level up as info message general chat frame. (This is not a gratulation bot!)"]},
		{ type="separator", alpha=0 },
		{ type="header", label=L["Secondary tooltip options"] },
		{ type="separator" },
		{ type="desc",   text=L["The secondary tooltip will be displayed by moving the mouse over a guild member in main tooltip. The tooltip will be displayed if one of the following options activated."]},
		{ type="toggle", name="showZoneInTT2",			label=L["Show zone"],					tooltip=L["Show current zone from guild member"]},
		{ type="toggle", name="showNotesInTT2",			label=L["Show notes"],					tooltip=L["Show notes from guild member"]},
		{ type="toggle", name="showONotesInTT2",		label=L["Show officer notes"],			tooltip=L["Show officer notes from guild member"]},
		{ type="toggle", name="showProfessionsInTT2",	label=L["Show professions"],			tooltip=L["Show professions from guild member"]}
	},
	clickOptions = {
		["1_open_guild"] = {
			cfg_label = "Open guild roster", -- L["Open guild roster"]
			cfg_desc = "open the guild roster", -- L["open the guild roster"]
			cfg_default = "_LEFT",
			hint = "Open guild roster", -- L["Open guild roster"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleGuildFrame")
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self)
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

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
	tmp[gNumMembers], _, tmp[gNumMembersOnline] = GetNumGuildMembers();
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
	local tmp,tmpNames, _ = {},{};
	guild[gNumMobile] = 0;
	for i=1, guild[gNumMembers] do
		local m,old = {};
		m[mFullName], m[mRank], m[mRankIndex], m[mLevel], m[mClassLocale], m[mZone], m[mNote], m[mOfficerNote], m[mOnline], m[mIsAway], m[mClassFile], m[mAchievementPoints], m[mAchievementRank], m[mIsMobile], m[mCanSoR], m[mStanding] = GetGuildRosterInfo(i);
		tmpNames[m[mFullName]]=i;
		m[mName], m[mRealm] = strsplit("-",m[mFullName]);
		m[mStandingText] = _G["FACTION_STANDING_LABEL"..m[mStanding]];
		if m[mIsMobile] then
			if not m[mOnline] then
				m[mIsMobileClosed]=true;
			end
			m[mOnline] = true;
			mobile[m[mName]] = true;
			guild[gNumMobile] = guild[gNumMobile]+1;
		end
		if membersName2Index[m[mFullName]] and members[membersName2Index[m[mFullName]]] then
			old = members[membersName2Index[m[mFullName]]];
			if m[mZone]~=old[mZone] then
				doUpdateTooltip = true;
			end
			if db.showMembersLevelUp and old[mLevel]~=nil and m[mLevel]~=old[mLevel] then
				ns.print( C(m[mClassFile],m[mName]) .." ".. C("green",L["has reached Level %d."]:format(m[mLevel])) );
				doUpdateTooltip = true;
			end
		end
		tinsert(tmp,m);
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
		d = {GetGuildTradeSkillInfo(index)};
		if d[headerName] and d[isCollapsed] then
			if not header[d[headerName]] then
				header[d[headerName]] = {d[iconTexture],d[skillID]};
			end
			tinsert(collapsed,d[skillID]);
			ExpandGuildTradeSkillHeader(d[skillID]);
		end
	end

	-- 2. run...
	local tmp,skillName = {},"";
	local num = GetNumGuildTradeSkill();
	for index=1, num do
		d = {GetGuildTradeSkillInfo(index)};
		if (d[headerName]) then
			skillName = d[headerName];
		elseif (d[playerFullName]) then
			if (tmp[d[playerFullName]]==nil) then
				tmp[d[playerFullName]]={};
			end
			tinsert(
				tmp[d[playerFullName]],
				{
					skillName,
					header[skillName]~=nil and header[skillName][1] or "?",
					d[skill],
					d[skillID]
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
		applicant[app_name], Realm = strsplit("-",applicant[app_name]);
		tinsert(applicant,app_realm,Realm or guild[gRealmNoSpacer]);
		tinsert(temp,applicant);
	end
	applicants = temp;
	if #temp~=guild[gNumApplicants] then
		doApplicantsUpdate = true;
	end
end

local function updateBroker()
	local broker = ns.LDB:GetDataObjectByName(ldbName);
	if guild[gName] then
		local txt = {};
		if (guild[gNumApplicants]>0) then
			tinsert(txt, C("orange",guild[gNumApplicants]));
		end
		if (ns.profile[name].showMobileChatterBroker) then
			tinsert(txt, C("ltblue",guild[gNumMobile]));
		end
		tinsert(txt,C("green",guild[gNumMembersOnline]));
		tinsert(txt,C("green",guild[gNumMembers]));
		broker.text = table.concat(txt,"/");
	else
		broker.text = L["No guild"];
	end
end

local function createTooltip2()
end

local function tooltipAddLine(v,me)
	if not (tt and tt.key and tt.key==ttName) then return end

	local status = ( (v[mIsAway]==1) and C("gold","[AFK] ") ) or ( (v[mIsAway]==2) and C("ltred","[DND] ") ) or "";
	local realm = "";
	if guild[gRealmNoSpacer]~=v[mRealm] then
		if (db.showRealmname) then
			realm = C("white","-")..C("dkyellow", ns.scm(v[mRealm]));
		else
			realm = C("dkyellow","*");
		end
	end
	local ts1, ts2, ts1script, ts2script = "","", false, false;
	if db.showProfessions and tradeskills[v[mFullName]] then
		if tradeskills[v[mFullName]][1] then
			local t = tradeskills[v[mFullName]][1];
			ts1 = "|T"..t[tsIcon]..":0|t "..t[tsValue];
			ts1script = {"OnMouseUp", function(self, button) GetGuildMemberRecipes(v[mFullName],t[tsID]); end}
		end
		if tradeskills[v[mFullName]][2] then
			local t = tradeskills[v[mFullName]][2];
			ts2 = "|T"..t[tsIcon]..":0|t "..t[tsValue];
			ts2script = {"OnMouseUp", function(self, button) GetGuildMemberRecipes(v[mFullName],t[tsID]); end}
		end
	end

	local MobIcon, Zone = "",v[mZone];
	if v[mIsMobile] and not v[mOnline] then
		Zone=C("cyan",REMOTE_CHAT);
	end
	if v[mIsMobile] then
		if v[mIsAway]==2 then
			MobIcon = MOBILE_BUSY_ICON.." ";
		elseif v[mIsAway]==1 then
			MobIcon = MOBILE_AWAY_ICON.." "
		else
			MobIcon = ChatFrame_GetMobileEmbeddedTexture(73/255, 177/255, 73/255).." ";
		end
	end

	local l=tt:AddLine(
		v[mLevel],
		C(v[mClassFile],MobIcon .. ns.scm(v[mName]) .. realm),
		(db.showZone) and Zone or "", -- [3]
		(db.showNotes) and ns.scm(v[mNote]) or "", -- [4]
		(db.showONotes) and ns.scm(v[mOfficerNote]) or "", -- [5]
		(db.showRank) and ns.scm(v[mRank]) or "", -- [6]
		ts1, -- [7]
		ts2 -- [8]
	);

	if ts1script then
		tt:SetCellScript(l, 7, unpack(ts1script));
	end

	if ts2script then
		tt:SetCellScript(l, 8, unpack(ts2script));
	end

	if v[mFullName]==ns.player.name_realm_short then
		tt:SetLineColor(l, .5, .5, .5);
	--elseif ns.friendlist then
	--	if ns.friendlist[v[mFullName]]==1 then
	--		tt:SetLineColor(l, .1, .5, .1);
	--	elseif ns.friendlist[v[mFullName]]==2 then
	--		tt:SetLineColor(l, .1, .3, .7);
	--	end
	end

	-- tt.lines[line].info = {v[mFullName],v[mIsMobile]};
	tt:SetLineScript(l, "OnMouseUp", function(self)
		if (IsAltKeyDown()) then
			if (not v[mIsMobile]) then
				InviteUnit(v[mFullName]);
			end
		else
			SetItemRef("player:"..v[mFullName], ("|Hplayer:%1$s|h[%1$s]|h"):format(v[mFullName]), "LeftButton");
		end
	end);
end

local function createTooltip(self, tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	tt:Clear()

	if (not IsInGuild()) then
		tt:AddHeader(C("dkyellow",GUILD));
		tt:AddSeparator();
		tt:AddLine(C("ltgray",ERR_GUILD_PLAYER_NOT_IN_GUILD));
		ns.roundupTooltip(self, tt);
		return;
	end

	local realm = "";

	if ns.realm~=guild[gRealm] then
		if (db.showRealmname) then
			realm = C("gray"," - ")..C("dkyellow",ns.scm(guild[gRealm]));
		else
			realm = C("dkyellow","*");
		end
	end

	local l = tt:AddHeader();
	tt:SetCell(l,1,C("dkyellow",GUILD) .. "  " .. C("green",ns.scm(guild[gName])) .. realm, nil,"LEFT",ttColumns);

	tt:AddSeparator(4,0,0,0,0);

	local sep=false;
	if (db.showMOTD) then
		local l = tt:AddLine(C("ltblue",MOTD_COLON));
		tt:SetCell(l, 2, C("ltgreen",ns.scm(ns.strWrap(guild[gMotD],56),true)), nil, nil, ttColumns-1)
		sep = true;
	end

	if (db.showRep) then
		local l = tt:AddLine(("%s: "):format(C("ltblue",REPUTATION_ABBR)));
		tt:SetCell(l,2,("%s: (%d/%d)"):format(player[pStandingText], player[pStandingValue]-player[pStandingMin], player[pStandingMax]-player[pStandingMin]), nil, nil, ttColumns - 1);
		sep=true;
	end

	if (sep) then
		tt:AddSeparator(4,0,0,0,0);
	end

	if (db.showApplicants) and (guild[gNumApplicants]>0) then

		local line,column = tt:AddLine(C("orange",LEVEL),C("orange",L["Applicant"]),C("orange",L["Roles"]),C("orange",RAID_INSTANCE_EXPIRES_EXPIRED),C("orange",COMMENT));
		tt:AddSeparator();

		for i, a in ipairs(applicants) do
			if not (tt and tt.key and tt.key==ttName) then return end -- interupt processing on close tooltip
			local realm = "";
			if guild[gRealmNoSpacer]~=a[app_realm] then
				if (db.showRealmname) then
					realm = C("white","-")..C("dkyellow", ns.scm(a[app_realm]));
				else
					realm = C("dkyellow","*");
				end
			end

			local roles = {};
			if a[app_bTank] then table.insert(roles,TANK); end
			if a[app_bHealer] then table.insert(roles,HEALER); end
			if a[app_bDamage] then table.insert(roles,DAMAGER); end

			local l = tt:AddLine(
				a[app_level],
				C(a[app_class], ns.scm(a[app_name])) .. realm,
				table.concat(roles,", "),
				date("%Y-%m-%d",time()+a[app_timeLeft])
			);
			tt:SetCell(l,5,(strlen(a[app_comment])>0 and ns.scm(ns.strCut(a[app_comment],60)) or L["No Text"]),nil,nil,ttColumns-4);

			tt.lines[l].appIndex=a[app_index];
			tt:SetLineScript(l,"OnMouseUp",function(self)
				if (IsInGuild()) then
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
					SetGuildApplicantSelection(self.appIndex);
					GuildInfoFrameApplicants_Update();
				end
			end)
		end
		tt:AddSeparator(4,0,0,0,0);
	end

	local l=tt:AddLine(
		C("ltyellow",LEVEL), -- [1]
		C("ltyellow",CHARACTER), -- [2]
		(db.showZone) and C("ltyellow",ZONE) or "", -- [3]
		(db.showNotes) and C("ltyellow",L["Notes"]) or "", -- [4]
		(displayOfficerNotes and db.showONotes) and C("ltyellow",OFFICER_NOTE_COLON) or "", -- [5]
		(db.showRank) and C("ltyellow",RANK) or "" -- [6]
	);

	if db.showProfessions then
		tt:SetCell(l, 7,C("ltyellow",TRADE_SKILLS), nil,nil,2); -- [7,8]
	end

	tt:AddSeparator();

	-- table.sort(members,function() end); -- idea for later maybe ^_^
	for i,v in ipairs(members)do
		if not (tt and tt.key and tt.key==ttName) then return end -- interupt processing on close tooltip
		if v[mOnline] and ((not v[mIsMobile]) or (db.showMobileChatter and v[mIsMobile] and not db.splitTables)) then
			tooltipAddLine(v);
		end
	end

	if db.showMobileChatter and db.splitTables and guild[gNumMobile]>0 then
		--tt:AddSeparator(4,0,0,0,0);
		tt:AddSeparator();
		for i,v in ipairs(members)do
			if not (tt and tt.key and tt.key==ttName) then return end -- interupt processing on close tooltip
			if v[mOnline] and v[mIsMobile] then
				tooltipAddLine(v);
			end
		end
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0);

		if (db.showApplicants) and (guild[gNumApplicants]>0) then
			local l = tt:AddLine();
			tt:SetCell(l,1,C("orange",L["Click"]).." || "..C("green","Open guild applications"),nil,"LEFT",ttColumns);
		end

		if (ttColumns>4) then
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["Click"]).." || "..C("green",L["Whisper with a member"]) .." - ".. C("ltblue",L["Alt+Click"]).." || "..C("green",L["Invite a member"]),nil,"LEFT",ttColumns);
		else
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["Click"]).." || "..C("green",L["Whisper with a member"]),nil,"LEFT",ttColumns);
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["Alt+Click"]).." || "..C("green",L["Invite a member"]),nil,"LEFT",ttColumns);
		end

		if (ns.modules[name].clickHints) then
			local steps,t1,t2=1,{},{};
			if (ttColumns>4) then
				steps=2;
			end
			for i=1, #ns.modules[name].clickHints, steps do
				if (ttColumns>4) then
					t2 = {};
					if (ns.modules[name].clickHints[i]) then tinsert(t2,ns.modules[name].clickHints[i]); end
					if (ns.modules[name].clickHints[i+1]) then tinsert(t2,ns.modules[name].clickHints[i+1]); end
					tinsert(t1,table.concat(t2," - "));
				else
					if (ns.modules[name].clickHints[i]) then
						tinsert(t1,ns.modules[name].clickHints[i]);
					end
				end
			end
			for i,v in ipairs(t1) do
				line, column = tt:AddLine();
				tt:SetCell(line,1,v,nil,"LEFT",ttColumns);
			end
		end
	end

	tt:AddSeparator(1,0,0,0,0);
	--tt:UpdateScrolling(GetScreenHeight() * (ns.profile.GeneralOptions.maxTooltipHeight/100));
	ns.roundupTooltip(self, tt);
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
	db = ns.profile[name];
end

ns.modules[name].onevent = function(self,event,msg,...)
	if event=="PLAYER_ENTERING_WORLD" or event=="LF_GUILD_RECRUIT_LIST_CHANGED" then
		RequestGuildApplicantsList();
	end
	if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_GUILD_UPDATE" then
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
			doGuildUpdate     = true;
			doMembersUpdate    = true;
			doApplicantsUpdate = true;
		end
		self:UnregisterEvent("PLAYER_ENTERING_WORLD");
	elseif event=="GUILD_ROSTER_UPDATE" or event=="LF_GUILD_RECRUITS_UPDATED" or event=="BE_DUMMY_EVENT" or (event=="CHAT_MSG_SYSTEM" and (msg:find(off) or msg:find(on))) then
		doGuildUpdate = true;
		doMembersUpdate = true;
	elseif event=="GUILD_TRADESKILL_UPDATE" then
		doTradeskillsUpdate = true;
	elseif event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	end
end

ns.modules[name].onupdate = function(self)
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
		createTooltip(ttParent, tt);
	end
--	if (IsInGuild()) then 
--		RequestGuildApplicantsList();
--		GuildRoster();
--	end
end

-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].optionspanel = function(panel) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	local ttAlignings = {"LEFT"};
	if IsInGuild() then
		displayOfficerNotes = CanViewOfficerNote();
		ttAlignings = {
			"RIGHT", -- level
			"LEFT" -- name
		};
		--if (ns.profile[name].showZone) then
			tinsert(ttAlignings,"CENTER"); -- zone
		--end
		--if (ns.profile[name].showNotes) then
			tinsert(ttAlignings,"LEFT"); -- notes
		--end
		--if (displayOfficerNotes) and (ns.profile[name].showONotes) then
			tinsert(ttAlignings,"LEFT"); -- onotes
		--end
		--if (ns.profile[name].showRank) then
			tinsert(ttAlignings,"LEFT"); -- rank
		--end
		--if (ns.profile[name].showProfessions) then
			tinsert(ttAlignings,"LEFT"); -- professions 1
			tinsert(ttAlignings,"LEFT"); -- professions 2
		--end
	end

	ttColumns = #ttAlignings;

	tt = ns.LQT:Acquire(ttName, ttColumns,unpack(ttAlignings));
	ttParent = self;
	createTooltip(self, tt);
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

