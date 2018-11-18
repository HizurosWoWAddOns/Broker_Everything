
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name1 = "Raids" -- RAIDS L["ModDesc-Raids"]
local name2 = "Dungeons" -- DUNGEONS L["ModDesc-Dungeons"]
local ttName1, ttName2, ttColumns, tt1, tt2, createTooltip, module1, module2 = name1.."TT", name2.."TT", 5
local fState,symbol,renameIt = C("ltgray"," (%d/%d)"),"|Tinterface\\buttons\\UI-%sButton-Up:0|t ",{};
local instanceName, instanceID, instanceReset, instanceDifficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress=1,2,3,4,5,6,7,8,9,10,11,12; -- GetSavedInstanceInfo
local activeRaids,PL_collected,PEW_collected,activeEncounter = {},true,true;
local BossKillQueryUpdate,UpdateInstaceInfoLock = false,{};
local hide = {
	[322] = true, -- pandaria world bosses // no raid
	[557] = true, -- draenor world bosses // no raid
	[822] = true, -- legion world bosses // no raid
	[959] = true, -- legion invasionpoints (argus) // no raid
	[1028] = true, -- bfa world bosses // no raid
}
-- some entries have not exact matching names between encounter journal and raidinfo frame
local rename_il,rename_ej,ignore_ej = {},{},{};
local diffModeShort = {
	[RAID_DIFFICULTY_10PLAYER] = "10n",
	[RAID_DIFFICULTY_20PLAYER] = "20n",
	[RAID_DIFFICULTY_25PLAYER] = "25n",
	[RAID_DIFFICULTY_40PLAYER] = "40n",
	[RAID_DIFFICULTY3] = "10hc",
	[RAID_DIFFICULTY4] = "25hc",
};


-- register icon names and default files --
-------------------------------------------
I[name1] = {iconfile="interface\\minimap\\raid", coords={0.25,0.75,0.25,0.75}};
I[name2] = {iconfile="interface\\minimap\\dungeon", coords={0.25,0.75,0.25,0.75}};


-- some local functions --
--------------------------
local function RequestRaidInfoUpdate()
	if BossKillQueryUpdate then
		RequestRaidInfo();
	end
end

local function updateInstances(name,mode)
	if EncounterJournal and EncounterJournal:IsShown() then return end -- prevent use of EJ_SelectTier while EncounterJournal is shown
	local currentTime,num = time(),GetNumSavedInstances();
	for i=1, num do
		local data = {GetSavedInstanceInfo(i)};
		if data[isRaid]==mode and data[instanceReset]>0 then
			local name = data[instanceName];
			if rename_il[name] then
				name = rename_il[name];
			end
			if activeRaids[name]==nil then
				activeRaids[name] = {new=true};
			end
			activeRaids[name][data[difficultyName]] = {data[instanceReset],currentTime,data[encounterProgress],data[numEncounters]};
		end
	end
	for i=1, (NUM_LE_EXPANSION_LEVELS+1) do
		EJ_SelectTier(i);
		local index, instance_id, instance_name, _ = 1;
		instance_id, instance_name = EJ_GetInstanceByIndex(index, mode);
		while instance_id~=nil do
			if rename_ej[instance_name] then
				instance_name = rename_ej[instance_name];
			end
			if activeRaids[instance_name] then
				if ns.toon[name]==nil then
					ns.toon[name]={};
				end
				ns.toon[name][instance_id] = activeRaids[instance_name];
			end
			index = index + 1;
			instance_id, instance_name = EJ_GetInstanceByIndex(index, mode);
		end
	end
	UpdateInstaceInfoLock[name] = nil;
end

local function createTooltip2(self,instance)
	local id,name,label = unpack(instance);
	local t = time();

	GameTooltip:SetOwner(self,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(self,"horizontal",tt1 or tt2));
	GameTooltip:SetFrameLevel(self:GetFrameLevel()+1);

	GameTooltip:ClearLines();

	GameTooltip:AddLine(label);
	GameTooltip:AddLine(C("gray",ns.realm));
	GameTooltip:AddLine(" ");

	for i=1, #Broker_Everything_CharacterDB.order do
		local v = Broker_Everything_CharacterDB[ Broker_Everything_CharacterDB.order[i] ];
		local c,r = strsplit("-",Broker_Everything_CharacterDB.order[i],2); -- char, realm
		local factionSymbol = "";
		if v.faction and v.faction~="Neutral" then
			factionSymbol = " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t";
		end

		if r==ns.realm then
			local diffState = {};
			if v[name] and v[name][id] then
				if v[name][id].new then
					for diffName, data in ns.pairsByKeys(v[name][id]) do
						if type(data)=="table" and (data[1]+data[2])>t then
							local diff,state = C("ltgray",diffName)..", ",C("orange",L["In progress"]);
							if data[3]==data[4] then
								state = C("green",L["Cleared"]);
							else
								state = state..fState:format(data[3],data[4]);
							end
							tinsert(diffState,diff..state);
						end
					end
				elseif (v[name][id][1]+v[name][id][2])>t and v[name][id][5] and v[name][id][5]~="" then
					local diff,state = C("ltgray",v[name][id][5])..", ", C("orange",L["In progress"]);
					if v[name][id][3]==v[name][id][4] then
						state = C("green",L["Cleared"]);
					else
						state = state..fState:format(v[name][id][3],v[name][id][4]);
					end
					tinsert(diffState,diff..state);
				end
			end
			GameTooltip:AddDoubleLine(C(v.class,c)..factionSymbol,#diffState==0 and C("gray",L["Free"]) or table.concat(diffState,"\n"));
		end
	end

	GameTooltip:Show();
end

local function hideTooltip2()
	GameTooltip:Hide();
end

local function toggleExpansion(self,data)
	ns.profile[data.name]['showExpansion'..data.expansion] = not ns.profile[data.name]['showExpansion'..data.expansion];
	createTooltip(data.name==name1 and tt1 or tt2,data.name,data.mode); -- force update tooltip?
end

function createTooltip(tt,name,mode)
	local ttName = name==name1 and ttName1 or ttName2;
	if not (tt and tt.key and tt.key==ttName) then return end

	if tt.lines~=nil then tt:Clear(); end

	tt:AddHeader(C("dkyellow",name==name1 and RAIDS or DUNGEONS));

	updateInstances(name,mode);

	-- create instance list
	local exp_start, exp_stop, exp_direction = 1, (NUM_LE_EXPANSION_LEVELS+1), 1;
	if ns.profile[name].invertExpansionOrder then
		exp_start, exp_stop, exp_direction = (NUM_LE_EXPANSION_LEVELS+1), 1, -1;
	end
	for i=exp_start, exp_stop, exp_direction do
		local hColor,sState,_status_,_mode_ = "gray","Plus","","";
		if ns.profile[name]['showExpansion'..i]==nil then
			ns.profile[name]['showExpansion'..i] = true;
		end
		if ns.profile[name]['showExpansion'..i] then
			hColor,sState,_status_,_mode_ = "ltblue","Minus",C("ltblue",STATUS),C("ltblue",MODE);
		end
		tt:AddSeparator(4,0,0,0,0);
		local l=tt:AddLine(symbol:format(sState)..C(hColor,_G['EXPANSION_NAME'..(i-1)]),_status_,_mode_);
		tt:SetLineScript(l,"OnMouseUp",toggleExpansion, {name=name,mode=mode,expansion=i});

		if ns.profile[name]['showExpansion'..i] then
			tt:AddSeparator();
			EJ_SelectTier(i);
			local index, instance_id, instance_name, _ = 1;
			instance_id, instance_name = EJ_GetInstanceByIndex(index, mode);
			while instance_id~=nil do
				if not hide[instance_id] then
					local status,diff,encounter,id = {},{},"","";
					if ignore_ej[instance_name] then
						status = false;
					elseif rename_ej[instance_name] then
						instance_name = rename_ej[instance_name];
					end
					if status then
						if activeRaids[instance_name] then
							for diffName, data in ns.pairsByKeys(activeRaids[instance_name])do
								if type(data)=="table" then
									local s,d = C("orange",L["In progress"]),C("ltgray",diffName);
									if data[3]==data[4] then
										s = C("green",L["Cleared"]);
									else
										s = s .. fState:format(data[3],data[4]);
									end
									tinsert(status,s);
									tinsert(diff,d);
								end
							end
						end
						if ns.profile[name].showID then
							id = C("gray"," ("..instance_id..")");
						end
						local l=tt:AddLine(
							C("ltyellow","    "..instance_name)..id,
							#status==0 and C("gray",L["Free"]) or table.concat(status,"\n"),
							#diff==0 and "" or table.concat(diff,"\n")
						);

						tt:SetLineScript(l,"OnEnter",createTooltip2,{instance_id,name,instance_name});
						tt:SetLineScript(l,"OnLeave",hideTooltip2);

						if ns.toon[name]==nil then
							ns.toon[name]={};
						end
						ns.toon[name][instance_id] = activeRaids[instance_name];
					end
				end
				index = index + 1;
				instance_id, instance_name = EJ_GetInstanceByIndex(index, mode);
			end
		end
	end

	--if ns.profile.GeneralOptions.showHints then
	--	tt:AddSeparator(4,0,0,0,0)
	--	ns.ClickOpts.ttAddHints(tt,name);
	--end
	ns.roundupTooltip(tt);
end

local function OnEvent(self,event,...)
	if event=="PLAYER_LOGIN" then
		for _,v in ipairs(renameIt)do
			local B,A = (EJ_GetInstanceInfo(v[3]));
			if v[2]>0 then
				local res = ns.ScanTT.query({type="link",link="instancelock:0:"..v[2]},true);
				if res and res.lines and res.lines[1] then
					local name = {strsplit('"',res.lines[1])};
					if name[2] then
						A = name[2];
					end
				end
			end
			if A and B and A~=B then
				if v[1]=="IL" then
					rename_il[A] = B;
				elseif v[1]=="EJ" then
					rename_ej[B] = A;
				elseif v[1]=="XX" then
					ignore_ej[B] = true;
				end
			end
		end
		wipe(renameIt);

		RequestRaidInfo(); -- trigger UPDATE_INSTANCE_INFO
	elseif event=="BOSS_KILL" then
		local encounterID, name = ...;
		BossKillQueryUpdate=true;
		C_Timer.After(0.14,RequestRaidInfoUpdate);
	elseif event=="UPDATE_INSTANCE_INFO" then
		local mode,name = false,name2;
		if self==module1.eventFrame then
			mode,name = true,name1;
		end
		BossKillQueryUpdate=false;
		if not UpdateInstaceInfoLock[name] then
			UpdateInstaceInfoLock[name] = true;
			C_Timer.After(0.3, function()
				updateInstances(name,mode);
			end);
		end
	end
end


-- module functions and variables --
------------------------------------
module1 = {
	events = {
		"PLAYER_LOGIN",
		"UPDATE_INSTANCE_INFO",
		"BOSS_KILL"
	},
	config_defaults = {
		enabled = false,
		invertExpansionOrder = true,
		showID = false
	}
}

module2 = {
	events = {
		"PLAYER_LOGIN",
		"UPDATE_INSTANCE_INFO",
		"BOSS_KILL"
	},
	config_defaults = {
		enabled = false,
		invertExpansionOrder = true,
		showID = false
	}
}

function module1.options()
	return {
		broker = nil,
		tooltip = {
			invertExpansionOrder={ type="toggle", name=L["Invert expansion order"], desc=L["Invert order by exspansion in tooltip"] }
		},
		misc = nil,
	}
end

function module2.options()
	return {
		broker = nil,
		tooltip = {
			invertExpansionOrder={ type="toggle", name=L["Invert expansion order"], desc=L["Invert order by exspansion in tooltip"] }
		},
		misc = nil,
	}
end

function module1.init()
	-- {<target>,<raidinfo>,<encounterjournalid>}
	-- IL = InstanceLock, EJ = EncounterJournal, XX = No ID, list without Free/InProgress/Cleared-info
	table.insert(renameIt,{"IL",  409, 741}); -- molten core
	table.insert(renameIt,{"IL",  531, 744}); -- temple of ahn'qiraj
	table.insert(renameIt,{"IL",  548, 748}); -- serpentshrine cavern
	table.insert(renameIt,{"IL",  550, 749}); -- tempest keep
	table.insert(renameIt,{"IL",  564, 751}); -- black temple
	table.insert(renameIt,{"IL",  580, 752}); -- sunwell
	table.insert(renameIt,{"IL",  615, 755}); -- obsidian sanctum
	table.insert(renameIt,{"IL",  724, 761}); -- rubin sanctum
	table.insert(renameIt,{"IL",  631, 758}); -- Icecrown Citadel
	table.insert(renameIt,{"EJ",  996, 320}); -- Terrace of Endless Spring
	table.insert(renameIt,{"IL", 1136, 369}); -- siege of orgrimmar
	table.insert(renameIt,{"EJ", 1205, 457}); -- Blackrock Foundry
	table.insert(renameIt,{"EJ", 1530, 786}); -- The Nighthold
	table.insert(renameIt,{"IL", 1228, 477}); -- Highmaul
end

function module2.init()
	table.insert(renameIt,{"IL", 1688,  63}); -- Deadmines
	table.insert(renameIt,{"IL",  938, 184}); -- End Time
	table.insert(renameIt,{"IL",  939, 185}); -- Well of Eternity
	table.insert(renameIt,{"IL",  940, 186}); -- Hour of Twilight
	table.insert(renameIt,{"IL",  429, 230}); -- Dire Maul
	table.insert(renameIt,{"XX",    0, 237}); -- The Temple of Atal'hakkar
	table.insert(renameIt,{"XX",    0, 238}); -- The Stockade (or maybe Stormwind Stockade)
	table.insert(renameIt,{"IL",  558, 247}); -- Auchenai Crypts
	--table.insert(renameIt,{"IL",   , 248}); --
	table.insert(renameIt,{"IL",  585, 249}); -- Magisters' Terrace
	table.insert(renameIt,{"IL",  557, 250}); -- Mana-Tombs
	--table.insert(renameIt,{"IL",   , 251}); --
	table.insert(renameIt,{"IL",  556, 252}); -- Sethekk Halls
	table.insert(renameIt,{"IL",  555, 253}); -- Shadow Labyrinth
	table.insert(renameIt,{"IL",  552, 254}); -- The Arcatraz
	--table.insert(renameIt,{"IL",   , 255}); -- The Black Morass
	table.insert(renameIt,{"IL",  542, 256}); -- The Blood Furnace
	table.insert(renameIt,{"IL",  553, 257}); -- The Botanica
	table.insert(renameIt,{"IL",  554, 258}); -- The Mechanar
	table.insert(renameIt,{"IL",  540, 259}); -- The Shattered Halls
	table.insert(renameIt,{"IL",  547, 260}); -- The Slave Pens
	table.insert(renameIt,{"IL",  545, 261}); -- The Steamvault
	table.insert(renameIt,{"IL",  546, 262}); -- The Underbog
	table.insert(renameIt,{"IL",  619, 271}); -- Ahn'kahet: The Old Kingdom
	table.insert(renameIt,{"IL",  600, 273}); -- Drak'Tharon Keep
	table.insert(renameIt,{"IL",  595, 279}); -- The Culling of Stratholme
	table.insert(renameIt,{"IL",  632, 280}); -- The Forge of Souls
	table.insert(renameIt,{"IL",  576, 281}); -- The Nexus
	table.insert(renameIt,{"IL",  578, 282}); -- The Oculus
	--table.insert(renameIt,{"IL",   , 283}); --
	table.insert(renameIt,{"IL",  961, 302}); -- Stormstout Brewery
	table.insert(renameIt,{"IL",  962, 303}); -- Gate of the Setting Sun
	table.insert(renameIt,{"IL", 1001, 311}); -- Scarlet Halls
	table.insert(renameIt,{"IL", 1004, 316}); -- Scarlet Monastery
	table.insert(renameIt,{"IL", 1195, 558}); -- Iron Docks
	table.insert(renameIt,{"IL", 1492, 727}); -- Maw of Souls
	table.insert(renameIt,{"IL", 1544, 777}); -- Assault on Violet Hold
end

module1.onevent = OnEvent;
module2.onevent = OnEvent;

-- function module1.optionspanel(panel) end
-- function module1.onmousewheel(self,direction) end
-- function module1.ontooltip(tooltip) end

function module1.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt1 = ns.acquireTooltip({ttName1, ttColumns, "LEFT", "LEFT", "LEFT", "LEFT", "LEFT"},{false},{self});
	createTooltip(tt1,name1,true); -- raids
end

function module2.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt2 = ns.acquireTooltip({ttName2, ttColumns, "LEFT", "LEFT", "LEFT", "LEFT", "LEFT"},{false},{self});
	createTooltip(tt2,name2,false); -- dungeons
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name1] = module1;
ns.modules[name2] = module2;


--[[
	-- dungeons
	{"IL",  938, 184, all=0},  -- End Time
	{"IL",  939, 185, all=0},  -- Well of Eternity
	{"IL",  940, 186, all=0},  -- Hour of Twilight
	{"IL",  389, 226, all=0},  -- Ragefire Chasm
	{"IL",   48, 227, all=0},  -- Blackfathom Deeps
	{"IL",  230, 228, all=0},  -- Blackrock Depths
	{"IL",  229, 229, all=0},  -- Lower Blackrock Spire
	{"IL",  429, 230, all=0},  -- Dire Maul
	{"IL",   90, 231, all=0},  -- Gnomeregan
	{"IL",  349, 232, all=0},  -- Maraudon
	{"IL",  129, 233, all=0},  -- Razorfen Downs
	{"IL",   47, 234, all=0},  -- Razorfen Kraul
	{"IL",  329, 236, all=0},  -- Stratholme
	{"IL",   70, 239, all=0},  -- Uldaman
	{"IL",   43, 240, all=0},  -- Wailing Caverns
	{"IL",  209, 241, all=0},  -- Zul'Farrak
	{"IL", 1008, 246, all=0},  -- Scholomance
	{"IL",  558, 247, all=0},  -- Auchenai Crypts
	{"IL",  585, 249, all=0},  -- Magisters' Terrace
	{"IL",  557, 250, all=0},  -- Mana-Tombs
	{"IL",  556, 252, all=0},  -- Sethekk Halls
	{"IL",  555, 253, all=0},  -- Shadow Labyrinth
	{"IL",  552, 254, all=0},  -- The Arcatraz
	{"IL",  542, 256, all=0},  -- The Blood Furnace
	{"IL",  553, 257, all=0},  -- The Botanica
	{"IL",  554, 258, all=0},  -- The Mechanar
	{"IL",  540, 259, all=0},  -- The Shattered Halls
	{"IL",  547, 260, all=0},  -- The Slave Pens
	{"IL",  545, 261, all=0},  -- The Steamvault
	{"IL",  546, 262, all=0},  -- The Underbog
	{"IL",  619, 271, all=0},  -- Ahn'kahet: The Old Kingdom
	{"IL",  601, 272, all=0},  -- Azjol-Nerub
	{"IL",  600, 273, all=0},  -- Drak'Tharon Keep
	{"IL",  604, 274, all=0},  -- Gundrak
	{"IL",  602, 275, all=0},  -- Halls of Lightning
	{"IL",  668, 276, all=0},  -- Halls of Reflection
	{"IL",  599, 277, all=0},  -- Halls of Stone
	{"IL",  658, 278, all=0},  -- Pit of Saron
	{"IL",  595, 279, all=0},  -- The Culling of Stratholme
	{"IL",  632, 280, all=0},  -- The Forge of Souls
	{"IL",  576, 281, all=0},  -- The Nexus
	{"IL",  578, 282, all=0},  -- The Oculus
	{"IL",  650, 284, all=0},  -- Trial of the Champion
	{"IL",  574, 285, all=0},  -- Utgarde Keep
	{"IL",  575, 286, all=0},  -- Utgarde Pinnacle
	{"IL",  961, 302, all=0},  -- Stormstout Brewery
	{"IL",  962, 303, all=0},  -- Gate of the Setting Sun
	{"IL", 1001, 311, all=0},  -- Scarlet Halls
	{"IL",  959, 312, all=0},  -- Shado-Pan Monastery
	{"IL",  960, 313, all=0},  -- Temple of the Jade Serpent
	{"IL", 1004, 316, all=0},  -- Scarlet Monastery
	{"IL",  994, 321, all=0},  -- Mogu'shan Palace
	{"IL", 1011, 324, all=0},  -- Siege of Niuzao Temple
	{"IL", 1175, 385, all=0},  -- Bloodmaul Slag Mines
	{"IL", 1209, 476, all=0},  -- Skyreach
	{"IL", 1208, 536, all=0},  -- Grimrail Depot
	{"IL", 1176, 537, all=0},  -- Shadowmoon Burial Grounds
	{"IL", 1182, 547, all=0},  -- Auchindoun
	{"IL", 1279, 556, all=0},  -- The Everbloom
	{"IL", 1195, 558, all=0},  -- Iron Docks
	{"IL", 1358, 559, all=0},  -- Upper Blackrock Spire
	{"IL", 1688,  63, all=0},  -- Deadmines
	{"IL",   33,  64, all=0},  -- Shadowfang Keep
	{"IL",  643,  65, all=0},  -- Throne of the Tides
	{"IL",  645,  66, all=0},  -- Blackrock Caverns
	{"IL",  725,  67, all=0},  -- The Stonecore
	{"IL",  657,  68, all=0},  -- The Vortex Pinnacle
	{"IL",  755,  69, all=0},  -- Lost City of the Tol'vir
	{"IL", 1493, 707, all=0},  -- Vault of the Wardens
	{"IL",  644,  70, all=0},  -- Halls of Origination
	{"IL", 1456, 716, all=0},  -- Eye of Azshara
	{"IL",  670,  71, all=0},  -- Grim Batol
	{"IL", 1477, 721, all=0},  -- Halls of Valor
	{"IL", 1516, 726, all=0},  -- The Arcway
	{"IL", 1492, 727, all=0},  -- Maw of Souls
	{"IL", 1501, 740, all=0},  -- Black Rook Hold
	{"IL", 1466, 762, all=0},  -- Darkheart Thicket
	{"IL", 1458, 767, all=0},  -- Neltharion's Lair
	{"IL",  859,  76, all=0},  -- Zul'Gurub
	{"IL", 1544, 777, all=0},  -- Assault on Violet Hold
	{"IL",  568,  77, all=0},  -- Zul'Aman
	{"IL", 1571, 800, all=0},  -- Court of Stars
	{"IL", 1651, 860, all=0},  -- Return to Karazhan
	{"IL", 1677, 900, all=0},  -- Cathedral of Eternal Night

	-- raids
	{"IL",  967, 187, all=0},  -- Dragon Soul
	{"IL", 1008, 317, all=0},  -- Mogu'shan Vaults
	{"IL",  996, 320, all=0},  -- Terrace of Endless Spring
	{"IL",  870, 322, all=0},  -- Pandaria
	{"IL", 1009, 330, all=0},  -- Heart of Fear
	{"IL", 1098, 362, all=0},  -- Throne of Thunder
	{"IL", 1136, 369, all=0},  -- Siege of Orgrimmar
	{"IL", 1205, 457, all=0},  -- Blackrock Foundry
	{"IL", 1228, 477, all=0},  -- Highmaul
	{"IL", 1116, 557, all=0},  -- Draenor
	{"IL", 1448, 669, all=0},  -- Hellfire Citadel
	{"IL",  671,  72, all=0},  -- The Bastion of Twilight
	{"IL",  669,  73, all=0},  -- Blackwing Descent
	{"IL",  409, 741, all=0},  -- Molten Core
	{"IL",  469, 742, all=0},  -- Blackwing Lair
	{"IL",  509, 743, all=0},  -- Ruins of Ahn'Qiraj
	{"IL",  531, 744, all=0},  -- Temple of Ahn'Qiraj
	{"IL",  532, 745, all=0},  -- Karazhan
	{"IL",  565, 746, all=0},  -- Gruul's Lair
	{"IL",  544, 747, all=0},  -- Magtheridon's Lair
	{"IL",  548, 748, all=0},  -- Serpentshrine Cavern
	{"IL",  550, 749, all=0},  -- The Eye
	{"IL",  754,  74, all=0},  -- Throne of the Four Winds
	{"IL",  534, 750, all=0},  -- The Battle for Mount Hyjal
	{"IL",  564, 751, all=0},  -- Black Temple
	{"IL",  580, 752, all=0},  -- Sunwell Plateau
	{"IL",  624, 753, all=0},  -- Vault of Archavon
	{"IL",  533, 754, all=0},  -- Naxxramas
	{"IL",  615, 755, all=0},  -- The Obsidian Sanctum
	{"IL",  616, 756, all=0},  -- The Eye of Eternity
	{"IL",  649, 757, all=0},  -- Trial of the Crusader
	{"IL",  631, 758, all=0},  -- Icecrown Citadel
	{"IL",  603, 759, all=0},  -- Ulduar
	{"IL",  757,  75, all=0},  -- Baradin Hold
	{"IL",  249, 760, all=0},  -- Onyxia's Lair
	{"IL",  724, 761, all=0},  -- The Ruby Sanctum
	{"IL", 1520, 768, all=0},  -- The Emerald Nightmare
	{"IL", 1530, 786, all=0},  -- The Nighthold
	{"IL",  720,  78, all=0},  -- Firelands
	{"IL", 1220, 822, all=0},  -- Broken Isles
	{"IL", 1648, 861, all=0},  -- Trial of Valor
	{"IL", 1676, 875, all=0},  -- Tomb of Sargeras

--]]

--[[ deDE
	r::741::Der Geschmolzene Kern
	r::748::Höhle des Schlangenschreins
	r::749::Das Auge
	r::752::Sonnenbrunnenplateau
	r::320::Terrasse d. Endlosen Frühlings
	r::369::Die Schlacht um Orgrimmar

	d::316::Das Scharlachrote Kloster
	d::238::Das Verlies
	d::237::Der Tempel von Atal'Hakkar
	d::311::Scharlachrote Hallen
	d::247::Auchenaikrypta
	d::256::Der Blutkessel
	d::255::Der Schwarze Morast
	d::262::Der Tiefensumpf
	d::254::Die Arkatraz
	d::257::Die Botanika
	d::261::Die Dampfkammer
	d::258::Die Mechanar
	d::260::Die Sklavenunterkünfte
	d::259::Die Zerschmetterten Hallen
	d::248::Höllenfeuerbollwerk
	d::250::Managruft
	d::253::Schattenlabyrinth
	d::252::Sethekkhallen
	d::251::Vorgebirge des Alten Hügellands
	d::273::Feste Drak'Tharon
	d::186::Die Stunde des Zwielichts
	d::316::Das Scharlachrote Kloster
	d::302::Die Brauerei Sturmbräu
	d::311::Scharlachrote Hallen
	d::303::Tor der Untergehenden Sonne
--]]

--[[ enGB, enUS
	r::744::Temple of Ahn'Qiraj
	r::748::Serpentshrine Cavern
	r::749::The Eye
	r::752::Sunwell Plateau

	d::238::The Stockade
	d::237::The Temple of Atal'hakkar
	d::247::Auchenai Crypts
	d::248::Hellfire Ramparts
	d::249::Magisters' Terrace
	d::250::Mana-Tombs
	d::251::Old Hillsbrad Foothills
	d::252::Sethekk Halls
	d::253::Shadow Labyrinth
	d::254::The Arcatraz
	d::255::The Black Morass
	d::256::The Blood Furnace
	d::257::The Botanica
	d::258::The Mechanar
	d::259::The Shattered Halls
	d::260::The Slave Pens
	d::261::The Steamvault
	d::262::The Underbog
--]]

--[[ esES
	r::741::Núcleo de magma
	r::748::Caverna Santuario Serpiente
	r::749::El Ojo
	r::752::Meseta de La Fuente del Sol

	d::237::El Templo de Atal'Hakkar
	d::238::Las Mazmorras
	d::251::Antiguas Laderas de Trabalomas
	d::247::Criptas Auchenai
	d::254::El Arcatraz
	d::256::El Horno de Sangre
	d::257::El Invernáculo
	d::258::El Mechanar
	d::255::La Ciénaga Negra
	d::261::La Cámara de Vapor
	d::262::La Sotiénaga
	d::253::Laberinto de las Sombras
	d::259::Las Salas Arrasadas
	d::248::Murallas del Fuego Infernal
	d::260::Recinto de los Esclavos
	d::252::Salas Sethekk
	d::250::Tumbas de Maná

	esMX
	r::741::Núcleo de magma
	r::748::Caverna Santuario Serpiente
	r::749::El Ojo
	r::752::Meseta de La Fuente del Sol

	d::237::El Templo de Atal'Hakkar
	d::238::Las Mazmorras
	d::251::Antiguas Laderas de Trabalomas
	d::247::Criptas Auchenai
	d::254::El Arcatraz
	d::256::El Horno de Sangre
	d::257::El Invernáculo
	d::258::El Mechanar
	d::255::La Ciénaga Negra
	d::261::La Cámara de Vapor
	d::262::La Sotiénaga
	d::253::Laberinto de las Sombras
	d::259::Las Salas Arrasadas
	d::248::Murallas del Fuego Infernal
	d::260::Recinto de los Esclavos
	d::252::Salas Sethekk
	d::250::Tumbas de Maná
	d::558::Muelles de Hierro
--]]

--[[ frFR
	r::748::Caverne du sanctuaire du Serpent
	r::749::L’Œil
	r::751::Le Temple noir
	r::752::Plateau du Puits de soleil

	d::238::La Prison
	d::237::Le temple d’Atal’Hakkar
	d::63::Les Mortemines
	d::251::Contreforts de Hautebrande d’antan
	d::247::Cryptes Auchenaï
	d::262::La Basse-tourbière
	d::257::La Botanica
	d::256::La Fournaise du sang
	d::253::Labyrinthe des Ombres
	d::261::Le caveau de la Vapeur
	d::258::Le Méchanar
	d::255::Le Noir marécage
	d::260::Les enclos aux esclaves
	d::259::Les salles Brisées
	d::252::Les salles des Sethekk
	d::254::L’Arcatraz
	d::248::Remparts des Flammes infernales
	d::249::Terrasse des Magistères
	d::250::Tombes-mana
	d::777::Assaut sur le fort Pourpre
	d::727::La Gueule des âmes
--]]

--[[ itIT
	r::748::Caverna di Sacrespire
	r::749::Occhio della Tempesta
	r::752::Cittadella del Pozzo Solare

	d::237::Tempio di Atal'Hakkar
	d::261::Antro dei Vapori
	d::254::Arcatraz
	d::248::Bastioni del Fuoco Infernale
	d::257::Botanica
	d::247::Cripte degli Auchenai
	d::256::Forgia del Sangue
	d::260::Fosse degli Schiavi
	d::253::Labirinto delle Ombre
	d::258::Mecanar
	d::252::Sale dei Sethekk
	d::259::Sale della Devastazione
	d::250::Tombe del Mana
	d::262::Torbiera Sotterranea
--]]

--[[ koKR
	r::748::불뱀 제단
	r::749::폭풍우 눈
	r::752::태양샘 고원

	d::237::아탈학카르 신전
	d::260::강제 노역소
	d::255::검은늪
	d::250::마나 무덤
	d::258::메카나르
	d::252::세데크 전당
	d::257::신록의 정원
	d::247::아키나이 납골당
	d::254::알카트라즈
	d::253::어둠의 미궁
	d::251::옛 언덕마루 구릉지
	d::259::으스러진 손의 전당
	d::261::증기 저장고
	d::248::지옥불 성루
	d::262::지하수렁
	d::256::피의 용광로
--]]

--[[ ptBR, ptPT
	r::748::Caverna do Serpentário
	r::749::O Olho
	r::752::Platô da Nascente do Sol
	r::755::O Santuário Obsidiano
	r::761::O Santuário Rubi
	r::457::Fundição Rocha Negra
	r::786::O Baluarte da Noite

	d::184::Fim dos tempos
	d::185::Nascente da eternidade
	d::186::Hora do crepúsculo
	d::230::Martelo do Gládio Cruel
	d::237::O Templo de Atal'hakkar
	d::238::O Cárcere
	d::247::Catacumbas Auchenai
	d::248::Muralha Fogo do Inferno
	d::250::Tumbas de Mana
	d::251::Antigo Contraforte de Eira dos Montes
	d::252::Salões dos Sethekk
	d::253::Labirinto Soturno
	d::254::Arcatraz
	d::255::Lamaçal Negro
	d::256::A Fornalha de Sangue
	d::257::Jardim Botânico
	d::258::O Mecanar
	d::259::Os Salões Despedaçados
	d::260::O Pátio dos Escravos
	d::261::A Câmara dos Vapores
	d::262::O Brejo Oculto
	d::279::O Expurgo de Stratholme
	d::280::A Forja das Almas
	d::281::O Nexus
	d::282::O Óculus
	d::283::O Castelo Violeta
--]]

--[[ ruRU
	r::741::Огненные недра
	r::748::Змеиное святилище
	r::749::Око
	r::752::Плато Солнечного Колодца
	r::477::Верховный Молот

	d::237::Храм Атал'Хаккара
	d::238::Тюрьма
	d::247::Аукенайские гробницы
	d::248::Бастионы Адского Пламени
	d::250::Гробницы Маны
	d::251::Старые предгорья Хилсбрада
	d::252::Сетеккские залы
	d::253::Темный лабиринт
	d::254::Аркатрац
	d::255::Черные топи
	d::256::Кузня Крови
	d::257::Ботаника
	d::258::Механар
	d::259::Разрушенные залы
	d::260::Узилище
	d::261::Паровое подземелье
	d::262::Нижетопь
--]]

--[[ zhCN
	r::748::毒蛇神殿
	r::752::太阳之井高地

	d::237::阿塔哈卡神庙
	d::238::监狱
	d::247::奥金尼地穴
	d::248::地狱火城墙
	d::250::法力陵墓
	d::251::旧希尔斯布莱德丘陵
	d::252::塞泰克大厅
	d::253::暗影迷宫
	d::254::禁魔监狱
	d::255::黑色沼泽
	d::256::鲜血熔炉
	d::257::生态船
	d::258::能源舰
	d::259::破碎大厅
	d::260::奴隶围栏
	d::261::蒸汽地窟
	d::262::幽暗沼泽
--]]

--[[ zhTW
	r::748::毒蛇神殿洞穴
	r::749::風暴核心
	r::752::太陽之井高地

	d::237::阿塔哈卡神廟
	d::238::監獄
	d::247::奧奇奈地穴
	d::248::地獄火壁壘
	d::250::法力墓地
	d::251::希爾斯布萊德丘陵舊址
	d::252::塞司克大廳
	d::253::暗影迷宮
	d::254::亞克崔茲
	d::255::黑色沼澤
	d::256::血熔爐
	d::257::波塔尼卡
	d::258::麥克納爾
	d::259::破碎大廳
	d::260::奴隸監獄
	d::261::蒸汽洞窟
	d::262::深幽泥沼
	d::271::安卡罕特：古王國
--]]


