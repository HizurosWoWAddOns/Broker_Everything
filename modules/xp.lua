
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
xpDB = {}
be_xp_db = {};

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "XP" -- L["XP"]
local ldbName = name
local ttName,ttName2 = name.."TT", name.."TT2"
local string = string
local tt,tooltip,tt2,createMenu,ttColumns
local data = {};
local sessionStartLevel = UnitLevel("player");
local slots = {  [1]=L["Head"], [3]=L["Shoulder"], [5]=L["Chest"], [7]=L["Legs"], [15]=L["Back"], [11]=L["Ring1"], [12]=L["Ring2"]}
local items = { -- Heirlooms with {<percent>,<maxLevel>}
	-- SoO Weapons
	[104399] = {0,100}, [104400] = {0,100}, [104401] = {0,100}, [104402] = {0,100}, [104403] = {0,100}, [104404] = {0,100}, [104405] = {0,100},
	[104406] = {0,100}, [104407] = {0,100}, [104408] = {0,100}, [104409] = {0,100}, [105670] = {0,100}, [105671] = {0,100}, [105672] = {0,100},
	[105673] = {0,100}, [105674] = {0,100}, [105675] = {0,100}, [105676] = {0,100}, [105677] = {0,100}, [105678] = {0,100}, [105679] = {0,100}, 
	[105680] = {0,100}, [105683] = {0,100}, [105684] = {0,100}, [105685] = {0,100}, [105686] = {0,100}, [105687] = {0,100}, [105688] = {0,100},
	[105689] = {0,100}, [105690] = {0,100}, [105691] = {0,100}, [105692] = {0,100}, [105693] = {0,100},
	-- Head
	[61931] = {10,85}, [61935] = {10,85}, [61936] = {10,85}, [61937] = {10,85}, [61942] = {10,85}, [61958] = {10,85}, [69887] = {10,85},
	-- shoulder
	[42949] = {10,80}, [42951] = {10,80}, [42952] = {10,80}, [42984] = {10,80}, [42985] = {10,80}, [44099] = {10,80}, [44100] = {10,80},
	[44101] = {10,80}, [44102] = {10,80}, [44103] = {10,80}, [44105] = {10,80}, [44107] = {10,80}, [69890] = {10,80}, [93859] = {10,85},
	[93861] = {10,85}, [93862] = {10,85}, [93864] = {10,85}, [93866] = {10,85}, [93876] = {10,85}, [93886] = {10,85}, [93887] = {10,85},
	[93889] = {10,85}, [93890] = {10,85}, [93893] = {10,85}, [93894] = {10,85},
	-- chest
	[48677] = {10,80}, [48683] = {10,80}, [48685] = {10,80}, [48687] = {10,80}, [48689] = {10,80}, [48691] = {10,80}, [69889] = {10,80},
	[93860] = {10,85}, [93863] = {10,85}, [93865] = {10,85}, [93885] = {10,85}, [93888] = {10,85}, [93891] = {10,85}, [93892] = {10,85},
	-- legs
	[62029] = {10,85}, [62026] = {10,85}, [62027] = {10,85}, [62024] = {10,85}, [62025] = {10,85}, [62023] = {10,85}, [69888] = {10,85},
	-- rings
	[50255] = {5,80},
	-- backs
	[62038] = {5,85}, [62039] = {5,85}, [62040] = {5,85}, [69892] = {5,85}
}

-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\ability_dualwield",coords={0.05,0.95,0.05,0.95}}; --IconName::XP--
--{iconfile="Interface\\Addons\\"..addon.."\\media\\xp"}


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
		showNonMaxLevelOnly = false
	},
	config_allowed = {
		display = {["1"]=true,["2"]=true,["3"]=true,["4"]=true}
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showMyOtherChars", label=L["Show other chars xp"], tooltip=L["Display a list of my chars on same realm with her level and xp"] },
		{ type="toggle", name="showNonMaxLevelOnly", label=L["Show non max. level characters only"], tooltip=L["Hide all characters who have reached the level cap."] },
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
	tt2 = ns.LQT:Acquire(ttName2, 2, "LEFT", "RIGHT")

	tt2:Clear()

	local removeGuildPerk=0;
	for i,v in ns.pairsByKeys(data.xpBonus) do
		if (i>=800) then
			removeGuildPerk = removeGuildPerk + v.percent;
		end
	end

	tt2:AddLine(C("ltblue",L["XP bonus"]),C("green",(data.xpBonusSum-removeGuildPerk).."%"))
	tt2:AddSeparator(1)
	for i,v in ns.pairsByKeys(data.xpBonus) do
		if not (v.percent==false and (i==11 or i==12)) and (i<800) then
			tt2:AddLine(
				C(v.percent==false and "ltgray" or "ltyellow",v.name),
				(v.percent==false and C("ltgray",L["not equipped"])) or (v.outOfLevel and C("red",L["Out of Level"])) or v.percent.."%"
			)
		end
	end

	ns.createTooltip(parentLine, tt2)
	tt2:ClearAllPoints()
	tt2:SetPoint("TOP",parentLine,"TOP",0,0)

	local tL,tR,tT,tB = ns.getBorderPositions(tt)
	local uW = UIParent:GetWidth()
	if tR<(uW/2) then
		tt2:SetPoint("RIGHT",tt,"LEFT",-2,0)
	else
		tt2:SetPoint("LEFT",tt,"RIGHT",2,0)
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
		tt:AddLine(C("ltyellow",L[name]),data.xpPercent,C("white",("(%d/%d)"):format(data.xp,data.xpMax)));
		tt:AddLine(C("ltyellow",L["Til Next Level"]),"",C("white",data.xpNeed));
		if (data.xpRestStr) then
			tt:AddLine(C("ltyellow",L["Rest"]),"",C("cyan",data.xpRestStr));
		end
	end

	if (UnitLevel("player")<MAX_PLAYER_LEVEL) and (#data.xpBonus>0) then
		tt:AddSeparator(5,0,0,0,0)
		tt:AddLine(C("ltblue",L["XP bonus"]),"",C("green",data.xpBonusSum.."%"));
		tt:AddSeparator();
		for i,v in ns.pairsByKeys(data.xpBonus) do
			if not (v.percent==false and (i==11 or i==12)) then
				tt:AddLine(C(v.percent==false and "ltgray" or "ltyellow",v.name), "", (v.percent==false and C("ltgray",L["not equipped"])) or (v.outOfLevel and C("red",L["Out of Level"])) or v.percent.."%");
			end
		end
	end

	if Broker_EverythingDB[name].showMyOtherChars then
		tt:AddSeparator(4,0,0,0,0);
		local l = tt:AddLine();
		tt:SetCell(l,1,C("ltblue",L["Your other chars (%s)"]:format(ns.realm)),nil,nil,3)
		tt:AddSeparator();
		local count = 0;
		for i,v in pairs(be_xp_db[ns.realm]) do
			if (v~=nil) and (i~=ns.player.name) and not (Broker_EverythingDB[name].showNonMaxLevelOnly and v.level==MAX_PLAYER_LEVEL) then
				local l = tt:AddLine(
					("(%d) %s %s"):format(v.level,C(v.class,ns.scm(i)), v.faction and "|TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or ""),
					("%s "..C("cyan","%s")):format(v.xpPercent,v.xpRestStr or "> ?%"),
					("(%d/%d)"):format(v.xp,v.xpMax)
				);
				tt:SetLineScript(l,"OnMouseUp",function(self,button) be_xp_db[ns.realm][i] = nil getTooltip(tt) end)
				if (#v.xpBonus>0) then
					tt:SetLineScript(l,"OnEnter",function(self) getTooltip2(self,v) end)
					tt:SetLineScript(l,"OnLeave",function(self) ns.hideTooltip(tt2,ttName2,true) end)
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
	local empty=true;
	if (be_xp_db) then
		for i,v in pairs(be_xp_db) do empty=false; end
	end
	if (xpDB~=nil) and (empty) then
		be_xp_db = xpDB;
		xpDB = nil;
	end
end

ns.modules[name].onevent = function(self,event,msg)

	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end

	if (event=="UNIT_INVENTORY_CHANGED") and (msg~="player") then return end

	local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName)

	local xpBonus = 0
	data.xpBonus = {}
	for slotId,slotName in pairs(slots) do
		local itemId = GetInventoryItemID("player",slotId)
		if itemId and items[itemId] then
			xpBonus = xpBonus + items[itemId][1]
			data.xpBonus[slotId] = {name=slotName, percent=items[itemId][1], outOfLevel=UnitLevel("player")>items[itemId][2]}
		else
			data.xpBonus[slotId] = {name=slotName, percent=false}
		end
	end

	local count = 1
	if IsInGroup() or IsInRaid() then
		local raf_boost = false
		for i=1, GetNumGroupMembers() or 0 do
			local m = (IsInRaid() and "raid" or "party")..i
			if UnitIsVisible(m) and IsReferAFriendLinked(m) then
				raf_boost = true
				data.xpBonus[999] = {name=L["Recruite a Friend"],percent=300}
			end
		end
		if raf_boost then
			xpBonus = xpBonus + 300
		end
	end

	data.level       = UnitLevel("player")
	data.class       = ns.player.class
	data.faction     = ns.player.faction
	data.xpBonusSum  = xpBonus
	if (MAX_PLAYER_LEVEL==data.level) then
		data.xp          = 1
		data.xpMax       = 1
		data.xpPercent   = "100%"
		data.xpNeed      = 0
		data.xpRest      = 0
		data.xpRestStr   = "n/a";
	else
		data.xp          = UnitXP("player")
		data.xpMax       = UnitXPMax("player")
		data.xpPercent   = math.floor((data.xp / data.xpMax) * 100).."%"
		data.xpNeed      = data.xpMax - data.xp
		data.xpRest      = GetXPExhaustion()
		data.xpRestStr   = (data.xp+data.xpRest>data.xpMax) and ">100%+" or ">"..("%1.2f%%"):format((data.xp+data.xpRest)/data.xpMax*100);
	end


	if be_xp_db[ns.realm]==nil then be_xp_db[ns.realm] = {} end
	be_xp_db[ns.realm][ns.player.name] = data

	if (MAX_PLAYER_LEVEL~=sessionStartLevel) and (MAX_PLAYER_LEVEL==data.level) then
		dataobj.text = C("ltblue",L["Max. Level reached"]);
	elseif IsXPUserDisabled() then
		dataobj.text = C("orange",L["XP gain disabled"])
	elseif Broker_EverythingDB[name].display == "1" then
		dataobj.text = data.xpPercent;
	elseif Broker_EverythingDB[name].display == "2" then
		dataobj.text = data.xp.."/"..data.xpMax;
	elseif Broker_EverythingDB[name].display == "3" then
		dataobj.text = data.xpNeed;
	elseif Broker_EverythingDB[name].display == "4" then
		dataobj.text = data.xpPercent.." ("..data.xpRestStr..")";
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

