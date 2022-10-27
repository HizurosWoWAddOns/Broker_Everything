
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<5 then return end


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
	[1192] = true, -- shadowlands world bosses // no raid
	[1205] = true, -- dragonflight world bosses // no raid
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
local renameManually = {}
if LOCALE_enUS or LOCALE_enGB then
	renameManually["Ahn'Qiraj Temple"] = "Temple of Ahn'Qiraj";
end


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
			elseif renameManually[name] then
				name = renameManually[name];
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

	for i,toonNameRealm,toonName,toonRealm,toonData,isCurrent in ns.pairsToons(name,{currentFirst=true,forceSameRealm=true}) do
		if toonName then
			local diffState = {};
			if toonData[name] and toonData[name][id] then
				if toonData[name][id].new then
					for diffName, data in ns.pairsByKeys(toonData[name][id]) do
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
				elseif (toonData[name][id][1]+toonData[name][id][2])>t and toonData[name][id][5] and toonData[name][id][5]~="" then
					local diff,state = C("ltgray",toonData[name][id][5])..", ", C("orange",L["In progress"]);
					if toonData[name][id][3]==toonData[name][id][4] then
						state = C("green",L["Cleared"]);
					else
						state = state..fState:format(toonData[name][id][3],toonData[name][id][4]);
					end
					tinsert(diffState,diff..state);
				end
			end
			local factionSymbol = "";
			if toonData.faction and toonData.faction~="Neutral" then
				factionSymbol = " |TInterface\\PVPFrame\\PVP-Currency-"..toonData.faction..":16:16:0:-1:16:16:0:16:0:16|t";
			end
			GameTooltip:AddDoubleLine(C(toonData.class,ns.scm(toonName))..factionSymbol,#diffState==0 and C("gray",L["Free"]) or table.concat(diffState,"\n"));
		end
	end
	GameTooltip:Show();
end

local function toggleExpansion(self,data)
	ns.profile[data.name]['showExpansion'..data.expansion] = not ns.profile[data.name]['showExpansion'..data.expansion];
	createTooltip(data.name==name1 and tt1 or tt2,data.name,data.mode); -- force update tooltip?
end

function createTooltip(tt,name,mode)
	local ttName = name==name1 and ttName1 or ttName2;
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

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
						tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);

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
		showID = false,
		showCharsFrom = true,
		showAllFactions = true,
	}
}

function module1.options()
	return {
		broker = nil,
		tooltip = {
			invertExpansionOrder={ type="toggle", order=1, width="double", name=L["Invert expansion order"], desc=L["Invert order by exspansion in tooltip"] },
			tooltip2header = { type="header", order=2, name=L["Tooltip2"]},
			showCharsFrom = 2,
			showAllFactions = 3,
		},
		misc = nil,
	}
end

function module2.options()
	return {
		broker = nil,
		tooltip = {
			invertExpansionOrder={ type="toggle", order=1, width="double", name=L["Invert expansion order"], desc=L["Invert order by exspansion in tooltip"] },
			tooltip2header = { type="header", order=2, name=L["Tooltip2"]},
			showCharsFrom = 2,
			showAllFactions = 3,
		},
		misc = nil,
	}
end

function module1.init() -- raids
	-- {<target>,<raidinfo>,<encounterjournalid>}
	-- IL = InstanceLock, EJ = EncounterJournal, XX = No ID, list without Free/InProgress/Cleared-info
	-- classic
	table.insert(renameIt,{"IL",  409, 741}); -- molten core
	table.insert(renameIt,{"IL",  531, 744}); -- temple of ahn'qiraj
	-- bc
	table.insert(renameIt,{"IL",  548, 748}); -- serpentshrine cavern
	table.insert(renameIt,{"IL",  550, 749}); -- tempest keep
	table.insert(renameIt,{"IL",  564, 751}); -- black temple
	table.insert(renameIt,{"IL",  580, 752}); -- sunwell
	-- woltk
	table.insert(renameIt,{"IL",  615, 755}); -- obsidian sanctum
	table.insert(renameIt,{"IL",  724, 761}); -- rubin sanctum
	table.insert(renameIt,{"IL",  631, 758}); -- Icecrown Citadel
	-- mop
	table.insert(renameIt,{"EJ",  996, 320}); -- Terrace of Endless Spring
	table.insert(renameIt,{"IL", 1136, 369}); -- siege of orgrimmar
	-- wod
	table.insert(renameIt,{"EJ", 1205, 457}); -- Blackrock Foundry
	table.insert(renameIt,{"IL", 1228, 477}); -- Highmaul
	-- legion
	table.insert(renameIt,{"EJ", 1530, 786}); -- The Nighthold
	table.insert(renameIt,{"IL", 1676, 875, all=0}); -- Tomb of Sargeras
end

function module2.init() -- dungeons
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
	table.insert(renameIt,{"IL", 1009, 330, all=0});  -- Heart of Fear
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

