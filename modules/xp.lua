
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "XP" -- XP
local ttName, ttName2, ttColumns, tt, tt2, module, createTooltip,init  = name.."TT", name.."TT2", 3;
local data = {};
local sessionStartLevel = UnitLevel("player");
local slots,items = {  [1]=HEADSLOT, [3]=SHOULDERSLOT, [5]=CHESTSLOT, [7]=LEGSSLOT, [15]=BACKSLOT, [11]=FINGER0SLOT, [12]=FINGER1SLOT, [998]=L["Guild perk"], [999]=L["Recruite a Friend"]};
local textbarSigns = {"=","-","#","||","/","\\","+",">","•","⁄"};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\ability_dualwield",coords={0.05,0.95,0.05,0.95}}; --IconName::XP--


-- some local functions --
--------------------------
local function deleteCharacterXP(self,name_realm)
	Broker_Everything_CharacterDB[name_realm].xp = nil;
	createTooltip(tt);
end

local function showThisChar(name_realm,data)
	if data.xp==nil then
		return false;
	end
	if ns.profile[name].showNonMaxLevelOnly and data.level==MAX_PLAYER_LEVEL then
		return false;
	end
	local _,realm = strsplit("-",name_realm,2);
	return ns.showThisChar(name,realm,data.faction);
end

local function updateBroker()
	local dataobj = module.obj or ns.LDB:GetDataObjectByName(module.ldbName);

	-- broker button text
	if (MAX_PLAYER_LEVEL~=sessionStartLevel) and (MAX_PLAYER_LEVEL==UnitLevel("player")) then
		dataobj.text = C("ltblue",L["Max. Level reached"]);
	elseif IsXPUserDisabled() then
		dataobj.text = C("orange",L["XP gain disabled"])
	elseif ns.profile[name].display == "1" then
		dataobj.text = data.percentStr;
	elseif ns.profile[name].display == "2" then
		dataobj.text = ns.FormatLargeNumber(name,data.cur).."/"..ns.FormatLargeNumber(name,data.max);
	elseif ns.profile[name].display == "3" then
		dataobj.text = ns.FormatLargeNumber(name,data.need);
	elseif ns.profile[name].display == "4" then
		dataobj.text = data.percentStr.." ("..data.restStr..")";
	elseif ns.profile[name].display == "5" then
		dataobj.text = ns.textBar(ns.profile[name].textBarCharCount,{1,data.percentCur or 1,data.percentRest-data.percentCur},{"gray2","violet","ltblue"},ns.profile[name].textBarCharacter);
	end
end

local function createTooltip2(parentLine,data)
	tt2 = ns.acquireTooltip({ttName2, 3, "LEFT", "RIGHT", "RIGHT"},{true},{parentLine,"horizontal",tt});

	tt2:Clear();

	tt2:AddLine(C("ltblue",L["XP bonus"]),C("ltblue",L["max Level"]),C("ltblue",L["XP bonus"]));
	tt2:AddSeparator(1);
	for slotId,slotName in ns.pairsByKeys(slots) do
		local v=data.bonus[slotId] or {};
		if(slotId==998)then
			tt2:AddLine(C("ltyellow",slotName),v.maxLevel or "",(v.percent) and v.percent.."%" or C("ltgray",ERR_GUILD_PLAYER_NOT_IN_GUILD));
		elseif(slotId==999)then
			-- ignore refer-a-friend
		else
			tt2:AddLine(
				C("ltyellow",slotName),
				v.maxLevel or "",
				(v.percent==nil and C("ltgray",L["Not equipped"])) or (v.outOfLevel==true and C("red",L["Out of level"])) or v.percent.."%"
			);
		end
	end
	tt2:AddSeparator();
	tt2:AddLine(C("ltblue",L["Summary"]),"",C(data.bonusSum>0 and "green" or "gray",data.bonusSum.."%"));

	ns.roundupTooltip(tt2);
end

function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	if (IsXPUserDisabled()) then
		tt:AddHeader(C("orange",L["XP gain disabled"]));
	else
		tt:AddHeader(C("dkyellow",XP));
	end

	if (UnitLevel("player")<MAX_PLAYER_LEVEL) then
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",POWER_TYPE_EXPERIENCE),"",C("white",("(%s/%s)"):format(ns.FormatLargeNumber(name,data.cur,true),ns.FormatLargeNumber(name,data.max,true))));
		tt:AddLine(C("ltyellow",POWER_TYPE_EXPERIENCE.." ("..L["Percent"]..")"), "",data.percentStr);
		tt:AddLine(C("ltyellow",GARRISON_FOLLOWER_XP_STRING),"",C("white",ns.FormatLargeNumber(name,data.need,true)));
		if (data.restStr) then
			tt:AddLine(C("ltyellow",L["Rest"]),"",C("cyan",data.restStr));
		end
	end

	if (UnitLevel("player")<MAX_PLAYER_LEVEL) and (#data.bonus>0) then
		tt:AddSeparator(5,0,0,0,0);
		tt:AddLine(C("ltblue",L["XP bonus"]),C("ltblue",L["max Level"]),C("ltblue",L["XP bonus"]));
		tt:AddSeparator();
		for slotId,slotName in ns.pairsByKeys(slots) do
			local v = data.bonus[slotId] or {};
			if(slotId==999)then
				if(v.percent)then
					tt:AddLine(C("ltyellow", slotName),"", v.percent.."%"); -- show only if active
				end
			elseif(slotId==998)then
				tt:AddLine(C("ltyellow", slotName),"", (v.percent==nil) and L["Not in a guild"] or v.percent.."%");
			else
				tt:AddLine(
					C("ltyellow", slotName),
					v.maxLevel or "",
					(v.percent==nil and C("ltgray",L["not equipped"])) or (v.outOfLevel==true and C("red",L["Out of Level"])) or v.percent.."%"
				);
			end
		end
		tt:AddSeparator();
		tt:AddLine(C("ltblue",L["Summary"]),"",C(data.bonusSum>0 and "green" or "gray",data.bonusSum.."%"));
	end

	if ns.profile[name].showMyOtherChars then
		tt:AddSeparator(4,0,0,0,0);
		local l = tt:AddLine();
		local showFactions = (ns.profile[name].showAllFactions and L["All factions"]) or ns.player.factionL;
		tt:SetCell(l,1,C("ltblue",L["Your other chars (%s)"]:format(ns.showCharsFrom_Values[ns.profile[name].showCharsFrom].."/"..showFactions)),nil,nil,3);
		tt:AddSeparator();
		local count = 0;
		for i=1, #Broker_Everything_CharacterDB.order do
			local name_realm = Broker_Everything_CharacterDB.order[i];
			local v = Broker_Everything_CharacterDB[name_realm];
			if(v.xp and v.xp.bonus)then --- little cleanup outdated boolean usage
				for slotId, slot in pairs(v.xp.bonus)do
					if( slot.percent==nil or slot.percent==false )then
						v.xp.bonus[slotId]=nil;
					end
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
				local restState = "";
				if v.xp.restStr then
					restState = " "..C("cyan",v.xp.restStr);
				end
				local l = tt:AddLine(
					("(%d) %s %s"):format(v.level,C(v.class,ns.scm(Name))..ns.showRealmName(name,Realm), factionSymbol),
					(v.xp.percentStr or 0)..restState,
					("(%s/%s)"):format(ns.FormatLargeNumber(name,v.xp.cur,true),ns.FormatLargeNumber(name,v.xp.max,true))
				);
				tt:SetLineScript(l,"OnMouseUp",deleteCharacterXP, name_realm);
				if (v.xp.bonus and #v.xp.bonus>0) then
					tt:SetLineScript(l,"OnEnter",createTooltip2,v.xp);
				end
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
		["1"]="Percent \"77%\"",
		["2"]="Absolute value \"1234/4567\"",
		["3"]="Til next level \"1242\"",
		["4"]="Percent + Resting \"77% (>94%)\"",
		["5"]="Little text bar"
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
			name = L["Text bar"],
			textBarInfo      = { type="description", order=1, name=L["Text bar is a simple row of colored characters act like status, reputation or xp bar but without textures."],   fontSize="medium" },
			textBarCharacter={ type="select", order=2, name=L["Text bar character"], desc=L["Choose character for little text bar"], values=textBarValues },
			textBarCharCount={ type="range", order=3, name=L["Text bar num characters"], desc=L["..."], min=5, max=200, step=1 }
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
	items = { -- Heirlooms with {<percent>,<maxLevel>}
		-- SoO Weapons
		[104399] = {0,100}, [104400] = {0,100}, [104401] = {0,100}, [104402] = {0,100}, [104403] = {0,100}, [104404] = {0,100}, [104405] = {0,100},
		[104406] = {0,100}, [104407] = {0,100}, [104408] = {0,100}, [104409] = {0,100}, [105670] = {0,100}, [105671] = {0,100}, [105672] = {0,100},
		[105673] = {0,100}, [105674] = {0,100}, [105675] = {0,100}, [105676] = {0,100}, [105677] = {0,100}, [105678] = {0,100}, [105679] = {0,100},
		[105680] = {0,100}, [105683] = {0,100}, [105684] = {0,100}, [105685] = {0,100}, [105686] = {0,100}, [105687] = {0,100}, [105688] = {0,100},
		[105689] = {0,100}, [105690] = {0,100}, [105691] = {0,100}, [105692] = {0,100}, [105693] = {0,100},

		-- Head
		[61931] = {10,85}, [61935] = {10,85}, [61936] = {10,85}, [61937] = {10,85}, [61942] = {10,85}, [61958] = {10,85}, [69887] = {10,85},
		--- (new since wod 6.0)
		[127012] = {10,100,1}, [122263] = {10,100,1}, [122245] = {10,100,1}, [122247] = {10,100,1}, [122246] = {10,100,1}, [122249] = {10,100,1}, [122248] = {10,100,1}, [122250] = {10,100,1},

		-- shoulder
		[42949] = {10,80}, [42951] = {10,80}, [42952] = {10,80}, [42984] = {10,80}, [42985] = {10,80}, [44099] = {10,80}, [44100] = {10,80},
		[44101] = {10,80}, [44102] = {10,80}, [44103] = {10,80}, [44105] = {10,80}, [44107] = {10,80}, [69890] = {10,80}, [93859] = {10,85},
		[93861] = {10,85}, [93862] = {10,85}, [93864] = {10,85}, [93866] = {10,85}, [93876] = {10,85}, [93886] = {10,85}, [93887] = {10,85},
		[93889] = {10,85}, [93890] = {10,85}, [93893] = {10,85}, [93894] = {10,85},
		--- (new since wod 6.0)
		[122355] = {10,100,1}, [122356] = {10,100,1}, [122357] = {10,100,1}, [122358] = {10,100,1}, [122359] = {10,100,1}, [122360] = {10,100,1}, [122372] = {10,100,1},
		[122375] = {10,100,1}, [122376] = {10,100,1}, [122377] = {10,100,1}, [122378] = {10,100,1}, [122388] = {10,100,1}, [122373] = {10,100,1}, [122374] = {10,100,1},

		-- chest
		[48677] = {10,80}, [48683] = {10,80}, [48685] = {10,80}, [48687] = {10,80}, [48689] = {10,80}, [48691] = {10,80}, [69889] = {10,80},
		[93860] = {10,85}, [93863] = {10,85}, [93865] = {10,85}, [93885] = {10,85}, [93888] = {10,85}, [93891] = {10,85}, [93892] = {10,85},
		--- (new since wod 6.0)
		[122384] = {10,100,1}, [122382] = {10,100,1}, [122383] = {10,100,1}, [122379] = {10,100,1}, [122380] = {10,100,1}, [122381] = {10,100,1}, [122387] = {10,100,1}, [127010] = {10,100,1},

		-- legs
		[62029] = {10,85}, [62026] = {10,85}, [62027] = {10,85}, [62024] = {10,85}, [62025] = {10,85}, [62023] = {10,85}, [69888] = {10,85},
		--- (new since wod 6.0)
		[122256] = {10,100,1}, [122254] = {10,100,1}, [122255] = {10,100,1}, [122252] = {10,100,1}, [122253] = {10,100,1}, [122251] = {10,100,1}, [122264] = {10,100,1}, [127011] = {10,100,1},

		-- backs
		[62038] = {5,85}, [62039] = {5,85}, [62040] = {5,85}, [69892] = {5,85},
		--- (new since wod 6.0)
		[122260] = {5,100,1}, [122261] = {5,100,1}, [122262] = {5,100,1}, [122266] = {5,100,1},

		-- rings
		[50255] = {5,80},
		--- (new since wod 6.0)
		[128169] = {5,100}, [128172] = {5,100}, [128173] = {5,100},
	};
	-- add values to config.textBarCharacter
	--for _,v in ipairs(textbarSigns)do
	--	module.config_broker[2].values[v]=v;
	--end
	if ns.toon.xp==nil then
		ns.toon.xp={};
	end
end

function module.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" and msg and msg:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif not (event=="UNIT_INVENTORY_CHANGED" and msg~="player") then
		if (MAX_PLAYER_LEVEL==UnitLevel("player")) then
			data = {cur=1,max=1,rest=0,need=0,percentCur=1,percentRest=1,percentStr="100%",restStr="n/a",bonus={},bonusSum=0};
		else
			data = {
				cur = UnitXP("player"),
				max = UnitXPMax("player"),
				rest = GetXPExhaustion() or 0,
			}
			data.need = data.max-data.cur;
			data.percentCur = ns.round(data.cur/data.max,2);
			local cur_rest = data.cur+data.rest;
			data.percentRest = (cur_rest>data.max) and 1 or ns.round(cur_rest/data.max,2);
			data.percentStr = math.floor(data.percentCur * 100).."%";
			data.restStr   = data.percentRest==1 and ">100%+" or ">"..("%1.2f%%"):format(data.percentRest*100);

			data.bonus     = {};
			data.bonusSum  = 0;

			--- Bonus by inventory items
			for slotId,slotName in pairs(slots) do
				local itemId = GetInventoryItemID("player",slotId);
				if itemId and items[itemId] then
					local _,_,_,_,_,_,_,_,_,_,_,_,_,_,upgrade = strsplit(":",GetInventoryItemLink("player",slotId));
					local maxLevel = items[itemId][2]; upgrade=tonumber(upgrade);
					if upgrade==0 then
						maxLevel = 60;
					elseif upgrade==582 then
						maxLevel = 90;
					elseif upgrade==583 then
						maxLevel = 100;
					elseif upgrade==3592 then
						maxLevel = 110;
					end
					data.bonus[slotId] = {percent=items[itemId][1], outOfLevel=(UnitLevel("player")>maxLevel) and true or nil, maxLevel=maxLevel};
				end
			end


			--- Bonus by Refer-A-Friend
			local count = 1;
			if IsInGroup() or IsInRaid() then
				local raf_boost = false;
				for i=1, GetNumGroupMembers() or 0 do
					local m = (IsInRaid() and "raid" or "party")..i;
					if UnitIsVisible(m) and IsReferAFriendLinked(m) then
						raf_boost = true;
						data.bonus[999] = {percent=300};
					end
				end
			end

			--- bonus summary
			for i,v in pairs(data.bonus)do
				if(v.percent and not v.outOfLevel)then
					data.bonusSum = data.bonusSum + v.percent;
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
