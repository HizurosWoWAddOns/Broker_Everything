
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Quest Log" -- QUESTLOG_BUTTON
local ldbName,ttName,ttName2,ttColumns,ttColumns2,tt,tt2,createMenu,createTooltip = name,name.."TT",name.."TT2",9,2;
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
local Level, LevelPrefix, Title, Header, Color, Status, Type, ShortType, QuestId, Index, Title2, Text = 1,2,3,4,5,6,7,8,9,10,11,12;
local Zone = 13;
local frequencies = {
	[LE_QUEST_FREQUENCY_DAILY] = {"*",DAILY},
	[LE_QUEST_FREQUENCY_WEEKLY] = {"**",WEEKLY},
};
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
-- StaticPopup_Show("BE_URL_DIALOG")


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="Interface\\TARGETINGFRAME\\PortraitQuestBadge",coords={0.05,0.95,0.05,0.95}}; --IconName::Quest Log--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show count of quests in your questlog and quest titles in tooltip"],
	label = QUESTLOG_BUTTON,
	events = {
		"PLAYER_LOGIN",
		"PLAYER_ENTERING_WORLD",
		"QUEST_LOG_UPDATE",
	},
	updateinterval = 1, -- 10
	config_defaults = {
		showQuestTags = true,
		showQuestIds = true,
		showQuestZone = true,
		showQuestTagsShort = true,
		--showQuestItems = true,
		showQuestOptions = true,
		questIdUrl = "WoWHead",
		separateBy = "status",
		-- second tooltip options
		tooltip2QuestText = true,
		tooltip2QuestLevel = true,
		tooltip2QuestZone = true,
		tooltip2QuestTag = true,
		tooltip2QuestID = true,

	},
	config_allowed = {
	},
	config = {
		{ type="header", label=QUESTLOG_BUTTON, align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showQuestIds",       label=L["Show quest id's"], tooltip=L["Show quest id's in tooltip."] },
		{ type="toggle", name="showQuestZone",      label=L["Show quest zone"], tooltip=L["Show quest zone in tooltip."] },
		{ type="toggle", name="showQuestTags",      label=L["Show quest tags"], tooltip=L["Show quest tags in tooltip."] },
		{ type="toggle", name="showQuestTagsShort", label=L["Show short quest tags"], tooltip=L["Show short quest tags in tooltip."] },
		{ type="toggle", name="showQuestOptions",   label=L["Show quest option"], tooltip=L["Show quest options like track, untrack, share and cancel in tooltip."] },
		{ type="select", name="questIdUrl",         label=L["Fav. website"], tooltip=L["Choose your favorite website for further informations to a quest."], event=true,
			default = "WoWHead",
			values = {
				WoWHead = "WoWHead",
				WoWDB = "WoWDB (english only)",
				Buffed = "Buffed"
			}
		},
		{
			type="select", name="separateBy", label=L["Separate quests by"], tooltip=L["Separate the quests by header (like Blizzard) or status"],
			default = "status",
			values = {
				status = "Status",
				header = "Header",
				zone = "Zone"
			}
		},
		{ type="sepatator" },
		{ type="header", label=L["Second tooltip options"] },
		{ type="separator", inMenuInvisible=true },
		{ type="toggle", name="tooltip2QuestText", label=L["Show quest text"], tooltip=L["Display quest text in tooltip"] },
		{ type="toggle", name="tooltip2QuestLevel", label=L["Show quest level"], tooltip=L["Display quest level in tooltip"] },
		{ type="toggle", name="tooltip2QuestZone", label=L["Show quest zone"], tooltip=L["Display quest zone in tooltip"] },
		{ type="toggle", name="tooltip2QuestTag", label=L["Show quest tag"], tooltip=L["Display quest tags in tooltip"] },
		{ type="toggle", name="tooltip2QuestID", label=L["Show quest id"], tooltip=L["Display quest id in tooltip"] },
	},
	clickOptions = {
		["1_open_quest_log"] = {
			cfg_label = "Open quest log", -- L["Open quest log"]
			cfg_desc = "open the quest log", -- L["open the quest log"]
			cfg_default = "_LEFT",
			hint = "Open quest log", -- L["Open quest log"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleQuestLog");
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
	if (tt~=nil) then tt:Hide(); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(ldbName);
	local fail, active, complete = numQuestStatus.fail, numQuestStatus.active, numQuestStatus.complete;
	obj.text = (fail>0 and C("red",fail).."/" or "")..(complete>0 and C("ltblue",complete).."/" or "")..sum.."/"..MAX_QUESTS;
end

local function showQuest(self)
	securecall("QuestMapFrame_OpenToQuestDetails",select(8, GetQuestLogTitle(self.questIndex)));
end

local function showQuestURL(self)
	url = urls[ns.profile[name].questIdUrl](self.questId);
	StaticPopup_Show("BE_URL_DIALOG");
end

local function pushQuest(self)
	QuestLogPushQuest(self.questIndex);
end

local function deleteQuest(self)
	local questId = self.questId;
	if requested==questId then
		SelectQuestLogEntry(GetQuestLogIndexByID(questId));
		SetAbandonQuest();
		AbandonQuest();
		requested = false;
	else
		requested = questId;
		createTooltip(tt,true,"deleteQuest");
	end	
end

local function trackQuest(self)
	securecall("QuestMapQuestOptions_TrackQuest",self.questId);
	createTooltip(tt,true,"trackQuest");
end

local function createTooltip2(self, obj)
	if tt2created then return end
	tt2created=true;

	tt2 = ns.acquireTooltip({ttName2,ttColumns2,"LEFT","RIGHT"},{true},{self,"horizontal",tt});

	tt2:Clear();
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

	--ns.roundupTooltip(tt2);
	tt2:Show();
end

local function tt2ShowOnEnter(self)
	createTooltip2(self,self.info);
end
local function tt2HideOnLeave()
	if tt2 then
		tt2created=false;
	end
end

local function ttAddLine(obj)
	assert(type(obj)=="table","object must be a table, got "..type(obj));
	local l = tt:AddLine();
	local cell, color,GroupQuest = 1,"red",{};

	if (obj[Color]) then
		color = ns.LC.colorTable2HexCode(obj[Color]);
	end

	if (type(obj[QuestId])=="number") and (IsInGroup()) then
		for i=1, GetNumSubgroupMembers() do -- GetNumSubgroupMembers
			if (IsUnitOnQuestByQuestID(obj[QuestId],"party"..i)) then
				tinsert(GroupQuest,C(select(2,UnitClass("party"..i)),UnitName("party"..i)));
			end
		end
		if (#GroupQuest>0) then
			obj[Title2] = ("%s [%d]"):format(obj[Title],#GroupQuest);
		end
	end

	tt:SetCell(l,cell,C(color,obj[Level])); cell=cell+1; -- [1]
	if ns.profile[name].showQuestTagsShort then tt:SetCell(l,cell,obj[ShortType]); end cell=cell+1; -- [2]
	tt:SetCell(l,cell,C(color,ns.strCut(obj[Title2] or obj[Title],32))); cell=cell+1; -- [3]
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
	tt:SetLineScript(l,"OnMouseUp",showQuest);
	tt.lines[l].questIndex = obj[Index];

	if ns.profile[name].showQuestIds then
		tt:SetCell(l,cell,obj[QuestId])
		if (obj[QuestId]~=L["QuestId"]) then
			tt:SetCellScript(l,cell,"OnMouseUp",showQuestURL);
			tt.lines[l].cells[cell].questId = obj[QuestId];
		end
		cell=cell+1; -- [6]
	end

	if ns.profile[name].showQuestOptions then
		tt:SetCell(l,cell,IsQuestWatched(obj[Index]) and UNTRACK_QUEST_ABBREV or TRACK_QUEST_ABBREV);
		tt:SetCellScript(l,cell,"OnMouseUp",trackQuest);
		tt.lines[l].cells[cell].questId = obj[QuestId];
		cell=cell+1; -- [7]

		tt:SetCell(l,cell,CANCEL .. (requested==obj[QuestId] and C("orange"," ("..L["really?"]..")") or ""));
		tt:SetCellScript(l,cell,"OnMouseUp",deleteQuest);
		tt.lines[l].cells[cell].questId = obj[QuestId];
		cell=cell+1; -- [8]

		if IsInGroup() then
			if GetNumGroupMembers()>1 and GetQuestLogPushable(obj[Index]) then
				tt:SetCell(l,cell,SHARE_QUEST_ABBREV);
				tt:SetCellScript(l,cell,"OnMouseUp",pushQuest);
				tt.lines[l].cells[cell].questIndex = obj[Index];
				cell=cell+1 -- [9]
			end
			if #GroupQuest>0 and IsShiftKeyDown() then
				l,c = tt:AddLine();
				tt:SetCell(l,1,table.concat(GroupQuest,", "), nil, nil, ttColumns);
				tt:AddSeparator();
			end
		end
	end

	tt.lines[l].info = obj;
	tt:SetLineScript(l,"OnEnter", tt2ShowOnEnter);
	tt:SetLineScript(l,"OnLeave", tt2HideOnLeave);

	return #GroupQuest;
end

function createTooltip(tt, update, from)
	if not tt or (tt and tt.key and tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	local header = false;
	if self then requested=false; end

	tt:AddLine(" "); --dummy
	tt:Clear();
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
		tt:SetCell(l,c,C("ltYellow",L["Options"]),nil,nil,2); -- share, track / untrack
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
					table.sort(quests,function(a,b) return (a[Title2] or a[Title])<(b[Title2] or b[Title]) end);
					for _,obj in pairs(quests)do
						if obj[Status]==s[1] then
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
			local l,c = tt:AddLine()
			tt:SetCell(l,1,C("ltblue",L["Hold shift"]).." || "..C("green",L["Show group member name with same quests"]),nil,"LEFT",ttColumns);
		end
		local l,c = tt:AddLine()
		tt:SetCell(l,1,C("ltblue",L["Click"]).." || "..C("green",L["Open QuestLog and select quest"]),nil,"LEFT",ttColumns)
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end

	if not update then
		ns.roundupTooltip(tt);
	end
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	if event=="PLAYER_LOGIN" then
		ns.tradeskills();
	elseif event == "PLAYER_ENTERING_WORLD" or event == "QUEST_LOG_UPDATE" then
		local numEntries, numQuests = GetNumQuestLogEntries()
		local header, status, isBounty, _ = false;
		local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory, qText = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15; -- GetQuestLogTitle(index)
		sum,quests,numQuestStatus = numQuests,{},{fail=0,complete=0,active=0};

		for index=1, numEntries do
			local q = {GetQuestLogTitle(index)};
			q[qText] = GetQuestLogQuestText(index);
			if q[isHeader]==true then
				header = q[title];
			elseif header then
				local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(q[questID]);
				local tagNameLong = tagName;
				if tagName==GROUP and q[suggestedGroup]>0 then
					tagNameLong = tagName.."["..q[suggestedGroup].."]";
				elseif tagName==PLAYER_DIFFICULTY2 then
					tagNameLong = LFG_TYPE_DUNGEON.." ("..tagName..")";
				end
				local tags,shortTags = {},{};
				if ns.questTags[tagID] then
					tinsert(tags,tagNameLong);
					if type(ns.questTags[tagID])=="table" then
						tinsert(shortTags,C(ns.questTags[tagID][2],ns.questTags[tagID][1]));
					else
						tinsert(shortTags,C("dailyblue",ns.questTags[tagID]));
					end
				end
				if ns.tradeskills[header] then
					tinsert(tags,TRADE_SKILLS);
					tinsert(shortTags,C(ns.questTags.TRADE_SKILLS[2],ns.questTags.TRADE_SKILLS[1]));
				end
				if q[qText]:find(TRACKER_HEADER_WORLD_QUESTS) then
					tinsert(tags,TRACKER_HEADER_WORLD_QUESTS);
					tinsert(shortTags,C(ns.questTags.WORLD_QUESTS[2],ns.questTags.WORLD_QUESTS[1]));
				end
				if frequencies[q[frequency]] then
					tinsert(tags,frequencies[q[frequency]][2]);
					tinsert(shortTags,C("dailyblue",frequencies[q[frequency]][1]));
				end
				local mapId,mapName;
				if not questZones[q[questID]] and not WorldMapFrame:IsShown() then
					mapId = securecall("GetQuestWorldMapAreaID",q[questID]);
					mapName = GetMapNameByID(mapId);
					questZones[q[questID]] = {mapId=mapId,mapName=mapName};
				end
				if #tags==0 then
					tinsert(tags," ");
				end
				
				status = (q[isComplete]==-1 and "fail") or (q[isComplete==1] and "complete") or "active";
				table.insert(quests,{
					q[level],
					" ",
					q[title],
					header,GetQuestDifficultyColor(q[level]),
					status,
					table.concat(tags,", "),
					table.concat(shortTags,""),
					q[questID],
					index,
					nil,
					q[qText],
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

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns,"RIGHT","LEFT","LEFT","LEFT","LEFT","LEFT","LEFT","LEFT"},{false},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

