
local addon, ns = ...
local addonLabel = addon;
local C, L, I = ns.LC.color, ns.L, ns.I;

-- TODO: modul optionen von nicht aktiven modulen werden nicht mit angezeigt in AceOptions

local dbDefaults,db = {
	profile = {
		GeneralOptions = {
			suffixColour = true,
			tooltipScale = false,
			showHints = true,
			iconset = "NONE",
			iconcolor = {1,1,1,1},
			goldColor = false,
			usePrefix = false,
			maxTooltipHeight = 60,
			scm = false,
			ttModifierKey1 = "NONE",
			ttModifierKey2 = "NONE",
			goldHideCopper = false,
			goldHideSilver = false,
			goldHideLowerZeros = false,
			separateThousands = true,
			showAddOnLoaded = true
		}
	}
};

ns.showCharsFrom_Values = {
	ns.realm,
	L["Connected realms"],
	L["Same battlegroup"],
	L["All realms"]
}

local nsProfileMT = {
	__newindex = function(t,k,v)
		db.profile[t.section][k] = v;
	end,
	__index = function(t,k)
		local s = rawget(t,"section");
		assert(s,"Error: section not defined? "..tostring(k));
		local v = db.profile[s][k];
		if v==nil then
			ns.debug("<FIXME:nsProfileMT:NilOption>",t.section,k);
		end
		return v;
	end
};

ns.profile = {
	GeneralOptions=setmetatable({section="GeneralOptions"},nsProfileMT)
}

setmetatable(ns.profile,{__index=function(t,k) rawset(t,k,{enabled=true}) end});

-- some values tables and functions
local ttModifierValues = {NONE = L["Default (no modifier)"]};
for i,v in pairs(ns.tooltipModifiers) do ttModifierValues[i] = L["ModKey"..v.l]; end

local function calcDataSize(info,obj)
	if info then
		local key = info[#info];
		return "~"..ns.FormatLargeNumber(true,calcDataSize(nil,Broker_Everything_CharacterDB[key])).."B";
	end
	local obj_t = type(obj);
	if obj_t=="table" then
		local sum = 0;
		for k,v in pairs(obj) do
			if type(k)=="string" then
				sum = sum + 40 + strlen(k);
			else
				sum = sum + 16;
			end
			sum = sum + calcDataSize(nil,v);
		end
		return sum + 40;
	elseif obj_t=="boolean" then
		return 2;
	elseif obj_t=="number" then
		return strlen(string.format("%x",obj));
	end
	return strlen(tostring(objStr));
end

local function getIconSets()
	local t = {NONE=NONE}
	local l = ns.LSM:List((addon.."_Iconsets"):lower())
	if type(l)=="table" then
		for i,v in pairs(l) do
			t[v] = v
		end
	end
	return t
end

local function noReload()
	return false;
end

-- module events on option changed
local moduleEvents = {
	--
}

-- option set/get function
local function opt(info,value,...)
	-- section = GeneralOptions or module names
	local key,section,isModEnable=info[#info],info[#info-2],(info[#info-1]=="modEnable");
	if value~=nil then
		if isModEnable then
			db.profile[key].enabled = value;
			if value then
				-- init module
				ns.moduleInit(key);
			end
		elseif key=="minimap" then
			db.profile[section][key].hide = not value;
			ns.toggleMinimapButton(section);
		else
			if ... then value={value,...}; end
			db.profile[section][key]=value;
			ns.modules[section]:onevent("BE_UPDATE_CFG");
			if moduleEvents[section] and moduleEvents[section][key] then
				ns.modules[section]:onevent(moduleEvents[section][key]);
			end
		end
	end
	if isModEnable then
		return db.profile[key].enabled;
	elseif key=="minimap" then
		return not db.profile[section][key].hide;
	else
		if type(db.profile[section][key])=="table" then
			return unpack(db.profile[section][key]);
		end
		if db.profile[section][key]==nil then
			ns.debug("<FIXME:opt:NilOptions>",tostring(section),tostring(key));
		end
		return db.profile[section][key];
	end
end

ns.option=opt; -- used in shared.lua (EasyMenu wrapper)

local options = {
	type = "group",
	name = addon,
	get=opt, set=opt,
	childGroups = "tab",
	args = {
		reloadinfo = {
			type = "group", order=1, inline = true,
			name = "",
			args = {
				spacer = { type="description", order=1, name=" ", width="half"},
				reload = { type="execute", order=2, name=L["OptReloadUI"], func=ReloadUI },
				info = { type="description", order=3, name=C("orange",L["OptReloadUIRequired"]), fontSize="medium", width="double", hidden=noReload},
			},
			hidden = true
		},
		GeneralOptions = {
			type = "group", order = 1,
			name = L["OptGeneral"],
			args = {
				gold = {
					type = "group", order = 1, inline = true,
					name = L["OptMoney"],
					args = {
						goldColor          = {type="toggle",order=1,name=L["OptGoldColor"], desc=L["OptGoldColorDesc"]},
						goldHideCopper     = {type="toggle",order=2,name=L["OptHideCopper"],desc=L["OptHideCopperDesc"]},
						goldHideSilver     = {type="toggle",order=3,name=L["OptHideSilver"],desc=L["OptHideSilverDesc"]},
						goldHideLowerZeros = {type="toggle",order=4,name=L["OptHideZeros"], desc=L["OptHideZerosDesc"]},
						separateThousands  = {type="toggle",order=5,name=L["OptDigitGroup"],desc=L["OptDigitGroupDesc"]},
					}
				},
				tooltip = {
					type = "group", order = 2, inline = true,
					name = L["OptTooltip"],
					args = {
						tooltipScale     = {type="toggle",order=1,name=L["OptTTScale"],desc=L["OptTTScaleDesc"]},
						scm              = {type="toggle",order=2,name=L["OptSCM"],desc=L["OptSCMDesc"]},
						showHints        = {type="toggle",order=3,name=L["OptTTHints"],desc=L["OptTTHintsDesc"]},
						ttModifierKey1   = {type="select",order=4,name=L["Show tooltip"],desc=L["Hold modifier key to display tooltip"],values=ttModifierValues,width="double"},
						maxTooltipHeight = {type="range", order=5,name=L["Max. Tooltip height"], desc=L["Adjust the maximum of tooltip height in percent of your screen height."],min=10, max=90},
						ttModifierKey2   = {type="select",order=6,name=L["Allow mouseover"],desc=L["Hold modifier key to use mouseover in tooltip"],values=ttModifierValues,width="double"},
					}
				},
				icons = {
					type = "group", order = 3, inline = true,
					name = L["OptIcons"],
					args = {
						iconcolor = {type="color", order=1,name=L["Icon color"],desc=L["Change the color of the icons"]},
						iconset   = {type="select",order=2,name=L["Iconsets"],desc=L["Choose an custom iconset"],values=getIconSets(),width="double"},
						iconsetinfo = {
							type = "description", order = 3,
							name = L["OptIconSetsInfo"] .. " " .. C("dkyellow","https://www.wowinterface.com/downloads/info22790.html")
						}
					}
				},
				misc = {
					type = "group", order = 0, inline = true,
					name = L["OptMisc"],
					args = {
						showAddOnLoaded = { type="toggle", order=1, name=L["Show 'AddOn Loaded...'"], desc=L["Show 'AddOn Loaded...' message on logins and UI reloads"] },
						suffixColour    = { type="toggle", order=2, name=L["Suffix coloring"], desc=L["Enable/Disable class coloring of the information display suffixes. (eg, ms, fps etc)"] },
						usePrefix       = { type="toggle", order=3, name=L["Use prefix"], desc=L["Use prefix 'BE..' on module registration at LibDataBroker. This fix problems with other addons with same broker names but effect your current settings in panel addons like Bazooka or Titan Panel."] },
					}
				},
			}
		},
		modEnable = {
			type = "group", order = 2,
			name = L["OptModToggle"],
			childGroups = "tab",
			args = {
			}
		},
		modOptions = { -- dummy group
			type = "group", order = 3,
			childGroups="tree",
			name = L["OptMods"],
			args = {},
		},
		chars = {
			type = "group", order = 4, --fontSize="normal",
			name = L["OptCharData"],
			childGroups="tab",
			args = {
				infoheader = { type = "description",   order=1, name=C("dkyellow",L["OptCharInfoHeader"]), fontSize="medium" },
				info1_2 = {
					type = "description", order= 2,
					name =  C("ltgreen",L["OptCharInfo1"]) .. "\n" .. L["OptCharInfo1Desc"].. "\n\n" ..
							C("ltgreen",L["OptCharInfo2"]) .. "\n" .. L["OptCharInfo2Desc"] .."\n "
				},
				info3 = { type="description", order=6, name=C("ltgreen",L["OptCharInfo3"]), width="normal"},
				delete = {
					type = "execute", order=7, width="double",
					name = L["OptCharDelAll"], desc = L["OptCharDelAllDesc"]
				},
				list = {
					type = "group", order=8,
					name = L["OptCharList"],
					childGroups="tab",
					args = {
					}
				}
			}
		}
		-- profiles = {}, -- created by AceDBOptions
	}
}

ns.sharedOptions = {
	shortNumbers    = { type="toggle", name=L["Short numbers"], desc=L["Display short numbers like 123K instead of 123000"]},
	showAllFactions = { type="toggle", name=L["Show all factions"], desc=L["Show characters from all factions (alliance, horde and neutral) in tooltip"]},
	showRealmNames  = { type="toggle", name=L["Show realm names"], desc=L["Show realm names behind charater names in tooltip"]},
	showCharsFrom   = { type="select", name=L["Show chars from"], desc=L["Show characters from connected realms, same battlegroup or all realms in tooltip"],
		values=ns.showCharsFrom_Values,
	}
}

local sharedDefaults = {
	shortNumbers = true,
	showAllFactions = true,
	showRealmNames = true,
	showCharsFrom = 2
}

local coords=nil;
local function Icon(info)
	local key=info[#info];
	if key=="modOptions" then return end
	local icon = I[key..(ns.modules[key].icon_suffix or "")];
	coords = icon.coords or {.1,.9,.1,.9};
	return icon.iconfile;
end

function ns.getModOptionTable(modName)
	if modName and options.args.modOptions.args[modName] then
		return options.args.modOptions.args[modName].args;
	end
	return {};
end

local function IconCoords(info)
	if info[#info]=="modOptions" then return end
	return coords;
end

local function optionWalker(modName,group,lst)
	for k, v in pairs(lst)do
		local tV = type(v);
		if tV=="number" or tV=="boolean" then
			if ns.sharedOptions[k] then
				lst[k] = ns.sharedOptions[k];
				if tV=="number" then
					lst[k].order = v;
				end
				dbDefaults.profile[modName][k] = sharedDefaults[k];
			else
				lst[k]=nil;
			end
		else
			if v.type=="separator" then
				v.type = "description";
				v.name = " ";
			end
			if v.type=="slider" or v.type=="desc" then
				ns.debug("<FIXME:BadType>",k,modName);
				lst[k]=nil;
			end

			if (v.default or v.inMenuInvisible or v.text or v.isSubMenu or v.alpha or v.tooltip or v.label or v.format or v.rep or v.minText or v.maxText)~=nil  then
				ns.debug("<FIXME:BadKey>",k,modName);
				lst[k]=nil;
			end
		end
	end
	if group=="broker" then
		lst.minimap = {
			type = "toggle", order = 0,
			name = L["OptMinimap"], desc=L["OptMinimapDesc"]
		}
	end
end

function ns.Options_AddModuleDefaults(modName)
	ns.profile[modName] = setmetatable({section=modName},nsProfileMT);
	local mod = ns.modules[modName];

	-- normal defaults
	dbDefaults.profile[modName] = mod.config_defaults or {};

	-- add shared option defaults
	if mod.options then
		for _,group in pairs(mod.options())do
			for key,value in pairs(group)do
				if sharedDefaults[key]~=nil and dbDefaults.profile[modName][key]==nil then
					dbDefaults.profile[modName][key] = sharedDefaults[key];
				end
			end
		end
	end

	-- add clickOption defaults
	if mod and type(mod.clickOptions)=="table" then
		for cfgKey,clickOpts in pairs(mod.clickOptions) do
			local optKey = "clickOptions::"..cfgKey;
			dbDefaults.profile[modName][optKey] = clickOpts.default or "__NONE";
		end
	end
end

local function ModName(info)
	local key=info[#info];
	if not ns.profile[key].enabled then
		return C("gray",L[key]);
	end
	return L[key];
end

local function ModDesc(info)
	local key=info[#info];
	if not ns.profile[key].enabled then
		return C("red","("..ADDON_DISABLED..")").."\n"..C("gray",L["ModDesc-"..key]);
	end
	return L["ModDesc-"..key];
end

function ns.Options_AddModuleOptions(modName)
	-- add toggle to ModToggleTab
	options.args.modEnable.args[modName] = {type="toggle",name=L[modName],desc=L["ModDesc-"..modName]};

	-- add own tree entry per module
	if ns.modules[modName].options then
		options.args.modOptions.args[modName] = {
			type = "group",
			name = ModName, desc = ModDesc,
			icon = Icon, iconCoords = IconCoords, -- currently ace ignore IconCoords
			args = {
			}
		}
		local modOptions, modEvents = ns.modules[modName].options();
		modEvents = modEvents or {};

		if dbDefaults.profile[modName]==nil then
			dbDefaults.profile[modName]={}; -- should never be nil... :D
			ns.debug("<FIXME:NilDefaultTable>",modName);
		end

		ns.clickOptions.createOptions(modName,modOptions,modEvents);

		for k, v in pairs(modOptions)do
			local name, order = v.name, v.order;
			if k:find("^broker") then
				name = name or L["OptBroker"];
				order = order or 1;
				if modEvents[k]==nil then
					modEvents[k]="BE_DUMMY_EVENT";
				end
			elseif k:find("^tooltip") then
				name = name or L["OptTooltip"];
				order = order or 2;
			elseif k:find("^misc") then
				name = name or L["OptMisc"];
				order = order or 98;
			elseif k:find("^clickOptions") then
				name = name or L["OptClickOptions"];
				order = 99;
			end
			optionWalker(modName,k,v);
			options.args.modOptions.args[modName].args[k] = {
				type="group", name=name, order=order, inline=true, args=v
			}
			if modEvents[k]==true then
				modEvents[k]="BE_DUMMY_EVENT";
			end
		end

		moduleEvents[modName] = modEvents;
	end
end

local function buildCharDataOptions()
	local lst = options.args.chars.args.list.args;
	-- Broker_Everything_CharacterDB
	-- Broker_Everything_CharacterDB.order
	for order,name_realm in ipairs(Broker_Everything_CharacterDB.order)do
		local charName, realm = strsplit("%-",name_realm,2);
		local class = Broker_Everything_CharacterDB[name_realm].class;
		lst[name_realm] = {
			type = "group", order = order, inline=true,
			name = "",
			args = {
				label = {
					type = "description", order=1, width="normal", fontSize = "medium",
					name = C(class,charName).."\n"..C("gray",realm),
				},
				[name_realm] = {
					type = "description", order = 2, width = "half",
					name = calcDataSize,
				},
				up   = {type="execute", order=3, width="half", name=L["Up"]},
				down = {type="execute", order=4, width="half", name=L["Down"]},
				del  = {type="execute", order=5, width="half", name=DELETE},
			}
		}
	end
end

function ns.RegisterOptions()
	if Broker_Everything_AceDB==nil then
		Broker_Everything_AceDB = {}
	end

	-- db migration to ace
	if Broker_Everything_AceDB.profileKeys==nil then
		-- migrate profile keys to ace
		Broker_Everything_AceDB.profileKeys = {}
		for char_realm, profileName in pairs(Broker_Everything_ProfileDB.use_profile)do
			if profileName==DEFAULT then
				profileName="Default"
			end
			local charName,realmName = strsplit("-",char_realm,2); -- aceDB has whitespaces around the dash between char and realm names. split and rejoin
			if realmName then
				Broker_Everything_AceDB.profileKeys[charName.." - "..realmName] = profileName;
			end
		end
	end

	if Broker_Everything_AceDB.profiles==nil then
		-- migrate profiles to ace
		Broker_Everything_AceDB.profiles=CopyTable(Broker_Everything_ProfileDB.profiles);
		if Broker_Everything_AceDB.profiles[DEFAULT]~=nil then
			Broker_Everything_AceDB.profiles.Default = Broker_Everything_AceDB.profiles[DEFAULT];
			Broker_Everything_AceDB.profiles[DEFAULT] = nil;
		end

		for profileName,profileData in pairs(Broker_Everything_AceDB.profiles)do
			for modName,modData in pairs(profileData)do
				-- migrate clickoption keys
				for optName, optValue in pairs(modData)do
					local name = optName:match("^clickOptions::[0-9]*_(.*)$");
					if name then
						modData["ClkOpts:"..name] = optValue;
						modData[optName] = nil;
					end
				end

				-- migrate showAllRealms
				if modData.showAllRealms~=nil then
					modData.showCharsFrom = 4;
					modData.showAllRealms = nil;
				end
			end

			-- migrate some option entries from shared_module
			local modName="GPS / Location / ZoneText";
			if profileData[modName] then
				for key,value in pairs(profileData[modName])do
					if profileData.GPS==nil then profileData.GPS={} end
					if profileData.Location==nil then profileData.Location={} end
					if profileData.ZoneText==nil then profileData.ZoneText={} end
					profileData.GPS[key]=value;
					profileData.Location[key]=value;
					profileData.ZoneText[key]=value;
				end
				profileData[modName]=nil;
			end
		end
	end

	buildCharDataOptions();

	db = LibStub("AceDB-3.0"):New("Broker_Everything_AceDB",dbDefaults,true);

	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db);
	options.args.profiles.order=-1;

	LibStub("AceConfig-3.0"):RegisterOptionsTable(addonLabel, options);
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonLabel);
end

function ns.ToggleBlizzOptionPanel()
	InterfaceOptionsFrame_OpenToCategory(addon);
	InterfaceOptionsFrame_OpenToCategory(addon);
end
