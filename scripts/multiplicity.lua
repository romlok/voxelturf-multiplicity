-- Overrides calls to generate_city with multiple calls to generate_city!

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
			
			
			-- Start the actual generation
			
			-- Work out an appropriate number of cities based on map size
			local biglyness = math.min(xMax - xMin, zMax - zMin);
			local num_cities = math.floor(biglyness / (2 * radius))
			maxPlayerBases = math.max(1, maxPlayerBases/num_cities)
			local perimeters = {}
			
			for i=1,num_cities do
				-- Random position and variable radius
				local cRadius = math.random(0.5 * radius, 1.5 * radius);
				local cX = math.random(xMin + cRadius, xMax - cRadius);
				local cZ = math.random(zMin + cRadius, zMax - cRadius);
				perimeters[#perimeters+1] = get_city_limits(cRadius, cX, cZ);
				
				generate_city_old (W, LC, cRadius, cX, cZ, maxPlayerBases);
				
			end
			
			Net:forceUpdateStartupStatusString ("Generating City - Merging overlaps");
			-- Check all possible city lots for overlap artifacts
			local checked = {}
			for idx, perim in pairs(perimeters) do
				for x=perim.xMin,perim.xMax do
					for z=perim.zMin,perim.zMax do
						-- TODO: Skip if we've already check this lot
						-- TODO: Link this road to neighbouring ones
						-- TODO: Wipe out this lot (and appropriate neighbours) if it's been cut up, or not connected to a road
					end
					Net:doKeepAlive();
				end
			end
			
		end
	end
end

if (defineBlocksUserCallback == nil) then defineBlocksUserCallback = {}; end
defineBlocksUserCallback[#defineBlocksUserCallback + 1] = { "define_multiple_cities|Injection point for MultipliCity mod", define_multiple_cities } 
