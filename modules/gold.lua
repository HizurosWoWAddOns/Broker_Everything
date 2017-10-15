
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Gold"; -- BONUS_ROLL_REWARD_MONEY
local ttName, tt, createMenu, createTooltip,module = name.."TT";
local login_money = nil;
local next_try = false;
local current_money = 0
local faction = UnitFactionGroup("Player")


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Minimap\\TRACKING\\Auctioneer",coords={0.05,0.95,0.05,0.95}} --IconName::Gold--


-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.addEntry({separator=true});
	ns.EasyMenu.addEntry({ label = C("yellow",L["Reset session profit"]), func=function() module.onevent(nil,"PLAYER_LOGIN"); end, keepShown=false });
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

local function deleteCharacterGoldData(self,name_realm,button)
	if button == "RightButton" then
		Broker_Everything_CharacterDB[name_realm].gold = nil;
		tt:Clear();
		createTooltip(tt,true);
	end
end

local function updateBroker()
	local broker = {};
	if ns.profile[name].showCharGold then
		tinsert(broker,ns.GetCoinColorOrTextureString(name,current_money));
	end
	if ns.profile[name].showSessionProfit and login_money then
		local profit, direction = getProfit();
		local sign = (direction==1 and "|Tinterface\\buttons\\ui-microstream-green:14:14:0:0:32:32:6:26:26:6|t") or (direction==-1 and "|Tinterface\\buttons\\ui-microstream-red:14:14:0:0:32:32:6:26:6:26|t") or "";
		tinsert(broker, sign .. ns.GetCoinColorOrTextureString(name,profit));
	end
	if #broker==0 then
		broker = {BONUS_ROLL_REWARD_MONEY};
	end
	ns.LDB:GetDataObjectByName(module.ldbName).text = table.concat(broker,", ");
end

function createTooltip(tt,update)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	local sAR,sAF = ns.profile[name].showAllRealms==true,ns.profile[name].showAllFactions==true;
	local totalGold,diff_money = {Alliance=0,Horde=0,Neutral=0};
	totalGold[ns.player.faction] = current_money;

	if tt.lines~=nil then tt:Clear(); end

	tt:AddHeader(C("dkyellow",L["Gold information"]));
	tt:AddSeparator(4,0,0,0,0);

	if(sAR or sAF)then
		tt:AddLine(C("ltgreen", (sAR and sAF and "("..L["all realms and factions"]..")") or (sAR and "("..L["all realms"]..")") or (sAF and "("..L["all factions"]..")") or "" ));
		tt:AddSeparator(4,0,0,0,0);
	end

	local faction = ns.player.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..ns.player.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
	tt:AddLine(C(ns.player.class,ns.player.name) .. faction, ns.GetCoinColorOrTextureString(name,current_money,{inTooltip=true}));
	tt:AddSeparator();

	local lineCount=0;
	for i=1, #Broker_Everything_CharacterDB.order do
		local name_realm = Broker_Everything_CharacterDB.order[i];
		local charName,realm,_=strsplit("-",name_realm);
		local v = Broker_Everything_CharacterDB[name_realm];

		if (v.gold) and (ns.player.name_realm~=name_realm) and ns.showThisChar(name,realm,v.faction) then
			local faction = v.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
			if type(realm)=="string" and realm:len()>0 then
				_,realm = ns.LRI:GetRealmInfo(realm);
			end
			local realm = sAR==true and C("dkyellow"," - "..ns.scm(realm)) or "";
			local line, column = tt:AddLine( C(v.class,ns.scm(charName)) .. realm .. faction, ns.GetCoinColorOrTextureString(name,v.gold,{inTooltip=true}));

			tt:SetLineScript(line, "OnMouseUp", deleteCharacterGoldData, name_realm);

			totalGold[v.faction] = totalGold[v.faction] + v.gold;

			line, column = nil, nil;
			lineCount=lineCount+1;
		end
	end

	if(lineCount>0)then
		tt:AddSeparator()
		if ns.profile[name].splitSummaryByFaction then
			tt:AddLine(L["Total Gold"].." |TInterface\\PVPFrame\\PVP-Currency-Alliance:16:16:0:-1:16:16:0:16:0:16|t", ns.GetCoinColorOrTextureString(name,totalGold.Alliance,{inTooltip=true}));
			tt:AddLine(L["Total Gold"].." |TInterface\\PVPFrame\\PVP-Currency-Horde:16:16:0:-1:16:16:0:16:0:16|t", ns.GetCoinColorOrTextureString(name,totalGold.Horde,{inTooltip=true}));
		else
			tt:AddLine(L["Total Gold"], ns.GetCoinColorOrTextureString(name,totalGold.Alliance+totalGold.Horde+totalGold.Neutral,{inTooltip=true}))
		end
	end
	tt:AddSeparator(3,0,0,0,0)

	local profit, direction = getProfit();
	if profit then
		local sign = (direction==1 and "|Tinterface\\buttons\\ui-microstream-green:14:14:0:0:32:32:6:26:26:6|t") or (direction==-1 and "|Tinterface\\buttons\\ui-microstream-red:14:14:0:0:32:32:6:26:6:26|t") or "";
		tt:AddLine(profit<0 and C("ltred",L["Session loss"]) or C("ltgreen",L["Session profit"]), sign .. ns.GetCoinColorOrTextureString(name,profit,{inTooltip=true}));
	else
		tt:AddLine(C("ltgreen",L["Session profit"]),C("orange","Error"));
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		ns.AddSpannedLine(tt,C("ltblue",L["Right-click"]).." || "..C("green",L["Remove entry"]));
		ns.clickOptions.ttAddHints(tt,name);
	end

	if not update then
		ns.roundupTooltip(tt);
	end
end


-- module functions and variables --
------------------------------------
module = {
	desc = L["Broker to show gold of all your chars and lost and earned money for the current session"],
	label = BONUS_ROLL_REWARD_MONEY,
	events = {
		"PLAYER_LOGIN",
		"PLAYER_MONEY",
		"PLAYER_TRADE_MONEY",
		"TRADE_MONEY_CHANGED",
	},
	updateinterval = nil, -- 10
	config_defaults = {
		goldColor = nil,
		showAllFactions=true,
		showRealmNames=true,
		showCharsFrom=4,
		showCharGold = true,
		showSessionProfit = true,
		splitSummaryByFaction = true,
	},
	config_allowed = nil,
	config_header = {type="header", label=BONUS_ROLL_REWARD_MONEY, align="left", icon=I[name]},
	config_broker = {
		{ type="toggle", name="showCharGold",         label=L["Show character gold"],     tooltip=L["Show character gold on broker button"], event=true },
		{ type="toggle", name="showSessionProfit",    label=L["Show session profit"],     tooltip=L["Show session profit on broker button"], event=true },
		{ type="toggle", name="splitSummaryByFaction", label=L["Split summary by faction"], tooltip=L["Separate summary by faction (Alliance/Horde)"], event=true }
	},
	config_tooltip = {
		"showAllFactions",
		"showRealmNames",
		"showCharsFrom"
	},
	config_misc = {"shortNumbers"},
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

function module.init()
	if ns.toon.gold==nil then
		ns.toon.gold = 0;
	end
end

function module.onevent(self,event,msg)
	if event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(module,ns.profile[name]);
	else
		current_money = GetMoney();
		ns.toon.gold = current_money;
		if event=="PLAYER_LOGIN" then
			login_money = current_money;
		end
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, 2, "LEFT", "RIGHT"},{false},{self})
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
