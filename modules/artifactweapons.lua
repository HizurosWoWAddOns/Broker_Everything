
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.build<70000000 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Artifact weapon" -- L["Artifact weapon"] L["ModDesc-Artifact weapon"]
local ttName,ttNameAlt,ttColumns,tt,ttAlt,module,createTooltip = name.."TT",name.."TT2", 3;
local ap_items_found,spec2weapon,knowledgeLevel,obtained,updateBroker, _ = {},{},0,0;
local _ITEM_LEVEL = gsub(ITEM_LEVEL,"%%d","(%%d*)");
local PATTERN_ARTIFACT_XP_GAIN = gsub(ARTIFACT_XP_GAIN,"%s",".*");
local number_pattern,akUpgrade = {};
local artifactKnowledgeMultiplier_cap, artifactLocked = 55;
local updateItemStateTry,updateItemState=0;
local artifactKnowledgeMultiplier = {}
local AP_MATCH_STRINGS,FISHING_AP_MATCH_STRINGS;
ns.artifactpower_items = {};
ns.artifactrelikts = {};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=1109508 or ns.icon_fallback,coords={0.05,0.95,0.05,0.95}} --IconName::Artifact weapon--


-- some local functions --
--------------------------
local function sort_up_down(a,b)
	return a:len()>b:len();
end

local function ttMatchString(line,matchString)
	local artifact_power;
	if type(matchString)=="table" then
		artifact_power = line:match(matchString[1]);
		if not artifact_power then
			artifact_power = line:match(matchString[2]);
		end
	else
		artifact_power = line:match(matchString);
	end

	if artifact_power then
		local pat,expo=nil,0;
		for _,v in ipairs(number_pattern)do
			if artifact_power:find(v[1]) then
				pat = v[1];
				expo = v[2];
				break;
			end
		end
		if pat then
			artifact_power = tonumber((artifact_power:gsub("(%d*)[,%.](%d)[ ]?"..pat,"%1.%2"):gsub("(%d*)[ ]?"..pat,"%1"))) * (10^expo);
		else
			artifact_power = artifact_power:gsub("[,%.]","");
		end
	end
	return tonumber(artifact_power);
end

function updateItemState()
	wipe(ap_items_found);
	local lst = ns.items.GetItemlist();
	local isFishing = false;
	for id,v in pairs(lst) do
		if ns.artifactpower_items[id]~=nil then
			-- group items with same item id by knowledge levels
			local klvls = {};
			for _,item in ipairs(v)do
				local knowledge = item.linkData[#item.linkData-3];
				if knowledge then
					if klvls[knowledge]==nil then klvls[knowledge]={}; end
					tinsert(klvls[knowledge],item);
				end
			end
			for klvl,items in pairs(klvls)do
				local knowledgeLevel = klvl-1;
				local artefact_power = nil;
				-- missing item tooltip?
				if not items[1].tooltip then
					ns.items.GetItemTooltip(items[1]);
				end
				-- read artefact power from single item tooltip with same item id and knowledge level
				if items[1].tooltip then
					for i=2, #items[1].tooltip do
						artefact_power = ttMatchString(items[1].tooltip[i],AP_MATCH_STRINGS); -- artefact power for artefact weapons?
						if not artefact_power then
							artefact_power = ttMatchString(items[1].tooltip[i],FISHING_AP_MATCH_STRINGS); -- artefact power for artefact pole?
							if artefact_power then
								isFishing = true;
							end
						end
						if artefact_power then
							break;
						end
					end
				end
				tinsert(ap_items_found,{
					id=id,
					count=#items,
					name=items[1].name,
					link=items[1].link,
					icon=items[1].icon,
					artifact_power=artefact_power or -1,
					quality=items[1].rarity,
					isFishing = isFishing
				});
			end
		end
	end
	updateBroker()
end

local function GetRelicTooltipData(data)
	local obj = data.obj or {};
	if obj.awItemID and obj.relicIndex then
		if ns.toon[name][obj.awItemID].relic==nil then
			ns.toon[name][obj.awItemID].relic = {};
		end
		local iLevel,increaseLevel = 0,0;
		if data and data.lines and #data.lines>0 then
			iLevel = tonumber(data.lines[2]:match(_ITEM_LEVEL)) or tonumber(data.lines[3]:match(_ITEM_LEVEL)) or 0;
			increaseLevel = tonumber(data.lines[5]:match("(.*) "..RELIC_ITEM_LEVEL_INCREASE)) or tonumber(data.lines[6]:match("(.*) "..RELIC_ITEM_LEVEL_INCREASE)) or 0;
		end
		ns.toon[name][obj.awItemID].relic[obj.relicIndex].level = iLevel;
		ns.toon[name][obj.awItemID].relic[obj.relicIndex].increase = increaseLevel;
	end
end

local function updateCharacterDB(equipped)
	local artifact_frame = (ArtifactFrame and ArtifactFrame:IsShown() and ArtifactFrame.PerksTab and ArtifactFrame.PerksTab:IsShown());
	local artifact_forge = (ArtifactRelicForgeFrame and ArtifactRelicForgeFrame:IsShown());
	local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop, artifactTier = C_ArtifactUI[artifact_frame and "GetArtifactInfo" or "GetEquippedArtifactInfo"]();
	if itemID and itemID~=0 then
		local numPoints, artifactXP, xpForNextPoint = 0,0,0; --MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp,artifactTier);
		local maxPoints = numPoints+pointsSpent;

		local relic = {};
		artifactLocked = nil;
		if equipped then
			ns.toon[name].equipped=equipped;
		end
		if ns.toon[name][itemID] and ns.toon[name][itemID].relic then
			relic = ns.toon[name][itemID].relic;
			if not artifact_frame then
				for i=1,#relic do
					if relic[i].link and relic[i].level==nil then
						ns.ScanTT.query({type="link",link=relic[i].link,obj={awItemID=itemID,relicIndex=i},callback=GetRelicTooltipData});
					end
				end
			end
		end

		local weapon = ns.items.GetInventoryItemBySlotIndex(16);

		ns.toon[name][itemID] = {
			name=itemName,
			numPoints=numPoints,
			pointsSpent=pointsSpent,
			maxPoints=maxPoints,
			xp=xp,
			artifactTier=artifactTier,
			artifactXP=artifactXP,
			xpForNextPoint=xpForNextPoint,
			xpTotal=xpTotal,
			relic=relic,
			classSpec="", -- string
			itemLevel=weapon and weapon.level or 0
		};

		ns.toon[name].obtained[itemID] = true;

		-- update relict slots. (only possible with open artifact frame)
		if artifact_frame or artifact_forge then
			for i,v in ipairs(ArtifactFrame.PerksTab.TitleContainer.RelicSlots)do
				if not v.relicType then
					artifactLocked = ARTIFACT_VISIT_FORGE_TO_START;
				end
				local icon,itemname,color,linktype,itemid,data,_=ns.icon_fallback;
				if v.relicLink then
					_,_,color,linktype,itemid,data,itemname = v.relicLink:find("|c(%x*)|H([^:]*):(%d+):(.+)|h%[([^%[%]]*)%]|h|r");
					icon = GetItemIcon(itemid);
				end
				local affected = {C_ArtifactUI.GetPowersAffectedByRelic(i)};
				for I,A in ipairs(affected) do
					affected[I] = (C_ArtifactUI.GetPowerInfo(A) or {}).spellID or UNKNOWN
				end
				ns.toon[name][itemID].relic[i]={id=tonumber(itemid),color=color,icon=icon,name=itemname,type=v.relicType,locked=v.lockedReason or false,link=v.relicLink,affected=affected};
				if v.relicLink then
					ns.ScanTT.query({type="link",link=v.relicLink,obj={awItemID=itemID,relicIndex=i},callback=GetRelicTooltipData});
				end
			end
		end

		-- update knowledge
		ns.toon[name].knowledgeLevel = artifactKnowledgeMultiplier_cap;
	end
end

function updateBroker()
	local _;

	obtained = C_ArtifactUI.GetNumObtainedArtifacts();

	local allDisabled,data,obj = true,{}, ns.LDB:GetDataObjectByName(module.ldbName);
	local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo();

	updateCharacterDB(itemID);

	if itemID then
		local numPoints, artifactXP, xpForNextPoint = 0,0,0; --MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp,artifactTier);
		local maxPoints = numPoints+pointsSpent;

		if ns.profile[name].showName then
			tinsert(data,C("quality"..quality,itemName));
			allDisabled=false;
		end

		if ns.profile[name].showPoints then
			tinsert(data,C(maxPoints>pointsSpent and "orange" or "green",pointsSpent).."/"..C("green",numPoints+pointsSpent));
			allDisabled=false;
		end

		if ns.profile[name].showXP=="1" then
			tinsert(data,C("yellow",ns.FormatLargeNumber(name,artifactXP)).."/"..C("ltblue",ns.FormatLargeNumber(name,xpForNextPoint)));
			allDisabled=false;
		elseif ns.profile[name].showXP=="2" then
			tinsert(data,C("yellow",ns.FormatLargeNumber(name,xpForNextPoint-artifactXP)));
			allDisabled=false;
		end

		if ns.profile[name].showKnowledge and ns.toon[name].knowledgeLevel>0 then
			tinsert(data,C("orange",ns.toon[name].knowledgeLevel));
		end

		if ns.profile[name].showPower then
			local sum = {0,0};
			for i,v in ipairs(ap_items_found)do
				if v.artifact_power==-1 then
					sum[2] = sum[2] + 1;
				elseif v.artifact_power>0 then
					sum[1] = sum[1] + (v.count * v.artifact_power);
				end
			end
			tinsert(data,ns.FormatLargeNumber(name,sum[1])..strrep("+",sum[2]));
			allDisabled=false;
		end
	end

	obj.icon = icon or "interface\\icons\\Ability_MeleeDamage";

	if allDisabled then
		if ns.profile[name].showWarning and obtained>0 then
			obj.text = C("orange",L["Artifact weapon not equipped"]);
		else
			obj.text = L[name];
		end
	else
		obj.text = table.concat(data,", ");
	end
end

local function itemTooltipShow(self,info)
	if not info then return end
	GameTooltip:SetOwner(tt,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(tt,"horizontal"));
	GameTooltip:SetClampedToScreen(true);
	GameTooltip:ClearLines();
	if info.locked then
		GameTooltip:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-LOCK:16:16:0:2:32:32:0:25:0:25|t "..C("red",LOCKED));
		GameTooltip:AddLine(info.locked,.78,.78,.78,true);
	elseif info.link then
		GameTooltip:SetHyperlink(info.link);
	end
	if type(info.affected)=="table" then
		local regions = {GameTooltip:GetRegions()};
		for r=1, #regions do
			if regions[r].GetText then
				local str = regions[r]:GetText();
				if str and str==" " then
					local text = "";
					for i=2, #info.affected do
						local spell = GetSpellInfo(info.affected[i]);
						if spell then
							text = text .. RELIC_TOOLTIP_RANK_INCREASE:format(1,spell) .. "\n";
						end
					end
					regions[r]:SetText(text.." ");
					regions[r]:SetTextColor(1,1,1);
					break;
				end
			end
		end
	end
	GameTooltip:Show();
end

local function itemTooltipHide(self)
	GameTooltip:Hide();
end

local function createTooltip2(parent,artifactID)
	local item,missingdata,l = ns.toon[name][artifactID],false;
	local tt = ns.acquireTooltip({ttNameAlt, ttColumns, "LEFT", "RIGHT", "RIGHT", "LEFT", "LEFT","RIGHT", "CENTER", "LEFT", "LEFT", "LEFT"},{false},{parent,"horizontal",tt});
	ttAlt = tt;

	tt:Clear();
	l=tt:AddHeader("|T"..(GetItemIcon(artifactID) or ns.icon_fallback)..":0|t "..C("ltyellow",item.name));
	--tt:SetCell(l,3,C("gray","(class spec?)"));

	tt:AddSeparator();

	-- spent xp
	if item.xp and item.xpForNextPoint then
		l=tt:AddLine();
		tt:SetCell(l,1,C("ltgreen",L["Spent artifact power"]),nil,nil,2);
		tt:SetCell(l,3,C("ltyellow",ns.FormatLargeNumber(name,item.xp,true)).."/"..C("ltyellow",ns.FormatLargeNumber(name,item.xpForNextPoint,true)));
	else
		missingdata = true;
	end

	-- spent points
	if item.maxPoints and item.pointsSpent and item.numPoints then
		l=tt:AddLine();
		tt:SetCell(l,1,C("ltgreen",L["Spent points"]),nil,nil,2);
		tt:SetCell(l,3,C(item.maxPoints>item.pointsSpent and "ltorange" or "ltyellow",item.pointsSpent).."/"..C("ltyellow",item.numPoints+item.pointsSpent));
	else
		missingdata = true;
	end

	-- spent power
	if ns.profile[name].showTotalAP and item.artifactTier then
		local xp = item.xp;
		for i=1, item.pointsSpent-1 do
			xp=xp+C_ArtifactUI.GetCostForPointAtRank(i,item.artifactTier);
		end
		l=tt:AddLine();
		tt:SetCell(l,1,C("ltgreen",L["Total spend power"]),nil,nil,2);
		tt:SetCell(l,3,C("ltyellow",ns.FormatLargeNumber(name,xp,true)));
	end

	-- item level
	if item.itemLevel then
		tt:AddLine(C("ltgreen",STAT_AVERAGE_ITEM_LEVEL),"",C("ltyellow",item.itemLevel));
	else
		missingdata = true;
	end

	-- display relic slot items
	if ns.profile[name].showRelic and artifactID~=133755 and item and item.relic then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",RELICSLOT));
		tt:AddSeparator();
		if #item.relic>0 then
			for i,v in ipairs(item.relic) do
				local ilvl={};
				if (tonumber(v.level) or 0)>0 and ns.profile[name].showRelicItemLevel then
					tinsert(ilvl,v.level);
				end
				if (tonumber(v.increase) or 0)>0 and ns.profile[name].showRelicIncreaseItemLevel then
					tinsert(ilvl,"+"..v.increase);
				end
				if #ilvl>0 then
					ilvl = " "..C("gray2","("..table.concat(ilvl,"/")..")");
				else
					ilvl="";
				end
				local n = (v.color and C(v.color,v.name)..ilvl) or (v.locked and C("red", LOCKED)) or C("ltgray",EMPTY);
				local icon = v.locked and "|TInterface\\LFGFrame\\UI-LFG-ICON-LOCK:14:14:0:0:32:32:0:25:0:25|t " or "|T"..(v.icon or ns.icon_fallback)..":0|t ";
				local _type = v.type or UNKNOWN;
				local label = _G["RELIC_SLOT_TYPE_" .. _type:upper()] .. " " .. RELICSLOT;
				local l=tt:AddLine(C("white",i..". ")..C("ltgreen",label));
				tt:SetCell(l,2,icon .. n,nil,nil,0);
				if v.locked or v.link then
					tt:SetLineScript(l,"OnEnter",itemTooltipShow,v);
					tt:SetLineScript(l,"OnLeave",itemTooltipHide);
				end
			end
		else
			local l=tt:AddLine();
			tt:SetCell(l,1,C("ltgray",ns.strWrap(L["Artifact relic are displayable after opening artifact window. Shift Right-Click on your equipped artifact weapon."],64)),nil,nil,ttColumns);
		end
	end


	if missingdata then
		tt:AddSeparator(4,0,0,0,0);
		l=tt:AddLine();
		tt:SetCell(l,1,ns.strWrap(C("orange",L["Missing artifact weapon data"]),64),nil,"CENTER",0);
	end

	ns.roundupTooltip(tt);
end

local function hideTooltip2()
	if ttAlt then
		ttAlt:Release();
		ttAlt=nil;
	end
end

local function addAltArtifactLine(tt,c,id)
	local l=tt:AddLine(C("ltyellow",c..". "..L["Artifact weapon"]));
	tt:SetCell(l,3,"|T"..(GetItemIcon(id) or ns.icon_fallback)..":0|t "..C("ltyellow",ns.toon[name][id].name));
	tt:SetLineScript(l, "OnEnter", createTooltip2, id);
	tt:SetLineScript(l, "OnLeave");
end

function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	-- tooltip header
	tt:AddHeader(C("dkyellow",L[name]));

	if obtained==0 then
		-- not optained info
		tt:SetCell(tt:AddLine(),1,C("gray",L["Currently you have no artifact weapon obtained..."]));
	elseif artifactLocked then
		-- locked info. only for ARTIFACT_VISIT_FORGE_TO_START
		tt:AddLine(artifactLocked);
	else
		-- query data and pray for itemID is not nil... :D
		local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop, artifactTier,l = C_ArtifactUI.GetEquippedArtifactInfo();
		if itemID then
			-- wow... not nil... okay...  :)

			-- display current and next artifact knowledge level
			if ns.toon[name].knowledgeLevel and ns.toon[name].knowledgeLevel>0 and itemID~=133755 then
				tt:AddSeparator(3,0,0,0,0);
				local ak = GetCurrencyInfo(1171); -- localized name if artifact knowledge
				tt:AddLine(C("ltblue",ak or L["Artifact knowledge"]));
				tt:AddSeparator();
				l=tt:AddLine();
				tt:SetCell(l,1,C("ltgreen",REFORGE_CURRENT));
				tt:SetCell(l,3,C("ltyellow",("%d (+%s%%)"):format(ns.toon[name].knowledgeLevel,ns.FormatLargeNumber(name,math.ceil(artifactKnowledgeMultiplier[ns.toon[name].knowledgeLevel]*10)*10,true))));
				local nextKL = ns.toon[name].knowledgeLevel+1;
				if nextKL<=artifactKnowledgeMultiplier_cap then
					l=tt:AddLine();
					tt:SetCell(l,1,C("gray2",L["Next knowledge level"]),nil,nil,2);
					tt:SetCell(l,3,C("gray2",("%d (+%s%%)"):format(nextKL,ns.FormatLargeNumber(name,math.ceil(artifactKnowledgeMultiplier[nextKL]*10)*10,true))));
					tt:AddLine(C("gray2",L["Time to next"]),"",C("gray2",SecondsToTime(ns.toon[name].timeToNextAK,nil,nil,nil,true)));
				end
			end

			tt:AddSeparator(3,0,0,0,0);
			tt:SetCell(tt:AddLine(),1, C("ltblue",L["Equipped artifact weapon"]),nil,nil,0);
			tt:AddSeparator();

			-- display name of artifact weapon in your hand
			l=tt:AddLine();
			tt:SetCell(l,1,C("ltgreen",NAME),nil,"LEFT");
			tt:SetCell(l,2,"|T"..icon..":0|t "..C("ltyellow",itemName),nil,nil,2);

			-- display current class spec
			-- l=tt:AddLine();
			-- tt:SetCell(l,1,C("ltgreen",SPEC_LABEL));
			-- tt:SetCell(l,3,C("ltyellow",specname));

			-- get/calculate points and expirience
			local numPoints, artifactXP, xpForNextPoint = 0,0,0; --MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp,artifactTier);
			local maxPoints = numPoints+pointsSpent;

			-- display spent artifact power
			l=tt:AddLine();
			tt:SetCell(l,1,C("ltgreen",L["Spent artifact power"]),nil,nil,2);
			tt:SetCell(l,3,C("ltyellow",ns.FormatLargeNumber(name,xp,true)).."/"..C("ltyellow",ns.FormatLargeNumber(name,xpForNextPoint,true)));

			-- display spent points
			l=tt:AddLine();
			tt:SetCell(l,1,C("ltgreen",L["Spent points"]),nil,nil,2);
			tt:SetCell(l,3,C(maxPoints>pointsSpent and "ltorange" or "ltyellow",pointsSpent).."/"..C("ltyellow",numPoints+pointsSpent));

			-- calculate and display total spent artifact power for current weapon (one more line for real total with all weapons?)
			if ns.profile[name].showTotalAP then
				local _,_,_,_,xp,ps=C_ArtifactUI.GetEquippedArtifactInfo();
				for i=1,ps-1 do
					xp=xp+C_ArtifactUI.GetCostForPointAtRank(i,artifactTier);
				end
				l=tt:AddLine();
				tt:SetCell(l,1,C("ltgreen",L["Total spend power"]),nil,nil,2);
				tt:SetCell(l,3,C("ltyellow",ns.FormatLargeNumber(name,xp,true)));
			end

			-- display average item level
			local weapon = ns.items.GetInventoryItemBySlotIndex(16);
			if weapon then
				tt:AddLine(C("ltgreen",STAT_AVERAGE_ITEM_LEVEL),"",C("ltyellow",weapon.level));
			end

			-- display relic slot and relic items
			if ns.profile[name].showRelic and ns.toon[name][itemID] and ns.toon[name][itemID].relic and itemID~=133755 then
				tt:AddSeparator(4,0,0,0,0);
				tt:AddLine(C("ltblue",RELICSLOT));
				tt:AddSeparator();
				if #ns.toon[name][itemID].relic>0 then
					for i,v in ipairs(ns.toon[name][itemID].relic) do
						local ilvl={};
						if (tonumber(v.level) or 0)>0 and ns.profile[name].showRelicItemLevel then
							tinsert(ilvl,v.level);
						end
						if (tonumber(v.increase) or 0)>0 and ns.profile[name].showRelicIncreaseItemLevel then
							tinsert(ilvl,"+"..v.increase);
						end
						if #ilvl>0 then
							ilvl = " "..C("gray2","("..table.concat(ilvl,"/")..")");
						else
							ilvl="";
						end
						local n = (v.color and C(v.color,v.name)..ilvl) or (v.locked and C("red", LOCKED)) or C("ltgray",EMPTY);
						local icon = v.locked and "|TInterface\\LFGFrame\\UI-LFG-ICON-LOCK:14:14:0:0:32:32:0:25:0:25|t " or "|T"..(v.icon or ns.icon_fallback)..":0|t ";
						local label = (v.type and _G["RELIC_SLOT_TYPE_" .. v.type:upper()] or UNKNOWN) .. " " .. RELICSLOT;
						local l=tt:AddLine(C("white",i..". ")..C("ltgreen",label));
						tt:SetCell(l,2,icon .. n,nil,nil,0);
						if v.locked or v.link then
							tt:SetLineScript(l,"OnEnter",itemTooltipShow,v);
							tt:SetLineScript(l,"OnLeave",itemTooltipHide);
						end
					end
				else
					-- or a locked info
					local l=tt:AddLine();
					tt:SetCell(l,1,C("ltgray",ns.strWrap(L["Artifact relic are displayable after opening artifact window. Shift Right-Click on your equipped artifact weapon."],64)),nil,nil,ttColumns);
				end
			end

			-- list of your other obtained artifacts
			if ns.profile[name].showAlt and obtained>1 then
				tt:AddSeparator(4,0,0,0,0);
				tt:AddLine(C("ltblue",L["Your other artifacts"]));
				tt:AddSeparator();
				local pole,c = false,2;
				for id,loc in pairs(ns.toon[name].obtained)do
					if id==133755 then
						pole=true;
					elseif id>0 and itemID~=id then
						addAltArtifactLine(tt,c,id);
						c=c+1;
					end
				end
				if pole then
					addAltArtifactLine(tt,c,133755);
					c=c+1;
				end
			end

			-- display a list of items to empower your artifact with artifact power
			if ns.profile[name].showItems then
				tt:AddSeparator(4,0,0,0,0);
				local l=tt:AddLine();
				tt:SetCell(l,1,C("ltblue",L["Found in your backpack"]),nil,nil,2);
				tt:SetCell(l,3,C("ltblue",ARTIFACT_POWER));
				tt:AddSeparator();
				local count,sum=0,0;
				for i,v in ipairs(ap_items_found)do
					local l;
					if v.artifact_power==-1 then
						l=tt:AddLine();
						tt:SetCell(l,1,"|T".. v.icon .. ":0|t ".. C("quality"..v.quality or 7,v.name),nil,nil,2);
						tt:SetCell(l,3," ");
					elseif v.artifact_power>0 then
						l=tt:AddLine();
						tt:SetCell(l,1,"|T".. v.icon .. ":0|t ".. C("quality"..v.quality or 7,v.name),nil,nil,2);
						tt:SetCell(l,3,C("ltyellow",v.count .." x " .. ns.FormatLargeNumber(name,v.artifact_power,true)));
						sum = sum + (v.count*v.artifact_power);
					end
					if v.link then
						tt:SetLineScript(l,"OnEnter",itemTooltipShow,v);
						tt:SetLineScript(l,"OnLeave",itemTooltipHide);
					end
					count=count+1;
				end
				if count>0 then
					tt:AddSeparator();
					tt:AddLine(C("ltblue",ACHIEVEMENT_SUMMARY_CATEGORY..":"),nil,ns.FormatLargeNumber(name,sum,true));
				else
					local l = tt:AddLine();
					tt:SetCell(l,1,C("ltgray",L["Currently no artifact power items found"]), nil, nil, ttColumns);
				end
			end
		else
			tt:AddLine(C("ltgray",L["Currently you have no artifact weapon equipped..."]));
		end
	end

	-- add hints if player want see it :D
	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(3,0,0,0,0);
		ns.ClickOpts.ttAddHints(tt,name);
	end

	-- little roundup for tooltip
	ns.roundupTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"ARTIFACT_XP_UPDATE",
		--"ARTIFACT_MAX_RANKS_UPDATE",-- alerted in 8.0
		"ARTIFACT_UPDATE",
		"UNIT_INVENTORY_CHANGED",
		"CURRENCY_DISPLAY_UPDATE"
	},
	config_defaults = {
		enabled = false,
		showName = true,
		showPoints = true,
		showXP = "1",
		showPower = true,
		showWarning = true,
		showRelic = true,
		showRelicItemLevel = false,
		showRelicIncreaseItemLevel = true,
		showItems = true,
		showTotalAP = true,
		showKnowledge = true,
		showAlt = true,
	},
	clickOptionsRename = {
		["charinfo"] = "1_open_character_info",
		["artifactframe"] = "2_artifact_frame",
		["menu"] = "3_open_menu"
	},
	clickOptions = {
		["charinfo"] = "CharacterInfo",
		["artifactframe"] = {"Artifact frame","call",{"SocketInventoryItem",16}}, -- L["Artifact frame"]
		["menu"] = "OptionMenu"
	}
};

ns.ClickOpts.addDefaults(module,{
	charinfo = "__NONE",
	artifactframe = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			showName   = { type="toggle", order=1, name=L["OptArtName"],   desc=L["OptArtNameDesc"]},
			showPoints = { type="toggle", order=2, name=L["OptArtPoints"], desc=L["OptArtPointsDesc"]},
			showXP     = { type="select", order=3, name=L["OptArtPower"],  desc=L["OptArtPowerDesc"],
				values	= {
					["0"]    = HIDE,
					["1"]    = L["Current / max xp"],
					["2"]    = L["Need to next point"],
				},
			},
			showPower     = { type="toggle", order=4, name=L["OptArtUnused"],  desc=L["OptArtUnusedDesc"]},
			showKnowledge = { type="toggle", order=5, name=L["OptArtKnowledge"],   desc=L["OptArtKnowledgeDesc"]},
			showWarning   = { type="toggle", order=6, name=L["OptartNotEquipped"], desc=L["OptArtNotEquippedDesc"]},
		},
		tooltip = {
			showRelic                  = { type="toggle", order=1, name=L["OptArtRelic"],        desc=L["OptArtRelicDesc"]},
			showRelicItemLevel         = { type="toggle", order=2, name=L["OptArtRelicILvl"],    desc=L["OptArtRelicILvlDesc"]},
			showRelicIncreaseItemLevel = { type="toggle", order=3, name=L["OptArtReliciLvlInc"], desc=L["OptArtReliciLvlIncDesc"]},
			showItems                  = { type="toggle", order=4, name=L["OptArtPowerItems"],   desc=L["OptArtPowerItemsDesc"]},
			showTotalAP                = { type="toggle", order=5, name=L["OptArtPowerTotal"],   desc=L["OptArtPowerTotalDesc"]},
			showAlt                    = { type="toggle", order=6, name=L["OptArtOthers"],       desc=L["OptArtOthersDesc"]}
		},
		misc = {
			shortNumbers=1
		},
	},
	{ -- option set function should execute module event function. true="BE_DUMMY_EVENT", [string]=<execute with given event name>
		showName="ARTIFACT_UPDATE",
		showPoints="ARTIFACT_UPDATE",
		showXP="ARTIFACT_UPDATE",
	}
end

function module.init()
	ns.artifactpower_items = {
		-- >0 = known amount of artifact power
		-- -1 = special actifact power items
		[127999]=2, [128000]=2, [128021]=2, [128022]=2, [128026]=2, [130144]=1, [130149]=1, [130152]=1, [130153]=1, [130159]=1, [130160]=1, [130165]=1,
		[131728]=1, [131732]=1, [131751]=1, [131753]=1, [131758]=1, [131763]=1, [131778]=1, [131784]=1, [131785]=1, [131789]=1, [131795]=1, [131802]=1,
		[131808]=1, [132361]=1, [132897]=1, [132923]=1, [132950]=1, [134118]=2, [134133]=2, [136360]=1, [138480]=1, [138487]=1, [138726]=2, [138732]=1,
		[138781]=1, [138782]=1, [138783]=1, [138784]=1, [138785]=1, [138786]=1, [138812]=1, [138813]=1, [138814]=1, [138816]=1, [138839]=1, [138864]=1,
		[138865]=1, [138880]=1, [138881]=1, [138885]=1, [138886]=1, [139413]=1, [139506]=1, [139507]=1, [139508]=1, [139509]=1, [139510]=1, [139511]=1,
		[139512]=1, [139608]=1, [139609]=1, [139610]=1, [139611]=1, [139612]=1, [139613]=1, [139614]=1, [139615]=1, [139616]=1, [139617]=1, [139652]=1,
		[139653]=1, [139654]=1, [139655]=1, [139656]=1, [139657]=1, [139658]=1, [139659]=1, [139660]=1, [139661]=1, [139662]=1, [139663]=1, [139664]=1,
		[139665]=1, [139666]=1, [139667]=1, [139668]=1, [139669]=1, [140176]=1, [140237]=1, [140238]=1, [140241]=1, [140244]=1, [140247]=1, [140250]=1,
		[140251]=1, [140252]=1, [140254]=1, [140255]=1, [140304]=1, [140305]=1, [140306]=1, [140307]=1, [140310]=1, [140322]=1, [140349]=1, [140357]=1,
		[140358]=1, [140359]=1, [140361]=1, [140364]=1, [140365]=1, [140366]=1, [140367]=1, [140368]=1, [140369]=1, [140370]=1, [140371]=1, [140372]=1,
		[140373]=1, [140374]=1, [140377]=1, [140379]=1, [140380]=1, [140381]=1, [140382]=1, [140383]=1, [140384]=1, [140385]=1, [140386]=1, [140387]=1,
		[140388]=1, [140389]=1, [140391]=1, [140392]=1, [140393]=1, [140396]=1, [140409]=1, [140410]=1, [140421]=1, [140422]=1, [140444]=1, [140445]=1,
		[140459]=1, [140460]=1, [140461]=1, [140462]=1, [140463]=1, [140466]=1, [140467]=1, [140468]=1, [140469]=1, [140470]=1, [140471]=1, [140473]=1,
		[140474]=1, [140475]=1, [140476]=1, [140477]=1, [140478]=1, [140479]=1, [140480]=1, [140481]=1, [140482]=1, [140484]=1, [140485]=1, [140486]=1,
		[140487]=1, [140488]=1, [140489]=1, [140490]=1, [140491]=1, [140492]=1, [140494]=1, [140497]=1, [140498]=1, [140503]=1, [140504]=1, [140505]=1,
		[140507]=1, [140508]=1, [140509]=1, [140510]=1, [140511]=1, [140512]=1, [140513]=1, [140515]=1, [140516]=1, [140517]=1, [140518]=1, [140519]=1,
		[140520]=1, [140521]=1, [140522]=1, [140523]=1, [140524]=1, [140525]=1, [140528]=1, [140529]=1, [140530]=1, [140531]=1, [140532]=1, [140685]=1,
		[140847]=1, [141023]=1, [141024]=1, [141310]=1, [141313]=1, [141314]=1, [141337]=1, [141383]=1, [141384]=1, [141385]=1, [141386]=1, [141387]=1,
		[141388]=1, [141389]=1, [141390]=1, [141391]=1, [141392]=1, [141393]=1, [141394]=1, [141395]=1, [141396]=1, [141397]=1, [141398]=1, [141399]=1,
		[141400]=1, [141401]=1, [141402]=1, [141403]=1, [141404]=1, [141405]=1, [141638]=1, [141639]=1, [141667]=1, [141668]=1, [141669]=1, [141670]=1,
		[141671]=1, [141672]=1, [141673]=1, [141674]=1, [141675]=1, [141676]=1, [141677]=1, [141678]=1, [141679]=1, [141680]=1, [141681]=1, [141682]=1,
		[141683]=1, [141684]=1, [141685]=1, [141689]=1, [141690]=1, [141699]=1, [141701]=1, [141702]=1, [141703]=1, [141704]=1, [141705]=1, [141706]=1,
		[141707]=1, [141708]=1, [141709]=1, [141710]=1, [141711]=1, [141852]=1, [141853]=1, [141854]=1, [141855]=1, [141856]=1, [141857]=1, [141858]=1,
		[141859]=1, [141863]=1, [141872]=1, [141876]=1, [141877]=1, [141883]=1, [141886]=1, [141887]=1, [141888]=1, [141889]=1, [141890]=1, [141891]=1,
		[141892]=1, [141896]=1, [141921]=1, [141922]=1, [141923]=1, [141924]=1, [141925]=1, [141926]=1, [141927]=1, [141928]=1, [141929]=1, [141930]=1,
		[141931]=1, [141932]=1, [141933]=1, [141934]=1, [141935]=1, [141936]=1, [141937]=1, [141940]=1, [141941]=1, [141942]=1, [141943]=1, [141944]=1,
		[141945]=1, [141946]=1, [141947]=1, [141948]=1, [141949]=1, [141950]=1, [141951]=1, [141952]=1, [141953]=1, [141954]=1, [141955]=1, [141956]=1,
		[142001]=1, [142002]=1, [142003]=1, [142004]=1, [142005]=1, [142006]=1, [142007]=1, [142054]=1, [142449]=1, [142450]=1, [142451]=1, [142453]=1,
		[142454]=1, [142455]=1, [142533]=1, [142534]=1, [142535]=1, [142555]=1, [143333]=1, [143486]=1, [143487]=1, [143488]=1, [143498]=1, [143499]=1,
		[143533]=1, [143536]=1, [143538]=1, [143540]=1, [143677]=1, [143680]=1, [143713]=1, [143714]=1, [143715]=1, [143716]=1, [143738]=1, [143739]=1,
		[143740]=1, [143741]=1, [143742]=1, [143743]=1, [143744]=1, [143745]=1, [143746]=1, [143747]=1, [143749]=1, [143757]=1, [143844]=1, [143868]=1,
		[143869]=1, [143870]=1, [143871]=1, [144266]=1, [144267]=1, [144268]=1, [144269]=1, [144270]=1, [144271]=1, [144272]=1, [144297]=1, [146122]=1,
		[146123]=1, [146124]=1, [146125]=1, [146126]=1, [146127]=1, [146128]=1, [146129]=1, [146309]=1, [146313]=1, [146314]=1, [146315]=1, [146316]=1,
		[146318]=1, [146319]=1, [146320]=1, [146321]=1, [146322]=1, [146323]=1, [146324]=1, [146325]=1, [146326]=1, [146327]=1, [146329]=2, [146662]=1,
		[146663]=1, [146664]=1, [146671]=1, [147198]=1, [147199]=1, [147200]=1, [147201]=1, [147202]=1, [147203]=1, [147293]=1, [147398]=1, [147399]=1,
		[147400]=1, [147401]=1, [147402]=1, [147403]=1, [147404]=1, [147405]=1, [147406]=1, [147407]=1, [147408]=1, [147409]=1, [147441]=1, [147442]=1,
		[147444]=1, [147456]=1, [147457]=1, [147458]=1, [147459]=1, [147460]=1, [147461]=1, [147462]=1, [147463]=1, [147464]=1, [147465]=1, [147466]=1,
		[147467]=1, [147468]=1, [147469]=1, [147470]=1, [147471]=1, [147472]=1, [147473]=1, [147474]=1, [147475]=1, [147476]=1, [147477]=1, [147478]=1,
		[147479]=1, [147480]=1, [147481]=1, [147482]=1, [147483]=1, [147484]=1, [147485]=1, [147486]=1, [147513]=2, [147548]=1, [147549]=1, [147550]=1,
		[147551]=1, [147579]=1, [147581]=1, [147718]=1, [147719]=1, [147720]=1, [147721]=1, [147808]=1, [147809]=1, [147810]=1, [147811]=1, [147812]=1,
		[147814]=1, [147818]=1, [147819]=1, [147842]=1, [150931]=1, [151240]=1, [151241]=1, [151242]=1, [151243]=1, [151244]=1, [151245]=1, [151246]=1,
		[151247]=1, [151556]=1, [151561]=1, [151619]=1, [151620]=1, [151696]=1, [151697]=1, [151698]=1, [151699]=1, [151700]=1, [151789]=1, [151914]=1,
		[151915]=1, [151916]=1, [151917]=1, [151918]=1, [151919]=1, [151920]=1, [151921]=1, [151922]=1, [152430]=1, [152431]=1, [152432]=1, [152433]=1,
		[152434]=1, [152435]=1, [152504]=1, [152651]=1, [152653]=1, [152654]=1, [152700]=1, [152706]=1, [152707]=1, [152708]=1, [152709]=1, [152710]=1,
		[152711]=1, [152712]=1, [152713]=1, [152937]=1, [152938]=1, [152939]=1, [152962]=1, [152984]=1, [153001]=1, [153007]=1, [153008]=1, [153009]=1,
		[153046]=1, [153047]=1, [153048]=1, [153052]=1, [153159]=1, [153160]=1, [153161]=1, [153162]=1, [153163]=1, [153164]=1, [153165]=1, [153198]=1,
		[153199]=1, [153200]=1, [153201]=1, [153217]=1, [153218]=1, [153220]=1, [153221]=1, [153222]=1, [153223]=1, [153224]=1, [153225]=1, [153246]=1,
		[153259]=1, [153266]=1, [153278]=1, [155657]=1
	};

	artifactKnowledgeMultiplier = {
		-- with 7.0
		  0.25,  0.50,  0.90,  1.40,  2.00, --  1 -  5
		  2.75,  3.75,  5.00,  6.50,  8.50, --  6 - 10
		 11.00, 14.00, 17.75, 22.50, 28.50, -- 11 - 15
		 36.00, 45.50, 57.00, 72.00, 90.00, -- 16 - 20
		113.00,142.00,178.00,223.00,249.00, -- 21 - 25

		-- with 7.2
		  1000.00,   1300.00,   1700.00,   2200.00,   2900.00, -- 26 - 30
		  3800.00,   4900.00,   6400.00,   8300.00,  10800.00, -- 31 - 35
		 14000.00,  18200.00,  23700.00,  30800.00,  40000.00, -- 36 - 40

		-- with 7.2.5
		-- 52000.00,  67600.00,  87900.00, 114300.00, 148600.00, -- 41 - 45
		--193200.00, 251200.00, 326600.00, 424600.00, 552000.00, -- 46 - 50

		-- with 7.3
		 160000.00,  208000.00,  270400.00,  351500.00,  457000.00, -- 41 - 45
 		 594000.00,  772500.00, 1004000.00, 1305000.00, 1696500.00, -- 46 - 50
		2205500.00, 2867500.00, 3727500.00, 4846000.00, 6300000.00, -- 51 - 55

		-- wow... damned high values
	}

	AP_MATCH_STRINGS = ({
		deDE = "Gewährt Eurem derzeit ausgerüsteten Artefakt (.*) Artefaktmacht",
		enUS = "Grants (.*) Artifact Power to your currently equipped Artifact",
		esES = "Otorga (.*) p. de poder de artefacto al artefacto que lleves equipado",
		esMX = "Otorga (.*) p. de Poder de artefacto para el artefacto que llevas equipado",
		frFR = "Confère (.*) point* de puissance à l’arme prodigieuse que vous brandissez",
		itIT = {"Fornisce (.*) Potere Artefatto all'Artefatto attualmente equipaggiato.","(.*) Potere Artefatto fornito all'Artefatto attualmente equipaggiato"},
		koKR = {"현재 장착한 유물에 (.*)의 유물력을 부여합니다.","현재 장착한 유물에 (.*)의 유물력 부여"},
		ptBR = "Concede (.*) de Poder do Artefato ao artefato equipado",
		ptPT = "Concede (.*) de Poder do Artefato ao artefato equipado",
		ruRU = {"Добавляет используемому в данный момент артефакту (.*) ед. силы артефакта.","Добавление используемому в данный момент артефакту (.*) ед. силы артефакта"},
		zhCN = "将(.*)点神器能量注入到你当前装备的神器之中",
		zhTW = "賦予你目前裝備的神兵武器(.*)點神兵之力",
	})[ns.locale];

	FISHING_AP_MATCH_STRINGS = ({
		deDE = "Wirft den Fisch zurück ins Wasser und gewährt Eurem Angelartefakt (.*) Artefaktmacht",
		enUS = "Toss the fish back into the water, granting (.*) Artifact Power to your fishing artifact",
		esES = "Lanza el pez de nuevo al agua, lo que otorga (.*) p. de poder de artefacto a tu artefacto de pesca",
		esMX = "Devuelve el pez al agua, lo que otorga (.*) de poder de artefacto a tu artefacto de pesca",
		frFR = "Vous rejetez le poisson à l’eau, ce qui confère (.*) $lpoint:points; de puissance prodigieuse à votre ustensile de pêche prodigieux",
		itIT = "Rilancia il pesce in acqua, fornendo (.*) Potere Artefatto al tuo artefatto da pesca",
		koKR = "물고기를 다시 물에 던져 낚시 유물에 (.*)의 유물력을 추가합니다.",
		ptBR = "Joga o peixe de volta na água, concedendo (.*) de Poder do Artefato ao seu artefato de pesca",
		ptPT = "Joga o peixe de volta na água, concedendo (.*) de Poder do Artefato ao seu artefato de pesca",
		ruRU = "Бросить рыбу обратно в воду, добавив вашему рыболовному артефакту (.*) ед. силы артефакта",
		zhCN = "将鱼扔回到水中，使你的钓鱼神器获得(.*)点神器能量",
		zhTW = "將魚丟回水中，為你的釣魚神器取得(.*)點神兵之力",
	})[ns.locale];

	for _,expo in ipairs({{SECOND_NUMBER,6},{THIRD_NUMBER,9},{FOURTH_NUMBER,12}})do
		local strs = {strsplit(":",(expo[1]:gsub("%\1247(.*);","%1")))};
		table.sort(strs,sort_up_down);
		for i,v in pairs(strs)do
			table.insert(number_pattern,{v,expo[2]});
		end
	end
end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGIN" then
		if ns.toon[name]==nil then
			ns.toon[name] = {equipped=false,knowledgeLevel=0};
		end
		if ns.toon[name].knowledgeLevel==nil then
			ns.toon[name].knowledgeLevel = 0;
		end
		if ns.toon[name].obtained==nil then
			ns.toon[name].obtained = {};
			for id, data in pairs(ns.toon[name])do
				if type(id)=="number" and id>0 and type(data)=="table" and data.name then
					ns.toon[name].obtained[id] = true;
				end
			end
		end
		if ns.toon[name][0]~=nil then
			ns.toon[name][0]=nil;
			ns.toon[name].obtained[0]=nil;
		end
		ns.items.RegisterCallback(name,updateItemState,"any");
		C_Timer.After(1,ns.items.UpdateNow);
		C_Timer.After(2,function()
			module:onevent("BE_DUMMY_EVENT");
		end);
	end
	if ns.eventPlayerEnteredWorld then
		--if event=="ARTIFACT_XP_UPDATE" or event=="ARTIFACT_MAX_RANKS_UPDATE" or event=="ARTIFACT_UPDATE" then
		obtained = C_ArtifactUI.GetNumObtainedArtifacts() or 0;
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "LEFT", "LEFT","RIGHT", "CENTER", "LEFT", "LEFT", "LEFT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
