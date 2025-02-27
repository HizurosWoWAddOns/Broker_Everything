
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<2 then return end

-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Titles"; L[name] = PAPERDOLL_SIDEBAR_TITLES;
local ttName, ttColumns, tt, module = name.."TT", 6;
local newTitles,knownTitles = {}


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\inv_misc_note_02", coords={.05,.95,.05,.95}, size={64,64}}; --IconName::Titles--


-- some local functions --
--------------------------
local function PlayerTitleSort(a, b) return a.name < b.name; end

local createTooltip
local function setTitle(self,id)
	SetCurrentTitle(id)
	ns.hideTooltip(tt)
end

local function updateBroker()
	local txt = {};
	local current = GetCurrentTitle();
	if current > 0 then
		local title, playerTitle = GetTitleName(current);
		tinsert(txt,title)
	end
	(ns.LDB:GetDataObjectByName(module.ldbName) or {}).text = #txt>0 and table.concat(txt," ") or PLAYER_TITLE_NONE;
end

function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end

	tt:SetCell(tt:AddLine(),1,C("dkyellow",L[name]),tt:GetHeaderFont(),"CENTER",0);
	tt:AddSeparator(4,0,0,0,0);

	local current = GetCurrentTitle();
	local titles = GetKnownTitles();
	local numRows = ns.profile[name].ttRows; --ceil(numTitles/40);
	local curCell,line;
	table.sort(titles,PlayerTitleSort)

	local l=tt:AddLine();
	tt:SetCell(l,1,PLAYER_TITLE_NONE,nil,"CENTER",0) -- no title as separate line
	tt:SetLineScript(l,"OnMouseUp",setTitle,titles[1].id)
	tt:AddSeparator(1.1,.7,.7,.7);

	local index = 1;
	for i=2, #titles do
		if titles[i] and titles[i].name and not ns.profile[name]["title-"..titles[i].id] then
			curCell = index % numRows;
			if curCell==0 then
				curCell=numRows
			end
			if curCell==1 then
				line = tt:AddLine();
			end
			local title = titles[i].name;
			if titles[i].id==current then
				title = C("dkyellow",title)
			elseif newTitles[title] then
				title = C("ltgreen",title)
			end
			tt:SetCell(line,curCell,title)
			tt:SetCellScript(line,curCell,"OnMouseUp",setTitle,titles[i].id)
			index = index+1
		end
	end

	if ns.profile.GeneralOptions.showHints then
		--tt:AddSeparator(4,0,0,0,0)
		--ns.ClickOpts.ttAddHints(tt,name);
	end

	ns.roundupTooltip(tt);
end

local function optHideTitle(info,value)
	local key = info[#info];
	if value~=nil then
		ns.profile[name][key] = value==false and true or nil
	end
	return not ns.profile[name][key];
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		--"PLAYER_LOGIN",
		"PLAYER_ENTERING_WORLD",
		"KNOWN_TITLES_UPDATE",
		"UNIT_NAME_UPDATE",
	},
	config_defaults = {
		enabled = false,
		ttRows = 3,
		ttHideTitles = {}
	},
	clickOptionsRename = {},
	clickOptions = {
		--["menu"] = "OptionMenuCustom"
		--["ClearTitle"] = L["ClearTitle"]
	}
};

--ns.ClickOpts.addDefaults(module,"menu","_RIGHT");

local options
local function listOptTitles()
	local firstRun = knownTitles==nil
	if firstRun then
		knownTitles = {}
	end
	local titles,num = {},GetNumTitles()
	titles.desc = {type="description", order=1, name=L["TitlesShowDesc"]}
	for i=1, num do
		local tempName, playerTitle = GetTitleName(i);
		if tempName and IsTitleKnown(i) then
			titles["title-"..i] = {
				type = "toggle",
				order = 2,
				name = tempName,
				get = optHideTitle,
				set = optHideTitle,
				width = "half"
			}
			if not firstRun and not knownTitles[tempName] then
				newTitles[tempName] = true
			end
			knownTitles[tempName] = true;
		end
	end
	options.tooltip.ttShowTitles.args = titles
end

function module.options()
	options = {
		broker = {},
		tooltip = {
			ttRows = {type = "range", order=1, name=L["TitlesRow"], desc=L["TitlesRowDesc"], min=1, max=8, step=1},
			ttShowTitles = {
				type = "group", order = 2,
				name = L["TitlesShow"],
				args = {} -- filled by function
			}
		}
	};
	return options;
end

-- function module.OptionMenu(self,button,modName) end

-- function module.init() end

function module.onevent(self,event,...)
	if event=="BE_UPDATE_CFG" and (...) and (...):find("^ClickOpt") then
		--ns.ClickOpts.update(name);
		return;
	end
	if event=="PLAYER_LOGIN" or event=="KNOWN_TITLES_UPDATE" then
		listOptTitles()
	end
	if event=="PLAYER_ENTERING_WORLD" or (event=="UNIT_NAME_UPDATE" and (...)=="player") then
		updateBroker()
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "CENTER", "CENTER", "CENTER", "CENTER", "CENTER","CENTER","CENTER","CENTER"},{false},{self,mod=module},{OnHide=tooltipOnHide});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;

