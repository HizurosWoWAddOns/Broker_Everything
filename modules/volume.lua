
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Volume" -- VOLUME
local ldbName,ttName,ttColumns,tt,createMenu,createTooltip = name,name.."TT",2;
local updateBrokerButton,getSoundHardware,setSoundHardware
local icon = "Interface\\AddOns\\"..addon.."\\media\\volume_"
local VIDEO_VOLUME_TITLE = L["Video Volume"];
local volume,cvars = {},{};
local vol = {
	{inset=0,locale="MASTER_VOLUME",			toggle="Sound_EnableAllSound",									percent="Sound_MasterVolume"},
	{inset=1,locale="ENABLE_SOUNDFX",			toggle="Sound_EnableSFX",						depend={1},		percent="Sound_SFXVolume"},
	{inset=2,locale="ENABLE_ERROR_SPEECH",		toggle="Sound_EnableErrorSpeech",				depend={1,2}	},
	{inset=2,locale="ENABLE_EMOTE_SOUNDS",		toggle="Sound_EnableEmoteSounds",				depend={1,2}	},
	{inset=2,locale="ENABLE_PET_SOUNDS",		toggle="Sound_EnablePetSounds",					depend={1,2}	},
	{inset=1,locale="MUSIC_VOLUME",				toggle="Sound_EnableMusic",						depend={1},		percent="Sound_MusicVolume"},
	{inset=2,locale="ENABLE_MUSIC_LOOPING",		toggle="Sound_ZoneMusicNoDelay",				depend={1,6}	},
	{inset=2,locale="ENABLE_PET_BATTLE_MUSIC",	toggle="Sound_EnablePetBattleMusic",			depend={1,6}	},
	{inset=1,locale="ENABLE_AMBIENCE",			toggle="Sound_EnableAmbience",					depend={1},		percent="Sound_AmbienceVolume"},
	{inset=1,locale="DIALOG_VOLUME",			toggle="Sound_EnableDialog",					depend={1},		percent="Sound_DialogVolume", hide=(select(4,GetBuildInfo())<60000)},
	{inset=1,locale="ENABLE_BGSOUND",			toggle="Sound_EnableSoundWhenGameIsInBG",		depend={1}		},
	{inset=1,locale="ENABLE_SOUND_AT_CHARACTER",toggle="Sound_ListenerAtCharacter",				depend={1}		},
	{inset=1,locale="ENABLE_REVERB",			toggle="Sound_EnableReverb",					depend={1}		},
	{inset=1,locale="ENABLE_SOFTWARE_HRTF",		toggle="Sound_EnablePositionalLowPassFilter",	depend={1}		},
	{inset=1,locale="ENABLE_DSP_EFFECTS",		toggle="Sound_EnableDSPEffects",				depend={1}		},
	--{inset=0,locale="VIDEO_VOLUME_TITLE",		toggle=false,									special="video"},
	{inset=0,locale="HARDWARE",					toggle=false,									special="hardware"},
}
for i=1,#vol do
	if vol[i].locale then
		cvars[vol[i].locale:lower()]=true;
	end
	if vol[i].toggle then
		cvars[vol[i].toggle:lower()]=true;
	end
	if vol[i].percent then
		cvars[vol[i].percent:lower()]=true;
	end
end


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name..'_0']    = {iconfile=icon.."0"}		--IconName::Volume_0--
I[name..'_33']   = {iconfile=icon.."33"}	--IconName::Volume_33--
I[name..'_66']   = {iconfile=icon.."66"}	--IconName::Volume_66--
I[name..'_100']  = {iconfile=icon.."100"}	--IconName::Volume_100--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show current volume and in tooltip all changeable audio options"],
	label = VOLUME,
	icon_suffix = "_100",
	events = {
		"PLAYER_ENTERING_WORLD",
		"CVAR_UPDATE",
		"SOUND_DEVICE_UPDATE"
	},
	updateinterval = nil, --5,
	config_defaults = {
		useWheel = false,
		steps = 10,
		listHardware = true
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=VOLUME, align="left", icon=I[name..'_100'] },
		{ type="separator" },
		{ type="toggle", name="useWheel", label=L["Use MouseWheel"], tooltip=L["Use the MouseWheel to change the volume"] },
		{ type="slider", name="steps", label=L["Change steps"], tooltip=L["Change the stepping width for volume changes with mousewheel and clicks."], min=1, max=100, default=10, format = "%d" },
		{ type="toggle", name="listHardware", label=L["List of hardware"], tooltip=L["Display in tooltip a list of your sound output hardware."] },
	},
	clickOptions = {
		["0_mute"] = {
			cfg_label = "Mute game sound", -- L["Mute game sound"]
			cfg_desc = "mute gane sound", -- L["mute game sound"]
			cfg_default = "_LEFT",
			hint = "Mute game sound",
			func = function(self,button)
				local _mod=name;
				BlizzardOptionsPanel_SetCVarSafe("Sound_EnableAllSound",BlizzardOptionsPanel_GetCVarSafe("Sound_EnableAllSound")==0 and 1 or 0);
				updateBroker();
				createTooltip(tt,true);
			end
		},
		["1_louder"] = {
			cfg_label = "Louder", -- L["Louder"]
			cfg_desc = "make volume louder", -- L["make volume louder"]
			cfg_default = "__NONE",
			hint = "Louder",
			func = function(self,button)
				local _mod=name;
				if volume.master==1 then return end
				volume.master = volume.master + (ns.profile[name].steps / 100);
				if volume.master>1 then volume.master=1 elseif volume.master<0 then volume.master=0; end
				BlizzardOptionsPanel_SetCVarSafe("Sound_MasterVolume",volume.master);
				updateBroker();
				createTooltip(tt,true);
			end
		},
		["2_quieter"] = {
			cfg_label = "Quieter", -- L["Quieter"]
			cfg_desc = "make volume quieter", -- L["make volume quieter"]
			cfg_default = "__NONE",
			hint = "Quieter",
			func = function(self,button)
				local _mod=name;
				if volume.master==0 then return end
				volume.master = volume.master - (ns.profile[name].steps / 100)
				if volume.master>1 then volume.master=1 elseif volume.master<0 then volume.master=0; end
				BlizzardOptionsPanel_SetCVarSafe("Sound_MasterVolume",volume.master);
				updateBroker();
				createTooltip(tt,true);
			end
		},
		["3_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self);
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

function updateBroker()
	volume.master = tonumber(("%.2f"):format(GetCVar("Sound_MasterVolume")))
	local obj = ns.LDB:GetDataObjectByName(ldbName);
	local suffix,color = "100","green"
	if volume.master < .1 then
		suffix,color = "0","gray"
	elseif volume.master < .3 then
		suffix = "33"
	elseif volume.master < .6 then
		suffix = "66"
	end

	obj.iconCoords = {0,1,0,1};
	obj.icon = "interface\\common\\VOICECHAT-MUTED";
	if GetCVar("Sound_EnableAllSound")=="1" then
		if volume.master>0 then
			local icon = I(name.."_"..(suffix or "100"));
			obj.iconCoords = icon.coords or {0,1,0,1};
			obj.icon = icon.iconfile;
		end
		obj.text = ceil(volume.master*100).."%";
	else
		obj.text = C("gray",ceil(volume.master*100).."%");
	end
end

do
	local cvar = "Sound_OutputDriverIndex"
	local hardware = {
		selected = tonumber(GetCVar(cvar))+1,
		list = {}
	}
	local hardware_selected = nil

	function getSoundHardware()
		if #hardware.list==0 then
			local num = Sound_GameSystem_GetNumOutputDrivers()
			for index=1, num do
				hardware.list[index] = Sound_GameSystem_GetOutputDriverNameByIndex(index-1)
			end
		end
		return hardware.list, hardware.num, hardware.selected
	end

	function setSoundHardware(self)
		if InCombatLockdown() then
			ns.print("("..VOLUME..")",C("orange",L["Sorry, In combat lockdown."]));
		else
			hardware.selected = self.hardwareIndex;
			SetCVar(cvar,tostring(self.hardwareIndex-1) or 0);
			AudioOptionsFrame_AudioRestart();
			createTooltip(tt,true);
		end
	end
end

local function updateTooltip()
	createTooltip(tt, true);
end

local function toggleEntry(self, button)
	ns.SetCVar(self.info.toggle,tostring(self.info.inv),self.info.toggle);
	updateBroker();
	createTooltip(tt,true);
end

local function percent(self,cvar,now,direction)
	if not (cvar and now) then return end
	if (direction==-1 and now==0) or (direction==1 and now==1) then return end
	local new = now + ((direction * ns.profile[name].steps) / 100);
	new = (new>1 and 1) or (new<0 and 0) or new;
	ns.SetCVar(cvar,new,cvar);
	createTooltip(tt,true);
	updateBroker();
end

local function volumeWheel(self,direction)
	percent(self,self.info.percent,self.info.pnow,direction);
end

local function volumeClick(self,_,button)
	local direction = button=="RightButton" and -1 or 1;
	percent(self,self.info.percent,self.info.pnow,direction);
end

function createTooltip(tt, update)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	local wheels,l,c={};
	tt:Clear()
	tt:AddHeader(C("dkyellow",VOLUME))
	tt:AddSeparator()

	for i,v in ipairs(vol) do
		local color,disabled

		if (v.hide) then
			-- do nothing
		elseif type(v.toggle)=="string" then
			l,c = tt:AddLine();
			v.now = tonumber(GetCVar(v.toggle)); vol[i].now=v.now;
			v.inv = v.now==1 and 0 or 1;
			if (v.toggle~="no-toggle") then

				if v.depend~=nil and ( (v.depend[1]~=nil and vol[v.depend[1]].now==0) or (v.depend[2]~=nil and vol[v.depend[2]].now==0) ) then
					color = v.now==1 and "gray" or "dkgray";
					disabled = color;
				end

				if color==nil then
					color = v.now==1 and "green" or "red";
					disabled = v.now==1 and "white" or "gray";
				end
				tt.lines[l].info = v;
				tt:SetLineScript(l,"OnMouseUp",toggleEntry);
			else
				if v.depend~=nil and ( (v.depend[1]~=nil and vol[v.depend[1]].now==0) or (v.depend[2]~=nil and vol[v.depend[2]].now==0) ) then
					color = "gray";
					disabled = color;
				else
					color = "dkyellow"
					disabled = "white";
				end
				tt:SetLineScript(l,"OnMouseUp",updateTooltip);
			end

			tt:SetCell(l,1,strrep(" ",3 * v.inset)..C(color,_G[v.locale]));

			if v.percent~=nil then
				v.pnow = tonumber(("%.2f"):format(GetCVar(v.percent)));

				tt.lines[l].info = v;
				tt.lines[l]:EnableMouseWheel(1)
				tt.lines[l]:SetScript("OnMouseWheel",volumeWheel);
				tinsert(wheels,l);

				tt:SetCell(l,ttColumns,C(disabled,ceil(v.pnow*100).."%"));

				tt.lines[l].cells[ttColumns].info = v;
				tt:SetCellScript(l,ttColumns,"OnMouseUp",volumeClick);
			else
				tt:SetCell(l,ttColumns,"           ");
			end
		elseif (v.special=="hardware") and (ns.profile[name].listHardware) then
			tt:AddSeparator(3,0,0,0,0);
			tt:AddHeader(C("dkyellow",_G[v.locale])..(InCombatLockdown() and C("orange"," (disabled in combat)") or ""));
			tt:AddSeparator();

			local lst,num,sel = getSoundHardware();

			for I,V in ipairs(lst) do
				local color = I==sel and "green" or "ltgray";

				local m = 30
				if strlen(V)>m then
					V = strsub(V,0,m-3).."...";
				end

				l,c = tt:AddLine(strrep(" ",3 * (v.inset+1))..C(color,V).." ")

				if not InCombatLockdown() then
					tt.lines[l].hardwareIndex = I;
					tt:SetLineScript(l,"OnMouseUp",setSoundHardware);
				end
			end
		elseif (v.special=="video") then
			tt:AddSeparator(3,0,0,0,0);
			tt:AddHeader(C("dkyellow",VIDEO_VOLUME_TITLE));
			tt:AddSeparator();
			-- master volumes
			tt:AddLine("   ".._G["MASTER_VOLUME"], "0%");
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(5,0,0,0,0)
		tt:AddLine(C("ltblue",L["Click"])..      " || "..C("green",L["On/Off"]));
		tt:AddLine(C("ltblue",L["Mousewheel"]).. " || "..C("green",L["Louder"].."/"..L["Quieter"]));
		ns.clickOptions.ttAddHints(tt,name);
	end

	if not update then
		ns.roundupTooltip(tt);
		tt.OnHide = function(self)
			if type(wheels)=="table" then
				for i=1, #wheels do
					if self.lines[wheels[i]] and self.lines[wheels[i]].EnableMouseWheel then
						self.lines[wheels[i]]:EnableMouseWheel(false);
						self.lines[wheels[i]]:SetScript("OnMouseWheel",nil);
					end
				end
			end
		end
	end
end

local function BlizzardOptionsPanel_SetCVarSafeHook(cvar)
	if cvars[cvar:lower()] then
		updateBroker();
	end
end

function BE_ToggleAllSound()
	ns.SetCVar(vol[1].toggle,GetCVar(vol[1].toggle)=="1" and 0 or 1,vol[1].locale);
	updateBroker();
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,arg1)
	if event=="PLAYER_ENTERING_WORLD" or event=="SOUND_DEVICE_UPDATE" or (event=="CVAR_UPDATE" and cvars[arg1:lower()]) then
		if not self.hooked then
			hooksecurefunc("BlizzardOptionsPanel_SetCVarSafe",BlizzardOptionsPanel_SetCVarSafeHook);
			self.hooked = true;
		end
		updateBroker();
	elseif event=="BE_UPDATE_CLICKOPTIONS" then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	end
end

-- ns.modules[name].optionspanel = function(panel) end

ns.modules[name].onmousewheel = function(self,direction)
	if not ns.profile[name].useWheel then return end
	if (direction==-1 and volume.master == 0) or (direction==1 and volume.master == 1) then return end

	volume.master = volume.master + (direction * ns.profile[name].steps / 100)
	if volume.master > 1 then
		volume.master = 1
	elseif volume.master < 0 then
		volume.master = 0
	end
	local cvar = "Sound_MasterVolume"
	ns.SetCVar(cvar,volume.master,cvar)
	updateBroker();
	if tt and tt.key==ttName and tt:IsShown() then
		createTooltip(tt,true);
	end
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	if not self.mousewheelOn then
		self:EnableMouseWheel(1);
		self.mousewheelOn = true;
	end

	tt = ns.acquireTooltip({ttName, 2, "LEFT", "RIGHT"},{false},{self})
	ns.RegisterMouseWheel(self,ns.modules[name].onmousewheel)
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

