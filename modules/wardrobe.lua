
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = WARDROBE;
local ldbName, ttName, ttColumns, tt, createMenu = name, name.."TT", 4
local illusions,weapons = {0,0},{};
local session = {};
XXX = session

-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="INTERFACE\\ICONS\\trade_archaeology",coords={0.05,0.95,0.05,0.95}}; --IconName::Archaeology--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show count of collected transmog apperiences"],
	label = WARDROBE,
	--icon_suffix = "_Neutral",
	events = {
		"PLAYER_LOGIN",
		--"PLAYER_ENTERING_WORLD",
		--"KNOWN_CURRENCY_TYPES_UPDATE",
		--"ARTIFACT_UPDATE",
		--"ARTIFACT_COMPLETE",
		--"CURRENCY_DISPLAY_UPDATE",
		--"GET_ITEM_INFO_RECEIVED",
		--"CHAT_MSG_SKILL"
	},
	updateinterval = nil,
	config_defaults = {},
	config_allowed = {},
	config_header = { type="header", label=WARDROBE, align="left", icon=true },
	config_broker = {},
	config_tooltip = {},
	config_misc = {},
	clickOptions = {
		-- world map
		--[[
		["1_open_archaeology_frame"] = {
			cfg_label = "Open archaeology frame", -- L["Open archaeology frame"]
			cfg_desc = "open your archaeology frame", -- L["open your archaeology frame"]
			cfg_default = "_LEFT",
			hint = "Open archaeology frame", -- L["Open archaeology frame"]
			func = function(self,button)
				local _mod=name;
				if ( not ArchaeologyFrame ) then
					ArchaeologyFrame_LoadUI()
				end
				if ( ArchaeologyFrame ) then
					if(ArchaeologyFrame:IsShown())then
						securecall("ArchaeologyFrame_Hide")
					else
						securecall("ArchaeologyFrame_Show")
					end
				end
			end
		},
		]]
		["9_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self);
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(ns.modules[name].ldbName);
	if(#solvables==1)then
		obj.text = C("green",table.concat(solvables,", "));
	elseif(#solvables>1)then
		obj.text = C("green",solvables[1].." " ..L["and %d more"]:format(#solvables-1));
	else
		obj.text = PROFESSIONS_ARCHAEOLOGY;
	end
end

local function sortWeapons(a,b)
	return a[1]<b[1];
end

local function updateData()
end

local function addLine(name,collected,total,session)
	local session = collected-session;
	tt:AddLine(
		C("ltyellow",name),
		true and collected.."/"..total or "",
		true and ("%.1f%%"):format(collected/total*100) or "",
		session>0 and C("ltgreen","+"..session) or ""
	);
end

local function createTooltip(tt)
	tt:Clear()
	tt:AddHeader(C("dkyellow",L[name]));

	updateData();

	tt:AddSeparator(4,0,0,0,0);
	tt:AddLine(C("ltblue",ARMOR));
	tt:AddSeparator();

	-- armor
	for i=1, 11 do
		local v = TRANSMOG_SLOTS[i];
		addLine(
			_G[v.slot],
			C_TransmogCollection.GetCategoryCollectedCount(v.armorCategoryID),
			C_TransmogCollection.GetCategoryTotal(v.armorCategoryID),
			session.armor[v.slot]
		);
	end

	tt:AddSeparator(4,0,0,0,0);
	tt:AddLine(C("ltblue",HEIRLOOMS_CATEGORY_WEAPON));
	tt:AddSeparator();

	-- weapons
	local names = {};
	for categoryID = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE do
		local name, isWeapon = C_TransmogCollection.GetCategoryInfo(categoryID);
		if name and isWeapon then
			tinsert(names,{name,categoryID});
		end
	end
	table.sort(names,sortWeapons);
	for i,v in pairs(names)do
		addLine(
			v[1],
			C_TransmogCollection.GetCategoryCollectedCount(v[2]),
			C_TransmogCollection.GetCategoryTotal(v[2]),
			session.weapons[v[1]]
		);
	end

	tt:AddSeparator(4,0,0,0,0);
	tt:AddLine(C("ltblue",CALENDAR_TYPE_OTHER));
	tt:AddSeparator();

	-- illusions
	local illusions = C_TransmogCollection.GetIllusions();
	local collected,total = 0,#illusions;
	for i=1, total do
		if illusions[i].isCollected then
			collected=collected+1;
		end
	end
	addLine(WEAPON_ENCHANTMENT,collected,total,session.misc.illusions);

	-- sets
	local collected,total = C_TransmogSets.GetBaseSetsCounts();
	addLine(WARDROBE_SETS,collected,total,session.misc.sets);

	if ns.profile.GeneralOptions.showHints and false then
		tt:AddSeparator(4,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,...)
	if event=="PLAYER_LOGIN" then
		session.armor = {};
		for i=1, 11 do
			local v = TRANSMOG_SLOTS[i];
			local collected = C_TransmogCollection.GetCategoryCollectedCount(v.armorCategoryID);
			session.armor[v.slot] = collected;
		end

		session.weapons = {};
		for categoryID = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE do
			local name, isWeapon, _, canMainHand, canOffHand = C_TransmogCollection.GetCategoryInfo(categoryID);
			if name and isWeapon then
				session.weapons[name] = C_TransmogCollection.GetCategoryCollectedCount(categoryID);
			end
		end

		local count,total = 0,C_TransmogCollection.GetIllusions();
		for i=1, #total do
			if total[i].isCollected then
				count=count+1;
			end
		end
		session.misc = {
			illusions = count,
			sets = (C_TransmogSets.GetBaseSetsCounts())
		}
	elseif event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "RIGHT","RIGHT"},{true},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end


--[[
list of counter collected templates

--------------
Wardrobe

Slot | Count/Total | Currently mogged
---------------------------------------

Last collected
----------------------
5 lines

<Class>
-------------------------------
Gloth knowledge:	<name>
Weapons: <name1>[, <name N>]




--]]

--[[

		collected = C_TransmogCollection.GetCategoryCollectedCount(WardrobeCollectionFrame.activeCategory);
		total = C_TransmogCollection.GetCategoryTotal(WardrobeCollectionFrame.activeCategory);

if


TRANSMOG_SLOTS = {
	[1]  = { slot = "HEADSLOT", 			transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_HEAD },
	[2]  = { slot = "SHOULDERSLOT", 		transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_SHOULDER },
	[3]  = { slot = "BACKSLOT", 			transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_BACK },
	[4]  = { slot = "CHESTSLOT",		 	transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_CHEST },
	[5]  = { slot = "TABARDSLOT", 			transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_TABARD },
	[6]  = { slot = "SHIRTSLOT", 			transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_SHIRT },
	[7]  = { slot = "WRISTSLOT", 			transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_WRIST },
	[8]  = { slot = "HANDSSLOT", 			transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_HANDS },
	[9]  = { slot = "WAISTSLOT", 			transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_WAIST },
	[10] = { slot = "LEGSSLOT", 			transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_LEGS },
	[11] = { slot = "FEETSLOT", 			transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_FEET },
	[12] = { slot = "MAINHANDSLOT", 		transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = nil },
	[13] = { slot = "SECONDARYHANDSLOT", 	transmogType = LE_TRANSMOG_TYPE_APPEARANCE,	armorCategoryID = nil },
	[14] = { slot = "MAINHANDSLOT", 		transmogType = LE_TRANSMOG_TYPE_ILLUSION,	armorCategoryID = nil },
	[15] = { slot = "SECONDARYHANDSLOT",	transmogType = LE_TRANSMOG_TYPE_ILLUSION,	armorCategoryID = nil },
}


--]]

