
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
local ldbName, ttName, ttColumns, tt, createMenu, createTalentMenu = name, name.."TT", 3;


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

local function createTooltip(self, tt)
	if (not tt.key) or (tt.key~=ttName) then return; end -- don't override other LibQTip tooltips...
	tt:Clear()

	tt:SetCell(tt:AddLine(),1,C("dkyellow",SPECIALIZATION.." & "..TALENTS),tt:GetHeaderFont(),"LEFT",ttColumns);

	local active = GetSpecialization();
	local activeName,activeIcon
	local num = GetNumSpecializations();
	local iconStr,str = "|T%s:0|t","|T%s:0|t %s";

	local l=tt:AddLine();
	tt:SetCell(l,1,C("ltblue",SPECIALIZATION),nil,"LEFT",2);
	tt:SetCell(l,3,C("ltblue",ROLE));

	tt:AddSeparator();
	for i=1, num do
		local specId, specName, _, icon, _, specRole, specPrimStat = GetSpecializationInfo(i);
		if i==active then activeName,activeIcon = specName,icon; end
		local l=tt:AddLine(
			iconStr:format(icon),
			C(ns.player.class,specName) .. (i==active and C("green","("..ACTIVE_PETS..")") or ""),
			C( (specRole=="TANK" and "ltblue") or (specRole=="HEALER" and "ltgreen") or "ltred", _G[specRole] )
		);
		tt:SetLineScript(l,"OnMouseUp",function(_self)
			if not InCombatLockdown() then
				SetSpecialization(i);
			end
		end);
		--[[
		tt:SetCellScript(l,4,"OnEnter",function(_self)
			GameTooltip:SetOwner(tt,"ANCHOR_NONE");
			GameTooltip:SetPoint(ns.GetTipAnchor(tt));
			GameTooltip:SetHyperlink(spellLink);
			GameTooltip:Show();
		end);
		tt:SetCellScript(l,4,"OnLeave",function(_self)
			GameTooltip:Hide();
		end);
		--]]
	end 

	if ns.player.class:lower()=="hunter" then
		-- pet spec
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
					local points=ns.GetTipAnchor(tt,"horizontal");
					for i=1, #points do
						GameTooltip:SetPoint(unpack(points[i]));
					end
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
		local l=tt:AddLine(C("ltblue",PVP.." "..LEVEL_ABBR));
		tt:SetCell(l,2,C("ltblue",PVP_TALENTS),nil,nil,2);
		tt:AddSeparator();

		local tierLevels = {1,2,4,6,8,10};
		local Id, Name, Icon, Selected, Available, spellId, Unlocked = 1,2,3,4,5,6,7;
		for row=1, MAX_PVP_TALENT_TIERS do
			local selected,isUnlocked = false,false;
			local l=tt:AddLine(C("ltyellow",tierLevels[row]));
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
					GameTooltip:SetPoint(ns.GetTipAnchor(tt));
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
ns.modules[name].init = function(obj)
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	if event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	else
		local specName = L["No Spec!"]
		local icon = I(name)
		local spec = GetSpecialization()
		local _ = nil
		local dataobj = self.obj or ns.LDB:GetDataObjectByName(ldbName)
		unspent = {GetNumUnspentTalents()>0 or GetNumUnspentPvpTalents()>0,GetNumUnspentTalents(),GetNumUnspentPvpTalents()};

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

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.LQT:Acquire(ttName, ttColumns, "RIGHT", "LEFT", "LEFT", "LEFT")
	createTooltip(self, tt);
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

-- ns.modules[name].onclick = function(self,button) end

-- ns.modules[name].ondblclick = function(self,button) end

