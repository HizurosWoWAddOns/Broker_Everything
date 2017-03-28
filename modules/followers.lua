
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
if ns.build<60000000 then return end
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local nameF,nameS = "Followers","Ships"; -- GARRISON_FOLLOWERS, GARRISON_SHIPYARD_FOLLOWERS
local ttNameF, ttColumnsF, ttF = nameF.."TT", 7;
local ttNameS, ttColumnsS, ttS = nameS.."TT" ,7;
local followers,ships,champions,troops,createMenu = {num=0},{num=0},{num=0},{num=0};
local garrLevel, ohLevel, syLevel = 0,0,0;
local followerEnabled,shipsEnabled=false,false;
local delay,ticker=true;


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[nameF]  = {iconfile="Interface\\Icons\\Achievement_GarrisonFolLower_Rare", coords={0.1,0.9,0.1,0.9} }; --IconName::Follower--
I[nameS]  = {iconfile="Interface\\Icons\\Achievement_GarrisonFolLower_Rare", coords={0.1,0.9,0.1,0.9} }; --IconName::Ships--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules.followers_core = {
	noBroker = true,
	noOptions = true,
	events = {
		"PLAYER_ENTERING_WORLD",
		"GARRISON_FOLLOWER_LIST_UPDATE",
		"GARRISON_FOLLOWER_UPGRADED",
		"GARRISON_FOLLOWER_XP_CHANGED",
		"GARRISON_FOLLOWER_REMOVED",
	},
	updateinterval = 30,
}

ns.modules[nameF] = {
	desc = L["Broker to show a list of your follower with level, quality, experience and more"],
	label = GARRISON_FOLLOWERS,
	--icon_suffix = "_Neutral",
	events = {},
	updateinterval = nil,
	config_defaults = {
		showAllInOne = true,
		showFollowersOnBroker = true,
		showChampionsOnBroker = true,
		showTroopsOnBroker = true,

		bgColoredStatus = true,
		hideDisabled=false,
		hideWorking=false,
		showChars = true,
		showAllRealms = false,
		showAllFactions = true,
		showFollowers = true,
		showChampions = true,
		showTroops = true
	},
	config_allowed = nil,
	config_header = {type="header", label=GARRISON_FOLLOWERS, align="left", icon=I[nameF]},
	config_broker = {
		"minimapButton",
		{ type="toggle", name="showAllInOne",          label=L["Show all in one"],       tooltip=L["Show all counts of followers, champions and troops as overall summary on broker button. You can disable single types with following toggles."], event="BE_DUMMY_EVENT"},
		{ type="toggle", name="showFollowersOnBroker", label=L["Show followers"],        tooltip=L["Show followers summary on broker button"], event="BE_DUMMY_EVENT"},
		{ type="toggle", name="showChampionsOnBroker",  label=L["Show champions"],        tooltip=L["Show champions summary on broker button"], event="BE_DUMMY_EVENT"},
		{ type="toggle", name="showTroopsOnBroker",    label=L["Show troops"],           tooltip=L["Show troops summary on broker button"], event="BE_DUMMY_EVENT"},
	},
	config_tooltip = {
		{ type="toggle", name="bgColoredStatus", label=L["Background colored row for status"], tooltip=L["Use background colored row for follower status instead to split in separate tables"], event=true },
		{ type="toggle", name="hideDisabled",    label=L["Hide disabled followers"],           tooltip=L["Hide disabled followers in tooltip"], event=true },
		{ type="toggle", name="hideWorking",     label=L["Hide working followers"],            tooltip=L["Hide working followers in tooltip"], event=true },
		{ type="toggle", name="showChars",       label=L["Show characters"],                   tooltip=L["Show a list of your characters with count of chilling, working and followers on missions in tooltip"] },
		{ type="toggle", name="showAllRealms",   label=L["Show all realms"],                   tooltip=L["Show characters from all realms in tooltip."] },
		{ type="toggle", name="showAllFactions", label=L["Show all factions"],                 tooltip=L["Show characters from all factions in tooltip."] },
		{ type="toggle", name="showFollowers",   label=L["Show followers"],                    tooltip=L["Show followers in tooltip"]},
		{ type="toggle", name="showChampions",   label=L["Show champions"],                    tooltip=L["Show champions in tooltip"]},
		{ type="toggle", name="showTroops",      label=L["Show troops"],                       tooltip=L["Show troops in tooltip"]},
	},
	config_misc = nil,
	clickOptions = {
		["1_open_garrison_report"] = {
			cfg_label = "Open garrison report",
			cfg_desc = "open the garrison report",
			cfg_default = "__NONE",
			hint = "Open garrison report",
			func = function(self,button)
				local _mod=nameF;
				securecall("GarrisonLandingPage_Toggle");
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "__NONE",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=nameF;
				createMenu(self,nameF);
			end
		}
	}
}

ns.modules[nameS] = {
	desc = L["Broker to show your naval ships with level, quality, xp and more"],
	label = GARRISON_SHIPYARD_FOLLOWERS,
	--icon_suffix = "_Neutral",
	events = {},
	updateinterval = nil,
	config_defaults = {
		bgColoredStatus = true,
		showChars = true,
		showAllRealms = false,
		showAllFactions = true
	},
	config_allowed = nil,
	config_header = {type="header", label=GARRISON_SHIPYARD_FOLLOWERS, align="left", icon=I[nameS]},
	config_broker = {"minimapButton"},
	config_tooltip = {
		{ type="toggle", name="showChars",       label=L["Show characters"],          tooltip=L["Show a list of your characters with count of chilling, working and ships on missions in tooltip"] },
		{ type="toggle", name="showAllRealms",   label=L["Show all realms"],          tooltip=L["Show characters from all realms in tooltip."] },
		{ type="toggle", name="showAllFactions", label=L["Show all factions"],        tooltip=L["Show characters from all factions in tooltip."] },
		{ type="toggle", name="bgColoredStatus", label=L["Background colored row for status"], tooltip=L["Use background colored row for follower status instead to split in separate tables"], event=true },
	},
	config_misc = nil,
	clickOptions = {
		["1_open_garrison_report"] = {
			cfg_label = "Open garrison report", -- L["Open garrison report"]
			cfg_desc = "open the garrison report", -- L["open the garrison report"]
			cfg_default = "__NONE",
			hint = "Open garrison report",
			func = function(self,button)
				local _mod=nameS;
				securecall("GarrisonLandingPage_Toggle");
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "__NONE",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=nameS;
				createMenu(self,nameS);
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self,name)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name,nil,name==nameF);
	ns.EasyMenu.ShowMenu(self);
end


local function getFollowers(tableName)
	local _ = function(count,level,xp,quality,ilevel)
		local num = ("%04d"):format(count);
		num = ("%03d"):format(700-ilevel)    .. num;
		num = ("%03d"):format(100-ceil(xp))  .. num;
		num = ("%02d"):format(10-quality)    .. num;
		num = ("%02d"):format(100-level)     .. num;
		return num
	end
	local xp = function(v) return (v.levelXP>0) and (v.xp/v.levelXP*100) or 100; end;

	local name,isTroop,Table,garrType,followerType = nameF;
	if tableName=="followers" then
		followers = {allinone={},available={},available_num=0,onmission={},onwork_num=0,onwork={},onmission_num=0,onresting={},onresting_num=0,disabled={},disabled_num=0,num=0};
		Table,garrType,followerType = followers,LE_GARRISON_TYPE_6_0,LE_FOLLOWER_TYPE_GARRISON_6_0;
	elseif tableName=="ships" then
		ships = {allinone={},available={},available_num=0,onmission={},onwork_num=0,onwork={},onmission_num=0,onresting={},onresting_num=0,disabled={},disabled_num=0,num=0};
		Table,garrType,followerType,name = ships,LE_GARRISON_TYPE_6_0,LE_FOLLOWER_TYPE_SHIPYARD_6_2,nameS;
	elseif tableName=="champions" then
		champions = {allinone={},available={},available_num=0,onmission={},onwork_num=0,onwork={},onmission_num=0,onresting={},onresting_num=0,disabled={},disabled_num=0,num=0};
		Table,garrType,followerType,isTroop = champions,LE_GARRISON_TYPE_7_0,LE_FOLLOWER_TYPE_GARRISON_7_0,false;
	elseif tableName=="troops" then
		troops = {allinone={},available={},available_num=0,onmission={},onwork_num=0,onwork={},onmission_num=0,onresting={},onresting_num=0,disabled={},disabled_num=0,num=0};
		Table,garrType,followerType,isTroop = troops,LE_GARRISON_TYPE_7_0,LE_FOLLOWER_TYPE_GARRISON_7_0,true;
	end

	ns.toon[tableName]={}; -- wipe
	local cache=ns.toon[tableName];

	local tmp = C_Garrison.GetFollowers(followerType) or {};
	for i,v in ipairs(tmp)do
		if v.isCollected==true and (isTroop==nil or v.isTroop==isTroop) then
			v.follower_Type = followerType; -- ?
			v.AbilitiesAndTraits = C_Garrison.GetFollowerAbilities(v.followerID);
			local s,m=0,0;
			if (v.status==nil) then
				v.status2="available";
				Table.available_num = Table.available_num + 1
				Table.available[_(Table.available_num,v.level,xp(v),v.quality,v.iLevel)] = v
			elseif (v.status==GARRISON_FOLLOWER_ON_MISSION) then
				v.status2="onmission";
				Table.onmission_num = Table.onmission_num + 1
				Table.onmission[_(Table.onmission_num,v.level,xp(v),v.quality,v.iLevel)] = v
				m=time()+C_Garrison.GetFollowerMissionTimeLeftSeconds(v.followerID);
			elseif (v.status==GARRISON_FOLLOWER_EXHAUSTED) then
				v.status2="onresting";
				Table.onresting_num = Table.onresting_num + 1
				Table.onresting[_(Table.onresting_num,v.level,xp(v),v.quality,v.iLevel)] = v
				s=1;
			elseif (v.status==GARRISON_FOLLOWER_WORKING) then
				v.status2="onwork";
				Table.onwork_num = Table.onwork_num + 1
				Table.onwork[_(Table.onwork_num,v.level,xp(v),v.quality,v.iLevel)] = v
				s=2;
			elseif (v.status==GARRISON_FOLLOWER_INACTIVE) then
				v.status2="disabled";
				Table.disabled_num = Table.disabled_num + 1
				Table.disabled[_(Table.disabled_num,v.level,xp(v),v.quality,v.iLevel)] = v
				s=3;
			end
			if (ns.profile[name].bgColoredStatus) then
				if (v.status==nil) then v.status="available"; end
				Table.allinone[_(Table.num,v.level,xp(v),v.quality,v.iLevel)] = v
			end
			local _,class = strsplit("-",v.classAtlas);
			tinsert(cache,{
				id=tonumber(v.garrFollowerID or v.followerID) or 0, -- id
				level=v.level, -- level
				name=v.name, -- name
				quality=v.quality, -- quality
				class=class, -- class
				durability=v.durability,
				maxDurability=v.maxDurability,
				status=s, -- status (reduced)
				missionEnd=m -- missionEndTime
			}); 
			Table.num = Table.num + 1;
		end
	end
	Table.allinone_num=Table.num;
end

local function updateBroker()
	if followerEnabled then
		local aio = {0,0,0,0,0};
		local single = {};
		if ns.profile[nameF].showFollowersOnBroker and garrLevel>0 then
			getFollowers("followers");
			aio[1]=aio[1]+(followers.onresting_num or 0);
			aio[2]=aio[2]+(followers.onmission_num or 0);
			aio[3]=aio[3]+(followers.onwork_num or 0);
			aio[4]=aio[4]+(followers.available_num or 0);
			aio[5]=aio[5]+(followers.num or 0);
			tinsert(single, ("%s/%s/%s/%s"):format(C("ltblue",followers.onresting_num),C("yellow",followers.onmission_num+followers.onwork_num),C("green",followers.available_num),followers.num));
		end
		if ns.profile[nameF].showChampionsOnBroker and LE_GARRISON_TYPE_7_0 and ohLevel>0 then
			getFollowers("champions");
			aio[1]=aio[1]+(champions.onresting_num or 0);
			aio[2]=aio[2]+(champions.onmission_num or 0);
			aio[3]=aio[3]+(champions.onwork_num or 0);
			aio[4]=aio[4]+(champions.available_num or 0);
			aio[5]=aio[5]+(champions.num or 0);
			tinsert(single, ("%s/%s/%s/%s"):format(C("ltblue",champions.onresting_num),C("yellow",champions.onmission_num+champions.onwork_num),C("green",champions.available_num),champions.num));
		end
		if ns.profile[nameF].showTroopsOnBroker and LE_GARRISON_TYPE_7_0 and ohLevel>0 then
			getFollowers("troops");
			aio[1]=aio[1]+(troops.onresting_num or 0);
			aio[2]=aio[2]+(troops.onmission_num or 0);
			aio[3]=aio[3]+(troops.onwork_num or 0);
			aio[4]=aio[4]+(troops.available_num or 0);
			aio[5]=aio[5]+(troops.num or 0);
			tinsert(single, ("%s/%s/%s/%s"):format(C("ltblue",troops.onresting_num),C("yellow",troops.onmission_num+troops.onwork_num),C("green",troops.available_num),troops.num));
		end
		local obj = ns.LDB:GetDataObjectByName(ns.modules[nameF].ldbName);
		if ns.profile[nameF].showAllInOne then
			obj.text = ("%s/%s/%s/%s"):format(C("ltblue",aio[1]),C("yellow",aio[2]+aio[3]),C("green",aio[4]),aio[5]);
		else
			obj.text = #single>0 and table.concat(single,", ") or L[nameF];
		end
	end
	if shipsEnabled then
		local obj = ns.LDB:GetDataObjectByName(ns.modules[nameS].ldbName);
		if LE_FOLLOWER_TYPE_SHIPYARD_6_2 and garrLevel>0 and syLevel>0 then
			getFollowers("ships");
			obj.text = ("%s/%s/%s/%s"):format(C("ltblue",ships.onresting_num),C("yellow",ships.onmission_num+ships.onwork_num),C("green",ships.available_num),ships.num);
		else
			obj.text = GARRISON_SHIPYARD_FOLLOWERS;
		end
	end
end

local function charSummary(lst,c,v,t,a)
	local cMissions,cWorking,cCollected = {},{},{};
	local collected = {
		followers = v.followers~=nil and #v.followers or 0,
		ships     = v.ships~=nil     and #v.ships or 0,
		champions = v.champions~=nil and #v.champions or 0,
		troops    = v.troops~=nil    and #v.troops or 0
	};
	local n,a = 0,0;
	for _,x in ipairs(lst)do
		local l,label = unpack(x);
		if type(v[l])=="table" then
			for _,data in ipairs(v[l])do
				if type(data)=="table" then
					if data.id then -- new table
						if data.status == 1 then
							c[l].chilling=c[l].chilling+1;
						elseif data.status == 2 then
							c[l].working=c[l].working+1;
						elseif data.status == 3 then
							c[l].disabled=c[l].disabled+1;
						elseif data.missionEnd>t then
							c[l].onmission=c[l].onmission+1;
						elseif data.missionEnd>0 then
							c[l].aftermission=c[l].aftermission+1;
						else
							c[l].chilling=c[l].chilling+1;
						end
						if data.missionEnd>t and ((n==0) or (n~=0 and data.missionEnd<n)) then n=data.missionEnd; end
						if data.missionEnd>a then a=data.missionEnd; end
					end
				end
			end
		end
		tinsert(cMissions, (c[l].aftermission==0 and "−" or C("green",c[l].aftermission)) .."/".. (c[l].onmission==0 and "−" or C("yellow",c[l].onmission)));
		tinsert(cWorking,  (c[l].chilling==0 and "−" or C("green",c[l].chilling)) .."/".. (c[l].working==0 and "−" or C("yellow",c[l].working)));
		tinsert(cCollected,C("cyan",collected[l]) .. "/" .. C("green",collected[l]-c[l].disabled) .. "/" .. C("yellow",c[l].disabled));
	end	
	return cMissions, cWorking, cCollected,n,a;
end

local function createTooltip(tt, name)
	--if (tt) and (tt.key) and (tt.key~=name) then return end -- don't override other LibQTip tooltips...
	local colors,qualities,count = {"ltblue","yellow","yellow","green","red"},{"white","ff1eaa00","ff0070dd","ffa335ee","ffff8000"},0
	local statuscolors = {["onresting"]="ltblue",["onwork"]="orange",["onmission"]="yellow",["available"]="green",["disabled"]="red"};
	local none=true;

	tt:Clear();
	if name==nameS then
		tt:AddHeader(C("dkyellow",GARRISON_SHIPYARD_FOLLOWERS));
	elseif ns.build>70000000 then
		tt:AddHeader(C("dkyellow",("%s, %s, %s"):format(GARRISON_FOLLOWERS,FOLLOWERLIST_LABEL_CHAMPIONS,FOLLOWERLIST_LABEL_TROOPS)));
	else
		tt:AddHeader(C("dkyellow",GARRISON_FOLLOWERS));
	end

	if (ns.profile[name].showChars) then
		tt:AddSeparator(4,0,0,0,0)
		local l=tt:AddLine( C("ltblue", L["Characters"]) ); -- 1
		if(IsShiftKeyDown())then
			tt:SetCell(l, 2, C("ltblue",L["Back from missions"]).."|n"..L["next"].." / "..L["all"], nil, "RIGHT", 3);
		else
			tt:SetCell(l, 2, C("ltblue",GARRISON_FOLLOWER_ON_MISSION) .."|n".. C("green",L["Completed"]) .." / ".. C("yellow",GARRISON_SHIPYARD_MSSION_INPROGRESS_TOOLTIP), nil, "RIGHT", 3);
		end
		tt:SetCell(l, 5, C("ltblue",L["Without missions"])     .."|n".. C("green",L["Chilling"]) .." / ".. C("yellow",GARRISON_FOLLOWER_WORKING), nil, "RIGHT", 2);
		tt:SetCell(l, 7, C("ltblue",GARRISON_FOLLOWERS) .. "|n" .. C("cyan",COLLECTED) .." / ".. C("green",L["Active"]) .." / ".. C("yellow",GARRISON_FOLLOWER_INACTIVE));

		tt:AddSeparator();
		local t=time();

		for i=1, #Broker_Everything_CharacterDB.order do
			local name_realm = Broker_Everything_CharacterDB.order[i];
			local v = Broker_Everything_CharacterDB[name_realm];
			local charName,realm=strsplit("-",name_realm);

			local lst = {};
			if name==nameF then
				tinsert(lst,{"followers","FOLLOWERS_ABBREV"});
				if v.champions then
					tinsert(lst,{"champions","CHAMPIONS_ABBREV"});
				end
			else
				tinsert(lst,{"ships","FOLLOWERS_ABBREV"});
			end

			if (ns.profile[name].showAllRealms~=true and realm~=ns.realm) or (ns.profile[name].showAllFactions~=true and v.faction~=ns.player.faction) then
				-- do nothing
			else
				local faction = v.faction and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
				realm = realm~=ns.realm and C("dkyellow"," - "..ns.scm(realm)) or "";

				local l=tt:AddLine(C(v.class,ns.scm(charName)) .. realm .. faction );

				local n,a,cMissions,cWorking,cCollected = 0,0;
				local c = {}
				if followerEnabled and (followers.num>0 or champions.num>0) then
					c.followers={chilling=0,working=0,onmission=0,resting=0,disabled=0,aftermission=0};
					c.ships={chilling=0,working=0,onmission=0,resting=0,disabled=0,aftermission=0};
					c.champions={chilling=0,working=0,onmission=0,resting=0,disabled=0,aftermission=0};
					c.troops={chilling=0,working=0,onmission=0,resting=0,disabled=0,aftermission=0};
					cMissions, cWorking, cCollected,n,a = charSummary(lst,c,v,t);
					if IsShiftKeyDown() then
						tt:SetCell(l, 2, SecondsToTime(n-t) .. " / " .. SecondsToTime(a-t), nil, "RIGHT", 3);
					else
						tt:SetCell(l, 2, table.concat(cMissions, ", "), nil, "RIGHT", 3);
					end
					tt:SetCell(l, 5, table.concat(cWorking, ", "), nil, "RIGHT", 2);
					tt:SetCell(l, 7, table.concat(cCollected, ", ") );

				elseif shipsEnabled and ships.num>0 then
					c.ships={chilling=0,working=0,onmission=0,resting=0,disabled=0,aftermission=0};
					cMissions, cWorking, cCollected,n,a = charSummary(lst,c,v,t);
					if IsShiftKeyDown() then
						tt:SetCell(l, 2, SecondsToTime(n-t) .. " / " .. SecondsToTime(a-t), nil, "RIGHT", 3);
					else
						tt:SetCell(l, 2, table.concat(cMissions, ", "), nil, "RIGHT", 3);
					end
					tt:SetCell(l, 5, table.concat(cWorking, ", "), nil, "RIGHT", 2);
					tt:SetCell(l, 7, table.concat(cCollected, ", ") );
				end

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
		["available"] = C("green",AVAILABLE),
		["disabled"]  = C("red",ADDON_DISABLED),
		["allinone"]  = false,
	};

	if (ns.profile[name].hideWorking) then
		tableTitles["onwork"] = false;
	end

	if (ns.profile[name].hideDisabled) then
		tableTitles["disabled"]=false;
	end

	if (ns.profile[name].bgColoredStatus) then
		for i,v in pairs(tableTitles)do tableTitles[i]=false; end
		tableTitles["allinone"]=C("ltblue",GARRISON_FOLLOWERS);
	end

	local title,subTitle,inset=true,true,"";

	for _,n in ipairs(tableOrder) do
		if (tableTitles[n]) then
			local lst = {};
			if name==nameF then
				lst = {{"followers",GARRISON_FOLLOWERS}};
				if ohLevel>0 then
					tinsert(lst,1,{"champions",FOLLOWERLIST_LABEL_CHAMPIONS});
					tinsert(lst,2,{"troops",FOLLOWERLIST_LABEL_TROOPS});
					inset="   ";
				end
			else
				lst = {{"ships",GARRISON_SHIPYARD_FOLLOWERS}};
			end
			for _,x in ipairs(lst)do -- follower types
				local Table;
				if x[1]=="followers" and ns.profile[name].showFollowers then
					Table = followers;
				elseif x[1]=="champions" and ns.profile[name].showChampions then
					Table = champions;
				elseif x[1]=="troops" and ns.profile[name].showTroops then
					Table = troops;
				elseif x[1]=="ships" then
					Table = ships;
				end
				if Table and (type(Table[n.."_num"])=="number") and (Table[n.."_num"]>0) then
					none=false;
					for i,v in ns.pairsByKeys(Table[n]) do
						if	(v.status2=="disabled" and ns.profile[name].hideDisabled)
							or
							(v.status2=="onwork" and ns.profile[name].hideWorking) then
							-- hide
						else
							if (title) then
								tt:AddSeparator(4,0,0,0,0)
								if name==nameF then
									tt:AddLine(tableTitles[n],C("ltblue",LEVEL),C("ltblue",XP),C("ltblue",L["iLevel"]),C("ltblue",ABILITIES),C("ltblue",GARRISON_TRAITS));
								else
									tt:AddLine(tableTitles[n],C("ltblue",TYPE),C("ltblue",XP), --[[C("ltblue",L["iLevel"]),]] C("ltblue",ABILITIES));
								end
								tt:AddSeparator()
								title=false;
							end
							if #lst>1 and subTitle then
								tt:AddLine(C("ltgray",x[2]));
								subTitle=false;
							end
							local class,_ = "red";
							if (type(v["classAtlas"])=="string") then
								_,class = strsplit("-",v["classAtlas"]);
							end
							if (strlen(v["name"])==0) then
								v["name"] = "["..UNKNOWN.."]";
							end
							local a,t,l = "","";
								
							if name==nameF then
								if x[1]=="troops" then
									for _,at in ipairs(v.AbilitiesAndTraits) do
										if at~=nil then
											a = a .. " |T"..at.icon..":14:14:0:0:64:64:4:56:4:56|t";
										end
									end
									t={};
									for i=1, v.maxDurability do
										if i<=v.durability then
											tinsert(t,"|T1384099:11:12:0:0:256:256:1:16:1:14|t"); --"GarrisonTroops-Health"
										else
											tinsert(t,"|T1384099:11:12:0:0:256:256:18:33:1:14|t"); --"GarrisonTroops-Health-Consume"
										end
									end
									t = table.concat(t," ");
								else
									for _,at in ipairs(v.AbilitiesAndTraits) do
										if at~=nil then
											if type(at.icon)=="string" and (at.icon:find("Trade_") or at.icon:find("INV_Misc_Gem_01") or at.icon:find("Ability_HanzandFranz_ChestBump") or at.icon:find("INV_Misc_Pelt_Wolf_01") or at.icon:find("INV_Inscription_Tradeskill01")) then
												-- wod version
												t = t .. " |T"..at.icon..":14:14:0:0:64:64:4:56:4:56|t";
											elseif at.icon==136240 -- Trade_Alchemy
												or at.icon==136241 -- Trade_BlackSmithing
												or at.icon==136242 -- Trade_BrewPoison
												or at.icon==136243 -- Trade_Engineering
												or at.icon==136244 -- Trade_Engraving
												or at.icon==136245 -- Trade_Fishing
												or at.icon==136246 -- Trade_Herbalism
												or at.icon==136247 -- Trade_LeatherWorking
												or at.icon==136248 -- Trade_Mining
												or at.icon==136249 -- Trade_Tailoring
												or at.icon==134071 -- INV_Misc_Gem_01
												or at.icon==1037260 -- Ability_HanzandFranz_ChestBump
												or at.icon==134366 -- INV_Misc_Pelt_Wolf_01
												or at.icon==237171 then -- INV_Inscription_Tradeskill01
												-- legion version
												t = t .. " |T"..at.icon..":14:14:0:0:64:64:4:56:4:56|t";
											else
												a = a .. " |T"..(at.icon or ns.icon_fallback)..":14:14:0:0:64:64:4:56:4:56|t";
											end
										end
									end
								end
								if v.levelXP~=0 then
									l = tt:AddLine( inset..C(class,v.name), v.level.." ", ("%1.1f"):format(v.xp / v.levelXP * 100).."%", v.iLevel, a, t );
								else
									l = tt:AddLine( inset..C(class,v.name), v.level.." ", C("gray","100%"), v.iLevel, a, t );
								end
								if v.quality>1 then
									local col = C(qualities[v.quality],"colortable");
									tt.lines[l].cells[2]:SetBackdrop({bgFile="Interface\\AddOns\\"..addon.."\\media\\rowbg", tile=false, insets={ left=0, right=0, top=1, bottom=0 }})
									tt.lines[l].cells[2]:SetBackdropColor(col[1],col[2],col[3],1);
									if (ns.profile[name].bgColoredStatus) then
										local col=C(statuscolors[v.status2] or "red","colortable");
										tt.lines[l]:SetBackdrop({bgFile="Interface\\AddOns\\"..addon.."\\media\\rowbg", tile=false, insets={ left=0, right=0, top=1, bottom=0 }})
										tt.lines[l]:SetBackdropColor(col[1],col[2],col[3],.37);
									end
								end
							else
								for _,at in ipairs(v.AbilitiesAndTraits) do
									a = a .. " |T"..at.icon..":14:14:0:0:64:64:4:56:4:56|t";
								end
								if v.levelXP~=0 then
									l = tt:AddLine( C(class,v.name), v.className.." ", ("%1.1f"):format(v.xp / v.levelXP * 100).."%", --[[v.iLevel,]] a );
								else
									l = tt:AddLine( C(class,v.name), v.className.." ", C("gray","100%"), --[[v.iLevel,]] a );
								end
								if v.quality>1 then
									local col = C(qualities[v.quality],"colortable");
									tt.lines[l].cells[1]:SetBackdrop({bgFile="Interface\\AddOns\\"..addon.."\\media\\rowbg", tile=false, insets={ left=0, right=0, top=1, bottom=0 }})
									tt.lines[l].cells[1]:SetBackdropColor(col[1],col[2],col[3],1);
									if (ns.profile[name].bgColoredStatus) then
										local col=C(statuscolors[v.status2] or "red","colortable");
										tt.lines[l]:SetBackdrop({bgFile="Interface\\AddOns\\"..addon.."\\media\\rowbg", tile=false, insets={ left=0, right=0, top=1, bottom=0 }})
										tt.lines[l]:SetBackdropColor(col[1],col[2],col[3],.37);
									end
								end
							end
						end
					end
				end
				subTitle=true;
			end
		end
		title=true;
	end

	if none then
		if name==nameF then
			tt:AddLine(L["No followers found..."]);
		else
			tt:AddLine(L["No ships found..."]);
		end
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0);
		ns.clickOptions.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

local function updater()
	if UnitLevel("player")>=90 and ((followerEnabled and followers.num>0) or (shipsEnabled and ships.num>0)) then
		ns.modules.followers_core.onevent(self,"GARRISON_FOLLOWER_LIST_UPDATE");
	end
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules.followers_core.init = function(self) end

ns.modules[nameF].init = function(self)
	followerEnabled=true;
end

ns.modules[nameS].init = function(self)
	shipsEnabled=true;
end

ns.modules.followers_core.onevent = function(self,event,msg)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[nameF],ns.profile[nameF]);
		ns.clickOptions.update(ns.modules[nameS],ns.profile[nameS]);
	elseif UnitLevel("player")>=90 then
		if (delay==true) then
			delay = false;
			C_Timer.After(4,ns.modules.followers_core.onevent);
			return;
		end

		-- garrison level
		garrLevel = C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_6_0) or 0;

		-- shipyard level
		if garrLevel>0 then
			local lvl = C_Garrison.GetOwnedBuildingInfoAbbrev(98);
			if lvl then syLevel=lvl-204; end
		end

		-- order hall level?
		if ns.build>70000000 then
			ohLevel = LE_GARRISON_TYPE_7_0~=nil and C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_7_0) or 0;
		end

		updateBroker();
	end
	if not ticker then
		ticker = C_Timer.NewTicker(ns.modules.followers_core.updateinterval,updater);
	end
end

ns.modules[nameF].onevent = ns.modules.followers_core.onevent;
ns.modules[nameS].onevent = ns.modules.followers_core.onevent;
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(self) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[nameF].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttF = ns.acquireTooltip({ttNameF, ttColumnsF, "LEFT", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "RIGHT"},{true},{self});
	createTooltip(ttF, nameF)
end

ns.modules[nameS].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttS = ns.acquireTooltip({ttNameS, ttColumnsS, "LEFT", "LEFT", "CENTER", "CENTER", "CENTER", "RIGHT","RIGHT"},{true},{self});
	createTooltip(ttS, nameS)
end

-- ns.modules[nameF].onleave = function(self) end
-- ns.modules[nameS].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end
