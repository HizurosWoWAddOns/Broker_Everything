
local addon, ns = ...
local C, L = ns.LC.color, ns.L
local panel,datapanel,profilepanel,infopanel,CharList_Update;

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
		parent[Index]:SetHeight(e:GetHeight()+6);
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
		e:SetMinMaxValues(data.min,data.max);

		if (data.format) then
			data.min = tonumber(data.format:format(data.min));
			data.max = tonumber(data.format:format(data.max));
			cur = tonumber(data.format:format(cur));
		end

		if(data.step)then
			e:SetValueStep(data.step);
		end
		e.value = cur;
		e:SetValue(e.value);

		do
			local m,M,c = data.min,data.max,cur;
			if (data.rep) then
				if (data.rep[data.min]) then
					m = data.rep[m];
				end
				if (data.rep[data.max]) then
					M = data.rep[M];
				end
				if (data.rep[cur]) then
					c = data.rep[c];
				end
			end

			e.Low:SetText(m);
			e.High:SetText(M);
			e.Current:SetText(c);
		end

		e:SetScript("OnValueChanged",function(self)
			local value = self:GetValue();
			if (data.format) then
				value = tonumber(data.format:format(value));
			end
			self:SetValue(value)
			panel:change(data.modName,data.name,value);
			if (data.rep) and (data.rep[value]) then
				value = data.rep[value];
			end
			self.Current:SetText(value);
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

		e.Text:SetText(L[data.values[current]]);

		--[[
		local btn=_G[e:GetName().."Button"];
		--btn:SetHitRectInsets(-(e:GetWidth()-(btn:GetWidth()*2)),-3,-3,-3)
		btn:SetScript("OnClick",function(self,button)
			local parent = self:GetParent();
			local data = parent.data;

			ns.EasyMenu.InitializeMenu();
			for v,t in ns.pairsByKeys(data.values) do
				ns.EasyMenu.addEntry({
					label = L[t],
					radio = v,
					--keepShown = false,
					checked = function()
						return (current==v);
					end,
					func = function(self)
						--Broker_EverythingDB[data.modName][data.name] = v;
						--ns.modules[modName].onevent({},"BE_UPDATE_CLICKOPTIONS");
						parent.Label:SetText(t);
						panel:change(data.modName,data.name,value);
					end
				});
			end
			ns.EasyMenu.ShowMenu(self);
			PlaySound("igMainMenuOptionCheckBoxOn");
		end);
		]]

		e:SetScript("OnClick",function(self,button)
			local data = self.data;
			ns.EasyMenu.InitializeMenu();
			for v,t in ns.pairsByKeys(data.values) do
				ns.EasyMenu.addEntry({
					label = L[t],
					radio = v,
					checked = function()
						return (current==v);
					end,
					func = function(self)
						e.Text:SetText(L[data.values[v]]);
						panel:change(data.modName,data.name,v);
						current = v;
						ns.EasyMenu.RefreshAll(menu);
					end
				});
			end
			ns.EasyMenu.ShowMenu(self);
			PlaySound("igMainMenuOptionCheckBoxOn");
		end);

		e:SetHitRectInsets(-3,-e.Label:GetWidth(),-3,-3)
		parent[Index]:SetHeight(e:GetHeight()+12);
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
	local f = CreateFrame("Frame", "BrokerEverythingOptionPanel", InterfaceOptionsFramePanelContainer, "BrokerEverythingOptionPanelTemplate");
	f.name, f.controls,f.changes = addon, {},{};

	function f:okay()
		local needs = false;
		for name1,value1 in pairs(f.changes) do
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
			f.Needs:SetText(L["An UI reload is necessary to apply all changes."]);
			f.Needs:Show();
		end
		wipe(f.changes);
		f:refresh();
		f.Apply:Disable();
	end

	function f:cancel()
		wipe(f.changes);
		f.Apply:Disable();
	end

	function f:default()
		wipe(Broker_EverythingDB);
		wipe(Broker_EverythingGlobalDB);
		wipe(f.changes);
		f.Apply:Disable();
	end

	function f:refresh()
		local cur,r,g,b,a;
		for i,v in pairs(f.controls) do
			if (v.data.modName) then
				if (f.changes[v.data.modName]) and (f.changes[v.data.modName][v.data.name]~=nil) then
					cur = f.changes[v.data.modName][v.data.name];
				else
					cur = Broker_EverythingDB[v.data.modName][v.data.name];
				end
			else
				if (f.changes[v.data.name]~=nil) then
					cur = f.changes[v.data.name];
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
					if _G[v:GetName().."Text"] and v.data and v.data.values and v.data.values[cur] then
						_G[v:GetName().."Text"]:SetText(v.data.values[cur]);
					end
				elseif (v.data.type=="color") then
					r,g,b,a=unpack(cur);
					v.Color:SetVertexColor(r,g,b,a);
				elseif (v.data.type=="input") then
					v:SetText(cur);
					v.Ok:Hide();
				end
			end
		end

		if (f:IsVisible()) then
			f.Apply:Show()
			f.Reload:Show()
			f.Reset:Show()
		end
	end

	function f:reset()
		for i,v in ipairs(f.controls)do
			if (v.Color) then
				v.info.cancelFunc()
			end
		end
		wipe(f.changes);
		f:refresh();
		f:ModList_Update();
		f.Apply:Disable();
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

	function f:change(name,key,value)
		local changed=false;
		if (name) then
			if (not f.changes[name]) then f.changes[name]={}; end
			if (hasChanged(Broker_EverythingDB[name][key],value)) then
				f.changes[name][key] = value;
				changed=true;
			end
		else
			if (hasChanged(Broker_EverythingDB[key],value)) then
				f.changes[key] = value;
				changed=true;
			end
		end
		if(changed)then
			f.Apply:Enable();
		end
	end

	function f:ModOpts_Choose(name)
		local p = f.Modules.Container;

		if (p.current) and (p.current.Hide) then
			p.current:Hide();
		end

		if (not p.frames[name]) then
			f:ModOpts_Build(name);
		end

		if (p.current==p.frames[name]) or (name=="DESC") then
			p.current=p.frames["DESC"];
		else
			p.current=p.frames[name];
		end

		p.current:Show();
		return p.current==p.frames[name];
	end

	function f:ModOpts_Build(name)
		local mod = ns.modules[name];
		if (mod) then
			local frame, i = CreateFrame("Frame", ("%s_%s"):format(addon,gsub(gsub(gsub(name,"_",""),"/","")," ","")), f.Modules.Container.child), 1;
			frame:SetPoint("TOPLEFT"); frame:SetSize(f.Modules.Container.child:GetWidth(),1); frame:Hide();
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

			f.Modules.Container.frames[name] = frame;
		end
	end

	function f:ModList_Update()
		local scroll = f.Modules.List;
		local button, index, offset, nButtons, nModules;

		if (not scroll.buttons) then
			f.Modules.List.update=f.ModList_Update;
			HybridScrollFrame_CreateButtons(f.Modules.List, "BEConfigPanel_ModuleButtonTemplate", 0, 0, nil, nil, 0, -mods.entryOffset);
			mods.entryHeight = f.Modules.List.buttons[1]:GetHeight();
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
					if (f.changes[name]) and (f.changes[name].enabled~=nil) then
						e = f.changes[name].enabled;
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
							if (f:ModOpts_Choose(self.data.name)) then
								mods.pointer=self.data.name;
							else
								mods.pointer=nil;
							end
						elseif (button=="RightButton") then
							local val = not Broker_EverythingDB[name].enabled;
							if (f.changes[name]) and (f.changes[name].enabled~=nil) then
								val = not f.changes[name].enabled;
							end
							f:change(name,"enabled",val);
						end
						f:ModList_Update()
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

	f:SetScript("OnShow", function()
		f.title:SetText(addon.." - "..L["Options"]);
		f.subTitle:SetText(L["Allows you to adjust the display options."]);

		f.Reset.tooltip = {RESET,L["Opens a little menu with 3 reset options"]};
		f.Reset:SetScript("OnEnter",tooltipOnEnter);
		f.Reset:SetScript("OnLeave",tooltipOnLeave);
		f.Reset:SetScript("OnClick",function(self,button)
			ns.EasyMenu.InitializeMenu();
			ns.EasyMenu.addEntry({
				label = L["Reset all data"],
				tooltip = {L["Reset all data"],L["Your current settings and all other data collected by some modules like mail on other chars or profession cooldowns of your twinks."]},
				func = function()
					ns.resetAllSavedVariables();
					f:reset()
				end,
			});
			ns.EasyMenu.addEntry({
				label = L["Reset config"],
				tooltip={L["Reset config"],L["Resets your global and module settings but not collected data about your twinks to display mail, profession cooldowns and more."]},
				func = function()
					ns.resetConfigs();
					f:reset()
				end,
			});
			ns.EasyMenu.addEntry({
				label = L["Reset unsaved changes"],
				tooltip = {L["Reset unsaved changes"],L["Resets your last unsaved changes. Not more..."]},
				func = function()
					f:reset()
				end,
				disabled = not f.Apply:IsEnabled()
			});
			ns.EasyMenu.ShowMenu(self);
		end);

		f.Reload.tooltip = {RELOADUI,L["Reloads your user interface. (It does not save changes)"]};
		f.Reload:SetScript("OnEnter",tooltipOnEnter);
		f.Reload:SetScript("OnLeave",tooltipOnLeave);
		f.Reload:SetScript("OnClick",ReloadUI);

		f.Apply.tooltip = {APPLY,L["Save changes without closing the option panel"]};
		f.Apply:SetScript("OnEnter",tooltipOnEnter);
		f.Apply:SetScript("OnLeave",tooltipOnLeave);
		f.Apply:SetScript("OnClick",f.okay);
		f.Apply:Disable();

		-- general options
		f.Generals.Title:SetText(L["General options"]);
		f.Generals:SetHitRectInsets(3,12,3,4)
		f.Generals.scrollBar:SetScale(0.725);
		local i = 1;
		for _,v in ipairs(ns.coreOptions) do
			if (build[v.type]) then
				if (v.set) and (v.get) then
					v.modName=false;
				end
				build[v.type](f.Generals.child, i, v, nil);
				i=i+1;
			end
		end
		--f.Generals.child:SetHeight(c)

		-- module options
		f.Modules.Title1:SetText(L["Modules"]);
		f.Modules.Title2:SetText(L["Module options"]);
		f.Modules.Title2:SetPoint("LEFT", f.Modules.List.split, "LEFT", 10,0);

		local tmp1,tmp2,d={},{};
		for k, v in pairs(ns.modules) do tmp1[L[k]] = k; end -- tmp1 to order modules by localized names

		tinsert(mods.list,1);
		for k, v in ns.pairsByKeys(tmp1) do -- mods.list as order list with names and boolean. the booleans indicates the header "With options" and "Without options"
			if(ns.modules[v].clickOptions)then
				ns.clickOptions.update(ns.modules[v],Broker_EverythingDB[v]);
			end
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
		f.Modules.All.tooltip = {ALL,L["Enable all modules"]};
		f.Modules.All:SetScript("OnEnter",tooltipOnEnter);
		f.Modules.All:SetScript("OnLeave",tooltipOnLeave);
		f.Modules.All:SetScript("OnClick",function()
			for i,v in pairs(ns.modules) do
				f:change(i,"enabled",true);
			end
			f:ModList_Update();
		end);

		f.Modules.None.tooltip = {NONE_KEY,L["Disable all modules"]};
		f.Modules.None:SetScript("OnEnter",tooltipOnEnter);
		f.Modules.None:SetScript("OnLeave",tooltipOnLeave);
		f.Modules.None:SetScript("OnClick",function()
			for i,v in pairs(ns.modules) do
				f:change(i,"enabled",false);
			end
			f:ModList_Update();
		end);

		f.Modules.List.scrollBar:SetScale(0.725);
		f:ModList_Update();

		-- options for any modules
		f.Modules.Container:SetHitRectInsets(3,12,3,4);
		f.Modules.Container.scrollBar:SetScale(0.725);
		f.Modules.Container.frames = {};

		local frame = CreateFrame("Frame", addon.."ModuleListInfoFrame", f.Modules.Container.child);
		frame:SetPoint("TOPLEFT"); frame:SetSize(f.Modules.Container.child:GetWidth(),1); frame:Hide();

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

		f.Modules.Container.frames["DESC"] = frame;
		f:ModOpts_Choose("DESC");

		f:SetScript("OnShow",nil --[[f.refresh]]);
	end);

	InterfaceOptions_AddCategory(f);
	panel = f;
	return f;
end

ns.datapanel = function()
	local f = CreateFrame("Frame", "BrokerEverythingDataPanel", InterfaceOptionsFramePanelContainer,"BrokerEverythingDataPanelTemplate");
	f.name, f.parent, f.controls, f.tmpCharCache = L["Character data"], addon, {},false;

	function f:okay()
		be_character_cache = CopyTable(f.tmpCharCache);
		f.tmpCharCache = false;
	end
	function f:cancel()
		f.tmpCharCache = false;
	end
	function f:default()
		--f.tmpCharCache = false;
	end
	function f:refresh()
		f.CharList.update();
	end
	function f:reset()
		f.tmpCharCache = false;
		be_character_cache = {order={ns.player.name_realm}};
		for i,v in ipairs({"name","class","faction","race"})do
			if(ns.player[v] and be_character_cache[ns.player.name_realm][v]~=ns.player[v])then
				be_character_cache[ns.player.name_realm][v] = ns.player[v];
			end
		end
		be_character_cache[ns.player.name_realm].level = UnitLevel("player");
	end

	local function CharList_OrderUp(name)
		tremove(f.tmpCharCache.order,f.tmpCharCache[name].orderId);
		tinsert(f.tmpCharCache.order,f.tmpCharCache[name].orderId-1,name);
	end

	local function CharList_OrderDown(name)
		tremove(f.tmpCharCache.order,f.tmpCharCache[name].orderId);
		tinsert(f.tmpCharCache.order,f.tmpCharCache[name].orderId+1,name);
	end

	local function CharList_Delete(name)
		tremove(f.tmpCharCache.order,f.tmpCharCache[name].orderId);
		f.tmpCharCache[name]=nil;
	end
	
	function CharList_Update()
		local scroll = f.CharList;
		local button, index, offset, nButtons, nEntries;

		if (not scroll.buttons) then
			f.CharList.update=CharList_Update;
			HybridScrollFrame_CreateButtons(f.CharList, "BECharacterListButtonTemplate", 0, 0, nil, nil, 0, -2);
		end

		if(f.tmpCharCache==false)then
			f.tmpCharCache = CopyTable(be_character_cache);
		end

		offset = HybridScrollFrame_GetOffset(scroll);
		nButtons = #scroll.buttons;
		nEntries = #f.tmpCharCache.order;

		for i=1, nButtons do
			button = scroll.buttons[i];
			index = offset+i;

			if (f.tmpCharCache.order[index]) then
				local name_realm = f.tmpCharCache.order[index];
				local name, realm = strsplit("-",name_realm);
				local data = f.tmpCharCache[name_realm];

				local factionIcon = " |TInterface\\minimap\\tracking\\BattleMaster:16:16:0:-1:16:16:0:16:0:16|t";
				if(data.faction~="Neutral")then
					factionIcon = " |TInterface\\PVPFrame\\PVP-Currency-"..data.faction..":16:16:0:-1:16:16:0:16:0:16|t";
				end

				if(data.orderId==nil or data.orderId~=index)then
					data.orderId=index;
				end

				button.Number:SetText(data.orderId..".");
				button.Name:SetText(C(data.class,name) .. factionIcon);
				button.Realm:SetText(realm);
				button.ClassIcon:SetTexCoord(unpack(_G.CLASS_ICON_TCOORDS[data.class:upper()]));

				button.OrderUp:Enable();
				button.OrderDown:Enable();

				button.OrderUp:SetScript("OnClick",function() CharList_OrderUp(name_realm); CharList_Update(); end);
				button.OrderDown:SetScript("OnClick",function() CharList_OrderDown(name_realm); CharList_Update(); end);

				if(data.orderId==1)then
					button.OrderUp:Disable();
				elseif(data.orderId==nEntries)then
					button.OrderDown:Disable();
				end

				button.Delete:SetScript("OnClick",function() CharList_Delete(name_realm); CharList_Update(); end);

				button:SetBackdropColor(1,.6,.1, index/2==floor(index/2) and .15 or .07);

				button:Show();
			else
				button:Hide();
			end
		end

		local height = f.CharList.buttonHeight + 1;
		HybridScrollFrame_Update(scroll, nEntries * height, nButtons * height);
	end

	f:SetScript("OnShow",function()
		f.title:SetText(addon.." - "..L["Character data"]);
		f.InfoLine0:SetText(L["Your options on this panel:"]);
		f.InfoLine1:SetText(L["1. Sort your characters"]);
		f.InfoLine1Sub:SetText(L["That means you can sort your chars like character choose panel and all modules with informations about your characters respect this order."]);
		f.InfoLine2:SetText(L["2. Delete character data"]);
		f.InfoLine2Sub:SetText(L["You can delete all collected data about your characters with a single click."]);

		_G[f:GetName().."DeleteAllText"]:SetText(L["Delete all character data"]);
		f.DeleteAll:SetScript("OnClick",function()  end);

		f.CharList.scrollBar:SetScale(0.725);
		CharList_Update();

		f:SetScript("OnShow",nil --[[f.refresh]]);
	end);

	InterfaceOptions_AddCategory(f);
	datapanel = f;
	return f;
end

ns.profilepanel = function()
	local f = CreateFrame("Frame", "BrokerEverythingProfilePanel", InterfaceOptionsFramePanelContainer); --, "BrokerEverythingOptionPanelTemplate");
	f.name, f.parent, f.controls, f.changes = L["Profiles"], addon, {},{};

	f:SetScript("OnShow",function()
		--f.title:SetText(addon.." - "..L["Options"]);
		--f.subTitle:SetText(L["Allows you to adjust the display options."]);
		f:SetScript("OnShow",nil --[[f.refresh]]);
	end);

	--InterfaceOptions_AddCategory(f);
	profilepanel = f;
	return f;
end

ns.infopanel = function()
	local f = CreateFrame("Frame", "BrokerEverythingInfoPanel", InterfaceOptionsFramePanelContainer); --, "BrokerEverythingOptionPanelTemplate");
	f.name, f.parent, f.controls, f.changes = L["Informations"], addon, {},{};
	
	f:SetScript("OnShow",function()
		--f.title:SetText(addon.." - "..L["Options"]);
		--f.subTitle:SetText(L["Allows you to adjust the display options."]);
		f:SetScript("OnShow",nil --[[f.refresh]]);
	end);

	--InterfaceOptions_AddCategory(f);
	infopanel = f;
	return f;
end

