
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Speed"; -- SPEED L["ModDesc-Speed"]
local ttName, ttColumns, tt, module = name.."TT", 3
local riding_skills,licenses,bonus_spells,replace_unknown,trainer_faction,deprecated_licenses = {},{},{},{},{},{};
local updateToonSkillLocked,currentMapID

-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\Ability_Rogue_Sprint",coords={0.05,0.95,0.05,0.95}}; --IconName::Speed--


-- some local functions --
--------------------------
local UnitInVehicle = UnitInVehicle or function()
	return false;
end

local function updateTrainerName(data)
	if data.lines[1] then
		trainer_faction[data.trainer_index][6] = data.lines[1];
	end
end

local function updateToonSkill(...)
	if ns.toon[name]==nil then
		ns.toon[name] = {skill=0};
	elseif ns.toon[name].skill==nil then
		ns.toon[name].skill = 0;
	end
	for i=1, #riding_skills do
		if C_SpellBook.IsSpellInSpellBook(riding_skills[i].spell) then
			if ns.toon[name].skill<riding_skills[i].spell then
				ns.toon[name].skill = riding_skills[i].spell;
			end
			break;
		end
	end
	updateToonSkillLocked = nil;
end

local CalcSpeed = {
	x=0,y=0,t=0,s=0
};

local worldMapByMapID = {
	[1355]=1355, -- nazjatar
	[2133]=2133, -- zaralek
	[2351]=2351, -- housing zone
	[2352]=2352, -- housing zone
	[2371]=2371, -- k'aresh
}

setmetatable(worldMapByMapID,{__index=function(t,k)
	if not tonumber(k) then
		return false; -- invalid key
	end
	local limit,mapID,mapInfo = 6,k,C_Map.GetMapInfo(k) or 0;
	if not mapInfo then
		return;
	end
	while type(mapInfo)=="table" and limit>=0 do
		if mapInfo.mapType < 3 then
			rawset(t,k,mapID)
			return mapID;
		end
		mapID = mapInfo.parentMapID;
		mapInfo = C_Map.GetMapInfo(mapID);
		limit = limit - 1;
	end
	return false;
end})

function CalcSpeed:Update()
	if IsInInstance() then
		return
	end
	-- Get mapID and positionInfo
	if not currentMapID then
		currentMapID = C_Map.GetBestMapForUnit("player") or 0
		if worldMapByMapID[currentMapID]~=currentMapID then
			currentMapID = worldMapByMapID[currentMapID];
		end
	end
	if not (currentMapID and currentMapID>0) then
		return
	end
	local posInfo = C_Map.GetPlayerMapPosition(currentMapID,"player");
	if not posInfo then
		local id = C_Map.GetBestMapForUnit("player")
		if id then
			posInfo = C_Map.GetPlayerMapPosition(id,"player");
		end
	end
	if not posInfo then
		ns:debugPrint("posInfo is nil",currentMapID)
		return
	end

	-- Get delta time
	local time,dt = GetTime();
	dt,CalcSpeed.t = time-CalcSpeed.t,time;

	-- Calculate speed
	local w,h,x,y = C_Map.GetMapWorldSize(currentMapID);
	x,y = (posInfo.x * w), (posInfo.y * h);
	local dx,dy = x-CalcSpeed.x,y-CalcSpeed.y;
	CalcSpeed.x,CalcSpeed.y = x,y;
	CalcSpeed.s = math.sqrt(dx*dx + dy*dy) / dt;

	if C_UnitAuras then
		local tspeed = 60
		-- C_UnitAuras.IsPlayerAuraActive(<spellID>) would be better but not exist
		local thrill = not not C_UnitAuras.GetPlayerAuraBySpellID(377234);
		local as,ad,mb = 0,3.5,35;
		if thrill and time < as + mb then
			local p,b = (time-as) / ad;
			b = tspeed + (1-p) * mb;
			if CalcSpeed.s < b then
				CalcSpeed.s = b
			end
		end

		if (CalcSpeed.s < tspeed and thrill) or (CalcSpeed.s > tspeed and not thrill) then
			CalcSpeed.s = tspeed
		end
	end
end

local function updateBroker()
	local speed = 0
	if ns.IsRetailClient() then
		CalcSpeed:Update();
		speed = CalcSpeed.s;
	else
		speed = GetUnitSpeed( UnitInVehicle("player") and "vehicle" or "player" ) or 0;
	end
	local str = ("%."..ns.profile[name].precision.."f"):format(speed / 7 * 100 ) .. "%";
	local l = 4 + (ns.profile[name].precision>0 and ns.profile[name].precision+1 or 0) - str:len();
	ns.LDB:GetDataObjectByName(module.ldbName).text = strrep("|TInterface\\buttons\\ui-passivehighlight:9:9|t",l)..str;
	-- hidden texture as placeholder is not nice but it works.
end

local function tooltipOnEnter(self,data)
	GameTooltip:SetOwner(tt,"ANCHOR_NONE");
	GameTooltip:SetPoint("TOP",tt,"BOTTOM");
	local Link
	if data.spell and not data.link then
		Link = C_Spell.GetSpellLink(data.spell)
	end
	if data.info then
		for i=1, #data.info do
			local aid = data.info[i]:match("^a(%d+)$");
			local Name, color, completed, _ = data.info[i],{.8,.8,.8,false};
			if i==1 then
				color = {1,.8,0,false};
			end
			if aid then
				_, Name, _, completed = GetAchievementInfo(aid);
				if completed then
					color = {.1,.95,.1,false};
				elseif not Name and replace_unknown[data.info[i]] then
					Name = replace_unknown[data.info[i]];
				end
			end
			GameTooltip:AddLine(Name,unpack(color));
		end
	elseif data.link or (Link and Link:match("spell:%d+")) then
		GameTooltip:SetHyperlink(Link or data.link);
	elseif data.spell then
		GameTooltip:SetSpellByID(data.spell)
	end
	if data.extend=="trainerfaction" and ns.client_version>4 then
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(C("ltblue",L["Trainer that offer reputation dicount"]));
		local faction,ttTrainerLine,ttFactionLine,fInfo = false,"%s (%0.1f, %0.1f)","%s (%0.1f%%)";
		for i=1, #trainer_faction do
			local v = trainer_faction[i];
			if faction~=v[1] then
				fInfo = ns.deprecated.C_Reputation.GetFactionDataByID(v[1]);
			end
			if fInfo and fInfo.name then
				if faction~=v[1] then
					if faction then
						GameTooltip:AddLine(" ");
					end
					local standing = _G["FACTION_STANDING_LABEL"..fInfo.reaction];
					if fInfo.reaction<8 then
						standing = ttFactionLine:format(standing,((fInfo.currentStanding-fInfo.currentReactionThreshold)/(fInfo.nextReactionThreshold-fInfo.currentReactionThreshold))*100);
					end
					GameTooltip:AddDoubleLine(C("gray",fInfo.name), C("gray",standing) );
				end
				local mapInfo
				for m=1, #v[3] do
					mapInfo = C_Map.GetMapInfo(v[3][m]);
					if mapInfo then
						break;
					end
				end
				if mapInfo then
					GameTooltip:AddDoubleLine(v[6] or UNKNOWN, ttTrainerLine:format(mapInfo.name, v[4], v[5] ) );
				end
				faction = v[1];
			end
		end
	end
	--/run local t=GameTooltip t:Hide(); t:SetOwner(UIParent,"ANCHOR_NONE") t:SetPoint("CENTER") t:SetUnit("Creature-0-0-0-0-35135-0"); t:Show();
	GameTooltip:Show();
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	local _=function(d) if tonumber(d) then return ("+%d%%"):format(d); end return d; end;
	local lvl = UnitLevel("player");

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",SPEED));
	tt:AddSeparator(4,0,0,0,0);

	tt:AddLine(C("ltblue",L["Riding skill"]));
	tt:AddSeparator();
	local learned = nil;
	-- list known/available riding skills
	for i,skill in ipairs(riding_skills) do
		local spellInfo = C_Spell.GetSpellInfo(skill.spell)
		local l,ttExtend;
		-- check if learned. skills ordered in table from highest to lowest.
		if(learned==nil and C_SpellBook.IsSpellInSpellBook(skill.spell))then
			learned = true;
		end
		local cell1color,cell2;
		if learned==nil then -- not learned
			if(lvl>=skill.minLevel)then
				cell1color = "yellow";
				cell2 = C("ltgray",L["Learnable"]);
				ttExtend = true;
			elseif skill.race==false then
				local factionInfo = ns.deprecated.C_Reputation.GetFactionDataByID(skill.faction)
				cell1color = "red";
				cell2 = C("ltgray", L["Need excalted reputation:"].." "..factionInfo.name);
			else
				cell1color = "red";
				cell2 = C("ltgray", L["Need level"].." "..skill.minLevel);
			end
		elseif(learned==true)then -- highest learned
			cell1color = "green";
			cell2 = _(skill.speed);
			learned=false;
		elseif(learned==false)then -- lower learned spells in darker green
			cell1color = "dkgreen";
			cell2 = C("gray",_(skill.speed));
		end

		if cell1color and cell2 then
			l = tt:AddLine();
			tt:SetCell(l,1,C(cell1color,spellInfo.name),nil,nil,2);
			tt:SetCell(l,3,cell2);
		end

		if l and ns.client_version>=4 then
			tt:SetLineScript(l,"OnEnter",tooltipOnEnter, {spell=skill.spell, extend=ttExtend and "trainerfaction" or nil});
			tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);
		end
	end

	if ns.client_version<2 then
		if lvl<40 then
			tt:AddSeparator();
			tt:SetCell(tt:AddLine(),1,C("orange","You must be reach level 40 to learn riding."),nil,nil,0);
		end
	elseif (lvl<20) then
		tt:AddSeparator();
		tt:SetCell(tt:AddLine(),1,C("orange","You must be reach level 20 to learn riding."),nil,nil,0);
	end

	if ns.profile[name].showBonus then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltblue",L["SpeedBonus"]),nil,nil,0);
		tt:AddSeparator();
		local Id,ChkActive,Type,TypeValue,CustomText,Speed,Special,count=1,2,3,4,5,6,7,0;
		for i,spell in ipairs(bonus_spells)do
			local id = nil;
			if(spell[Type]=="race")then
				if(spell[TypeValue]==ns.player.race:upper())then
					id = spell[Id];
				end
			elseif(spell[Type]=="class")then
				if(spell[TypeValue]==ns.player.classId)then
					id = spell[Id];
				end
			else
				id = spell[Id];
			end

			if(id and C_SpellBook.IsSpellInSpellBook(id))then
				local active=false;
				local custom = "";
				local spellInfo = C_Spell.GetSpellInfo(spell[Id])

				if spell[CustomText]==true and spellInfo.rank then
					local ranks = {strsplit(" ",spellInfo.rank)}; -- TODO: missing rank in bfa?
					spell[CustomText] = ranks[2] or ranks[1];
				end

				if type(spell[CustomText])=="string" then
					custom = " "..C("ltgray","("..spell[CustomText]..")");
				end

				if(spell[ChkActive])then
					local start, duration, enabled = C_Spell.GetSpellCooldown(spell[Id]);
					if(spell[Special])then
						if(spell[Special][1]=="SPELL")then
							local spellInfo = C_Spell.GetSpellInfo(spell[Special][2])
							for i=1, 10 do
								local res = --[[ns.deprecated.]]C_UnitAuras.GetDebuffDataByIndex("player", i)
								if res and res.name==spellInfo.name then -- BfA -- changed arg2 to numeric index only
									active=true;
									break;
								end
							end
						elseif(spell[Special][1]=="TIME")then
							local h = GetGameTime();
							for i,v in ipairs(spell[Special])do
								if(type(v)=="table" and h>=v[1] and h<=v[2])then
									active=true;
								end
							end
						end
					elseif(enabled)then
						active=true;
					end
				elseif(spell[Special])then
					--- ?
				else
					active=true;
				end

				if(active)then
					local l=tt:AddLine();
					tt:SetCell(l,1,C("ltyellow",spellInfo.name .. custom));
					tt:SetCell(l,3,_(spell[Speed]));
					if spell[Id] then
						local data = {spell=spell[Id]}
						if ns.client_version>=4 then
							data.link = "spell:"..spell[Id]..":0";
						end
						tt:SetLineScript(l,"OnEnter",tooltipOnEnter, data);
						tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);
					end
					count=count+1;
				end
			end
		end
		--- inventory items and enchants?
		if(count==0)then
			tt:SetCell(tt:AddLine(),1,L["No speed bonus found..."],nil,nil,0);
		end
	end

	if ns.profile[name].showLicenses and ns.client_version>=3 and lvl>=20 then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",L["Flight licenses"]));
		tt:AddSeparator();
		for i,v in ipairs(licenses) do
			local Name, rank, icon, castTime, minRange, maxRange, completed, ready, link, l, tt2, _;
			local achievement = false;
			if v[2]==nil then
				Name = v[1];
			elseif(type(v[1])=="string")then
				local id = tonumber(v[1]:match("a(%d+)"));
				achievement = true;
				if id then
					if GetAchievementLink then
						link = GetAchievementLink(id);
					end
					if link then
						_, Name, _, completed = GetAchievementInfo(id);
						ready = completed;
					elseif type(replace_unknown[v[1]])=="table" then
						v = replace_unknown[v[1]];
						Name = v[1];
					elseif replace_unknown[v[1]] then
						Name = replace_unknown[v[1]];
					end
				end
			else
				link = C_Spell.GetSpellLink(v[1]);
				if link then
					ready = C_SpellBook.IsSpellInSpellBook(v[1]);
					local spellInfo = C_Spell.GetSpellInfo(v[1])
					Name = spellInfo.name;
				elseif type(replace_unknown["s"..v[1]])=="table" then
					v = replace_unknown["s"..v[1]];
					Name = v[1];
				elseif replace_unknown["s"..v[1]] then
					Name = replace_unknown["s"..v[1]];
				end
			end
			if Name then
				-- learned
				local color1, color2, info = "green", "ltgray", " ";
				if deprecated_licenses[v[1]] then
					color1,info = ready and "green" or "gray",L["Deprecated"];
				elseif lvl<v[2] then
					-- need level
					color1,info = "red", L["Need level"].." "..v[2];
				elseif achievement and not ready then
					-- need achievement
					color1,info = "yellow",L["Need achievement"];
				elseif not ready then
					-- learnable
					color1,info = "yellow",L["Learnable"];
				elseif v[2]==nil then
					-- obsolete, higher version active
					color1 = "dkgreen";
				end
				if not (ns.profile[name].showLicensesDeprecated and deprecated_licenses[v[1]]) then
					l = tt:AddLine();
					tt:SetCell(l,1, C(color1,Name), nil,nil,2);
					tt:SetCell(l,3, info==" " and info or C(color2,info));
					if type(v[4])=="table" or link then
						tt:SetLineScript(l,"OnEnter",tooltipOnEnter, {link=link, info=v[4]});
						tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);
					end
				end
			end
		end
	end

	if ns.profile[name].showChars then
		local hasHeader = false;
		local skillColor = {
			[90265] = "dkgreen",
			[34090] = "green",
		};
		for i,toonNameRealm,toonName,toonRealm,toonData,isCurrent in ns.pairsToons(name,{--[[currentFirst=true,]] currentHide=true,forceSameRealm=true}) do
			if toonData[name] and toonData[name].skill then
				if not hasHeader then
					tt:AddSeparator(4,0,0,0,0);
					tt:SetCell(tt:AddLine(),1,C("ltblue",L["Your other chars"]),nil,nil,0);
					tt:AddSeparator();
					hasHeader = true;
				end
				local skillName,color = TRADE_SKILLS_UNLEARNED_TAB,"orange";
				if toonData[name].skill>0 then
					local spellInfo = C_Spell.GetSpellInfo(toonData[name].skill)
					skillName = spellInfo.name;
					color = skillColor[toonData[name].skill] or "yellow";
				end
				local faction = ns.factionIcon(toonData.faction,16,16);
				local line, column = tt:AddLine(C(toonData.class,ns.scm(toonName)) .. ns.showRealmName(name,toonRealm) .. faction);
				tt:SetCell(line,2, C(color,skillName), nil,"RIGHT", 0);
			end
		end
	end

	ns.roundupTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"PLAYER_ENTERING_WORLD",
		"SKILL_LINES_CHANGED",
		"ZONE_CHANGED",
		"ZONE_CHANGED_INDOORS",
	},
	config_defaults = {
		enabled = false,

		-- broker
		precision = 0,

		-- tooltip
		showBonus = true,
		showLicenses = true,
		showLicensesDeprecated = true,

	}
}

if ns.IsRetailClient() then
	tinsert(module.events,"UNIT_SPELLCAST_SUCCEEDED");
end

function module.options()
	return {
		broker = { precision={ type="range", name=L["Precision"], desc=L["Adjust the count of numbers behind the dot."], min = 0, max = 3, step=1 } },
		tooltip = {
			showBonus = { type="toggle", order=1, name=L["SpeedBonus"], desc=L["SpeedBonusDesc"], hidden=(ns.client_version>=5) },
			showLicenses = { type="toggle", order=2, name=L["SpeedLicenses"], desc=L["SpeedLicensesDesc"], hidden=(ns.client_version>=5) },
			showLicensesDeprecated  = { type="toggle", order=2, name=L["SpeedLicensesDeprec"], desc=L["SpeedLicensesDeprecDesc"], hidden=(ns.client_version>=5) },
			showChars = {3,true},
			showAllFactions=4,
			showRealmNames=5,
			showCharsFrom=6,
		},
		misc = nil,
	}
end

function module.init()
	if ns.client_version<4 then
		local skills = {};
		if ns.player.faction=="Alliance" then
			tinsert(skills,{spell=828,   minLevel=40, speed=60, race="NightElf", faction=69}); -- NightElf
			tinsert(skills,{spell=824,   minLevel=40, speed=60, race="Human",    faction=72}); -- Human
			tinsert(skills,{spell=826,   minLevel=40, speed=60, race="Dwarf",    faction=47}); -- Dwarf
			tinsert(skills,{spell=10907, minLevel=40, speed=60, race="Gnome",    faction=54}); -- Gnome
		else
			tinsert(skills,{spell=825,   minLevel=40, speed=60, race="Orc",      faction=76}); -- Orc
			tinsert(skills,{spell=10861, minLevel=40, speed=60, race="Troll",    faction=530}); -- Troll
			tinsert(skills,{spell=18995, minLevel=40, speed=60, race="Tauren",   faction=81}); -- Tauren
			tinsert(skills,{spell=10906, minLevel=40, speed=60, race="Scourge",  faction=68}); -- Scourge
		end
		riding_skills = {};
		for i=1, #skills do
			if skills[i].race~=ns.player.race then
				skills[i].race = false;
				tinsert(riding_skills,skills[i]);
			end
		end
		for i=1, #skills do
			if skills[i].race==ns.player.race then
				skills[i].race = true;
				tinsert(riding_skills,skills[i]);
			end
		end
		return;
	end
	riding_skills = { -- <spellid>, <minLevel>, <air speed increase>, <ground speed increase>
		{spell=90265, minLevel=40, speed=310},
		{spell=34090, minLevel=30, speed=150},
		{spell=33391, minLevel=20, speed=100},
		{spell=33388, minLevel=10, speed=60},
	};
	licenses = { -- <spellid>, <minLevel>, <mapIds>
		{"a40231", 70, {}}, -- tww pathfinder
		{"a13250", 50, {}}, -- bfa pathfinder
		{"a11446", 0, {}}, -- legion pathfinder
		{"a10018", 0, {}},-- wod pathfinder
		{115913,   85, {[862]=1,[858]=1,[929]=1,[928]=1,[857]=1,[809]=1,[905]=1,[903]=1,[806]=1,[873]=1,[808]=1,[951]=1,[810]=1,[811]=1,[807]=1}},
		{54197,    80, {[485]=1,[486]=1,[510]=1,[504]=1,[488]=1,[490]=1,[491]=1,[541]=1,[492]=1,[493]=1,[495]=1,[501]=1,[496]=1}},
		{90267,    70, {[4]=1,[9]=1,[11]=1,[13]=1,[14]=1,[16]=1,[17]=1,[19]=1,[20]=1,[21]=1,[22]=1,[23]=1,[24]=1,[26]=1,[27]=1,[28]=1,[29]=1,[30]=1,[32]=1,[34]=1,[35]=1,[36]=1,[37]=1,[38]=1,[39]=1,[40]=1,[41]=1,[42]=1,[43]=1,[61]=1,[81]=1,[101]=1,[121]=1,[141]=1,[161]=1,[181]=1,[182]=1,[201]=1,[241]=1,[261]=1,[281]=1,[301]=1,[321]=1,[341]=1,[362]=1,[381]=1,[382]=1,[462]=1,[463]=1,[464]=1,[471]=1,[476]=1,[480]=1,[499]=1,[502]=1,[545]=1,[606]=1,[607]=1,[610]=1,[611]=1,[613]=1,[614]=1,[615]=1,[640]=1,[673]=1,[684]=1,[685]=1,[689]=1,[700]=1,[708]=1,[709]=1,[720]=1,[772]=1,[795]=1,[864]=1,[866]=1,[888]=1,[889]=1,[890]=1,[891]=1,[892]=1,[893]=1,[894]=1,[895]=1}},
	};
	if ns.client_version>7.35 then
		deprecated_licenses = {
			["a11446"]=1,
			["a10018"]=1,
			[115913]=1,
			[54197]=1,
			[90267]=1,
		};
	end
	trainer_faction = UnitFactionGroup("player")=="Alliance" and {
		-- { <factionID>, <npcID>, <zoneID>, <x>, <y> }
		{  72, 43693, {84,1453}, 77.6, 67.2},
		{  72, 43769, {84,1453}, 70.6, 73.0},
		{ 946, 35100, {100,1944}, 54.2, 62.6},
		{1050, 35133, {114}, 58.8, 68.2},
		{1090, 31238, {125}, 70.8, 45.6},
		{1269, 60166, {390}, 84.2, 61.6},
	} or {
		{  76, 44919, {85,1454}, 49.0, 59.6},
		{  76, 35093, {100,1944}, 54.2, 41.6},
		{1085, 35135, {114}, 42.0, 55.2},
		{1090, 31238, {125}, 70.8, 45.6},
		{1269, 60167, {390}, 62.8, 23.2},
	};
	bonus_spells = { -- <spellid>, <chkActive[bool]>, <type>, <typeValue>, <customText>, <speed increase>, <special>
		-- race spells
		{154748,  true, "race", "NIGHTELF", true,  1, {"TIME", {18,24}, {0,6}} },
		{ 20582,  true, "race", "NIGHTELF", true,  2},
		{ 20585,  true, "race", "NIGHTELF", true, 75, {"SPELL", 8326}},
		{ 68992,  true, "race",     "WORG", true, 40},
		{ 69042,  true, "race",   "GOBLIN", true,  1},

		-- class spells
		-- class: druid, id: 11
		{  5215,  true, "class",        11, LOCALIZED_CLASS_NAMES_MALE.DRUID, 30},
		-- glyphes

		-- misc
		{ 78633, false,    nil,        nil, true, 10}, -- guild perk
		{ 220510, true,    nil,        nil, false, UNKNOWN}, -- Bloodtotem Saddle Blanket (Tailoring 800)
		{ 226342, true,    nil,        nil, false, 20}
	};
	-- note: little problem with not stagging speed increasement spells...

	-- replace_unknown = { };
end

function module.onevent(self,event,...)
	if event=="PLAYER_LOGIN" then
		for i=1, #trainer_faction do
			ns.ScanTT.query({
				["type"]="unit",
				["unit"]="Creature",
				["id"]=trainer_faction[i][2],
				["trainer_index"] = i,
				["callback"] = updateTrainerName
			});
		end
		updateToonSkillLocked = true;
		updateToonSkill();
		C_Timer.NewTicker(0.2,updateBroker);
	elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
		if (...)==372610 then
			CalcSpeed.as = GetTime();
		end
		return;
	elseif event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED" or event=="ZONE_CHANGED_INDOOR" then
		local id = C_Map.GetBestMapForUnit("player");
		if currentMapID~=id then
			currentMapID = nil;
		end
	elseif not updateToonSkillLocked then
		updateToonSkillLocked = true; -- event trigger twice
		C_Timer.After(0.2, updateToonSkill);
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip(
		{ttName, ttColumns, "LEFT","RIGHT", "RIGHT", "CENTER", "LEFT", "LEFT", "LEFT", "LEFT"}, -- for LibQTip:Aquire
		{ns.client_version<4}, -- show/hide mode
		{self} -- anchor data
	);
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
