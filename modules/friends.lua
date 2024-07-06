
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Friends"; -- FRIENDS L["ModDesc-Friends"]
local ttName,ttName2,ttColumns,tt,tt2,module = name.."TT",name.."TT2",8;

local D4icon = "Interface/AddOns/Broker_Everything/media/Battlenet-D4icon.tga";
local GetClientInfo = setmetatable({
	-- Blizzard
	ANBS = {icon=4557783, short="DI",      long="Diablo Immortal"},
	App  = {icon=796351,  short="Desktop", long="Desktop App"},
	BSAp = {icon=796351,  short="Mobile",  long="Mobile App"},
	CLNT = {icon=796351,  short=nil,       long=nil},
	D3   = {icon=536090,  short="D3",      long="Diablo 3"},
	Fen  = {icon=D4icon,  short="D4",      long="Diablo 4"},
	GRY  = {icon=4553312, short="Arclight",long="Warcraft Arclight Rumble"},
	Hero = {icon=1087463, short="HotS",    long="Heroes of the Storm"},
	OSI  = {icon=4034244, short="D2",      long="Diablo II Resurrected"},
	Pro  = {icon=1313858, short="OW",      long="Overwatch"},
	RTRO = {icon=4034242, short="Arcade",  long="Blizzard Arcade Collection"},
	S1   = {icon=1669008, short="SC1",     long="Starcraft"},
	S2   = {icon=374211,  short="SC2",     long="Starcraft 2"},
	W3   = {icon=3257659, short="WC3",     long="Warcraft 3 Reforged"},
	WoW  = {icon=374212,  short="WoW",     long="World of Warcraft"},
	WTCG = {icon=374211,  short="HS",      long="Hearthstone"},

	-- Activision
	WLBY = {icon=4034243, short="CB4",     long="Crash Bandicoot 4"},
	DST2 = {icon=1711629, short="DST2",    long="Destiny 2"},
	VIPR = {icon=2204215, short="BO4",     long="Call Of Duty: Black Ops 4"},
	FORE = {icon=4256535, short="CoDV",    long="Call Of Duty: Vanguard"},
	LAZR = {icon=3581732, short="MW2",     long="Call Of Duty: Modern Warfare 2"},
	ODIN = {icon=3257658, short="MW",      long="Call Of Duty: Modern Warfare"},
	ZEUS = {icon=3920823, short="BOCW",    long="Call Of Duty: Black Ops Cold War"},

},{
	__call = function(t,name)
		local v = rawget(t,name)
		if not v then
			v = {icon=134400,short=name,long=name}
			ns.print("Game name '"..name.."' not known. Please report the addon author.");
			rawset(t,name,v)
		elseif not (v.icon and v.short and v.long and v.iconStr) then
			v.icon = v.icon or 134400;
			v.short = v.short or name;
			v.long = v.long or name;
			v.iconStr = "|T"..v.icon..":0:0:0:0:32:32:5:27:5:27|t";
		end
		if not v.type then
			v.type = v.icon==796351 and "App" or GAME;
		end
		return v;
	end
})

-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Addons\\"..addon.."\\media\\friends"}; --IconName::Friends--


-- some local functions --
--------------------------
local function _status(afk,dnd)
	if ns.profile[name].showStatus=="1" then
		return ("|T%s:0|t"):format(_G["FRIENDS_TEXTURE_"  .. ((afk==true and "AFK") or (dnd==true and "DND") or "ONLINE")]);
	elseif ns.profile[name].showStatus=="2" then
		return (afk==true and C("gold","[AFK]")) or (dnd==true and C("ltred","[DND]")) or "";
	end
	return "";
end

local function updateBroker()
	local dataobj = ns.LDB:GetDataObjectByName(module.ldbName);
	local numBNFriends, numOnlineBNFriends = 0,0;
	if BNConnected() then
		numBNFriends, numOnlineBNFriends = BNGetNumFriends();
	end
	local numFriends = C_FriendList.GetNumFriends();
	local friendsOnline = C_FriendList.GetNumOnlineFriends();
	if not (tonumber(numOnlineBNFriends) and tonumber(friendsOnline)) then return end

	if ns.profile[name].splitFriendsBroker then
		local friends = tostring(friendsOnline);
		local bnfriends = tostring(numOnlineBNFriends);
		if ns.profile[name].showTotalCount then
			friends = friends.."/"..numFriends;
			bnfriends = bnfriends.."/"..numBNFriends;
		end
		dataobj.text = friends .." ".. C(BNConnected() and "ltblue" or "red",bnfriends);
	else
		local txt = tostring(numOnlineBNFriends + friendsOnline);
		if ns.profile[name].showTotalCount then
			txt = txt .."/".. (numBNFriends + numFriends);
		end
		dataobj.text = txt .. (BNConnected()==false and "("..C("red","BNet Off")..")" or "");
	end

	local broadcastText = select(4,BNGetInfo());
	if (broadcastText) and (strlen(broadcastText)>0) then
		dataobj.text=dataobj.text.." |Tinterface\\chatframe\\ui-chatinput-focusicon:0|t";
	end
end

local function createTooltip2(self,data)
	if not (ns.profile[name].showBroadcastTT2 or ns.profile[name].showBattleTagTT2 or ns.profile[name].showRealIDTT2 or ns.profile[name].showZoneTT2 or ns.profile[name].showGameTT2 or ns.profile[name].showNotesTT2) then return end
	local color1 = "ltblue";
	tt2 = ns.acquireTooltip(
		{ttName2, 3, "LEFT","RIGHT","RIGHT"},
		{true,true},
		{self, "horizontal", tt}
	);
	if tt2.lines~=nil then tt2:Clear(); end
	local l=tt2:AddHeader(C("dkyellow",NAME));
	tt2:SetCell(l,2,C(data.className or color1,ns.scm(data.name)),nil,nil,0);
	tt2:AddSeparator();
	-- game
	if ns.profile[name].showGameTT2 then
		local info = GetClientInfo(data.client);
		tt2:SetCell(tt2:AddLine(C(color1,info.type)),2,info.long .." ".. info.iconStr,nil,"RIGHT",0);
	end
	if data.client=="WoW" then
		-- realm
		if (data.realm) then
			tt2:SetCell(tt2:AddLine(C(color1,L["Realm"])),2,ns.scm(data.realm),nil,"RIGHT",0);
		end
		-- faction
		if ns.profile[name].showFactionTT2 then
			tt2:SetCell(tt2:AddLine(C(color1,FACTION)),2, data.factionL .. " |TInterface\\PVPFrame\\PVP-Currency-".. data.factionT ..":14:14:0:-1:32:32:3:29:3:29|t", nil,"RIGHT",0);
		end
	end
	-- zone
	if ns.profile[name].showZoneTT2 and data.area then
		tt2:SetCell(tt2:AddLine(C(color1,ZONE)),2,data.area,nil,"RIGHT",0);
	end
	-- notes
	if ns.profile[name].showNotesTT2 and data.notes and data.notes:trim():len()>0 then
		tt2:AddSeparator(4,0,0,0,0);
		tt2:SetCell(tt2:AddLine(),1,C(color1,COMMUNITIES_ROSTER_COLUMN_TITLE_NOTE),nil,nil,0);
		tt2:AddSeparator();
		tt2:SetCell(tt2:AddLine(),1,ns.scm(data.notes,true),nil,"LEFT",0);
	end
	-- broadcast
	if ns.profile[name].showBroadcastTT2 and data.broadcast and data.broadcast:len()>0 then
		tt2:AddSeparator(4,0,0,0,0);
		tt2:SetCell(tt2:AddLine(),1,C(color1,BATTLENET_BROADCAST),nil,nil,0);
		tt2:AddSeparator();
		local broadcast = data.broadcast;
		if ns.profile.GeneralOptions.scm then
			broadcast="***"; -- dummy text
		else
			broadcast=ns.strWrap(broadcast,48);
		end
		tt2:SetCell(tt2:AddLine(),1,broadcast,nil,"LEFT",0);
		if data.broadcastTime then
			tt2:SetCell(tt2:AddLine(),1,C("ltgray","("..L["Active since"]..CHAT_HEADER_SUFFIX..SecondsToTime(time()-data.broadcastTime)..")"),nil,"RIGHT",0);
		end
	end

	ns.roundupTooltip(tt2);
end

local function tooltipLineScript_OnMouseUp(self,data,button)
	if data.type=="realm" then
		-- whisper toon to toon
		if IsAltKeyDown() then
			if C_PartyInfo.InviteUnit then
				C_PartyInfo.InviteUnit(data.fullName);
			elseif InviteUnit then
				InviteUnit(data.fullName);
			end
		elseif IsShiftKeyDown() then
			if data.client=="WoW" then
				local name = data.name;
				if ns.realm~=data.realm then
					name = name.."-"..ns.realm;
				end
				_G["ChatFrame1EditBox"]:Insert(name)
			end
		else
			ChatFrame_SendTell(data.fullName:gsub(" ",""));
		end
	elseif data.type=="battlenet" then
		-- battlenet whisper
		if IsAltKeyDown() then
			if data.client=="WoW" then
				BNInviteFriend(data.toonID);
			end
		elseif IsShiftKeyDown() then
			if data.client=="WoW" then
				local name = data.name;
				if ns.realm~=data.realm then
					name = name.."-"..ns.realm;
				end
				_G["ChatFrame1EditBox"]:Insert(name)
			end
		else
			local func,name = "BNet",data.account; -- account name
			if button=="RightButton" then
				func,name = "",data.name; -- toon name
				if ns.realm~=data.realm then
					name = name .."-".. ns.stripRealm(data.realm);
				end
			end
			securecall("ChatFrame_Send"..func.."Tell",name);
		end
	end
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	local columns,l,c=8;
	local numFriends = C_FriendList.GetNumFriends();
	local friendsOnline = C_FriendList.GetNumOnlineFriends();

	local numBNFriends = BNGetNumFriends();
	if tt.lines~=nil then tt:Clear(); end
	tt:SetCell(tt:AddLine(),1,C("dkyellow",L[name]),tt:GetHeaderFont(),"LEFT",0);

	local _, _, _, broadcastText = BNGetInfo();
	if broadcastText~=nil and broadcastText~="" then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("dkyellow",L["My current broadcast message"]),nil,nil,columns);
		tt:AddSeparator();
		tt:SetCell(tt:AddLine(),1,C("white",ns.scm(broadcastText,true)),nil,nil,columns);
	end

	local fi,nt,ti;
	local visible = {};

	tt:AddSeparator(4,0,0,0,0);
	tt:AddLine(
		C("ltyellow",L["Real ID"].."/"..BATTLETAG), -- 1
		C("ltyellow",LEVEL),		-- 2
		C("ltyellow",CHARACTER),	-- 3
		ns.profile[name].showGame~="0"    and C("ltyellow",GAME)       or "", -- 4
		ns.profile[name].showZone         and C("ltyellow",ZONE)       or "", -- 5
		ns.profile[name].showRealm=="1"   and C("ltyellow",L["Realm"]) or "", -- 6
		ns.profile[name].showFaction=="2" and C("ltyellow",FACTION)    or "", -- 7
		ns.profile[name].showNotes        and C("ltyellow",L["Notes"]) or ""  -- 8
	);
	tt:AddSeparator();

	if ns.profile[name].showBNFriends then
		tt:SetCell(tt:AddLine(),1,C("ltgray",L["BattleNet friends"]),nil,"LEFT",0);
		local friendsDisplayed = false;
		if not BNConnected() then
			tt:SetCell(tt:AddLine(),1,"    "..C("ltred",BATTLENET_UNAVAILABLE),nil,"LEFT",0);
		else
			-- RealId	Status Character	Level	Zone	Game	Realm	Notes
			for i=1, numBNFriends do
				local nt = C_BattleNet.GetFriendNumGameAccounts(i);
				local fi = C_BattleNet.GetFriendAccountInfo(i);
				if nt and fi and fi.gameAccountInfo.isOnline then
					for I=1, nt do
						local ti =  C_BattleNet.GetFriendGameAccountInfo(i,I) or {};
						local bcIcon = fi.customMessage~="" and "|Tinterface\\chatframe\\ui-chatinput-focusicon:0|t" or "";
						local cl = ti.clientProgram;
						local mobileApp =  cl~="BSAp" or (cl=="BSAp" and ns.profile[name].showMobileApp); -- filter mobile app
						local desktopApp = cl~= "App" or (cl== "App" and ns.profile[name].showDesktopApp); -- filter desktop app
						local duplicates = not visible[fi.bnetAccountID]; -- filter duplicates...
						if duplicates and mobileApp and desktopApp then
							local isBNColor=false;
							visible[fi.bnetAccountID] = true
							local clientInfo = GetClientInfo(ti.clientProgram);
							local l = tt:AddLine();

							-- wow logout is buggy. sometimes level==0 and reamid==0. player is logout out but displayed as playing wow
							if ti.characterLevel==0 and ti.realmID==0 then
								ti.clientProgram = "App"
							end

							-- wow clients compare
							if ti.clientProgram=="WoW" then
								if not (ti.realmName and ti.realmName~="") then
									-- missing realm name. try to get it from richPresence
									local _,realmName = strsplit("-",ti.richPresence)
									if realmName then
										realmName = realmName:trim()
										if realmName~="" then
											-- get realmName from richPresence
											ti.realmName = realmName;
										end
									end
								end
								if ti.realmName and ti.realmName~="" then
									ti.realmInfo = {};
									_, ti.realmInfo.Name, _, _, ti.realmInfo.Locale, _, ti.realmInfo.Region, ti.realmInfo.Timezone = ns.LRI:GetRealmInfo(ti.realmName,ns.region);
								else
									ns:debug("missing realmName",ti.realmName)
								end
								if  ti.realmInfo.Name then
									-- get realmName from realmInfo
									ti.realmName = ti.realmInfo.Name;
								end
								if not (ti.areaName and ti.areaName~="") then
									-- missing area name. try to it from richPresence
									local areaName = strsplit("-",ti.richPresence)
									if areaName then
										areaName = areaName:trim();
										if areaName~="" then
											ti.areaName = areaName;
										end
									end
								end
								-- show different project id
								if WOW_PROJECT_ID ~= ti.wowProjectID then
									-- add project name to realmName
									if ti.realmName and ti.realmName~="" then
										ti.realmName = ti.realmName .. " |cffffee00("..L["WoWProjectId"..ti.wowProjectID]..")|r";
									else
										ti.realmName = "|cffffee00"..L["WoWProjectId"..ti.wowProjectID].."|r";
									end
								end
							end

							-- battle tags / realids
							if ns.profile[name].showBattleTags~="0" then
								local a,b = strsplit("#",fi.battleTag);
								local BattleTag = C("ltblue",ns.scm(a))..C("ltgray","#"..ns.scm(b));
								local bnName=C("ltblue",ns.scm(fi.accountName));
								-- 0 Disabled
								-- 1 Name
								-- 2 Name (BattleTag)
								-- 3 BattleTag
								if ns.profile[name].showBattleTags=="2" then
									bnName = bnName .. C("white"," (")..BattleTag..C("white",")");
								elseif ns.profile[name].showBattleTags=="3" then
									bnName = BattleTag;
								end
								tt:SetCell(l,1,"    "..bnName..bcIcon); -- 1
							end

							-- level
							ti.characterLevel = tonumber(ti.characterLevel);
							if ti.characterLevel and ti.characterLevel>0 then
								tt:SetCell(l,2,C("white",ti.characterLevel));		-- 2
							end

							-- toon name
							local nameStr = (ti.characterName and ti.characterName~="" and ti.characterName) or (fi.isBattleTagFriend and fi.accountName and fi.accountName~="" and fi.accountName) or strsplit("#",fi.battleTag);
							if ti.clientProgram=="WoW" and ti.realmID>0 and ti.className then
								nameStr = C(ti.className,ns.scm(nameStr)); -- wow character name in class color
							else
								nameStr = C("ltblue",ns.scm(nameStr)); -- all other in light blue
							end
							-- toon name - append realm name or asterisk
							if tonumber(ns.profile[name].showRealm)>1 and ti.realmName~=ns.realm_short and ti.realmID and ti.realmID>0 then
								if ns.profile[name].showRealm=="2" then
									nameStr = nameStr..C("dkyellow","-"..ns.scm(ti.realmName));
								else
									nameStr = nameStr..C("dkyellow","*");
								end
							end
							-- toon name - append faction icon
							if ns.profile[name].showFaction=="1" and ti.clientProgram=="WoW" and ti.factionName then
								nameStr = nameStr.."|TInterface\\PVPFrame\\PVP-Currency-"..ti.factionName..":16:16:0:-1:32:32:2:30:2:30|t";
							elseif ns.profile[name].showBattleTags=="0" and ti.clientProgram~="App" then
								nameStr = nameStr.." "..bcIcon;
							end
							tt:SetCell(l,3,_status(fi.isAFK,fi.isDND)..nameStr); -- 3

							-- game icon or text
							if ns.profile[name].showGame~="0" then
								tt:SetCell(l,4, ns.profile[name].showGame=="2" and C("white",clientInfo.short) or clientInfo.iconStr );	-- 4
							end

							-- zone or current screen
							if ns.profile[name].showZone then
								if ti.clientProgram=="WoW" and ti.areaName and ti.areaName:match("^"..GARRISON_LOCATION_TOOLTIP) and ti.areaName~=GARRISON_LOCATION_TOOLTIP then
									ti.areaName = GARRISON_LOCATION_TOOLTIP;
								end
								local zoneStr = (ti.areaName and ti.areaName~="" and ti.areaName) or (ti.clientProgram and ti.clientProgram~="" and clientInfo.long) or UNKNOWN;
								tt:SetCell(l,5,C("white",zoneStr),nil,nil, ti.clientProgram=="WoW" and 1 or 3);			-- 5,6,7
							end

							if ti.clientProgram=="WoW" then
								-- realm (own column)
								if ns.profile[name].showRealm=="1" and ti.realmID>0 then
									local realmLocaleIcon = ""
									if ns.profile[name].showRealmLanguageFlag and ti.realmInfo and ti.realmInfo.Locale then
										if ti.realmInfo.Region=="EU" and ti.realmInfo.Locale=="enUS" then
											ti.realmInfo.Locale = "enGB"; -- Great Britain
										elseif ti.realmInfo.Region=="US" and ti.realmInfo.Timezone=="AEST" then
											ti.realmInfo.Locale = "enAU"; -- flag of australian
										end
										realmLocaleIcon = "|T"..ns.media .. "countries/" .. ti.realmInfo.Locale .. ":0:2|t";
									end
									if not ti.realmName then
										ti.realmName = (ti.realmID and "Unknown Realm [Id: "..ti.realmID.."]" or UNKNOWN) --.." |cffffee00("..EXPANSION_NAME0.."?)|r";
									end
									tt:SetCell(l,6,C( (ns.realms[ti.realmName] or (ti.realmName and ns.realms[ti.realmName])) and "green" or "white",ti.realmName .. realmLocaleIcon));			-- 6
								end
								-- faction (own column)
								if ti.factionName then
									if ns.profile[name].showFaction=="2" then
										local color = "green";
										if ti.factionName=="Alliance" then
											color = "ff0077ff"
										elseif ti.factionName=="Horde" then
											color = "red"
										end
										tt:SetCell(l,7,C(color,_G["FACTION_"..ti.factionName:upper()] or ti.factionName));		-- 7
									elseif ns.profile[name].showFaction=="3" then
										if ti.factionName=="Neutral" then
											tt:SetCell(l,7,"|TInterface\\minimap\\tracking\\battlemaster:16:16:0:-1:32:32:2:30:2:30|t");
										else
											tt:SetCell(l,7,"|TInterface\\PVPFrame\\PVP-Currency-"..ti.factionName..":16:16:0:-1:32:32:2:30:2:30|t");
										end
									end
								end
							end
							-- notes
							if ns.profile[name].showNotes and fi.note then
								tt:SetCell(l,8,C("white",C("white",ns.scm(fi.note,true)))); -- 8
							end

							local data = {
								type = "battlenet",
								toonID = ti.gameAccountID,
								account = fi.accountName,
								className = ti.className or false,
								name = ti.characterName,
								client = ti.clientProgram,
								realm = ti.realmName,
								area = ti.clientProgram~="App" and (ti.areaName or ti.richPresence) or false,
								notes = strtrim(fi.note or ""),
								broadcast = strtrim(fi.customMessage or ""),
								broadcastTime = fi.customMessageTime or false,
							};
							if ti.factionName then
								data.factionT = ti.factionName:upper();
								data.factionL = _G["FACTION_"..ti.factionName:upper()];
							end

							tt:SetLineScript(l, "OnMouseUp", tooltipLineScript_OnMouseUp, data);
							tt:SetLineScript(l, "OnEnter", createTooltip2, data);

							friendsDisplayed = true;
						end
					end
				end
			end
		end
		if not friendsDisplayed then
			tt:SetCell(tt:AddLine(),1,"    "..C("gray",L["Currently no battle.net friends online..."]),nil,"LEFT",0);
		end
	end

	if ns.profile[name].showFriends then
		tt:SetCell(tt:AddLine(),1,C("ltgray",FRIENDS),nil,"LEFT",0);
		if friendsOnline==0 then
			tt:SetCell(tt:AddLine(),1,"    "..C("gray",L["Currently no friends online..."]),nil,"LEFT",0);
		else
			local clientInfo,_ = GetClientInfo("WoW")
			for i=1, numFriends do
				local v = C_FriendList.GetFriendInfoByIndex(i);
				v.fullName = v.name;
				if v.name:find("-") then
					v.name, v.realm = strsplit("-",v.fullName,2);
				else
					v.realm = ns.realm;
					v.fullName = v.fullName .."-".. ns.realm;
				end
				v.client = "WoW";
				if visible[v.name..v.realm..v.area] then
					-- filter duplicates...
				elseif v.name and v.connected then
					visible[v.name..v.realm..v.area] = true;
					local l = tt:AddLine("","","","","","","","");
					tt:SetCell(l,2,C("white",v.level));

					local nameStr = _status(v.afk,v.dnd) .. C(v.className:upper(),ns.scm(v.name));

					local realm,_
					if type(v.realm)=="string" and v.realm:len()>0 then
						_,realm = ns.LRI:GetRealmInfo(v.realm,ns.region);
					end

					if tonumber(ns.profile[name].showRealm)>1 and v.realm~=ns.realm then
						if ns.profile[name].showRealm=="2" then
							nameStr = nameStr..C("dkyellow","-"..ns.scm(realm or v.realm));
						else
							nameStr = nameStr..C("dkyellow","*");
						end
					end
					if ns.profile[name].showFaction=="1" then
						nameStr = nameStr.."|TInterface\\PVPFrame\\PVP-Currency-"..ns.player.faction..":16:16:0:-1:32:32:2:30:2:30|t";
					end
					tt:SetCell(l,3,nameStr);

					-- client icon or text
					if ns.profile[name].showGame~="0" then
						tt:SetCell(l,4,clientInfo.iconStr);
					end
					-- zone
					if ns.profile[name].showZone then
						if v.area:match("^"..GARRISON_LOCATION_TOOLTIP) and v.area~=GARRISON_LOCATION_TOOLTIP then
							v.area = GARRISON_LOCATION_TOOLTIP;
						end
						tt:SetCell(l,5,C("white",v.area));
					end
					-- realm
					if ns.profile[name].showRealm=="1" then
						tt:SetCell(l,6,C("green",realm or v.realm));
					end
					-- faction
					if ns.profile[name].showFaction=="2" then
						tt:SetCell(l,7,C(ns.player.faction=="Horde" and "red" or "ltblue",ns.player.factionL or ns.player.faction));
					elseif ns.profile[name].showFaction=="3" then
						tt:SetCell(l,7,"|TInterface\\PVPFrame\\PVP-Currency-"..ns.player.faction..":16:16:0:-1:32:32:2:30:2:30|t");
					end
					-- notes
					if ns.profile[name].showNotes and type(v.notes)=="string" and v.notes:len()>0 then
						tt:SetCell(l,8,C("white",ns.scm(v.notes or "")));
					end

					v.type = "realm";
					v.factionT = ns.player.faction:upper();
					v.factionL = ns.player.factionL;

					tt:SetLineScript(l, "OnMouseUp", tooltipLineScript_OnMouseUp, v);
					tt:SetLineScript(l, "OnEnter", createTooltip2, v);
				end
			end
		end
	end

	if not ns.profile[name].showBNFriends and not ns.profile[name].showFriends then
		tt:AddLine(C("ltgray",L["No friends to diplay. You have both disabled for tooltip"]));
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(3,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,
			C("ltblue",L["MouseBtn"]).." = "..C("green",WHISPER) .." || "..
			C("ltblue",L["ModKeyA"].."+"..L["MouseBtn"]).." = "..C("green",TRAVEL_PASS_INVITE) .. " || "..
			C("ltblue",L["ModKeyS"].."+"..L["MouseBtn"]).." = "..C("green",L["FriendCopyIntoChatInput"]
		),nil,nil,columns);
		ns.ClickOpts.ttAddHints(tt,name,nil,2);
	end

	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"BATTLETAG_INVITE_SHOW", -- ?
		"BN_BLOCK_LIST_UPDATED",
		"BN_CONNECTED",
		"BN_CUSTOM_MESSAGE_CHANGED",
		"BN_CUSTOM_MESSAGE_LOADED",
		"BN_DISCONNECTED",
		"BN_FRIEND_ACCOUNT_OFFLINE",
		"BN_FRIEND_ACCOUNT_ONLINE",
		"BN_FRIEND_INFO_CHANGED",
		"BN_FRIEND_INVITE_ADDED",
		"BN_FRIEND_INVITE_REMOVED",
		"BN_INFO_CHANGED",
		"FRIENDLIST_UPDATE",
		"PLAYER_LOGIN",
		"CHAT_MSG_SYSTEM"
	},
	config_defaults = {
		enabled = true,
		-- broker button
		splitFriendsBroker = true,
		showFriendsBroker = true,
		showBNFriendsBroker = true,

		-- tooltip 1
		showFriends = true,
		showStatus = "1",
		showBNFriends = true,
		showBattleTags = "3",
		showRealm = "1",
		showGame = "1",
		showFaction = "2",
		showZone = true,
		showNotes = true,
		showTotalCount = true,
		showMobileApp = true,
		showDesktopApp = true,
		showRealmLanguageFlag = true,

		-- tooltip 2
		showBroadcastTT2 = true,
		showBattleTagTT2 = false,
		showRealIDTT2 = false,
		showFactionTT2 = false,
		showZoneTT2 = false,
		showGameTT2 = false,
		showNotesTT2 = false
	},
	clickOptionsRename = {
		["friends"] = "1_open_character_info",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["friends"] = {SOCIAL_BUTTON,"call",{"ToggleFriendsFrame",1}},
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	friends = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			splitFriendsBroker={ type="toggle", order=1, name=L["Split friends on Broker"], desc=L["Split Characters and BattleNet-Friends on Broker Button"] },
			showFriendsBroker={ type="toggle", order=2, name=L["Show friends"], desc=L["Display count of friends if 'Split friends on Broker' enabled otherwise add friends to summary count."]},
			showBNFriendsBroker={ type="toggle", order=3, name=L["Show BattleNet friends"], desc=L["Display count of BattleNet friends on Broker if 'Split friends on Broker' enabled otherwise add BattleNet friends to summary count."] },
			showTotalCount={ type="toggle", order=4, name=L["Show total count"], desc=L["Display total count of friens and/or BattleNet friends on broker button"] },
		},
		tooltip1 = {
			name = L["Main tooltip options"],
			order = 2,

			showFriends={ type="toggle", order=1, name=L["Show friends"],           desc=L["Display friends in tooltip"] },
			showBNFriends={ type="toggle", order=2, name=L["Show BattleNet friends"], desc=L["Display BattleNet friends in tooltip"] },
			showBattleTags={ type="select", order=3, name=L["Show BattleTag/RealID"],  desc=L["Display BattleTag and/or RealID in tooltip"], width="double",
				values={
					["0"] = NONE.." / "..ADDON_DISABLED,
					["1"] = "RealID or BattleName",
					["2"] = "RealID or BattleName (BattleTag)",
					["3"] = "BattleTag",
				},
			},
			showRealm={ type="select", order=4, name=L["Show realm"], desc=L["Display realm name in tooltip (WoW only)"], width="double",
				values={
					["0"] = NONE.." / "..ADDON_DISABLED,
					["1"] = L["Realm name in own column"],
					["2"] = L["Realm name in character name column"],
					["3"] = L["* (Asterisk) behind character name if on foreign realm"]
				},
			},
			showRealmLanguageFlag = { type="toggle", order=4, name=L["Show country flag"], desc = L["Display country flag behind realm names"] },
			showFaction={ type="select", order=5, name=L["Show faction"], desc=L["Display faction in tooltip (WoW only)"], width="double",
				values={
					["0"]=NONE.." / "..ADDON_DISABLED,
					["1"]=L["Icon behind character name"],
					["2"]=L["Faction name in own column"],
					["3"]=L["Faction icon in own column"]
				},
			},
			showGame={ type="select", order=6, name=L["Show game"], desc=L["Display game icon or game shortcut in tooltip"], --width="double",
				values={
					["0"]=NONE.." / "..ADDON_DISABLED,
					["1"]=L["Game icon"],
					["2"]=L["Game shortcut"]
				},
			},
			showStatus={ type="select", order=7, name=L["Show status"], desc=L["Display status like AFK in tooltip"], -- width="double",
				values={
					["0"]=NONE.." / "..ADDON_DISABLED,
					["1"]=L["Status icon"],
					["2"]=L["Status text"],
				},
			},
			showZone={ type="toggle", order=8, name=ZONE, desc=L["Display zone in tooltip"] },
			showNotes={ type="toggle", order=9, name=L["Notes"], desc=L["Display notes in tooltip"] },
			showMobileApp={ type="toggle", order=10, name=L["Show MobileApp"], desc=L["Display Battle.Net-Friends on MobileApp in tooltip"] },
			showDesktopApp={ type="toggle", order=11, name=L["Show DesktopApp"], desc=L["Display Battle.Net-Friends on DesktopApp in tooltip"] },
		},
		tooltip2 = {
			name=L["Second tooltip options"],
			order = 3,

			desc={ type="description", order=11, name=L["The secondary tooltip will be displayed by moving the mouse over a friend in main tooltip. The tooltip will be displayed if one of the following options activated."], fontSize="medium"},
			showBroadcastTT2={ type="toggle", order=12, name=L["Show broadcast message"], desc=L["Display broadcast message in tooltip (BattleNet friend only)"] },
			showBattleTagTT2={ type="toggle", order=13, name=L["Show BattleTag"], desc=L["Display BattleTag in tooltip (BattleNet friend only)"] },
			showRealIDTT2={ type="toggle", order=14, name=L["Show RealID"], desc=L["Display RealID in tooltip if available (BattleNet friend only)"] },
			showFactionTT2={ type="toggle", order=15, name=L["Show faction"], desc=L["Display faction in tooltip if available"] },
			showZoneTT2={ type="toggle", order=16, name=L["Show zone"], desc=L["Display zone in second tooltip"] },
			showGameTT2={ type="toggle", order=17, name=L["Show game"], desc=L["Display game in second tooltip"] },
			showNotesTT2={ type="toggle", order=18, name=L["Show notes"], desc=L["Display notes in second tooltip"] },
		},
		misc = nil,
	}
end

-- function module.init() end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGIN" then
		if type(ns.profile[name].showBattleTags)=="boolean" then
			ns.profile[name].showBattleTags = ns.profile[name].showBattleTags and "3" or "0";
		end
	elseif ns.eventPlayerEnteredWorld then
		updateBroker();
		if (tt) and (tt.key) and (tt.key==ttName) and (tt:IsShown()) then
			createTooltip(tt);
		end
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip(
		{ttName, ttColumns, "LEFT","CENTER", "LEFT", "CENTER", "LEFT", "LEFT", "LEFT", "LEFT"},
		{false},
		{self}
	);
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button)
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
