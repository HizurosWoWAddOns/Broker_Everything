
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
if ns.build<70000000 then return end
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "ClassSpecs"
local ttName, ttColumns, tt, createMenu, createTalentMenu = name.."TT", 4;
local createTooltip


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=134942,coords={0.05,0.95,0.05,0.95}}; --IconName::ClassSpecs--


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
		showTalentsShort = false,
		showPvPTalents = true,
		showPvPTalentsShort = false,
		showPvPHonor = true,
		showPvPHonorOnBroker = true
	},
	config_allowed = nil,
	config_header = nil, -- use default header
	config_broker = {
		{ type="toggle", name="showPvPHonorOnBroker", label=L["Show PvP honor"], tooltip=L["Show PvP honor on broker button"]}
	},
	config_tooltip = {
		{ type="toggle", name="showTalents", label=L["Show talents"], tooltip=L["Show talents in tooltip"]},
		{ type="toggle", name="showTalentsShort", label=L["Show short talent list"], tooltip=L["Show short list of PvE talents in tooltip"]},
		{ type="toggle", name="showPvPTalents", label=L["Show PvP talents"], tooltip=L["Show PvP talents in tooltip"]},
		{ type="toggle", name="showPvPTalentsShort", label=L["Show short PvP talent list"], tooltip=L["Show short list of PvP talents in tooltip"]},
		{ type="toggle", name="showPvPHonor", label=L["Show PvP honor"], tooltip=L["Show PvP honor in tooltip"]},
	},
	config_misc = nil,
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
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

function createTalentMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	-- 1. pve talents
	-- 2. pvp talents
	-- 3. pet talents?
	ns.EasyMenu.ShowMenu(self);
end

local function infoTooltipShow(self)
	if self.infoTooltip then
		GameTooltip:SetOwner(tt,"ANCHOR_NONE");
		GameTooltip:SetPoint(ns.GetTipAnchor(tt,"horizontal"));
		if self.infoTooltip.type=="text" and #self.intoTooltip>0 then
			for i=1, #self.infoTooltip do
				GameTooltip:AddLine(unpack(self.infoTooltip[i]));
			end
		elseif self.infoTooltip.type=="spell" and self.infoTooltip.spellId then
			GameTooltip:SetHyperlink("spell:"..self.infoTooltip.spellId);
		elseif self.infoTooltip.type=="talent" and self.infoTooltip.args then
			GameTooltip:SetTalent(unpack(self.infoTooltip.args));
		elseif self.infoTooltip.type=="pvptalent" and self.infoTooltip.args then
			GameTooltip:SetPvpTalent(unpack(self.infoTooltip.args));
		end
		if self.infoTooltip.extraLine then
			GameTooltip:AddLine(self.infoTooltip.extraLine);
		end
		GameTooltip:Show();
	end
end

local function infoTooltipHide()
	GameTooltip:Hide();
end

local function setSpec(self)
	if not InCombatLockdown() then
		SetSpecialization(self.specIndex,self.specPet);
	end
end

local function setLootSpec(self)
	SetLootSpecialization(self.specId);
	C_Timer.After(.7,function() createTooltip(tt,true) end);
end

local function changeTalent(self)
	if self.talentId then
		LearnTalent(self.talentId);
	elseif self.pvpTalentId then
		LearnPvpTalent(self.pvpTalentId);
	end
end

function createTooltip(tt,update)
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
			tt.lines[l].cells[4].specId = spec[i].id;
			tt.lines[l].cells[4].infoTooltip = {{L["Click to change your loot specialization"]}};
			tt:SetCellScript(l,4,"OnMouseUp",setLootSpec);
			tt:SetCellScript(l,4,"OnEnter",infoTooltipShow);
			tt:SetCellScript(l,4,"OnLeave",infoTooltipHide);
		end
		if i~=active then
			tt.lines[l].specIndex = i;
			tt.lines[l].specPet = false;
			tt:SetLineScript(l,"OnMouseUp",setSpec);
		end
		tt.lines[l].infoTooltip = {{("|T%s:32:32|t %s"):format(spec[i].icon,spec[i].name)},{spec[i].desc,1,1,1,true}};
		tt:SetLineScript(l,"OnEnter",infoTooltipShow);
		tt:SetLineScript(l,"OnLeave",infoTooltipHide);
	end
	tt:AddSeparator(1,1,1,1,.6);
	local l=tt:AddLine();
	tt:SetCell(l,1,C("dkyellow",LOOT_SPECIALIZATION_DEFAULT:gsub(" %( %%s %)",":")),nil,"RIGHT",3);
	tt:SetCell(l,4,lootSpecID==0 and C("green",ACTIVE_PETS) or C( "gray", L["Set"]));
	if lootSpecID~=0 then
		tt.lines[l].specId = 0;
		tt.lines[l].cells[4].infoTooltip = {{L["Click to change your loot specialization"]}};
		tt:SetCellScript(l,4,"OnMouseUp",setLootSpec);
		tt:SetCellScript(l,4,"OnEnter",infoTooltipShow);
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
					tt.lines[l].specIndex = i;
					tt.lines[l].specPet = true;
					tt:SetLineScript(l,"OnMouseUp",setSpec);
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
		local Id, Name, Icon, Selected, Available, spellId, Unlocked,x,y,Known = 1,2,3,4,5,6,7,8,9,10;
		local tierLevels = CLASS_TALENT_LEVELS[ns.player.class] or CLASS_TALENT_LEVELS.DEFAULT
		local level = UnitLevel("player");
		for row=1, MAX_TALENT_TIERS do
			local selected, isUnlocked,x = false,false;
			local l=tt:AddLine(C("ltyellow",tierLevels[row]));
			for col=1, NUM_TALENT_COLUMNS do
				local tmp = {GetTalentInfo(row,col,talentGroup)};
				x=tmp;
				if ns.profile[name].showTalentsShort then
					if tmp[Selected]==true then
						selected = tmp;
						break;
					elseif tmp[Unlocked] then
						isUnlocked = tmp;
					end
				else
					local c,color = col+1,(tmp[Selected] and "ltyellow") or (level>=tierLevels[row] and "gray") or "dkred";
					tt:SetCell(l,c,str:format(tmp[Icon],C(color,tmp[Name])),nil,"LEFT");
					tt.lines[l].cells[c].infoTooltip = {
						type=level>=tierLevels[row] and "talent" or "spell",
						spellId=tmp[spellId],
						args={tmp[Id],false,talentGroup},
						extraLine=level<tierLevels[row] and C("red","Locked, level too low") or nil
					};
					tt:SetCellScript(l,c,"OnEnter",infoTooltipShow);
					tt:SetCellScript(l,c,"OnLeave",infoTooltipHide);
					if not tmp[Selected] and level>=tierLevels[row] then
						tt.lines[l].cells[c].talentId = tmp[Id];
						tt:SetCellScript(l,c,"OnMouseUp",changeTalent);
					end
				end
			end
			if ns.profile[name].showTalentsShort then
				if selected then
					tt:SetCell(l,2,str:format(selected[Icon],C("ltyellow",selected[Name])),nil,nil,2);
					tt.lines[l].infoTooltip = {type="talent",args={selected[Id],false,talentGroup}};
					tt:SetLineScript(l,"OnEnter",infoTooltipShow);
					tt:SetLineScript(l,"OnLeave",infoTooltipHide);
				elseif isUnlocked then
					tt:SetCell(l,2,C("orange","Unlocked, not selected"),nil,nil,2);
				else
					tt:SetCell(l,2,C("gray","Locked, level too low"),nil,nil,2);
				end
			end
		end
	end

	-- PVP Talents
	if ns.profile[name].showPvPTalents then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),2,C("ltblue",PVP_TALENTS),nil,"LEFT",0);
		tt:AddSeparator();
		local Id, Name, Icon, Selected, Available, spellId, Unlocked = 1,2,3,4,5,6,7;

		if UnitLevel("player") == MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_LEVEL_CURRENT] then
			for row=1, MAX_PVP_TALENT_TIERS do
				local selected,isUnlocked = false,false;
				local l=tt:AddLine(C("ltyellow",row));
				for col=1, MAX_PVP_TALENT_COLUMNS do 
					local tmp={GetPvpTalentInfo(row,col,talentGroup)};
					if ns.profile[name].showPvPTalentsShort then
						if tmp[Selected]==true then
							selected = tmp;
							break;
						elseif tmp[Unlocked] then
							isUnlocked = true;
						end
					else
						local c,color = col+1,(tmp[Selected] and "ltyellow") or (tmp[Unlocked] and "gray") or "dkred";
						tt:SetCell(l,c,str:format(tmp[Icon],C(color,tmp[Name])),nil,"LEFT");
						tt.lines[l].cells[c].infoTooltip = {type="pvptalent",args={tmp[Id],false,talentGroup}};
						tt:SetCellScript(l,c,"OnEnter",infoTooltipShow);
						tt:SetCellScript(l,c,"OnLeave",infoTooltipHide);
						if not tmp[Selected] and tmp[Unlocked] then
							tt.lines[l].cells[c].pvpTalentId = tmp[Id];
							tt:SetCellScript(l,c,"OnMouseUp",changeTalent);
						end
					end
				end
				if ns.profile[name].showPvPTalentsShort then
					if selected then
						tt:SetCell(l,2,str:format(selected[Icon],C("ltyellow",selected[Name])),nil,nil,2);
						tt.lines[l].infoTooltip = {type="pvptalent",args={selected[Id],false,talentGroup}};
						tt:SetLineScript(l,"OnEnter",infoTooltipShow);
						tt:SetLineScript(l,"OnLeave",infoTooltipHide);
					else
						if isUnlocked then
							tt:SetCell(l,2,C("orange","Unlocked, not selected"),nil,nil,2);
						else
							tt:SetCell(l,2,C("gray","Locked, level too low"),nil,nil,2);
						end
					end
				end
			end
		else
			tt:SetCell(tt:AddLine(),2,C("gray",L["PvP talents will be available on max level"]),nil,nil,0);
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltblue",L["Click"]).." || "..C("green",L["Activate specialization"]),nil,"LEFT",ttColumns);
		ns.clickOptions.ttAddHints(tt,name);
	end
	if not update then
		ns.roundupTooltip(tt);
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules[name].init = function() end

ns.modules[name].onevent = function(self,event,msg,...)
	if event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	else
		local specName = L["No Spec!"]
		local icon = I(name)
		local spec = GetSpecialization()
		local _ = nil
		local dataobj = self.obj or ns.LDB:GetDataObjectByName(ns.modules[name].ldbName)
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
	tt = ns.acquireTooltip({ttName, ttColumns, "RIGHT", "LEFT", "LEFT", "CENTER"},{false},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

