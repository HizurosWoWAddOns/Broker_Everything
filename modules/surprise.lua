
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Surprise" -- L["Surprise"] L["ModDesc-Surprise"]
local ttName,ttColumns,tt,module = name.."TT",3,nil
local ITEM_DURATION,ITEM_COOLDOWN,ITEM_LOOTABLE=1,2,3
local founds,counter,items = {},{sum=0,lootable=0,progress=0};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\INV_misc_gift_01",coords={0.05,0.95,0.05,0.95}}; --IconName::Surprise--


-- some local functions --
--------------------------
local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	if counter.sum>0 then
		obj.text = ((counter.lootable and C("green",counter.lootable)) or C("ltgray",0)) .. "/" .. counter.sum;
	else
		obj.text = C("ltgray",0).."/0";
	end
end

local function resetFunc() -- clear founds table
	wipe(founds);
	counter = {sum=0,lootable=0,progress=0};
	updateBroker();
end

local function callbackFunc(data)
	local status;
	tinsert(founds,data);
	counter.sum = counter.sum+1;
	status = data[1]==ITEM_LOOTABLE and "lootable" or "progress";
	counter[status] = counter[status]+1;
	updateBroker();
end

local function updateFunc() -- update broker
	local item;
	for id,v in pairs(items)do
		item = ns.items.exist(id);
		if(item)then
			for I,V in ipairs(item)do
				if(V.type=="bag")then
					local t = CopyTable(V);
					t.callback = callbackFunc;
					ns.ScanTT.query(t);
				end
			end
		end
	end
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",L[name]))
	tt:AddSeparator(4,0,0,0,0)

	if #founds>0 then
		tt:AddLine(C("ltblue",ITEMS));
		tt:AddSeparator();
		for _,item in ipairs(founds) do
			tt:AddLine(
				("|T%s:12:12:0:-1:64:64:4:56:4:56|t |C%s%s|r"):format(item.itemTexture,C("quality"..item.itemRarity),item.itemName),
				C("dkyellow","||"),
				(type(items[item.id][2])=="function" and items[item.id][2]())
				or (items[item.id][2]=="tooltip" and item.lines[items[item.id][3]])
				or (items[item.id][2]=="duration" and tonumber(item.duraction) and SecondsToTime(item.duraction))
				or (items[item.id][1]==ITEM_LOOTABLE and L["(finished)"])
				or "("..UNKNOWN..")"
			);
		end
	else
		tt:AddLine(L["No item found."])
	end

	ns.roundupTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {},
	config_defaults = {
		enabled = false,
	},
}

-- function module.options() return {} end

function module.init()
	items = {
		-- 1 items with duration time
		[39878] = {ITEM_DURATION, "tooltip", 4}, -- Mysterious Egg (Geen <Oracles Quartermaster>, Sholaar Basin)
		[44717] = {ITEM_DURATION, "tooltip", 4}, -- Disgusting Jar
		[94295] = {ITEM_DURATION, "tooltip", 4}, -- Primal Egg
		[118705] = {ITEM_DURATION, "tooltip", 4}, -- Warm Goren Egg
		[127396] = {ITEM_DURATION, "tooltip", 4}, -- Strange Green Fruit
		[137599] = {ITEM_DURATION, "tooltip", 5}, -- Pulsating Sac
		[153190] = {ITEM_DURATION, "tooltip", 3}, -- Fel-Spotted Egg
		-- 2 items with cooldown time
		[19462] = {ITEM_COOLDOWN, "duration"}, -- Unhatched Jubling Egg
		-- 3 lootable items
		[19450] = {ITEM_LOOTABLE}, -- A Jubling's Tiny Home (prev.: Unhatched Jubling Egg)
		[39883] = {ITEM_LOOTABLE}, -- Cracked Egg (prev.: Mysterious Egg)
		[44718] = {ITEM_LOOTABLE}, -- Ripe Disgusting Jar (prev.: Disgusting Jar)
		[94296] = {ITEM_LOOTABLE}, -- Cracked Primal Egg (prev.: Primal Egg)
		[118706] = {ITEM_LOOTABLE}, -- Cracked Goren Egg
		[127395] = {ITEM_LOOTABLE}, -- Ripened Strange Fruit
		[137608] = {ITEM_LOOTABLE}, -- Growling Sac
		[153191] = {ITEM_LOOTABLE} -- Cracked Fel-Spotted Egg
	}

	ns.items.RegisterPreScanCallback(name,resetFunc);
	for i,v in pairs(items)do
		ns.items.RegisterCallback(name,updateFunc,"item",i);
	end
end

function module.onevent(self,event,...)
	if event=="BE_UPDATE_CFG" then
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT"},{true},{self})
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
