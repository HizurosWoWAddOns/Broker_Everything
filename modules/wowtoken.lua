
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "WoWToken" -- L["WoWToken"]
local ldbName, ttName = name, name.."TT"
local tt,_,icon = nil
local ttColumns = 1;
local price = {last=0,money=0,diff=0};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\ICONS\\WoW_Token01",coords={0.05,0.95,0.05,0.95}}; --IconName::WoWToken--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Show on broker button and in tooltip the current amount of gold for a WoW Token. (Updating in two minute interval)."]
ns.modules[name] = {
	desc = desc,
	events = {
		"ADDON_LOADED",
		"PLAYER_ENTERING_WORLD",
		"TOKEN_MARKET_PRICE_UPDATED"
	},
	updateinterval = 120, -- false or integer
	config_defaults = {
		diff=true,
		history=true,
	},
	config_allowed = {},
	config = {
		{ type="header",                 label=L[name], align="left", icon=I[name] },
		{ type="toggle", name="diff",    label=L["Show difference"], tooltip=L["Show difference of last change in tooltip"]},
		{ type="toggle", name="history", label=L["Show history"],    tooltip=L["Show history of the 5 last changes in tooltip"]},
	}
}


--------------------------
-- some local functions --
--------------------------


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	if(event=="ADDON_LOADED" and msg==addon)then
		if(be_wowtoken_db==nil)then
			be_wowtoken_db={};
		end
		if(#be_wowtoken_db>0 and be_wowtoken_db[1].last<time()-(60*30))then
			wipe(be_wowtoken_db);
		end
	elseif(event=="PLAYER_ENTERING_WORLD")then
		L[name] = GetItemInfo(122284);
		C_WowTokenPublic.UpdateMarketPrice();
	elseif(event=="TOKEN_MARKET_PRICE_UPDATED")then

		if(#be_wowtoken_db==0 or (#be_wowtoken_db>0 and be_wowtoken_db[1].money~=price.money))then
			tinsert(be_wowtoken_db,1,{money=price.money,last=price.last});
			if(#be_wowtoken_db==7)then tremove(be_wowtoken_db,7); end
		end

		local current = C_WowTokenPublic.GetCurrentMarketPrice();

		if(current)then
			if(current~=price.money)then
				local prev=price.money;
				price = {last=time(),money=current};
				if(prev>0)then
					price.diff=price.money-prev;
				end
			end

			local obj = ns.LDB:GetDataObjectByName(ldbName);
			obj.text = ns.GetCoinColorOrTextureString(name,current,{hideLowerZeros=true});
		end
	end
end

ns.modules[name].onupdate = function(self)
	C_WowTokenPublic.UpdateMarketPrice();
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)
	local l;
	--tt:AddHeader(C("dkyellow",L[name]));
	--tt:AddSeparator(4,0,0,0,0);
	tt:AddLine(L[name]);
	tt:AddLine(" ");
	if(price.last~=0)then
		tt:AddDoubleLine(
			C("ltblue",L["Current price:"]),
			ns.GetCoinColorOrTextureString(name,price.money,{hideLowerZeros=true})
		);
		tt:AddDoubleLine(
			C("ltblue",L["Last changed:"]),
			C("ltyellow",date("%Y-%m-%d %H:%M",price.last))
		);
		if(Broker_EverythingDB[name].diff and price.diff)then
			local diff=0;
			if(price.diff<0)then
				diff = "- "..ns.GetCoinColorOrTextureString(name,-price.diff,{hideLowerZeros=true});
			else
				diff = ns.GetCoinColorOrTextureString(name,price.diff,{hideLowerZeros=true});
			end
			tt:AddDoubleLine(
				C("ltblue",L["Diff to previous:"]),
				diff
			);
		end
		if(Broker_EverythingDB[name].history and #be_wowtoken_db>1)then
			tt:AddLine(" ");
			tt:AddLine(C("ltblue",L["Price history (last 5 changes)"]));
			for i,v in ipairs(be_wowtoken_db)do
				if(i>1 and v.money>0)then
					tt:AddDoubleLine(date("%Y-%m-%d %H:%M",v.last),ns.GetCoinColorOrTextureString(name,v.money,{hideLowerZeros=true}));
				end
			end
		end
	else
		tt:AddLine(C("orange",L["Currently no price available..."]));
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
--ns.modules[name].onenter = function(self)
--	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT");
--	ns.modules[name].ontooltip(tt)
--	ns.createTooltip(self,tt);
--end

--ns.modules[name].onleave = function(self)
--	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
--end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

