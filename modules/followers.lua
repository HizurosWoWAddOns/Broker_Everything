
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I

if ns.build<60000000 then return end

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Follower";
L.Follower = GARRISON_FOLLOWERS;
local ldbName, ttName, ttColumns, tt, createMenu = name, name.."TT", 6
local followers = {available={}, onmission={}, onwork={}, onresting={}, unknown={},num=0};
local delay=true;


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name]  = {iconfile="Interface\\Icons\\Achievement_GarrisonFolLower_Rare", coords={0.1,0.9,0.1,0.9} }; --IconName::Follower--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show a list of your follower with level, quality, xp and more."],
	--icon_suffix = "_Neutral",
	events = {
		"PLAYER_ENTERING_WORLD",
		"GARRISON_FOLLOWER_LIST_UPDATE",
		"GARRISON_FOLLOWER_XP_CHANGED",
		"GARRISON_FOLLOWER_REMOVED"
	},
	updateinterval = 30,
	config_defaults = {
		bgColoredStatus = true,
		hideDisabled=false,
		hideWorking=false,
		showChars = true,
		showAllRealms = false,
		showAllFactions = true
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showChars",       label=L["Show characters"],           tooltip=L["Show a list of your characters with count of chilling, working and followers on missions in tooltip"] },
		{ type="toggle", name="bgColoredStatus", label=L["Background colored row for status"], tooltip=L["Use background colored row for follower status instead to split in separate tables"], event=true },
		{ type="toggle", name="hideDisabled",    label=L["Hide disabled followers"],   tooltip=L["Hide disabled followers in tooltip"], event=true },
		{ type="toggle", name="hideWorking",     label=L["Hide working followers"],    tooltip=L["Hide working followers in tooltip"], event=true },
		{ type="toggle", name="showAllRealms",   label=L["Show all realms"],           tooltip=L["Show characters from all realms in tooltip."] },
		{ type="toggle", name="showAllFactions", label=L["Show all factions"],         tooltip=L["Show characters from all factions in tooltip."] },
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

local function getFollowers()
	local _ = function(count,level,xp,quality,ilevel)
		local num = ("%04d"):format(count);
		num = ("%03d"):format(700-ilevel)    .. num;
		num = ("%03d"):format(100-ceil(xp))  .. num;
		num = ("%02d"):format(10-quality)    .. num;
		num = ("%02d"):format(100-level)     .. num;
		return num
	end
	local xp = function(v) return (v.levelXP>0) and (v.xp/v.levelXP*100) or 100; end;
	local tmp = C_Garrison.GetFollowers(LE_FOLLOWER_TYPE_GARRISON_6_0);
	followers = {allinone={},available={},available_num=0,onmission={},onwork_num=0,onwork={},onmission_num=0,onresting={},onresting_num=0,disabled={},disabled_num=0,num=0};

	-- fix error for user with disabled garrison module.
	if(be_character_cache[ns.player.name_realm].garrison==nil)then
		be_character_cache[ns.player.name_realm].garrison={C_Garrison.GetGarrisonInfo(),0,{0,0},{}};
	end

	be_character_cache[ns.player.name_realm].followers={}; -- wipe
	local cache=be_character_cache[ns.player.name_realm].followers;

	for i,v in ipairs(tmp)do
		if (v.isCollected==true) then
			v.AbilitiesAndTraits = C_Garrison.GetFollowerAbilities(v.followerID);
			local s,m=0,0;
			if (v.status==nil) then
				v.status2="available";
				followers.available_num = followers.available_num + 1
				followers.available[_(followers.available_num,v.level,xp(v),v.quality,v.iLevel)] = v
			elseif (v.status==GARRISON_FOLLOWER_ON_MISSION) then
				v.status2="onmission";
				followers.onmission_num = followers.onmission_num + 1
				followers.onmission[_(followers.onmission_num,v.level,xp(v),v.quality,v.iLevel)] = v
				m=time()+C_Garrison.GetFollowerMissionTimeLeftSeconds(v.followerID);
			elseif (v.status==GARRISON_FOLLOWER_EXHAUSTED) then
				v.status2="onresting";
				followers.onresting_num = followers.onresting_num + 1
				followers.onresting[_(followers.onresting_num,v.level,xp(v),v.quality,v.iLevel)] = v
				s=1;
			elseif (v.status==GARRISON_FOLLOWER_WORKING) then
				v.status2="onwork";
				followers.onwork_num = followers.onwork_num + 1
				followers.onwork[_(followers.onwork_num,v.level,xp(v),v.quality,v.iLevel)] = v
				s=2;
			elseif (v.status==GARRISON_FOLLOWER_INACTIVE) then
				v.status2="disabled";
				followers.disabled_num = followers.disabled_num + 1
				followers.disabled[_(followers.disabled_num,v.level,xp(v),v.quality,v.iLevel)] = v
				s=3;
			end
			if (Broker_EverythingDB[name].bgColoredStatus) then
				if (v.status==nil) then v.status="available"; end
				followers.allinone[_(followers.num,v.level,xp(v),v.quality,v.iLevel)] = v
			end
			tinsert(cache,{s, m}); -- status (reduced), missionEndTime
			followers.num = followers.num + 1;
		end
	end
	followers.allinone_num=followers.num;
end

local function makeTooltip(tt)
	local colors, qualities,count = {"ltblue","yellow","yellow","green","red"},{"white","ff1eaa00","ff0070dd","ffa335ee","ffff8000"},0
	local statuscolors = {["onresting"]="ltblue",["onwork"]="orange",["onmission"]="yellow",["available"]="green",["disabled"]="red"};
	tt:AddHeader(C("dkyellow",L["Follower"]));

	if (Broker_EverythingDB[name].showChars) then
		tt:AddSeparator(4,0,0,0,0)
		local l=tt:AddLine( C("ltblue", L["Characters"]) ); -- 1
		if(IsShiftKeyDown())then
			tt:SetCell(l, 2, C("ltblue",L["Back from missions"]).."|n"..L["next"].." / "..L["all"], nil, "RIGHT", 3);
		else
			tt:SetCell(l, 2, C("ltblue",L["On missions"]) .."|n".. C("green",L["Completed"]) .." / ".. C("yellow",L["In progress"]), nil, "RIGHT", 3);
		end
		tt:SetCell(l, 5, C("ltblue",L["Without missions"])     .."|n".. C("green",L["Chilling"]) .." / ".. C("yellow",L["Working"]), nil, "RIGHT", 2);
		tt:SetCell(l, 7, C("ltblue",L["Followers"]) .. "|n" .. C("cyan",L["Collected"]) .." / ".. C("green",L["Active"]) .." / ".. C("yellow",L["Inactive"]));

		tt:AddSeparator();
		local t=time();

		for i=1, #be_character_cache.order do
			local name_realm = be_character_cache.order[i];
			local v = be_character_cache[name_realm];
			local charName,realm=strsplit("-",name_realm);
			if (Broker_EverythingDB[name].showAllRealms~=true and realm~=ns.realm) or (Broker_EverythingDB[name].showAllFactions~=true and v.faction~=ns.player.faction) or (v.garrison[1]==nil) or (v.garrison[1]==0) then
				-- do nothing
			elseif(v.followers)then
				local faction = v.faction and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
				realm = realm~=ns.realm and C("dkyellow"," - "..ns.scm(realm)) or "";
				local l=tt:AddLine(C(v.class,ns.scm(charName)) .. realm .. faction );
				if(name_realm==ns.player.name_realm)then
					--- background highlight
				end

				local c,n,a = {chilling=0,working=0,onmission=0,resting=0,disabled=0,aftermission=0},0,0;
				local collected = #v.followers;

				for _,data in ipairs(v.followers)do
					if(type(data)=="table")then
						local s,m=unpack(data);
						if s == 1 then
							c.chilling=c.chilling+1;
						elseif s == 2 then
							c.working=c.working+1;
						elseif s == 3 then
							c.disabled=c.disabled+1;
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
					tt:SetCell(l, 2, SecondsToTime(n-t) .. " / " .. SecondsToTime(a-t), nil, "RIGHT", 3);
				else
					tt:SetCell(l, 2, (c.aftermission==0 and "−" or C("green",c.aftermission)) .." / ".. (c.onmission==0 and "−" or C("yellow",c.onmission)), nil, "RIGHT", 3);
				end
				tt:SetCell(l, 5, (c.chilling==0 and "−" or C("green",c.chilling)) .." / ".. (c.working==0 and "−" or C("yellow",c.working)), nil, "RIGHT", 2);
				tt:SetCell(l, 7, C("cyan",collected) .. " / " .. C("green",collected-c.disabled) .. " / " .. C("yellow",c.disabled) );
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
		elseif (type(followers[n.."_num"])=="number") and (followers[n.."_num"]>0) then
			for i,v in ns.pairsByKeys(followers[n]) do
				if (v.status2=="disabled" and Broker_EverythingDB[name].hideDisabled) then
					-- hide
				elseif (v.status2=="onwork" and Broker_EverythingDB[name].hideWorking) then
					-- hide
				else
					if (title) then
						tt:AddSeparator(4,0,0,0,0)
						tt:AddLine(tableTitles[n],C("ltblue",L["Level"]),C("ltblue",L["XP"]),C("ltblue",L["iLevel"]),C("ltblue",L["Abilities"]),C("ltblue",L["Traits"]));
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
					local a,t = "","";
					for _,at in ipairs(v.AbilitiesAndTraits) do
						if (at.icon:find("Trade_") or at.icon:find("INV_Misc_Gem_01") or at.icon:find("Ability_HanzandFranz_ChestBump") or at.icon:find("INV_Misc_Pelt_Wolf_01") or at.icon:find("INV_Inscription_Tradeskill01")) then
							t = t .. " |T"..at.icon..":14:14:0:0:64:64:4:56:4:56|t";
						else
							a = a .. " |T"..at.icon..":14:14:0:0:64:64:4:56:4:56|t";
						end
					end
					if v["levelXP"]~=0 then
						l,c = tt:AddLine( C(class,v["name"]), v["level"].." ", ("%1.1f"):format(v.xp / v.levelXP * 100).."%", v.iLevel, a, t );
					else
						l,c = tt:AddLine( C(class,v.name), v.level.." ", C("gray","100%"), v.iLevel, a, t );
					end
					local col = C(qualities[v.quality],"colortable");
					tt.lines[l].cells[2]:SetBackdrop({bgFile="Interface\\AddOns\\"..addon.."\\media\\rowbg", tile = false, insets = { left = 0, right = 0, top = 1, bottom = 0 }})
					tt.lines[l].cells[2]:SetBackdropColor(col[1],col[2],col[3],1);
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

	if (followers.num==0) then
		tt:AddLine(L["No followers found..."]);
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

	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	else

		if (delay==true) then
			delay = false
			C_Timer.After(10,ns.modules[name].onevent)
			return;
		end

		getFollowers();
		local obj = ns.LDB:GetDataObjectByName(ldbName)
		obj.text = ("%s/%s/%s/%s"):format(C("ltblue",followers.onresting_num),C("yellow",followers.onmission_num+followers.onwork_num),C("green",followers.available_num),followers.num);
	end
end

ns.modules[name].onupdate = function(self)
	if UnitLevel("player")>=90 and followers.num==0 then
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
		ttColumns=7;
	end

	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "CENTER", "CENTER", "CENTER", "RIGHT");
	makeTooltip(tt)
	ns.createTooltip(self, tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

