--!strict
-- Mutations multiply a slime's value. A slime can carry at most one variant
-- (rolled once when it ripens) plus one of each weather mutation (rolled
-- while it sits ripe in the garden during matching weather). All odds are
-- shown to players in the Slimepedia.

local Types = require(script.Parent.Types)

type Mutation = Types.Mutation

local Mutations = {}

local list: { Mutation } = {
	{
		id = "shiny",
		name = "Shiny",
		kind = "variant",
		multiplier = 2,
		color = Color3.fromRGB(255, 255, 210),
		chance = 0.05,
		order = 1,
	},
	{
		id = "golden",
		name = "Golden",
		kind = "variant",
		multiplier = 6,
		color = Color3.fromRGB(255, 205, 50),
		chance = 0.012,
		order = 2,
	},
	{
		id = "rainbow",
		name = "Rainbow",
		kind = "variant",
		multiplier = 15,
		color = Color3.fromRGB(255, 120, 220),
		chance = 0.0025,
		order = 3,
	},
	{
		id = "drenched",
		name = "Drenched",
		kind = "weather",
		multiplier = 2,
		color = Color3.fromRGB(90, 210, 255),
		chance = 0.25,
		weather = "goorain",
		order = 4,
	},
	{
		id = "sunkissed",
		name = "Sunkissed",
		kind = "weather",
		multiplier = 2.5,
		color = Color3.fromRGB(255, 170, 60),
		chance = 0.2,
		weather = "goldenhour",
		order = 5,
	},
	{
		id = "frozen",
		name = "Frozen",
		kind = "weather",
		multiplier = 3,
		color = Color3.fromRGB(180, 230, 255),
		chance = 0.2,
		weather = "snowfall",
		order = 6,
	},
	{
		id = "starstruck",
		name = "Starstruck",
		kind = "weather",
		multiplier = 8,
		color = Color3.fromRGB(200, 160, 255),
		chance = 0.12,
		weather = "starfall",
		order = 7,
	},
}

local byId: { [string]: Mutation } = {}
local variants: { Mutation } = {}
local byWeather: { [string]: Mutation } = {}

for _, mutation in list do
	byId[mutation.id] = mutation
	if mutation.kind == "variant" then
		table.insert(variants, mutation)
	elseif mutation.weather then
		byWeather[mutation.weather] = mutation
	end
end

-- Rarest first so a single roll picks the most valuable variant it hits.
table.sort(variants, function(a, b)
	return a.chance < b.chance
end)

Mutations.list = list
Mutations.byId = byId
Mutations.variants = variants
Mutations.byWeather = byWeather

function Mutations.get(id: string): Mutation?
	return byId[id]
end

return Mutations
