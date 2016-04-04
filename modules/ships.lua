
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I

if ns.build<60000000 then return end

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Ships"; --L["Ships"]
--L.Ships = GARRISON_FOLLOWERS;
local ldbName, ttName, ttColumns, tt, createMenu = name, name.."TT" ,5
local ships = {available={}, onmission={}, onwork={}, onresting={}, unknown={},num=0};
local syLevel = false; -- shipyard level
local Lvl3QuestID,Lvl3QuestInQuestlog = (ns.player.faction=="Alliance") and 39068 or 39246, false;

-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name]  = {iconfile="Interface\\Icons\\Achievement_GarrisonFolLower_Rare", coords={0.1,0.9,0.1,0.9} }; --IconName::Follower--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show a list of your naval ships with level, quality, xp and more."],
	--icon_suffix = "_Neutral",
	events = {
		"PLAYER_ENTERING_WORLD",
		"GARRISON_FOLLOWER_LIST_UPDATE",
		"GARRISON_FOLLOWER_XP_CHANGED",
		"GARRISON_FOLLOWER_REMOVED",
		"QUEST_LOG_UPDATE"
	},
	updateinterval = 30,
	config_defaults = {
		bgColoredStatus = true,
		showChars = true,
		showAllRealms = false,
		showAllFactions = true
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showChars",       label=L["Show characters"],          tooltip=L["Show a list of your characters with count of chilling, working and ships on missions in tooltip"] },
		{ type="toggle", name="showAllRealms",   label=L["Show all realms"],          tooltip=L["Show characters from all realms in tooltip."] },
		{ type="toggle", name="showAllFactions", label=L["Show all factions"],        tooltip=L["Show characters from all factions in tooltip."] },
		{ type="toggle", name="bgColoredStatus", label=L["Background colored row for status"], tooltip=L["Use background colored row for follower status instead to split in separate tables"], event=true },
	},
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
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function getShips()
	local _ = function(count,xp,quality,ilevel)
		local num = ("%04d"):format(count);
		num = ("%03d"):format(700-ilevel)    .. num;
		num = ("%03d"):format(100-ceil(xp))  .. num;
		num = ("%02d"):format(10-quality)    .. num;
		return num
	end
	local xp = function(v) return (v.levelXP>0) and (v.xp/v.levelXP*100) or 100; end;
	local tmp = C_Garrison.GetFollowers(LE_FOLLOWER_TYPE_SHIPYARD_6_2);
	ships = {allinone={},available={},available_num=0,onmission={},onwork_num=0,onwork={},onmission_num=0,onresting={},onresting_num=0,disabled={},disabled_num=0,num=0};

	for i,t in ipairs(C_Garrison.GetBuildings()) do
		if(t.plotID==98)then
			syLevel = t.buildingID - 204;
			break;
		end
	end

	-- fix error for user with disabled garrison module.
	if(be_character_cache[ns.player.name_realm].garrison==nil)then
		be_character_cache[ns.player.name_realm].garrison={C_Garrison.GetGarrisonInfo(),0,{0,0},{}};
	end

	be_character_cache[ns.player.name_realm].ships={level=syLevel}; -- wipe
	local cache=be_character_cache[ns.player.name_realm].ships;

	for i,v in ipairs(tmp)do
		if (v.isCollected==true) then
			v.AbilitiesAndTraits = C_Garrison.GetFollowerAbilities(v.followerID);
			local s,m=0,0;
			if (v.status==nil) then
				v.status2="available";
				ships.available_num = ships.available_num + 1
				ships.available[_(ships.available_num,xp(v),v.quality,v.iLevel)] = v
			elseif (v.status==GARRISON_FOLLOWER_ON_MISSION) then
				v.status2="onmission";
				ships.onmission_num = ships.onmission_num + 1
				ships.onmission[_(ships.onmission_num,xp(v),v.quality,v.iLevel)] = v
				m=time()+C_Garrison.GetFollowerMissionTimeLeftSeconds(v.followerID);
			elseif (v.status==GARRISON_FOLLOWER_EXHAUSTED) then
				v.status2="onresting";
				ships.onresting_num = ships.onresting_num + 1
				ships.onresting[_(ships.onresting_num,xp(v),v.quality,v.iLevel)] = v
				s=1;
			end
			if (Broker_EverythingDB[name].bgColoredStatus) then
				if (v.status==nil) then v.status="available"; end
				ships.allinone[_(ships.num,xp(v),v.quality,v.iLevel)] = v;
			end
			tinsert(cache,{ s, m }); -- ship (unique) id, status (reduced), missionEndTime
			ships.num = ships.num + 1;
		end
	end
	ships.allinone_num=ships.num;
end

local function makeTooltip(tt)
	local colors, qualities,count = {"ltblue","yellow","yellow","green","red"},{"white","ff1eaa00","ff0070dd","ffa335ee","ffff8000"},0
	local statuscolors = {["onresting"]="ltblue",["onwork"]="orange",["onmission"]="yellow",["available"]="green",["disabled"]="red"};
	tt:AddHeader(C("dkyellow",L[name]));

	if (Broker_EverythingDB[name].showChars) then
		tt:AddSeparator(4,0,0,0,0)
		local l=tt:AddLine( C("ltblue", L["Characters"]) ); -- 1
		if(IsShiftKeyDown())then
			tt:SetCell(l, 2, C("ltblue",L["Back from missions"]).."|n"..L["next"].." / "..L["all"], nil, "RIGHT", 2);
		else
			tt:SetCell(l, 2, C("ltblue",L["On missions"]) .."|n".. C("green",L["Completed"]) .." / ".. C("yellow",L["In progress"]), nil, "RIGHT", 2);
		end
		tt:SetCell(l, 4, C("ltblue",L["Ships"]) .. "|n" .. C("green",L["Build"]) .." / ".. C("yellow",L["Limit"]), nil, "RIGHT", 2);

		tt:AddSeparator();
		local t=time();

		for i=1, #be_character_cache.order do
			local name_realm = be_character_cache.order[i];
			local v = be_character_cache[name_realm];
			local charName,realm=strsplit("-",name_realm);
			if (Broker_EverythingDB[name].showAllRealms~=true and realm~=ns.realm)
				or (Broker_EverythingDB[name].showAllFactions~=true
				and v.faction~=ns.player.faction)
				or (v.garrison[1]==nil)
				or (v.garrison[1]==0)
			then
				-- do nothing
			elseif(v.ships and v.ships.level)then
				local faction = v.faction and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
				realm = realm~=ns.realm and C("dkyellow"," - "..ns.scm(realm)) or "";
				local l=tt:AddLine(C(v.class,ns.scm(charName)) .. realm .. faction );
				if(name_realm==ns.player.name_realm)then
					--- background highlight
				end

				local c,n,a = {chilling=0,working=0,onmission=0,resting=0,disabled=0,aftermission=0},0,0;
				local build = #v.ships;

				for _,data in ipairs(v.ships)do
					if(type(data)=="table")then
						local s,m=unpack(data);
						if s == 1 then
							c.chilling=c.chilling+1;
						elseif s == 2 then
							c.working=c.working+1;
						elseif m>t then
							c.onmission=c.onmission+1;
						elseif m>0 then
							c.aftermission=c.aftermission+1;
						else
							c.chilling=c.chilling+1;
						end
						if m>t and ((n==0) or (n~=0 and m<n)) then n=m; end
						if m>a then a=m; end
					end
				end
				if IsShiftKeyDown() then
					tt:SetCell(l, 2, SecondsToTime(n-t) .. " / " .. SecondsToTime(a-t), nil, "RIGHT", 2);
				else
					tt:SetCell(l, 2, (c.aftermission==0 and "−" or C("green",c.aftermission)) .." / ".. (c.onmission==0 and "−" or C("yellow",c.onmission)), nil, "RIGHT", 2);
				end
				tt:SetCell(l, 4, C("green",build) .. " / " .. C("yellow",v.ships.level and ((v.ships.level*2)+4) or "?"), nil, "RIGHT", 2);
				if(name_realm==ns.player.name_realm)then
					tt:SetLineColor(l, 0.1, 0.3, 0.6);
				end
			end
		end
	end

	local tableOrder={
		"available",
		"onmission",
		"onwork",
		"onresting",
		"disabled",
		"allinone"
	};

	local tableTitles = {
		["onresting"] = C("ltblue",GARRISON_FOLLOWER_EXHAUSTED),
		["onmission"] = C("yellow",GARRISON_FOLLOWER_ON_MISSION),
		["onwork"]    = C("orange",GARRISON_FOLLOWER_WORKING),
		["available"] = C("green",L["Available"]),
		["disabled"]  = C("red",L["Disabled"]),
		["allinone"]  = false,
	};

	if (Broker_EverythingDB[name].hideWorking) then
		tableTitles["onwork"] = false;
	end

	if (Broker_EverythingDB[name].hideDisabled) then
		tableTitles["disabled"]=false;
	end

	if (Broker_EverythingDB[name].bgColoredStatus) then
		for i,v in pairs(tableTitles)do tableTitles[i]=false; end
		tableTitles["allinone"]=C("ltblue",L["Follower"]);
	end
	local title=true;
	for _,n in ipairs(tableOrder) do
		if (not tableTitles[n]) then
			-- nothing
		elseif (type(ships[n.."_num"])=="number") and (ships[n.."_num"]>0) then
			for i,v in ns.pairsByKeys(ships[n]) do
				if (v.status2=="disabled" and Broker_EverythingDB[name].hideDisabled) then
					-- hide
				elseif (v.status2=="onwork" and Broker_EverythingDB[name].hideWorking) then
					-- hide
				else
					if (title) then
						tt:AddSeparator(4,0,0,0,0)
						tt:AddLine(tableTitles[n],C("ltblue",L["Type"]),C("ltblue",L["XP"]),C("ltblue",L["iLevel"]),C("ltblue",L["Abilities"]));
						tt:AddSeparator()
						title=false;
					end
					local class = "red"
					if (type(v["classAtlas"])=="string") then
						class = strsub(v["classAtlas"],23);
					end
					if (strlen(v["name"])==0) then
						v["name"] = "["..L["Unknown"].."]";
					end
					local a = "";
					for _,at in ipairs(v.AbilitiesAndTraits) do
						a = a .. " |T"..at.icon..":14:14:0:0:64:64:4:56:4:56|t";
					end
					local l,c;
					if v["levelXP"]~=0 then
						l,c = tt:AddLine( C(class,v["name"]), v["className"].." ", ("%1.1f"):format(v.xp / v.levelXP * 100).."%", v.iLevel, a );
					else
						l,c = tt:AddLine( C(class,v.name), v.className.." ", C("gray","100%"), v.iLevel, a );
					end
					local col = C(qualities[v.quality],"colortable");
					tt.lines[l].cells[1]:SetBackdrop({bgFile="Interface\\AddOns\\"..addon.."\\media\\rowbg", tile = false, insets = { left = 0, right = 0, top = 1, bottom = 0 }})
					tt.lines[l].cells[1]:SetBackdropColor(col[1],col[2],col[3],1);
					if (Broker_EverythingDB[name].bgColoredStatus) then
						local col=C(statuscolors[v.status2] or "red","colortable");
						tt.lines[l]:SetBackdrop({bgFile="Interface\\AddOns\\"..addon.."\\media\\rowbg", tile = false, insets = { left = 0, right = 0, top = 1, bottom = 0 }})
						tt.lines[l]:SetBackdropColor(col[1],col[2],col[3],.37);
					end
				end
			end
		end
		title=true;
	end

	if (ships.num==0) then
		tt:AddLine(L["No ships found..."]);
	end

	if (Broker_EverythingDB.showHints) then
		tt:AddSeparator(4,0,0,0,0);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	local update = false;
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	elseif(event=="PLAYER_ENTERING_WORLD")then
		C_Timer.After(10,function() ns.modules[name].onevent(self,"BE_DUMMY_EVENT"); end);
	elseif(event=="QUEST_LOG_UPDATE" and Lvl3QuestInQuestlog==true and IsQuestFlaggedCompleted(Lvl3QuestID)) or (event=="BE_DUMMY_EVENT")then
		if(Lvl3QuestInQuestlog==false)then
			for i=1, GetNumQuestLogEntries() do
				local _,_,_,_,_,_,_,id=GetQuestLogTitle(i);
				if(id == Lvl3QuestID)then
					Lvl3QuestInQuestlog = true;
				end
			end
		end
		update = true;
	else
		update = true;
	end
	if(update)then
		getShips();
		local obj = ns.LDB:GetDataObjectByName(ldbName)
		obj.text = ("%s/%s/%s/%s"):format(C("ltblue",ships.onresting_num),C("yellow",ships.onmission_num+ships.onwork_num),C("green",ships.available_num),ships.num);
	end
end

ns.modules[name].onupdate = function(self)
	if UnitLevel("player")>=90 and ships.num==0 then
		-- stupid blizzard forgot to trigger this event after all types of long distance ports (teleport/portals/homestones)...
		ns.modules[name].onevent(self,"GARRISON_FOLLOWER_LIST_UPDATE")
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(self) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	if Broker_EverythingDB[name].showChars then
		ttColumns=6;
	end

	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "CENTER", "CENTER", "RIGHT");
	makeTooltip(tt)
	ns.createTooltip(self, tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end



--- destroyed in this session
