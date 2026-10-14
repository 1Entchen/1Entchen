--!strict
-- Shared type definitions that cross the client/server boundary or are
-- persisted. Persisted shapes must stay JSON-encodable (string keys or
-- dense arrays only, no Instances).

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Exclusive"

export type Species = {
	id: string,
	name: string,
	tier: number, -- 1..10 for shop seeds, 0 for exclusives
	rarity: Rarity,
	price: number, -- coin price in the seed shop (0 = not sold for coins)
	growTime: number, -- seconds of growth at 1x speed
	value: number, -- base coin value of a 1.0 weight slime
	color: Color3,
	accent: Color3,
	material: Enum.Material,
	transparency: number,
	stockChance: number, -- probability [0,1] the seed appears in a restock
	stockMin: number,
	stockMax: number,
	requiresRebirth: number,
	flavor: string,
}

export type MutationKind = "variant" | "weather"

export type Mutation = {
	id: string,
	name: string,
	kind: MutationKind,
	multiplier: number,
	color: Color3,
	-- variant: chance rolled once when a slime ripens.
	-- weather: chance per minute while the matching weather is active.
	chance: number,
	weather: string?,
	order: number,
}

-- A slime growing on a garden tile (persisted).
export type PlantData = {
	tile: number,
	s: string, -- species id
	w: number, -- weight multiplier
	e: number, -- growth-seconds accumulated
	m: { string }, -- mutation ids
	r: boolean, -- variant roll done (happens once, at ripening)
	b: number?, -- base value override (exclusive seeds)
}

-- A harvested slime in the backpack (persisted).
export type SlimeData = {
	id: number,
	s: string,
	w: number,
	m: { string },
	b: number?,
	f: boolean?, -- favorited: protected from Sell All and kept on rebirth
}

export type QuestData = {
	kind: string,
	target: number,
	progress: number,
	claimed: boolean,
	rewardCoins: number,
	rewardItem: string?,
}

export type Profile = {
	version: number,
	coins: number,
	totalEarned: number,
	rebirths: number,
	bestTier: number,
	seeds: { [string]: number },
	slimes: { SlimeData },
	nextSlimeId: number,
	plants: { PlantData },
	unlockedTiles: number,
	potions: { [string]: number },
	boostExpiry: { [string]: number }, -- unix time a timed boost ends
	instantGrowCharges: number,
	index: { [string]: boolean }, -- "goo" or "goo:golden"
	daily: { lastClaimDay: number, streak: number },
	quests: { day: number, list: { QuestData } },
	tutorialStep: number,
	stats: {
		harvested: number,
		planted: number,
		seedsBought: number,
		robuxSpent: number,
		sessions: number,
		playSeconds: number,
		firstJoin: number,
	},
	receipts: { string },
	passCache: { [string]: boolean },
	starterPackClaimed: boolean,
	autoHarvest: boolean,
	lastSeen: number,
}

export type BoostEntry = {
	key: string,
	label: string,
	icon: string,
	expiresAt: number?, -- server time (workspace:GetServerTimeNow scale) when it ends
}

export type Multipliers = {
	sell: number,
	growth: number,
	luck: number,
}

export type WeatherState = {
	id: string?,
	endsAt: number, -- server time
	summonedBy: string?,
	nextAt: number, -- server time of the next natural event (approximate)
}

export type StockState = {
	restockId: number,
	nextRestockAt: number, -- server time
	stock: { [string]: number },
}

return nil
