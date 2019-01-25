
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "ChatChannels"; -- CHAT_CHANNELS L["ModDesc-ChatChannels"]
local ttName,ttColumns,tt,module,ticker = name.."TT",2
local iName, iHeader, iCollapsed, iChannelNumber, iCount, iActive, iCategory, iVoiceEnabled, iVoiceActive = 1,2,3,4,5,6,7,8,9; -- GetChannelDisplayInfo indexes
local iLastUpdate, iNoUpdate = 10,11; -- custom indexes
local channels,ChanIndex,updateChannelListLock,updateCountTicker={},0,false;
local wd = ({
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
})[ns.locale];


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="Interface\\chatframe\\ui-chatwhispericon",coords={0.05,0.95,0.05,0.95}} --IconName::ChatChannels--


-- some local functions --
--------------------------
local function updateBroker()
	local obj = ns.LDB:GetDataObjectByName(module.ldbName);
	local txt={};
	for i,v in ipairs(channels)do
		if not v[iHeader] then
			local color,count = {.5,.5,.5},v[iCount] or 0;
			if(v.color and v[iActive])then
				color = v.color;
			end
			tinsert(txt,C(color,ns.FormatLargeNumber(name,count)));
		end
	end
	obj.text = #txt>0 and table.concat(txt,"/") or CHAT_CHANNELS;
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
	local r,g,b = GetMessageTypeColor(chatTypeName);
	data.color = {r or 0.6, g or 0.6, b or 0.6};
	if data[iName]==wd then
		-- exclude world defence channel from user count update.
		-- SetSelectedDisplayChannel on world defence results in error message
		data[iNoUpdate] = true;
	end
	if not tbl==channels then
		data[iLastUpdate] = (data[iCount]>0 and time()) or 0;
	end
	tbl[index]=data;
end

function nextChannel()
	repeat
		ChanIndex=ChanIndex+1;
	until (channels[ChanIndex] and not channels[ChanIndex][iHeader] and channels[ChanIndex][iActive]) or not channels[ChanIndex];

	if not channels[ChanIndex] then
		updateCountTicker:Cancel();
		updateCountTicker = nil;
	elseif channels[ChanIndex] and channels[ChanIndex][iActive] then
		SetSelectedDisplayChannel(ChanIndex); -- trigger CHANNEL_COUNT_UPDATE
	end
end

local function updateChannelList()
	local tmp = {};
	local num = GetNumDisplayChannels();
	for index=1, num do
		addChannel(tmp,index);
	end
	channels = tmp;
	updateChannelListLock = false;

	updateBroker();
	module.onupdate();
end

local function createTooltip(tt,update)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",CHAT_CHANNELS));

	for i,v in ipairs(channels) do
		local channel, header, collapsed, channelNumber, count, active, category = unpack(v);

		if header then
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
			tt:AddLine(C(color,(channelNumber~=nil and channelNumber..". " or "") ..channel), ns.FormatLargeNumber(name,count,true));
		else
			tt:AddLine(C("gray",(channelNumber~=nil and channelNumber..". " or "") ..channel), C("gray",FACTION_INACTIVE));
		end
	end
	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(3,0,0,0,0);
		ns.ClickOpts.ttAddHints(tt,name);
	end
	if not update then
		ns.roundupTooltip(tt);
	end
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_ENTERING_WORLD",
		"CHANNEL_UI_UPDATE",
		"CHANNEL_COUNT_UPDATE",
		"CHANNEL_ROSTER_UPDATE"
	},
	onupdate_interval = 30,
	config_defaults = {
		enabled = false,
	},
	clickOptionsRename = {
		["chats"] = "1_open_chats",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["chats"] = {CHAT_CHANNELS,"call",{"ToggleFriendsFrame",3}},
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	chats = "_LEFT",
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = nil,
		tooltip = nil,
		misc = {
			shortNumbers=true,
		},
	}
end

-- function module.init() end

function module.onevent(self,event,...)
	local msg = ...;
	if event=="BE_UPDATE_CFG" and msg and msg:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="CHANNEL_COUNT_UPDATE" then
		local index, count = ...;
		if channels[index]==nil then
			addChannel(channels,index);
		end
		channels[index][iCount] = count or 0;
		channels[index][iLastUpdate] = time(); -- ?
		updateBroker();
	elseif ns.eventPlayerEnteredWorld and (event=="PLAYER_ENTERING_WORLD" or event=="CHANNEL_UI_UPDATE") then
		if not updateChannelListLock then -- catch multible triggered events
			C_Timer.After(.15, updateChannelList);
		end
	end
end

function module.onupdate()
	if (ChannelFrame and ChannelFrame:IsShown()) or (updateCountTicker~=nil) then return end
	ChanIndex = 0;
	updateCountTicker = C_Timer.NewTicker(.5, nextChannel);
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT","RIGHT"},{true},{self})
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
