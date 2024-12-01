
--[[ 3 in 1 module ]]--

-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I, _ = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name0 = "GPS / Location / ZoneText"; L[name0] = ("%s / %s / %s"):format(L["GPS"],L["Location"],L["ZoneText"]);
local name1 = "GPS"; -- L["GPS"] L["ModDesc-GPS"]
local name2 = "Location"; -- L["Location"] L["ModDesc-Location"]
local name3 = "ZoneText"; -- L["ZoneText"] L["ModDesc-ZoneText"]
local updateinterval,module1,module2,module3 = 0.12;
local ttName1, ttName2, ttName3, ttName4 = name1.."TT", name2.."TT", name3.."TT", "TransportMenuTT";
local ttColumns,ttColumns4,onleave,tt4Params = 3,5;
local tt1, tt2, tt3, tt4, items;
local zoneRed, zoneOrange, zoneYellow, zoneGreen,zoneBlue = C("red","%s"),C("orange","%s"),C("dkyellow","%s"),C("ltgreen","%s"),C("ltblue","%s");
local tt5positions = {
	["LEFT"]   = {edgeSelf = "RIGHT",  edgeParent = "LEFT",   x = -2, y =  0},
	["RIGHT"]  = {edgeSelf = "LEFT",   edgeParent = "RIGHT",  x =  2, y =  0},
}
local iStr16,iStr32 = "|T%s:16:16:0:0|t","|T%s:32:32:0:0|t";
local gpsLoc = {zone=" ",color="white",pvp="contested",pos=""}
local zoneDisplayValues = {
	["1"] = ZONE,
	["2"] = L["Subzone"],
	["3"] = ZONE..CHAT_HEADER_SUFFIX..L["Subzone"],
	["4"] = ("%s (%s)"):format(ZONE,L["Subzone"]),
	["5"] = ("%s (%s)"):format(L["Subzone"],ZONE),
}
local foundItems, foundToys, foundToysNum, teleports, portals, spells, hearthstoneLocation = {},{},0,{},{},{};
local _classSpecialSpellIds,_teleportIds,_portalIds,_itemIds,_toyIds,_hearthstones,_itemMustBeEquipped,_itemFactions,_namelessToys,_toyUsableBug = {},{},{},{},{},{},{},{},{},{};
local sharedclickOptionsRename = {
	["1_open_world_map"] = "worldmap",
	["2_open_transport_menu"] = "transport",
	["3_open_menu"] = "menu"
};
local sharedclickOptions = {
	["worldmap"] = {"World map","call",{"ToggleWorldMap"}},
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
		--local sName, _, icon, _, _, _, _, _, _ = ns.deprecated.C_Spell.GetSpellInfo(id);
		local info = ns.deprecated.C_Spell.GetSpellInfo(id)
		table.insert(tb,{type="spell",id=id,icon=info.iconID,name=info.name,name2=info.name});
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

local function itemIsHearthstone(id)
	if _hearthstones[id] then
		return true, hearthstoneLocation;
	end
	return false,"";
end

local function addToy(id)
	if not foundToys[id] and PlayerHasToy then
		local toyName, _, _, _, _, _, _, _, _, toyIcon = C_Item.GetItemInfo(id);
		local hasToy = PlayerHasToy(id);
		local canUse = C_ToyBox.IsToyUsable(id);
		if _toyUsableBug[id] then
			-- special problem; Sometimes C_ToyBox.IsToyUsable does not return correct state of some items
			-- like the Broker Translocation Matrix (190237) on toons without needed reputation to purchase it.
			-- But they can use it.
			if canUse then
				ns.data.IsToyUsable[id] = true;
			elseif ns.data.IsToyUsable[id] then
				canUse = true;
			end
		end
		if toyName and hasToy and canUse then
			local isHS, hsLoc = itemIsHearthstone(id);
			foundToys[id] = {
				type="item",
				id=id,
				icon=toyIcon,
				name=toyName,
				name2=isHS and toyName..hsLoc or toyName
			};
			foundToysNum = foundToysNum + 1;
			if _namelessToys[id] then
				_namelessToys[id] = nil;
			end
		elseif not toyName then
			return false;
		end
	end
	return true;
end

local function addToyOnCallback(toyID,toyIcon,toyName)
	local isHS, hsLoc = itemIsHearthstone(toyID);
	foundToys[toyID] = { type="item", id=toyID, icon=toyIcon, name=toyName, name2=isHS and toyName..hsLoc or toyName };
	foundToysNum = foundToysNum + 1;
	if _namelessToys[toyID] then
		_namelessToys[toyID] = nil;
	end
end

local function updateItems()
	-- update hearthstone location string
	hearthstoneLocation = " "..C("ltblue","("..GetBindLocation()..")");

	-- update foundItems table
	wipe(foundItems);
	for i=1, #_itemIds do
		local id = _itemIds[i];
		if ns.items.byID[id] then
			for sharedSlot,item in pairs(ns.items.byID[id]) do
				local isHS,hsLoc = itemIsHearthstone(id);
				local obj = {type="item", id=id, sharedSlot=sharedSlot};
				obj.name, _, _, _, _, _, _, _, _, obj.icon = C_Item.GetItemInfo(item.link);
				if obj.name then
					obj.name2 = isHS and obj.name..hsLoc or obj.name;
					if _itemMustBeEquipped[id] then
						obj.mustBeEquipped = true;
						obj.equipped = item.bag==-1;
					end
					tinsert(foundItems,obj);
				end
			end
		end
	end

	-- update foundToys table;
	if ns.client_version>=5 then
		for i=1, #_toyIds do
			if addToy(_toyIds[i]) then
				_namelessToys[_toyIds[i]] = true;
			end
		end
	end
end

local function position(name)
	local p, f, posObject = ns.profile[name].precision or 0, ns.profile[name].coordsFormat or "%s, %s";
	local x, y = 0,0;
	local mapID = C_Map.GetBestMapForUnit("player");
	if mapID then
		posObject = C_Map.GetPlayerMapPosition(mapID,"player");
	end
	if posObject and posObject.GetXY then
		x,y = posObject:GetXY();
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

local function GetZoneInfo()
	local zoneColor,zoneLabel,zoneType, _, f = "white","", C_PvP.GetZonePVPInfo()

	if zoneType == "combat" or zoneType == "arena" or zoneType == "hostile" then
		zoneColor,zoneLabel = zoneRed,HOSTILE;
	elseif zoneType == "contested" or zoneType == nil then
		zoneColor,zoneLabel,zoneType = zoneYellow,L["Contested"],"contested"
	elseif zoneType == "friendly" then
		zoneColor,zoneLabel = zoneGreen,FRIENDLY;
	elseif zoneType == "sanctuary" then
		zoneColor,zoneLabel = zoneBlue,L["Sanctuary"];
	end
	return zoneColor,zoneLabel,zoneType;
end

-- shared tooltip for modules Location, GPS and ZoneText
local function createTooltip(tt,ttName,modName)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

	local zoneColor,zoneLabel,zoneType = GetZoneInfo()
	local line, column

	if buttonFrame then buttonFrame:ClearAllPoints() buttonFrame:Hide() end

	if tt.lines~=nil then tt:Clear(); end

	tt:AddHeader(C("dkyellow",L[modName]))

	tt:AddSeparator()

	local lst = {
		{C("ltyellow",ZONE .. HEADER_COLON),GetRealZoneText()},
		{C("ltyellow",L["Subzone"] .. HEADER_COLON),GetSubZoneText()},
		{C("ltyellow",L["Zone status"] .. HEADER_COLON),zoneColor:format(zoneLabel)},
		{C("ltyellow",L["Coordinates"] .. HEADER_COLON),position(modName) or C(gpsLoc.posColor or gpsLoc.color,gpsLoc.pos)}
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
	tt:SetCell(line,1,C("ltyellow",L["Inn"]..HEADER_COLON),nil,nil,1)
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
	GameTooltip:SetHyperlink(data.tooltip.type..HEADER_COLON..data.tooltip.id);
	GameTooltip:Show();
end

local transportMenu
--[[local function updateTPM()
	if tt4Params then
		--C_Timer.After(0.2,function() transportMenu(unpack(tt4Params)) end);
		transportMenu(unpack(tt4Params));
	end
end]]

-- tooltip as transport menu
local function tpmOnEnter(self,data)
	local object = {
		attributes={type=data.type,[data.type]=data.name},
		tooltip={parent=tt4,type=data.type,id=data.id},
		OnEnter=createTooltip3,
		OnLeave=GameTooltip_Hide,
		--OnClick=updateTPM
	};
	ns.secureButton(self,object);
end

local function transportMenuOnHide()
	tt4Params = nil;
end

local function transportMenuDoUpdate()
	if tt4Params then
		transportMenu(unpack(tt4Params));
	end
end

local cd_day = 60 * 60 * 24;
local cd_hour = 60 * 60;
local cd_minute = 60;

local function cooldownFmt(cooldown)
	if cooldown > cd_day then
		local d = math.floor(cooldown / cd_day);
		local h = (cooldown - d * cd_day) / cd_hour;
		h = math.floor(h + 0.5);
		return string.format('%dd%dh', d, h);
	end
	if cooldown > cd_hour then
		local h = math.floor(cooldown / cd_hour);
		local m = (cooldown - h * cd_hour) / cd_minute;
		m = math.floor(m + 0.5);
		return string.format('%dh%dm', h, m);
	end
	if cooldown > cd_minute then
		local m = math.floor(cooldown / cd_minute);
		local s = cooldown - m * cd_minute;
		s = math.floor(s + 0.5);
		return string.format('%dm%ds', m, s);
	end
	local s = math.floor(cooldown + 0.5);
	return string.format('%ds', s);
end

local function tpmAddObject(tt,parent,name,line,column,data)
	local start, duration, enabled;
	if data.type=="spell" then
		start, duration, enabled = ns.deprecated.C_Spell.GetSpellCooldown(data.id);
		if type(start)=="table" then
			start,duration,enabled = start.startTime,start.duration,start.isEnabled;
		end
	elseif data.type=="item" then
		local bagIndex, slotIndex
		if data.sharedSlot then
			bagIndex, slotIndex = ns.items.GetBagSlot(data.sharedSlot);
		end
		if bagIndex and slotIndex then
			start, duration, enabled = C_Container.GetContainerItemCooldown(bagIndex, slotIndex)
		elseif bagIndex==false and slotIndex then
			start, duration, enabled = GetInventoryItemCooldown("player", slotIndex)
		end
		if not (start and duration and enabled) then
			start, duration, enabled = ns.deprecated.C_Item.GetItemCooldown(data.id)
		end
		if start and duration then
			if enabled==0 then
				data.cooldown = duration;
			elseif start>0 and duration>0 then
				data.cooldown = start + duration - GetTime()
			end
		end
	end
	if ns.profile[name].shortMenu then
		if column<ttColumns4 and line~=nil then
			column = column+1;
		else
			column = 1;
			line = tt:AddLine();
		end
		tt:SetCell(line, column, iStr32:format(data.icon), nil, nil, 1);
		tt:SetCellScript(line,column,"OnEnter",tpmOnEnter,data);
		return line,column;
	end
	local info = "";
	if data.mustBeEquipped==true and data.equipped==false then
		info = " "..C("orange","(click to equip)");
	end
	local cooldown = "";
	if data.cooldown and data.cooldown ~= 0 then
		cooldown = " "..C("green", '('..cooldownFmt(data.cooldown)..')');
	end
	line = tt:AddLine(iStr16:format(data.icon)..(data.name2 or data.name)..info..cooldown, "1","2","3");
	tt:SetLineScript(line,"OnEnter",tpmOnEnter,data);
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
	if not (tt4 and tt4.key and tt4.key==ttName4) then
		tt4 = ns.acquireTooltip({ttName4, ttColumns4, "LEFT","LEFT","LEFT","LEFT","LEFT"},{false},{self},{OnHide=transportMenuOnHide});
		tt4Params = {self,button,name};
	end

	local line, column, counter = nil,ttColumns4,0

	tt4:Clear()

	-- title
	if not ns.profile[name].shortMenu then
		tt4:AddHeader(C("dkyellow","Choose your transport"))
	end

	if #teleports>0 or #portals>0 or #spells>0 then
		-- class title
		if not ns.profile[name].shortMenu then
			tt4:AddSeparator(4,0,0,0,0)
			tt4:AddLine(C("ltyellow",ns.player.classLocale))
			tt4:AddSeparator()
		end
		-- class spells
		if ns.player.class=="MAGE" then
			for _,data in ns.pairsByKeys(teleports) do
				line,column = tpmAddObject(tt4,self,name,line,column,data);
				counter = counter+1;
			end
			if not ns.profile[name].shortMenu then
				tt4:AddSeparator()
			end
			for _,data in ns.pairsByKeys(portals) do
				line,column = tpmAddObject(tt4,self,name,line,column,data);
				counter = counter+1;
			end
		else
			for _,data in ns.pairsByKeys(spells) do
				line,column = tpmAddObject(tt4,self,name,line,column,data);
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
		for _,data in ns.pairsByKeys(foundItems) do
			line,column = tpmAddObject(tt4,self,name,line,column,data);
			counter = counter + 1
		end
	end

	if ns.client_version>=6 and foundToysNum>0 then
		-- toy title
		if not ns.profile[name].shortMenu then
			tt4:AddSeparator(4,0,0,0,0);
			tt4:AddLine(C("ltyellow",TOY_BOX));
			tt4:AddSeparator();
		end
		-- toys
		for _,data in pairs(foundToys) do
			line,column = tpmAddObject(tt4,self,name,line,column,data);
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
		gpsLoc.posColor = "%s"
		gpsLoc.posInfo = nil
	else
		if gpsLoc.posLast==nil then
			gpsLoc.posLast=time()
		elseif time()-gpsLoc.posLast>5 then
			gpsLoc.posColor = zoneOrange;
			gpsLoc.posInfo = L["Coordinates indeterminable"]
		end
	end
	return gpsLoc;
end

local function updater()
	if not (ns.profile[name1].enabled or ns.profile[name2].enabled or ns.profile[name3].enabled) then return end
	local zoneColor,zoneLabel,zoneType = GetZoneInfo();

	if ns.profile[name1].enabled and module1.obj then
		local gpsLoc = posUpdater(name1)
		gpsLoc.zone = zone(name1);
		module1.obj.text = zoneColor:format(gpsLoc.zone.." (")..(gpsLoc.poszoneColor and C(gpsLoc.poszoneColor,gpsLoc.pos) or zoneColor:format(gpsLoc.pos))..zoneColor:format(")");
	end

	if ns.profile[name2].enabled and module2.obj then
		local gpsLoc = posUpdater(name2)
		module2.obj.text = gpsLoc.poszoneColor and C(gpsLoc.poszoneColor,gpsLoc.pos) or zoneColor:format(gpsLoc.pos);
	end

	if ns.profile[name3].enabled and module3.obj then
		local gpsLoc = posUpdater(name3)
		gpsLoc.zone = zone(name3)
		module3.obj.text = zoneColor:format(gpsLoc.zone);
	end
end

local initFinished = false;
local function init()
	if initFinished then return end
	initFinished = true;

	-- spells
	_classSpecialSpellIds = {50977,18960,556,126892,147420,193753};
	_teleportIds = {3561,3562,3563,3565,3566,3567,32271,32272,33690,35715,49358,49359,53140,88342,88344,120145,132621,132627,176248,176242,193759,224869,281403,281404,344587,395277,446540};
	_portalIds = {10059,11416,11417,11418,11419,11420,32266,32267,33691,35717,49360,49361,53142,88345,88346,120146,132620,132626,176246,176244,224871,281400,281402,344597,395289,446534};

	-- items
	_itemIds = {
		17690,17691,17900,17901,17902,17903,17904,17905,17906,17907,17908,17909,21711,22589,22630,22631,22632,24335,29796,32757,34420,35230,36747,37863,38685,40585,
		40586,44934,44935,45688,45689,45690,45691,45705,46874,48954,48955,48956,48957,50287,51557,51558,51559,51560,52251,52576,58487,58964,60273,60374,60407,60498,
		61379,63206,63207,63352,63353,63378,63379,64457,65274,65360,66061,68808,68809,82470,87548,91850,91860,91861,91862,91863,91864,91865,91866,92056,92057,92058,
		92430,92431,92432,92510,95050,95051,103678,104110,104113,107441,116413,117389,118662,118663,118907,118908,119183,128353,128502,128503,129276,132119,
		132120,132122,132517,133755,134058,138448,139541,139590,139599,140319,140493,141013,141014,141015,141016,141017,141605,142469,144391,144392,147870,
		152964,156927,159224,166559,166560,184504,219222,

		-- hearth stones (not toys)
		6948,28585,37118,44314,44315,142298,142543
	};

	-- toys
	_toyIds = {
		18984,18986,30542,30544,43824,48933,87215,95567,95568,95589,95590,110560,112059,129929,132517,136849,140192,140324,151016,151652,168807,168808,169297,169298,172924,198156,211788,221966,

		-- hearth stones
		54452,64488,93672,142542,162973,163045,165669,165670,165802,166746,166747,168862,168907,172179,184353,180290,182773,183716,184871,188952,190196,190237,193588,200630,206195,208704,209035,212337,228940
	};

	-- on some toys C_ToyBox.IsToyUsable returns wrong state
	_toyUsableBug = {
		[190237] = true,
	};

	-- items with hearthstone spell
	_hearthstones = {
		[6948]=1, -- Hearthstone
		[28585]=1, -- Ruby Slippers
		[37118]=1, -- Scroll of Recall
		[44314]=1, -- Scroll of Recall II
		[44315]=1, -- Scroll of Recall III
		[54452]=1, -- Toy - Ethereal Portal
		[64488]=1, -- Toy - The Innkeeper's Daughter
		[93672]=1, -- Toy - Dark Portal
		[142298]=1, -- Astonishingly Scarlet Slippers
		[142542]=1, -- Toy - Tome of Town Portal
		[142543]=1, -- Scroll of Town Portal
		[162973]=1, -- Toy - Greatfather Winter's Hearthstone
		[163045]=1, -- Toy - Headless Horseman's Hearthstone
		[165669]=1, -- Toy - Lunar Elder's Hearthstone
		[165670]=1, -- Toy - Peddlefeet's Lovely Hearthstone
		[165802]=1, -- Toy - Noble Gardener's Hearthstone
		[166746]=1, -- Toy - Fire Eater's Hearthstone
		[166747]=1, -- Toy - Brewfest Reveler's Hearthstone
		[168862]=1, -- Toy - G.E.A.R. Tracking Beacon
		[168907]=1, -- Toy - Holographic Digitalization Hearthstone
		[172179]=1, -- Toy - Eternal Traveler's Hearthstone
		[184353]=1, -- Toy - Kyrian Hearthstone
		[180290]=1, -- Toy - Night Fae Hearthstone
		[182773]=1, -- Toy - Necrolord Hearthstone
		[183716]=1, -- Toy - Venthyr Sinstone
		[184871]=1, -- Toy - Dark Portal
		[188952]=1, -- Toy - Dominated Hearthstone
		[190196]=1, -- Toy - Enlightened Hearthstone
		[190237]=1, -- Toy - Broker Translocation Matrix
		[193588]=1, -- Toy - Timewalker's Hearthstone
		[200630]=1, -- Toy - Ohn'ir Windsage's Hearthstone
		[206195]=1, -- Toy - Path of the Naaru
		[208704]=1, -- Toy - Deepdweller's Earthen Hearthstone
		[209035]=1, -- Toy - Hearthstone of the Flame
		[212337]=1, -- Toy - Stone of the Hearth
		[228940]=1, -- Toy - Deepdweller's Earthen Hearthstone

	};

	--_itemReplacementIds = {64488,28585,6948,44315,44314,37118,142542,142298};
	_itemMustBeEquipped = {[32757]=1,[40585]=1,[142298]=1};

	-- init ns.data
	if ns.data.IsToyUsable==nil then
		ns.data.IsToyUsable = {};
	end

	-- init ns.items
	ns.items.Init("any");
	ns.items.RegisterCallback(name1,transportMenuDoUpdate,"any");
	ns.items.RegisterCallback(name1,addToyOnCallback,"toys");

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

module1.init = init;
module2.init = init;
module3.init = init

local eventActive = false;
local function onevent(name,self,event,arg1,...)
	if event=="BE_UPDATE_CFG" then
		if arg1 and arg1:find("^ClickOpt") then
			ns.ClickOpts.update(name);
		end
		if not eventActive then
			eventActive = name;
		end
	end
end

function module1.onevent(...)
	onevent(name1,...);
end

function module2.onevent(...)
	onevent(name2,...);
end

function module3.onevent(...)
	onevent(name3,...);
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
