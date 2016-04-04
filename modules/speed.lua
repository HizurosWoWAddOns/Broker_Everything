
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Speed" -- L["Speed"]
local ldbName, ttName, ttColumns, tt = name, name.."TT", 2
local string,GetUnitSpeed,UnitInVehicle = string,GetUnitSpeed,UnitInVehicle
local riding_skills = { -- <spellid>, <skill>, <minLevel>, <air speed increase>, <ground speed increase>
	{90265, 80, 310},
	{34091, 70, 280},
	{34090, 60, 150},
	{33391, 40, 100},
	{33388, 20,  60},
};
local licences = { -- <spellid>, <minLevel>, <mapIds>
	{"a10018", 90, { --[[ draenor map ids? ]] }},
	{115913,   85, {[862]=1,[858]=1,[929]=1,[928]=1,[857]=1,[809]=1,[905]=1,[903]=1,[806]=1,[873]=1,[808]=1,[951]=1,[810]=1,[811]=1,[807]=1}},
	{54197,    68, {[485]=1,[486]=1,[510]=1,[504]=1,[488]=1,[490]=1,[491]=1,[541]=1,[492]=1,[493]=1,[495]=1,[501]=1,[496]=1}},
	{90267,    60, {[4]=1,[9]=1,[11]=1,[13]=1,[14]=1,[16]=1,[17]=1,[19]=1,[20]=1,[21]=1,[22]=1,[23]=1,[24]=1,[26]=1,[27]=1,[28]=1,[29]=1,[30]=1,[32]=1,[34]=1,[35]=1,[36]=1,[37]=1,[38]=1,[39]=1,[40]=1,[41]=1,[42]=1,[43]=1,[61]=1,[81]=1,[101]=1,[121]=1,[141]=1,[161]=1,[181]=1,[182]=1,[201]=1,[241]=1,[261]=1,[281]=1,[301]=1,[321]=1,[341]=1,[362]=1,[381]=1,[382]=1,[462]=1,[463]=1,[464]=1,[471]=1,[476]=1,[480]=1,[499]=1,[502]=1,[545]=1,[606]=1,[607]=1,[610]=1,[611]=1,[613]=1,[614]=1,[615]=1,[640]=1,[673]=1,[684]=1,[685]=1,[689]=1,[700]=1,[708]=1,[709]=1,[720]=1,[772]=1,[795]=1,[864]=1,[866]=1,[888]=1,[889]=1,[890]=1,[891]=1,[892]=1,[893]=1,[894]=1,[895]=1}},
}
local bonus_spells = { -- <spellid>, <chkActive[bool]>, <type>, <typeValue>, <customText>, <speed increase>, <special>
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
	{ 78633, false,    nil,        nil, true, 10} -- guild perk
}


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\Ability_Rogue_Sprint",coords={0.05,0.95,0.05,0.95}}; --IconName::Speed--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["How fast are you swimming, walking, riding or flying."]
ns.modules[name] = {
	desc = desc,
	events = {},
	updateinterval = 0.1, -- false or integer
	config_defaults = {
		precision = 0
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="slider", name="precision", label=L["Precision"], tooltip=L["Adjust the count of numbers behind the dot."], min = 0, max = 3, default = 0, format="%d" }
	}
}


--------------------------
-- some local functions --
--------------------------
local function createTooltip(tt)
	local _=function(d) return ("+%d%%"):format(d); end;
	local lvl = UnitLevel("player");
	tt:Clear();

	tt:AddHeader(C("dkyellow",L[name]));
	tt:AddSeparator(4,0,0,0,0);

	tt:AddLine(C("ltblue",L["Riding skill"]));
	tt:AddSeparator();
	local learned = nil;
	for i,v in ipairs(riding_skills) do
		local Name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(v[1]);
		if(IsSpellKnown(v[1]))then
			learned = true;
		end
		if (learned==nil) then
			if(lvl>=v[2])then
				tt:AddLine(C("yellow",Name), C("ltgray",L["Learnable"]));
			else
				tt:AddLine(C("red",Name), C("ltgray", L["Need level"].." "..v[2]));
			end
		elseif(learned==true)then
			tt:AddLine(C("green",Name), _(v[3]));
			learned=false;
		elseif(learned==false)then
			tt:AddLine(C("dkgreen",Name), C("gray",_(v[3])) );
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

			if(spell[CustomText]==true)then
				rank = {strsplit(" ",rank)};
				spell[CustomText] = rank[2] or rank[1];
			end

			if(spell[CustomText])then
				custom = " "..C("ltgray","("..spell[CustomText]..")");
			end

			if(spell[ChkActive])then
				local start, duration, enabled = GetSpellCooldown(spell[Id]);
				if(spell[Special])then
					if(spell[Special][1]=="SPELL")then
						local n = GetSpellInfo(spell[Special][2]);
						if(UnitDebuff("player",n))then
							active=true;
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
				tt:AddLine(C("ltyellow",Name .. custom), _(spell[Speed]));
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
			local Name, rank, icon, castTime, minRange, maxRange, completed, wasEarnedByMe, ready, _;
			if(type(v[1])=="string")then
				local id = tonumber(v[1]:match("a(%d+)"));
				if(id)then
					_, Name, _, completed, _, _, _, _, _, _, _, _, wasEarnedByMe = GetAchievementInfo(id);
					ready = completed;
				end
			else
				Name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(v[1]);
				ready = IsSpellKnown(v[1]);
			end
			if(Name)then

				if(ready and lvl<v[2])then
					tt:AddLine(C("yellow",Name),C("ltgray",L["Need level"].." "..v[2]));
				elseif(ready) then
					tt:AddLine(C("green",Name));
				elseif(lvl>=v[2])then
					tt:AddLine(C("yellow",Name),C("ltgray",L["Learnable"]));
				else
					tt:AddLine(C("red",Name),C("ltgray",L["Need level"].." "..v[2]));
					learnable=true;
				end
			end
		end
	end

end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

-- ns.modules[name].onevent = function(self,event,msg) end

ns.modules[name].onupdate = function(self)
	local obj = self.obj or ns.LDB:GetDataObjectByName(ldbName)

	local unit = "player"
	if UnitInVehicle("player") then unit = "vehicle" end

	local speed = ("%."..Broker_EverythingDB[name].precision.."f"):format(GetUnitSpeed(unit) / 7 * 100 ) .. "%"

	obj.text = speed
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT","RIGHT", "RIGHT", "CENTER", "LEFT", "LEFT", "LEFT", "LEFT" );
	createTooltip(tt);
	ns.createTooltip(self,tt);
end -- tt prevention (currently not on all broker panels...)

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
end

-- ns.modules[name].onclick = function(self,button)
	--if not PetJournalParent then PetJournal_LoadUI() end 
	--securecall("TogglePetJournal",1)
--end

-- ns.modules[name].ondblclick = function(self,button) end

