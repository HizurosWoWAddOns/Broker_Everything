
-- module independent variables --
----------------------------------
local addon, ns = ...
local classes = {HUNTER=true,ROGUE=true,WARRIOR=true,--[[WARLOCK=true]]};
if not (ns.client_version<5 and classes[ns.player.class]) then return end
local C, L, I = ns.LC.color, ns.L, ns.I
ns.ammo_classic = true;


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Ammo"; -- INVTYPE_AMMO L["ModDesc-Ammo"]
local ttName, ttColumns, tt, module, createTooltip = name.."TT", 2;
local ammo = {sum=false,inUse=0,itemInfo={}};
local thrown = {sum=false,inUse=0,itemInfo={}};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=133581,coords={0.05,0.95,0.05,0.95}}; --IconName::Talents--


-- some local functions --
--------------------------
local function updateBroker()
	if not (ammo.sum or thrown.sum) then return end
	local obj,icon,text = ns.LDB:GetDataObjectByName(module.ldbName) or {};
	local itemInfoInUse = false;
	if ammo.inUse and ammo.itemInfo[ammo.inUse] then
		itemInfoInUse = ammo.itemInfo[ammo.inUse];
	elseif thrown.inUse and thrown.itemInfo[thrown.inUse] then
		itemInfoInUse = thrown.itemInfo[thrown.inUse];
	end
	if itemInfoInUse then
		icon = itemInfoInUse.icon
		text = C( (itemInfoInUse.count<=10 and "red") or (itemInfoInUse.count<=25 and "orange") or (itemInfoInUse.count<=50 and "yellow") or "green",itemInfoInUse.count)
		if ns.profile[name].showNameBroker then
			text = text .. " " .. C("quality"..(itemInfoInUse.quality or 1),itemInfoInUse.name);
		end
	else
		icon,text = 133581,C("gray",L["No ammo attached"]);
	end
	obj.icon,obj.text = icon,text;
end

local function sortItems(a,b)
	return a.name>b.name;
end

function createTooltip(tt,update)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end
	tt:SetCell(tt:AddLine(),1,C("dkyellow",INVTYPE_AMMO.." / "..INVTYPE_THROWN),tt:GetHeaderFont(),"LEFT",0);
	tt:AddSeparator(1);
	if ammo.sum>0 then
		tt:AddLine(C("ltgray",INVTYPE_AMMO))
		table.sort(ammo.itemInfo,sortItems);
		for id,itemInfo in pairs(ammo.itemInfo) do
			tt:AddLine("    |T"..itemInfo.icon..":0|t "..C("quality"..itemInfo.quality,itemInfo.name)..(ammo.inUse==id and " "..C("green","("..CONTRIBUTION_ACTIVE..")") or ""),C("white",itemInfo.count));
		end
	end
	if thrown.sum>0 then
		tt:AddLine(C("ltgray",INVTYPE_THROWN))
		table.sort(thrown.itemInfo,sortItems);
		for id,itemInfo in pairs(thrown.itemInfo)do
			tt:AddLine("    |T"..itemInfo.icon..":0|t "..C("quality"..itemInfo.quality,itemInfo.name)..(thrown.inUse==id and " "..C("green","("..CONTRIBUTION_ACTIVE..")") or ""),C("white",itemInfo.count));
		end
	end
	if ammo.sum==0 and thrown.sum==0 then
		tt:SetCell(tt:AddLine(),1,C("ltgray",L["No ammo or throwing weapon found..."]),nil,nil,0);
	end
	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

local function updateItems()
	local sum,items,s,_ = {a=0,t=0},{a={},t={}},"a";
	for sharedSlot in pairs(ns.items.ammo) do
		local item,count = ns.items.bySlot[sharedSlot],-1;
		if sharedSlot<0 then
			-- inventory
			count = GetInventoryItemCount("player",18);
		else
			-- container
			local info = (C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo)(item.bag,item.slot);
			if info then
				count = info.stackCount;
			end
		end
		if item.ammo==2 then
			s="t"
		end
		if count>0 then
			if not items[s][item.id] then
				items[s][item.id] = {count=count};
				items[s][item.id].name,_,items[s][item.id].quality,_,_,_,_,_,_,items[s][item.id].icon = GetItemInfo(item.id);
			else
				items[s][item.id].count = items[s][item.id].count + count;
			end
			sum[s] = sum[s] + count;
		else
			ns:debugPrint("Ammo",sharedSlot,count);
		end
	end
	ammo.inUse = GetInventoryItemID("player",0);
	ammo.sum = sum.a;
	ammo.itemInfo = items.a;

	thrown.inUse = GetInventoryItemID("player",18);
	thrown.sum = sum.t;
	thrown.itemInfo = items.t;

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
	ns.items.RegisterCallback(name,updateItems,"ammo");
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
		updateItems();
		return;
	end
	updateBroker();
end

-- function module.onmousewheel(self,direction) end
-- function module.optionspanel(panel) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "CENTER", "CENTER"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
