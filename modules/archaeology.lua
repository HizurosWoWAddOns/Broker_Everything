
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
local type,GetItemInfo=type,GetItemInfo;


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Archaeology" -- L["Archaeology"]
L[name] = GetArchaeologyInfo()
L["Fragments"] = ARCHAEOLOGY_RUNE_STONES;
L["Races"] = RACES;
local ldbName, ttName, ttColumns, tt = name, name.."TT", 5, nil
local skill,createMenu
local races = {};
local maxFragments = 200;
local maxFragments250 = {[109585]=1,[108439]=1,[109584]=1};

local race2currency = setmetatable({
	-- added 4.0
	Dwarf=384,		Troll=385,		Fossil=393,
	NightElf=394,	Orc=397,		Draenei=398,
	Vrykul=399,		Nerubian=400,	Tolvir=401,

	-- added 5.0
	Pandaren=676,	Mogu=677,		Mantid=754,

	-- added 6.0
	DraenorOrc=821,	Ogre=828,		Arakkoa=829,
},{__call=function(t,a)
	local icon,_=false;
	if(t[a]~=nil)then
		_,_,icon = GetCurrencyInfo(t[a]);
	end
	return type(icon)=="string" and icon or "interface\\icons\\inv_misc_questionmark";
end})

local QuestStarterItems = {
	-- MoP Archeology
	89174,89169,89182,89183,85477,89184,89185,89172,
	89178,89171,89179,89170,89181,89176,89175,89173,
	89209,89180,85557,85558,89209,95385,95388,95387,
	95390,95389,95386,95384,95383,
	-- WoD Archeology
	114142,114144,114146,114148,114150,114152,114154,114156,
	114158,114160,114162,114164,114166,114168,114170,114172,
	114174,114176,114178,114182,114184,114186,114188,114208,
	114209,114210,114211,114212,114213,114215,114216,114217,
	114218,114219,114220,114221,114222,114223,114224,
};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="INTERFACE\\ICONS\\trade_archaeology",coords={0.05,0.95,0.05,0.95}}; --IconName::Archaeology--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show your archaeology artifacts."],
	--icon_suffix = "_Neutral",
	events = {
		"PLAYER_ENTERING_WORLD",
		"KNOWN_CURRENCY_TYPES_UPDATE",
		"ARTIFACT_UPDATE",
		"ARTIFACT_COMPLETE",
		"CURRENCY_DISPLAY_UPDATE",
		"GET_ITEM_INFO_RECEIVED",
		"CHAT_MSG_SKILL"
	},
	updateinterval = nil,
	config_defaults = {
		inTitle = {},
		continentOrder=true
	},
	config_allowed = {
		subTTposition = {["AUTO"]=true,["TOP"]=true,["LEFT"]=true,["RIGHT"]=true,["BOTTOM"]=true}
	},
	config = {
		{ type="header", label=L[name], align="left", icon=true },
		{ type="separator" },
		{ type="toggle", name="continentOrder", label=L["Order by continent"], tooltip=L["Order archaeology races by continent"] }
	},
	clickOptions = {
		["1_open_archaeology_frame"] = {
			cfg_label = "Open archaeology frame", -- L["Open archaeology frame"]
			cfg_desc = "open your bags", -- L["open your archaeology frame"]
			cfg_default = "_LEFT",
			hint = "Open archaeology frame", -- L["Open archaeology frame"]
			func = function(self,button)
				local _mod=name;
				if ( not ArchaeologyFrame ) then
					ArchaeologyFrame_LoadUI()
				end
				if ( ArchaeologyFrame ) then
					if(ArchaeologyFrame:IsShown())then
						securecall("ArchaeologyFrame_Hide")
					else
						securecall("ArchaeologyFrame_Show")
					end
				end
			end
		},
		["2_open_menu"] = {
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


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function ItemTooltipShow(self,link)
	if (self) then
		GameTooltip:SetOwner(self,"ANCHOR_NONE");
		if (select(1,self:GetCenter()) > (select(1,UIParent:GetWidth()) / 2)) then
			GameTooltip:SetPoint("RIGHT",tt,"LEFT",-2,0);
		else
			GameTooltip:SetPoint("LEFT",tt,"RIGHT",2,0);
		end
		GameTooltip:SetPoint("TOP",self,"TOP", 0, 4);

		GameTooltip:ClearLines();
		GameTooltip:SetHyperlink(link);

		GameTooltip:SetFrameLevel(self:GetFrameLevel()+1);
		GameTooltip:Show();
	else
		GameTooltip:Hide();
	end
end

local function ItemTooltipHide(self)
	GameTooltip:Hide();
end

local function createTooltip()
	local l;
	tt:Clear()
	tt:AddHeader(C("dkyellow",L[name]))

	local n=GetNumArchaeologyRaces();
	local order = {};
	local icon="|T%s:14:14:0:0:64:64:4:56:4:56|t";
	local icon2="|T%s:14:14:0:0:128:128:3:70:8:75|t";

	if(n==15 and Broker_EverythingDB[name].continentOrder)then
		order = {
			false,	L["Azeroth"],	true,	1,3,4,7,8,
			false,	L["Outland"],	true,	2,6,
			false,	L["Northend"],	true,	5,9,
			false,	L["Pandaria"],	true,	10,11,12,
			false,	L["Draenor"],	true,	13,14,15
		}
	else
		order = {false,"",true};
		for i=1,n do tinsert(order,i); end
	end

	for _,i in ipairs(order) do
		if(i==true)then
			tt:AddSeparator();
		elseif(i==false)then
			tt:AddSeparator(4,0,0,0,0);
		elseif(type(i)=="string")then
			if(i~="")then i=" ("..i..")"; end
			tt:AddLine(C("ltblue",L["Races"]..i),C("ltblue",L["Keystones"]),C("ltblue",L["Fragments"]),C("ltblue",L["Artifacts"]));
		else
			local raceName, raceTexture, raceItemID, numFragmentsCollected, numFragmentsRequired, maxFragments = GetArchaeologyRaceInfo(i);
			local artifactName, _, _, artifactIcon, _, keystoneSlots = GetActiveArtifactByRace(i);
			local keystoneCount,keystoneIcon,keystoneSum,Artifact = "","",0,{numFragmentsCollected, "/", numFragmentsRequired};
			local raceCurrencyIcon = race2currency(select(3,strsplit("-",raceTexture)));
			local solve,l=false;
			if (keystoneSlots~=nil)then
				if(raceItemID~=0) then
					keystoneCount = GetItemCount(raceItemID,true,true);
					keystoneIcon = icon:format(GetItemIcon(raceItemID));
					if(keystoneSlots>0)then
						keystoneSum = (keystoneCount<=keystoneSlots and keystoneCount or keystoneSlots) * 20;
					end
					if(numFragmentsCollected+keystoneSum>=numFragmentsRequired)then
						solve=true
					end
				end
				l=tt:AddLine(
					icon2:format(raceTexture) .. " "..C(solve==true and "green" or "ltyellow",raceName),
					keystoneCount.." "..keystoneIcon,
					numFragmentsCollected.." / "..maxFragments.." "..icon:format(raceCurrencyIcon),
					C(solve==true and "green" or "white",numFragmentsRequired).." "..icon:format(artifactIcon or ""),
					QuestStarterItems[artifactName] and "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|t" or " "
				);
				if(raceItemID~=0)then
					tt:SetLineScript(l,"OnEnter", function(self) ItemTooltipShow(self,"item:"..raceItemID) end);
					tt:SetLineScript(l,"OnLeave", function(self) ItemTooltipHide(self) end);
					--tt:SetCellScript(l,2,"OnEnter", function(self) ItemTooltipShow(self,"item:"..raceItemID) end);
					--tt:SetCellScript(l,2,"OnLeave", function(self) ItemTooltipHide(self) end);
					--tt:SetLineScript(l,"OnMouseUp", function(self) --[[ open frame ]] end);
				end
				l=nil;
			else
				if(not maxFragments)then

				end
				tt:AddLine(
					icon2:format(raceTexture) .. " " ..C("gray",raceName),
					"",
					C("gray",numFragmentsCollected.." / "..maxFragments)
				);
			end
		end
	end

	if Broker_EverythingDB.showHints then
		tt:AddSeparator(3,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,...)
	if event=="GET_ITEM_INFO_RECEIVED" then
		local id = ...;
		if(type(id)=="number")then
			local item={GetItemInfo(id)};
			if(#item>0)then
				QuestStarterItems[item[1]]=id;
				QuestStarterItems[id]=item;
			end
		end
	else
		if event=="PLAYER_ENTERING_WORLD" then
			C_Timer.After(11, function()
				local item;
				for i=1, #QuestStarterItems do
					if(type(QuestStarterItems[i])=="number")then
						item={GetItemInfo(QuestStarterItems[i])};
						if(#item>0)then
							QuestStarterItems[item[1]]=QuestStarterItems[i];
							QuestStarterItems[QuestStarterItems[i]]=item;
						end
					end
				end
			end);
			self:UnregisterEvent(event);
		end
		
		local obj = ns.LDB:GetDataObjectByName(ldbName);
		local countSolveable,nameSolveable = 0,"";
		for i=1, GetNumArchaeologyRaces() do
			local raceName, _, raceItemID, numFragmentsCollected, numFragmentsRequired = GetArchaeologyRaceInfo(i);
			local _, _, _, _, _, keystoneSlots = GetActiveArtifactByRace(i);
			local keystoneCount, keystoneIcon, keystoneSum = "","",0

			if (keystoneSlots~=nil)then
				if(raceItemID~=0) then
					keystoneCount = GetItemCount(raceItemID,true,true);
					if(keystoneSlots>0)then
						keystoneSum = (keystoneCount<=keystoneSlots and keystoneCount or keystoneSlots) * 20;
					end
					if(numFragmentsCollected+keystoneSum>=numFragmentsRequired)then
						countSolveable,nameSolveable=countSolveable+1,raceName;
					end
				end
			end
		end

		if(countSolveable==1)then
			obj.text = C("green",nameSolveable);
		elseif(countSolveable>1)then
			obj.text = C("green",countSolveable.." "..strlower(READY));
		else
			obj.text = L[name];
		end
	end
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "CENTER", "RIGHT", "RIGHT","LEFT")
	createTooltip()
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if tt then ns.hideTooltip(tt,ttName, false, true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

