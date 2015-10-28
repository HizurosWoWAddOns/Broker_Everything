
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
--local be_ids_db = {}

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "IDs";
local ldbName,ttName = name,name.."TT";
local scanTooltip = CreateFrame("GameTooltip",addon.."_"..name.."_ScanTooltip",UIParent,"GameTooltipTemplate"); scanTooltip:SetScale(0.0001); scanTooltip:Hide();
local tt;

local diffTypes = setmetatable({ -- http://wowpedia.org/API_GetDifficultyInfo
	[1] = 1,	--  1 =  5 Regular
	[2] = 1,	--  2 =  5 Heroic

	[3] = 4,	--  3 = 10 Normal
	[4] = 4,	--  4 = 25 Normal
	[5] = 4,	--  5 = 10 Heroic
	[6] = 4,	--  6 = 25 Heroic
	[7] = 5,	--  7 = 25 LFR

	[8] = 2,	--  8 =  5 Challenge
	[9] = 4,	--  9 = 40 man classic

	[11] = 3,	-- 11 = 5 Szenario Heroic
	[12] = 3,	-- 12 = 5 Szenario Normal

	[14] = 7,	-- 14 = 10-30 Normal
	[15] = 7,	-- 15 = 10-30 Heroic
	[16] = 7,	-- 16 = 20 Mystic
	[17] = 7,	-- 17 = 10-30 LFR

	[18] = 8,	-- 18 = ? Event
	[19] = 8,	-- 19 = ? Event
	[20] = 8,	-- 20 = ? Event Scenario
},{__index=function(t,k) rawset(t,k,0); return 0; end});

local diffName = {
	"Dungeons",			-- [1]
	"Challenges",		-- [2]
	"Szenarios",		-- [3]
	"Raids (Classic)",	-- [4]
	"Raids (LFR)",		-- [5]
	"Raids (Flex)",		-- [6]
	"Raids",			-- [7]
	"Events"			-- [8]
};

---------------------------------------
-- module variables for registration --
---------------------------------------
I[name] = {iconfile=[[interface\icons\inv_misc_pocketwatch_02]],coords={0.05,0.95,0.05,0.95}} --IconName::IDs--

ns.modules[name] = {
	desc = L["Broker to show raid, dungeon and other lockout id's. (+World bosses)"],
	events = {},
	updateinterval = nil, --10,
	timeout = nil, --20,
	timeout_used = false,
	timeout_args = nil,
	config_defaults = {},
	config_allowed = {},
	config = { { type="header", label=L[name], align="left", icon=I[name] } }
}


--------------------------
-- some local functions --
--------------------------
local function createTooltip()
	if not (tt~=nil and tt.key~=nil and tt.key==ttName) then return; end
	local nothing = true;
	local _,title = ns.DurationOrExpireDate(0,false,"Duration","Expire date");
	local timer = function(num)
		return (IsShiftKeyDown()) and ( (num==true) and "Expire date" or date("%Y-%m-%d %H:%M",time()+num) ) or ( (num==true) and "Duration" or SecondsToTime(num) );
	end

	tt:Clear();
	tt:AddHeader(C("dkyellow",L[name]));

	local num = GetNumSavedWorldBosses();
	if (num>0) then
		local lst,data = {};
		for i=1, num do
			local n,id,r = GetSavedWorldBossInfo(i);
			if (n) and (type(r)=="number") and (r>0) then
				tinsert(lst,{name=n,id=id,reset=r,bonus=false});
			end
		end
		if (#lst>0) then
			tt:AddSeparator(3,0,0,0,0)
			tt:AddLine(C("ltblue",L["World bosses"]),"","",C("ltblue",L[title]))
			tt:AddSeparator()
			for i,v in ipairs(lst) do
				tt:AddLine(C("ltyellow",v.name),"","",ns.DurationOrExpireDate(v.reset))
			end
			nothing = false
		end
	end

	local instanceName, instanceID, instanceReset, instanceDifficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress=1,2,3,4,5,6,7,8,9,10,11,12;
	local num = GetNumSavedInstances();
	if (num>0) then
		local lst,count,data = {},0;
		for i=1, num do
			data={GetSavedInstanceInfo(i)};
			if (data[instanceName]) and (data[instanceReset]>0) and (data[instanceDifficulty]) then
				if (not lst[diffTypes[data[instanceDifficulty]]]) then
					lst[diffTypes[data[instanceDifficulty]]]={};
				end
				tinsert(lst[diffTypes[data[instanceDifficulty]]],data);
				count=count+1;
			end
		end
		if (count>0) then
			for diff, data in ns.pairsByKeys(lst) do
				if (#data>0) then
					local header = (diffName[diff]) and diffName[diff] or "Unknown type";
					tt:AddSeparator(3,0,0,0,0);
					tt:AddLine(C("ltblue",L[header]), C("ltblue",L["Type"]),C("ltblue",L["Bosses"]),C("ltblue",L[title]));
					tt:AddSeparator();
					for i,v in ipairs(data) do
						tt:AddLine(
							C("ltyellow",v[instanceName]),
							v[difficultyName].. (not diffName[diff] and " ("..v[instanceDifficulty]..")" or ""),
							("%s/%s"):format(
								(v[encounterProgress]>0) and v[encounterProgress] or "?",
								(v[numEncounters]>0) and v[numEncounters] or "?"
							),
							ns.DurationOrExpireDate(v[instanceReset])
						);
					end
					nothing = false;
				end
			end
		end
		if nothing==true then
			tt:AddLine("No IDs found...")
		elseif (Broker_EverythingDB.showHints) then
			tt:AddSeparator(3,0,0,0,0);
			local l,c = tt:AddLine()
			local _,_,mod = ns.DurationOrExpireDate();
			tt:SetCell(l,1,C("copper",L["Hold "..mod]).." || "..C("green",L["Show expire date instead of duration"]),nil,nil,4);
			l,c = nil,nil;
		end
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	if (self) then
		local obj = ns.LDB:GetDataObjectByName(ldbName);
		obj.text = L[name];
	end
end

-- ns.modules[name].onevent = function(self,event,...) end
-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(ttName, 4, "LEFT", "LEFT", "LEFT", "RIGHT")
	createTooltip(tt)
	ns.createTooltip(self, tt)
end

ns.modules[name].onleave = function(self)
	if tt then
		ns.hideTooltip(tt,name)
	end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end




--[=[

be_ids_db [table]
	<realm [table]>
		<char [table]>
			nBosses [number]
			bosses [table]
				<name [table]>
					<id [number]>
					<reset [number]>
					<extended [bool]> ?
					<bonusloot [bool]>

			nDungeons [number]
			dungeons
				<name [table]>
					<id [number]>
					<reset [number]>
					<extended [bool]>
					<difficultyName [string]>
					<numEncounters [number]>
					<maxEncounters [number]>
					<encounters [table]>
						<name [table]>
							<bonusloot [boolean]>

			nChallenges [number]
			challenges
				{see dungeons}

			nRaids [number]
			raids/myths
				{see dungeons}

			nLFR [number]
			lfr
				{see dungeons}

			nFlex [number]
			flex
				{see dungeons}


all tables (bosses, dungeons etc...) crawled and add set [reset] to false befor start a new scan
after the scan a second run through the table remove all entries with reset==false

]=]



--[=[
numDungeons, numRaids, numChallenges, numUnknown = 0,0,0,0;
dungeons,raids,lfr,flex,challenges,bosses,unknown = {},{},{},{},{},{},{};
local data
for i=1, GetNumSavedInstances() do
	local instanceName, instanceID, instanceReset, instanceDifficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i);

	if instanceDifficulty~=nil and instanceReset>0 then
		scanTooltip:Show()
		scanTooltip:SetOwner(UIParent,"LEFT",0,0)
		scanTooltip:SetInstanceLockEncountersComplete(i)
		local reg,data,line = {scanTooltip:GetRegions()},{},1
		local n,nc
		for k,v in pairs(reg) do
			if v~=nil and v:GetObjectType()=="FontString" and v:GetText()~=nil then
				if line>1 then
					if line/2==floor(line/2) then
						n = v:GetText()
					else
						tinsert(data,{n,({v:GetTextColor()})[0]~=0})
					end
				end
				line = line + 1
			end
		end
		scanTooltip:ClearLines()
		scanTooltip:Hide()

		data = {
			instanceName		= instanceName,
			instanceReset		= instanceReset,
			extended			= extended,
			maxPlayers			= maxPlayers,
			difficultyName		= difficultyName,
			numEncounters		= numEncounters~=0 and numEncounters or "a",
			encounterProgress	= numEncounters~=0 and encounterProgress or "n",
			encounters			= data
		};

		if (instanceDifficulty<=2) then
			tinsert(dungeons,data);
			numDungeons = numDungeons+1
		elseif instanceDifficulty==8 then
			tinsert(challenges,data);
			numChallenges = numChallenges+1
		elseif instanceDifficulty<=16 then
			tinsert(raids,data);
			numRaids = numRaids+1
		else
			numUnknown = numUnknown+1
			unknown[data.instanceName] = data
		end

		if (instances[instanceDifficulty]==nil) then
			instances[instanceDifficulty]={};
		end
		tinsert(instances[instanceDifficulty],data);
	end
end
]=]
