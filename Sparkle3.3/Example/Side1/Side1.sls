Path:		"../Sparkle Demo Side 1.d64"
Header:		sparkle 3.3  omg
ID:		side1
Name:		sparkle 3.3 demo
Start:		1000
Tracks:		40
DirArt:		"DirArtSide1.png"
ProdID:		53d15c

<< bundle #0 - main code >>

File:		"Part1/Side1.prg"		<< Loads and saves hi-score file, loads SID and all parts on this, requests next side

<< bundle #1 - SID >>

File:		"../SID/OMG_ItsBurnin.sid"	<< SID by Jammer

<< bundle #2 - MC bitmap >>

File:		"Part2/Part2.map" 6000		<< File name in double quotes allows using space as parameter separator
File:		Part2/Part2.col		d800	<< No double quotes, parameters must be separated using tabs
File:		"Part2/Part2.scr" 4400

<< bundle #3 - hires bitmap >>

File:		"Part3/Part3.map" 6000
File:		"Part3/Part3.scr" 4400

<< saver plugin >>

PlgIndex:	7e				<< Plugin directory index, must be larger than the number for standard file bundles
Plugin:		saver				<< The saver plugin must preced the h-score file

<< hi-score file >>

PlgIndex:	7f				<< PlgIndex entries can be combined with DirIndex entries or bundle indices
HSFile:		"Hi-score.bin*" d000		<< This is the Hi-Score file that gets loaded to and saved from RAM under I/O
