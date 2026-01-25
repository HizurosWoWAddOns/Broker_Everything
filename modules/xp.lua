
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "XP" -- XP L["ModDesc-XP"]
local ttName, ttColumns, tt, module, createTooltip  = name.."TT", 3;
local data,xp2levelup = {};
local sessionStartLevel = UnitLevel("player");
local textbarSigns = {"=","-","#","||","/","\\","+",">","•","⁄"};
local triggerLocked = false;
local chromieTimePreviewAtlasToExpansionIndex = {
	burningcrusade=1, wrathofthelichking=2, cataclysm = 3,
	mistsofpandaria=4, warlordsofdraenor=5, legion=6,
	battleforazeroth=7, shadowlands=8, dragonflight=9,
	thewarwithin=10, mitnight=11, thelasttitan=12
};

local MAX_PLAYER_LEVEL = GetMaxPlayerLevel and GetMaxPlayerLevel() or MAX_PLAYER_LEVEL or 0 -- missing changes by blizzard for bc and wotlk
if MAX_PLAYER_LEVEL==60 and WOW_PROJECT_ID==WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
	MAX_PLAYER_LEVEL=70;
elseif MAX_PLAYER_LEVEL==60 and WOW_PROJECT_ID==WOW_PROJECT_WRATH_CLASSIC then
	MAX_PLAYER_LEVEL=80;
end


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\ability_dualwield",coords={0.05,0.95,0.05,0.95}}; --IconName::XP--


-- some local functions --
--------------------------
local function GetExperience(level,currentXP,maxXP,exhaustion)
	if not (currentXP and maxXP) then return 0,0,0,0,0 end
	if level>=MAX_PLAYER_LEVEL then return 0,0,-1; end
	local xpOverLevelup,percentCurrentXP,percentExhaustion = (currentXP+exhaustion)-maxXP,currentXP/maxXP,0;
	if xpOverLevelup>0 then
		percentExhaustion = (xpOverLevelup/xp2levelup[level+1]) + 1;
		if percentExhaustion>2 then
			percentExhaustion=2;
		end
	else
		percentExhaustion = (currentXP+exhaustion)/maxXP;
	end
	-- <needToLevelup>, <percentCurrentXP>, <percentExhaustion>, <percentCurrentXPStr>, <percentExhaustionStr>
	return maxXP-currentXP, percentCurrentXP, percentExhaustion, ("%1.2f%%"):format(percentCurrentXP*100) or UNKNOWN, (">%1.2f%%"):format(percentExhaustion*100);
end

local function deleteCharacterXP(self,name_realm)
	Broker_Everything_CharacterDB[name_realm].xp = nil;
	createTooltip(tt);
end

-- UnitChromieTimeID(unitToken) -- return number value but not corresponding with _G.EXPANSION_NAME%d
local chromieTimeExpansions = {}
local function updateChromieTime()
	chromieTimeExpansions.list = false
	chromieTimeExpansions.current = false;
	-- check if available for current character. Too low or too high level?
	if not (C_PlayerInfo.CanPlayerEnterChromieTime and C_ChromieTime) then
		chromieTimeExpansions.current = -1 -- wrong client for cromie time
		return false;
	end
	if not C_PlayerInfo.CanPlayerEnterChromieTime() then
		chromieTimeExpansions.current = -2 -- player is out of required level range
		return false;
	end
	-- get list of expansion options
	local tmp = C_ChromieTime.GetChromieTimeExpansionOptions();
	if not tmp then -- failed?
		chromieTimeExpansions.current = -3; -- get data failed
		return false;
	end
	for i, v in pairs(tmp)do
		v.exp = chromieTimePreviewAtlasToExpansionIndex[v.previewAtlas:lower():gsub("chromietime%-portrait%-small%-","")];
		if v.alreadyOn then
			chromieTimeExpansions.current = v;
			-- alternative: C_ChromieTime.GetChromieTimeExpansionOption(UnitChromieTimeID(unitToken));
			-- unitToken is limited to player and party1-4
			-- seen in Interface\AddOns\Blizzard_FrameXMLUtil\PartyUtil.lua
		end
	end
	chromieTimeExpansions.list = tmp;
	return true;
end

local function chromieTimeSortByExp(a,b)
	return a.exp < b.exp;
end

local function updateBroker()
	local text,level = L[name],UnitLevel("player");
	local needToLevelup, percentCurrentXP, percentExhaustion, percentCurrentXPStr, percentExhaustionStr = GetExperience(level,data.cur,data.max,data.rest);

	-- broker button text
	if (MAX_PLAYER_LEVEL~=sessionStartLevel) and (MAX_PLAYER_LEVEL==level) then
		text = C("ltblue",L["Max. Level reached"]);
	elseif (MAX_PLAYER_LEVEL==level) then
		-- nothing
	elseif IsXPUserDisabled and IsXPUserDisabled() then
		text = C("orange",L["XP gain disabled"])
	elseif ns.profile[name].display == "1" then
		text = percentCurrentXPStr;
	elseif ns.profile[name].display == "2" then
		text = ns.FormatLargeNumber(name,data.cur).."/"..ns.FormatLargeNumber(name,data.max);
	elseif ns.profile[name].display == "3" then
		text = ns.FormatLargeNumber(name,needToLevelup);
	elseif ns.profile[name].display == "4" then
		text = percentCurrentXPStr;
		if percentExhaustionStr then
			text = text .. " ("..percentExhaustionStr..")";
		end
	elseif ns.profile[name].display == "5" then
		if percentExhaustion>1 then
			percentExhaustion = 1;
		end
		text = ns.textBar(ns.profile[name].textBarCharCount,{1,percentCurrentXP or 1,ns.round(percentExhaustion-percentCurrentXP)},{"gray2","violet","ltblue"},ns.profile[name].textBarCharacter);
	end

	if level<MAX_PLAYER_LEVEL and ns.profile[name].chromieTimeBroker and updateChromieTime() then
		local current = NONE;
		for _, entry in ipairs(chromieTimeExpansions.list) do
			if entry.alreadyOn then
				current = entry.name;
				break;
			end
		end
		text = text .. ", " .. current;
	end

	(module.obj or ns.LDB:GetDataObjectByName(module.ldbName) or {}).text = text;
end

function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	if (IsXPUserDisabled and IsXPUserDisabled()) then
		tt:AddHeader(C("orange",L["XP gain disabled"]));
	else
		tt:AddHeader(C("dkyellow",XP));
	end

	local level = UnitLevel("player");

	if level<MAX_PLAYER_LEVEL then
		tt:AddSeparator();
		local needToLevelup, percentCurrentXP, percentExhaustion, percentCurrentXPStr, percentExhaustionStr = GetExperience(level,data.cur,data.max,data.rest);
		tt:AddLine(C("ltyellow",POWER_TYPE_EXPERIENCE),"",C("white",("%s/%s"):format(ns.FormatLargeNumber(name,data.cur,true),ns.FormatLargeNumber(name,data.max,true))));
		tt:AddLine(C("ltyellow",POWER_TYPE_EXPERIENCE.." ("..STATUS_TEXT_PERCENT..")"), "",percentCurrentXPStr);
		tt:AddLine(C("ltyellow",GARRISON_FOLLOWER_XP_STRING),"",C("white",ns.FormatLargeNumber(name,data.max-data.cur,true)));
		if percentExhaustionStr then
			tt:AddLine(C("ltyellow",TUTORIAL_TITLE26),"",C("cyan",percentExhaustionStr));
		end

		if ns.profile[name].chromieTimeTooltip then
			local available = updateChromieTime();
			if ns.profile[name].chromieTimeTooltipLong and available then
				--
				tt:AddSeparator(4,0,0,0,0)
				tt:AddLine(C("ltblue",CHROMIE_TIME_PREVIEW_CARD_DEFAULT_TITLE))
				tt:AddSeparator();
				if type(chromieTimeExpansions)=="table" then
					table.sort(chromieTimeExpansions,chromieTimeSortByExp);
					for i,entry in pairs(chromieTimeExpansions.list) do
						local n = _G["EXPANSION_NAME"..entry.exp] or entry.name; -- failsave for next expansion ;-)
						local l = tt:AddLine(C(entry.alreadyOn and "ltgreen" or "ltyellow", n))
						if entry.alreadyOn then
							tt:SetCell(l, 2, C("ltgreen",SPEC_ACTIVE), nil,"RIGHT", 0)
							tt:SetLineColor(l, 1, 1, 1,.45);
						end
					end
				end
			elseif available then
				local l = tt:AddLine(C("ltyellow",CHROMIE_TIME_PREVIEW_CARD_DEFAULT_TITLE))
				local current = chromieTimeExpansions.current;
				if current then
					tt:SetCell(l, 2, C("ltgreen",_G["EXPANSION_NAME"..current.exp] or current.name), nil, "RIGHT", 0)
				else
					tt:SetCell(l, 2, C("ltgray",NONE), nil, "RIGHT", 0)
				end
			else
				tt:AddSeparator(4,0,0,0,0)
				tt:AddLine(CHROMIE_TIME_PREVIEW_CARD_DEFAULT_TITLE)
				tt:AddSeparator();
				tt:AddLine(L["XPChromieTimeNotAvailable"])
			end
		end

	end

	if ns.profile[name].showMyOtherChars then
		tt:AddSeparator(4,0,0,0,0);
		local l = tt:AddLine();
		local showFactions = (ns.profile[name].showAllFactions and L["AllFactions"]) or ns.player.factionL;
		tt:SetCell(l,1,C("ltblue",L["Your other chars (%s)"]:format(ns.showCharsFrom_Values[ns.profile[name].showCharsFrom].."/"..showFactions)),nil,nil,3);
		tt:AddSeparator();
		local count = 0;

		for i,toonNameRealm,toonName,toonRealm,toonData,isCurrent in ns.pairsToons(name,{currentFirst=true,forceSameRealm=true}) do
			if toonData.xp~=nil and not isCurrent and not (ns.profile[name].showNonMaxLevelOnly and toonData.level==MAX_PLAYER_LEVEL) then
				if type(toonRealm)=="string" and toonRealm:len()>0 then
					local _,_realm = ns.LRI:GetRealmInfo(toonRealm,ns.region);
					if _realm then toonRealm = _realm; end
				end

				local factionSymbol = "";
				if toonData.faction and toonData.faction~="Neutral" then
					factionSymbol = ns.factionIcon(toonData.faction,16,16);
				end

				toonData.level = toonData.level or 1;
				local _, _, percentExhaustion, percentCurrentXPStr, percentExhaustionStr = GetExperience(toonData.level,toonData.xp.cur or 0,toonData.xp.max or xp2levelup[toonData.level],toonData.xp.rest or 0);

				local restState = "";
				if percentExhaustion>0 then
					restState = " "..C("cyan",percentExhaustionStr.."~");
				end

				local l = tt:AddLine(
					("(%d) %s %s"):format(toonData.level,C(toonData.class,ns.scm(toonName))..ns.showRealmName(name,toonRealm), factionSymbol),
					(percentCurrentXPStr or 0)..restState,
					("%s/%s"):format(ns.FormatLargeNumber(name,toonData.xp.cur,true),ns.FormatLargeNumber(name,toonData.xp.max,true))
				);
				tt:SetLineScript(l,"OnMouseUp",deleteCharacterXP, toonNameRealm);
				count = count + 1;
			end
		end
		if (count==0) then
			local l = tt:AddLine();
			tt:SetCell(l,1,L["No data found"],nil,nil,3);
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		if (ns.profile[name].showMyOtherChars) then
			ns.AddSpannedLine(tt,C("ltblue",L["MouseBtn"]).." || "..C("green",L["Delete a character from the list"]));
		end
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"PLAYER_LOGOUT",
		"PLAYER_XP_UPDATE",
		"DISABLE_XP_GAIN",
		"ENABLE_XP_GAIN",
		"UNIT_INVENTORY_CHANGED"
	},
	config_defaults = {
		enabled = false,
		display = "1",
		showMyOtherChars = true,
		showNonMaxLevelOnly = false,
		textBarCharacter = "=",
		textBarCharCount = 20,

		chromieTimeBroker = true,
		chromieTimeTooltip = true,
		chromieTimeTooltipLong = true,

		showAllFactions=true,
		showRealmNames=true,
		showCharsFrom="2"
	},
	clickOptionsRename = {
		["switch"] = "1_switch_mode",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["switch"] = {"Switch (percent, absolute, til next and more)","module","switch"}, -- L["Switch (percent, absolute, til next and more)"]
		["menu"] = "OptionMenu"
	}
};

if ns.IsClassicClient() then
	module.config_defaults.chromieTimeBroker = false
	module.config_defaults.chromieTimeTooltip = false
	module.config_defaults.chromieTimeTooltipLong = false
end

ns.ClickOpts.addDefaults(module,{
	switch = "_LEFT",
	menu = "_RIGHT"
});

function module.switch(self)
	local cur = tonumber(ns.profile[name].display);
	local new = cur==5 and 1 or cur+1;
	ns.profile[name].display = tostring(new);
	module.onevent(self)
end

function module.options()
	local textBarValues,displayValues = {},{
		["1"]=STATUS_TEXT_PERCENT.." \"77%\"",
		["2"]=L["Absolute value"].." \"1234/4567\"",
		["3"]=L["Til next level"].." \"1242\"",
		["4"]=STATUS_TEXT_PERCENT.." + Resting \"77% (>94%)\"",
		["5"]=L["TextBar"]
	};
	-- add values to config.textBarCharacter
	for _,v in ipairs(textbarSigns)do
		textBarValues[v]=v;
	end
	return 	{
		broker = {
			order=1,
			display={ type="select", order=1, name=L["Display XP in broker"], desc=L["Select to show XP as an absolute value; Deselected will show it as a percentage."], values=displayValues, width="double" },
			chromieTimeBroker = { type="toggle", order=2, name=L["XPChromieTimeShow"], desc=L["XPChromieTimeBrokerDesc"], hidden=ns.IsClassicClient }
		},
		broker2 = {
			order=2,
			name = L["TextBar"],
			textBarInfo      = { type="description", order=1, name=L["TextBarDesc"],   fontSize="medium" },
			textBarCharacter = { type="select",      order=2, name=L["TextBarChar"], desc=L["TextBarCharDesc"], values=textBarValues },
			textBarCharCount = { type="range",       order=3, name=L["TextBarNum"], desc=L["TextBarNumDesc"], min=5, max=200, step=1 }
		},
		tooltip = {
			order=3,
			chromieTimeTooltip = { type="toggle", order=1, name=L["XPChromieTimeShow"], desc=L["XPChromieTimeTooltipDesc"], hidden=ns.IsClassicClient },
			chromieTimeTooltipLong = { type="toggle", order=2, name=L["XPChromieTimeTooltipLong"], desc=L["XPChromieTimeTooltipLongDesc"], hidden=ns.IsClassicClient },
			showMyOtherChars={ type="toggle", order=3, name=L["Show other chars xp"], desc=L["Display a list of my chars on same realm with her level and xp"] },
			showNonMaxLevelOnly={ type="toggle", order=4, name=L["Hide characters at maximum level"], desc=L["Hide all characters who have reached the level cap."] },
			showAllFactions=5,
			showRealmNames=6,
			showCharsFrom=7
		},
		misc = {
			order=4,
			shortNumbers=true
		},
	}, {
		display = true
	}
end

function module.init()
	-- gametables/xp.txt
	if WOW_PROJECT_ID==WOW_PROJECT_CLASSIC then
		xp2levelup = {
			   400,    900,   1400,   2100,   2800,   3800,   5000,   6400,   8100,   9240, --   1- 10
			 10780,  13225,  16800,  20375,  24440,  28080,  31500,  34800,  38550,  42315, --  11- 20
			 46560,  49440,  52000,  55040,  58400,  61120,  64160,  66880,  71680,  76160, --  21- 30
			 81440,  85600,  90240,  94560,  99200, 104160, 108480, 113280, 117920, 133980, --  31- 40
			139300, 144620, 149800, 155120, 160580, 165900, 171360, 176820, 182280, 188020, --  41- 50
			193620, 199360, 205100, 210700, 216580, 222460, 228480, 234220, 240380, 254000, --  51- 60
		}
	elseif WOW_PROJECT_ID==WOW_PROJECT_MISTS_CLASSIC then
		xp2levelup = {
			   400,    900,   1400,   2100,   2800,   3800,   5000,   6400,   8100,   9240, --   1- 10
			 10780,  13225,  16800,  20375,  24440,  28080,  31500,  34800,  38550,  42315, --  11- 20
			 46560,  49440,  52000,  55040,  58400,  61120,  64160,  66880,  71680,  76160, --  21- 30
			 81440,  85600,  90240,  94560,  99200, 104160, 108480, 113280, 117920, 133980, --  31- 40
			139300, 144620, 149800, 155120, 160580, 165900, 171360, 176820, 182280, 188020, --  41- 50
			193620, 199360, 205100, 210700, 216580, 222460, 228480, 234220, 240380, 254000, --  51- 60
			275000, 301000, 328000, 359000, 367000, 374000, 381000, 388000, 395000, 405000, --  61- 70
			415000, 422000, 427000, 432000, 438000, 445000, 455000, 462000, 474000, 482000, --  71- 80
			487000, 492000, 497000, 506000, 517000, 545000, 550000, 556000, 562000, 596000, --  81- 90
		}
	else
		xp2levelup = {
			    250,    655,   1245,   2025,   2995,   4155,   5505,   7040,   8770,    10590, --  1-10
			  11685,  12795,  13920,  15055,  16210,  17380,  18560,  19755,  20970,    22195, -- 11-20
			  23435,  24690,  25960,  27245,  28545,  29860,  31190,  32535,  33890,    32075, -- 21-30
			  32700,  33295,  33865,  34410,  34925,  35415,  35875,  36310,  36720,    37100, -- 31-40
			  37450,  37780,  38075,  38350,  38595,  38810,  39000,  39165,  39300,    40435, -- 41-50
			  41590,  42750,  43930,  45120,  46325,  47545,  48775,  50020,  51280,    52555, -- 51-60
			  53840,  55140,  56455,  57780,  59120,  60475,  61845,  63225,  64620,    58645, -- 61-70
			  60335,  62045,  63780,  65540,  67325,  69130,  70965,  72820,  74700,   302795, -- 71-80
			 317540, 332545, 347805, 363320, 379095, 395120, 411405, 427940, 444735, 99999999, -- 81-90
		};
	end
	if ns.toon.xp==nil then
		ns.toon.xp={};
	end
end

local function OnEventUpdateXP()
	local level = UnitLevel("player");
	if MAX_PLAYER_LEVEL==level then
		data = {
			cur=1,
			max=1,
			rest=0,
			logoutTime=0,
			isResting=false,
			bonus={}
		};
	else
		data = {
			cur = UnitXP("player") or 0,
			max = UnitXPMax("player") or 0,
			rest = GetXPExhaustion() or 0,
			logoutTime=0,
			isResting=false,
			bonus = {}
		}
	end
	ns.toon.xp = data;
	updateBroker();
	triggerLocked = false
end

function module.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" and msg and msg:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGOUT" then
		ns.toon.xp.logoutTime = time();
		ns.toon.xp.isResting = IsResting();
	elseif ns.eventPlayerEnteredWorld and not (event=="UNIT_INVENTORY_CHANGED" and msg~="player") and not triggerLocked then
		triggerLocked = true
		C_Timer.After(0.314159,OnEventUpdateXP);
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
