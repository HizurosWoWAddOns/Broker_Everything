--[[
ideas:
	default - list of all active factions with reputation and session plus
	fav mode - list of factions choosed by user

	mouseover - tooltip with list of other user characters with count.
]]


----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Reputation"; -- L["Reputation"]
local ldbName, ttName, ttColumns, tt, createMenu = name, name.."TT", 5;
local Name,description,standingID,barMin,barMax,barValue,atWarWith,canToggleAtWar,isHeader,isCollapsed,hasRep,isWatched,isChild,factionID,hasBonusRepGain,canBeLFGBonus,factionStandingText=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17;

local bars,wasShown = {},false;
local allinone = 85000;
local allinone_friend = 43000;
local allinone_bodyguard = 31000;
local bodyguards = {193,207,216,218,219};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\Icons\\Achievement_Reputation_01", coords={0.1,0.9,0.1,0.9}}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Display informations about faction standing of your character"],
	--icon_suffix = "",
	events = {
		"PLAYER_ENTERING_WORLD",
		"UPDATE_FACTION"
	},
	updateinterval = 0.5, -- 10
	config_defaults = {
		bgBars = true,
		standingText = true,
		numbers="Percent",
	},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=true },
		{ type="separator" },
		{ type="select",
			name	= "numbers",
			label	= L["Numeric format"],
			tooltip	= L["How would you like to view numeric reputation format."],
			values	= {
				["_NONE"]       = "None",
				["Percent"]     = "25.4%",
				["PercentNeed"] = "22.2% need",
				["Number"]      = "1234/3000",
				["NumberNeed"]  = "321 need",
			},
			default = "Percent",
		},
		{ type="toggle", name="standingText", label=L["Standing text"], tooltip=L["Show standing text in tooltip"]},
		{ type="select",
			name	= "bgBars",
			label	= L["Background reputation bar mode"],
			tooltip	= L["How would you like to view the background reputation bar."],
			values	= {
				["_NONE"]       = "None",
				["single"]     = "Single standing level",
				["allinone"] = "All standing level in one",
			},
			default = "single",
		},
		--{ type="toggle", name="favsOnly", label=L["Favorites only"], tooltip=L["Show favorites only in tooltip"] }
	},
	clickOptions = {
		["1_open_reputation"] = {
			cfg_label = "Open reputation pane",
			cfg_desc = "open the reputation pane",
			cfg_default = "_LEFT",
			hint = "Open reputation pane",
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCharacter","ReputationFrame");
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "_RIGHT",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self)
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function updateBars()
	local bgWidth = false;
	for i,v in ipairs(bars)do
		if(v~=nil and v:IsShown() and v.percent)then
			v.BarSingle:Hide();
			v.BarAIO:Hide();
			v.BarAIO_friend:Hide();
			v.BarAIO_bodyguard:Hide();

			if not bgWidth then
				bgWidth=v.Bg:GetWidth();
			end

			if(Broker_EverythingDB[name].bgBars=="single")then
				v.BarSingle:SetWidth(bgWidth*v.percent);
				v.BarSingle:Show();
			elseif(Broker_EverythingDB[name].bgBars=="allinone")then
				if(v.bodyguard)then
					local totalPercent = (v.data[barValue] / allinone_bodyguard);
					if v.data[barMax]==1 then totalPercent = 1; end
					v.BarAIO_bodyguard:SetTexCoord(0, 916/1024 * totalPercent, 0, 1);
					v.BarAIO_bodyguard:SetWidth((bgWidth * totalPercent)+0.1);
					v.BarAIO_bodyguard:Show();
				elseif(v.friend)then
					local totalPercent = (v.data[barValue] / allinone_friend);
					if v.data[barMax]==1 then totalPercent = 1; end
					v.BarAIO_friend:SetTexCoord(0, 870/1024 * totalPercent, 0, 1);
					v.BarAIO_friend:SetWidth((bgWidth * totalPercent)+0.1);
					v.BarAIO_friend:Show();
				else
					local totalPercent = ((v.data[barValue] + 42000) / allinone);
					v.BarAIO:SetTexCoord(0, 850/1024 * totalPercent, 0, 1);
					v.BarAIO:SetWidth((bgWidth * totalPercent)+0.1);
					v.BarAIO:Show();
				end
			end
		end
	end
end

local function ttAddLine(tt,mode,data,count)
	local inset,line,_barMax,_barValue = 0, {}, data[barMax]-data[barMin], data[barValue]-data[barMin];
	if(data[standingID]==8)then _barMax=999; end
	local percent = _barValue/_barMax;
	if (data[isHeader] and data[hasRep] and data[isChild]) or (not data[isHeader]) then inset=1; end

	tinsert(line,
		strrep("   ",inset)..
		C(data[isHeader] and "ltblue" or "ltyellow",data[Name])..
		(data[atWarWith] and " |TInterface\\buttons\\UI-Checkbox-SwordCheck:12:12:0:-1:32:32:0:18:0:18|t" or "")
	);

	if(Broker_EverythingDB[name].standingText)then
		tinsert(line,data[factionStandingText]);
	end

	if(mode=="Percent")then
		tinsert(line,("%1.1f%%"):format(_barValue/_barMax*100));
	elseif(mode=="PercentNeed")then
		tinsert(line,("%1.1f%% "..L["need"]):format(_barValue/_barMax*100));
	elseif(mode=="Number")then
		tinsert(line,_barValue.."/".._barMax);
	elseif(mode=="NumberNeed")then
		tinsert(line,(_barMax-_barValue).." "..L["need"]);
	end

	for i=#line, ttColumns do
		tinsert(line," ")
	end

	local l=tt:AddLine(unpack(line));

	if(Broker_EverythingDB[name].bgBars=="single") or (Broker_EverythingDB[name].bgBars=="allinone")then
		if(not bars[count])then
			bars[count] = CreateFrame("Frame","BERepurationBar"..count,nil,"BEReputationBarTemplate");
		end
		bars[count]:SetParent(tt.lines[l]);
		if(true)then
			bars[count]:SetPoint("TOPLEFT",tt.lines[l].cells[1],"TOPLEFT");
			bars[count]:SetPoint("BOTTOMRIGHT",tt.lines[l].cells[ttColumns],"BOTTOMRIGHT");
		else
			bars[count]:SetPoint("TOPLEFT",tt.lines[l].cells[1],"BOTTOMLEFT",0,1);
			bars[count]:SetPoint("BOTTOMRIGHT",tt.lines[l].cells[ttColumns],"BOTTOMRIGHT",0,-3);
		end
		bars[count]:Show();
		bars[count].data = data;
		bars[count].standing = data[standingID];
		bars[count].percent = (_barValue/_barMax);
		bars[count].bodyguard = bodyguards[data[Name]] or false;
		bars[count].friend = data[factionStandingText]~=_G["FACTION_STANDING_LABEL"..data[standingID]];
	end

	local darker = 0.6;
	if(Broker_EverythingDB[name].bgBars=="single")then
		local color = FACTION_BAR_COLORS[data[standingID]];
		bars[count].BarSingle:SetVertexColor(color.r*darker,color.g*darker,color.b*darker,1);
		bars[count].BarSingle:Show();
	--elseif(Broker_EverythingDB[name].bgBars=="allinone")then
	end
end

local function createTooltip()
	if not (tt and tt.key and tt.key==ttName)then return end

	tt:AddHeader(C("dkyellow",L[name]));

	local count,inset,num = 0,0,GetNumFactions();
	for i=1, num do
		local data = {GetFactionInfo(i)};
		data[factionStandingText] = _G["FACTION_STANDING_LABEL"..data[standingID]];
		local friendID,friendRep,friendMaxRep,friendName,friendText,friendTexture,friendTextLevel,friendThreshold,nextFriendThreshold = GetFriendshipReputation(data[factionID]);

		if (friendID ~= nil) then
			data[factionStandingText] = friendTextLevel;
			data[standingID] = 5;
			if ( nextFriendThreshold ) then
				data[barMin], data[barMax], data[barValue] = friendThreshold, nextFriendThreshold, friendRep;
			else
				data[barMin], data[barMax], data[barValue] = 0, 1, 1;
			end
		end

		if(data[isHeader])then
			tt:AddSeparator(4,0,0,0,0);
			if(data[hasRep])then
				count=count+1;
				ttAddLine(tt,Broker_EverythingDB[name].numbers,data,count);
			else
				tt:AddLine(strrep("   ",data[isChild] and 1 or 0)..C("ltblue",data[Name]));
			end
			if not data[isChild] then
				tt:AddSeparator();
			end
		else
			count=count+1;
			ttAddLine(tt,Broker_EverythingDB[name].numbers,data,count);
		end
	end
	wasShown=true;

	if (Broker_EverythingDB.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,...)
	if(event=="PLAYER_ENTERING_WORLD" and UnitLevel("player")>=90)then
		local id = ns.player.faction:lower();
		for i=1,#bodyguards do
			local data = C_Garrison.GetFollowerInfo(bodyguards[i]);
			if(data and data.name)then
				bodyguards[data.name]=true;
			end
			bodyguards[i]=nil;
		end
	end

	if(event=="PLAYER_ENTERING_WORLD") and (event=="UPDATE_FACTION")then
		-- name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus

		local obj = ns.LDB:GetDataObjectByName(ldbName);
		local name, standingId, barMin, barMax, barValue = GetWatchedFactionInfo();
		if(name)then
			local min,max = barValue-barMin, barMax-barMin;
			obj.text = ("%s, %1.1f%%"):format(name,min/max*100);
		else
			obj.text = L[name];
		end
	end
end
ns.modules[name].onupdate = function(self,elapse)
	if(#bars==0)then return end -- no bars no actions...

	if not (tt and tt.key==ttName)then
		if(wasShown)then
			for i,v in ipairs(bars)do
				v:SetParent(nil);
				v:ClearAllPoints();
				v:Hide();
				wasShown=false;
			end
		end
		return
	end
end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "LEFT", "RIGHT", "CENTER", "LEFT")
	tt:SetScript("OnHide",function()
		for i=1, #bars do
			bars[i]:SetParent(nil);
			bars[i]:ClearAllPoints();
			bars[i]:Hide();
		end
	end);
	createTooltip()
	ns.createTooltip(self,tt)
	C_Timer.After(0.5,updateBars);
end

ns.modules[name].onleave = function(self)
	if (tt) then
		ns.hideTooltip(tt,ttName,false,true);
	end
end

--ns.modules[name].onclick = function(self,button)
--	if button=="LeftButton" then
--	elseif button=="RightButton" then
--	end
--end

-- ns.modules[name].ondblclick = function(self,button) end

