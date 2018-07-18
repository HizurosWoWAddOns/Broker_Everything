
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Archaeology"; -- PROFESSIONS_ARCHAEOLOGY
local ttName, ttColumns, tt, skill, module = name.."TT", 5
local tradeskill, maxFragments, maxFragments250 = {},200,{[109585]=1,[108439]=1,[109584]=1};
local raceIndex,raceCurrencyId,raceKeystone2Fragments,raceName,raceTexture,raceKeystoneItemID = 1,2,3,4,5,6;
local raceFragmentsCollected,raceNumFragmentsRequired,raceFragmentsMax,raceArtifactName,raceArtifactIcon,raceKeystoneSlots = 7,8,9,10,11,12;
local raceKeystoneIcon,raceKeystoneCount,raceKeystoneFragmentsValue,raceArtifactSolvable,raceFragmentsIcon = 13,14,15,16,17;
local keystoneItem2race,races,racesOrder = {};
local solvables,limitWarning,iconID2Race = {},{};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="INTERFACE\\ICONS\\trade_archaeology",coords={0.05,0.95,0.05,0.95}}; --IconName::Archaeology--


-- some local functions --
--------------------------
local function limitColors(numFree,default)
	return (numFree<=10 and "red") or (numFree<=30 and "orange") or (numFree<=50 and "yellow") or default;
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
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
			local k = iconID2Race[info[2]] or "UNKNOWN";
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

local function ItemTooltipHide(self)
	GameTooltip:Hide();
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
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	if tt.lines~=nil then tt:Clear(); end
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
				C(v[raceArtifactSolvable]==true and "green" or "white",v[raceNumFragmentsRequired].." "..v[raceArtifactIcon])
			);
			if(v[raceKeystoneItemID]~=0)then
				tt:SetLineScript(l,"OnEnter", ItemTooltipShow,v[raceKeystoneItemID]);
				tt:SetLineScript(l,"OnLeave", ItemTooltipHide);
			end
			tt:SetLineScript(l,"OnMouseUp", toggleArchaeologyFrame, v[raceIndex]);
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
		--"KNOWN_CURRENCY_TYPES_UPDATE", -- alerted in 8.0
		"ARTIFACT_UPDATE",
		--"ARTIFACT_COMPLETE", -- alerted in 8.0
		"CURRENCY_DISPLAY_UPDATE",
		"CHAT_MSG_SKILL"
	},
	config_defaults = {
		enabled = false,
		inTitle = {},
		continentOrder=true
	},
	clickOptionsRename = {
		["archaeology"] = "1_open_archaeology_frame",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["archaeology"] = {"Archaeology","module","ToggleArchaeologyFrame"}, -- L["Archaeology"]
		["menu"] = "OptionMenu"

	}
};

ns.ClickOpts.addDefaults(module,{
	archaeology = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		tooltip = {
			continentOrder = { type="toggle", order=1, name=L["OptArchOrder"], desc=L["OptArchOrderDesc"] }
		}
	}
end

function module.init()
	racesOrder = {
		"Azeroth", -- continent header
		"Dwarf","Troll","Fossil","NightElf","Tolvir",
		"Outland", -- continent header
		"Draenei","Orc",
		"Northend", -- continent header
		"Vrykul","Nerubian"
	};

	races = { -- <raceIndex>, <currencyId>, <raceKeystone2FragmentsCount>
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

	iconID2Race = { -- 7.3 -- required since blizzard replaced iconFile with iconFileID
		[461829]="Draenei",		[461831]="Dwarf",
		[461833]="Fossil",		[462319]="Misc",
		[461835]="Nerubian",	[461837]="NightElf",
		[462321]="Orc",			[461839]="Tolvir",
		[461841]="Troll",		[461843]="Vrykul",
		[1030616]="Arakkoa",	[1445573]="Demons",
		[1030617]="DraenorOrc",	[1445575]="HighborneNightElves",
		[839111]="Mantid",		[1445577]="HighmountainTauren",
		[633000]="Mogu",		[1030618]="Ogre",
		[633002]="Pandaren",
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
