
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Gold" -- L["Gold"]
local ldbName, ttName, tt = name, name.."TT";
local login_money = nil;
local next_try = false;
local current_money = 0
local faction = UnitFactionGroup("Player")


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Minimap\\TRACKING\\Auctioneer",coords={0.05,0.95,0.05,0.95}} --IconName::Gold--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show gold information. Shows gold amounts for characters on the same realm and faction and the amount made or lost for the session."]
ns.modules[name] = {
	desc = desc,
	events = {
		"PLAYER_LOGIN",
		"PLAYER_MONEY",
		"PLAYER_TRADE_MONEY",
		"TRADE_MONEY_CHANGED",
		"PLAYER_ENTERING_WORLD"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		goldColor = nil,
		showAllRealms = true,
		showAllFactions = true,
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showAllRealms", label=L["Show all realms"], tooltip=L["Show characters from all realms in tooltip."] },
		{ type="toggle", name="showAllFactions", label=L["Show all factions"], tooltip=L["Show characters from all factions in tooltip."] },
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
	if(be_character_cache[ns.player.name_realm].gold==nil)then
		be_character_cache[ns.player.name_realm].gold = 0;
	end
end

ns.modules[name].onevent = function(self,event,msg)
	current_money = GetMoney();
	be_character_cache[ns.player.name_realm].gold = current_money;

	if(event=="PLAYER_LOGIN")then
		login_money = current_money;
	end

	(self.obj or ns.LDB:GetDataObjectByName(ldbName)).text = ns.GetCoinColorOrTextureString(name,current_money)
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...

	local sAR,sAF = Broker_EverythingDB[name].showAllRealms==true,Broker_EverythingDB[name].showAllFactions==true;
	local totalGold = current_money;
	local diff_money

	tt:Clear()

	tt:AddHeader(C("dkyellow",L["Gold information"]));
	tt:AddSeparator(4,0,0,0,0);

	if(sAR or sAF)then
		tt:AddLine(C("ltgreen", (sAR and sAF and "("..L["all realms and factions"]..")") or (sAR and "("..L["all realms"]..")") or (sAF and "("..L["all factions"]..")") or "" ));
		tt:AddSeparator(4,0,0,0,0);
	end

	local faction = ns.player.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..ns.player.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
	tt:AddLine(C(ns.player.class,ns.player.name) .. faction, ns.GetCoinColorOrTextureString(name,current_money));
	tt:AddSeparator();

	local lineCount=0;
	for i=1, #be_character_cache.order do
		local name_realm = be_character_cache.order[i];
		local charName,realm=strsplit("-",name_realm);
		local v = be_character_cache[name_realm];

		if (v.gold) and (sAR==true or (sAR==false and realm==ns.realm)) and (sAF==true or (sAF==false and v.faction==ns.player.faction)) and (ns.player.name_realm~=name_realm) then
			local faction = v.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
			local realm = sAR==true and C("dkyellow"," - "..ns.scm(realm)) or "";
			local line, column = tt:AddLine( C(v.class,ns.scm(charName)) .. realm .. faction, ns.GetCoinColorOrTextureString(name,v.gold));

			tt:SetLineScript(line, "OnMouseUp", function(self,x,button)
				if button == "RightButton" then
					be_character_cache[name_realm].gold = nil;
					tt:Clear();
					ns.modules[name].ontooltip(tt);
				end 
			end)

			tt:SetLineScript(line, "OnEnter", function(self) tt:SetLineColor(line, 1,192/255, 90/255, 0.3); end );
			tt:SetLineScript(line, "OnLeave", function(self) tt:SetLineColor(line, 0,0,0,0); end);

			totalGold = totalGold + v.gold;

			line, column = nil, nil;
			lineCount=lineCount+1;
		end
	end

	if(lineCount>0)then
		tt:AddSeparator()
		tt:AddLine(L["Total Gold"], ns.GetCoinColorOrTextureString(name,totalGold))
	end
	tt:AddSeparator(3,0,0,0,0)

	if login_money == nil then
		tt:AddLine(L["Session profit"], C("orange","Error"))
	elseif current_money == login_money then
		tt:AddLine(L["Session profit"], ns.GetCoinColorOrTextureString(name,0))
	elseif current_money > login_money then
		tt:AddLine(C("ltgreen",L["Session profit"]), "+ " .. ns.GetCoinColorOrTextureString(name,current_money - login_money))
	else
		tt:AddLine(C("ltred",L["Session loss"]), "- " .. ns.GetCoinColorOrTextureString(name,login_money - current_money))
	end

	if Broker_EverythingDB.showHints then
		tt:AddSeparator(3,0,0,0,0)
		line, column = tt:AddLine()
		tt:SetCell(line, 1, C("ltblue",L["Right-click"]).." || "..C("green",L["Remove entry"]), nil, nil, 2)
		line, column = tt:AddLine()
		tt:SetCell(line, 1, C("copper",L["Click"]).." || "..C("green",L["Open currency pane"]), nil, nil, 2)
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	tt = ns.LQT:Acquire(ttName, 2, "LEFT", "RIGHT")
	ns.modules[name].ontooltip(tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

ns.modules[name].onclick = function(self,button)
	securecall("ToggleCharacter","TokenFrame")
end

-- ns.modules[name].ondblclick = function(self,button) end
