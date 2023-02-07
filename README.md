# DSMS Portable Auto Mod Merger
## Creates .bat files for use with mountlover's DSMSPortable to make merging Elden Ring mods easier.

![2023-02-06 15_15_51-DSMSPortableGUI (DEBUG)](https://user-images.githubusercontent.com/106239192/217009886-5536fd5f-61e7-4c0e-a536-331a229c0735.jpg)

## Current supported filetypes
* .csv - See "CSV Notes" section for some important information!
* .massedit
* .tae
* (Tentatively) .fmg/.fmg.json/.fmg.xml
# Requirements
* mountlover's DSMSPortable - https://github.com/mountlover/DSMSPortable
* The .csv/.massedit/(eventually) .fmg(.json/.xml) source files for the mods you'd like to merge
# How to Use
1) Download DSMSPortable and extract it to a convenient folder.
2) Download AMM and extract it to a convenient folder.
3) Open AMM and set the program's required paths using the "Browse" function beside each textbox.
4) In the center of the window is the "Mod Folder Entries" (MFE) load order. Click "Browse", then navigate to and select the folder containing the source .csv/.massedit/etc. files of the first mod you'd like merged.
5) With the desired path visible in the MFE path text box, click "Add To Load Order". This will create a MFE load order entry that can be moved up and down, removed and temporarily disabled.
6) Repeat steps 4 and 5 for any subsequent mod folders you'd like added - note that the last mod in the load order will be merged last, so any major patches to existing CSVs should be as low down as possible!
7) If you'd like the resulting .bat to automatically replace the merged mod's regulation.bin with either a backup named "regulation - Copy.bin" or the "regulation.bin.prev" file that might have been produced previously (AMM will check for these in that order), check "Start Fresh".
8) If you'd like AMM to attempt to convert a .CSV file to a DSMS readable format if it's been exported from Yapped, check the next box. This will only fully work if the .CSV in question already has all of the param properties needed for the param type it's being merged into - see the "pad" issue under CSV Notes to learn about why this might not be the case.
# CSV Notes
* You may encounter a couple of possible errors when trying to import some mods' .csv files, both of which can have a number of causes, but I'd like to list a few possible causes here.
### CSV has the wrong number of values
* This is unfortunately a difficult one to fix. A typical cause is that the CSV is for an outdated version of the game before new param properties were introduced.
* A likely one if .csvs made for the latest version of the game do not work is that they were exported from Yapped, which excludes a few properties DSMS requires in order to import, typically the array-like "pad" values. Unfortunately, the best way of fixing this is to manually add these extra param properties to the mod's entries using a program capable of directly editing .csvs.
### Could not parse data types
* If DSMS returns this after fixing the above, there's a good chance that the headers in the CSV are formatted for Yapped, which uses "Row ID" and "Row Name" instead of "ID" and "Name". AMM can optionally attempt to convert these automatically, though manual fixing of the above may still be required.
