
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Mail" -- BUTTON_LAG_MAIL
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

local function UpdateStatus(event)
	local mailNew, _time = HasNewMail(), time();
	local sender,subject,money,daysLeft,itemCount,wasReturned,isGM,dt,ht,_;
	local num,total = GetInboxNumItems(); num=num or 0; total=total or 0;
	local returns,mailState,next1,next2,next3,tmp = (99*86400),0,nil,nil,nil,nil;

	if ns.toon.mail==nil then
		ns.toon.mail = { new={}, stored={} };
	end
	if ns.toon.mail.count then
		ns.toon.mail = { new={}, stored={} };
	end
	local charDB_mail = ns.toon.mail;

	if (_G.MailFrame:IsShown()) or (event=="MAIL_CLOSED") then
		charDB_mail.stored={};
		for i=1, num do
			_, _, sender, subject, money, _, daysLeft, itemCount, _, wasReturned, _, _, isGM = GetInboxHeaderInfo(i)
			itemCount = itemCount or 0; -- pre WoD compatibility
			dt,ht = floor(daysLeft)*86400, (1-(daysLeft-floor(daysLeft)))*86400;
			tinsert(charDB_mail.stored,{
				sender  = sender,
				subject = subject,
				money   = money>0,
				items   = itemCount>0,
				gm      = (isGM),
				last    = _time,
				returns = floor(dt-ht)
			});
		end
		charDB_mail.more = total>num;
		charDB_mail.new = {};
	else
		local names = {};
		if #charDB_mail.stored>0 then
			 for i=1, #charDB_mail.stored do
				local n = strsplit("-",charDB_mail.stored[i].sender or UNKNOWN,2);
				names[n]=true;
			 end
		end
		for i,v in ipairs({GetLatestThreeSenders()}) do
			if not names[v] then
				tinsert(charDB_mail.new,v);
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

local function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	local newMails = {};
	if HasNewMail() then
		newMails = {GetLatestThreeSenders()}; -- this function is unreliable after clearing and closing mail box. must be captured by HasNewMail().
	end
	local l,c
	if tt.lines~=nil then tt:Clear(); end

	tt:AddHeader(C("dkyellow",BUTTON_LAG_MAIL))
	tt:AddSeparator()
	tt:AddLine(C("ltblue",L["Last 3 new mails"]),#newMails.." "..L["mails"])
	if #newMails>0 then
		for i,v in ipairs(newMails) do
			tt:AddLine("   "..ns.scm(v))
		end
	end

	if (ns.profile[name].showDaysLeft) then

		tt:AddSeparator(3,0,0,0,0)
		tt:AddHeader(C("dkyellow",L["Left in mailbox"]))
		tt:AddSeparator()

		local noData,t = true;
		for i=1, #Broker_Everything_CharacterDB.order do
			if Broker_Everything_CharacterDB.order[i]~=ns.player.name_realm then
				local v = Broker_Everything_CharacterDB[Broker_Everything_CharacterDB.order[i]];
				local n = {strsplit("-",Broker_Everything_CharacterDB.order[i],2)}
				if v.mail and ns.showThisChar(name,n[2],v.faction) then
					if #v.mail.new>0 or #v.mail.stored>0 then
						local count,countnew,str = #v.mail.stored,#v.mail.new,"";
						if count==0 and countnew>0 then
							str = C("green",L["New mails"]..": "..countnew);
						elseif count>0 or countnew>0 then
							str = L["Mails"]..": "..(count+countnew);
							if countnew>0 then
								str = str.." "..C("green","("..NEW..": "..countnew..")");
							end
						end

						tt:AddLine(
							(v.faction=="Neutral" and storedMailLineNeutral or storedMailLineFaction):format(C(v.class,ns.scm(n[1])),ns.showRealmName(name,n[2]),v.faction),
							str
						);
						noData = false;
					end
					if #v.mail.stored>0 then
						for I,V in ipairs(v.mail.stored) do
							t = V.returns~=nil and V.returns-(time()-V.last) or 30*86400
							tt:AddLine(
								"   "..
								ns.scm(V.sender)
								.." "..
								(V.money and " |TInterface\\Minimap\\TRACKING\\Auctioneer:12:12:0:-1:64:64:4:56:4:56|t" or "")
								..
								(V.items and " |TInterface\\icons\\INV_Crate_02:12:12:0:-1:64:64:4:56:4:56|t" or "")
								..
								(V.gm and " |TInterface\\chatframe\\UI-ChatIcon-Blizz:12:20:0:0:32:16:4:28:0:16|t" or ""),
								C((t<86400 and "red") or (t<(3*86400) and "orange") or (t<(7*86400) and "yellow") or "green",SecondsToTime(t))
							)
						end
					end
				end
			end
		end

		if noData then
			tt:AddLine(C("gray",L["No data"]));
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
		hooksecurefunc("SendMail",function(targetName)
			local n,r,_ = strsplit("-",targetName,2);
			if type(r)=="string" and r:len()>0 then
				r = ns.realms[r];
			end
			targetName = n.."-"..(r or ns.realm);
			if Broker_Everything_CharacterDB[targetName] then
				if Broker_Everything_CharacterDB[targetName].mail==nil then
					Broker_Everything_CharacterDB[targetName].mail = { new={}, stored={} };
				end
				tinsert(Broker_Everything_CharacterDB[targetName].mail.new,ns.player.name);
			end
		end);
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
