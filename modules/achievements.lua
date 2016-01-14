
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Achievements"; L["Achievements"] = ACHIEVEMENTS;
local ldbName, ttName, ttColumns, tt, createMenu = name, name.."TT", 2
local categoryIds,bars,count = {92, 96, 97, 95, 168, 169, 201, 15165, 155, 15117, 15246, 15237},{},0;


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\achievementframe\\UI-Achievement-Progressive-Shield-NoPoints", coords={.15,.55,.15,.55}, size={64,64}};


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Display a list of your running auctions"],
	--icon_suffix = "",
	events = {},
	updateinterval = false, -- 10
	config_defaults = {
		showLatest = true,
		showCategory = true,
		showWatchlist = true,
		showProgressBars = true,
		showCompleted = true
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=true },
		{ type="separator" },
		{ type="toggle", name="showLatest",       label=L["Show latest achievements"],    tooltip=L["Show 5 latest earned achievements in tooltip"]},
		{ type="toggle", name="showCategory",     label=L["Show achievement categories"], tooltip=L["Show achievement categories in tooltip"]},
		{ type="toggle", name="showWatchlist",    label=L["Show watch list"],             tooltip=L["Show watch list in tooltip"]},
		{ type="toggle", name="showProgressBars", label=L["Show progress bars"],          tooltip=L["Show progress bars in tooltip"]},
		{ type="toggle", name="showCompleted",    label=L["Show completed criteria"],     tooltip=L["Show completed criteria in watch list"]},
	},
	clickOptions = {
		["open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "_RIGHT",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self)
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

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

local function progressBar(tt, l, low, high)
	count=count+1;
	if(not Broker_EverythingDB[name].showProgressBars)then
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
	bars[count]:SetPoint("TOPLEFT",tt.lines[l].cells[1],"TOPLEFT");
	bars[count]:SetPoint("BOTTOMRIGHT",tt.lines[l].cells[ttColumns],"BOTTOMRIGHT");
	bars[count]:Show();
	bars[count].cur = low;
	bars[count].all = high;
	bars[count].percent = low / high;
end

local function getTooltip()
	tt:Clear();
	tt:AddHeader(C("dkyellow",L[name]));
	count=0;

	if(Broker_EverythingDB[name].showLatest)then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",LATEST_UNLOCKED_ACHIEVEMENTS));
		tt:AddSeparator();
		local latest = {GetLatestCompletedAchievements()};
		for i=1, #latest do
			local id, Name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(latest[i]);
			tt:AddLine("  "..C("ltyellow",Name), ("20%02d-%02d-%02d"):format(year,month,day));
		end
	end

	if(Broker_EverythingDB[name].showCategory)then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",ACHIEVEMENT_CATEGORY_PROGRESS));
		tt:AddSeparator();
		local count=1;
		local categories = listCategories();
		for i=1, #categories do
			if(categories[i][3]==true)then
				tt:AddLine("  "..C("ltyellow",categories[i][2]), categories[i][4]);
			else
				local l = tt:AddLine("  "..C("ltyellow",categories[i][2]), categories[i][4].." / "..categories[i][3]);
				progressBar(tt,l,categories[i][4], categories[i][3]);
			end
		end
	end

	if(Broker_EverythingDB[name].showWatchlist)then
		local ids = {GetTrackedAchievements()};
		if(#ids>0)then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Watch list"]));
			tt:AddSeparator();
			for i=1, #ids do
				local id, Name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(ids[i]);
				local l = tt:AddLine(C("ltyellow",Name));
				local num = GetAchievementNumCriteria(id);
				for i=1, num do
					local criteriaString, criteriaType, criteriaCompleted, quantity, reqQuantity, charName, _flags, assetID, quantityString = GetAchievementCriteriaInfo(id, i);
					if ( bit.band(_flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) == EVALUATION_TREE_FLAG_PROGRESS_BAR ) then
						local color          = (Broker_EverythingDB[name].showProgressBars) and "white" or "ltgray";
						local colorCompleted = (not Broker_EverythingDB[name].showProgressBars) and "ltgreen" or "green";
						local l=tt:AddLine("  " .. C(criteriaCompleted and colorCompleted or color,description),quantityString);
						progressBar(tt,l,quantity,reqQuantity);
					elseif( not criteriaCompleted or Broker_EverythingDB[name].showCompleted)then
						tt:AddLine("  " .. C(criteriaCompleted and "green" or "ltgray",criteriaString));
					end
				end
				if num==0 then
					tt:AddLine("  " ..  C(criteriaCompleted and "green" or "ltgray",description));
				end
			end
		end
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name;
end

-- ns.modules[name].onevent = function(self,event,...) end
-- ns.modules[name].onupdate = function(self,elapsed) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT", "CENTER", "RIGHT", "LEFT");
	tt:SetScript("OnHide",function()
		for i=1, #bars do
			bars[i]:SetParent(nil);
			bars[i]:ClearAllPoints();
			bars[i]:Hide();
		end
	end);
	getTooltip(self,tt)
	ns.createTooltip(self,tt)
	C_Timer.After(0.5,updateBars);
end

ns.modules[name].onleave = function(self)
	if(tt)then
		ns.hideTooltip(tt,ttName,false,true);
	end
end

--[[ ns.modules[name].onclick = function(self,button)
	if button=="LeftButton" then
		
	elseif button=="RightButton" then
		if IsShiftKeyDown() then
		else
		end
	end
end ]]

-- ns.modules[name].ondblclick = function(self,button) end

