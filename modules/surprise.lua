
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<4 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Surprise" -- L["Surprise"] L["ModDesc-Surprise"]
local ttName,ttColumns,tt,module = name.."TT",3,nil
local ITEM_DURATION,ITEM_COOLDOWN,ITEM_LOOTABLE=1,2,3
local founds,items = {};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\INV_misc_gift_01",coords={0.05,0.95,0.05,0.95}}; --IconName::Surprise--


-- some local functions --
--------------------------
local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local sum,finished = #founds,0;
	for i=1, sum do
		if items[founds[i].id] and items[founds[i].id][1]==ITEM_LOOTABLE then
			finished = finished+1;
		end
	end
	if sum>0 then
		obj.text = C(finished==0 and "gray" or "green",finished) .. "/" .. sum;
	else
		obj.text = C("gray",0).."/0";
	end
end

local function ScanTT_Callback(data)
	tinsert(founds,data);
	updateBroker();
end

local function bagCheck()
	wipe(founds);
	for sharedSlot,item in pairs(ns.items.bySlot) do
		if item.bag>=0 and items[item.id] then
			local t = CopyTable(item);
			t.type = "bag";
			t.callback = ScanTT_Callback;
			ns.ScanTT.query(t);
		end
	end
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...

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
				or (items[item.id][1]==ITEM_LOOTABLE and C("green",L["(finished)"]))
				or "("..UNKNOWN..")"
			);
		end
	else
		tt:AddLine(L["No item found."]);
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
	-- see https://wow.curseforge.com/projects/broker-everything/pages/modules/surprise
	items = {
		-- 1. Unhatched Jubling Egg >> A Jubling's Tiny Home
		[19462] = {ITEM_COOLDOWN, "duration"},
		[19450] = {ITEM_LOOTABLE},

		-- 2. Mysterious Egg >> Cracked Egg
		[39878] = {ITEM_DURATION, "tooltip", 4},
		[39883] = {ITEM_LOOTABLE},

		-- 3. Disgusting Jar >> Ripe Disgusting Jar
		[44717] = {ITEM_DURATION, "tooltip", 4},
		[44718] = {ITEM_LOOTABLE},

		-- 4. Hyldnir Spoils (from daily quest)
		[44751] = {ITEM_LOOTABLE},

		-- 5. Primal Egg >> Cracked Primal Egg
		[94295] = {ITEM_DURATION, "tooltip", 4},
		[94296] = {ITEM_LOOTABLE},

		-- 6. Warm Goren Egg >> Cracked Goren Egg
		[118705] = {ITEM_DURATION, "tooltip", 4},
		[118706] = {ITEM_LOOTABLE},

		-- 7. Strange Green Fruit >> Ripened Strange Fruit
		[127396] = {ITEM_DURATION, "tooltip", 4},
		[127395] = {ITEM_LOOTABLE},

		-- 8. Pulsating Sac >> Growling Sac
		[137599] = {ITEM_DURATION, "tooltip", 5},
		[137608] = {ITEM_LOOTABLE},

		-- 9. Time-Lost Wallet (from quest)
		[151482] = {ITEM_LOOTABLE},

		-- 10. Fel-Spotted Egg >> Cracked Fel-Spotted Egg
		[153190] = {ITEM_DURATION, "tooltip", 3},
		[153191] = {ITEM_LOOTABLE},

		-- 11. Viable Cobra Egg >> Cracking Cobra Egg
		[160832] = {ITEM_DURATION, "tooltip", 3},
		[160831] = {ITEM_LOOTABLE},

		-- 12. Nightwreathed Egg >> Nightwreathed Watcher
		[166525] = {ITEM_DURATION, "tooltip", 3},
		[166528] = {ITEM_LOOTABLE},

		-- 13. hairy egg >> Bloodlouse Larva
		[182607] = {ITEM_DURATION, "tooltip", 4},
		[182606] = {ITEM_LOOTABLE},

		-- 14. Blight-Touched Egg >>  Chewed Reins of the Callow Flayedwing
		[184104] = {ITEM_DURATION, "tooltip", 3},
		[181818] = {ITEM_LOOTABLE},

		--
	}
	ns.items.RegisterCallback(name,bagCheck,"bags");
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
