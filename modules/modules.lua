local addon, ns = ...;
local L = ns.L;

-- ------------------------------- --
-- modules table and init function --
-- ~Hizuro                         --
-- ------------------------------- --
ns.modules = {};
ns.updateList = {};
ns.timeoutList = {};

local function moduleInit(name)

	local ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name;
	local data = ns.modules[name];

	-- module load on demand like
	if (data.enabled==nil) then
		data.enabled = true;
	end

	-- check if savedvariables for module present?
	if (Broker_EverythingDB[name]==nil) then
		Broker_EverythingDB[name] = {enabled = data.enabled};
	elseif (type(Broker_EverythingDB[name].enabled)~="boolean") then
		Broker_EverythingDB[name].enabled = data.enabled;
	end

	if (data.config_defaults) then
		for i,v in pairs(data.config_defaults) do
			if (Broker_EverythingDB[name][i]==nil) then
				Broker_EverythingDB[name][i] = v;
			elseif (data.config_allowed~=nil) and (data.config_allowed[i]~=nil) then
				if (data.config_allowed[i][Broker_EverythingDB[name][i]]~=true) then
					Broker_EverythingDB[name][i] = v;
				end
			end
		end
	end

	-- force enabled status of non Broker modules.
	if (data.noBroker) then
		data.enabled = true;
		Broker_EverythingDB[name].enabled = true;
	end

	if (Broker_EverythingDB[name].enabled==true) then
		local onclick;

		-- pre LDB init
		if data.init then
			data.init();
		end

		-- new clickOptions system
		if (type(data.clickOptions)=="table") then
			local active = ns.clickOptions.update(data,Broker_EverythingDB[name]);
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
			local iColor = Broker_EverythingDB.iconcolor;
			data.obj = ns.LDB:NewDataObject(ldbName, {

				-- button data
				type          = "data source",
				label         = data.label or L[name],
				text          = data.text or L[name],
				icon          = icon.iconfile, -- default or custom icon
				staticIcon    = icon.iconfile, -- default icon only
				iconCoords    = icon.coords or {0, 1, 0, 1},

				-- button event functions
				OnEnter       = data.onenter or nil,
				OnLeave       = data.onleave or nil,
				OnClick       = onclick,
				OnTooltipShow = data.ontooltipshow or nil
			})

			ns.updateIconColor(name);

			if (Broker_EverythingDB.libdbicon) then
				if (Broker_EverythingDB[name].dbi==nil) then
					Broker_EverythingDB[name].dbi = {};
				end
				data.dbi = ns.LDBI:Register(ldbName,data.obj,Broker_EverythingDB[name].dbi);
			end
		end

		-- event/update handling
		if (data.onevent) or (data.onupdate) then
			data.eventFrame=CreateFrame("Frame");
			data.eventFrame.modName = name;

			if (type(data.onevent)=="function") then
				data.eventFrame:SetScript("OnEvent",data.onevent);
				for _, e in pairs(data.events) do
					if (e=="ADDON_LOADED") then
						data.onevent(data.eventFrame,e,addon);
					else
						data.eventFrame:RegisterEvent(e);
					end
				end
			end

			if (type(data.onupdate)=="function") and (data.updateinterval~=nil) then
				data.eventFrame:SetScript("OnUpdate",function(self,elapse)
					if (self.elapsed==nil) then
						self.elapsed=0;
					end

					if (data.updateinterval == false) then
						data.onupdate(self,elapse);
					elseif (self.elapsed>=data.updateinterval) then
						self.elapsed = 0;
						data.onupdate(self,elapse);
					else
						self.elapsed = self.elapsed + elapse;
					end
				end);
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

		-- post LDB init
		if (data.init) then
			data.init(data);
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

ns.moduleCoexist = function()
	for name,data in pairs(ns.modules) do
		if (type(data.coexist)=="function") then
			data.coexist();
		end
	end
end
