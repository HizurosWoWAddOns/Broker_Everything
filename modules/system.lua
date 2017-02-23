
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
L.System = SYSTEMOPTIONS_MENU;


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name_sys,name_fps,name_traf,name_lat,name_mem = "System","FPS","Traffic","Latency","Memory";
-- L["Traffic"] L["Latency"] L["Memory"]
local ldbNameSys, ttNameSys, ttColumnsSys, ttSys  = name_sys, name_sys .."TT",2;
local ldbNameFPS, ttNameFPS, ttColumnsFPS, ttFPS  = name_fps, name_fps .."TT",2;
local ldbNameTraf,ttNameTraf,ttColumnsTraf,ttTraf = name_traf,name_traf.."TT",2;
local ldbNameLat, ttNameLat, ttColumnsLat, ttLat  = name_lat, name_lat .."TT",2;
local ldbNameMem, ttNameMem, ttColumnsMem, ttMem  = name_mem, name_mem .."TT",3;

local GetNetStats,GetFramerate,GetNumAddOns,GetAddOnMemoryUsage,GetAddOnInfo = GetNetStats,GetFramerate,GetNumAddOns,GetAddOnMemoryUsage,GetAddOnInfo;

local latency = {home={cur=0,min=99999,max=0,his={},curStr="",minStr="",maxStr="",brokerStr=""},world={cur=0,min=9999,max=0,his={},curStr="",minStr="",maxStr="",brokerStr=""}};
local traffic = {inCur=0,inMin=99999,inMax=0,outCur=0,outMin=99999,outMax=0,inCurStr="",inMinStr="",inMaxStr="",outCurStr="",outMinStr="",outMaxStr="",inHis={},outHis={}};
local fps     = {cur=0,min=-5,max=0,his={},curStr="",minStr="",maxStr=""};
local memory  = {cur=0,min=0,max=0,his={},list={},curStr="",minStr="",maxStr="",brokerStr="",numAddOns=0,loadedAddOns=0};
local PEW,netStatTimeout,memoryTimeout,enabled,createMenu,isHooked=false,1,2,{};
local version, build, buildDate, interfaceVersion = GetBuildInfo();

local addonpanels = {};
local addonpanels_select = {["none"]=L["None (disable right click)"]};
do
	if (ns.build>=60000000) then
		-- BetterAddonList
		addonpanels["Blizzard's Addons Panel"] = function(chk) if (chk) then return (_G.AddonList); end if (_G.AddonList:IsShown()) then _G.AddonList:Hide(); else _G.AddonList:Show(); end end;
		addonpanels_select["Blizzard's Addons Panel"] = "Blizzard's Addons Panel";
	end
	addonpanels["ACP"] = function(chk) if (chk) then return (IsAddOnLoaded("ACP")); end ACP:ToggleUI() end
	addonpanels["Ampere"] = function(chk) if (chk) then return (IsAddOnLoaded("Ampere")); end InterfaceOptionsFrame_OpenToCategory("Ampere"); InterfaceOptionsFrame_OpenToCategory("Ampere"); end
	addonpanels["OptionHouse"] = function(chk) if (chk) then return (IsAddOnLoaded("OptionHouse")); end OptionHouse:Open(1) end
	addonpanels["stAddonManager"] = function(chk) if (chk) then return (IsAddOnLoaded("stAddonManager")); end stAddonManager:LoadWindow() end
	addonpanels["BetterAddonList"] = function(chk) if (chk) then return (IsAddOnLoaded("BetterAddonList")); end end
	local panelstates,d,s = {};
	local addonname,title,notes,loadable,reason,security,newVersion = 1,2,3,4,5,6,7;
	for i=1, GetNumAddOns() do
		d = {GetAddOnInfo(i)};
		s = (GetAddOnEnableState(ns.player.name,i)>0);
		--panelstates[d[addonname]] = nil -- nil = not present, false = present but not loaded yet, true = present and loaded
		if (addonpanels[d[addonname]]) and (s) then
			addonpanels_select[d[addonname]] = d[title];
		end
	end
end
local clickOptions = {
	["1_garbage"] = {
		cfg_label = "Collect garbage", -- L["Collect garbage"]
		cfg_desc = "collect garbage", -- L["collect garbage"]
		cfg_default = "__NONE",
		hint = "Collect garbage", -- L["Collect garbage"]
		func = function(self,button)
			local _mod=name_sys;
			ns.print(L["Collecting Garbage..."]);
			collectgarbage("collect");
		end
	},
	["2_optionpanel"] = {
		cfg_label = "Open option panel", -- L["Open option panel"]
		cfg_desc = "open the option panel", -- L["open the option panel"]
		cfg_default = "_LEFT",
		hint = "Open option panel", -- L["Open option panel"]
		func = function(self,button)
			local _mod=name_sys;
			InterfaceOptionsFrame_OpenToCategory(ns.be_option_panel);
			InterfaceOptionsFrame_OpenToCategory(ns.be_option_panel);
		end
	},
	["3_addonlist"] = {
		cfg_label = "Open addon list", -- L["Open addon list"]
		cfg_desc = "open addon list", -- L["open addon list"]
		cfg_default = "__NONE",
		hint = "Open addon list", -- L["Open addon list"]
		func = function(self,button)
			local _mod=name_sys;
			local ap = ns.profile[name_sys].addonpanel;
			if (ap~="none") then
				if (ap~="Blizzard's Addons Panel") then
					if not IsAddOnLoaded(ap) then LoadAddOn(ap) end
				end
				if (addonpanels[ap]) and (addonpanels[ap](true)) then
					addonpanels[ap]();
				end
			end
		end
	},
	-- toggle netstats
	["4_open_menu"] = {
		cfg_label = "Open option menu",
		cfg_desc = "open the option menu",
		cfg_default = "_RIGHT",
		hint = "Open option menu",
		func = function(self,button)
			local _mod=name_sys;
			createMenu(self, _mod);
		end
	},
	["5_update_memoryusage"] = {
		cfg_label = "Update memory usage",
		cfg_desc = "update memory usage",
		cfg_default = "__NONE",
		hint = "Update memory usage manually",
		func = function(self,button)
			local _mod=name_sys;
			createMenu(self, _mod);
		end
	}
};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name_sys] = {iconfile="Interface\\Addons\\"..addon.."\\media\\latency"}; --IconName::System--
I[name_fps..'_yellow'] = {iconfile="Interface\\Addons\\"..addon.."\\media\\fps_yellow"}	--IconName::FPS_yellow--
I[name_fps..'_red']    = {iconfile="Interface\\Addons\\"..addon.."\\media\\fps_red"}	--IconName::FPS_red--
I[name_fps..'_blue']   = {iconfile="Interface\\Addons\\"..addon.."\\media\\fps_blue.png"}	--IconName::FPS_blue--
I[name_fps..'_green']  = {iconfile="Interface\\Addons\\"..addon.."\\media\\fps_green.png"}	--IconName::FPS_green--
I[name_lat] = {iconfile="Interface\\Addons\\"..addon.."\\media\\latency"}; --IconName::Latency--
I[name_mem] = {iconfile="Interface\\Addons\\"..addon.."\\media\\memory"}; --IconName::Memory--
I[name_traf] = {iconfile="Interface\\Addons\\"..addon.."\\media\\memory"}; --IconName::Memory--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules.system_core = {
	noBroker = true,
	noOptions = true,
	events = {"PLAYER_ENTERING_WORLD"},
	updateinterval = 1
};

ns.modules[name_sys] = {
	desc = L["Broker to show system infos like fps, traffic, latency and memory in broker and tooltip"],
	label = CHAT_MSG_SYSTEM,
	events = {},
	updateinterval = nil,
	config_defaults = {
		-- broker button options
		showInboundOnBroker = true,
		showOutboundOnBroker = true,
		showWorldOnBroker = true,
		showHomeOnBroker = true,
		showFpsOnBroker = true,
		showMemoryUsageOnBroker = true,
		showAddOnsCountOnBroker = true,
		showClientVersionOnBroker = false,
		showClientBuildOnBroker = false,
		showInterfaceVersionOnBroker = false,

		-- tooltip options
		showTrafficInTooltip = true,
		showLatencyInTooltip = true,
		showFpsInTooltip = true,
		showMemoryUsageInTooltip = true,
		showClientInfoInTooltip = true,
		numDisplayAddOns = 10,

		-- misc
		addonpanel = "none",
		updateInterval = 300,
		collectGarbage = true
	},
	config_allowed = {
		updateInterval = {[0]=true,[30]=true,[60]=true,[300]=true,[600]=true,[1200]=true,[2400]=true,[3600]=true}
	},
	config = {
		{ type="header", label=CHAT_MSG_SYSTEM, align="left", icon=I[name_sys] },
		{ type="separator", alpha=0 },
		{ type="header", label=L["Broker button options"], align="center" },
		{ type="separator", inMenuInvisible=true },
		{ type="toggle", name="showInboundOnBroker",     label=L["Show inbound traffic"],  tooltip=L["Display inbound traffic on broker"] },
		{ type="toggle", name="showOutboundOnBroker",    label=L["Show outbound traffic"], tooltip=L["Display outbound traffic on broker"] },
		{ type="toggle", name="showWorldOnBroker",       label=L["Show world latency"],    tooltip=L["Display world latency on broker"] },
		{ type="toggle", name="showHomeOnBroker",        label=L["Show home latency"],     tooltip=L["Display home latency on broker"] },
		{ type="toggle", name="showFpsOnBroker",         label=L["Show fps"],              tooltip=L["Display fps on broker"] },
		{ type="toggle", name="showMemoryUsageOnBroker", label=L["Show memory usage"],     tooltip=L["Display memory usage on broker"] },
		{ type="toggle", name="showAddOnsCountOnBroker", label=L["Show addons"],           tooltip=L["Display addon count on broker"] },

		{ type="toggle", name="showClientVersionOnBroker",    label=L["Show client version"],    tooltip=L["Display client version on broker"] },
		{ type="toggle", name="showClientBuildOnBroker",      label=L["Show client build"],      tooltip=L["Display client build number on broker"] },
		{ type="toggle", name="showInterfaceVersionOnBroker", label=L["Show interface version"], tooltip=L["Display interface version on broker"] },

		{ type="separator", alpha=0 },
		{ type="header", label=L["Tooltip options"], align="center" },
		{ type="separator", inMenuInvisible=true },
		{ type="toggle", name="showTrafficInTooltip",     label=L["Show traffic"],      tooltip=L["Display traffic in tooltip"] },
		{ type="toggle", name="showLatencyInTooltip",     label=L["Show latency"],      tooltip=L["Display latency in tooltip"] },
		{ type="toggle", name="showFpsInTooltip",         label=L["Show fps"],          tooltip=L["Display fps in tooltip"] },
		{ type="toggle", name="showMemoryUsageInTooltip", label=L["Show memory usage"], tooltip=L["Display memory usage in tooltip"] },
		{ type="toggle", name="showClientInfoInTooltip",  label=L["Show client info"], tooltip=L["Display client info in tooltip"] },
		{ type="slider", name="numDisplayAddOns",         label=L["Show addons in tooltip"], tooltip=L["Select the maximum number of addons to display, otherwise drag to 'All'."],
			minText = ACHIEVEMENTFRAME_FILTER_ALL,
			default = 10,
			step = 5,
			min = 0,
			max = 100,
			format = "%d",
			rep = {[0]=ACHIEVEMENTFRAME_FILTER_ALL}
		},
		{ type="select", name="updateInterval", label=L["Update interval"], tooltip=L["Change the update interval or disable it."],
			default = 300,
			values = {
				[0] = DISABLE,
				[30] = L["All 30 seconds"],
				[60] = L["One time per minute"],
				[300] = L["All 5 minutes"],
				[600] = L["All 10 minutes"],
				[1200] = L["All 20 minutes"],
				[2400] = L["All 40 minutes"],
				[3600] = L["One time per hour"]
			}
		},
		{ type="toggle", name="collectGarbage", label=L["Collect garbage on update"], tooltip=L["Collect garbage on any update of memory usage"] }
	},
	clickOptions = clickOptions
};

ns.modules[name_fps] = {
	desc = L["Broker to show your frames per second in broker button and current session min/max in tooltip"],
	icon_suffix = "_blue",
	events = {},
	updateinterval = nil,
	config_defaults = {
		fillCharacter = "0none",
	},
	config_allowed = nil,
	config = {
		{ type="header", label=FPS_ABBR, align="left", icon=I[name_fps..'_blue'] },
		{ type="separator", alpha=0 },
		{ type="select", name="fillCharacter", label=L["Prepend character"], tooltip=L["Prepend a character to fill displayed fps up to 3 character."],
			values = {
				["0none"] = NONE.."/"..ADDON_DISABLED,
				["1zero"] = L["0 (zero) > [060 fps]"],
				["2blank"] = L["blank > [ 60 fps]"],
				["3undercore"] = L["_ (undercore) > [_60 fps]"]
			}
		}
	}
};

ns.modules[name_lat] = {
	desc = L["Broker to show current home and world latency"],
	events = {},
	updateinterval = nil,
	config_defaults = {
		showHome = true,
		showWorld = true
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=L[name_lat], align="left", icon=I[name_lat] },
		{ type="separator" },
		{ type="toggle", name="showHome",  label=L["Show home"],  tooltip = L["Enable/Disable the display of the latency to the home realm"] },
		{ type="toggle", name="showWorld", label=L["Show world"], tooltip = L["Enable/Disable the display of the latency to the world realms"] }
	}
};

ns.modules[name_mem] = {
	desc = L["Broker to show memory usage summary and single addons usage"],
	events = {},
	updateinterval = nil,
	config_defaults = {
		mem_max_addons = -1,
		addonpanel = "none",
		updateInterval = 300,
		collectGarbage = true
	},
	config_allowed = {
		updateInterval = {[0]=true,[30]=true,[60]=true,[300]=true,[600]=true,[1200]=true,[2400]=true,[3600]=true}
	},
	config = {
		{ type="header", label=L[name_mem], align="left", icon=I[name_mem] },
		{ type="separator" },
		{ type="slider", name="mem_max_addons", label=L["Show addons in tooltip"], tooltip=L["Select the maximum number of addons to display, otherwise drag to 'All'."],
			minText = ACHIEVEMENTFRAME_FILTER_ALL,
			default = -1,
			min = -1,
			max = 100,
			format = "%d",
			rep = {[-1]=ACHIEVEMENTFRAME_FILTER_ALL}
		},
		{ type="select", name="addonpanel", label=L["Addon panel"], tooltip=L["Choose your addon panel that opens if you rightclick on memory broker or disable the right click option."], default = "none", values = addonpanels_select },
		{ type="separator", alpha=0 },
		{ type="header", label=L["Memory usage"], align="center" },
		{ type="separator" },
		{ type="select", name="updateInterval", label=L["Update interval"], tooltip=L["Change the update interval or disable it."],
			default = 300,
			values = {
				[0] = DISABLE,
				[30] = L["All 30 seconds"],
				[60] = L["One time per minute"],
				[300] = L["All 5 minutes"],
				[600] = L["All 10 minutes"],
				[1200] = L["All 20 minutes"],
				[2400] = L["All 40 minutes"],
				[3600] = L["One time per hour"]
			}
		},
		{ type="toggle", name="collectGarbage", label=L["Collect garbage on update"], tooltip=L["Collect garbage on any update of memory usage"] },
		{ type="desc", text="|n"..table.concat({
				C("orange",L["Any update of the addon memory usage can cause results in fps drops and 'Script ran too long' error messages!"]),
				C("white",L["The necessary time to collect memory usage of all addons depends on CPU speed, CPU usage, the number of running addons and other factors."]),
				C("yellow",L["If you have more than one addon to display memory usage it is recommended to disable the update interval of this addon."])
			},"|n|n")
		},
	},
	clickOptions = clickOptions
}

ns.modules[name_traf] = {
	desc = L["Broker to show the traffic between blizzard and your game client"],
	icon_suffix = "_blue",
	events = {},
	updateinterval = nil,
	config_defaults = {
		showInbound = true,
		showOutbound = true
	},
	config_allowed = nil,
	config = { { type="header", label=L[name_traf], align="left", icon=I[name_traf..'_blue'] } }
}


--------------------------
-- some local functions --
--------------------------
function createMenu(parent,name)
	if not name then return end
	if (tt) and (tt.key) and (tt.key==name.."TT") then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	-- additional elements...?
	--if name then
		ns.EasyMenu.addConfigElements(name,nil,true);
	--end
	ns.EasyMenu.ShowMenu(parent);
end

local function prependHistory(t,n,l)
	local l = type(l)=="number" and l+1 or 51;
	tinsert(t,1,n);
	if(#t==l)then tremove(t,l); end
end

local function min(t,k1,k2)
	t[k1] = _G.min(t[k1],t[k2]);
end

local function max(t,k1,k2)
	t[k1] = _G.max(t[k1],t[k2]);
end

local function formatBytes(bytes, precision)
	local units,i = {'b','kb','mb','gb'},1;
	bytes = _G.max(bytes,0);
	while bytes>1000 do
		bytes,i = bytes/1000,i+1;
	end
	return ("%0."..( (i==1 and 0) or precision or 1).."f"):format(bytes), units[i] or "b";
end

local function fpsStr(k)
	local num = fps[k];
	if ns.profile[name_fps].fillCharacter~="0none" then
		local chr = {
			["1zero"] = "0",
			["2blank"] = " ",
			["3undercore"] = "_"
		}
		num = strrep(chr[ns.profile[name_fps].fillCharacter],3-strlen(num))..num;
	end
	fps[k.."Str"] = C( (fps[k]<18 and "red") or (fps[k]<24 and "orange") or (fps[k]<30 and "dkyellow") or (fps[k]<100 and "green") or (fps[k]<160 and "ltblue") or (fps[k]<200 and "ltviolet") or "violet", num ) .. ns.suffixColour("fps");
end

local function latencyStr(a,b)
	latency[a][b.."Str"] =  C( (latency[a][b]<40 and "ltblue") or (latency[a][b]<120 and "green") or (latency[a][b]<250 and "dkyellow") or (latency[a][b]<400 and "orange") or (latency[a][b]<1200 and "red") or "violet", ns.FormatLargeNumber(name,latency[a][b]) ) .. ns.suffixColour("ms");
end

local function trafficStr(k)
	local value, suffix = formatBytes(traffic[k]);
	traffic[k.."Str"] = value..""..ns.suffixColour(suffix.."/s");
end

local function memoryStr(t,k)
	local value, suffix = formatBytes(t[k],2);
	t[k.."Str"] = value..""..ns.suffixColour(suffix);
end

local function updateFPS()
	fps.cur = floor(GetFramerate());
	if fps.min<-1 then
		fps.min=fps.min+1;
	elseif fps.min==-1 then
		fps.min=fps.cur;
	else
		min(fps,"min","cur");
	end
	max(fps,"max","cur");
	--prependHistory(fps.his,fps.cur,50);
	fpsStr("cur");
	fpsStr("min");
	fpsStr("max");
end

local function updateNetStats()
	if netStatTimeout>0 then netStatTimeout=netStatTimeout-1; return end
	netStatTimeout=10;

	traffic.inCur, traffic.outCur, latency.home.cur, latency.world.cur = GetNetStats();
	traffic.inCur = floor(traffic.inCur*1000);
	traffic.outCur = floor(traffic.outCur*1000);

	min(traffic,"inMin","inCur");
	max(traffic,"inMax","inCur");
	min(traffic,"outMin","outCur");
	max(traffic,"outMax","outCur");

	min(latency.home,"min","cur");
	max(latency.home,"max","cur");
	min(latency.world,"min","cur");
	max(latency.world,"max","cur");

	--prependHistory(traffic.inHis,traffic.inCur,50);
	--prependHistory(traffic.outHis,traffic,outCur,50);
	--prependHistory(latency.home.his,latency.home.cur,50);
	--prependHistory(latency.world.his,latency.world.cur,50);

	latencyStr("home","cur");
	latencyStr("home","min");
	latencyStr("home","max");
	latencyStr("world","cur");
	latencyStr("world","min");
	latencyStr("world","max");

	trafficStr("inCur");
	trafficStr("inMin");
	trafficStr("inMax");
	trafficStr("outCur");
	trafficStr("outMin");
	trafficStr("outMax");
end

local function setMemoryTimeout()
	local interval={};
	memoryTimeout = false;
	if enabled.mem_sys then
		tinsert(interval,ns.profile[name_sys].updateInterval);
	end
	if enabled.mem_mod then
		tinsert(interval,ns.profile[name_mem].updateInterval);
	end
	if #interval>0 then
		memoryTimeout = math.min(unpack(interval));
	end
end

local function updateMemory()
	--memoryTimeout = 60;
	setMemoryTimeout();
	if not (enabled.sys_mod or enabled.mem_mod) then return end
	memory.numAddOns=GetNumAddOns();
	local lst,sum,numLoadedAddOns = {},0,0;
	for i=1, memory.numAddOns do
		local Name, Title, Notes, Loadable, Reason = GetAddOnInfo(i);
		if IsAddOnLoaded(Name) then
			local tmp = {name=Name,cur=floor(GetAddOnMemoryUsage(i)*1000),min=0,max=0,curStr="",minStr="",maxStr=""};
			min(tmp,"min","cur");
			max(tmp,"max","cur");
			memoryStr(tmp,"cur");
			memoryStr(tmp,"min");
			memoryStr(tmp,"max");
			sum = sum + tmp.cur;
			tinsert(lst,tmp);
		end
	end
	memory.list = lst;
	memory.loadedAddOns=#lst;
	memory.cur = sum;
	min(memory,"min","cur");
	max(memory,"max","cur");
	memoryStr(memory,"cur");
	memoryStr(memory,"min");
	memoryStr(memory,"max");
end

local function createTooltip(tt, name, ttName, update)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	local allHidden=true;
	tt:Clear();
	tt:AddHeader(C("dkyellow",L[name]))
	if name_sys==name then
		if ns.profile[name].showFpsInTooltip then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",FPS_ABBR..":"),fps.curStr);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Min."]..":"),fps.minStr);
			tt:AddLine(C("ltyellow",L["Max."]..":"),fps.maxStr);
			allHidden=false;
		end
		if ns.profile[name].showLatencyInTooltip then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Latency"].." ("..L["Home"].."):"), latency.home.curStr);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Min."] .. ":"), latency.home.minStr);
			tt:AddLine(C("ltyellow",L["Max."] .. ":"), latency.home.maxStr);

			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Latency"].." ("..L["World"].."):"), latency.world.curStr);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Min."] .. ":"), latency.world.minStr);
			tt:AddLine(C("ltyellow",L["Max."] .. ":"), latency.world.maxStr);
			allHidden=false;
		end
		if ns.profile[name].showTrafficInTooltip then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Traffic"].." ("..L["Inbound"].."):"),traffic.inCurStr);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Min."] .. ":"), traffic.inMinStr);
			tt:AddLine(C("ltyellow",L["Max."] .. ":"), traffic.inMaxStr);

			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Traffic"].." ("..L["Outbound"].."):"),traffic.outCurStr);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Min."] .. ":"), traffic.outMinStr);
			tt:AddLine(C("ltyellow",L["Max."] .. ":"), traffic.outMaxStr);
			allHidden=false;
		end
		if ns.profile[name].showMemoryUsageInTooltip then
			tt:AddSeparator(4,0,0,0,0);
			tt:SetCell(tt:AddLine(),1,C("ltblue",L["AddOns and memory"]),nil,nil,0);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Loaded AddOns"]..":"), memory.loadedAddOns.."/"..memory.numAddOns);
			tt:AddLine(C("ltyellow",L["Memory usage"]..":"), memory.curStr);

			local num = _G.min(#memory.list,ns.profile[name_sys].numDisplayAddOns);
			if num==0 then num=_G.min(#memory.list,1000); end
			table.sort(memory.list,function(a,b) return a.cur>b.cur; end);

			tt:AddSeparator(4,0,0,0,0);
			tt:SetCell(tt:AddLine(),1,C("ltblue",L[#memory.list==num and "Loaded AddOns" or "Top %d AddOns in memory usage"]:format(num)),nil,nil,ttColumnsSys);
			tt:AddSeparator();
			for i=1, num do
				tt:AddLine(C("ltyellow",memory.list[i].name),memory.list[i].curStr);
			end
			allHidden=false;
		end
		if ns.profile[name].showClientInfoInTooltip then
			tt:AddSeparator(4,0,0,0,0);
			tt:SetCell(tt:AddLine(),1,C("ltblue",L["Client info"]),nil,nil,0);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Version"]..":"),version);
			tt:AddLine(C("ltyellow",L["Build version"]..":"),build);
			tt:AddLine(C("ltyellow",L["Build date"]..":"),buildDate);
			tt:AddLine(C("ltyellow",L["Interface version"]..":"),interfaceVersion);
			allHidden=false;
		end
		if allHidden then
			tt:AddLine(C("violet",L["Oops... You have all 'In tooltip' options disabled. :)"]));
		end
		if (ns.profile.GeneralOptions.showHints) then
			tt:AddSeparator(4,0,0,0,0)
			ns.clickOptions.ttAddHints(tt,name_sys);
		end

	elseif name_fps==name then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",REFORGE_CURRENT..":"),fps.curStr);
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",L["Min."]..":"),fps.minStr);
		tt:AddLine(C("ltyellow",L["Max."]..":"),fps.maxStr);

	elseif name_lat==name then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgreen",L["Home"]),nil,"CENTER",ttColumnsLat);
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",REFORGE_CURRENT..":"),latency.home.curStr);
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",L["Min."] .. ":"), latency.home.minStr);
		tt:AddLine(C("ltyellow",L["Max."] .. ":"), latency.home.maxStr);
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgreen",L["World"]),nil,"CENTER",ttColumnsLat);
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",REFORGE_CURRENT..":"),latency.world.curStr);
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",L["Min."] .. ":"), latency.world.minStr);
		tt:AddLine(C("ltyellow",L["Max."] .. ":"), latency.world.maxStr);

	elseif name_mem==name then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(C("ltgreen",L["Addon"])),2,C("ltgreen",L["Memory Usage"]),nil,nil,2);
		tt:AddSeparator()
		table.sort(memory.list,function(a,b) return a.cur>b.cur; end);
		local maxAddons = tonumber(ns.profile[name].mem_max_addons) or 0;
		local num = _G.min(#memory.list, maxAddons>0 and maxAddons or 1000);
		for i=1, num do
			local l = tt:AddLine()
			tt:SetCell(l,1,ns.strCut(memory.list[i].name,32),nil,nil,2);
			tt:SetCell(l,3,memory.list[i].curStr,nil,nil,1);
		end
		tt:AddSeparator();
		local l = tt:AddLine();
		tt:SetCell(l,1,L["Total Memory usage"]..":",nil,nil,2);
		tt:SetCell(l,3,memory.curStr,nil,nil,1);
		if (ns.profile.GeneralOptions.showHints) then
			tt:AddSeparator(4,0,0,0,0)
			ns.clickOptions.ttAddHints(tt,name_mem);
		end

	elseif name_traf==name then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgreen",L["Inbound / Download"]),nil,"CENTER",ttColumnsTraf);
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",REFORGE_CURRENT..":"),traffic.inCurStr);
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",L["Min."] .. ":"), traffic.inMinStr);
		tt:AddLine(C("ltyellow",L["Max."] .. ":"), traffic.inMaxStr);
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgreen",L["Outbound / Upload"]),nil,"CENTER",ttColumnsTraf);
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",REFORGE_CURRENT..":"),traffic.outCurStr);
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",L["Min."] .. ":"), traffic.outMinStr);
		tt:AddLine(C("ltyellow",L["Max."] .. ":"), traffic.outMaxStr);

	end

	if not update then
		ns.roundupTooltip(tt);
	end
end

local function updateAll()
	if not (enabled.sys_mod or enabled.fps_mod or enabled.lat_mod or enabled.mem_mod) then return; end

	-- apply hook
	if not isHooked and (enabled.sys_mod or enabled.mem_mod) then
		hooksecurefunc("UpdateAddOnMemoryUsage",updateMemory);
		isHooked = true;
	end

	-- update fps
	if enabled.fps_mod or enabled.fps_sys then
		updateFPS();
	end

	-- update network stats
	if enabled.lat_mod or enabled.lat_sys or enabled.traf_mod or enabled.traf_sys then
		updateNetStats();
	end

	-- update memmory usage
	if not InCombatLockdown() and memoryTimeout~=false and ((enabled.mem_sys and ns.profile[name_sys].updateInterval>0) or (enabled.mem_mod and ns.profile[name_mem].updateInterval>0)) then
		if memoryTimeout<=0 then
			if not ((enabled.mem_sys and not ns.profile[name_sys].collectGarbage) or (enabled.mem_mod and not ns.profile[name_mem].collectGarbage)) then
				collectgarbage("collect");
			end
			UpdateAddOnMemoryUsage();
			--> updateMemory (via hook)
				--> setMemoryTimeout
		else
			memoryTimeout=memoryTimeout-1;
		end
	end

	-- update broker buttons and visible tooltips
	if enabled.sys_mod then
		local broker = {};

		if traffic.inCurStr~="" and ns.profile[name_sys].showInboundOnBroker then
			tinsert(broker, C("white",L["In:"]) .. traffic.inCurStr);
		end

		if traffic.outCurStr~="" and ns.profile[name_sys].showOutboundOnBroker then
			tinsert(broker, C("white",L["Out:"]) .. traffic.outCurStr);
		end

		local home,world = ns.profile[name_sys].showHomeOnBroker,ns.profile[name_sys].showWorldOnBroker;
		if latency.world.curStr~="" and world then
			tinsert(broker, (home and C("white","W:") or "") .. latency.world.curStr);
		end

		if latency.home.curStr~="" and home then
			tinsert(broker, (world and C("white","H:") or "") .. latency.home.curStr);
		end

		if fps.curStr~="" and ns.profile[name_sys].showFpsOnBroker then
			tinsert(broker, fps.curStr);
		end

		if memory.curStr~="" and ns.profile[name_sys].showMemoryUsageOnBroker then
			tinsert(broker, memory.curStr);
		end

		if memory.numAddOns>0 and ns.profile[name_sys].showAddOnsCountOnBroker then
			tinsert(broker, memory.loadedAddOns.."/"..memory.numAddOns);
		end

		if ns.profile[name_sys].showClientVersionOnBroker then
			tinsert(broker,version);
		end

		if ns.profile[name_sys].showClientBuildOnBroker then
			tinsert(broker,build);
		end

		if ns.profile[name_sys].showInterfaceVersionOnBroker then
			tinsert(broker,interfaceVersion);
		end

		ns.LDB:GetDataObjectByName(ldbNameSys).text = #broker>0 and table.concat(broker," ") or CHAT_MSG_SYSTEM;

		if ttSys~=nil and ttSys.key~=nil and ttSys.key==ttNameSys and ttSys:IsShown() then
			createTooltip(ttSys, name_sys, ttNameSys, true);
		end
	end

	if enabled.fps_mod then
		ns.LDB:GetDataObjectByName(ldbNameFPS).text = fps.curStr~="" and fps.curStr or L[name_fps];

		if ttFPS~=nil and ttFPS.key~=nil and ttFPS.key==ttNameFPS and ttFPS:IsShown() then
			createTooltip(ttFPS, name_fps, ttNameFPS, true);
		end
	end

	if enabled.lat_mod then
		local broker = {};

		local home,world = ns.profile[name_lat].showHome,ns.profile[name_lat].showWorld;
		if latency.world.curStr~="" and world then
			tinsert(broker, (home and C("white","W:") or "") .. latency.world.curStr);
		end

		if latency.home.curStr~="" and home then
			tinsert(broker, (world and C("white","H:") or "") .. latency.home.curStr);
		end

		ns.LDB:GetDataObjectByName(ldbNameLat).text = #broker>0 and table.concat(broker," ") or L[name_lat];

		if ttLat~=nil and ttLat.key~=nil and ttLat.key==ttNameLat and ttLat:IsShown() then
			createTooltip(ttLat, name_lat, ttNameLat, true);
		end
	end

	if enabled.mem_mod then
		ns.LDB:GetDataObjectByName(ldbNameMem).text = memory.curStr~="" and memory.curStr or L[name_mem];

		if ttMem~=nil and ttMem.key~=nil and ttMem.key==ttNameMem and ttMem:IsShown() then
			createTooltip(ttMem, name_mem, ttNameMem, true);
		end
	end

	if enabled.traf_mod then
		local broker = {};

		if traffic.inCurStr~="" and ns.profile[name_traf].showInbound then
			tinsert(broker, C("white",L["In:"]) .. traffic.inCurStr);
		end

		if traffic.outCurStr~="" and ns.profile[name_traf].showOutbound then
			tinsert(broker, C("white",L["Out:"]) .. traffic.outCurStr);
		end

		ns.LDB:GetDataObjectByName(ldbNameTraf).text = #broker>0 and table.concat(broker," ") or L[name_traf];

		if ttTraf~=nil and ttTraf.key~=nil and ttTraf.key==ttNameTraf and ttTraf:IsShown() then
			createTooltip(ttTraf, name_traf, ttNameTraf, true);
		end
	end
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules.system_core.init = function() end

ns.modules[name_sys].init = function()
	ldbNameSys = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name_sys;
	enabled.sys_mod = true;
	enabled.fps_sys = (ns.profile[name_sys].showFpsOnBroker or ns.profile[name_sys].showFpsInTooltip);
	enabled.lat_sys = (ns.profile[name_sys].showWorldOnBroker or ns.profile[name_sys].showHomeOnBroker or ns.profile[name_sys].showLatencyInTooltip);
	enabled.mem_sys = (ns.profile[name_sys].showMemoryUsageOnBroker or ns.profile[name_sys].showAddOnsCountOnBroker or ns.profile[name_sys].showMemoryUsageInTooltip);
	enabled.traf_sys = (ns.profile[name_sys].showInboundOnBroker or ns.profile[name_sys].showOutboundOnBroker or ns.profile[name_sys].showTrafficInTooltip);
end
ns.modules[name_fps].init = function()
	ldbNameFPS = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name_fps;
	enabled.fps_mod=true;
end
ns.modules[name_lat].init = function()
	ldbNameLat = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name_lat;
	enabled.lat_mod=true;
end
ns.modules[name_mem].init = function()
	ldbNameMem = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name_mem;
	enabled.mem_mod=true;
end
ns.modules[name_traf].init = function()
	ldbNameTraf = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name_traf;
	enabled.traf_mod=true;
end

ns.modules.system_core.onevent = function(self,event,msg)
	if event=="PLAYER_ENTERING_WORLD" then
		C_Timer.NewTicker(ns.modules.system_core.updateinterval,updateAll);
		self:UnregisterEvent(event);
	end
end

ns.modules[name_sys].onevent = function(self,event,msg)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name_sys],ns.profile[name_sys]);
	end
end

ns.modules[name_mem].onevent = function(self,event,msg)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name_mem],ns.profile[name_mem]);
	end
end

-- ns.modules.system_core.optionspanel = function(panel) end
-- ns.modules.system_core.onmousewheel = function(self,direction) end
-- ns.modules.system_core.ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name_sys].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttSys = ns.acquireTooltip({ttNameSys, ttColumnsSys, "LEFT","RIGHT", "RIGHT"},{true},{self});
	createTooltip(ttSys, name_sys, ttNameSys);
end
ns.modules[name_fps].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttFPS = ns.acquireTooltip({ttNameFPS, ttColumnsFPS, "LEFT","RIGHT", "RIGHT"},{true},{self});
	createTooltip(ttFPS, name_fps, ttNameFPS);
end
ns.modules[name_lat].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttLat = ns.acquireTooltip({ttNameLat, ttColumnsLat, "LEFT","RIGHT", "RIGHT"},{true},{self});
	createTooltip(ttLat, name_lat, ttNameLat);
end
ns.modules[name_mem].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttMem = ns.acquireTooltip({ttNameMem, ttColumnsMem, "LEFT","RIGHT", "RIGHT"},{false},{self});
	createTooltip(ttMem, name_mem, ttNameMem);
end
ns.modules[name_traf].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttTraf = ns.acquireTooltip({ttNameTraf, ttColumnsTraf, "LEFT","RIGHT", "RIGHT"},{true},{self});
	createTooltip(ttTraf, name_traf, ttNameTraf);
end

--ns.modules[name_sys].onleave = function(self) end
--ns.modules[name_fps].onleave = function(self) end
--ns.modules[name_lat].onleave = function(self) end
--ns.modules[name_mem].onleave = function(self) end
--ns.modules[name_traf].onleave = function(self) end

-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

