
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "WoWToken"; -- L["ModDesc-WoWToken"]
local ttName,ttColumns,tt,icon,module,_ = name.."TT",1;
local price = {last=0,money=0,diff=0};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\ICONS\\WoW_Token01",coords={0.05,0.95,0.05,0.95}}; --IconName::WoWToken--


-- some local functions --
--------------------------


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"TOKEN_MARKET_PRICE_UPDATED"
	},
	onupdate_interval = 120,
	config_defaults = {
		enabled = false,
		diff=true,
		history=true
	},
};

function module.options()
	return {
		tooltip = {
			diff={ type="toggle", name=L["Difference"], desc=L["Show difference of last change in tooltip"]},
			history={ type="toggle", name=L["Price history"], desc=L["Show price history of the 5 last changes in tooltip"]},
		},
		misc = {
			shortNumbers=true
		},
	};
end

-- function module.init() end

function module.onevent(self,event,msg)
	if event=="PLAYER_LOGIN" then
		if Broker_Everything_DataDB[name]==nil then
			Broker_Everything_DataDB[name] = {};
		end
		if(#Broker_Everything_DataDB[name]>0 and Broker_Everything_DataDB[name][1].last<time()-(60*30))then
			wipe(Broker_Everything_DataDB[name]);
		end
		C_WowTokenPublic.UpdateMarketPrice();
	elseif event=="TOKEN_MARKET_PRICE_UPDATED" then
		if(#Broker_Everything_DataDB[name]==0 or (#Broker_Everything_DataDB[name]>0 and Broker_Everything_DataDB[name][1].money~=price.money))then
			tinsert(Broker_Everything_DataDB[name],1,{money=price.money,last=price.last});
			if(#Broker_Everything_DataDB[name]==7)then tremove(Broker_Everything_DataDB[name],7); end
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

			local obj = ns.LDB:GetDataObjectByName(module.ldbName);
			obj.text = ns.GetCoinColorOrTextureString(name,current,{hideMoney=3});
		end
	end
end

function module.onupdate()
	C_WowTokenPublic.UpdateMarketPrice();
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end

function module.ontooltip(tt)
	local l;
	tt:AddLine(L[name]);
	tt:AddLine(" ");
	if(price.last~=0)then
		tt:AddDoubleLine(
			C("ltblue",L["Current price:"]),
			ns.GetCoinColorOrTextureString(name,price.money,{hideMoney=3,inTooltip=true})
		);
		tt:AddDoubleLine(
			C("ltblue",L["Last changed:"]),
			C("ltyellow",date("%Y-%m-%d %H:%M",price.last))
		);
		if(ns.profile[name].diff and price.diff)then
			local diff=0;
			if(price.diff<0)then
				diff = "- "..ns.GetCoinColorOrTextureString(name,-price.diff,{hideMoney=3,inTooltip=true});
			else
				diff = ns.GetCoinColorOrTextureString(name,price.diff,{hideMoney=3,inTooltip=true});
			end
			tt:AddDoubleLine(
				C("ltblue",L["Difference to previous:"]),
				diff
			);
		end
		if(ns.profile[name].history and #Broker_Everything_DataDB[name]>1)then
			tt:AddLine(" ");
			tt:AddLine(C("ltblue",L["Price history (last 5 changes)"]));
			for i,v in ipairs(Broker_Everything_DataDB[name])do
				if(i>1 and v.money>0)then
					tt:AddDoubleLine(date("%Y-%m-%d %H:%M",v.last),ns.GetCoinColorOrTextureString(name,v.money,{hideMoney=3,inTooltip=true}));
				end
			end
		end
	else
		tt:AddLine(C("orange",L["Currently no price available..."]));
	end
end

-- function module.onenter(self) end
-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
