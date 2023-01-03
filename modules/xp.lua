
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


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\ability_dualwield",coords={0.05,0.95,0.05,0.95}}; --IconName::XP--


-- some local functions --
--------------------------
local function GetExperience(level,currentXP,maxXP,exhaustion)
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
					factionSymbol = "|TInterface\\PVPFrame\\PVP-Currency-"..toonData.faction..":16:16:0:-1:16:16:0:16:0:16|t";
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
			showMyOtherChars={ type="toggle", order=1, name=L["Show other chars xp"], desc=L["Display a list of my chars on same realm with her level and xp"] },
			showNonMaxLevelOnly={ type="toggle", order=2, name=L["Hide characters at maximum level"], desc=L["Hide all characters who have reached the level cap."] },
			showAllFactions=3,
			showRealmNames=4,
			showCharsFrom=5
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
	-- https://wow.tools/files/#search=gametables/xp.txt

	if WOW_PROJECT_ID==WOW_PROJECT_MAINLINE then
		-- from build 45969 (df beta)
		xp2levelup = {
			   250,   590,  1065,  1675,  2420,  3305,  4325,  5485,  6775,    8205, --  1-10
			  9765, 11030, 12360, 13755, 15220, 16750, 18345, 20005, 21730,   23525, -- 11-20
			 25385, 27310, 29305, 31365, 33490, 35680, 37935, 40260, 42650,   45105, -- 21-30
			 45590, 46005, 46360, 46655, 46880, 47045, 47145, 47185, 47160,   47070, -- 31-40
			 46915, 46700, 46420, 46075, 45670, 45200, 44670, 44070, 43410,   42690, -- 41-50
			 47565, 52600, 57785, 63135, 68635, 74295, 80110, 86085, 92215,  194815, -- 51-60
			214540,234805,255610,276945,298820,321235,344185,367675,391700,99999999  -- 61-70
		}
	else -- classic
		xp2levelup = {
			   400,    900,   1400,   2100,   2800,   3800,   5000,   6400,   8100,   9240, --  1-10 // vanilla
			 10780,  13225,  16800,  20375,  24440,  28080,  31500,  34800,  38550,  42315, -- 11-20
			 46560,  49440,  52000,  55040,  58400,  61120,  64160,  66880,  71680,  76160, -- 21-30
			 81440,  85600,  90240,  94560,  99200, 104160, 108480, 113280, 117920, 133980, -- 31-40
			139300, 144620, 149800, 155120, 160580, 165900, 171360, 176820, 182280, 188020, -- 41-50
			193620, 199360, 205100, 210700, 216580, 222460, 228480, 234220, 240380, 254000, -- 51-60
			275000, 301000, 328000, 359000, 367000, 374000, 381000, 388000, 395000, 405000, -- 61-70 // bc
			415000, 422000, 427000, 432000, 438000, 445000, 455000, 462000, 474000, 482000, -- 71-80 // wotlk
			487000, 492000, 497000, 506000, 517000, 545000, 550000, 556000, 562000, 596000, -- 81-90 // cata
		}
	end
	if ns.toon.xp==nil then
		ns.toon.xp={};
	end
end

function module.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" and msg and msg:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGOUT" then
		ns.toon.xp.logoutTime = time();
		ns.toon.xp.isResting = IsResting();
	elseif ns.eventPlayerEnteredWorld and not (event=="UNIT_INVENTORY_CHANGED" and msg~="player") then
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
