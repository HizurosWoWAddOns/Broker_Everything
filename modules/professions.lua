
-- module independent variables --
----------------------------------
local addon, ns = ...;
local C,L,I = ns.LC.color,ns.L,ns.I;

--#- missing event to update list of professions... [?]
--#- update cooldown list

-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Professions"; -- TRADE_SKILLS L["ModDesc-Professions"]
local ttName,ttName2,ttColumns,ttColumns2,tt,tt2,module = name.."TT",name.."TT2",2,3;
local professions,db,locked = {};
local Faction = UnitFactionGroup("player")=="Alliance" and 1 or 2;
local nameLocale, icon, skill, maxSkill, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset, fullNameLocale = 1,2,3,4,5,6,7,8,9,10,11; -- GetProfessionInfo
local nameEnglish,spellId,skillId,disabled = 11, 12, 13, 14; -- custom after GetProfessionInfo
local spellName,spellLocaleName,spellIcon,spellId = 1,2,3,4;
local legion_faction_recipes,bfa_faction_recipes,cdSpells = {},{},{};
local profs = {data={},id2Name={},test={}, generated=false};
local ts = {};
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
	for spellId, spellName in pairs({
		[1804] = "Lockpicking", [2018]  = "Blacksmithing", [2108]  = "Leatherworking", [2259]  = "Alchemy",     [2550]  = "Cooking",     [2575]   = "Mining",
		[2656] = "Smelting",    [2366]  = "Herbalism",     [3273]  = "First Aid",      [3908]  = "Tailoring",   [4036]  = "Engineering", [7411]   = "Enchanting",
		[8613] = "Skinning",    [25229] = "Jewelcrafting", [45357] = "Inscription",    [53428] = "Runeforging", [78670] = "Archaeology", [131474] = "Fishing",
	}) do
		local spellLocaleName,_,spellIcon = GetSpellInfo(spellId);
		if (spellLocaleName) then
			profs.data[spellId]   = {spellName,spellLocaleName,spellIcon,spellId};
			profs.id2Name[spellName] = spellId;
			L[spellName] = spellLocaleName; -- localization
			L[spellLocaleName] = spellName; -- localization backwards
			profs.test[spellName] = spellLocaleName; -- localization
			profs.test[spellLocaleName] = spellName; -- localization backwards
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
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
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

		-- link to second tooltip
		local showLegion = ns.profile[name].showLegionFactionRecipes and ns.toon.level>=110;
		local showBfA = ns.profile[name].showBfAFactionRecipes and ns.toon.level>=120;
		if showLegion or showBfA then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Recipes from faction vendors by expansion"]));
			tt:AddSeparator();
			-- AddFactionRecipeLines(tt, <ExpansionIndex>, <List of recipes of the expansion>)
			if showLegion then
				AddFactionRecipeLines(tt,6,legion_faction_recipes);
			end
			if showBfA then
				AddFactionRecipeLines(tt,7,bfa_faction_recipes);
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
		"ARTIFACT_UPDATE",
		"CURRENCY_DISPLAY_UPDATE",
		"SKILL_LINES_CHANGED",
		"BAG_UPDATE_DELAYED",
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
		if (v.spellId) and (not v[disabled]) then
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
	return {
		broker = nil,
		tooltip = {
			showLegionFactionRecipes={ type="toggle", order=1, name=L["EmissaryVendorRecipes"].." ("..EXPANSION_NAME6..")", desc=L["EmissaryVendorRecipesDesc"], width="full" },
			showBfAFactionRecipes={ type="toggle", order=2, name=L["EmissaryVendorRecipes"].." ("..EXPANSION_NAME7..")", desc=L["EmissaryVendorRecipesDesc"], width="full" },
			showCooldowns={ type="toggle", order=3, name=L["Show cooldowns"], desc=L["Show/Hide profession cooldowns from all characters."] },
			showAllFactions=4,
			showRealmNames=5,
			showCharsFrom=6,
		},
		misc = nil,
	}
end

function module.init()
	-- [<tradeSkillId>] = { {<factionId>, <standingId>, <itemId>, <spellId>[, <recipeStars>]}, ... }
	legion_faction_recipes = {
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
		bfa_faction_recipes = {
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
		bfa_faction_recipes = {
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
	elseif event=="ADDON_LOADED" and arg1=="Blizzard_TradeSkillUI" then
		hooksecurefunc(TradeSkillFrame,"RefreshTitle",updateTradeSkill);
		self:UnregisterEvent(event);
	elseif event=="NEW_RECIPE_LEARNED" and type(arg1)=="number" then
		ns.toon[name].learnedRecipes[arg1] = true;
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

		local t = {GetProfessions()};
		if (#t>0) then
			wipe(professions);
			local short, d, tsIds, add, _ = {},{},{},true,nil;

			for n=1, #t do
				add = true;
				d = {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil};

				if t[n] then
					d = {GetProfessionInfo(t[n])};
				end

				if (t[n]~=nil) then
					--d = {GetProfessionInfo(t[n])};
					d.skillId = t[n];
					d.spellId = profs.id2Name[L[d[nameLocale]]] or nil;
					d.nameEnglish = L[d[nameLocale]];

					if (n<=2) then
						short[n] = {d[skillLine],d[nameLocale],d[icon],d[skill],d[maxSkill],d.skillId,d.spellId};
					end
					if (n==4) then -- hide fishing in profession menu to prevent error message
						d[disabled]=true;
					end
					tsIds[d[7]] = true;
				elseif (n<=2) then
					d[nameLocale] = (n==1) and PROFESSIONS_FIRST_PROFESSION or PROFESSIONS_SECOND_PROFESSION;
					d[icon] = ns.icon_fallback;
					d.spellId = false;
				elseif (n>=3 and n<=5) then
					d.spellId = (n==3 and 78670) or (n==4 and 131474) or (n==5 and 2550);-- or (n==6 and 3273) first aid removed in bfa;
					d.nameEnglish,d[nameLocale],d[icon] = unpack(profs.data[d.spellId] or {});
				else
					add=false;
				end
				if (add) then
					professions[n] = d;
				end
			end

			if (ns.player.class=="DEATHKNIGHT") then
				d.spellId = 53428;
				if (IsSpellKnown(d.spellId)) then
					d[skill],d[maxSkill] = 1,1;
				end
				d.nameEnglish,d[nameLocale],d[icon] = unpack(profs.data[d.spellId] or {});
			elseif (ns.player.class=="ROGUE") then
				d.spellId = 1804;
				if (IsSpellKnown(d.spellId)) then
					d[skill] = UnitLevel("player") * 5;
					d[maxSkill] = d[skill];
				end
				d.nameEnglish,d[nameLocale],d[icon] = unpack(profs.data[d.spellId] or {});
				d[disabled] = true;
			end

			db.profession1 = short[1] or false;
			db.profession2 = short[2] or false;
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

			for i=1, #legion_faction_recipes do
				local v = legion_faction_recipes[i];
				if tsIds[legion_faction_recipes[i][1]] then
					ns.UseContainerItemHook.registerItemID(name,legion_faction_recipes[i][4],OnLearnRecipe,i);
				end
			end
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
