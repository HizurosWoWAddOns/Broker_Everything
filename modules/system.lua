
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name_sys,name_fps,name_traf,name_lat,name_mem,name_rlm = "System","FPS","Traffic","Latency","Memory","Realm";
-- L["Traffic"] L["Latency"] L["Memory"]
-- L["ModDesc-System"] L["ModDesc-FPS"] L["ModDesc-Traffic"] L["ModDesc-Latency"] L["ModDesc-Memory"] L["ModDesc-Realm"]
local ttNameSys, ttColumnsSys, ttSys  = name_sys .."TT",2;
local ttNameFPS, ttColumnsFPS, ttFPS  = name_fps .."TT",2;
local ttNameTraf,ttColumnsTraf,ttTraf = name_traf.."TT",2;
local ttNameLat, ttColumnsLat, ttLat  = name_lat .."TT",2;
local ttNameMem, ttColumnsMem, ttMem  = name_mem .."TT",3;
local ttNameRlm, ttColumnsRlm, ttRlm  = name_rlm .."TT",2;
local module_sys,module_fps,module_lat,module_mem,module_traf,module_rlm
local latency = {home={cur=0,min=99999,max=0,his={},curStr="",minStr="",maxStr="",brokerStr=""},world={cur=0,min=9999,max=0,his={},curStr="",minStr="",maxStr="",brokerStr=""}};
local traffic = {inCur=0,inMin=99999,inMax=0,outCur=0,outMin=99999,outMax=0,inCurStr="",inMinStr="",inMaxStr="",outCurStr="",outMinStr="",outMaxStr="",inHis={},outHis={}};
local fps     = {cur=0,min=-5,max=0,his={},curStr="",minStr="",maxStr=""};
local memory  = {cur=0,min=0,max=0,his={},list={},curStr="",minStr="",maxStr="",brokerStr="",numAddOns=0,loadedAddOns=0};
local netStatTimeout,memoryTimeout,enabled,module,isHooked,memUpdateLock=1,2,{};
local version, build, buildDate, interfaceVersion = GetBuildInfo();
local GetAddOnMecmoryUsage = GetAddOnMemoryUsage or C_AddOns.GetAddOnMemoryUsage;
local addonpanels,updateAllTicker,memUpdateLocked = {};
local triggerUpdateToken = {};
local addonpanels_select = {["none"]=L["None (disable right click)"]};
local clickOptionsRename = {
	["options"] = "2_optionpanel",
	["addons"] = "3_addonlist",
	["menu"] = "4_open_menu",
	--["memoryusage"] = "5_update_memoryusage"
};
local clickOptions = {
	["1_garbage"] = false, -- deprecated option. false should automatically remove savedvariables entry
	["options"] = "OptionPanel",
	["addons"] = {"Addon list","module","addonpanel"}, -- L["Addon list"]
	-- toggle netstats
	["menu"] = "OptionMenu",
	-- ["memoryusage"] = {"Update memory usage","direct",function() end }
};
local clickOptionsDefaults = {
	options = "_LEFT",
	addons = "__NONE",
	--memoryusage = "__NONE",
	menu = "_RIGHT"
};
local addonGroups = {
	["^DBM%-"] = "Deadly Boss Mod",
	["^Auc%:"] = "Auctioneer",
	["^Altoholic"] = "Altoholic",
	["^DataStore"] = "Altoholic",
}


-- register icon names and default files --
-------------------------------------------
I[name_sys] = {iconfile=ns.media.."latency"}; --IconName::System--
I[name_fps..'_yellow'] = {iconfile=ns.media.."fps_yellow"}	--IconName::FPS_yellow--
I[name_fps..'_red']    = {iconfile=ns.media.."fps_red"}	--IconName::FPS_red--
I[name_fps..'_blue']   = {iconfile=ns.media.."fps_blue.png"}	--IconName::FPS_blue--
I[name_fps..'_green']  = {iconfile=ns.media.."fps_green.png"}	--IconName::FPS_green--
I[name_lat] = {iconfile=ns.media.."latency"}; --IconName::Latency--
I[name_mem] = {iconfile=ns.media.."memory"}; --IconName::Memory--
I[name_traf] = {iconfile=ns.media.."memory"}; --IconName::Traffic--
I[name_rlm] = {iconfile=ns.media.."server128"} --IconName::Realm--


-- some local functions --
--------------------------
local function checkAddonManager()
	addonpanels["Blizzard's Addons Panel"] = function(chk) if (chk) then local AddonList = _G["AddonList"]; return (AddonList); end if (AddonList:IsShown()) then AddonList:Hide(); else AddonList:Show(); end end;
	addonpanels_select["Blizzard's Addons Panel"] = "Blizzard's Addons Panel";
	addonpanels["ACP"] = function(chk) if (chk) then return (C_AddOns.IsAddOnLoaded("ACP")); end ACP:ToggleUI() end
	addonpanels["Ampere"] = function(chk) if (chk) then return (C_AddOns.IsAddOnLoaded("Ampere")); end Settings.OpenToCategory("Ampere"); end
	addonpanels["OptionHouse"] = function(chk) if (chk) then return (C_AddOns.IsAddOnLoaded("OptionHouse")); end OptionHouse:Open(1) end
	addonpanels["stAddonManager"] = function(chk) if (chk) then return (C_AddOns.IsAddOnLoaded("stAddonManager")); end stAddonManager:LoadWindow() end
	addonpanels["BetterAddonList"] = function(chk) if (chk) then return (C_AddOns.IsAddOnLoaded("BetterAddonList")); end end
	local panelstates,d,s = {};
	local addonname,title,notes,loadable,reason,security,newVersion = 1,2,3,4,5,6,7;
	for i=1, C_AddOns.GetNumAddOns() do
		d = {C_AddOns.GetAddOnInfo(i)};
		s = (C_AddOns.GetAddOnEnableState(ns.player.name,i)>0);
		if (addonpanels[d[addonname]]) and (s) then
			addonpanels_select[d[addonname]] = d[title];
		end
	end
end

local function addonpanel(self,button)
	local ap = ns.profile[name_sys].addonpanel;
	if (ap~="none") then
		if (ap~="Blizzard's Addons Panel") then
			if not C_AddOns.IsAddOnLoaded(ap) then C_AddOns.LoadAddOn(ap) end
		end
		if (addonpanels[ap]) and (addonpanels[ap](true)) then
			addonpanels[ap]();
		end
	end
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
	local num = tostring(fps[k]);
	if ns.profile[name_fps].fillCharacter~="0none" then
		local chr = {
			["1zero"] = "0",
			["2blank"] = " ",
			["3undercore"] = "_"
		}
		num = strrep(chr[ns.profile[name_fps].fillCharacter] or "",3-strlen(num))..num;
	end
	fps[k.."Str"] = C( (fps[k]<18 and "red") or (fps[k]<24 and "orange") or (fps[k]<30 and "dkyellow") or (fps[k]<100 and "green") or (fps[k]<160 and "ltblue") or (fps[k]<200 and "ltviolet") or "violet", num ) .. ns.suffixColour("fps");
end

local function latencyStr(a,b)
	latency[a][b.."Str"] =  C( (latency[a][b]<40 and "ltblue") or (latency[a][b]<120 and "green") or (latency[a][b]<250 and "dkyellow") or (latency[a][b]<400 and "orange") or (latency[a][b]<1200 and "red") or "violet", ns.FormatLargeNumber(name_traf,latency[a][b]) ) .. ns.suffixColour("ms");
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
	fps.cur = floor(GetFramerate() or 0);
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
	memoryTimeout = 0;
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

local function resetMemUpdateLock()
	memUpdateLocked = false;
end

local memUpdateLocked2 = false;
local function memUpdateHook()
	-- second update lock for execution of UpdateAddOnMemoryUsage by other addons.
	memUpdateLocked2 = true
	C_Timer.After(3.14159,function() memUpdateLocked2 = false end)
end

-- local function updateRealm() end

if UpdateAddOnMemoryUsage then
	hooksecurefunc("UpdateAddOnMemoryUsage",memUpdateHook)
elseif C_AddOns.UpdateAddOnMemoryUsage then
	hooksecurefunc(C_AddOns,"UpdateAddOnMemoryUsage",memUpdateHook);
end

local function updateMemory(updateToken)
	-- against too often triggered UpdateAddOnMemoryUsage.
	if (IsInInstance() and enabled.sys_mod and ns.profile[name_sys].updateIntervalNotInInstance)
	or (IsInInstance() and enabled.mem_mod and ns.profile[name_mem].updateIntervalNotInInstance)
	or memUpdateLocked then return end

	memUpdateLocked = true;
	C_Timer.After(25, resetMemUpdateLock);
	--
	setMemoryTimeout();
	if not (enabled.sys_mod or enabled.mem_mod) then return end
	if updateToken==triggerUpdateToken and not memUpdateLocked2 then
		if UpdateAddOnMemoryUsage then
			securecall("UpdateAddOnMemoryUsage")
		elseif C_AddOns.UpdateAddOnMemoryUsage then
			securecall("C_AddOns.UpdateAddOnMemoryUsage");
		end
	end
	local num=C_AddOns.GetNumAddOns();
	local lst,grps,sum,numLoadedAddOns = {},{},0,0;
	memory.numAddOns=0;
	for i=1, num do
		local Name = C_AddOns.GetAddOnInfo(i);
		local IsLoaded = C_AddOns.IsAddOnLoaded(Name);

		local group = nil;
		for pat,gName in pairs(addonGroups)do
			if Name:find(pat) then
				group = gName;
				break;
			end
		end

		if not group then
			if IsLoaded then
				local tmp = {name=Name,cur=floor(ns.deprecated.C_AddOns.GetAddOnMemoryUsage(i)*1000),min=0,max=0,curStr="",minStr="",maxStr=""};
				min(tmp,"min","cur");
				max(tmp,"max","cur");
				memoryStr(tmp,"cur");
				memoryStr(tmp,"min");
				memoryStr(tmp,"max");
				sum = sum + tmp.cur;
				tinsert(lst,tmp);
			end
			memory.numAddOns=memory.numAddOns+1;
		else
			if grps[group]==nil then
				grps[group] = {name=group,cur=0,min=0,max=0,curStr="",minStr="",maxStr=""};
				memory.numAddOns=memory.numAddOns+1;
			end
			if IsLoaded then
				grps[group].cur=grps[group].cur+floor(ns.deprecated.C_AddOns.GetAddOnMemoryUsage(i)*1000);
			end
		end
	end
	for _,grp in pairs(grps)do
		if grp.cur>0 then
			min(grp,"min","cur");
			max(grp,"max","cur");
			memoryStr(grp,"cur");
			memoryStr(grp,"min");
			memoryStr(grp,"max");
			sum = sum + grp.cur;
			tinsert(lst,grp);
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
	if not (tt and tt.key and tt.key==ttName) then return end -- don't override other LibQTip tooltips...
	local allHidden=true;
	if tt.lines~=nil then tt:Clear(); end
	local headerLine = tt:AddHeader(C("dkyellow",L[name]))
	if name_sys==name then
		if ns.profile[name].showFpsInTooltip then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",FPS_ABBR..HEADER_COLON),fps.curStr);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Min."]..HEADER_COLON),fps.minStr);
			tt:AddLine(C("ltyellow",L["Max."]..HEADER_COLON),fps.maxStr);
			allHidden=false;
		end
		if ns.profile[name].showLatencyInTooltip then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Latency"].." ("..L["Home"].."):"), latency.home.curStr);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Min."] .. HEADER_COLON), latency.home.minStr);
			tt:AddLine(C("ltyellow",L["Max."] .. HEADER_COLON), latency.home.maxStr);

			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Latency"].." ("..L["World"].."):"), latency.world.curStr);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Min."] .. HEADER_COLON), latency.world.minStr);
			tt:AddLine(C("ltyellow",L["Max."] .. HEADER_COLON), latency.world.maxStr);
			allHidden=false;
		end
		if ns.profile[name].showTrafficInTooltip then
			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Traffic"].." ("..L["Inbound"].."):"),traffic.inCurStr);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Min."] .. HEADER_COLON), traffic.inMinStr);
			tt:AddLine(C("ltyellow",L["Max."] .. HEADER_COLON), traffic.inMaxStr);

			tt:AddSeparator(4,0,0,0,0);
			tt:AddLine(C("ltblue",L["Traffic"].." ("..L["Outbound"].."):"),traffic.outCurStr);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",L["Min."] .. HEADER_COLON), traffic.outMinStr);
			tt:AddLine(C("ltyellow",L["Max."] .. HEADER_COLON), traffic.outMaxStr);
			allHidden=false;
		end
		if ns.profile[name].showMemoryUsageInTooltip then
			tt:AddSeparator(4,0,0,0,0);
			tt:SetCell(tt:AddLine(),1,C("ltblue",L["AddOns and memory"]),nil,nil,0);
			tt:AddSeparator();
			if IsInInstance() and ns.profile[name].updateIntervalNotInInstance then
				tt:SetCell(tt:AddLine(),1,C("orange",L["SystemUpdateInInstancesInfo"]),nil,nil,ttColumnsSys)
			else
				tt:AddLine(C("ltyellow",L["Loaded AddOns"]..HEADER_COLON), memory.loadedAddOns.."/"..memory.numAddOns);
				tt:AddLine(C("ltyellow",L["Memory usage"]..HEADER_COLON), memory.curStr);

				local num = _G.min(#memory.list,ns.profile[name].numDisplayAddOns);
				if num==0 then num=_G.min(#memory.list,1000); end
				table.sort(memory.list,function(a,b) return a.cur>b.cur; end);

				tt:AddSeparator(4,0,0,0,0);
				tt:SetCell(tt:AddLine(),1,C("ltblue",L[#memory.list==num and "Loaded AddOns" or "Top %d AddOns in memory usage"]:format(num)),nil,nil,ttColumnsSys);
				tt:AddSeparator();
				for i=1, num do
					tt:AddLine(C("ltyellow",memory.list[i].name),memory.list[i].curStr);
				end
			end
			allHidden=false;
		end
		if ns.profile[name].showRealmInTooltip then
			if ns.profile[name].showRealmConnection then
			end
		end
		if ns.profile[name].showClientInfoInTooltip then
			tt:AddSeparator(4,0,0,0,0);
			tt:SetCell(tt:AddLine(),1,C("ltblue",L["Client info"]),nil,nil,0);
			tt:AddSeparator();
			tt:AddLine(C("ltyellow",GAME_VERSION_LABEL..HEADER_COLON),version.."  ");
			tt:AddLine(C("ltyellow",L["Build version"]..HEADER_COLON),build.."  ");
			tt:AddLine(C("ltyellow",L["Build date"]..HEADER_COLON),buildDate.."  ");
			tt:AddLine(C("ltyellow",L["Interface version"]..HEADER_COLON),interfaceVersion.."  ");
			tt:AddLine(C("ltyellow",L["Locale code"]..HEADER_COLON),ns.locale.."  ");
			allHidden=false;
		end
		if allHidden then
			tt:AddLine(C("violet",L["Oops... You have all 'In tooltip' options disabled. :)"]));
		end
		if (ns.profile.GeneralOptions.showHints) then
			tt:AddSeparator(4,0,0,0,0)
			ns.ClickOpts.ttAddHints(tt,name_sys);
		end

	elseif name_fps==name then
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",REFORGE_CURRENT..HEADER_COLON),fps.curStr);
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",L["Min."]..HEADER_COLON),fps.minStr);
		tt:AddLine(C("ltyellow",L["Max."]..HEADER_COLON),fps.maxStr);

	elseif name_lat==name then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgreen",L["Home"]),nil,"CENTER",ttColumnsLat);
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",REFORGE_CURRENT..HEADER_COLON),latency.home.curStr);
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",L["Min."] .. HEADER_COLON), latency.home.minStr);
		tt:AddLine(C("ltyellow",L["Max."] .. HEADER_COLON), latency.home.maxStr);
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgreen",L["World"]),nil,"CENTER",ttColumnsLat);
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",REFORGE_CURRENT..HEADER_COLON),latency.world.curStr);
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",L["Min."] .. HEADER_COLON), latency.world.minStr);
		tt:AddLine(C("ltyellow",L["Max."] .. HEADER_COLON), latency.world.maxStr);

	elseif name_mem==name then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(C("ltgreen",L["Addon"])),2,C("ltgreen",L["Memory usage"]),nil,nil,2);
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
		tt:SetCell(l,1,L["Total Memory usage"]..HEADER_COLON,nil,nil,2);
		tt:SetCell(l,3,memory.curStr,nil,nil,1);
		if (ns.profile.GeneralOptions.showHints) then
			tt:AddSeparator(4,0,0,0,0)
			ns.ClickOpts.ttAddHints(tt,name_mem);
		end

	elseif name_traf==name then
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgreen",L["Inbound / Download"]),nil,"CENTER",ttColumnsTraf);
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",REFORGE_CURRENT..HEADER_COLON),traffic.inCurStr);
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",L["Min."] .. HEADER_COLON), traffic.inMinStr);
		tt:AddLine(C("ltyellow",L["Max."] .. HEADER_COLON), traffic.inMaxStr);
		tt:AddSeparator(4,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("ltgreen",L["Outbound / Upload"]),nil,"CENTER",ttColumnsTraf);
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltblue",REFORGE_CURRENT..HEADER_COLON),traffic.outCurStr);
		tt:AddSeparator();
		tt:AddLine(C("ltyellow",L["Min."] .. HEADER_COLON), traffic.outMinStr);
		tt:AddLine(C("ltyellow",L["Max."] .. HEADER_COLON), traffic.outMaxStr);

	elseif name_rlm==name then
		tt:SetCell(headerLine,2,"|T".. ns.media.."server128"..":64:64:0:0|t",nil,"RIGHT",0)
		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(C("ltyellow",REFORGE_CURRENT), C("ltblue",ns.realm))
		local label = C("ltyellow",L["Connected with:"])
		local short = ns.realms[ns.realm]
		local tmp = {}
		for k in ns.pairsByKeys(ns.realms) do
			if k~=short and k~=ns.realm and ns.realm_shorts[k]==nil then
				tinsert(tmp,k)
			end
		end
		if #tmp>0 then
			tt:AddSeparator();
		end
		if #tmp>=4 then
			for i=1, #tmp, 2 do
				if tmp[i] then
					tt:AddLine(label, C("green",tmp[i]))
					if tmp[i+1] then
						label = C("green",tmp[i+1]);
					end
				end
			end
		else
			for i=1, #tmp do
				if tmp[i] then
					tt:AddLine(label, C("green",tmp[i]))
					label = ""
				end
			end
		end
	end

	if not update then
		ns.roundupTooltip(tt);
	end
end

local function updateAll()
	if not (enabled.sys_mod or enabled.fps_mod or enabled.lat_mod or enabled.mem_mod or enabled.rlm_mod) then return; end

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
			-- for debugging
			-- try to get the list of addons in lua errors like 'script ran too long' :-/
			local activeAddOns,numActiveAddOns,numAddOns = {},0,C_AddOns.GetNumAddOns();
			for i=1, numAddOns do local n=C_AddOns.GetAddOnInfo(i); if C_AddOns.IsAddOnLoaded(n) then tinsert(activeAddOns,n) end end
			numActiveAddOns,activeAddOns = #activeAddOns,table.concat(activeAddOns,",");

			updateMemory(triggerUpdateToken);
		else
			memoryTimeout=memoryTimeout-1;
		end
	end

	-- update realm
	-- if enabled.rlm_mod then
	-- 	updateRealm();
	-- end

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

		if ns.profile[name_sys].showRealmOnBroker then
			tinsert(broker,ns.realm)
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

		ns.LDB:GetDataObjectByName(module_sys.ldbName).text = #broker>0 and table.concat(broker," ") or CHAT_MSG_SYSTEM;

		if ttSys~=nil and ttSys.key~=nil and ttSys.key==ttNameSys and ttSys:IsShown() then
			createTooltip(ttSys, name_sys, ttNameSys, true);
		end
	end

	if enabled.fps_mod then
		ns.LDB:GetDataObjectByName(module_fps.ldbName).text = fps.curStr~="" and fps.curStr or L[name_fps];

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

		ns.LDB:GetDataObjectByName(module_lat.ldbName).text = #broker>0 and table.concat(broker," ") or L[name_lat];

		if ttLat~=nil and ttLat.key~=nil and ttLat.key==ttNameLat and ttLat:IsShown() then
			createTooltip(ttLat, name_lat, ttNameLat, true);
		end
	end

	if enabled.mem_mod then
		ns.LDB:GetDataObjectByName(module_mem.ldbName).text = memory.curStr~="" and memory.curStr or L[name_mem];

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

		ns.LDB:GetDataObjectByName(module_traf.ldbName).text = #broker>0 and table.concat(broker," ") or L[name_traf];

		if ttTraf~=nil and ttTraf.key~=nil and ttTraf.key==ttNameTraf and ttTraf:IsShown() then
			createTooltip(ttTraf, name_traf, ttNameTraf, true);
		end
	end
end

local function init()
	if updateAllTicker then
		return;
	end
	updateAllTicker = C_Timer.NewTicker(2,updateAll);
end

-- module variables for registration --
---------------------------------------
module_sys = {
	events = {
		"PLAYER_LOGIN",
	},
	config_defaults = {
		enabled = true,
		-- broker button options
		showInboundOnBroker = false,
		showOutboundOnBroker = false,
		showWorldOnBroker = true,
		showHomeOnBroker = true,
		showFpsOnBroker = true,
		showMemoryUsageOnBroker = true,
		showAddOnsCountOnBroker = false,
		showRealmOnBroker = true,
		showClientVersionOnBroker = false,
		showClientBuildOnBroker = false,
		showInterfaceVersionOnBroker = false,

		-- tooltip options
		showTrafficInTooltip = true,
		showLatencyInTooltip = true,
		showFpsInTooltip = true,
		showMemoryUsageInTooltip = true,
		showRealmInTooltip = true,
		showRealmConnection = true,
		showClientInfoInTooltip = true,
		numDisplayAddOns = 10,

		-- misc
		addonpanel = "none",
		updateInterval = 300,
		updateIntervalNotInInstance = false,
	},
	clickOptions = clickOptions
};

module_fps = {
	icon_suffix = "_blue",
	events = {
		"PLAYER_LOGIN",
	},
	config_defaults = {
		enabled = false,
		fillCharacter = "0none"
	},
};

module_lat = {
	events = {
		"PLAYER_LOGIN",
	},
	config_defaults = {
		enabled = false,
		showHome = true,
		showWorld = true
	},
};

module_mem = {
	events = {
		"PLAYER_LOGIN",
	},
	config_defaults = {
		enabled = false,
		mem_max_addons = -1,
		addonpanel = "none",
		updateInterval = 300,
		updateIntervalNotInInstance = false,
	},
	clickOptions = clickOptions
}

module_traf = {
	events = {
		"PLAYER_LOGIN",
	},
	config_defaults = {
		enabled = false,
		showInbound = true,
		showOutbound = true
	},
}

module_rlm = {
	config_defaults = {
		enabled = true
	}
}

ns.ClickOpts.addDefaults(module_sys,clickOptionsDefaults);
ns.ClickOpts.addDefaults(module_mem,clickOptionsDefaults);

module_sys.addonpanel = addonpanel;
module_mem.addonpanel = addonpanel;

local function addUpdateInterval(opt,addHeader,order)
	if type(addHeader)=="number" then
		if addHeader==2 then
			opt["updateIntervalSeparator0"]={ type="separator", order=order };
		end
		opt["header"]={ type="header", name=L["Memory usage"], order=order+1 };
		opt['updateIntervalSeparator1'] = { type="separator", order=order+2 };
		order=order+3;
	end

	opt['updateInterval'] = { type="select", order=order+3, name=L["SystemUpdateInterval"], desc=L["SystemUpdateIntervalDesc"],
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
	};

	opt['updateIntervalDesc']={ type="description", order=order+4, name="|n"..table.concat({
			C("orange",L["SystemUpdateIntervalDescLong1"]),
			C("white", L["SystemUpdateIntervalDescLong2"]),
			C("yellow",L["SystemUpdateIntervalDescLong3"])
		},"|n|n"), fontSize="medium"
	}

	opt['updateIntervalNotInInstance'] = {
		type = "toggle", order=order+5,
		name = L["SystemUpdateInInstances"],
		desc = L["SystemUpdateInInstancesDesc1"].."|n|n"..C("ltgreen",L["SystemUpdateInInstancesDesc2"])
	}

	return order+6
end

function module_sys.options()
	local opt = {
		broker = {
			showInboundOnBroker  = { type="toggle", order=1, name=L["Inbound traffic"],  desc=L["Display inbound traffic on broker"] },
			showOutboundOnBroker = { type="toggle", order=2, name=L["Outbound traffic"], desc=L["Display outbound traffic on broker"] },

			showWorldOnBroker    = { type="toggle", order=3, name=L["World latency"],    desc=L["Display world latency on broker"] },
			showHomeOnBroker     = { type="toggle", order=4, name=L["Home latency"],     desc=L["Display home latency on broker"] },

			showFpsOnBroker      = { type="toggle", order=5, name=L["FPS"],              desc=L["Display fps on broker"] },

			showMemoryUsageOnBroker = { type="toggle", order=6, name=L["Memory usage"],  desc=L["Display memory usage on broker"] },
			showAddOnsCountOnBroker = { type="toggle", order=7, name=ADDONS,             desc=L["Display addon count on broker"] },

			showRealmOnBroker       = { type="toggle", order=8, name=L["Realm"], desc=L["SystemRealmOnBrokerDesc"]},

			showClientVersionOnBroker    = { type="toggle", order=9, name=L["Client version"],    desc=L["Display client version on broker"] },
			showClientBuildOnBroker      = { type="toggle", order=10, name=L["Client build"],      desc=L["Display client build number on broker"] },
			showInterfaceVersionOnBroker = { type="toggle", order=11, name=L["Interface version"], desc=L["Display interface version on broker"] },
		},
		tooltip = {
			showTrafficInTooltip     = { type="toggle", order=1, name=L["Traffic"],      desc=L["Display traffic in tooltip"] },
			showLatencyInTooltip     = { type="toggle", order=2, name=L["Latency"],      desc=L["Display latency in tooltip"] },
			showFpsInTooltip         = { type="toggle", order=3, name=L["FPS"],          desc=L["Display fps in tooltip"] },
			showMemoryUsageInTooltip = { type="toggle", order=4, name=L["Memory usage"], desc=L["Display memory usage in tooltip"] },
			showRealmInTooltip       = { type="toggle", order=5, name=L["Realm"],        desc=L["SystemRealmShowTTDesc"] },
			showClientInfoInTooltip  = { type="toggle", order=6, name=L["Client info"],  desc=L["Display client info in tooltip"] },
			numDisplayAddOns         = { type="range",  order=7, name=ADDONS, desc=L["Select the maximum number of addons to display, otherwise drag to 'All'."], step = 1, min = 0, max = 100},
		},
		misc = {},
	}
	addUpdateInterval(opt.misc,1,1);
	return opt;
end

function module_lat.options()
	return {
		broker = {
			showHome={ type="toggle", order=1, name=L["Home latency"],  desc=L["Display home latency"] },
			showWorld={ type="toggle", order=2, name=L["World latency"], desc=L["Display world latency"] }
		},
		tooltip = nil,
		misc = nil,
	}
end

function module_mem.options()
	local opt = {
		tooltip = {
			mem_max_addons={ type="range", name=L["Number of addons"], desc=L["Select the maximum number of addons to display, otherwise drag to '0' to display all."], step = 1, min = 0, max = 100}
		},
		misc = {
			shortNumbers=0,
			addonpanel={ type="select", order=1, name=L["Addon panel"], desc=L["Choose your addon panel that opens if you rightclick on memory broker or disable the right click option."], values=addonpanels_select, width="double" },
		},
	}
	addUpdateInterval(opt.misc,2,10)
	return opt;
end

function module_fps.options()
	return {
		misc = {
			fillCharacter={ type="select", order=1, name=L["Prepend character"], desc=L["Prepend a character to fill displayed fps up to 3 character."], width="double",
				values = {
					["0none"] = NONE.."/"..ADDON_DISABLED,
					["1zero"] = L["0 (zero) > [060 fps]"],
					["2blank"] = L["blank > [ 60 fps]"],
					["3undercore"] = L["_ (undercore) > [_60 fps]"]
				}
			}
		},
	}
end

function module_traf.options()
	return {
		misc = {
			shortNumbers=1,
		}
	}
end

--function module_rlm.options() end

function module_sys.init()
	enabled.sys_mod = true;
	enabled.fps_sys = (ns.profile[name_sys].showFpsOnBroker or ns.profile[name_sys].showFpsInTooltip);
	enabled.lat_sys = (ns.profile[name_sys].showWorldOnBroker or ns.profile[name_sys].showHomeOnBroker or ns.profile[name_sys].showLatencyInTooltip);
	enabled.mem_sys = (ns.profile[name_sys].showMemoryUsageOnBroker or ns.profile[name_sys].showAddOnsCountOnBroker or ns.profile[name_sys].showMemoryUsageInTooltip);
	enabled.traf_sys= (ns.profile[name_sys].showInboundOnBroker or ns.profile[name_sys].showOutboundOnBroker or ns.profile[name_sys].showTrafficInTooltip);
	enabled.rlm_sys = (ns.profile[name_sys].showRealmOnBroker or ns.profile[name_sys].showRealmInTooltip)
end

function module_fps.init()
	enabled.fps_mod=true;
end

function module_lat.init()
	enabled.lat_mod=true;
end

function module_mem.init()
	enabled.mem_mod=true;
end

function module_traf.init()
	enabled.traf_mod=true;
end

function module_rlm.init()
	enabled.rlm_mod=true;
end

function module_sys.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name_sys);
	elseif event=="PLAYER_LOGIN" then
		init();
	end
end

function module_mem.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name_mem);
	elseif event=="PLAYER_LOGIN" then
		init();
	end
end

function module_fps.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name_fps);
	elseif event=="PLAYER_LOGIN" then
		init();
	end
end

function module_lat.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name_lat);
	elseif event=="PLAYER_LOGIN" then
		init();
	end
end

function module_traf.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name_traf);
	elseif event=="PLAYER_LOGIN" then
		init();
	end
end

function module_rlm.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name_rlm);
	elseif event=="PLAYER_LOGIN" then
		init();
	end
end

-- function module_*.optionspanel(panel) end
-- function module_*.onmousewheel(self,direction) end
-- function module_*.ontooltip(tt) end

function module_sys.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttSys = ns.acquireTooltip({ttNameSys, ttColumnsSys, "LEFT","RIGHT", "RIGHT"},{true},{self});
	createTooltip(ttSys, name_sys, ttNameSys);
end

function module_fps.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttFPS = ns.acquireTooltip({ttNameFPS, ttColumnsFPS, "LEFT","RIGHT", "RIGHT"},{true},{self});
	createTooltip(ttFPS, name_fps, ttNameFPS);
end

function module_lat.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttLat = ns.acquireTooltip({ttNameLat, ttColumnsLat, "LEFT","RIGHT", "RIGHT"},{true},{self});
	createTooltip(ttLat, name_lat, ttNameLat);
end

function module_mem.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttMem = ns.acquireTooltip({ttNameMem, ttColumnsMem, "LEFT","RIGHT", "RIGHT"},{false},{self});
	createTooltip(ttMem, name_mem, ttNameMem);
end

function module_traf.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttTraf = ns.acquireTooltip({ttNameTraf, ttColumnsTraf, "LEFT","RIGHT", "RIGHT"},{true},{self});
	createTooltip(ttTraf, name_traf, ttNameTraf);
end

function module_rlm.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	ttRlm = ns.acquireTooltip({ttNameRlm, ttColumnsRlm, "LEFT","RIGHT", "RIGHT"},{true},{self});
	createTooltip(ttRlm, name_rlm, ttNameRlm);
end

-- function module_*.onleave(self) end
-- function module_*.onclick(self,button) end
-- function module_*.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name_sys] = module_sys;
ns.modules[name_fps] = module_fps;
ns.modules[name_lat] = module_lat;
ns.modules[name_mem] = module_mem;
ns.modules[name_traf] = module_traf;
ns.modules[name_rlm] = module_rlm;
