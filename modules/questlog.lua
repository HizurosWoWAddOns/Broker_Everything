
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Quest Log" -- QUESTLOG_BUTTON L["ModDesc-Quest Log"]
local ttName,ttName2,ttColumns,ttColumns2,tt,tt2,module,createTooltip = name.."TT",name.."TT2",9,2;
local quests,numQuestStatus,sum,url,tt2created,requested
local urls = {
	WoWHead = function(id)
		local lang = {deDE="de",esES="es",esMX="es",frFR="fr",ptBR="pt"}
		return ("http://%s.wowhead.com/quest=%d"):format(lang[GetLocale()] or "www",id)
	end,
	Buffed = function(id)
		local url = {deDE="http://wowdata.buffed.de/?q=%d",ruRU="http://wowdata.buffed.ru/?q=%d"}
		return (url[GetLocale()] or "http://wowdata.getbuffed.com/?q=%d"):format(id)
	end,
	WoWDB = function(id)
		return ("http://www.wowdb.com/quests/%d"):format(id)
	end
	--
}
local hideQuestsAnytime = {
	[54180] = true, -- weekly pvp
};
local hidePvPQuests = {
	[44891] = true; -- PvP 2vs2
	[44908] = true; -- PvP 3vs3
	[44909] = true; -- PvP battlefield
}
local hideEmissaryQuests = {
	-- legion
	[42170]=true, [42233]=true, [42234]=true, [42420]=true, [42421]=true,
	[42422]=true, [43179]=true, [48639]=true, [48641]=true, [48642]=true,
	-- bfa
	[50600]=true, [50601]=true, [50599]=true, [50605]=true, [50603]=true,
	[50598]=true, [50602]=true, [50606]=true, [50604]=true, [50562]=true,
	-- bfa 8.2.5
	[56120]=true, [56119]=true
}
local Level, Title, Header, Color, Status, Type, ShortType, QuestId, Index, IsHidden, Text = 1,2,3,4,5,6,7,8,9,10,11;
local frequencies = {
	[LE_QUEST_FREQUENCY_DAILY or Enum.QuestFrequency.Daily] = {"*",DAILY},
	[LE_QUEST_FREQUENCY_WEEKLY or Enum.QuestFrequency.Weekly] = {"**",WEEKLY},
};
local MATCH_DUNGEON_DIFFICULTY = DUNGEON_DIFFICULTY.." '(.*)'";
local difficulties = {
	[PLAYER_DIFFICULTY1] = {"N"},
	[PLAYER_DIFFICULTY2] = {"HC"},
	[PLAYER_DIFFICULTY3] = {"RB"},
	[PLAYER_DIFFICULTY4] = {"FL"},
	[PLAYER_DIFFICULTY5] = {"CM"},
	[PLAYER_DIFFICULTY6] = {"M"},
	[PLAYER_DIFFICULTY_TIMEWALKER] = {"TW"}
}
local _PLAYER_DIFFICULTY6="'"..PLAYER_DIFFICULTY6.."'";
local questZones = {};

StaticPopupDialogs["BE_URL_DIALOG"] = {
	text = "URL",
	button2 = CLOSE,
	timeout = 0,
	whileDead = 1,
	hasEditBox = 1,
	hideOnEscape = 1,
	maxLetters = 1024,
	editBoxWidth = 250,
	OnShow = function(f)
		local e,b = _G[f:GetName().."EditBox"],_G[f:GetName().."Button2"]
		if e then e:SetText(url) e:SetFocus() e:HighlightText(0) end
		if b then b:ClearAllPoints() b:SetWidth(100) b:SetPoint("CENTER",e,"CENTER",0,-30) end
	end,
	EditBoxOnEscapePressed = function(f)
		f:GetParent():Hide()
	end
}


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\TARGETINGFRAME\\PortraitQuestBadge",coords={0.05,0.95,0.05,0.95}}; --IconName::Quest Log--


-- some local functions --
--------------------------
local IsQuestWatched = IsQuestWatched or function(questLogIndex)
	local info = C_QuestLog.GetInfo(questLogIndex);
	if info then
		return C_QuestLog.GetQuestWatchType(info.questID) ~= nil;
	end
end

local GetQuestLogPushable = GetQuestLogPushable or function(questLogIndex)
	local info = C_QuestLog.GetInfo(questLogIndex);
	if info then
		return C_QuestLog.IsPushableQuest(info.questID);
	end
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local fail, active, complete = numQuestStatus.fail, numQuestStatus.active, numQuestStatus.complete;
	obj.text = (fail>0 and C("red",fail).."/" or "")..(complete>0 and C("ltblue",complete).."/" or "")..sum.."/"..MAX_QUESTS;
end

local function showQuest(self,questIndex)
	local questID = C_QuestLog.GetQuestIDForLogIndex(questIndex);
	if questID then
		securecall("QuestMapFrame_OpenToQuestDetails", questID);
	end
end

local function showQuestURL(self,questId)
	url = urls[ns.profile[name].questIdUrl](questId);
	StaticPopup_Show("BE_URL_DIALOG");
end

local function pushQuest(self,questIndex)
	QuestLogPushQuest(questIndex);
end

local function deleteQuest(self,questId)
	if requested==questId then
		C_QuestLog.SetSelectedQuest(questId);
		C_QuestLog.SetAbandonQuest();
		C_QuestLog.AbandonQuest();
		requested = false;
	else
		requested = questId;
		createTooltip(tt,true,"deleteQuest");
	end
end

local function trackQuest(self,questId)
	securecall("QuestMapQuestOptions_TrackQuest",questId);
	createTooltip(tt,true,"trackQuest");
end

local function createTooltip2(self, obj)
	if tt2created then return end
	tt2created=true;

	tt2 = ns.acquireTooltip({ttName2,ttColumns2,"LEFT","RIGHT"},{true},{self,"horizontal",tt});

	if tt2.lines~=nil then tt2:Clear(); end
	tt2:SetCell(tt2:AddLine(),1,C("dkyellow",obj[Title]),tt2:GetHeaderFont(),"LEFT",2);

	if ns.profile[name].tooltip2QuestText then
		tt2:AddSeparator(4,0,0,0,0);
		tt2:SetCell(tt2:AddLine(),1,ns.strWrap(obj[Text],40),nil,"LEFT",2);
	end

	if ns.profile[name].tooltip2QuestLevel
	and ns.profile[name].tooltip2QuestZone
	and ns.profile[name].tooltip2QuestTag
	and ns.profile[name].tooltip2QuestID then
		tt2:AddSeparator(4,0,0,0,0);
	end

	if ns.profile[name].tooltip2QuestLevel then
		tt2:AddLine(C("ltblue",L["Quest level"]),C("ltgreen",obj[Level]));
	end

	if ns.profile[name].tooltip2QuestZone and questZones[obj[QuestId]] and questZones[obj[QuestId]].mapName then
		tt2:AddLine(C("ltblue",L["Quest zone"]),C("ltgreen",questZones[obj[QuestId]].mapName));
	end

	if ns.profile[name].tooltip2QuestTag and obj[Type]:len()>1 then
		tt2:AddLine(C("ltblue",L["Quest tags"]),C("ltgreen",obj[Type]));
	end

	if ns.profile[name].tooltip2QuestTag then
		tt2:AddLine(C("ltblue",L["Quest id"]),C("ltgreen",obj[QuestId]));
	end

	tt2:Show();
end

local function hideTooltip2()
	if tt2 then
		tt2created=false;
	end
end

local function ttAddLine(obj)
	assert(type(obj)=="table","object must be a table, got "..type(obj));

	if (not ns.profile[name].showPvPWeeklys and hidePvPQuests[obj[QuestId]]) or (not ns.profile[name].showWorldQuests and hideEmissaryQuests[obj[QuestId]]) then
		return;
	end

	local l,c = tt:AddLine();
	local cell, color,GroupQuest = 1,"red",{};

	if (obj[Color]) then
		color = ns.LC.colorTable2HexCode(obj[Color]);
	end

	if (type(obj[QuestId])=="number") and (IsInGroup()) then
		for i=1, GetNumSubgroupMembers() do -- GetNumSubgroupMembers
			if (IsUnitOnQuest and IsUnitOnQuest(obj[Index],"party"..i)) -- classic
			or (C_QuestLog and C_QuestLog.IsUnitOnQuest and C_QuestLog.IsUnitOnQuest("party"..i,obj[QuestId])) then -- retail
				tinsert(GroupQuest,C(select(2,UnitClass("party"..i)),UnitName("party"..i)));
			end
		end
		if (#GroupQuest>0) then
			obj.Title2 = ("%s [%d]"):format(obj[Title],#GroupQuest);
		end
	end

	tt:SetCell(l,cell,C(color,obj[Level])); cell=cell+1; -- [1]
	if ns.profile[name].showQuestTagsShort then tt:SetCell(l,cell,obj[ShortType]); end cell=cell+1; -- [2]
	tt:SetCell(l,cell,C(color,ns.strCut(obj.Title2 or obj[Title],32))); cell=cell+1; -- [3]
	if ns.profile[name].showQuestZone then
		local mapName = " ";
		if obj[QuestId] and questZones[obj[QuestId]] and questZones[obj[QuestId]].mapName then
			mapName = questZones[obj[QuestId]].mapName;
		end
		tt:SetCell(l,cell,mapName); cell=cell+1; -- [4]
	end
	if ns.profile[name].showQuestTags then
		tt:SetCell(l,cell,C(color,obj[Type])); cell=cell+1; -- [5]
	end
	tt:SetLineScript(l,"OnMouseUp",showQuest, obj[Index]);

	if ns.profile[name].showQuestIds then
		tt:SetCell(l,cell,obj[QuestId])
		if (obj[QuestId]~=L["QuestId"]) then
			tt:SetCellScript(l,cell,"OnMouseUp",showQuestURL,obj[QuestId]);
		end
		cell=cell+1; -- [6]
	end

	if ns.profile[name].showQuestOptions then
		if ns.client_version>=5 then
			tt:SetCell(l,cell,IsQuestWatched(obj[Index]) and UNTRACK_QUEST_ABBREV or TRACK_QUEST_ABBREV);
			tt:SetCellScript(l,cell,"OnMouseUp",trackQuest,obj[QuestId]);
			cell=cell+1; -- [7]
		end

		tt:SetCell(l,cell,CANCEL .. (requested==obj[QuestId] and C("orange"," ("..L["really?"]..")") or ""));
		tt:SetCellScript(l,cell,"OnMouseUp",deleteQuest,obj[QuestId]);
		cell=cell+1; -- [8]

		if IsInGroup() then
			if GetNumGroupMembers()>1 and GetQuestLogPushable(obj[Index]) then
				tt:SetCell(l,cell,SHARE_QUEST_ABBREV);
				tt:SetCellScript(l,cell,"OnMouseUp",pushQuest,obj[Index]);
				cell=cell+1 -- [9]
			end
			if #GroupQuest>0 and IsShiftKeyDown() then
				l,c = tt:AddLine();
				tt:SetCell(l,1,table.concat(GroupQuest,", "), nil, nil, ttColumns);
				tt:AddSeparator();
			end
		end
	end

	tt:SetLineScript(l,"OnEnter", createTooltip2, obj);
	tt:SetLineScript(l,"OnLeave", hideTooltip2);

	return #GroupQuest;
end

function createTooltip(tt, update, from)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	local header = false;
	--if self then requested=false; end

	if tt.lines~=nil then tt:Clear(); end
	tt:SetCell(select(1,tt:AddLine()),1,C("dkyellow",name),tt:GetHeaderFont(),"LEFT",ttColumns)
	local GroupQuestCount=0;

	if sum==0 then
		tt:AddSeparator();
		local l=tt:AddLine();
		tt:SetCell(l,1,C("ltgray",L["You have no quests in your quest log"]),"CENTER",nil,ttColumns);
	else
		tt:AddSeparator(4,0,0,0,0);
		local c,l=4,tt:AddLine();
		tt:SetCell(l,1,C("ltYellow",LEVEL),nil,"CENTER",2);
		tt:SetCell(l,3,C("ltYellow",L["Quest name"]));
		if ns.profile[name].showQuestZone then
			tt:SetCell(l,c,C("ltyellow",L["Quest zone"])); c=c+1;
		end
		if ns.profile[name].showQuestTags then
			tt:SetCell(l,c,C("ltYellow",L["Quest tags"])); c=c+1;
		end
		if ns.profile[name].showQuestIds then
			tt:SetCell(l,c,C("ltYellow",L["QuestId"])); c=c+1;
		end
		tt:SetCell(l,c,C("ltYellow",OPTIONS),nil,nil,2); -- share, track / untrack
		tt:AddSeparator()

		if ns.profile[name].separateBy=="status" then
			local firstHeader = true;
			for i,s in ipairs({{"fail","red",L["Failed quests"]},{"active","ltgreen",L["Active quests"]},{"complete","ltblue",L["Completed quests"]}}) do
				if numQuestStatus[s[1]]>0 then
					if not firstHeader then
						tt:AddSeparator(2,0,0,0,0);
					end
					firstHeader = false;
					tt:SetCell(select(1,tt:AddLine()),1,C(s[2],s[3]),nil,"LEFT",ttColumns);
					table.sort(quests,function(a,b) return (a.Title2 or a[Title])<(b.Title2 or b[Title]) end);
					for _,obj in pairs(quests)do
						if obj[Status]==s[1] and (not obj[IsHidden]==true) then
							ttAddLine(obj);
						end
					end
				end
			end
		elseif ns.profile[name].separateBy=="header" then
			table.sort(quests,function(a,b) return ns.strCut(a[Header],10)..ns.strCut(a[Title],10)<ns.strCut(b[Header],10)..ns.strCut(b[Title],10) ; end);
			for _,obj in ipairs(quests) do
				if header ~= obj[Header] then
					if header then
						tt:AddSeparator(2,0,0,0,0);
					end
					header = obj[Header];
					tt:SetCell(select(1,tt:AddLine()),1,C("ltBlue",header),nil,"LEFT",ttColumns);
				end
				ttAddLine(obj);
			end
		elseif ns.profile[name].separateBy=="zone" then
			table.sort(quests,function(a,b) return ns.strCut(questZones[a[QuestId]].mapName or "0",10)..ns.strCut(a[Title],10)<ns.strCut(questZones[b[QuestId]].mapName or "0",10)..ns.strCut(b[Title],10) ; end);
			for _,obj in ipairs(quests) do
				if header ~= (questZones[obj[QuestId]].mapName or "0") then
					if header then
						tt:AddSeparator(2,0,0,0,0);
					end
					header = questZones[obj[QuestId]].mapName or UNKNOWN;
					tt:SetCell(select(1,tt:AddLine()),1,C("ltBlue",header),nil,"LEFT",ttColumns);
				end
				ttAddLine(obj);
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(3,0,0,0,0)
		if (GroupQuestCount>0) then
			ns.AddSpannedLine(tt,C("ltblue",L["Hold shift"]).." || "..C("green",L["Show group member name with same quests"]),nil,"LEFT");
		end
		ns.AddSpannedLine(tt,C("ltblue",L["MouseBtn"]).." || "..C("green",L["Open QuestLog and select quest"]),nil,"LEFT");
		ns.ClickOpts.ttAddHints(tt,name);
	end

	if not update then
		ns.roundupTooltip(tt);
	end
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"QUEST_LOG_UPDATE",
	},
	config_defaults = {
		enabled = false,
		showQuestTags = true,
		showQuestIds = true,
		showQuestZone = true,
		showQuestTagsShort = true,
		showQuestOptions = true,
		questIdUrl = "WoWHead",
		separateBy = "status",
		showPvPWeeklys = true,
		showWorldQuests = true,
		-- second tooltip options
		tooltip2QuestText = true,
		tooltip2QuestLevel = true,
		tooltip2QuestZone = true,
		tooltip2QuestTag = true,
		tooltip2QuestID = true,
	},
	clickOptionsRename = {
		["questlog"] = "1_open_quest_log",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["questlog"] = "QuestLog",
		["menu"] = "OptionMenu"
	}
}

if ns.client_version<4 then
	module.config_defaults.showQuestZone = false
	module.config_defaults.showQuestTags = false
	module.config_defaults.showQuestTagsShort = false
	module.config_defaults.tooltip2QuestTag = false
	module.config_defaults.tooltip2QuestZone = false
end

ns.ClickOpts.addDefaults(module,{
	questlog = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = nil,
		tooltip = {
			order=1,
			showQuestIds={ type="toggle", order=1, name=L["Show quest id's"], desc=L["Show quest id's in tooltip."] },
			showQuestZone={ type="toggle", order=2, name=L["Show quest zone"], desc=L["Show quest zone in tooltip."], hidden=ns.IsClassicClient },
			showQuestTags={ type="toggle", order=3, name=L["Show quest tags"], desc=L["Show quest tags in tooltip."], hidden=ns.IsClassicClient },
			showQuestTagsShort={ type="toggle", order=4, name=L["Show short quest tags"], desc=L["Show short quest tags in tooltip."], hidden=ns.IsClassicClient },
			showQuestOptions={ type="toggle", order=5, name=L["Show quest option"], desc=L["Show quest options like track, untrack, share and cancel in tooltip."] },
			showPvPWeeklys={ type="toggle", order=6, name=L["Show PvP weeklys"], desc=L["Show PvP weekly quests in tooltip"]},
			showWorldQuests={ type="toggle", order=7, name=L["Show world quests"], desc=L["Show quests to complete 4 world quests for a faction in tooltip."], width="full" },
			questIdUrl={ type="select", order=8, name=L["Fav. website"], desc=L["Choose your favorite website for further informations to a quest."],
				values = {
					WoWHead = "WoWHead",
					WoWDB = "WoWDB (english only)",
					Buffed = "Buffed"
				}
			},
			separateBy={
				type="select", order=9, name=L["Separate quests by"], desc=L["Separate the quests by header (like Blizzard) or status"],
				values = {
					status = "Status",
					header = "Header",
					zone = "Zone"
				}
			},
		},
		tooltip2 = {
			order=2,
			name = L["Second tooltip options"],
			tooltip2QuestText={ type="toggle", order=1, name=L["Show quest text"], desc=L["Display quest text in tooltip"] },
			tooltip2QuestLevel={ type="toggle", order=2, name=L["Show quest level"], desc=L["Display quest level in tooltip"] },
			tooltip2QuestZone={ type="toggle", order=3, name=L["Show quest zone"], desc=L["Display quest zone in tooltip"], hidden=ns.IsClassicClient },
			tooltip2QuestTag={ type="toggle", order=4, name=L["Show quest tag"], desc=L["Display quest tags in tooltip"], hidden=ns.IsClassicClient },
			tooltip2QuestID={ type="toggle", order=5, name=L["Show quest id"], desc=L["Display quest id in tooltip"] },
		},
		misc = nil,
	},
	{
		questIdUrl=true
	}
end

-- function module.init() end

function module.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name);
	end
	if event=="PLAYER_LOGIN" or event=="QUEST_LOG_UPDATE" then
		local numEntries, numQuests = (GetNumQuestLogEntries or C_QuestLog.GetNumQuestLogEntries)();
		local header, status, isBounty, _ = false;
		local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory, isHidden, isScaling = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16; -- GetQuestLogTitle(index)
		sum,quests,numQuestStatus = numQuests,{},{fail=0,complete=0,active=0};

		-- list trade skills
		local tradeskills = {}
		if GetProfessions then -- retail
			for order,index in ipairs({GetProfessions()}) do -- prof1, prof2, arch, fish, cook
				if index then
					local skillName, texture, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset, skillLineName = GetProfessionInfo(index);
					tradeskills[skillName] = true;
				end
			end
		else -- classic & bc classic
			local numSkills, lastHeader = GetNumSkillLines();
			local SECONDARY_SKILLS = SECONDARY_SKILLS:gsub(HEADER_COLON,"");
			for skillIndex=1, numSkills do
				local skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType = GetSkillLineInfo(skillIndex);
				if skillName then
					if header then
						lastHeader = skillName;
					elseif (lastHeader==TRADE_SKILLS or lastHeader==SECONDARY_SKILLS) then
						tradeskills[skillName] = true;
					end
				end
			end
		end

		for index=1, numEntries do
			local q = ns.C_QuestLog_GetInfo(index) or {};
			if q.isHeader==true then
				header = q.title;
			elseif header and q.questID and not hideQuestsAnytime[q.questID] then
				local tagInfo = ns.C_QuestLog_GetQuestTagInfo(q.questID);
				q.text,q.objectives = GetQuestLogQuestText(index);

				-- second way to check quest is completed. GetQuestLogTitle argument 6 aren't longer secure enough.
				local numObjectives = GetNumQuestLeaderBoards(index);
				local fin = true;
				if tonumber(numObjectives) then
					for objectiveIndex = 1, numObjectives do
						local text, objectiveType, finished = GetQuestLogLeaderBoard(objectiveIndex, index);
						if (not finished) and fin then
							fin=false;
						end
					end
				end

				local tags,shortTags,long = {},{};
				if tagInfo then
					if tagInfo.tagName==GROUP and type(q.suggestedGroup)=="number" and q.suggestedGroup>0 then
						tagInfo.tagName = tagInfo.tagName.."["..q.suggestedGroup.."]";
					elseif tagInfo.tagName==PLAYER_DIFFICULTY2 or tagInfo.tagName==PLAYER_DIFFICULTY6 then
						tagInfo.tagName = LFG_TYPE_DUNGEON.." ("..tagInfo.tagName..")";
					end
					if ns.questTags[tagInfo.tagID] then
						if tagInfo.tagName and tagInfo.tagName~="" then
							tinsert(tags,tagInfo.tagName);
							long=true;
						end
						if type(ns.questTags[tagInfo.tagID])=="table" then
							if not long then
								tinsert(tags,C(ns.questTagsLong[tagInfo.tagID][2],ns.questTagsLong[tagInfo.tagID][1]));
							end
							tinsert(shortTags,C(ns.questTags[tagInfo.tagID][2],ns.questTags[tagInfo.tagID][1]));
						else
							if not long then
								tinsert(tags,ns.questTagsLong[tagInfo.tagID]);
							end
							tinsert(shortTags,C("dailyblue",ns.questTags[tagInfo.tagID]));
						end
					end
				end
				if tradeskills[header] then
					tinsert(tags,TRADE_SKILLS);
					tinsert(tags,header);
					tinsert(shortTags,C(ns.questTags.TRADE_SKILLS[2],ns.questTags.TRADE_SKILLS[1]));
				elseif q.text:find(TRACKER_HEADER_WORLD_QUESTS) then
					tinsert(tags,TRACKER_HEADER_WORLD_QUESTS);
					tinsert(shortTags,C(ns.questTags.WORLD_QUESTS[2],ns.questTags.WORLD_QUESTS[1]));
				end
				if q.frequency and frequencies[q.frequency] then
					tinsert(tags,frequencies[q.frequency][2]);
					tinsert(shortTags,C("dailyblue",frequencies[q.frequency][1]));
				end
				local mapId,mapName;
				if ns.client_version>=4 then
					if not questZones[q.questID] and not WorldMapFrame:IsShown() then
						mapId = GetQuestUiMapID(q.questID,true);
						if mapId then
							local mapInfo = C_Map.GetMapInfo(mapId);
							if mapInfo then
								mapName = mapInfo.name;
							end
						end
						questZones[q.questID] = {mapId=mapId,mapName=mapName};
					end
				end
				if #tags==0 then
					tinsert(tags," ");
				end

				status = (q.isComplete==-1 and "fail") or ((q.isComplete==1 or fin) and "complete") or "active";
				table.insert(quests,{
					q.level,
					q.title,
					header,GetQuestDifficultyColor(q.level),
					status,
					table.concat(tags,", "),
					table.concat(shortTags," "),
					q.questID,
					index,
					q.isHidden,
					q.text,
					mapId or 0
				});
				numQuestStatus[status]=numQuestStatus[status]+1;
			end
		end

		updateBroker()
		if tt and tt.key and tt.key==ttName and not tt2created then
			createTooltip(tt, true, "event("..event..")");
		end
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns,"RIGHT","LEFT","LEFT","LEFT","LEFT","LEFT","LEFT","LEFT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
