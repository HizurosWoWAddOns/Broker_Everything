
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I


-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Notes" -- L["Notes"] L["ModDesc-Notes"]
local ttName,ttColumns,tt,module = name.."TT",2;
local delIndex,editor,createTooltip,note_edit
local titleLimit,textLimit = 32,10000;


-- register icon names and default files --
-------------------------------------------
I[name]              = {iconfile="Interface\\Icons\\INV_Misc_PaperBundle04a", coords={0.05,0.95,0.05,0.95}}; --IconName::Notes--
I[name..'_alliance'] = {iconfile="Interface\\Icons\\INV_Misc_PaperBundle04c", coords={0.05,0.95,0.05,0.95}}; --IconName::Notes_alliance--
I[name..'_horde']    = {iconfile="Interface\\Icons\\INV_Misc_PaperBundle04b", coords={0.05,0.95,0.05,0.95}}; --IconName::Notes_horde--


-- some local functions --
--------------------------
local function updateBroker()
	local icon,obj = I[name],ns.LDB:GetDataObjectByName(module.ldbName);
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
	editor.textCount:SetFormattedText("%s / %s",ns.FormatLargeNumber(name,textCount),ns.FormatLargeNumber(name,10000));

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
	editor.textCount:SetText("0 / "..ns.FormatLargeNumber(name,textLimit));

	editor:SetScript("OnHide",note_save);
	editor.title:SetScript("OnTextChanged",note_save);
	editor.text:SetScript("OnTextChanged",note_save);
end

function note_edit(self,index)
	local title,text = "","";
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

local function note_options(self,index,button)
	if button=="LeftButton" then
		note_edit(self,index);
	elseif button=="RightButton" then
		note_del(self,index);
	end
end

local function note_show(self,index)
	GameTooltip:SetOwner(tt,"ANCHOR_NONE");
	GameTooltip:SetPoint(ns.GetTipAnchor(tt,"horizontal"));
	GameTooltip:SetText(strlen(ns.data[name][index][1])>0 and ns.data[name][index][1] or COMMUNITIES_ROSTER_COLUMN_TITLE_NOTE);
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

	if tt.lines~=nil then tt:Clear(); end
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
		tt:SetLineScript(l,"OnMouseUp",note_options,i);
		tt:SetLineScript(l,"OnEnter",note_show,i);
		tt:SetLineScript(l,"OnLeave",note_hide);
	end
	if #ns.data[name]==0 then
		local l=tt:AddLine();
		tt:SetCell(l,1,C("gray",L["No entries found"]),nil,"LEFT",0);
	end

	tt:AddSeparator(4,0,0,0,0);
	local l=tt:AddLine();
	tt:SetCell(l,1,C("ltgray",L["Add new note"]),nil,"CENTER",0);
	tt:SetLineScript(l,"OnMouseUp",note_edit);

	if (ns.profile.GeneralOptions.showHints) then
		tt:AddSeparator(4,0,0,0,0);
		ns.AddSpannedLine(tt,C("ltblue",L["MouseBtnL"]).." || "..C("green",L["Edit note"]));
		ns.AddSpannedLine(tt,C("ltblue",L["MouseBtnR"]).." || "..C("green",L["Delete note"]));
		ns.ClickOpts.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


-- module functions and variables --
------------------------------------
module = {
	events = {
		"PLAYER_LOGIN",
		"NEUTRAL_FACTION_SELECT_RESULT"
	},
	config_defaults = {
		enabled = false,
	},
	clickOptionsRename = {
		["newnote"] = "1_new_note",
		["menu"] = "9_open_menu"
	},
	clickOptions = {
		["newnote"] = {"Add new note","module","newNote"},
		["menu"] = "OptionMenu"
	}
}

ns.ClickOpts.addDefaults(module,{
	newnote = "__NONE",
	menu = "_RIGHT"
});

function module.newNote()
	note_edit({},nil,"LeftButton");
end

function module.options()
	return {
		broker = nil,
		tooltip = nil,
		misc = {
			shortNumbers=true
		},
	}
end

function module.init()
	if ns.data[name]==nil then
		ns.data[name] = {};
	end
end

function module.onevent(self,event,arg1,...)
	if event=="BE_UPDATE_CFG" and arg1 and arg1:find("^ClickOpt") then
		ns.ClickOpts.update(name);
	else
		updateBroker();
	end
end

-- function module.optionspanel(panel) end
-- function module.onmousewheel(self,direction) end
-- function module.ontooltip(self) end

function module.onenter(self)
	if (ns.tooltipChkOnShowModifier(false)) then return; end
	tt = ns.acquireTooltip({ttName,ttColumns, "LEFT","RIGHT"},{false},{self});
	delIndex = nil;
	createTooltip(tt);
end

-- function module.onleave(self) end
-- function module.onclick(self,button) end
-- function module.ondblclick(self,button) end


-- final module registration --
-------------------------------
ns.modules[name] = module;
