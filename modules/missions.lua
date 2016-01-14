
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
local ldbName, ttName, ttColumns, tt, createMenu = name, name.."TT",6
local missions = {inprogress={},available={},completed={}}
local started = {}
local qualities = {"white","ff1eaa00","ff0070dd","ffa335ee","red"};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name]             = {iconfile="Interface\\Icons\\Achievement_RareGarrisonQuests_X", coords={0.1,0.9,0.1,0.9} }; --IconName::Missions--
I[name.."Follower"] = {iconfile="Interface\\Garrison\\GarrisonShipMapIcons", coordsStr="16:16:0:0:512:512:146:186:336:376" }; --IconName::MissionsFollower--
I[name.."Ship"]     = {iconfile="Interface\\Garrison\\GarrisonShipMapIcons", coordsStr="16:16:0:0:512:512:411:451:270:310" }; --IconName::MissionsShip--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show active and available missions for your followers."],
	--icon_suffix = "_Neutral",
	events = {
		"PLAYER_ENTERING_WORLD",
		"GARRISON_MISSION_LIST_UPDATE",
		"GARRISON_MISSION_STARTED",
		"GARRISON_MISSION_FINISHED"
	},
	updateinterval = 30,
	config_defaults = {
		showAvailable = true,
		showActive = true,
		showReady = true,
		showChars = true,
		showAllRealms = false,
		showAllFactions = true
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showChars",     label=L["Show characters"],          tooltip=L["Show a list of your characters with count of ready and active missions in tooltip"] },
		{ type="toggle", name="showReady",     label=L["Show ready missions"],      tooltip=L["Show ready missions in tooltip"] },
		{ type="toggle", name="showActive",    label=L["Show active missions"],     tooltip=L["Show active missions in tooltip"] },
		{ type="toggle", name="showAvailable", label=L["Show available missions"],  tooltip=L["Show available missions in tooltip"] },
		{ type="toggle", name="showAllRealms", label=L["Show all realms"], tooltip=L["Show characters from all realms in tooltip."] },
		{ type="toggle", name="showAllFactions", label=L["Show all factions"], tooltip=L["Show characters from all factions in tooltip."] },
	},
	clickOptions = {
		["1_open_garrison_report"] = {
			cfg_label = "Open garrison report",
			cfg_desc = "open the garrison report",
			cfg_default = "_LEFT",
			hint = "Open garrison report",
			func = function(self,button)
				local _mod=name;
				securecall("GarrisonLandingPage_Toggle");
			end
		},
		["2_open_menu"] = {
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

	if (Broker_EverythingDB[name].showChars) then
		tt:AddSeparator(4,0,0,0,0)
		local l=tt:AddLine( C("ltblue", L["Characters"]) ); -- 1
		if(IsShiftKeyDown())then
			tt:SetCell(l, 2, C("ltblue",L["Follower missions"].."|n"..L["completed"].." - "..L["next"].." / "..L["all"]), nil, "RIGHT", 3);
			tt:SetCell(l, 5, C("ltblue",L["Ship missions"].."|n"..L["completed"].." - "..L["next"].." / "..L["all"]), nil, "RIGHT", 2);
		else
			tt:SetCell(l, 2, C("ltblue",L["Follower missions"]) .."|n".. C("green",L["Completed"]) .." / ".. C("yellow",L["In progress"]), nil, "RIGHT", 3);
			tt:SetCell(l, 5, C("ltblue",L["Ship missions"])     .."|n".. C("green",L["Completed"]) .." / ".. C("yellow",L["In progress"]), nil, "RIGHT", 2);
		end
		tt:AddSeparator();
		local t=time();
		for i=1, #be_character_cache.order do
			local name_realm = be_character_cache.order[i];
			local v = be_character_cache[name_realm];
			local charName,realm=strsplit("-",name_realm);
			if (Broker_EverythingDB[name].showAllRealms~=true and realm~=ns.realm) or (Broker_EverythingDB[name].showAllFactions~=true and v.faction~=ns.player.faction) or (v.garrison[1]==nil) or (v.garrison[1]==0) then
				-- do nothing
			elseif(v.missions)then
				local faction = v.faction and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
				realm = realm~=ns.realm and C("dkyellow"," - "..ns.scm(realm)) or "";
				local l=tt:AddLine(C(v.class,ns.scm(charName)) .. realm .. faction );
				if(name_realm==ns.player.name_realm)then
					--- background highlight
				end
				local fm_completed,sm_completed,fm_progress,sm_progress,fm_next,sm_next,fm_all,sm_all = 0,0,0,0,0,0,0,0;
				for _,data in ipairs(v.missions)do
					if(type(data)=="table")then
						local endTime,Type=unpack(data);
						if(Type==1)then
							if(endTime<=t)then
								fm_completed=fm_completed+1;
							else
								fm_progress=fm_progress+1;
								if(fm_next==0 or (fm_next>0 and endTime<fm_next))then fm_next = endTime; end
								if(endTime>fm_all)then fm_all = endTime; end
							end
						else
							if(endTime<=t)then
								sm_completed=sm_completed+1;
							else
								sm_progress=sm_progress+1;
								if(sm_next==0 or (fm_next>0 and endTime<fm_next))then sm_next = endTime; end
								if(endTime>sm_all)then sm_all = endTime; end
							end
						end
					end
				end
				if(IsShiftKeyDown())then
					tt:SetCell(l, 2, (fm_next==0 and "−" or SecondsToTime(fm_next-t) ).." / "..(fm_all==0 and "−" or SecondsToTime(fm_all-t) ), nil, "RIGHT", 3);
					tt:SetCell(l, 5, (sm_next==0 and "−" or SecondsToTime(sm_next-t) ).." / "..(sm_all==0 and "−" or SecondsToTime(sm_all-t) ), nil, "RIGHT", 2);
				else
					tt:SetCell(l, 2, (fm_completed==0 and "−" or C("green",fm_completed)) .." / ".. (fm_progress==0 and "−" or C("yellow",fm_progress)), nil, "RIGHT", 3);
					tt:SetCell(l, 5, (sm_completed==0 and "−" or C("green",sm_completed)) .." / ".. (sm_progress==0 and "−" or C("yellow",sm_progress)), nil, "RIGHT", 2);
				end
				if(name_realm==ns.player.name_realm)then
					tt:SetLineColor(l, 0.1, 0.3, 0.6);
				end
			end
		end
	end

	local show = {Broker_EverythingDB[name].showReady,Broker_EverythingDB[name].showActive,Broker_EverythingDB[name].showAvailable};
	for mI,mD in ipairs({missions.completed,missions.inprogress,missions.available}) do
		if #mD>0 and show[mI]==true then
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
			tt:AddSeparator();
			for mi, md in ipairs(mD) do
				local duration_str = md["duration"];
				if (duration_title ~= "Time") then
					duration_str = SecondsToTime(md["missionEndTime"]-time()) --md["timeLeft"];
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

				local tex = md.followerTypeID==2 and I[name.."Ship"] or I[name.."Follower"];

				l,c = tt:AddLine(
					C(color, "|T"..tex.iconfile..":"..tex.coordsStr.."|t " .. md["name"]),
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
			end
			count = count + 1;
		end
	end

	if (count==0) then
		tt:AddLine(L["No missions found..."]);
	elseif (Broker_EverythingDB.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		if(Broker_EverythingDB[name].showChars)then
			local line = tt:AddLine()
			tt:SetCell(line,1,C("copper",L["Hold shift"]).." || "..C("green",L["Show time to next and all missions completed in characters list"]),nil,nil,6);
		end
		if(Broker_EverythingDB[name].showReady or Broker_EverythingDB[name].showActive)then
			local line = tt:AddLine()
			tt:SetCell(line,1,C("copper",L["Hold shift"]).." || "..C("green",L["Show followers on missions"]),nil,nil,6);
		end
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end

end

local function update()
	local obj = ns.LDB:GetDataObjectByName(ldbName)
	local tmp = C_Garrison.GetInProgressMissions() or {};
	--missions.completed = C_Garrison.GetCompleteMissions() or {};
	missions.available  = C_Garrison.GetAvailableMissions() or {};
	missions.inprogress,missions.completed = {},{};

	local _time,_ = time();

	-- fix error for user with disabled garrison module.
	if(be_character_cache[ns.player.name_realm].garrison==nil)then
		be_character_cache[ns.player.name_realm].garrison={C_Garrison.GetGarrisonInfo(),0,{0,0},{}};
	end

	be_character_cache[ns.player.name_realm].missions={}; -- wipe
	local mCache=be_character_cache[ns.player.name_realm].missions;

	for i,v in ipairs(tmp) do
		_,_,_,_,_,_,v.isExhausting = C_Garrison.GetMissionInfo(v.missionID);
		if(v.missionEndTime-_time>0)then
			tinsert(missions.inprogress,v);
		else
			tinsert(missions.completed,v);
		end
		tinsert(mCache,{v.missionEndTime,v.followerTypeID});
	end

	for i,v in ipairs(missions.available) do
		_,_,_,_,_,_,missions.available[i].isExhausting = C_Garrison.GetMissionInfo(v.missionID);
	end

	obj.text = ("%s/%s/%s"):format(C("ltblue",#missions.completed),C("yellow",#missions.inprogress),C("green",#missions.available));
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	else
		update()
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

	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT", "LEFT", "CENTER", "CENTER","RIGHT")
	makeTooltip(tt)
	ns.createTooltip(self, tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end



