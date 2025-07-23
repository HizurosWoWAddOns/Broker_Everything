
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
local fState,symbol = C("ltgray"," (%d/%d)"),"|Tinterface\\buttons\\UI-%sButton-Up:0|t ";
local PL_collected,PEW_collected,activeEncounter = true,true;
local BossKillQueryUpdate,UpdateInstaceInfoLock = false,{};
local ejInstanceId2instanceMapId = {};
-- some entries have not exact matching names between encounter journal and raidinfo frame
local ignore_ej = {};
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

local ejInstances,ejDoubleInstanceNames,ejInstancesFinished,LoadEjInstances,LoadEjInstancesLock={},{};
do

	local function getEjInstances(exp,mode)
		-- walk through list
		local index = 1;
		local ejInstanceId, instanceName, _, _, _, _, _, _, _, shouldDisplayDifficulty, instanceMapId = EJ_GetInstanceByIndex(index, mode);
		while ejInstanceId~=nil do
			if instanceMapId and shouldDisplayDifficulty then
				ejInstances[exp][instanceMapId] = {index=index,isRaid=mode,ejId=ejInstanceId,instanceName=instanceName};
				if ejDoubleInstanceNames[instanceName]==nil then
					ejDoubleInstanceNames[instanceName] = {}
				end
				tinsert(ejDoubleInstanceNames[instanceName],instanceMapId);
				ejDoubleInstanceNames[instanceMapId] = true;
			end
			index = index+1;
			ejInstanceId, instanceName, _, _, _, _, _, _, _, shouldDisplayDifficulty, instanceMapId = EJ_GetInstanceByIndex(index, mode);
		end
	end

	function LoadEjInstances()
		if LoadEjInstancesLock then return end LoadEjInstancesLock = true;

		local numTiers = EJ_GetNumTiers();

		-- Note: Tier 1-n is not
		for ejTier=1, numTiers do
			EJ_SelectTier(ejTier);
			local exp = ejTier-1;
			if not _G["EXPANSION_NAME"..exp] then
				exp = exp-1;
			end
			if ejInstances[exp]==nil then
				ejInstances[exp]={};
			end
			-- get all raids
			getEjInstances(exp,true);
			-- get all dungeons
			getEjInstances(exp,false);
		end

		ejInstancesFinished=true;
	end
end

local activeInstances = {last=0,Raids={},Dungeons={}};
local function updateInstances()
	local currentTime = time();
	if activeInstances.last>=currentTime-2 then
		return;
	end
	activeInstances.last = currentTime;

	local num = GetNumSavedInstances();
	for index=1, num do
		local iName, lockoutId, reset, difficultyId, locked, extended,
		instanceIDMostSig, isRaid, maxPlayers, difficultyName,
		numEncounters, encounterProgress, extendDisabled, instanceMapId = GetSavedInstanceInfo(index);
		local aInst = activeInstances[isRaid and "Raids" or "Dungeons"];
		if reset>0 and instanceMapId and difficultyName then
			if aInst[instanceMapId]==nil then
				aInst[instanceMapId] = {};
			end
			aInst[instanceMapId][difficultyName] = {reset,currentTime,encounterProgress,numEncounters,isRaid};
		end
	end

	ns.toon[name1] = activeInstances.Raids;
	ns.toon[name2] = activeInstances.Dungeons;
end

local function createTooltip2(self,instance)
	local instanceMapId,name,label = unpack(instance);
	local t = time();

	GameTooltip:SetOwner(self,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(self,"horizontal",tt1 or tt2));
	GameTooltip:SetFrameLevel(self:GetFrameLevel()+1);

	GameTooltip:ClearLines();

	GameTooltip:AddLine(label);
	GameTooltip:AddLine(C("gray",ns.realm));
	GameTooltip:AddLine(" ");

	local numShownToons = 0;
	for i,toonNameRealm,toonName,toonRealm,toonData,isCurrent in ns.pairsToons(name,{currentFirst=true,forceSameRealm=true}) do
		if not isCurrent and toonData[name] and toonData[name][instanceMapId] then
			-- toonData - name - instanceMapId - diffName - data [ reset, timestamp, encounterProgress, numEncounters ]
			local diffState, entries = {}, toonData[name][instanceMapId];
			for diffName, data in ns.pairsByKeys(entries) do
				if type(data)=="table" and (data[1]+data[2])>t then
					local diffColor, stateColor, stateStr = "ltgray", "orange", "In progress";
					local encounter = fState:format(data[3],data[4]);
					if data[3]==data[4] then
						stateColor,stateStr="green","Cleared";
						encounter = "";
					end
					tinsert(diffState,C(diffColor,diffName)..C(stateColor,L[stateStr])..encounter);
					numShownToons = numShownToons+1;
				end
			end
			local factionSymbol = ns.factionIcon(toonData.faction or "Neutral",16,16);
			if (ns.profile[name].showActiveOnly and #diffState>0) or not ns.profile[name].showActiveOnly then
				GameTooltip:AddDoubleLine(C(toonData.class,ns.scm(toonName))..factionSymbol,#diffState==0 and C("gray",L["Free"]) or table.concat(diffState,"\n"));
			end
		end
	end
	if numShownToons==0 then
		GameTooltip:AddLine(C("ltgray",L["No active instance ids on other twinks found."]))
	end

	GameTooltip:Show();
end

local function toggleExpansion(self,data)
	ns.profile[data.name]['showExpansion'..data.expansion] = not ns.profile[data.name]['showExpansion'..data.expansion];
	createTooltip(data.name==name1 and tt1 or tt2,data.name,data.mode); -- force update tooltip?
end

local function sortByIndex(a,b)
	return a.index<b.index and -1 or 1;
end

function createTooltip(tt,name,mode)
	local ttName = name==name1 and ttName1 or ttName2;
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end

	tt:AddHeader(C("dkyellow",name==name1 and RAIDS or DUNGEONS));

	if not ejInstancesFinished then
		tt:AddSeparator(4,0,0,0,0)
		tt:AddLine(L["Sorry. List under construction."])
		tt:AddLine(L["Try again in some seconds."])
		ns.roundupTooltip(tt);
		return;
	end

	updateInstances();

	-- create instance list
	local exp_max,prevLabel = GetNumExpansions(),"";
	if not _G["EXPANSION_NAME"..exp_max] then
		exp_max = exp_max-1;
	end
	local exp_start, exp_stop, exp_direction = 1, exp_max, 1;
	if ns.profile[name].invertExpansionOrder then
		exp_start, exp_stop, exp_direction = exp_max, 1, -1;
	end

	for exp=exp_start, exp_stop, exp_direction do
		if ns.profile[name]['showExpansion'..exp] and ejInstances and ejInstances[exp] then
			table.sort(ejInstances[exp],sortByIndex)
			local alreadyShown = {}
			for instanceMapId, ejInfo in pairs(ejInstances[exp]) do
				if ejInfo.isRaid==mode and not (ejDoubleInstanceNames[instanceMapId] and alreadyShown[ejInfo.instanceName])--[[ and not hide[ejInfo.ejId] ]] then
					if prevLabel~=_G["EXPANSION_NAME"..exp] then
						local hColor,sState,_status_,_mode_ = "gray","Plus","","";
						if ns.profile[name]['showExpansion'..exp]==nil then
							ns.profile[name]['showExpansion'..exp] = true;
						end
						if ns.profile[name]['showExpansion'..exp] then
							hColor,sState,_status_,_mode_ = "ltblue","Minus",C("ltblue",STATUS),C("ltblue",MODE);
						end
						tt:AddSeparator(4,0,0,0,0);
						local l=tt:AddLine(symbol:format(sState)..C(hColor,_G["EXPANSION_NAME"..exp]),_status_,_mode_);
						tt:SetLineScript(l,"OnMouseUp",toggleExpansion, {name=name,mode=mode,expansion=exp});
						prevLabel = _G["EXPANSION_NAME"..exp];
						if ns.profile[name]['showExpansion'..exp] then
							tt:AddSeparator();
						end
					end

					alreadyShown[ejInfo.instanceName] = true;
					local status,diff,encounter,id = {},{},"","";
					if ignore_ej[ejInfo.instanceName] then
						status = nil;
					end
					if status then
						if activeInstances[name][instanceMapId] then
							for diffName, data in ns.pairsByKeys(activeInstances[name][instanceMapId])do
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
							-- ejDoubleInstanceNames
							id = C("gray"," ("..instanceMapId..")");
						end
						local l=tt:AddLine(
							C("ltyellow","    "..ejInfo.instanceName)..id,
							#status==0 and C("gray",L["Free"]) or table.concat(status,"\n"),
							#diff==0 and "" or table.concat(diff,"\n")
						);

						tt:SetLineScript(l,"OnEnter",createTooltip2,{instanceMapId,name,ejInfo.instanceName});
						tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);
					end
				end
			end

			--[[
			EJ_SelectTier(tier)
			local index, ejInfo.instanceMapId, ejInfo.instanceName, _ = 1;
			ejInfo.instanceMapId, ejInfo.instanceName = EJ_GetInstanceByIndex(index, mode);
			while ejInfo.instanceMapId~=nil do
				if not hide[ejInfo.instanceMapId] then
					local status,diff,encounter,id = {},{},"","";
					if ignore_ej[ejInfo.instanceName] then
						status = false;
					end
					if status then
						if activeInstances[ejInfo.instanceName] then
							for diffName, data in ns.pairsByKeys(activeInstances[ejInfo.instanceName])do
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
							id = C("gray"," ("..ejInfo.instanceMapId..")");
						end
						local l=tt:AddLine(
							C("ltyellow","    "..ejInfo.instanceName)..id,
							#status==0 and C("gray",L["Free"]) or table.concat(status,"\n"),
							#diff==0 and "" or table.concat(diff,"\n")
						);

						-- tt:SetLineScript(l,"OnEnter",createTooltip2,{ejInfo.instanceMapId,name,ejInfo.instanceName});
						-- tt:SetLineScript(l,"OnLeave",GameTooltip_Hide);

						if ns.toon[name]==nil then
							ns.toon[name]={};
						end
						ns.toon[name][ejInfo.instanceMapId] = activeInstances[ejInfo.instanceName];
					end
				end
				index = index + 1;
				ejInfo.instanceMapId, ejInfo.instanceName = EJ_GetInstanceByIndex(index, mode);
			end
			--]]
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0)
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

local function OnEvent(self,event,...)
	local name = self==module1.eventFrame and name1 or name2;
	if event=="PLAYER_LOGIN" then
		if ns.toon[name]==nil then
			ns.toon[name]={}
		end

		C_Timer.After(3.14159,LoadEjInstances)

		RequestRaidInfo(); -- trigger UPDATE_INSTANCE_INFO
	elseif event=="BOSS_KILL" then
		local encounterID, name = ...;
		BossKillQueryUpdate=true;
		C_Timer.After(0.14,RequestRaidInfoUpdate);
	elseif event=="UPDATE_INSTANCE_INFO" then
		BossKillQueryUpdate=false;
		C_Timer.After(0.3, function()
			updateInstances();
		end);
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
		showActiveOnly = false,
	}
}

function module1.options()
	return {
		broker = nil,
		tooltip = {
			invertExpansionOrder={ type="toggle", order=1, width="double", name=L["Invert expansion order"], desc=L["Invert order by exspansion in tooltip"] },
			showID = { type = "toggle", order=2, name=L["Show IDs"], desc=L["Display instance id's behind the name in tooltip"] },
			tooltip2header = { type="header", order=20, name=L["Tooltip2"]},
			showCharsFrom = 21,
			showAllFactions = 22,
			showActiveOnly = { type = "toggle", order=23, name=L["InstancesShowActiveTwinks"], desc=L["InstancesShowActiveTwinksDesc"] },
		},
		misc = nil,
	}
end

function module2.options()
	return {
		broker = nil,
		tooltip = {
			invertExpansionOrder={ type="toggle", order=1, width="double", name=L["Invert expansion order"], desc=L["Invert order by exspansion in tooltip"] },
			showID = { type = "toggle", order=2, name=L["Show IDs"], desc=L["Display instance id's behind the name in tooltip"] },
			tooltip2header = { type="header", order=20, name=L["Tooltip2"]},
			showCharsFrom = 21,
			showAllFactions = 22,
			showActiveOnly = { type = "toggle", order=23, name=L["InstancesShowActiveTwinks"], desc=L["InstancesShowActiveTwinksDesc"] },
		},
		misc = nil,
	}
end

-- function module1.init() end
-- function module2.init() end

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

