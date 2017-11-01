-- Overrides calls to generate_city with multiple calls to generate_city!

function define_multiple_cities ()
	if (generate_city_old == nil) then -- Prevents double-defines
		generate_city_old = generate_city; -- backup existing generate_city
		
		generate_city = function (W, LC, radius, startX, startZ, maxPlayerBases) -- define a wrapper
			local xMin = LC:getXMin();
			local xMax = LC:getXMax();
			local zMin = LC:getZMin();
			local zMax = LC:getZMax();
			
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
			end
		end
	end
end

if (defineBlocksUserCallback == nil) then defineBlocksUserCallback = {}; end
defineBlocksUserCallback[#defineBlocksUserCallback + 1] = { "define_multiple_cities|Injection point for MultipliCity mod", define_multiple_cities } 
