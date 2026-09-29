Path:		"../Sparkle Demo Side 2.d64"
Header:		sparkle 3.3  omg
ID:		side2
Name:		sparkle 3.3 demo
Start:		1000
DirArt:		"DirArtSide2.png"

<< bundle #0 - main code
File:		"Part4/Side2.prg"		<< Loads SID and all parts on this side

<< bundle #1 - SID
File:		"../SID/OMG_ItsBurnin.sid"

<< bundle #2 - text part
DirIndex:	01				<< Presence of DirIndex means only bundles with a DirIndex..
File:		"Part5/Part5.bin" 04a0		<< ...can be accessed by index-based loading

<< bundle #3 - hires bitmap part		<< This bundle can only be accessed by sequential loading
File:		"Part6/Part6.map" 6000		<< File name in double quotes allows using space as parameter separator
File:		Part6/Part6.scr		4400	<< No double quotes, parameters must be separated using tabs
