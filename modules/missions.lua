
-- module independent variables --
----------------------------------
local addon, ns = ...
if ns.client_version<6 then return end
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Missions" -- GARRISON_MISSIONS L["ModDesc-Missions"]
local ttName, ttColumns,ttColumns_default,ttColumnsMin, tt, module = name.."TT",6,6,2
local missions,started,counter = {},{},{};
local qualities = {"white","ff1eaa00","ff0070dd","ffa335ee","red"};
local garrLevel,syLevel,ohLevel = 0,0,0;
local expansions = {
	-- { <expansionIndex>, <internalTypeString>, <localizedLabel>, <garrison-/follower-type>, <garrisonLevelFunction> }
	{index=5, typeStr="followers",     label=GARRISON_FOLLOWERS,           type="6_0", levelFnc=C_Garrison.GetGarrisonInfo},
	{index=5, typeStr="ships",         label=GARRISON_SHIPYARD_FOLLOWERS,  type="6_2", levelFnc=function() return (C_Garrison.GetOwnedBuildingInfoAbbrev(98) or 204)-204; end},
	{index=6, typeStr="champions",     label=FOLLOWERLIST_LABEL_CHAMPIONS, type="7_0", levelFnc=C_Garrison.GetGarrisonInfo},
	{index=7, typeStr="champions_bfa", label=FOLLOWERLIST_LABEL_CHAMPIONS, type="8_0", levelFnc=C_Garrison.GetGarrisonInfo},
	{index=8, typeStr="champions_sl",  label=FOLLOWERLIST_LABEL_CHAMPIONS, type="9_0", levelFnc=C_Garrison.GetGarrisonInfo},
};


-- register icon names and default files --
-------------------------------------------
I[name]             = {iconfile="Interface\\Icons\\Achievement_RareGarrisonQuests_X", coords={0.1,0.9,0.1,0.9} }; --IconName::Missions--
I[name.."Follower"] = {iconfile="Interface\\Garrison\\GarrisonShipMapIcons", coordsStr="16:16:0:0:512:512:146:186:336:376" }; --IconName::MissionsFollower--
I[name.."Ship"]     = {iconfile="Interface\\Garrison\\GarrisonShipMapIcons", coordsStr="16:16:0:0:512:512:411:451:270:310" }; --IconName::MissionsShip--


-- some local functions --
--------------------------
local function stripTime(str,tag)
	local h, m, s = str:match("(%d+)");
end

local function Counter(missions)
	local c,t = {inprogress=0, completed=0},time();
	for i=1, #missions do
		local k = missions[i]-t>0 and "inprogress" or "completed";
		c[k] = c[k] + 1;
	end
	return c;
end

local function updateBroker()
	(ns.LDB:GetDataObjectByName(module.ldbName) or {}).text = ("%s/%s/%s"):format(C("ltblue",counter.completed),C("yellow",counter.inprogress),C("green",counter.available));
end

local function updateMissions()
	local t,_ = time();
	ns.toon.missions = {}; -- wipe
	counter={completed=0,inprogress=0,available=0};
	for e=1, #expansions do
		local exp = expansions[e];
		if exp.type then
			exp.level = exp.levelFnc(Enum.GarrisonType["Type_"..exp.type]) or 0;
			missions[exp.typeStr] = {inprogress={},available={},completed={}};
			local m=missions[exp.typeStr];
			local tmp = C_Garrison.GetInProgressMissions(Enum.GarrisonFollowerType["FollowerType_"..exp.type]) or {};
			for i=1, #tmp do
				tinsert(m[tmp[i].missionEndTime-t>0 and "inprogress" or "completed"],tmp[i]);
				tinsert(ns.toon.missions,tmp[i].missionEndTime);
			end
			m.available = C_Garrison.GetAvailableMissions(Enum.GarrisonFollowerType["FollowerType_"..exp.type]) or {};
			for i=1, #m.available do
				local info = C_Garrison.GetMissionDeploymentInfo(m.available[i].missionID);
				m.available[i].isExhausting = info.isExhausting;
			end
			counter.completed=counter.completed+#m.completed;
			counter.inprogress=counter.inprogress+#m.inprogress;
			counter.available=counter.available+#m.available;
		end
	end
	updateBroker();
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end

	local act,l,c = {};
	local pipe = C("gray","   ||   ");
	tt:AddHeader(C("dkyellow",GARRISON_MISSIONS))

	local show = {
		{"completed", "Missions completed",  "ltblue",ns.profile[name].showReady},
		{"inprogress","Missions in progress","yellow",ns.profile[name].showActive},
		{"available", "Missions available",  "green", ns.profile[name].showAvailable},
	};

	for i=1, #show do
		if show[i][4] then
			tt:AddSeparator(4,0,0,0,0);
			local duration_title = show[i][1]=="inprogress" and "Duration" or "Time";
			local count,c,l=0,2,tt:AddLine(C(show[i][3],L[show[i][2]]));
			if ns.profile[name].showMissionLevel then         tt:SetCell(l,c,C("ltblue",LEVEL),nil,"RIGHT");          c=c+1; end
			if ns.profile[name].showMissionType then          tt:SetCell(l,c,C("ltblue",TYPE),nil,"LEFT");            c=c+1; end
			if ns.profile[name].showMissionItemLevel then     tt:SetCell(l,c,C("ltblue",L["iLevel"]),nil,"CENTER");   c=c+1; end
			if ns.profile[name].showMissionFollowerSlots then tt:SetCell(l,c,C("ltblue",L["Follower"]),nil,"CENTER"); c=c+1; end
			tt:SetCell(l,c,C("ltblue",L[duration_title]),nil,"RIGHT");
			tt:AddSeparator();

			for e=1, #expansions do
				local exp = expansions[e];
				if ns.profile[name]["showExpansion"..exp.index] and missions and missions[exp.typeStr] and missions[exp.typeStr][show[i][1]] and #missions[exp.typeStr][show[i][1]]>0 then
					local tbl = missions[exp.typeStr][show[i][1]];
					-- expansion header
					tt:SetCell(tt:AddLine(),1,C("ltgray",exp.label.." (".._G["EXPANSION_NAME"..exp.index]..")"),nil,"LEFT",0);
					for i=1, #tbl do
						local md=tbl[i];
						local duration_str = md["duration"];
						if (duration_title ~= "Time") then
							duration_str = SecondsToTime(md["missionEndTime"]-time());
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

						local c = 2;
						local l = tt:AddLine(C(color, "|T"..tex.iconfile..HEADER_COLON..tex.coordsStr.."|t " .. ns.strCut(md["name"],32)));
						if ns.profile[name].showMissionLevel then         tt:SetCell(l,c,C(color_lvl,lvl),nil,"RIGHT"); c=c+1; end
						if ns.profile[name].showMissionType then          tt:SetCell(l,c,C(color,md["type"]),nil,"LEFT"); c=c+1; end
						if ns.profile[name].showMissionItemLevel then     tt:SetCell(l,c,C(color,(md["iLevel"]>0 and md["iLevel"] or "-")),nil,"CENTER"); c=c+1; end
						if ns.profile[name].showMissionFollowerSlots then tt:SetCell(l,c,C(color,md["numFollowers"]),nil,"CENTER"); c=c+1; end
						tt:SetCell(l,c,C(color,duration_str),nil,"RIGHT");

						if (IsShiftKeyDown()) and (type(md.followers)=="table") and (#md.followers>0) then
							local f,d,c,_ = {};
							for i,v in ipairs(md.followers) do
								d = C_Garrison.GetFollowerInfo(v);
								_,c = strsplit("-",d.classAtlas);
								tinsert(f,C(c,d.name).." "..C(qualities[d.quality],"("..d.level..")"));
							end
							if (#f>0) then
								l,c = tt:AddLine();
								tt:SetCell(l,1, table.concat(f,", "), nil, "LEFT", ttColumns);
								tt.lines[l].cells[c].fontString:SetNonSpaceWrap(true);
								tt:AddSeparator()
							end
						end

					end -- for #tbl
					count=count+1;
				end -- if #tbl>0
			end -- for #expansions
			if count==0 then
				tt:AddLine(C("gray",L["No missions found..."]));
			end
		end -- if show[2]
	end -- for #show

	if ns.profile[name].showChars then
		tt:AddSeparator(4,0,0,0,0);
		local n,t=0,time();
		local l=tt:AddLine(C("ltblue",CHARACTER));
		tt:SetCell(l,2,
			(IsShiftKeyDown() and GOAL_COMPLETED.." - "..C("green",L["next"]).." / "..C("yellow",SPELL_TARGET_TYPE12_DESC) or C("green",GOAL_COMPLETED).." / "..C("yellow",L["In progress"])),
			nil,"RIGHT",0);
		tt:AddSeparator();
		for index,toonNameRealm,toonName,toonRealm,toonData,isCurrent in ns.pairsToons(name,{currentFirst=true,forceSameRealm=true}) do
			if toonData.missions and #toonData.missions>0 then
				local num = Counter(toonData.missions);
				local l = tt:AddLine(C(toonData.class,ns.scm(toonName)) .. ns.showRealmName(name,toonRealm) .. (toonData.faction and " |TInterface\\PVPFrame\\PVP-Currency-"..toonData.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "") );
				tt:SetCell(l,2, C("green",num.completed).."/"..C("yellow",num.inprogress),nil,"RIGHT",0);
				n=n+1;
			end
		end
		if n==0 then
			tt:SetCell(tt:AddLine(),1,C("gray",L["No missions found..."]),nil,nil,0);
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0)
		if act.completed or act.inprogress then
			if ns.profile[name].showReady or ns.profile[name].showActive then
				ns.AddSpannedLine(tt,C("copper",L["Hold shift"]).." || "..C("green",L["Show followers on missions"]));
			end
		end
		ns.ClickOpts.ttAddHints(tt,name);
	end

	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"GARRISON_MISSION_LIST_UPDATE",
		"GARRISON_MISSION_STARTED",
		"GARRISON_MISSION_FINISHED"
	},
	config_defaults = {
		enabled = false,
		showAvailable = true,
		showActive = true,
		showReady = true,


		showMissionType = true,
		showMissionLevel = true,
		showMissionItemLevel = true,
		showMissionFollowerSlots = true,
	},
	clickOptionsRename = {
		["garrreport"] = "1_open_garrison_report",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["garrreport"] = "GarrisonReport",
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	garrreport = "_LEFT",
	menu = "_RIGHT"
});

do
	local misc,o = {},1;
	for e=1, #expansions do
		local key = "showExpansion"..expansions[e].index;
		if not misc[key] then
			local name = _G["EXPANSION_NAME"..expansions[e].index];
			misc[key] = { type="toggle", order=o, name=name, desc=L["MissionsExpansionsDesc"]:format(name) }
			module.config_defaults[key] = true;
			o = o+1;
		end
	end
	function module.options()
		return {
			broker = nil,
			tooltip = {
				showChars={1,true},
				showAllFactions=2,
				showRealmNames=3,
				showCharsFrom=4,

				showReady={ type="toggle", order=5, name=L["Show ready missions"],     desc=L["Show ready missions in tooltip"] },
				showActive={ type="toggle", order=6, name=L["Show active missions"],    desc=L["Show active missions in tooltip"] },
				showAvailable={ type="toggle", order=7, name=L["Show available missions"], desc=L["Show available missions in tooltip"] },

				showMissionType={ type="toggle", order=8, name=L["Show mission type"],   desc=L["Show mission type in tooltip."] },
				showMissionLevel={ type="toggle", order=9, name=L["Show mission level"],  desc=L["Show mission level in tooltip."] },
				showMissionItemLevel={ type="toggle", order=10, name=L["Show mission iLevel"], desc=L["Show mission item level in tooltip."] },
				showMissionFollowerSlots={ type="toggle", order=11, name=L["Show follower slots"], desc=L["Show mission follower slots in tooltip."] },
			},
			misc = misc,
		}
	end
end

-- function module.init() end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGIN" then
		if ns.toon.missions==nil then
			ns.toon.missions={};
		end
	elseif ns.eventPlayerEnteredWorld then
		C_Timer.After(0.314159,updateMissions);
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(self) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttColumns=ttColumnsMin;
	if ns.profile[name].showMissionLevel then         ttColumns=ttColumns+1; end
	if ns.profile[name].showMissionType then          ttColumns=ttColumns+1; end
	if ns.profile[name].showMissionItemLevel then     ttColumns=ttColumns+1; end
	if ns.profile[name].showMissionFollowerSlots then ttColumns=ttColumns+1; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "LEFT", "CENTER", "CENTER","RIGHT"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
