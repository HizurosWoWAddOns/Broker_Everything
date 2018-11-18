
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Volume" -- VOLUME L["ModDesc-Volume"]
local ttName,ttColumns,tt,module,createTooltip = name.."TT",2;
local updateBrokerButton,getSoundHardware,setSoundHardware
local icon = "Interface\\AddOns\\"..addon.."\\media\\volume_"
local VIDEO_VOLUME_TITLE = L["Video Volume"];
local volume,cvars,updateBroker,vol = {},{};

if not ENABLE_DSP_EFFECTS then
	if LOCALE_deDE then
		L.ENABLE_DSP_EFFECTS = "Todesritterstimmen"
	elseif LOCALE_esES or LOCALE_esMX then
		L.ENABLE_DSP_EFFECTS = "Voces caballeros de la M."
	elseif LOCALE_frFR then
		L.ENABLE_DSP_EFFECTS = "Voix ch. de la mort"
	elseif LOCALE_itIT then
		L.ENABLE_DSP_EFFECTS = "Voci Cavalieri della Morte"
	elseif LOCALE_koKR then
		L.ENABLE_DSP_EFFECTS = "죽음의 기사 음성"
	elseif LOCALE_ptBR or LOCALE_ptPT then
		L.ENABLE_DSP_EFFECTS = "Vozes de CdM"
	elseif LOCALE_ruRU then
		L.ENABLE_DSP_EFFECTS = "Голоса рыцарей смерти"
	elseif LOCALE_zhCN then
		L.ENABLE_DSP_EFFECTS = "死亡骑士语音"
	elseif LOCALE_zhTW then
		L.ENABLE_DSP_EFFECTS = "死亡騎士語音"
	else
		L.ENABLE_DSP_EFFECTS = "Death Knight Voices"
	end
end

-- register icon names and default files --
-------------------------------------------
I[name..'_0']    = {iconfile=icon.."0"}		--IconName::Volume_0--
I[name..'_33']   = {iconfile=icon.."33"}	--IconName::Volume_33--
I[name..'_66']   = {iconfile=icon.."66"}	--IconName::Volume_66--
I[name..'_100']  = {iconfile=icon.."100"}	--IconName::Volume_100--


-- some local functions --
--------------------------
function updateBroker()
	volume.master = tonumber(("%.2f"):format(GetCVar("Sound_MasterVolume")))
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
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

	function setSoundHardware(self,hardwareIndex,button)
		if InCombatLockdown() then
			ns.print("("..VOLUME..")",C("orange",L["Sorry, In combat lockdown."]));
		else
			hardware.selected = hardwareIndex;
			SetCVar(cvar,tostring(hardwareIndex-1) or 0);
			AudioOptionsFrame_AudioRestart();
			createTooltip(tt,true);
		end
	end
end

local function updateTooltip()
	createTooltip(tt, true);
end

local function toggleEntry(self, info, button)
	ns.SetCVar(info.toggle,tostring(info.inv),info.toggle);
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

local function volumeClick(self,data,button)
	percent(self,data.percent,data.pnow,button=="RightButton" and -1 or 1);
end

function createTooltip(tt, update)
	if (tt) and (tt.Clear) and (tt.key) and (tt.key~=ttName) and (tt.lines~=nil) and (tt.columns~=nil) then return end -- don't override other LibQTip tooltips...
	local wheels,l,c={};

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",VOLUME))
	tt:AddSeparator()

	for i,v in ipairs(vol) do
		local color,disabled

		local label = _G[v.locale];
		if not label then
			label = L[v.locale];
		end

		if (v.hide) or not label then
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
				tt:SetLineScript(l,"OnMouseUp",toggleEntry,v);
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

			tt:SetCell(l,1,strrep(" ",3 * v.inset)..C(color,label));

			if v.percent~=nil then
				v.pnow = tonumber(("%.2f"):format(GetCVar(v.percent)));

				tt.lines[l].info = v;
				tt.lines[l]:EnableMouseWheel(1)
				tt.lines[l]:SetScript("OnMouseWheel",volumeWheel);
				tinsert(wheels,l);

				tt:SetCell(l,ttColumns,C(disabled,ceil(v.pnow*100).."%"));

				tt:SetCellScript(l,ttColumns,"OnMouseUp",volumeClick,v);
			else
				tt:SetCell(l,ttColumns,"           ");
			end
		elseif (v.special=="hardware") and (ns.profile[name].listHardware) then
			tt:AddSeparator(3,0,0,0,0);
			tt:AddHeader(C("dkyellow",label)..(InCombatLockdown() and C("orange"," (disabled in combat)") or ""));
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
					tt:SetLineScript(l,"OnMouseUp",setSoundHardware,I);
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
		tt:AddLine(C("ltblue",L["MouseBtn"])..      " || "..C("green",L["On/Off"]));
		tt:AddLine(C("ltblue",L["Mousewheel"]).. " || "..C("green",L["Louder"].."/"..L["Quieter"]));
		ns.ClickOpts.ttAddHints(tt,name);
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


-- module variables for registration --
---------------------------------------
module = {
	icon_suffix = "_100",
	events = {
		"PLAYER_LOGIN",
		"CVAR_UPDATE",
		"SOUND_DEVICE_UPDATE"
	},
	config_defaults = {
		enabled = true,
		useWheel = false,
		steps = 10,
		listHardware = true
	},
	clickOptionsRename = {
		["mute"] = "0_mute",
		["louder"] = "1_louder",
		["quieter"] = "2_quieter",
		["menu"] = "3_open_menu"
	},
	clickOptions = {
		["mute"] = {"Mute game sound","module","mute"}, -- L["Mute game sound"]
		["louder"] = {"Louder","module","volumeAdjust"}, -- L["Louder"]
		["quieter"] = {"Quieter","module","volumeAdjust"}, -- L["Quieter"]
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	mute = "_LEFT",
	louder = "__NONE",
	quieter = "__NONE",
	menu = "_RIGHT"
});

function module.volumeAdjust(self,button,modName,action)
	local cap,new = volume.master,0;
	if action=="louder" then
		cap,new = 1,volume.master + (ns.profile[name].steps / 100);
		if new > cap then new=1; end
	elseif action=="quieter" then
		cap,new = 0,volume.master-(ns.profile[name].steps / 100);
		if new < cap then new=0; end
	end
	if volume.master==cap then return; end
	volume.master = new;
	BlizzardOptionsPanel_SetCVarSafe("Sound_MasterVolume",volume.master);
	updateBroker();
	createTooltip(tt,true);
end

function module.mute()
	BlizzardOptionsPanel_SetCVarSafe("Sound_EnableAllSound",BlizzardOptionsPanel_GetCVarSafe("Sound_EnableAllSound")==0 and 1 or 0);
	updateBroker();
	createTooltip(tt,true);
end

function module.options()
	return {
		broker = nil,
		tooltip = {
			listHardware={ type="toggle", name=L["List of hardware"], desc=L["Display in tooltip a list of your sound output hardware."] },
		},
		misc = {
			useWheel={ type="toggle", name=L["Use MouseWheel"], desc=L["Use the MouseWheel to change the volume"] },
			steps={ type="range", name=L["Change steps"], desc=L["Change the stepping width for volume changes with mousewheel and clicks."], min=1, max=100, step=1 },
		},
	}
end

function module.init()
	vol = {
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
end

function module.onevent(self,event,arg1)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="BE_UPDATE_CFG" or event=="PLAYER_LOGIN" or event=="SOUND_DEVICE_UPDATE" or (event=="CVAR_UPDATE" and cvars[arg1:lower()]) then
		if not self.hooked then
			hooksecurefunc("BlizzardOptionsPanel_SetCVarSafe",BlizzardOptionsPanel_SetCVarSafeHook);
			self.hooked = true;
		end
		updateBroker();
	end
end

-- function module.optionspanel(panel) end

function module.onmousewheel(self,direction)
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

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	if not self.mousewheelOn then
		self:EnableMouseWheel(1);
		self.mousewheelOn = true;
	end

	tt = ns.acquireTooltip({ttName, 2, "LEFT", "RIGHT"},{false},{self})
	ns.RegisterMouseWheel(self,module.onmousewheel)
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
