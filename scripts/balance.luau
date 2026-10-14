--!nocheck
-- Economy pacing simulator: a reasonable free player (no purchases, no
-- mutations counted) playing continuously. Prints when each milestone is
-- reached so balance changes in Species/Economy can be evaluated quickly.
-- Usage: lune run scripts/balance.luau [minutes] [seed]

local process = require("@lune/process")
local Env = require("../tests/harness/Env")

local env = Env.new()
local Economy = env.require(env.shared.Economy)
local Species = env.require(env.shared.Species)
local Stock = env.require(env.shared.Stock)
local Rng = env.require(env.shared.Rng)
local Config = env.require(env.shared.Config)

local minutes = tonumber(process.args[1]) or 120
local rng = Rng.new(tonumber(process.args[2]) or 7)

local coins, tiles, bestTier = 30, Config.Plots.StartingTiles, 1
local seeds = { goo = 3 }
local plants = {} -- { s, ready }
local backpack = 0
local stock, bought = {}, {}
local milestones = {}
local function mark(label, t)
	if not milestones[label] then
		milestones[label] = t
		print(string.format("%6.1f min  %s  (coins %s, tiles %d)", t / 60, label, Economy.niceRound(coins), tiles))
	end
end

local SELL_TRIP = 20 -- seconds walking to sell and back
local nextSell = 0
for t = 0, minutes * 60 do
	if t % Config.Shop.RestockInterval == 0 then
		stock, bought = Stock.roll(rng), {}
	end
	-- harvest
	for i = #plants, 1, -1 do
		if plants[i].ready <= t then
			backpack += Economy.slimeValue({ s = plants[i].s, w = 1.12, m = {} }, 1)
			table.remove(plants, i)
		end
	end
	-- sell + shop trip
	local idle = #plants < tiles and next(seeds) == nil
	if t >= nextSell and (backpack > 0 or idle) then
		coins += backpack
		backpack = 0
		nextSell = t + SELL_TRIP
		-- unlock tiles while cheap relative to savings
		while tiles < Config.Plots.FreeTileLimit and coins >= 3 * Economy.tileCost(tiles + 1) do
			coins -= Economy.tileCost(tiles + 1)
			tiles += 1
			mark("tiles " .. tiles, t)
		end
		-- buy best seeds first, enough to keep every tile busy
		for tier = Species.MaxTier, 1, -1 do
			local species = Species.byTier[tier]
			local have = 0
			for _, count in seeds do
				have += count
			end
			local want = tiles * 2 - have
			local left = (stock[species.id] or 0) - (bought[species.id] or 0)
			local n = math.min(left, math.floor(coins / species.price), math.max(want, 0))
			if n > 0 and species.requiresRebirth == 0 then
				coins -= n * species.price
				seeds[species.id] = (seeds[species.id] or 0) + n
				bought[species.id] = (bought[species.id] or 0) + n
				mark("first " .. species.name, t)
			end
		end
	end
	-- plant best seeds first
	while #plants < tiles do
		local best
		for id, count in seeds do
			if count > 0 and (not best or Species.byId[id].tier > Species.byId[best].tier) then
				best = id
			end
		end
		if not best then
			break
		end
		seeds[best] -= 1
		if seeds[best] == 0 then
			seeds[best] = nil
		end
		table.insert(plants, { s = best, ready = t + Species.byId[best].growTime })
	end
	if t == 60 or t == 300 or t == 600 or t == 1800 or t == 3600 or t == 7200 then
		print(string.format("%6.1f min  -- coins %s, tiles %d", t / 60, Economy.niceRound(coins), tiles))
	end
	if coins >= Economy.rebirthCost(0) then
		mark("can afford Rebirth 1", t)
	end
end
