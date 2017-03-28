
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "GuildLog" -- L["GuildLog"]
local ttName,ttColumns,tt,createMenu = name.."TT",4
local type2locale = {
	["invite"]	= C("cyan",CALENDAR_STATUS_INVITED),
	["join"]	= C("green",LFG_LIST_APP_INVITE_ACCEPTED),
	["promote"]	= C("yellow",L["Promoted"]),
	["demote"]	= C("orange",L["Demoted"]),
	["remove"]	= C("red",L["Removed"]),
	["quit"]	= C("red",L["Left the guild"]),
}
local logs = {};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\icons\\inv_misc_note_05",coords={0.05,0.95,0.05,0.95}}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show last entries of the guild log"],
	events = {
		"PLAYER_ENTERING_WORLD",
		"GUILD_ROSTER_UPDATE",
		"GUILD_EVENT_LOG_UPDATE"
		-- guild roster update or so...
	},
	updateinterval = nil, -- 10
	config_defaults = {
		max_entries = 0,
		displayMode = "NORMAL",
		hideJoin = false,
		hideLeave = false,
		hideRemove = false,
		hideInvite = false,
		hidePromote = false,
		hideDemote = false,
		showRealms = true
	},
	config_allowed = nil,
	config_header = nil, -- use default header
	config_broker = {"minimapButton"},
	config_tooltip = {
		{ type="toggle", name="hideInvite",  label=L["Hide invites"],    tooltip=L["Hide all entries with 'Invite' as action."] },
		{ type="toggle", name="hideJoin",    label=L["Hide joins"],      tooltip=L["Hide all entries with 'Join' as action."] },
		{ type="toggle", name="hidePromote", label=L["Hide promotions"], tooltip=L["Hide all entries with 'Promote' as action."] },
		{ type="toggle", name="hideDemote",  label=L["Hide demotions"],  tooltip=L["Hide all entries with 'Demote' as action."] },
		{ type="toggle", name="hideLeave",   label=L["Hide leaves"],     tooltip=L["Hide all entries with 'Leave' as action."] },
		{ type="toggle", name="hideRemove",  label=L["Hide removes"],    tooltip=L["Hide all entries with 'Remove' as action."] },
		{ type="separator" },
		{ type="toggle", name="showRealm",  label=L["Show realm names"], tooltip=L["Show realm names after character names from other realms (connected realms)."] },
		{ type="slider", name="max_entries", label=L["Show max. entries"], tooltip=L["Select the maximum number of entries from the guild log, otherwise drag to 'All'."],
			minText = ACHIEVEMENTFRAME_FILTER_ALL,
			default = 0,
			min = 0,
			max = 100,
			format = "%d",
			step = 1,
			rep = {[0]=ACHIEVEMENTFRAME_FILTER_ALL}
		},
		{ type="select", name="displayMode", label=L["Display mode"], tooltip=L["Change the list style."],
			values	= {
				["NORMAL"]    = L["Normal list of log entries"],
				["SPLIT"]    = L["Separate tables by actions and 'Show max. entries' used per table."],
			},
			default = "BOTTOM"
		},
	},
	config_misc = nil,
	clickOptions = {
		["1_open_guild"] = {
			cfg_label = "Open guild roster", -- L["Open guild roster"]
			cfg_desc = "open the guild roster", -- L["open the guild roster"]
			cfg_default = "_LEFT",
			hint = "Open guild roster", -- L["Open guild roster"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleGuildFrame")
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu",
			cfg_desc = "open the option menu",
			cfg_default = "_RIGHT",
			hint = "Open option menu",
			func = function(self,button)
				local _mod=name;
				createMenu(self)
			end
		}
	}

}


--------------------------
-- some local functions --
--------------------------
function createMenu(parent)
	if (tt~=nil) and (tt:IsShown()) then tt:Hide(); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(parent);
end

local function showRealm(Char)
	local Name,Realm,_ = strsplit("-", Char);
	if ns.profile[name].showRealm and Realm then
		if type(Realm)=="string" and Realm:len()>0 then
			_,Realm = ns.LRI:GetRealmInfo(Realm);
		end
		return Name..C("ltgray","-")..C("dkyellow",Realm);
	end
	return Name..(Realm and C("dkyellow","*") or "");
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...
	local doHide = {
		["join"] = ns.profile[name].hideJoin==true,
		["quit"] = ns.profile[name].hideLeave==true,
		["invite"] = ns.profile[name].hideInvite==true,
		["promote"] = ns.profile[name].hidePromote==true,
		["demote"] = ns.profile[name].hideDemote==true,
		["remove"] = ns.profile[name].hideRemove==true
	}

	local limit,nolimit,tLimit = tonumber(ns.profile[name].max_entries),false;
	tLimit = limit;
	if (limit==0) then limit = #logs; nolimit=true; end
	if (limit > #logs) then limit = #logs; end

	tt:Clear();
	if (ns.profile[name].displayMode=="NORMAL") then

		local l=tt:AddHeader(C("dkyellow",L[name]));
		if(not nolimit)then
			tt:SetCell(l,2,C("dkyellow","(" .. L["latest %d entries"]:format(tLimit) .. ")"),nil,"RIGHT",ttColumns-1);
		end
		l=nil;

		tt:AddSeparator(4,0,0,0,0);
		tt:AddLine(
			C("ltblue",L["Action"]),
			C("ltblue",CHARACTER),
			C("ltblue",L["By"]),
			C("ltblue",L["Recently"])
		);
		tt:AddSeparator();


		for num=1, limit do
			if (not doHide[logs[num].type]) then
				local act = type2locale[logs[num].type];
				if (logs[num].type=="promote" or logs[num].type=="demote") then
					act = act .. " ("..logs[num].rank..")";
				end
				tt:AddLine(
					act,
					showRealm(logs[num].char),
					(logs[num].by) and showRealm(logs[num].by) or "",
					logs[num].recent
				);
			end
		end
	elseif (ns.profile[name].displayMode=="SPLIT") then
		local actions,_ = {"invite","join","promote","demote","remove","quit"};
		tt:AddHeader(C("dkyellow",L[name]));

		for _,action in ipairs(actions) do
			if (not doHide[action]) then
				tt:AddSeparator(4,0,0,0,0);
				tt:AddHeader(type2locale[action] .. ((not nolimit) and " ("..L["latest %d entries"]:format(tLimit)..")" or ""));
				if (action=="demote") or (action=="promote") then
					tt:AddLine(
						C("ltblue",CHARACTER),
						C("ltblue",L["By"]),
						C("ltblue",L["New rank"]),
						C("ltblue",L["Recently"])
					);
				else
					tt:AddLine(
						C("ltblue",CHARACTER),
						(action~="quit" and action~="join") and C("ltblue",L["By"]) or "",
						"",
						C("ltblue",L["Recently"])
					);
				end
				tt:AddSeparator();
				local c = 0;
				for num=1, #logs do
					if (logs[num].type==action) and (c<limit) then
						local ch,r = strsplit("-",logs[num].char);
						if (ns.profile[name].showRealm) then
							ch = ch..(r and C("dkyellow","*") or "");
						else
							ch = ch..(r and C("gray","-")..C("dkyellow",r) or "");
						end
						tt:AddLine(
							showRealm(logs[num].char),
							(logs[num].by) and showRealm(logs[num].by) or "",
							(logs[num].type=="promote" or logs[num].type=="demote") and logs[num].rank or "",
							logs[num].recent
						);
						c=c+1;
					end
				end
				if (c==0) then
					ns.AddSpannedLine(tt,L["No log entries found..."]);
				end
			end
		end
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.clickOptions.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end



------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules[name].init = function() end

ns.modules[name].onevent = function(self,event,msg)
	if (event=="PLAYER_ENTERING_WORLD") or (event=="GUILD_ROSTER_UPDATE") then
		QueryGuildEventLog();
	elseif (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	elseif (event=="GUILD_EVENT_LOG_UPDATE") then
		wipe(logs);
		local numEvents = GetNumGuildEvents();
		local cY,cM,cD,cH = strsplit(".",date("%Y.%m.%d.%H"));
		local type, player1, player2, rank, year, month, day, hour,key;
		for i = numEvents, 1, -1 do
			type, player1, player2, rank, year, month, day, hour = GetGuildEventInfo(i);

			if (type=="join") or (type=="quit") then
				tinsert(logs,{
					type = type,
					char = player1 or UNKNOWN,
					recent = RecentTimeDate(year, month, day, hour),
					time = time({year=cY-year,month=cM-month,day=cD-day,hour=cH-hour,min=0,sec=0})
				});
			else
				tinsert(logs,{
					type = type,
					char = player2 or UNKNOWN,
					by = player1 or UNKNOWN,
					rank = rank,
					recent = RecentTimeDate(year, month, day, hour),
					time = time({year=cY-year,month=cM-month,day=cD-day,hour=cH-hour,min=0,sec=0})
				});
			end
		end
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tt) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "LEFT", "LEFT", "RIGHT"},{false},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end
