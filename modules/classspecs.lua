
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.build<70000000 then return end


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "ClassSpecs" -- L["ClassSpecs"]
local ldbName, ttName, ttColumns, tt, createMenu, createTalentMenu = name, name.."TT", 4;


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=GetItemIcon(7516),coords={0.05,0.95,0.05,0.95}}; --IconName::ClassSpecs--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show and switch your character specializations"],
	events = {
		"PLAYER_LOGIN",
		"ACTIVE_TALENT_GROUP_CHANGED",
		"PLAYER_ENTERING_WORLD",
		"SKILL_LINES_CHANGED",
		"CHARACTER_POINTS_CHANGED",
		"PLAYER_TALENT_UPDATE",
		"PLAYER_SPECIALIZATION_CHANGED",
		"CHAT_MSG_SYSTEM" -- for loot spec changes -.-
	},
	updateinterval = nil, -- 10
	config_defaults = {
		showTalents = true,
		showPvPTalents = true
	},
	config_allowed = nil,
	config = {
		{ type="header", label=L[name], align="left", icon=true },
		{ type="separator" },
		{ type="toggle", name="showTalents", label=L["Show talents"], tooltip=L["Show talents in tooltip"]},
		{ type="toggle", name="showPvPTalents", label=L["Show PvP talents"], tooltip=L["Show PvP talents in tooltip"]}
	},
	clickOptions = {
		["1_open_specialization"] = {
			cfg_label = "Open specialization", -- L["Open specialization"]
			cfg_desc = "open specialization", -- L["open specialization"]
			cfg_default = "_LEFT",
			hint = "Open specialization", -- L["Open specialization"]
			func = function(self,button)
				local _mod,doSelect=name,false;
				securecall("ToggleTalentFrame",SPECIALIZATION_TAB);
			end
		},
		["2_open_talents"] = {
			cfg_label = "Open talents", -- L["Open talents"]
			cfg_desc = "open talents", -- L["open talents"]
			cfg_default = "__NONE",
			hint = "Open talents", -- L["Open talents"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleTalentFrame",TALENTS_TAB);
			end
		},
		["3_open_pvp_talents"] = {
			cfg_label = "Open pvp talents", -- L["Open pvp talents"]
			cfg_desc = "open pvp talents", -- L["open pvp talents"]
			cfg_default = "__NONE",
			hint = "Open pvp talents", -- L["Open pvp talents"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleTalentFrame",PVP_TALENTS_TAB);
			end
		},
		["4_open_pet_specialization"] = {
			cfg_label = "Open pet specialization", -- L["Open pet specialization"]
			cfg_desc = "open pet specialization", -- L["open pet specialization"]
			cfg_default = "__NONE",
			hint = "Open pet specialization", -- L["Open pet specialization"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleTalentFrame",ns.player.class:upper()=="HUNTER" and PET_SPECIALIZATION_TAB or SPECIALIZATION_TAB);
			end
		},
		--[[
		["5_open_talent_menu"] = {
			cfg_label = "Open talents menu", -- L["Open talents menu"]
			cfg_desc = "open talents menu", -- L["open talents menu"]
			cfg_default = "__NONE",
			hint = "Open talents menu", -- L["Open talents menu"]
			func = function(self,button)
				local _mod=name;
				createTalentMenu(self);
			end
		},
		--]]
		["6_open_menu"] = {
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

function createTalentMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	-- 1. pve talents
	-- 2. pvp talents
	-- 3. pet talents?
	ns.EasyMenu.ShowMenu(self);
end

local function createSecTooltip(...)
	if select('#',...)==0 then return end
	GameTooltip:SetOwner(tt,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(tt,"horizontal"));
	for i,v in ipairs({...}) do
		GameTooltip:AddLine(unpack(v));
	end
	GameTooltip:Show();
end

local function createTooltip(self, tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	tt:Clear()
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
		spec[i].id, spec[i].name, spec[i].desc, spec[i].icon, _, spec[i].role = GetSpecializationInfo(i);
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
			tt:SetCellScript(l,4,"OnMouseUp",function()
				SetLootSpecialization(spec[i].id);
				C_Timer.After(.7,function() createTooltip(false, tt) end);
			end);
			tt:SetCellScript(l,4,"OnEnter",function(self) createSecTooltip({L["Click to change your loot specialization"]}); end);
			tt:SetCellScript(l,4,"OnLeave",function() GameTooltip:Hide(); end);
		end
		if i~=active then
			tt:SetLineScript(l,"OnMouseUp",function()
				if not InCombatLockdown() then
					SetSpecialization(i);
				end
			end);
		end
		tt:SetLineScript(l,"OnEnter",function() createSecTooltip({("|T%s:32:32|t %s"):format(spec[i].icon,spec[i].name)},{spec[i].desc,1,1,1,true}); end);
		tt:SetLineScript(l,"OnLeave",function() GameTooltip:Hide(); end);
	end

	local l=tt:AddLine();
	tt:SetCell(l,1,C("dkyellow",LOOT_SPECIALIZATION_DEFAULT:gsub(" %( %%s %)",":")),nil,"RIGHT",3);
	tt:SetCell(l,4,lootSpecID==0 and C("green",ACTIVE_PETS) or C( "gray", L["Set"]));
	if lootSpecID~=0 then
		tt:SetCellScript(l,4,"OnMouseUp",function()
			SetLootSpecialization(0);
			C_Timer.After(.7,function() createTooltip(false, tt) end);
		end);
		tt:SetCellScript(l,4,"OnEnter",function() createSecTooltip({L["Click to change your loot specialization"]}); end);
		tt:SetCellScript(l,4,"OnLeave",function() GameTooltip:Hide(); end);
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
				spec[i].id, spec[i].name, spec[i].desc, spec[i].icon, _, spec[i].role = GetSpecializationInfo(i,nil,true);
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
					tt:SetLineScript(l,"OnMouseUp",function(_self)
						if not InCombatLockdown() then
							SetSpecialization(i,true);
						end
					end);
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

		local tierLevels = CLASS_TALENT_LEVELS[ns.player.class] or CLASS_TALENT_LEVELS.DEFAULT
		for row=1, MAX_TALENT_TIERS do
			local tierAvailable, selectedTalent = GetTalentTierInfo(row,talentGroup);
			local l=tt:AddLine(C("ltyellow",tierLevels[row]));
			if not tierAvailable then
				tt:SetCell(l,2,C("gray","Locked, level too low"),nil,nil,2);
			elseif selectedTalent==0 then
				tt:SetCell(l,2,C("orange","Unlocked, not selected"),nil,nil,2);
			else
				local talentID, Name, iconTexture, Selected, Available, spellId, u1, u2, u3, u4 = GetTalentInfo(row, selectedTalent, talentGroup);
				tt:SetCell(l,2,str:format(iconTexture,C("ltyellow",Name)),nil,nil,2);
				tt:SetLineScript(l,"OnEnter",function(_self)
					GameTooltip:SetOwner(tt,"ANCHOR_NONE");
					GameTooltip:SetPoint(ns.GetTipAnchor(tt,"horizontal"));
					GameTooltip:SetHyperlink("spell:"..spellId);
					GameTooltip:Show();
				end);
				tt:SetLineScript(l,"OnLeave",function() GameTooltip:ClearLines(); GameTooltip:Hide(); end);
			end
		end
	end

	-- PVP Talents
	if ns.profile[name].showPvPTalents then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),2,C("ltblue",PVP_TALENTS),nil,"LEFT",0);
		tt:AddSeparator();

		local Id, Name, Icon, Selected, Available, spellId, Unlocked = 1,2,3,4,5,6,7;
		for row=1, MAX_PVP_TALENT_TIERS do
			local selected,isUnlocked = false,false;
			local l=tt:AddLine(C("ltyellow",row));
			if UnitLevel("player") == MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_LEVEL_CURRENT] then
				for col=1, MAX_PVP_TALENT_COLUMNS do 
					local tmp={GetPvpTalentInfo(row, col, talentGroup)};
					if tmp[Selected]==true then
						selected = tmp;
						break;
					elseif tmp[Unlocked] then
						isUnlocked = true;
					end
				end
			end
			if selected then
				tt:SetCell(l,2,str:format(selected[Icon],C("ltyellow",selected[Name])),nil,nil,2);
				tt:SetLineScript(l,"OnEnter",function(_self)
					GameTooltip:SetOwner(tt,"ANCHOR_NONE");
					GameTooltip:SetPoint(ns.GetTipAnchor(tt,"horizontal"));
					GameTooltip:SetHyperlink("spell:"..selected[spellId]);
					GameTooltip:Show();
				end);
				tt:SetLineScript(l,"OnLeave",function()
					GameTooltip:ClearLines();
					GameTooltip:Hide();
				end);
			else
				if isUnlocked then
					tt:SetCell(l,2,C("orange","Unlocked, not selected"),nil,nil,2);
				else
					tt:SetCell(l,2,C("gray","Locked, level too low"),nil,nil,2);
				end
			end
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltblue",L["Click"]).." || "..C("green",L["Activate specialization"]),nil,"LEFT",ttColumns);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
	ns.roundupTooltip(self,tt);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg,...)
	if event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	else
		local specName = L["No Spec!"]
		local icon = I(name)
		local spec = GetSpecialization()
		local _ = nil
		local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName)
		local unspent = {GetNumUnspentTalents()>0 or GetNumUnspentPvpTalents()>0,GetNumUnspentTalents(),GetNumUnspentPvpTalents()};

		if spec ~= nil then
			 _, specName, _, icon.iconfile, _, _ = GetSpecializationInfo(spec)
		end

		dataobj.iconCoords = icon.coords
		dataobj.icon = icon.iconfile

		if unspent[1] then
			local lst = {};
			if unspent[2]>0 then
				tinsert(lst,unspent[2].." "..L["PvE"]);
			end
			if unspent[3]>0 then
				tinsert(lst,unspent[3].." "..L["PvP"]);
			end
			dataobj.text = C("ltred",L["Unspent talents"]..": ".. table.concat(lst,", "));
		else
			dataobj.text = specName
		end
	end
end

-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip(ttName, ttColumns, "RIGHT", "LEFT", "LEFT", "CENTER")
	createTooltip(self, tt);
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

-- ns.modules[name].onclick = function(self,button) end

-- ns.modules[name].ondblclick = function(self,button) end

