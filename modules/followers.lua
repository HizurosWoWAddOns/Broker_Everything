
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
local ldbName,ttName = name,name.."TT"
local tt,createMenu
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
	enabled = false,
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
		hideWorking=false
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="bgColoredStatus", label=L["Background colored row for status"], tooltip=L["Use background colored row for follower status instead to split in separate tables"], event=true },
		{ type="toggle", name="hideDisabled", label=L["Hide disabled followers"], tooltip=L["Hide disabled followers in tooltip"], event=true },
		{ type="toggle", name="hideWorking", label=L["Hide working followers"], tooltip=L["Hide working followers in tooltip"], event=true },
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
	local tmp = C_Garrison.GetFollowers();
	followers = {allinone={},available={},available_num=0,onmission={},onwork_num=0,onwork={},onmission_num=0,onresting={},onresting_num=0,disabled={},disabled_num=0,num=0};
	for i,v in ipairs(tmp)do
		if (v.isCollected==true) then
			v.AbilitiesAndTraits = C_Garrison.GetFollowerAbilities(v.followerID);
			if (v.status==nil) then
				v.status2="available";
				followers.available_num = followers.available_num + 1
				followers.available[_(followers.available_num,v.level,xp(v),v.quality,v.iLevel)] = v
			elseif (v.status==GARRISON_FOLLOWER_ON_MISSION) then
				v.status2="onmission";
				followers.onmission_num = followers.onmission_num + 1
				followers.onmission[_(followers.onmission_num,v.level,xp(v),v.quality,v.iLevel)] = v
			elseif (v.status==GARRISON_FOLLOWER_EXHAUSTED) then
				v.status2="onresting";
				followers.onresting_num = followers.onresting_num + 1
				followers.onresting[_(followers.onresting_num,v.level,xp(v),v.quality,v.iLevel)] = v
			elseif (v.status==GARRISON_FOLLOWER_WORKING) then
				v.status2="onwork";
				followers.onwork_num = followers.onwork_num + 1
				followers.onwork[_(followers.onwork_num,v.level,xp(v),v.quality,v.iLevel)] = v
			else
				v.status2="disabled";
				followers.disabled_num = followers.disabled_num + 1
				followers.disabled[_(followers.disabled_num,v.level,xp(v),v.quality,v.iLevel)] = v
			end
			if (Broker_EverythingDB[name].bgColoredStatus) then
				if (v.status==nil) then v.status="available"; end
				followers.allinone[_(followers.num,v.level,xp(v),v.quality,v.iLevel)] = v
			end
			followers.num = followers.num + 1
		end
	end
	followers.allinone_num=followers.num;
end

local function makeTooltip(tt)
	local colors, qualities,count = {"ltblue","yellow","yellow","green","red"},{"white","ff1eaa00","ff0070dd","ffa335ee","ffff8000"},0
	local statuscolors = {["onresting"]="ltblue",["onwork"]="orange",["onmission"]="yellow",["available"]="green",["disabled"]="red"};
	tt:AddHeader(C("dkyellow",L["Follower"]));

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

	tt = ns.LQT:Acquire(name.."TT", 6, "LEFT", "RIGHT", "RIGHT", "CENTER", "CENTER", "CENTER")
	makeTooltip(tt)
	ns.createTooltip(self, tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

