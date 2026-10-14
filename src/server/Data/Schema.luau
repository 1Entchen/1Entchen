--!strict
-- Player profile schema: defaults, migrations and reconciliation. Pure
-- functions so they can be tested outside Roblox.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Species = require(Shared:WaitForChild("Species"))
local Types = require(Shared:WaitForChild("Types"))

type Profile = Types.Profile

local Schema = {}

Schema.CURRENT_VERSION = 1

function Schema.defaults(now: number): Profile
	return {
		version = Schema.CURRENT_VERSION,
		coins = 30,
		totalEarned = 0,
		rebirths = 0,
		bestTier = 1,
		seeds = { goo = 3 },
		slimes = {},
		nextSlimeId = 1,
		plants = {},
		unlockedTiles = Config.Plots.StartingTiles,
		potions = {},
		boostExpiry = {},
		instantGrowCharges = 0,
		index = {},
		daily = { lastClaimDay = -1, streak = 0 },
		quests = { day = -1, list = {} },
		tutorialStep = 0,
		stats = {
			harvested = 0,
			planted = 0,
			seedsBought = 0,
			robuxSpent = 0,
			sessions = 0,
			playSeconds = 0,
			firstJoin = now,
		},
		receipts = {},
		passCache = {},
		starterPackClaimed = false,
		autoHarvest = true,
		lastSeen = now,
	}
end

-- Migrations from version N to N+1. Add entries as the schema evolves, never
-- edit an entry that has shipped.
local MIGRATIONS: { [number]: (any) -> any } = {}

function Schema.migrate(data: any): any
	local version = tonumber(data.version) or 1
	while version < Schema.CURRENT_VERSION do
		local step = MIGRATIONS[version]
		assert(step, `missing profile migration from v{version}`)
		data = step(data)
		version += 1
		data.version = version
	end
	return data
end

local function isFiniteNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function number(value: unknown, fallback: number, minimum: number?): number
	if not isFiniteNumber(value) then
		return fallback
	end
	local n = value :: number
	if minimum and n < minimum then
		return minimum
	end
	return n
end

local function stringList(value: unknown): { string }
	local result = {}
	if typeof(value) == "table" then
		for _, item in value :: { any } do
			if typeof(item) == "string" then
				table.insert(result, item)
			end
		end
	end
	return result
end

local function countMap(value: unknown): { [string]: number }
	local result = {}
	if typeof(value) == "table" then
		for key, count in value :: { [any]: any } do
			if typeof(key) == "string" and isFiniteNumber(count) and count > 0 then
				result[key] = math.floor(count)
			end
		end
	end
	return result
end

-- Fills missing fields and repairs corrupt ones so gameplay code can trust
-- the shape. Unknown keys are kept (forward compatibility with newer
-- servers during a rolling update).
function Schema.reconcile(raw: any, now: number): Profile
	local defaults = Schema.defaults(now)
	if typeof(raw) ~= "table" then
		return defaults
	end
	local data = raw :: any

	data.version = number(data.version, Schema.CURRENT_VERSION)
	data.coins = number(data.coins, defaults.coins, 0)
	data.totalEarned = number(data.totalEarned, 0, 0)
	data.rebirths = math.floor(number(data.rebirths, 0, 0))
	data.bestTier = math.clamp(math.floor(number(data.bestTier, 1, 1)), 1, Species.MaxTier)
	data.seeds = countMap(data.seeds)
	data.potions = countMap(data.potions)
	data.nextSlimeId = math.floor(number(data.nextSlimeId, 1, 1))
	data.unlockedTiles = math.clamp(
		math.floor(number(data.unlockedTiles, defaults.unlockedTiles)),
		0,
		Config.Plots.FreeTileLimit
	)
	data.instantGrowCharges = math.floor(number(data.instantGrowCharges, 0, 0))
	data.tutorialStep = math.floor(number(data.tutorialStep, 0, 0))
	data.starterPackClaimed = data.starterPackClaimed == true
	data.autoHarvest = data.autoHarvest ~= false
	data.lastSeen = number(data.lastSeen, now)

	local boostExpiry = {}
	if typeof(data.boostExpiry) == "table" then
		for key, value in data.boostExpiry do
			if typeof(key) == "string" and isFiniteNumber(value) then
				boostExpiry[key] = value
			end
		end
	end
	data.boostExpiry = boostExpiry

	local index = {}
	if typeof(data.index) == "table" then
		for key, value in data.index do
			if typeof(key) == "string" and value == true then
				index[key] = true
			end
		end
	end
	data.index = index

	local passCache = {}
	if typeof(data.passCache) == "table" then
		for key, value in data.passCache do
			if typeof(key) == "string" and value == true then
				passCache[key] = true
			end
		end
	end
	data.passCache = passCache

	local slimes = {}
	local maxId = 0
	if typeof(data.slimes) == "table" then
		for _, slime in data.slimes do
			if
				typeof(slime) == "table"
				and Species.isValidId(slime.s)
				and isFiniteNumber(slime.id)
				and isFiniteNumber(slime.w)
			then
				local entry: Types.SlimeData = {
					id = math.floor(slime.id),
					s = slime.s,
					w = slime.w,
					m = stringList(slime.m),
					b = if isFiniteNumber(slime.b) then slime.b else nil,
					f = if slime.f == true then true else nil,
				}
				maxId = math.max(maxId, entry.id)
				table.insert(slimes, entry)
			end
		end
	end
	data.slimes = slimes
	data.nextSlimeId = math.max(data.nextSlimeId, maxId + 1)

	local plants = {}
	local usedTiles = {}
	if typeof(data.plants) == "table" then
		for _, plant in data.plants do
			if
				typeof(plant) == "table"
				and Species.isValidId(plant.s)
				and isFiniteNumber(plant.tile)
				and isFiniteNumber(plant.w)
				and not usedTiles[plant.tile]
			then
				usedTiles[plant.tile] = true
				table.insert(plants, {
					tile = math.floor(plant.tile),
					s = plant.s,
					w = plant.w,
					e = number(plant.e, 0, 0),
					m = stringList(plant.m),
					r = plant.r == true,
					b = if isFiniteNumber(plant.b) then plant.b else nil,
				})
			end
		end
	end
	data.plants = plants

	local daily = if typeof(data.daily) == "table" then data.daily else {}
	data.daily = {
		lastClaimDay = math.floor(number(daily.lastClaimDay, -1)),
		streak = math.floor(number(daily.streak, 0, 0)),
	}

	local quests = if typeof(data.quests) == "table" then data.quests else {}
	local questList = {}
	if typeof(quests.list) == "table" then
		for _, quest in quests.list do
			if typeof(quest) == "table" and typeof(quest.kind) == "string" then
				table.insert(questList, {
					kind = quest.kind,
					target = number(quest.target, 1, 1),
					progress = number(quest.progress, 0, 0),
					claimed = quest.claimed == true,
					rewardCoins = number(quest.rewardCoins, 0, 0),
					rewardItem = if typeof(quest.rewardItem) == "string" then quest.rewardItem else nil,
				})
			end
		end
	end
	data.quests = { day = math.floor(number(quests.day, -1)), list = questList }

	local stats = if typeof(data.stats) == "table" then data.stats else {}
	data.stats = {
		harvested = number(stats.harvested, 0, 0),
		planted = number(stats.planted, 0, 0),
		seedsBought = number(stats.seedsBought, 0, 0),
		robuxSpent = number(stats.robuxSpent, 0, 0),
		sessions = number(stats.sessions, 0, 0),
		playSeconds = number(stats.playSeconds, 0, 0),
		firstJoin = number(stats.firstJoin, now),
	}

	data.receipts = stringList(data.receipts)
	while #data.receipts > Config.Data.MaxReceipts do
		table.remove(data.receipts, 1)
	end

	return data :: Profile
end

-- Deep copy for JSON-shaped data (used before handing data to a DataStore so
-- later in-memory mutation can't race the write).
function Schema.deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = Schema.deepCopy(child)
	end
	return copy :: any
end

return Schema
