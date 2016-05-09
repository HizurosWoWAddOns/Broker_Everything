
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "XP" -- L["XP"]
local ldbName, ttName, ttName2 = name, name.."TT", name.."TT2";
local string = string
local tt,tooltip,tt2,createMenu,ttColumns
local data = {};
local sessionStartLevel = UnitLevel("player");
local slots = {  [1]=L["Head"], [3]=L["Shoulder"], [5]=L["Chest"], [7]=L["Legs"], [15]=L["Back"], [11]=L["Ring1"], [12]=L["Ring2"], [998]=L["Guild perk"], [999]=L["Recruite a Friend"]}
local items = { -- Heirlooms with {<percent>,<maxLevel>}
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
}


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\ability_dualwield",coords={0.05,0.95,0.05,0.95}}; --IconName::XP--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show your xp. Can be shown either as a percentage, or as values."]
ns.modules[name] = {
	desc = desc,
	events = {
		"PLAYER_XP_UPDATE",
		"PLAYER_LOGIN",
		"DISABLE_XP_GAIN",
		"ENABLE_XP_GAIN",
		"UNIT_INVENTORY_CHANGED"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		display = "1",
		showMyOtherChars = true,
		showNonMaxLevelOnly = false,
		showAllRealms = true
	},
	config_allowed = {
		display = {["1"]=true,["2"]=true,["3"]=true,["4"]=true}
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showMyOtherChars", label=L["Show other chars xp"], tooltip=L["Display a list of my chars on same realm with her level and xp"] },
		{ type="toggle", name="showNonMaxLevelOnly", label=L["Show non max. level characters only"], tooltip=L["Hide all characters who have reached the level cap."] },
		{ type="toggle", name="showAllRealms", label=L["Show all realms"], tooltip=L["Show characters from all realms in tooltip."] },
		{ type="select", name="display", label=L["Display XP in broker"], tooltip=L["Select to show XP as an absolute value; Deselected will show it as a percentage."],
			default="1",
			values={
				["1"]="Percent \"77%\"",
				["2"]="Absolute value \"1234/4567\"",
				["3"]="Til next level \"1242\"",
				["4"]="Percent + Resting \"77% (>94%)\""
			},
			event=true
		}
	},
	clickOptions = {
		["1_switch_mode"] = {
			cfg_label = "Switch mode",
			cfg_desc = " switch displayed xp data for characters under the level cap",
			cfg_default = "_RIGHT",
			hint = "Switch mode",
			func = function(self,button)
				local _mod=name;
				if (Broker_EverythingDB[name].display=="1") then
					Broker_EverythingDB[name].display = "2"
				elseif (Broker_EverythingDB[name].display=="2") then
					Broker_EverythingDB[name].display = "3"
				elseif (Broker_EverythingDB[name].display=="3") then
					Broker_EverythingDB[name].display = "4"
				elseif (Broker_EverythingDB[name].display=="4") then
					Broker_EverythingDB[name].display = "1"
				end
				ns.modules[name].onevent(self)
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "_LEFT",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self)
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function getTooltip2(parentLine,data)
	tt2 = ns.LQT:Acquire(ttName2, 2, "LEFT", "RIGHT");

	tt2:Clear();

	tt2:AddLine(C("ltblue",L["XP bonus"]),C("green",data.bonusSum.."%"));
	tt2:AddSeparator(1);
	for slotId,slotName in ns.pairsByKeys(slots) do
		local v=data.bonus[slotId] or {};
		if(slotId==998)then
			tt2:AddLine(C("ltyellow",slotName),(v.percent) and v.percent.."%" or C("ltgray",L["Not in a guild"]));
		elseif(slotId==999)then
			-- ignore refer-a-friend
		else
			tt2:AddLine(
				C("ltyellow",slotName),
				(v.percent==nil and C("ltgray",L["not equipped"])) or (v.outOfLevel==true and C("red",L["Out of Level"])) or v.percent.."%"
			);
		end
	end

	ns.createTooltip(parentLine, tt2);
	tt2:ClearAllPoints();
	tt2:SetPoint("TOP",parentLine,"TOP",0,0);

	local tL,tR,tT,tB = ns.getBorderPositions(tt);
	local uW = UIParent:GetWidth();
	if tR<(uW/2) then
		tt2:SetPoint("RIGHT",tt,"LEFT",-2,0);
	else
		tt2:SetPoint("LEFT",tt,"RIGHT",2,0);
	end
end

local function getTooltip(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...

	tt:Clear();
	if (IsXPUserDisabled()) then
		tt:AddHeader(C("orange",L["XP gain disabled"]));
	else
		tt:AddHeader(C("dkyellow",L[name]));
	end

	if (UnitLevel("player")<MAX_PLAYER_LEVEL) then
		tt:AddSeparator();

		local c,m = data.cur,data.max;
		if(Broker_EverythingDB.separateThousands)then
			c = FormatLargeNumber(c);
			m = FormatLargeNumber(m);
		end

		tt:AddLine(C("ltyellow",POWER_TYPE_EXPERIENCE),"",C("white",("(%s/%s)"):format(c,m)));
		tt:AddLine(C("ltyellow",POWER_TYPE_EXPERIENCE.." ("..L["Percent"]..")"), "",data.percent);
		tt:AddLine(C("ltyellow",GARRISON_FOLLOWER_XP_STRING),"",C("white",data.need));
		if (data.restStr) then
			tt:AddLine(C("ltyellow",L["Rest"]),"",C("cyan",data.restStr));
		end
	end

	if (UnitLevel("player")<MAX_PLAYER_LEVEL) and (#data.bonus>0) then
		tt:AddSeparator(5,0,0,0,0);
		tt:AddLine(C("ltblue",L["XP bonus"]),"",C("green",data.bonusSum.."%"));
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
					"",
					(v.percent==nil and C("ltgray",L["not equipped"])) or (v.outOfLevel==true and C("red",L["Out of Level"])) or v.percent.."%"
				);
			end
		end
	end

	if Broker_EverythingDB[name].showMyOtherChars then
		local allRealms = (Broker_EverythingDB[name].showAllRealms==true);
		tt:AddSeparator(4,0,0,0,0);
		local l = tt:AddLine();
		tt:SetCell(l,1,C("ltblue",L["Your other chars (%s)"]:format(allRealms and L["all realms"] or ns.realm)),nil,nil,3);
		tt:AddSeparator();
		local count = 0;
		for i=1, #be_character_cache.order do
			local name_realm = be_character_cache.order[i];
			local v = be_character_cache[name_realm];
			if(v.xp and v.xp.bonus)then --- little cleanup outdated boolean usage
				for slotId, slot in pairs(v.xp.bonus)do
					if( slot.percent==nil or slot.percent==false )then
						v.xp.bonus[slotId]=nil;
					end
				end
			end
			if( (name_realm:match(ns.realm) or allRealms) and (name_realm~=ns.player.name_realm) and v.xp~=nil and not (Broker_EverythingDB[name].showNonMaxLevelOnly and v.level==MAX_PLAYER_LEVEL) )then
				local Name,Realm = strsplit("-",name_realm);
				Realm = allRealms and " "..C("dkyellow","- "..ns.scm(Realm)) or "";
				local c,m = v.xp.cur,v.xp.max;
				if(Broker_EverythingDB.separateThousands)then
					c = FormatLargeNumber(c);
					m = FormatLargeNumber(m);
				end
				local l = tt:AddLine(
					("(%d) %s %s"):format(v.level,C(v.class,ns.scm(Name))..Realm, v.faction and "|TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or ""),
					("%s "..C("cyan","%s")):format(v.xp.percent or 0,v.xp.restStr or "> ?%"),
					("(%s/%s)"):format(c,m)
				);
				tt:SetLineScript(l,"OnMouseUp",function(self,button) be_character_cache[name_realm].xp = nil; getTooltip(tt); end);
				if (v.xp.bonus and #v.xp.bonus>0) then
					tt:SetLineScript(l,"OnEnter",function(self) getTooltip2(self,v.xp) end);
					tt:SetLineScript(l,"OnLeave",function(self) ns.hideTooltip(tt2,ttName2,true) end);
				end
				count = count + 1;
			end
		end
		if (count==0) then
			local l = tt:AddLine();
			tt:SetCell(l,1,L["No data found"],nil,nil,3);
		end
	end

	if Broker_EverythingDB.showHints then
		tt:AddSeparator(4,0,0,0,0);
		if (Broker_EverythingDB[name].showMyOtherChars) then
			local l = tt:AddLine();
			tt:SetCell(l,1,C("ltblue",L["Click"]).."||"..C("green",L["Delete a character from the list"]),nil,nil,ttColumns);
		end
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	if(be_character_cache[ns.player.name_realm].xp==nil)then
		be_character_cache[ns.player.name_realm].xp={};
	end
end

ns.modules[name].onevent = function(self,event,msg)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end

	if (event=="UNIT_INVENTORY_CHANGED") and (msg~="player") then return end

	local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName);

	if (MAX_PLAYER_LEVEL==UnitLevel("player")) then
		data = {cur=1,max=1,percent="100%",need=0,rest=0,restStr="n/a",bonus={},bonusSum=0};
	else
		data = {
			cur = UnitXP("player"),
			max = UnitXPMax("player"),
			rest = GetXPExhaustion() or 0,
		}
		data.percent   = math.floor((data.cur / data.max) * 100).."%";
		data.need      = data.max - data.cur;
		data.restStr   = (data.cur+data.rest>data.max) and ">100%+" or ">"..("%1.2f%%"):format((data.cur+data.rest)/data.max*100);
		data.bonus     = {};
		data.bonusSum  = 0;

		--- Bonus by inventory items
		for slotId,slotName in pairs(slots) do
			local itemId = GetInventoryItemID("player",slotId);
			if itemId and items[itemId] then
				data.bonus[slotId] = {percent=items[itemId][1], outOfLevel=(UnitLevel("player")>items[itemId][2]) and true or nil};
			end
		end

		--- Bonus by Guild Perk
		if IsInGuild() then
			data.bonus[998] = {percent=10};
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

	be_character_cache[ns.player.name_realm].xp = data;

	if (MAX_PLAYER_LEVEL~=sessionStartLevel) and (MAX_PLAYER_LEVEL==UnitLevel("player")) then
		dataobj.text = C("ltblue",L["Max. Level reached"]);
	elseif IsXPUserDisabled() then
		dataobj.text = C("orange",L["XP gain disabled"])
	elseif Broker_EverythingDB[name].display == "1" then
		dataobj.text = data.percent;
	elseif Broker_EverythingDB[name].display == "2" then
		local c,m = data.cur,data.max;
		if(Broker_EverythingDB.separateThousands)then
			c = FormatLargeNumber(c);
			m = FormatLargeNumber(m);
		end
		dataobj.text = c.."/"..m;
	elseif Broker_EverythingDB[name].display == "3" then
		dataobj.text = data.need;
	elseif Broker_EverythingDB[name].display == "4" then
		dataobj.text = data.percent.." ("..data.restStr..")";
	end
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttColumns = 3
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT", "RIGHT")
	getTooltip(tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

ns.modules[name].onclick = function(self,button)
	if (button=="RightButton") then
		if type(Broker_EverythingDB[name].display)=="boolean" then
			Broker_EverythingDB[name].display = "1"
		end

		if (UnitLevel("player")<MAX_PLAYER_LEVEL) then
			if (Broker_EverythingDB[name].display=="1") then
				Broker_EverythingDB[name].display = "2"
			elseif (Broker_EverythingDB[name].display=="2") then
				Broker_EverythingDB[name].display = "3"
			elseif (Broker_EverythingDB[name].display=="3") then
				Broker_EverythingDB[name].display = "4"
			elseif (Broker_EverythingDB[name].display=="4") then
				Broker_EverythingDB[name].display = "1"
			end
			ns.modules[name].onevent(self)
		end
	end
end

-- ns.modules[name].ondblclick = function(self,button) end

