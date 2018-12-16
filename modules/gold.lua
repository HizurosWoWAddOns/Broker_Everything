
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
local time,date,tinsert,tconcat=time,date,tinsert,table.concat;


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Gold"; -- BONUS_ROLL_REWARD_MONEY L["ModDesc-Gold"]
local ttName, tt, createTooltip, module = name.."TT";
local login_money = nil;
local next_try = false;
local current_money = 0
local faction = UnitFactionGroup("Player")
local player = ns.player.name_realm;
local profit,ttLines = {},{
	{"showProfitSession",L["Session"]},
	{"showProfitDaily",HONOR_TODAY,"daily"},
	{"showProfitDaily",HONOR_YESTERDAY,"daily",true},
	{"showProfitWeekly",ARENA_THIS_WEEK,"weekly"},
	{"showProfitWeekly",HONOR_LASTWEEK,"weekly",true},
	{"showProfitMonthly",L["This month"],"monthly"},
	{"showProfitMonthly",L["Last month"],"monthly",true},
};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Minimap\\TRACKING\\Auctioneer",coords={0.05,0.95,0.05,0.95}} --IconName::Gold--


-- some local functions --
--------------------------
local function getProfit(Type,last)
	local value = 0;
	if Type then
		local p,d=ns.data[name].Profit[Type][player],profit[Type];
		if not last then
			value = current_money-p[d[1]];
		elseif p[d[2]]~=false then
			value = tonumber(p[d[2]]);
		end
	elseif login_money~=nil then -- session
		value = current_money-login_money;
	end
	if value<0 then
		return 0-value,-1;
	end
	return value, value>0 and 1 or 0;
end

local updateProfit;
function updateProfit()
	local w = date("%w"); w=w==0 and 7 or w;
	local day,T,t = 86400,date("*t"),time();
	local today = time({year=T.year,month=T.month,day=T.day,hour=23,min=59,sec=59});
	local week = time({year=T.year,month=T.month,day=T.day+(7-w)+1,hour=0,min=0,sec=0})-1;

	profit.daily = { today, today-day };
	profit.weekly = { week, week-(day*7) };
	profit.monthly = {
		time({year=T.year,month=T.month+1,day=1,hour=0,min=0,sec=0})-1,
		time({year=T.year,month=T.month,day=1,hour=0,min=0,sec=0})-1
	};

	for k,v in pairs(profit) do
		ns.tablePath(ns.data,name,"Profit",k,player);
		local p = ns.data[name].Profit[k][player];
		if  p[v[1]]==nil then
			p[v[1]] = current_money;
		end
		if  p[v[2]]==nil then
			p[v[2]] = false;
		elseif type(p[v[2]])=="number" then
			p[v[2]] = tostring(current_money-p[v[2]]);
		end
		local c = 0;
		for x,y in ns.pairsByKeys(p,true) do
			c=c+1;
			if c>5 then
				p[x] = nil; -- remove older entries
			end
		end
	end

	C_Timer.After(today-time()+1,updateProfit); -- next update
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
	if ns.profile[name].showProfitSessionBroker and login_money then
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

	local sAR,sAF = ns.profile[name].showCharsFrom=="4",ns.profile[name].showAllFactions==true;
	local totalGold,diff_money = {Alliance=0,Horde=0,Neutral=0};
	totalGold[ns.player.faction] = current_money;

	if tt.lines~=nil then tt:Clear(); end

	tt:AddHeader(C("dkyellow",L["Gold information"]));
	tt:AddSeparator(4,0,0,0,0);

	if(sAR or sAF)then
		tt:AddLine(C("ltgreen","("..(sAR and L["All realms"] or "")..((sAR and sAF) and "/" or "")..(sAF and L["AllFactions"] or "")..")"));
		tt:AddSeparator(4,0,0,0,0);
	end

	local faction = ns.player.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..ns.player.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
	tt:AddLine(C(ns.player.class,ns.player.name) .. faction, ns.GetCoinColorOrTextureString(name,current_money,{inTooltip=true}));
	tt:AddSeparator();

	local lineCount=0;
	for i=1, #Broker_Everything_CharacterDB.order do
		local name_realm = Broker_Everything_CharacterDB.order[i];
		local charName,realm,_=strsplit("-",name_realm,2);
		local v = Broker_Everything_CharacterDB[name_realm];

		if (v.gold) and (ns.player.name_realm~=name_realm) and ns.showThisChar(name,realm,v.faction) then
			local faction = v.faction~="Neutral" and " |TInterface\\PVPFrame\\PVP-Currency-"..v.faction..":16:16:0:-1:16:16:0:16:0:16|t" or "";
			local line, column = tt:AddLine( C(v.class,ns.scm(charName)) .. ns.showRealmName(name,realm) .. faction, ns.GetCoinColorOrTextureString(name,v.gold,{inTooltip=true}));

			tt:SetLineScript(line, "OnMouseUp", deleteCharacterGoldData, name_realm);

			totalGold[v.faction] = totalGold[v.faction] + v.gold;

			line, column = nil, nil;
			lineCount=lineCount+1;
		end
	end

	if(lineCount>0)then
		tt:AddSeparator()
		if ns.profile[name].splitSummaryByFaction and ns.profile[name].showAllFactions then
			tt:AddLine(L["Total Gold"].." |TInterface\\PVPFrame\\PVP-Currency-Alliance:16:16:0:-1:16:16:0:16:0:16|t", ns.GetCoinColorOrTextureString(name,totalGold.Alliance,{inTooltip=true}));
			tt:AddLine(L["Total Gold"].." |TInterface\\PVPFrame\\PVP-Currency-Horde:16:16:0:-1:16:16:0:16:0:16|t", ns.GetCoinColorOrTextureString(name,totalGold.Horde,{inTooltip=true}));
		else
			tt:AddLine(L["Total Gold"], ns.GetCoinColorOrTextureString(name,totalGold.Alliance+totalGold.Horde+totalGold.Neutral,{inTooltip=true}))
		end
	end

	if ns.profile[name].showProfitSession or ns.profile[name].showProfitDaily or ns.profile[name].showProfitWeekly or ns.profile[name].showProfitMonthly then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltyellow","Profit / Loss"),C("orange","("..L["Experimental"]..")"));
		tt:AddSeparator();
		for i=1, #ttLines do
			local v = ttLines[i];
			if ns.profile[name][v[1]] then
				local profit, direction = getProfit(v[3],v[4]);
				local color,icon = "gray","";
				if direction==1 then
					color,icon = "ltgreen","|Tinterface\\buttons\\ui-microstream-green:14:14:0:0:32:32:6:26:26:6|t";
				elseif direction==-1 then
					color,icon = "ltred","|Tinterface\\buttons\\ui-microstream-red:14:14:0:0:32:32:6:26:6:26|t";
				end
				tt:AddLine(C(color,v[2]), icon .. ns.GetCoinColorOrTextureString(name,profit,{inTooltip=true}));
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		ns.AddSpannedLine(tt,C("ltblue",L["MouseBtnR"]).." || "..C("green",L["Remove entry"]));
		ns.ClickOpts.ttAddHints(tt,name);
	end

	if not update then
		ns.roundupTooltip(tt);
	end
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"PLAYER_MONEY",
		"PLAYER_TRADE_MONEY",
		"TRADE_MONEY_CHANGED",
	},
	config_defaults = {
		enabled = true,
		showAllFactions=true,
		showRealmNames=true,
		showCharsFrom="2",
		showCharGold = true,
		showProfitSessionBroker = true,
		splitSummaryByFaction = true,
		showProfitSession = true,
		showProfitDaily = true,
		showProfitWeekly = true,
		showProfitMonthly = true,
	},
	clickOptionsRename = {
		["1_open_tokenframe"] = "currency",
		["2_open_character_info"] = "charinfo",
		["3_open_bags"] = "bags",
		["4_open_menu"] = "menu"
	},
	clickOptions = {
		["currency"] = "Currency",
		["charinfo"] = "CharacterInfo",
		["bags"] = {"Open all bags","call","ToggleAllBags"}, -- L["Open all bags"]
		["menu"] = "OptionMenuCustom"
	}
}

ns.ClickOpts.addDefaults(module,{
	currency = "_LEFT",
	charinfo = "__NONE",
	bags = "__NONE",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			showCharGold={ type="toggle", order=1, name=L["Show character gold"],     desc=L["Show character gold on broker button"] },
			showProfitSessionBroker={ type="toggle", order=2, name=L["Show session profit"],     desc=L["Show session profit on broker button"] },
		},
		tooltip = {
			splitSummaryByFaction={ type="toggle", order=1, name=L["Split summary by faction"], desc=L["Separate summary by faction (Alliance/Horde)"] },
			showProfitSession = { type="toggle", order=1, name=L["Show session profit"], desc=L["Display profit/loss of the current session in tooltip"]},
			showProfitDaily   = { type="toggle", order=2, name=L["Show daily profit"],   desc=L["Display today and yesterday profit in tooltip"] },
			showProfitWeekly  = { type="toggle", order=2, name=L["Show weekly profit"],  desc=L["Display this week and last week profit in tooltip"] },
			showProfitMonthly = { type="toggle", order=2, name=L["Show monthly profit"], desc=L["Display this month and last month profit in tooltip"] },
			showAllFactions=2,
			showRealmNames=3,
			showCharsFrom=4,
		},
		misc = {
			shortNumbers=1,
		},
	}
end

function module.OptionMenu(self,button,modName)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	ns.EasyMenu:AddConfig(name);
	ns.EasyMenu:AddEntry({separator=true});
	ns.EasyMenu:AddEntry({ label = C("yellow",L["Reset session profit"]), func=function() module.onevent(nil,"PLAYER_LOGIN"); end, keepShown=false });
	ns.EasyMenu:ShowMenu(self);
end

function module.init()
	if ns.toon.gold==nil then
		ns.toon.gold = 0;
	end
end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	else
		current_money = GetMoney();
		ns.toon.gold = current_money;
		if event=="PLAYER_LOGIN" then
			if ns.data[name] and ns.data[name].profit~=nil then
				ns.data[name].profit=nil;
			end
--@do-not-package@
	        ns.profileSilenceFIXME=true;
--@end-do-not-package@
			if ns.profile[name].showProfit~=nil then
				ns.profile[name].showProfit=nil;
			end
--@do-not-package@
	        ns.profileSilenceFIXME=true;
--@end-do-not-package@
			if ns.profile[name].showSessionProfit~=nil then
				ns.profile[name].showProfitSessionBroker=ns.profile[name].showSessionProfit
				ns.profile[name].showSessionProfit=nil
			end
			login_money = current_money;
			updateProfit();
			updateBroker();
		elseif ns.eventPlayerEnteredWorld then
			updateBroker();
		end
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
