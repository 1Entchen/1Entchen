--!strict
-- Slime species catalog. Value/price ratio sits around 2.4x per harvest and
-- profit per tile-second grows roughly 2.5x per tier, so every new seed is a
-- clear upgrade while stock scarcity keeps high tiers aspirational.

local Types = require(script.Parent.Types)

type Species = Types.Species

local Species = {}

local list: { Species } = {
	{
		id = "goo",
		name = "Goo Slime",
		tier = 1,
		rarity = "Common",
		price = 10,
		growTime = 12,
		value = 24,
		color = Color3.fromRGB(110, 222, 96),
		accent = Color3.fromRGB(60, 160, 60),
		material = Enum.Material.SmoothPlastic,
		transparency = 0.12,
		stockChance = 1,
		stockMin = 10,
		stockMax = 20,
		requiresRebirth = 0,
		flavor = "The friendliest blob in the garden.",
	},
	{
		id = "bubble",
		name = "Bubble Slime",
		tier = 2,
		rarity = "Common",
		price = 60,
		growTime = 30,
		value = 150,
		color = Color3.fromRGB(96, 178, 255),
		accent = Color3.fromRGB(200, 235, 255),
		material = Enum.Material.Glass,
		transparency = 0.2,
		stockChance = 1,
		stockMin = 6,
		stockMax = 12,
		requiresRebirth = 0,
		flavor = "Pops with joy when it is harvested.",
	},
	{
		id = "berry",
		name = "Berry Slime",
		tier = 3,
		rarity = "Uncommon",
		price = 300,
		growTime = 60,
		value = 720,
		color = Color3.fromRGB(255, 110, 170),
		accent = Color3.fromRGB(90, 190, 80),
		material = Enum.Material.SmoothPlastic,
		transparency = 0.1,
		stockChance = 0.85,
		stockMin = 4,
		stockMax = 8,
		requiresRebirth = 0,
		flavor = "Smells like strawberry jam.",
	},
	{
		id = "ember",
		name = "Ember Slime",
		tier = 4,
		rarity = "Uncommon",
		price = 1_500,
		growTime = 120,
		value = 3_600,
		color = Color3.fromRGB(255, 136, 46),
		accent = Color3.fromRGB(255, 220, 90),
		material = Enum.Material.SmoothPlastic,
		transparency = 0.05,
		stockChance = 0.65,
		stockMin = 3,
		stockMax = 6,
		requiresRebirth = 0,
		flavor = "Warm to the touch. Do not hug.",
	},
	{
		id = "frost",
		name = "Frost Slime",
		tier = 5,
		rarity = "Rare",
		price = 7_500,
		growTime = 240,
		value = 18_000,
		color = Color3.fromRGB(170, 235, 255),
		accent = Color3.fromRGB(255, 255, 255),
		material = Enum.Material.Ice,
		transparency = 0.15,
		stockChance = 0.45,
		stockMin = 2,
		stockMax = 4,
		requiresRebirth = 0,
		flavor = "Keeps your garden nice and chilly.",
	},
	{
		id = "toxic",
		name = "Toxic Slime",
		tier = 6,
		rarity = "Rare",
		price = 38_000,
		growTime = 480,
		value = 92_000,
		color = Color3.fromRGB(170, 255, 40),
		accent = Color3.fromRGB(120, 60, 200),
		material = Enum.Material.Neon,
		transparency = 0.25,
		stockChance = 0.3,
		stockMin = 1,
		stockMax = 3,
		requiresRebirth = 0,
		flavor = "Glows in the dark. Probably fine.",
	},
	{
		id = "crystal",
		name = "Crystal Slime",
		tier = 7,
		rarity = "Epic",
		price = 190_000,
		growTime = 900,
		value = 460_000,
		color = Color3.fromRGB(190, 120, 255),
		accent = Color3.fromRGB(240, 210, 255),
		material = Enum.Material.Glass,
		transparency = 0.3,
		stockChance = 0.18,
		stockMin = 1,
		stockMax = 2,
		requiresRebirth = 0,
		flavor = "Grows gemstones on its head.",
	},
	{
		id = "shadow",
		name = "Shadow Slime",
		tier = 8,
		rarity = "Epic",
		price = 950_000,
		growTime = 1_800,
		value = 2_300_000,
		color = Color3.fromRGB(52, 36, 78),
		accent = Color3.fromRGB(190, 80, 255),
		material = Enum.Material.SmoothPlastic,
		transparency = 0.05,
		stockChance = 0.1,
		stockMin = 1,
		stockMax = 2,
		requiresRebirth = 0,
		flavor = "Only its eyes can be seen at night.",
	},
	{
		id = "king",
		name = "King Slime",
		tier = 9,
		rarity = "Legendary",
		price = 4_800_000,
		growTime = 3_600,
		value = 12_000_000,
		color = Color3.fromRGB(255, 204, 51),
		accent = Color3.fromRGB(255, 240, 160),
		material = Enum.Material.Foil,
		transparency = 0,
		stockChance = 0.04,
		stockMin = 1,
		stockMax = 1,
		requiresRebirth = 0,
		flavor = "Rules the garden. Demands snacks.",
	},
	{
		id = "cosmic",
		name = "Cosmic Slime",
		tier = 10,
		rarity = "Mythic",
		price = 24_000_000,
		growTime = 7_200,
		value = 65_000_000,
		color = Color3.fromRGB(40, 30, 120),
		accent = Color3.fromRGB(120, 220, 255),
		material = Enum.Material.Neon,
		transparency = 0.1,
		stockChance = 0.015,
		stockMin = 1,
		stockMax = 1,
		requiresRebirth = 1,
		flavor = "Fell from a galaxy far away.",
	},
	{
		id = "prism",
		name = "Prism Slime",
		tier = 0,
		rarity = "Exclusive",
		price = 0,
		growTime = 300,
		value = 0, -- dynamic: see Economy.prismBaseValue
		color = Color3.fromRGB(255, 255, 255),
		accent = Color3.fromRGB(255, 120, 220),
		material = Enum.Material.Glass,
		transparency = 0.15,
		stockChance = 0,
		stockMin = 0,
		stockMax = 0,
		requiresRebirth = 0,
		flavor = "Shimmers in every colour. Always worth 8x your best slime.",
	},
}

local byId: { [string]: Species } = {}
local byTier: { [number]: Species } = {}
local shopOrder: { Species } = {}

for _, species in list do
	byId[species.id] = species
	if species.tier > 0 then
		byTier[species.tier] = species
		table.insert(shopOrder, species)
	end
end
table.sort(shopOrder, function(a, b)
	return a.tier < b.tier
end)

Species.list = list
Species.byId = byId
Species.byTier = byTier
Species.shopOrder = shopOrder
Species.MaxTier = #shopOrder

Species.RarityColors = {
	Common = Color3.fromRGB(200, 205, 215),
	Uncommon = Color3.fromRGB(110, 225, 110),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 200, 50),
	Mythic = Color3.fromRGB(255, 80, 120),
	Exclusive = Color3.fromRGB(255, 120, 220),
} :: { [string]: Color3 }

function Species.get(id: string): Species?
	return byId[id]
end

function Species.isValidId(id: unknown): boolean
	return typeof(id) == "string" and byId[id] ~= nil
end

return Species
