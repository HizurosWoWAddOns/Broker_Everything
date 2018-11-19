
-- module independent variables --
----------------------------------
local addon, ns = ...
if ns.build<60000000 then return end
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Missions" -- GARRISON_MISSIONS L["ModDesc-Missions"]
local ttName, ttColumns,ttColumns_default, tt, module = name.."TT",6,6
local missions,started = {},{};
local qualities = {"white","ff1eaa00","ff0070dd","ffa335ee","red"};
local garrLevel,syLevel,ohLevel = 0,0,0;


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

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end
	local labels,colors,l,c = {"Missions completed","Missions in progress","Missions available"},{"ltblue","yellow","green"};
	local pipe = C("gray","   ||   ");
	tt:AddHeader(C("dkyellow",GARRISON_MISSIONS))

	if (ns.profile[name].showChars) then
		tt:AddSeparator(4,0,0,0,0)
		local _ttColumns = 1;
		if ns.profile[name].showMissionLevel then         _ttColumns=_ttColumns+1; end
		if ns.profile[name].showMissionType then          _ttColumns=_ttColumns+1; end
		if ns.profile[name].showMissionItemLevel then     _ttColumns=_ttColumns+1; end
		if ns.profile[name].showMissionFollowerSlots then _ttColumns=_ttColumns+1; end

		local l=tt:AddLine( C("ltblue",CHARACTER) ); -- 1
		if(IsShiftKeyDown())then
			tt:SetCell(l,2,C("ltblue",GARRISON_FOLLOWERS)..pipe..C("ltblue",GARRISON_SHIPYARD_FOLLOWERS)..( ns.build>70000000 and pipe..C("ltblue",FOLLOWERLIST_LABEL_CHAMPIONS) or "" ).."|n"..
				GOAL_COMPLETED.." - "..C("green",L["next"]).." / ".. C("yellow",SPELL_TARGET_TYPE12_DESC),nil, "RIGHT", _ttColumns);
		else
			tt:SetCell(l,2,C("ltblue",GARRISON_FOLLOWERS)..pipe..C("ltblue",GARRISON_SHIPYARD_FOLLOWERS)..( ns.build>70000000 and pipe..C("ltblue",FOLLOWERLIST_LABEL_CHAMPIONS) or "" ).."|n"..
				C("green",GOAL_COMPLETED).." / ".. C("yellow",L["In progress"]),nil, "RIGHT", _ttColumns);
		end
		tt:AddSeparator();
		local t=time();
		for i=1, #Broker_Everything_CharacterDB.order do
			local name_realm = Broker_Everything_CharacterDB.order[i];
			local v,_ = Broker_Everything_CharacterDB[name_realm];
			local charName,realm=strsplit("-",name_realm,2);
			if v.missions and v.missions.followers and ns.showThisChar(name,realm,v.faction) then
				local faction = v.faction and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
				local l=tt:AddLine(C(v.class,ns.scm(charName)) .. ns.showRealmName(name,realm) .. faction );
				local get = function(Type)
					local c,p,n,l=0,0,0,0; -- completed, progress, time next, time last
					if type(v.missions[Type])=="table" then
						for _,eT in ipairs(v.missions[Type])do
							if(eT<=t)then
								c=c+1;
							else
								p=p+1;
								if n==0 or (n>0 and eT<n) then n=eT; end
								if eT>l then l=eT; end
							end
						end
					end
					return c,p,n,l;
				end;

				local fm_completed, fm_progress, fm_next, fm_all = get("followers");
				local sm_completed, sm_progress, sm_next, sm_all = get("ships");
				local cm_completed, cm_progress, cm_next, cm_all = 0,0,0,0;
				if ns.build>70000000 then
					  cm_completed, cm_progress, cm_next, cm_all = get("champions");
				end

				if IsShiftKeyDown() then
					tt:SetCell(l,2,                    C("ltgray", GARRISON_FOLLOWERS)           .. " " ..C("green", fm_next==0 and "−" or SecondsToTime(fm_next-t) ).." / "..C("yellow",fm_all==0 and "−" or SecondsToTime(fm_all-t))..
						"|n" ..                        C("ltgray", GARRISON_SHIPYARD_FOLLOWERS)  .. " " ..C("green", sm_next==0 and "−" or SecondsToTime(sm_next-t) ).." / "..C("yellow",sm_all==0 and "−" or SecondsToTime(sm_all-t))..
						(ns.build>70000000 and "|n" .. C("ltgray", FOLLOWERLIST_LABEL_CHAMPIONS) .. " " ..C("green", cm_next==0 and "−" or SecondsToTime(cm_next-t) ).." / "..C("yellow",cm_all==0 and "−" or SecondsToTime(cm_all-t)) or ""),
						nil,"RIGHT",_ttColumns);
				else
					tt:SetCell(l,2,                   C("green",fm_completed==0 and "−" or fm_completed) .." / ".. C("yellow",fm_progress==0 and "−" or fm_progress)..
						pipe ..                       C("green",sm_completed==0 and "−" or sm_completed) .." / ".. C("yellow",sm_progress==0 and "−" or sm_progress)..
						(ns.build>70000000 and pipe.. C("green",cm_completed==0 and "−" or cm_completed) .." / ".. C("yellow",cm_progress==0 and "−" or cm_progress) or ""),
						nil,"RIGHT",_ttColumns);
				end

				if(name_realm==ns.player.name_realm)then
					tt:SetLineColor(l, 0.1, 0.3, 0.6);
				end
				if IsShiftKeyDown() then
					tt:AddSeparator(1,.7,.7,.7,.8);
				end
			end
		end
	end

	local show = {ns.profile[name].showReady,ns.profile[name].showActive,ns.profile[name].showAvailable};
	local lst = {{"followers",GARRISON_FOLLOWERS}};
	local title = true;
	local subTitle = false;
	if syLevel>0 then
		tinsert(lst,{"ships",GARRISON_SHIPYARD_FOLLOWERS});
		subTitle = true;
	end
	if ohLevel>0 then
		tinsert(lst,1,{"champions",FOLLOWERLIST_LABEL_CHAMPIONS});
		subTitle = true;
	end

	local act = {};
	for mI,aType in ipairs({"completed","inprogress","available"}) do
		if show[mI]==true then
			tt:AddSeparator(4,0,0,0,0);
			local duration_title = aType=="inprogress" and "Duration" or "Time";
			local count,c,l=0,2,tt:AddLine(C(colors[mI],L[labels[mI]]));
			if ns.profile[name].showMissionLevel then         tt:SetCell(l,c,C("ltblue",LEVEL),nil,"RIGHT");          c=c+1; end
			if ns.profile[name].showMissionType then          tt:SetCell(l,c,C("ltblue",TYPE),nil,"LEFT");            c=c+1; end
			if ns.profile[name].showMissionItemLevel then     tt:SetCell(l,c,C("ltblue",L["iLevel"]),nil,"CENTER");   c=c+1; end
			if ns.profile[name].showMissionFollowerSlots then tt:SetCell(l,c,C("ltblue",L["Follower"]),nil,"CENTER"); c=c+1; end
			tt:SetCell(l,c,C("ltblue",L[duration_title]),nil,"RIGHT");
			tt:AddSeparator();

			for _,fType in ipairs(lst)do -- follower types
				local Type,Label = unpack(fType);
				if missions[Type] and missions[Type][aType] and #missions[Type][aType]>0 then
					act[aType]=true;
					tt:AddLine(C("ltgray",Label));
					for mi, md in ipairs(missions[Type][aType]) do
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
						local l = tt:AddLine(C(color, "|T"..tex.iconfile..":"..tex.coordsStr.."|t " .. ns.strCut(md["name"],32)));
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
					end
					count=count+1;
				end
			end

			if count==0 then
				tt:AddLine(C("gray",L["No missions found..."]));
			end
		end
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		if act.completed or act.inprogress then
			if(ns.profile[name].showChars)then
				ns.AddSpannedLine(tt,C("copper",L["Hold shift"]).." || "..C("green",L["Show time in characters list"]));
			end
			if(ns.profile[name].showReady or ns.profile[name].showActive)then
				ns.AddSpannedLine(tt,C("copper",L["Hold shift"]).." || "..C("green",L["Show followers on missions"]));
			end
		end
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

local function update()
	-- LE_FOLLOWER_TYPE_GARRISON_6_0 // LE_FOLLOWER_TYPE_SHIPYARD_6_2 // LE_FOLLOWER_TYPE_GARRISON_7_0
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local completed, inprogress, available = 0,0,0;

	for _,Type in ipairs({"followers","ships","champions"})do
		local followerType,Table;

		if Type=="followers" and LE_FOLLOWER_TYPE_GARRISON_6_0 then
			garrLevel = C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_6_0) or 0;
			followerType = LE_FOLLOWER_TYPE_GARRISON_6_0;
		elseif Type=="ships" and LE_FOLLOWER_TYPE_SHIPYARD_6_2 then
			local lvl = C_Garrison.GetOwnedBuildingInfoAbbrev(98);
			syLevel = lvl~=nil and (lvl - 204) or 0;
			followerType = LE_FOLLOWER_TYPE_SHIPYARD_6_2;
		elseif Type=="champions" and LE_FOLLOWER_TYPE_GARRISON_7_0 then
			ohLevel = C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_7_0) or 0;
			followerType = LE_FOLLOWER_TYPE_GARRISON_7_0;
		end

		if followerType then
			local _time,_ = time();
			local tmp = C_Garrison.GetInProgressMissions(followerType) or {};
			local charDB = ns.toon;
			if charDB.missions==nil or (charDB.missions~=nil and #charDB.missions>0) then
				charDB.missions = {};
			end
			charDB.missions[Type]={}; -- wipe

			missions[Type] = {inprogress={},available={},completed={}};
			missions[Type].available  = C_Garrison.GetAvailableMissions(followerType) or {};
			missions[Type].inprogress,missions[Type].completed = {},{};

			for i,v in ipairs(tmp) do
				if(v.missionEndTime-_time>0)then
					tinsert(missions[Type].inprogress,v);
				else
					tinsert(missions[Type].completed,v);
				end
				tinsert(charDB.missions[Type],v.missionEndTime);
			end

			for i,v in ipairs(missions[Type].available) do
				_,_,_,_,_,_,missions[Type].available[i].isExhausting = C_Garrison.GetMissionInfo(v.missionID);
			end

			completed=completed+#missions[Type].completed;
			inprogress=inprogress+#missions[Type].inprogress;
			available=available+#missions[Type].available;
		end
	end
	obj.text = ("%s/%s/%s"):format(C("ltblue",completed),C("yellow",inprogress),C("green",available));
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

		showChars = true,
		showAllFactions=true,
		showRealmNames=true,
		showCharsFrom="2",

		showMissionType = true,
		showMissionLevel = true,
		showMissionItemLevel = true,
		showMissionFollowerSlots = true
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

function module.options()
	return {
		broker = nil,
		tooltip = {
			showChars={ type="toggle", order=1, name=L["Show characters"],          desc=L["Show a list of your characters with count of ready and active missions in tooltip"] },
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
		misc = nil,
	}
end

-- function module.init() end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	else
		update();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(self) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttColumns=ttColumns_default;
	if not ns.profile[name].showMissionLevel then         ttColumns=ttColumns-1; end
	if not ns.profile[name].showMissionType then          ttColumns=ttColumns-1; end
	if not ns.profile[name].showMissionItemLevel then     ttColumns=ttColumns-1; end
	if not ns.profile[name].showMissionFollowerSlots then ttColumns=ttColumns-1; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "LEFT", "CENTER", "CENTER","RIGHT"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
