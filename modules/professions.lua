
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...;
local C,L,I = ns.LC.color,ns.L,ns.I;


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Professions";
L.professions = TRADE_SKILLS;
local ldbName,ttName,ttName2,tt,tt2 = name,name.."TT",name.."TT2";

local GetSpellInfo,GetSpellCooldown,GetProfessionInfo,unpack = GetSpellInfo,GetSpellCooldown,GetProfessionInfo,unpack;
local icon_placeholder = "interface\\icons\\INV_MISC_QUESTIONMARK";

local professions,db,createMenu = {};
local nameLocale, icon, skill, maxSkill, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset = 1,2,3,4,5,6,7,8,9,10; -- GetProfessionInfo
local nameEnglish,spellId,skillId,disabled = 11, 12, 13, 14; -- custom after GetProfessionInfo
local spellName,spellLocaleName,spellIcon,spellId = 1,2,3,4;

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
local cdSpells = {
	["Alchemy"] = {
		[11479]		= {group=1,	type=2}, -- Iron to Gold
		[11480]		= {group=1,	type=2}, -- Mithril to Truesilver
		[17559]		= {group=1,	type=2}, -- Air to Fire
		[17560]		= {group=1,	type=2}, -- Fire to Earth
		[17561]		= {group=1,	type=2}, -- Earth to Water
		[17562]		= {group=1,	type=2}, -- Water to Air
		[17563]		= {group=1,	type=2}, -- Undeath to Earth
		[17564]		= {group=1,	type=2}, -- Water to Undeath
		[17565]		= {group=1,	type=2}, -- Life to Earth
		[17566]		= {group=1,	type=2}, -- Earth to Life
		[28566]		= {group=1,	type=2}, -- Primal Air to Fire
		[28567]		= {group=1,	type=2}, -- Primal Earth to Water
		[28568]		= {group=1,	type=2}, -- Primal Fire to Earth
		[28569]		= {group=1,	type=2}, -- Primal Water to Air
		[28580]		= {group=1,	type=2}, -- Primal Shadow to Water
		[28581]		= {group=1,	type=2}, -- Primal Water to Shadow
		[28582]		= {group=1,	type=2}, -- Primal Mana to Fire
		[28583]		= {group=1,	type=2}, -- Primal Fire to Mana
		[28584]		= {group=1,	type=2}, -- Primal Life to Earth
		[28585]		= {group=1,	type=2}, -- Primal Earth to Life
		[52776]		= {group=1,	type=2}, -- Eternal Air to Water
		[52780]		= {group=1,	type=2}, -- Eternal Shadow to Life
		[53771]		= {group=1,	type=2}, -- Eternal Life to Shadow
		[53773]		= {group=1,	type=2}, -- Eternal Life to Fire
		[53774]		= {group=1,	type=2}, -- Eternal Fire to Water
		[53775]		= {group=1,	type=2}, -- Eternal Fire to Life
		[53777]		= {group=1,	type=2}, -- Eternal Air to Earth
		[53779]		= {group=1,	type=2}, -- Eternal Shadow to Earth
		[53781]		= {group=1,	type=2}, -- Eternal Earth to Air
		[53782]		= {group=1,	type=2}, -- Eternal Earth to Shadow
		[53783]		= {group=1,	type=2}, -- Eternal Water to Air
		[53784]		= {group=1,	type=2}, -- Eternal Water to Fire
		[54020]		= {group=1,	type=2}, -- Eternal Might
		[60893]		= {group=0,	type=1}, -- Alchemy Research // 3 days QuestResetTime?
		[66658]		= {group=1,	type=2}, -- Ametrine
		[66659]		= {group=1,	type=2}, -- Cardinal Ruby
		[66660]		= {group=1,	type=2}, -- King's Amber
		[66662]		= {group=1,	type=2}, -- Dreadstone
		[66663]		= {group=1,	type=2}, -- Majestic Zircon
		[66664]		= {group=1,	type=2}, -- Eye of Zul
		[78866]		= {group=1,	type=2}, -- Living Elements
		[80243]		= {group=0,	type=2}, -- Truegold
		[80244]		= {group=1,	type=2}, -- Pyrium Bar
		[114780]	= {group=1,	type=2}, -- Transmute: Living Steel
		[114783]	= {group=0,	type=2}, -- Transmute: Trillium Ingot
		[156587]	= {group=0,	type=2}, -- Alchemical Catalyst					[wod beta]
		[168042]	= {group=0,	type=2}, -- Alchemical Catalyst					[wod beta, maybe a replacement on max skill level]
		[175880]	= {group=0,	type=2}, -- Secrets of Draenor Alchemy			[wod beta, research]
	},
	["Enchanting"] = {
		[116499]	= {group=0,	type=2}, -- Sha Crystal
		[169092]	= {group=0,	type=2}, -- Temporal Crystal					[wod beta]
		[177043]	= {group=0,	type=2}, -- Secrets of Draenor Enchanting		[wod beta, Research]
		[178241]	= {group=0,	type=2}, -- Temporal Crystal					[wod beta, maybe a replacement on max skill level]
	},
	["Jewelcrafting"] = {
		[47280]		= {group=0,	type=2}, -- Brilliant Glass
		[62242]		= {group=0,	type=2}, -- Icy Prism
		[73478]		= {group=0,	type=4}, -- Fire Prism
		[131593]	= {group=2,	type=2}, -- River's Heart
		[131695]	= {group=2,	type=2}, -- Sun's Radiance
		[131690]	= {group=2,	type=2}, -- Vermilion Onyx
		[131686]	= {group=2,	type=2}, -- Primordial Ruby
		[131691]	= {group=2,	type=2}, -- Imperial Amethyst
		[131688]	= {group=2,	type=2}, -- Wild Jade
		[140050]	= {group=0,	type=2}, -- Serpent's Heart
		[170700]	= {group=0,	type=2}, -- Taladite Crytal						[wod beta]
		[170832]	= {group=0,	type=2}, -- Taladite Crytal						[wod beta, maybe a replacement on max skill level]
		[176087]	= {group=0, type=2}, -- Secrets of Draenor Jewelcrafting	[wod beta, research]
	},
	["Tailoring"] = {
		[75141]		= {group=0,	type=1}, -- Dream of Skywall
		[75142]		= {group=0,	type=1}, -- Dream of Deepholm
		[75144]		= {group=0,	type=1}, -- Dream of Hyjal
		[75145]		= {group=0,	type=1}, -- Dream of Ragnaros
		[75146]		= {group=0,	type=1}, -- Dream of Azshara	//	6days, 20min-40min?

		[125557]	= {group=0,	type=2}, -- Imperial Silk
		[143011]	= {group=0,	type=2}, -- Celestial Cloth
		[168835]	= {group=0,	type=2}, -- Hexweave Cloth						[wod beta]
		[169669]	= {group=0,	type=2}, -- Hexweave Cloth						[wod beta, maybe a replacement on max skill level]
		[176058]	= {group=0, type=2}, -- Secrets of Draenor Tailoring		[wod beta, research]
	},
	["Inscription"] = {
		[61288]		= {group=0,	type=2}, -- Minor Glyph Research
		[61177]		= {group=0,	type=2}, -- Major Glyph Research
		[89244]		= {group=0,	type=2}, -- Forged Documents - Alliance
		[86654]		= {group=0,	type=2}, -- Forged Documents - Horde
		[112996]	= {group=0,	type=2}, -- Scroll of Wisdom
		[169081]	= {group=0,	type=2}, -- War Paints							[wod beta]
		[177045]	= {group=0,	type=2}, -- Secrets of Draenor Inscription		[wod beta, research]
		[178240]	= {group=0,	type=2}, -- War Paints							[wod beta, maybe a replacement on max skill level]
	},
	["Blacksmithing"] = {
		[138646]	= {group=0,	type=2}, -- Lightning Steel Ingot
		[143255]	= {group=0,	type=2}, -- Balanced Trillium Ingot
		[171690]	= {group=0,	type=2}, -- Truesteel Ingot						[wod beta]
		[171718]	= {group=0,	type=2}, -- Truesteel Ingot						[wod beta, maybe a replacement on max skill level]
		[176090]	= {group=0,	type=2}, -- Secrets of Draenor Blacksmithing	[wod beta, research]
	},
	["Leatherworking"] = {
		[140040]	= {group=3,	type=2}, -- Magnificence of Leather
		[140041]	= {group=3,	type=2}, -- Magnificence of Scales
		[142976]	= {group=0,	type=2}, -- Hardened Magnificent Hide
		[171391]	= {group=0,	type=2}, -- Burnished Leather					[wod beta]
		[171713]	= {group=0,	type=2}, -- Burnished Leather					[wod beta, maybe a replacement on max skill level]
		[176089]	= {group=0,	type=2}, -- Secrets of Draenor Leatherworking	[wod beta, research]
	},
	["Engineering"] = {
		[139176]	= {group=0,	type=2}, -- Jard's Peculiar Energy Source
		[169080]	= {group=0,	type=2}, -- Gearspring Parts					[wod beta]
		[177054]	= {group=0,	type=2}, -- Secrets of Draenor Engineering		[wod beta, research]
		[178242]	= {group=0,	type=2}, -- Gearspring Parts					[wod beta, maybe a replacement on max skill level]
	}
};
--		[]	= {cd_group=0,	cd_type=0},


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="Interface\\Icons\\INV_Misc_Book_09.png",coords={0.05,0.95,0.05,0.95}}; --IconName::Professions--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Display a list of your professions"]
ns.modules[name] = {
	desc = desc,
	events = {
		"ADDON_LOADED",
		"PLAYER_ENTERING_WORLD",
		"TRADE_SKILL_UPDATE",

		-- archaeology
		"ARTIFACT_UPDATE",
		"ARTIFACT_HISTORY_READY",
		"ARTIFACT_COMPLETE",
		"ARTIFACT_DIG_SITE_UPDATED",
		"CURRENCY_DISPLAY_UPDATE",
		"SKILL_LINES_CHANGED",
		"BAG_UPDATE_DELAYED",
		"GET_ITEM_INFO_RECEIVED",


	},
	updateinterval = nil, -- 10
	config_defaults = {
		showCooldowns = true,
		showDigSiteStatus = true,
		inTitle = {}
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showCooldowns", label=L["Show cooldowns"], tooltip=L["Show/Hide profession cooldowns from all characters."] },
		-- { type="toggle", name="showDigSiteStatus", label=L["Show dig site status"], tooltip=L["Show dig site status in broker button."] },
	},
	clickOptions = {
		["1_open_character_info"] = {
			cfg_label = "Open profession menu",
			cfg_desc = "open the profession menu",
			cfg_default = "_LEFT",
			hint = "Open profession menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self,"professions")
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "_RIGHT",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self,"options")
			end
		}
	}

}


--------------------------
-- some local functions --
--------------------------

local function Title_Update()
	local inTitle,db,v = {},Broker_EverythingDB[name].inTitle;

	for i=1, 4 do
		v = db[i];
		if (v) and (professions[v]) and (professions[v][icon]) then
			table.insert(inTitle, ("%d/%d|T%s:0|t"):format(professions[v][skill],professions[v][maxSkill],professions[v][icon]));
		end
	end

	local obj = ns.LDB:GetDataObjectByName(ldbName);
	obj.text = (#inTitle==0) and L[name] or table.concat(inTitle," ");
end

local function Title_Set(place,obj)
	local db = Broker_EverythingDB[name].inTitle;
	db[place] = (db[place]~=obj) and obj or false;
	Title_Update();
end

local function Title_Check(id)
	--?
end

local function GetTimeLeft(a,b)
	return floor(a-(time()-b));
end

local profs = {data={},id2Name={},test={}, generated=false};
profs.build=function()
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

local function createTooltip(tt)
	local iconnameLocale = "|T%s:12:12:0:0:64:64:2:62:4:62|t %s";
	local function item_icon(name,icon) return select(10,GetItemInfo(name)) or icon or icon_placeholder; end

	tt:Clear();
	tt:AddHeader(C("dkyellow",L[name]));

	tt:AddLine(C("ltblue","Name"),C("ltblue","Skill"),C("ltblue","Abilities"));
	tt:AddSeparator();
	for i,v in ipairs(professions) do
		if (v[maxSkill]==v[skill]) then
			local c1,c2,s,m="ltyellow","ltgray",v[skill] or 0,v[maxSkill] or 0;
			if (m==0) then
				c1,c2,s,m = "gray","gray","-","-";
			end
			tt:AddLine((iconnameLocale):format(v[icon],C(c1,v[nameLocale])),C(c2,s.."/"..m));
		else
			tt:AddLine((iconnameLocale):format(v[icon] or icon_placeholder,C("ltyellow",v[nameLocale] or "?")),("%d/%d"):format(v[skill] or 0,v[maxSkill] or 0));
		end
	end

	if (Broker_EverythingDB[name].showCooldowns) then
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

		for i=1, #be_character_cache.order do
			local charName,charRealm = strsplit("-",be_character_cache.order[i]);
			local charData = be_character_cache[be_character_cache.order[i]];
			local char_header=false;
			if (not (charRealm==ns.realm and charName==ns.player.name)) and (charData.professions) and (charData.professions.cooldowns) and (charData.professions.hasCooldowns==true) then
				local outdated = true;
				for spellid, spellData in pairs(charData.professions.cooldowns) do
					if ( (spellData.timeLeft-(time()-spellData.lastUpdate)) > 0) then
						if (not char_header) then
							if (cd1>0) or (sep) then
								tinsert(lst,{type="sep",data={4,0,0,0,0}});
							end
							tinsert(lst,{type="line",data={C("ltblue",ns.scm(charName).." - "..ns.scm(charRealm)),C("ltblue",L[durationHeader])}});
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
		end -- / #lst>0
	end -- / .showCooldowns

	if (Broker_EverythingDB.showHints) then
		tt:AddSeparator(3,0,0,0,0)
		local l,c = tt:AddLine()
		local _,_,mod = ns.DurationOrExpireDate();
		tt:SetCell(l,1,C("copper",L["Hold "..mod]).." || "..C("green",L["Show expire date instead of duration"]),nil,nil,2);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
end

function createMenu(self,menu)
	if (tt~=nil) then ns.hideTooltip(tt,ttName,true); end

	ns.EasyMenu.InitializeMenu();

	if (menu=="professions") then
		ns.EasyMenu.addEntry({ label = L["Open"], title = true });
		ns.EasyMenu.addEntry({ separator = true });

		for i,v in ipairs(professions) do
			if (v[spellId]) and (not v[disabled]) then
				ns.EasyMenu.addEntry({
					label = v[nameLocale],
					icon = v[icon],
					func = function() securecall("CastSpellByName",v[nameLocale]); end,
					disabled = not ((v[skill]) and (v[skill]>0));
				});
			end
		end
	elseif (menu=="options") then
		ns.EasyMenu.addEntry({ label = L["In title"], title = true });
		ns.EasyMenu.addEntry({ separator = true });

		local numProfs,numLearned = (ns.player.class=="ROGUE") and 7 or 6,0;
		for i=1, numProfs do
			if (professions[i]) then
				numLearned = numLearned+1;
			end
		end

		for I=1, 3 do
			local d,e,p = Broker_EverythingDB[name].inTitle;
			if (d[I]) and (professions[d[I]]) then
				e=professions[d[I]];
				p=ns.EasyMenu.addEntry({ label = (C("dkyellow","%s%d:").."  |T%s:20:20:0:0|t %s"):format(L["Place"], I, e[icon], C("ltblue",e[nameLocale])), arrow = true, disabled=(numLearned==0) });
				ns.EasyMenu.addEntry({
					label = (C("ltred","%s").." |T%s:20:20:0:0|t %s"):format(L["Remove"],e[icon],C("ltblue",e[nameLocale])),
					func = function()
						Title_Set(I,nil);
					end
				},p);
				ns.EasyMenu.addEntry({ separator=true },p);
			else
				p=ns.EasyMenu.addEntry({ label = (C("dkyellow","%s%d:").."  %s"):format(L["Place"],I,L["Add a profession"]), arrow = true, disabled=(numLearned==0) });
			end
			for i=1, numProfs do
				local v = professions[i];
				if (v) then
					ns.EasyMenu.addEntry({
						label = v[nameLocale],
						icon = v[icon],
						func = function() Title_Set(I,i) end,
						disabled = (not v[nameLocale])
					},p);
				end
			end
		end

		ns.EasyMenu.addConfigElements(name,true);
	end

	ns.EasyMenu.ShowMenu(self);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	if(be_character_cache[ns.player.name_realm].professions==nil)then
		be_character_cache[ns.player.name_realm].professions = {cooldowns={},hasCooldowns=false};
	end
	db = be_character_cache[ns.player.name_realm].professions;
	if (db.cooldowns==nil) then
		db.cooldowns = {};
	end
	if (db.cooldown_locks==nil) then
		db.cooldown_locks = {};
	end
	profs.build();
end

ns.modules[name].onevent = function(self,event,arg1)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end

	local nameLocale, icon, skill, maxSkill, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset = 1,2,3,4,5,6,7,8,9,10; -- GetProfessionInfo
	local nameEnglish,spellId,skillId = 11, 12, 13; -- custom after GetProfessionInfo

	if (not profs.generated) then
		profs.build();
	end

	local t = {GetProfessions()};
	if (#t>0) then
		wipe(professions);
		local short, d, add, _ = {},{},true,nil;

		for n=1, 7 do
			add = true;
			d = {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil};

			if (t[n]~=nil) then
				d = {GetProfessionInfo(t[n])};
				d[skillId] = t[n];

				d[spellId] = profs.id2Name[L[d[nameLocale]]] or nil;
				d[nameEnglish] = L[d[nameLocale]];

				if (n<=2) then -- ?
					short[n] = {d[nameEnglish],d[nameLocale],d[icon],d[skill],d[maxSkill],d[skillId],d[spellId]};
				end
				if (n==4) then -- hide fishing in profession menu to prevent error message
					d[disabled]=true;
				end
			elseif (n<=2) then
				d[nameLocale] = (n==1) and PROFESSIONS_FIRST_PROFESSION or PROFESSIONS_SECOND_PROFESSION;
				d[icon] = icon_placeholder;
				d[spellId] = false;
			elseif (n>=3 and n<=6) then
				d[spellId] = (n==3 and 78670) or (n==4 and 131474) or (n==5 and 2550) or (n==6 and 3273);
				d[nameEnglish],d[nameLocale],d[icon] = unpack(profs.data[d[spellId]] or {});
			elseif (ns.player.class=="DEATHKNIGHT") then
				d[spellId] = 53428;
				if (IsSpellKnown(d[spellId])) then
					d[skill],d[maxSkill] = 1,1;
				end
				d[nameEnglish],d[nameLocale],d[icon] = unpack(profs.data[d[spellId]] or {});
			elseif (ns.player.class=="ROGUE") then
				d[spellId] = 1804;
				if (IsSpellKnown(d[spellId])) then
					d[skill] = UnitLevel("player") * 5;
					d[maxSkill] = d[skill];
				end
				d[nameEnglish],d[nameLocale],d[icon] = unpack(profs.data[d[spellId]] or {});
				d[disabled] = true;
			else
				add=false;
			end
			if (add) then
				professions[n] = d;
			end
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

		local check = function(_nameEng,_nameLoc,_icon,_skill,_maxSkill,_skillId,_spellId)
			local idOrGroup,timeLeft,lastUpdate,_name
			for id,cd in pairs(cdSpells[_nameEng]) do
				if (GetSpellCooldown(id)>0) then
					idOrGroup = (cd.group>0) and "cd.group."..cd.group or id;
					_name = (cd.group>0) and cd_groups[cd.group].." cooldown group" or select(1,GetSpellInfo(id));
					timeLeft,lastUpdate = cdResetTypes[cd.type](id);

					if (db.cooldowns[idOrGroup] and (timeLeft~=false) and floor(db.cooldowns[idOrGroup].timeLeft)~=floor(timeLeft)) or (not db.cooldowns[idOrGroup]) then
						db.cooldowns[idOrGroup] = {name=_name,icon=_icon,timeLeft=timeLeft,lastUpdate=lastUpdate};
						db.hasCooldowns = true;
					end
				end
			end
		end
		if (short[1]) and (short[1][1]) and (type(cdSpells[short[1][1]])=="table") then check(unpack(short[1])); end
		if (short[2]) and (short[2][1]) and (type(cdSpells[short[2][1]])=="table") then check(unpack(short[2])); end
	end
	Title_Update();
end
-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	tt = ns.LQT:Acquire(ttName, 2, "LEFT", "RIGHT");
	createTooltip(tt);
	ns.createTooltip(self,tt);
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true); end
end

--ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

