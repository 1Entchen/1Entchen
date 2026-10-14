--!strict
-- Rebirth: spend coins to reset the garden for a permanent +50% coin bonus,
-- an extra starting tile and (from Rebirth 1) Cosmic seeds in the shop.
-- Favorited slimes, the Slimepedia, passes and potions are kept.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Badges = require(Util:WaitForChild("Badges"))
local Notify = require(Util:WaitForChild("Notify"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local Analytics = require(script.Parent.Analytics)
local Boosts = require(script.Parent.Boosts)
local DataService = require(script.Parent.DataService)
local Garden = require(script.Parent.Garden)
local Plots = require(script.Parent.Plots)
local Sync = require(script.Parent.Sync)

type SlimeData = Types.SlimeData

local Rebirth = {}

local function onRebirth(player: Player)
	if not RateLimiter.allow(player, "Rebirth", 0.2, 1) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Economy.rebirthCost(data.rebirths)
	if data.coins < cost then
		Notify.player(player, `You need {Format.short(cost)} coins to rebirth.`, "error")
		return
	end

	Garden.clearAll(player)
	local favorites: { SlimeData } = {}
	for _, slime in data.slimes do
		if slime.f then
			table.insert(favorites, slime)
		end
	end
	local spent = data.coins
	data.rebirths += 1
	data.coins = 30
	data.seeds = { goo = 3 }
	data.slimes = favorites
	data.unlockedTiles = Economy.startingTiles(data.rebirths)
	table.clear(data.plants)

	Analytics.coinSink(player, spent, data.coins, Enum.AnalyticsEconomyTransactionType.Gameplay, "rebirth")
	Analytics.progression(player, "Rebirth", data.rebirths)
	if data.rebirths == 1 then
		Badges.award(player, "FirstRebirth")
	end
	Boosts.refresh(player)
	Plots.refreshTiles(player)
	Sync.markAll(player)
	Notify.all(`⭐ {player.DisplayName} reached Rebirth {data.rebirths}!`, Color3.fromRGB(255, 220, 90))
	Notify.effect(player, "rebirth", { rebirths = data.rebirths })
end

function Rebirth.start()
	Net.event("Rebirth").OnServerEvent:Connect(onRebirth)
end

return Rebirth
