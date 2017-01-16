
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
local type,GetItemInfo=type,GetItemInfo;


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Archaeology"; -- PROFESSIONS_ARCHAEOLOGY
local ldbName, ttName, ttColumns, tt = name, name.."TT", 5, nil
local skill,createMenu
local tradeskill = {};
local maxFragments = 200;
local maxFragments250 = {[109585]=1,[108439]=1,[109584]=1};
local raceIndex,raceCurrencyId,raceKeystone2Fragments,raceName,raceTexture,raceKeystoneItemID = 1,2,3,4,5,6;
local raceFragmentsCollected,raceNumFragmentsRequired,raceFragmentsMax,raceArtifactName,raceArtifactIcon,raceKeystoneSlots = 7,8,9,10,11,12;
local raceKeystoneIcon,raceKeystoneCount,raceKeystoneFragmentsValue,raceArtifactSolvable,raceFragmentsIcon = 13,14,15,16,17;
local races = { -- <raceIndex>, <currencyId>, <raceKeystone2FragmentsCount>
	Azeroth		= {nil, true},
	Dwarf		= {nil, 384, 20},
	Troll		= {nil, 385, 20},
	Fossil		= {nil, 393, 20},
	NightElf	= {nil, 394, 20},
	Tolvir		= {nil, 401, 20},
	Outland		= {nil, true},
	Draenei		= {nil, 398, 20},
	Orc			= {nil, 397, 20},
	Northend	= {nil, true},
	Vrykul		= {nil, 399, 20},
	Nerubian	= {nil, 400, 20}, 
};
local racesOrder = {
	"Azeroth", -- continent header
	"Dwarf","Troll","Fossil","NightElf","Tolvir",
	"Outland", -- continent header
	"Draenei","Orc",
	"Northend", -- continent header
	"Vrykul","Nerubian"
};
local keystoneItem2race = {};
--[[
local QuestStarterItems,QuestStarterItemIds = {},{
	[ 79872]=1,[ 79873]=1,[ 79874]=1,[ 79875]=1,[ 79876]=1,[ 79877]=1,[ 79878]=1,[ 79879]=1,[ 79880]=1,[ 79881]=1,[ 79882]=1,[ 79883]=1,
	[ 79884]=1,[ 79885]=1,[ 79886]=1,[ 79887]=1,[ 79888]=1,[ 79889]=1,[ 79890]=1,[ 79891]=1,[ 79892]=1,[ 79893]=1,[ 85453]=1,[ 85477]=1,
	[ 85533]=1,[ 85534]=1,[ 85557]=1,[ 85558]=1,[ 89145]=1,[ 89146]=1,[ 89147]=1,[ 89148]=1,[ 89149]=1,[ 89150]=1,[ 89151]=1,[ 89152]=1,
	[ 89154]=1,[ 89155]=1,[ 89156]=1,[ 89157]=1,[ 89158]=1,[ 89159]=1,[ 89160]=1,[ 89161]=1,[ 89169]=1,[ 89170]=1,[ 89171]=1,[ 89172]=1,
	[ 89173]=1,[ 89174]=1,[ 89175]=1,[ 89176]=1,[ 89178]=1,[ 89179]=1,[ 89180]=1,[ 89181]=1,[ 89182]=1,[ 89183]=1,[ 89184]=1,[ 89185]=1,
	[ 89209]=1,[ 89587]=1,[ 89590]=1,[ 89660]=1,[ 89661]=1,[ 95351]=1,[ 95352]=1,[ 95353]=1,[ 95354]=1,[ 95355]=1,[ 95356]=1,[ 95357]=1,
	[ 95358]=1,[ 95359]=1,[ 95360]=1,[ 95361]=1,[ 95362]=1,[ 95363]=1,[ 95364]=1,[ 95365]=1,[ 95366]=1,[ 95367]=1,[ 95368]=1,[ 95383]=1,
	[ 95384]=1,[ 95385]=1,[ 95386]=1,[ 95387]=1,[ 95388]=1,[ 95389]=1,[ 95390]=1,[114117]=1,[114118]=1,[114119]=1,[114120]=1,[114121]=1,
	[114122]=1,[114123]=1,[114124]=1,[114125]=1,[114126]=1,[114127]=1,[114128]=1,[114129]=1,[114130]=1,[114131]=1,[114132]=1,[114133]=1,
	[114134]=1,[114135]=1,[114136]=1,[114137]=1,[114138]=1,[114139]=1,[114140]=1,[114141]=1,[114142]=1,[114143]=1,[114144]=1,[114145]=1,
	[114146]=1,[114147]=1,[114148]=1,[114149]=1,[114150]=1,[114151]=1,[114152]=1,[114153]=1,[114154]=1,[114156]=1,[114157]=1,[114158]=1,
	[114159]=1,[114160]=1,[114161]=1,[114162]=1,[114163]=1,[114164]=1,[114165]=1,[114166]=1,[114167]=1,[114168]=1,[114169]=1,[114170]=1,
	[114171]=1,[114172]=1,[114173]=1,[114174]=1,[114175]=1,[114176]=1,[114177]=1,[114178]=1,[114179]=1,[114180]=1,[114181]=1,[114182]=1,
	[114183]=1,[114184]=1,[114185]=1,[114186]=1,[114187]=1,[114188]=1,[114189]=1,[114191]=1,[114192]=1,[114193]=1,[114194]=1,[114195]=1,
	[114196]=1,[114197]=1,[114198]=1,[114199]=1,[114200]=1,[114208]=1,[114209]=1,[114210]=1,[114211]=1,[114212]=1,[114213]=1,[114215]=1,
	[114216]=1,[114217]=1,[114218]=1,[114219]=1,[114220]=1,[114221]=1,[114222]=1,[114223]=1,[114224]=1,[130882]=1,[130883]=1,[130884]=1,
	[130885]=1,[130886]=1,[130887]=1,[130888]=1,[130889]=1,[130890]=1,[130891]=1,[130892]=1,[130893]=1,[130894]=1,[130895]=1,[130896]=1,
	[130897]=1,[130898]=1,[130899]=1,[130900]=1,[130901]=1,[130902]=1,[130903]=1,[130904]=1,[130905]=1,[130906]=1,[130907]=1,[130908]=1,
	[130909]=1,[130910]=1,[130911]=1
};
--]]
local solvables,limitWarning = {},{};

if ns.build>50000000 then -- MoP
	races.Pandaria	= {nil, true};
	races.Pandaren	= {nil, 676, 20};
	races.Mogu		= {nil, 677, 20};
	races.Mantid	= {nil, 754, 20};
	tinsert(racesOrder,"Pandaria"); -- continent header
	tinsert(racesOrder,"Pandaren");
	tinsert(racesOrder,"Mogu");
	tinsert(racesOrder,"Mantid");
end

if ns.build>60000000 then -- WoD
	races.Draenor		= {nil, true};
	races.DraenorOrc	= {nil, 821, 20};
	races.Ogre			= {nil, 828, 20};
	races.Arakkoa		= {nil, 829, 20};
	tinsert(racesOrder,"Draenor"); -- continent header
	tinsert(racesOrder,"DraenorOrc");
	tinsert(racesOrder,"Ogre");
	tinsert(racesOrder,"Arakkoa");
end

if ns.build>70000000 then -- Legion
	races.Legion				= {nil, true};
	races.HighborneNightElves	= {nil, 1172, 12};
	races.HighmountainTauren	= {nil, 1173, 12};
	races.Demons				= {nil, 1174, 12};
	tinsert(racesOrder,"Legion"); -- continent header
	tinsert(racesOrder,"HighborneNightElves");
	tinsert(racesOrder,"HighmountainTauren");
	tinsert(racesOrder,"Demons");
end

if ns.build>80000000 then -- ?
end


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="INTERFACE\\ICONS\\trade_archaeology",coords={0.05,0.95,0.05,0.95}}; --IconName::Archaeology--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show archaeology factions with fragments, keystones and necessary amount of fragments to solve artifacts"],
	label = PROFESSIONS_ARCHAEOLOGY,
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
		{ type="header", label=PROFESSIONS_ARCHAEOLOGY, align="left", icon=true },
		{ type="separator" },
		{ type="toggle", name="continentOrder", label=L["Order by continent"], tooltip=L["Order archaeology races by continent"] }
	},
	clickOptions = {
		["1_open_archaeology_frame"] = {
			cfg_label = "Open archaeology frame", -- L["Open archaeology frame"]
			cfg_desc = "open your archaeology frame", -- L["open your archaeology frame"]
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
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function limitColors(numFree,default)
	return (numFree<=10 and "red") or (numFree<=30 and "orange") or (numFree<=50 and "yellow") or default;
end


local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(ldbName);
	local text = {};
	if #limitWarning>0 then
		table.sort(limitWarning,function(a,b) return a.free < b.free; end);
		local _,v = pairs(limitWarning);
		tinsert(text,C(limitColors(v.free,"white"),v.name .. (#limitWarning>1 and " "..L["and %d more"]:format(#limitWarning-1) or "")));
	end
	if #solvables>0 then
		tinsert(text,C("green",solvables[1] .. (#solvables>1 and " " ..L["and %d more"]:format(#solvables-1) or "")));
	end
	obj.text = #text>0 and table.concat(text,", ") or PROFESSIONS_ARCHAEOLOGY;
end

local function updateRaceArtifact(t,...)
	local ArtifactName,_,_,ArtifactIcon,_,KeystoneSlots = ...;
	local icon = "|T%s:14:14:0:0:64:64:4:56:4:56|t";

	if t[raceArtifactName]==nil and ArtifactName~=nil then
		t[raceArtifactName],t[raceArtifactIcon],t[raceKeystoneSlots] = ArtifactName,ArtifactIcon,KeystoneSlots;
		t[raceArtifactIcon] = icon:format(t[raceArtifactIcon]);

		--[=[
		local item = {GetItemInfo(t[raceArtifactName])};
		if item[1] then
			local id = tonumber(item[2]:match("item:(%d+)"));
			if id~=nil then
				QuestStarterItems[item[1]] = id;
			end
		end
		--]=]

		if(type(t[raceKeystoneItemID])=="number" and t[raceKeystoneItemID]>0) then
			keystoneItem2race[t[raceKeystoneItemID]] = k;
			t[raceKeystoneIcon] = icon:format(GetItemIcon(t[raceKeystoneItemID]) or ns.icon_fallback);
			t[raceKeystoneCount] = GetItemCount(t[raceKeystoneItemID],true,true);
		end

		if(t[raceKeystoneSlots]>0)then
			t[raceKeystoneFragmentsValue] = (t[raceKeystoneCount]<=t[raceKeystoneSlots] and t[raceKeystoneCount] or t[raceKeystoneSlots]) * t[raceKeystone2Fragments]; -- 20;
		end

		if(t[raceFragmentsCollected]+t[raceKeystoneFragmentsValue]>=t[raceNumFragmentsRequired])then
			t[raceArtifactSolvable]=true
			tinsert(solvables,t[raceName]);
		end
	elseif ArtifactName~=nil then
		t[raceKeystoneSlots] = KeystoneSlots;

		t[raceKeystoneCount] = 0;
		if(type(t[raceKeystoneItemID])=="number" and t[raceKeystoneItemID]>0) then
			t[raceKeystoneCount] = GetItemCount(t[raceKeystoneItemID],true,true);
		end

		if(t[raceKeystoneSlots]>0)then
			t[raceKeystoneFragmentsValue] = (t[raceKeystoneCount]<t[raceKeystoneSlots] and t[raceKeystoneCount] or t[raceKeystoneSlots]) * t[raceKeystone2Fragments]; -- 20;
		end

		if(t[raceFragmentsCollected]+t[raceKeystoneFragmentsValue]>=t[raceNumFragmentsRequired])then
			t[raceArtifactSolvable]=true
			tinsert(solvables,t[raceName]);
		end
	end
end

local function updateRaces(firstUpdate)
	wipe(solvables);
	if firstUpdate then
		local num = GetNumArchaeologyRaces();
		local icon = "|T%s:14:14:0:0:64:64:4:56:4:56|t";
		local icon2="|T%s:14:14:0:0:128:128:3:70:8:75|t";
		local unknownHeader = true;
		for i=1, num do
			local info,iconFile,_ = {GetArchaeologyRaceInfo(i)};
			local k=select(3,strsplit("-",info[2]));
			local t = races[k];
			if t==nil then
				if unknownHeader then
					tinsert(racesOrder,UNKNOWN);
					races[UNKNOWN] = {nil, true};
					unknownHeader = false;
				end
				tinsert(racesOrder,k);
				races[k] = {nil, 0, 0};
				t=races[k];
			end
			t[raceIndex],t[raceKeystoneCount],t[raceKeystoneFragmentsValue],t[raceArtifactSolvable] = i,0,0,false;
			t[raceName],t[raceTexture],t[raceKeystoneItemID],t[raceFragmentsCollected],t[raceNumFragmentsRequired],t[raceFragmentsMax] = unpack(info);
			t[raceTexture] = icon2:format(t[raceTexture]);

			
			if t[raceCurrencyId]~=0 then
				_,_,iconFile = GetCurrencyInfo(t[raceCurrencyId]);
			end
			t[raceFragmentsIcon] = icon:format(iconFile or ns.icon_fallback);

			updateRaceArtifact(t,GetActiveArtifactByRace(i));
		end
	else
		for k, t in pairs(races)do
			local _;
			t[raceKeystoneFragmentsValue] = 0;
			_, _, _, t[raceFragmentsCollected], t[raceNumFragmentsRequired] = GetArchaeologyRaceInfo(t[raceIndex]);
			updateRaceArtifact(t,GetActiveArtifactByRace(i));
		end
	end
	updateBroker();
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
		GameTooltip:SetHyperlink("item:"..self.itemId);

		GameTooltip:SetFrameLevel(self:GetFrameLevel()+1);
		GameTooltip:Show();
	else
		GameTooltip:Hide();
	end
end

local function ItemTooltipHide(self)
	GameTooltip:Hide();
end

local function toggleArchaeologyFrame(self)
	if ( not ArchaeologyFrame ) then
		securecall("ArchaeologyFrame_LoadUI");
	end
	if ( ArchaeologyFrame ) then
		if not ArchaeologyFrame:IsShown() then
			securecall("ArchaeologyFrame_Show");
		end
		securecall("ArchaeologyFrame_OnTabClick",ArchaeologyFrame.tab1);
		securecall("ArchaeologyFrame_ShowArtifact",self.raceIndex);
	end
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	tt:Clear()
	local ts,l = C("gray",L["Not learned"]),tt:AddHeader(C("dkyellow",PROFESSIONS_ARCHAEOLOGY))
	if tradeskill.maxSkill>0 then
		ts = tradeskill.skill.." / "..tradeskill.maxSkill;
	end
	tt:SetCell(l,ttColumns-2, ts, nil, "RIGHT", 3);

	if not ns.profile[name].continentOrder then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",RACES),C("ltblue",L["Keystones"]),C("ltblue",ARCHAEOLOGY_RUNE_STONES),C("ltblue",L["Artifacts"]));
		tt:AddSeparator();
	end

	for i, k in ipairs(racesOrder)do
		local v = races[k];
		if v[raceCurrencyId]==true then
			if ns.profile[name].continentOrder then
				tt:AddSeparator(4,0,0,0,0);
				tt:AddLine(C("ltblue",RACES.." ("..L[k]..")"),C("ltblue",L["Keystones"]),C("ltblue",ARCHAEOLOGY_RUNE_STONES),C("ltblue",L["Artifacts"]));
				tt:AddSeparator();
			end
		elseif v[raceName] and v[raceArtifactName] then
			local l=tt:AddLine(
				v[raceTexture].." "..C(v[raceArtifactSolvable]==true and "green" or "ltyellow",v[raceName]),
				v[raceKeystoneIcon]~=nil and v[raceKeystoneCount].." "..v[raceKeystoneIcon] or "",
				C(limitColors(v[raceFragmentsMax]-v[raceFragmentsCollected],"white"),v[raceFragmentsCollected].." / "..v[raceFragmentsMax]).." "..v[raceFragmentsIcon],
				C(v[raceArtifactSolvable]==true and "green" or "white",v[raceNumFragmentsRequired].." "..v[raceArtifactIcon]),
				--[[QuestStarterItems[raceArtifactName] and "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|t" or]] " "
			);
			if(v[raceKeystoneItemID]~=0)then
				tt.lines[l].itemId=v[raceKeystoneItemID];
				tt:SetLineScript(l,"OnEnter", ItemTooltipShow);
				tt:SetLineScript(l,"OnLeave", ItemTooltipHide);
			end
			tt.lines[l].raceIndex = v[raceIndex];
			tt:SetLineScript(l,"OnMouseUp", toggleArchaeologyFrame);
			--[=[
			if QuestStarterItems[v[raceArtifactName]] then
				tt.lines[l].cells[4].itemId = QuestStarterItems[v[raceArtifactName]];
				tt:SetCellScript(l,4,"OnEnter", ItemTooltipShow);
				tt:SetCellScript(l,4,"OnLeave", ItemTooltipHide);
			end
			--]=]
		elseif v[raceName] then
			local l=tt:AddLine(
				v[raceTexture].." "..C("gray",v[raceName]),
				" ",
				C("gray",v[raceFragmentsCollected].." / "..v[raceFragmentsMax]),
				" ",
				" "
			);
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0)
		ns.AddSpannedLine(tt,C("ltblue",L["Click"]).." || "..C("green",L["Open archaeology frame with choosen faction"]));
		ns.clickOptions.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,...)
	if event=="GET_ITEM_INFO_RECEIVED" then
		--[[
		local id = ...;
		if(type(id)=="number")then
			local item=GetItemInfo(id);
			if item~=nil then
				QuestStarterItems[item]=id;
			end
		end
		--]]
	elseif event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	else
		if event=="PLAYER_ENTERING_WORLD" then
			updateRaces(true);

			local _;
			_,_,tradeskill.id = GetProfessions();
			if tradeskill.id then
				tradeskill.name,tradeskill.icon,tradeskill.skill,tradeskill.maxSkill = GetProfessionInfo(tradeskill.id);
			else
				tradeskill.name,_,tradeskill.icon = GetSpellInfo(78670);
				tradeskill.skill, tradeskill.maxSkill = 0,0;
			end

			self:UnregisterEvent(event);
		else
			updateRaces(true);
		end
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "CENTER", "RIGHT", "RIGHT","RIGHT"},{false},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

