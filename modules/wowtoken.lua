
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
local price = {last=0,money=0};
local priceHistory = {};


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
		"PLAYER_ENTERING_WORLD",
		"TOKEN_MARKET_PRICE_UPDATED"
	},
	updateinterval = 120, -- false or integer
	config_defaults = {},
	config_allowed = {},
	config = { { type="header", label=L[name], align="left", icon=I[name] } }
}


--------------------------
-- some local functions --
--------------------------
local function updatePrice()
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	if(event=="PLAYER_ENTERING_WORLD")then
		L[name] = GetItemInfo(122284);
		C_WowTokenPublic.UpdateMarketPrice();
	elseif(event=="TOKEN_MARKET_PRICE_UPDATED")then
		local current = C_WowTokenPublic.GetCurrentMarketPrice();
		if(current)then
			if(current~=price.money)then
				local prev=price.money;
				price = {last=time(),money=current};
				if(prev>0)then
					price.diff=price.money-prev;
				end
			end

			tinsert(priceHistory,1,price.money/10000);
			if(#priceHistory==51)then tremove(priceHistory,51); end
			if(tt and tt.key and tt.key==ttName)then
				--ns.graphTT.Update(tt,priceHistory);
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
		if(price.diff)then
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
		if(#priceHistory>0)then
			--ns.graphTT.Update(tt,priceHistory);
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

