
--[[
	Little description to this 3 in 1 module.
	it register 4 modules. the first (name0) is only for shared configuration.
]]

----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
local _

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name0 = "GPS / Location / ZoneText" -- L["GPS / Location / ZoneText"]
local name1 = "GPS" -- L["GPS"]
local name2 = "Location" -- L["Location"]
local name3 = "ZoneText" -- L["ZoneText"]
local ldbName1, ldbName2, ldbName3 = name1, name2, name3
local ttName1, ttName2, ttName3, ttName4 = name1.."TT", name2.."TT", name3.."TT", name1.."TT2"
local ttColumns,onleave,gpsTooltip2,createMenu
local tt1, tt2, tt3, tt4
local tt5positions = {
	["LEFT"]   = {edgeSelf = "RIGHT",  edgeParent = "LEFT",   x = -2, y =  0},
	["RIGHT"]  = {edgeSelf = "LEFT",   edgeParent = "RIGHT",  x =  2, y =  0},
}

local iStr16 = "|T%s:16:16:0:0|t"
local iStr32 = "|T%s:32:32:0:0|t"
local gpsLoc = {
	zone = " ",
	color = "white",
	pvp = "contested",
	pos = ""
}
local zoneDisplayValues = {
	["1"] = L["Zone"],
	["2"] = L["Subzone"],
	["3"] = L["Zone"]..": "..L["Subzone"],
	["4"] = ("%s (%s)"):format(L["Zone"],L["Subzone"]),
	["5"] = ("%s (%s)"):format(L["Subzone"],L["Zone"]),
}
local teleports, portals, spells, items_for_menu, item_replacements = {},{},{},{},{}
local _classSpecialSpellIds = {50977,18960,556,126892,147420};
local _teleportIds = {3561,3562,3563,3565,3566,3567,32271,32272,33690,35715,49358,49359,53140,88342,88344,120145,132621,132627,176248,176242};
local _portalIds = {10059,11416,11417,11418,11419,11420,32266,32267,33691,35717,49360,49361,53142,88345,88346,120146,132620,132626,176246,176244};
local _itemIds = {18984,18986,21711,30542,30544,32757,35230,37863,40585,40586,43824,44934,44935,45688,45689,45690,45691,46874,48933,48954,48955,48956,48957,50287,51557,51558,51559,51560,52251,58487,63206,63207,63352,63353,63378,63379,64457,65274,65360,87215,95050,95051,95567,95568,110560,112059,128353,118662,118663};
local _itemReplacementIds = {64488,28585,6948,44315,44314,37118};
local _itemMustBeEquipped = {32757};
for _,v in ipairs(_itemIds) do items_for_menu[v] = true end
for _,v in ipairs(_itemReplacementIds) do item_replacements[v] = true end


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name1] = {iconfile="Interface\\Addons\\"..addon.."\\media\\gps"}		--IconName::GPS--
I[name2] = {iconfile="Interface\\Addons\\"..addon.."\\media\\gps"}		--IconName::Location--
I[name3] = {iconfile=GetItemIcon(11105),coords={0.05,0.95,0.05,0.95}}	--IconName::ZoneText--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Some shared options for the modules GPS, Location and ZoneText"];
ns.modules[name0] = {
	noBroker = true,
	desc = desc,
	events = {
		"PLAYER_ENTERING_WORLD",
		"LEARNED_SPELL_IN_TAB"
	},
	updateinterval = 0.1,
	config_defaults = {
		precision = 0,
		coordsFormat = "%s, %s",
		shortMenu = false
	},
	config_allowed = {
		coordsFormat = {
			["%s, %s"] = true,
			["%s / %s"] = true,
			["%s/%s"] = true,
			["%s | %s"] = true,
			["%s||%s"] = true
		}
	},
	config = {
		{ type="header", label=L[name0], align="left", icon=I[name1] },
		{ type="separator" },
		{ type="toggle", name="shortMenu", label=L["Short transport menu"], tooltip=L["Display the transport menu without names of spells and items behind the icons."]},
		{ type="select",
			name	= "coordsFormat",
			label	= L["Co-ordination format"],
			tooltip	= L["How would you like to view co-ordinations."],
			values	= {
				["%s, %s"]     = "10.3, 25.4",
				["%s / %s"]    = "10.3 / 25.4",
				["%s/%s"]      = "10.3/25.4",
				["%s | %s"]    = "10.3 | 25.4",
				["%s||%s"]     = "10.3||25.4"
			},
			default = "%s, %s",
		},
		{ type="slider",
			name		= "precision",
			label		= L["Precision"],
			tooltip		= L["Change how much digits display after the dot."],
			min			= 0,
			max			= 3,
			default		= 0,
			format		= "%d"
		}
	}
}

ns.modules[name1] = {
	desc = L["Broker to show the name of the current Zone and the co-ordinates."],
	events = {},
	updateinterval = nil,
	config_defaults = {
		bothZones = "2"
	},
	config_prepend = name0,
	config = {
		{ type="header", label=L[name1], align="left", icon=I[name1] },
		{ type="separator" },
		{ type="select", name="bothZones", label=L["Display zone names"], tooltip=L["Display in broker zone and subzone if exists or one of it."], default="2", values=zoneDisplayValues }
	},
	clickOptions = {
		["1_open_world_map"] = {
			cfg_label = "Open World map",
			cfg_desc = "open the World map",
			cfg_default = "_LEFT",
			hint = "Open World map",
			func = function(self,button)
				local _mod=name;
				securecall("ToggleFrame",WorldMapFrame)
			end
		},
		["2_open_transport_menu"] = {
			cfg_label = "Open transport menu",
			cfg_desc = "open the transport menu",
			cfg_default = "_RIGHT",
			hint = "Open transport menu",
			func = function(self,button)
				local _mod=name;
				if tt1 then onleave(self,tt1,ttName1) end

				if (InCombatLockdown()) then return; end
				if Broker_EverythingDB[name0].shortMenu then
					tt4 = ns.LQT:Acquire(ttName4, 4, "LEFT","LEFT","LEFT","LEFT")
				else
					tt4 = ns.LQT:Acquire(ttName4, 1, "LEFT")
				end
				gpsTooltip2(tt4);
				ns.createTooltip(self,tt4);
			end
		},
		["3_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "__NONE",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self)
			end
		}
	}
}

ns.modules[name2] = {
	desc = L["Broker to show your current co-ordinates within the zone."],
	enabled = false,
	events = {},
	updateinterval = nil,
	config_defaults = nil,
	config_prepend = name0,
	config = {
		{type="header", label=L[name2], align="left", icon=I[name2] },
	},
	clickOptions = {
		["1_open_world_map"] = {
			cfg_label = "Open World map",
			cfg_desc = "open the World map",
			cfg_default = "_LEFT",
			hint = "Open World map",
			func = function(self,button)
				local _mod=name;
				securecall("ToggleFrame",WorldMapFrame)
			end
		},
		["2_open_transport_menu"] = {
			cfg_label = "Open transport menu",
			cfg_desc = "open the transport menu",
			cfg_default = "_RIGHT",
			hint = "Open transport menu",
			func = function(self,button)
				local _mod=name;
				if tt2 then onleave(self,tt2,ttName2) end

				if (InCombatLockdown()) then return; end
				if Broker_EverythingDB[name0].shortMenu then
					tt4 = ns.LQT:Acquire(ttName4, 4, "LEFT","LEFT","LEFT","LEFT")
				else
					tt4 = ns.LQT:Acquire(ttName4, 1, "LEFT")
				end
				gpsTooltip2(tt4);
				ns.createTooltip(self,tt4);
			end
		},
		["3_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "__NONE",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self,false)
			end
		}
	}
}

ns.modules[name3] = {
	desc = L["Broker to show the name of the current zone."],
	enabled = false,
	events = {},
	updateinterval = nil,
	config_defaults = {
		bothZones = "2"
	},
	config_prepend = name0,
	config = {
		{ type="header", label=L[name3], align="left", icon=I[name3] },
		{ type="separator" },
		{ type="select", name="bothZones", label=L["Display zone names"], tooltip=L["Display in broker zone and subzone if exists or one of it."], default="2", values=zoneDisplayValues }
	},
	clickOptions = {
		["1_open_world_map"] = {
			cfg_label = "Open World map",
			cfg_desc = "open the World map",
			cfg_default = "_LEFT",
			hint = "Open World map",
			func = function(self,button)
				local _mod=name;
				securecall("ToggleFrame",WorldMapFrame)
			end
		},
		["2_open_transport_menu"] = {
			cfg_label = "Open transport menu",
			cfg_desc = "open the transport menu",
			cfg_default = "_RIGHT",
			hint = "Open transport menu",
			func = function(self,button)
				local _mod=name;
				if tt3 then onleave(self,tt3,ttName3) end

				if (InCombatLockdown()) then return; end
				if Broker_EverythingDB[name0].shortMenu then
					tt4 = ns.LQT:Acquire(ttName4, 4, "LEFT","LEFT","LEFT","LEFT")
				else
					tt4 = ns.LQT:Acquire(ttName4, 1, "LEFT")
				end
				gpsTooltip2(tt4);
				ns.createTooltip(self,tt4);
			end
		},
		["3_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "__NONE",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self,name3)
			end
		}
	}

}


--------------------------
-- some local functions --
--------------------------
function createMenu(self,nameX)
	if (tt1~=nil) then ns.hideTooltip(tt1,ttName1,true); end
	if (tt2~=nil) then ns.hideTooltip(tt2,ttName2,true); end
	if (tt3~=nil) then ns.hideTooltip(tt3,ttName3,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name0);
	if (nameX) then
		ns.EasyMenu.addConfigElements(nameX,true);
	end
	ns.EasyMenu.ShowMenu(self);
end

local function setSpell(tb,id)
	if (IsSpellKnown(id)) then
		local sName, _, icon, _, _, _, _, _, _ = GetSpellInfo(id)
		table.insert(tb,{id=id,icon32=iStr32:format(icon),icon16=iStr16:format(icon),name=sName,name2=sName});
	end
end

local function setItem(tb,id,nameReplacement)
	local itemName, _, _, _, _, _, _, _, _, icon, _ = GetItemInfo(id)
	table.insert(tb,{id=id,icon32=iStr32:format(icon),icon16=iStr16:format(icon),name=itemName,name2=(nameReplacement or itemName)});
end

local function chkInventory(ifExists)
	local found, count = {},0

	-- check bags
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local item_id = GetContainerItemID(bag,slot)
			if item_id then
				local itemName, _, _, _, _, _, _, _, _, icon, _ = GetItemInfo(item_id)
				if type(ifExists)=="table" and ifExists[item_id] then
					return itemName
				elseif type(ifExists)=="number" and ifExists == item_id then
					return itemName
				elseif items_for_menu[item_id]==true then
					setItem(found,item_id)
					count = count + 1
				elseif item_replacements[item_id]==true then
					setItem(found,item_id,GetBindLocation())
					count = count + 1
				end
			end
		end
	end

	-- check character slots
	--[[
	local slots = {"ShirtSlot","Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot"};
	for i,v in ipairs(slots) do
		local id = GetInventoryItemID("player",v);
		if(
	end
	]]

	return found, count
end

local XX=0;
local function position()
	local p,f = Broker_EverythingDB[name0].precision, Broker_EverythingDB[name0].coordsFormat
	if not p then p = 0 end
	local precision_format = "%."..p.."f"
	if not f then f = "%s, %s" end

	local x, y = GetPlayerMapPosition("player")

	if x ~= 0 and y ~= 0 then
		return string.format(
			f,
			string.format(precision_format, (x * 100)),
			string.format(precision_format, (y * 100))
		)
	else
		local pX = strrep("?",p)
		return string.format(f, (pX~="" and "?."..pX or "?"), (pX~="" and "?."..pX or "?") )
	end
end

local function zone(byName)
	local subZone = GetSubZoneText() or ""
	local zone = GetRealZoneText() or ""
	local types = {"%s: %s","%s (%s)"}
	local mode = "2";

	if Broker_EverythingDB[byName]==nil then
		Broker_EverythingDB[byName]={};
	end
	if Broker_EverythingDB[byName].bothZones==nil then
		Broker_EverythingDB[byName].bothZones = mode;
	else
		mode = Broker_EverythingDB[byName].bothZones;
	end

	if mode=="2" and subZone~="" then
		return subZone
	elseif mode=="3" and subZone~="" then
		return subZone and types[1]:format(zone,subZone or "")
	elseif mode=="4" and subZone~="" then
		return subZone and types[2]:format(zone,subZone)
	elseif mode=="5" and subZone~="" then
		return subZone and types[2]:format(subZone,zone)
	end

	return zone
end

local function zoneColor()
	local p, _, f = GetZonePVPInfo()
	local color = "white"

	if p == "combat" or p == "arena" or p == "hostile" then
		color = "red"
	elseif p == "contested" or p == nil then 
		color = "dkyellow"
		p = "contested"
	elseif p == "friendly" then
		color = "ltgreen"
	elseif p == "sanctuary" then
		color = "ltblue"
	end
	--[[
		L["Contested"]
		L["Sanctuary"]
		L["Friendly"]
		L["Combat"]
		L["Arena"]
		L["Hostile"]
	]]
	return p, color
end

-- shared tooltip for modules Location, GPS and ZoneText
local function gpsTooltip(self,tt,ttName,modName)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...

	local pvp, color = zoneColor()
	local line, column
	pvp = gsub(pvp,"^%l", string.upper)

	if buttonFrame then buttonFrame:ClearAllPoints() buttonFrame:Hide() end

	tt:Clear()

	tt:AddHeader(C("dkyellow",L[modName]))

	tt:AddSeparator()

	local lst = {
		{C("ltyellow",L["Zone"] .. ":"),GetRealZoneText()},
		{C("ltyellow",L["Subzone"] .. ":"),GetSubZoneText()},
		{C("ltyellow",L["Zone status"] .. ":"),C(color,L[pvp])},
		{C("ltyellow",L["Co-ordinates"] .. ":"),position() or C(gpsLoc.posColor or gpsLoc.color,gpsLoc.pos)}
	}

	for _, d in pairs(lst) do
		line, column = tt:AddLine()
		tt:SetCell(line,1,d[1],nil,nil,2)
		tt:SetCell(line,3,d[2],nil,nil,1)
	end

	if gpsLoc.posColor then
		line,column = tt:AddLine()
		tt:SetCell(line,1,C(gpsLoc.posColor,gpsLoc.posInfo),nil,"CENTER",3)
	end

	tt:AddSeparator()

	line, column = tt:AddLine()
	tt:SetCell(line,1,C("ltyellow",L["Inn"]..":"),nil,nil,1)
	tt:SetCell(line,2,GetBindLocation(),nil,nil,2)

	if Broker_EverythingDB.showHints then
		tt:AddSeparator(4,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,modName,ttColumns);
	end
end

function gpsTooltip2(tt)
	local pts,ipts,tls,itls = {},{},{},{}
	local line, column,cellcount = nil,nil,5
	local inv, inv_c = chkInventory()

	local function add_title(title)
		tt:AddSeparator(4,0,0,0,0)
		tt:AddLine(C("ltyellow",title))
		tt:AddSeparator()
	end

	local function add_cell(v,t)
		local startTime, duration, enable
		if(t=="item")then
			startTime, duration, enable = GetItemCooldown(v.id);
		end
		tt:SetCell(line, cellcount, v.icon32, nil, nil, 1)
		tt:SetCellScript(line,cellcount,"OnEnter",function(self) ns.secureButton(self,{ {typeName="type", typeValue=t, attrName=t, attrValue=v.name} }) end)
	end

	local function add_line(v,t)
		local startTime, duration, enable
		if(t=="item")then
			startTime, duration, enable = GetItemCooldown(v.id);
		end
		local line, column = tt:AddLine(v.icon16..(v.name2 or v.name), "1","2","3")
		tt:SetLineScript(line,"OnEnter",function(self) ns.secureButton(self,{ {typeName="type", typeValue=t, attrName=t, attrValue=v.name} }) end)
	end

	local function add_obj(v,t)
		if Broker_EverythingDB[name0].shortMenu then
			if cellcount<4 then
				cellcount = cellcount + 1
			else
				cellcount = 1
				line, column = tt:AddLine()
			end
			add_cell(v,t)
		else
			add_line(v,t)
		end
	end

	tt:Clear()

	-- title
	if not Broker_EverythingDB[name0].shortMenu then
		tt:AddHeader(C("dkyellow","Choose your transport"))
	end

	local counter = 0

	if #teleports>0 or #portals>0 or #spells>0 then
		-- class title
		if not Broker_EverythingDB[name0].shortMenu then
			add_title(ns.player.classLocale)
		end
		-- class spells
		if ns.player.class=="MAGE" then
			for i,v in ns.pairsByKeys(teleports) do
				add_obj(v,"spell")
			end
			if not Broker_EverythingDB[name0].shortMenu then
				tt:AddSeparator()
			end
			for i,v in ns.pairsByKeys(portals) do
				add_obj(v,"spell")
			end
		else
			for i,v in ns.pairsByKeys(spells) do
				add_obj(v,"spell")
			end
		end
	end

	if inv_c>0 then
		-- item title
		if not Broker_EverythingDB[name0].shortMenu then
			add_title(L["Items"])
		end
		-- items
		for i,v in ns.pairsByKeys(inv) do
			add_obj(v,"item")
			counter = counter + 1
		end
	end
	
	if counter==0 then
		tt:AddSeparator(4,0,0,0,0)
		tt:AddHeader(C("ltred",L["Sorry"].."!"))
		tt:AddSeparator(1,1,.4,.4,1)
		tt:AddLine(C("ltred",L["No spells or items found"].."."))
	end
end

function onleave(self,tt,ttN)
	if (tt) and (tt~=tt4) then
		ns.hideTooltip(tt,ttN,true);
		ns.secureButton(false);
		if (tt==tt1) then tt1=nil; end
		if (tt==tt2) then tt2=nil; end
		if (tt==tt3) then tt3=nil; end
	end
	if (tt4) then
		if MouseIsOver(tt4) then
			tt4:SetScript('OnLeave',function(self)
				if (ns.hideTooltip(tt4,ttName4)) then tt4 = nil; end
			end)
		else
			if (ns.hideTooltip(tt4,ttName4)) then tt4 = nil; end
		end
	end
end

local function onclick(self,button)
	if button == "LeftButton" then
		securecall("ToggleFrame",WorldMapFrame)
	elseif button == "RightButton" then
		if tt1 then onleave(self,tt1,ttName1) end
		if tt2 then onleave(self,tt2,ttName2) end
		if tt3 then onleave(self,tt3,ttName3) end

		if (InCombatLockdown()) then return; end
		if Broker_EverythingDB[name0].shortMenu then
			tt4 = ns.LQT:Acquire(ttName4, 4, "LEFT","LEFT","LEFT","LEFT");
		else
			tt4 = ns.LQT:Acquire(ttName4, 4, "LEFT","RIGHT","CENTER","CENTER");
		end
		gpsTooltip2(tt4);
		ns.createTooltip(self,tt4);
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------

ns.modules[name0].init = function(self)
	ldbName1 = (Broker_EverythingDB.usePrefix and "BE.." or "")..name1
	ldbName2 = (Broker_EverythingDB.usePrefix and "BE.." or "")..name2
	ldbName3 = (Broker_EverythingDB.usePrefix and "BE.." or "")..name3
end

-- ns.modules[name1].init = function(self) end
-- ns.modules[name2].init = function(self) end
-- ns.modules[name3].init = function(self) end

ns.modules[name0].onevent = function(self,event,msg)
	if (event=="LEARNED_SPELL_IN_TAB") or (event=="PLAYER_ENTERING_WORLD") then
		wipe(teleports); wipe(portals); wipe(spells);
		if (ns.player.class=="MAGE") then
			for _,v in ipairs(_teleportIds) do setSpell(teleports,v) end
			for _,v in ipairs(_portalIds) do setSpell(portals,v) end
		end
		for _,v in ipairs(_classSpecialSpellIds) do setSpell(spells,v) end
	end
end

ns.modules[name1].onevent = function(self,event,msg)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name1],Broker_EverythingDB[name1]);
	end
end

ns.modules[name2].onevent = function(self,event,msg)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name2],Broker_EverythingDB[name2]);
	end
end

ns.modules[name3].onevent = function(self,event,msg)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name3],Broker_EverythingDB[name3]);
	end
end
-- ns.modules[name0].onmousewheel = function(self,direction) end
-- ns.modules[name1].onmousewheel = function(self,direction) end
-- ns.modules[name2].onmousewheel = function(self,direction) end
-- ns.modules[name3].onmousewheel = function(self,direction) end

ns.modules[name0].onupdate = function(self)
	if not (Broker_EverythingDB[name1].enabled or Broker_EverythingDB[name2].enabled or Broker_EverythingDB[name3].enabled) then return end

	gpsLoc.zone1 = zone(name1)
	gpsLoc.zone3 = zone(name3)
	gpsLoc.pvp, gpsLoc.color = zoneColor()
	local pos = position()
	if pos then
		gpsLoc.pos = pos
		gpsLoc.posColor = nil
		gpsLoc.posInfo = nil
	else
		if gpsLoc.posLast==nil then
			gpsLoc.posLast=time()
		elseif time()-gpsLoc.posLast>5 then
			gpsLoc.posColor = "orange"
			gpsLoc.posInfo = L["Co-ordinates indeterminable"]
		end
	end

	local obj = ns.LDB:GetDataObjectByName(ldbName1);
	if (obj) then
		obj.text = C(gpsLoc.color,gpsLoc.zone1.." (")..C(gpsLoc.posColor or gpsLoc.color,gpsLoc.pos)..C(gpsLoc.color,")");
	end

	obj = ns.LDB:GetDataObjectByName(ldbName2);
	if (obj) then
		obj.text = C(gpsLoc.posColor or gpsLoc.color,gpsLoc.pos);
	end

	obj = ns.LDB:GetDataObjectByName(ldbName3);
	if (obj) then
		obj.text = C(gpsLoc.color,gpsLoc.zone3);
	end
end

-- ns.modules[name1].onupdate = function(self) end
-- ns.modules[name2].onupdate = function(self) end
-- ns.modules[name3].onupdate = function(self) end
-- ns.modules[name0].optionspanel = function(panel) end
-- ns.modules[name1].optionspanel = function(panel) end
-- ns.modules[name2].optionspanel = function(panel) end
-- ns.modules[name3].optionspanel = function(panel) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name1].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	ttColumns = 3;
	tt1 = ns.LQT:Acquire(ttName1, ttColumns, "LEFT", "RIGHT", "RIGHT");
	gpsTooltip(self,tt1,ttName1,name1);
	ns.createTooltip(self,tt1);
end

ns.modules[name2].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	ttColumns = 3;
	tt2 = ns.LQT:Acquire(ttName2, ttColumns, "LEFT", "RIGHT", "RIGHT");
	gpsTooltip(self,tt2,ttName2,name2);
	ns.createTooltip(self,tt2);
end

ns.modules[name3].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	ttColumns = 3;
	tt3 = ns.LQT:Acquire(ttName3, ttColumns, "LEFT", "RIGHT", "RIGHT");
	gpsTooltip(self,tt3,ttName3,name3);
	ns.createTooltip(self,tt3);
end

ns.modules[name1].onleave = function(self)
	onleave(self,tt1,ttName1);
end

ns.modules[name2].onleave = function(self)
	onleave(self,tt2,ttName2);
end

ns.modules[name3].onleave = function(self)
	onleave(self,tt3,ttName3);
end

--ns.modules[name1].onclick = function(self,button) end
--ns.modules[name2].onclick = function(self,button) end
--ns.modules[name3].onclick = function(self,button) end

-- ns.modules[name1].ondblclick = function(self,button) end
-- ns.modules[name2].ondblclick = function(self,button) end
-- ns.modules[name3].ondblclick = function(self,button) end
