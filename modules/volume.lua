
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
local _G = _G


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Volume" -- L["Volume"]
local ldbName = name
local tt,createMenu,updateBrokerButton
local ttName = name.."TT"
local ttColumns = 2
local icon = "Interface\\AddOns\\"..addon.."\\media\\volume_"
local VIDEO_VOLUME_TITLE = L["Video Volume"];
local getSoundHardware,setSoundHardware
local volume = {}
local vol = {
	{inset=0,locale="MASTER_VOLUME",			toggle="Sound_EnableAllSound",								percent="Sound_MasterVolume"},
	{inset=1,locale="ENABLE_SOUNDFX",			toggle="Sound_EnableSFX",					depend={1},		percent="Sound_SFXVolume"},
	{inset=2,locale="ENABLE_ERROR_SPEECH",		toggle="Sound_EnableErrorSpeech",			depend={1,2}	},
	{inset=2,locale="ENABLE_EMOTE_SOUNDS",		toggle="Sound_EnableEmoteSounds",			depend={1,2}	},
	{inset=2,locale="ENABLE_PET_SOUNDS",		toggle="Sound_EnablePetSounds",				depend={1,2}	},
	{inset=1,locale="MUSIC_VOLUME",				toggle="Sound_EnableMusic",					depend={1},		percent="Sound_MusicVolume"},
	{inset=2,locale="ENABLE_MUSIC_LOOPING",		toggle="Sound_ZoneMusicNoDelay",			depend={1,6}	},
	{inset=2,locale="ENABLE_PET_BATTLE_MUSIC",	toggle="Sound_EnablePetBattleMusic",		depend={1,6}	},
	{inset=1,locale="ENABLE_AMBIENCE",			toggle="Sound_EnableAmbience",				depend={1},		percent="Sound_AmbienceVolume"},
	{inset=1,locale="DIALOG_VOLUME",			toggle="Sound_EnableDialog",				depend={1},		percent="Sound_DialogVolume", hide=(select(4,GetBuildInfo())<60000)},
	{inset=1,locale="ENABLE_BGSOUND",			toggle="Sound_EnableSoundWhenGameIsInBG",	depend={1}		},
	{inset=1,locale="ENABLE_SOUND_AT_CHARACTER",toggle="Sound_ListenerAtCharacter",			depend={1}		},
	{inset=1,locale="ENABLE_REVERB",			toggle="Sound_EnableReverb",				depend={1}		},
	{inset=1,locale="ENABLE_SOFTWARE_HRTF",		toggle="Sound_EnableSoftwareHRTF",			depend={1}		},
	{inset=1,locale="ENABLE_DSP_EFFECTS",		toggle="Sound_EnableDSPEffects",			depend={1}		},
	--{inset=0,locale="VIDEO_VOLUME_TITLE",		toggle=false,								special="video"},
	{inset=0,locale="HARDWARE",					toggle=false,								special="hardware"},
}


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
local desc = L["Change Volumes and toggle some audio options."]
ns.modules[name] = {
	desc = desc,
	icon_suffix = "_100",
	events = {
		"ADDON_LOADED"
	},
	updateinterval = 5,
	config_defaults = {
		useWheel = false,
		steps = 10,
		listHardware = true
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name..'_100'] },
		{ type="separator" },
		{ type="toggle", name="useWheel", label=L["Use MouseWheel"], tooltip=L["Use the MouseWheel to change the volume"] },
		{ type="slider", name="steps", label=L["Change steps"], tooltip=L["Change the stepping width for volume changes with mousewheel and clicks."], min=1, max=100, default=10, format = "%d" },
		{ type="toggle", name="listHardware", label=L["List of hardware"], tooltip=L["Display in tooltip a list of your sound output hardware."] },
	},
	clickOptions = {
		["1_louder"] = {
			cfg_label = "Louter",
			cfg_desc = "make volume louter",
			cfg_default = "_LEFT",
			hint = "Louder",
			func = function(self,button)
				local _mod=name;
				if volume.master == 1 then return end
				volume.master = volume.master + (Broker_EverythingDB[name].steps / 100)
				if volume.master > 1 then volume.master = 1 elseif volume.master < 0 then volume.master = 0 end
				BlizzardOptionsPanel_SetCVarSafe("Sound_MasterVolume",volume.master)
				updateBrokerButton(self)
			end
		},
		["2_quieter"] = {
			cfg_label = "Quieter",
			cfg_desc = "make volume quieter",
			cfg_default = "_RIGHT",
			hint = "Quieter",
			func = function(self,button)
				local _mod=name;
				if volume.master == 0 then return end
				volume.master = volume.master - (Broker_EverythingDB[name].steps / 100)
				if volume.master > 1 then volume.master = 1 elseif volume.master < 0 then volume.master = 0 end
				BlizzardOptionsPanel_SetCVarSafe("Sound_MasterVolume",volume.master)
				updateBrokerButton(self)
			end
		},
		["3_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "__NONE",
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
	if (tt~=nil) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

function updateBrokerButton()
	volume.master = tonumber(GetCVar("Sound_MasterVolume"))
	local obj = ns.LDB:GetDataObjectByName(ldbName);
	local suffix,color = "100","green"
	if volume.master < .1 then
		suffix,color = "0","gray"
	elseif volume.master < .3 then
		suffix = "33"
	elseif volume.master < .6 then
		suffix = "66"
	end
	local icon = I(name.."_"..(suffix or "100"))
	obj.iconCoords = icon.coords or {0,1,0,1}
	obj.icon = icon.iconfile
	if GetCVar("Sound_EnableAllSound")=="1" then
		obj.text = ceil(volume.master*100).."%";
	else
		obj.text = C("gray",ceil(volume.master*100).."%");
	end
end

local function volTooltip(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...
	local l,c
	tt:Clear()
	tt:AddHeader(C("dkyellow",L[name]))
	tt:AddSeparator()

	local function percent(self,cvar,now,direction)
		if (direction==-1 and now==0) or (direction==1 and now==1) then return end
		local new = now + ((direction * Broker_EverythingDB[name].steps) / 100)
		new = (new>1 and 1) or (new<0 and 0) or new
		ns.SetCVar(cvar,new,cvar)
		volTooltip(tt)
		updateBrokerButton(self)
	end

	for i,v in ipairs(vol) do
		local color,disabled

		if (v.hide) then
			-- do nothing
		elseif type(v.toggle)=="string" then
			l,c = tt:AddLine()
			v.now = tonumber(GetCVar(v.toggle)) vol[i].now=v.now
			v.inv = v.now==1 and 0 or 1
			if (v.toggle~="no-toggle") then

				if v.depend~=nil and ( (v.depend[1]~=nil and vol[v.depend[1]].now==0) or (v.depend[2]~=nil and vol[v.depend[2]].now==0) ) then
					color = v.now==1 and "gray" or "dkgray"
					disabled = color
				end

				if color==nil then
					color = v.now==1 and "green" or "red"
					disabled = v.now==1 and "white" or "gray"
				end

				tt:SetLineScript(l,"OnMouseUp",function(self, button)
					ns.SetCVar(v.toggle,tostring(v.inv),v.toggle);
					updateBrokerButton();
					volTooltip(tt);
				end);
			else
				if v.depend~=nil and ( (v.depend[1]~=nil and vol[v.depend[1]].now==0) or (v.depend[2]~=nil and vol[v.depend[2]].now==0) ) then
					color = "gray";
					disabled = color;
				else
					color = "dkyellow"
					disabled = "white";
				end
				tt:SetLineScript(l,"OnMouseUp",function(self, button) volTooltip(tt) end);
			end

			tt:SetCell(l,1,strrep(" ",3 * v.inset)..C(color,_G[v.locale]));

			if v.percent~=nil then
				v.pnow = tonumber(GetCVar(v.percent))

				tt.lines[l]:EnableMouseWheel(1)
				tt.lines[l]:SetScript("OnMouseWheel",function(self,direction)
					percent(self,v.percent,v.pnow,direction)
				end)

				tt:SetCell(l,ttColumns,C(disabled,ceil(v.pnow*100).."%"))
				tt:SetCellScript(l,ttColumns,"OnMouseUp",function(self,button) end)
				tt.lines[l].cells[ttColumns]:SetScript("OnMouseUp",function(self,button)
					local direction = button=="RightButton" and -1 or 1
					percent(self,v.percent,v.pnow,direction)
				end)
			else
				tt:SetCell(l,ttColumns,"           ")
			end
		elseif (v.special=="hardware") and (Broker_EverythingDB[name].listHardware) then
			tt:AddSeparator(3,0,0,0,0)
			tt:AddHeader(C("dkyellow",_G[v.locale])..(InCombatLockdown() and C("orange"," (disabled in combat)") or ""))
			tt:AddSeparator()

			local lst,num,sel = getSoundHardware()

			for I,V in ipairs(lst) do
				local color = I==sel and "green" or "ltgray"

				local m = 30
				if strlen(V)>m then
					V = strsub(V,0,m-3).."..."
				end

				l,c = tt:AddLine(strrep(" ",3 * (v.inset+1))..C(color,V).." ")

				if not InCombatLockdown() then
					tt:SetLineScript(l,"OnMouseUp",function(self,button)
						if InCombatLockdown() then
							ns.print("("..L[name]..")",L["Sorry, In combat lockdown."])
						else
							setSoundHardware(I)
							volTooltip(tt)
							AudioOptionsFrame_AudioRestart()
						end
					end)
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

	if Broker_EverythingDB.showHints then
		tt:AddSeparator(5,0,0,0,0)
		tt:AddLine(C("ltblue",L["Click"])..      " || "..C("green",L["On/Off"]));
		tt:AddLine(C("ltblue",L["Mousewheel"]).. " || "..C("green",L["Louder"].."/"..L["Quieter"]));
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
end

do
	local cvar = "Sound_OutputDriverIndex"
	local hardware = {
		selected = tonumber(GetCVar(cvar))+1,
		list = {}
	}
	local hardware_selected = nil

	getSoundHardware = function()
		if #hardware.list==0 then
			local num = Sound_GameSystem_GetNumOutputDrivers()
			for index=1, num do
				hardware.list[index] = Sound_GameSystem_GetOutputDriverNameByIndex(index-1)
			end
		end
		return hardware.list, hardware.num, hardware.selected
	end

	setSoundHardware = function(value)
		hardware.selected = value
		SetCVar(cvar,tostring(value-1) or 0)
	end
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(self)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
	if self then
		updateBrokerButton(self)
	end
end

ns.modules[name].onevent = function(self,event,msg)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],Broker_EverythingDB[name]);
	end
end

ns.modules[name].onupdate = function(self)
	updateBrokerButton(self)
end

-- ns.modules[name].optionspanel = function(panel) end

ns.modules[name].onmousewheel = function(self,direction)
	if not Broker_EverythingDB[name].useWheel then return end
	if (direction==-1 and volume.master == 0) or (direction==1 and volume.master == 1) then return end

	volume.master = volume.master + (direction * Broker_EverythingDB[name].steps / 100)
	if volume.master > 1 then
		volume.master = 1
	elseif volume.master < 0 then
		volume.master = 0
	end
	local cvar = "Sound_MasterVolume"
	ns.SetCVar(cvar,volume.master,cvar)
	--BlizzardOptionsPanel_SetCVarSafe("Sound_MasterVolume",volume.master)
	updateBrokerButton(self)
end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	tt = ns.LQT:Acquire(ttName, 2, "LEFT", "RIGHT")
	volTooltip(tt)
	ns.createTooltip(self,tt)
	ns.RegisterMouseWheel(self,ns.modules[name].onmousewheel)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,false,true); end
end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

