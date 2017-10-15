
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "IDs"; -- L["IDs"]
local ttName,ttColumns,tt,createMenu,module = name.."TT", 4;
local diffTypes = setmetatable({ -- http://wowpedia.org/API_GetDifficultyInfo / http://wow.gamepedia.com/DifficultyID
	[1] = 1,	--  1 =  5 Regular
	[2] = 1,	--  2 =  5 Heroic

	[3] = 4,	--  3 = 10 Normal
	[4] = 4,	--  4 = 25 Normal
	[5] = 4,	--  5 = 10 Heroic
	[6] = 4,	--  6 = 25 Heroic
	[7] = 5,	--  7 = 25 LFR

	[8] = 2,	--  8 =  5 Challenge
	[9] = 4,	--  9 = 40 man classic raids

	--[10] = 0,	-- 10 = unknown

	[11] = 3,	-- 11 = 5 Szenario Heroic
	[12] = 3,	-- 12 = 5 Szenario Normal

	--[13] = 0,	-- 13 = unknown

	[14] = 7,	-- 14 = 10-30 Normal
	[15] = 7,	-- 15 = 10-30 Heroic
	[16] = 7,	-- 16 = 20 Mystic
	[17] = 7,	-- 17 = 10-30 LFR

	[18] = 8,	-- 18 = ? Event
	[19] = 8,	-- 19 = ? Event
	[20] = 8,	-- 20 = ? Event Scenario

	--[21] = 0,	-- 21 = unknown
	--[22] = 0,	-- 22 = unknown

	[23] = 1,	-- 23 = Mythic dungeons
	[24] = 1,	-- 24 = timewalker dungeons
	[25] = 3,	-- 25 = PvP scenarios
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


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=[[interface\icons\inv_misc_pocketwatch_02]],coords={0.05,0.95,0.05,0.95}} --IconName::IDs--


-- some local functions --
--------------------------
function createMenu(self)
	if (tt) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function extendInstance(self,info)
	securecall("SetSavedInstanceExtend", info.index, info.doExtend);
	securecall("RequestRaidInfo");
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	local allNothing,iniNothing = true,true;
	local _,title = ns.DurationOrExpireDate(0,false,"Duration","Expire date");
	local timer = function(num)
		return (IsShiftKeyDown()) and ( (num==true) and "Expire date" or date("%Y-%m-%d %H:%M",time()+num) ) or ( (num==true) and "Duration" or SecondsToTime(num) );
	end

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",L[name]));

	if ns.profile[name].showBosses then
		tt:AddSeparator(3,0,0,0,0)
		tt:AddLine(C("ltblue",L["World bosses"]),"","",C("ltblue",L[title]))
		tt:AddSeparator()
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
				for i,v in ipairs(lst) do
					tt:AddLine(C("ltyellow",v.name),"","",ns.DurationOrExpireDate(v.reset))
				end
				allNothing = false
			end
		else
			tt:AddLine(C("gray",L["No boss IDs found..."]));
		end
	end

	local instanceName, instanceID, instanceReset, instanceDifficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress=1,2,3,4,5,6,7,8,9,10,11,12;
	tt:AddSeparator(3,0,0,0,0);
	tt:AddLine(C("ltblue",L["Instances"]), C("ltblue",TYPE),C("ltblue",L["Bosses"]),C("ltblue",L[title]));
	tt:AddSeparator();
	local empty,num = true,GetNumSavedInstances();
	local diffCounter = {};
	if (num>0) then
		local lst,count,data = {},0;
		for i=1, num do
			data={GetSavedInstanceInfo(i)};
			data.index = i;
			if (data[instanceName]) and (data[instanceDifficulty]) then
				local diff = diffTypes[data[instanceDifficulty]];
				if not lst[diff] then
					lst[diff]={};
				end
				if not diffCounter[diff] then
					diffCounter[diff] = {0,0};
				end
				diffCounter[diff][1]=diffCounter[diff][1]+1;
				if data[instanceReset]>0 then
					diffCounter[diff][2]=diffCounter[diff][2]+1;
				end
				tinsert(lst[diff],data);
				count=count+1;
			end
		end
		if (count>0) then
			local showDiff = { -- show difficulty
				{ns.profile[name].showDungeons,    false},										--"Dungeons", -- [1]
				{ns.profile[name].showChallenges,  false},										--"Challenges", -- [2]
				{ns.profile[name].showSzenarios,   false},										--"Szenarios", -- [3]
				{ns.profile[name].showRaidsClassic,ns.profile[name].showExpiredRaidsClassic},	--"Raids (Classic)", -- [4]
				{ns.profile[name].showRaidsLFR,    false},										--"Raids (LFR)", -- [5]
				{ns.profile[name].showRaidsFlex,   false},										--"Raids (Flex)", -- [6]
				{ns.profile[name].showRaids,       ns.profile[name].showExpiredRaids},			--"Raids", -- [7]
				{ns.profile[name].showEvents,      false},										--"Events" -- [8]
			};
			for diff, data in ns.pairsByKeys(lst) do
				if diff~=0 and showDiff[diff][1] and (diffCounter[diff][2]>0 or (diffCounter[diff][1]>0 and showDiff[diff][2])) then
					local header,doExtend = (diffName[diff]) and diffName[diff] or "Unknown type",false;
					tt:AddLine(C("gray",header));
					for i,v in ipairs(data) do
						local duration,color = false,"ltgray";
						if v[instanceReset]>0 then
							duration = ns.DurationOrExpireDate(v[instanceReset])
							color = "ltyellow";
						elseif v[encounterProgress]>0 and v[numEncounters]>0 and v[encounterProgress]<v[numEncounters] then
							if v[extended] then
								doExtend = false;
								duration = L["Unextend ID"];
							else
								doExtend = true;
								if v[locked] then
									duration = L["Extend ID"];
								else
									duration = L["Reactivate ID"];
								end
							end
							duration = C("ltgray",duration);
						else
							duration = C("gray",RAID_INSTANCE_EXPIRES_EXPIRED);
						end
						local l=tt:AddLine(
							C(color,"    "..v[instanceName]),
							v[difficultyName].. (not diffName[diff] and " ("..v[instanceDifficulty]..")" or ""),
							("%s/%s"):format(
								(v[encounterProgress]>0) and v[encounterProgress] or "?",
								(v[numEncounters]>0) and v[numEncounters] or "?"
							),
							duration or ""
						);
						if not duration then
							tt:SetCellScript(l,4,"OnMouseUp", extendInstance, {index=v.index,doExtend=doExtend});
						end
					end
					allNothing = false;
					iniNothing = false;
				end
			end
		end
	end

	if iniNothing then
		tt:AddLine(C("gray",L["No instance IDs found..."]));
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0)
		if allNothing==false then
			local _,_,mod = ns.DurationOrExpireDate();
			tt:SetCell(tt:AddLine(),1,C("copper",L["Hold "..mod]).." || "..C("green",L["Show expire date instead of duration"]),nil,nil,ttColumns);
		end
		ns.clickOptions.ttAddHints(tt,name);
	end

	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	desc = L["Broker to show locked raids, dungeons and world bosses"],
	events = {},
	updateinterval = nil, --10,
	timeout = nil, --20,
	timeout_used = false,
	timeout_args = nil,
	config_defaults = {
		-- show types
		showBosses = true,
		showDungeons = true,
		showChallenges = true,
		showSzenarios = true,
		showRaidsClassic = true,
		showRaidsLFR = true,
		showRaidsFlex = true,
		showRaids = true,
		showEvents = true,

		-- show expired types
		showExpiredRaidsClassic = true,
		showExpiredRaids = true
	},
	config_allowed = nil,
	config_header = nil, -- use default header
	config_broker = nil,
	config_tooltip = {
		{ type="toggle", name="showBosses",              label=L["Show world bosses"],          tooltip=L["Display list of world boss IDs in tooltip"] },
		{ type="toggle", name="showDungeons",            label=L["Show dungeons"],              tooltip=L["Display list of dungeon IDs in tooltip"] },
		{ type="toggle", name="showChallenges",          label=L["Show challenges"],            tooltip=L["Display list of challenge IDs in tooltip"] },
		{ type="toggle", name="showSzenarios",           label=L["Show szenarios"],             tooltip=L["Display list of szenario IDs in tooltip"] },
		{ type="toggle", name="showRaidsClassic",        label=L["Show classic raids"],         tooltip=L["Display list of classic raid IDs in tooltip"] },
		{ type="toggle", name="showRaidsLFR",            label=L["Show lfr"],                   tooltip=L["Display list of lfr IDs in tooltip"] },
		{ type="toggle", name="showRaidsFlex",           label=L["Show flex raids"],            tooltip=L["Display list of flex raid IDs in tooltip"] },
		{ type="toggle", name="showRaids",               label=L["Show raids"],                 tooltip=L["Display list of raid IDs in tooltip"] },
		{ type="toggle", name="showEvents",              label=L["Show events"],                tooltip=L["Display list of event IDs in tooltip"] },
		{ type="separator" },
		{ type="toggle", name="showExpiredRaidsClassic", label=L["Show expired classic raids"], tooltip=L["Display expired classic raids in tooltip"] },
		{ type="toggle", name="showExpiredRaids",        label=L["Show expired raids"],         tooltip=L["Display expired raids in tooltip"] },
	},
	config_misc = nil,
	clickOptions = {
		["5_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self)
			end
		}
	}
}

-- function module.init() end

function module.onevent(self,event,...)
	if event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(module,ns.profile[name]);
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "LEFT", "RIGHT", "RIGHT", "RIGHT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
