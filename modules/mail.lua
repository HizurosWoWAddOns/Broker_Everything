
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Mail" -- L["Mail"]
local ldbName, ttName, tooltip, tt = name, name.."TT"
local alertLocked,onUpdateLocked = false,false;
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
local desc = L["Broker to alert you if you have mail."];
ns.modules[name] = {
	desc = desc,
	events = {
		"VARIABLES_LOADED",
		"UPDATE_PENDING_MAIL",
		--"MAIL_INBOX_UPDATE",
		"MAIL_CLOSED",
		"PLAYER_ENTERING_WORLD",
		"MAIL_SHOW"
	},
	updateinterval = 60,
	config_defaults = {
		playsound = false,
		showDaysLeft = true,
		hideMinimapMail = false,
		showAllRealms = false,
		showAllFactions = true
	},
	config_allowed = {
	},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
		{ type="separator" },
		{ type="toggle", name="playsound", label=L["Play sound on new mail"], tooltip=L["Enable to play a sound on receiving a new mail message. Default is off"] },
		{ type="toggle", name="showDaysLeft", label=L["List mails on chars"], tooltip=L["Display a list of chars on all realms with there mail counts and 3 lowest days before return to sender. Chars with empty mail box aren't displayed."] },
		{ type="toggle", name="hideMinimapMail", label=L["Hide minimap mail icon"], tooltip=L["Hide minimap mail icon"],
			event = "BE_HIDE_MINIMAPMAIL",
			disabled = function()
				if (ns.coexist.found~=false) then
					return L["This option is disabled"],L[coexist_tooltip[ns.coexist.found]]:format(ns.coexist.found);
				end
				return false;
			end
		},
		{ type="toggle", name="showAllRealms", label=L["Show all realms"], tooltip=L["Show characters from all realms in tooltip."] },
		{ type="toggle", name="showAllFactions", label=L["Show all factions"], tooltip=L["Show characters from all factions in tooltip."] }
	}
}


--------------------------
-- some local functions --
--------------------------
local function UpdateStatus(event)
	local mailNew = (HasNewMail());
	local mailUnseen = (GetLatestThreeSenders()~=nil);
	local _,sender,subject,money,daysLeft,itemCount,wasReturned,isGM,dt,ht;
	local num,returns,mailState,next1,next2,next3,tmp = GetInboxNumItems(),(99*86400),0,nil,nil,nil,nil;

	if (_G.MailFrame:IsShown()) or (event=="MAIL_CLOSED") then
		for i=1, num do
			_, _, sender, subject, money, _, daysLeft, itemCount, _, wasReturned, _, _, isGM = GetInboxHeaderInfo(i)
			itemCount = itemCount or 0; -- pre WoD compatibility
			dt,ht = floor(daysLeft)*86400, (1-(daysLeft-floor(daysLeft)))*86400;
			tmp = {
				sender  = sender,
				subject = subject,
				money   = money>0,
				items   = itemCount>0,
				gm      = (isGM),
				last    = time(),
				returns = floor(dt-ht)
			};

			if (not wasReturned) or (isGM) then -- GM mail are marked as wasReturned
				if (tmp.returns < returns) then
					returns = tmp.returns;
				end
				if (next1==nil) then
					next1,mailStored = tmp,true;
				elseif (tmp.returns<next1.returns) then
					if (next2~=nil) then
						next3 = next2;
					end
					next2,next1 = next1,tmp;
				end
			end
		end
		be_character_cache[ns.player.name_realm].mail = { count=num, next3={next1,next2,next3} };
	end

	local mailStored = false;
	for i=1, #be_character_cache.order do
		local v = be_character_cache[be_character_cache.order[i]];
		if (v.mail and v.mail.count>0) then
			mailStored = true;
		end
	end

	local icon,text,obj = I(name), L["No Mail"],ns.LDB:GetDataObjectByName(ldbName);

	if (mailNew) or (mailUnseen) then
		icon, text = I(name.."_new"), C("green",L["New mail"]);
	elseif (mailStored) then
		icon, text = I(name.."_stored"), C("yellow",L["Stored mails"]);
	end
	obj.iconCoords,obj.icon,obj.text = icon.coords or {0,1,0,1},icon.iconfile,text;
end

local function getTooltip(tt)
	if (not tt.key) or tt.key~=ttName then return end -- don't override other LibQTip tooltips...

	local newMails = {GetLatestThreeSenders()}
	local l,c
	tt:Clear()

	tt:AddHeader(C("dkyellow",L[name]))
	tt:AddSeparator()
	tt:AddLine(C("ltblue",L["Last 3 new mails"]),#newMails.." "..L["mails"])
	if #newMails>0 then
		for i,v in ipairs(newMails) do
			tt:AddLine("   "..ns.scm(v))
		end
	end

	if (Broker_EverythingDB[name].showDaysLeft) then

		tt:AddSeparator(3,0,0,0,0)
		tt:AddHeader(C("dkyellow",L["Left in mailbox"]))
		tt:AddSeparator()

		local x,t = false,nil
		for i=1, #be_character_cache.order do
			local v = be_character_cache[be_character_cache.order[i]];
			local n = {strsplit("-",be_character_cache.order[i])}
			if (Broker_EverythingDB[name].showAllRealms~=true and n[2]~=ns.realm) or (Broker_EverythingDB[name].showAllFactions~=true and v.faction~=ns.player.faction) then
				-- do nothing
			elseif (v.mail and #v.mail.next3>0) then
				tt:AddLine(("%s (%s)"):format(C(v.class,ns.scm(n[1])),C("dkyellow",ns.scm(n[2]))),((v.mail.count>3) and "3 "..L["of"].." " or "")..v.mail.count.." "..L["mails"])
				for I,V in ipairs(v.mail.next3) do
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
				x = true;
			end
		end
			
		if x==false then
			tt:AddLine(L["No data"]);
		end
	end

	if (Broker_EverythingDB.showHints) then
		tt:AddSeparator(3,0,0,0,0)
		local l,c = tt:AddLine()
		tt:SetCell(l,1,C("copper",L["Right-click"]).." || "..C("green",L["Open option menu"]),nil,nil,2);
	end
end

local function createMenu(self,button)
	if (button=="RightButton") then
		if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt,ttName,true); end
		ns.EasyMenu.InitializeMenu();
		ns.EasyMenu.addConfigElements(name);
		ns.EasyMenu.ShowMenu(parent);
	end
end

------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
end

ns.modules[name].onevent = function(self,event,msg)
	if (event=="BE_HIDE_MINIMAPMAIL") and (not ns.coexist.found) then
		if (Broker_EverythingDB[name].hideMinimapMail) then
			ns.hideFrame("MiniMapMailFrame")
		else
			ns.unhideFrame("MiniMapMailFrame")
		end
	else
		if (HasNewMail()) and (Broker_EverythingDB[name].playsound) and (not alertLocked) then
			PlaySoundFile("Interface\\Addons\\"..addon.."\\media\\mailalert.mp3", "Master"); -- or SFX?
			alertLocked=true;
		elseif (not HasNewMail()) then
			alertLocked=false;
		end
		UpdateStatus(event);
	end
end

-- ns.modules[name].onupdate = function(self) end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(tooltip) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------

ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end

	tt = ns.LQT:Acquire(ttName, 2, "LEFT", "RIGHT")
	getTooltip(tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if (tt) then ns.hideTooltip(tt,ttName,true) end
end

ns.modules[name].onclick = createMenu; --function(self,button) end

-- ns.modules[name].ondblclick = function(self,button) end

ns.modules[name].coexist = function()
	if (not ns.coexist.found) and (Broker_EverythingDB[name].hideMinimapMail) then
		ns.hideFrame("MiniMapMailFrame");
	end
end

