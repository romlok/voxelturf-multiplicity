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
			
			-- Helper functions
			
			local function lot_floor(ord)
				-- Return the given ordinate floored to the side of its lot
				return ord - (ord % LOT_SIZE);
			end
			
			local function get_perimeter_lots(radius, x, z)
				-- Returns coordinates of all lots a certain distance from a centre-point
				-- Based on a perfunctory glance at the Midpoint circle algorithm
				-- NB, these are probably not the exact lots at the edge of a city.
				
				local lots = {};
				local perimX = radius;
				local perimZ = 0;
				-- We only need to iterate a single octant of the perimeter
				while perimX >= perimZ do
					lots[#lots+1] = {
						x = lot_floor(x + perimX),
						z = lot_floor(z + perimZ),
					}
					lots[#lots+1] = {
						x = lot_floor(x - perimX),
						z = lot_floor(z + perimZ),
					}
					lots[#lots+1] = {
						x = lot_floor(x + perimX),
						z = lot_floor(z - perimZ),
					}
					lots[#lots+1] = {
						x = lot_floor(x - perimX),
						z = lot_floor(z - perimZ),
					}
					lots[#lots+1] = {
						x = lot_floor(x + perimZ),
						z = lot_floor(z + perimX),
					}
					lots[#lots+1] = {
						x = lot_floor(x - perimZ),
						z = lot_floor(z + perimX),
					}
					lots[#lots+1] = {
						x = lot_floor(x + perimZ),
						z = lot_floor(z - perimX),
					}
					lots[#lots+1] = {
						x = lot_floor(x - perimZ),
						z = lot_floor(z - perimX),
					}
					-- Move to the next lot along
					perimZ = perimZ + LOT_SIZE;
					if (perimX^2 + perimZ^2 > radius^2) then
						perimX = perimX - LOT_SIZE;
					end
				end
				
				return lots
			end
			
			
			-- Start the actual generation
			
			-- Work out an appropriate number of cities based on map size
			local biglyness = math.min(xMax - xMin, zMax - zMin);
			local num_cities = math.floor(biglyness / (2 * radius))
			maxPlayerBases = math.max(1, maxPlayerBases/num_cities)
			
			for i=1,num_cities do
				-- Random position and variable radius
				local cRadius = math.random(0.5 * radius, 1.5 * radius);
				local cX = math.random(xMin + cRadius, xMax - cRadius);
				local cZ = math.random(zMin + cRadius, zMax - cRadius);
				generate_city_old (W, LC, cRadius, cX, cZ, maxPlayerBases);
				
				Net:forceUpdateStartupStatusString ("Generating City - Merging borderlands");
				-- Skirt the perimeter, looking for erroneous tiles
				local borderlands = get_perimeter_lots(cRadius, cX, cZ);
				for i=1,#borderlands do
					-- TEST! We splat something obvious in the perimeter lots
					local lot = borderlands[i];
					
					LC:loadLot (lot.x, lot.z, yStart, "vacant/concrete", "n", turf.Lot.LOT_FILL_MODE_NORMAL);

					local L = LC:getLotAt (lot.x, lot.z);
					local oldType = L.vtype;
					L:clearData(LC);
					L.vtype = turf.Lot.LOT_VACANT;
					LC:markUpdate (lot.x, lot.z, oldType, L.vtype);
					
					-- TODO: Connect merged roads along city perimeter
					-- TODO: Clear lots carved up by city merge
				end
				
				Net:doKeepAlive();
			end
		end
	end
end

if (defineBlocksUserCallback == nil) then defineBlocksUserCallback = {}; end
defineBlocksUserCallback[#defineBlocksUserCallback + 1] = { "define_multiple_cities|Injection point for MultipliCity mod", define_multiple_cities } 
