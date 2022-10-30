
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "XP" -- XP L["ModDesc-XP"]
local ttName, ttName2, ttColumns, tt, tt2, module, createTooltip,init  = name.."TT", name.."TT2", 3;
local data = {};
local sessionStartLevel = UnitLevel("player");
local slots,heirloomXP,xp2levelup = {[1]=HEADSLOT, [3]=SHOULDERSLOT, [5]=CHESTSLOT, [7]=LEGSSLOT, [15]=BACKSLOT, [11]=FINGER0SLOT, [12]=FINGER1SLOT};
local textbarSigns = {"=","-","#","||","/","\\","+",">","•","⁄"};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\ability_dualwield",coords={0.05,0.95,0.05,0.95}}; --IconName::XP--


-- some local functions --
--------------------------
local function CalcRestedXP(data)
	-- https://wow.gamepedia.com/Rest
	local p5 = data.max*0.05;
	local p5perHours = 32; -- 32 hours for 5 percent rested xp earning outside from inn and cities
	if data.isRested then
		p5perHours = 8; -- inn and cities
	end
	local restedXpPerSec = p5 / (p5perHours * 3600);
	local offlineRested = math.floor((time()-data.offlineTime) * restedXpPerSec);
	local maxRested = p5*30;
	if offlineRested>=maxRested then
		offlineRested = maxRested; -- rested xp limit
	end
	data.offlineRested = offlineRested;
end

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
	return maxXP-currentXP, percentCurrentXP, percentExhaustion, ("%1.2f%%"):format(percentCurrentXP*100), (">%1.2f%%"):format(percentExhaustion*100);
end

local function deleteCharacterXP(self,name_realm)
	Broker_Everything_CharacterDB[name_realm].xp = nil;
	createTooltip(tt);
end

local function showThisChar(name_realm,data)
	if name_realm==ns.player.name_realm or data.xp==nil or (ns.profile[name].showNonMaxLevelOnly and data.level==MAX_PLAYER_LEVEL) then
		return false;
	end
	local _,realm = strsplit("-",name_realm,2);
	return ns.showThisChar(name,realm,data.faction);
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
		text = percentCurrentXPStr.." ("..percentExhaustionStr..")";
	elseif ns.profile[name].display == "5" then
		if percentExhaustion>1 then
			percentExhaustion = 1;
		end
		text = ns.textBar(ns.profile[name].textBarCharCount,{1,percentCurrentXP or 1,ns.round(percentExhaustion-percentCurrentXP)},{"gray2","violet","ltblue"},ns.profile[name].textBarCharacter);
	end
	(module.obj or ns.LDB:GetDataObjectByName(module.ldbName) or {}).text = text;
end

local function createTooltip2(parentLine,name_realm) -- DEPRECATED
	local toon = Broker_Everything_CharacterDB[name_realm];

	local lst,sum = {},0;
	for slotId,slotName in ns.pairsByKeys(slots) do
		local maxLevel,xpPercent,_ = 0,0;
		if toon.xp.bonus[slotId] then
			if tonumber(toon.xp.bonus[slotId]) then
				local itemId=toon.xp.bonus[slotId];
				_, _, _, _, _, _, _, _, _, maxLevel = C_Heirloom.GetHeirloomInfo(itemId);
				if not maxLevel then
					C_Timer.After(0.1,function()
						createTooltip2(parentLine,name_realm); -- sometimes blizzard api return nil; retry it
					end);
				end
				xpPercent = heirloomXP[itemId];
			elseif type(toon.xp.bonus[slotId])=="table" then
				-- deprecated type
				maxLevel,xpPercent = toon.xp.bonus[slotId].maxLevel,toon.xp.bonus[slotId].percent;
			end
			sum = sum + xpPercent;
		end
		local row = {C("ltyellow",slotName)};
		if maxLevel and maxLevel>0 then
			tinsert(row,maxLevel);
		end
		tinsert(row,
			(toon.xp.bonus[slotId]==nil and C("ltgray",L["Not equipped"]))
				or (maxLevel and toon.level>maxLevel and C("red",L["Level too high"]))
				or (xpPercent>0 and xpPercent.."%")
				or ""
		);
		tinsert(lst,row);
	end

	tt2 = ns.acquireTooltip({ttName2.."_"..name_realm, 3, "LEFT", "RIGHT", "RIGHT"},{true},{parentLine,"horizontal",tt});
	tt2:Clear();
	tt2:AddLine(C("ltblue",L["XP bonus"]),C("ltblue",L["max Level"]),C("ltblue",L["XP bonus"]));
	tt2:AddSeparator(1);
	for i,row in ipairs(lst) do
		if #row==3 then
			tt2:AddLine(unpack(row));
		else
			local l=tt2:AddLine(row[1]);
			tt2:SetCell(l,2,row[2],nil,"RIGHT",0);
		end
	end
	tt2:AddSeparator();
	tt2:AddLine(C("ltblue",ACHIEVEMENT_SUMMARY_CATEGORY),"",C(sum>0 and "green" or "gray",sum.."%"));

	ns.roundupTooltip(tt2);
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
		tt:AddLine(C("ltyellow",TUTORIAL_TITLE26),"",C("cyan",percentExhaustionStr));
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
				local Name,Realm,_ = strsplit("-",toonNameRealm,2);

				if type(toonRealm)=="string" and toonRealm:len()>0 then
					local _,_realm = ns.LRI:GetRealmInfo(toonRealm,ns.region);
					if _realm then toonRealm = _realm; end
				end

				local factionSymbol = "";
				if toonData.faction and toonData.faction~="Neutral" then
					factionSymbol = "|TInterface\\PVPFrame\\PVP-Currency-"..toonData.faction..":16:16:0:-1:16:16:0:16:0:16|t";
				end

				toonData.level = toonData.level or 1;
				local needToLevelup, percentCurrentXP, percentExhaustion, percentCurrentXPStr, percentExhaustionStr = GetExperience(toonData.level,toonData.xp.cur or 0,toonData.xp.max or xp2levelup[toonData.level],toonData.xp.rest or 0);

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
				--tt:SetLineScript(l,"OnEnter",createTooltip2,toonNameRealm);
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

	if ns.client_version<4 then
		xp2levelup = {
			-- classic client
			    400,    900,   1400,   2100,   2800,   3600,   4500,   5400,   6500,   7600, --   1-10
			   8700,   9800,  11000,  12300,  13600,  15000,  16400,  17800,  19300,  20800, --  11-20
			  22400,  24000,  25500,  27200,  28900,  30500,  32200,  33900,  36300,  38800, --  21-30
			  41600,  44600,  48000,  51400,  55000,  58700,  62400,  66200,  70200,  74300, --  31-40
			  78500,  82800,  87100,  91600,  96300, 101000, 105800, 110700, 115700, 120900, --  41-50
			 126100, 131500, 137000, 142500, 148200, 154000, 159900, 165800, 172000, 494000, --  51-60
			-- bc classic
			 574700, 614400, 650300, 682300, 710200, 734100, 753700, 768900, 779700,1523800, --  61-70
			-- wotlk classic
			1539000,1555700,1571800,1587900,1604200,1620700,1637400,1653900,1670800,9999999 --
		}
	elseif ns.client_version<3 then
		xp2levelup = {
			-- classic client
			   400,   900,  1400,  2100,  2800,  3600,  4500,  5400,  6500,  7600, --   1-10
			  8800, 10100, 11400, 12900, 14400, 16000, 17700, 19400, 21300, 23200, --  11-20
			 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400, --  21-30
			 50800, 54500, 58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700, --  31-40
			 95800,101000,106300,111800,117500,123200,129100,135100,141200,147500, --  41-50
			153900,160400,167100,173900,180800,187900,195000,202300,209800,494000, --  51-60
			-- bc classic
			574700,614400,650300,682300,710200,734100,753700,768900,779700,999999, --  61-70
		}
	else -- retail
		if ns.client_version>=10.02 then
			-- build 45969 (df beta)
			xp2levelup = {
				   250,   590,  1065,  1675,  2420,  3305,  4325,  5485,  6775,    8205, --  1-10
				  9765, 11030, 12360, 13755, 15220, 16750, 18345, 20005, 21730,   23525, -- 11-20
				 25385, 27310, 29305, 31365, 33490, 35680, 37935, 40260, 42650,   45105, -- 21-30
				 45590, 46005, 46360, 46655, 46880, 47045, 47145, 47185, 47160,   47070, -- 31-40
				 46915, 46700, 46420, 46075, 45670, 45200, 44670, 44070, 43410,   42690, -- 41-50
				 47565, 52600, 57785, 63135, 68635, 74295, 80110, 86085, 92215,  194815, -- 51-60
				214540,234805,255610,276945,298820,321235,344185,367675,391700,99999999  -- 61-70
			}
		else
			-- build 44649 (df prepatch)
			xp2levelup = {
				   250,   595,  1085,  1715,  2485,  3405,  4460,  5660,  7005,    8490, --  1-10
				  9765, 11015, 12325, 13705, 15145, 16645, 18215, 19845, 21540,   23300, -- 11-20
				 25125, 27010, 28960, 30975, 33055, 35195, 37400, 39670, 42005,   45370, -- 21-30
				 45855, 46275, 46635, 46925, 47155, 47320, 47425, 47460, 47435,   47345, -- 31-40
				 47190, 46975, 46695, 46350, 45940, 45465, 44930, 44330, 43665,   42940, -- 41-50
				 47845, 52905, 58125, 63505, 69040, 74730, 80580, 86590, 92755,  170680, -- 51-60
				205795,242940,282165,323515,367035,412775,460785,511105,563785,99999999  -- 61-70
			}
		end
		--[[
		xp2levelup = {
			   250,   655,  1265,  2085, 3240,   4125,  4785,  5865,  7275,  8205, --  1-10
			  9365, 10715, 12085, 13455, 14810, 16135, 17415, 18635, 19775, 20825, -- 11-20
			 22295, 23745, 25170, 26550, 27885, 30140, 32480, 34910, 37425, 40675, -- 21-30
			 44100, 47705, 51490, 55460, 59625, 63985, 68545, 73305, 78280, 83460, -- 31-40
			 88860, 94485,100330,106405,112715,119265,129995,139665,154075,178215, -- 41-50
			209480,242790,278190,315745,355500,397520,441860,488565,537700,999999, -- 51-60
		};
		]]
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
