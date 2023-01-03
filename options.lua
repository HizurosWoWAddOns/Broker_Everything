
local addon, ns = ...
local addonLabel = addon;
local C, L, I = ns.LC.color, ns.L, ns.I;
local setmetatable,type,rawget,tostring=setmetatable,type,rawget,tostring;
local ipairs,pairs,wipe,strsplit,tremove=ipairs,pairs,wipe,strsplit,tremove;

local dbDefaults,db = {
	profile = {
		GeneralOptions = {
			suffixColour = true,
			showHints = true,
			iconset = "NONE",
			iconcolor = {1,1,1,1},
			goldColor = "white",
			goldCoins = true,
			usePrefix = false,
			maxTooltipHeight = 60,
			scm = false,
			ttModifierKey1 = "NONE",
			ttModifierKey2 = "NONE",
			goldHide = "0",
			separateThousands = true,
			showAddOnLoaded = true,
			chatCommands = true
		}
	}
};

ns.showCharsFrom_Values = { -- used in xp.lua to display current mode in tooltip
	["1"] = ns.realm,
	["2"] = L["Connected realms"],
	["4"] = L["All realms"]
};

local goldHideValues = {
	["0"]=ADDON_DISABLED,
	["1"]=L["HideMoneyCopper"],
	["2"]=L["HideMoneySilver"],
	["3"]=L["HideMoneyZeros"],
	["4"]=L["ShowHighestOnly"]
};

local nsProfileMT
--@do-not-package@
do
	nsProfileMT = {
		__newindex = function(t,k,v)
			local s = rawget(t,"section");
			if s and db and db.profile[s] then
				db.profile[s][k] = v;
			elseif ns.profileSilenceFIXME then
				ns.profileSilenceFIXME=false;
			else
				ns:debug("Options","<FIXME:nsProfileMT:MissingSection>",tostring(s),tostring(k));
			end
		end,
		__index = function(t,k)
			local s = rawget(t,"section");
			if s and db and db.profile[s] then
				local v = db.profile[s][k];
				if v~=nil then
					return v;
				elseif ns.profileSilenceFIXME then
					ns.profileSilenceFIXME=false;
				else
					ns:debug("Options","<FIXME:nsProfileMT:NilValue>",tostring(s),tostring(k));
				end
			elseif ns.profileSilenceFIXME then
				ns.profileSilenceFIXME=false;
			else
				ns:debug("Options","<FIXME:nsProfileMT:MissingSectionOrDB>",tostring(s),tostring(k));
			end
		end
	};

	ns.profileSilenceFIXME = false;
	ns.profile = {GeneralOptions=setmetatable({section="GeneralOptions"},nsProfileMT)};
end
--@end-do-not-package@

-- some values tables and functions
local ttModifierValues = {NONE = L["ModKeyDefault"]};
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
		return (floor(obj/2147483647)+1)*8;
	end
	return strlen(tostring(obj));
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

local function toggleAllModules(info)
	local state = info[#info];
	if not (state=="enable" or state=="disable" or state=="default") then
		return;
	end
	for modName,modObject in pairs(ns.modules) do
		if not modObject.isHiddenModule then
			local newValue
			if state=="enable" and db.profile[modName].enabled==false then
				newValue = true;
			elseif state=="disable" and db.profile[modName].enabled==true then
				newValue = false;
			elseif state=="default" and db.profile[modName].enabled~=ns.modules[modName].config_defaults.enabled then
				newValue = ns.modules[modName].config_defaults.enabled;
			end
			if newValue~=nil then
				db.profile[modName].enabled = newValue;
				if newValue then
					ns.moduleInit(modName);
				end
			end
		end
	end
end

-- option set/get function
local function opt(info,value,...)
	if not db then return end
	-- section = GeneralOptions or module names
	local key,section,isModEnable = info[#info],info[#info-2],(info[#info-1]=="modEnable");
	if #info>=5 then
		local modOptDepth = nil;
		for i=#info, 1, -1 do
			if info[i]=="modOptions" then
				modOptDepth = i+1;
				break;
			end
		end
		if modOptDepth~=nil then
			section = info[modOptDepth];
		end
	end
	if value~=nil then
		if isModEnable then
--@do-not-package@
			ns:debug("Options","<ToggleModuleEnableState>",key,type(db.profile),type(db.profile[key]));
--@end-do-not-package@
			db.profile[key].enabled = value;
			if value then
				-- init module
				ns.moduleInit(key);
			end
		elseif key=="minimap" then
			db.profile[section][key].hide = not value;
			ns.toggleMinimapButton(section);
		else
			if ... then value={value,...}; end -- color table
			db.profile[section][key]=value;
			if section=="GeneralOptions" then
				for modName,mod in pairs(ns.modules)do
					if mod.isEnabled and mod.onevent then
						mod.onevent(mod.eventFrame,"BE_UPDATE_CFG",key);
					end
				end
				if key=="iconcolor" then
					ns.updateIcons(true,"color");
				elseif key=="iconset" then
					ns.updateIcons(true,"icon");
				end
			elseif ns.modules[section].onevent then
				ns.modules[section].onevent(ns.modules[section].eventFrame,"BE_UPDATE_CFG",key);
--@do-not-package@
			else
				ns:debug("Options","<FIXME:opt:MissingEventFunction>",section);
--@end-do-not-package@
			end
		end
	end
	if isModEnable then
		return (db and key and db.profile and db.profile[key] and db.profile[key].enabled);
	elseif key=="minimap" then
		return not db.profile[section][key].hide;
	else
		if type(db.profile[section][key])=="table" then
			return unpack(db.profile[section][key]);
		end
--@do-not-package@
		if db.profile[section][key]==nil then
			ns:debug("Options","<FIXME:opt:NilOptions>",tostring(section),tostring(key),tostring(key):len());
		end
--@end-do-not-package@
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
		GeneralOptions = {
			type = "group", order = 1,
			name = GENERAL,
			args = {
				misc = {
					type = "group", order = 1, inline = true,
					name = C("ff00aaff",AUCTION_SUBCATEGORY_OTHER),
					args = {
						showAddOnLoaded = { type="toggle",order=1,name=L["AddOnLoaded"],desc=L["AddOnLoadedDesc"].."|n|n|cff44ff44"..L["AddOnLoadedDescAlt"].."|r" },
						suffixColour    = { type="toggle",order=2,name=L["SuffixColor"],desc=L["SuffixColorDesc"] },
						usePrefix       = { type="toggle",order=3,name=L["Prefix"],desc=L["PrefixDesc"] },
						chatCommands    = { type="toggle",order=4,name=L["ChatCommands"],desc=L["ChatCommandsDesc"] },
					}
				},
				gold = {
					type = "group", order = 2, inline = true,
					name = C("ff00aaff",BONUS_ROLL_REWARD_MONEY),
					args = {
						goldColor          = {type="select",order=1,name=L["GoldColor"],desc=L["GoldColorDesc"],values={_none=ADDON_DISABLED,color=L["GoldColorCoin"],white=L["GoldColorWhite"]} },
						goldCoins          = {type="toggle",order=2,name=L["GoldCoins"],desc=L["GoldCoinsDesc"]},
						separateThousands  = {type="toggle",order=3,name=L["DigitGroup"],desc=L["DigitGroupDesc"]},
						goldHide           = {type="select",order=4,name=L["HideMoney"],desc=L["HideMoneyDescEverywhere"], width = "double", values= goldHideValues }
					}
				},
				tooltip = {
					type = "group", order = 3, inline = true,
					name = C("ff00aaff",L["Tooltip"]),
					args = {
						scm              = {type="toggle",order=1,name=L["OptSCM"],desc=L["OptSCMDesc"]},
						showHints        = {type="toggle",order=2,name=L["OptTTHints"],desc=L["OptTTHintsDesc"]},
						maxTooltipHeight = {type="range", order=3,name=L["TTMaxHeight"],desc=L["TTMaxHeightDesc"],min=10, max=90},
						ttModifierKey1   = {type="select",order=4,name=L["TTShowMod"],desc=L["TTShowModDesc"],values=ttModifierValues,width="double"},
						ttModifierKey2   = {type="select",order=5,name=L["TTMouse"],desc=L["TTMouseDesc"],values=ttModifierValues,width="double"},
					}
				},
				icons = {
					type = "group", order = 4, inline = true,
					name = C("ff00aaff",L["Icons"]),
					args = {
						iconcolor = {type="color", order=1,name=L["IconColor"],desc=L["IconColorDesc"]},
						iconset   = {type="select",order=2,name=L["IconSets"],desc=L["IconSetsDesc"],values=getIconSets(),width="double"},
						iconsetinfo = {
							type = "description", order = 3, fontSize = "medium",
							name = C("dkyellow",L["IconSetsInfo"])
						},
						iconsetlink = {
							type = "input", order = 4, width = "full",
							name = "",
							get = function() return "http://www.wowinterface.com/downloads/info22790.html"; end,
							set = function() end
						}
					}
				},
			}
		},
		modEnable = {
			type = "group", order = 2,
			name = L["ModsToggle"],
			desc = L["ModsToggleDesc"],
			childGroups = "tab",
			args = {
				info = {
					type = "group", order = 0, inline = true,
					name = "",
					args = {
						desc    = { type="description", order=0, fontSize="medium", width="double", name=C("orange",L["ModsToggleInfo"]) },
						reload  = { type="execute", order=1, name=L["ReloadUI"], func=C_UI.Reload },

						enable  = { type="execute", order=2, name=ENABLE_ALL_ADDONS, func=toggleAllModules },
						disable = { type="execute", order=3, name=DISABLE_ALL_ADDONS, func=toggleAllModules },
						default = { type="execute", order=4, name=DEFAULT, func=toggleAllModules }
					}
				},
			}
		},
		modOptions = { -- dummy group
			type = "group", order = 3,
			name = L["Modules"],
			desc = L["ModulesDesc"],
			childGroups="tree",
			args = {},
		},
		chars = {
			type = "group", order = 4, --fontSize="normal",
			name = L["OptCharData"],
			desc = L["OptCharDataDesc"],
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
		},
		-- profiles = {}, -- created by AceDBOptions
	}
}

ns.sharedOptions = {
	shortNumbers    = { type="toggle", name=L["ShortNum"], desc=L["ShortNumDesc"]},
	showAllFactions = { type="toggle", name=L["AllFactions"], desc=L["AllFactionsDesc"]},
	showRealmNames  = { type="toggle", name=L["RealmNames"], desc=L["RealmNamesDesc"]},
	showChars       = { type="toggle", name=L["ShowChars"], desc=L["ShowCharsDesc"], customDescFormat="ShowCharsDesc-%s" }, -- TODO: translation ShowCharsDesc
	showCharsFrom   = { type="select", name=L["CharsFrom"], desc=L["CharsFromDesc"], values=ns.showCharsFrom_Values },
	goldHideBB      = { type="select", name=L["HideMoney"], desc=L["HideMoneyDescBrokerButton"], width = "double", values = goldHideValues },
	goldHideTT      = { type="select", name=L["HideMoney"], desc=L["HideMoneyDescTooltip"], width = "double", values = goldHideValues },
}

local sharedDefaults = {
	shortNumbers = true,
	showChars = true,
	showAllFactions = true,
	showRealmNames = true,
	showCharsFrom = "2",
	minimap = {hide=false}
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
		local tV,customModDesc = type(v);
		if tV=="table" and #v>0 then
			-- short table {<order[number|bool]>, <customModDesc>}
			customModDesc,v,tV = v[2],v[1],type(v[1]);
		end
		if tV=="number" or tV=="boolean" then
			if ns.sharedOptions[k] then
				local shared = CopyTable(ns.sharedOptions[k]);
				if tV=="number" then
					shared.order = v;
				end
				if customModDesc then
					local LStr = "";
					if customModDesc==true then
						customModDesc = modName;
					end
					if shared.customDescFormat then
						LStr = L[shared.customDescFormat:format(customModDesc)];
						shared.customDescFormat = nil;
					else
						LStr = L[customModDesc];
					end
					if LStr~="" then
						shared.desc = LStr;
					end
				end
				lst[k] = shared;
				dbDefaults.profile[modName][k] = sharedDefaults[k];
			else
				lst[k]=nil;
			end
		elseif tV=="table" then
			if v.type=="separator" then
				v.type = "description";
				v.name = " ";
			end
			if v.type=="slider" or v.type=="desc" then
--@do-not-package@
				ns:debug("Options","<FIXME:optionWalker:BadType>",k,modName);
--@end-do-not-package@
				lst[k]=nil;
			end
			if (v.default or v.inMenuInvisible or v.text or v.isSubMenu or v.alpha or v.tooltip or v.label or v.format or v.rep or v.minText or v.maxText)~=nil then
--@do-not-package@
				ns:debug("Options","<FIXME:optionWalker:BadKey>",k,modName);
--@end-do-not-package@
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

function ns.Options_RegisterDefaults() -- re-registration for dbDefaults after 'db = LibStub("AceDB-3.0"):New("Broker_Everything_AceDB",dbDefaults,true);'
	db:RegisterDefaults(dbDefaults);
end

function ns.Options_RegisterModule(modName)
	local mod,modOptions = ns.modules[modName],{};

	-- defaults
	if nsProfileMT then -- namespace profile metatable for debugging; not present in normal release versions. ;-)
		ns.profile[modName] = setmetatable({section=modName},nsProfileMT);
	end
--@do-not-package@
	if not mod.config_defaults then
		ns:debug("Options","<FIXME:MissingModConfigDefault>",modName);
	elseif mod.config_defaults.enabled==nil then
		ns:debug("Options","<FIXME:MissingModEnableState>",modName);
	end
--@end-do-not-package@

	-- normal defaults
	dbDefaults.profile[modName] = mod.config_defaults or {enabled=false};

	if not mod.isHiddenModule then
		if dbDefaults.profile[modName].minimap==nil then
			dbDefaults.profile[modName].minimap = {hide=false};
		end

		-- add toggle to ModToggleTab
		options.args.modEnable.args[modName] = {type="toggle",name=L[modName],desc=L["ModDesc-"..modName]};

		-- add shared option defaults
		if type(mod.options)=="function" then
			modOptions = mod.options();
			for _,group in pairs(modOptions)do
				for key,value in pairs(group)do
					if sharedDefaults[key]~=nil and dbDefaults.profile[modName][key]==nil then
						dbDefaults.profile[modName][key] = sharedDefaults[key];
					end
				end
			end
		end

		-- add own tree entry per module
		options.args.modOptions.args[modName] = {
			type = "group",
			name = ModName, desc = ModDesc,
			icon = Icon, iconCoords = IconCoords, -- currently ace ignore IconCoords
			args = {
			}
		}

		if mod.clickOptions then
			ns.ClickOpts.createOptions(modName,modOptions);
		end

		local hasBrokerOpts = false;
		for k in pairs(modOptions)do
			if k:find("^broker") then
				hasBrokerOpts = true;
				break;
			end
		end
		if not hasBrokerOpts then
			modOptions.broker = {};
		end
		for k, v in pairs(modOptions)do
			local name, order = v.name, v.order;
			v.name,v.order = nil,nil;
			if k:find("^broker") then
				name = name or L["Broker"];
				order = order or 1;
			elseif k:find("^tooltip") then
				name = name or L["Tooltip"];
				order = order or 2;
			elseif k:find("^misc") then
				name = name or AUCTION_SUBCATEGORY_OTHER;
				order = order or 98;
			elseif k:find("^ClickOpts") then
				name = name or L["ClickOptions"];
				order = 99;
			end
			optionWalker(modName,k,v);
			options.args.modOptions.args[modName].args[k] = {
				type="group", name=C("ff00aaff",name), order=order, inline=true, args=v
			}
		end
	end
end

local function buildCharDataOptions()
	wipe(options.args.chars.args.list.args);
	local lst = options.args.chars.args.list.args;
	-- Broker_Everything_CharacterDB
	-- Broker_Everything_CharacterDB.order
	for order,name_realm in ipairs(Broker_Everything_CharacterDB.order)do
		if Broker_Everything_CharacterDB[name_realm] then
			local charName, realm = strsplit("%-",name_realm,2);
			local label,hasError = "",false
			if Broker_Everything_CharacterDB[name_realm].class and charName and realm then
				label = C(Broker_Everything_CharacterDB[name_realm].class or "ffff0000",charName or "error").."\n"..C("gray",realm or "error");
			else
				label = C("ffff0000",charName) .. "\n" .. C("gray",realm);
				hasError = true;
			end
			lst[name_realm] = {
				type = "group", order = order, inline=true,
				name = "",
				args = {
					label = {
						type = "description", order=1, width="normal", fontSize = "medium",
						name = label,
					},
					[name_realm] = {
						type = "description", order = 2, width = "half",
						name = calcDataSize,
					},
					up   = {type="execute", order=3, width="half", name=L["Up"], desc=label, disabled=(order==1) },
					down = {type="execute", order=4, width="half", name=L["Down"], desc=label, disabled=(order==#Broker_Everything_CharacterDB.order) },
					del  = {type="execute", order=5, width="half", name=DELETE, desc=label, disabled=(name_realm==ns.player.name_realm) },
					error = {type = "description", order=6, fontSize = "medium", name = C("red",L["CharDataError"].." "..name_realm).."\n"..L["CharDataErrorTODO"], hidden=not hasError },
				}
			}
		end
	end
end

function options.args.chars.func(info) -- function for buttons 'Up', 'Down' and 'Delete' for single character and 'Delete all'
	local key,char = info[#info],info[#info-1];
	if key=="up" or key=="down" then
		local cur
		for i,v in ipairs(Broker_Everything_CharacterDB.order)do
			if char==v then
				cur = i;
				break;
			end
		end
		if key=="up" then
			Broker_Everything_CharacterDB.order[cur],Broker_Everything_CharacterDB.order[cur-1] = Broker_Everything_CharacterDB.order[cur-1],Broker_Everything_CharacterDB.order[cur];
		else -- down
			Broker_Everything_CharacterDB.order[cur],Broker_Everything_CharacterDB.order[cur+1] = Broker_Everything_CharacterDB.order[cur+1],Broker_Everything_CharacterDB.order[cur];
		end
		buildCharDataOptions();
	elseif key=="del" then -- delete single character
		Broker_Everything_CharacterDB[char] = nil;
		for i,v in ipairs(Broker_Everything_CharacterDB.order)do
			if char==v then
				tremove(Broker_Everything_CharacterDB.order,i);
				break;
			end
		end
		buildCharDataOptions();
	elseif key=="delete" then -- delete all
		Broker_Everything_CharacterDB = {};
		C_UI.Reload();
	end
end

function ns.RegisterOptions()
	if Broker_Everything_AceDB==nil then
		Broker_Everything_AceDB = {};
	end

	buildCharDataOptions();

	db = LibStub("AceDB-3.0"):New("Broker_Everything_AceDB",dbDefaults,true);
	if not nsProfileMT then
		ns.profile = db.profile;
	end

	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db);
	options.args.profiles.order=-1;

	LibStub("AceConfig-3.0"):RegisterOptionsTable(addonLabel, options);
	local opts = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonLabel);
	LibStub("HizurosSharedTools").BlizzOptions_ExpandOnShow(opts);
	LibStub("HizurosSharedTools").AddCredit(addon);

	local goldColor = ns.profile.GeneralOptions.goldColor;
	if type(goldColor)~="string" then
		ns.profile.GeneralOptions.goldColor = goldColor and "color" or "white";
	end
end

function ns.ToggleBlizzOptionPanel()
	InterfaceOptionsFrame_OpenToCategory(addon);
	InterfaceOptionsFrame_OpenToCategory(addon);
end
