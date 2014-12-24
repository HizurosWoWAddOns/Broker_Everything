
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I

if ns.build<60000000 then return end

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Missions" -- L["Missions"]
local ldbName = name
local tt,createMenu
local ttName = name.."TT"
local missions = {inprogress={},available={},completed={}}
local started = {}
local qualities = {"white","ff1eaa00","ff0070dd","ffa335ee"};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name]  = {iconfile="Interface\\Icons\\Achievement_RareGarrisonQuests_X", coords={0.1,0.9,0.1,0.9} }; --IconName::Missions--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show active and available missions for your followers."],
	--icon_suffix = "_Neutral",
	enabled = false,
	events = {
		"PLAYER_ENTERING_WORLD",
		"GARRISON_MISSION_LIST_UPDATE",
		"GARRISON_MISSION_STARTED",
		"GARRISON_MISSION_FINISHED"
	},
	updateinterval = 30,
	config_defaults = {
		chars_progress = {}
	},
	config_allowed = {},
	config = { { type="header", label=L[name], align="left", icon=I[name] } },
	clickOptions = {
		["1_open_garrison_report"] = {
			cfg_label = "Open garrison report",
			cfg_desc = "open the garrison report",
			cfg_default = "__NONE",
			hint = "Open garrison report",
			func = function(self,button)
				local _mod=name;
				securecall("GarrisonLandingPage_Toggle");
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "__NONE",
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
	if (tt~=nil) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function stripTime(str,tag)
	local h, m, s = str:match("(%d+)");
end

local function makeTooltip(tt)
	tt:Clear()
	local labels,colors,count,l,c = {"Missions completed","Missions in progress","Missions available"},{"ltblue","yellow","green"},0
	tt:AddHeader(C("dkyellow",L[name]))

	for mI,mD in ipairs({missions.completed,missions.inprogress,missions.available}) do
		if #mD>0 then
			local duration_title = "Time";
			tt:AddSeparator(4,0,0,0,0)
			if (missions.inprogress == mD) then
				duration_title = "Duration";
			end
			tt:AddLine(
				C(colors[mI],L[labels[mI]]),
				C("ltblue",L["Level"]),
				C("ltblue",L["Type"]),
				C("ltblue",L["iLevel"]),
				C("ltblue",L["Follower"]),
				C("ltblue",L[duration_title])
			)
			tt:AddSeparator()
			for mi, md in ipairs(mD) do
				local duration_str = md["duration"];
				if (duration_title ~= "Time") then
					duration_str = md["timeLeft"];
				end

				local color,color_lvl,lvl = "white","white",md["level"];
				if (md["isElite"]) then
					lvl = "++"..lvl
					color_lvl="violet"
				elseif (md["isRare"]) then
					lvl = "+"..lvl
					color_lvl = "ff00eeff"
				end
					
				if (md["isExhausting"]) then
					color = "orange"
					if (color_lvl=="white") then
						color_lvl = color
					end
				end

				l,c = tt:AddLine(
					C(color,md["name"]),
					C(color_lvl,lvl),
					C(color,md["type"]),
					C(color,(md["iLevel"]>0 and md["iLevel"] or "-")),
					C(color,md["numFollowers"]),
					C(color,duration_str)
				)

				if (IsShiftKeyDown()) and (type(md.followers)=="table") and (#md.followers>0) then
					local f,d,c,_ = {};
					for i,v in ipairs(md.followers) do
						d = C_Garrison.GetFollowerInfo(v);
						_,c = strsplit("-",d.classAtlas);
						tinsert(f,C(c,d.name).." "..C(qualities[d.quality],"("..d.level..")"));
					end
					if (#f>0) then
						l,c = tt:AddLine();
						tt:SetCell(l,1, table.concat(f,", "), nil, "LEFT", 6);
						tt.lines[l].cells[c].fontString:SetNonSpaceWrap(true);
						tt:AddSeparator()
					end
				end
				--stripTime(duration_str);
			end
			count = count + 1;
		end
	end

	if (count==0) then
		tt:AddLine(L["No missions found..."]);
	elseif (Broker_EverythingDB.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		local line, column = tt:AddLine()
		tt:SetCell(line,1,C("copper",L["Hold shift"]).." || "..C("green",L["Show followers on missions"]),nil,nil,6);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end

	if (Broker_EverythingDB[name].chars_progress) then
		--?
	end


end --LoadAddOn("Blizzard_GarrisonUI")

local function update()
	local location, xp, environment, environmentDesc, environmentTexture, locPrefix, isExhausting, enemies
	local obj = ns.LDB:GetDataObjectByName(ldbName)
	missions.inprogress = C_Garrison.GetInProgressMissions() or {};
	missions.available  = C_Garrison.GetAvailableMissions() or {};
	missions.completed  = C_Garrison.GetCompleteMissions() or {};

	--Broker_EverythingDB[name].chars_progress[C(ns.player.class, ns.player.name.." - "..ns.realm)] = {
	--	inprogress = #missions.inprogress,
	--	completed = #missions.completed
	--}

	local cIds = {}
	for i,v in ipairs(missions.completed) do
		cIds[v["missionID"]..v["name"]] = true;
		missions.completed[i].isExhausting = select(7,C_Garrison.GetMissionInfo(v.missionID))
	end
	local tmp = {}
	for i,v in pairs(missions.inprogress) do
		if (not cIds[v["missionID"]..v["name"]]) then
			tinsert(tmp,v)
		end
		missions.inprogress[i].isExhausting = select(7,C_Garrison.GetMissionInfo(v.missionID))
	end
	for i,v in pairs(missions.available) do
		missions.available[i].isExhausting = select(7,C_Garrison.GetMissionInfo(v.missionID))
	end

	missions.inprogress = tmp
	obj.text = ("%s/%s/%s"):format(C("ltblue",#missions.completed),C("yellow",#missions.inprogress),C("green",#missions.available));

	--XYDB.missions = missions
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	update()
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end
end

ns.modules[name].onupdate = function(self)
	update()
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(self) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	tt = ns.LQT:Acquire(name.."TT", 6, "LEFT", "RIGHT", "LEFT", "CENTER", "CENTER","RIGHT")
	makeTooltip(tt)
	ns.createTooltip(self, tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end



