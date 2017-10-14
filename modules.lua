local addon, ns = ...;
local L = ns.L;

-- ------------------------------- --
-- modules table and init function --
-- ~Hizuro                         --
-- ------------------------------- --
ns.modules = {};
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
	local data = ns.modules[name];

	-- module load on demand like
	if (data.enabled==nil) then
		data.enabled = true;
	end

	-- check if savedvariables for module present?
	if (ns.profile[name]==nil) then
		ns.profile[name] = {enabled = data.enabled};
	elseif (type(ns.profile[name].enabled)~="boolean") then
		ns.profile[name].enabled = data.enabled;
	end

	-- prepend minimapButton to all modules
	if type(data.config_broker)~="table" then
		data.config_broker = {};
	end

	-- add option for minimap button
	tinsert(data.config_broker,1,{type="toggle", name="minimap", label=L["Broker as Minimap Button"], tooltip=L["Create a minimap button for this broker"], event=true});

	-- add allModsOptions_defaults to config_defaults
	local t;
	for config_table, entries in pairs(allModsOptions_defaults)do
		if type(data[config_table])=="table" then
			for i=1, #data[config_table] do
				t=type(data[config_table][i]);
				if t=="string" and entries[data[config_table][i]]~=nil then
					addConfigDefault(data,entries,data[config_table][i],name);
				elseif t=="table" then
					for _,optionEntry in ipairs(data[config_table][i])do
						addConfigDefault(data,entries,optionEntry.name,name);
					end
				end
			end
		end
	end

	-- check current config
	if (data.config_defaults) then
		for k,v in pairs(data.config_defaults) do
			if ns.profile[name][k]==nil then
				ns.profile[name][k] = v; -- nil = copy default value
			elseif (data.config_allowed~=nil) and type(data.config_allowed[k])=="table" and (data.config_allowed[k][ns.profile[name][k]]~=true) then
				ns.profile[name][k] = v; -- mismatching allowed type
			elseif type(ns.profile[name][k])~=type(v) then
				ns.profile[name][k] = v; -- mismatching current/default value type
			end
		end
	end

	-- force enabled status of non Broker modules.
	if (data.noBroker) then
		data.enabled = true;
		ns.profile[name].enabled = true;
	end

	if (ns.profile[name].enabled==true) then
		local onclick;

		-- pre LDB init
		if data.init then
			data.init();
		end

		-- new clickOptions system
		if (type(data.clickOptions)=="table") then
			local active = ns.clickOptions.update(data,ns.profile[name]);
			if (active) then
				onclick = function(self,button) ns.clickOptions.func(name,self,button); end;
			end
		elseif (type(data.onclick)=="function") then
			onclick = data.onclick;
		end

		-- LDB init
		if (not data.noBroker) then
			if (not data.onenter) and data.ontooltip then
				data.ontooltipshow = data.ontooltip;
			end

			local icon = ns.I(name .. (data.icon_suffix or ""));
			local iColor = ns.profile.GeneralOptions.iconcolor;
			data.ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name;
			data.obj = ns.LDB:NewDataObject(data.ldbName, {
				-- button data
				type          = "data source",
				label         = data.label or L[name],
				text          = data.text or L[name],
				icon          = icon.iconfile, -- default or custom icon
				staticIcon    = icon.staticIcon or icon.iconfile, -- default icon only
				iconCoords    = icon.coords or {0, 1, 0, 1},

				-- button event functions
				OnEnter       = data.onenter or nil,
				OnLeave       = data.onleave or nil,
				OnClick       = onclick,
				OnTooltipShow = data.ontooltipshow or nil,

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
		if (data.onevent) or (data.onupdate) then
			data.eventFrame=CreateFrame("Frame");
			data.eventFrame.modName = name;
			if (type(data.onevent)=="function") then
				data.eventFrame:SetScript("OnEvent",data.onevent);
				for _, e in pairs(data.events) do
					if e=="ADDON_LOADED" then
						data.onevent(data.eventFrame,e,addon);
					elseif e=="PLAYER_ENTERING_WORLD" and ns.pastPEW then
						data.onevent(data.eventFrame,e);
					end
					data.eventFrame:RegisterEvent(e);
					-- TODO: performance issue?
				end
			end
		end

		-- timeout function
		if (type(data.ontimeout)=="function") and (type(data.timeout)=="number") and (data.timeout>0) then
			if (data.afterEvent) then
				C_Timer.After(data.timeout,data.ontimeout);
			else
				C_Timer.After(data.timeout,data.ontimeout);
			end
		end

		-- chat command registration
		if (data.chatcommands) then
			for i,v in pairs(data.chatcommands) do
				if (type(i)=="string") and (ns.commands[i]==nil) then -- prevents overriding
					ns.commands[i] = v;
				end
			end
		end

		data.init = nil;
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

ns.moduleInit = function(name)
	if (name) then
		moduleInit(name);
	else
		local i=0;
		for name, data in pairs(ns.modules) do
			moduleInit(name);
			i=i+1;
		end
	end
end
