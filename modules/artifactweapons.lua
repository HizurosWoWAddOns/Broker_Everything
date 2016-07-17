

----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.build<70000000 then return end


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Artifact weapon" -- L["Artifact weapon"]
local ldbName,ttName,ttColumns, tt = name, name.."TT", 2;
local empowering_items_found, _ = {};
local empowering_items = {
	-- >0 = known amount of artifact power
	-- -1 = special actifact power items
	[121818]=   -1,[127999]=   -1,[128000]=   -1,[128021]=   -1,[128022]=   -1,[128026]=   -1,[130144]=   -1,[130149]=   -1,[130152]=   35,[130153]=   -1,[130159]=   -1,[130160]=   -1,
	[130165]=   -1,[131728]=   -1,[131732]= 1000,[131751]=   35,[131753]=   35,[131758]=   -1,[131763]=   35,[131778]=   -1,[131784]=   -1,[131785]=   -1,[131789]=   -1,[131795]=   35,
	[131802]=   45,[131808]=   25,[132361]=   -1,[132897]=   45,[132923]=   -1,[132950]=   35,[134118]=   -1,[134133]=   -1,[136356]=   -1,[136360]=  300,[136655]=   -1,[136656]=   -1,
	[136657]=   -1,[136658]=   -1,[136659]=   -1,[136660]=   -1,[136661]=   -1,[136662]=   -1,[136663]=   -1,[136664]=   -1,[138480]=    5,[138487]=    5,[138726]=   -1,[138732]=   10,
	[138781]=   75,[138782]=  100,[138783]=   20,[138784]=  100,[138785]=  400,[138786]=  200,[138812]=   35,[138813]=  100,[138814]=   35,[138816]=  100,[138839]=   20,[138864]=    5,
	[138865]=   50,[138880]=   50,[138881]=  150,[138885]=   35,[138886]=  150,[139390]=   -1,[139413]=  200,[139506]= 1000,[139507]=  170,[139508]=  160,[139509]=  245,[139510]=  480,
	[139511]=  250,[139512]=  490,[139591]=  200,[139608]=  150,[139609]=  235,[139610]=  465,[139611]=  165,[139612]=  210,[139613]=  450,[139614]=  175,[139615]=  230,[139616]=  475,
	[139617]=  350,[139652]=   -1,[139653]=   -1,[139654]=   -1,[139655]=   -1,[139656]=   -1,[139657]=   -1,[139658]=   -1,[139659]=   -1,[139660]=   -1,[139661]=   -1,[139662]=   -1,
	[139663]=   -1,[139664]=   -1,[139665]=   -1,[139666]=   -1,[139667]=   -1,[139668]=   -1,[139669]=   -1,[140176]=  400,[140237]=  250,[140238]=  200,[140241]=  200,[140244]=  250,
	[140247]=  250,[140250]=  250,[140251]=  400,[140252]=  200,[140254]=  400,[140255]=  500,[140304]=  250,[140305]= 2000,[140306]= 5000,[140307]=20000,[140310]=   10,[140322]=  100,
	[140349]=  100,[140357]=   15,[140358]=   15,[140359]=   15,[140361]=   15,[140364]=    5,[140365]=    5,[140366]=    5,[140367]=    5,[140368]=    5,[140369]=   15,[140370]=   15,
	[140371]=   15,[140372]=   75,[140373]=   15,[140374]=   15,[140377]=    5,[140379]=    5,[140380]=    5,[140381]=   75,[140382]=    5,[140383]=    5,[140384]=  125,[140385]=    5,
	[140386]=   75,[140387]=   15,[140388]=   75,[140389]=   15,[140391]=   15,[140392]=   15,[140393]=   15,[140396]=   75,[140409]= 1500,[140410]= 5000,[140421]=15000,[140422]=10000,
	[140444]=30000,[140445]=25000,[140459]=    5,[140460]=    5,[140461]=    5,[140462]=    5,[140463]=    5,[140466]=    5,[140467]=    5,[140468]=    5,[140469]=    5,[140470]=    5,
	[140471]=   15,[140473]=    5,[140474]=    5,[140475]=    5,[140476]=    5,[140477]=    5,[140478]=   15,[140479]=   15,[140480]=   15,[140481]=   15,[140482]=   15,[140484]=    5,
	[140485]=    5,[140486]=    5,[140487]=    5,[140488]=    5,[140489]=   15,[140490]=   15,[140491]=   15,[140492]=   15,[140494]=   15,[140497]=    5,[140498]=   15,[140503]=    5,
	[140504]=    5,[140505]=    5,[140507]=    5,[140508]=    5,[140509]=   15,[140510]=   15,[140511]=   15,[140512]=   15,[140513]=   15,[140515]=    5,[140516]=    5,[140517]=  300,
	[140518]=    5,[140519]=    5,[140520]=    5,[140521]=   15,[140522]=   15,[140523]=   15,[140524]=   15,[140525]=   15,[140528]=   15,[140529]=   15,[140530]=   15,[140531]=   15,
	[140532]=   15,[140685]=   25,[140847]=  200,[141023]=   20,[141024]=  100,[141310]=  100,[141313]= 1000,[141314]= 1000,[141335]=   -1,[141337]=  300,[141383]=  100,[141384]=  100,
	[141385]=  100,[141386]=  100,[141387]=  100,[141388]=  100,[141389]=  100,[141390]=  100,[141391]=  100,[141392]=  100,[141393]=  100,[141394]=  100,[141395]=  100,[141396]=  100,
	[141397]=  100,[141398]=  100,[141399]=  100,[141400]=  100,[141401]=  100,[141402]=  100,[141403]=  100,[141404]=  100,[141405]=  100,[141638]=  200,[141639]=  300,[141667]=  500,
	[141668]=  200,[141669]=  300,[141670]=  200,[141671]=  200,[141672]=  200,[141673]=  250,[141674]=  200,[141675]=  200,[141676]= 4000,[141677]=  500,[141678]= 3000,[141679]=  500,
	[141680]= 5000,[141681]=20000,[141682]=20000,[141683]=20000,[141684]=25000,[141685]=50000,[141689]=   55,[141690]=   10,[141699]=  100,[141701]=  100,[141702]=  200,[141703]=  190,
	[141704]=  210,[141705]=  205,[141706]=  210,[141707]=  520,[141708]=  545,[141709]=  550,[141710]=  530,[141711]=  515,[141852]=  500,[141853]=  600,[141854]=  250,[141855]=  125,
	[141856]=  400,[141857]=   50,[141858]=    5,[141859]=  250,[141863]=   20,[141872]=  150,[141876]=   25,[141877]=   75,[141883]=   50,[141886]=   50,[141887]=   50,[141888]=   50,
	[141889]=  150,[141890]=   50,[141891]=   45,[141892]=   35,[141896]=   45,[141921]=  170,[141922]=  220,[141923]=  195,[141924]=  185,[141925]=  190,[141926]=  215,[141927]=  180,
	[141928]=  185,[141929]=  220,[141930]=  175,[141931]=  215,[141932]=  750,[141933]=  200,[141934]=  200,[141935]=  200,[141936]=  250,[141937]=  400,[141940]=  200,[141941]=  250,
	[141942]=  250,[141943]=  200,[141944]=  200,[141945]=  200,[141946]=  200,[141947]=  200,[141948]=  200,[141949]=  200,[141950]=  500,[141951]=  700,[141952]=  800,[141953]= 4000,
	[141954]= 3000,[141955]= 5000,[141956]=  200,[142001]=  400,[142002]=  400,[142003]=  400,[142004]=  400,[142005]=  400,[142006]=  400,[142007]=  400,[142054]=  100
};

local doUpdateBroker = false;
local PATTERN_ARTIFACT_XP_GAIN = gsub(ARTIFACT_XP_GAIN,"%s",".*");

-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\inv_misc_questionmark",coords={0.05,0.95,0.05,0.95}}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["..."],
	events = {
		"PLAYER_ENTERING_WORLD",
		"ARTIFACT_XP_UPDATE",
		"ARTIFACT_MAX_RANKS_UPDATE",
		"ARTIFACT_UPDATE",
		"CHAT_MSG_SYSTEM",
	},
	updateinterval = nil, -- 10
	config_defaults = {
		showName = true,
		showPoints = true,
		showXP = "1",
		showPower = true,
		showWarning = true,
		showRelic = true
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showName", label=L["Show weapon name"], tooltip=L["Show artifact weapon name in broker button"], event="ARTIFACT_UPDATE"},
		{ type="toggle", name="showPoints", label=L["Show points"], tooltip=L["Show spent/available points in broker button"], event="ARTIFACT_UPDATE"},
		{ type="select", name="showXP", label=L["Show artifact power"], tooltip=L["Show artifact weapon expierence in broker button"], event="ARTIFACT_UPDATE",
			values	= {
				["0"]    = L["Hide"],
				["1"]    = L["Current / max expierence"],
				["2"]    = L["Need to next point"],
			},
			default = "1"
		},
		{ type="toggle", name="showPower", label=L["Show unspend artifact power"], tooltip=L["Show amount summary of artifact power from items in your backpack in broker button"]},
		{ type="toggle", name="showWarning", label=L["Show 'not equipped' warning"], tooltip=L["Show 'artifact weapon not equipped' warning in broker button"]},
		{ type="toggle", name="showRelic", label=L["Show artifact relic"], tooltip=L["Show a list of artifact relic slots in tooltip"]},
	},
	clickOptions = {
		["1_open_character_info"] = {
			cfg_label = "Open character info", -- L["Open character info"]
			cfg_desc = "open the character info", -- L["open the character info"]
			cfg_default = "__NONE",
			hint = "Open character info", -- L["Open character info"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCharacter","PaperDollFrame");
			end
		},
		--[=[
		-- it is not clear how it is possible to set a weapon to display without shift right click on an artifact weapon...
		["2_artifact_frame"] = {
			cfg_label = "Open artifact frame", -- L["Show artifact frame"]
			cfg_desc = "open artifact frame", -- L["open artifact frame"]
			cfg_default = "_LEFT",
			hint = "Open artifact frame",
			func = function(self,button)
				local _mod=name;
				securecall("ArtifactFrame_LoadUI");
				--ArtifactFrame.AppearancesTab:OnNewItemEquipped();
				ArtifactFrame:OnEvent("ARTIFACT_UPDATE",true);
				--ArtifactFrame.AppearancesTab:OnEvent("ARTIFACT_UPDATE",true);
				--ShowUIPanel(ArtifactFrame);
				--ArtifactFrame:Show();
			end
		},
		--]=]
		["3_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self);
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

local function updateItemState()
	wipe(empowering_items_found);
	local c,lst = 0,ns.items.GetItemlist();
	for i,v in pairs(lst) do
		if empowering_items[i]~=nil then
			tinsert(empowering_items_found,{id=i, count=#v, name=v[1].name, link=v[1].link, icon=v[1].icon, artifact_power=empowering_items[i],quality=v[1].rarity});
			c=c+1;
		end
	end
	doUpdateBroker=true;
end

local function updateCharacterDB(equipped)
	local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop = C_ArtifactUI[(ArtifactFrame and ArtifactFrame.PerksTab) and "GetArtifactInfo" or "GetEquippedArtifactInfo"]();
	if itemID then
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp);
		local maxPoints = numPoints+pointsSpent;

		local relic = {};
		if equipped then
			Broker_Everything_CharacterDB[ns.player.name_realm][name].equipped=equipped;
		end
		if Broker_Everything_CharacterDB[ns.player.name_realm][name][itemID] and Broker_Everything_CharacterDB[ns.player.name_realm][name][itemID].relic then
			relic = Broker_Everything_CharacterDB[ns.player.name_realm][name][itemID].relic;
		end
		Broker_Everything_CharacterDB[ns.player.name_realm][name][itemID] = {name=itemName,points={pointsSpent,maxPoints},xp={artifactXP, xpForNextPoint},relic=relic};

		if ArtifactFrame and ArtifactFrame.PerksTab then
			for i,v in ipairs(ArtifactFrame.PerksTab.TitleContainer.RelicSlots)do
				local icon,itemname,color,linktype,itemid,data,_="interface\\icons\\INV_MISC_QUESTIONMARK";
				if v.relicLink then
					_,_,color,linktype,itemid,data,itemname = v.relicLink:find("|c(%x*)|H([^:]*):(%d+):(.+)|h%[([^%[%]]*)%]|h|r");
					icon = GetItemIcon(itemid);
				end
				Broker_Everything_CharacterDB[ns.player.name_realm][name][itemID].relic[i]={id=tonumber(itemid),color=color,icon=icon,name=itemname,type=v.relicType,locked=v.lockedReason or false,link=v.relicLink};
			end
		end
	end
end

local function updateBroker()
	if not doUpdateBroker then return end
	doUpdateBroker=false;


	local allDisabled,data,obj = true,{}, ns.LDB:GetDataObjectByName(ldbName);
	local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop = C_ArtifactUI.GetEquippedArtifactInfo();

	updateCharacterDB(itemID);

	if itemID then
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp);
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
			tinsert(data,C("yellow",artifactXP).."/"..C("ltblue",xpForNextPoint));
			allDisabled=false;
		elseif ns.profile[name].showXP=="2" then
			tinsert(data,C("yellow",xpForNextPoint-artifactXP));
			allDisabled=false;
		end
		if ns.profile[name].showPower then
			local sum = {0,0};
			for i,v in ipairs(empowering_items_found)do
				if v.artifact_power==-1 then
					sum[2] = sum[2] + 1;
				elseif v.artifact_power>0 then
					sum[1] = sum[1] + (v.count * v.artifact_power);
				end
			end
			tinsert(data,sum[1]..strrep("+",sum[2]));
			allDisabled=false;
		end
	end

	obj.icon = icon or "interface\\icons\\Ability_MeleeDamage";

	if allDisabled then
		if ns.profile[name].showWarning and Broker_Everything_CharacterDB[ns.player.name_realm][name].equipped~=false then
			X = Broker_Everything_CharacterDB[ns.player.name_realm][name];
			obj.text = C("orange",L["Artifact weapon not equipped"]);
		else
			obj.text = L[name];
		end
	else
		obj.text = table.concat(data,", ");
	end
end

local function createTooltip(self, tt)
	if not (tt and tt.key and tt.key==ttName) then return end
	tt:Clear();

	tt:AddHeader(C("dkyellow",L[name]));
	tt:AddSeparator();

	local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop = C_ArtifactUI.GetEquippedArtifactInfo();
	if itemID then
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp);
		local maxPoints = numPoints+pointsSpent;

		tt:AddLine(C("ltgreen",L["Equipped artifact weapon"])," |T"..icon..":0|t"..C("ltyellow",itemName));
		tt:AddLine(C("ltgreen",L["Spent expierence"]),C("ltyellow",xp).."/"..C("ltyellow",xpForNextPoint));
		tt:AddLine(C("ltgreen",L["Spent points"]),C(maxPoints>pointsSpent and "ltorange" or "ltyellow",pointsSpent).."/"..C("ltyellow",numPoints+pointsSpent));
		local weapon = ns.items.GetInventoryItemBySlotIndex(16);
		if weapon then
			tt:AddLine(C("ltgreen",STAT_AVERAGE_ITEM_LEVEL),C("ltyellow",weapon.level));
		end

		if ns.profile[name].showRelic and Broker_Everything_CharacterDB[ns.player.name_realm][name][itemID] and Broker_Everything_CharacterDB[ns.player.name_realm][name][itemID].relic then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",RELICSLOT));
			tt:AddSeparator();
			if #Broker_Everything_CharacterDB[ns.player.name_realm][name][itemID].relic>0 then
				for i,v in ipairs(Broker_Everything_CharacterDB[ns.player.name_realm][name][itemID].relic) do
					local n = (v.color and C(v.color,v.name)) or (v.locked and C("red", LOCKED)) or C("ltgray",EMPTY);
					local icon = v.locked and "|TInterface\\LFGFrame\\UI-LFG-ICON-LOCK:14:14:0:0:32:32:0:25:0:25|t " or "|T"..(v.icon or "interface\\icons\\INV_MISC_QUESTIONMARK")..":0|t ";
					local l=tt:AddLine(C("white",i..". ")..C("ltgreen",_G["STRING_SCHOOL_"..v.type:upper()] or v.type), icon .. n);
					if v.locked or v.link then
						tt:SetLineScript(l,"OnEnter",function()
							local p = {tt:GetPoint()}; p[2]=tt;
							GameTooltip:SetOwner(self,"ANCHOR_NONE");
							GameTooltip:SetPoint(unpack(p));
							if v.locked then
								GameTooltip:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-LOCK:16:16:0:2:32:32:0:25:0:25|t "..C("red",LOCKED));
								GameTooltip:AddLine(v.locked,.78,.78,.78,true);
							elseif v.link then
								GameTooltip:SetHyperlink(v.link);
							end
							GameTooltip:Show();
						end);
						tt:SetLineScript(l,"OnLeave",function() GameTooltip:Hide(); end);
					end
				end
			else
				local l=tt:AddLine();
				tt:SetCell(l,1,C("ltgray",ns.strWrap(L["Artifact relic are displayable after opening artifact window. Shift Right-Click on your equipped artifact weapon."],64)),nil,nil,ttColumns);
			end
		end

		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",L["Found in your backpack"]), C("ltblue",ARTIFACT_POWER));
		tt:AddSeparator();
		local count,sum=0,0;
		for i,v in ipairs(empowering_items_found)do
			local l;
			if v.artifact_power==-1 then
				l=tt:AddLine("|T".. v.icon .. ":0|t ".. v.name, UNKNOWN);
			elseif v.artifact_power>0 then
				l=tt:AddLine("|T".. v.icon .. ":0|t ".. C("quality"..v.quality or 7,v.name), C("ltyellow",v.count .." x " .. v.artifact_power));
				sum = sum + (v.count*v.artifact_power);
			end
			tt:SetLineScript(l,"OnEnter",function(self)
				if v.link then
					local p = {tt:GetPoint()}; p[2]=tt;
					GameTooltip:SetOwner(self,"ANCHOR_NONE");
					GameTooltip:SetPoint(unpack(p));
					GameTooltip:SetHyperlink(v.link);
				end
			end);
			tt:SetLineScript(l,"OnLeave",function(self) GameTooltip:Hide(); end);
			count=count+1;
		end
		if count>0 then
			tt:AddSeparator();
			tt:AddLine(C("ltblue",L["Summary"]..":"),sum);
		else
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltgray",L["Currently no artifact power items found"]), nil, nil, ttColumns);
		end
	elseif Broker_Everything_CharacterDB[ns.player.name_realm][name].equipped~=nil then
		tt:AddLine(C("ltgray",L["Currently you have no artifact weapon equipped..."]));
	else
		--tt:AddLine(C("ltgray",L[""]));
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(3,0,0,0,0);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
	ns.roundupTooltip(self,tt)
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name;
end

ns.modules[name].onevent = function(self,event,arg1,...)
	if event=="PLAYER_ENTERING_WORLD" then
		if Broker_Everything_CharacterDB[ns.player.name_realm][name]==nil then
			Broker_Everything_CharacterDB[ns.player.name_realm][name] = {equipped=false};
		end
		ns.items.RegisterCallback(name,updateItemState,"any");
		C_Timer.NewTicker(1,updateBroker);
		self:UnregisterEvent(event);
	elseif event=="ARTIFACT_XP_UPDATE" or event=="ARTIFACT_MAX_RANKS_UPDATE" or event=="ARTIFACT_UPDATE" then
		doUpdateBroker=true
	elseif event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	end
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT", "CENTER", "LEFT", "LEFT","RIGHT", "CENTER", "LEFT", "LEFT", "LEFT")
	createTooltip(self, tt);
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end


