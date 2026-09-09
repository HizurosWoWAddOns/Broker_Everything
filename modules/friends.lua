
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Friends"; -- FRIENDS L["ModDesc-Friends"]
local ttName,ttName2,ttColumns,tt,tt2,module = name.."TT",name.."TT2",8;
local showApp = {BSAp="showMobileApp", App="showDesktopApp"} -- <clientProgram>=<optionKey>

local CODicon = ns.media.."Battlenet-CODicon.tga";
local SORicon = ns.media.."Battlenet-SORicon.tga";
local GetClientInfo = setmetatable({
	-- <clientProgram>
	-- From Blizzard
	ANBS = {icon=4557783, short="DI",      long="Diablo Immortal"},
	App  = {icon=796351,  short="Desktop", long="Desktop App"},
	BSAp = {icon=796351,  short="Mobile",  long="Mobile App"},
	CLNT = {icon=796351,  short=nil,       long=nil},
	D3   = {icon=536090,  short="D3",      long="Diablo 3"},
	Fen  = {icon=5207606, short="D4",      long="Diablo 4"},
	GRY  = {icon=4553312, short="Arclight",long="Warcraft Arclight Rumble"},
	Hero = {icon=1087463, short="HotS",    long="Heroes of the Storm"},
	OSI  = {icon=4034244, short="D2",      long="Diablo II Resurrected"},
	Pro  = {icon=1313858, short="OW",      long="Overwatch"},
	Pro2 = {icon=4734171, short="OW2",     long="Overwatch 2"},
	RTRO = {icon=4034242, short="Arcade",  long="Blizzard Arcade Collection"},
	S1   = {icon=1669008, short="SC1",     long="Starcraft"},
	S2   = {icon=374211,  short="SC2",     long="Starcraft 2"},
	W3   = {icon=3257659, short="WC3",     long="Warcraft 3 Reforged"},
	WoW  = {icon=374212,  short="WoW",     long="World of Warcraft"},
	WTCG = {icon=852633,  short="HS",      long="Hearthstone"},
	-- missing:
	-- Warcraft 1: Remastered
	-- Warcraft 2: Remastered
	-- Warcraft 2: Battle.net-Edition
	-- Warcraft: Orcs & Humans

	-- From Activision
	WLBY = {icon=4034243, short="CB4",     long="Crash Bandicoot 4"},
	DST2 = {icon=1711629, short="DST2",    long="Destiny 2"},
	AUKS = {icon=CODicon, short="COD",     long="Call Of Duty"},
	VIPR = {icon=2204215, short="BO4",     long="Call Of Duty: Black Ops 4"},
	FORE = {icon=4256535, short="CoDV",    long="Call Of Duty: Vanguard"},
	LAZR = {icon=3581732, short="MW2",     long="Call Of Duty: Modern Warfare 2"},
	ODIN = {icon=3257658, short="MW",      long="Call Of Duty: Modern Warfare"},
	ZEUS = {icon=3920823, short="BOCW",    long="Call Of Duty: Black Ops Cold War"},

	-- From Others
	SCOR = {icon=SORicon, short="SOT",     long="Sea of Thieves"}

	-- Missing entries: (main problem is to get the 4 characters long code name)
	-- The Witcher 3
	-- Doom: The dark age
	-- Avowed
	-- The Outer World 2
	-- Tony Hawk's Pro Skater 3+4
	-- Call of Duty: Black Ops 6
	-- Call Of Duty: Modern Warfare 3

},{
	__call = function(t,name)
		local v = rawget(t,name)
		if not v then
			v = {icon=134400,short=name,long=name}
			ns:print("Game name '"..name.."' not known. Please report the addon author. - One or more of your friends are playing a game that this addon does not know.");
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

local editboxes = {}
if ChatFrame1EditBox then tinsert(editboxes,ChatFrame1EditBox) end
if StaticPopup1EditBox then tinsert(editboxes,StaticPopup1EditBox) end
if CommunitiesFrame and CommunitiesFrame.ChatEditBox then tinsert(editboxes,_G.CommunitiesFrame.ChatEditBox) end
-- BE_Notes?
-- WIM?


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

local function battleTagColoring(tagName,tagIndex)
	return C("ltblue",ns.scm(tagName))..C("ltgray","#"..ns.scm(tagIndex))
end

local function AddRealmInfo(data)
	local realmName,region,timezone,_
	_, realmName, _, _, data.realmLocale, _, region, timezone = ns.LRI:GetRealmInfo((data.realmName and data.realmName~="" and data.realmName) or data.realmID,ns.region);
	if realmName then
		if data.realmName=="" then
			-- get realmName from realmInfo
			data.realmName = realmName;
		end
		-- fix language code
		if region=="EU" and data.realmLocale=="enUS" then
			data.realmLocale = "enGB"; -- Great Britain
		elseif region=="US" and timezone=="AEST" then
			data.realmLocale = "enAU"; -- Australian
		end
	end
end

local function UpdateBNClientEntry(client)
	local bnFriendAccInfo = client.bnFriendAccInfo
	client.friendType="battlenet" -- required for tooltipLineScript_OnMouseUp
	client.accountName = bnFriendAccInfo.accountName -- ChatFrame_SendBNetTell() and ChatFrame_SendTell() in tooltipLineScript_OnMouseUp()
	client.note = bnFriendAccInfo.note -- createTooltip2()
	client.customMessage = bnFriendAccInfo.customMessage -- createTooltip2()
	client.customMessageTime = bnFriendAccInfo.customMessageTime -- createTooltip2()
	client.battleTag = bnFriendAccInfo.battleTag -- AddBNFriendLine()
	client.isBattleTagFriend = bnFriendAccInfo.isBattleTagFriend
	client.isAFK = bnFriendAccInfo.isAFK
	client.isDND = bnFriendAccInfo.isDND
	if client.clientProgram=="WoW" then
		if client.factionName then
			local factionUpperCase = client.factionName:upper();
			client.factionTexture = factionUpperCase -- createTooltip2()
			client.factionLocale = _G["FACTION_"..factionUpperCase]; -- createTooltip2()
		end
		client.richPresence = client.richPresence or ""
		if client.richPresence~="" then
			local z,r = strsplit("-",client.richPresence)
			z,r = z:trim(),r:trim()
			if (client.realmName==nil or client.realmName=="") and r~="" then client.realmName = r end
			if (client.areaName==nil or client.areaName=="") and z~="" then client.areaName = z end
		end
		AddRealmInfo(client)
		if WOW_PROJECT_ID ~= client.wowProjectID then
			-- add project name
			client.wowProjectStr = "|cffffee00("..L["WoWProjectId"..client.wowProjectID]..")|r";
		end
	end
end

local function updateBroker()
	local txt, numBNFriends, numOnlineBNFriends, IsBNetOnline,numFriends,friendsOnline  = {},0,0,BNConnected();

	if IsBNetOnline then
		numBNFriends, numOnlineBNFriends = BNGetNumFriends();
	end

	numFriends = C_FriendList.GetNumFriends();
	friendsOnline = C_FriendList.GetNumOnlineFriends();

	if not (tonumber(numOnlineBNFriends) and tonumber(friendsOnline)) then
		return
	end

	if ns.profile[name].splitFriendsBroker then
		local friends = tostring(friendsOnline);
		local bnfriends = tostring(numOnlineBNFriends);
		if ns.profile[name].showTotalCount then
			friends = friends.."/"..numFriends;
			bnfriends = bnfriends.."/"..numBNFriends;
		end
		tinsert(txt,friends);
		if IsBNetOnline then
			tinsert(txt,bnfriends)
		end
	else
		local str = tostring(numOnlineBNFriends + friendsOnline);
		if ns.profile[name].showTotalCount then
			str = str .."/".. (numBNFriends + numFriends);
		end
		tinsert(txt,str);
	end

	if IsBNetOnline then
		local broadcastText = select(4,BNGetInfo());
		if (broadcastText) and (strlen(broadcastText)>0) then
			tinsert(txt,"|Tinterface\\chatframe\\ui-chatinput-focusicon:0|t");
		end
	end

	if #txt==0 then
		tinsert(txt,FRIENDS)
	end

	if not IsBNetOnline then
		tinsert(txt,"("..C("red","BNet Off")..")");
	end

	local dataobj = ns.LDB:GetDataObjectByName(module.ldbName);
	if dataobj then
		dataobj.text = table.concat(txt," ");
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
	tt2:SetCell(l,2,C(data.className or color1,ns.scm(data.characterName)),nil,nil,0);
	tt2:AddSeparator();
	-- game
	if ns.profile[name].showGameTT2 then
		local info = GetClientInfo(data.clientProgram);
		tt2:SetCell(tt2:AddLine(C(color1,info.type)),2,info.long .." ".. info.iconStr,nil,"RIGHT",0);
	end
	if data.clientProgram=="WoW" then
		-- realm
		if data.realmName then
			tt2:SetCell(tt2:AddLine(C(color1,L["Realm"])),2,ns.scm(data.realmName),nil,"RIGHT",0);
		end
		-- class
		if ns.profile[name].showClassTT2 then
			tt2:SetCell(tt2:AddLine(C(color1,CLASS)),2,data.className or UNKNOWN,"RIGHT",0)
		end
		-- faction
		if ns.profile[name].showFactionTT2 then
			tt2:SetCell(tt2:AddLine(C(color1,FACTION)),2, data.factionLocale .. " "..ns.factionIcon(data.factionTexture,14,14), nil,"RIGHT",0);
		end
	end
	-- zone
	if ns.profile[name].showZoneTT2 and not showApp[data.clientProgram] then
		tt2:SetCell(tt2:AddLine(C(color1,ZONE)),2,data.areaName or data.richPresence or "?",nil,"RIGHT",0);
	end
	-- notes
	if ns.profile[name].showNotesTT2 and data.note and strtrim(data.note):len()>0 then
		tt2:AddSeparator(4,0,0,0,0);
		tt2:SetCell(tt2:AddLine(),1,C(color1,COMMUNITIES_ROSTER_COLUMN_TITLE_NOTE),nil,nil,0);
		tt2:AddSeparator();
		tt2:SetCell(tt2:AddLine(),1,ns.scm(data.note,true),nil,"LEFT",0);
	end
	-- broadcast
	if ns.profile[name].showBroadcastTT2 and data.customMessage and strtrim(data.customMessage):len()>0 then
		tt2:AddSeparator(4,0,0,0,0);
		tt2:SetCell(tt2:AddLine(),1,C(color1,BATTLENET_BROADCAST),nil,nil,0);
		tt2:AddSeparator();
		local broadcast = data.customMessage;
		if ns.profile.GeneralOptions.scm then
			broadcast="***"; -- dummy text
		else
			broadcast=ns.strWrap(broadcast,48);
		end
		tt2:SetCell(tt2:AddLine(),1,broadcast,nil,"LEFT",0);
		if data.customMessageTime then
			tt2:SetCell(tt2:AddLine(),1,C("ltgray","("..L["Active since"]..CHAT_HEADER_SUFFIX..SecondsToTime(time()-data.customMessageTime)..")"),nil,"RIGHT",0);
		end
	end

	ns.roundupTooltip(tt2);
end

local function AddNameToEditBox(name,realm)
	if ns.realm~=realm then
		name = name.."-"..realm;
	end
	for _,editbox in ipairs(editboxes) do
		if editbox and editbox:IsVisible() and editbox:HasFocus() then
			editbox:Insert(name)
			break;
		end
	end
end

local function tooltipLineScript_OnMouseUp(self,data,button)
	if data.friendType=="realm" then
		local isKeyDown = IsAltKeyDown
		if ns.profile[name].useCtrlKeyInsteadAlt then
			isKeyDown = IsControlKeyDown
		end
		if isKeyDown() then
			-- party invite
			if C_PartyInfo.InviteUnit then
				C_PartyInfo.InviteUnit(data.fullName);
			elseif InviteUnit then
				InviteUnit(data.fullName);
			end
		elseif IsShiftKeyDown() then
			-- copy to chatbox
			if data.clientProgram=="WoW" then
				AddNameToEditBox(data.characterName,data.realmName)
			end
		else
			(ChatFrameUtil and ChatFrameUtil.SendTell or ChatFrame_SendTell)(data.fullName:gsub(" ",""));
			-- ChatFrameUtil.SendTell; 2026-06-01 not in classic available
			if not ns.IsRetailClient() and ChatFrameUtil and ChatFrameUtil.SendTell then
				ns:debug("friends.lua","ChatFrameUtil.SendTell","available")
			end
		end
	elseif data.friendType=="battlenet" then
		-- battlenet whisper
		local isKeyDown = IsAltKeyDown
		if ns.profile[name].useCtrlKeyInsteadAlt then
			isKeyDown = IsControlKeyDown
		end
		if isKeyDown() then
			if data.clientProgram=="WoW" then
				BNInviteFriend(data.gameAccountID);
			end
		elseif IsShiftKeyDown() then
			if data.clientProgram=="WoW" then
				AddNameToEditBox(data.characterName,data.realmName)
			end
		else
			local friendName,chatType,editBox;
			if button=="RightButton" then
				if WOW_PROJECT_ID ~= data.wowProjectID then
					ns:print(L["Sorry, could not whisper to another wow version."])
					return;
				end
				chatType = "WHISPER"
				friendName = data.characterName;
				if ns.realmName~=data.realmName then
					friendName = data.characterName .."-".. ns.stripRealm(data.realmName);
				end
			else
				chatType = "BN_WHISPER"
				friendName = data.accountName;
			end

			if ChatFrameUtil and ChatFrameUtil.ChooseBoxForSend then
				-- from ChatFrameUtil.lua - ChatFrameUtil.Send[BNet]Tell does not work very well.
				editBox = ChatFrameUtil.ChooseBoxForSend();
			end
			if editBox and editBox.SetChatType and editBox.SetTellTarget and editBox.UpdateHeader then
				editBox:SetChatType(chatType);
				editBox:SetTellTarget(friendName);
				if ( editBox ~= ChatFrameUtil.GetActiveWindow() ) then
					ChatFrameUtil.OpenChat("");
				end
				editBox:UpdateHeader();
			elseif chatType=="BN_WHISPER" and ChatFrame_SendBNetTell then -- old way
				securecall("ChatFrame_SendBNetTell",friendName);
			elseif chatType=="WHISPER" and ChatFrame_SendTell then -- old way
				securecall("ChatFrame_SendTell",friendName);
			end
		end
	end
end

local function AddTooltipLine(tt,data)
	local line = tt:AddLine()

	-- broadcast icon (battlenet only) will be appended to battletag or name (name if battletag disabled)
	local bcIcon = data.friendType=="battlenet" and data.customMessage and strtrim(data.customMessage)~="" and "|Tinterface\\chatframe\\ui-chatinput-focusicon:0|t" or "";

	local clientInfo = GetClientInfo(data.clientProgram);

	-- RealId  |  Status  |  Character  |  Level  |  Zone  |  Game  |  Realm  |  Notes

	-- BattleTag/RealID
	local showBattleTags = ns.profile[name].showBattleTags
	if showBattleTags~="0" and data.battleTag then
		-- db.showBattleTags
		-- | 0 Disabled
		-- | 1 RealName
		-- | 2 RealName (BattleTag)
		-- | 3 BattleTag

		local battleTag = battleTagColoring(strsplit("#",data.battleTag))
		local realID = data.accountName and data.accountName~="" and C("battlenet",ns.scm(data.accountName)) or false
		local bnName
		if realID then
			bnName = realID .. (showBattleTags=="2" and " ("..battleTag..")" or "")
		else -- showBattleTags=="3" and fallback if realID not available
			bnName = battleTag
		end
		tt:SetCell(line,1,"    ".._status(data.isAFK,data.isDND)..bnName..bcIcon) -- 1
	end

	-- level
	local level = tonumber(data.characterLevel)
	if level and level>0 then
		tt:SetCell(line, 2, C("white",level)) -- 2
	end

	-- character name string
	local nameStr = (data.characterName and data.characterName~="" and data.characterName)
				or  (data.isBattleTagFriend and data.accountName and data.accountName~="" and data.accountName)
				or  strsplit("#",data.battleTag);

	local classColor = "ltgray" -- color if not wow or class not available (buggy blizzard function)
	if data.clientProgram=="WoW" and data.className then
		classColor = data.className
	end
	nameStr = C(classColor,ns.scm(nameStr))

	if data.timerunningSeasonID and TimerunningUtil and TimerunningUtil.AddTinyIcon then
		-- TODO: is TimerunningUtil presend on classic clients?
		nameStr = TimerunningUtil.AddSmallIcon(nameStr)
	end

	-- character name string - append realm name or asterisk
	if tonumber(ns.profile[name].showRealm)>1 and data.realmName~=ns.realm_short and data.realmID and data.realmID>0 then
		if ns.profile[name].showRealm=="2" then
			nameStr = nameStr..C("dkyellow","-"..ns.scm(data.realmName));
		else
			nameStr = nameStr..C("dkyellow","*");
		end
	end

	-- character name string - append faction icon
	if data.clientProgram=="WoW" and data.factionName and ns.profile[name].showFaction=="1" then
		nameStr = nameStr..ns.factionIcon(data.factionName,16,16);
	end

	-- append broadcast icon to character name if battleTag disabled
	if bcIcon~="" and ns.profile[name].showBattleTags=="0" then
		nameStr = nameStr.." "..bcIcon;
	end
	tt:SetCell(line,3,_status(data.isGameAFK,data.isGameDND) .. nameStr); -- 3


	-- TODO: add character race - coming soon?

	-- game icon or text
	if ns.profile[name].showGame~="0" then
		tt:SetCell(line,4, ns.profile[name].showGame=="2" and C("white",clientInfo.short) or clientInfo.iconStr );	-- 4
	end

	-- zone or current screen
	if ns.profile[name].showZone then
		if data.clientProgram=="WoW" and data.areaName and data.areaName:match("^"..GARRISON_LOCATION_TOOLTIP) and data.areaName~=GARRISON_LOCATION_TOOLTIP then
			data.areaName = GARRISON_LOCATION_TOOLTIP;
		end
		local zoneColor = "grey"
		local zoneStr = UNKNOWN
		if data.areaName and data.areaName~="" then
			zoneStr = data.areaName
			zoneColor = "white" -- todo add color for same zone? zone id would be better than simple zone name matching. there are multible zones with same name and different ids.
		elseif data.clientProgram and data.clientProgram~="" and data.clientProgram~="WoW" then
			zoneStr = clientInfo.long
		end
		tt:SetCell(line,5,C(zoneColor,zoneStr),nil,nil, data.clientProgram=="WoW" and 1 or 3);			-- 5,6,7
	end


	if data.clientProgram=="WoW" then
		-- realm (own column)
		if ns.profile[name].showRealm=="1" then
			local realmName,realmLanguage = data.realmName
			local realmColor = "white"

			if realmName==nil or realmName=="" then
				realmName = UNKNOWN --..(data.realmID and " ("..data.realmID..")" or "")
				realmColor = "gray"
			elseif ns.realms[data.realmName] then -- connect realm
				realmColor = "green"
			end

			-- country/language flag
			if ns.profile[name].showRealmLanguageFlag and data.realmLocale then
				realmLanguage = "|T"..ns.media .. "countries/" .. data.realmLocale .. ":0:2|t";
			end

			tt:SetCell(line,6,
				C(realmColor, realmName)
				.. (data.wowProjectStr and " "..data.wowProjectStr or "")
				.. (realmLanguage or "")
			); -- 6
		end

		-- faction (own column)
		if data.factionName then
			if ns.profile[name].showFaction=="2" then
				local color = "green";
				if data.factionName=="Alliance" then
					color = "ff0077ff"
				elseif data.factionName=="Horde" then
					color = "red"
				end
				tt:SetCell(line,7,C(color,_G["FACTION_"..data.factionName:upper()] or data.factionName));		-- 7
			elseif ns.profile[name].showFaction=="3" then
				if data.factionName=="Neutral" then
					tt:SetCell(line,7,"|TInterface\\minimap\\tracking\\battlemaster:16:16:0:-1:32:32:2:30:2:30|t");
				else
					tt:SetCell(line,7,ns.factionIcon(data.factionName,16,16));
				end
			end
		end
	end

	-- notes
	if ns.profile[name].showNotes and data.note and strtrim(data.note):len()>0 then
		tt:SetCell(line,8,C("white",C("white",ns.scm(data.note,true)))); -- 8
	end

	-- add functions to the line for mouse over and click
	tt:SetLineScript(line, "OnMouseUp", tooltipLineScript_OnMouseUp, data);
	tt:SetLineScript(line, "OnEnter", createTooltip2, data);
	return true
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	local columns=8;

	if tt.lines~=nil then tt:Clear(); end
	tt:SetCell(tt:AddLine(),1,C("dkyellow",L[name]),tt:GetHeaderFont(),"LEFT",0);

	if BNConnected() then
		local _, _, _, broadcastText = BNGetInfo();
		if broadcastText~=nil and broadcastText~="" then
			tt:AddSeparator(4,0,0,0,0);
			tt:SetCell(tt:AddLine(),1,C("dkyellow",L["My current broadcast message"]),nil,nil,columns);
			tt:AddSeparator();
			tt:SetCell(tt:AddLine(),1,C("white",ns.scm(broadcastText,true)),nil,nil,columns);
		end
	end

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
		if BNConnected() then
			local friendsDisplayed = false;
			local numBNFriends = BNGetNumFriends();
			local friendsArePlaying,friendsAreNotPlaying = {},{}
			for i=1, numBNFriends do
				local numBNFriendClients = C_BattleNet.GetFriendNumGameAccounts(i);
				local bnFriendAccInfo = C_BattleNet.GetFriendAccountInfo(i);
				if numBNFriendClients and bnFriendAccInfo then
					local clientList,appList = {},{}

					for j=1, numBNFriendClients do
						local client =  C_BattleNet.GetFriendGameAccountInfo(i,j);
						client.bnFriendAccInfo=bnFriendAccInfo
						UpdateBNClientEntry(client)
						if type(client)=="table" and client.clientProgram then
							if not showApp[client.clientProgram]
								-- wow logout is buggy. sometimes level==0 and reamid==0 or characterName is empty. player is logout out (mostly by disconnect) but displayed as playing wow
								and not (client.clientProgram=="WoW" and ((client.characterName and client.characterName=="") or (client.characterLevel==0 and client.realmID==0)))
							then
								tinsert(clientList,client)
							elseif ns.profile[name][showApp[client.clientProgram]] then
								if client.clientProgram=="App" then
									tinsert(appList,1,client) -- desktop app first
								else
									tinsert(appList,client)
								end
							end
						else
							ns:debug("Something goes wrong with battle net data...",type(client),type(client and client.clientProgram))
						end
					end
					if #clientList>0 then
						tinsert(friendsArePlaying,clientList)
					end
					if #clientList==0 and #appList>0 then
						tinsert(friendsAreNotPlaying,{appList[1]})
					end
				end
			end
			for i, friends in ipairs({friendsArePlaying,friendsAreNotPlaying})do
				for j, clientList in ipairs(friends) do
					for k, client in ipairs(clientList)do
						AddTooltipLine(tt,client)
						friendsDisplayed = true;
					end
				end
			end
			if not friendsDisplayed then
				tt:SetCell(tt:AddLine(),1,"    "..C("gray",L["Currently no battle.net friends online..."]),nil,"LEFT",0);
			end
		else -- bn is not available
			tt:SetCell(tt:AddLine(),1,"    "..C("ltred",BATTLENET_UNAVAILABLE),nil,"LEFT",0);
		end
	end

	if ns.profile[name].showFriends then
		local friendsDisplayed,_ = false
		local numFriends = C_FriendList.GetNumFriends();
		tt:SetCell(tt:AddLine(),1,C("ltgray",FRIENDS),nil,"LEFT",0);
		for i=1, numFriends do
			local v = C_FriendList.GetFriendInfoByIndex(i);
			if v.name:find("-") then
				v.name, v.realm = strsplit("-",v.name,2);
			else
				v.realm = ns.realm;
			end
			if v.name and v.connected and not visible[v.name..v.realm..v.area] then
				visible[v.name..v.realm..v.area] = true;
				local localizedClass, englishClass, localizedRace, englishRace = GetPlayerInfoByGUID(v.guid)
				local factionUpperCase = (ns.player.faction):upper();
				local data = {
					areaName = v.area,
					characterLevel = v.level,
					characterName = v.name,
					classFilename = englishClass,
					className = v.className or localizedClass,
					clientProgram = "WoW",
					factionName = ns.player.faction, -- realm friends are faction bound? currently C_FriendList.GetFriendInfoByIndex() does not return faction name...
					factionTexture = factionUpperCase, -- createTooltip2()
					factionLocale = _G["FACTION_"..factionUpperCase], -- createTooltip2()
					friendType = "realm",
					isAFK = v.afk,
					isDND = v.dnd,
					isGameAFK = v.afk,
					isGameBusy = v.dnd,
					isOnline = v.connected, --or v.className==nil,
					isAppearOffline = false,
					note = v.notes,
					playerGuid = v.guid,
					raceFilename = englishRace,
					raceName = localizedRace,
					realmName = v.realm,
					regionID = ns.region,
					wowProjectID = WOW_PROJECT_ID,
				}
				AddRealmInfo(data)
				AddTooltipLine(tt,data)
				friendsDisplayed = true
			end
		end
		if not friendsDisplayed then
			tt:SetCell(tt:AddLine(),1,"    "..C("gray",L["Currently no friends online..."]),nil,"LEFT",0);
		end
	end

	if not ns.profile[name].showBNFriends and not ns.profile[name].showFriends then
		tt:AddLine(C("ltgray",L["No friends to diplay. You have both disabled for tooltip"]));
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(3,0,0,0,0);
		local modKey = ns.profile[name].useCtrlKeyInsteadAlt and "ModKeyC" or "ModKeyA"
		tt:SetCell(tt:AddLine(),1,
			C("ltblue",L["MouseBtn"]).." = "..C("green",WHISPER) .." || "..
			C("ltblue",L[modKey].."+"..L["MouseBtn"]).." = "..C("green",TRAVEL_PASS_INVITE) .. " || "..
			C("ltblue",L["ModKeyS"].."+"..L["MouseBtn"]).." = "..C("green",L["FriendCopyIntoChatInput"]
		),nil,nil,columns);
		ns.ClickOpts.ttAddHints(tt,name,nil,2);
	end

	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	group = L["Social"],
	name = FRIENDS,
	events = {
		"PLAYER_LOGIN",
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
		appendApps = false, -- initially just for debugging

		-- tooltip 2
		showBroadcastTT2 = true,
		showBattleTagTT2 = false,
		showRealIDTT2 = false,
		showClassTT2 = false,
		showFactionTT2 = false,
		showZoneTT2 = false,
		showGameTT2 = false,
		showNotesTT2 = false,

		-- misc
		controlKey = false,
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
			appendApps = { type="toggle", order=12, name=L["Append apps"], desc=L["Append apps from friends with active game clients are listed"], hidden=not ns.debugMode, disabled = function() return not (ns.profile[name].showMobileApp or ns.profile[name].showDesktopApp) end}
		},
		tooltip2 = {
			name=L["FriendsTT2"],
			order = 3,

			desc={ type="description", order=11, name=L["FriendsTT2Desc"], fontSize="medium"},
			showBroadcastTT2={ type="toggle", order=12, name=L["Show broadcast message"], desc=L["Display broadcast message in tooltip (BattleNet friend only)"] },
			showBattleTagTT2={ type="toggle", order=13, name=L["Show BattleTag"], desc=L["Display BattleTag in tooltip (BattleNet friend only)"] },
			showRealIDTT2={ type="toggle", order=14, name=L["Show RealID"], desc=L["Display RealID in tooltip if available (BattleNet friend only)"] },
			showClassTT2={ type="toggle", order=14, name=L["FriendsTT2Class"], desc=L["FriendsTT2ClassDesc"]},
			showFactionTT2={ type="toggle", order=15, name=L["Show faction"], desc=L["Display faction in tooltip if available"] },
			showZoneTT2={ type="toggle", order=16, name=L["Show zone"], desc=L["Display zone in second tooltip"] },
			showGameTT2={ type="toggle", order=17, name=L["Show game"], desc=L["Display game in second tooltip"] },
			showNotesTT2={ type="toggle", order=18, name=L["Show notes"], desc=L["Display notes in second tooltip"] },
		},
		misc = {
			useCtrlKeyInsteadAlt = 1,
		},
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
		local events = {
			"BN_BLOCK_LIST_UPDATED","BN_CONNECTED","BN_CUSTOM_MESSAGE_CHANGED","BN_CUSTOM_MESSAGE_LOADED",
			"BN_DISCONNECTED","BN_FRIEND_ACCOUNT_OFFLINE","BN_FRIEND_ACCOUNT_ONLINE","BN_FRIEND_INFO_CHANGED","BN_FRIEND_INVITE_ADDED",
			"BN_FRIEND_INVITE_REMOVED","BN_INFO_CHANGED","FRIENDLIST_UPDATE","PLAYER_ENTERING_WORLD","CHAT_MSG_SYSTEM"
		}
		if ns.client_version<12.1 then
			tinsert(events,"BATTLETAG_INVITE_SHOW")
			-- TOOD: search another way to track battle tag invites
		end
		for _,e in ipairs(events) do
			self:RegisterEvent(e)
		end
	elseif (ns.eventPlayerEnteredWorld or event=="PLAYER_ENTERING_WORLD") and not self.locked then
		self.locked=true -- catch up mass triggered events
		C_Timer.After(0.314159,function()
			updateBroker();
			if (tt) and (tt.key) and (tt.key==ttName) and (tt:IsShown()) then
				createTooltip(tt);
			end
			self.locked=nil
		end)
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
