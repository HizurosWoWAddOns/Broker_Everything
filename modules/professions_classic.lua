
-- module independent variables --
----------------------------------
local addon, ns = ...;
local C,L,I = ns.LC.color,ns.L,ns.I;
if ns.client_version>1.9 then return end

--#- missing event to update list of professions... [?]
--#- update cooldown list
--#- invert ns.toon.professions.learnedRecipes to unlearnedRecipes. reduce memory usage
--#- max skills / get skill from event / get skill list from open profession frame

-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Professions"; -- TRADE_SKILLS L["ModDesc-Professions"]
local ttName,ttName2,ttColumns,ttColumns2,tt,tt2,module = name.."TT",name.."TT2",2,3;
local nameLocale, icon, skill, maxSkill, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset, fullNameLocale = 1,2,3,4,5,6,7,8,9,10,11; -- GetProfessionInfo
local nameEnglish,spellId,skillId,disabled = 11, 12, 13, 14; -- custom after GetProfessionInfo
local spellName,spellLocaleName,spellIcon,spellId = 1,2,3,4;
local professions,db,locked = {};
local Faction = UnitFactionGroup("player")=="Alliance" and 1 or 2;
local profs = {data={},name2Id={},spellId2skillId={},generated=false};
local ts,skillsMax = {},{};

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

	for i=1, 4 do
		local v = ns.profile[name].inTitle[i];
		if v and professions[v] and professions[v][icon] and professions[v][skill] and professions[v][maxSkill] then
			local Skill,modifier,color = professions[v][skill],"","gray2";
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

local function GetTimeLeft(a,b)
	return floor(a-(time()-b));
end

function profs.build()
	for spellId, spellData in pairs({
		[1804] = {"Lockpicking"}, [2018] = {"Blacksmithing",164}, [2108] = {"Leatherworking",165}, [2259] = {"Alchemy",171},     [2550] = {"Cooking"},         [2575] = {"Mining"},
		[2656] = {"Smelting"},    [2366] = {"Herbalism"},         [3273] = {"First Aid"},          [3908] = {"Tailoring",197},   [4036] = {"Engineering",202}, [7411] = {"Enchanting",333},
		[7620] = {"Fishing"},     [8613] = {"Skinning"},
	}) do
		local spellLocaleName,_,spellIcon = GetSpellInfo(spellId);
		if (spellLocaleName) then
			profs.data[spellId]   = {spellData[1],spellLocaleName,spellIcon,spellId};
			L[spellData[1]] = spellLocaleName; -- localization
			L[spellLocaleName] = spellData[1]; -- localization backwards
			profs.name2Id[spellData[1]] = spellId;
			profs.name2Id[L[spellData[1]]] = spellId;
			profs.spellId2skillId[spellId] = spellData[2];
			profs.generated=true;
		end
	end
end

local function OnLearnRecipe(itemId,i)
	if legion_faction_recipes[i][4]==itemId then
		ns.toon[name].learnedRecipes[legion_faction_recipes[i][5]]=true;
	end
end

local function CreateTooltip2(self, content)
	local content,expansion,tsId,recipes,factions = unpack(content);
	tt2 = ns.acquireTooltip({ttName2, ttColumns2, "LEFT","RIGHT","CENTER"},{true,true},{self, "horizontal", tt});

	if content=="skilled" then
		--
	elseif content=="faction-recipes" then
		tt2:AddLine(C("ltblue",L["Recipes from faction vendors"].." ("..ts[tsId]..")"),C("ltblue",REPUTATION),C("ltblue",L["Buyable"]));
		tt2:AddSeparator();

		local factionID,factionName,factionId,standingID,_ = 0;
		for _, recipeData in ipairs(recipes) do
			local factionId, standingId, itemId, recipeId, recipeStars = unpack(recipeData);
			if ts[tsId] then
				local Name = GetSpellInfo(recipeId);
				if Name then
					-- faction header
					if factionID~=recipeData[1] then
						factionName,_,standingID = GetFactionInfoByID(factionId);
						tt2:AddLine(C("ltgray",factionName),C("ltgray",_G["FACTION_STANDING_LABEL"..standingID]));
						factionID = factionId;
					end
					-- recipe
					local color,faction,buyable = "red",_G["FACTION_STANDING_LABEL"..standingId],NO;
					if ns.toon[name].learnedRecipes[recipeId]==true then
						color,buyable = "ltgreen",ALREADY_LEARNED;
					elseif standingID>=standingId then
						color,buyable = "green",YES;
					end
					local stars = "";
					if recipeStars then
						stars = " "..("|Tinterface\\common\\reputationstar:12:12:0:0:32:32:2:14:2:14|t"):rep(recipeStars);
					end
					tt2:AddLine("    "..C("ltyellow",Name)..stars,C(color,faction),C(color,buyable));
				end
			end
		end
	end

	ns.roundupTooltip(tt2, true);
end

local function AddFactionRecipeLines(tt,expansion,recipesByProfession)
	local legende,faction,trade_skill,factionName,factionId,standingID,_ = false,0,0;
	tt:AddLine(C("gray",_G["EXPANSION_NAME"..expansion]));
	local tskills = {};
	local factions = {};
	for tsId, recipes in pairs(recipesByProfession)do
		if ts[tsId] then
			local count = {0,0,0}; -- <learned>,<buyable>,<total>
			for _,recipe in ipairs(recipes) do
				if not factions[recipe[1]] then
					factions[recipe[1]] = {};
					factions[recipe[1]].name,_,factions[recipe[1]].standing = GetFactionInfoByID(recipe[1]);
				end
				if ns.toon[name].learnedRecipes[recipe[4]] then
					count[1] = count[1]+1; -- learned
				end
				if recipe[2]==factions[recipe[1]].standing then
					count[2] = count[2]+1; -- buyable
				end
				count[3] = count[3]+1; -- total
			end
			local l=tt:AddLine("    "..C(count[1]==count[3] and "gray2" or "ltyellow",L[ts[tsId]]));
			tt:SetCell(l,2,("%d/%d"):format(count[1],count[3]));
			tt:SetLineScript(l,"OnEnter",CreateTooltip2,{"faction-recipes",expansion,tsId,recipes,factions});
		end
	end
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	local iconnameLocale = "|T%s:12:12:0:0:64:64:2:62:4:62|t %s";
	local function item_icon(name,icon) return select(10,GetItemInfo(name)) or icon or ns.icon_fallback; end

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",TRADE_SKILLS));
	local legende = false;

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
					color2 = "gray2","gray2";
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
			tt:AddLine((iconnameLocale):format(v[icon] or ns.icon_fallback,nameStr),C(color2,skill)..modifier..C(color2,"/"..maxSkill));
			if v[7] and v.nameEnglish then
				ts[v[7]] = v.nameEnglish;
			end
		end
	else
		tt:AddLine(C("gray",L["No professions learned..."]));
	end

	if (ns.profile[name].showCooldowns) then
		local lst,lst = {},{};
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

		for i=1, #Broker_Everything_CharacterDB.order do
			local charName,charRealm,_ = strsplit("-",Broker_Everything_CharacterDB.order[i],2);
			local charData = Broker_Everything_CharacterDB[Broker_Everything_CharacterDB.order[i]];
			local char_header=false;
			if (not (charRealm==ns.realm and charName==ns.player.name)) and (charData.professions) and (charData.professions.cooldowns) and (charData.professions.hasCooldowns==true) then
				local outdated = true;
				for spellid, spellData in pairs(charData.professions.cooldowns) do
					if ( (spellData.timeLeft-(time()-spellData.lastUpdate)) > 0) then
						if (not char_header) then
							if (cd1>0) or (sep) then
								tinsert(lst,{type="sep",data={4,0,0,0,0}});
							end
							tinsert(lst,{type="line",data={C("ltblue",ns.scm(charName))..ns.showRealmName(name,charRealm),C("ltblue",L[durationHeader])}});
							tinsert(lst,{type="sep",data={nil}});
							char_header = true;
							sep=true;
						end
						tinsert(lst,{type="cdLine",data=spellData});
						outdated = false;
					end
				end
				if(outdated)then
					charData.professions = {cooldowns={},hasCooldowns=false};
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
		local l,c = tt:AddLine()
		local _,_,mod = ns.DurationOrExpireDate();
		ns.AddSpannedLine(tt,C("copper",L["Hold "..mod]).." || "..C("green",L["Show expire date instead of duration"]));
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

local cdX = {};
local function updateTradeSkill(_,recipes)

	if _==true and type(recipes)=="table" then
		--local info = {};
		-- recipes buyable from faction vendors
		local fvr = {};
		for _,v in ipairs(recipes) do
			fvr[v[4]] = true;
		end
		-- spell cooldowns
		local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs();
		local recipeInfo = {};
		for idx = 1, #recipeIDs do
			local recipeID = recipeIDs[idx];
			C_TradeSkillUI.GetRecipeInfo(recipeID, recipeInfo);
			if fvr[recipeID] and recipeInfo and recipeInfo.learned then
				ns.toon[name].learnedRecipes[recipeID] = true;
			end
			local cooldown, isDayCooldown, charges, maxCharges = C_TradeSkillUI.GetRecipeCooldown(recipeID);
		end

	else
		C_Timer.After(.314159,function()
			local _,_,_,_,_,tsId = C_TradeSkillUI.GetTradeSkillLine();
			if legion_faction_recipes[tsId] then
				updateTradeSkill(true,legion_faction_recipes[tsId]);
			end
			if bfa_faction_recipes[tsId] then
				updateTradeSkill(true,bfa_faction_recipes[tsId]);
			end
		end);
	end
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
		"ADDON_LOADED",
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
		showCharsFrom="2"
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
	tinsert(module.events,"ARTIFACT_UPDATE");
	tinsert(module.events,"CURRENCY_DISPLAY_UPDATE");
end

ns.ClickOpts.addDefaults(module,{
	profmenu = "_LEFT",
	menu = "_RIGHT"
});

function module.ProfessionMenu()
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

function module.OptionMenu()
	if (tt~=nil) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:AddEntry({ label = L["In title"], title = true });
	local numProfs,numLearned = (ns.player.class=="ROGUE") and 7 or 6,0;
	for i=1, numProfs do
		if (professions[i]) then
			numLearned = numLearned+1;
		end
	end
	for I=1, 3 do
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
			--showCooldowns={ type="toggle", order=3, name=L["Show cooldowns"], desc=L["Show/Hide profession cooldowns from all characters."] },
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
		},
		[333] = { -- Enchanting
		},
		[197] = { -- Tailoring
			{75141,0,1},{75142,0,1},{75144,0,1},{75145,0,1},{75146,0,1},{125557,0,2},{143011,0,2},
		},
		[164] = { -- Blacksmithing
			{138646,0,2},{143255,0,2},
		},
		[165] = { -- Leatherworking
			{140040,3,2},{140041,3,2},{142976,0,2},
		},
		[202] = { -- Engineering
			{139176,0,2},
		}
	};
	skillsMax = {
		300, -- vanilla
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
	profs.build();
end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
		return;
	elseif event=="ADDON_LOADED" and arg1==addon then
--@do-not-package@
		ns.profileSilenceFIXME=true;
--@end-do-not-package@
		if ns.profile[name].showFactionRecipes~=nil then
			ns.profile[name].showLegionFactionRecipes = ns.profile[name].showFactionRecipes;
			ns.profile[name].showFactionRecipes = nil;
		end
	elseif event=="NEW_RECIPE_LEARNED" and type(arg1)=="number" then
		ns.toon[name].learnedRecipes[arg1] = true;
	elseif event=="CHAT_MSG_SKILL" then
		ns.debug(event,arg1,...);
	elseif event=="PLAYER_LOGIN" or ns.eventPlayerEnteredWorld then
		if ns.toon[name]==nil then
			ns.toon[name]={};
		end
		if ns.toon[name].learnedRecipes==nil then
			ns.toon[name].learnedRecipes = {};
		end

		if (not profs.generated) then
			profs.build();
		end

		local numSkills,lastHeader = GetNumSkillLines();
		local SECONDARY_SKILLS = SECONDARY_SKILLS:gsub(HEADER_COLON,"");
		local tmp,short = {},{};
		local n = 1;
		for skillIndex=1, numSkills do
			local skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType = GetSkillLineInfo(skillIndex);
			if skillName then
				local _profs = profs; -- for debugging
				if header then
					lastHeader = skillName;
				elseif (lastHeader==TRADE_SKILLS or lastHeader==SECONDARY_SKILLS) and profs.name2Id[skillName] then
					skillRank = skillRank + numTempPoints;
					local d = {skillName,nil,skillRank,skillMaxRank,0,nil,nil,skillModifier,nil,nil,nil,nil,nil};

					d.spellId = profs.name2Id[skillName];
					d[icon] = profs.data[d.spellId][spellIcon];
					d.skillId = profs.spellId2skillId[d.spellId];
					if d.spellId==2575 then
						d.spellId = 2656; -- replace mining with smelting to open skillframe window
					end
					d.nameEnglish = L[skillName];

					if lastHeader==TRADE_SKILLS then
						short[n] = {d[skillLine],skillName,d[icon],d[skill],d[maxSkill],d.skillId,d.spellId};
					end

					if d.nameEnglish == "Fishing" then -- hide fishing in profession menu to prevent error message
						d[disabled]=true;
					end

					tmp[n] = d or false;
					n = n + 1;
				end
			end
		end
		if #tmp>0 then
			professions = tmp;
		end

		if (ns.player.class=="ROGUE") then
			d = {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil};
			d.spellId = 1804;
			if (IsSpellKnown(d.spellId)) then
				d[skill] = UnitLevel("player") * 5;
				d[maxSkill] = d[skill];
			end
			d.nameEnglish,d[nameLocale],d[icon] = unpack(profs.data[d.spellId] or {});
			d[disabled] = true;
			tinsert(professions,d);
		end

		db.hasCooldowns = false;

		local nCooldowns = 0;
		for i,v in pairs(db.cooldowns) do
			if (type(v)=="table") and (v.timeLeft) and (v.timeLeft-(time()-v.lastUpdate)<=0) then
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
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
