
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Mail" -- BUTTON_LAG_MAIL L["ModDesc-Mail"]
local ttName, tooltip, tt, module = name.."TT"
local alertLocked,onUpdateLocked,hookOn = false,false,false;
local storedMailLineFaction = "%s%s |TInterface\\PVPFrame\\PVP-Currency-%s:16:16:0:-1:16:16:0:16:0:16|t";
local storedMailLineNeutral = "%s%s";
local icons = {}


-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile="interface\\icons\\inv_letter_15",coords={0.05,0.95,0.05,0.95}}					--IconName::Mail--
I[name..'_new'] = {iconfile="interface\\icons\\inv_letter_18",coords={0.05,0.95,0.05,0.95}}			--IconName::Mail_new--
I[name..'_stored'] = {iconfile="interface\\icons\\inv_letter_03",coords={0.05,0.95,0.05,0.95}}		--IconName::Mail_stored--


-- some local functions --
--------------------------
local function clearStoredMailsData()
	for i=1, #Broker_Everything_CharacterDB.order do
		if Broker_Everything_CharacterDB.order[i]~=ns.player.name_realm then
			local v = Broker_Everything_CharacterDB[Broker_Everything_CharacterDB.order[i]];
			if v.mail then
				if v.mail.count~=nil then
					v.mail = { new={}, stored={} };
				else
					v.mail.new = {};
					v.mail.stored = {};
				end
			end
		end
	end
	module.onevent({},"BE_DUMMY_EVENT");
end

local function sortStoredMails(a,b)
	return (a.returns or 0)<(b.returns or 0);
end

local function UpdateStatus(event)
	if ns.toon.mail==nil then
		ns.toon.mail = { new={}, stored={} };
	end
	if ns.toon.mail.stored2==nil then
		ns.toon.mail.stored2={};
	end

	local mailNew, _time = HasNewMail(), time();
	local sender,daysLeft,dt,ht,_;
	local returns,mailState,next1,next2,next3,tmp = (99*86400),0;
	local charDB_mail = ns.toon.mail;

	if (_G.MailFrame:IsShown()) or (event=="MAIL_CLOSED") then
		charDB_mail.num, charDB_mail.total = GetInboxNumItems();
		charDB_mail.num, charDB_mail.total = charDB_mail.num or 0, charDB_mail.total or 0;
		wipe(charDB_mail.stored);
		for i=1, charDB_mail.num do
			_, _, sender_realm, _, _, _, daysLeft = GetInboxHeaderInfo(i);
			if sender_realm then
				local returns = _time + floor(daysLeft * 86400);
				if not sender_realm:find("%-") then
					sender_realm = sender_realm.."-"..ns.realm_short;
				end
				tinsert(charDB_mail.stored,sender_realm..";"..returns);
			end
		end
		wipe(charDB_mail.new);
	else
		local names = {};
		for i=1, #charDB_mail.stored do
			if type(charDB_mail.stored[i])=="table" then -- deprecated
				charDB_mail.stored[i] = charDB_mail.stored[i].sender.."-"..(charDB_mail.stored[i].realm or ns.realm_short)..";"..(charDB_mail.stored[i].last+charDB_mail.stored[i].returns);
			end
			local sender = strsplit(";",charDB_mail.stored[i]);
			names[sender]=true;
		end
		for i=1, #charDB_mail.new do
			if type(charDB_mail.new[i])=="string" then
				local sender = strsplit(";",charDB_mail.new[i]);
				names[sender]=true;
			else
				charDB_mail.new[i] = nil;
			end
		end
		local latest = {GetLatestThreeSenders()};
		for i=1, #latest do
			if type(latest[i])=="string" then
				latest[i] = ns.realmCheckOrAppend(latest[i]);
				if not names[latest[i]] then
					tinsert(charDB_mail.new,latest[i]);
				end
			end
		end
	end

	local mailStored = false;
	for i=1, #Broker_Everything_CharacterDB.order do
		if Broker_Everything_CharacterDB.order[i]~=ns.player.name_realm then
			local v = Broker_Everything_CharacterDB[Broker_Everything_CharacterDB.order[i]];
			if v.mail then
				if v.mail.count~=nil then
					v.mail = { new={}, stored={} };
				end
				if #v.mail.new>0 or #v.mail.stored>0 then
					mailStored = true;
				end
			end
		end
	end

	local icon,text,obj = I(name), L["No Mail"],ns.LDB:GetDataObjectByName(module.ldbName);

	if #charDB_mail.new>0 then
		icon, text = I(name.."_new"), C("green",L["New mail"]);
	elseif mailStored then
		icon, text = I(name.."_stored"), C("yellow",L["Stored mails"]);
	end

	obj.iconCoords,obj.icon,obj.text = icon.coords or {0,1,0,1},icon.iconfile,text;
end

local function AddStoredMailsLine(tt,player)
	local hasData = false;
	local _time = time();
	local v,n = Broker_Everything_CharacterDB[player],{strsplit("-",player,2)}
	if v.mail and ns.showThisChar(name,n[2],v.faction) then
		local counter,key,oldest={stored=0,new=0,returned=0},{"stored","new"};

		for k=1, #key do
			if #v.mail[key[k]]>0 then
				for i=1, #v.mail[key[k]] do
					if type(v.mail[key[k]][i])=="table" then -- deprecated
						if v.mail[key[k]][i].realm==nil then
							v.mail[key[k]][i].realm = ns.realm_short;
						end
						v.mail[key[k]][i] = v.mail[key[k]][i].sender.."-"..v.mail[key[k]][i].realm..";"..v.mail[key[k]][i].last+v.mail[key[k]][i].returns;
					end
					local sender,returns = strsplit(";",v.mail[key[k]][i]);
					returns = tonumber(returns);
					if returns then
						if returns<_time then
							counter.returned = counter.returned+1;
						else
							counter[key[k]] = counter[key[k]]+1;
							if (not oldest) or (oldest and returns<oldest) then
								oldest = returns;
							end
						end
					end
				end
			end
		end

		if counter.new>0 or counter.stored>0 then
			local str="";
			if counter.stored==0 and counter.new>0 then
				str = C("green",L["New mails"]..": "..counter.new);
			elseif counter.stored>0 or counter.new>0 then
				str = L["Mails"]..": "..counter.stored;
				if counter.new>0 then
					str = str.." "..C("green","("..NEW..": "..counter.new..")");
				end
			end
			local l=tt:AddLine(
				(v.faction=="Neutral" and storedMailLineNeutral or storedMailLineFaction):format(C(v.class,ns.scm(n[1])),ns.showRealmName(name,n[2]),v.faction),
				str
			);
			if player==ns.player.name_realm then
				tt:SetLineColor(l, .5, .5, .5);
			end
			hasData = true;
		end

		if oldest then
			local returnsIn = oldest-_time;
			tt:AddLine("  "..C("ltgray",L["Oldest:"]), C((returnsIn<86400 and "red") or (returnsIn<(3*86400) and "orange") or (returnsIn<(7*86400) and "yellow") or "ltgray",SecondsToTime(returnsIn)));
		end
	end
	return hasData;
end

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	local newMails = {};
	if HasNewMail() then
		newMails = {GetLatestThreeSenders()}; -- this function is unreliable after clearing and closing mail box. must be captured by HasNewMail().
	end
	local l,c
	if tt.lines~=nil then tt:Clear(); end

	local l = tt:AddLine();
	tt:SetCell(l,1,C("dkyellow",BUTTON_LAG_MAIL),tt:GetHeaderFont(),"LEFT");
	tt:AddSeparator(3,0,0,0,0);
	if #newMails>0 then
		tt:SetCell(l,2,C("green",L["You have new mails"]),nil,"RIGHT");
		tt:AddLine(C("ltblue",L["Lastest senders:"]));
		tt:AddSeparator()
		for i,v in ipairs(newMails) do
			tt:AddLine("   "..ns.scm(v));
		end
	else
		tt:SetCell(l,2,C("gray",L["No new mails"]),nil,"RIGHT");
	end

	if (ns.profile[name].showDaysLeft) then

		tt:AddSeparator(3,0,0,0,0);
		tt:SetCell(tt:AddLine(),1,C("dkyellow",L["Left in mailbox"]),nil,"LEFT",0);
		tt:AddSeparator();

		local hasData,t = false;

		if AddStoredMailsLine(tt,ns.player.name_realm) then
			hasData=true;
		end

		for i=1, #Broker_Everything_CharacterDB.order do
			if Broker_Everything_CharacterDB.order[i]~=ns.player.name_realm then
				if AddStoredMailsLine(tt,Broker_Everything_CharacterDB.order[i]) then
					hasData = true;
				end
			end
		end

		if not hasData then
			tt:AddLine(C("gray",L["No data"]));
		end
	end

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0)
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end

local function SendMailHook(targetName)
	if debugstack():find("\?") then return end -- ignore double executed function

	local t = time()+30*86400;
	local _,r = strsplit("-",targetName,2);
	if type(r)=="string" and r:len()>0 then
		targetName = targetName.."-"..ns.realms[r];
	elseif not r then
		targetName = targetName.."-"..ns.realm;
	end
	if Broker_Everything_CharacterDB[targetName] then
		if Broker_Everything_CharacterDB[targetName].mail==nil then
			Broker_Everything_CharacterDB[targetName].mail = { new={}, stored={} };
		end
		tinsert(Broker_Everything_CharacterDB[targetName].mail.new,ns.player.name..";"..t);
	end
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"UPDATE_PENDING_MAIL",
		"MAIL_CLOSED",
		"MAIL_SHOW"
	},
	config_defaults = {
		enabled = false,
		playsound = false,
		showDaysLeft = true,
		hideMinimapMail = false,
		showAllFactions=true,
		showRealmNames=true,
		showCharsFrom="2"
	},
	clickOptionsRename = {
		["menu"] = "open_menu"
	},
	clickOptions = {
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	menu = "_RIGHT"
});

function module.options()
	return {
		broker = nil,
		tooltip = {
			showDaysLeft={ type="toggle", order=1, name=L["List mails on chars"], desc=L["Display a list of chars on all realms with there mail counts and 3 lowest days before return to sender. Chars with empty mail box aren't displayed."] },
			showAllFactions=2,
			showRealmNames=3,
			showCharsFrom=4,
		},
		misc = {
			playsound={ type="toggle", order=1, name=L["Play sound on new mail"], desc=L["Enable to play a sound on receiving a new mail message. Default is off"], width="full" },
			hideMinimapMail={ type="toggle", order=2, name=L["Hide minimap mail icon"], desc=L["Hide minimap mail icon"], width="full", disabled=ns.coexist.IsNotAlone },
			hideMinimapMailInfo = { type="description", order=3, name=ns.coexist.optionInfo, fontSize="medium", hidden=ns.coexist.IsNotAlone }
		},
	},
	{
		hideMinimapMail = "BE_HIDE_MINIMAPMAIL",
	}
end

function module.init()
	for i=1, 22 do
		local I = ("inv_letter_%02d"):format(i);
		icons[I] = "|Tinterface\\icons\\"..I..":16:16:0:0|t";
	end
	if (not ns.coexist.IsNotAlone()) and ns.profile[name].hideMinimapMail then
		ns.hideFrames("MiniMapMailFrame",true);
	end
end

function module.onevent(self,event,msg)
	if event=="BE_UPDATE_CFG" and msg and msg:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	elseif event=="BE_UPDATE_CFG" then
		if not ns.coexist.IsNotAlone() then
			ns.hideFrames("MiniMapMailFrame",ns.profile[name].hideMinimapMail);
		end
	elseif event=="PLAYER_LOGIN" then
		hooksecurefunc("SendMail",SendMailHook);
	end
	if ns.eventPlayerEnteredWorld then
		if (HasNewMail()) and (ns.profile[name].playsound) and (not alertLocked) then
			PlaySoundFile("Interface\\Addons\\"..addon.."\\media\\mailalert.mp3", "Master"); -- or SFX?
			alertLocked=true;
		elseif (not HasNewMail()) then
			alertLocked=false;
		end
		UpdateStatus(event);
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(tooltip) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName, 2, "LEFT", "RIGHT"},{true},{self});
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
