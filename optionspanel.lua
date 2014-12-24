
local addon, ns = ...
local C, L = ns.LC.color, ns.L

local panel;

local function setPoints(element, sibling, points, fir)
	local parent = sibling.elem
	if not points then
		if fir==sibling.dot then
			if element.type=="dropdown" or element.type=="slider" or element.type=="editbox" then
				points = {edgeSelf="TOPLEFT", edgeSibling="TOPLEFT", x=0, y=-14}
			else
				points = {edgeSelf="TOPLEFT", edgeSibling="TOPLEFT", x=0, y=0}
			end
		else
			points = {edgeSelf="TOPLEFT", edgeSibling="TOPLEFT", x=200, y=0}
		end
	end
	if points.sibling then
		if points.sibling=="dot" then
			parent = sibling.dot
		else
			parent = points.sibling
		end
	end
	element:SetPoint(points.edgeSelf,parent or sibling.elem,points.edgeSibling,points.x,points.y)
end

local function getIconSets()
	local t = {NONE=L["None"]}
	local l = ns.LSM:List((addon.."_Iconsets"):lower())
	if type(l)=="table" then
		for i,v in pairs(l) do
			t[v] = v
		end
	end
	return t
end

local function tooltipOnEnter(self)
	if (self.tooltip) then
		GameTooltip:SetOwner(self,"ANCHOR_".. (self.tooltip_anchor or "TOP"));
		GameTooltip:ClearLines();
		GameTooltip:AddLine(self.tooltip[1]);
		for i=2, #self.tooltip do
			GameTooltip:AddLine(self.tooltip[i],1,1,1,1);
		end
		GameTooltip:Show();
	end
end

local function tooltipOnLeave(self)
	GameTooltip:Hide();
end

local function init(parent, index, data)
	local Index,v="Entry"..index,nil;
	if (not parent[Index]) then
		local name;
		if (data.name) then
			name = addon..Index..data.name;
		end
		parent[Index] = CreateFrame("Frame", parent:GetName()..Index, parent, "BEConfigPanel_OptionsTemplate");
		if(index==1) then
			parent[Index]:SetPoint("TOP",0,-5);
		else
			parent[Index]:SetPoint("TOP",parent["Entry"..(index-1)],"BOTTOM");
		end
	end
	for i,n in ipairs({"toggle","select","color","icon","header","desc","separator","slider","input"}) do
		v = parent[Index]["__"..n];
		if (v) then
			if (n==data.type) then
				v.data = data;
				if (data.tooltip) then
					if (type(data.tooltip)=="function") then
						v.tooltip = {data.label,data.tooltip()};
					else
						v.tooltip = {data.label,data.tooltip};
					end
					v.tooltip_anchor="RIGHT";
					v:SetScript("OnEnter",tooltipOnEnter);
					v:SetScript("OnLeave",tooltipOnLeave);
					local def,o=false,nil;

					if(data.modName)then
						if(ns.modules[data.modName]) and (type(ns.modules[data.modName].config_defaults)=="table") and (ns.modules[data.modName].config_defaults[data.name]~=nil) then
							o=ns.modules[data.modName].config_defaults[data.name];
						end
					else
						if(ns.coreOptionDefaults[data.name]~=nil)then
							o=ns.coreOptionDefaults[data.name];
						elseif(data.name=="global")then
							o=false;
						end
					end
					if (o~=nil) then
						if(data.type=="toggle")then
							def = (o) and "On" or "Off";
						elseif(data.type=="select")then
							def="User defined";
							if (data.values[o]) then
								def=data.values[o];
							end
						elseif(data.rep) and (data.rep[o])then
							def=data.rep[o];
						elseif(data.pat)then
							def=data.pat:format(o);
						elseif(type(o)~="table")then
							def=o;
						end
					end
					if(def)then tinsert(v.tooltip,C("gray",L["Default: %s"]:format(L[def]))); end
				end
				if (data.disabledMessage) then
					local o = parent[Index].__disabledOverlay;
					o.tooltip = data.disabledMessage;
					o.tooltip_anchor="RIGHT";
					o:SetScript("OnEnter",tooltipOnEnter);
					o:SetScript("OnLeave",tooltipOnLeave);
					o:Show();
					v:Disable();
				end
				if (n~="header") and (n~="desc") and (n~="separator") and (n~="icon") then
					local n = data.name;
					if (data.modName) then n=data.modName.."::"..n; end
					panel.controls[n] = v;
				end
				v:Show();
			else
				v.data,v.db,v.tooltip,v.tooltip_anchor=nil,nil,nil,nil;
				if (n~="header") and (n~="desc") and (n~="separator") and (n~="icon") then
					v:SetScript("OnEnter",nil);
					v:SetScript("OnLeave",nil);
				end
				v:Hide();
			end
		end
	end
	return Index;
end

local build = {
	header = function(parent,index,data)
		local Index,s,d,i,h,icon = init(parent,index,data),"",ns.modules[data.modName];
		i,h = parent[Index].__icon, parent[Index].__header;

		if (data.icon==true) and (ns.I[data.modName..(d.icon_suffix or "")]) then
			icon = ns.I[data.modName..(d.icon_suffix or "")];
		elseif (type(data.icon)=="table") and (data.icon.iconfile) then
			icon = data.icon;
		end

		if (icon) then
			i:SetTexture(icon.iconfile);
			if (icon.coords) then
				i:SetTexCoord(unpack(icon.coords));
			end
			i:Show();
			h:SetPoint("LEFT",i,"RIGHT",4,0);
		end

		h:SetText(data.label);
		if (type(data.align)=="string") then
			h:SetJustifyH(data.align:upper());
		end

		parent[Index]:SetHeight(h:GetHeight()+6);
	end,

	desc = function(parent,index,data)
		local Index = init(parent,index,data);
		local e = parent[Index].__desc;
		e:SetNonSpaceWrap(true);
		e:SetWidth(180);
		e:SetText(data.text);
		if (type(data.align)=="string") then
			e:SetJustifyH(data.align:upper());
		end
		parent[Index]:SetHeight(e:GetHeight()+6);
	end,

	icon = function(parent,index,data)
		local Index,e,icon = init(parent,index,data);
		e = parent[Index].__icon;

		if (data.icon==true) and (ns.I[data.modName..(d.icon_suffix or "")]) then
			icon = ns.I[data.modName..(d.icon_suffix or "")];
		elseif (type(data.icon)=="table") and (data.icon.iconfile) then
			icon = data.icon;
		end

		if (icon) then
			e:SetTexture(icon.iconfile);
			if (icon.coords) then
				e:SetTexCoord(unpack(icon.coords));
			end
			parent[Index]:SetHeight( e:GetHeight()+6);
		end
	end,

	separator = function(parent,index,data)
		local Index = init(parent,index,data);
		if (type(data.alpha)~="number") then
			data.alpha=1;
		end
		parent[Index].__separator:SetAlpha(data.alpha);
		if (type(data.height)=="number") then
			parent[Index]:SetHeight(data.height);
		else
			parent[Index]:SetHeight(10);
		end
	end,

	toggle = function(parent,index,data)
		local Index,cur = init(parent,index,data);
		local e = parent[Index].__toggle;
		if (data.modName) then
			e:SetChecked(not not Broker_EverythingDB[data.modName][data.name]);
		else
			e:SetChecked(not not Broker_EverythingDB[data.name]);
		end
		e.data=data;
		e.Text:SetWidth(160);
		e.Text:SetText(data.label);
		e:SetHitRectInsets(0, -e.Text:GetWidth() - 1, 0, 0);
		e:SetScript("OnClick",function(self,button)
			self:SetChecked(not not self:GetChecked());
			panel:change(data.modName,data.name,not not self:GetChecked());
		end);
		parent[Index]:SetHeight(e:GetHeight());
	end,

	slider = function(parent,index,data)
		local Index,cur = init(parent,index,data);
		local e = parent[Index].__slider;
		if (data.modName) then
			cur = Broker_EverythingDB[data.modName][data.name];
		else
			cur = Broker_EverythingDB[data.name];
		end
		e.data=data;
		e.Low,e.High = _G[e:GetName().."Low"],_G[e:GetName().."High"];
		e.Text:SetText(data.label);
		if (data.rep) and (data.rep[data.min])then
			e.Low:SetText(data.rep[data.min]);
		else
			e.Low:SetFormattedText(data.pat,data.min);
		end
		if (data.rep) and (data.rep[data.max]) then
			e.High:SetText(data.rep[data.max]);
		else
			e.High:SetFormattedText(data.pat,data.max);
		end
		if (data.rep) and (data.rep[cur]) then
			e.Current:SetText(data.rep[cur]);
		else
			e.Current:SetFormattedText(data.pat, cur);
		end
		e:SetMinMaxValues(data.min,data.max);
		if(data.step)then
			e:SetValueStep(data.step);
		end
		if (cur) then
			e.value = ("%d"):format(cur);
		else
			e.value = data.default;
		end
		e:SetValue(e.value);
		e:SetScript("OnValueChanged",function(self)
			local value = self:GetValue();
			if (data.format) then
				value = data.format:format(value);
			end
			self:SetValue(value)
			if (data.rep) and (data.rep[value]) then
				self.Current:SetText(data.rep[value]);
			else
				self.Current:SetFormattedText(data.pat, value);
			end
			panel:change(data.modName,data.name,value);
		end);
		parent[Index]:SetHeight(e:GetHeight()+30);
	end,

	select = function(parent,index,data)
		local Index = init(parent,index,data);
		local e = parent[Index].__select;

		local current;
		if (data.modName) then
			current = Broker_EverythingDB[data.modName][data.name];
		else
			current = Broker_EverythingDB[data.name];
		end

		e.data=data;
		e.Label:SetText(data.label);
		e.value=current;

		UIDropDownMenu_SetWidth(e, 140);
		UIDropDownMenu_Initialize(e, function()
			for v,t in ns.pairsByKeys(data.values) do
				local info = UIDropDownMenu_CreateInfo();
				info.value,info.text,info.arg1,info.arg2=v,t,e,v;
				info.func = function(self,frame,value)
					UIDropDownMenu_SetSelectedValue(frame, value);
					panel:change(data.modName,data.name,value);
				end
				UIDropDownMenu_AddButton(info);
			end
		end);

		UIDropDownMenu_SetSelectedValue(e, current);

		local btn=_G[e:GetName().."Button"];
		btn:SetHitRectInsets(-(e:GetWidth()-(btn:GetWidth()*2)),-3,-3,-3)

		parent[Index]:SetHeight(e:GetHeight()+e.Label:GetHeight()+6);
	end,

	color = function(parent,index,data)
		local Index,cur = init(parent,index,data);
		local e = parent[Index].__color;
		if (data.modName) then
			cur = Broker_EverythingDB[data.modName][data.name];
		else
			cur = Broker_EverythingDB[data.name];
		end
		e.data=data;
		e.data.prev={r=cur[1],g=cur[2],b=cur[3],opacity=1-(cur[4] or 1)};
		e.Text:SetText(data.label);
		e.Color:SetVertexColor(unpack(cur or {1,1,1,1}));
		e:SetHitRectInsets(0, -e.Text:GetWidth() - 1, 0, 0)

		e:SetScript("OnClick",function(self)
			local cur;
			if (data.modName) then
				cur = Broker_EverythingDB[data.modName][data.name];
			else
				cur = Broker_EverythingDB[data.name];
			end
			self.info = {
				ignore=2,
				swatchFunc = function()
					if (self.info.ignore>0)then
						self.info.ignore=self.info.ignore-1;
						return false;
					end
					local f,i,r,g,b,a = "%0.4f",self.info,ColorPickerFrame:GetColorRGB();
					a = OpacitySliderFrame:GetValue();
					r=f:format(r); g=f:format(g); b=f:format(b); a=f:format(a);
					self.info.r,self.info.g,self.info.b,self.info.opacity = r,g,b,a;
					panel:change(data.modName,data.name,{r,g,b,1-a});
					e.Color:SetVertexColor(r,g,b,1-a);
				end,
				r = cur[1] or 1,
				g = cur[2] or 1,
				b = cur[3] or 1,
				cancelFunc = function()
					local i=self.info;
					i.r,i.g,i.b,i.opacity=unpack(cur);
					i.opacity=1-i.opacity;
					panel:change(data.modName,data.name,cur);
				end
			};

			if (data.opacity==true) then
				self.info.hasOpacity = true;
				self.info.opacityFunc = self.info.swatchFunc;
				self.info.opacity = 1-(cur[4] or 1);
			end
			OpenColorPicker(self.info)
		end);

		parent[Index]:SetHeight(e:GetHeight());
	end,

	input = function(parent,index,data)
		local Index,cur = init(parent,index,data);
		local e = parent[Index].__input;
		if (data.modName) then
			cur = Broker_EverythingDB[data.modName][data.name];
		else
			cur = Broker_EverythingDB[data.name];
		end
		e.data=data;
		e.prev=cur;

		e.Label:SetText(data.label);
		e:SetText(cur);

		local change = function()
			panel:change(data.modName,data.name,e:GetText());
			e:ClearFocus();
			e.Ok:Hide();
		end

		e:SetScript("OnEnterPressed",function(self) change() end);
		e.Ok:SetScript("OnClick",function(self) change() end);

		e:SetScript("OnTextChanged",function(self,changed)
			if (changed) then
				e.Ok:Show();
			end
		end);

		e:SetScript("OnEscapePressed",function(self)
			e:SetText(e.prev);
			self:ClearFocus();
			e.Ok:Hide();
		end);

		parent[Index]:SetHeight(e:GetHeight()+e.Label:GetHeight()+6);
	end
};

ns.optionpanel = function()
	local mods = {list={},events={},needs={},pointer=nil,entryHeight=0,entryOffset=0};
	panel = CreateFrame("Frame", "BrokerEverythingOptionPanel", InterfaceOptionsFramePanelContainer, "BrokerEverythingOptionPanelTemplate");
	panel.name, panel.controls,panel.changes = addon, {},{};

	function panel:okay()
		local needs = false;
		for name1,value1 in pairs(panel.changes) do
			if (type(value1)=="table") and (name1~="iconcolor") then
				for name2,value2 in pairs(value1) do
					Broker_EverythingDB[name1][name2]=value2;
					if (mods.events[name1]) and (mods.events[name1][name2]) then
						ns.modules[name1].onevent({}, (mods.events[name1][name2]==true) and "BE_DUMMY_EVENT" or mods.events[name1][name2]);
					end
					if (mods.needs[name1]) and (mods.needs[name1][name2]~=nil) then
						if (type(value2)~="boolean") then
							needs=true;
						elseif (ns.needs[name1][name2]==value2) or (ns.needs[name1][name2]=="both") then
							needs=true;
						end
					end
					if(name2=="enabled")then
						if(value2)then
							if value2==true and ns.LDB:GetDataObjectByName(name1)==nil then
								ns.moduleInit(name1);
								if (ns.modules[name1].onevent) then
									ns.modules[name1].onevent({},"ADDON_LOADED",addon);
								end
							end
						else
							needs = true;
						end
					end
				end
			else
				Broker_EverythingDB[name1]=value1;
				if (name1=="iconcolor") then
					ns.updateIconColor(true);
				end
			end
		end

		if (needs) then
			panel.Needs:SetText(L["An UI reload is necessary to apply all changes."]);
			panel.Needs:Show();
		end
		wipe(panel.changes);
		panel:refresh();
		panel.Apply:Disable();
	end

	function panel:cancel()
		wipe(panel.changes);
		panel.Apply:Disable();
	end

	function panel:default()
		wipe(Broker_EverythingDB);
		wipe(Broker_EverythingGlobalDB);
		wipe(panel.changes);
		panel.Apply:Disable();
	end

	function panel:refresh()
		local cur,r,g,b,a;
		for i,v in pairs(panel.controls) do
			if (v.data.modName) then
				if (panel.changes[v.data.modName]) and (panel.changes[v.data.modName][v.data.name]~=nil) then
					cur = panel.changes[v.data.modName][v.data.name];
				else
					cur = Broker_EverythingDB[v.data.modName][v.data.name];
				end
			else
				if (panel.changes[v.data.name]~=nil) then
					cur = panel.changes[v.data.name];
				else
					cur = Broker_EverythingDB[v.data.name];
				end
			end

			if (cur~=nil) then
				if (v.data.type=="toggle") then
					v:SetChecked(cur);
				elseif (v.data.type=="slider") then
					v:SetValue(cur);
				elseif (v.data.type=="select") then
					v.selectedValue=cur;
					_G[v:GetName().."Text"]:SetText(v.data.values[cur]);
				elseif (v.data.type=="color") then
					r,g,b,a=unpack(cur);
					v.Color:SetVertexColor(r,g,b,a);
				elseif (v.data.type=="input") then
					v:SetText(cur);
					v.Ok:Hide();
				end
			end
		end

		if (panel:IsVisible()) then
			panel.Apply:Show()
			panel.Reload:Show()
			panel.Reset:Show()
		end
	end

	function panel:reset()
		for i,v in ipairs(panel.controls)do
			if (v.Color) then
				v.info.cancelFunc()
			end
		end
		wipe(panel.changes);
		panel:refresh();
		panel:ModList_Update();
		panel.Apply:Disable();
	end

	local function hasChanged(o,n)
		if (type(o)=="table") then
			local r = false;
			for i,v in pairs(o) do
				if(v~=n[i])then
					r=true;
				end
			end
			return r;
		end
		return (o~=n);
	end

	function panel:change(name,key,value)
		local changed=false;
		if (name) then
			if (not panel.changes[name]) then panel.changes[name]={}; end
			if (hasChanged(Broker_EverythingDB[name][key],value)) then
				panel.changes[name][key] = value;
				changed=true;
			end
		else
			if (hasChanged(Broker_EverythingDB[key],value)) then
				panel.changes[key] = value;
				changed=true;
			end
		end
		if(changed)then
			panel.Apply:Enable();
		end
	end

	function panel:ModOpts_Choose(name)
		local p = panel.Modules.Container;

		if (p.current) and (p.current.Hide) then
			p.current:Hide();
		end

		if (not p.frames[name]) then
			panel:ModOpts_Build(name);
		end

		if (p.current==p.frames[name]) or (name=="DESC") then
			p.current=p.frames["DESC"];
		else
			p.current=p.frames[name];
		end

		p.current:Show();
		return p.current==p.frames[name];
	end

	function panel:ModOpts_Build(name)
		local mod = ns.modules[name];
		if (mod) then
			local frame, i = CreateFrame("Frame", ("%s_%s"):format(addon,gsub(gsub(gsub(name,"_",""),"/","")," ","")), panel.Modules.Container.child), 1;
			frame:SetPoint("TOPLEFT"); frame:SetSize(panel.Modules.Container.child:GetWidth(),1); frame:Hide();
			local icon = ns.I[name];

			if (mod.config) and (#mod.config>0) then
				tinsert(mod.config,1,{type="separator", alpha=0, height=7 });
				if (#mod.config==2) then
					tinsert(mod.config,{type="separator"});
					tinsert(mod.config,{type="desc", text=L["This module has no options"]});
				end
				tinsert(mod.config,{type="separator",alpha=0,height=30});
				for _, entry in ipairs(mod.config) do
					if (type(entry.disabled)=="function") then
						local h,m = entry.disabled();
						if (h) then
							entry.disabledMessage = {h,m};
						end
						entry.disabled=false;
					end
					if (build[entry.type]) and (not entry.disabled) then
						if (entry.set) and (entry.get) then
							entry.modName = false;
						else
							entry.modName = name;
						end
						build[entry.type](frame, i, entry);
						i=i+1;
						if (entry.event) then
							if (not mods.events[name]) then mods.events[name] = {}; end
							mods.events[name][entry.name] = entry.event;
						end
						if (entry.needs) then
							if (not mods.needs[name]) then mods.needs[name] = {}; end
							mods.needs[name][entry.name] = entry.needs;
						end
					end
				end
			end

			panel.Modules.Container.frames[name] = frame;
		end
	end

	function panel:ModList_Update()
		local scroll = panel.Modules.List;
		local button, index, offset, nButtons;

		if (not scroll.buttons) then
			panel.Modules.List.update=panel.ModList_Update;
			HybridScrollFrame_CreateButtons(panel.Modules.List, "BEConfigPanel_ModuleButtonTemplate", 0, 0, nil, nil, 0, -mods.entryOffset);
			mods.entryHeight = panel.Modules.List.buttons[1]:GetHeight();
		end

		offset = HybridScrollFrame_GetOffset(scroll);
		nButtons = #scroll.buttons;
		nModules = #mods.list;

		for i=1, nButtons do
			button = scroll.buttons[i];
			index = offset+i;

			if (mods.list[index]) then
				local name = mods.list[index];

				if (type(name)=="number") then
					button.name:SetText( (name==1) and L["With options"] or L["Without options"] );
					button.Bg:Hide();
					button.pointer:Hide();
					button.StyleN:Hide();
					button:Disable();
				elseif (ns.modules[name]) then
					local d,e = ns.modules[name],Broker_EverythingDB[name].enabled;
					if (panel.changes[name]) and (panel.changes[name].enabled~=nil) then
						e = panel.changes[name].enabled;
					end
					button.data = {name=name,db=Broker_EverythingDB[name]};
					button.name:SetText(L[name]);

					button.Bg:Show()
					if (d.noBroker) then -- no broker, can't be disabled
						button.Bg:SetVertexColor(0.5,0.5,0.5,0.5);
					elseif (e) then
						button.Bg:SetVertexColor(0,1,0,0.5);
					else
						button.Bg:SetVertexColor(1,0,0,0.5);
					end

					if (mods.pointer==name) then
						button.pointer:Show();
					else
						button.pointer:Hide();
					end

					button:RegisterForClicks("AnyUp");
					button:SetScript("OnClick",function(self,button)
						if (button=="LeftButton") then
							if (panel:ModOpts_Choose(self.data.name)) then
								mods.pointer=self.data.name;
							else
								mods.pointer=nil;
							end
						elseif (button=="RightButton") then
							local val = not Broker_EverythingDB[name].enabled;
							if (panel.changes[name]) and (panel.changes[name].enabled~=nil) then
								val = not panel.changes[name].enabled;
							end
							panel:change(name,"enabled",val);
						end
						panel:ModList_Update()
					end);

					button.tooltip_anchor="LEFT";
					button.tooltip = {
						L[name],
						d.tooltip or d.desc,
						C("copper",L["Left-click"]).." || "..C("green",L["Show options"]),
					}
					if (not d.noBroker) then
						tinsert(button.tooltip,C("copper",L["Right-click"]).." || "..C("green",(e) and L["Disable this module"] or L["Enable this module"]));
						button.tooltip[1] = button.tooltip[1].. " ("..C((e) and "green" or "red",(e) and L["Enabled"] or L["Disabled"])..")";
					end
					button:SetScript("OnEnter",tooltipOnEnter);
					button:SetScript("OnLeave",tooltipOnLeave);
					button.StyleN:Show();
					button:Enable();
				end
				button:Show();
			else
				button:Hide();
			end
		end

		local height = mods.entryHeight + mods.entryOffset;
		HybridScrollFrame_Update(scroll, nModules * height, nButtons * height);
	end

	panel:SetScript("OnShow", function()
		panel.title:SetText(addon.." - "..L["Options"]);
		panel.subTitle:SetText(L["Allows you to adjust the display options."]);

		panel.Reset.tooltip = {RESET,L["Opens a little menu with 3 reset options"]};
		panel.Reset:SetScript("OnEnter",tooltipOnEnter);
		panel.Reset:SetScript("OnLeave",tooltipOnLeave);
		panel.Reset:SetScript("OnClick",function(self,button)
			ns.EasyMenu.InitializeMenu();
			ns.EasyMenu.addEntry({
				label = L["Reset all data"],
				tooltip = {L["Reset all data"],L["Your current settings and all other data collected by some modules like mail on other chars or profession cooldowns of your twinks."]},
				func = function()
					ns.resetAllSavedVariables();
					panel:reset()
				end,
			});
			ns.EasyMenu.addEntry({
				label = L["Reset config"],
				tooltip={L["Reset config"],L["Resets your global and module settings but not collected data about your twinks to display mail, profession cooldowns and more."]},
				func = function()
					ns.resetConfigs();
					panel:reset()
				end,
			});
			ns.EasyMenu.addEntry({
				label = L["Reset unsaved changes"],
				tooltip = {L["Reset unsaved changes"],L["Resets your last unsaved changes. Not more..."]},
				func = function()
					panel:reset()
				end,
				disabled = not panel.Apply:IsEnabled()
			});
			ns.EasyMenu.ShowMenu(self);
		end);

		panel.Reload.tooltip = {RELOADUI,L["Reloads your user interface. (It does not save changes)"]};
		panel.Reload:SetScript("OnEnter",tooltipOnEnter);
		panel.Reload:SetScript("OnLeave",tooltipOnLeave);
		panel.Reload:SetScript("OnClick",ReloadUI);

		panel.Apply.tooltip = {APPLY,L["Save changes without closing the option panel"]};
		panel.Apply:SetScript("OnEnter",tooltipOnEnter);
		panel.Apply:SetScript("OnLeave",tooltipOnLeave);
		panel.Apply:SetScript("OnClick",panel.okay);
		panel.Apply:Disable();

		-- general options
		panel.Generals.Title:SetText(L["General options"]);
		panel.Generals:SetHitRectInsets(3,12,3,4)
		panel.Generals.scrollBar:SetScale(0.725);
		local i = 1;
		for _,v in ipairs(ns.coreOptions) do
			if (build[v.type]) then
				if (v.set) and (v.get) then
					v.modName=false;
				end
				build[v.type](panel.Generals.child, i, v, nil);
				i=i+1;
			end
		end
		--panel.Generals.child:SetHeight(c)

		-- module options
		panel.Modules.Title1:SetText(L["Modules"]);
		panel.Modules.Title2:SetText(L["Module options"]);
		panel.Modules.Title2:SetPoint("LEFT", panel.Modules.List.split, "LEFT", 10,0);

		local tmp1,tmp2,d={},{};
		for k, v in pairs(ns.modules) do tmp1[L[k]] = k; end -- tmp1 to order modules by localized names

		tinsert(mods.list,1);
		for k, v in ns.pairsByKeys(tmp1) do -- mods.list as order list with names and boolean. the booleans indicates the header "With options" and "Without options"
			if (type(ns.modules[v].config)=="table") and (#ns.modules[v].config>1) then
				tinsert(mods.list,v);
			else
				tinsert(tmp2,v); -- modules without options into a second tmp table to add them after the second header indicator
			end
		end
		tinsert(mods.list,-1);
		for i,v in ipairs(tmp2) do
			tinsert(mods.list,v);
		end
		tmp1,tmp2=nil,nil;

		-- module list
		panel.Modules.All.tooltip = {ALL,L["Enable all modules"]};
		panel.Modules.All:SetScript("OnEnter",tooltipOnEnter);
		panel.Modules.All:SetScript("OnLeave",tooltipOnLeave);
		panel.Modules.All:SetScript("OnClick",function()
			for i,v in pairs(ns.modules) do
				panel:change(i,"enabled",true);
			end
			panel:ModList_Update();
		end);

		panel.Modules.None.tooltip = {NONE_KEY,L["Disable all modules"]};
		panel.Modules.None:SetScript("OnEnter",tooltipOnEnter);
		panel.Modules.None:SetScript("OnLeave",tooltipOnLeave);
		panel.Modules.None:SetScript("OnClick",function()
			for i,v in pairs(ns.modules) do
				panel:change(i,"enabled",false);
			end
			panel:ModList_Update();
		end);

		panel.Modules.List.scrollBar:SetScale(0.725);
		panel:ModList_Update();

		-- options for any modules
		panel.Modules.Container:SetHitRectInsets(3,12,3,4);
		panel.Modules.Container.scrollBar:SetScale(0.725);
		panel.Modules.Container.frames = {};

		local frame = CreateFrame("Frame", addon.."ModuleListInfoFrame", panel.Modules.Container.child);
		frame:SetPoint("TOPLEFT"); frame:SetSize(panel.Modules.Container.child:GetWidth(),1); frame:Hide();

		local icon1="Interface\\Tooltips\\ReforgeGreenArrow:16:16:0:0:16:16:16:0:0:16"
		local icon2="Interface\\OPTIONSFRAME\\UI-OptionsFrame-NewFeatureIcon:0";
		local str="|T%s|t "..C("ltblue","%s").."|n%s";

		local desc = {
			{type="separator", alpha=0, height=40 },
			{type="desc", text=str:format(icon1,L["Left-click"],L["Display the options for this module"]), align="LEFT" },
			{type="separator", alpha=0 },
			{type="desc", text=str:format(icon1,L["Right-click"],L["Enable/Disable the module"]), align="LEFT", type="desc" },
			{type="separator", alpha=0, height=40 },
			{type="desc", text=str:format(icon2,RESET,L["Opens a little menu with 3 reset options"]), align="LEFT", type="desc" },
			{type="separator", alpha=0 },
			{type="desc", text=str:format(icon2,RELOADUI,L["Reloads your user interface. (It does not save changes)"]), align="LEFT" },
			{type="separator", alpha=0 },
			{type="desc", text=str:format(icon2,APPLY,L["Save changes without closing the option panel"]), align="LEFT" }
		}
		for i,v in ipairs(desc) do
			if (build[v.type]) then
				build[v.type](frame,i,v);
			end
		end

		panel.Modules.Container.frames["DESC"] = frame;
		panel:ModOpts_Choose("DESC");

		panel:SetScript("OnShow",nil --[[panel.refresh]]);
	end);

	InterfaceOptions_AddCategory(panel);
	return panel;
end



