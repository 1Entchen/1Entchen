--!strict
-- Replicates each player's own state to their client. Systems mark sections
-- dirty; dirty sections are rebuilt and sent at most every 0.15 s, so a burst
-- of changes (Harvest All, Sell All) costs one message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))

local RateLimiter = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("RateLimiter"))

local DataService = require(script.Parent.DataService)

type Profile = Types.Profile
type Builder = (Player, Profile) -> any

local FLUSH_INTERVAL = 0.15

local Sync = {}

local builders: { [string]: Builder } = {}
local dirty: { [Player]: { [string]: boolean } } = {}

function Sync.register(section: string, builder: Builder)
	assert(builders[section] == nil, `duplicate sync section {section}`)
	builders[section] = builder
end

function Sync.mark(player: Player, section: string?)
	local sections = dirty[player]
	if not sections then
		sections = {}
		dirty[player] = sections
	end
	sections[section or "main"] = true
end

function Sync.markAll(player: Player)
	for section in builders do
		Sync.mark(player, section)
	end
end

local function buildMain(_: Player, data: Profile): any
	return {
		coins = data.coins,
		totalEarned = data.totalEarned,
		rebirths = data.rebirths,
		bestTier = data.bestTier,
		seeds = data.seeds,
		unlockedTiles = data.unlockedTiles,
		potions = data.potions,
		instantGrowCharges = data.instantGrowCharges,
		index = data.index,
		tutorialStep = data.tutorialStep,
		autoHarvest = data.autoHarvest,
		stats = { harvested = data.stats.harvested },
	}
end

local function buildBackpack(_: Player, data: Profile): any
	return data.slimes
end

local function flush()
	for player, sections in dirty do
		local data = DataService.get(player)
		if not data then
			if not player.Parent then
				dirty[player] = nil
			end
			continue
		end
		dirty[player] = nil
		local payload = {}
		for section in sections do
			local builder = builders[section]
			if builder then
				local ok, result = pcall(builder, player, data)
				if ok then
					payload[section] = result
				else
					warn(`[Sync] section {section} failed: {result}`)
				end
			end
		end
		Net.event("Sync"):FireClient(player, payload)
	end
end

function Sync.init()
	Sync.register("main", buildMain)
	Sync.register("backpack", buildBackpack)
end

function Sync.start()
	DataService.ProfileLoaded:Connect(function(player)
		Sync.markAll(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
	Net.event("RequestSync").OnServerEvent:Connect(function(player)
		if RateLimiter.allow(player, "RequestSync", 0.2, 2) then
			Sync.markAll(player)
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= FLUSH_INTERVAL then
			elapsed = 0
			flush()
		end
	end)
end

return Sync
