--!strict
-- The core loop: plant -> grow -> ripen (variant roll) -> weather mutations
-- -> harvest. Growth is tracked as "growth-seconds" so speed boosts can
-- change at any moment without losing progress, and keeps going offline.
--
-- Persisted per plant: tile, species, weight, accumulated growth-seconds,
-- mutations and whether the ripening roll happened. Runtime adds the model
-- and the server time of the last commit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Mutations = require(Shared:WaitForChild("Mutations"))
local Net = require(Shared:WaitForChild("Net"))
local SlimeBuilder = require(Shared:WaitForChild("SlimeBuilder"))
local Species = require(Shared:WaitForChild("Species"))
local Types = require(Shared:WaitForChild("Types"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Badges = require(Util:WaitForChild("Badges"))
local Notify = require(Util:WaitForChild("Notify"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))
local Validate = require(Util:WaitForChild("Validate"))

local Boosts = require(script.Parent.Boosts)
local DataService = require(script.Parent.DataService)
local Index = require(script.Parent.Index)
local Monetization = require(script.Parent.Monetization)
local Plots = require(script.Parent.Plots)
local Retention = require(script.Parent.Retention)
local Sync = require(script.Parent.Sync)
local Tutorial = require(script.Parent.Tutorial)
local Weather = require(script.Parent.Weather)

type Profile = Types.Profile
type PlantData = Types.PlantData
type SlimeData = Types.SlimeData

type Plant = {
	data: PlantData,
	model: Model?,
	lastCommit: number, -- server time
	ripe: boolean,
}

type GardenState = {
	player: Player,
	plot: any,
	plants: { [number]: Plant },
	rate: number,
	luck: number,
}

local Garden = {}

local MAX_TILE = Config.Plots.FreeTileLimit + Config.Plots.PassTiles
local random = Random.new()
local gardens: { [Player]: GardenState } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rng(): number
	return random:NextNumber()
end

local function growTime(plant: Plant): number
	return Economy.growTime(plant.data.s)
end

local function writeAttributes(state: GardenState, plant: Plant)
	local model = plant.model
	if not model then
		return
	end
	model:SetAttribute("Elapsed", plant.data.e)
	model:SetAttribute("Rate", if plant.ripe then 0 else state.rate)
	model:SetAttribute("UpdatedAt", plant.lastCommit)
	model:SetAttribute("Ripe", plant.ripe)
end

local function buildModel(state: GardenState, plant: Plant)
	if plant.model then
		plant.model:Destroy()
		plant.model = nil
	end
	local top = Plots.tileTop(state.plot, plant.data.tile)
	if not top then
		return
	end
	local model = SlimeBuilder.build(plant.data.s, plant.data.m, Economy.visualSize(plant.data.w))
	model.Name = `Plant{plant.data.tile}`
	model:SetAttribute("OwnerUserId", state.player.UserId)
	model:SetAttribute("Tile", plant.data.tile)
	model:SetAttribute("Weight", plant.data.w)
	model:SetAttribute("GrowTime", growTime(plant))
	model:SetAttribute("Mutations", table.concat(plant.data.m, ","))
	model:SetAttribute("BaseValue", Economy.baseValue(plant.data))
	model:PivotTo(top)
	plant.model = model
	writeAttributes(state, plant)
	model.Parent = state.plot.plants
end

-- Folds elapsed time into each plant's stored growth at the current rate.
local function commit(state: GardenState)
	local t = now()
	for _, plant in state.plants do
		if not plant.ripe then
			plant.data.e = math.min(growTime(plant), plant.data.e + (t - plant.lastCommit) * state.rate)
		end
		plant.lastCommit = t
	end
end

local function ripen(state: GardenState, plant: Plant, quiet: boolean)
	plant.ripe = true
	plant.data.e = growTime(plant)
	local mutated = false
	if not plant.data.r then
		plant.data.r = true
		local variant = Economy.rollVariant(rng, state.luck)
		if variant then
			table.insert(plant.data.m, variant)
			mutated = true
		end
	end
	if mutated then
		buildModel(state, plant)
	else
		writeAttributes(state, plant)
	end
	local data = DataService.get(state.player)
	if data then
		Tutorial.event(state.player, data, "ripe")
	end
	if not quiet then
		Notify.effect(state.player, "ripe", { tile = plant.data.tile, mutated = mutated })
	end
end

function Garden.get(player: Player): GardenState?
	return gardens[player]
end

function Garden.ripeCount(player: Player): number
	local state = gardens[player]
	if not state then
		return 0
	end
	local count = 0
	for _, plant in state.plants do
		if plant.ripe then
			count += 1
		end
	end
	return count
end

local function setup(player: Player, plot: any, data: Profile)
	local multipliers = Boosts.get(player)
	local state: GardenState = {
		player = player,
		plot = plot,
		plants = {},
		rate = multipliers.growth,
		luck = multipliers.luck,
	}
	gardens[player] = state

	-- Offline growth at the base rate (+ Fast Grow, which is permanent).
	local offline = math.clamp(os.time() - data.lastSeen, 0, Config.Growth.MaxOfflineSeconds)
	local offlineRate = Economy.growthRate(Monetization.owns(player, "fast_grow"), false, 1)
	local t = now()
	for _, plantData in data.plants do
		-- Plants stay on their tile even if it is no longer usable (e.g. a
		-- deleted Big Garden pass) so nothing the player owns disappears.
		plantData.e = math.min(Economy.growTime(plantData.s), plantData.e + offline * offlineRate)
		local plant: Plant = { data = plantData, model = nil, lastCommit = t, ripe = false }
		state.plants[plantData.tile] = plant
		buildModel(state, plant)
	end
	for _, plant in state.plants do
		if plant.data.e >= growTime(plant) then
			ripen(state, plant, true)
		end
	end
	Sync.mark(player, "main")
end

local function teardown(player: Player)
	local state = gardens[player]
	if not state then
		return
	end
	gardens[player] = nil
	for _, plant in state.plants do
		if plant.model then
			plant.model:Destroy()
		end
	end
end

local function removePlant(state: GardenState, data: Profile, tile: number)
	local plant = state.plants[tile]
	if not plant then
		return
	end
	state.plants[tile] = nil
	if plant.model then
		plant.model:Destroy()
	end
	for i, stored in data.plants do
		if stored.tile == tile then
			table.remove(data.plants, i)
			break
		end
	end
end

local function backpackCapacity(player: Player): number
	return Economy.backpackCapacity(Monetization.owns(player, "vip"))
end

local function announce(player: Player, slime: SlimeData)
	local species = Species.byId[slime.s]
	if not species then
		return
	end
	local multiplier = Economy.mutationMultiplier(slime.m)
	local weightLabel = Economy.weightLabel(slime.w)
	local tier = Economy.effectiveTier(slime.s)
	if
		tier < Config.AnnounceMinTier
		and multiplier < Config.AnnounceMinMultiplier
		and weightLabel ~= "Titanic"
	then
		return
	end
	local parts = {}
	local mutationText = SlimeBuilder.mutationNames(slime.m)
	if mutationText ~= "" then
		table.insert(parts, mutationText)
	end
	if weightLabel then
		table.insert(parts, weightLabel)
	end
	table.insert(parts, species.name)
	Notify.all(
		`🌟 {player.DisplayName} harvested a {table.concat(parts, " ")}!`,
		Species.RarityColors[species.rarity]
	)
end

-- Harvests one ripe plant. Returns the slime, or nil (with reason) if not possible.
local function harvestTile(state: GardenState, data: Profile, tile: number): (SlimeData?, string?)
	local plant = state.plants[tile]
	if not plant or not plant.ripe then
		return nil, "not ripe"
	end
	if #data.slimes >= backpackCapacity(state.player) then
		return nil, "full"
	end
	local slime: SlimeData = {
		id = data.nextSlimeId,
		s = plant.data.s,
		w = plant.data.w,
		m = table.clone(plant.data.m),
		b = plant.data.b,
	}
	data.nextSlimeId += 1
	table.insert(data.slimes, slime)
	removePlant(state, data, tile)
	data.stats.harvested += 1

	local player = state.player
	Index.discover(player, data, slime)
	Retention.progress(player, data, "harvest", 1)
	if #slime.m > 0 then
		Retention.progress(player, data, "mutated", 1)
	end
	local tier = Economy.effectiveTier(slime.s)
	if tier >= 5 then
		Retention.progress(player, data, "rare", 1)
	end
	if data.stats.harvested == 1 then
		Badges.award(player, "FirstHarvest")
	end
	if tier >= 9 then
		Badges.award(player, "LegendaryHarvest")
	end
	announce(player, slime)
	return slime, nil
end

local function reportHarvest(player: Player, data: Profile, harvested: { SlimeData }, failure: string?)
	if #harvested > 0 then
		local multiplier = Boosts.get(player).sell
		local total = 0
		local best: SlimeData = harvested[1]
		for _, slime in harvested do
			total += Economy.slimeValue(slime, multiplier)
			if Economy.slimeValue(slime, 1) > Economy.slimeValue(best, 1) then
				best = slime
			end
		end
		Notify.effect(player, "harvest", {
			count = #harvested,
			value = total,
			species = best.s,
			mutations = best.m,
			weight = best.w,
		})
		Tutorial.event(player, data, "harvested")
		Sync.mark(player, "main")
		Sync.mark(player, "backpack")
	end
	if failure == "full" then
		Notify.player(player, "🎒 Backpack full! Sell slimes at the Sell Stand.", "error")
	end
end

local function nearPlot(player: Player, state: GardenState): boolean
	return Validate.near(player, state.plot.origin.Position, Config.Plots.ReachDistance)
end

local function onPlant(player: Player, rawTile: unknown, rawSpecies: unknown)
	if not RateLimiter.allow(player, "Plant", 8, 12) then
		return
	end
	local tile = Validate.integer(rawTile, 1, MAX_TILE)
	local speciesId = Validate.shortString(rawSpecies, 24)
	local data = DataService.get(player)
	local state = gardens[player]
	if not tile or not speciesId or not data or not state then
		return
	end
	local species = Species.byId[speciesId]
	if not species then
		return
	end
	if (data.seeds[speciesId] or 0) < 1 then
		return
	end
	if not Economy.isTileUsable(tile, data.unlockedTiles, Monetization.owns(player, "big_garden")) then
		return
	end
	if state.plants[tile] then
		return
	end
	local top = Plots.tileTop(state.plot, tile)
	if not top or not Validate.near(player, top.Position, Config.Plots.ReachDistance) then
		return
	end

	local count = data.seeds[speciesId]
	if count > 1 then
		data.seeds[speciesId] = count - 1
	else
		data.seeds[speciesId] = nil
	end

	commit(state)
	local plantData: PlantData = {
		tile = tile,
		s = speciesId,
		w = Economy.rollWeight(rng),
		e = 0,
		m = {},
		r = false,
		b = if species.tier == 0 then Economy.prismBaseValue(data.bestTier) else nil,
	}
	table.insert(data.plants, plantData)
	local plant: Plant = { data = plantData, model = nil, lastCommit = now(), ripe = false }
	state.plants[tile] = plant
	buildModel(state, plant)

	data.stats.planted += 1
	if species.tier > data.bestTier then
		data.bestTier = species.tier
	end
	Retention.progress(player, data, "plant", 1)
	Tutorial.event(player, data, "planted")
	Notify.effect(player, "plant", { tile = tile, species = speciesId })
	Sync.mark(player, "main")
end

local function onHarvest(player: Player, rawTile: unknown)
	if not RateLimiter.allow(player, "Harvest", 10, 15) then
		return
	end
	local tile = Validate.integer(rawTile, 1, MAX_TILE)
	local data = DataService.get(player)
	local state = gardens[player]
	if not tile or not data or not state then
		return
	end
	local top = Plots.tileTop(state.plot, tile)
	if not top or not Validate.near(player, top.Position, Config.Plots.ReachDistance) then
		return
	end
	local slime, failure = harvestTile(state, data, tile)
	reportHarvest(player, data, if slime then { slime } else {}, failure)
end

function Garden.harvestAll(player: Player, requireNear: boolean): number
	local data = DataService.get(player)
	local state = gardens[player]
	if not data or not state then
		return 0
	end
	if requireNear and not nearPlot(player, state) then
		Notify.player(player, "Go to your garden to harvest!", "error")
		return 0
	end
	local harvested = {}
	local failure: string? = nil
	local tiles = {}
	for tile, plant in state.plants do
		if plant.ripe then
			table.insert(tiles, tile)
		end
	end
	table.sort(tiles)
	for _, tile in tiles do
		local slime, reason = harvestTile(state, data, tile)
		if slime then
			table.insert(harvested, slime)
		elseif reason == "full" then
			failure = reason
			break
		end
	end
	reportHarvest(player, data, harvested, failure)
	return #harvested
end

local function onHarvestAll(player: Player)
	if not RateLimiter.allow(player, "HarvestAll", 1, 3) then
		return
	end
	Garden.harvestAll(player, true)
end

-- Ripens everything that is still growing. Returns how many plants ripened.
function Garden.ripenAll(player: Player): number
	local state = gardens[player]
	if not state then
		return 0
	end
	commit(state)
	local count = 0
	for _, plant in state.plants do
		if not plant.ripe then
			ripen(state, plant, false)
			count += 1
		end
	end
	return count
end

local function growingCount(player: Player): number
	local state = gardens[player]
	if not state then
		return 0
	end
	local count = 0
	for _, plant in state.plants do
		if not plant.ripe then
			count += 1
		end
	end
	return count
end

local function useInstantGrow(player: Player, data: Profile): boolean
	if data.instantGrowCharges < 1 or growingCount(player) == 0 then
		return false
	end
	data.instantGrowCharges -= 1
	local count = Garden.ripenAll(player)
	Notify.player(player, `⏩ {count} slime(s) ripened instantly!`, "success")
	Sync.mark(player, "main")
	return true
end

local function onUseInstantGrow(player: Player)
	if not RateLimiter.allow(player, "UseInstantGrow", 1, 2) then
		return
	end
	local data = DataService.get(player)
	if data and not useInstantGrow(player, data) and data.instantGrowCharges > 0 then
		Notify.player(player, "Nothing is growing right now. Your Instant Grow is saved.", "info")
	end
end

local function onSetAutoHarvest(player: Player, rawEnabled: unknown)
	if not RateLimiter.allow(player, "SetAutoHarvest", 2, 4) then
		return
	end
	local enabled = Validate.boolean(rawEnabled)
	local data = DataService.get(player)
	if enabled == nil or not data then
		return
	end
	data.autoHarvest = enabled
	Sync.mark(player, "main")
end

-- Removes every plant (rebirth).
function Garden.clearAll(player: Player)
	local state = gardens[player]
	local data = DataService.get(player)
	if not state or not data then
		return
	end
	for tile in state.plants do
		removePlant(state, data, tile)
	end
	table.clear(data.plants)
end

local function growthTick()
	local t = now()
	for _, state in gardens do
		for _, plant in state.plants do
			if not plant.ripe and plant.data.e + (t - plant.lastCommit) * state.rate >= growTime(plant) then
				ripen(state, plant, false)
			end
		end
	end
end

local function weatherTick()
	local weatherId = Weather.current()
	if not weatherId then
		return
	end
	local mutation = Mutations.byWeather[weatherId]
	if not mutation then
		return
	end
	for player, state in gardens do
		local chance = Economy.weatherTickChance(mutation.chance, state.luck, Config.Weather.MutationTick)
		local gained = 0
		for _, plant in state.plants do
			if plant.ripe and not table.find(plant.data.m, mutation.id) and rng() < chance then
				table.insert(plant.data.m, mutation.id)
				buildModel(state, plant)
				gained += 1
			end
		end
		if gained > 0 then
			Notify.effect(player, "mutation", { mutation = mutation.id, count = gained })
		end
	end
end

local function autoHarvestTick()
	for player in gardens do
		local data = DataService.get(player)
		if data and data.autoHarvest and Monetization.owns(player, "auto_harvest") then
			if Garden.ripeCount(player) > 0 then
				Garden.harvestAll(player, false)
			end
		end
	end
end

function Garden.init()
	Monetization.registerProduct("instant_grow", function(player, data)
		data.instantGrowCharges += 1
		if not useInstantGrow(player, data) then
			Notify.player(
				player,
				"⏩ Instant Grow saved! Use it from the menu when slimes are growing.",
				"reward"
			)
		end
		return true
	end)

	DataService.addSaveHook(function(player)
		local state = gardens[player]
		if state then
			commit(state)
		end
	end)
end

function Garden.start()
	Plots.Assigned:Connect(setup)
	Plots.Released:Connect(teardown)
	DataService.ProfileReleased:Connect(teardown)

	Boosts.Changed:Connect(function(player, multipliers)
		local state = gardens[player]
		if not state then
			return
		end
		commit(state)
		state.rate = multipliers.growth
		state.luck = multipliers.luck
		for _, plant in state.plants do
			writeAttributes(state, plant)
		end
	end)

	Net.event("Plant").OnServerEvent:Connect(onPlant)
	Net.event("Harvest").OnServerEvent:Connect(onHarvest)
	Net.event("HarvestAll").OnServerEvent:Connect(onHarvestAll)
	Net.event("UseInstantGrow").OnServerEvent:Connect(onUseInstantGrow)
	Net.event("SetAutoHarvest").OnServerEvent:Connect(onSetAutoHarvest)

	task.spawn(function()
		local weatherAcc, autoAcc = 0, 0
		while true do
			local dt = task.wait(0.5)
			growthTick()
			weatherAcc += dt
			autoAcc += dt
			if weatherAcc >= Config.Weather.MutationTick then
				weatherAcc = 0
				weatherTick()
			end
			if autoAcc >= Config.Growth.AutoHarvestInterval then
				autoAcc = 0
				autoHarvestTick()
			end
		end
	end)
end

return Garden
