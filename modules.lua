local addon, ns = ...;
local L = ns.L;

ns.modules = {};

setmetatable(ns.modules,{
	__newindex = function(t,name,data)
		rawset(t,name,data);
		-- first step... register defaults
		if type(data.config_defaults)=="table" then
			ns.Options_AddModuleDefaults(name);
		end
	end
});

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

	-- register options
	if not mod.noBroker then
		ns.Options_AddModuleOptions(name);
	end

	if mod.noOptions or (mod.noOptions==nil and ns.profile[name].enabled==true) then
		local onclick;

		-- module init
		if mod.init then
			mod.init();
			mod.init = nil;
		end

		-- new clickOptions system
		if (type(mod.clickOptions)=="table") then
			local active = ns.clickOptions.update(name);
			if active then
				function onclick(self,button)
					ns.clickOptions.func(self,button,name);
				end;
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
		if (mod.onevent and mod.events) or (mod.onupdate) then
			mod.eventFrame=CreateFrame("Frame");
			mod.eventFrame.modName = name;
			if type(mod.onevent)=="function" and type(mod.events)=="table" then
				mod.eventFrame:SetScript("OnEvent",mod.onevent);
				mod.onevent(mod.eventFrame,"BE_UPDATE_CFG");
				mod.onevent(mod.eventFrame,"BE_UPDATE_CLICKOPTION");
				for _, e in pairs(mod.events) do
					if e=="ADDON_LOADED" then
						mod.onevent(mod.eventFrame,e,addon);
					elseif e=="PLAYER_LOGIN" and ns.eventPlayerEnteredWorld then -- for later enabled modules
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
