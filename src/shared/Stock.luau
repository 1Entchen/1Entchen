--!strict
-- Seed shop restock roll. Every restock rolls each species independently
-- against its published stock chance; quantities are per player, so nobody
-- can buy out the shop on someone else.

local Species = require(script.Parent.Species)

local Stock = {}

function Stock.roll(rng: () -> number): { [string]: number }
	local stock: { [string]: number } = {}
	for _, species in Species.shopOrder do
		if rng() < species.stockChance then
			local span = species.stockMax - species.stockMin
			stock[species.id] = species.stockMin + math.floor(rng() * (span + 1))
		end
	end
	return stock
end

return Stock
