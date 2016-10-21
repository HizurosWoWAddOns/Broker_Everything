
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
L.Gold = BONUS_ROLL_REWARD_MONEY;

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Gold";
local ldbName, ttName, tt, createMenu, createTooltip = name, name.."TT";
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
ns.modules[name] = {
	desc = L["Broker to show gold of all your chars and lost and earned money for the current session"],
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
		showCharGold = true,
		--showRealmGold = false,
		showSessionProfit = true
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="showAllRealms",     label=L["Show all realms"],     tooltip=L["Show characters from all realms in tooltip."] },
		{ type="toggle", name="showAllFactions",   label=L["Show all factions"],   tooltip=L["Show characters from all factions in tooltip."] },
		{ type="toggle", name="showCharGold",      label=L["Show character gold"], tooltip=L["Show character gold on broker button"], event=true },
		--{ type="toggle", name="showRealmGold",     label=L["Show realm gold"],     tooltip=L["Show summary of gold on current realm (factionbound) on broker button"] },
		{ type="toggle", name="showSessionProfit", label=L["Show session profit"], tooltip=L["Show session profit on broker button"], event=true }
	},
	clickOptions = {
		["1_open_tokenframe"] = {
			cfg_label = "Open currency pane", -- L["Open currency pane"]
			cfg_desc = "open the currency pane", -- L["open the currency pane"]
			cfg_default = "_LEFT",
			hint = "Open currency pane",
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCharacter","TokenFrame");
			end
		},
		["2_open_character_info"] = {
			cfg_label = "Open character info", -- L["Open character info"]
			cfg_desc = "open the character info", -- L["open the character info"]
			cfg_default = "__NONE",
			hint = "Open character info", -- L["Open character info"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCharacter","PaperDollFrame");
			end
		},
		["3_open_bags"] = {
			cfg_label = "Open all bags", -- L["Open all bags"]
			cfg_desc = "open your bags", -- L["open your bags"]
			cfg_default = "__NONE",
			hint = "Open all bags", -- L["Open all bags"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleAllBags");
			end
		},
		["4_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self);
			end
		}
	}
}

-- [Abzeichen,Character,Bags,Option menu]

--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.addEntry({separator=true});
	ns.EasyMenu.addEntry({ label = C("yellow",L["Reset session profit"]), func=function() ns.modules[name].onevent(nil,"PLAYER_LOGIN"); end, keepShown=false });
	ns.EasyMenu.ShowMenu(self);
end

local function getProfit()
	local direction,profit = 0,0;
	if login_money==nil then
		profit = false;
	elseif current_money>login_money then
		profit = current_money-login_money;
		direction = 1;
	elseif current_money<login_money then
		profit = login_money-current_money;
		direction = -1;
	end
	return profit, direction;
end

local function deleteCharacterGoldData(self,_,button)
	if button == "RightButton" then
		Broker_Everything_CharacterDB[name_realm].gold = nil;
		tt:Clear();
		createTooltip(tt,true);
	end 
end

function createTooltip(tt,update)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	local sAR,sAF = ns.profile[name].showAllRealms==true,ns.profile[name].showAllFactions==true;
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
	for i=1, #Broker_Everything_CharacterDB.order do
		local name_realm = Broker_Everything_CharacterDB.order[i];
		local charName,realm=strsplit("-",name_realm);
		local v = Broker_Everything_CharacterDB[name_realm];

		if (v.gold) and (sAR==true or (sAR==false and realm==ns.realm)) and (sAF==true or (sAF==false and v.faction==ns.player.faction)) and (ns.player.name_realm~=name_realm) then
			local faction = v.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
			local realm = sAR==true and C("dkyellow"," - "..ns.scm(realm)) or "";
			local line, column = tt:AddLine( C(v.class,ns.scm(charName)) .. realm .. faction, ns.GetCoinColorOrTextureString(name,v.gold));

			tt:SetLineScript(line, "OnMouseUp", deleteCharacterGoldData);

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

	local profit, direction = getProfit();
	if profit then
		local sign = (direction==1 and "|Tinterface\\buttons\\ui-microstream-green:14:14:0:0:32:32:6:26:26:6|t") or (direction==-1 and "|Tinterface\\buttons\\ui-microstream-red:14:14:0:0:32:32:6:26:6:26|t") or "";
		tt:AddLine(profit<0 and C("ltred",L["Session loss"]) or C("ltgreen",L["Session profit"]), sign .. ns.GetCoinColorOrTextureString(name,profit));
	else
		tt:AddLine(C("ltgreen",L["Session profit"]),C("orange","Error"));
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(3,0,0,0,0);
		tt:SetCell(tt:AddLine(), 1, C("ltblue",L["Right-click"]).." || "..C("green",L["Remove entry"]), nil, nil, 2);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end

	if not update then
		ns.roundupTooltip(tt);
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
	if(ns.toon.gold==nil)then
		ns.toon.gold = 0;
	end
end

ns.modules[name].onevent = function(self,event,msg)
	current_money = GetMoney();
	ns.toon.gold = current_money;

	if(event=="PLAYER_LOGIN")then
		login_money = current_money;
	end
	local broker = {};
	if ns.profile[name].showCharGold then
		tinsert(broker,ns.GetCoinColorOrTextureString(name,current_money));
	end
	--[[if ns.profile[name].showRealmGold then
		tinsert(broker,ns.GetCoinColorOrTextureString(name,current_money));
	end]]
	if ns.profile[name].showSessionProfit and login_money then
		local profit, direction = getProfit();
		local sign = (direction==1 and "|Tinterface\\buttons\\ui-microstream-green:14:14:0:0:32:32:6:26:26:6|t") or (direction==-1 and "|Tinterface\\buttons\\ui-microstream-red:14:14:0:0:32:32:6:26:6:26|t") or "";
		tinsert(broker, sign .. ns.GetCoinColorOrTextureString(name,profit));
	end
	if #broker==0 then
		broker = {L[name]};
	end
	ns.LDB:GetDataObjectByName(ldbName).text = table.concat(broker,", ");
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, 2, "LEFT", "RIGHT"},{false},{self})
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end
