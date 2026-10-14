--!strict
-- Gameplay tunables. This module replicates to clients, so it holds nothing
-- secret; the server remains the only authority for every value used here.

local Config = {}

Config.GameName = "Slime Garden"

-- Set to your Roblox group id to enable the +10% group bonus (0 = disabled).
Config.GroupId = 0

Config.Plots = {
	Count = 6, -- also set Max Players to this value in Game Settings
	Radius = 92, -- distance of each plot centre from the hub
	Columns = 6,
	Rows = 5,
	TileSize = 5,
	TileGap = 1,
	StartingTiles = 6,
	FreeTileLimit = 24, -- tiles 1..24 unlock with coins
	PassTiles = 6, -- tiles 25..30 come with the Big Garden pass
	MaxRebirthBonusTiles = 6,
	ReachDistance = 70, -- max character distance from a tile to plant / harvest it
}

Config.Shop = {
	RestockInterval = 300, -- seconds
	ReachDistance = 30,
}

Config.Sell = {
	ReachDistance = 30,
}

Config.Backpack = {
	BaseCapacity = 150,
	VipBonus = 50,
	MaxFavorites = 30,
}

Config.Growth = {
	MinVisualScale = 0.28, -- size of a freshly planted slime relative to grown
	MaxOfflineSeconds = 7 * 24 * 3600,
	AutoHarvestInterval = 5,
}

Config.Weather = {
	MinInterval = 540,
	MaxInterval = 780,
	Duration = 150,
	MutationTick = 10, -- seconds between weather mutation rolls
}

Config.Boosts = {
	PotionDuration = 15 * 60,
	GrowthPotionMultiplier = 2,
	LuckPotionMultiplier = 2,
	MaxLuck = 4,
}

Config.Bonuses = {
	FriendBonus = 0.1,
	MaxFriends = 3,
	PremiumBonus = 0.1,
	GroupBonus = 0.1,
	VipBonus = 0.15,
	RebirthBonus = 0.5,
	FastGrowMultiplier = 1.3,
}

Config.Rebirth = {
	BaseCost = 15_000_000,
	CostGrowth = 4,
}

Config.Data = {
	StoreName = "SlimeGardenPlayers_v1",
	LeaderboardStoreName = "SlimeGardenTopEarned_v1",
	AutosaveInterval = 60,
	LockStaleAfter = 300, -- a lock not refreshed for this long belongs to a dead server
	MaxReceipts = 100,
}

Config.Leaderboard = {
	RefreshInterval = 180,
	Size = 10,
	PublishInterval = 120,
}

-- Optional Roblox badges. Create them in the Creator Dashboard and paste the
-- ids here; 0 disables the award.
Config.Badges = {
	Welcome = 0,
	FirstHarvest = 0,
	FirstRebirth = 0,
	LegendaryHarvest = 0,
}

-- Built-in Roblox sounds that ship with every client. Replace with Creator
-- Store audio ids (rbxassetid://...) for a more polished soundscape.
Config.Sounds = {
	Click = "rbxasset://sounds/clickfast.wav",
	Plant = "rbxasset://sounds/clickfast.wav",
	Harvest = "rbxasset://sounds/electronicpingshort.wav",
	Sell = "rbxasset://sounds/electronicpingshort.wav",
	Rare = "rbxasset://sounds/victory.wav",
	Error = "rbxasset://sounds/clickfast.wav",
}

Config.AnnounceMinTier = 7 -- server-wide announcement for harvests at/above this tier
Config.AnnounceMinMultiplier = 6 -- ...or with a mutation multiplier at/above this

return Config
