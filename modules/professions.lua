
-- module independent variables --
----------------------------------
local addon, ns = ...;
local C,L,I = ns.LC.color,ns.L,ns.I;
if ns.client_version<4 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Professions"; -- TRADE_SKILLS L["ModDesc-Professions"]
local ttName,ttName2,ttColumns,ttColumns2,tt,tt2,module = name.."TT",name.."TT2",2,3;
local professions,cdSpells,skillNameById,toonDB,locked = {},{},{};
local faction_recipes,PATTERN_SKILL_RANK_UP = {factionId=1,standing=2,itemId=3,spellId=4,rank=5};
local expansionSkillLines
do
	local arg1pattern, arg2pattern = "'%%s'","%%d";
	if LOCALE_deDE then
		arg1pattern, arg2pattern = "%%1%$s","%%2%$d"
	end
	PATTERN_SKILL_RANK_UP = ERR_SKILL_UP_SI:gsub(arg1pattern, "(.+)"):gsub(arg2pattern, "(%%d+)")
end
local cd_groups = { -- %s cooldown group
	"Transmutation",	-- L["Transmutation cooldown group"]
	"Jewels",			-- L["Jewels cooldown group"]
	"Leather"			-- L["Leather cooldown group"]
}


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\INV_Misc_Book_09.png",coords={0.05,0.95,0.05,0.95}}; --IconName::Professions--


-- some local functions --
--------------------------
local function cdReset(id,more)
	local cd = 0;
	more.days = more.days or 0;
	more.hours = more.hours or 0;
	cd = cd + more.days*86400 + more.hours*3600;
	if (not toonDB.cooldown_locks[id]) then
		toonDB.cooldown_locks[id] = time();
	elseif (toonDB.cooldown_locks[id]) and (toonDB.cooldown_locks[id]+cd<time()) then
		return false;
	end
	return cd, toonDB.cooldown_locks[id];
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

local function OnLearnRecipe(itemId,info) -- info {<expansionIndex>,<index>}
	local recipeItemID = faction_recipes[ info[1] ][ info[2] ][ faction_recipes.itemId ];
	if recipeItemID==itemId then
		toonDB.unlearnedRecipes[recipeItemID]=nil;
	end
end

local function chkExpiredCooldowns()
	toonDB.hasCooldowns = false;

	-- check for expired cooldowns
	local nCooldowns = 0;
	for i,v in pairs(toonDB.cooldowns) do
		if (type(v)=="table") and (v.timeLeft) and (v.timeLeft-(time()-v.lastUpdate)<=0) then
			toonDB.cooldowns[i]=nil;
		else
			nCooldowns=nCooldowns+1;
			toonDB.hasCooldowns=true;
		end
	end
end

local function chkCooldownSpells(skillId,icon)
	if cdSpells[skillId] then
		local cooldown,idOrGroup,timeLeft,lastUpdate,_name
		local spellId, cdGroup, cdType = 1,2,3;
		for _,cd in pairs(cdSpells[skillId]) do
			cooldown = GetSpellCooldown(cd[spellId]);
			if cooldown and cooldown>0 then
				idOrGroup = (cd[cdGroup]>0) and "cd.group."..cd[cdGroup] or cd[spellId];
				_name = (cd[cdGroup]>0) and cd_groups[cdGroup].." cooldown group" or select(1,GetSpellInfo(cd[spellId]));
				timeLeft,lastUpdate = cdResetTypes[cd[cdType]](cd[spellId]);

				if (toonDB.cooldowns[idOrGroup] and (timeLeft~=false) and floor(toonDB.cooldowns[idOrGroup].timeLeft)~=floor(timeLeft)) or (not toonDB.cooldowns[idOrGroup]) then
					toonDB.cooldowns[idOrGroup] = {name=_name,icon=icon,timeLeft=timeLeft,lastUpdate=lastUpdate};
					toonDB.hasCooldowns = true;
				end
			end
		end
	end
end

local function updateTradeSkills()
	wipe(professions)

	local lst = {GetProfessions()}; -- prof1, prof2, arch, fish, cook
	for order,index in pairs(lst) do
		local skillName, texture, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset, skillLineName
		if index then
			skillName, texture, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset, skillLineName = GetProfessionInfo(index);
		end
		if skillName then
			local _, spellId = GetSpellBookItemInfo(1 + spelloffset, BOOKTYPE_PROFESSION);
			professions[order] = {
				skillName = skillName,
				skillNameFull = skillLineName,
				skillIcon = texture,
				skillId = skillLine,
				spellId = spellId,
				numSkill = rank or 0,
				maxSkill = maxRank or 0,
				skillModifier = rankModifier or 0,
			};
			chkCooldownSpells(skillLine,texture);
			chkExpiredCooldowns();
			skillNameById[skillLine] = skillName;

			-- register unlearned faction recipes // ~~not working anymore. IsSpellKnown return false for known recipes~~ fixed in dragonflight.

			for expansionIndex, recipes in pairs(faction_recipes) do
				if tonumber(expansionIndex) and recipes[skillLine] then
					for index,recipe in ipairs(recipes[skillLine]) do
						if IsSpellKnown(recipe[faction_recipes.spellId]) then
							toonDB.unlearnedRecipes[recipe[faction_recipes.itemId] ] = nil;
						else
							toonDB.unlearnedRecipes[recipe[faction_recipes.itemId] ] = true;
							ns.UseContainerItemHook.registerItemID(name,recipe[faction_recipes.itemId],OnLearnRecipe,{expansionIndex,index});
						end
					end
				end
			end
		else
			professions[order] = false;
		end
	end

	-- class skills
	for spellId,t in pairs({[1804]={"ROGUE",0,true},[53428]={"DEATHKNIGHT",1,false}})do
		if ns.player.class==t[1] then
			local spellName,_,icon = GetSpellInfo(spellId);
			local skill,maxSkill = 0,0;
			if IsSpellKnown(spellId) then
				if t[1]=="ROGUE" then
					skill = UnitLevel("player") * 5;
					maxSkill = skill;
				else
					skill,maxSkill = t[2],t[2];
				end
			end
			tinsert(professions,{
				skillName = spellName,
				skillNameFull = spellName,
				skillIcon = icon,
				skillId = false,
				spellId = spellId,
				numSkill = skill,
				maxSkill = maxSkill,
				disabled = t[3]
			});
		end
	end
end


local function updateCooldownAndRecipeLists(skillLineID,rebuildCooldowns) -- on hooked TradeSkillFrame:RefreshTitle()
	local factionRecipeIDs = {};
	-- create recipe spellId list
	for expansionIndex,recipes in pairs(faction_recipes) do
		if not tonumber(recipes) and recipes[skillLineID] then
			for _,recipeInfo in ipairs(recipes[skillLineID]) do
				factionRecipeIDs[recipeInfo[faction_recipes.spellId]] = recipeInfo[faction_recipes.itemId];
			end
		end
	end
	--[[
	local rebuildCooldowns = true;
	if dataDB.recipeCooldowns[skillLineID]==nil then
		dataDB.recipeCooldowns[skillLineID] = {};
		rebuildCooldowns = true;
	end
	--]]
	local learnedRecipes = {};
	for i, recipeId in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
		-- status of recipes buyable from faction vendors
		if factionRecipeIDs[recipeId] then
			local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeId);
			if recipeInfo then
				local isUnlearned = nil;
				if not recipeInfo.learned then
					isUnlearned = true;
				end
				toonDB.unlearnedRecipes[factionRecipeIDs[recipeId]] = isUnlearned;
			end
		end
		-- spell cooldowns
		--[[
		if rebuildCooldowns then
			--local cooldown, isDayCooldown, charges, maxCharges = C_TradeSkillUI.GetRecipeCooldown(recipeId);
			local _,_,cooldown = GetSpellCooldown(recipeId);
			--learnedRecipes[recipeId] = recipeInfo.learned
			if recipeId==143011 then
				ns:debug(name,recipeId,cooldown);
			end
			if cooldown then
				dataDB.recipeCooldowns[skillLineID][recipeId] = {isDayCooldown, charges, maxCharges};
				-- /dump C_TradeSkillUI.GetRecipeCooldown(GetMouseFocus().tradeSkillInfo.recipeID)
				-- 143011
			end
		end
		--]]
	end
end

---------------------------

local function updateBroker()
	local inTitle = {};

	for place=1, 4 do
		local profIndex = ns.profile[name].inTitle[place];
		if profIndex and professions[profIndex] and professions[profIndex].skillIcon and professions[profIndex].numSkill and professions[profIndex].maxSkill then
			local modifier,color = "","gray2";
			if professions[profIndex].numSkill~=professions[profIndex].maxSkill then
				color = "ffff"..string.format("%02x",255*(professions[profIndex].numSkill/professions[profIndex].maxSkill)).."00";
			end
			if professions[profIndex].skillModifier and professions[profIndex].skillModifier>0 then
				modifier = C("green","+"..professions[profIndex].skillModifier);
			end
			table.insert(inTitle, ("%s/%s|T%s:0|t"):format(C(color,professions[profIndex].numSkill)..modifier,C(color,professions[profIndex].maxSkill),professions[profIndex].skillIcon));
		end
	end

	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	obj.text = (#inTitle==0) and TRADE_SKILLS or table.concat(inTitle," ");
end

local function CreateTooltip2(self, content)
	local content,expansion,tsId,recipes,factions = unpack(content);
	tt2 = ns.acquireTooltip({ttName2, ttColumns2, "LEFT","RIGHT","CENTER"},{true,true},{self, "horizontal", tt});

	if content=="skill-list" then
		--
	elseif content=="faction-recipes" then
		tt2:AddLine(C("ltblue",L["Recipes from faction vendors"].." ("..skillNameById[tsId]..")"),C("ltblue",REPUTATION),C("ltblue",L["Buyable"]));
		tt2:AddSeparator();

		local factionID,factionName,currentStanding,standingID,_ = 0;
		for _, recipeData in ipairs(recipes) do
			local factionId, standing, itemId, spellId, recipeRank = unpack(recipeData);
			if skillNameById[tsId] then
				local Name = GetSpellInfo(spellId);
				if Name then
					-- faction header
					if factionID~=recipeData[1] then
						factionName,_,currentStanding = GetFactionInfoByID(factionId);
						tt2:AddLine(C("ltgray",factionName),C("ltgray",_G["FACTION_STANDING_LABEL"..currentStanding]));
						factionID = factionId;
					end
					-- recipe
					local color,faction,buyable = "red",_G["FACTION_STANDING_LABEL"..standing],NO;
					if toonDB.unlearnedRecipes[itemId] and IsSpellKnown(spellId) then
						toonDB.unlearnedRecipes[itemId]	= nil;
					end
					if toonDB.unlearnedRecipes[itemId]==nil then
						color,buyable = "ltgreen",ALREADY_LEARNED;
					elseif currentStanding>=standing then
						color,buyable = "green",YES;
					end
					local stars = "";
					if recipeRank then
						stars = " "..("|Tinterface\\common\\reputationstar:12:12:0:0:32:32:2:14:2:14|t"):rep(recipeRank);
					end
					tt2:AddLine("    "..C("ltyellow",Name)..stars,C(color,faction),C(color,buyable));
				end
			end
		end
	end

	ns.roundupTooltip(tt2, true);
end

local function AddFactionRecipeLines(tt,expansion,recipesByProfession)
	local faction,trade_skill,factionName,factionId,standingID,_ = 0,0;
	local factions,tskills = {},{};

	tt:AddLine(C("gray",_G["EXPANSION_NAME"..expansion]));
	for skillId, recipes in pairs(recipesByProfession) do
		if skillNameById[skillId] then
			local count = {0,0,0}; -- <learned>,<buyable>,<total>
			for _,recipe in ipairs(recipes) do
				if not factions[recipe[1]] then -- fill factions table
					factions[recipe[1]] = {};
					factions[recipe[1]].name,_,factions[recipe[1]].standing = GetFactionInfoByID(recipe[1]);
				end
				if toonDB.unlearnedRecipes[recipe[3]]==nil then
					count[1] = count[1]+1; -- learned
				end
				if recipe[2]==factions[recipe[1]].standing then
					count[2] = count[2]+1; -- buyable
				end
				count[3] = count[3]+1; -- total
			end
			local l=tt:AddLine("    "..C(count[1]==count[3] and "gray2" or "ltyellow",skillNameById[skillId]));
			tt:SetCell(l,2,("%d/%d"):format(count[1],count[3]));
			tt:SetLineScript(l,"OnEnter",CreateTooltip2,{"faction-recipes",expansion,skillId,recipes,factions});
		end
	end
end

local function expansionSkillLines_OnEnter(self,skillId)
	if not expansionSkillLines then
		expansionSkillLines = {}
		local list = C_TradeSkillUI.GetAllProfessionTradeSkillLines();
		for i=1, #list do
			local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(list[i]);
			if info.parentProfessionID then
				expansionSkillLines[info.parentProfessionID] = expansionSkillLines[info.parentProfessionID] or {};
				tinsert(expansionSkillLines[info.parentProfessionID],list[i]);
			end
		end
	end

	if not expansionSkillLines[skillId] then
		--ns:debugPrint(skillId);
		return
	end

	tt2 = ns.acquireTooltip({ttName2, ttColumns2, "LEFT","RIGHT","CENTER"},{true,true},{self, "horizontal", tt});

	if C_TradeSkillUI.GetProfessionInfoBySkillLineID then
		for i=1, #expansionSkillLines[skillId] do
			local skillInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(expansionSkillLines[skillId][i]);
			if skillInfo then
				local color,text = "ltgray",L["Learnable"];
				if skillInfo.skillLevel and skillInfo.maxSkillLevel and skillInfo.maxSkillLevel~=0 then
					local percentSkillLevel = skillInfo.skillLevel/skillInfo.maxSkillLevel;
					if percentSkillLevel==1 then
						color = "gray2","gray2";
					else
						color = "ffff"..string.format("%02x",255*percentSkillLevel).."00";
					end
					text = skillInfo.skillLevel..'/'..skillInfo.maxSkillLevel;
				end
				tt2:AddLine(C("ltyellow",skillInfo.expansionName),C(color,text));
			end
		end
	else
		for i=1, #expansionSkillLines[skillId] do
			local skillLineDisplayName, skillLineRank, skillLineMaxRank, skillLineModifier, parentSkillLineID = C_TradeSkillUI.GetTradeSkillLineInfoByID(expansionSkillLines[skillId][i]);
			if skillLineDisplayName then
				local color,text = "ltgray",L["Learnable"];
				if skillLineRank and skillLineMaxRank and skillLineMaxRank~=0 then
					local skillPercent = skillLineRank/skillLineMaxRank;
					if skillPercent==1 then -- on max skill
						color = "gray2","gray2";
					else
						color = "ffff"..string.format("%02x",255*skillPercent).."00";
					end
					text = skillLineRank..'/'..skillLineMaxRank;
				end
				tt2:AddLine(C("ltyellow",skillLineDisplayName),C(color,text));
			end
		end
	end
	ns.roundupTooltip(tt2, true);
end

local function expansionSkillLines_OnLeave(self)
	--
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	local iconnameLocale = "|T%s:12:12:0:0:64:64:2:62:4:62|t %s";

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",TRADE_SKILLS));

	tt:AddLine(C("ltblue",NAME),C("ltblue",SKILL),C("ltblue",ABILITIES));
	tt:AddSeparator();
	if #professions>0 then
		for i,v in ipairs(professions) do
			if v then
				local color1,color2,modifier,nameStr = "ltyellow","white","",v.skillNameFull or v.skillName or UNKNOWN;
				if v.maxSkill==0 then
					color1,color2 = "gray","gray";
				else
					local skillPercent = v.numSkill/v.maxSkill;
					if skillPercent==1 then -- on max skill
						color2 = "gray2","gray2";
					else
						color2 = "ffff"..string.format("%02x",255*skillPercent).."00";
					end
					if v.skillModifier and v.skillModifier>0 then
						modifier = C("green","+"..v.skillModifier);
					end
					if v.skillNameFull and v.skillName and v.skillNameFull~=v.skillName then
						nameStr = "";
						local str = {strsplit(";",(v.skillNameFull:gsub(v.skillName,";%1;")))};
						for i=1, #str do
							if str[i]==v.skillName then
								nameStr = nameStr..C(color1,v.skillName);
							elseif str[i]~="" then
								nameStr = nameStr..C("gray2",str[i]);
							end
						end
					else
						nameStr = C(color1,nameStr);
					end
				end
				local l = tt:AddLine((iconnameLocale):format(v.skillIcon or ns.icon_fallback,nameStr),C(color2,v.numSkill)..modifier..C(color2,"/"..v.maxSkill));
				tt:SetLineScript(l,"OnEnter",expansionSkillLines_OnEnter,v.skillId);
				--tt:SetLineScript(l,"OnLeave",expansionSkillLines_OnLeave);
			end
		end

		-- link to second tooltip
		local showLegion = ns.profile[name].showLegionFactionRecipes and ns.toon.level>=GetMaxLevelForExpansionLevel(5);
		local showBfA = ns.profile[name].showBfAFactionRecipes and ns.toon.level>=GetMaxLevelForExpansionLevel(6);
		local showShadow = ns.profile[name].showShadowFactionRecipes and ns.toon.level>=GetMaxLevelForExpansionLevel(7);
		if showLegion or showBfA then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Recipes from faction vendors by expansion"]));
			tt:AddSeparator();
			-- AddFactionRecipeLines(tt, <ExpansionIndex>, <List of recipes of the expansion>)
			if showLegion then
				AddFactionRecipeLines(tt,6,faction_recipes[6]);
			end
			if showBfA then
				AddFactionRecipeLines(tt,7,faction_recipes[7]);
			end
			if showShadow then
				AddFactionRecipeLines(tt,8,faction_recipes[8]);
			end
		end
	else
		tt:AddLine(C("gray",L["No professions learned..."]));
	end

	if (ns.profile[name].showCooldowns) then
		local lst,sep,cd1={},false,0;

		-- current toon cooldowns
		local _, durationHeader = ns.DurationOrExpireDate(0,false,"Duration","Expire date"); -- L["Duration"], L["Expire date"]
		if toonDB.hasCooldowns then
			for i,v in pairs(toonDB.cooldowns) do
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

		-- cooldowns of other toons
		for i,toonNameRealm,toonName,toonRealm,toonData,isCurrent in ns.pairsToons(name,{currentFirst=true,forceSameRealm=true}) do
			local hasHeader = false;
			if toonData.professions and toonData.professions.cooldowns and toonData.professions.hasCooldowns==true then
				local isOutdated = true;
				for spellid, spellData in pairs(toonData.professions.cooldowns) do
					if ( (spellData.timeLeft-(time()-spellData.lastUpdate)) > 0) then
						if (not hasHeader) then
							if (cd1>0) or (sep) then
								tinsert(lst,{type="sep",data={4,0,0,0,0}});
							end
							tinsert(lst,{type="line",data={C("ltblue",ns.scm(toonName))..ns.showRealmName(name,toonRealm),C("ltblue",L[durationHeader])}});
							tinsert(lst,{type="sep",data={nil}});
							hasHeader = true;
							sep=true;
						end
						tinsert(lst,{type="cdLine",data=spellData});
						isOutdated = false;
					end
				end
				if isOutdated then -- is outdated; reset cooldown data
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
					tt:AddLine(iconnameLocale:format(GetItemIcon(v.data.name) or v.data.icon or ns.icon_fallback,C("ltyellow",v.data.name)),"~ "..ns.DurationOrExpireDate(v.data.timeLeft,v.data.lastUpdate));
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


-- module functions and variables --
------------------------------------
module = {
	events = {
		"VARIABLES_LOADED",
		"PLAYER_LOGIN",
		"SKILL_LINES_CHANGED",

		-- for faction recipes
		"NEW_RECIPE_LEARNED",

		-- for sub skillLines
		--"CHAT_MSG_SKILL",
		--"TRADE_SKILL_LIST_UPDATE",

		-- for archaeology
		"ARTIFACT_UPDATE",

		--"CURRENCY_DISPLAY_UPDATE",
		--"BAG_UPDATE_DELAYED",

		"CHAT_MSG_SKILL",
		"CHAT_MSG_SYSTEM"
	},
	config_defaults = {
		enabled = true,
		showCooldowns = true,
		showDigSiteStatus = true,
		showLegionFactionRecipes = true,
		showBfAFactionRecipes = true,
		showShadowFactionRecipes = true,
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

ns.ClickOpts.addDefaults(module,{
	profmenu = "_LEFT",
	menu = "_RIGHT"
});

function module.ProfessionMenu(self,button,modName,actName)
	if (tt~=nil) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:AddEntry({ label = L["Open"], title = true });
	ns.EasyMenu:AddEntry({ separator = true });
	for i,v in pairs(professions) do
		if v and v.spellId and not v.disabled then
			ns.EasyMenu:AddEntry({
				label = v.skillName,
				icon = v.skillIcon,
				func = function() securecall("CastSpellByID",v.spellId); end,
				disabled = not (v.numSkill and v.numSkill>0)
			});
		end
	end
	ns.EasyMenu:ShowMenu(self);
end

local function OptionMenu_TitleSet(place,obj)
	local db = ns.profile[name].inTitle;
	db[place] = (db[place]~=obj) and obj or false;
	updateBroker();
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
	for I=1, 3 do
		local d,e,p = ns.profile[name].inTitle;
		if (d[I]) and (professions[d[I]]) then
			e=professions[d[I]];
			p=ns.EasyMenu:AddEntry({ label = (C("dkyellow","%s%d:").."  |T%s:20:20:0:0|t %s"):format(L["Place"], I, e.skillIcon, C("ltblue",e.skillName)), arrow = true, disabled=(numLearned==0) });
			ns.EasyMenu:AddEntry({
				label = (C("ltred","%s").." |T%s:20:20:0:0|t %s"):format(CALENDAR_VIEW_EVENT_REMOVE,e.skillIcon,C("ltblue",e.skillName)),
				func = function()
					OptionMenu_TitleSet(I,nil);
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
					label = v.skillName,
					icon = v.skillIcon,
					func = function() OptionMenu_TitleSet(I,i) end,
					disabled = (not v.skillName)
				},p);
			end
		end
	end
	ns.EasyMenu:AddConfig(name,true);
	ns.EasyMenu:ShowMenu(self);
end

function module.options()
	return {
		broker = nil,
		tooltip = {
			showLegionFactionRecipes={ type="toggle", order=1, name=L["EmissaryVendorRecipes"].." ("..EXPANSION_NAME6..")", desc=L["EmissaryVendorRecipesDesc"], width="full" },
			showBfAFactionRecipes={ type="toggle", order=2, name=L["EmissaryVendorRecipes"].." ("..EXPANSION_NAME7..")", desc=L["EmissaryVendorRecipesDesc"], width="full" },
			showShadowFactionRecipes={ type="toggle", order=3, name=L["EmissaryVendorRecipes"].." ("..EXPANSION_NAME8..")", desc=L["EmissaryVendorRecipesDesc"], width="full" },
			showCooldowns={ type="toggle", order=10, name=L["Show cooldowns"], desc=L["Show/Hide profession cooldowns from all characters."] },
			showAllFactions=11,
			showRealmNames=12,
			showCharsFrom=13,
		},
		misc = nil,
	}
end

function module.init()
	-- [<tradeSkillId>] = { {<factionId>, <standingId>, <itemId>, <spellId>[, <recipeStars>]}, ... }
	faction_recipes[6] = { -- legion
		-- Alchemy
		[171] = {{1859,7,142120,229218}},
		-- Blacksmithing
		[164] = {{1828,8,123948,182982},{1828,8,123953,182987},{1828,8,123955,182989},{1828,6,136697,209497},{1948,6,136698,209498},{1948,8,123951,182985},{1948,8,123954,182988}},
		-- Enchanting
		[333] = {{1859,8,128600,191013},{1859,8,128602,191015},{1859,8,128603,191016},{1859,8,128609,191022},{1883,8,128593,191006},{1883,6,128599,191012},{1883,8,128601,191014},{1883,8,128608,191021}},
		-- Engineering
		[202] = {{1894,6,137713,199007},{1894,6,137714,199008},{1894,8,137715,199009},{1894,8,137716,199010}},
		-- Inscription
		[773] = {{1894,7,137773,192897},{1894,7,137777,192901},{1894,7,137781,192905},{1894,7,142107,229183},{1900,7,137774,192898},{1900,7,137779,192903},{1900,7,137780,192904}},
		-- Jewelcrafting
		[755] = {{1828,6,137839,195924},{1828,8,137844,195929},{1828,8,137846,195931},{1828,8,137855,195940},{1859,8,137850,195935},{1894,8,137849,195934}},
		-- Leatherworking
		[165] = {{1828,7,142408,230954},{1828,8,142409,230955},{1883,6,137883,194718},{1883,8,137895,194730},{1883,8,137896,194731},{1883,8,137898,194733},{1948,6,137910,194753},{1948,6,137915,194758},{1948,8,137927,194770},{1948,8,137928,194771}},
		-- Tailoring
		[197] = {{1859,8,137973,185954},{1859,8,137976,185957},{1859,8,137979,185960},{1900,8,137977,185958},{1900,8,137978,185959},{1900,8,137980,185961},{1900,6,138015,208353}},
		-- Cooking
		[185] = {{1894,7,142331,230046}},
	};
	-- since BfA some recipes are available for alliance or horde only.
	if ns.player.faction=="Alliance" then
		faction_recipes[7] = { -- bfa
			-- Alchemy
			[171] = {{2159,7,162138,252378,3},{2159,7,162132,252350,3},{2159,7,163320,279170,3},{2159,7,162128,252336,3},{2159,7,162139,252381,3},{2162,7,162133,252353,3},{2162,7,162255,252384,3},{2162,7,163318,279167,3},{2162,7,162129,252340,3},{2161,7,162135,252359,3},{2161,7,163314,279161,3},{2161,7,162131,252346,3},{2161,7,162256,252390,3},{2160,7,162134,252356,3},{2160,7,163316,279164,3},{2160,7,162254,252387,3},{2160,7,162130,252343,3},{2163,7,162137,252370,3},{2163,7,162136,252363,3}},
			-- Blacksmithing
			[164] = {{2159,7,162275,253158,3},{2159,7,162670,278133,3},{2159,7,162261,253118,3},{2159,7,162276,253161,3}},
			-- Enchanting
			[333] = {{2159,7,162302,255098,3},{2159,7,162306,265112,3},{2162,7,162303,255099,3},{2162,7,162313,268909,3},{2162,7,162312,268915,3},{2161,7,162305,255101,3},{2161,7,162318,255143,3},{2161,7,162320,268879,3},{2160,7,162304,255100,3},{2160,7,162316,255112,3},{2160,7,162317,268903,3},{2163,7,162301,255097,3},{2163,7,162298,255094,3}},
			-- Engineering
			[202] = {{2159,6,162323,272057,2},{2159,7,162344,264967,3},{2159,7,162346,255459,3},{2159,7,162345,253152,3},{2159,7,162324,272058,3},{2162,6,162325,272060,2},{2162,7,162341,256084,3},{2162,7,162337,255409,3},{2162,7,162342,256156,3},{2162,7,162326,272061,3},{2161,6,162329,272066,2},{2161,7,162322,265102,3},{2161,7,162330,272067,3},{2160,6,162327,272063,2},{2160,7,162328,272064,3}},
			-- Inscription
			[773] = {{2162,6,162363,256282,2},{2161,6,162361,256279,2},{2160,6,162359,256276,2},{2163,6,162373,256298,2},{2163,6,162371,256295,2},{2163,7,162377,256246,3},{2163,7,162376,256237,3},{2163,7,162023,276059,0},{2163,7,162352,256249,3},{2163,7,162358,256234,3}},
			-- Jewelcrafting
			[755] = {{2159,7,162378,256515,3},{2162,7,162379,256517,3},{2162,7,162382,256257,3},{2162,7,162385,256260,3},{2161,7,162381,256521,3},{2160,7,162380,256519,3}},
			-- Leatherworking
			[165] = {{2161,7,162412,256789,3},{2160,7,162414,256784,3},{2160,7,162413,256781,3}},
			-- Tailoring
			[197] = {{2161,7,162427,257116,3},{2161,7,162421,257127,3},{2163,6,163026,257129,2}},
			-- Cooking
			[185] = {{2163,6,162288,259422,2},{2163,7,162292,259432,3},{2163,7,162293,259435,3},{2163,7,162287,259420,3},{2163,7,162289,259423,3},{2163,8,166806,290472,2},{2163,8,166263,287110,2},{2163,8,166367,288029,3},{2163,8,166368,288033,3}},
		};
	elseif ns.player.faction=="Horde" then
		faction_recipes[7] = { -- bfa
			-- Alchemy
			[171] = {{2157,7,162701,252378,3},{2157,7,162695,252350,3},{2157,7,163320,279170,3},{2157,7,162691,252336,3},{2157,7,162702,252381,3},{2103,7,162696,252353,3},{2103,7,162704,252384,3},{2103,7,163317,279167,3},{2103,7,162692,252340,3},{2158,7,162698,252359,3},{2158,7,163313,279161,3},{2158,7,162694,252346,3},{2158,7,162705,252390,3},{2156,7,162697,252356,3},{2156,7,163315,279164,3},{2156,7,162703,252387,3},{2156,7,162693,252343,3},{2163,7,162137,252370,3},{2163,7,162136,252363,3}},
			-- Blacksmithing
			[164] = {{2157,7,162707,253158,3},{2157,7,162774,278133,3},{2157,7,162706,253118,3},{2157,7,162708,253161,3}},
			-- Enchanting
			[333] = {{2157,7,162716,255098,3},{2157,7,162720,265112,3},{2103,7,162717,255099,3},{2103,7,162722,268909,3},{2103,7,162721,268915,3},{2158,7,162719,255101,3},{2158,7,162725,255143,3},{2158,7,162726,268879,3},{2156,7,162718,255100,3},{2156,7,162723,255112,3},{2156,7,162724,268903,3},{2163,7,162301,255097,3},{2163,7,162298,255094,3}},
			-- Engineering
			[202] = {{2157,6,162728,272057,2},{2157,7,162744,264967,3},{2157,7,162746,255459,3},{2157,7,162745,253152,3},{2157,7,162729,272058,3},{2103,6,162730,272060,2},{2103,7,162742,256084,3},{2103,7,162741,255409,3},{2103,7,162743,256156,3},{2103,7,162731,272061,3},{2158,6,162734,272066,2},{2158,7,162727,265102,3},{2158,7,162735,272067,3},{2156,6,162732,272063,2},{2156,7,162733,272064,3}},
			-- Inscription
			[773] = {{2103,6,162753,256285,2},{2158,6,162755,256291,2},{2156,6,162754,256288,2},{2163,6,162373,256298,2},{2163,6,162371,256295,2},{2163,7,162377,256246,3},{2163,7,162376,256237,3},{2163,7,162023,276059,0},{2163,7,162352,256249,3},{2163,7,162358,256234,3}},
			-- Jewelcrafting
			[755] = {{2157,7,162760,256515,3},{2103,7,162761,256517,3},{2103,7,162764,256257,3},{2103,7,162765,256260,3},{2158,7,162763,256521,3},{2156,7,162762,256519,3}},
			-- Leatherworking
			[165] = {{2158,7,162766,256789,3},{2156,7,162768,256784,3},{2156,7,162767,256781,3}},
			-- Tailoring
			[197] = {{2158,7,162772,257116,3},{2158,7,162769,257127,3},{2163,6,163026,257129,2}},
			-- Cooking
			[185] = {{2163,6,162288,259422,2},{2163,7,162292,259432,3},{2163,7,162293,259435,3},{2163,7,162287,259420,3},{2163,7,162289,259423,3},{2163,8,166806,290472,2},{2163,8,166263,287110,2},{2163,8,166367,288029,3},{2163,8,166368,288033,3}},
		};
	end
	faction_recipes[8] = { -- https://www.wowhead.com/items/recipes
			-- Alchemy
			[171] = {
				{2465, 5, 183106, 307087},
				{2439, 5, 182660, 307143},
			},
			-- Blacksmithing
			[164] = {
				{2407, 6, 183094, 322590},
				{2410, 6, 183095, 322593},
			},
			-- Enchanting
			[333] = {
				{2465, 6, 183096, 309644},
			},
			-- Engineering
			[202] = {
				--{2465, 6, 183069, 309644},
				{2407, 8, 183097, 331007},
				{2410, 6, 183858, 310535},
				--{,, 182666, 309636},
				--{,, 183866, 343682},
			},
			-- Inscription
			[773] = {
				{2407, 5, 183098, 311424},
				{2407, 7, 183103, 311409},
				{2465, 7, 183093, 311410},
				{2410, 7, 183104, 311411},
				{2413, 7, 183102, 311412},
			},
			-- Jewelcrafting
			[755] = {
				{2413, 6, 183099, 311870},
			},
			-- Leatherworking
			[165] = {
				{2465, 6, 183100, 324088},
				-- {2413, 7, 183839, 308897}, -- no source
			},
			-- Tailoring
			[197] = {
				{2410, 6, 183101, 310898},
			},
			-- Cooking
			[185] = {
				{ 2413, 7, 182668, 308403},
			},
	}

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
			-- legion
			-- bfa
		},
		[333] = { -- Enchanting
			-- cata
			{116499,0,2},
			-- wod
			{169092,0,2},{177043,0,2},{178241,0,2},
		},
		[755] = { -- Jewelcrafting
			{47280,0,2},{62242,0,2},{73478,0,2},{131593,2,2},{131695,2,2},{131690,2,2},{131686,2,2},{131691,2,2},{131688,2,2},{140050,0,2},
			-- wod
			{170700,0,2},{170832,0,2},{176087,0,2},
		},
		[197] = { -- Tailoring
			{75141,0,1},{75142,0,1},{75144,0,1},{75145,0,1},{75146,0,1},{125557,0,2},{143011,0,2},
			-- wod
			{168835,0,2},{169669,0,2},{176058,0,2},
		},
		[773] = { -- Inscription
			{61288,0,2},{61177,0,2},{89244,0,2},{86654,0,2},{112996,0,2},
			-- wod
			{169081,0,2},{177045,0,2},{178240,0,2},
		},
		[164] = { -- Blacksmithing
			{138646,0,2},{143255,0,2},
			-- wod
			{171690,0,2},{171718,0,2},{176090,0,2},
		},
		[165] = { -- Leatherworking
			{140040,3,2},{140041,3,2},{142976,0,2},
			-- wod
			{171391,0,2},{171713,0,2},{176089,0,2},
		},
		[202] = { -- Engineering
			{139176,0,2},
			-- wod
			{169080,0,2},{177054,0,2},{178242,0,2},
		}
	};

	--[[
	tradeSkillExpansionSpells = {
		[164] = { -- Blacksmithing
			264437, 264439, 264441, 264443, 264445, 264447, 264449, 265804, 309828,
		},
		[197] = { -- Tailoring
			264619, 264621, 264623, 264625, 264627, 264629, 264631, 265816, 310950,
		},
		[755] = { -- Jewelcrafting
			264534, 264537, 264539, 264542, 264544, 264546, 264548, 264811, 311967,
		},
		[773] = { -- Inscription
			264496, 264498, 264500, 264502, 264504, 264506, 264508, 265809, 309804,
		},
		[165] = { -- Leatherworking
			264579, 264581, 264583, 264585, 264588, 264590, 264592, 265813, 309038,
		},
		[202] = { -- Engineering
			264479, 264481, 264483, 264485, 164487, 264490, 264492, 265807, 310539,
		},
		[333] = { -- Enchanting
			264460, 264462, 264464, 264467, 264469, 264471, 264473, 265805, 309833,
		},
		[171] = { -- Alchemy
			264213, 264220, 264243, 264245, 264247, 264250, 264255, 265787, 309822,
		},
		[186] = { -- Mining
			265840, 265842, 265844, 265846, 265848, 265850, 265852, 267482, 325019,
		},
		[182] = { -- Herbalism
			265822, 265824, 265826, 265828, 265830, 265832, 265833, 265836, 300932,
		}
	}
	--]]

	-- skillLineDisplayName, skillLineRank, skillLineMaxRank, skillLineModifier, parentSkillLineID = C_TradeSkillUI.GetTradeSkillLineInfoByID(skillLineID)
end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
		return;
	elseif event=="VARIABLES_LOADED" then
		if ns.toon[name]==nil then
			ns.toon[name]={};
		end
		toonDB = ns.toon[name];
		if toonDB.unlearnedRecipes==nil then
			toonDB.unlearnedRecipes = {}
		end
		if toonDB.cooldowns==nil then
			toonDB.cooldowns = {};
		end
		if toonDB.cooldown_locks==nil then
			toonDB.cooldown_locks = {};
		end
		--[[
		if ns.data[name]==nil then
			ns.data[name]={};
		end
		dataDB = ns.data[name];
		if dataDB.recipeCooldownsBuild==nil or dataDB.recipeCooldownsBuild~=ns.client_version then
			dataDB.recipeCooldownsBuild = ns.client_version;
			dataDB.recipeCooldowns = {};
		end
		--]]
		self:RegisterEvent("ADDON_LOADED");
	elseif event=="ADDON_LOADED" and arg1=="Blizzard_TradeSkillUI" then
		self:UnregisterEvent("ADDON_LOADED");
		hooksecurefunc(TradeSkillFrame,"RefreshTitle",function()
			C_Timer.After(.2,function()
				local skillLineID, skillLineDisplayName, skillLineRank, skillLineMaxRank, skillLineModifier, parentSkillLineID, parentSkillLineDisplayName = C_TradeSkillUI.GetTradeSkillLine();
				if parentSkillLineID or skillLineID then
					updateCooldownAndRecipeLists(parentSkillLineID or skillLineID);
				end
			end);
		end);
	elseif event=="NEW_RECIPE_LEARNED" then
		local id = tonumber(arg1)
		if id  and toonDB.unlearnedRecipes[id] then
			toonDB.unlearnedRecipes[id] = nil;
		end
	elseif event=="PLAYER_LOGIN" or ns.eventPlayerEnteredWorld then
		if not toonDB then
			if ns.toon[name]==nil then
				ns.toon[name]={};
			end
			toonDB = ns.toon[name];
			if toonDB.unlearnedRecipes==nil then
				toonDB.unlearnedRecipes = {}
			end
			if toonDB.cooldowns==nil then
				toonDB.cooldowns = {};
			end
			if toonDB.cooldown_locks==nil then
				toonDB.cooldown_locks = {};
			end
		end
		updateTradeSkills();
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
