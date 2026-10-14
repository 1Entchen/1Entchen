--!strict
-- Seed shop with a server-wide restock every few minutes. Stock is per
-- player (everyone can buy the full listed amount), so it creates a reason
-- to check back without letting anyone grief others.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Species = require(Shared:WaitForChild("Species"))
local Stock = require(Shared:WaitForChild("Stock"))
local Types = require(Shared:WaitForChild("Types"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Notify = require(Util:WaitForChild("Notify"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))
local Validate = require(Util:WaitForChild("Validate"))

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Plots = require(script.Parent.Plots)
local Retention = require(script.Parent.Retention)
local Sync = require(script.Parent.Sync)
local Tutorial = require(script.Parent.Tutorial)

type Profile = Types.Profile
type StockState = Types.StockState

local Shop = {}

local random = Random.new()
local state: StockState = { restockId = 0, nextRestockAt = 0, stock = {} }
local bought: { [Player]: { restockId: number, counts: { [string]: number } } } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rng(): number
	return random:NextNumber()
end

function Shop.state(): StockState
	return state
end

local function purchasesFor(player: Player): { [string]: number }
	local entry = bought[player]
	if entry and entry.restockId == state.restockId then
		return entry.counts
	end
	local counts: { [string]: number } = {}
	bought[player] = { restockId = state.restockId, counts = counts }
	return counts
end

local function restock(silent: boolean)
	state.restockId += 1
	state.stock = Stock.roll(rng)
	state.nextRestockAt = now() + Config.Shop.RestockInterval
	Net.event("Stock"):FireAllClients(state)
	for _, player in Players:GetPlayers() do
		Sync.mark(player, "shop")
	end
	if silent then
		return
	end
	-- Call out rare stock so players in the server can react.
	local rare = {}
	for _, species in Species.shopOrder do
		if state.stock[species.id] and species.tier >= 6 then
			table.insert(rare, species.name)
		end
	end
	if #rare > 0 then
		Notify.all(
			`🌱 Seed Shop restocked with RARE seeds: {table.concat(rare, ", ")}!`,
			Color3.fromRGB(255, 220, 90)
		)
	else
		Notify.all("🌱 The Seed Shop has restocked!", nil)
	end
end

local function onBuySeed(player: Player, rawSpecies: unknown, rawQuantity: unknown)
	if not RateLimiter.allow(player, "BuySeed", 8, 12) then
		return
	end
	local speciesId = Validate.shortString(rawSpecies, 24)
	local quantity = Validate.integer(rawQuantity, 1, 50)
	local data = DataService.get(player)
	if not speciesId or not quantity or not data then
		return
	end
	local species = Species.byId[speciesId]
	if not species or species.price <= 0 then
		return
	end
	if data.rebirths < species.requiresRebirth then
		Notify.player(player, `{species.name} seeds unlock after Rebirth {species.requiresRebirth}.`, "error")
		return
	end
	if not Validate.near(player, Plots.world().shopCounter.Position, Config.Shop.ReachDistance) then
		Notify.player(player, "Visit the Seed Shop to buy seeds.", "error")
		return
	end
	local counts = purchasesFor(player)
	local remaining = (state.stock[speciesId] or 0) - (counts[speciesId] or 0)
	local affordable = math.floor(data.coins / species.price)
	local amount = math.min(quantity, remaining, affordable)
	if remaining <= 0 then
		Notify.player(player, `{species.name} is sold out until the next restock.`, "error")
		return
	elseif amount <= 0 then
		Notify.player(
			player,
			`You need {Format.short(species.price)} coins for a {species.name} seed.`,
			"error"
		)
		return
	end

	local cost = amount * species.price
	data.coins -= cost
	data.seeds[speciesId] = (data.seeds[speciesId] or 0) + amount
	data.stats.seedsBought += amount
	counts[speciesId] = (counts[speciesId] or 0) + amount

	Analytics.coinSink(
		player,
		cost,
		data.coins,
		Enum.AnalyticsEconomyTransactionType.Shop,
		"seed_" .. speciesId
	)
	Retention.progress(player, data, "buy", amount)
	Tutorial.event(player, data, "bought")
	Notify.effect(player, "buy", { species = speciesId, amount = amount })
	Sync.mark(player, "main")
	Sync.mark(player, "shop")
end

function Shop.init()
	Sync.register("shop", function(player: Player)
		return { restockId = state.restockId, bought = purchasesFor(player) }
	end)
	restock(true)
end

function Shop.start()
	Net.event("BuySeed").OnServerEvent:Connect(onBuySeed)
	Net.event("RequestSync").OnServerEvent:Connect(function(player)
		if RateLimiter.allow(player, "RequestSyncStock", 0.2, 2) then
			Net.event("Stock"):FireClient(player, state)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		bought[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if now() >= state.nextRestockAt then
				restock(false)
			end
		end
	end)
end

return Shop
