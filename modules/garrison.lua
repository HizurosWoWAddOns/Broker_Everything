
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.build<60000000 then return end


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Garrison" -- GARRISON_LOCATION_TOOLTIP
local ldbName,ttName,LName = name, name.."TT",GARRISON_LOCATION_TOOLTIP;
local tt,createMenu,ttColumns
local buildings,nBuildings,construct,nConstruct,blueprints3,achievements3 = {},0,{},0,{},{}
local longer,ticker = false,false;
local displayAchievements=false;
local buildings2achievements = {[9]=9129,[25]=9565,[27]=9523,[35]=9703,[38]=9497,[41]=9429,[62]=9453,[66]=9526,[117]=9406,[119]=9406,[121]=9406,[123]=9406,[125]=9406,[127]=9406,[129]=9406,[131]=9406,[134]=9462,[136]=9454,[140]=9468,[142]=9487,[144]=9478,[160]=9495,[163]=9527,[167]=9463};
local blueprintsL3 = {[9]=111967,[25]=111969,[27]=111971,[35]=109065,[38]=109063,[41]=109255,[62]=111996,[66]=112003,[117]=111991,[119]=111930,[121]=111989,[123]=109257,[125]=111973,[127]=111993,[129]=111979,[131]=111975,[134]=111928,[136]=111997,[140]=111977,[142]=111983,[144]=111987,[160]=111981,[163]=111985,[167]=111999};
local jobslots = {[25]=1,[27]=1,[28]=1,[62]=1,[63]=1,[117]=1,[118]=1,[119]=1,[120]=1,[121]=1,[122]=1,[123]=1,[124]=1,[125]=1,[126]=1,[127]=1,[128]=1,[129]=1,[130]=1,[131]=1,[132]=1,[133]=1,[135]=1,[136]=1,[137]=1,[138]=1};
local plot_order=setmetatable({[59]=1,[63]=2,[67]=3,[81]=4,[98]=5,[23]=6,[24]=7,[22]=8,[25]=9,[18]=10,[19]=11,[20]=12},{__index=function(t,k) local c=0; for i,v in pairs(t)do if(v>c)then c=v; end end c=c+1; rawset(t,k,c); return c; end});
local garrLevel, ohLevel, syLevel = 0,0,0;
local merchant=false;
local UseContainerItemHooked = false;
if ns.build>7000000 then
	LName = GARRISON_LOCATION_TOOLTIP.."/".."OrderHall";
end

-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\inv_garrison_resource", coords={0.05,0.95,0.05,0.95}}; --IconName::Garrison--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show garrison buildings, worker, active work orders, available blueprints, depending achievements and gives you a garrison cache forecast for all your chars"],
	events = {
		"PLAYER_ENTERING_WORLD",
		"GARRISON_LANDINGPAGE_SHIPMENTS",
		"GARRISON_UPDATE",
		"GARRISON_BUILDING_UPDATE",
		"GARRISON_BUILDING_PLACED",
		"GARRISON_BUILDING_REMOVED",
		"GARRISON_BUILDING_LIST_UPDATE",
		"GARRISON_BUILDING_ACTIVATED",
		"GARRISON_UPGRADEABLE_RESULT",
		"SHOW_LOOT_TOAST"
	},
	updateinterval = 30, -- 10
	config_defaults = {
		showConstruct = true,
		showBlueprints = true,
		showAchievements = true,
		showCacheForcast = true,
		showCacheForcastInBroker = true,
		showRealms = true,
		showChars = true,
		showAllRealms = false,
		showAllFactions = true
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator", alpha=0 },
		{ type="header", label=L["In tooltip options"]},
		{ type="separator", inMenuInvisible=true },
		{ type="toggle", name="showConstruct",            label=L["Show under construction"],     tooltip=L["Show list of buildings there are under construction in tooltip"] },
		{ type="toggle", name="showBlueprints",           label=L["Show blueprints"],             tooltip=L["Show available blueprints in tooltip"] },
		{ type="toggle", name="showAchievements",         label=L["Show archievements"],          tooltip=L["Show necessary archievements to unlock blueprints in tooltip"] },
		{ type="toggle", name="showCacheForcast",         label=L["Show cache forcast"],          tooltip=L["Show garrison cache forecast for all your characters in tooltip"] },
		{ type="toggle", name="showChars",                label=L["Show characters"],             tooltip=L["Show a list of your characters with count of ready and active missions in tooltip"] },
		{ type="toggle", name="showAllRealms",            label=L["Show all realms"],             tooltip=L["Show characters from all realms in tooltip."] },
		{ type="toggle", name="showAllFactions",          label=L["Show all factions"],           tooltip=L["Show characters from all factions in tooltip."] },
		{ type="separator", alpha=0 },
		{ type="header", label=L["On broker button options"]},
		{ type="separator", inMenuInvisible=true },
		{ type="toggle", name="showCacheForcastInBroker", label=L["Show cache forcast in title"], tooltip=L["Show garrison cache forecast for your current char in broker button"] },
	},
	clickOptions = {
		["1_open_garrison_report"] = {
			cfg_label = "Open garrison report", -- L["Open garrison report"]
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
local function strCut(str,length)
	if (strlen(str)>length) then
		return strsub(str,0,length).."...";
	end
	return str;
end

function createMenu(self)
	if (tt~=nil) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function AchievementTooltipShow(self)
	GameTooltip:SetOwner(self,"ANCHOR_NONE");
	if (select(1,self:GetCenter()) > (select(1,UIParent:GetWidth()) / 2)) then
		GameTooltip:SetPoint("RIGHT",tt,"LEFT",-2,0);
	else
		GameTooltip:SetPoint("LEFT",tt,"RIGHT",2,0);
	end
	GameTooltip:SetPoint("TOP",self,"TOP", 0, 4);

	GameTooltip:ClearLines();
	GameTooltip:SetHyperlink(GetAchievementLink(self.achievementId));

	GameTooltip:SetFrameLevel(self:GetFrameLevel()+1);
	GameTooltip:Show();
end

local function AchievementTooltipHide()
	GameTooltip:Hide();
end

local function toggleAchievementFrame()
	if ( not AchievementFrame ) then
		AchievementFrame_LoadUI();
	end
	
	if ( not AchievementFrame:IsShown() ) then
		AchievementFrame_ToggleAchievementFrame();
		AchievementFrame_SelectAchievement(v.id);
	else
		if ( AchievementFrameAchievements.selection ~= v.id ) then
			AchievementFrame_SelectAchievement(v.id);
		else
			AchievementFrame_ToggleAchievementFrame();
		end
	end
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	local now, timeleft, timeleftAll, shipmentsCurrent = time();
	local none, qualities = true,{"white","ff1eaa00","ff0070dd","ffa335ee"};
	local _,title = ns.DurationOrExpireDate(0,false,"Single|nduration","Single|nexpire date")
	local _,title2= ns.DurationOrExpireDate(0,false,"Overall|nduration","Overall|nexpire date")
	local building = "|T%s:14:14:0:0:64:64:4:56:4:56|t "..C("ltgray","(%d%s)").." "..C("ltyellow","%s");

	local _ = function(n)
		if (IsShiftKeyDown()) then -- TODO: modifier key adjustable...
			return date("%Y-%m-%d %H:%M",time() + n); -- TODO: timestring adjustable...
		end
		return SecondsToTime(n,true);
	end;

	tt:Clear();
	tt:AddHeader(C("dkyellow",LName));

	if (ohLevel>0 and ns.profile[name].showOrderhall) then
		
	end

	if (garrLevel>0 and ns.profile[name].showGarrison) then
		if (ns.profile[name].showChars and false) then
			tt:AddSeparator(4,0,0,0,0);
			local l=tt:AddLine( C("ltblue", L["Characters"]) ); -- 1

			-- Garrison /n level, buildings
			-- Jobs /n available, worker
			-- shipments /n finished, progress // duration /n next, all
			-- 

			if(IsShiftKeyDown())then
				tt:SetCell(l, 2, C("ltblue",GARRISON_LOCATION_TOOLTIP..		"|n"..C("green",L["level"])..		" / "..C("yellow",L["buildings"])), nil, "RIGHT", 1); --2 
				tt:SetCell(l, 3, C("ltblue",L["Shipments"]..	"|n"..C("green",L["finished"])..	" / "..C("yellow",L["in progress"])), nil, "RIGHT", 3); -- 3,4,5
				tt:SetCell(l, 6, C("ltblue",L["Jobs"]..			"|n"..C("green",L["available"])..	" / "..C("yellow",L["worker"])), nil, "RIGHT", 2); -- 6,7
			else
				tt:SetCell(l, 2, C("ltblue",GARRISON_LOCATION_TOOLTIP..		"|n"..C("green",L["level"])..		" / "..C("yellow",L["buildings"])), nil, "RIGHT", 1); --2 
				tt:SetCell(l, 3, C("ltblue",L["Shipments"]..	"|n"..C("green",L["finished"])..	" / "..C("yellow",L["in progress"])), nil, "RIGHT", 3); -- 3,4,5
				tt:SetCell(l, 6, C("ltblue",L["Jobs"]..			"|n"..C("green",L["available"])..	" / "..C("yellow",L["worker"])), nil, "RIGHT", 2); -- 6,7
			end
			tt:AddSeparator();
			local t=time();
			for i=1, #Broker_Everything_CharacterDB.order do
				local name_realm = Broker_Everything_CharacterDB.order[i];
				local v = Broker_Everything_CharacterDB[name_realm];
				local charName,realm=strsplit("-",name_realm);
				if (ns.profile[name].showAllRealms~=true and realm~=ns.realm) or (ns.profile[name].showAllFactions~=true and v.faction~=ns.player.faction) then
					-- do nothing
				elseif(v.missions)then
					local faction = v.faction and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
					realm = realm~=ns.realm and C("dkyellow"," - "..ns.scm(realm)) or "";
					local l=tt:AddLine(C(v.class,ns.scm(charName)) .. realm .. faction );
					if(name_realm==ns.player.name_realm)then
						--- background highlight
					end

					if(IsShiftKeyDown())then
					else
					end
					if(name_realm==ns.player.name_realm)then
						tt:SetLineColor(l, 0.1, 0.3, 0.6);
					end
				end
			end
		end

		if (nBuildings>0) then
			local lst,longer = {},false;
			for i,v in pairs(buildings) do
				if (v) then
					timeleft,timeleftAll = nil,nil;
					if (not v.shipmentsTotal) then
						v.shipmentsTotal = 0;
					end
					if (not v.shipmentsReady) then
						v.shipmentsReady = 0;
					end
					if (v.creationTime) and (v.creationTime>0) then
						timeleft =     ns.DurationOrExpireDate( (v.creationTime + v.duration) - now );
						timeleftAll =  ns.DurationOrExpireDate( (v.creationTime + (v.duration * (v.shipmentsTotal - v.shipmentsReady) ) ) - now );
					end
					if ((v.shipmentsTotal - v.shipmentsReady)>1) then
						longer = true;
					end
					tinsert(lst,{
						(building):format(
							v.texture,
							v.rank,
							((v.canUpgrade) and "|T"..ns.media.."GarrUpgrade:12:12:0:0:32:32:4:24:4:24|t") or  "", 
							v.name .. ((v.canActivate) and C("orange"," ("..L["Upgrade finished"]..")") or "")
						),
						((v.follower) and C(v.follower.class,v.follower.name) .. C(qualities[v.follower.quality], " ("..v.follower.level..")")) or ((jobslots[v.buildingID]~=nil) and C("gray","< "..L["free job"].." >")) or "",
						(v.shipmentCapacity) and v.shipmentCapacity or "",
						(v.shipmentCapacity and v.shipmentsReady>0) and v.shipmentsReady or "",
						(v.shipmentCapacity and v.shipmentsTotal>0) and (v.shipmentsTotal - v.shipmentsReady) or "",
						(v.shipmentCapacity and timeleft) and timeleft or "",
						(v.shipmentCapacity and timeleftAll and longer) and timeleftAll or ""
					});
				end
			end

			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",NAME),C("ltblue","Follower"),C("ltblue",L["Max."]),C("ltblue",READY),C("ltblue",L["In|nprogress"]),C("ltblue",L[title]),(longer) and C("ltblue",L[title2]) or "");
			tt:AddSeparator();
			for i=1, #lst do
				tt:AddLine(unpack(lst[i]));
			end
			none = false;
		end

		-- cunstruction list
		if (ns.profile[name].showConstruct) and (nConstruct>0) then
			if (not none) then tt:AddSeparator(4,0,0,0,0); end
			local _,title = ns.DurationOrExpireDate(0,false,"Duration","Expire date");
			local l,c = tt:AddLine(C("ltblue",L["Under construction"]));
			tt:SetCell(l, 7, C("ltblue",L[title]), "RIGHT");
			tt:AddSeparator();
			for i,v in ipairs(construct) do
				local l, c = tt:AddLine(C("ltyellow",v.name))
				tt:SetCell(l, 7, ns.DurationOrExpireDate(v.duration), "RIGHT");
			end

			none = false;
		end

		-- blueprints
		if (ns.profile[name].showBlueprints) and (#blueprints3>0) then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Available blueprints level 3"]));
			tt:AddSeparator();
			for i,v in ipairs(blueprints3) do
				if (v.iicon) and (v.iname) then
					local l = tt:AddLine(("|T%s:14:14:0:0:64:64:4:56:4:56|t "..C("ltyellow","%s")):format(v.icon,v.name));
					tt:SetCell(l,2, ("|T%s:14:14:0:0:64:64:4:56:4:56|t "..C("ltyellow","%s")):format(v.iicon,v.iname), nil,nil,5);
				end
			end
		end

		-- achievements
		if (ns.profile[name].showAchievements) and (#achievements3>0) then
			displayAchievements = true;
			tt:AddSeparator(4,0,0,0,0);
			local l,c = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["Necessary achievements for blueprints level 3"]),nil,nil,3);
			tt:AddSeparator();
			for i,v in ipairs(achievements3) do
				local l = tt:AddLine(
					("|T%s:14:14:0:0:64:64:4:56:4:56|t "..C("ltyellow","%s")):format(v.bicon,v.bname),
					("|T%s:14:14:0:0:64:64:4:56:4:56|t "..C("ltyellow","%s")):format(v.icon,v.name)
				);
				tt:SetCell(l,3, v.need, nil,"LEFT",5);
				tt.lines[l].achievementId = v.id;
				tt:SetLineScript(l,"OnMouseUp", toggleAchievementFrame);
				tt:SetLineScript(l,"OnEnter", AchievementTooltipShow);
				tt:SetLineScript(l,"OnLeave", AchievementTooltipHide);
			end
		end
	end

	-- garrison cache forecast
	if (ns.profile[name].showCacheForcast) then
		local _ = function(k,v)
			local l=tt:AddLine();
			local x,y = strsplit("-",k);
			if (not ns.profile[name].showRealms) then
				y = (y~=ns.realm) and C("dkyellow","*") or "";
			else
				y = (y~=ns.realm) and C("gray"," - ")..C("dkyellow",y) or "";
			end
			tt:SetCell(l,1,C(v.class or "white", x)..y,nil,nil,ttColumns-1);
			if(v.garrison_cache[1]==0)then
				tt:SetCell(l,ttColumns, C("orange","n/a"));
			else
				local cache = floor((time()-v.garrison_cache[1])/600);
				local cap = (v.garrison_cache[2]) and 1000 or 500;
				if(v.garrison_cache[2]~=nil and cache>=cap)then
					cache = C("red",cap);
					cap = C("red",cap);
				elseif(v.garrison_cache[2]==nil)then
					cap = C("dkyellow",cap);
				end
				tt:SetCell(l,ttColumns, ("~ %s/%s"):format(cache,cap)); -- 10 minutes = 1 garrison resource
			end
			if(k==ns.player.name_realm)then
				tt:SetLineColor(l, 0.1, 0.3, 0.6);
			end
		end
		tt:AddSeparator(4,0,0,0,0);
		local l = tt:AddLine();
		local None=true;
		tt:SetCell(l,1,C("ltblue",L["Garrison cache forcast"]),nil,nil,ttColumns);
		tt:AddSeparator();
		for i=1, #Broker_Everything_CharacterDB.order do
			local v = Broker_Everything_CharacterDB[Broker_Everything_CharacterDB.order[i]];
			local c,r = strsplit("-",Broker_Everything_CharacterDB.order[i]);
			if (ns.profile[name].showAllRealms~=true and r~=ns.realm) or (ns.profile[name].showAllFactions~=true and v.faction~=ns.player.faction) or v.garrison==nil or (v.garrison~=nil and (v.garrison[1]==nil) or (v.garrison[1]==0))then
				-- do nothing
			elseif (v.garrison_cache and v.garrison_cache[1]) then
				_(Broker_Everything_CharacterDB.order[i],v);
				None=false;
			end
		end
		if (None) then
			tt:AddLine(L["No data found..."]);
		end
		none=false;
	end

	if (none) then
		tt:AddLine(L["No data to display..."]);
	elseif (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0);
		local _,_,mod = ns.DurationOrExpireDate();
		if (displayAchievements) then
			ns.AddSpannedLine(tt,C("ltblue",L["Click"]).." || "..C("green",L["Open achievement"]),ttColumns);
		end
		ns.AddSpannedLine(tt,C("copper",L["Hold "..mod]).." || "..C("green",L["Show expire date instead of duration"]),ttColumns);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
	ns.roundupTooltip(tt);
end

local function updateBlueprints(Data)
	local known = false;
	for i,v in ipairs(Data.lines) do
		if v:find(ITEM_SPELL_KNOWN) then
			known=true;
		end
	end
	if (not known) then
		tinsert(blueprints3,{
			id = Data.id,
			name = Data.passThrough.name,
			icon = Data.passThroughicon,
			iname = Data.itemName,
			iicon = Data.itemTexture,
			texPrefix = Data.passThrough.texPrefix,
		});
	end
end

local function updater()
	C_Garrison.RequestLandingPageShipmentInfo(); -- stupid event triggering to get new data
	C_Garrison.RequestShipmentInfo();
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name;
end

ns.modules[name].onevent = function(self,event,...)
	if(event=="PLAYER_ENTERING_WORLD")then

		if ns.toon.garrison and ns.toon.garrison.cache then
			for i=1, #Broker_Everything_CharacterDB.order do
				local k = Broker_Everything_CharacterDB.order[i];
				local v = Broker_Everything_CharacterDB[k];
				if (v.garrison and v.garrison.cache) then
					Broker_Everything_CharacterDB[k].garrison_cache = {
						Broker_Everything_CharacterDB[k].garrison.cache or 0,
						(Broker_Everything_CharacterDB[k].garrison.trade_agreement==true)
					};
					Broker_Everything_CharacterDB[k].garrison = {};
				end
			end
		end

		if not ns.toon.garrison_cache then
			ns.toon.garrison_cache = {0,false};
		elseif(ns.toon.garrison_cache[1]==nil)then
			ns.toon.garrison_cache[1]=0;
		end

		--- usage tracking for the trade agreement to set garrison cache limit up to 1000
		if(not UseContainerItemHooked and UnitLevel("player")==MAX_PLAYER_LEVEL and not ns.toon.garrison_cache[2])then
			ns.UseContainerItemHook.registerItemID(name,128294,function(bag,slot,itemId)
				ns.toon.garrison_cache[2]=true;
				ns.modules[name].onevent(self,"BE_CUSTOM_EVENT");
			end);
		end
	elseif (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	else
		local progress,ready=0,0;
		local garrLevel = C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_6_0) or 0;
		local tmp, names, _, bName, texture, shipmentCapacity, shipmentsReady, shipmentsTotal, creationTime, duration, timeleftString, shipmentsCurrent = {}, {};

		if not ticker and garrLevel>0 then
			ticker = C_Timer.NewTicker(ns.modules[name].updateinterval,updater);
		end

		wipe(construct); wipe(blueprints3); wipe(achievements3);
		longer,nConstruct,nBuildings = false,0,0;

		local cBuildings,cJobs,cShipments=2,3,4;
		ns.toon.garrison={garrLevel,0,{0,0},{}};
		local cache=ns.toon.garrison;

		buildings = C_Garrison.GetBuildings(LE_GARRISON_TYPE_6_0) or {};

		for i=1, #buildings do
			if (buildings[i]) and (buildings[i].buildingID) then
				_, buildings[i].name, _, buildings[i].texture, buildings[i].rank, buildings[i].isBuilding, buildings[i].timeStart, buildings[i].buildTime, buildings[i].canActivate, buildings[i].canUpgrade, buildings[i].isPrebuilt = C_Garrison.GetOwnedBuildingInfoAbbrev(buildings[i].plotID);
				_, _, _, _, _, _, _, _, _, _, _, _, _, buildings[i].upgrades, _, _, buildings[i].hasFollowerSlot = C_Garrison.GetBuildingInfo(buildings[i].plotID);
				_, _, buildings[i].shipmentCapacity, buildings[i].shipmentsReady, buildings[i].shipmentsTotal, buildings[i].creationTime, buildings[i].duration = C_Garrison.GetLandingPageShipmentInfo(buildings[i].buildingID);

				if(buildings[i].plotID==98)then
					buildings[i].canUpgrade=false; -- correct wrong displaying upgrade status for the shipyard
				end

				-- catch double posted buildings while under construction
				if (buildings[i].name) then
					if (names[buildings[i].name]) then
						if (names[buildings[i].name][2]>buildings[i].rank) then
							buildings[names[buildings[i].name][1]] = nil;
						else
							buildings[i] = nil;
						end
					else
						names[buildings[i].name] = {i,buildings[i].rank};
					end
				end

				if(jobslots[buildings[i].buildingID])then
					cache[cJobs][1] = cache[cJobs][1]+1;
				end

				local _,_,_,_,fID = C_Garrison.GetFollowerInfoForBuilding(buildings[i].plotID);
				if (fID) then
					buildings[i].follower = C_Garrison.GetFollowerInfo(fID);
					if buildings[i].follower then
						buildings[i].follower.class = strsub(buildings[i].follower.classAtlas,23);
						--(isBuilding or canActivate or not owned);
						cache[cJobs][2] = cache[cJobs][2]+1;
					end
				end

				if (buildings[i].shipmentCapacity==0) then
					buildings[i].shipmentCapacity = nil;
				else
					buildings[i].shipmentsReady = buildings[i].shipmentsReady or 0;
					if (buildings[i].shipmentsReady) then
						ready = ready + buildings[i].shipmentsReady;
					end

					buildings[i].shipmentsTotal = buildings[i].shipmentsTotal or 0;
					if (buildings[i].shipmentsTotal) then
						progress = progress + buildings[i].shipmentsTotal;
					end

					tinsert(cache[cShipments],{
						buildings[i].shipmentCapacity,
						time(),
						buildings[i].shipmentsReady,
						buildings[i].shipmentsTotal,
						buildings[i].creationTime or 0,
						buildings[i].duration or 0
					});
				end

				if (not buildings[i].texture) then
					buildings[i].texture = ns.icon_fallback;
				end

				nBuildings = nBuildings + 1;

				local aname, completed, aicon, wasEarnedByMe, earnedBy,numCriteria,description,_;
				local id, pname, texPrefix, icon, rank, isBuilding, timeStart, buildTime, canActivate, canUpgrade, isPrebuilt = C_Garrison.GetOwnedBuildingInfoAbbrev(buildings[i].plotID);
				if (id) then
					local tooltip, cost, goldQty, currencyID, buildTime2, needsPlan = C_Garrison.GetBuildingTooltip(id);
					local aid = buildings2achievements[id];
					local timeEnd = timeStart + buildTime;
					local duration = timeEnd - time();
					if (aid) then
						_, aname, _, completed, _, _, _, description, _, aicon, _, _, wasEarnedByMe, earnedBy = GetAchievementInfo(aid);
						numCriteria = GetAchievementNumCriteria(aid);
					end
					if (isBuilding) or (duration>0) then
						tinsert(construct, {
							id			= id,
							icon		= icon,
							name		= pname,
							texPrefix	= texPrefix,
							rank		= rank,
							isBuilding	= isBuilding,

							isPrebuilt	= isPrebuilt,
							timeStart	= timeStart,
							timeStartStr= date("%Y-%m-%d %H:%M",timeStart),
							timeEnd		= timeEnd,
							timeEndStr	= date("%Y-%m-%d %H:%M",timeEnd),
							duration	= duration,
							durationStr	= duration
						});
						nConstruct = nConstruct + 1;
					elseif (garrLevel==3) and (rank==2) and (blueprintsL3[id]) then
						--local data = ns.GetItemData(blueprintsL3[id]);
						if (aid) and (not completed) then
							local need = {};
							if (numCriteria>0) then
								for ai=1, numCriteria do
									local criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString = GetAchievementCriteriaInfo(aid, ai);
									if (not completed) and (bit.band(flags, EVALUATION_TREE_FLAG_PROGRESS_BAR)==EVALUATION_TREE_FLAG_PROGRESS_BAR) then
										tinsert(need,quantityString);
									end
								end
								if (#need==0) then
									need = {L["More info in tooltip..."]};
								end
							end
							tinsert(achievements3,{
								id = aid,
								name = strCut(aname,25),
								icon = aicon,
								bname = pname,25,
								bicon = icon,
								need = table.concat(need,"|n"),
								progress = false -- later
							});
						else
							ns.ScanTT.query({type="item",id=blueprintsL3[id],callback=updateBlueprints,passThrough={name=pname,icon=icon,texPrefix=texPrefix}});
						end
					end
				end
				tmp[plot_order[buildings[i].plotID]] = buildings[i];
			end
		end

		if(#buildings>0)then
			buildings = tmp;
		end

		cache[cBuildings] = #buildings;

		if (event=="SHOW_LOOT_TOAST") then
			local typeIdentifier, _, quantity, _, _, isPersonal, lootSource = ...;
			if (isPersonal==true) and (typeIdentifier=="currency") and (lootSource==10) then
				if(ns.toon.garrison_cache[1]~=nil and ns.toon.garrison_cache[1]~=0)then
					local forcast = floor((time()-ns.toon.garrison_cache[1])/600);
					if(quantity>500)then
						ns.toon.garrison_cache[2]=true; -- Trade Agreement: Arakkoa Outcasts (128294)
					elseif(forcast > quantity and quantity==500)then
						ns.toon.garrison_cache[2]=false; -- no Trade Agreement
					end
				end
				ns.toon.garrison_cache[1]=time();
			end
		end

		local ohLevel = C_Garrison.GetGarrisonInfo(LE_GARRISON_TYPE_7_0) or 0;

		

		local obj = ns.LDB:GetDataObjectByName(ldbName);
		local title = {};
		tinsert(title, C("ltblue",ready) .."/".. C("orange",progress - ready) );

		if (ns.profile[name].showCacheForcastInBroker) then
			if(ns.toon.garrison_cache[1]==nil or ns.toon.garrison_cache[1]==0)then
				colCache = "orange";
				colCap = "red";
				tinsert(title, C("orange","n/a") );
			else
				local colCache,colCap,cap = "white","white",500;
				local cache = floor((time()-ns.toon.garrison_cache[1])/600);

				if(ns.toon.garrison_cache[2])then
					cap = 1000;
				end

				if(cache>=cap)then
					colCache = "gray";
					if(ns.toon.garrison_cache[2]==nil)then
						colCap = "dkyellow";
					else
						colCap = "red";
					end
				end
				tinsert(title, C(colCache,cache) .."/".. C(colCap,cap) );
			end
		end

		obj.text = table.concat(title,", ");
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

end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(self) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttColumns = 7;
	tt = ns.acquireTooltip({ttName, 7, "LEFT","LEFT", "CENTER", "CENTER", "CENTER", "RIGHT","RIGHT"},{not displayAchievements},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

