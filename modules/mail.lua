
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Mail" -- BUTTON_LAG_MAIL
local ttName, tooltip, tt = name.."TT"
local alertLocked,onUpdateLocked,hookOn = false,false,false;
local icons = {}
do for i=1, 22 do local _ = ("inv_letter_%02d"):format(i) icons[_] = "|Tinterface\\icons\\".._..":16:16:0:0|t" end end
local similar, own, unsave = "%s has a similar option to hide the minimap mail icon.","%s has its own mail icon.","%s found. It's unsave to hide the minimap mail icon without errors.";
local coexist_tooltip = {
	["Carbonite"]			= unsave,
	["DejaMinimap"]			= unsave,
	["Chinchilla"]			= similar,
	["Dominos_MINIMAP"]		= similar,
	["gUI4_Minimap"]		= own,
	["LUI"]					= own,
	["MinimapButtonFrame"]	= unsave,
	["SexyMap"]				= similar,
	["SquareMap"]			= unsave,
};


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name] = {iconfile="interface\\icons\\inv_letter_15",coords={0.05,0.95,0.05,0.95}}					--IconName::Mail--
I[name..'_new'] = {iconfile="interface\\icons\\inv_letter_18",coords={0.05,0.95,0.05,0.95}}			--IconName::Mail_new--
I[name..'_stored'] = {iconfile="interface\\icons\\inv_letter_03",coords={0.05,0.95,0.05,0.95}}		--IconName::Mail_stored--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Broker to show incoming mails and stored mails on all your chars"],
	label = BUTTON_LAG_MAIL,
	events = {
		"ADDON_LOADED",
		"PLAYER_ENTERING_WORLD",
		"UPDATE_PENDING_MAIL",
		"MAIL_CLOSED",
		"MAIL_SHOW"
	},
	updateinterval = 60,
	config_defaults = {
		playsound = false,
		showDaysLeft = true,
		hideMinimapMail = false,
		showAllFactions=true,
		showRealmNames=true,
		showCharsFrom=4
	},
	config_allowed = nil,
	config_header = {type="header", label=BUTTON_LAG_MAIL, align="left", icon=I[name]},
	config_broker = nil,
	config_tooltip = {
		{ type="toggle", name="showDaysLeft", label=L["List mails on chars"], tooltip=L["Display a list of chars on all realms with there mail counts and 3 lowest days before return to sender. Chars with empty mail box aren't displayed."] },
		"showAllFactions",
		"showRealmNames",
		"showCharsFrom"
	},
	config_misc = {
		{ type="toggle", name="playsound", label=L["Play sound on new mail"], tooltip=L["Enable to play a sound on receiving a new mail message. Default is off"] },
		{ type="toggle", name="hideMinimapMail", label=L["Hide minimap mail icon"], tooltip=L["Hide minimap mail icon"],
			event = "BE_HIDE_MINIMAPMAIL",
			disabled = function()
				if ns.coexist.check() then
					return ns.coexist.optionInfo();
				end
				return false;
			end
		},
	},
}


--------------------------
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
	ns.modules[name].onevent({},"BE_DUMMY_EVENT");
end

local function createMenu(self,button)
	if (button=="RightButton") then
		if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
		ns.EasyMenu.InitializeMenu();
		ns.EasyMenu.addConfigElements(name);
		ns.EasyMenu.addEntry({separator=true});
		ns.EasyMenu.addEntry({ label = C("yellow",L["Reset stored mails data"]), func=clearStoredMailsData, keepShown=false });
		ns.EasyMenu.ShowMenu(parent);
	end
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
				local n = strsplit("-",charDB_mail.stored[i].sender);
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

	local icon,text,obj = I(name), L["No Mail"],ns.LDB:GetDataObjectByName(ns.modules[name].ldbName);

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
				local n = {strsplit("-",Broker_Everything_CharacterDB.order[i])}
				if v.mail and  not ((ns.profile[name].showAllRealms~=true and n[2]~=ns.realm) or (ns.profile[name].showAllFactions~=true and v.faction~=ns.player.faction)) then
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
							("%s (%s)"):format(C(v.class,ns.scm(n[1])),C("dkyellow",ns.scm(n[2]))),
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
		tt:AddSeparator(3,0,0,0,0)
		local l,c = tt:AddLine()
		tt:SetCell(l,1,C("copper",L["Right-click"]).." || "..C("green",L["Open option menu"]),nil,nil,2);
	end
	ns.roundupTooltip(tt);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules[name].init = function() end

ns.modules[name].onevent = function(self,event,msg)
	if event=="ADDON_LOADED" then
		if ns.profile[name].showAllRealms~=nil then
			ns.profile[name].showCharsFrom = 4;
			ns.profile[name].showAllRealms = nil;
		end
	elseif (event=="BE_HIDE_MINIMAPMAIL") and (not ns.coexist.found) then
		if (ns.profile[name].hideMinimapMail) then
			ns.hideFrame("MiniMapMailFrame")
		else
			ns.unhideFrame("MiniMapMailFrame")
		end
	elseif event=="PLAYER_ENTERING_WORLD" then
		hooksecurefunc("SendMail",function(targetName)
			local n,r,_ = strsplit("-",targetName);
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

		self:UnregisterEvent(event);
	elseif ns.pastPEW then
		if (HasNewMail()) and (ns.profile[name].playsound) and (not alertLocked) then
			PlaySoundFile("Interface\\Addons\\"..addon.."\\media\\mailalert.mp3", "Master"); -- or SFX?
			alertLocked=true;
		elseif (not HasNewMail()) then
			alertLocked=false;
		end
		UpdateStatus(event);
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
	tt = ns.acquireTooltip({ttName, 2, "LEFT", "RIGHT"},{true},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end

ns.modules[name].onclick = createMenu; --function(self,button) end

-- ns.modules[name].ondblclick = function(self,button) end

ns.modules[name].coexist = function()
	if (not ns.coexist.found) and (ns.profile[name].hideMinimapMail) then
		ns.hideFrame("MiniMapMailFrame");
	end
end
