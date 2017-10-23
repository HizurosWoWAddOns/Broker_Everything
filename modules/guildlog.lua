
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "GuildLog" -- L["GuildLog"]
local ttName,ttColumns,tt,module = name.."TT",4
local type2locale = {
	["invite"]	= C("cyan",CALENDAR_STATUS_INVITED),
	["join"]	= C("green",LFG_LIST_APP_INVITE_ACCEPTED),
	["promote"]	= C("yellow",L["Promoted"]),
	["demote"]	= C("orange",L["Demoted"]),
	["remove"]	= C("red",L["Removed"]),
	["quit"]	= C("red",L["Left the guild"]),
}
local logs = {};


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\icons\\inv_misc_note_05",coords={0.05,0.95,0.05,0.95}} --IconName::GuildLog--


-- some local functions --
--------------------------
local function showRealm(Char)
	local Name,Realm,_ = strsplit("-", Char,2);
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

	if tt.lines~=nil then tt:Clear(); end
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
						local ch,r = strsplit("-",logs[num].char,2);
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
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
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
	clickOptionsRename = {
		["guild"] = "1_open_guild",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["guild"] = "Guild",
		["menu"] = "OptionMenu"
	}

}

ns.ClickOpts.addDefaults(module,{
	guild = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = nil,
		tooltip = {
			hideInvite={ type="toggle", order=1, name=L["Hide invites"],    desc=L["Hide all entries with 'Invite' as action."] },
			hideJoin={ type="toggle", order=2, name=L["Hide joins"],      desc=L["Hide all entries with 'Join' as action."] },
			hidePromote={ type="toggle", order=3, name=L["Hide promotions"], desc=L["Hide all entries with 'Promote' as action."] },
			hideDemote={ type="toggle", order=4, name=L["Hide demotions"],  desc=L["Hide all entries with 'Demote' as action."] },
			hideLeave={ type="toggle", order=5, name=L["Hide leaves"],     desc=L["Hide all entries with 'Leave' as action."] },
			hideRemove={ type="toggle", order=6, name=L["Hide removes"],    desc=L["Hide all entries with 'Remove' as action."] },
			--separator=true,
			showRealm={ type="toggle", order=7, name=L["Show realm names"], desc=L["Show realm names after character names from other realms (connected realms)."] },
			max_entries={ type="range", order=8, name=L["Show max. entries"], desc=L["Select the maximum number of entries from the guild log, otherwise drag to 'All'."],
				--minText = ACHIEVEMENTFRAME_FILTER_ALL,
				min = 0,
				max = 100,
				step = 1,
				--rep = {[0]=ACHIEVEMENTFRAME_FILTER_ALL}
			},
			displayMode={ type="select", order=9, name=L["Display mode"], desc=L["Change the list style."], width="double",
				values	= {
					["NORMAL"]    = L["Normal list of log entries"],
					["SPLIT"]    = L["Separate tables by actions and 'Show max. entries' used per table."],
				},
			},
		},
		misc = nil,
	}
end

-- function module.init() end

function module.onevent(self,event,msg)
	if event=="PLAYER_LOGIN" or event=="GUILD_ROSTER_UPDATE" then
		QueryGuildEventLog();
	elseif event=="BE_UPDATE_CFG" then
		ns.ClickOpts.update(name);
	elseif event=="GUILD_EVENT_LOG_UPDATE" then
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

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tt) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "LEFT", "LEFT", "RIGHT"},{false},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
