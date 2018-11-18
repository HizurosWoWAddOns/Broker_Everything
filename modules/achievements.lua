
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Achievements"; -- ACHIEVEMENTS L["ModDesc-Achievements"]
local ttName, ttColumns, tt, module = name.."TT", 3;
local bars,count,session = {},0,{};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\achievementframe\\UI-Achievement-Progressive-Shield-NoPoints", coords={.15,.55,.15,.55}, size={64,64}}; --IconName::Achievements--


-- some local functions --
--------------------------
local function listCategories()
	local categories, AchievementsSum, CompletedSum = {},0,0;
	local idList = GetCategoryList();
	for i=1, #idList do
		local Name,parentId = GetCategoryInfo(idList[i]);
		if(parentId==-1)then
			local Achievements, Completed = GetCategoryNumAchievements(idList[i],true);
			if(idList[i]~=81)then
				AchievementsSum = AchievementsSum + Achievements;
				CompletedSum = CompletedSum + Completed;
				for I=1, #idList do
					local _,parentId = GetCategoryInfo(idList[I]);
					if(idList[i]==parentId)then
						local SubAchievements, SubCompleted = GetCategoryNumAchievements(idList[I],true);
						Achievements = Achievements + SubAchievements;
						Completed = Completed + SubCompleted;
						AchievementsSum = AchievementsSum + SubAchievements;
						CompletedSum = CompletedSum + SubCompleted;
					end
				end
				tinsert(categories,{idList[i],Name,Achievements,Completed});
			else
				tinsert(categories,{idList[i],Name,true,Completed});
			end
		end
	end
	tinsert(categories,1,{0,--[[ACHIEVEMENTS_COMPLETED]] TOTAL,AchievementsSum,CompletedSum});
	return categories;
end

local function updateBars()
	local bgWidth = false;
	for i,v in ipairs(bars)do
		if(v~=nil and v:IsShown() and v.percent)then
			if not bgWidth then
				bgWidth=v.Bg:GetWidth();
			end
			v.Bar:SetWidth(bgWidth*v.percent);
			v.Bar:Show();
		end
	end
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local txt = {};

	local now = GetTotalAchievementPoints();
	if not session.total then
		session.total = now
	end

	local diff = now-session.total;
	if ns.profile[name].showPoints then
		if ns.profile[name].showPointsSess and diff>0 then
			now=now.." +"..diff;
		end
		tinsert(txt,C("dkyellow",now));
	elseif ns.profile[name].showPointsSess and diff>0 then
		tinsert(txt,C("dkyellow","+"..diff));
	end

	obj.text = #txt>0 and table.concat(txt,", ") or ACHIEVEMENTS;
end

local function resetSessionCounter()
	local id, points, _
	wipe(session);
	session.total = GetTotalAchievementPoints();
	local categories = listCategories();
	for i=1, #categories do
		if categories[i][3]~=true then
			session[i] = categories[i][4];
		end
	end
	updateBroker();
end

local function progressBar(tt, l, low, high)
	count=count+1;
	if(not ns.profile[name].showProgressBars)then
		if(bars[count])then
			bars[count]:Hide();
		end
		return;
	end
	if(not bars[count])then
		bars[count] = CreateFrame("Frame","BEStatusBarAchievements"..count,nil,"BEStatusBarTemplate");
		bars[count].Bar:SetVertexColor(0,0.39,0.07);
	end
	bars[count]:SetParent(tt.lines[l]);
	bars[count]:SetPoint("TOPLEFT",tt.lines[l],"TOPLEFT",-1,1);
	bars[count]:SetPoint("BOTTOMRIGHT",tt.lines[l],"BOTTOMRIGHT",1,-1);
	bars[count]:Show();
	bars[count].cur = low;
	bars[count].all = high;
	bars[count].percent = low==0 and 0 or low / high;
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end
	local l = tt:AddHeader(C("dkyellow",ACHIEVEMENTS));

	local now = GetTotalAchievementPoints();
	local diff = now-session.total;
	now = C("dkyellow",now) .. (diff>0 and C("ltgreen"," +"..diff) or "");
	tt:SetCell(l,2,now,nil,"RIGHT",0);
	count=0;

	if(ns.profile[name].showLatest)then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",LATEST_UNLOCKED_ACHIEVEMENTS));
		tt:AddSeparator();
		local latest = {GetLatestCompletedAchievements()};
		for i=1, #latest do
			local id, Name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(latest[i]);
			tt:AddLine("  "..C("ltyellow",ns.strCut(Name,42)), ("20%02d-%02d-%02d"):format(year,month,day));
		end
	end

	if(ns.profile[name].showCategory)then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",ACHIEVEMENT_CATEGORY_PROGRESS));
		tt:AddSeparator();
		local count=1;
		local categories = listCategories();
		for i=1, #categories do
			if(categories[i][3]==true)then
				tt:AddLine("  "..C("ltyellow",categories[i][2]), categories[i][4]);
			else
				local earned = categories[i][4] - session[i];
				local l = tt:AddLine("  "..C("ltyellow",categories[i][2]), categories[i][4].." / "..categories[i][3],earned>0 and C("ltgreen","+"..earned) or "");
				progressBar(tt,l,categories[i][4], categories[i][3]);
			end
		end
	end

	if(ns.profile[name].showWatchlist)then
		local limit = 48; -- 52
		local ids = {GetTrackedAchievements()};
		if(#ids>0)then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Watch list"]));
			tt:AddSeparator();
			for i=1, #ids do
				local id, Name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(ids[i]);
				local l = tt:AddLine(C("ltyellow",ns.strCut(Name,56)));
				local num = GetAchievementNumCriteria(id);
				local plainCriteria = {};
				for i=1, num do
					local criteriaString, criteriaType, criteriaCompleted, quantity, reqQuantity, charName, _flags, assetID, quantityString = GetAchievementCriteriaInfo(id, i);
					if ( bit.band(_flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) == EVALUATION_TREE_FLAG_PROGRESS_BAR ) then
						local color          = (ns.profile[name].showProgressBars) and "white" or "ltgray";
						local colorCompleted = (not ns.profile[name].showProgressBars) and "ltgreen" or "green";
						local l=tt:AddLine("  " .. C(criteriaCompleted and colorCompleted or color,ns.strWrap(description,limit,2)),quantityString);
						progressBar(tt,l,quantity,reqQuantity);
					elseif( not criteriaCompleted or ns.profile[name].showCompleted)then
						if ns.profile[name].criteriaPerLine then
							tt:AddLine("  " .. C(criteriaCompleted and "green" or "ltgray",ns.strWrap(criteriaString,limit,2)));
						else
							tinsert(plainCriteria,C(criteriaCompleted and "green" or "ltgray",criteriaString,limit,2));
						end
					end
				end
				if #plainCriteria>0 then
					tt:SetCell(tt:AddLine(),1,"  "..ns.strWrap(table.concat(plainCriteria,", "),limit*2,2),nil,nil,0);
				end
				if num==0 then
					tt:AddLine("  " ..  C(criteriaCompleted and "green" or "ltgray",ns.strWrap(description,limit,2)));
				end
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0)
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

local function tooltipOnHide()
	for i=1, #bars do
		bars[i]:SetParent(nil);
		bars[i]:ClearAllPoints();
		bars[i]:Hide();
	end
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"ACHIEVEMENT_EARNED"
	},
	config_defaults = {
		enabled = false,
		showLatest = true,
		showCategory = true,
		showWatchlist = true,
		showProgressBars = true,
		showCompleted = true,
		showPoints = true,
		showPointsSess = true,
		criteriaPerLine = false,
	},
	clickOptionsRename = {
		["menu"] = "open_menu"
	},
	clickOptions = {
		["menu"] = "OptionMenuCustom"
	}
};

ns.ClickOpts.addDefaults(module,"menu","_RIGHT");

function module.options()
	return {
		broker = {
			showPoints      = {type="toggle", order=1, name=L["OptAchievBrokerPoints"],     desc=L["OptAchievBrokerPointsDesc"]},
			showPointsSess  = {type="toggle", order=2, name=L["OptAchievBrokerPointsSess"], desc=L["OptAchievBrokerPointsSessDesc"]},
		},
		tooltip = {
			showLatest       = {type="toggle", order=1, name=L["OptAchievLast"],       desc=L["OptAchievLastDesc"]},
			showCategory     = {type="toggle", order=2, name=L["OptAchievCat"],        desc=L["OptAchievCatDesc"]},
			showWatchlist    = {type="toggle", order=3, name=L["Watch list"],          desc=L["OptAchievWatchDesc"]},
			showProgressBars = {type="toggle", order=4, name=L["OptAchievBars"],       desc=L["OptAchievBarsDesc"]},
			showCompleted    = {type="toggle", order=5, name=L["OptAchievCompleted"],  desc=L["OptAchievCompletedDesc"]},
			criteriaPerLine  = {type="toggle", order=6, name=L["OptAchievCriteriaPL"], desc=L["OptAchievCriteriaPLDesc"]},
		}
	}
end

function module.OptionMenu(self,button,modName)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:AddConfig(name);
	ns.EasyMenu:AddEntry({separator=true});
	ns.EasyMenu:AddEntry({ label = C("yellow",L["Reset session earn/loss counter"]), func=resetSessionCounter, keepShown=false });
	ns.EasyMenu:ShowMenu(self);
end

-- function module.init() end

function module.onevent(self,event,...)
	if event=="BE_UPDATE_CFG" and (...) and (...):find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGIN" then
		resetSessionCounter()
	elseif ns.eventPlayerEnteredWorld then
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "RIGHT", "LEFT"},{false},{self},{OnHide=tooltipOnHide});
	createTooltip(tt);
	C_Timer.After(0.5,updateBars);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
