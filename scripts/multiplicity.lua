-- Overrides calls to generate_city with multiple calls to generate_city!

-- Customisation options
local CITIES_PER_KM2 = 0.5
local MIN_RADIUS_MULTIPLIER = 0.7
local MAX_RADIUS_MULTIPLIER = 1.3


function define_multiple_cities ()
	if (generate_city_old == nil) then -- Prevents double-defines
		generate_city_old = generate_city; -- backup existing generate_city
		
		generate_city = function (W, LC, radius, startX, startZ, maxPlayerBases) -- define a wrapper
			local Net = turf.NetworkHandler.getInstance ();
			local xMin = LC:getXMin();
			local xMax = LC:getXMax();
			local zMin = LC:getZMin();
			local zMax = LC:getZMax();
			local yStart = 10;
			
			local LOT_SIZE = turf.Lot.LOT_SIZE;
			local TILE_SIZE = 5;
			
			-- Helper functions
			
			local function lot_floor(ord)
				-- Return the given ordinate floored to the side of its lot
				return ord - (ord % LOT_SIZE);
			end
			
			local function place_marker(x, z)
				-- Splat something obvious at the given lot location
				x = lot_floor(x)
				z = lot_floor(z)
				
				LC:loadLot (x, z, yStart, "vacant/concrete", "n", turf.Lot.LOT_FILL_MODE_NORMAL);

				local L = LC:getLotAt (x, z);
				local oldType = L.vtype;
				L:clearData(LC);
				L.vtype = turf.Lot.LOT_VACANT;
				LC:markUpdate (x, z, oldType, L.vtype);
			end
			
			local function get_city_limits(radius, cx, cz)
				-- Return a table of a city's outer limit coordinates
				-- City auto-gen uses 5x5 lot tiles, so the limits can extend outside the radius by up to 4 lots in the +ord directions.
				return {
					xMin = cx - radius,
					xMax = cx + radius + TILE_SIZE - 1,
					zMin = cz - radius,
					zMax = cz + radius + TILE_SIZE - 1,
				}
			end
			
			local function lot_in_region(lot, perim)
				-- Return if the given lot is within the perim
				if lot.x < perim.xMin or lot.x > perim.xMax then
					return false
				end
				if lot.z < perim.zMin or lot.z > perim.zMax then
					return false
				end
				return true
			end
			
			local function get_next_lot(coords, perim, excludes)
				-- Return coords for the next lot within the given perim, excluding any that are within the excludes
				local newCoords
				local x = lot_floor(coords.x)
				local z = lot_floor(coords.z)
				repeat
					x = x + LOT_SIZE
					if x > perim.xMax then
						-- Move to the next z-line
						x = perim.xMin
						z = z + LOT_SIZE
					end
					if z > perim.zMax then
						-- End of the line, none left to process
						return nil
					end
					newCoords = {x=x, z=z}
					
					-- Move the new coords to the far side of any excludes
					for idx, exc in pairs(excludes or {}) do
						if lot_in_region(newCoords, exc) then
							newCoords.x = exc.xMax + LOT_SIZE
							-- x will be incremented on the next while
							x = exc.xMax
						end
					end
					
				until lot_in_region(newCoords, perim)
				
				return newCoords
			end
			
			local function get_perimeter_lots(radius, cx, cz)
				-- Returns coordinates of all lots along a city's perimeter
				
				local lots = {};
				local limits = get_city_limits(radius, cx, cz)
				
				for i=limits.xMin,limits.xMax do
					lots[#lots+1] = {x=i, z=limits.zMin}
					lots[#lots+1] = {x=i, z=limits.zMax}
				end
				for j=limits.zMin+1, limits.zMax-1 do
					lots[#lots+1] = {x=limits.xMin, z=j}
					lots[#lots+1] = {x=limits.xMax, z=j}
				end
				
				return lots
			end
			
			local function get_adjacent_lots(lx, lz)
				-- Returns a table of Lot objects adjacent to the given coords
				-- Return value be all like {n= ,e=, s=, w=} up in your face
				return {
					n = LC:getLotAt(lx+LOT_SIZE, lz),
					s = LC:getLotAt(lx-LOT_SIZE, lz),
					e = LC:getLotAt(lx, lz+LOT_SIZE),
					w = LC:getLotAt(lx, lz-LOT_SIZE),
				}
			end
			
			local function get_road_directions(lot)
				-- Return the "out" directions of the given road lot
				-- Return value will be {n=bool, s=bool, e=bool, w=bool}
				if lot.vtype ~= turf.Lot.LOT_ROAD and lot.vtype ~= turf.Lot.LOT_HIGHWAY then
					return {n=false, s=false, e=false, w=false}
				end
				local roadData = turf.LotRoadData.upcast(lot.lotData)
				return {
					n = roadData:n(),
					s = roadData:s(),
					e = roadData:e(),
					w = roadData:w(),
				}
			end
			
			local function get_roadpiece(dirs)
				-- Return the roadpeice for the given directions
				local roadpiece = "j"
				if dirs.n then
					roadpiece = roadpiece.."n"
				end
				if dirs.s then
					roadpiece = roadpiece.."s"
				end
				if dirs.e then
					roadpiece = roadpiece.."e"
				end
				if dirs.w then
					roadpiece = roadpiece.."w"
				end
				if #roadpiece > 4 then
					return "cross"
				end
				if #roadpiece < 4 then
					-- This one likely had a neighbour overwritten
					-- so should wait for its neighbour to be fixed
					return nil
				end
				return roadpiece
			end
			
			local function replace_road(lx, lz, dirs)
				-- Replace an existing road lot with a similar one in different directions
				local roadpiece = get_roadpiece(dirs)
				if roadpiece == nil then
					return
				end
				
				LC:loadLot (lx, lz, yStart, "road/rfl/"..roadpiece, 'n', turf.Lot.LOT_FILL_MODE_NORMAL);
				local L = LC:getLotAt (lx, lz);
				local oldType = L.vtype;
				L:clearData(LC);
				
				local LRD = turf.LotRoadData.genNew ();
				LRD:set(dirs.n, dirs.s, dirs.e, dirs.w);
				
				L.vtype = turf.Lot.LOT_ROAD;
				L.lotData = LRD;
				
				LC:markUpdate (lx, lz, oldType, L.vtype);
				LC:insureLot (0, turf.LotCoordinate(lx, lz), true, true);
				
			end
			
			local function make_vacant(lx, lz)
				-- Make sure the given lot location is vacant
				local dirs = { 'n','s','e','w' };
				local vacantLots = { "v1", "v2", "v3", "v4", "v5", "v6", "v7" }
				
				-- The type of vacancy depends on its surroundings
				local isBarren = true
				local isRoundabout = true
				for idx, lot in pairs(get_adjacent_lots(lx, lz)) do
					if lot.vtype ~= turf.Lot.LOT_ROAD then
						isRoundabout = false
					end
					if lot.vtype ~= turf.Lot.LOT_VACANT
							and lot.vtype ~= turf.Lot.LOT_HILLS
							and lot.vtype ~= turf.Lot.LOT_SEA
							then
						isBarren = false
					end
				end
				
				local vacancyType
				if isRoundabout then
					vacancyType = "misc/roundabout"
				elseif isBarren then
					-- Barren lots are (hopefully) outside any city
					vacancyType = nil
				else
					vacancyType =  "vacant/"..vacantLots[math.random(1,#vacantLots)]
				end
				
				if not vacancyType then
					-- We don't want to change this lot
					return
				end
				
				LC:loadLot (lx, lz, yStart, vacancyType, dirs[math.random(1,#dirs)], turf.Lot.LOT_FILL_MODE_NORMAL);
				
				local L = LC:getLotAt (lx, lz);
				local oldType = L.vtype;
				L:clearData(LC);
				L.vtype = turf.Lot.LOT_VACANT;
				LC:markUpdate (lx, lz, oldType, L.vtype);
				
			end
			
			
			-- Start the actual generation
			
			-- Work out an appropriate number of cities based on map size
			local mapArea = (xMax - xMin) * (zMax - zMin)
			local num_cities = (mapArea / 1000000) * CITIES_PER_KM2
			num_cities = math.max(1, math.floor(num_cities))
			maxPlayerBases = math.max(1, maxPlayerBases/num_cities)
			local perimeters = {}
			
			for i=1,num_cities do
				-- Random position and variable radius
				local cRadius = math.random(
					MIN_RADIUS_MULTIPLIER * radius,
					MAX_RADIUS_MULTIPLIER * radius
				);
				local cX = math.random(xMin + cRadius, xMax - cRadius);
				local cZ = math.random(zMin + cRadius, zMax - cRadius);
				perimeters[#perimeters+1] = get_city_limits(cRadius, cX, cZ);
				
				generate_city_old (W, LC, cRadius, cX, cZ, maxPlayerBases);
				
			end
			
			Net:forceUpdateStartupStatusString ("Generating City - Merging overlap");
			-- Check all possible city lots for overlap artifacts
			local checked = {}
			for idx, perim in pairs(perimeters) do
				local coords = {x = perim.xMin, z = perim.zMin}
				
				repeat
					local lot = LC:getLotAt(coords.x, coords.z)
					if lot.vtype == turf.Lot.LOT_ROAD then
						-- Link road to neighbouring ones
						local dirs = get_road_directions(lot)
						local newDirs = {}
						local neighbours = get_adjacent_lots(coords.x, coords.z)
						newDirs.n = get_road_directions(neighbours.n).s
						newDirs.s = get_road_directions(neighbours.s).n
						newDirs.e = get_road_directions(neighbours.e).w
						newDirs.w = get_road_directions(neighbours.w).e
						if dirs.n ~= newDirs.n or dirs.s ~= newDirs.s or dirs.e ~= newDirs.e or dirs.w ~= newDirs.w then
							replace_road(coords.x, coords.z, newDirs);
						end
						
					elseif lot.vtype == turf.Lot.LOT_VACANT then
						-- Parts of dissected buildings are marked vacant,
						-- but the blocks are not cleared
						make_vacant(coords.x, coords.z)
						
					else
						-- Skip if this isn't the primary lot of the building
						local mainCoords = LC:getLotCoordinateByAddr(lot);
						if mainCoords.x ~= coords.x or mainCoords.z ~= coords.z then
							goto nextLotPlease
						end
						
						--TODO: Delete if it's no longer facing a road. Rare, but could happen.
						
						-- Wipe out this lot if it's been cut up
						local lotpackItem = lot:wrangleLotPackData()
						if not lotpackItem then
							goto nextLotPlease
						end
						if not lotpackItem:isFootprintKnown() then
							goto nextLotPlease
						end
						if lotpackItem.footprintXsz < 2 and lotpackItem.footprintZsz < 2 then
							goto nextLotPlease
						end
						-- Truncated lots sit all alone, so we can ignore any lot which is the same building in adjacent lots
						if LC:isInSameLot(coords.x+LOT_SIZE, coords.z, coords.x, coords.z) then
							goto nextLotPlease
						end
						if LC:isInSameLot(coords.x, coords.z+LOT_SIZE, coords.x, coords.z) then
							goto nextLotPlease
						end
						if LC:isInSameLot(coords.x-LOT_SIZE, coords.z, coords.x, coords.z) then
							goto nextLotPlease
						end
						if LC:isInSameLot(coords.x, coords.z-LOT_SIZE, coords.x, coords.z) then
							goto nextLotPlease
						end
						
						-- No checks left to do, must be a bad 'un
						make_vacant(coords.x, coords.z)
						
					end
					
					::nextLotPlease::
					coords = get_next_lot(coords, perim, checked)
					Net:doKeepAlive();
				until coords == nil;
				checked[#checked+1] = perim;
			end
		end
	end
end

if (defineBlocksUserCallback == nil) then defineBlocksUserCallback = {}; end
defineBlocksUserCallback[#defineBlocksUserCallback + 1] = { "define_multiple_cities|Injection point for MultipliCity mod", define_multiple_cities } 
