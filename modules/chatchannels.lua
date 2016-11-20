
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
local ldbName,ttName,ttColumns,tt,createMenu,ticker = name,name.."TT",2
local iName, iHeader, iCollapsed, iChannelNumber, iCount, iActive, iCategory, iVoiceEnabled, iVoiceActive = 1,2,3,4,5,6,7,8,9;
local WD_Locale = {
	enUS="WorldDefense",
	enBG="WorldDefense",
	enCN="WorldDefense",
	enTW="WorldDefense",
	deDE="WeltVerteidigung",
	esES="DefensaGeneral",
	frFR="DéfenseUniverselle",
	itIT="DifesaMondiale",
	koKR="전쟁",
	ptBR="DefesaGlobal",
	ptPT="DefesaGlobal",
	ruRU="ОборонаГлобальный",
	zhCN="世界防务",
	zhTW="世界防務",
};
local wd = WD_Locale[ns.locale];
local events={PLAYER_ENTERING_WORLD=1,CHANNEL_UI_UPDATE=1,PARTY_LEADER_CHANGED=1,GROUP_ROSTER_UPDATE=1,CHANNEL_ROSTER_UPDATE=1,MUTELIST_UPDATE=2,IGNORELIST_UPDATE=2}

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
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function addChannel(tbl,index)
	local data = {GetChannelDisplayInfo(index)};
	local chatTypeName = "SYSTEM";
	if(type(data[iChannelNumber])=="number")then
		chatTypeName = "CHANNEL"..data[iChannelNumber];
	elseif(data[iName]==GROUP)then
		chatTypeName = "PARTY";
		if(not IsInGroup())then
			data[iActive]=false;
		end
	elseif(data[iName]==RAID)then
		chatTypeName = "RAID";
		if(not IsInRaid())then
			data[iActive]=false;
		end
	elseif(data[iName]==INSTANCE_CHAT)then
		chatTypeName = "INSTANCE_CHAT";
		if(not IsInInstance())then
			data[iActive]=false;
		end
	end
	if(data[iName]==wd)then
		data.noUpdate = true;
	end
	local r,g,b = GetMessageTypeColor(chatTypeName);
	data.color = {r or 0.6, g or 0.6, b or 0.6};
	if not (tbl==channels and channels[index] and channels[index][iName]==data[iName]) then
		data.lastUpdate=0;
	end
	tinsert(tbl,data);
end

local function updateChannels(index,num)
	if channels[index]==nil then
		addChannel(channels,index);
	end
	channels[index][5]=num;
	channels[index].lastUpdate=time();
end

--local iName, iHeader, iCollapsed, iChannelNumber, iCount, iActive, iCategory, iVoiceEnabled, iVoiceActive = 1,2,3,4,5,6,7,8,9;
local function updateList()
	local tmp = {};
	local num = GetNumDisplayChannels();
	for index=1, num do
		addChannel(tmp,index);
	end
	channels = tmp;
end

local function createTooltip(tt,update)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

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
	if not update then
		ns.roundupTooltip(tt);
	end
end

local function updater()
	if(ChannelFrame and ChannelFrame:IsShown()) then return end
	local I=0;
	for i,v in ipairs(channels)do
		if not v.noUpdate and not v[iHeader] and v[iActive] then
			C_Timer.After(i*1.2,function()
				if(ChannelFrame and ChannelFrame:IsShown()) then return end
				SetSelectedDisplayChannel(i);
				if(tt and tt.key and tt.key==ttName)then
					createTooltip(tt,true);
				end
			end);
		end
		I=i+1;
	end
	C_Timer.After(I*1.2,function()
		local obj = ns.LDB:GetDataObjectByName(ldbName);
		local txt={};
		for i,v in ipairs(channels)do
			if not v[iHeader] then
				local color,count = {.5,.5,.5},v[iCount] or 0;
				if(v.color and v[iActive])then
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

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,arg1,arg2,...)
	if events[event]==1 then
		updateList()
		if not ticker and event=="PLAYER_ENTERING_WORLD" then
			C_Timer.After(5,updater);
			ticker = C_Timer.NewTicker(ns.modules[name].updateinterval,updater);
		end
	--elseif event=="CHANNEL_FLAGS_UPDATED" then
	--elseif event=="CHANNEL_VOICE_UPDATE" then
	elseif event=="CHANNEL_COUNT_UPDATE" then
		updateChannels(arg1,arg2 or 0)
	elseif event=="d" then
		updateList()
	--elseif events[event]==2 then
	end
end

-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT","RIGHT"},{true},{self})
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end


