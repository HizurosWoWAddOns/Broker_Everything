
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
	local t = {NONE=NONE}
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
					if type(data.tooltip)=="function" then
						v.tooltip = {data.label,data.tooltip()};
					elseif type(data.tooltip)=="table" then
						v.tooltip = data.tooltip;
						tinsert(v.tooltip,1,data.label);
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
						if(ns.defaultGeneralOptions[data.name]~=nil)then
							o=ns.defaultGeneralOptions[data.name];
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
				if (n~="header") and (n~="desc") and (n~="separator") and (n~="icon") and (data.name) then
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

local functions = {
	toggleOnClick = function(self,button)
		local data,v = self.data,not not self:GetChecked();
		self:SetChecked(v);
		if data.set then
			data.set(v);
		else
			panel:change(data.modName,data.name,v);
		end
	end,
	sliderOnValueChanged = function(self)
		local value,data = self:GetValue(),self.data;
		if (data.format) then
			value = tonumber(data.format:format(value));
		end
		if data.step then
			value = floor(value/data.step)*data.step;
		end
		self:SetValue(value);
		if data.set then
			data.set(value);
		else
			panel:change(data.modName,data.name,value);
		end
		if (data.rep) and (data.rep[value]) then
			value = data.rep[value];
		end
		self.Current:SetText(value);
	end,
	selectOnClick = function(self,button)
		local data, values, _ = self.data;
		values = data.values;

		if(data.get)then
			_, values = data.get();
		end

		ns.EasyMenu.InitializeMenu();

		for k,d in ns.pairsByKeys(values) do
			local add,current = true;
			local entry={
				radio = k,
				keepShown = data.keepShown~=nil and data.keepShown or false,
				checked = function() return (current==k); end,
				func = function(_self)
					if type(values[k])=="table" then
						self.Text:SetText(L[values[k].label]);
					else
						self.Text:SetText(L[values[k]]);
					end
					if(data.set)then
						data.set(k);
					else
						panel:change(data.modName,data.name,k);
					end
					current = k;
					ns.EasyMenu.RefreshAll(menu);
				end
			};
			if type(d)=="table" then
				entry.label=d.label;
				if d.hide==true then
					add=false;
				elseif d.disabled==true then
					entry.disabled = true;
				elseif d.title==true then
					entry.title = true;
				end
			else
				entry.label=L[d];
			end
			if add then
				ns.EasyMenu.addEntry(entry);
			end
		end
		ns.EasyMenu.ShowMenu(self);
		PlaySound("igMainMenuOptionCheckBoxOn");
	end,
	colorOnClick = function(self)
		local data,cur=self.data;
		if (data.modName) then
			cur = ns.profile[data.modName][data.name];
		else
			cur = ns.profile.GeneralOptions[data.name];
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
				self.Color:SetVertexColor(r,g,b,1-a);
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
		OpenColorPicker(self.info);
	end,
	inputOnClickOrEnterPressed = function(self)
		if not self.Ok then
			self = self:GetParent();
		end
		local data=self.data;
		if(data.set)then
			data.set(e:GetText());
		else
			panel:change(data.modName,data.name,self:GetText());
		end
		self:ClearFocus();
		self.Ok:Hide();
	end,
	inputOnTextChanged = function(self,changed)
		if changed then
			self.Ok:Show();
		end
	end,
	inputOnEscapePressed = function(self)
		self:SetText(self.prev);
		self:ClearFocus();
		self.Ok:Hide();
	end,
	modListButtonOnClick = function(self,button)
		local name = self.modName;
		if (button=="LeftButton") then
			if (self.parentPanel:ModOpts_Choose(self.data.name)) then
				self.mods.pointer=self.data.name;
			else
				self.mods.pointer=nil;
			end
		elseif (button=="RightButton") then
			local val = not ns.profile[name].enabled;
			if (self.parentPanel.changes[name]) and (self.parentPanel.changes[name].enabled~=nil) then
				val = not self.parentPanel.changes[name].enabled;
			end
			self.parentPanel:change(name,"enabled",val);
		end
		self.parentPanel:ModList_Update()
	end
};

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
		if data.get then
			if data.name=="minimap" then
				e:SetChecked(not data.get());
			else
				e:SetChecked(data.get());
			end
		else
			if data.modName then
				if data.name=="minimap" then
					e:SetChecked(not ns.profile[data.modName].minimap.hide);
				else
					e:SetChecked(not not ns.profile[data.modName][data.name]);
				end
			else
				e:SetChecked(not not ns.profile.GeneralOptions[data.name]);
			end
		end
		e.data=data;
		e.Text:SetWidth(160);
		e.Text:SetText(data.label);
		e:SetHitRectInsets(0, -e.Text:GetWidth() - 1, 0, 0);
		e:SetScript("OnClick",functions.toggleOnClick);
		parent[Index]:SetHeight(e:GetHeight()+6);
	end,

	slider = function(parent,index,data)
		local Index,cur = init(parent,index,data);
		local e = parent[Index].__slider;

		if data.get then
			cur = data.get();
		else
			if (data.modName) then
				cur = ns.profile[data.modName][data.name];
			else
				cur = ns.profile.GeneralOptions[data.name];
			end
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

		e:SetScript("OnValueChanged",functions.sliderOnValueChanged);
		parent[Index]:SetHeight(e:GetHeight()+30);
	end,

	select = function(parent,index,data)
		local Index = init(parent,index,data);
		local e = parent[Index].__select;

		local current,values,alternative={},"","";
		if (data.get) then
			current, values, alternative = data.get();
		else
			if (data.modName) then
				current = ns.profile[data.modName][data.name];
			else
				current = ns.profile.GeneralOptions[data.name];
			end
			values = data.values;
			alternative = NONE;
		end

		e.data=data;
		e.Label:SetText(data.label);
		e.value=current;

		local numValues = 0;
		for i in pairs(values)do
			numValues=numValues+1;
		end

		if numValues>0 then
			if current and values[current] then
				if type(values[current])=="table" then
					e.Text:SetText(L[values[current].label]);
				else
					e.Text:SetText(L[values[current]]);
				end
			else
				e.Text:SetText(alternative);
			end

			e:SetScript("OnClick",functions.selectOnClick);
			e:Enable();
		else
			e.Text:SetText(alternative);
			e:Disable();
		end

		e:SetHitRectInsets(-3,-e.Label:GetWidth(),-3,-3)
		parent[Index]:SetHeight(e:GetHeight()+14);
	end,

	color = function(parent,index,data)
		local Index,cur = init(parent,index,data);
		local e = parent[Index].__color;
		if (data.modName) then
			cur = ns.profile[data.modName][data.name];
		else
			cur = ns.profile.GeneralOptions[data.name];
		end
		e.data=data;
		e.data.prev={r=cur[1],g=cur[2],b=cur[3],opacity=1-(cur[4] or 1)};
		e.Text:SetText(data.label);
		e.Color:SetVertexColor(unpack(cur or {1,1,1,1}));
		e:SetHitRectInsets(0, -e.Text:GetWidth() - 1, 0, 0)
		e:SetScript("OnClick",functions.colorOnClick);
		parent[Index]:SetHeight(e:GetHeight());
	end,

	input = function(parent,index,data)
		local Index,cur = init(parent,index,data);
		local e = parent[Index].__input;

		if (data.get) then
			cur = data.get();
		elseif (data.modName) then
			cur = ns.profile[data.modName][data.name];
		else
			cur = ns.profile.GeneralOptions[data.name];
		end
		e.data=data;
		e.prev=cur;

		e.Label:SetText(data.label);
		e:SetText(cur);

		e:SetScript("OnEnterPressed",functions.inputOnClickOrEnterPressed);
		e:SetScript("OnTextChanged",functions.inputOnTextChanged);
		e.Ok:SetScript("OnClick",functions.inputOnClickOrEnterPressed);
		e:SetScript("OnEscapePressed",functions.inputOnEscapePressed);

		parent[Index]:SetHeight(e:GetHeight()+e.Label:GetHeight()+6);
	end
};

ns.optionpanel = function()
	local mods = {list={},events={},needs={},pointer=nil,entryHeight=0,entryOffset=0};
	local f = CreateFrame("Frame", "BrokerEverythingOptionPanel", InterfaceOptionsFramePanelContainer, "BrokerEverythingOptionPanelTemplate");
	f.name, f.controls,f.changes = addon, {},{};

	function f:okay()
		local action = "update";
		local needs = false;
		if BrokerEverythingOptionPanel.change_profile then
			local pName,pAct = unpack(BrokerEverythingOptionPanel.change_profile);
			action = "none";
		
			if pAct=="new" then
				Broker_Everything_ProfileDB.profiles[pName] = {};
				for i,v in pairs(ns.defaultGeneralOptions)do
					Broker_Everything_ProfileDB.profiles[pName][i] = v;
				end
				for i,v in pairs(ns.modules)do
					if(v.config_defaults)then
						for I,V in pairs(v.config_defaults)do
							if Broker_Everything_ProfileDB.profiles[pName][i]==nil then
								Broker_Everything_ProfileDB.profiles[pName][i] = {};
							end
							Broker_Everything_ProfileDB.profiles[pName][i][I]=V;
						end
					end
				end
			elseif pAct=="copy" then
				local dbNew = Broker_Everything_ProfileDB.profiles[pName];
				for i,v in pairs(ns.defaultGeneralOptions)do
					ns.be_option_panel:change(nil,i,dbNew[i]);
				end
				for i,v in pairs(ns.modules)do
					if(v.config_defaults)then
						for I,V in pairs(v.config_defaults)do
							ns.be_option_panel:change(i,I,dbNew[i][I]);
						end
					end
				end
			end

			ns.db = nil;
			ns.db = Broker_Everything_ProfileDB.profiles[pName];
			Broker_Everything_ProfileDB.use_profile[ns.player.name_realm] = pName;
			BrokerEverythingOptionPanel.change_profile = nil;
		end
		for name1,value1 in pairs(f.changes) do
			if (type(value1)=="table") and (name1~="iconcolor") then
				for name2,value2 in pairs(value1) do
					if action=="defaults" then
						if ns.allModDefaults[name2] then
							ns.profile[name1][name2] = ns.allModDefaults[name2]; -- table defined in modules/modules.lua
						else
							ns.profile[name1][name2] = ns.modules[name1].defaults[name2];
						end
					elseif action~="none" and name2~="minimap" then
						ns.profile[name1][name2] = value2;
					end
					if (mods.events[name1]) and (mods.events[name1][name2]) then
						ns.modules[name1].onevent(ns.modules[name1].eventFrame, type(mods.events[name1][name2])=="string" and mods.events[name1][name2] or "BE_DUMMY_EVENT");
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
					if name2=="minimap" then
						if value2 then
							ns.LDBI:Show(ns.modules[name1].ldbName);
						else
							ns.LDBI:Hide(ns.modules[name1].ldbName);
						end
						ns.profile[name1].minimap.hide=not value2;
					end
				end
			else
				if action=="defaults" then
					ns.profile.GeneralOptions[name1] = ns.defaultGeneralOptions[name1];
				elseif action~="none" then
					ns.profile.GeneralOptions[name1] = value1;
				end
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
		wipe(Broker_Everything_ProfileDB);
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
					if v.data.name=="minimap" then
						cur = not ns.profile[v.data.modName][v.data.name].hide;
					else
						cur = ns.profile[v.data.modName][v.data.name];
					end
				end
			else
				if (f.changes[v.data.name]~=nil) then
					cur = f.changes[v.data.name];
				else
					cur = ns.profile.GeneralOptions[v.data.name];
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
			if key=="minimap" then
				if (hasChanged(not ns.profile[name].minimap.hide,value)) then
					f.changes[name][key] = value;
					changed=true;
				end
			elseif (hasChanged(ns.profile[name][key],value)) then
				f.changes[name][key] = value;
				changed=true;
			end
		else
			if (hasChanged(ns.profile.GeneralOptions[key],value)) then
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
			local frame, i = CreateFrame("Frame", ("%s_%s"):format(addon,name:gsub("_",""):gsub("/",""):gsub(" ",""):trim()), f.Modules.Container.child), 1;
			frame:SetPoint("TOPLEFT"); frame:SetSize(f.Modules.Container.child:GetWidth(),1); frame:Hide();
			local icon = ns.I[name];

			for n=1, #mod.config do
				if type(mod.config[n].disabled)=="function" then
					local h,m = mod.config[n].disabled();
					if h then
						mod.config[n].disabledMessage = {h,m};
					end
					mod.config[n].disabled=false;
				end
				if build[mod.config[n].type] and not mod.config.disabled then
					if mod.config[n].set and mod.config[n].get then
						mod.config[n].modName = false;
					else
						mod.config[n].modName = name;
					end
					build[mod.config[n].type](frame,i,mod.config[n]);
					i=i+1;
					if mod.config[n].events then
						if not mods.events[name] then
							mods.events[name] = {};
						end
						mods.events[name][mod.config[n].name] = mod.config[n].event;
					end
					if mod.config[n].needs then
						if not mods.needs[name] then
							mods.needs[name] = {};
						end
						mods.needs[name][mod.config[n].name] = mod.config[n].needs;
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
					button.pointer:Hide();
					button.TextureN:Hide();
					button:Disable();
				elseif (ns.modules[name]) then
					local d,e = ns.modules[name],ns.profile[name].enabled;
					if (f.changes[name]) and (f.changes[name].enabled~=nil) then
						e = f.changes[name].enabled;
					end
					button.data = {name=name,db=ns.profile[name]};
					button.name:SetText(ns.modules[name].label or L[name]);

					if (d.noBroker) then -- no broker, can't be disabled
						button.TextureN:SetVertexColor( .8, .8, .8, .5);
						button.TextureP:SetVertexColor( .8, .8, .8, .5);
					elseif (e) then
						-- on
						button.TextureN:SetVertexColor( .3, 1, .3, .5);
						button.TextureP:SetVertexColor( .3, 1, .3, .5);
					else
						-- off
						button.TextureN:SetVertexColor( 1, .4, .4, .5);
						button.TextureP:SetVertexColor( 1, .4, .4, .5);
					end

					if (mods.pointer==name) then
						button.pointer:Show();
					else
						button.pointer:Hide();
					end

					button.modName = name;
					button.mods = mods;
					button.parentPanel = f;

					button:RegisterForClicks("AnyUp");
					button:SetScript("OnClick",functions.modListButtonOnClick);

					button.tooltip_anchor="LEFT";
					button.tooltip = {
						L[name],
						d.tooltip or d.desc,
						C("copper",L["Left-click"]).." || "..C("green",L["Show options"]),
					}
					if (not d.noBroker) then
						tinsert(button.tooltip,C("copper",L["Right-click"]).." || "..C("green",(e) and L["Disable this module"] or L["Enable this module"]));
						button.tooltip[1] = button.tooltip[1].. " ("..C((e) and "green" or "red",(e) and VIDEO_OPTIONS_ENABLED or ADDON_DISABLED)..")";
					end
					button:SetScript("OnEnter",tooltipOnEnter);
					button:SetScript("OnLeave",tooltipOnLeave);
					button.TextureN:Show();
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
		f.title:SetText(addon.." - "..OPTIONS);
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
		for _,v in ipairs(ns.coreOptions) do -- see core.lua
			if (build[v.type]) then
				build[v.type](f.Generals.child, i, v, nil);
				i=i+1;
			end
		end
		--f.Generals.child:SetHeight(c)

		-- module options
		f.Modules.Title1:SetText(L["Modules"]);
		f.Modules.Title2:SetText(L["Module options"]);
		f.Modules.Title2:SetPoint("LEFT", f.Modules.List.split, "LEFT", 10,0);

		local tmp,d={};
		for k, v in pairs(ns.modules) do -- to order modules by localized names
			if not v.noOptions then
				tmp[v.label or L[k]] = k;
			end
		end

		for k, v in ns.pairsByKeys(tmp) do
			if(ns.modules[v].clickOptions)then
				ns.clickOptions.update(ns.modules[v],ns.profile[v]);
			end
			tinsert(mods.list,v);
		end
		tmp=nil;

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
		Broker_Everything_CharacterDB = CopyTable(f.tmpCharCache);
		ns.toon = Broker_Everything_CharacterDB[ns.player.name_realm];
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
		Broker_Everything_CharacterDB = {order={ns.player.name_realm}};
		ns.toon = Broker_Everything_CharacterDB[ns.player.name_realm];
		for i,v in ipairs({"name","class","faction","race"})do
			if(ns.player[v] and ns.toon[v]~=ns.player[v])then
				ns.toon[v] = ns.player[v];
			end
		end
		ns.toon.level = UnitLevel("player");
	end
	
	local function CharList_Change(self)
		local parent=self:GetParent();
		local name = parent.name_realm;
		if self==parent.OrderUp then
			tremove(f.tmpCharCache.order,f.tmpCharCache[name].orderId);
			tinsert(f.tmpCharCache.order,f.tmpCharCache[name].orderId-1,name);
		elseif self==parent.OrderDown then
			tremove(f.tmpCharCache.order,f.tmpCharCache[name].orderId);
			tinsert(f.tmpCharCache.order,f.tmpCharCache[name].orderId+1,name);
		elseif self==parent.Delete then
			tremove(f.tmpCharCache.order,f.tmpCharCache[name].orderId);
		end
		CharList_Update();
	end

	function CharList_Update()
		local scroll = f.CharList;
		local button, index, offset, nButtons, nEntries;

		if (not scroll.buttons) then
			f.CharList.update=CharList_Update;
			HybridScrollFrame_CreateButtons(f.CharList, "BECharacterListButtonTemplate", 0, 0, nil, nil, 0, -2);
		end

		if(f.tmpCharCache==false)then
			f.tmpCharCache = CopyTable(Broker_Everything_CharacterDB);
		end

		offset = HybridScrollFrame_GetOffset(scroll);
		nButtons = #scroll.buttons;
		nEntries = #f.tmpCharCache.order;

		for i=1, nButtons do
			button = scroll.buttons[i];
			index = offset+i;

			if (f.tmpCharCache.order[index]) then
				local name_realm = f.tmpCharCache.order[index];
				local name, realm, _ = strsplit("-",name_realm);
				if realm then
					_, realm = ns.LRI:GetRealmInfo(realm);
				end
				local data = f.tmpCharCache[name_realm];
				button.name_realm = name_realm;

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
				if(data.orderId==1)then
					button.OrderUp:Disable();
				elseif(data.orderId==nEntries)then
					button.OrderDown:Disable();
				end

				button.OrderUp:SetScript("OnClick",CharList_Change);
				button.OrderDown:SetScript("OnClick",CharList_Change);
				button.Delete:SetScript("OnClick",CharList_Change);

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

