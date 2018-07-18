
--[[ 3 in 1 module ]]--

-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I, _ = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name0 = "GPS / Location / ZoneText"; L[name0] = ("%s / %s / %s"):format(L["GPS"],L["Location"],L["ZoneText"]);
local name1 = "GPS"; -- L["GPS"]
local name2 = "Location"; -- L["Location"]
local name3 = "ZoneText"; -- L["ZoneText"]
local updateinterval,module1,module2,module3 = 0.12;
local ttName1, ttName2, ttName3, ttName4 = name1.."TT", name2.."TT", name3.."TT", "TransportMenuTT";
local ttColumns,ttColumns4,onleave = 3,5;
local tt1, tt2, tt3, tt4, items;
local tt5positions = {
	["LEFT"]   = {edgeSelf = "RIGHT",  edgeParent = "LEFT",   x = -2, y =  0},
	["RIGHT"]  = {edgeSelf = "LEFT",   edgeParent = "RIGHT",  x =  2, y =  0},
}
local iStr16,iStr32 = "|T%s:16:16:0:0|t","|T%s:32:32:0:0|t";
local gpsLoc = {zone=" ",color="white",pvp="contested",pos=""}
local zoneDisplayValues = {
	["1"] = ZONE,
	["2"] = L["Subzone"],
	["3"] = ZONE..": "..L["Subzone"],
	["4"] = ("%s (%s)"):format(ZONE,L["Subzone"]),
	["5"] = ("%s (%s)"):format(L["Subzone"],ZONE),
}
local foundItems, foundToys, teleports, portals, spells = {},{},{},{},{};
local _classSpecialSpellIds,_teleportIds,_portalIds,_itemIds,_itemReplacementIds,_itemMustBeEquipped,_itemFactions = {},{},{},{},{},{},{};
local sharedclickOptionsRename = {
	["1_open_world_map"] = "worldmap",
	["2_open_transport_menu"] = "transport",
	["3_open_menu"] = "menu"
};
local sharedclickOptions = {
	["worldmap"] = {"World map","call",{"ToggleFrame",WorldMapFrame}},
	["transport"] = {"Transport menu","module","transportMenu"},
	["menu"] = "OptionMenu"
};
local sharedclickOptionsDefaults = {
	worldmap = "_LEFT",
	transport = "_RIGHT",
	menu = "__NONE"
};
local sharedMisc = {
	shortMenu={ type="toggle", name=L["Short transport menu"], desc=L["Display the transport menu without names of spells and items behind the icons."]},
	coordsFormat={ type="select",
		name	= L["Coordination format"],
		desc	= L["How would you like to view coordinations."],
		values	= {
			["%s, %s"]     = "10.3, 25.4",
			["%s / %s"]    = "10.3 / 25.4",
			["%s/%s"]      = "10.3/25.4",
			["%s | %s"]    = "10.3 | 25.4",
			["%s||%s"]     = "10.3||25.4"
		},
	},
	precision={ type="range", name=L["Precision"], desc=L["Change how much digits display after the dot."], min=0, max=3, step=1 }
}

-- register icon names and default files --
-------------------------------------------
I[name1] = {iconfile="Interface\\Addons\\"..addon.."\\media\\gps"}		--IconName::GPS--
I[name2] = {iconfile="Interface\\Addons\\"..addon.."\\media\\gps"}		--IconName::Location--
I[name3] = {iconfile=134269,coords={0.05,0.95,0.05,0.95}}				--IconName::ZoneText--


-- some local functions --
--------------------------
local function setSpell(tb,id)
	if IsSpellKnown(id) then
		local sName, _, icon, _, _, _, _, _, _ = GetSpellInfo(id);
		table.insert(tb,{id=id,icon=icon,name=sName,name2=sName});
	end
end

local function updateSpells()
	wipe(teleports); wipe(portals); wipe(spells);
	if (ns.player.class=="MAGE") then
		for i=1, #_teleportIds do setSpell(teleports,_teleportIds[i]) end
		for i=1, #_portalIds do setSpell(portals,_portalIds[i]) end
	end
	for i=1, #_classSpecialSpellIds do setSpell(spells,_classSpecialSpellIds[i]) end
end

local function addItem(id,loc)
	local toyName,toyIcon,_;
	if PlayerHasToy(id) then
		_, toyName, toyIcon = C_ToyBox.GetToyInfo(id);
	end
	if toyName and toyIcon then
		if C_ToyBox.IsToyUsable(id) then
			table.insert(foundToys,{id=id,icon=toyIcon,name=toyName,name2=loc~=nil and toyName..loc or nil});
		end
	elseif items[id] and items[id][1] then
		local v=items[id][1];
		if type(v)=="table" and v.name then
			table.insert(foundItems,{id=id,icon=v.icon,name=v.name,name2=v.name,mustBeEquipped=_itemMustBeEquipped[id]==1,equipped=v.type=="inventory"});
		end
	end
end

local function updateItems()
	wipe(foundItems); wipe(foundToys);
	items = ns.items.GetItemlist();
	for i=1, #_itemIds do
		addItem(_itemIds[i]);
	end
	local loc = " "..C("ltblue","("..GetBindLocation()..")");
	for i=1, #_itemReplacementIds do
		addItem(_itemReplacementIds[i],loc);
	end
	items = nil;
end

local function position(name)
	local p, f, pf = ns.profile[name].precision or 0, ns.profile[name].coordsFormat or "%s, %s";
	local x, y = 0,0;
	if GetPlayerMapPosition then
		x,y = GetPlayerMapPosition("player"); -- TODO: BfA - removed function
	elseif C_Map and C_Map.GetPlayerMapPosition then
		local mapID = C_Map.GetBestMapForUnit("player");
		if mapID then
			local obj = C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"),"player");
			if obj and obj.GetXY then
				x,y = obj:GetXY();
			end
		end
	end
	if not x or (x==0 and y==0) then
		local pX = p==0 and "−" or "−."..strrep("−",p);
		return f:format(pX,pX);
	else
		return f:format("%."..p.."f","%."..p.."f"):format(x*100, y*100);
	end
end

local function zone(byName)
	local subZone = GetSubZoneText() or "";
	local zone = GetRealZoneText() or "";
	local types = {"%s: %s","%s (%s)"};
	local mode = "2";

	if ns.profile[byName]==nil then
		ns.profile[byName]={};
	end
	if ns.profile[byName].bothZones==nil then
		ns.profile[byName].bothZones = mode;
	else
		mode = ns.profile[byName].bothZones;
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
	return p, color
end

-- shared tooltip for modules Location, GPS and ZoneText
local function createTooltip(tt,ttName,modName)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	local pvp, color = zoneColor()
	local line, column
	pvp = gsub(pvp,"^%l", string.upper)

	if buttonFrame then buttonFrame:ClearAllPoints() buttonFrame:Hide() end

	if tt.lines~=nil then tt:Clear(); end

	tt:AddHeader(C("dkyellow",L[modName]))

	tt:AddSeparator()

	local lst = {
		{C("ltyellow",ZONE .. ":"),GetRealZoneText()},
		{C("ltyellow",L["Subzone"] .. ":"),GetSubZoneText()},
		{C("ltyellow",L["Zone status"] .. ":"),C(color,L[pvp])},
		{C("ltyellow",L["Coordinates"] .. ":"),position(modName) or C(gpsLoc.posColor or gpsLoc.color,gpsLoc.pos)}
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

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0)
		ns.ClickOpts.ttAddHints(tt,modName);
	end
	ns.roundupTooltip(tt);
end

local function createTooltip3(_,data)
	if not (data.tooltip and data.tooltip.parent and data.tooltip.parent:IsShown()) then return end
	GameTooltip:SetOwner(data.tooltip.parent,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(data.tooltip.parent,"horizontal"));
	GameTooltip:SetHyperlink(data.tooltip.type..":"..data.tooltip.id);
	GameTooltip:Show();
end

local function hideTooltip3()
	GameTooltip:Hide();
end

-- tooltip as transport menu
local function tpmOnEnter(self,info)
	local parent, v, t = unpack(info);
	local data = {
		attributes={type=t,[t]=v.name},
		tooltip={parent=tt4,type=t,id=v.id},
		OnEnter=createTooltip3,
		OnLeave=hideTooltip3
	};
	ns.secureButton(self,data);
end

local function tpmAddObject(tt,p,l,c,v,t,name)
	if ns.profile[name].shortMenu then
		if c<ttColumns4 and l~=nil then
			c=c+1;
		else
			c=1;
			l=tt:AddLine();
		end
		tt:SetCell(l, c, iStr32:format(v.icon), nil, nil, 1);
		tt:SetCellScript(l,c,"OnEnter",tpmOnEnter, {p,v,t});
		return l,c;
	else
		local info,doUpdate = "";
		if v.mustBeEquipped==true and v.equipped==false then
			info = " "..C("orange","(click to equip)");
			doUpdate=true
		end
		l = tt:AddLine(iStr16:format(v.icon)..(v.name2 or v.name)..info, "1","2","3");
		tt:SetLineScript(l,"OnEnter",tpmOnEnter,{p,v,t});
	end
end

function transportMenu(self,button,name)
	if InCombatLockdown() then return; end
	if (tt1~=nil) then tt1=ns.hideTooltip(tt1); end
	if (tt2~=nil) then tt2=ns.hideTooltip(tt2); end
	if (tt3~=nil) then tt3=ns.hideTooltip(tt3); end

	updateItems();
	updateSpells();

	local columns = 5;
	ttColumns4 = ns.profile[name].shortMenu and columns or 1;
	tt4 = ns.acquireTooltip({ttName4, ttColumns4, "LEFT","LEFT","LEFT","LEFT","LEFT"},{false},{self});

	local pts,ipts,tls,itls = {},{},{},{}
	local line, column,cellcount = nil,nil,5

	tt4:Clear()

	-- title
	if not ns.profile[name].shortMenu then
		tt4:AddHeader(C("dkyellow","Choose your transport"))
	end

	local counter = 0
	local l,c=nil,ttColumns4;

	if #teleports>0 or #portals>0 or #spells>0 then
		-- class title
		if not ns.profile[name].shortMenu then
			tt4:AddSeparator(4,0,0,0,0)
			tt4:AddLine(C("ltyellow",ns.player.classLocale))
			tt4:AddSeparator()
		end
		-- class spells
		local t = "spell";
		if ns.player.class=="MAGE" then
			for i,v in ns.pairsByKeys(teleports) do
				l,c = tpmAddObject(tt4,self,l,c,v,t,name);
				counter = counter+1;
			end
			if not ns.profile[name].shortMenu then
				tt4:AddSeparator()
			end
			for i,v in ns.pairsByKeys(portals) do
				l,c = tpmAddObject(tt4,self,l,c,v,t,name);
				counter = counter+1;
			end
		else
			for i,v in ns.pairsByKeys(spells) do
				l,c = tpmAddObject(tt4,self,l,c,v,t,name);
				counter = counter+1;
			end
		end
	end

	local t = "item";
	if #foundItems>0 then
		-- item title
		if not ns.profile[name].shortMenu then
			tt4:AddSeparator(4,0,0,0,0);
			tt4:AddLine(C("ltyellow",ITEMS));
			tt4:AddSeparator();
		end
		-- items
		for i,v in ns.pairsByKeys(foundItems) do
			l,c = tpmAddObject(tt4,self,l,c,v,t,name);
			counter = counter + 1
		end
	end

	if #foundToys>0 then
		-- toy title
		if not ns.profile[name].shortMenu then
			tt4:AddSeparator(4,0,0,0,0);
			tt4:AddLine(C("ltyellow",TOY_BOX));
			tt4:AddSeparator();
		end
		-- toys
		for i,v in ns.pairsByKeys(foundToys) do
			l,c = tpmAddObject(tt4,self,l,c,v,t,name);
			counter = counter + 1;
		end
	end

	if counter==0 then
		tt4:AddSeparator(4,0,0,0,0)
		tt4:AddHeader(C("ltred",L["Sorry"].."!"))
		tt4:AddSeparator(1,1,.4,.4,1)
		tt4:AddLine(C("ltred",L["No spells, items or toys found"].."."))
	end
	ns.roundupTooltip(tt4);
end

local function posUpdater(name)
	local gpsLoc,pos = {},position(name)
	if pos then
		gpsLoc.pos = pos
		gpsLoc.posColor = nil
		gpsLoc.posInfo = nil
	else
		if gpsLoc.posLast==nil then
			gpsLoc.posLast=time()
		elseif time()-gpsLoc.posLast>5 then
			gpsLoc.posColor = "orange"
			gpsLoc.posInfo = L["Coordinates indeterminable"]
		end
	end
	return gpsLoc;
end

local function updater()
	if not (ns.profile[name1].enabled or ns.profile[name2].enabled or ns.profile[name3].enabled) then return end
	local pvp, color = zoneColor()

	if ns.profile[name1].enabled and module1.obj then
		local gpsLoc = posUpdater(name1)
		gpsLoc.zone = zone(name1);
		module1.obj.text = C(color,gpsLoc.zone.." (")..C(gpsLoc.posColor or color,gpsLoc.pos)..C(color,")");
	end

	if ns.profile[name2].enabled and module2.obj then
		local gpsLoc = posUpdater(name2)
		module2.obj.text = C(gpsLoc.posColor or color,gpsLoc.pos);
	end

	if ns.profile[name3].enabled and module3.obj then
		local gpsLoc = posUpdater(name3)
		gpsLoc.zone = zone(name3)
		module3.obj.text = C(color,gpsLoc.zone);
	end
end

local function init()
	_classSpecialSpellIds = {50977,18960,556,126892,147420,193753};
	_teleportIds = {3561,3562,3563,3565,3566,3567,32271,32272,33690,35715,49358,49359,53140,88342,88344,120145,132621,132627,176248,176242,193759,224869};
	_portalIds = {10059,11416,11417,11418,11419,11420,32266,32267,33691,35717,49360,49361,53142,88345,88346,120146,132620,132626,176246,176244,224871};
	_itemIds = {18984,18986,21711,22589,22630,22631,22632,24335,29796,30542,30544,32757,33637,33774,34420,35230,36747,37863,38685,40585,40586,43824,44934,44935,45688,45689,45690,45691,45705,46874,48933,48954,48955,48956,48957,51557,51558,51559,51560,52251,52576,58487,58964,60273,60374,60407,60498,61379,63206,63207,63352,63353,63378,63379,64457,65274,65360,66061,68808,68809,82470,87215,87548,91850,91860,91861,91862,91863,91864,91865,91866,92056,92057,92058,92430,92431,92432,95050,95051,95567,95568,103678,104110,104113,107441,110560,112059,116413,117389,118662,118663,118907,118908,119183,128353,128502,128503,129276,132119,132120,132122,132517,133755,134058,136849,138448,139541,139590,139599,140192,140319,140493,141013,141014,141015,141016,141017,141605,142298};
	_itemReplacementIds = {64488,28585,6948,44315,44314,37118,142542,142298};
	_itemMustBeEquipped = {[32757]=1,[40585]=1,[142298]=1};

	C_Timer.After(5,function()
		C_Timer.NewTicker(updateinterval,updater);
		updateItems();
		updateSpells();
	end);
end


-- module functions and variables --
------------------------------------
module1 = { -- GPS
	events = {},
	config_defaults = {
		enabled = true,
		bothZones = "2",
		precision = 0,
		coordsFormat = "%s, %s",
		shortMenu = false
	},
	clickOptions = sharedclickOptions
}

module2 = { -- Location
	events = {},
	config_defaults = {
		enabled = false,
		precision = 0,
		coordsFormat = "%s, %s",
		shortMenu = false
	},
	clickOptions = sharedclickOptions
}

module3 = { -- ZoneText
	events = {},
	config_defaults = {
		enabled = false,
		bothZones = "2",
		precision = 0,
		coordsFormat = "%s, %s",
		shortMenu = false
	},
	clickOptions = sharedclickOptions
}

ns.ClickOpts.addDefaults(module1,sharedclickOptionsDefaults);
ns.ClickOpts.addDefaults(module2,sharedclickOptionsDefaults);
ns.ClickOpts.addDefaults(module3,sharedclickOptionsDefaults);

module1.transportMenu = transportMenu;
module2.transportMenu = transportMenu;
module3.transportMenu = transportMenu;

function module1.options()
	return {
		broker = {
			bothZones={ type="select", name=L["Display zone names"], desc=L["Display in broker zone and subzone if exists or one of it."], values=zoneDisplayValues }
		},
		misc = sharedMisc
	}
end

function module2.options()
	return {
		broker = nil,
		misc = sharedMisc
	}
end

function module3.options()
	return {
		broker = {
			bothZones={ type="select", name=L["Display zone names"], desc=L["Display in broker zone and subzone if exists or one of it."], values=zoneDisplayValues }
		},
		misc = sharedMisc
	}
end

function module1.init()
	if init then init() init=nil end
end

function module2.init()
	if init then init() init=nil end
end

function module3.init()
	if init then init() init=nil end
end

function module1.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name1);
	end
end

function module2.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name2);
	end
end

function module3.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name3);
	end
end

-- function module1.onmousewheel(self,direction) end
-- function module2.onmousewheel(self,direction) end
-- function module3.onmousewheel(self,direction) end
-- function module1.optionspanel(panel) end
-- function module2.optionspanel(panel) end
-- function module3.optionspanel(panel) end

function module1.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt1 = ns.acquireTooltip({ttName1, ttColumns, "LEFT", "RIGHT", "RIGHT"},{true},{self});
	createTooltip(tt1,ttName1,name1);
end

function module2.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt2 = ns.acquireTooltip({ttName2, ttColumns, "LEFT", "RIGHT", "RIGHT"},{true},{self});
	createTooltip(tt2,ttName2,name2);
end

function module3.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt3 = ns.acquireTooltip({ttName3, ttColumns, "LEFT", "RIGHT", "RIGHT"},{true},{self});
	createTooltip(tt3,ttName3,name3);
end

-- function module1.onleave(self) end
-- function module2.onleave(self) end
-- function module3.onleave(self) end
-- function module1.onclick(self,button) end
-- function module2.onclick(self,button) end
-- function module3.onclick(self,button) end
-- function module1.ondblclick(self,button) end
-- function module2.ondblclick(self,button) end
-- function module3.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name1] = module1;
ns.modules[name2] = module2;
ns.modules[name3] = module3;
