
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
local channels={}
local channels_last =1;

-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "ChatChannels";
local ttName,ttColumns,tt,module,ticker = name.."TT",2
local iName, iHeader, iCollapsed, iChannelNumber, iCount, iActive, iCategory, iVoiceEnabled, iVoiceActive = 1,2,3,4,5,6,7,8,9;
local events={PLAYER_LOGIN=1,CHANNEL_UI_UPDATE=1,PARTY_LEADER_CHANGED=1,GROUP_ROSTER_UPDATE=1,CHANNEL_ROSTER_UPDATE=1,MUTELIST_UPDATE=2,IGNORELIST_UPDATE=2}
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

local function updater()
	if(ChannelFrame and ChannelFrame:IsShown()) then return end
	local I=0;
	for i,v in ipairs(channels)do
		if not v.noUpdate and not v[iHeader] and v[iActive] then
			C_Timer.After(i*.4,function()
				if(ChannelFrame and ChannelFrame:IsShown()) then return end
				SetSelectedDisplayChannel(i);
				if(tt and tt.key and tt.key==ttName)then
					createTooltip(tt,true);
				end
			end);
		end
		I=i+1;
	end
	C_Timer.After(I*.4,function()
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
		if(#txt>0)then
			obj.text = table.concat(txt,"/");
		else
			obj.text = CHAT_CHANNELS;
		end
	end);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"CHANNEL_UI_UPDATE",
		"CHANNEL_COUNT_UPDATE",
		"CHANNEL_ROSTER_UPDATE"
	},
	onupdate_interval = 30,
	config_defaults = {},
	clickOptionsRename = {
		["chats"] = "1_open_chats",
		["menu"] = "2_open_menu"
	},
	clickOptions = {
		["chats"] = {"Chat channels window","call",{"ToggleFriendsFrame",3}}, -- L["Chat channels window"]
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

function module.onevent(self,event,arg1,arg2,...)
	local msg = ...;
	if event=="BE_UPDATE_CFG" and msg and msg:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="CHANNEL_COUNT_UPDATE" then
		updateChannels(arg1,arg2 or 0)
	end
	if events[event]==1 then
		updateList()
		if not ticker and event=="PLAYER_LOGIN" then
			C_Timer.After(5,updater);
			ticker = C_Timer.NewTicker(module.updateinterval,updater);
		end
	elseif event=="d" then
		updateList()
	end
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
