# DSMS Portable Auto Mod Merger
## Creates .bat files for use with mountlover's DSMSPortable to make merging Elden Ring mods easier.

![2023-02-06 15_15_51-DSMSPortableGUI (DEBUG)](https://user-images.githubusercontent.com/106239192/217009886-5536fd5f-61e7-4c0e-a536-331a229c0735.jpg)

## Current supported filetypes
* .csv - See "CSV Notes" section for some important information!
* .massedit
# Requirements
* mountlover's DSMSPortable - https://github.com/mountlover/DSMSPortable
* The .csv/.massedit/(eventually) .fmg(.json/.xml) source files for the mods you'd like to merge
# CSV Notes
* You may encounter a couple of possible errors when trying to import some mods' .csv files, both of which can have a number of causes, but I'd like to list a few possible causes here.
### CSV has the wrong number of values
* This is unfortunately a difficult one to fix. A typical cause is that the CSV is for an outdated version of the game before new param properties were introduced.
* A likely one if .csvs made for the latest version of the game do not work is that they were exported from Yapped, which excludes a few properties DSMS requires in order to import, typically the Array-like "pad" values. Unfortunately, the best way of fixing this is to manually add these extra param properties to the mod's entries using a program capable of directly editing .csvs.
### Could not parse data types
* If DSMS returns this after fixing the above, there's a good chance that the headers in the CSV are formatted for Yapped, which uses "Row ID" and "Row Name" instead of "ID" and "Name". AMM can optionally attempt to convert these automatically, though manual fixing of the above may still be required.
