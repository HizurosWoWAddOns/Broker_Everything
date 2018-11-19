
-- module independent variables --
----------------------------------
local addon, ns = ...
if ns.build<60000000 then return end
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local nameF,nameS = "Followers","Ships"; -- GARRISON_FOLLOWERS, GARRISON_SHIPYARD_FOLLOWERS L["ModDesc-Followers"] L["ModDesc-Ships"]
local ttNameF, ttColumnsF, ttF, moduleF = nameF.."TT", 7;
local ttNameS, ttColumnsS, ttS, moduleS = nameS.."TT" ,7;
local followers,ships,champions,troops = {num=0},{num=0},{num=0},{num=0};
local updateinterval, garrLevel, ohLevel, syLevel = 30,0,0,0;
local delayF,delayS,ticker=true,true;
local clickOptionsRename = {
	["1_open_garrison_report"] = "garrreport",
	["2_open_menu"] = "OptionMenu"
};
local  clickOptions = {
	["garrreport"] = "GarrisonReport",
	["menu"] = "OptionMenu"
};
local clickOptionsDefaults = {
	garrreport = "__NONE",
	menu = "_RIGHT"
};


-- register icon names and default files --
-------------------------------------------
I[nameF]  = {iconfile="Interface\\Icons\\Achievement_GarrisonFolLower_Rare", coords={0.1,0.9,0.1,0.9} }; --IconName::Follower--
I[nameS]  = {iconfile="Interface\\Icons\\Achievement_GarrisonFolLower_Rare", coords={0.1,0.9,0.1,0.9} }; --IconName::Ships--


-- some local functions --
--------------------------
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

local function updateBroker(name)
	if name==nameF then
		local aio = {0,0,0,0,0};
		local single = {};
		if ns.profile[name].showFollowersOnBroker and garrLevel>0 then
			getFollowers("followers");
			aio[1]=aio[1]+(followers.onresting_num or 0);
			aio[2]=aio[2]+(followers.onmission_num or 0);
			aio[3]=aio[3]+(followers.onwork_num or 0);
			aio[4]=aio[4]+(followers.available_num or 0);
			aio[5]=aio[5]+(followers.num or 0);
			tinsert(single, ("%s/%s/%s/%s"):format(C("ltblue",followers.onresting_num),C("yellow",followers.onmission_num+followers.onwork_num),C("green",followers.available_num),followers.num));
		end
		if ns.profile[name].showChampionsOnBroker and LE_GARRISON_TYPE_7_0 and ohLevel>0 then
			getFollowers("champions");
			aio[1]=aio[1]+(champions.onresting_num or 0);
			aio[2]=aio[2]+(champions.onmission_num or 0);
			aio[3]=aio[3]+(champions.onwork_num or 0);
			aio[4]=aio[4]+(champions.available_num or 0);
			aio[5]=aio[5]+(champions.num or 0);
			tinsert(single, ("%s/%s/%s/%s"):format(C("ltblue",champions.onresting_num),C("yellow",champions.onmission_num+champions.onwork_num),C("green",champions.available_num),champions.num));
		end
		if ns.profile[name].showTroopsOnBroker and LE_GARRISON_TYPE_7_0 and ohLevel>0 then
			getFollowers("troops");
			aio[1]=aio[1]+(troops.onresting_num or 0);
			aio[2]=aio[2]+(troops.onmission_num or 0);
			aio[3]=aio[3]+(troops.onwork_num or 0);
			aio[4]=aio[4]+(troops.available_num or 0);
			aio[5]=aio[5]+(troops.num or 0);
			tinsert(single, ("%s/%s/%s/%s"):format(C("ltblue",troops.onresting_num),C("yellow",troops.onmission_num+troops.onwork_num),C("green",troops.available_num),troops.num));
		end
		local obj = ns.LDB:GetDataObjectByName(moduleF.ldbName);
		if ns.profile[name].showAllInOne then
			obj.text = ("%s/%s/%s/%s"):format(C("ltblue",aio[1]),C("yellow",aio[2]+aio[3]),C("green",aio[4]),aio[5]);
		else
			obj.text = #single>0 and table.concat(single,", ") or L[nameF];
		end
	elseif name==nameS then
		local obj = ns.LDB:GetDataObjectByName(moduleS.ldbName);
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
	local colors,qualities,count = {"ltblue","yellow","yellow","green","red"},{"white","ff1eaa00","ff0070dd","ffa335ee","ffff8000","ffB3965D"},0
	local statuscolors = {["onresting"]="ltblue",["onwork"]="orange",["onmission"]="yellow",["available"]="green",["disabled"]="red"};
	local none=true;

	if tt.lines~=nil then tt:Clear(); end
	if name==nameS then
		tt:AddHeader(C("dkyellow",GARRISON_SHIPYARD_FOLLOWERS));
	elseif ns.build>70000000 then
		tt:AddHeader(C("dkyellow",("%s, %s, %s"):format(GARRISON_FOLLOWERS,FOLLOWERLIST_LABEL_CHAMPIONS,FOLLOWERLIST_LABEL_TROOPS)));
	else
		tt:AddHeader(C("dkyellow",GARRISON_FOLLOWERS));
	end

	if (ns.profile[name].showChars) then
		tt:AddSeparator(4,0,0,0,0)
		local l=tt:AddLine( C("ltblue",CHARACTER) ); -- 1
		if(IsShiftKeyDown())then
			tt:SetCell(l, 2, C("ltblue",L["Back from missions"]).."|n"..L["next"].." / "..SPELL_TARGET_TYPE12_DESC, nil, "RIGHT", 3);
		else
			tt:SetCell(l, 2, C("ltblue",GARRISON_FOLLOWER_ON_MISSION) .."|n".. C("green",GOAL_COMPLETED) .." / ".. C("yellow",GARRISON_SHIPYARD_MSSION_INPROGRESS_TOOLTIP), nil, "RIGHT", 3);
		end
		tt:SetCell(l, 5, C("ltblue",L["Without missions"])     .."|n".. C("green",L["Chilling"]) .." / ".. C("yellow",GARRISON_FOLLOWER_WORKING), nil, "RIGHT", 2);
		tt:SetCell(l, 7, C("ltblue",GARRISON_FOLLOWERS) .. "|n" .. C("cyan",COLLECTED) .." / ".. C("green",CONTRIBUTION_ACTIVE) .." / ".. C("yellow",GARRISON_FOLLOWER_INACTIVE));

		tt:AddSeparator();
		local t=time();

		for i=1, #Broker_Everything_CharacterDB.order do
			local name_realm = Broker_Everything_CharacterDB.order[i];
			local v = Broker_Everything_CharacterDB[name_realm];
			local charName,realm=strsplit("-",name_realm,2);

			local lst = {};
			if name==nameF then
				tinsert(lst,{"followers","FollowersAbbrev"});
				if v.champions then
					tinsert(lst,{"champions","ChampsAbbrev"});
				end
			else
				tinsert(lst,{"ships","ShipsAbbrev"});
			end

			if (ns.player.name_realm~=name_realm) and ns.showThisChar(name,realm,v.faction) then
				local faction = v.faction and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
				local l=tt:AddLine(C(v.class,ns.scm(charName)) .. ns.showRealmName(name,realm) .. faction );

				local n,a,cMissions,cWorking,cCollected = 0,0;
				local c = {}
				if name==nameF and (followers.num>0 or champions.num>0) then
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

				elseif name==nameS and ships.num>0 then
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

	if name==nameF and ns.profile[name].hideWorking then
		tableTitles["onwork"] = false;
	end

	if name==nameF and ns.profile[name].hideDisabled then
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
			tt:AddLine(C("gray",L["No followers found..."]));
		else
			tt:AddLine(C("gray",L["No ships found..."]));
		end
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0);
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

-- module functions and variables --
------------------------------------
moduleF = {
	events = {
		"PLAYER_LOGIN",
		"GARRISON_FOLLOWER_LIST_UPDATE",
		"GARRISON_FOLLOWER_UPGRADED",
		"GARRISON_FOLLOWER_XP_CHANGED",
		"GARRISON_FOLLOWER_REMOVED",
	},
	config_defaults = {
		enabled = false,
		showAllInOne = true,
		showFollowersOnBroker = true,
		showChampionsOnBroker = true,
		showTroopsOnBroker = true,

		bgColoredStatus = true,
		hideDisabled=false,
		hideWorking=false,
		showChars = true,

		showAllFactions=true,
		showRealmNames=true,
		showCharsFrom="2",

		showFollowers = true,
		showChampions = true,
		showTroops = true
	},
	clickOptionsRename = clickOptionsRename,
	clickOptions = clickOptions
}

moduleS = {
	--icon_suffix = "",
	events = {
		"PLAYER_LOGIN",
		"GARRISON_FOLLOWER_LIST_UPDATE",
		"GARRISON_FOLLOWER_UPGRADED",
		"GARRISON_FOLLOWER_XP_CHANGED",
		"GARRISON_FOLLOWER_REMOVED",
	},
	config_defaults = {
		enabled = false,
		bgColoredStatus = true,
		showChars = true,
		showAllFactions = true
	},
	clickOptionsRename = clickOptionsRename,
	clickOptions = clickOptions
}

ns.ClickOpts.addDefaults(moduleF,clickOptionsDefaults);
ns.ClickOpts.addDefaults(moduleS,clickOptionsDefaults);

function moduleF.options()
	return {
		broker = {
			showAllInOne={ type="toggle", order=1, name=L["Show all in one"],       desc=L["Show all counts of followers, champions and troops as overall summary on broker button. You can disable single types with following toggles."]},
			showFollowersOnBroker={ type="toggle", order=2, name=L["Show followers"],        desc=L["Show followers summary on broker button"]},
			showChampionsOnBroker={ type="toggle", order=3, name=L["Show champions"],        desc=L["Show champions summary on broker button"]},
			showTroopsOnBroker={ type="toggle", order=4, name=L["Show troops"],           desc=L["Show troops summary on broker button"]},
		},
		tooltip = {
			bgColoredStatus={ type="toggle", order=1, name=L["Background colored row for status"], desc=L["Use background colored row for follower status instead to split in separate tables"] },
			hideDisabled={ type="toggle", order=2, name=L["Hide disabled followers"],           desc=L["Hide disabled followers in tooltip"] },
			hideWorking={ type="toggle", order=3, name=L["Hide working followers"],            desc=L["Hide working followers in tooltip"]},
			showChars={ type="toggle", order=4, name=L["Show characters"],                   desc=L["Show a list of your characters with count of chilling, working and followers on missions in tooltip"] },
			showAllFactions=5,
			showRealmNames=6,
			showCharsFrom=7,
			showFollowers={ type="toggle", order=8, name=L["Show followers"],                    desc=L["Show followers in tooltip"]},
			showChampions={ type="toggle", order=9, name=L["Show champions"],                    desc=L["Show champions in tooltip"]},
			showTroops={ type="toggle", order=10, name=L["Show troops"],                       desc=L["Show troops in tooltip"]},
		},
		misc = nil,
	},
	{
		bgColoredStatus=true,
		hideDisabled=true,
		hideWorking=true,
	}
end

function moduleS.options()
	return {
		broker = nil,
		tooltip = {
			bgColoredStatus={ type="toggle", order=1, name=L["Background colored row for status"], desc=L["Use background colored row for follower status instead to split in separate tables"] },
			separator={ type="separator", order=2},
			showChars={ type="toggle", order=3, name=L["Show characters"],          desc=L["Show a list of your characters with count of chilling, working and ships on missions in tooltip"] },
			showAllFactions=4,
			showRealmNames=5,
			showCharsFrom=6

		},
		misc = nil,
	},
	{
		bgColoredStatus=true
	}
end

-- function moduleF.init(self) end
-- function moduleS.init(self) end

function moduleF.onevent(self,event)
	if (event=="BE_UPDATE_CFG") then
		ns.ClickOpts.update(moduleF,ns.profile[nameF]);
	elseif UnitLevel("player")>=90 then
		if (delayF==true) then
			delayF = false;
			C_Timer.After(4,moduleF.onevent);
			return;
		end

		-- garrison level
		garrLevel = C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_6_0) or 0;

		-- order hall level
		if ns.build>70000000 then
			ohLevel = LE_GARRISON_TYPE_7_0~=nil and C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_7_0) or 0;
		end

		updateBroker(nameF);
	end
end

function moduleS.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(moduleS,ns.profile[nameS]);
	elseif UnitLevel("player")>=90 then
		if (delayS==true) then
			delayS = false;
			C_Timer.After(4,moduleS.onevent);
			return;
		end

		-- shipyard level
		if garrLevel>0 then
			local lvl = C_Garrison.GetOwnedBuildingInfoAbbrev(98);
			if lvl then syLevel=lvl-204; end
		end

		-- order hall level
		if ns.build>70000000 then
			ohLevel = LE_GARRISON_TYPE_7_0~=nil and C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_7_0) or 0;
		end

		updateBroker(nameS);
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(self) end

function moduleF.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttF = ns.acquireTooltip({ttNameF, ttColumnsF, "LEFT", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "RIGHT"},{true},{self});
	createTooltip(ttF, nameF)
end

function moduleS.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttS = ns.acquireTooltip({ttNameS, ttColumnsS, "LEFT", "LEFT", "CENTER", "CENTER", "CENTER", "RIGHT","RIGHT"},{true},{self});
	createTooltip(ttS, nameS)
end

-- function moduleF.onleave(self) end
-- function moduleS.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[nameF] = moduleF;
ns.modules[nameS] = moduleS;
