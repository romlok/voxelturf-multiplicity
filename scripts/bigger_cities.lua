-- Works by overriding calls to generate_city (.., radius, ..) with generate_city (.., radius*2, .. )

function define_bigger_cities ()
	if (generate_city_old == nil) then -- Prevents double-defines
		generate_city_old = generate_city; -- backup existing generate_city
		
		generate_city = function (W, LC, radius, startX, startZ, maxPlayerBases) -- define a wrapper
			return generate_city_old (W, LC, radius*2, startX, startZ, maxPlayerBases); --generate a city with twice the radius
		end
	end
end

if (defineBlocksUserCallback == nil) then defineBlocksUserCallback = {}; end
defineBlocksUserCallback[#defineBlocksUserCallback + 1] = { "define_bigger_cities|Injection point for define_bigger_cities mod", define_bigger_cities } 
