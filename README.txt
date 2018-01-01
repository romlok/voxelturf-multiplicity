MultipliCity
============

MultipliCity alters map generation so that multiple cities are created randomly across the map, possibly overlapping. This makes the map more urban, but with a hopefully more interesting distribution than merely enlarging a single centralised city, as the example Bigger Cities mod does.

The mod attempts to cleanly merge cities which overlap, but can result in some "interesting" road layouts at the seams.

https://github.com/romlok/voxelturf-multiplicity


[h1]Tweaks[/h1]

You can customise the density and size of the cities generated, using the three values at the start of the MultipliCity script:
[code]
SteamApps/workshop/content/404530/1196104761/scripts/multiplicity.lua

-- Customisation options
local CITIES_PER_KM2 = 0.5
local MIN_RADIUS_MULTIPLIER = 0.7
local MAX_RADIUS_MULTIPLIER = 1.3
[/code]


[h1]Known Bugs[/h1]

Global spawn points, commerce, and offices get placed toward the map centre, rather than the city centres. This is a bug/quirk of the original city generation code.

If you wish to correct this, open the Voxel Turf file scripts/server/map_generation/city_generation.lua, go to line 587, and replace the sortDistFunc function with:
[code]
local function sortDistFunc (a, b)
	return len2 (a.x - startX, a.z - startZ) < len2 (b.x - startX, b.z - startZ);
end	
[/code]
