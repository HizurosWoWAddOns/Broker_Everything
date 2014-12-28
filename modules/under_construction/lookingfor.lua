
----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I

-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "LookingFor" -- L["LookingFor"]
local ldbName = name
local tt
local queues = {}
local paused = {lfr=false,pvp=false,pet=false}
local iconAnimation = false
local animationData = {}
local events = {
	PLAYER_ENTERING_WORLD=0,
	GROUP_ROSTER_UPDATE=0,

	-- pve
	LFG_UPDATE=1,
	LFG_ROLE_CHECK_UPDATE=1,
	LFG_QUEUE_STATUS_UPDATE=1,
	LFG_PROPOSAL_UPDATE=1,
	LFG_PROPOSAL_FAILED=1,
	LFG_PROPOSAL_SUCCEEDED=1,
	LFG_PROPOSAL_SHOW=1,
	-- missing lfg abbonded by user?

	-- pvp
	PVP_ROLE_CHECK_UPDATED=2,
	UPDATE_BATTLEFIELD_STATUS=2,
	UPDATE_WORLD_STATES=2,
	ZONE_CHANGED_NEW_AREA=2,
	ZONE_CHANGED=2,
	BATTLEFIELD_MGR_QUEUE_REQUEST_RESPONSE=2,
	BATTLEFIELD_MGR_EJECT_PENDING=2,
	BATTLEFIELD_MGR_EJECTED=2,
	BATTLEFIELD_MGR_QUEUE_INVITE=2,
	BATTLEFIELD_MGR_ENTRY_INVITE=2,
	BATTLEFIELD_MGR_ENTERED=2,

	-- pb (pet battle)
	PET_BATTLE_QUEUE_STATUS=3,

	-- all the events are really necessary?
}


-- ------------------------------------- --
-- register icon names and default files --
-- ------------------------------------- --
I[name..'_off']     = {iconfile="Interface\\Addons\\"..addon.."\\media\\LFG-Eye-Green", coords={0.5 , 0.625 , 0 , 0.25}}
I[name..'_default'] = {iconfile="Interface\\Addons\\"..addon.."\\media\\LFG-Eye-Green", coords=nil, width=256, height=128, frames=29, iconSize=32, delay=0.12}
I[name..'_raid']    = {iconfile="Interface\\LFGFrame\\LFR-Anim",                        coords=nil, width=256, height=256, frames=16, iconSize=64, delay=0.12}
I[name..'_unknown'] = {iconfile="Interface\\LFGFrame\\WaitAnim",                        coords=nil, width=128, height=128, frames=4,  iconSize=64, delay=0.25}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["Display informations about the usage of group, raid and battlefield finder and more..."],
	icon_suffix = '_off',
	events = {},
	updateinterval = false, -- 10
	config_defaults = {},
	config_allowed = {},
	config = {
		height = 53,
		elements = {
			{
				type = "dropdown",
				label = L["In broker"],
				desc = L["Choose..."],
				default = "1",
				values = {
					["1"] = "T H D",
					["2"] = "0/n 0/n 0/n",
					["3"] = "av. wait time"
				}
			}
		}
	}
}
for i,v in pairs(events) do tinsert(ns.modules[name].events,i) end


--------------------------
-- some local functions --
--------------------------
local function getTooltip()
	local line, column
	local none = true
	tt:Clear()
	tt:AddHeader(C("dkyellow",L[name]))
	for k,v in pairs(queues) do
		local c=0 for x,y in pairs(v) do if type(y)=="table" or y==true then c=c+1 end end
		if c~=0 then
			if LFG_CATEGORY_NAMES[k]~=nil then
				tt:AddSeparator(4,0,0,0,0)
				tt:AddLine(C("ltyellow",LFG_CATEGORY_NAMES[k]))
				tt:AddSeparator(1,1,1,0)
				for K,V in ns.pairsByKeys(v) do
					if type(V)~="boolean" then
						none = false
						if paused.lfr then
							tt:AddLine(C("ltblue",V.queueName),L["paused"])
							tt:AddLine(C("lwhite",V.txt))
							tt:AddSeparator(1,.7,.7,.7)
						else
							tt:AddLine(C("ltblue",V.queueName),V.nNum)
							tt:AddLine(V.queuedTime,V.wait or "?")
							tt:AddSeparator(1,.7,.7,.7)
						end
					end
				end
			elseif k>100 and k<200 then
				-- pvp
				none=false
				
			elseif k==200 then
				-- pet battle
				none = false
				local d = queues[200][1]
				tt:AddSeparator(4,0,0,0,0)
				tt:AddLine(C("ltyellow",d.catName))
				tt:AddSeparator(1,1,1,0)
				tt:AddLine(d.queuedTime,d.wait)
				tt:AddLine(d.txt,d.ext)
			end
		end
	end
	if none==true then
		tt:AddLine(L["You are not in a queue."])
	end

	if Broker_EverythingDB.showHints then
		tt:AddSeparator(4,0,0,0,0)
		line,column = tt:AddLine()
		tt:SetCell(line,1,C("copper",L["Left-click"]).." || "..C("green",L["Open Dungeonbrowser"]) .. "|n" .. C("copper",L["Right-click"]).." || "..C("green",L["Open Raidfinder"]),2)
	end
end

local function updateQueueData(catId, catName, queueID, queueName, statusText, extra, queuedTime, myWait, tank, healer, dps, totalTanks, totalHealers, totalDPS, tankNeeds, healerNeeds, dpsNeeds)
	if queuedTime~=nil then
		myWait = myWait~=nil and SecondsToTime(myWait) or L["Unknown"]
		queuedTime = SecondsToTime(GetTime()-queuedTime)
	end
	if catId < 100 then
		local c = function(need,total,colorA,colorB) total = total or "?" return C(need~=0 and colorA or colorB,type(total)=="string" and total or ("%d/%d"):format(total-need,total)) end
		local needsStr,needsNum,tanks,healers,dps = "","",0,0,0
		if tankNeeds~=nil then
			needsStr = ("%s %s %s"):format(c(tankNeeds,"T","ltgray","ltblue"),c(healerNeeds,"H","ltgray","green"),c(dpsNeeds,"D","ltgray","red"))
			needsNum = ("%s %s %s"):format(c(tankNeeds,totalTanks,"ltgray","ltblue"),c(healerNeeds,totalHealers,"ltgray","green"),c(dpsNeeds,totalDPS,"ltgray","red"))
		end
		if queues[catId]==nil then queues[catId]={} end
		queues[catId][queueID] = {
			catId   = catId,
			queueId = queueID,
			catName = catName,
			queueName = queueName,
			txt  = statusText,
			ext  = extra,
			wait = (myWait~=nil and myWait~="" and "~"..myWait) or false,
			queuedTime=queuedTime,
			nStr = needsStr,
			nNum = needsNum,
			nSum = (type(tankNeeds)=="number" and tankNeeds or 0)+(type(healerNeeds)=="number" and healerNeeds or 0)+(type(dpsNeeds)=="number" and dpsNeeds or 0)
		}
	elseif catId < 200 then
		if queues[catId]==nil then queues[catId]={} end
		
	elseif catId==200 then
		if queues[catId]==nil then queues[catId]={} end
		queues[catId][queueID] = {
			catId   = catId,
			queueId = queueID,
			catName = catName,
			queueName = queueName,
			txt  = statusText,
			ext  = extra,
			wait = (myWait~=nil and myWait~="" and "~"..myWait) or false,
			queuedTime=queuedTime
		}
		ns.print_r("?",queues[catId][queueID])
	end
end


local function update(active)
	local obj = ns.LDB:GetDataObjectByName(ldbName)

	if active and iconAnimation==false then
		--[[
		local suffix = 
		local icon = I(name..suffix)
		obj.icon = icon.iconfile
		obj.iconCoords = {0, (icon.iconSize / icon.width), 0, (icon.iconSize / icon.height)}
		]]
		iconAnimation = true
		animationData.suffix="_unknown"
	end

	if active then
		local txt = {}
		for i,v in pairs(queues)do
			local x = {}
			for I,V in pairs(v) do
				if type(V)=="table" then
					if x[1]==nil or (x[1]~=nil and x[1] > V.nSum) then
						x = {V.nSum,V.nNum}
					end
				end
			end
			if x[2]~=nil then
				tinsert(txt,x[2])
			end
		end
		obj.text = table.concat(txt," || ")
	else
		iconAnimation = false
		animationData = {}
		local icon = I(name..'_off')
		obj.text = L[name]
		obj.icon = icon.iconfile
		obj.iconCoords = icon.coords
	end

	if tt~=nil and tt.key~=nil and tt.key==name.."TT" and tt:IsShown() then
		getTooltip()
	end
end

local function calcIconCoords(f,w,h,s)
	local nC,nR,cW,rH = floor(w/s),floor(h/s),s/w,s/h
	local left, bottom = mod(f-1,nC)*cW, ceil(f/nC) * rH
	local right, top   = left + cW, bottom - rH
	return {left,right,top,bottom}
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
ns.modules[name].init = function(obj)
	ldbName = (Broker_EverythingDB.usePrefix and "BE.." or "")..name
--	if Broker_EverythingDB[name].showNumbers == nil then
--		Broker_EverythingDB[name].showNumbers = true
--	end
end

ns.modules[name].onevent = function(self,event,...)
	local searchActive,_ = false

	if events[event]==1 then
		-- LFG Queues
		paused.lfr = false

		for i=1, NUM_LE_LFG_CATEGORYS do
			local ql = GetLFGQueuedList(i) or {}
			if queues[i]==nil then queues[i]={} end
			for k,v in pairs(queues[i]) do
				if ql[k]==nil then queues[i][k] = false end
			end
			for k,v in pairs(ql) do
				if queues[i][k]==nil then queues[i][k] = true end
			end
		end

		if event=="LFG_ROLE_CHECK_UPDATE" or event=="LFG_PROPOSAL_UPDATE" or event=="LFG_PROPOSAL_FAILED" or event=="LFG_PROPOSAL_SUCCEEDED" or event=="LFG_PROPOSAL_SHOW" then
			paused.lfr = true
		else
			for i=1, NUM_LE_LFG_CATEGORYS do
				if queues[i]==nil then queues[i] = {} end
				local activeID = select(18, GetLFGQueueStats(i))
				if activeID~=nil then
					instance_server=true
					local queueName, extra, mode, submode = select(LFG_RETURN_VALUES.name, GetLFGDungeonInfo(activeID)), nil, GetLFGMode(i, activeID)
					if mode then
						if mode=="queued" then
							local inParty, joined, queued, noPartialClear, achievements, lfgComment, slotCount, _, leader, tank, healer, dps = GetLFGInfoServer(i, activeID);
							local hasData,  leaderNeeds, tankNeeds, healerNeeds, dpsNeeds, totalTanks, totalHealers, totalDPS, instanceType, instanceSubType, instanceName, averageWait, tankWait, healerWait, damageWait, myWait, queuedTime, x = GetLFGQueueStats(i, activeID);
							if i==LE_LFG_CATEGORY_SCENARIO then --Hide roles for scenarios
								tank, healer, dps = nil, nil, nil;
								totalTanks, totalHealers, totalDPS, tankNeeds, healerNeeds, dpsNeeds = nil, nil, nil, nil, nil, nil;
							end
							updateQueueData(i, LFG_CATEGORY_NAMES[i], activeID, queueName, nil, extra, queuedTime, myWait, tank, healer, dps, totalTanks, totalHealers, totalDPS, tankNeeds, healerNeeds, dpsNeeds)
							if queuedTime~=nil and animationData.suffix~="_default" then
								animationData.suffix="_default"
								animationData.frame = nil
							end
						elseif mode=="proposal" then
							updateQueueData(i, LFG_CATEGORY_NAMES[i], activeID, queueName, QUEUED_STATUS_PROPOSAL, extra)
							paused.lfr = true
						elseif mode=="listed" then
							updateQueueData(i, LFG_CATEGORY_NAMES[i], activeID, queueName, QUEUED_STATUS_LISTED, extra)
							paused.lfr = true
						elseif mode=="suspended" then
							updateQueueData(i, LFG_CATEGORY_NAMES[i], activeID, queueName, QUEUED_STATUS_SUSPENDED, extra)
							paused.lfr = true
						elseif mode=="rolecheck" then
							updateQueueData(i, LFG_CATEGORY_NAMES[i], activeID, queueName, QUEUED_STATUS_ROLE_CHECK_IN_PROGRESS, extra)
							paused.lfr = true
						elseif mode=="lfgparty" or mode == "abandonedInDungeon" then
							updateQueueData(i, LFG_CATEGORY_NAMES[i], activeID, queueName, QUEUED_STATUS_IN_PROGRESS, extra)
							paused.lfr = true
						else
							updateQueueData(i, LFG_CATEGORY_NAMES[i], activeID, queueName, QUEUED_STATUS_UNKNOWN, extra)
						end
						searchActive = true
					end
				end
			end
		end

	elseif events[event]==2 then
		-- PvP Queues

		--[[
		local inProgress, _, _, _, _, isBattleground = GetLFGRoleUpdate()
		--Try PvP Role Check
		if ( inProgress and isBattleground ) then
			local entry = QueueStatusFrame_GetEntry(self, nextEntry)
			QueueStatusEntry_SetUpPVPRoleCheck(entry)
		end
		]]

		for i=1, GetMaxBattlefieldID() do
			local entry = i + 100
			local status, mapName, teamSize, registeredMatch, suspend = GetBattlefieldStatus(i)
			if status~=nil then
				if status=="queued" then
					if suspend then
						updateQueueData(entry, mapName, i, mapName, QUEUED_STATUS_SUSPENDED);
					else
						local queuedTime = GetTime() - GetBattlefieldTimeWaited(i) / 1000;
						local estimatedTime = GetBattlefieldEstimatedWaitTime(i) / 1000;
						updateQueueData(entry, mapName, i, mapName, nil, nil, queuedTime, estimatedTime)
					end
				elseif ( status == "confirm" ) then
					updateQueueData(entry, mapName, i, mapName, QUEUED_STATUS_PROPOSAL)
				elseif ( status == "active" ) then
					updateQueueData(entry, mapName, i, mapName, QUEUED_STATUS_IN_PROGRESS)
				elseif ( status == "locked" ) then
					updateQueueData(entry, mapName, i, mapName, QUEUED_STATUS_LOCKED, QUEUED_STATUS_LOCKED_EXPLANATION)
				else
					updateQueueData(entry, mapName, i, mapName, QUEUED_STATUS_UNKNOWN)
				end
				searchActive = true
			end
		end

		--[[
		--Try all World PvP queues
		for i=1, MAX_WORLD_PVP_QUEUES do
			local status, mapName, queueID = GetWorldPVPQueueStatus(i)
			if ( status and status ~= "none" ) then
				local entry = QueueStatusFrame_GetEntry(self, nextEntry)
				QueueStatusEntry_SetUpWorldPvP(entry, i)

				if ( status == "queued" ) then searchActive = true end
			end
		end

		--World PvP areas we're currently in
		if ( CanHearthAndResurrectFromArea() ) then
			
			local entry = QueueStatusFrame_GetEntry(self, nextEntry)
			QueueStatusEntry_SetUpActiveWorldPVP(entry)
			
		end
		]]

	elseif events[event]==3 then
		--Pet Battle PvP Queue

		local pbStatus, estimatedTime, queuedTime = C_PetBattles.GetPVPMatchmakingInfo()
		if pbStatus then
			if ( pbStatus == "queued" ) then
				updateQueueData(200, PET_BATTLE_PVP_QUEUE, 1, PET_BATTLE_PVP_QUEUE, nil, nil, queuedTime, estimatedTime)
			elseif ( pbStatus == "proposal" ) then
				updateQueueData(200, PET_BATTLE_PVP_QUEUE, 1, PET_BATTLE_PVP_QUEUE, QUEUED_STATUS_PROPOSAL)
			elseif ( pbStatus == "suspended" ) then
				updateQueueData(200, PET_BATTLE_PVP_QUEUE, 1, PET_BATTLE_PVP_QUEUE, QUEUED_STATUS_SUSPENDED)
			elseif ( pbStatus == "entry" ) then
				updateQueueData(200, PET_BATTLE_PVP_QUEUE, 1, PET_BATTLE_PVP_QUEUE, QUEUED_STATUS_WAITING)
			else
				updateQueueData(200, PET_BATTLE_PVP_QUEUE, 1, PET_BATTLE_PVP_QUEUE, QUEUED_STATUS_UNKNOWN)
			end
			searchActive = true
		end
	end

	update(searchActive)
end

ns.modules[name].onupdate = function(self,elapsed)
	if iconAnimation and elapsed~=nil then
		local obj = ns.LDB:GetDataObjectByName(ldbName)
		local icon = I(name..animationData.suffix)

		if ( not animationData.frame ) then
			-- initialize everything
			animationData.frame = 1;
			animationData.throttle    = 0;
		end

		if ( not animationData.throttle or animationData.throttle > icon.delay ) then
			local frame = animationData.frame + 1;
			if frame > icon.frames then frame = 1 end

			animationData.throttle = 0;

			obj.icon = icon.iconfile
			obj.iconCoords = calcIconCoords(frame,icon.width,icon.height,icon.iconSize)

			animationData.frame = frame;
		else
			animationData.throttle = animationData.throttle + elapsed;
		end
	end
end


--[[ ns.modules[name].optionspanel = function(panel) end ]]

--[[ ns.modules[name].onmousewheel = function(self,direction) end ]]

--[[ ns.modules[name].ontooltip = function(tooltip) end ]]


-------------------------------------------
-- module functions for LDB registration --
-------------------------------------------
ns.modules[name].onenter = function(self)
	tt = ns.LQT:Acquire(name.."TT", 2, "LEFT", "RIGHT")
	getTooltip(self,tt)
	ns.createTooltip(self,tt)
end

ns.modules[name].onleave = function(self)
	if tt then 
		ns.hideTooltip(tt,name)
	end
end

ns.modules[name].onclick = function(self,button)
	if button=="LeftButton" then
		-- open dungeonbrowser
		securecall("PVEFrame_ToggleFrame")
	elseif button=="RightButton" then
		securecall("ToggleRaidBrowser")
	end
end

--[[ ns.modules[name].ondblclick = function(self,button) end ]]



--[[

step0:
	a) track dungeon queue
	b) track raid queue
	c) track scenario queue
	d) track battleground queue
	d) track arena queue
	e) track petbattle queue

step1:
	display in broker and tooltip all queues with her own status

step2:
	display leader and role status in current party

step3:
	

]]


--[[

note:
paused.lfr on proposal ok. in active raid not. how i can detect if user in instancegroup

]]