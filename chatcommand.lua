
-- some usefull namespace to locals
local addon, ns = ...
local C, L = ns.LC.color, ns.L

--
-- Chat command handler
--

ns.commands = {
	options     = {
		desc = L["Open options panel"],
		func = function()
			-- double call. Thanks blizz for ignoring direct open custom option panels on first use.
			InterfaceOptionsFrame_OpenToCategory(ns.be_option_panel);
			InterfaceOptionsFrame_OpenToCategory(ns.be_option_panel);
		end,
	},
	broker = "options",
	config = "options",
	max_addons  = {
		desc = L["Change number of displayed addons in module memory."],
		func = function(arg)
			Broker_EverythingDB["Memory"].max_addons = tonumber(arg)
			if Broker_EverythingDB["Memory"].max_addons > 0 then
				ns.print(L["Cfg"], L["Showing a maximum of %d addons."]:format(Broker_EverythingDB["Memory"].mem_max_addons))
			else
				ns.print(L["Cfg"], L["Showing all addons."])
			end
		end,
	},
	reset       = {
		desc = L["Reset all module settings"],
		func = function()
			Broker_EverythingDB.reset = true
			ReloadUI()
		end,
	},
	global      = {
		desc = L["Switch between global and per character saved settings"],
		func = function()
			if not Broker_EverythingGlobalDB.global or Broker_EverythingGlobalDB.global == false then
				if Broker_EverythingGlobalDB["Clock"] == nil then
					Broker_EverythingGlobalDB = Broker_EverythingDB
				end			
				Broker_EverythingGlobalDB.global = true
			else
				Broker_EverythingGlobalDB.global = false
			end 
			ns.print(L["Cfg"], L["Broker_Everything will use the new setting on next reload."])
		end,
	},
	list        = {
		desc = L["List of available modules with his status"],
		func = function()
			ns.print(L["Cfg"], L["Data modules:"])
			for k, v in pairs(Broker_EverythingDB) do
				if ns.modules[k]~=nil and ns.modules[k].noBroker==true then
					-- do nothing ^^
				elseif not (v == true or v == false or v == 1 or v == 0) then
					local stat = {"red","Off"}
					if Broker_EverythingDB[k].enabled == true then
						stat = {"green","On"}
					end
					ns.print(L["Cfg"], (k==L[k] and "%s | %s" or "%s | %s - ( %s )"):format(C(stat[1],stat[2]),C("ltyellow",k),L[k]))
				end
			end
		end,
	},
	tooltip     = {
		desc = L["Enable/disable tooltip scaling."],
		func = function()
			if Broker_EverythingDB.tooltipScale == true then
				Broker_EverythingDB.tooltipScale = false
			else
				Broker_EverythingDB.tooltipScale = true
			end
		end,
	},
	scaling = "tooltip",
	hidehint = {
		desc = L["Hide/Show tooltip hint."],
		func = function()
		end,
	},
	equip = {
		desc = L["Equip a set."],
		func = function(cmd)
			local num = GetNumEquipmentSets()
			if cmd == nil then
				ns.print(L["Equipment"],L["Usage: /be equip <SetName>"])
				ns.print(L["Equipment"],L["Available Sets:"])

				if num~=0 then
					for i=1, num do
						local eName, icon, setID, isEquipped, totalItems, equippedItems, inventoryItems, missingItems, ignoredSlots = GetEquipmentSetInfo(i)
						ns.print(L["Equipment"],C((isEquipped and "yellow") or (missingItems>0 and "red") or "ltblue",eName))
					end
				else
					ns.print(L["Equipment"],L["No sets found"])
				end
			else
				for i=1, GetNumEquipmentSets() do
					local eName, _, _, isEquipped, _, _, _, _ = GetEquipmentSetInfo(i)
					if cmd==eName then validEquipment = true end
				end
				if (not validEquipment) then
					ns.print(L["Equipment"],L["Name of Equipmentset are invalid"])
				else
					ns.toggleEquipment(cmd)
				end
			end
		end
	},
	version = {
		desc = L["Display current version of Broker_Everything"],
		func = function()
			ns.print(GAME_VERSION_LABEL,GetAddOnMetadata(addon,"Version"));
		end
	}
}

SlashCmdList["BROKER_EVERYTHING"] = function(cmd)
	local cmd, arg = strsplit(" ", cmd, 2)
	cmd = cmd:lower()

	if cmd=="" then
		ns.print(L["Info"], L["Chat command list for /be & /broker_everything"])
		local cmds = {};
		for i,v in pairs(ns.commands)do tinsert(cmds,i); end
		table.sort(cmds);
		for _,name in pairs(cmds) do
			local obj = ns.commands[name];
			if type(obj)=="string" then
				ns.print(L["Info"], ("%s - alias of %s"):format(C("yellow",name),C("yellow",obj)))
			else
				ns.print(L["Info"], ("%s - %s"):format(C("yellow",name),obj.desc))
			end
		end
		return
	end

	if ns.commands[cmd]~=nil and type(ns.commands[cmd])=="string" then
		cmd = ns.commands[cmd];
	end

	if ns.commands[cmd]~=nil and type(ns.commands[cmd].func)=="function" then
		ns.commands[cmd].func(arg);
	end

	cmd = cmd:gsub("^%l", string.upper)
	for k, v in pairs(Broker_EverythingDB) do
		if k == cmd then
			local x = Broker_EverythingDB[cmd].enabled
			print(tostring(x))
			if x == true then
				Broker_EverythingDB[cmd].enabled = false
				print(tostring(Broker_EverythingDB[cmd].enabled))
					ns.print(L["Cfg"], L["Disabling %s on next reload."]:format(cmd)) -- cmd
				else
					Broker_EverythingDB[cmd].enabled = true
					ns.print(L["Cfg"], L["Enabling %s on next reload."]:format(cmd)) -- cmd
			end
		end
	end

end


SLASH_BROKER_EVERYTHING1 = "/broker_everything"
SLASH_BROKER_EVERYTHING2 = "/be"

