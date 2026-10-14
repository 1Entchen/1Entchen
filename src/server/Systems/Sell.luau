--!strict
-- Selling slimes for coins at the Sell Stand (or anywhere with the pass).
-- Prices come only from the server catalog and current multipliers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Notify = require(Util:WaitForChild("Notify"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))
local Validate = require(Util:WaitForChild("Validate"))

local Analytics = require(script.Parent.Analytics)
local Boosts = require(script.Parent.Boosts)
local DataService = require(script.Parent.DataService)
local Monetization = require(script.Parent.Monetization)
local Plots = require(script.Parent.Plots)
local Retention = require(script.Parent.Retention)
local Sync = require(script.Parent.Sync)
local Tutorial = require(script.Parent.Tutorial)

type Profile = Types.Profile
type SlimeData = Types.SlimeData

local Sell = {}

local function canSellHere(player: Player): boolean
	if Monetization.owns(player, "sell_anywhere") then
		return true
	end
	return Validate.near(player, Plots.world().sellCounter.Position, Config.Sell.ReachDistance)
end

local function finishSale(player: Player, data: Profile, total: number, count: number)
	data.coins += total
	data.totalEarned += total
	Analytics.coinSource(player, total, data.coins, Enum.AnalyticsEconomyTransactionType.Gameplay, "sell")
	Retention.progress(player, data, "sell", total)
	Tutorial.event(player, data, "sold")
	Notify.effect(player, "sell", { amount = total, count = count })
	Sync.mark(player, "main")
	Sync.mark(player, "backpack")
end

function Sell.sellAll(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if not canSellHere(player) then
		Notify.player(player, "Walk to the Sell Stand in the hub to sell!", "error")
		return
	end
	local multiplier = Boosts.get(player).sell
	local kept: { SlimeData } = {}
	local total, count = 0, 0
	for _, slime in data.slimes do
		if slime.f then
			table.insert(kept, slime)
		else
			total += Economy.slimeValue(slime, multiplier)
			count += 1
		end
	end
	if count == 0 then
		Notify.player(player, "Nothing to sell! Harvest ripe slimes in your garden first.", "info")
		return
	end
	data.slimes = kept
	finishSale(player, data, total, count)
	Notify.player(player, `💰 Sold {count} slime(s) for {Format.short(total)} coins!`, "success")
end

local function onSellAll(player: Player)
	if not RateLimiter.allow(player, "SellAll", 1, 3) then
		return
	end
	Sell.sellAll(player)
end

local function onSellSlime(player: Player, rawId: unknown)
	if not RateLimiter.allow(player, "SellSlime", 6, 10) then
		return
	end
	local id = Validate.integer(rawId, 1, 2 ^ 31)
	local data = DataService.get(player)
	if not id or not data then
		return
	end
	if not canSellHere(player) then
		Notify.player(player, "Walk to the Sell Stand in the hub to sell!", "error")
		return
	end
	for i, slime in data.slimes do
		if slime.id == id then
			if slime.f then
				Notify.player(player, "Unfavorite this slime to sell it.", "info")
				return
			end
			table.remove(data.slimes, i)
			local value = Economy.slimeValue(slime, Boosts.get(player).sell)
			finishSale(player, data, value, 1)
			return
		end
	end
end

local function onToggleFavorite(player: Player, rawId: unknown)
	if not RateLimiter.allow(player, "ToggleFavorite", 6, 10) then
		return
	end
	local id = Validate.integer(rawId, 1, 2 ^ 31)
	local data = DataService.get(player)
	if not id or not data then
		return
	end
	local favorites = 0
	local target: SlimeData? = nil
	for _, slime in data.slimes do
		if slime.f then
			favorites += 1
		end
		if slime.id == id then
			target = slime
		end
	end
	if not target then
		return
	end
	if target.f then
		target.f = nil
	elseif favorites >= Config.Backpack.MaxFavorites then
		Notify.player(player, `You can favorite up to {Config.Backpack.MaxFavorites} slimes.`, "error")
		return
	else
		target.f = true
	end
	Sync.mark(player, "backpack")
end

function Sell.start()
	Net.event("SellAll").OnServerEvent:Connect(onSellAll)
	Net.event("SellSlime").OnServerEvent:Connect(onSellSlime)
	Net.event("ToggleFavorite").OnServerEvent:Connect(onToggleFavorite)

	local prompt = Plots.world().sellCounter:FindFirstChild("SellPrompt") :: ProximityPrompt?
	if prompt then
		prompt.Triggered:Connect(function(player)
			if RateLimiter.allow(player, "SellAll", 1, 3) then
				Sell.sellAll(player)
			end
		end)
	end
end

return Sell
