
-- some usefull namespace to locals
local addon, ns = ...
local C, L = ns.LC.color, ns.L
local ACD = LibStub("AceConfigDialog-3.0");

--
-- Chat command handler
--
local spacer = "||"

local commands = {
	options     = {
		desc = L["Option panel"],
		func = ns.ToggleBlizzOptionPanel
	},
	broker = "options",
	config = "options",
	reset       = {
		desc = L["CmdResetInfo"],
		func = ns.resetConfigs
	},
	list        = {
		desc = L["CmdStatusInfo"],
		func = function()
			ns.print(spacer, L["Modules"])
			for k, v in ns.pairsByKeys(ns.modules) do
				if v and ns.profile[k] then
					local c,s = "red",OFF;
					if ns.profile[k].enabled==true then
						c,s = "green",L["On"];
					end
					ns.print(spacer, (k==L[k] and "%s | %s" or "%s | %s - ( %s )"):format(C(c,s),C("ltyellow",k),L[k]))
				end
			end
		end,
	},
	toggle = {
		desc = L["CmdToggleInfo"],
		func = function(arg)
			--cmd = cmd:gsub("^%l", string.upper);
			if not ns.modules[arg] then
				local lArg = arg:lower();
				for k in pairs(ns.modules)do
					if k:lower() == lArg then
						arg = k;
						break;
					end
				end
			end
			if ns.modules[arg] then
				ns.profile[arg].enabled = not ns.profile[arg].enabled;
				if ns.profile[arg].enabled then
					ns.moduleInit(arg);
					ns.print(spacer,arg,ADDON_ENABLED);
				else
					ns.print(spacer,arg,ADDON_DISABLED,L["CmdNeedReload"]);
				end
			end
		end
	},
	equip = {
		desc = L["CmdEquipInfo"],
		func = function(cmd)
			local num = C_EquipmentSet.GetNumEquipmentSets()
			if cmd == nil then
				ns.print(spacer,L["CmdEquipUsage"]);
				ns.print(spacer,L["CmdEquipSets"]);
				if num>0 then
					for i=0, num-1 do -- very rare in wow... equipment set index starts with 0 instead of 1
						local eName, icon, setID, isEquipped, totalItems, equippedItems, inventoryItems, missingItems, ignoredSlots = C_EquipmentSet.GetEquipmentSetInfo(i);
						ns.print(spacer,C((isEquipped and "yellow") or (missingItems>0 and "red") or "ltblue",eName),missingItems>0 and " - "..C("ltyellow",L["CmdEquipMiss"]:format(missingItems)) or nil);
					end
				else
					ns.print(spacer,L["No sets found"]);
				end
			else
				local validEquipment
				for i=1, C_EquipmentSet.GetNumEquipmentSets() do
					local eName, _, _, isEquipped, _, _, _, _ = C_EquipmentSet.GetEquipmentSetInfo(i)
					if cmd==eName then validEquipment = true end
				end
				if (not validEquipment) then
					ns.print(spacer,L["CmdEquipInvalid"])
				else
					ns.toggleEquipment(cmd)
				end
			end
		end
	},
	version = {
		desc = L["CmdVersion"],
		func = function()
			ns.print(GAME_VERSION_LABEL,GetAddOnMetadata(addon,"Version"));
		end
	}
}

function ns.AddChatCommand(key,data)
	if not commands[key] then
		commands[key] = data;
	end
end

function ns.RegisterSlashCommand()
	SlashCmdList["BROKER_EVERYTHING"] = function(cmd)
		local cmd, arg = strsplit(" ", cmd, 2)
		cmd = cmd:lower()

		if cmd=="" then
			ns.print(spacer, L["CmdUsage"])
			for name,obj in ns.pairsByKeys(commands) do
				if type(obj)=="string" and commands[obj] and commands[obj].desc then
					obj = commands[obj];
				end
				if obj.desc then
					ns.print(spacer, ("%s - %s"):format(C("yellow",name),obj.desc))
				end
			end
			ns.print(C("orange",L["CmdInfoOptional"]));
			return;
		end

		if commands[cmd]~=nil and type(commands[cmd])=="string" then
			cmd = commands[cmd];
		end

		if commands[cmd]~=nil and type(commands[cmd].func)=="function" then
			commands[cmd].func(arg);
			ns.print(C("orange",L["CmdInfoOptional"]));
		end
	end


	SLASH_BROKER_EVERYTHING1 = "/broker_everything"
	SLASH_BROKER_EVERYTHING2 = "/be"
end
