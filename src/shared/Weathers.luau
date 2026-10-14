--!strict
-- Server-wide weather events. Each one boosts the whole server and can add a
-- matching mutation to ripe slimes, which rewards players for being online
-- (and harvesting at the right moment) without punishing anyone.

export type Weather = {
	id: string,
	name: string,
	icon: string,
	description: string,
	weight: number, -- relative chance when a natural event is picked
	growthMultiplier: number,
	tint: Color3,
}

local Weathers = {}

local list: { Weather } = {
	{
		id = "goorain",
		name = "Goo Rain",
		icon = "🌧️",
		description = "Slimes grow 1.5x faster and may become Drenched (x2).",
		weight = 40,
		growthMultiplier = 1.5,
		tint = Color3.fromRGB(180, 255, 200),
	},
	{
		id = "goldenhour",
		name = "Golden Hour",
		icon = "🌅",
		description = "Ripe slimes may become Sunkissed (x2.5).",
		weight = 30,
		growthMultiplier = 1,
		tint = Color3.fromRGB(255, 210, 150),
	},
	{
		id = "snowfall",
		name = "Snowfall",
		icon = "❄️",
		description = "Ripe slimes may become Frozen (x3).",
		weight = 22,
		growthMultiplier = 1,
		tint = Color3.fromRGB(200, 225, 255),
	},
	{
		id = "starfall",
		name = "Starfall",
		icon = "🌠",
		description = "Ripe slimes may become Starstruck (x8)!",
		weight = 8,
		growthMultiplier = 1,
		tint = Color3.fromRGB(200, 170, 255),
	},
}

local byId: { [string]: Weather } = {}
local totalWeight = 0
for _, weather in list do
	byId[weather.id] = weather
	totalWeight += weather.weight
end

Weathers.list = list
Weathers.byId = byId
Weathers.totalWeight = totalWeight

function Weathers.get(id: string?): Weather?
	if id == nil then
		return nil
	end
	return byId[id]
end

-- Picks a weather id from a uniform number in [0, 1).
function Weathers.pick(roll: number): string
	local target = roll * totalWeight
	local acc = 0
	for _, weather in list do
		acc += weather.weight
		if target < acc then
			return weather.id
		end
	end
	return list[#list].id
end

return Weathers
