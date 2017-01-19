
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
local titleLimit,textLimit = 32,10000;


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Notes" -- L["Notes"]
local ldbName,ttName,ttColumns,tt,createMenu = name, name.."TT",2;
local delIndex,editor,createTooltip,note_edit


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name]              = {iconfile="Interface\\Icons\\INV_Misc_PaperBundle04a", coords={0.05,0.95,0.05,0.95}}; --IconName::Notes--
I[name..'_alliance'] = {iconfile="Interface\\Icons\\INV_Misc_PaperBundle04c", coords={0.05,0.95,0.05,0.95}}; --IconName::Notes_alliance--
I[name..'_horde']    = {iconfile="Interface\\Icons\\INV_Misc_PaperBundle04b", coords={0.05,0.95,0.05,0.95}}; --IconName::Notes_horde--


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Display a broker with very simple notes functionality"],
	events = {
		"PLAYER_ENTERING_WORLD",
		"NEUTRAL_FACTION_SELECT_RESULT"
	},
	updateinterval = 30, -- 10
	config_defaults = {},
	config_allowed = {},
	config = {
		{ type="header", label=L[name], align="left", icon=I[name] },
	},
	clickOptions = {
		["1_new_note"] = {
			cfg_label = "Add new note",
			cfg_desc = "add new note",
			cfg_default = "__NONE",
			hint = "Add new note",
			func = function(self,button)
				local _mod=name;
				note_edit({},nil,"LeftButton");
			end
		},
		["9_open_menu"] = {
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
function createMenu(self)
	if (tt~=nil) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function updateBroker()
	local icon,obj = I[name],ns.LDB:GetDataObjectByName(ldbName);
	local faction = UnitFactionGroup("player"):lower();
	if faction~="neutral" then
		icon = I[name..'_'..faction];
	end
	if icon then
		obj.icon = icon.iconfile;
		obj.iconCoords = icon.coords;
	end
end

local function note_save(self)
	if self~=editor then
		InputBoxInstructions_OnTextChanged(self==editor.title and editor.title or editor.text);
	end

	local title = editor.title:GetText():trim();
	local text = editor.text:GetText():trim();
	local titleCount,textCount = strlen(title),strlen(text);

	editor.titleCount:SetFormattedText("%d / %d",titleCount,32);
	editor.textCount:SetFormattedText("%s / %s",ns.FormatLargeNumber(textCount),ns.FormatLargeNumber(10000));

	if textCount==0 then
		return; -- no text, no changes :)
	end

	if editor.index then
		ns.data[name][editor.index] = {title,text};
	else
		tinsert(ns.data[name],{title,text});
		editor.index = #ns.data[name];
	end
end

-- local function updateBroker() end

local function initEditor()
	editor = BrokerEverythingNotesEditor;

	editor.TitleText:SetText(("%s - %s"):format(L["Notes"],C("gray",addon)));
	editor.title.Instructions:SetText(L["Title (optional)"]);
	editor.text.Instructions:SetText(L["Input your note here..."]);

	editor.title:SetMaxLetters(titleLimit);
	editor.text:SetMaxLetters(textLimit);

	editor.titleCount:SetText("0 / "..titleLimit);
	editor.textCount:SetText("0 / "..ns.FormatLargeNumber(textLimit));

	editor:SetScript("OnHide",note_save);
	editor.title:SetScript("OnTextChanged",note_save);
	editor.text:SetScript("OnTextChanged",note_save);
end

function note_edit(self)
	local index,title,text = self.note_index,"","";
	if index then
		title = ns.data[name][index][1];
		text = ns.data[name][index][2];
	end
	if not editor then
		initEditor();
	end
	editor.index = index or false;
	editor.title:SetText(title);
	editor.text:SetText(text);
	editor:Show();
end

local function note_del(self)
	local index = self.note_index;
	if not index then
		return
	end
	if delIndex==index then
		tremove(ns.data[name],index);
		delIndex = nil;
	else
		delIndex = index;
	end
	createTooltip(tt);
end

local function note_options(self,_,button)
	if button=="LeftButton" then
		note_edit(self);
	elseif button=="RightButton" then
		note_del(self);
	end
end

local function note_show(self)
	local index = self.note_index;
	GameTooltip:SetOwner(tt,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(tt,"horizontal"));
	GameTooltip:SetText(strlen(ns.data[name][index][1])>0 and ns.data[name][index][1] or L["Note"]);
	local text = ns.data[name][index][2];
	if not text:match("\n") then
		text = ns.strWrap(text,64);
	end
	GameTooltip:AddLine(text,1,1,1);
	GameTooltip:Show();
end

local function note_hide(self)
	GameTooltip:Hide();
end

function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	tt:Clear();
	tt:AddHeader(C("dkyellow",L[name]));
	tt:AddSeparator();
	for i=1, #ns.data[name] do
		local str = ns.data[name][i][1];
		if strlen(str)==0 then
			str = strsplit("\n",ns.data[name][i][2]);
			str = ns.strCut(str,32);
		end
		local l=tt:AddLine(str);
		if delIndex==i then
			tt:SetCell(l,2,C("orange","("..L["really?"]..")"));
		end
		tt.lines[l].note_index = i;
		tt:SetLineScript(l,"OnMouseUp",note_options);
		tt:SetLineScript(l,"OnEnter",note_show);
		tt:SetLineScript(l,"OnLeave",note_hide);
	end
	if #ns.data[name]==0 then
		local l=tt:AddLine();
		tt:SetCell(l,1,C("gray",L["No entries found"]),nil,"LEFT",0);
	end

	tt:AddSeparator(4,0,0,0,0);
	local l=tt:AddLine();
	tt.lines[l].note_index = nil;
	tt:SetCell(l,1,C("ltgray",L["Add new note"]),nil,"CENTER",0);
	tt:SetLineScript(l,"OnMouseUp",note_edit);

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0);
		ns.AddSpannedLine(tt,C("ltblue",L["Left-click"]).." || "..C("green",L["Edit note"]));
		ns.AddSpannedLine(tt,C("ltblue",L["Right-click"]).." || "..C("green",L["Delete note"]));
		ns.clickOptions.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function()
	ldbName = (ns.profile.GeneralOptions.usePrefix and "BE.." or "")..name;
	if ns.data[name]==nil then
		ns.data[name] = {};
	end
end

ns.modules[name].onevent = function(self,event,...)
	if (event=="BE_UPDATE_CLICKOPTIONS") then
		ns.clickOptions.update(ns.modules[name],ns.profile[name]);
	else
		updateBroker();
	end
end
-- ns.modules[name].optionspanel = function(panel) end
-- ns.modules[name].onmousewheel = function(self,direction) end
-- ns.modules[name].ontooltip = function(self) end


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName,ttColumns, "LEFT","RIGHT"},{false},{self});
	delIndex = nil;
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end

