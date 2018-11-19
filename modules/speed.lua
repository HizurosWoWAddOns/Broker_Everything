
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Speed"; -- SPEED L["ModDesc-Speed"]
local ttName, ttColumns, tt, module = name.."TT", 2
local riding_skills,licences,bonus_spells,replace_unknown,trainer_faction,deprecated_licences = {},{},{},{},{},{};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\Ability_Rogue_Sprint",coords={0.05,0.95,0.05,0.95}}; --IconName::Speed--


-- some local functions --
--------------------------
local function updateTrainerName(data)
	if data.lines[1] then
		trainer_faction[data.trainer_index][6] = data.lines[1];
	end
end

local function updateBroker()
	local currentSpeed = GetUnitSpeed( UnitInVehicle("player") and "vehicle" or "player" );
	local str = ("%."..ns.profile[name].precision.."f"):format(currentSpeed / 7 * 100 ) .. "%";
	local l = 4 + (ns.profile[name].precision>0 and ns.profile[name].precision+1 or 0) - str:len();
	ns.LDB:GetDataObjectByName(module.ldbName).text = strrep(" ",l)..str;
end

local function tooltipOnEnter(self,data)
	GameTooltip:SetOwner(tt,"ANCHOR_NONE");
	GameTooltip:SetPoint("TOP",tt,"BOTTOM");
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
	elseif data.link then
		GameTooltip:SetHyperlink(data.link);
	end
	if data.extend=="trainerfaction" then
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(C("ltblue",L["Trainer that offer reputation dicount"]));
		local faction,ttTrainerLine,ttFactionLine = false,"%s (%0.1f, %0.1f)","%s (%0.1f%%)";
		for i=1, #trainer_faction do
			local v = trainer_faction[i];
			if faction~=v[1] then
				local fname,_,fstanding,fmin,fmax,fval = GetFactionInfoByID(v[1]);
				if fname then
					if faction then
						GameTooltip:AddLine(" ");
					end
					local standing = _G["FACTION_STANDING_LABEL"..fstanding];
					if fstanding<8 then
						standing = ttFactionLine:format(standing,((fval-fmin)/(fmax-fmin))*100);
					end
					GameTooltip:AddDoubleLine(C("gray",fname), C("gray",standing) );
					faction = v[1];
				end
			end
			local mapName
			if GetMapNameByID then -- pre BfA
				mapName = GetMapNameByID(v[3]);
			else
				local mapInfo = C_Map.GetMapInfo(v[3]);
				if mapInfo then
					mapName = mapInfo.name;
				end
			end
			GameTooltip:AddDoubleLine(v[6] or UNKNOWN, ttTrainerLine:format(mapName, v[4], v[5] ) ); -- TODO: BfA - removed function
			--GetMapNameByID()
			--GetFactionInfoByID()
		end
	end
	--/run local t=GameTooltip t:Hide(); t:SetOwner(UIParent,"ANCHOR_NONE") t:SetPoint("CENTER") t:SetUnit("Creature-0-0-0-0-35135-0"); t:Show();
	GameTooltip:Show();
end

local function tooltipOnLeave()
	GameTooltip:Hide();
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	local _=function(d) if tonumber(d) then return ("+%d%%"):format(d); end return d; end;
	local lvl = UnitLevel("player");

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",SPEED));
	tt:AddSeparator(4,0,0,0,0);

	tt:AddLine(C("ltblue",L["Riding skill"]));
	tt:AddSeparator();
	local learned = nil;
	for i,v in ipairs(riding_skills) do
		local Name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(v[1]);
		local l,Link,ttExtend = nil,GetSpellLink(v[1]);
		if(learned==nil and IsSpellKnown(v[1]))then
			learned = true;
		end
		if (learned==nil) then
			if(lvl>=v[2])then
				l=tt:AddLine(C("yellow",Name), C("ltgray",L["Learnable"]));
				ttExtend = true;
			else
				l=tt:AddLine(C("red",Name), C("ltgray", L["Need level"].." "..v[2]));
			end
		elseif(learned==true)then
			l=tt:AddLine(C("green",Name), _(v[3]));
			learned=false;
		elseif(learned==false)then
			l=tt:AddLine(C("dkgreen",Name), C("gray",_(v[3])) );
		end
		if l and Link then
			tt:SetLineScript(l,"OnEnter",tooltipOnEnter, {link=Link,extend=ttExtend and "trainerfaction" or nil});
			tt:SetLineScript(l,"OnLeave",tooltipOnLeave);
		end
	end
	if (lvl<20)then
		tt:AddSeparator();
		tt:AddLine(C("orange","You must be reach level 20 to learn riding."),"",C("ltgray",lvl.."/20"));
	end

	tt:AddSeparator(4,0,0,0,0);
	tt:AddLine(C("ltblue",L["Speed bonus"]));
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

		if(id and IsSpellKnown(id))then
			local active=false;
			local custom = "";
			local Name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spell[Id]);
			local Link = GetSpellLink(spell[Id]);

			if spell[CustomText]==true and rank then
				rank = {strsplit(" ",rank)}; -- TODO: missing rank in bfa?
				spell[CustomText] = rank[2] or rank[1];
			end

			if type(spell[CustomText])=="string" then
				custom = " "..C("ltgray","("..spell[CustomText]..")");
			end

			if(spell[ChkActive])then
				local start, duration, enabled = GetSpellCooldown(spell[Id]);
				if(spell[Special])then
					if(spell[Special][1]=="SPELL")then
						local n = GetSpellInfo(spell[Special][2]);
						for i=1, 10 do
							if UnitDebuff("player",i)==n then -- BfA -- changed arg2 to numeric index only
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
				local l=tt:AddLine(C("ltyellow",Name .. custom), _(spell[Speed]));
				if Link then
					tt:SetLineScript(l,"OnEnter",tooltipOnEnter, {link=Link});
					tt:SetLineScript(l,"OnLeave",tooltipOnLeave);
				end
				count=count+1;
			end
		end
	end
	--- inventory items and enchants?
	if(count==0)then
		tt:AddLine(L["No speed bonus found..."]);
	end


	if (lvl>=20)then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",L["Flight licences"]));
		tt:AddSeparator();
		for i,v in ipairs(licences) do
			local Name, rank, icon, castTime, minRange, maxRange, completed, ready, link, l, tt2, _;
			local achievement = false;
			if v[2]==nil then
				Name = v[1];
			elseif(type(v[1])=="string")then
				local id = tonumber(v[1]:match("a(%d+)"));
				achievement = true;
				if id then
					link = GetAchievementLink(id);
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
				link = GetSpellLink(v[1]);
				if link then
					Name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(v[1]);
					ready = IsSpellKnown(v[1]);
				elseif type(replace_unknown["s"..v[1]])=="table" then
					v = replace_unknown["s"..v[1]];
					Name = v[1];
				elseif replace_unknown["s"..v[1]] then
					Name = replace_unknown["s"..v[1]];
				end
			end
			if(Name)then
				-- learned
				local color1, color2, info = "green", "ltgray", " ";
				if deprecated_licences[v[1]] then
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
				l=tt:AddLine(C(color1,Name),info==" " and info or C(color2,info));
				if type(v[4])=="table" or link then
					tt:SetLineScript(l,"OnEnter",tooltipOnEnter, {link=link, info=v[4]});
					tt:SetLineScript(l,"OnLeave",tooltipOnLeave);
				end
			end
		end
	end
	ns.roundupTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {"PLAYER_LOGIN"},
	config_defaults = {
		enabled = false,
		precision = 0,
	}
}

function module.options()
	return {
		broker = nil,
		tooltip = { precision={ type="range", name=L["Precision"], desc=L["Adjust the count of numbers behind the dot."], min = 0, max = 3, step=1 } },
		misc = nil,
	}
end

function module.init()
	riding_skills = { -- <spellid>, <skill>, <minLevel>, <air speed increase>, <ground speed increase>
		{90265, 80, 310},
		{34091, 70, 280},
		{34090, 60, 150},
		{33391, 40, 100},
		{33388, 20,  60},
	};
	licences = { -- <spellid>, <minLevel>, <mapIds>
		-- bfa pathfinder
		{"a11446", 100, {}},
		{"a10018", 90, { --[[ draenor map ids? ]] }},
		{115913,   85, {[862]=1,[858]=1,[929]=1,[928]=1,[857]=1,[809]=1,[905]=1,[903]=1,[806]=1,[873]=1,[808]=1,[951]=1,[810]=1,[811]=1,[807]=1}},
		{54197,    68, {[485]=1,[486]=1,[510]=1,[504]=1,[488]=1,[490]=1,[491]=1,[541]=1,[492]=1,[493]=1,[495]=1,[501]=1,[496]=1}},
		{90267,    60, {[4]=1,[9]=1,[11]=1,[13]=1,[14]=1,[16]=1,[17]=1,[19]=1,[20]=1,[21]=1,[22]=1,[23]=1,[24]=1,[26]=1,[27]=1,[28]=1,[29]=1,[30]=1,[32]=1,[34]=1,[35]=1,[36]=1,[37]=1,[38]=1,[39]=1,[40]=1,[41]=1,[42]=1,[43]=1,[61]=1,[81]=1,[101]=1,[121]=1,[141]=1,[161]=1,[181]=1,[182]=1,[201]=1,[241]=1,[261]=1,[281]=1,[301]=1,[321]=1,[341]=1,[362]=1,[381]=1,[382]=1,[462]=1,[463]=1,[464]=1,[471]=1,[476]=1,[480]=1,[499]=1,[502]=1,[545]=1,[606]=1,[607]=1,[610]=1,[611]=1,[613]=1,[614]=1,[615]=1,[640]=1,[673]=1,[684]=1,[685]=1,[689]=1,[700]=1,[708]=1,[709]=1,[720]=1,[772]=1,[795]=1,[864]=1,[866]=1,[888]=1,[889]=1,[890]=1,[891]=1,[892]=1,[893]=1,[894]=1,[895]=1}},
	};
	if ns.build>=73500000 then
		deprecated_licences = {
			[115913]=1,
			[54197]=1,
			[90267]=1,
		};
	end
	trainer_faction = UnitFactionGroup("player")=="Alliance" and {
		-- { <factionID>, <npcID>, <zoneID>, <x>, <y> }
		{  72, 43693, 84, 77.6, 67.2},
		{  72, 43769, 84, 70.6, 73.0},
		{ 946, 35100, 100, 54.2, 62.6},
		{1050, 35133, 114, 58.8, 68.2},
		{1090, 31238, 125, 70.8, 45.6},
		{1269, 60166, 390, 84.2, 61.6},
	} or {
		{  76, 44919, 85, 49.0, 59.6},
		{  76, 35093, 100, 54.2, 41.6},
		{1085, 35135, 114, 42.0, 55.2},
		{1090, 31238, 125, 70.8, 45.6},
		{1269, 60167, 390, 62.8, 23.2},
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

function module.onevent(self,event,msg)
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
		C_Timer.NewTicker(0.2,updateBroker);
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip(
		{ttName, ttColumns, "LEFT","RIGHT", "RIGHT", "CENTER", "LEFT", "LEFT", "LEFT", "LEFT"}, -- for LibQTip:Aquire
		{false}, -- show/hide mode
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
