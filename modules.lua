local addon, ns = ...;
local L = ns.L;
local pairs,type=pairs,type;

ns.modules = {};
local queue,queue_ticker = {};

local function queue_ticker_func()
	local mod
	if #queue>0 then
		mod = ns.modules[tremove(queue,1)];
		mod.onevent(mod.eventFrame,"PLAYER_LOGIN");
	elseif queue_ticker then
		queue_ticker:Cancel();
		queue_ticker = nil;
	end
end

function ns.modulePLQueueInit()
	queue_ticker = C_Timer.NewTicker(0.001,queue_ticker_func);
	ns.modulePLQueueInit = nil;
end

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

-- [force] - used by child modules to enable core module (like gps and followers)
local function moduleInit(name, force)
	if not ns.modules[name] then return end

	if ns.profile[name] and (ns.profile[name].enabled==true or force) then
		local mod = ns.modules[name];

		mod.isEnabled = true;

		-- module init
		if mod.init then
			mod.init();
			mod.init = nil;
		end

		if not mod.isHiddenModule then
			-- new clickOptions system
			local onclick;
			if (type(mod.clickOptions)=="table") then
				local active = ns.ClickOpts.update(name);
				if active then
					function onclick(self,button)
						ns.ClickOpts.func(self,button,name);
					end
				end
			elseif (type(mod.onclick)=="function") then
				onclick = mod.onclick;
			end

			-- LDB init
			if (not mod.onenter) and mod.ontooltip then
				mod.ontooltipshow = mod.ontooltip;
			end

			if not mod.iconName then
				mod.iconName = name;
			end
			local icon = ns.I(mod.iconName .. (mod.icon_suffix or ""));
			local iColor = ns.profile.GeneralOptions.iconcolor;
			local ldbOblectTable = {
				-- button data
				type          = "data source",
				label         = L[name],
				text          = L[name],
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
			};

			mod.ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name;
			mod.obj = ns.LDB:NewDataObject(mod.ldbName,ldbOblectTable);
			if not mod.obj then -- another addon has used the same name for registration
				mod.ldbName = "BE.."..mod.ldbName;
				mod.obj = ns.LDB:NewDataObject(mod.ldbName,ldbOblectTable);
			end

			ns.updateIcons(name);

			-- is possible that
			if mod.obj then
				-- register minimap button
				ns.toggleMinimapButton(name);
			end
		end

		-- event handling
		if (mod.onevent and mod.events) or (mod.onupdate) then
			if not mod.noEventFrame then
				mod.eventFrame=CreateFrame("Frame");
			else
				-- table as dummy to execute following BE_UPDATE_CFG, VARIABLES_LOADED and PLAYER_LOGIN only
				mod.eventFrame={};
			end
			mod.eventFrame.modName = name;
			if type(mod.onevent)=="function" and type(mod.events)=="table" then
				mod.eventFrame:SetScript("OnEvent",mod.onevent);
				mod.onevent(mod.eventFrame,"BE_UPDATE_CFG");
				if mod.clickOptions then
					mod.onevent(mod.eventFrame,"BE_UPDATE_CFG","ClickOpt");
				end
				for _, e in pairs(mod.events) do
					if e=="VARIABLES_LOADED" then
						mod.onevent(mod.eventFrame,e,addon);
					elseif (e=="PLAYER_LOGIN" and ns.eventPlayerEnteredWorld) then
						mod.onevent(mod.eventFrame,e);
					end
					if e=="PLAYER_LOGIN" then
						tinsert(queue,name);
					else
						mod.eventFrame:RegisterEvent(e);
					end
				end
			end
		end

		-- timeout function
		if type(mod.ontimeout)=="function" and type(mod.timeout)=="number" and mod.timeout>0 then
			C_Timer.After(mod.timeout,mod.ontimeout);
		end

		-- onupdate function
		-- frame script OnUpdate ticking too fast... C_Timer is better
		if type(mod.onupdate)=="function" and type(mod.onupdate_interval)=="number" and mod.onupdate_interval>0 then
			mod.onupdate_ticker = C_Timer.NewTicker(mod.onupdate_interval,mod.onupdate);
		end

		-- chat command registration
		if (mod.chatcommands) then
			for k,v in pairs(mod.chatcommands) do
				if (type(k)=="string") then
					-- Example: ns.AddChatCommand("<string>",{desc="<string>",func=function()end});
					ns.AddChatCommand(k,v);
				end
			end
		end
	end
end

-- in core.lua on event ADDON_LOADED or option panel
function ns.moduleInit(name,force)
	if (name) then
		-- enable module by name
		ns.Options_RegisterModule(name);
		ns.Options_RegisterDefaults();
		moduleInit(name,force);
	else
		-- enable all registered modules
		for name, data in pairs(ns.modules) do
			ns.Options_RegisterModule(name);
		end
		ns.Options_RegisterDefaults();
		for name, data in pairs(ns.modules) do
			moduleInit(name);
		end
	end
end
