
-- saved variables
goldDB = {}
be_gold_db = {};

----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Gold" -- L["Gold"]
local ldbName = name
local tt = nil
local ttName = name.."TT"
local login_money = nil
local next_try = false
local current_money = 0
local goldInit = false
local goldLoaded = false
local faction = UnitFactionGroup("Player")


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Minimap\\TRACKING\\Auctioneer",coords={0.05,0.95,0.05,0.95}} --IconName::Gold--


---------------------------------------
-- module variables for registration --
---------------------------------------
local desc = L["Broker to show gold information. Shows gold amounts for characters on the same ns.realm and faction and the amount made or lost for the session."]
ns.modules[name] = {
	desc = desc,
	events = {
		"PLAYER_LOGIN",
		"PLAYER_MONEY",
		"PLAYER_TRADE_MONEY",
		"TRADE_MONEY_CHANGED",
		"PLAYER_ENTERING_WORLD",
		"NEUTRAL_FACTION_SELECT_RESULT"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		goldColor = nil
	},
	config_allowed = {},
	config = { { type="header", label=L[name], align="left", icon=I[name] } }
}


--------------------------
-- some local functions --
--------------------------


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	local empty=true;
	if (be_gold_db) then
		for i,v in pairs(be_gold_db) do empty=false; end
	end
	if (goldDB~=nil) and (empty) then
		be_gold_db = goldDB;
		goldDB = nil;
	end
	if not be_gold_db[faction] then
		be_gold_db[faction] = { [ns.realm]={ [ns.player.name] = {0,ns.player.class} } }
	elseif not be_gold_db[faction][ns.realm] then
		be_gold_db[faction][ns.realm] = { [ns.player.name] = {0,ns.player.class} }
	end
end

ns.modules[name].onevent = function(self,event,msg)
	current_money = GetMoney()
	be_gold_db[faction][ns.realm][ns.player.name] = {current_money,ns.player.class}

	if event=="PLAYER_LOGIN" or (next_try and login_money==nil) then
		login_money = current_money
		next_try = (next_try==false and login_money==nil)
	end

	if event == "NEUTRAL_FACTION_SELECT_RESULT" then
		faction = UnitFactionGroup("Player")
		ns.modules[name].init(self)
		be_gold_db[faction][ns.realm][ns.player.name] = {current_money,ns.player.class}
		be_gold_db["Neutral"][ns.realm][ns.player.name] = nil
	end

	(self.obj or ns.LDB:GetDataObjectByName(ldbName)).text = ns.GetCoinColorOrTextureString(name,current_money)
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end

ns.modules[name].ontooltip = function(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...

	local totalGold = 0
	local diff_money

	current_money = GetMoney()
	be_gold_db[faction][ns.realm][ns.player.name] = {current_money,ns.player.class}

	tt:Clear()

	tt:AddHeader(C("dkyellow",L["Gold information"]))
	tt:AddSeparator()

	for k,v in ns.pairsByKeys(be_gold_db[faction][ns.realm]) do
		if type(v)~="table" then v = {v,"white"} end
		local line, column = tt:AddLine(C(v[2],ns.scm(k)), ns.GetCoinColorOrTextureString(name,v[1]))
		if (k~=ns.player.name) then
		tt:SetLineScript(line, "OnMouseUp", function(self,x,button)
			if button == "RightButton" then
				be_gold_db[faction][ns.realm][k] = nil
				tt:Clear()
				ns.modules[name].ontooltip(tt)
			end 
		end)
		tt:SetLineScript(line, "OnEnter", function(self) tt:SetLineColor(line, 1,192/255, 90/255, 0.3) end )
		tt:SetLineScript(line, "OnLeave", function(self) tt:SetLineColor(line, 0,0,0,0) mButton=nil end)
		end
		totalGold = totalGold + v[1]
		line, column = nil, nil
	end

	tt:AddSeparator()
	tt:AddLine(L["Total Gold"], ns.GetCoinColorOrTextureString(name,totalGold))
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
