
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Quest Log" -- QUESTLOG_BUTTON
L[name] = QUESTLOG_BUTTON;
local ldbName,ttName,ttName2,ttColumns,ttColumns2,tt,tt2,createMenu = name,name.."TT",name.."TT2",6,2;
local quests,numQuestStatus,sum,url
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
local Level, LevelPrefix, Title, Header, Color, Status, Type, QuestId, Index, Title2, Text = 1,2,3,4,5,6,7,8,9,10,11;

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
	events = {
		"PLAYER_ENTERING_WORLD",
		"QUEST_LOG_UPDATE",
	},
	updateinterval = 1, -- 10
	config_defaults = {
		showQuestTags = true,
		showQuestIds = true,
		--showQuestItems = true,
		showQuestOptions = true,
		questIdUrl = "WoWHead",
		separateBy = "status",
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showQuestIds", label=L["Show quest id's"], tooltip=L["Show quest id's in tooltip."] },
		{ type="toggle", name="showQuestTags", label=L["Show quest tags"], tooltip=L["Show quest tags in tooltip."] },
		{ type="toggle", name="showQuestOptions", label=L["Show quest option"], tooltip=L["Show quest options like track, untrack, share and cancel in tooltip."] },
		{ type="select", name="questIdUrl", label=L["Fav. website"], tooltip=L["Choose your favorite website for further informations to a quest."], event=true,
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
				header = "Header"
			}
		}
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
	local obj = ns.LDB:GetDataObjectByName(ldbName)
	local fail, active, complete = numQuestStatus.fail, numQuestStatus.active, numQuestStatus.complete;
	obj.text = (fail>0 and C("red",fail).."/" or "")..(complete>0 and C("ltblue",complete).."/" or "")..sum.."/"..MAX_QUESTS
end

local function createTooltip2(self, tt2, v)
	tt2:AddHeader(C("dkyellow",v[Title]));
	tt2:AddSeparator(4,0,0,0,0);
	local l=tt2:AddLine();
	tt2:SetCell(l,1,ns.strWrap(v[Text],40),nil,"LEFT",2);
	ns.roundupTooltip(self,tt2,nil,"horizontal",tt);
end

local function createTooltip(self, tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...
	local UnitNames={};

	local function addLine(obj)
		assert(type(obj)=="table","object must be a table, got "..type(obj));
		local l,c = tt:AddLine();
		local cell, color,GroupQuest = 1,"red",{};

		if (obj[Color]) then
			color = ns.LC.colorTable2HexCode(obj[Color]);
		end

		if (type(obj[QuestId])=="number") and (IsInGroup()) then
			for i=1, GetNumSubgroupMembers() do -- GetNumSubgroupMembers
				if (IsUnitOnQuestByQuestID(obj[QuestId],"party"..i)) then
					if (not UnitNames["p"..i]) then
						UnitNames["p"..i] = C(select(2,UnitClass("party"..i)),UnitName("party"..i));
					end
					tinsert(GroupQuest,UnitNames["p"..i]);
				end
			end
			if (#GroupQuest>0) then
				obj[Title2] = ("%s [%d]"):format(obj[Title],#GroupQuest);
			end
		end

		tt:SetCell(l,cell,C(color,obj[Level])) cell=cell+1; -- [1]
		tt:SetCell(l,cell,C(color,ns.strCut(obj[Title2] or obj[Title],32))); cell=cell+1; -- [2]
		if ns.profile[name].showQuestTags then
			tt:SetCell(l,cell,C(color,obj[Type])) cell=cell+1; -- [3]
		end
		tt:SetLineScript(l,"OnMouseUp",function(self)
			securecall("QuestMapFrame_OpenToQuestDetails",select(8, GetQuestLogTitle(obj[Index])));
		end)

		if ns.profile[name].showQuestIds then
			tt:SetCell(l,cell,obj[QuestId])
			if (obj[QuestId]~=L["QuestId"]) then
				tt:SetCellScript(l,cell,"OnMouseUp",function(self,button)
					url = urls[ns.profile[name].questIdUrl](obj[QuestId])
					StaticPopup_Show("BE_URL_DIALOG")
				end)
			end
			cell=cell+1; -- [4]
		end

		if ns.profile[name].showQuestOptions then
			tt:SetCell(l,cell,IsQuestWatched(obj[Index]) and UNTRACK_QUEST_ABBREV or TRACK_QUEST_ABBREV);
			tt:SetCellScript(l,cell,"OnMouseUp",function()
				QuestMapQuestOptions_TrackQuest(obj[QuestId]);
				createTooltip(false, tt);
			end);
			cell=cell+1; -- [4/5]

			local cancelCell = cell;
			tt:SetCell(l,cell,CANCEL);
			tt:SetCellScript(l,cell,"OnMouseUp",function(_self)
				if not _self.requested then
					tt:SetCell(l,cancelCell,CANCEL..C("orange"," ("..L["really?"]..")"));
					_self.requested=true;
				else
					SelectQuestLogEntry(GetQuestLogIndexByID(obj[QuestId]));
					SetAbandonQuest();
					AbandonQuest();
				end
			end);
			cell=cell+1; -- [5/6]

			if IsInGroup() then
				if GetNumGroupMembers()>1 and GetQuestLogPushable(obj[Index]) then
					tt:SetCell(l,cell,SHARE_QUEST_ABBREV);
					tt:SetCellScript(l,cell,"OnMouseUp",function(self,button)
						QuestLogPushQuest(obj[Index])
					end)
					cell=cell+1 -- [6/7]
				end
				if #GroupQuest>0 and IsShiftKeyDown() then
					l,c = tt:AddLine();
					tt:SetCell(l,1,table.concat(GroupQuest,", "), nil, nil, ttColumns);
					tt:AddSeparator();
				end
			end
		end

		tt:SetLineScript(l,"OnEnter",function(parent)
			tt2 = ns.LQT:Acquire(ttName2,ttColumns2,"LEFT","RIGHT");
			createTooltip2(self,tt2,obj);
		end);
		tt:SetLineScript(l,"OnLeave",function()
			if (tt2) then ns.hideTooltip(tt2,ttName2,false,true); end
		end);

		return #GroupQuest;
	end
	local header = false;

	tt:Clear()
	tt:SetCell(select(1,tt:AddLine()),1,C("dkyellow",name),tt:GetHeaderFont(),"LEFT",ttColumns)
	local GroupQuestCount=0;

	if sum==0 then
		tt:AddSeparator();
		local l=tt:AddLine();
		tt:SetCell(l,1,C("ltgray",L["You have no quests in your quest log"]),"CENTER",nil,ttColumns);
	else
		tt:AddSeparator(4,0,0,0,0);
		local c,l=3,tt:AddLine(C("ltYellow","    "..LEVEL),C("ltYellow",L["Quest name"]));
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
					for _,obj in ipairs(quests)do
						if obj[Status]==s[1] then
							addLine(obj);
						end
					end
				end
			end
		elseif ns.profile[name].separateBy=="header" then
			for _,obj in ipairs(quests) do
				if header ~= obj[Header] then
					if header then
						tt:AddSeparator(2,0,0,0,0);
					end
					header = obj[Header];
					tt:SetCell(select(1,tt:AddLine()),1,C("ltBlue",header),nil,"LEFT",ttColumns);
				end
				addLine(obj);
			end
		end
	end

	if (ns.profile.GeneralOptions.showHints) then
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
	ns.roundupTooltip(self,tt);
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	if event == "PLAYER_ENTERING_WORLD" or event == "QUEST_LOG_UPDATE" then
		local numEntries, numQuests = GetNumQuestLogEntries()
		local header, status, isBounty, _ = false;
		local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory, qText = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15; -- GetQuestLogTitle(index)
		sum,quests,numQuestStatus = numQuests,{},{fail=0,complete=0,active=0};
		--if ns.build>70000000 then
		--	isBounty, isStory = 14,15; -- legion change
		--end

		for index=1, numEntries do
			local q = {GetQuestLogTitle(index)};
			q[qText] = GetQuestLogQuestText(index);
			if q[isHeader]==true then
				header = q[title];
			elseif header then
				local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(q[questID]);
				if tagName==GROUP and q[suggestedGroup]>0 then
					tagName = tagName.."["..q[suggestedGroup].."]";
				elseif tagName==PLAYER_DIFFICULTY2 then
					tagName = LFG_TYPE_DUNGEON.." ("..tagName..")";
				end
				local tags = {};
				if tagName then
					tinsert(tags,tagName);
				end
				if q[frequency]==LE_QUEST_FREQUENCY_DAILY then
					tinsert(tags,DAILY);
				elseif q[frequency]==LE_QUEST_FREQUENCY_WEEKLY then
					tinsert(tags,WEEKLY);
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
					q[questID],
					index,
					nil,
					q[qText]
				});
				numQuestStatus[status]=numQuestStatus[status]+1;
			end
		end
		updateBroker()
		if tt then
			createTooltip(false, tt);
		end
	end
end


-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	tt = ns.LQT:Acquire(ttName, ttColumns,"RIGHT","LEFT","LEFT","LEFT","LEFT");
	createTooltip(self, tt);
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

