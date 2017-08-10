

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
local PATTERN_ARTIFACT_XP_GAIN = gsub(ARTIFACT_XP_GAIN,"%s",".*");
local PATTERN_SECOND_NUMBERS = {};
PATTERN_SECOND_NUMBERS[1] = SECOND_NUMBER:gsub("%|7(.*):(.*);","%1");
PATTERN_SECOND_NUMBERS[2] = SECOND_NUMBER:gsub("%|7(.*):(.*);","%2");
if PATTERN_SECOND_NUMBERS[1]:len()<PATTERN_SECOND_NUMBERS[2]:len() then
	PATTERN_SECOND_NUMBERS[1],PATTERN_SECOND_NUMBERS[2] = PATTERN_SECOND_NUMBERS[2],PATTERN_SECOND_NUMBERS[1];
end
local artifactKnowledgeMultiplier_cap, artifactLocked = 40; -- 50
if ns.build>=73000000 then
	artifactKnowledgeMultiplier_cap = 50; -- 7.3
end
local artifactKnowledgeMultiplier = {}
local AP_MATCH_STRINGS,FISHING_AP_MATCH_STRINGS = {},{};
ns.artifactpower_items = {};
ns.artifactrelikts = {};


-------------------------------------------
-- register icon names and default files --
-------------------------------------------
I[name] = {iconfile=1109508 or ns.icon_fallback,coords={0.05,0.95,0.05,0.95}} --IconName::Artifact weapon--


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
	config_misc = {"shortNumbers"},
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
local function initData()
	ns.artifactpower_items = {
		-- >0 = known amount of artifact power
		-- -1 = special actifact power items
		[127999]=1, [128000]=1, [128021]=1, [128022]=1, [128026]=1, [130144]=1, [130149]=1, [130152]=1, [130153]=1, [130159]=1, [130160]=1, [130165]=1,
		[131728]=1, [131732]=1, [131751]=1, [131753]=1, [131758]=1, [131763]=1, [131778]=1, [131784]=1, [131785]=1, [131789]=1, [131795]=1, [131802]=1,
		[131808]=1, [132361]=1, [132897]=1, [132923]=1, [132950]=1, [134118]=1, [134133]=1, [136360]=1, [138480]=1, [138487]=1, [138726]=1, [138732]=1,
		[138781]=1, [138782]=1, [138783]=1, [138784]=1, [138785]=1, [138786]=1, [138812]=1, [138813]=1, [138814]=1, [138816]=1, [138839]=1, [138864]=1,
		[138865]=1, [138880]=1, [138881]=1, [138885]=1, [138886]=1, [139413]=1, [139506]=1, [139507]=1, [139508]=1, [139509]=1, [139510]=1, [139511]=1,
		[139512]=1, [139608]=1, [139609]=1, [139610]=1, [139611]=1, [139612]=1, [139613]=1, [139614]=1, [139615]=1, [139616]=1, [139617]=1, [139652]=1,
		[139653]=1, [139654]=1, [139655]=1, [139656]=1, [139657]=1, [139658]=1, [139659]=1, [139660]=1, [139661]=1, [139662]=1, [139663]=1, [139664]=1,
		[139665]=1, [139666]=1, [139667]=1, [139668]=1, [139669]=1, [140176]=1, [140237]=1, [140238]=1, [140241]=1, [140244]=1, [140247]=1, [140250]=1,
		[140251]=1, [140252]=1, [140254]=1, [140255]=1, [140304]=1, [140305]=1, [140306]=1, [140307]=1, [140310]=1, [140322]=1, [140349]=1, [140357]=1,
		[140358]=1, [140359]=1, [140361]=1, [140364]=1, [140365]=1, [140366]=1, [140367]=1, [140368]=1, [140369]=1, [140370]=1, [140371]=1, [140372]=1,
		[140373]=1, [140374]=1, [140377]=1, [140379]=1, [140380]=1, [140381]=1, [140382]=1, [140383]=1, [140384]=1, [140385]=1, [140386]=1, [140387]=1,
		[140388]=1, [140389]=1, [140391]=1, [140392]=1, [140393]=1, [140396]=1, [140409]=1, [140410]=1, [140421]=1, [140422]=1, [140444]=1, [140445]=1,
		[140459]=1, [140460]=1, [140461]=1, [140462]=1, [140463]=1, [140466]=1, [140467]=1, [140468]=1, [140469]=1, [140470]=1, [140471]=1, [140473]=1,
		[140474]=1, [140475]=1, [140476]=1, [140477]=1, [140478]=1, [140479]=1, [140480]=1, [140481]=1, [140482]=1, [140484]=1, [140485]=1, [140486]=1,
		[140487]=1, [140488]=1, [140489]=1, [140490]=1, [140491]=1, [140492]=1, [140494]=1, [140497]=1, [140498]=1, [140503]=1, [140504]=1, [140505]=1,
		[140507]=1, [140508]=1, [140509]=1, [140510]=1, [140511]=1, [140512]=1, [140513]=1, [140515]=1, [140516]=1, [140517]=1, [140518]=1, [140519]=1,
		[140520]=1, [140521]=1, [140522]=1, [140523]=1, [140524]=1, [140525]=1, [140528]=1, [140529]=1, [140530]=1, [140531]=1, [140532]=1, [140685]=1,
		[140847]=1, [141023]=1, [141024]=1, [141310]=1, [141313]=1, [141314]=1, [141337]=1, [141383]=1, [141384]=1, [141385]=1, [141386]=1, [141387]=1,
		[141388]=1, [141389]=1, [141390]=1, [141391]=1, [141392]=1, [141393]=1, [141394]=1, [141395]=1, [141396]=1, [141397]=1, [141398]=1, [141399]=1,
		[141400]=1, [141401]=1, [141402]=1, [141403]=1, [141404]=1, [141405]=1, [141638]=1, [141639]=1, [141667]=1, [141668]=1, [141669]=1, [141670]=1,
		[141671]=1, [141672]=1, [141673]=1, [141674]=1, [141675]=1, [141676]=1, [141677]=1, [141678]=1, [141679]=1, [141680]=1, [141681]=1, [141682]=1,
		[141683]=1, [141684]=1, [141685]=1, [141689]=1, [141690]=1, [141699]=1, [141701]=1, [141702]=1, [141703]=1, [141704]=1, [141705]=1, [141706]=1,
		[141707]=1, [141708]=1, [141709]=1, [141710]=1, [141711]=1, [141852]=1, [141853]=1, [141854]=1, [141855]=1, [141856]=1, [141857]=1, [141858]=1,
		[141859]=1, [141863]=1, [141872]=1, [141876]=1, [141877]=1, [141883]=1, [141886]=1, [141887]=1, [141888]=1, [141889]=1, [141890]=1, [141891]=1,
		[141892]=1, [141896]=1, [141921]=1, [141922]=1, [141923]=1, [141924]=1, [141925]=1, [141926]=1, [141927]=1, [141928]=1, [141929]=1, [141930]=1,
		[141931]=1, [141932]=1, [141933]=1, [141934]=1, [141935]=1, [141936]=1, [141937]=1, [141940]=1, [141941]=1, [141942]=1, [141943]=1, [141944]=1,
		[141945]=1, [141946]=1, [141947]=1, [141948]=1, [141949]=1, [141950]=1, [141951]=1, [141952]=1, [141953]=1, [141954]=1, [141955]=1, [141956]=1,
		[142001]=1, [142002]=1, [142003]=1, [142004]=1, [142005]=1, [142006]=1, [142007]=1, [142054]=1, [142449]=1, [142450]=1, [142451]=1, [142453]=1,
		[142454]=1, [142455]=1, [142533]=1, [142534]=1, [142535]=1, [142555]=1, [143333]=1, [143486]=1, [143487]=1, [143488]=1, [143498]=1, [143499]=1,
		[143533]=1, [143536]=1, [143538]=1, [143540]=1, [143677]=1, [143680]=1, [143713]=1, [143714]=1, [143715]=1, [143716]=1, [143738]=1, [143739]=1,
		[143740]=1, [143741]=1, [143742]=1, [143743]=1, [143744]=1, [143745]=1, [143746]=1, [143747]=1, [143749]=1, [143757]=1, [143844]=1, [143868]=1,
		[143869]=1, [143870]=1, [143871]=1, [144266]=1, [144267]=1, [144268]=1, [144269]=1, [144270]=1, [144271]=1, [144272]=1, [144297]=1, [146122]=1,
		[146123]=1, [146124]=1, [146125]=1, [146126]=1, [146127]=1, [146128]=1, [146129]=1, [146309]=1, [146313]=1, [146314]=1, [146315]=1, [146316]=1,
		[146318]=1, [146319]=1, [146320]=1, [146321]=1, [146322]=1, [146323]=1, [146324]=1, [146325]=1, [146326]=1, [146327]=1, [146329]=1, [146662]=1,
		[146663]=1, [146664]=1, [146671]=1, [147198]=1, [147199]=1, [147200]=1, [147201]=1, [147202]=1, [147203]=1, [147293]=1, [147398]=1, [147399]=1,
		[147400]=1, [147401]=1, [147402]=1, [147403]=1, [147404]=1, [147405]=1, [147406]=1, [147407]=1, [147408]=1, [147409]=1, [147441]=1, [147442]=1,
		[147444]=1, [147456]=1, [147457]=1, [147458]=1, [147459]=1, [147460]=1, [147461]=1, [147462]=1, [147463]=1, [147464]=1, [147465]=1, [147466]=1,
		[147467]=1, [147468]=1, [147469]=1, [147470]=1, [147471]=1, [147472]=1, [147473]=1, [147474]=1, [147475]=1, [147476]=1, [147477]=1, [147478]=1,
		[147479]=1, [147480]=1, [147481]=1, [147482]=1, [147483]=1, [147484]=1, [147485]=1, [147486]=1, [147513]=1, [147548]=1, [147549]=1, [147550]=1,
		[147551]=1, [147579]=1, [147581]=1, [147718]=1, [147719]=1, [147720]=1, [147721]=1, [147808]=1, [147809]=1, [147810]=1, [147811]=1, [147812]=1,
		[147814]=1, [147818]=1, [147819]=1, [147842]=1
	};

	artifactKnowledgeMultiplier = {
		-- with 7.0
		  0.25,  0.50,  0.90,  1.40,  2.00, --  1 -  5
		  2.75,  3.75,  5.00,  6.50,  8.50, --  6 - 10
		 11.00, 14.00, 17.75, 22.50, 28.50, -- 11 - 15
		 36.00, 45.50, 57.00, 72.00, 90.00, -- 16 - 20
		113.00,142.00,178.00,223.00,249.00, -- 21 - 25

		-- with 7.2
		  1000.00,   1300.00,   1700.00,   2200.00,   2900.00, -- 26 - 30
		  3800.00,   4900.00,   6400.00,   8300.00,  10800.00, -- 31 - 35
		 14000.00,  18200.00,  23700.00,  30800.00,  40000.00, -- 36 - 40
		 52000.00,  67600.00,  87900.00, 114300.00, 148600.00, -- 41 - 45
		193200.00, 251200.00, 326600.00, 424600.00, 552000.00, -- 46 - 50
	}

	AP_MATCH_STRINGS = {
		deDE = "Gewährt Eurem derzeit ausgerüsteten Artefakt (.*) Artefaktmacht",
		enUS = "Grants (.*) Artifact Power to your currently equipped Artifact",
		esES = "Otorga (.*) p. de poder de artefacto al artefacto que lleves equipado",
		esMX = "Otorga (.*) p. de Poder de artefacto para el artefacto que llevas equipado",
		frFR = "Confère (.*) point* de puissance à l’arme prodigieuse que vous brandissez",
		itIT = {"Fornisce (.*) Potere Artefatto all'Artefatto attualmente equipaggiato.","(.*) Potere Artefatto fornito all'Artefatto attualmente equipaggiato"},
		koKR = {"현재 장착한 유물에 (.*)의 유물력을 부여합니다.","현재 장착한 유물에 (.*)의 유물력 부여"},
		ptBR = "Concede (.*) de Poder do Artefato ao artefato equipado",
		ptPT = "Concede (.*) de Poder do Artefato ao artefato equipado",
		ruRU = {"Добавляет используемому в данный момент артефакту (.*) ед. силы артефакта.","Добавление используемому в данный момент артефакту (.*) ед. силы артефакта"},
		zhCN = "将(.*)点神器能量注入到你当前装备的神器之中",
		zhTW = "賦予你目前裝備的神兵武器(.*)點神兵之力",
	}

	FISHING_AP_MATCH_STRINGS = {
		deDE = "Wirft den Fisch zurück ins Wasser und gewährt Eurem Angelartefakt (.*) Artefaktmacht",
		enUS = "Toss the fish back into the water, granting (.*) Artifact Power to your fishing artifact",
		esES = "Lanza el pez de nuevo al agua, lo que otorga (.*) p. de poder de artefacto a tu artefacto de pesca",
		esMX = "Devuelve el pez al agua, lo que otorga (.*) de poder de artefacto a tu artefacto de pesca",
		frFR = "Vous rejetez le poisson à l’eau, ce qui confère (.*) $lpoint:points; de puissance prodigieuse à votre ustensile de pêche prodigieux",
		itIT = "Rilancia il pesce in acqua, fornendo (.*) Potere Artefatto al tuo artefatto da pesca",
		koKR = "물고기를 다시 물에 던져 낚시 유물에 (.*)의 유물력을 추가합니다.",
		ptBR = "Joga o peixe de volta na água, concedendo (.*) de Poder do Artefato ao seu artefato de pesca",
		ptPT = "Joga o peixe de volta na água, concedendo (.*) de Poder do Artefato ao seu artefato de pesca",
		ruRU = "Бросить рыбу обратно в воду, добавив вашему рыболовному артефакту (.*) ед. силы артефакта",
		zhCN = "将鱼扔回到水中，使你的钓鱼神器获得(.*)点神器能量",
		zhTW = "將魚丟回水中，為你的釣魚神器取得(.*)點神兵之力",
	}
end

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
	local artefact_power;
	if type(matchString)=="table" then
		artefact_power = line:match(matchString[1]);
		if not artefact_power then
			artefact_power = line:match(matchString[2]);
		end
	else
		artefact_power = line:match(matchString);
	end

	if artefact_power then
		local pat;
		if artefact_power:find(PATTERN_SECOND_NUMBERS[1]) then
			pat = PATTERN_SECOND_NUMBERS[1];
		elseif artefact_power:find(PATTERN_SECOND_NUMBERS[2]) then
			pat = PATTERN_SECOND_NUMBERS[2];
		end
		if pat then
			artefact_power = artefact_power:gsub("(%d*)[,%.](%d)[ ]?"..pat,"%1%200000"):gsub("(%d*)[ ]?"..pat,"%1000000");
		end
		artefact_power = artefact_power:gsub("[,%.]","");
	end

	return tonumber(artefact_power);
end

function updateItemState()
	wipe(ap_items_found);
	local lst = ns.items.GetItemlist();
	local matchString1 = AP_MATCH_STRINGS[ns.locale] or AP_MATCH_STRINGS.enUS;
	local matchString2 = FISHING_AP_MATCH_STRINGS[ns.locale] or FISHING_AP_MATCH_STRINGS.enUS;
	local isFishing = false;
	for id,v in pairs(lst) do
		if ns.artifactpower_items[id]~=nil then
			-- group items with same item id by knowledge levels
			local klvls = {};
			for _,item in ipairs(v)do
				local knowledge = item.linkData[#item.linkData-3];
				if knowledge then
					if klvls[knowledge]==nil then klvls[knowledge]={}; end
					tinsert(klvls[knowledge],item);
				end
			end
			for klvl,items in pairs(klvls)do
				local knowledgeLevel = klvl-1;
				local artefact_power = nil;
				-- missing item tooltip?
				if not items[1].tooltip then
					ns.items.GetItemTooltip(items[1]);
				end
				-- read artefact power from single item tooltip with same item id and knowledge level
				if items[1].tooltip then
					for i=2, #items[1].tooltip do
						artefact_power = ttMatchString(items[1].tooltip[i],matchString1); -- artefact power for artefact weapons?
						if not artefact_power then
							artefact_power = ttMatchString(items[1].tooltip[i],matchString2); -- artefact power for artefact pole?
							if artefact_power then
								isFishing = true;
							end
						end
						if artefact_power then
							break;
						end
					end
				end
				tinsert(ap_items_found,{
					id=id,
					count=#items,
					name=items[1].name,
					link=items[1].link,
					icon=items[1].icon,
					artifact_power=artefact_power or -1,
					quality=items[1].rarity,
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
	local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop, artifactTier = C_ArtifactUI[artifact_frame and "GetArtifactInfo" or "GetEquippedArtifactInfo"]();
	if itemID then
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp,artifactTier);
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
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp,artifactTier);
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

	if tt.lines~=nil then tt:Clear(); end
	tt:AddHeader(C("dkyellow",L[name]));
	tt:AddSeparator();

	if obtained==0 then
		tt:SetCell(tt:AddLine(),1,C("gray",L["Currently you have no artifact weapon obtained..."]));
	elseif artifactLocked then
		tt:AddLine(artifactLocked);
	else
		local itemID, altItemID, itemName, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo();
		if itemID then
			local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent,xp,artifactTier);
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
					xp=xp+C_ArtifactUI.GetCostForPointAtRank(i,artifactTier);
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
				if nextKL<=artifactKnowledgeMultiplier_cap then
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
						local label = _G["RELIC_SLOT_TYPE_" .. _type:upper()] .. " " .. RELICSLOT;
						local l=tt:AddLine(C("white",i..". ")..C("ltgreen",label));
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
ns.modules[name].init = function()
	if initData then
		initData();
		initData=nil;
	end
end

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
