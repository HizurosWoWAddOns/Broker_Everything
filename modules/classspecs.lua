
-- module independent variables --
----------------------------------
local addon, ns = ...
if ns.build<70000000 then return end
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "ClassSpecs" -- L["ClassSpecs"] L["ModDesc-ClassSpecs"]
local ttName, ttColumns, tt, module, createTooltip = name.."TT", 4;


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=134942,coords={0.05,0.95,0.05,0.95}}; --IconName::ClassSpecs--


-- some local functions --
--------------------------
local function infoTooltipShow(self, info)
	if info then
		GameTooltip:SetOwner(tt,"ANCHOR_NONE");
		GameTooltip:SetPoint(ns.GetTipAnchor(tt,"horizontal"));
		if info.type=="text" and #info>0 then
			for i=1, #info do
				GameTooltip:AddLine(unpack(info[i]),nil,nil,nil,1);
			end
		elseif info.type=="spell" and info.spellId then
			GameTooltip:SetHyperlink("spell:"..info.spellId);
		elseif info.type=="talent" and info.args then
			GameTooltip:SetTalent(unpack(info.args));
		elseif info.type=="pvptalent" and info.args then
			GameTooltip:SetPvpTalent(unpack(info.args));
		end
		if info.extraLine then
			GameTooltip:AddLine(info.extraLine);
		end
		GameTooltip:Show();
	end
end

local function infoTooltipHide()
	GameTooltip:Hide();
end

local function setSpec(self, spec)
	if not InCombatLockdown() then
		SetSpecialization(spec.index,spec.ispet);
	end
end

local function setLootSpec(_, spec)
	SetLootSpecialization(spec);
	C_Timer.After(.7,function() createTooltip(tt,true) end);
end

local function changeTalent(_, talent)
	local f = LearnTalent;
	if talent.type=="pvp" then
		f = LearnPvpTalent;
	end
	f(talent.id);
end

local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName) or {};
	local specName,text,_ = L["No Spec!"],"";
	local icon = I(name);
	local spec = GetSpecialization();

	if spec ~= nil then
		local current = icon.iconfile;
		 _, specName, _, icon.iconfile, _, _ = GetSpecializationInfo(spec);
		 if current ~= icon.iconfile then
			obj.iconCoords, obj.icon = icon.coords, icon.iconfile;
		 end
	end

	txt = specName;

	local unspentPvE,unspentPvP,lvl = (GetNumUnspentTalents()),0,UnitLevel("player");
	for slotIndex=1, 4 do -- not nice but necessary... GetNumUnspentPvpTalents() does not check player level
		local slotMinLevel = C_SpecializationInfo.GetPvpTalentSlotUnlockLevel(slotIndex);
		if slotMinLevel and slotMinLevel<=lvl then
			local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex);
			if slotInfo.enabled and slotInfo.selectedTalentID==nil then
				unspentPvP = unspentPvP+1;
			end
		end
	end

	local lst = {};
	if unspentPvE>0 then
		tinsert(lst,unspentPvE.." "..TRANSMOG_SET_PVE);
	end
	if unspentPvP>0 then
		tinsert(lst,unspentPvP.." "..TRANSMOG_SET_PVP);
	end

	if #lst>0 then
		txt = C("ltred",L["Unspent talents"]..": ".. table.concat(lst,", "));
	end

	obj.text = txt;
end

function createTooltip(tt,update)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:SetCell(tt:AddLine(),1,C("dkyellow",SPECIALIZATION.." & "..TALENTS),tt:GetHeaderFont(),"LEFT",ttColumns);

	local spec,active = {},{index=GetSpecialization(),id=nil,name=nil,icon=nil};
	local lootSpecID = GetLootSpecialization();
	local num = GetNumSpecializations();
	local iconStr,str,_ = "|T%s:0|t","|T%s:0|t %s";

	local l=tt:AddLine();
	tt:SetCell(l,1,C("ltblue",SPECIALIZATION),nil,"LEFT",2);
	tt:SetCell(l,3,C("ltblue",ROLE));
	tt:SetCell(l,4,C("ltblue",LOOT));

	tt:AddSeparator();
	for i=1, num do
		spec[i]={};
		spec[i].id, spec[i].name, spec[i].desc, spec[i].icon, spec[i].role = GetSpecializationInfo(i);
		if active.index==i then
			active.id,active.name,active.icon = spec[i].id,spec[i].name,spec[i].icon;
		end
	end
	for i=1, num do
		local l=tt:AddLine(
			iconStr:format(spec[i].icon),
			C(ns.player.class,spec[i].name) .. (i==active.index and C("green","("..ACTIVE_PETS..")") or ""),
			C( (spec[i].role=="TANK" and "ltblue") or (spec[i].role=="HEALER" and "ltgreen") or "ltred", _G[spec[i].role] ),
			lootSpecID==spec[i].id and C("green",ACTIVE_PETS) or C( "gray", L["Set"])
		);
		if lootSpecID~=spec[i].id then
			tt:SetCellScript(l,4,"OnMouseUp",setLootSpec, spec[i].id);
			tt:SetCellScript(l,4,"OnEnter",infoTooltipShow, {type="text", {L["Click to change your loot specialization"]}});
			tt:SetCellScript(l,4,"OnLeave",infoTooltipHide);
		end
		if i~=active then
			tt:SetLineScript(l,"OnMouseUp",setSpec, {index=i});
		end
		tt:SetLineScript(l,"OnEnter",infoTooltipShow, {type="text", {("|T%s:32:32|t %s"):format(spec[i].icon,spec[i].name)},{spec[i].desc,1,1,1,true}});
		tt:SetLineScript(l,"OnLeave",infoTooltipHide);
	end
	tt:AddSeparator(1,1,1,1,.6);
	local l=tt:AddLine();
	tt:SetCell(l,1,C("dkyellow",strtrim(LOOT_SPECIALIZATION_DEFAULT:gsub("%([ ]?%%s[ ]?%)",""))..":"),nil,"RIGHT",3);
	tt:SetCell(l,4,lootSpecID==0 and C("green",ACTIVE_PETS) or C( "gray", L["Set"]));
	if lootSpecID~=0 then
		tt:SetCellScript(l,4,"OnMouseUp",setLootSpec, 0);
		tt:SetCellScript(l,4,"OnEnter",infoTooltipShow, {type="text", {L["Click to change your loot specialization"]}});
		tt:SetCellScript(l,4,"OnLeave",infoTooltipHide);
	end

	if ns.player.class:lower()=="hunter" then
		tt:AddSeparator(4,0,0,0,0);

		-- pet spec
		local spec,active = {},{index=GetSpecialization(nil,true),id=nil,name=nil,icon=nil};
		local num = GetNumSpecializations(nil,true);
		local iconStr = "|T%s:0|t";

		local l=tt:AddLine();
		tt:SetCell(l,1,C("ltblue",SPECIALIZATION.." ("..PET..")"),nil,"LEFT",2);
		tt:SetCell(l,3,C("ltblue",ROLE));

		tt:AddSeparator();
		if HasPetUI() then
			for i=1, num do
				spec[i]={};
				spec[i].id, spec[i].name, spec[i].desc, spec[i].icon, spec[i].role = GetSpecializationInfo(i,nil,true);
				if active.index==i then
					active.id,active.name,active.icon = spec[i].id,spec[i].name,spec[i].icon;
				end
			end
			for i=1, num do
				local l=tt:AddLine(
					iconStr:format(spec[i].icon),
					C(ns.player.class,spec[i].name) .. (i==active.index and " "..C("green","("..ACTIVE_PETS..")") or ""),
					C( (spec[i].role=="TANK" and "ltblue") or (spec[i].role=="HEALER" and "ltgreen") or "ltred", _G[spec[i].role] )
				);
				if i~=active then
					tt:SetLineScript(l,"OnMouseUp",setSpec, {index=i, true});
				end
			end
		else
			tt:SetCell(tt:AddLine(),1,C("gray",SPELL_FAILED_NO_PET),nil,"CENTER",0);
		end
	end

	-- PVE Talents
	local talentGroup = GetActiveSpecGroup(false);
	if ns.profile[name].showTalents then
		tt:AddSeparator(4,0,0,0,0);
		local l=tt:AddLine(C("ltblue",LEVEL_ABBR));
		tt:SetCell(l,2,C("ltblue",TALENTS),nil,nil,2);
		tt:AddSeparator();
		local Id, Name, Icon, Selected, Available, spellId = 1,2,3,4,5,6;
		local tierLevels = CLASS_TALENT_LEVELS[ns.player.class] or CLASS_TALENT_LEVELS.DEFAULT
		local level = UnitLevel("player");
		for row=1, MAX_TALENT_TIERS do
			local selected, isUnlocked = false,false;
			local l=tt:AddLine(C("ltyellow",tierLevels[row]));
			for col=1, NUM_TALENT_COLUMNS do
				local tmp = {GetTalentInfo(row,col,talentGroup)};
				if ns.profile[name].showTalentsShort then
					if tmp[Available] then
						isUnlocked = true;
					end
					if tmp[Selected]==true then
						selected = tmp;
						break;
					end
				else
					local c,color = col+1,(tmp[Selected] and "ltyellow") or (level>=tierLevels[row] and "gray") or "dkred";
					tt:SetCell(l,c,str:format(tmp[Icon],C(color,tmp[Name])),nil,"LEFT");
					local info = {
						type=level>=tierLevels[row] and "talent" or "spell",
						spellId=tmp[spellId],
						args={tmp[Id],false,talentGroup},
						extraLine=level<tierLevels[row] and C("red",L["TalentLocked"]) or nil
					};
					tt:SetCellScript(l,c,"OnEnter",infoTooltipShow, info);
					tt:SetCellScript(l,c,"OnLeave",infoTooltipHide);
					if not tmp[Selected] and level>=tierLevels[row] then
						tt:SetCellScript(l,c,"OnMouseUp",changeTalent, {id=tmp[Id]});
					end
				end
			end
			if ns.profile[name].showTalentsShort then
				if selected then
					tt:SetCell(l,2,str:format(selected[Icon],C("ltyellow",selected[Name])),nil,nil,0);
					tt:SetLineScript(l,"OnEnter",infoTooltipShow, {type="talent",args={selected[Id],false,talentGroup}});
					tt:SetLineScript(l,"OnLeave",infoTooltipHide);
				elseif isUnlocked then
					tt:SetCell(l,2,C("orange",L["TalentUnlocked"]),nil,nil,0);
				else
					tt:SetCell(l,2,C("gray",L["TalentLocked"]),nil,nil,0);
				end
			end
		end
	end

	-- PVP Talents
	if ns.profile[name].showPvPTalents then
		tt:AddSeparator(4,0,0,0,0);
		local l=tt:AddLine(C("ltblue",LEVEL_ABBR));
		tt:SetCell(l,2,C("ltblue",PVP_TALENTS),nil,"LEFT",0);
		tt:AddSeparator();
		for slotIndex=1, 4 do
			local slotMinLevel = C_SpecializationInfo.GetPvpTalentSlotUnlockLevel(slotIndex);
			local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex);
			local l = tt:AddLine(C("ltyellow",slotMinLevel));
			if slotInfo.enabled then
				if slotInfo.selectedTalentID then
					local _, talentName, texture = GetPvpTalentInfoByID(slotInfo.selectedTalentID);
					tt:SetCell(l,2,str:format(texture,C("ltyellow",talentName)),nil,nil,0);
				else
					tt:SetCell(l,2,C("orange",L["TalentUnlocked"]),nil,nil,0);
				end
			else
				tt:SetCell(l,2,C("gray",L["TalentLocked"]),nil,nil,0);
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltblue",L["MouseBtn"]).." || "..C("green",L["Activate specialization"]),nil,"LEFT",ttColumns);
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"ACTIVE_TALENT_GROUP_CHANGED",
		"PLAYER_TALENT_UPDATE",
		"PLAYER_SPECIALIZATION_CHANGED",
	},
	config_defaults = {
		enabled = false,
		showTalents = true,
		showTalentsShort = false,
		showPvPTalents = true,
	},
	clickOptionsRename = {
		["pvespec"] = "1_open_specialization",
		["pvetalents"] = "2_open_talents",
		["pvptalents"] = "3_open_pvp_talents",
		["petspec"] = "4_open_pet_specialization",
		["menu"] = "6_open_menu"
	},
	clickOptions = {
		["pvespec"] = {SPECIALIZATION,"call",{"ToggleTalentFrame",SPECIALIZATION_TAB}},
		["pvetalents"] = {TALENTS,"call",{"ToggleTalentFrame",TALENTS_TAB}},
		["pvptalents"] = {PVP_TALENTS,"call",{"ToggleTalentFrame",PVP_TALENTS_TAB}},
		["petspec"] = {"Pet specialization","call",{"ToggleTalentFrame",ns.player.class:upper()=="HUNTER" and PET_SPECIALIZATION_TAB or SPECIALIZATION_TAB}}, -- L["Pet specialization"]
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	pvespec = "_LEFT",
	pvetalents = "__NONE",
	pvptalents = "__NONE",
	petspec = "__NONE",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = {
		},
		tooltip = {
			showTalents={ type="toggle", order=1, name=L["Show talents"], desc=L["Show talents in tooltip"]},
			showTalentsShort={ type="toggle", order=2, name=L["Show short talent list"], desc=L["Show short list of PvE talents in tooltip"]},
			showPvPTalents={ type="toggle", order=3, name=PVP_LABEL_PVP_TALENTS, desc=L["Show PvP talents in tooltip"]},
		},
		misc = nil,
	}
end

-- function module.init() end

function module.createTalentMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu:InitializeMenu();
	-- 1. pve talents
	-- 2. pvp talents
	-- 3. pet talents?
	ns.EasyMenu:ShowMenu(self);
end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" then
		if arg1 and arg1:find("^ClickOpt") then
			ns.ClickOpts.update(name);
		end
	else
		updateBroker();
	end
end

-- function module.onmousewheel(self,direction) end
-- function module.optionspanel(panel) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "RIGHT", "LEFT", "LEFT", "CENTER"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
