

----------------------------------
-- module independent variables --
----------------------------------
local addon, ns = ...
local C, L, I = ns.LC.color, ns.L, ns.I
if ns.build<70000000 then return end


-----------------------------------------------------------
-- module own local variables and local cached functions --
-----------------------------------------------------------
local name = "Artifact weapon" -- L["Artifact weapon"]
local ttName,ttColumns,tt,createMenu,createTooltip = name.."TT", 3;
local ap_items_found,spec2weapon,knowledgeLevel,obtained,updateBroker, _ = {},{},0,0;
local _ITEM_LEVEL = gsub(ITEM_LEVEL,"%%d","(%%d*)");
ns.artifactpower_items = {
	-- >0 = known amount of artifact power
	-- -1 = special actifact power items
	[127999]=  -1,[128000]=  -1,[128021]=  -1,[128022]=  -1,[128026]=  -1,[130144]=  -1,[130149]=  -1,[130152]=  35,[130153]=  -1,[130159]=  -1,[130160]=  -1,[130165]=  -1,
	[131728]=  -1,[131732]=1000,[131751]=  35,[131753]=  35,[131758]=  -1,[131763]=  35,[131778]=  -1,[131784]=  -1,[131785]=  -1,[131789]=  -1,[131795]=  35,[131802]=  45,
	[131808]=  25,[132361]=  -1,[132897]=  45,[132923]=  -1,[132950]=  35,[134118]=  -1,[134133]=  -1,[136356]=  -1,[136360]= 300,[138480]=   5,[138487]=   5,[138726]=  -1,
	[138732]=  10,[138781]=  75,[138782]= 100,[138783]=  20,[138784]= 100,[138785]= 400,[138786]= 200,[138812]=  35,[138813]= 100,[138814]=  35,[138816]= 100,[138839]=  20,
	[138864]=   5,[138865]=  50,[138880]=  50,[138881]= 150,[138885]=  35,[138886]= 150,[139390]=  -1,[139413]= 200,[139506]=1000,[139507]= 170,[139508]= 160,[139509]= 245,
	[139510]= 480,[139511]= 250,[139512]= 490,[139591]= 200,[139608]= 150,[139609]= 235,[139610]= 465,[139611]= 165,[139612]= 210,[139613]= 450,[139614]= 175,[139615]= 230,
	[139616]= 475,[139617]= 350,[139652]=  -1,[139653]=  -1,[139654]=  -1,[139655]=  -1,[139656]=  -1,[139657]=  -1,[139658]=  -1,[139659]=  -1,[139660]=  -1,[139661]=  -1,
	[139662]=  -1,[139663]=  -1,[139664]=  -1,[139665]=  -1,[139666]=  -1,[139667]=  -1,[139668]=  -1,[139669]=  -1,[140176]= 400,[140237]= 350,[140238]= 300,[140241]= 300,
	[140244]= 350,[140247]= 350,[140250]= 350,[140251]= 350,[140252]= 300,[140254]= 350,[140255]= 100,[140304]= 250,[140305]= 500,[140306]=1000,[140307]=4000,[140310]=  10,
	[140322]= 100,[140349]= 100,[140357]=  15,[140358]=  15,[140359]=  15,[140361]=  15,[140364]=   5,[140365]=   5,[140366]=   5,[140367]=   5,[140368]=   5,[140369]=  15,
	[140370]=  15,[140371]=  15,[140372]=  40,[140373]=  15,[140374]=  15,[140377]=   5,[140379]=   5,[140380]=   5,[140381]=  40,[140382]=   5,[140383]=   5,[140384]=  80,
	[140385]=   5,[140386]=  40,[140387]=  15,[140388]=  40,[140389]=  15,[140391]=  15,[140392]=  15,[140393]=  15,[140396]=  40,[140409]= 900,[140410]=1000,[140421]=1200,
	[140422]= 750,[140444]=1250,[140445]= 875,[140459]=   5,[140460]=   5,[140461]=   5,[140462]=   5,[140463]=   5,[140466]=   5,[140467]=   5,[140468]=   5,[140469]=   5,
	[140470]=   5,[140471]=  15,[140473]=   5,[140474]=   5,[140475]=   5,[140476]=   5,[140477]=   5,[140478]=  15,[140479]=  15,[140480]=  15,[140481]=  15,[140482]=  15,
	[140484]=   5,[140485]=   5,[140486]=   5,[140487]=   5,[140488]=   5,[140489]=  15,[140490]=  15,[140491]=  15,[140492]=  15,[140494]=  15,[140497]=   5,[140498]=  15,
	[140503]=   5,[140504]=   5,[140505]=   5,[140507]=   5,[140508]=   5,[140509]=  15,[140510]=  15,[140511]=  15,[140512]=  15,[140513]=  15,[140515]=   5,[140516]=   5,
	[140517]= 300,[140518]=   5,[140519]=   5,[140520]=   5,[140521]=  15,[140522]=  15,[140523]=  15,[140524]=  15,[140525]=  15,[140528]=  15,[140529]=  15,[140530]=  15,
	[140531]=  15,[140532]=  15,[140685]=  25,[140847]= 300,[141023]=  20,[141024]= 500,[141310]= 100,[141313]= 500,[141314]= 500,[141335]=  -1,[141337]= 300,[141383]= 100,
	[141384]= 100,[141385]= 100,[141386]= 100,[141387]= 100,[141388]= 100,[141389]= 100,[141390]= 100,[141391]= 100,[141392]= 100,[141393]= 100,[141394]= 100,[141395]= 100,
	[141396]= 100,[141397]= 100,[141398]= 100,[141399]= 100,[141400]= 100,[141401]= 100,[141402]= 100,[141403]= 100,[141404]= 100,[141405]= 100,[141638]= 200,[141639]= 300,
	[141667]= 800,[141668]= 300,[141669]= 300,[141670]= 300,[141671]= 300,[141672]= 300,[141673]= 350,[141674]= 300,[141675]= 300,[141676]=1000,[141677]= 800,[141678]= 650,
	[141679]= 800,[141680]= 450,[141681]=1000,[141682]= 500,[141683]= 500,[141684]= 875,[141685]=2500,[141689]=  55,[141690]=  35,[141699]= 100,[141701]= 100,[141702]= 200,
	[141703]= 190,[141704]= 210,[141705]= 205,[141706]= 210,[141707]= 520,[141708]= 545,[141709]= 550,[141710]= 530,[141711]= 515,[141852]= 500,[141853]= 600,[141854]= 250,
	[141855]= 125,[141856]= 400,[141857]=  50,[141858]=   5,[141859]= 250,[141863]=  20,[141872]= 150,[141876]=  25,[141877]=  40,[141883]=  50,[141886]=  50,[141887]=  50,
	[141888]=  50,[141889]= 150,[141890]=  50,[141891]=  45,[141892]=  35,[141896]=  45,[141921]= 170,[141922]= 220,[141923]= 195,[141924]= 185,[141925]= 190,[141926]= 215,
	[141927]= 180,[141928]= 185,[141929]= 220,[141930]= 175,[141931]= 215,[141932]= 750,[141933]= 300,[141934]= 100,[141935]= 300,[141936]= 350,[141937]= 350,[141940]= 300,
	[141941]= 350,[141942]= 350,[141943]= 300,[141944]= 300,[141945]= 300,[141946]= 300,[141947]= 300,[141948]= 300,[141949]= 300,[141950]= 800,[141951]= 600,[141952]= 600,
	[141953]=1000,[141954]= 650,[141955]= 450,[141956]= 200,[142001]= 400,[142002]= 400,[142003]= 400,[142004]= 400,[142005]= 400,[142006]= 400,[142007]= 400,[142054]= 100,
	[142449]=  50,[142450]=  50,[142451]=  50,[142453]=1000,[142454]= 500,[142455]=1000,[142533]= 600,[142534]= 600,[142535]= 200,[142555]= 300,[143333]= 500,[143486]= 250,
	[143487]= 800,[143488]= 100,[143498]= 500,[143499]= 250,[143533]= 500,[143536]= 250,[143538]= 250,[143540]= 500,[143677]=  60,[143680]= 400,[143713]= 100,[143714]= 120,
	[143715]= 180,[143716]= 800,[143738]= 500,[143739]= 500,[143740]= 250,[143741]= 250,[143742]= 250,[143743]= 250,[143744]= 250,[143745]= 500,[143746]= 500,[143747]= 800,
	[143749]=1000,[143757]=3000,[143844]= 250,[143868]= 250,[143869]= 400,[143870]= 500,[143871]= 600
};
ns.artifactrelikts = {};
local PATTERN_ARTIFACT_XP_GAIN = gsub(ARTIFACT_XP_GAIN,"%s",".*");
local artifactKnowledgeMultiplier_len, artifactLocked = 25;
local artifactKnowledgeMultiplier = {
	-- with 7.0
	  0.25,  0.50,  0.90,  1.40,  2.00, --  1 -  5
	  2.75,  3.75,  5.00,  6.50,  8.50, --  6 - 10
	 11.00, 14.00, 17.75, 22.50, 28.50, -- 11 - 15
	 36.00, 45.50, 57.00, 72.00, 90.00, -- 16 - 20
	113.00,142.00,178.00,223.00,249.00, -- 21 - 25

	-- with 7.2
	 500.00, 750.00,1000.00,1250.00,1500.00, -- 26 - 30
	1750.00,2000.00,2250.00,2500.00,2750.00, -- 31 - 35
	3000.00,3250.00,3500.00,3750.00,4000.00  -- 36 - 40
}
if ns.build>=72000000 then
	artifactKnowledgeMultiplier_len = 30;
end

local AP_MATCH_STRINGS = {
	deDE = "Gewährt Eurem derzeit ausgerüsteten Artefakt (%d*) Artefaktmacht",
	enUS = "Grants (%d*) Artifact Power to your currently equipped Artifact",
	esES = "Otorga (%d*) p. de poder de artefacto al artefacto que lleves equipado",
	esMX = "Otorga (%d*) p. de Poder de artefacto para el artefacto que llevas equipado",
	frFR = "Confère (%d*) point* de puissance à l’arme prodigieuse que vous brandissez",
	itIT = {"Fornisce (%d*) Potere Artefatto all'Artefatto attualmente equipaggiato.","(%d*) Potere Artefatto fornito all'Artefatto attualmente equipaggiato"},
	koKR = {"현재 장착한 유물에 (%d*)의 유물력을 부여합니다.","현재 장착한 유물에 (%d*)의 유물력 부여"},
	ptBR = "Concede (%d*) de Poder do Artefato ao artefato equipado",
	ptPT = "Concede (%d*) de Poder do Artefato ao artefato equipado",
	ruRU = {"Добавляет используемому в данный момент артефакту (%d*) ед. силы артефакта.","Добавление используемому в данный момент артефакту (%d*) ед. силы артефакта"},
	zhCN = "将(%d*)点神器能量注入到你当前装备的神器之中",
	zhTW = "賦予你目前裝備的神兵武器(%d*)點神兵之力",
}

local FISHING_AP_MATCH_STRINGS = {
	deDE = "Wirft den Fisch zurück ins Wasser und gewährt Eurem Angelartefakt (%d*) Artefaktmacht",
	enUS = "Toss the fish back into the water, granting (%d*) Artifact Power to your fishing artifact",
	esES = "Lanza el pez de nuevo al agua, lo que otorga (%d*) p. de poder de artefacto a tu artefacto de pesca",
	esMX = "Devuelve el pez al agua, lo que otorga (%d*) de poder de artefacto a tu artefacto de pesca",
	frFR = "Vous rejetez le poisson à l’eau, ce qui confère (%d*) $lpoint:points; de puissance prodigieuse à votre ustensile de pêche prodigieux",
	itIT = "Rilancia il pesce in acqua, fornendo (%d*) Potere Artefatto al tuo artefatto da pesca",
	koKR = "물고기를 다시 물에 던져 낚시 유물에 (%d*)의 유물력을 추가합니다.",
	ptBR = "Joga o peixe de volta na água, concedendo (%d*) de Poder do Artefato ao seu artefato de pesca",
	ptPT = "Joga o peixe de volta na água, concedendo (%d*) de Poder do Artefato ao seu artefato de pesca",
	ruRU = "Бросить рыбу обратно в воду, добавив вашему рыболовному артефакту (%d*) ед. силы артефакта",
	zhCN = "将鱼扔回到水中，使你的钓鱼神器获得(%d*)点神器能量",
	zhTW = "將魚丟回水中，為你的釣魚神器取得(%d*)點神兵之力",
}


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=1109508 or ns.icon_fallback,coords={0.05,0.95,0.05,0.95}}


---------------------------------------
-- module variables for registration --
---------------------------------------
ns.modules[name] = {
	desc = L["..."],
	events = {
		"PLAYER_ENTERING_WORLD",
		"ARTIFACT_XP_UPDATE",
		"ARTIFACT_MAX_RANKS_UPDATE",
		"ARTIFACT_UPDATE",
		"UNIT_INVENTORY_CHANGED",
		"CURRENCY_DISPLAY_UPDATE"
	},
	updateinterval = nil, -- 10
	config_defaults = {
		showName = true,
		showPoints = true,
		showXP = "1",
		showPower = true,
		showWarning = true,
		showRelic = true,
		showRelicItemLevel = false,
		showRelicIncreaseItemLevel = true,
		showItems = true,
		showTotalAP = true,
		showKnowledge = true
	},
	config_allowed = nil,
	config_header = nil, -- use default header
	config_broker = {
		"minimapButton",
		{ type="toggle", name="showName", label=L["Show weapon name"], tooltip=L["Show artifact weapon name in broker button"], event="ARTIFACT_UPDATE"},
		{ type="toggle", name="showPoints", label=L["Show points"], tooltip=L["Show spent/available points in broker button"], event="ARTIFACT_UPDATE"},
		{ type="select", name="showXP", label=L["Show artifact power"], tooltip=L["Show artifact weapon expierence (artifact power) in broker button"], event="ARTIFACT_UPDATE",
			values	= {
				["0"]    = L["Hide"],
				["1"]    = L["Current / max expierence"],
				["2"]    = L["Need to next point"],
			},
			default = "1"
		},
		{ type="toggle", name="showPower", label=L["Show unspend artifact power"], tooltip=L["Show amount summary of artifact power from items in your backpack in broker button"]},
		{ type="toggle", name="showKnowledge", label=L["Show artifact knowledge"], tooltip=L["Show artifact knowledge in broker button"]},
		{ type="toggle", name="showWarning", label=L["Show 'not equipped' warning"], tooltip=L["Show 'artifact weapon not equipped' warning in broker button"]},
	},
	config_tooltip = {
		{ type="toggle", name="showRelic",                  label=L["Show artifact relic"],               tooltip=L["Display a list of artifact relic slots in tooltip"]},
		{ type="toggle", name="showRelicItemLevel",         label=L["Show relic item level"],             tooltip=L["Display relic item level"]},
		{ type="toggle", name="showRelicIncreaseItemLevel", label=L["Show increase item level by relic"], tooltip=L["Display increase item level by relic"]},
		{ type="toggle", name="showItems",                  label=L["Show artifact power items"],         tooltip=L["Display a list of artifact power items found in your bag in tooltip"]},
		{ type="toggle", name="showTotalAP",                label=L["Show total used artifact power"],    tooltip=L["Display amount of total used artifact power on current equipped artifact weapon. That doesn't includes point resets!"]},
	},
	config_misc = "shortNumbers",
	clickOptions = {
		["1_open_character_info"] = {
			cfg_label = "Open character info", -- L["Open character info"]
			cfg_desc = "open the character info", -- L["open the character info"]
			cfg_default = "__NONE",
			hint = "Open character info", -- L["Open character info"]
			func = function(self,button)
				local _mod=name;
				securecall("ToggleCharacter","PaperDollFrame");
			end
		},
		["2_artifact_frame"] = {
			cfg_label = "Open artifact frame", -- L["Show artifact frame"]
			cfg_desc = "open artifact frame", -- L["open artifact frame"]
			cfg_default = "_LEFT",
			hint = "Open artifact frame",
			func = function(self,button)
				local _mod=name;
				SocketInventoryItem(16);
			end
		},
		["3_open_menu"] = {
			cfg_label = "Open option menu", -- L["Open option menu"]
			cfg_desc = "open the option menu", -- L["open the option menu"]
			cfg_default = "_RIGHT",
			hint = "Open option menu", -- L["Open option menu"]
			func = function(self,button)
				local _mod=name; -- for error tracking
				createMenu(self);
			end
		}
	}
}


--------------------------
-- some local functions --
--------------------------
function createMenu(self)
	if (tt~=nil) and (tt:IsShown()) then ns.hideTooltip(tt); end
	ns.EasyMenu.InitializeMenu();
	ns.EasyMenu.addConfigElements(name);
	ns.EasyMenu.ShowMenu(self);
end

local function CalculateArtifactPower(ap,ak) -- artifact_power, artifact_knowledge
	ap,ak=tonumber(ap) or 0,tonumber(ak) or 0;
	if ak > 0 then
		ap = tonumber(("%.0f"):format(ap*(artifactKnowledgeMultiplier[ak]+1)));
		local n = tonumber(strsub(ap,-1));
		if n<3 then
			ap = ap-n;
		elseif n<=7 then
			ap = ap-n+5;
		end
	end
	return ap;
end

local updateItemStateTry,updateItemState=0;
local function ttMatchString(line,matchString)
	local AP;
	if type(matchString)=="table" then
		AP = tonumber(line:gsub("%.",""):match(matchString[1]));
		if not AP then
			AP = tonumber(line:gsub("%.",""):match(matchString[2]));
		end
	else
		AP = tonumber(line:gsub("%.",""):match(matchString));
	end
	return AP;
end

function updateItemState()
	wipe(ap_items_found);
	local lst = ns.items.GetItemlist();
	local matchString1 = AP_MATCH_STRINGS[ns.locale] or AP_MATCH_STRINGS.enUS;
	local matchString2 = FISHING_AP_MATCH_STRINGS[ns.locale] or FISHING_AP_MATCH_STRINGS.enUS;
	local isFishing = false;
	for id,v in pairs(lst) do
		if ns.artifactpower_items[id]~=nil then
			-- group items by knowledge levels
			local kl = {};
			for I,V in ipairs(v)do
				local knowledge = V.linkData[#V.linkData-3];
				if knowledge then
					if kl[knowledge]==nil then kl[knowledge]={}; end
					tinsert(kl[knowledge],V);
				end
			end
			for klvl,V in pairs(kl)do
				local knowledgeLevel = klvl-1;
				local AP = nil;
				-- try to get artifact power from tooltip
				if v[1].tooltip then
					for i=2, #v[1].tooltip do
						AP = ttMatchString(v[1].tooltip[i],matchString1);
						if not AP then
							AP = ttMatchString(v[1].tooltip[i],matchString2);
							if AP then
								isFishing = true;
							end
						end
						if AP then
							break;
						end
					end
				end
				-- second, calculate from ground value with knowledge level multiplier.
				-- sometimes not really accurate because blizzard does not really use its own multiplier.
				-- all values comes from database. 
				-- for example: item 141708 > 545 artifact power without knowledge level. 1025 instead of 1035 with knowledge level 3.
				-- /run print("\124cff0070dd\124Hitem:141708::::::::110:62:8388608:30::1:::\124h[Item 141708]\124h\124r")
				-- /run print("\124cff0070dd\124Hitem:141708::::::::110:62:8388608:30::4:::\124h[Item 141708]\124h\124r")
				if not isFishing and not AP and ns.artifactpower_items[id]~=-1 then
					AP = CalculateArtifactPower(ns.artifactpower_items[id],knowledgeLevel);
				end
				tinsert(ap_items_found,{
					id=id,
					count=#V,
					name=v[1].name,
					link=v[1].link,
					icon=v[1].icon,
					artifact_power=AP or -1,
					quality=v[1].rarity,
					isFishing = isFishing
				});
			end
		end
	end
	updateBroker()
end

local function GetRelicTooltipData(data)
	local obj = data.obj or {};
	if obj.awItemID and obj.relicIndex then
		if ns.toon[name][obj.awItemID].relic==nil then
			ns.toon[name][obj.awItemID].relic = {};
		end
		local iLevel,increaseLevel = 0,0;
		if data and data.lines and #data.lines>0 then
			iLevel = tonumber(data.lines[2]:match(_ITEM_LEVEL)) or tonumber(data.lines[3]:match(_ITEM_LEVEL)) or 0;
			increaseLevel = tonumber(data.lines[5]:match("(.*) "..RELIC_ITEM_LEVEL_INCREASE)) or tonumber(data.lines[6]:match("(.*) "..RELIC_ITEM_LEVEL_INCREASE)) or 0;
		end
		ns.toon[name][obj.awItemID].relic[obj.relicIndex].level = iLevel;
		ns.toon[name][obj.awItemID].relic[obj.relicIndex].increase = increaseLevel;
	end
end

local function updateCharacterDB(equipped)
	local artifact_frame = (ArtifactFrame and ArtifactFrame:IsShown() and ArtifactFrame.PerksTab and ArtifactFrame.PerksTab:IsShown());
	local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop = C_ArtifactUI[artifact_frame and "GetArtifactInfo" or "GetEquippedArtifactInfo"]();
	if itemID then
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp);
		local maxPoints = numPoints+pointsSpent;

		local relic = {};
		artifactLocked = nil;
		if equipped then
			ns.toon[name].equipped=equipped;
		end
		if ns.toon[name][itemID] and ns.toon[name][itemID].relic then
			relic = ns.toon[name][itemID].relic;
			if not artifact_frame then
				for i=1,#relic do
					if relic[i].link and relic[i].level==nil then
						ns.ScanTT.query({type="link",link=relic[i].link,obj={awItemID=itemID,relicIndex=i},callback=GetRelicTooltipData});
					end
				end
			end
		end
		ns.toon[name][itemID] = {name=itemName,points={pointsSpent,maxPoints},xp={artifactXP, xpForNextPoint},relic=relic};

		if artifact_frame then
			for i,v in ipairs(ArtifactFrame.PerksTab.TitleContainer.RelicSlots)do
				if not v.relicType then
					artifactLocked = ARTIFACT_VISIT_FORGE_TO_START;
				end
				local icon,itemname,color,linktype,itemid,data,_=ns.icon_fallback;
				if v.relicLink then
					_,_,color,linktype,itemid,data,itemname = v.relicLink:find("|c(%x*)|H([^:]*):(%d+):(.+)|h%[([^%[%]]*)%]|h|r");
					icon = GetItemIcon(itemid);
				end
				ns.toon[name][itemID].relic[i]={id=tonumber(itemid),color=color,icon=icon,name=itemname,type=v.relicType,locked=v.lockedReason or false,link=v.relicLink};
				if v.relicLink then
					ns.ScanTT.query({type="link",link=v.relicLink,obj={awItemID=itemID,relicIndex=i},callback=GetRelicTooltipData});
				end
			end
		end
	end
end

function updateBroker()
	local _;

	obtained = C_ArtifactUI.GetNumObtainedArtifacts();

	local allDisabled,data,obj = true,{}, ns.LDB:GetDataObjectByName(ns.modules[name].ldbName);
	local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo();

	updateCharacterDB(itemID);

	if itemID then
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp);
		local maxPoints = numPoints+pointsSpent;

		if ns.profile[name].showName then
			tinsert(data,C("quality"..quality,itemName));
			allDisabled=false;
		end

		if ns.profile[name].showPoints then
			tinsert(data,C(maxPoints>pointsSpent and "orange" or "green",pointsSpent).."/"..C("green",numPoints+pointsSpent));
			allDisabled=false;
		end

		if ns.profile[name].showXP=="1" then
			tinsert(data,C("yellow",ns.FormatLargeNumber(name,artifactXP)).."/"..C("ltblue",ns.FormatLargeNumber(name,xpForNextPoint)));
			allDisabled=false;
		elseif ns.profile[name].showXP=="2" then
			tinsert(data,C("yellow",ns.FormatLargeNumber(name,xpForNextPoint-artifactXP)));
			allDisabled=false;
		end

		if ns.profile[name].showKnowledge and ns.toon[name].knowledgeLevel>0 then
			tinsert(data,C("orange",ns.toon[name].knowledgeLevel));
		end

		if ns.profile[name].showPower then
			local sum = {0,0};
			for i,v in ipairs(ap_items_found)do
				if v.artifact_power==-1 then
					sum[2] = sum[2] + 1;
				elseif v.artifact_power>0 then
					sum[1] = sum[1] + (v.count * v.artifact_power);
				end
			end
			tinsert(data,ns.FormatLargeNumber(name,sum[1])..strrep("+",sum[2]));
			allDisabled=false;
		end
	end

	obj.icon = icon or "interface\\icons\\Ability_MeleeDamage";

	if allDisabled then
		if ns.profile[name].showWarning and obtained>0 then
			obj.text = C("orange",L["Artifact weapon not equipped"]);
		else
			obj.text = L[name];
		end
	else
		obj.text = table.concat(data,", ");
	end
end

local function itemTooltipShow(self,data)
	local info = self.info;
	if not info then return end

	GameTooltip:SetOwner(tt,"ANCHOR_NONE");
	GameTooltip:SetPoint("TOP",tt,"BOTTOM");
	GameTooltip:SetClampedToScreen(true);
	GameTooltip:ClearLines();
	if info.locked then
		GameTooltip:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-LOCK:16:16:0:2:32:32:0:25:0:25|t "..C("red",LOCKED));
		GameTooltip:AddLine(info.locked,.78,.78,.78,true);
	elseif info.link then
		GameTooltip:SetHyperlink(info.link);
	end
	GameTooltip:Show();
end

local function itemTooltipHide(self)
	GameTooltip:Hide();
end

function createTooltip(tt)
	if (tt) and (tt.key) and (tt.key~=ttName) then return end -- don't override other LibQTip tooltips...

	tt:Clear();
	tt:AddHeader(C("dkyellow",L[name]));
	tt:AddSeparator();

	if obtained==0 then
		tt:SetCell(tt:AddLine(),1,C("gray",L["Currently you have no artifact weapon obtained..."]));
	elseif artifactLocked then
		tt:AddLine(artifactLocked);
	else
		local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop = C_ArtifactUI.GetEquippedArtifactInfo();
		if itemID then
			local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp);
			local maxPoints = numPoints+pointsSpent;

			local l=tt:AddLine();
			tt:SetCell(l,1,C("ltgreen",L["Equipped artifact weapon"]),nil,"LEFT",2);
			if strlen(itemName)>16 then
				l=tt:AddLine();
				tt:SetCell(l,1,"     |T"..icon..":0|t "..C("ltyellow",itemName),nil,"RIGHT",0);
			else
				tt:SetCell(l,3,"|T"..icon..":0|t "..C("ltyellow",itemName));
			end

			l=tt:AddLine();
			tt:SetCell(l,1,C("ltgreen",L["Spent artifact power"]),nil,nil,2);
			tt:SetCell(l,3,C("ltyellow",ns.FormatLargeNumber(name,xp,true)).."/"..C("ltyellow",ns.FormatLargeNumber(name,xpForNextPoint,true)));

			l=tt:AddLine();
			tt:SetCell(l,1,C("ltgreen",L["Spent points"]),nil,nil,2);
			tt:SetCell(l,3,C(maxPoints>pointsSpent and "ltorange" or "ltyellow",pointsSpent).."/"..C("ltyellow",numPoints+pointsSpent));

			if ns.profile[name].showTotalAP then
				local _,_,_,_,xp,ps=C_ArtifactUI.GetEquippedArtifactInfo();
				for i=1,ps-1 do
					xp=xp+C_ArtifactUI.GetCostForPointAtRank(i);
				end 
				l=tt:AddLine();
				tt:SetCell(l,1,C("ltgreen",L["Total spend power"]),nil,nil,2);
				tt:SetCell(l,3,C("ltyellow",ns.FormatLargeNumber(name,xp,true)));
			end

			if ns.toon[name].knowledgeLevel and ns.toon[name].knowledgeLevel>0 and itemID~=133755 then
				l=tt:AddLine();
				local ak = GetCurrencyInfo(1171);
				tt:SetCell(l,1,C("ltgreen",ak or L["Artifact knowledge"]),nil,nil,2);
				tt:SetCell(l,3,C("ltyellow",("%d (+%s%%)"):format(ns.toon[name].knowledgeLevel,ns.FormatLargeNumber(name,math.ceil(artifactKnowledgeMultiplier[ns.toon[name].knowledgeLevel]*10)*10,true))));
				local nextKL = ns.toon[name].knowledgeLevel+1;
				if nextKL<=artifactKnowledgeMultiplier_len then
					l=tt:AddLine();
					tt:SetCell(l,1,C("gray2",L["Next artifact knowledge"]),nil,nil,2);
					tt:SetCell(l,3,C("gray2",("%d (+%s%%)"):format(nextKL,ns.FormatLargeNumber(name,math.ceil(artifactKnowledgeMultiplier[nextKL]*10)*10,true))));
				end
			end

			local weapon = ns.items.GetInventoryItemBySlotIndex(16);
			if weapon then
				tt:AddLine(C("ltgreen",STAT_AVERAGE_ITEM_LEVEL),"",C("ltyellow",weapon.level));
			end

			if ns.profile[name].showRelic and ns.toon[name][itemID] and ns.toon[name][itemID].relic and itemID~=133755 then
				tt:AddSeparator(4,0,0,0,0);
				tt:AddLine(C("ltblue",RELICSLOT));
				tt:AddSeparator();
				if #ns.toon[name][itemID].relic>0 then
					for i,v in ipairs(ns.toon[name][itemID].relic) do
						local ilvl={};
						if (tonumber(v.level) or 0)>0 and ns.profile[name].showRelicItemLevel then
							tinsert(ilvl,v.level);
						end
						if (tonumber(v.increase) or 0)>0 and ns.profile[name].showRelicIncreaseItemLevel then
							tinsert(ilvl,"+"..v.increase);
						end
						if #ilvl>0 then
							ilvl = " "..C("gray2","("..table.concat(ilvl,"/")..")");
						else
							ilvl="";
						end
						local n = (v.color and C(v.color,v.name)..ilvl) or (v.locked and C("red", LOCKED)) or C("ltgray",EMPTY);
						local icon = v.locked and "|TInterface\\LFGFrame\\UI-LFG-ICON-LOCK:14:14:0:0:32:32:0:25:0:25|t " or "|T"..(v.icon or ns.icon_fallback)..":0|t ";
						local _type = v.type or UNKNOWN;
						local l=tt:AddLine(C("white",i..". ")..C("ltgreen",_G["STRING_SCHOOL_".._type:upper()] or _type));
						tt:SetCell(l,2,icon .. n,nil,nil,0);
						if v.locked or v.link then
							tt.lines[l].info = v;
							tt:SetLineScript(l,"OnEnter",itemTooltipShow);
							tt:SetLineScript(l,"OnLeave",itemTooltipHide);
						end
					end
				else
					local l=tt:AddLine();
					tt:SetCell(l,1,C("ltgray",ns.strWrap(L["Artifact relic are displayable after opening artifact window. Shift Right-Click on your equipped artifact weapon."],64)),nil,nil,ttColumns);
				end
			end

			if ns.profile[name].showItems then
				tt:AddSeparator(4,0,0,0,0);
				local l=tt:AddLine();
				tt:SetCell(l,1,C("ltblue",L["Found in your backpack"]),nil,nil,2);
				tt:SetCell(l,3,C("ltblue",ARTIFACT_POWER));
				tt:AddSeparator();
				local count,sum=0,0;
				for i,v in ipairs(ap_items_found)do
					local l;
					if v.artifact_power==-1 then
						l=tt:AddLine();
						tt:SetCell(l,1,"|T".. v.icon .. ":0|t ".. C("quality"..v.quality or 7,v.name),nil,nil,2);
						tt:SetCell(l,3," ");
					elseif v.artifact_power>0 then
						l=tt:AddLine();
						tt:SetCell(l,1,"|T".. v.icon .. ":0|t ".. C("quality"..v.quality or 7,v.name),nil,nil,2);
						tt:SetCell(l,3,C("ltyellow",v.count .." x " .. ns.FormatLargeNumber(name,v.artifact_power,true)));
						sum = sum + (v.count*v.artifact_power);
					end
					if v.link then
						tt.lines[l].info = v;
						tt:SetLineScript(l,"OnEnter",itemTooltipShow);
						tt:SetLineScript(l,"OnLeave",itemTooltipHide);
					end
					count=count+1;
				end
				if count>0 then
					tt:AddSeparator();
					tt:AddLine(C("ltblue",L["Summary"]..":"),nil,ns.FormatLargeNumber(name,sum,true));
				else
					local l = tt:AddLine();
					tt:SetCell(l,1,C("ltgray",L["Currently no artifact power items found"]), nil, nil, ttColumns);
				end
			end
		else
			tt:AddLine(C("ltgray",L["Currently you have no artifact weapon equipped..."]));
		end
	end

	if ns.profile.GeneralOptions.showHints then
		tt:AddSeparator(3,0,0,0,0);
		ns.clickOptions.ttAddHints(tt,name);
	end
	ns.roundupTooltip(tt);
end


------------------------------------
-- module (BE internal) functions --
------------------------------------
-- ns.modules[name].init = function() end
ns.modules[name].onevent = function(self,event,arg1,...)
	if event=="PLAYER_ENTERING_WORLD" then
		if ns.toon[name]==nil then
			ns.toon[name] = {equipped=false,knowledgeLevel=0};
		end
		if ns.toon[name].knowledgeLevel==nil then
			ns.toon[name].knowledgeLevel = 0;
		end
		ns.items.RegisterCallback(name,updateItemState,"any");
		C_Timer.After(15,ns.items.UpdateNow);
		self:UnregisterEvent(event);
		self.PEW=true;
	elseif self.PEW then
		if event=="BE_UPDATE_CLICKOPTIONS" then
			ns.clickOptions.update(ns.modules[name],ns.profile[name]);
		elseif obtained>0 and event=="CURRENCY_DISPLAY_UPDATE" then -- update artifact knowledge
			local _, value = GetCurrencyInfo(1171);
			if value and ns.toon[name].knowledgeLevel~=value then
				ns.toon[name].knowledgeLevel = value;
				updateBroker();
			end
		else--if event=="ARTIFACT_XP_UPDATE" or event=="ARTIFACT_MAX_RANKS_UPDATE" or event=="ARTIFACT_UPDATE" then
			obtained = C_ArtifactUI.GetNumObtainedArtifacts() or 0;
			updateBroker();
		end
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
	tt = ns.acquireTooltip({ttName, ttColumns, "LEFT", "RIGHT", "RIGHT", "LEFT", "LEFT","RIGHT", "CENTER", "LEFT", "LEFT", "LEFT"},{false},{self});
	createTooltip(tt);
end

-- ns.modules[name].onleave = function(self) end
-- ns.modules[name].onclick = function(self,button) end
-- ns.modules[name].ondblclick = function(self,button) end
