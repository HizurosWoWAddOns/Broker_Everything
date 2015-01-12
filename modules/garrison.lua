
----------------------------------
-- module independent variables --
----------------------------------
	local addon, ns = ...
	local C, L, I = ns.LC.color, ns.L, ns.I

	if ns.build<60000000 then return end

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Garrison" -- L["Garrison"]
local ldbName = name
local tt,createMenu,ttColumns
local ttName = name.."TT"
local buildings,nBuildings,construct,nConstruct,blueprints3,achievements3 = {},0,{},0,{},{}
local updater = false;
local longer = false;
local displayAchievements=false;
local buildings2achievements = {[9]=9129,[25]=9565,[27]=9523,[35]=9703,[38]=9497,[41]=9429,[62]=9453,[66]=9526,[117]=9406,[119]=9406,[121]=9406,[123]=9406,[125]=9406,[127]=9406,[129]=9406,[131]=9406,[134]=9462,[136]=9454,[140]=9468,[142]=9487,[144]=9478,[160]=9495,[163]=9527,[167]=9463};
local blueprintsL3 = {[9]=111967,[25]=111969,[27]=111971,[35]=109065,[38]=109063,[41]=109255,[62]=111996,[66]=112003,[117]=111991,[119]=111930,[121]=111989,[123]=109257,[125]=111973,[127]=111993,[129]=111979,[131]=111975,[134]=111928,[136]=111997,[140]=111977,[142]=111983,[144]=111987,[160]=111981,[163]=111985,[167]=111999};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\inv_garrison_resource", coords={0.05,0.95,0.05,0.95}}; --IconName::Garrison--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to buildings of your garrison and there active work orders."], -- Display also if blueprints available that depending on achievements.
	enabled = false,
	events = {
		"GARRISON_LANDINGPAGE_SHIPMENTS",
		"GARRISON_UPDATE",
		"GARRISON_BUILDING_UPDATE",
		"GARRISON_BUILDING_PLACED",
		"GARRISON_BUILDING_REMOVED",
		"GARRISON_BUILDING_LIST_UPDATE",
		"GARRISON_BUILDING_ACTIVATED",
		"GARRISON_UPGRADEABLE_RESULT",
	},
	updateinterval = 30, -- 10
	config_defaults = {},
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

local function AchievementTooltip(self,link)
	if (self) then
		GameTooltip:SetOwner(self,"ANCHOR_NONE");
		if (select(1,self:GetCenter()) > (select(1,UIParent:GetWidth()) / 2)) then
			GameTooltip:SetPoint("RIGHT",tt,"LEFT",-2,0);
		else
			GameTooltip:SetPoint("LEFT",tt,"RIGHT",2,0);
		end
		GameTooltip:SetPoint("TOP",self,"TOP", 0, 4);

		GameTooltip:ClearLines();
		GameTooltip:SetHyperlink(link);

		GameTooltip:SetFrameLevel(self:GetFrameLevel()+1);
		GameTooltip:Show();
	else
		GameTooltip:Hide();
	end
end


local function makeTooltip(tt)
	local now, timeleft, timeleftAll, shipmentsCurrent = time();
	local none, qualities = true,{"white","ff1eaa00","ff0070dd","ffa335ee"};
	local _,title = ns.DurationOrExpireDate(0,false,"Single|nduration","Single|nexpire date")
	local _,title2= ns.DurationOrExpireDate(0,false,"Overall|nduration","Overall|nexpire date")
	local building = ""..
					"|T%s:14:14:0:0:64:64:4:56:4:56|t "..
					C("ltgray","(%d%s)")..
					" "..
					C("ltyellow","%s")..
					"";
	local _ = function(n)
		if (IsShiftKeyDown()) then -- TODO: modifier key adjustable...
			return date("%Y-%m-%d %H:%M",time() + n); -- TODO: timestring adjustable...
		end
		return SecondsToTime(n,true);
	end;
	tt:Clear();
	tt:AddHeader(C("dkyellow",L[name]));

	if (nBuildings>0) then
		local lst,longer = {},false;
		for i,v in ipairs(buildings) do
			if (v) then
				timeleft,timeleftAll = nil,nil;
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
						(v.canUpgrade) and "|T"..ns.media.."GarrUpgrade:12:12:0:0:32:32:4:24:4:24|t" or "",
						v.name
					),
					(v.follower) and C(v.follower.class,v.follower.name) .. C(qualities[v.follower.quality], " ("..v.follower.level..")") or "",
					(v.shipmentCapacity) and v.shipmentCapacity or "",
					(v.shipmentCapacity and v.shipmentsReady>0) and v.shipmentsReady or "",
					(v.shipmentCapacity and v.shipmentsTotal>0) and (v.shipmentsTotal - v.shipmentsReady) or "",
					(v.shipmentCapacity and timeleft) and timeleft or "",
					(v.shipmentCapacity and timeleftAll and longer) and timeleftAll or ""
				});
			end
		end

		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",L["Name"]),C("ltblue","Follower"),C("ltblue",L["Max."]),C("ltblue",L["Ready"]),C("ltblue",L["In|nprogress"]),C("ltblue",L[title]),(longer) and C("ltblue",L[title2]) or "");
		tt:AddSeparator();
		for i=1, #lst do
			tt:AddLine(unpack(lst[i]));
		end
		none = false;
	end

	-- cunstruction list
	if (nConstruct>0) then
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
	if (#blueprints3>0) then
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
	if (#achievements3>0) then
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
			tt:SetLineScript(l,"OnMouseUp", function(self)
				print("?")
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
			end);
			tt:SetLineScript(l,"OnEnter", function(self)
				AchievementTooltip(self,GetAchievementLink(v.id));
			end);
			tt:SetLineScript(l,"OnLeave", function()
				AchievementTooltip(false)
			end);
		end
	end

	if (none) then
		tt:AddLine(L["No buildings found..."]);

	elseif (Broker_EverythingDB.showHints) then
		tt:AddSeparator(4,0,0,0,0);
		local _,_,mod = ns.DurationOrExpireDate();
		if (displayAchievements) then
			ns.AddSpannedLine(tt,C("ltblue",L["Click"]).." || "..C("green",L["Open achievement"]),ttColumns);
		end
		ns.AddSpannedLine(tt,C("copper",L["Hold "..mod]).." || "..C("green",L["Show expire date instead of duration"]),ttColumns);
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
	local progress,ready=0,0;
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	else
		updater = true;
		longer = false;
		nBuildings = 0;
		local bName, texture, shipmentCapacity, shipmentsReady, shipmentsTotal, creationTime, duration, timeleftString, shipmentsCurrent
		local tmp = C_Garrison.GetBuildings() or {};
		wipe(construct); wipe(blueprints3); wipe(achievements3);
		nConstruct=0;

		buildings = C_Garrison.GetBuildings() or {};
		local names,_ = {};
		for i=1, #buildings do
			if (buildings[i]) and (buildings[i].buildingID) then
				_, buildings[i].name, _, buildings[i].texture, buildings[i].rank, buildings[i].isBuilding, buildings[i].timeStart, buildings[i].buildTime, buildings[i].canActivate, buildings[i].canUpgrade, buildings[i].isPrebuilt = C_Garrison.GetOwnedBuildingInfoAbbrev(buildings[i].plotID);
				_, _, _, _, _, _, _, _, _, _, _, _, _, buildings[i].upgrades, _, _, buildings[i].hasFollowerSlot = C_Garrison.GetBuildingInfo(buildings[i].plotID);
				_, _, buildings[i].shipmentCapacity, buildings[i].shipmentsReady, buildings[i].shipmentsTotal, buildings[i].creationTime, buildings[i].duration = C_Garrison.GetLandingPageShipmentInfo(buildings[i].buildingID);

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

				local fID = select(5,C_Garrison.GetFollowerInfoForBuilding(buildings[i].plotID));
				if (fID) then
					buildings[i].follower = C_Garrison.GetFollowerInfo(fID);
					buildings[i].follower.class = strsub(buildings[i].follower.classAtlas,23);
					--(isBuilding or canActivate or not owned);
				end

				buildings[i].shipmentsReady = buildings[i].shipmentsReady or 0;
				buildings[i].shipmentsTotal = buildings[i].shipmentsTotal or 0;

				if (buildings[i].shipmentCapacity==0) then
					buildings[i].shipmentCapacity = nil;
				end

				if (buildings[i].shipmentsReady) then
					ready = ready + buildings[i].shipmentsReady;
				end

				if (buildings[i].shipmentsTotal) then
					progress = progress + buildings[i].shipmentsTotal;
				end

				if (not buildings[i].texture) then
					buildings[i].texture = "interface\\icons\\inv_misc_questionmark";
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
					elseif (rank==2) and (blueprintsL3[id]) then
						local data = ns.GetItemData(blueprintsL3[id]);
						if (aid) and (not completed) then
							local need = {};
							if (numCriteria>0) then
								for ai=1, numCriteria do
									local criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString = GetAchievementCriteriaInfo(aid, ai);
									if (not completed) and (bit.band(flags, EVALUATION_TREE_FLAG_PROGRESS_BAR)==EVALUATION_TREE_FLAG_PROGRESS_BAR) then
										tinsert(need,strsub(description,0,45) .. (strlen(description)>45 and "..." or "") .. " ( " .. quantityString .. " )");
									end
								end
								if (#need==0) then
									need = {strsub(description,0,45)..(strlen(description)>45 and "..." or "")};
								end
							end
							tinsert(achievements3,{
								id = aid,
								name = aname,
								icon = aicon,
								bname = pname,
								bicon = icon,
								need = table.concat(need,"|n"),
								progress = false -- later
							});
						else
							local known = false;
							for Index=1, 10 do
								if (type(data['tooltipLine'..Index])=="string") and data['tooltipLine'..Index]:find(ITEM_SPELL_KNOWN) then
									known=true;
								end
							end
							if (not known) then
								tinsert(blueprints3,{
									id = id,
									name = pname,
									icon = icon,
									iname= data.itemName,
									iicon= data.itemTexture,
									texPrefix = texPrefix,
								});
							end
						end
					end
				end
			end
		end
	end

	if (not Broker_EverythingGlobalDB[name.."_cache"]) then Broker_EverythingGlobalDB[name.."_cache"] = {}; end
	Broker_EverythingGlobalDB[name.."_cache"][C(ns.player.class,ns.player.name).." - "..ns.realm] = buildings;

	local obj = ns.LDB:GetDataObjectByName(ldbName)
	progress = progress - ready;
	obj.text = ("%s/%s"):format(C("ltblue",ready),C("orange",progress))
end

ns.modules[name].onupdate = function(self)
	if not updater then return end
	C_Garrison.RequestLandingPageShipmentInfo(); -- stupid event triggering to get new data
	C_Garrison.RequestShipmentInfo();
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
	tt = ns.LQT:Acquire(name.."TT", 7, "LEFT","LEFT", "CENTER", "CENTER", "CENTER", "RIGHT","RIGHT")
	makeTooltip(tt)
	ns.createTooltip(self, tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then
		ns.hideTooltip(tt,ttName,not displayAchievements,true);
	end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

