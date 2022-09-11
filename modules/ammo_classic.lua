
-- module independent variables --
----------------------------------
local addon, ns = ...
if not (ns.client_version<5 and ns.player.class=="HUNTER") then return end
local C, L, I = ns.LC.color, ns.L, ns.I
ns.ammo_classic = true;

-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Ammo"; -- INVTYPE_AMMO L["ModDesc-Ammo"]
local ttName, ttColumns, tt, module, createTooltip = name.."TT", 2;
local ammo = {sum=false,inUse=0,itemInfo={}};

-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=133581,coords={0.05,0.95,0.05,0.95}}; --IconName::Talents--


-- some local functions --
--------------------------
local function updateBroker()
	if not ammo.sum then return end
	local obj,icon,text = ns.LDB:GetDataObjectByName(module.ldbName) or {};
	if ammo.inUse and ammo.itemInfo[ammo.inUse] then
		local itemInfo = ammo.itemInfo[ammo.inUse];
		icon = itemInfo.icon
		text = C( (itemInfo.count<=10 and "red") or (itemInfo.count<=25 and "orange") or (itemInfo.count<=50 and "yellow") or "green",itemInfo.count)
		if ns.profile[name].showNameBroker then
			text = text .. " " .. C("quality"..itemInfo.quality,itemInfo.name);
		end
	else
		icon,text = 133581,C("gray",L["No ammo attached"]);
	end
	obj.icon,obj.text = icon,text;
end

local function sortAmmo(a,b)
	return a.name>b.name;
end

function createTooltip(tt,update)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end
	tt:SetCell(tt:AddLine(),1,C("dkyellow",INVTYPE_AMMO),tt:GetHeaderFont(),"LEFT",0);
	tt:AddSeparator(1);
	if ammo.sum==0 then
		tt:SetCell(tt:AddLine(),1,C("ltgray",L["No ammo found..."]),nil,nil,0);
	else
		table.sort(ammo.itemInfo,sortAmmo);
		for id,itemInfo in pairs(ammo.itemInfo) do
			tt:AddLine("|T"..itemInfo.icon..":0|t "..C("quality"..itemInfo.quality,itemInfo.name)..(ammo.inUse==id and " "..C("green","("..CONTRIBUTION_ACTIVE..")") or ""),C("white",itemInfo.count));
		end
	end
	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

local function updateAmmo()
	local sum,itemInfo,_ = 0,{};
	for sharedSlot in pairs(ns.items.ammo) do
		local item = ns.items.bySlot[sharedSlot];
		local _, count = GetContainerItemInfo(item.bag,item.slot);
		if not itemInfo[item.id] then
			itemInfo[item.id] = {count=count};
			itemInfo[item.id].name,_,itemInfo[item.id].quality,_,_,_,_,_,_,itemInfo[item.id].icon = GetItemInfo(item.id);
		else
			itemInfo[item.id].count = itemInfo[item.id].count + count;
		end
		sum = sum + count;
	end
	ammo.inUse = GetInventoryItemID("player",0);
	ammo.sum = sum;
	ammo.itemInfo = itemInfo;

	updateBroker();
	createTooltip(tt,true);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"UNIT_RANGEDDAMAGE",
	},
	config_defaults = {
		enabled = true,
		showNameBroker = true
	},
	clickOptionsRename = {},
	clickOptions = {}
}

--ns.ClickOpts.addDefaults(module,{});

function module.options()
	return {
		broker = {
			showNameBroker = { type="toggle", order=1, name=L["Show ammunition name"], desc=L["Display ammunition name on broker button"] }
		},
		tooltip = nil,
		misc = nil,
	}
end

function module.init()
	ns.items.RegisterCallback(name,updateAmmo,"bags");
end

--[[
function module.createTalentMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:ShowMenu(self);
end
--]]

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" then
		if arg1 and arg1:find("^ClickOpt") then
			ns.ClickOpts.update(name);
		end
	elseif event=="UNIT_RANGEDDAMAGE" then
		updateAmmo();
		return;
	end
	updateBroker();
end

-- function module.onmousewheel(self,direction) end
-- function module.optionspanel(panel) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "CENTER", "CENTER", "CENTER", "CENTER"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
