
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
local channels={}
local channels_last =1;

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "ChatChannels";
local ldbName,ttName,ttColumns,tt,createMenu = name,name.."TT",2


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\chatframe\\ui-chatwhispericon"}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show count of users of all chat channels"],
	--icon_suffix = '',
	events = {
		"PLAYER_ENTERING_WORLD",
		"PARTY_LEADER_CHANGED",
		"GROUP_ROSTER_UPDATE",
		"CHANNEL_UI_UPDATE",
		"CHANNEL_COUNT_UPDATE",
		"CHANNEL_ROSTER_UPDATE"
	},
	updateinterval = 30, -- 10
	config_defaults = {
		inTitle = {}
	},
	config_allowed = {},
	config = {
		{ type="header", label=CHAT_CHANNELS, align="left", icon=I[name] },
	},
	clickOptions = {
		["1_open_chats"] = {
			cfg_label = "Open chat channels window", -- L["Open chat channels window"]
			cfg_desc = "open the chat channels tab on the contact window", -- L["open the chat channels tab on the contact window"]
			cfg_default = "_LEFT",
			hint = "Open chat channels window",
			func = function(self,button)
				local _mod=name;
				securecall("ToggleFriendsFrame",3);
			end
		},
		["2_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self);
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function updateChannels(id,num)
	channels[id][5]=num;
	channels[id].lastUpdate=time();
end

local function updateList()
	wipe(channels);
	local n = GetNumDisplayChannels();
	for i=1, n do
		channels[i] = {GetChannelDisplayInfo(i)};
		channels[i].lastUpdate=0;

		local chatTypeName = "SYSTEM";
		if(type(channels[i][4])=="number")then
			chatTypeName = "CHANNEL"..channels[i][4];
		elseif(channels[i][1]==GROUP)then
			chatTypeName = "PARTY";
			if(not IsInGroup())then
				channels[i][6]=false;
			end
		elseif(channels[i][1]==RAID)then
			chatTypeName = "RAID";
			if(not IsInRaid())then
				channels[i][6]=false;
			end
		elseif(channels[i][1]==INSTANCE_CHAT)then
			chatTypeName = "INSTANCE_CHAT";
			if(not IsInInstance())then
				channels[i][6]=false;
			end
		end

		local r,g,b = GetMessageTypeColor(chatTypeName);
		channels[i].color = {r or 0.6, g or 0.6, b or 0.6};
	end
end

local function updateRoster(chan)
	--ns.print(name,chan)
end

local function update()
	--local n = GetNumDisplayChannels();
	--for i=1, n do
		--local id = GetSelectedDisplayChannel()
	--end
	updateList()
	updateRoster(id)
end

local function createTooltip(self,tt)
	if (tt==nil) or ((tt) and (tt.key) and (tt.key~=ttName)) then return end -- don't override other LibQTip tooltips...

	tt:Clear();

	tt:AddHeader(C("dkyellow",CHAT_CHANNELS));

	for i,v in ipairs(channels) do
		local channel, header, collapsed, channelNumber, count, active, category = unpack(v);

		if(header)then
			tt:AddSeparator(4,0,0,0,0);
			local l=tt:AddLine(C("ltblue",channel));
			if(collapsed)then
				tt:SetCell(l,2,C("gray","("..L["collapsed"]..")"));
			else
				tt:AddSeparator();
				local n = ((not channels[i+1]) and true) or channels[i+1][2];
				if(n)then
					tt:AddLine(C("gray",L["No channels listed..."]));
				end
			end

		elseif(active)then
			local color = "ltyellow";
			if(v.color)then
				color = ("ff%02x%02x%02x"):format(v.color[1]*255,v.color[2]*255,v.color[3]*255);
			end
			tt:AddLine(C(color,(channelNumber~=nil and channelNumber..". " or "") ..channel), ns.FormatLargeNumber(count));
		else
			tt:AddLine(C("gray",(channelNumber~=nil and channelNumber..". " or "") ..channel), C("gray",FACTION_INACTIVE));
		end
	end
	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(3,0,0,0,0);
		ns.clickOptions.ttAddHints(tt,name,ttColumns);
	end
	ns.roundupTooltip(self,tt)
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,...)
	local arg1, arg2, arg3 = ...
	if ({PLAYER_ENTERING_WORLD=1,CHANNEL_UI_UPDATE=1,PARTY_LEADER_CHANGED=1,GROUP_ROSTER_UPDATE=1,CHANNEL_ROSTER_UPDATE=1})[event]==1 then
		update()
		if(event=="PLAYER_ENTERING_WORLD")then
			C_Timer.After(5,ns.modules[name].onupdate);
		end
	--elseif event=="CHANNEL_FLAGS_UPDATED" then
	--elseif event=="CHANNEL_VOICE_UPDATE" then
	elseif event=="CHANNEL_COUNT_UPDATE" then
		updateChannels(arg1,arg2 or 0)
	elseif event=="d" then
		update()
	elseif ({MUTELIST_UPDATE=1,IGNORELIST_UPDATE=1})[event]==1 then
		updateRoster(GetSelectedDisplayChannel())
	end
end

ns.modules[name].onupdate = function(self,elapsed)
	if(ChannelFrame and ChannelFrame:IsShown()) then return end
	local I=0;
	for i,v in pairs(channels)do
		if(not v[2] and v[6])then
			C_Timer.After(i*1.2,function()
				if(ChannelFrame and ChannelFrame:IsShown()) then return end
				SetSelectedDisplayChannel(i);
				if(tt and tt.key and tt.key==ttName)then
					createTooltip(false, tt)
				end
			end);
		end
		I=i+1;
	end
	C_Timer.After(I*1.2,function()
		local obj = ns.LDB:GetDataObjectByName(ldbName);
		local txt={};
		for i,v in pairs(channels)do
			if(not v[2])then
				local color,count = {.5,.5,.5},v[5] or 0;
				if(v.color and v[6])then
					color = v.color;
				end

				tinsert(txt,C(color,ns.FormatLargeNumber(count)));
			end
		end
		if(#txt>0)then
			obj.text = table.concat(txt,"/");
		else
			obj.text = CHAT_CHANNELS;
		end
	end);
end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(ttName, ttColumns, "LEFT", "RIGHT","RIGHT")
	createTooltip(self, tt);
end

ns.modules[name].onleave = function(self)
	if tt then ns.hideTooltip(tt,ttName,true,true); end
end

--[[
ns.modules[name].onclick = function(self,button)
	if button=="LeftButton" then
	elseif button=="RightButton" then
	end
end
]]

-- ns.modules[name].ondblclick = function(self,button) end


