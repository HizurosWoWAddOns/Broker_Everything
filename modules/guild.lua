
----------------------------------
-- module independent variables --
----------------------------------
local addon,ns = ...;
local C,L,I=ns.LC.color,ns.L,ns.I;


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Guild"; -- L["Guild"]
local ldbName, ttName,ttName2 = name, name.."TT", name.."TT2";
local tt,tt2,guildRealm,createMenu;
local ttColumns,db;
local guildUpdateFreq = 300;
local displayProfessions, displayOfficerNotes = false, false;
local off, on = strtrim(gsub(ERR_FRIEND_OFFLINE_S,"%%s","")), strtrim(gsub(ERR_FRIEND_ONLINE_SS,"\124Hplayer:%%s\124h%[%%s%]\124h",""));
local Skills, SkillMembers, SkillsUpdateLock={},{},false;


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=GetItemIcon(5976),coords={0.05,0.95,0.05,0.95}} --IconName::Guild--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show guild information. Guild members currently online, MOTD, guild xp etc."];
ns.modules[name] = {
	desc = desc,
	events = {
		"PLAYER_LOGIN",
		"GUILD_ROSTER_UPDATE",
		"PLAYER_ENTERING_WORLD",
		"CHAT_MSG_SYSTEM",
		"LF_GUILD_RECRUITS_UPDATED",
		"GUILD_TRADESKILL_UPDATE",
		"GUILD_RECIPE_KNOWN_BY_MEMBERS"
	},
	updateinterval = 30,
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
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
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
			cfg_label = "Open option menu", -- L[""]
			cfg_desc = "open the option menu", -- L[""]
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

local function GetGuildChallengesState()
	local numChallenges = GetNumGuildChallenges();
	local names = {"dungeons","szenarios","challenge mode dungeons","raids","rated battlegrounds"}
	local xp_overlimit = {120000,0,0,0,0,0}
	local result = {}
	for i = 1, numChallenges do
		local index, current, max, xp = GetGuildChallengeInfo(i);
		result[index] = {L[names[index]],max-current,xp,xp_overlimit[index]}
	end
	return result
end

local function Tradeskills_Collector()
	if (SkillsUpdateLock) then return; end

	local skillID,isCollapsed,iconTexture,headerName,numOnline,numVisible,numPlayers,playerName,playerFullName,class,online,zone,skill,classFileName,isMobile,isAway = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16; -- GetGuildTradeSkillInfo
	local collapsedIds,d={};

	wipe(Skills);
	wipe(SkillMembers);

	-- 1. run...
	for index=GetNumGuildTradeSkill(), 1, -1 do
		d = {GetGuildTradeSkillInfo(index)};
		if (d[headerName]) then
			Skills[d[skillID]] = {
				icon     = d[iconTexture],
				name     = d[headerName],
				nOnline  = d[numOnline],
				nVisible = d[numVisible],
				nChars   = d[numPlayers]
			};
			if (d[isCollapsed]) then
				tinsert(collapsedIds,d[skillID]);
				ExpandGuildTradeSkillHeader(d[skillID]);
			end
		end
	end

	-- 2. run...
	local skillName = "";
	for index=1, GetNumGuildTradeSkill() do
		d = {GetGuildTradeSkillInfo(index)};
		if (d[headerName]) then
			skillName = d[headerName];
		elseif (d[playerFullName]) then
			if (SkillMembers[d[playerFullName]]==nil) then
				SkillMembers[d[playerFullName]]={};
			end
			table.insert(SkillMembers[d[playerFullName]],{
				id    = d[skillID],
				icon  = Skills[d[skillID]].icon,
				name  = skillName,
				level = d[skill]
			});
		end
	end

	-- 3. run... collapse prev. expanded skills
	for _,id in ipairs(collapsedIds) do
		CollapseGuildTradeSkillHeader(id);
	end

	SkillsUpdateLock = true;
end

local function guildMemberTooltip(self)
	if (self~=false) then
		local fullName,rank,rankIndex,level,class,zone,note,officernote,online,isAway,classFileName,achievementPoints,achievementRank,isMobile,canSoR,repStanding = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16; -- GetGuildRosterInfo
		local tt2=GameTooltip;
		tt2:SetOwner(self,"ANCHOR_NONE");
		if (select(1,self:GetCenter()) > (select(1,UIParent:GetWidth()) / 2)) then
			tt2:SetPoint("RIGHT",tt,"LEFT",-2,0);
		else
			tt2:SetPoint("LEFT",tt,"RIGHT",2,0);
		end
		tt2:SetPoint("TOP",self,"TOP", 0, 4);

		tt2:ClearLines();
		tt2:AddLine(strsplit("-",self.info[fullName])); -- name
		if (db.showZoneInTT2) then
			tt2:AddDoubleLine(C("ltblue",L["Zone"]),C("white",self.info[zone]));
		end
		if (db.showNotesInTT2) then
			tt2:AddDoubleLine(C("ltblue",L["Notes"]),C("white",self.info[note]));
		end
		if (db.showONotesInTT2) and (displayOfficerNotes) then
			local on = strtrim(self.info[officernote]);
			if (strlen(on)==0) then
				on=L["<<empty>>"];
			end
			tt2:AddDoubleLine(C("ltblue",L["Officer notes"]),C("white",on));
		end
		if (db.showRankInTT2) then
			tt2:AddDoubleLine(C("ltblue",L["Rank"]),C("white",self.info[rank]));
		end
		if (db.showProfessionsInTT2) then
			local profs={};
			if (SkillMembers[self.info[fullName]]) and (#SkillMembers[self.info[fullName]]>0) then
				for k,v in ipairs(SkillMembers[self.info[fullName]]) do
					tt2:AddDoubleLine(C("ltblue",L["Professions"].." "..k),C("white",("|T%s:0|t %s (%d)"):format(v.icon,v.name,v.level)));
				end
			else
				tt2:AddDoubleLine(C("ltblue",L["Professions"]),C("white",L["unlearned"]));
			end
		end
		tt2:Show();
	else
		GameTooltip:Hide();
	end
	
end

local function guildTooltip()
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	tt:Clear()

	if (not IsInGuild()) then
		tt:AddHeader(L[name]);
		tt:AddSeparator();
		tt:AddLine(L["No Guild"]);
		return;
	end

	local currentXP, nextLevelXP, dailyXP, maxDailyXP, unitWeeklyXP, unitTotalXP, maxXP, line, column, factionStandingtext, guildName, guildLevel, gMOTD, description, standingID, barMin, barMax, barValue,guildRealm, showGuildRealm, _

	guildName, description, standingID, barMin, barMax, barValue = GetGuildFactionInfo();
	factionStandingtext = GetText("FACTION_STANDING_LABEL"..standingID);
	guildName,_,_,guildRealm = GetGuildInfo("player");
	if (not guildRealm) then
		showGuildRealm = "";
		guildRealm = gsub(ns.realm," ","");
		if (db.showRealmname) then
			showGuildRealm = C("gray"," - ")..C("dkyellow", ns.scm(guildRealm));
		end
	elseif (db.showRealmname) then
		showGuildRealm = C("gray"," - ")..C("dkyellow",ns.scm(guildRealm) or "*");
	else
		showGuildRealm = C("dkyellow","*");
	end

	line, column = tt:AddHeader();
	if (ns.build<60000000) then
		guildLevel = GetGuildLevel();
		currentXP, nextLevelXP, dailyXP, maxDailyXP, unitWeeklyXP, unitTotalXP = UnitGetGuildXP("player");
		maxXP = currentXP + nextLevelXP;
		tt:SetCell(line,1,C("dkyellow",L[name]) .. "  " .. C("green",("%s / Lvl: %d / XP: %.2f%%"):format(ns.scm(guildName) .. showGuildRealm ,guildLevel,(currentXP / (maxXP / 100) ))),nil,"LEFT",ttColumns)
	else
		tt:SetCell(line,1,C("dkyellow",L[name]) .. "  " .. C("green",ns.scm(guildName)) .. showGuildRealm, nil,"LEFT",ttColumns)
	end

	tt:AddSeparator(4,0,0,0,0);

	local sep=false;
	if (db.showMOTD) then
		gMOTD = GetGuildRosterMOTD();
		if (gMOTD:len() > 100) then
			gMOTD = ns.splitTextToHalf(gMOTD," ");
		end

		line, column = tt:AddLine(C("ltblue",L["MotD:"]));
		tt:SetCell(line, 2, C("ltgreen",ns.scm(gMOTD,true)), nil, nil, ttColumns-1)
		sep = true;
	end

	if (ns.build<60000000) and (db.showXP) then
		line, column = tt:AddLine(("%s: "):format(C("ltblue",L["XP"])));
		if (guildLevel<25) then
			tt:SetCell(line, 2, ("%s/%s (%s)"):format(currentXP, maxXP,nextLevelXP),nil, nil, ttColumns - 1);
		else
			tt:SetCell(line, 2, ("%s/%s"):format(currentXP, maxXP),nil, nil, ttColumns - 1);
		end
		sep = true;
	end

	if (db.showRep) then
		line, column = tt:AddLine(("%s: "):format(C("ltblue",L["Rep"])));
		tt:SetCell(line, 2, ("%s: (%d/%d)"):format(factionStandingtext, barValue-barMin, barMax-barMin), nil, nil, ttColumns - 1);
		sep=true;
	end


	if (sep) then
		tt:AddSeparator(4,0,0,0,0);
	end

	-- applicants
	local numApplicants = GetNumGuildApplicants()
	if (db.showApplicants) and (numApplicants>0) then
		line,column = tt:AddLine(C("orange",L["Level"]),C("orange",L["Applicant"]),C("orange",L["Roles"]),C("orange",L["Expired"]),C("orange",L["Comment"]));
		tt:AddSeparator()

		for index=1, numApplicants do
			local aName, level, class, bQuest, bDungeon, bRaid, bPvP, bRP, bWeekdays, bWeekends, bTank, bHealer, bDamage, comment, timeSince, timeLeft = GetGuildApplicantInfo(index);
			local roles = {}

			local realm,cross = "",false;
			if (aName:find("-")) then
				aName, realm = strsplit("-",aName);
				cross=true;
			end
			if (db.showRealmname) then
				realm = C("gray"," - ")..C("dkyellow", (realm:len()>0) and realm or gsub(ns.realm," ",""));
			elseif (cross) then
				realm = C("dkyellow","*");
			end

			if (bTank) then table.insert(roles,L["Tank"]); end
			if (bHealer) then table.insert(roles,L["Healer"]); end
			if (bDamage) then table.insert(roles,L["Damage"]); end
			line,column=tt:AddLine(level, C(class,aName) .. realm, table.concat(roles,", "), date("%Y-%m-%d",time()+timeLeft));
			tt:SetCell(line,5,(strlen(comment)>0 and ns.strLimit(comment,60) or L["No Text"]),nil,nil,ttColumns-4);

			tt.lines[line].appIndex=index;
			tt:SetLineScript(line,"OnMouseUp",function(self)
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

	-- roster title
	local cells = {
		C("ltyellow",L["Level"]),
		C("ltyellow",L["Character"]),
	};
	if (db.showZone) then
		tinsert(cells,C("ltyellow",L["Zone"]));
	end
	if (db.showNotes) then
		tinsert(cells,C("ltyellow",L["Notes"]));
	end
	if (displayOfficerNotes) and (db.showONotes) then 
		tinsert(cells,C("ltyellow",L["Officer notes"]));
	end
	if (db.showRank) then
		tinsert(cells,C("ltyellow",L["Rank"]));
	end
	local l,c = tt:AddLine(unpack(cells));
	if (db.showProfessions) then
		tt:SetCell(l, #cells+1, C("ltyellow",L["Professions"]), nil, nil, 2);
	end

	tt:AddSeparator()

	Tradeskills_Collector();

	local fullName,rank,rankIndex,level,class,zone,note,officernote,online,isAway,classFileName,achievementPoints,achievementRank,isMobile,canSoR,repStanding = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16; -- GetGuildRosterInfo

	local add = function(info)
		local charname,realm = strsplit("-",info[fullName]);
		local status = ((info[isAway]==1) and C("gold","[AFK] ")) or ((info[isAway]==2) and C("ltred","[DND] ")) or "";
		local cellScripts = {};

		if (db.showRealmname) then
			realm = C("gray"," - ")..C("dkyellow",ns.scm(realm));
		else
			if (realm~=guildRealm) then
				realm = C("dkyellow","*");
			else
				realm = "";
			end
		end

		local cells = {
			info[level],	-- level
			status .. C(info[classFileName],ns.scm(charname)) .. realm,				-- name
		};

		if (db.showZone) then
			tinsert(cells,((info[isMobile]) and C("ltblue",L["MobileChat"])) or info[zone] or ""); -- zone
		end

		if (db.showNotes) then
			local _note = "";
			if (info[note]) then _note = ns.scm(info[note],true); end
			tinsert(cells,_note);	-- notes
		end

		if (displayOfficerNotes) and (db.showONotes) then
			local _onote = "";
			if (info[officernote]) then _onote = ns.scm(info[officernote]); end
			tinsert(cells,_onote); -- officernotes
		end

		if (db.showRank) then
			local rankColor = "white";
			if (ns.player.name==charname) then  rankColor = "gray"; end
			tinsert(cells,C(rankColor,ns.scm(info[rank],true))); -- rank
		end

		if (db.showProfessions) then -- professions
			if (SkillMembers[info[fullName]]) then
				for k,v in ipairs(SkillMembers[info[fullName]]) do
					tinsert(cells,"|T"..v.icon..":0|t "..v.level);
					cellScripts[#cells] = {"OnMouseUp", function(self, button) GetGuildMemberRecipes(info[fullName],v.id); end};
					cellScripts.set=true;
				end
			end
		end

		local line, column = tt:AddLine(unpack(cells));
		tt.lines[line].info=info;

		if (cellScripts.set) then
			for i,v in pairs(cellScripts) do
				if (i~="set") then
					tt:SetCellScript(line,i,unpack(v));
				end
			end
		end

		if (db.showZoneInTT2) or (db.showNotesInTT2) or (db.showONotesInTT2 and displayOfficerNotes) or (db.showRankInTT2) or (db.showProfessionsInTT2) then
			tt:SetLineScript(line,"OnEnter",function(self) guildMemberTooltip(self) end);
			tt:SetLineScript(line,"OnLeave",function(self) guildMemberTooltip(false) end);
		end

		tt:SetLineScript(line, "OnMouseUp", function(self)
			if (IsAltKeyDown()) then
				if (self.info[isMobile]) then return; end
				InviteUnit(info[fullName]);
			else
				SetItemRef("player:"..info[fullName], "|Hplayer:"..info[fullName].."|h["..info[fullName].."|h", "LeftButton");
			end
		end);
	end

	local Armory = {};
	for i=1, GetNumGuildMembers(true) do
		local d = {GetGuildRosterInfo(i)};
		if (d[online]) and (not d[isMobile]) then
			add(d);
		elseif (d[isMobile]) then
			tinsert(Armory,d);
		end
	end

	if (db.showMobileChatter) and (#Armory>0) then
		if (db.splitTables) then
			tt:AddSeparator(3,0,0,0,0);
			line,column = tt:AddLine();
			tt:SetCell(line, 1, C("ltyellow",L["MobileChat"]), nil, "LEFT", ttColumns)
			tt:AddSeparator()
		end

		for i,v in ipairs(Armory) do
			add(v);
		end
	end

	if (Broker_EverythingDB.showHints) then
		tt:AddSeparator(4,0,0,0,0);

		if (db.showApplicants) and (numApplicants>0) then
			line, column = tt:AddLine();
			tt:SetCell(line,1,C("orange",L["Click"]).." || "..C("green","Open guild applications"),nil,"LEFT",ttColumns);
		end

		if (ttColumns>4) then
			line, column = tt:AddLine();
			tt:SetCell(line,1,C("ltblue",L["Click"]).." || "..C("green",L["Whisper with a member"]) .." - ".. C("ltblue",L["Alt+Click"]).." || "..C("green",L["Invite a member"]),nil,"LEFT",ttColumns);
		else
			line, column = tt:AddLine();
			tt:SetCell(line,1,C("ltblue",L["Click"]).." || "..C("green",L["Whisper with a member"]),nil,"LEFT",ttColumns);
			line, column = tt:AddLine();
			tt:SetCell(line,1,C("ltblue",L["Alt+Click"]).." || "..C("green",L["Invite a member"]),nil,"LEFT",ttColumns);
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
	tt:UpdateScrolling(GetScreenHeight() * (Broker_EverythingDB.maxTooltipHeight/100));
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	db = Broker_EverythingDB[name];
end

ns.modules[name].onevent = function(self,event,msg)
	local dataobj = (self) and self.obj or ns.LDB:GetDataObjectByName(ldbName);

	if (not IsInGuild()) then
		dataobj.text = L["No Guild"];
		return;
	end

	if (event=="PLAYER_LOGIN") or (event=="PLAYER_ENTERING_WORLD") then
		ns.modules[name].onupdate();
	end

	if (event=="GUILD_ROSTER_UPDATE") or (event=="LF_GUILD_RECRUITS_UPDATED") or (event=="BE_DUMMY_EVENT") or (event=="CHAT_MSG_SYSTEM" and (msg:find(off) or msg:find(on))) then
		local totalGuildMembers, membersOnline = GetNumGuildMembers();
		local numApplicants = (Broker_EverythingDB[name].showApplicants) and GetNumGuildApplicants() or 0;

		local currentXP, nextLevelXP, dailyXP, maxDailyXP, unitWeeklyXP, unitTotalXP, maxXP, guildLevel;
		local txt,txt2 = {},{};

		if (numApplicants>0) then
			tinsert(txt2, C("orange",numApplicants));
		end
		if (Broker_EverythingDB[name].showMobileChatterBroker) then
			local numMobile = 0;
			for i=1, GetNumGuildMembers(true) do
				local d = {GetGuildRosterInfo(i)};
				if (d[14]) then
					numMobile = numMobile + 1;
				end
			end
			tinsert(txt2, C("ltblue",numMobile));
		end
		tinsert(txt2,C("green",membersOnline));
		tinsert(txt2,C("green",totalGuildMembers));
		tinsert(txt,table.concat(txt2,"/"));

		if not (ns.build>=60000000) and (Broker_EverythingDB[name].showLvlXPbroker) then
			currentXP, nextLevelXP, dailyXP, maxDailyXP, unitWeeklyXP, unitTotalXP = UnitGetGuildXP("player");
			maxXP = currentXP + nextLevelXP
			guildLevel = GetGuildLevel()
			if (guildLevel<25) then
				tinsert(C("green",GetGuildLevel()) .. "/" .. C("green",("%.2f%%"):format( currentXP/(maxXP/100) )));
			end
		end
		dataobj.text = table.concat(txt," ");
	end

	if (event=="GUILD_TRADESKILL_UPDATE") or (event=="GUILD_RECIPE_KNOWN_BY_MEMBERS") then
		SkillsUpdateLock = false;
	elseif (tt) and (tt.key) and (tt.key==ttName) and (tt:IsShown()) then
		guildTooltip();
	end

	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end
end

ns.modules[name].onupdate = function(self)
	if (IsInGuild()) then 
		RequestGuildApplicantsList();
		GuildRoster();
		if (ns.build<60000000) then
			QueryGuildXP();
		end
	end
end

-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].optionspanel = function(panel) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	displayOfficerNotes = CanViewOfficerNote();
	local ttData = {
		"RIGHT", -- level
		"LEFT" -- name
	};
	if (Broker_EverythingDB[name].showZone) then
		tinsert(ttData,"CENTER"); -- zone
	end
	if (Broker_EverythingDB[name].showNotes) then
		tinsert(ttData,"LEFT"); -- notes
	end
	if (displayOfficerNotes) and (Broker_EverythingDB[name].showONotes) then
		tinsert(ttData,"LEFT"); -- onotes
	end
	if (Broker_EverythingDB[name].showRank) then
		tinsert(ttData,"LEFT"); -- rank
	end
	if (Broker_EverythingDB[name].showProfessions) then
		tinsert(ttData,"LEFT"); -- professions 1
		tinsert(ttData,"LEFT"); -- professions 2
	end

	ttColumns = #ttData;

	tt = ns.LQT:Acquire(ttName, ttColumns,unpack(ttData));
	ns.createTooltip(self,tt);
	guildTooltip(self);
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

