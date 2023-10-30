
-- module independent variables --
----------------------------------
local addon, ns = ...;
local C,L,I = ns.LC.color,ns.L,ns.I;
if ns.IsRetailClient() then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Professions"; -- TRADE_SKILLS L["ModDesc-Professions"]
local ttName,ttName2,ttColumns,ttColumns2,tt,tt2,module = name.."TT",name.."TT2",2,3;
local nameLocale, icon, skill, maxSkill, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset, fullNameLocale = 1,2,3,4,5,6,7,8,9,10,11; -- GetProfessionInfo
local spellId,skillId,disabled = 11, 12, 13; -- custom after GetProfessionInfo
local spellName,spellLocaleName,spellIcon,spellId = 1,2,3,4;
local professions,db,locked,cdSpells,poisons = {};
local skillName2Info = {}
local maxInTitle = 1;
local Faction = UnitFactionGroup("player")=="Alliance" and 1 or 2;
local skillsMax,triggerLock = {},false;
local cd_groups = { -- %s cooldown group
	"Transmutation",	-- L["Transmutation cooldown group"]
	"Jewels",			-- L["Jewels cooldown group"]
	"Leather"			-- L["Leather cooldown group"]
}

local cdReset = function(id,more)
	local cd = 0;
	more.days = more.days or 0;
	more.hours = more.hours or 0;
	cd = cd + more.days*86400 + more.hours*3600;
	if (not db.cooldown_locks[id]) then
		db.cooldown_locks[id] = time();
	elseif (db.cooldown_locks[id]) and (db.cooldown_locks[id]+cd<time()) then
		return false;
	end
	return cd, db.cooldown_locks[id];
end

local cdResetTypes = {
	function(id) -- get duration directly from GetSpellCooldown :: blizzard didn't update return values after reload.
		local start, stop = GetSpellCooldown(id);
		return stop - (GetTime()-start), time();
	end,
	function(id) -- use GetSpellCooldown to test and use GetQuestResetTime as duration time
		return GetQuestResetTime(), time();
	end,
	function(id) -- 3 days
		return cdReset(id,{days=3});
	end,
	function(id) -- 20 hours
		return cdReset(id,{hours=20});
	end,
	function(id) -- 6 days & 20 hours
		return cdReset(id,{hours=20,days=6});
	end
}


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\INV_Misc_Book_09.png",coords={0.05,0.95,0.05,0.95}}; --IconName::Professions--


-- some local functions --
--------------------------
local function updateBroker()
	local inTitle = {};

	for i=1, maxInTitle do
		local v = ns.profile[name].inTitle[i];
		if v and professions[v] and professions[v][icon] and professions[v][skill] and professions[v][maxSkill] then
			local modifier,color = "","gray2";
			if true then
				if professions[v][skill]~=professions[v][maxSkill] then
					color = "ffff"..string.format("%02x",255*(professions[v][skill]/professions[v][maxSkill])).."00";
				end
				if professions[v][rankModifier] and professions[v][rankModifier]>0 then
					modifier = C("green","+"..professions[v][rankModifier]);
				end
				table.insert(inTitle, ("%s/%s|T%s:0|t"):format(C(color,professions[v][skill])..modifier,C(color,professions[v][maxSkill]),professions[v][icon]));
			else
				table.insert(inTitle, ("%s/%s|T%s:0|t"):format(professions[v][skill]..modifier,professions[v][maxSkill],professions[v][icon]));
			end
		end
	end

	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	obj.text = (#inTitle==0) and TRADE_SKILLS or table.concat(inTitle," ");
end

local function Title_Set(place,obj)
	local db = ns.profile[name].inTitle;
	db[place] = (db[place]~=obj) and obj or false;
	updateBroker();
end

local function toggleTradeSkillWindow(self,data)
	securecall("CastSpellByName",data);
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	local iconnameLocale = "|T%s:12:12:0:0:64:64:2:62:4:62|t %s";
	local function item_icon(name,icon) return select(10,GetItemInfo(name)) or icon or ns.icon_fallback; end

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",TRADE_SKILLS));

	tt:AddLine(C("ltblue",NAME),C("ltblue",SKILL),C("ltblue",ABILITIES));
	tt:AddSeparator();
	if #professions>0 then
		for i,v in ipairs(professions) do
			local color1,color2 = "ltyellow","white";
			local skill, maxSkill,nameStr,modifier = v[skill] or 0,v[maxSkill] or 0,v[fullNameLocale] or v[nameLocale] or "?","";
			if maxSkill==0 then
				color1,color2 = "gray","gray";
			else
				local skillPercent = skill/maxSkill;
				if skillPercent==1 then
					color2 = "gray2";
				else
					color2 = "ffff"..string.format("%02x",255*skillPercent).."00";
				end
				if v[rankModifier] and v[rankModifier]>0 then
					modifier = C("green","+"..v[rankModifier]);
				end
				if v[fullNameLocale] and v[nameLocale] and v[fullNameLocale]~=v[nameLocale] then
					nameStr = "";
					local str = {strsplit(";",(v[fullNameLocale]:gsub(v[nameLocale],";%1;")))};
					for i=1, #str do
						if str[i]==v[nameLocale] then
							nameStr = nameStr..C(color1,v[nameLocale]);
						elseif str[i]~="" then
							nameStr = nameStr..C("gray2",str[i]);
						end
					end
				else
					nameStr = C(color1,nameStr);
				end
			end
			local l=tt:AddLine((iconnameLocale):format(v[icon] or ns.icon_fallback,nameStr),C(color2,skill)..modifier..C(color2,"/"..maxSkill));
			if not v[disabled] and ns.profile[name].ttOnClick then
				tt:SetLineScript(l,"OnMouseUp",toggleTradeSkillWindow,v[nameLocale]);
			end
		end
	else
		tt:AddLine(C("gray",L["No professions learned..."]));
	end

	if (ns.profile[name].showCooldowns) then
		local lst = {};
		local sep,cd1=false,0;
		local _, durationHeader = ns.DurationOrExpireDate(0,false,"Duration","Expire date");
		if (db.hasCooldowns) then
			for i,v in pairs(db.cooldowns) do
				if ( (v.timeLeft-(time()-v.lastUpdate)) > 0) then
					if (cd1==0) then
						tinsert(lst,{type="line",data={C("ltblue",ns.player.name),C("ltblue",L[durationHeader])}});
						tinsert(lst,{type="sep",data={nil}});
					end
					tinsert(lst,{type="cdLine",data=v});
					cd1=cd1+1;
				end
			end
		end

		for i,toonNameRealm,toonName,toonRealm,toonData,isCurrent in ns.pairsToons(name,{currentFirst=true,forceSameRealm=true}) do
			local char_header=false;
			if toonData.professions and toonData.professions.cooldowns and toonData.professions.hasCooldowns==true then
				local outdated = true;
				for spellid, spellData in pairs(toonData.professions.cooldowns) do
					if ( (spellData.timeLeft-(time()-spellData.lastUpdate)) > 0) then
						if (not char_header) then
							if (cd1>0) or (sep) then
								tinsert(lst,{type="sep",data={4,0,0,0,0}});
							end
							tinsert(lst,{type="line",data={C("ltblue",ns.scm(toonName))..ns.showRealmName(name,toonRealm),C("ltblue",L[durationHeader])}});
							tinsert(lst,{type="sep",data={nil}});
							char_header = true;
							sep=true;
						end
						tinsert(lst,{type="cdLine",data=spellData});
						outdated = false;
					end
				end
				if(outdated)then
					toonData.professions = {cooldowns={},hasCooldowns=false};
				end
			end
		end

		if (#lst>0) then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddHeader(C("dkyellow",L["Cooldowns"]));
			for i,v in ipairs(lst) do
				if (v.type=="sep") then
					tt:AddSeparator(unpack(v.data));
				elseif (v.type=="line") then
					tt:AddLine(unpack(v.data));
				elseif (v.type=="cdLine") then
					tt:AddLine(iconnameLocale:format(item_icon(v.data.name,v.data.icon),C("ltyellow",v.data.name)),"~ "..ns.DurationOrExpireDate(v.data.timeLeft,v.data.lastUpdate));
				end
			end
		end
	end -- / .showCooldowns

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		tt:AddLine()
		local _,_,mod = ns.DurationOrExpireDate();
		ns.AddSpannedLine(tt,C("copper",L["Hold "..mod]).." || "..C("green",L["Show expire date instead of duration"]));
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

local function checkCooldownSpells(_skillLine,_nameLoc,_icon,_skill,_maxSkill,_skillId,_spellId)
	if cdSpells[_skillLine] then
		local cooldown,idOrGroup,timeLeft,lastUpdate,_name
		local spellId, cdGroup, cdType = 1,2,3;
		for _,cd in pairs(cdSpells[_skillLine]) do
			cooldown = GetSpellCooldown(cd[spellId]);
			if cooldown and cooldown>0 then
				idOrGroup = (cd[cdGroup]>0) and "cd.group."..cd[cdGroup] or cd[spellId];
				_name = (cd[cdGroup]>0) and cd_groups[cdGroup].." cooldown group" or select(1,GetSpellInfo(cd[spellId]));
				timeLeft,lastUpdate = cdResetTypes[cd[cdType]](cd[spellId]);

				if (db.cooldowns[idOrGroup] and (timeLeft~=false) and floor(db.cooldowns[idOrGroup].timeLeft)~=floor(timeLeft)) or (not db.cooldowns[idOrGroup]) then
					db.cooldowns[idOrGroup] = {name=_name,icon=_icon,timeLeft=timeLeft,lastUpdate=lastUpdate};
					db.hasCooldowns = true;
				end
			end
		end
	end
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"VARIABLES_LOADED",
		"PLAYER_LOGIN",

		--"TRADE_SKILL_NAME_UPDATE",
		--"CHAT_MSG_TRADESKILLS",
		"NEW_RECIPE_LEARNED",

		-- archaeology
		"SKILL_LINES_CHANGED",
		"BAG_UPDATE_DELAYED",
		"CHAT_MSG_SKILL",
	},
	config_defaults = {
		enabled = true,
		showCooldowns = true,
		showDigSiteStatus = true,
		showLegionFactionRecipes = true,
		showBfAFactionRecipes = true,
		inTitle = {},
		showAllFactions=true,
		showRealmNames=true,
		showCharsFrom="2",
		ttOnClick = false,
	},
	clickOptionsRename = {
		["profmenu"] = "1_open_character_info",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["profmenu"] = {"Profession menu","module","ProfessionMenu"}, -- L["Profession menu"]
		["menu"] = "OptionMenuCustom"
	}

}

if ns.client_version>2 then
	tinsert(module.events,"CURRENCY_DISPLAY_UPDATE");
end

ns.ClickOpts.addDefaults(module,{
	profmenu = "_LEFT",
	menu = "_RIGHT"
});

function module.ProfessionMenu(self,button,modName,actName)
	if (tt~=nil) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:AddEntry({ label = L["Open"], title = true });
	ns.EasyMenu:AddEntry({ separator = true });
	for i,v in ipairs(professions) do
		if v and v.spellId and not v[disabled] then
			ns.EasyMenu:AddEntry({
				label = v[nameLocale],
				icon = v[icon],
				func = function() securecall("CastSpellByName",v[nameLocale]); end,
				disabled = not ((v[skill]) and (v[skill]>0));
			});
		end
	end
	ns.EasyMenu:ShowMenu(self);
end

function module.OptionMenu(self,button,modName,actName)
	if (tt~=nil) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:AddEntry({ label = L["In title"], title = true });
	local numProfs,numLearned = (ns.player.class=="ROGUE") and 7 or 6,0;
	for i=1, numProfs do
		if (professions[i]) then
			numLearned = numLearned+1;
		end
	end
	for I=1, maxInTitle do
		local d,e,p = ns.profile[name].inTitle;
		if (d[I]) and (professions[d[I]]) then
			e=professions[d[I]];
			p=ns.EasyMenu:AddEntry({ label = (C("dkyellow","%s%d:").."  |T%s:20:20:0:0|t %s"):format(L["Place"], I, e[icon], C("ltblue",e[nameLocale])), arrow = true, disabled=(numLearned==0) });
			ns.EasyMenu:AddEntry({
				label = (C("ltred","%s").." |T%s:20:20:0:0|t %s"):format(CALENDAR_VIEW_EVENT_REMOVE,e[icon],C("ltblue",e[nameLocale])),
				func = function()
					Title_Set(I,nil);
				end
			},p);
			ns.EasyMenu:AddEntry({ separator=true },p);
		else
			p=ns.EasyMenu:AddEntry({ label = (C("dkyellow","%s%d:").."  %s"):format(L["Place"],I,L["Add a profession"]), arrow = true, disabled=(numLearned==0) });
		end
		for i=1, numProfs do
			local v = professions[i];
			if (v) then
				ns.EasyMenu:AddEntry({
					label = v[nameLocale],
					icon = v[icon],
					func = function() Title_Set(I,i) end,
					disabled = (not v[nameLocale])
				},p);
			end
		end
	end
	ns.EasyMenu:AddConfig(name,true);
	ns.EasyMenu:ShowMenu(self);
end

function module.options()
	local opts = {
		tooltip={
			ttOnClick = { type="toggle", order=1, name=L["ProfessionTTOnClick"], desc=L["ProfessionTTOnClickDesc"]},
			showAllFactions=4,
			showRealmNames=5,
			showCharsFrom=6,
		}
	};
	return opts;
end

function module.init()
	cdSpells = {
		-- [<skillLine|tradeSkillId>] = { {<spellID|recipeID>,<Cd Group>,<Cd type>}, ... }
		[171] = { -- Alchemy
			-- classic
			{11479,1,2},{11480,1,2},{17559,1,2},{17560,1,2},{17561,1,2},{17562,1,2},{17563,1,2},{17564,1,2},{17565,1,2},{17566,1,2},
			-- bc
			{28566,1,2},{28567,1,2},{28568,1,2},{28569,1,2},{28580,1,2},{28581,1,2},{28582,1,2},{28583,1,2},{28584,1,2},{28585,1,2},
			-- wotlk
			{52776,1,2},{52780,1,2},{53771,1,2},{53773,1,2},{53774,1,2},{53775,1,2},{53777,1,2},{53779,1,2},{53781,1,2},{53782,1,2},{53783,1,2},{53784,1,2},{54020,1,2},
			-- cata
			{60893,0,1}, -- Alchemy Research // 3 days QuestResetTime?
			{66658,1,2},{66659,1,2},{66660,1,2},{66662,1,2},{66663,1,2},{66664,1,2},{78866,1,2},{80243,0,2},{80244,1,2},
			-- wod
			{114780,1,2},{114783,0,2},{156587,0,2},{168042,0,2},{175880,0,2},
		},
		[333] = { -- Enchanting
			-- cata
			{116499,0,2},
			-- wod
			{169092,0,2},{177043,0,2},{178241,0,2},
		},
		[755] = { -- Jewelcrafting
			-- bc
			{47280,0,2},
			-- wotlk
			{62242,0,2},
			-- cata
			{73478,0,2},
			-- mop
			{131593,2,2},{131695,2,2},{131690,2,2},{131686,2,2},{131691,2,2},{131688,2,2},{140050,0,2},
			-- wod
			{170700,0,2},{170832,0,2},{176087,0,2},
		},
		[197] = { -- Tailoring
			-- cata
			{75141,0,1},{75142,0,1},{75144,0,1},{75145,0,1},{75146,0,1},
			-- mop
			{125557,0,2},{143011,0,2},
			-- wod
			{168835,0,2},{169669,0,2},{176058,0,2},
		},
		[773] = { -- Inscription
			-- wotlk
			{61288,0,2},{61177,0,2},{89244,0,2},{86654,0,2},
			-- mop
			{112996,0,2},
			-- wod
			{169081,0,2},{177045,0,2},{178240,0,2},
		},
		[164] = { -- Blacksmithing
			-- cata
			{138646,0,2},{143255,0,2},
			-- wod
			{171690,0,2},{171718,0,2},{176090,0,2},
		},
		[165] = { -- Leatherworking
			-- cata
			{140040,3,2},{140041,3,2},{142976,0,2},
			-- wod
			{171391,0,2},{171713,0,2},{176089,0,2},
		},
		[202] = { -- Engineering
			-- cata
			{139176,0,2},
			-- wod
			{169080,0,2},{177054,0,2},{178242,0,2},
		}
	};
	skillsMax = {
		300, -- vanilla
	}
	poisons = {
		-- recipe, level, prof spellId, questrow
		{18160, 20, 2550, {}}
	}
	if(ns.toon.professions==nil)then
		ns.toon.professions = {cooldowns={},hasCooldowns=false};
	end
	db = ns.toon.professions;
	if (db.cooldowns==nil) then
		db.cooldowns = {};
	end
	if (db.cooldown_locks==nil) then
		db.cooldown_locks = {};
	end

	-- collect localized profession names
	local t = {
		-- main
		2259,171, -- Alchemy
		2018,164, -- Blacksmithing
		2108,165, -- Leatherworking
		3273,129, -- First Aid
		3908,197, -- Tailoring
		4036,202, -- Engineering
		7411,333, -- Enchanting
		45357,773, -- Inscription
		25229,755, -- Jewelcrafting

		-- main/collecting
		2575,186, -- Mining
		9134,182, -- Herbalism
		8613,393, -- Skinning

		-- secondary
		7620,356, -- Fishing
		2550,185, -- Cooking

		-- misc
		--2656,0,   -- Smelting
		2842,0,   -- Poisons, rouge
		1804,0,   -- Lockpicking, rouge
	}
	for i=1, #t, 2 do
		local Name,_,Icon = GetSpellInfo(t[i])
		if Name then
			skillName2Info[Name] = {spellId=t[i],icon=Icon,skillId=t[i+1]}
		end
	end
end

local function OnEventUpdate()
	local numSkills,lastHeader = GetNumSkillLines();
	local SECONDARY_SKILLS = SECONDARY_SKILLS:gsub(HEADER_COLON,"");
	local tmp,short = {},{};
	local n = 1;
	for skillIndex=1, numSkills do
		local skillName, header, _, skillRank, numTempPoints, skillModifier, skillMaxRank = GetSkillLineInfo(skillIndex);
		if skillName then
			if header then
				lastHeader = skillName;
			elseif (lastHeader==TRADE_SKILLS or lastHeader==SECONDARY_SKILLS) and skillName2Info[skillName] then
				skillRank = skillRank + numTempPoints;
				local d = {skillName,nil,skillRank,skillMaxRank,0,nil,nil,skillModifier,nil,nil,nil,nil,nil};

				local skillInfo = skillName2Info[skillName];
				if skillInfo then
					d.spellId = skillInfo.spellId
					d[icon] = skillInfo.icon
					d.skillId = skillInfo.skillId
				end

				if d.spellId==2575 then
					d.spellId = 2656; -- replace mining with smelting to open skillframe window
				elseif d.spellId == 7620 or d.spellId == 2842 or d.spellId == 1804 then
					-- hide some progessions in profession menu to prevent error message
					d[disabled] = true;
				end

				if lastHeader==TRADE_SKILLS then
					short[n] = {d[skillLine],skillName,d[icon],d[skill],d[maxSkill],d.skillId,d.spellId};
				end

				tmp[n] = d or false;
				n = n + 1;
			end
		end
	end
	if #tmp>0 then
		professions = tmp;
		maxInTitle = #tmp;
	end

	db.hasCooldowns = false;

	local nCooldowns,t = 0,time();
	for i,v in pairs(db.cooldowns) do
		if (type(v)=="table") and (v.timeLeft) and (v.timeLeft-(t-v.lastUpdate)<=0) then
			db.cooldowns[i]=nil;
		else
			nCooldowns=nCooldowns+1;
			db.hasCooldowns=true;
		end
	end

	if (short[1]) and (short[1][1]) and (type(cdSpells[short[1][1]])=="table") then
		checkCooldownSpells(unpack(short[1]));
	end
	if (short[2]) and (short[2][1]) and (type(cdSpells[short[2][1]])=="table") then
		checkCooldownSpells(unpack(short[2]));
	end
	updateBroker();
	triggerLock = false
end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
		return;
	elseif event=="VARIABLES_LOADED" then
		if ns.toon[name]==nil then
			ns.toon[name]={};
		end
		if ns.toon[name].learnedRecipes==nil then
			ns.toon[name].learnedRecipes = {};
		end
--@do-not-package@
		ns.profileSilenceFIXME=true;
--@end-do-not-package@
		if ns.profile[name].showFactionRecipes~=nil then
			ns.profile[name].showLegionFactionRecipes = ns.profile[name].showFactionRecipes;
			ns.profile[name].showFactionRecipes = nil;
		end
	elseif event=="NEW_RECIPE_LEARNED" and type(arg1)=="number" then
		ns.toon[name].learnedRecipes[arg1] = true;
	elseif (event=="PLAYER_LOGIN" or ns.eventPlayerEnteredWorld) and not triggerLock then
		triggerLock = true
		C_Timer.After(0.15, OnEventUpdate)
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT"},{not ns.profile[name].ttOnClick},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
