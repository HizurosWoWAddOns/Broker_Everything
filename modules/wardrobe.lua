
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Wardrobe"; -- WARDROBE
local ldbName, ttName, ttColumns, tt, module = name, name.."TT", 4
local illusions,weapons = {0,0},{};
local session = {};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="INTERFACE\\ICONS\\trade_archaeology",coords={0.05,0.95,0.05,0.95}}; --IconName::Archaeology--


-- some local functions --
--------------------------
local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	obj.text = WARDROBE;
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
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",WARDROBE));

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
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
	},
	config_defaults = {},
	clickOptionsRename = {
		["menu"] = "9_open_menu"
	},
	clickOptions = {
		--["wardrobe"] = {"Wardrobe","call",""}, -- problematically. colectionframe will be tained on open...
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	-- wardrobe = "_LEFT",
	menu = "_RIGHT"
});

-- function module.options() return {} end
-- function module.init() end

function module.onevent(self,event,...)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGIN" then
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
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "RIGHT","RIGHT"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;

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

