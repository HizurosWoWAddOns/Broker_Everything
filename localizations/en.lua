
local addon, ns = ...
-- ----------------------------------------------------------------- --
-- Localization metatable function                                   --
-- Instructions for Non-Ace3 method taken from Phanx at WowInterface --
-- http://www.wowinterface.com/portal.php?&id=224&pageid=250         --
-- ================================================================= --
-- Extended version by Hizuro to use some localization strings       --
-- from Blizzard                                                     --
-- ----------------------------------------------------------------- --

ns.L = setmetatable({}, {
	__index = function(t, k)
		if not k then return "?"; end
		local v=tostring(k);
		rawset(t, k, v);
		return v;
	end
})

if (FACTION_STANDING_LABEL1~="Hated") then
	ns.L["Hated"]         = FACTION_STANDING_LABEL1
	ns.L["Hostile"]       = FACTION_STANDING_LABEL2
	ns.L["Unfriendly"]    = FACTION_STANDING_LABEL3
	ns.L["Neutral"]       = FACTION_STANDING_LABEL4
	ns.L["Friendly"]      = FACTION_STANDING_LABEL5
	ns.L["Honoured"]      = FACTION_STANDING_LABEL6
	ns.L["Revered"]       = FACTION_STANDING_LABEL7
	ns.L["Exalted"]       = FACTION_STANDING_LABEL8
	ns.L["Inn"]           = HOME_INN
	ns.L["Officer notes"] = OFFICER_NOTE_COLON:gsub(":",""):gsub("：",""):trim();
	ns.L["FPS"]           = FRAMERATE_LABEL:gsub(":",""):gsub("：",""):trim();
end

if not (LOCALE_enUS or LOCALE_enGB) then
	ns.L["Home"], ns.L["World"] = MAINMENUBAR_LATENCY_LABEL:match("%((.*)%).*%((.*)%)");
end

ns.L["ChatChannels"] = "Chat channels";
ns.L["ClassSpecs"] = "Class specs";
ns.L["FOLLOWERS_ABBREV"] = "F";
ns.L["SHIPS_ABBREV"] = "S";
ns.L["CHAMPIONS_ABBREV"] = "C";



ns.L["CoExistDisabled"] = "This option is disabled because:"
ns.L["CoExistOwn"]     = "Has it's own minimap icon."
ns.L["CoExistSimilar"] = "Has similar option to hide the minimap icon."
ns.L["CoExistUnsave"]  = "Produce error on try to hide the minimap icon."



-----------

-- artifactweapons.lua
ns.L.ArtifactMissingData = "There are some missing informations. Do you want to see all about this weapon it is necessary to temporary switch the spec.";
