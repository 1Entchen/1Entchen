--!strict
-- Robux catalog. Create each pass / developer product in the Creator
-- Dashboard, set its price there, and paste the id into `id`. `price` is the
-- intended Robux price; the client always displays the live price fetched
-- from MarketplaceService when an id is set, so players never see a price
-- that differs from the purchase prompt.
--
-- While an id is 0 the item cannot be bought in live servers. In Studio the
-- store grants it directly so the full flow can be tested before publishing.

export type Category = "Passes" | "Boosts" | "Coins" | "Events"

export type Product = {
	key: string,
	kind: "pass" | "product",
	id: number,
	price: number,
	name: string,
	icon: string,
	description: string,
	category: Category,
	order: number,
	highlight: string?,
}

local Products = {}

local list: { Product } = {
	-- Game passes: permanent benefits.
	{
		key = "starter_pack",
		kind = "pass",
		id = 0,
		price = 49,
		name = "Starter Pack",
		icon = "🎁",
		description = "One-time bundle: 3 Ember + 2 Frost seeds, 2,500 coins, a Growth and a Luck Potion.",
		category = "Passes",
		order = 1,
		highlight = "BEST VALUE",
	},
	{
		key = "big_garden",
		kind = "pass",
		id = 0,
		price = 149,
		name = "Big Garden",
		icon = "🌱",
		description = "+6 extra garden tiles (a whole new row) forever.",
		category = "Passes",
		order = 2,
	},
	{
		key = "sell_anywhere",
		kind = "pass",
		id = 0,
		price = 149,
		name = "Sell Anywhere",
		icon = "💰",
		description = "Sell your slimes from anywhere with one tap.",
		category = "Passes",
		order = 3,
	},
	{
		key = "vip",
		kind = "pass",
		id = 0,
		price = 199,
		name = "VIP",
		icon = "👑",
		description = "+15% coins, +50 backpack space and a golden VIP tag in chat.",
		category = "Passes",
		order = 4,
	},
	{
		key = "lucky",
		kind = "pass",
		id = 0,
		price = 249,
		name = "Lucky Gardener",
		icon = "🍀",
		description = "Doubles every mutation chance, forever. Odds are listed in the Slimepedia.",
		category = "Passes",
		order = 5,
	},
	{
		key = "fast_grow",
		kind = "pass",
		id = 0,
		price = 299,
		name = "Fast Grow",
		icon = "⚡",
		description = "Slimes grow 30% faster, even while you are offline.",
		category = "Passes",
		order = 6,
	},
	{
		key = "auto_harvest",
		kind = "pass",
		id = 0,
		price = 349,
		name = "Auto Harvest",
		icon = "🤖",
		description = "Ripe slimes harvest themselves while you play (toggle any time).",
		category = "Passes",
		order = 7,
	},
	{
		key = "double_coins",
		kind = "pass",
		id = 0,
		price = 399,
		name = "2x Coins",
		icon = "💎",
		description = "Every slime sells for double, forever.",
		category = "Passes",
		order = 8,
		highlight = "POPULAR",
	},

	-- Developer products: repeatable purchases.
	{
		key = "instant_grow",
		kind = "product",
		id = 0,
		price = 29,
		name = "Instant Grow",
		icon = "⏩",
		description = "Instantly ripens every slime in your garden. Saved for later if nothing is growing.",
		category = "Boosts",
		order = 1,
	},
	{
		key = "growth_potion",
		kind = "product",
		id = 0,
		price = 39,
		name = "Growth Potion",
		icon = "🧪",
		description = "2x growth speed for 15 minutes. Stacks duration.",
		category = "Boosts",
		order = 2,
	},
	{
		key = "luck_potion",
		kind = "product",
		id = 0,
		price = 39,
		name = "Luck Potion",
		icon = "🔮",
		description = "2x mutation chances for 15 minutes. Stacks duration.",
		category = "Boosts",
		order = 3,
	},
	{
		key = "prism_seed",
		kind = "product",
		id = 0,
		price = 99,
		name = "Prism Seed",
		icon = "🌈",
		description = "An exclusive seed that grows in 5 minutes into a slime worth 8x your best species.",
		category = "Boosts",
		order = 4,
	},
	{
		key = "coins_small",
		kind = "product",
		id = 0,
		price = 25,
		name = "Pouch of Coins",
		icon = "🪙",
		description = "Scales with your progress.",
		category = "Coins",
		order = 1,
	},
	{
		key = "coins_medium",
		kind = "product",
		id = 0,
		price = 75,
		name = "Bag of Coins",
		icon = "💰",
		description = "Scales with your progress.",
		category = "Coins",
		order = 2,
	},
	{
		key = "coins_large",
		kind = "product",
		id = 0,
		price = 199,
		name = "Chest of Coins",
		icon = "🧰",
		description = "Scales with your progress.",
		category = "Coins",
		order = 3,
	},
	{
		key = "coins_huge",
		kind = "product",
		id = 0,
		price = 449,
		name = "Vault of Coins",
		icon = "🏦",
		description = "Scales with your progress.",
		category = "Coins",
		order = 4,
		highlight = "BEST RATE",
	},
	{
		key = "weather_goorain",
		kind = "product",
		id = 0,
		price = 79,
		name = "Summon Goo Rain",
		icon = "🌧️",
		description = "Starts Goo Rain for EVERYONE in the server: 1.5x growth and Drenched mutations.",
		category = "Events",
		order = 1,
	},
	{
		key = "weather_starfall",
		kind = "product",
		id = 0,
		price = 199,
		name = "Summon Starfall",
		icon = "🌠",
		description = "Starts a Starfall for EVERYONE in the server: Starstruck (x8) mutations.",
		category = "Events",
		order = 2,
	},
}

local byKey: { [string]: Product } = {}
local byPassId: { [number]: Product } = {}
local byProductId: { [number]: Product } = {}

for _, product in list do
	assert(byKey[product.key] == nil, `duplicate product key {product.key}`)
	byKey[product.key] = product
	if product.id ~= 0 then
		if product.kind == "pass" then
			byPassId[product.id] = product
		else
			byProductId[product.id] = product
		end
	end
end

Products.list = list
Products.byKey = byKey
Products.byPassId = byPassId
Products.byProductId = byProductId

Products.CoinPackUnits = {
	coins_small = 10,
	coins_medium = 35,
	coins_large = 100,
	coins_huge = 300,
} :: { [string]: number }

Products.Categories = { "Passes", "Boosts", "Coins", "Events" } :: { Category }

function Products.get(key: string): Product?
	return byKey[key]
end

return Products
