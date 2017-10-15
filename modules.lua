local addon, ns = ...;
local L = ns.L;

ns.modules = {};

setmetatable(ns.modules,{
	__newindex = function(t,name,data)
		rawset(t,name,data);
		-- first step... register defaults
		if type(data.config_defaults)=="table" then
			--ns.Options_AddModuleDefaults(name);
		end
	end
});


local counters = {};
ns.showCharsFrom_Values = {
	ns.realm,
	L["Connected realms"],
	L["Same battlegroup"],
	L["All realms"]
}
local allModsOptions_defaults = {
	config_tooltip = {
		showAllFactions = true,
		showRealmNames = true,
		showCharsFrom = 4,
	},
	config_misc = {
		shortNumbers = false,
	},
};
local allModsOptions = {
	shortNumbers = {type="toggle", name="shortNumbers", label=L["Short numbers"], tooltip=L["Display short numbers like 123K instead of 123000"]},

	showAllFactions = { type="toggle", name="showAllFactions", label=L["Show all factions"], tooltip=L["Show characters from all factions (alliance, horde and neutral) in tooltip"]},
	showRealmNames = { type="toggle", name="showRealmNames", label=L["Show realm names"], tooltip=L["Show realm names behind charater names in tooltip"]},
	showCharsFrom = { type="select", name="showCharsFrom", label=L["Show chars from"], tooltip=L["Show characters from connected realms, same battlegroup or all realms in tooltip"],
		values=ns.showCharsFrom_Values,
		default=1
	}
}

local separator1,separator2 = {type="separator", alpha=0},{type="separator", inMenuInvisible=true};

function ns.toggleMinimapButton(modName,setValue)
	local mod = ns.modules[modName];
	local cfg = ns.profile[modName];

	-- check config
	if type(cfg.minimap)~="table" then
		cfg.minimap = {hide=true};
	end

	if setValue~=nil then
		-- change config if setValue not nil
		cfg.minimap.hide = not setValue;
	end

	if ns.LDBI:IsRegistered(mod.ldbName) then
		-- perform refresh on minimap button if already exists
		ns.LDBI:Refresh(mod.ldbName);
	elseif not cfg.minimap.hide then
		-- register minimap button if not exists
		ns.LDBI:Register(mod.ldbName,mod.obj,cfg.minimap);
	end
end

-- data table <ns.modules[name]>, values from <allModsOptions_defaults[config_table]>, name of the option entry
local function addConfigDefault(data,values,name,mod)
	local name2,ignore = (name=="minimapButton" and "minimap") or name,false;
	if values[name]~=nil  then
		if data.config_defaults==nil then
			data.config_defaults={};
		elseif data.config_defaults[name2]~=nil then
			ignore=true; -- is already set in module file = ignore
		end
		if not ignore then
			data.config_defaults[name2] = values[name];
		end
	end
end

local function moduleInit(name)
	local mod = ns.modules[name];

	-- module load on demand like
	if mod.noBroker or mod.enabled==nil then
		mod.enabled=true;
	end

	-- check if savedvariables for module present?
	if not mod.noOptions and ns.profile[name].enabled==nil then
		ns.profile[name].enabled = mod.enabled;
	end

	-- prepend minimapButton to all modules
	if type(mod.config_broker)~="table" then
		mod.config_broker = {};
	end

	-- add option for minimap button
	tinsert(mod.config_broker,1,{type="toggle", name="minimap", label=L["Broker as Minimap Button"], tooltip=L["Create a minimap button for this broker"], event=true});

	-- add allModsOptions_defaults to config_defaults
	local t;
	for config_table, entries in pairs(allModsOptions_defaults)do
		if type(mod[config_table])=="table" then
			for i=1, #mod[config_table] do
				t=type(mod[config_table][i]);
				if t=="string" and entries[mod[config_table][i]]~=nil then
					addConfigDefault(mod,entries,mod[config_table][i],name);
				elseif t=="table" then
					for _,optionEntry in ipairs(mod[config_table][i])do
						addConfigDefault(mod,entries,optionEntry.name,name);
					end
				end
			end
		end
	end

	-- check current config
	if (mod.config_defaults) then
		for k,v in pairs(mod.config_defaults) do
			if ns.profile[name][k]==nil then
				ns.profile[name][k] = v; -- nil = copy default value
			elseif (mod.config_allowed~=nil) and type(mod.config_allowed[k])=="table" and (mod.config_allowed[k][ns.profile[name][k]]~=true) then
				ns.profile[name][k] = v; -- mismatching allowed type
			elseif type(ns.profile[name][k])~=type(v) then
				ns.profile[name][k] = v; -- mismatching current/default value type
			end
		end
	end

	-- force enabled status of non Broker modules.
	if (mod.noBroker) then
		mod.enabled = true;
		ns.profile[name].enabled = true;
	end

	if (ns.profile[name].enabled==true) then
		local onclick;

		-- module init
		if mod.init then
			mod.init();
			mod.init = nil;
		end

		-- new clickOptions system
		if (type(mod.clickOptions)=="table") then
			local active = ns.clickOptions.update(mod,ns.profile[name]);
			if (active) then
				onclick = function(self,button) ns.clickOptions.func(name,self,button); end;
			end
		elseif (type(mod.onclick)=="function") then
			onclick = mod.onclick;
		end

		-- LDB init
		if (not mod.noBroker) then
			if (not mod.onenter) and mod.ontooltip then
				mod.ontooltipshow = mod.ontooltip;
			end

			local icon = ns.I(name .. (mod.icon_suffix or ""));
			local iColor = ns.profile.GeneralOptions.iconcolor;
			mod.ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name;
			mod.obj = ns.LDB:NewDataObject(mod.ldbName, {
				-- button data
				type          = "data source",
				label         = mod.label or L[name],
				text          = mod.text or L[name],
				icon          = icon.iconfile, -- default or custom icon
				staticIcon    = icon.staticIcon or icon.iconfile, -- default icon only
				iconCoords    = icon.coords or {0, 1, 0, 1},

				-- button event functions
				OnEnter       = mod.onenter or nil,
				OnLeave       = mod.onleave or nil,
				OnClick       = onclick,
				OnTooltipShow = mod.ontooltipshow or nil,

				-- let user know who registered the broker
				-- displayable by broker dispay addons...
				-- DataBrokerGroups using it in option panel.
				parent        = addon
			});

			ns.updateIconColor(name);

			-- register minimap button on demand
			ns.toggleMinimapButton(name);
		end

		-- event/update handling
		if (mod.onevent) or (mod.onupdate) then
			mod.eventFrame=CreateFrame("Frame");
			mod.eventFrame.modName = name;
			if (type(mod.onevent)=="function") then
				mod.eventFrame:SetScript("OnEvent",mod.onevent);
				mod.onevent(mod.eventFrame,"BE_UPDATE_CFG");
				mod.onevent(mod.eventFrame,"BE_UPDATE_CLICKOPTION");
				for _, e in pairs(mod.events) do
					if e=="ADDON_LOADED" then
						mod.onevent(mod.eventFrame,e,addon);
					elseif e=="PLAYER_LOGIN" and ns.pastPEW then -- for later enabled modules
						mod.onevent(mod.eventFrame,e);
					end
					mod.eventFrame:RegisterEvent(e);
					-- TODO: performance issue?
				end
			end
		end

		-- timeout function
		if (type(mod.ontimeout)=="function") and (type(mod.timeout)=="number") and (mod.timeout>0) then
			if (mod.afterEvent) then
				C_Timer.After(mod.timeout,mod.ontimeout);
			else
				C_Timer.After(mod.timeout,mod.ontimeout);
			end
		end

		-- chat command registration
		if (mod.chatcommands) then
			for i,v in pairs(mod.chatcommands) do
				if (type(i)=="string") and (ns.commands[i]==nil) then -- prevents overriding
					ns.commands[i] = v;
				end
			end
		end
	end

	-- module header
	local config = {};
	tinsert(config,separator1);
	tinsert(config,type(data.config_header) and data.config_header or {type="header", label=L[name], align="left", icon=ns.I[name]});
	tinsert(config,separator1);
	-- broker button options
	if data.config_broker and #data.config_broker>0 then
		if (data.config_broker[1]~=true or (type(data.config_broker[1])=="table" and data.config_broker[1].type~="header")) then
			tinsert(config,{type="header",label=L["Broker button options"]});
			tinsert(config,separator2);
		end
		for i=1, #data.config_broker do
			if type(data.config_broker[i])=="string" then
				if allModsOptions[data.config_broker[i]] then
					tinsert(config,allModsOptions[data.config_broker[i]]);
				end
			else
				if data.config_broker[i].event==nil then
					data.config_broker[i].event = true;
				end
				tinsert(config,data.config_broker[i]);
			end
		end
		tinsert(config,separator1);
	end
	data.config_broker=nil;
	-- tooltip options
	if data.config_tooltip and #data.config_tooltip>0 then
		if data.config_tooltip[1]~=true or (type(data.config_tooltip[1]=="table" and data.config_tooltip[1].type~="header")) then
			tinsert(config,{type="header",label=L["Tooltip options"]});
			tinsert(config,separator2);
		end
		for i=1, #data.config_tooltip do
			if type(data.config_tooltip[i])=="string" then
				if allModsOptions[data.config_tooltip[i]] then
					tinsert(config,allModsOptions[data.config_tooltip[i]]);
				end
			else
				tinsert(config,data.config_tooltip[i]);
			end
		end
		tinsert(config,separator1);
	end
	data.config_tooltip=nil;
	-- misc options
	if data.config_misc then
		local t = type(data.config_misc);
		if (t=="table" and (data.config_misc[1]==true or (type(data.config_misc[1])=="table" and data.config_misc[1].type~="header"))) or t=="string" then
			tinsert(config,{type="header",label=L["Misc options"]});
			tinsert(config,separator2);
		end
		if t=="table" and #data.config_misc>0 then
			for i=1, #data.config_misc do
				if data.config_misc[i]==true then
					tinsert(config,separator1);
					tinsert(config,{type="header",label=L["Misc options"]});
					tinsert(config,separator2);
				elseif type(data.config_misc[i])=="string" then
					if allModsOptions[data.config_misc[i]] then
						tinsert(config,allModsOptions[data.config_misc[i]]);
					end
				else
					tinsert(config,data.config_misc[i]);
				end
			end
		elseif t=="string" and allModsOptions[data.config_misc] then
			tinsert(config,allModsOptions[data.config_misc]);
		end
		tinsert(config,separator1);
	end
	data.config_misc = nil;
	-- broker click options
	if data.config_click_options and #data.config_click_options>0 then
		tinsert(config,{type="header",label=L["Broker click options"]});
		tinsert(config,separator2);
		for i=1, #data.config_click_options do
			tinsert(config,data.config_click_options[i]);
		end
	end
	--
	data.config = config;
end

function ns.moduleInit(name) -- in core.lua on event ADDON_LOADED or option panel
	if (name) then
		moduleInit(name);
	else
		for name, data in pairs(ns.modules) do
			moduleInit(name);
		end
	end
end
