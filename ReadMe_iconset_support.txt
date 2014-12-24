
Since v5.4.6 Broker_Everything supports custom Iconsets.
(working example on http://www.wowinterface.com/downloads/info22790-Broker_Everything-DemoIconset.html)

A little note about the icon files:
	Blizzard supports .tga and .blp for images.

	Important for both:
		The image size must be 16 or a multible of it. (example: 16x32 or 1024x64)

	.tga alias Targa File:
		Gimp and Photoshop and some other programs can save images in this image format. Compression (RLE) supported by blizzard. Important for this format are the color table.
		- 16 bit colors aren't supported by blizzard.
		- 24 bit colors usable without alpha channel.
		- 32 bit colors usable and support alpha channel.

	.blp are blizzard's own image format:
		Some programs can convert blp to png (Portable Network Graphic) and otherwise.
		(please use your preferred search engine)

	I recommend .tga with compression. it creates the lowest file size from all formats.

greetings
Hizuro

--------------------

Info [2014-06-11]:
	i've wrote a php script to collect the icon names from the modules.
	i would try to run it any time i add new or remove icons.
	the script creates the file example_iconset.lua.
