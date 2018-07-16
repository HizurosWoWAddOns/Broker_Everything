
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Wardrobe"; -- WARDROBE
local ldbName, ttName, ttColumns, tt, module = name, name.."TT", 4
local illusions,weapons = {0,0},{};
local ctForm = C("green","%d")..C("gray","/")..C("dkyellow","%d");
local pForm = C("","")
local session = {};
local brokerValues = {
	["_none"] = NONE.."/"..HIDE,
	p = L["<Percent>"].." "..L["+<Collected in this session>"],
	ct = L["<Collected>/<Total>"].." "..L["+<Collected in this session>"],
	s = L["+<Collected in this session>"]
}

L["WardrobeBrokerSets"] = rawget(L,"WardrobeBrokerSets") or "S: ";
L["WardrobeBrokerArmor"] = rawget(L,"WardrobeBrokerArmor") or "A: ";
L["WardrobeBrokerWeapons"] = rawget(L,"WardrobeBrokerWeapons") or "W: ";
L["WardrobeBrokerIllusions"] = rawget(L,"WardrobeBrokerIllusions") or "I: ";

-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="INTERFACE\\ICONS\\trade_archaeology",coords={0.05,0.95,0.05,0.95}}; --IconName::Archaeology--


-- some local functions --
--------------------------

local function addToBroker(tb,color,o,collected,total,sess)
	local res,sess = "",(sess<collected and " +"..(collected-sess) or "");
	if ns.profile[name]["broker"..o]=="p" then
		res = ("%.1f%%"):format(collected/total*100)..sess;
	elseif ns.profile[name]["broker"..o]=="ct" then
		res = ("%d/%d"):format(collected,total)..sess;
	elseif ns.profile[name]["broker"..o]=="s" then
		res = strtrim(sess);
	end
	if res~="" then
		table.insert(tb,C(color,L["WardrobeBroker"..o]..res));
	end
end

local function updateBroker()
	local tmp,obj = {},ns.LDB:GetDataObjectByName(module.ldbName);

	if ns.profile[name].brokerSets~="_none" then
		local collected,total = C_TransmogSets.GetBaseSetsCounts();
		addToBroker(tmp,"violet","Sets",collected,total,session.misc.sets);
	end

	if ns.profile[name].brokerArmor~="_none" then
		local collected,total,sess = 0,0,0;
		for i=1, 11 do
			local v = TRANSMOG_SLOTS[i];
			collected = collected + (C_TransmogCollection.GetCategoryCollectedCount(v.armorCategoryID) or 0);
			total = total + (C_TransmogCollection.GetCategoryTotal(v.armorCategoryID) or 0);
			sess = sess + (session.armor[v.slot] or 0);
		end
		addToBroker(tmp,"dkyellow","Armor",collected,total,sess);
	end

	if ns.profile[name].brokerWeapons~="_none" then
		local collected,total,sess,ids = 0,0,0,{}
		for categoryID = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE do
			local name, isWeapon = C_TransmogCollection.GetCategoryInfo(categoryID);
			if name and isWeapon then
				collected = collected + (C_TransmogCollection.GetCategoryCollectedCount(categoryID) or 0);
				total = total + (C_TransmogCollection.GetCategoryTotal(categoryID) or 0);
				sess = sess + (session.weapons[name] or 0);
			end
		end
		addToBroker(tmp,"orange","Weapons",collected,total,sess);
	end

	if ns.profile[name].brokerIllusions~="_none" then
		local illusions = C_TransmogCollection.GetIllusions();
		local collected,total,sum = 0,#illusions,"";
		for i=1, total do
			if illusions[i].isCollected then
				collected=collected+1;
			end
		end
		addToBroker(tmp,"ltblue","Illusions",collected,total,session.misc.illusions);
	end

	obj.text = #tmp>0 and table.concat(tmp,", ") or WARDROBE;
end

local function resetSessionCounter(x)
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
	if x then
		updateBroker();
	end
end

local function sortWeapons(a,b)
	return a[2]<b[2];
end

local function updateData()
end

local function addLine(color,name,collected,total,session)
	tt:AddLine( C(color,name), ctForm:format(collected,total), C("%.1f%%"):format(collected/total*100), session<collected and C("ltgreen","+"..(collected-session)) or "");
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",WARDROBE));

	updateData();

	-- armor
	local collected,total,sess,lines = 0,0,0,{};
	for i=1, 11 do
		local c,t,s;
		c = C_TransmogCollection.GetCategoryCollectedCount(TRANSMOG_SLOTS[i].armorCategoryID) or 0;
		t = C_TransmogCollection.GetCategoryTotal(TRANSMOG_SLOTS[i].armorCategoryID) or 0;
		s = session.armor[TRANSMOG_SLOTS[i].slot] or 0;
		collected,total,sess = collected+c,total+t,sess+s;
		tinsert(lines,{"ltyellow",_G[TRANSMOG_SLOTS[i].slot],c,t,s});
	end
	tt:AddSeparator(4,0,0,0,0);
	--tt:AddLine(C("ltblue",ARMOR),ctForm:format(collected,total),("%.1f%%"):format(collected/total*100));
	addLine("ltblue",ARMOR,collected,total,sess);
	tt:AddSeparator();
	for i=1,#lines do
		addLine(unpack(lines[i]));
	end

	-- weapons
	local collected,total,sess,lines = 0,0,0,{};
	for categoryID = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE do
		local n, isWeapon = C_TransmogCollection.GetCategoryInfo(categoryID);
		if n and isWeapon then
			local c,t,s;
			c = C_TransmogCollection.GetCategoryCollectedCount(categoryID) or 0;
			t = C_TransmogCollection.GetCategoryTotal(categoryID) or 0;
			s = session.weapons[n] or 0
			collected,total,sess = collected+c,total+t,sess+s;
			tinsert(lines,{"ltyellow",n,c,t,s});
		end
	end
	tt:AddSeparator(4,0,0,0,0);
	tt:AddLine(C("ltblue",HEIRLOOMS_CATEGORY_WEAPON),ctForm:format(collected,total),("%.1f%%"):format(collected/total*100),sess<collected and C("ltgreen","+"..(collected-sess)) or "");
	tt:AddSeparator();
	table.sort(lines,sortWeapons);
	for _,v in pairs(lines)do
		addLine(unpack(v));
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
	addLine("ltyellow",WEAPON_ENCHANTMENT,collected,total,session.misc.illusions);

	-- sets
	local collected,total = C_TransmogSets.GetBaseSetsCounts();
	addLine("ltyellow",WARDROBE_SETS,collected,total,session.misc.sets);

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
		"BAG_UPDATE_DELAYED"
	},
	config_defaults = {
		enabled = false,
		brokerSets = "_none",
		brokerWeapons = "_none",
		brokerArmor = "_none",
		brokerIllusions = "_none"
	},
	clickOptionsRename = {
		["menu"] = "9_open_menu"
	},
	clickOptions = {
		--["wardrobe"] = {"Wardrobe","call",""}, -- problematically. colectionframe will be tained on open...
		["menu"] = "OptionMenuCustom"
	}
}

ns.ClickOpts.addDefaults(module,{
	-- wardrobe = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			brokerSets      = { type="select", order=10, width="double", name=L["Sets"], desc=L["WardrobeSetsDesc"], values=brokerValues },
			brokerArmor     = { type="select", order=11, width="double", name=L["Armor"], desc=L["WardrobeArmorDesc"], values=brokerValues },
			brokerWeapons   = { type="select", order=12, width="double", name=L["Weapons"], desc=L["WardrobeWeaponsDesc"], values=brokerValues },
			brokerIllusions = { type="select", order=13, width="double", name=L["Illusions"], desc=L["WardrobeIllusionsDesc"], values=brokerValues },
		}
	}
end

function module.OptionMenu(self,button,modName)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:AddConfig(name);
	ns.EasyMenu:AddEntry({separator=true});
	ns.EasyMenu:AddEntry({ label = C("yellow",L["Reset session earn/loss counter"]), func=resetSessionCounter, keepShown=false });
	ns.EasyMenu:ShowMenu(self);
end

-- function module.init() end

function module.onevent(self,event,...)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGIN" then
		resetSessionCounter();
	end
	if ns.eventPlayerEnteredWorld then
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

