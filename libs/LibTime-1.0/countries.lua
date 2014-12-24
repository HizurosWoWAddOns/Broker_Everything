
local lib = LibStub("LibTime-1.0")

if not lib.countries then
	lib.countries = {
		-- Name, Direction&Length, DST
		{"Afghanistan", 4.5,0},{"Alaska",-9,1},{"Arabian", 3,0},{"Argentina",-3,0},{"Armenia", 4,1},{"Australian Central", 9.5,1},{"Australian Eastern",10,1},{"Australian Western", 8,0},{"Azerbaijan", 4,1},
		{"Azores",-1,1},{"Bangladesh", 6,0},{"Bhutan", 6,0},{"Bolivia",-4,0},{"Brazil",-3,0},{"Brunei", 8,0},{"Cape Verde",-1,0},{"Central Africa", 2,0},{"Central Brazilian",-4,1},{"Central European", 1,1},
		{"Central Greenland",-3,1},{"Central Indonesian", 8,0},{"Central Standart Time (CST)",-6,1},{"Chamorro",10,0},{"Chile",-4,1},{"China",8,0},{"Christmas Island",7,0},{"Chuuk",10,0},
		{"Cocos Islands",6.5,0},{"Colombia",-5,0},{"Cook Islands",-10,0},{"East Africa",3,0},{"East Greenland",-1,1},{"East Timor",9,0},{"Eastern European",2,1},{"Eastern Indonesian",9,0},
		{"Eastern Kazakhstan",6,0},{"Eastern",-5,1},{"Ecuador",-5,0},{"Falkland Island",-4,0},{"Fernando de Noronha",-2,0},{"Fiji",12,1},{"French Guiana",-3,0},{"Galapagos",-6,0},{"Georgia",4,0},
		{"Gilbert Island",12,0},{"Greenwich Mean",0,1},{"Gulf",4,0},{"Guyana",-4,0},{"Hawaii",-10,1},{"Hovd",7,0},{"Indian",5.5,0},{"Indochina",7,0},{"Iran",3.5,1},{"Irkutsk",9,0},{"Israel",2,1},{"Japan",9,0},
		{"Kaliningrad",3,0},{"Korea",9,0},{"Krasnoyarsk",8,0},{"Kyrgyzstan",5,0},{"Magadan",12,0},{"Malaysia",8,0},{"Maldives",5,0},{"Marshall Islands",12,0},{"Mauritius",4,0},{"Moscow",4,0},{"Mountain",-7,1},
		{"Myanmar",6.5,0},{"Nauru",12,0},{"Nepal",5.75,0},{"New Caledonia",11,0},{"New Zealand",12,1},{"Newfoundland",-3.5,1},{"Niue",-11,0},{"Norfolk",11.5,0},{"Omsk",7,0},{"Pacific",-8,1},{"Pakistan",5,0},
		{"Palau",9,0},{"Papua New Guinea",10,0},{"Paraguay",-4,1},{"Peru",-5,0},{"Philippine",8,0},{"Pierre &amp; Miquelon",-3,1},{"Ponape",11,0},{"Reunion",4,0},{"Seychelles",4,0},{"Singapore",8,0},
		{"Solomon Islands",11,0},{"South Africa",2,0},{"Sri Lanka",5.5,0},{"Suriname",-3,0},{"Tahiti",-10,0},{"Tajikistan",5,0},{"Tokelau",13,0},{"Tonga",13,0},{"Turkmenistan",5,0},{"Tuvalu",12,0},
		{"Ulaanbaatar",8,},{"Uruguay",-3,1},{"Uzbekistan",5,0},{"Vanuatu",11,0},{"Venezuela",-4.5,0},{"Vladivostok",11,0},{"Wallis &amp; Futuna",12,0},{"West Africa",1,1},{"West Samoa",13,1},
		{"Western European",0,1},{"Western Indonesian",7,0},{"Western Kazakhstan",5,0},{"Yakutsk",10,0},{"Yap",10,0},{"Yekaterinburg",6,0}
	}

	lib.countriesBy = {name={},timeshift={}}
	for i,v in ipairs(lib.countries) do
		lib.countriesBy.name[v[1]] = i
		if lib.countriesBy.timeshift[v[2]]==nil then lib.countriesBy.timeshift[v[2]]={} end
		tinsert(lib.countriesBy.timeshift[v[2]],i)
	end
end