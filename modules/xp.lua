
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I

--#- rest xp improvements...
--#- heirloom updaten
--#- finde einen besseren weg, die max. upgrade stufe von erbstücken zu ermitteln...

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
	if level>=MAX_PLAYER_LEVEL then return 0,0,"n/a"; end
	local xpOverLevelup,percentCurrentXP = (currentXP+exhaustion)-maxXP,currentXP/maxXP,0;
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

local function createTooltip2(parentLine,name_realm)
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
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

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

		tt:AddSeparator(5,0,0,0,0);
		tt:AddLine(C("ltblue",L["XP bonus"]),C("ltblue",L["max Level"]),C("ltblue",L["XP bonus"]));
		tt:AddSeparator();
		local sum = 0;
		for slotId,slotName in ns.pairsByKeys(slots) do
			local v,maxLevel,xpPercent = data.bonus[slotId],0,0;
			if tonumber(v) then
				_, _, _, _, _, _, _, _, _, maxLevel = C_Heirloom.GetHeirloomInfo(v);
				xpPercent = heirloomXP[v];
			elseif type(v)=="table" then
				maxLevel,xpPercent = v.maxLevel,v.percent;
			end
			sum = sum + xpPercent;
			tt:AddLine(C("ltyellow", slotName),maxLevel>0 and maxLevel or "",(maxLevel==0 and C("ltgray",L["Not equipped"])) or (level>maxLevel and C("red",L["Level too high"])) or (xpPercent>0 and xpPercent.."%") or "");
		end
		tt:AddSeparator();
		tt:AddLine(C("ltblue",ACHIEVEMENT_SUMMARY_CATEGORY),"",C(sum>0 and "green" or "gray",sum.."%"));
	end

	if ns.profile[name].showMyOtherChars then
		tt:AddSeparator(4,0,0,0,0);
		local l = tt:AddLine();
		local showFactions = (ns.profile[name].showAllFactions and L["AllFactions"]) or ns.player.factionL;
		tt:SetCell(l,1,C("ltblue",L["Your other chars (%s)"]:format(ns.showCharsFrom_Values[ns.profile[name].showCharsFrom].."/"..showFactions)),nil,nil,3);
		tt:AddSeparator();
		local count = 0;
		for i=1, #Broker_Everything_CharacterDB.order do
			local name_realm = Broker_Everything_CharacterDB.order[i];
			local v = Broker_Everything_CharacterDB[name_realm];
			if v.xp and v.xp.bonus then --- little cleanup outdated boolean usage
				for slotId, slot in pairs(v.xp.bonus)do
					if slotId>900 then
						v.xp.bonus[slotId] = nil; -- remove deprecated entries
					elseif type(slot)=="table" and (slot.percent==nil or slot.percent==false) then
						v.xp.bonus[slotId]=nil;
					end
				end
				if v.xp.bonusSum then
					v.xp.bonusSum = nil;
				end
			end
			if showThisChar(name_realm,v) then
				local Name,Realm,_ = strsplit("-",name_realm,2);
				if type(Realm)=="string" and Realm:len()>0 then
					local _,_realm = ns.LRI:GetRealmInfo(Realm);
					if _realm then Realm = _realm; end
				end
				local factionSymbol = "";
				if v.faction and v.faction~="Neutral" then
					factionSymbol = "|TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t";
				end

				local needToLevelup, percentCurrentXP, percentExhaustion, percentCurrentXPStr, percentExhaustionStr = GetExperience(v.level,v.xp.cur,v.xp.max,v.xp.rest);

				local restState = "";
				if percentExhaustion>0 then
					restState = " "..C("cyan",percentExhaustionStr.."~");
				end
				local l = tt:AddLine(
					("(%d) %s %s"):format(v.level,C(v.class,ns.scm(Name))..ns.showRealmName(name,Realm), factionSymbol),
					(percentCurrentXPStr or 0)..restState,
					("%s/%s"):format(ns.FormatLargeNumber(name,v.xp.cur,true),ns.FormatLargeNumber(name,v.xp.max,true))
				);
				tt:SetLineScript(l,"OnMouseUp",deleteCharacterXP, name_realm);
				tt:SetLineScript(l,"OnEnter",createTooltip2,name_realm);
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
	if ns.client_version>=2 then
		xp2levelup = {
			400,900,1400,2100,2800,3800,5000,6400,8100,9240,10780,13230,16800,20380,24440,28080,31500,34800,38550,41260,44230,45730,46800,49540,51830,53480,55340,
			56850,60030,62830,66170,68480,71060,73280,75640,78120,80000,82130,84020,86300,88840,91900,95110,98210,101460,104740,107890,111190,114520,117700,121040,
			124400,127600,130960,134330,137540,140900,144270,147470,152580,157120,161890,166730,171470,176450,184520,192840,201220,210030,219090,228200,237770,247600,
			257470,267840,278480,289150,300340,311810,323580,330950,338670,346490,354110,362100,370180,378050,386310,394650,406940,415510,424160,432590,441410,450330,
			459330,468420,477610,486550,492540,497060,501580,506100,510620,515140,519660,524180,528690,533210,537730,831000,837930,844850,851780,858700,865630,872550,
			879480,886400,893550
		};
		heirloomXP = {
			-- Head
			[61931] = 10, [61935] = 10, [61936] = 10, [61937] = 10, [61942] = 10, [61958] = 10, [69887] = 10,
			--- (new since wod 6.0)
			[127012] = 10, [122263] = 10, [122245] = 10, [122247] = 10, [122246] = 10, [122249] = 10, [122248] = 10, [122250] = 10,

			-- shoulder
			[42949] = 10, [42951] = 10, [42952] = 10, [42984] = 10, [42985] = 10, [44099] = 10, [44100] = 10,
			[44101] = 10, [44102] = 10, [44103] = 10, [44105] = 10, [44107] = 10, [69890] = 10, [93859] = 10,
			[93861] = 10, [93862] = 10, [93864] = 10, [93866] = 10, [93876] = 10, [93886] = 10, [93887] = 10,
			[93889] = 10, [93890] = 10, [93893] = 10, [93894] = 10,
			--- (new since wod 6.0)
			[122355] = 10, [122356] = 10, [122357] = 10, [122358] = 10, [122359] = 10, [122360] = 10, [122372] = 10,
			[122375] = 10, [122376] = 10, [122377] = 10, [122378] = 10, [122388] = 10, [122373] = 10, [122374] = 10,

			-- chest
			[48677] = 10, [48683] = 10, [48685] = 10, [48687] = 10, [48689] = 10, [48691] = 10, [69889] = 10,
			[93860] = 10, [93863] = 10, [93865] = 10, [93885] = 10, [93888] = 10, [93891] = 10, [93892] = 10,
			--- (new since wod 6.0)
			[122384] = 10, [122382] = 10, [122383] = 10, [122379] = 10, [122380] = 10, [122381] = 10, [122387] = 10, [127010] = 10,

			-- legs
			[62029] = 10, [62026] = 10, [62027] = 10, [62024] = 10, [62025] = 10, [62023] = 10, [69888] = 10,
			--- (new since wod 6.0)
			[122256] = 10, [122254] = 10, [122255] = 10, [122252] = 10, [122253] = 10, [122251] = 10, [122264] = 10, [127011] = 10,

			-- backs
			[62038] = 5, [62039] = 5, [62040] = 5, [69892] = 5,
			--- (new since wod 6.0)
			[122260] = 5, [122261] = 5, [122262] = 5, [122266] = 5,
			--- {new since bfa 8.1}
			[166770] = 5, [166752] = 5,

			-- rings
			[50255] = 5, [122529] = 5,
			--- (new since wod 6.0)
			[128169] = 5, [128172] = 5, [128173] = 5,
		};
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
				cur = UnitXP("player"),
				max = UnitXPMax("player"),
				rest = GetXPExhaustion() or 0,
				logoutTime=0,
				isResting=false,
				bonus = {}
			}

			--- Bonus by inventory items
			if ns.client_version>=2 then
				for slotId,slotName in pairs(slots) do
					local itemId = GetInventoryItemID("player",slotId);
					if itemId and C_Heirloom.IsItemHeirloom(itemId) and heirloomXP[itemId] then
						data.bonus[slotId] = itemId;
					end
				end
			end
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
