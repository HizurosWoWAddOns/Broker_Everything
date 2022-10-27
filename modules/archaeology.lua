
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.client_version<4 then return end


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Archaeology"; -- PROFESSIONS_ARCHAEOLOGY L["ModDesc-Archaeology"]
local ttName, ttColumns, tt, skill, module = name.."TT", 5
local tradeskill, maxFragments, maxFragments250 = {},200,{[109585]=1,[108439]=1,[109584]=1};
local raceIndex,raceCurrencyId,raceKeystone2Fragments,raceName,raceTexture,raceKeystoneItemID = 1,2,3,4,5,6;
local raceFragmentsCollected,raceNumFragmentsRequired,raceFragmentsMax,raceArtifactName,raceArtifactIcon,raceKeystoneSlots = 7,8,9,10,11,12;
local raceKeystoneIcon,raceKeystoneCount,raceKeystoneFragmentsValue,raceArtifactSolvable,raceFragmentsIcon,raceCurrencyName = 13,14,15,16,17,18;
local keystoneItem2race,races,racesOrder = {};
local defaultKeystoneToFragment = 12;
local solvables,limitWarning,currencyName2race,currencySeen = {},{},{};
local iconFormat1 = "|T%s:14:14:0:0:64:64:4:56:4:56|t";
local iconFormat2 = "|T%s:14:14:0:0:128:128:3:70:8:75|t";
local CHAT_MSG_CURRENCY_PATTERN = "%[(.*)%]";
local knownCurrencies = { -- for module currency but managed here
	[384]=true,[385]=true,[393]=true,[394]=true,
	[401]=true,[398]=true,[397]=true,[399]=true,
	[400]=true,[676]=true,[677]=true,[754]=true,
	[821]=true,[828]=true,[829]=true,[1172]=true,
	[1173]=true,[1174]=true,[1535]=true,[1534]=true,
}


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="INTERFACE\\ICONS\\trade_archaeology",coords={0.05,0.95,0.05,0.95}}; --IconName::Archaeology--


-- some local functions --
--------------------------
function ns.isArchaeologyCurrency(id)
	return knownCurrencies[id];
end

local function limitColors(numFree,default)
	return (numFree<=10 and "red") or (numFree<=30 and "orange") or (numFree<=50 and "yellow") or default;
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local text = {};
	local numWarning = #limitWarning;
	if currencySeen then
		local str = currencySeen[raceName].." "..currencySeen[raceFragmentsCollected];
		if ns.profile[name].infoRequiredFragments then
			str = str.."/"..currencySeen[raceNumFragmentsRequired];
		end
		if ns.profile[name].infoMaxFragments then
			str = str.." ("..currencySeen[raceFragmentsMax]..")";
		end
		local color = limitColors(currencySeen[raceFragmentsMax]-currencySeen[raceFragmentsCollected],"white");
		tinsert(text,color~="white" and C(color,str) or str);
	end
	if #solvables>0 then
		tinsert(text,C("green",solvables[1] .. (#solvables>1 and " " ..L["and %d more"]:format(#solvables-1) or "")));
	end
	obj.text = #text>0 and table.concat(text,", ") or PROFESSIONS_ARCHAEOLOGY;
end

local function updateRaceArtifact(t,...)
	local ArtifactName,_,_,ArtifactIcon,_,KeystoneSlots = ...;

	if t[raceArtifactName]==nil and ArtifactName~=nil then
		t[raceArtifactName],t[raceArtifactIcon],t[raceKeystoneSlots] = ArtifactName,ArtifactIcon,KeystoneSlots;
		t[raceArtifactIcon] = iconFormat1:format(t[raceArtifactIcon]);

		if(type(t[raceKeystoneItemID])=="number" and t[raceKeystoneItemID]>0) then
			--keystoneItem2race[t[raceKeystoneItemID]] = t;
			t[raceKeystoneIcon] = iconFormat1:format(GetItemIcon(t[raceKeystoneItemID]) or ns.icon_fallback);
			t[raceKeystoneCount] = GetItemCount(t[raceKeystoneItemID],true,true);
		end

		if(t[raceKeystoneSlots]>0)then
			t[raceKeystoneFragmentsValue] = (t[raceKeystoneCount]<=t[raceKeystoneSlots] and t[raceKeystoneCount] or t[raceKeystoneSlots]) * (t[raceKeystone2Fragments] or defaultKeystoneToFragment);
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
			t[raceKeystoneFragmentsValue] = (t[raceKeystoneCount]<t[raceKeystoneSlots] and t[raceKeystoneCount] or t[raceKeystoneSlots]) * (t[raceKeystone2Fragments] or defaultKeystoneToFragment);
		end

		if(t[raceFragmentsCollected]+t[raceKeystoneFragmentsValue]>=t[raceNumFragmentsRequired])then
			t[raceArtifactSolvable]=true
			tinsert(solvables,t[raceName]);
		end
	end
end

local function updateRaces(firstUpdate)
	wipe(solvables);
	wipe(limitWarning);
	if firstUpdate then
		local num = GetNumArchaeologyRaces();
		local unknownHeader = true;
		for i=1, num do
			local info,iconFile,_ = {GetArchaeologyRaceInfo(i)};
			local t = races[info[2]];
			if t==nil then
				if unknownHeader then
					tinsert(racesOrder,UNKNOWN);
					races[UNKNOWN] = {nil, true};
					unknownHeader = false;
				end
				tinsert(racesOrder,info[2]);
				races[info[2]] = {nil, 0, 0};
				t=races[info[2]];
			end
			t[raceIndex],t[raceKeystoneCount],t[raceKeystoneFragmentsValue],t[raceArtifactSolvable] = i,0,0,false;
			t[raceName],t[raceTexture],t[raceKeystoneItemID],t[raceFragmentsCollected],t[raceNumFragmentsRequired],t[raceFragmentsMax] = unpack(info);
			t[raceTexture] = iconFormat2:format(t[raceTexture]);

			if t[raceCurrencyId]~=0 then
				local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(t[raceCurrencyId]);
				t[raceCurrencyName] = currencyInfo.name;
				iconFile = currencyInfo.iconFileID
			end
			t[raceFragmentsIcon] = iconFormat1:format(iconFile or ns.icon_fallback);

			updateRaceArtifact(t,GetActiveArtifactByRace(i));

			if t[raceCurrencyName] then
				currencyName2race[t[raceCurrencyName]] = info[2];
			end
		end
	else
		for k, t in pairs(races)do
			local _;
			t[raceKeystoneFragmentsValue] = 0;
			_, _, _, t[raceFragmentsCollected], t[raceNumFragmentsRequired] = GetArchaeologyRaceInfo(t[raceIndex]);
			updateRaceArtifact(t,GetActiveArtifactByRace(t[raceIndex]));
		end
	end
	updateBroker();
end

local function ItemTooltipShow(self,itemId)
	if (self) then
		GameTooltip:SetOwner(self,"ANCHOR_NONE");
		if (select(1,self:GetCenter()) > (select(1,UIParent:GetWidth()) / 2)) then
			GameTooltip:SetPoint("RIGHT",tt,"LEFT",-2,0);
		else
			GameTooltip:SetPoint("LEFT",tt,"RIGHT",2,0);
		end
		GameTooltip:SetPoint("TOP",self,"TOP", 0, 4);

		GameTooltip:ClearLines();
		GameTooltip:SetHyperlink("item:"..itemId);

		GameTooltip:SetFrameLevel(self:GetFrameLevel()+1);
		GameTooltip:Show();
	else
		GameTooltip:Hide();
	end
end

local function toggleArchaeologyFrame(self,raceIndex)
	if ( not ArchaeologyFrame ) then
		securecall("ArchaeologyFrame_LoadUI");
	end
	if ( ArchaeologyFrame ) then
		if not ArchaeologyFrame:IsShown() then
			securecall("ArchaeologyFrame_Show");
		end
		securecall("ArchaeologyFrame_OnTabClick",ArchaeologyFrame.tab1);
		securecall("ArchaeologyFrame_ShowArtifact",raceIndex);
	end
end

local function createTooltip(tt)
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end
	local ts,l = C("gray",L["Not learned"]),tt:AddHeader(C("dkyellow",PROFESSIONS_ARCHAEOLOGY))
	if tradeskill.maxSkill and tradeskill.maxSkill>0 then
		ts = tradeskill.skill.." / "..tradeskill.maxSkill;
	end
	tt:SetCell(l,ttColumns-2, ts, nil, "RIGHT", 3);

	if not ns.profile[name].continentOrder then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",RACES),C("ltblue",L["Keystones"]),C("ltblue",ARCHAEOLOGY_RUNE_STONES),C("ltblue",L["Artifacts"]));
		tt:AddSeparator();
	end

	for i=1, #racesOrder do
		local raceTextureID = racesOrder[i];
		if not races[raceTextureID] then
			if ns.profile[name].continentOrder then
				local mapID,mapName = tonumber(raceTextureID),raceTextureID;
				if mapID then
					local mapInfo = C_Map.GetMapInfo(mapID);
					if mapInfo then
						mapName = mapInfo.name;
					end
				end
				tt:AddSeparator(4,0,0,0,0);
				tt:AddLine(C("ltblue",RACES.." ("..mapName..")"),C("ltblue",L["Keystones"]),C("ltblue",ARCHAEOLOGY_RUNE_STONES),C("ltblue",L["Artifacts"]));
				tt:AddSeparator();
			end
		else
			local raceData = races[raceTextureID];
			if raceData[raceName] and raceData[raceArtifactName] then
				local l=tt:AddLine(
					raceData[raceTexture].." "..C(raceData[raceArtifactSolvable]==true and "green" or "ltyellow",raceData[raceName]),
					raceData[raceKeystoneIcon]~=nil and raceData[raceKeystoneCount].." "..raceData[raceKeystoneIcon] or "",
					C(limitColors(raceData[raceFragmentsMax]-raceData[raceFragmentsCollected],"white"),raceData[raceFragmentsCollected].." / "..raceData[raceFragmentsMax]).." "..raceData[raceFragmentsIcon],
					C(raceData[raceArtifactSolvable]==true and "green" or "white",raceData[raceNumFragmentsRequired].." "..raceData[raceArtifactIcon])
				);
				if(raceData[raceKeystoneItemID]~=0)then
					tt:SetLineScript(l,"OnEnter", ItemTooltipShow,raceData[raceKeystoneItemID]);
					tt:SetLineScript(l,"OnLeave", GameTooltip_Hide);
				end
				tt:SetLineScript(l,"OnMouseUp", toggleArchaeologyFrame, raceData[raceIndex]);
			elseif raceData[raceName] then
				local l=tt:AddLine(
					raceData[raceTexture].." "..C("gray",raceData[raceName]),
					" ",
					C("gray",raceData[raceFragmentsCollected].." / "..raceData[raceFragmentsMax]),
					" ",
					" "
				);
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0)
		ns.AddSpannedLine(tt,C("ltblue",L["MouseBtn"]).." || "..C("green",L["Open archaeology frame with choosen faction"]));
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module variables for registration --
---------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"ARTIFACT_UPDATE",
		"RESEARCH_ARTIFACT_UPDATE",
		"RESEARCH_ARTIFACT_COMPLETE",
		"CURRENCY_DISPLAY_UPDATE",
		"CHAT_MSG_CURRENCY"
	},
	config_defaults = {
		enabled = false,
		inTitle = {},
		continentOrder=true,
		infoMaxFragments=true,
		infoMaxFragments=true,
	},
	clickOptionsRename = {
		["archaeology"] = "1_open_archaeology_frame",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["archaeology"] = {PROFESSIONS_ARCHAEOLOGY,"module","ToggleArchaeologyFrame"},
		["menu"] = "OptionMenu"

	}
};

ns.ClickOpts.addDefaults(module,{
	archaeology = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
			infoRequiredFragments = { type="toggle", order=1, name=L["ArchaeologyInfoRequiredFragements"], desc=L["ArchaeologyInfoRequiredFragementsDesc"] },
			infoMaxFragments = { type="toggle", order=2, name=L["ArchaeologyInfoMaxFragements"], desc=L["ArchaeologyInfoMaxFragementsDesc"]},
		},
		tooltip = {
			continentOrder = { type="toggle", order=1, name=L["OptArchOrder"], desc=L["OptArchOrderDesc"] }
		}
	}
end

function module.init()
	racesOrder = {
		"947", -- continent header / mapID / Azeroth
		461831,461841,461833,461837,461839,
		"101", -- continent header / mapID / Outland
		461829,462321,
		"113", -- continent header / mapID / Northend
		461843,461835,
		"424", -- continent header / mapID / Pandaria
		633002,633000,839111,
		"572", -- continent header / mapID / Draenor
		1030617,1030618,1030616,
		"619", -- continent header / mapID / Legion
		1445575,1445577,1445573,
		"876", -- continent header / mapID / KulTiras
		2060049,
		"875", -- continent header / mapID / Zandalar
		2060051
	};
	races = { -- [<raceTextureID>] = { <raceIndex>, <currencyId>, <raceKeystone2FragmentsCount> }
		--Azeroth
		[461831] = {nil, 384, nil}, -- Dwarf
		[461841] = {nil, 385, nil}, -- Troll
		[461833] = {nil, 393, nil}, -- Fossil
		[461837] = {nil, 394, nil}, -- NightElf
		[461839] = {nil, 401, nil}, -- Tolvir

		--Outland
		[461829] = {nil, 398, nil}, -- Draenei
		[462321] = {nil, 397, nil}, -- Orc

		--Northend
		[461843] = {nil, 399, nil}, -- Vrykul
		[461835] = {nil, 400, nil}, -- Nerubian

		--Pandaria
		[633002] = {nil, 676, 20}, -- Pandaren
		[633000] = {nil, 677, 20}, -- Mogu
		[839111] = {nil, 754, 20}, -- Mantid

		--Draenor
		[1030617] = {nil, 821, 20}, -- DraenorOrc
		[1030618] = {nil, 828, 20}, -- Ogre
		[1030616] = {nil, 829, 20}, -- Arakkoa

		--Legion
		[1445575] = {nil, 1172, nil}, -- HighborneNightElves
		[1445577] = {nil, 1173, nil}, -- HighmountainTauren
		[1445573] = {nil, 1174, nil}, -- Demons

		-- BfA
		[2060049] = {nil,1535, nil}, -- Drust
		[2060051] = {nil,1534, nil}, -- Zandalari
	};
end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="PLAYER_LOGIN" then
		updateRaces(true);

		local _;
		_,_,tradeskill.id = GetProfessions();
		if tradeskill.id then
			tradeskill.name,tradeskill.icon,tradeskill.skill,tradeskill.maxSkill = GetProfessionInfo(tradeskill.id);
		else
			tradeskill.name,_,tradeskill.icon = GetSpellInfo(78670);
			tradeskill.skill, tradeskill.maxSkill = 0,0;
		end
	end
	if ns.eventPlayerEnteredWorld then
		if event=="CHAT_MSG_CURRENCY" then
			local currencyStr  = arg1:match(CHAT_MSG_CURRENCY_PATTERN);
			if currencyName2race[currencyStr] and races[currencyName2race[currencyStr]] then
				currencySeen = races[currencyName2race[currencyStr]];
			end
		end
		updateRaces(true);
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "CENTER", "RIGHT", "RIGHT","RIGHT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end

function module.ToggleArchaeologyFrame(self,button)
	if not ArchaeologyFrame then
		ArchaeologyFrame_LoadUI()
	end
	if ArchaeologyFrame then
		securecall("ArchaeologyFrame_"..(ArchaeologyFrame:IsShown() and "Hide" or "Show"));
	end
end

-- final module registration --
-------------------------------
ns.modules[name] = module;
