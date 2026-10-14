--!strict
-- Pure economy math shared by server (authoritative) and client (display
-- only). No Roblox services here so it can be unit tested under Lune.

local Config = require(script.Parent.Config)
local Mutations = require(script.Parent.Mutations)
local Products = require(script.Parent.Products)
local Species = require(script.Parent.Species)

type SlimeLike = { s: string, w: number, m: { string }, b: number? }

local Economy = {}

-- Rounds to two significant digits so prices read cleanly (1,641 -> 1,600).
function Economy.niceRound(n: number): number
	if n < 100 then
		return math.floor(n + 0.5)
	end
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / magnitude + 0.5) * magnitude
end

function Economy.tileCost(tileIndex: number): number
	local first = Config.Plots.StartingTiles + 1
	if tileIndex < first then
		return 0
	end
	return Economy.niceRound(100 * 1.75 ^ (tileIndex - first))
end

function Economy.startingTiles(rebirths: number): number
	return Config.Plots.StartingTiles + math.min(rebirths, Config.Plots.MaxRebirthBonusTiles)
end

function Economy.totalTiles(unlockedTiles: number, hasBigGarden: boolean): number
	local tiles = math.clamp(unlockedTiles, 0, Config.Plots.FreeTileLimit)
	if hasBigGarden then
		tiles += Config.Plots.PassTiles
	end
	return tiles
end

-- A tile index is plantable if it is among the coin-unlocked tiles, or in the
-- pass-only row while the player owns Big Garden.
function Economy.isTileUsable(tileIndex: number, unlockedTiles: number, hasBigGarden: boolean): boolean
	if tileIndex < 1 or tileIndex ~= math.floor(tileIndex) then
		return false
	end
	if tileIndex <= Config.Plots.FreeTileLimit then
		return tileIndex <= unlockedTiles
	end
	return hasBigGarden and tileIndex <= Config.Plots.FreeTileLimit + Config.Plots.PassTiles
end

function Economy.rebirthCost(rebirths: number): number
	return Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths
end

-- Scaling unit for rewards and coin packs: the value of the best slime the
-- player has grown, so rewards stay meaningful at every stage.
function Economy.unit(bestTier: number): number
	local species = Species.byTier[math.clamp(bestTier, 1, Species.MaxTier)]
	return math.max(24, species.value)
end

function Economy.coinPackAmount(packKey: string, bestTier: number): number
	local units = Products.CoinPackUnits[packKey]
	assert(units, `unknown coin pack {packKey}`)
	return Economy.niceRound(units * Economy.unit(bestTier))
end

function Economy.prismBaseValue(bestTier: number): number
	return Economy.niceRound(8 * Economy.unit(bestTier))
end

function Economy.mutationMultiplier(mutations: { string }): number
	local multiplier = 1
	for _, id in mutations do
		local mutation = Mutations.byId[id]
		if mutation then
			multiplier *= mutation.multiplier
		end
	end
	return multiplier
end

function Economy.baseValue(slime: SlimeLike): number
	if slime.b then
		return slime.b
	end
	local species = Species.byId[slime.s]
	return if species then species.value else 0
end

function Economy.slimeValue(slime: SlimeLike, sellMultiplier: number): number
	return math.floor(
		Economy.baseValue(slime) * slime.w * Economy.mutationMultiplier(slime.m) * sellMultiplier
	)
end

-- Weight distribution: 0.5% Titanic, 4% Huge, 20% Big, otherwise Normal.
-- `rng` returns uniform numbers in [0, 1).
function Economy.rollWeight(rng: () -> number): number
	local roll = rng()
	local low, high
	if roll < 0.005 then
		low, high = 4, 6
	elseif roll < 0.045 then
		low, high = 2, 4
	elseif roll < 0.245 then
		low, high = 1.25, 2
	else
		low, high = 0.8, 1.25
	end
	local weight = low + (high - low) * rng()
	return math.floor(weight * 100 + 0.5) / 100
end

function Economy.weightLabel(weight: number): string?
	if weight >= 4 then
		return "Titanic"
	elseif weight >= 2 then
		return "Huge"
	elseif weight >= 1.25 then
		return "Big"
	end
	return nil
end

function Economy.visualSize(weight: number): number
	return math.clamp(weight, 0.5, 8) ^ 0.45
end

-- Rolls at most one variant, rarest first. Luck multiplies every chance.
function Economy.rollVariant(rng: () -> number, luck: number): string?
	for _, mutation in Mutations.variants do
		if rng() < math.min(mutation.chance * luck, 0.5) then
			return mutation.id
		end
	end
	return nil
end

-- Converts a per-minute weather mutation chance into the chance for one tick.
function Economy.weatherTickChance(perMinute: number, luck: number, tickSeconds: number): number
	local perMinuteBoosted = math.min(perMinute * luck, 0.95)
	return 1 - (1 - perMinuteBoosted) ^ (tickSeconds / 60)
end

export type BonusInputs = {
	rebirths: number,
	doubleCoins: boolean,
	vip: boolean,
	premium: boolean,
	friends: number,
	inGroup: boolean,
}

function Economy.sellMultiplier(inputs: BonusInputs): number
	local additive = 1
	if inputs.vip then
		additive += Config.Bonuses.VipBonus
	end
	if inputs.premium then
		additive += Config.Bonuses.PremiumBonus
	end
	if inputs.inGroup then
		additive += Config.Bonuses.GroupBonus
	end
	additive += Config.Bonuses.FriendBonus * math.clamp(inputs.friends, 0, Config.Bonuses.MaxFriends)
	local rebirth = 1 + Config.Bonuses.RebirthBonus * inputs.rebirths
	local double = if inputs.doubleCoins then 2 else 1
	return additive * rebirth * double
end

function Economy.growthRate(fastGrow: boolean, potion: boolean, weatherMultiplier: number): number
	local rate = 1
	if fastGrow then
		rate *= Config.Bonuses.FastGrowMultiplier
	end
	if potion then
		rate *= Config.Boosts.GrowthPotionMultiplier
	end
	return rate * weatherMultiplier
end

function Economy.luck(luckyPass: boolean, potion: boolean): number
	local luck = 1
	if luckyPass then
		luck *= 2
	end
	if potion then
		luck *= Config.Boosts.LuckPotionMultiplier
	end
	return math.min(luck, Config.Boosts.MaxLuck)
end

function Economy.backpackCapacity(vip: boolean): number
	return Config.Backpack.BaseCapacity + (if vip then Config.Backpack.VipBonus else 0)
end

-- Growth time for a plant (exclusive species use their own catalog time).
function Economy.growTime(speciesId: string): number
	local species = Species.byId[speciesId]
	return if species then species.growTime else math.huge
end

-- Rarity tier used for announcements / quests; exclusives count as epic.
function Economy.effectiveTier(speciesId: string): number
	local species = Species.byId[speciesId]
	if not species then
		return 0
	end
	return if species.tier == 0 then 7 else species.tier
end

return Economy
