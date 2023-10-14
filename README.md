# BG3
Baldur's Gate 3 stuff

Currently in the misc_scripts directory are the following two classes of scripts/apps:
* getBg3PakMeta: This reads in a .pak file and spits out the information needed for the "ModuleShortDesc" of the modsettings.lsx file. Of possible iterest, it is parsing the .pak file and performing lz4 decompression, unencombered by any 3rd party libraries.
* makeNewBG3ModSettings: Reads in a number of mod .pak files, the game "Gustav" .pak file, and the existing modsettings.lsx file to generate a new modsettings.lsx file.

My work in those scripts (namely, the perl scripts that do the work) is provided by the "unlicense" license, which basically means you can freely do anything with it.
