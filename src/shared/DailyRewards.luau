--!strict
-- Seven-day login streak. Missing a day restarts the streak at day 1; the
-- cycle repeats after day 7. Rewards scale with progress.

local Economy = require(script.Parent.Economy)
local Format = require(script.Parent.Format)
local Species = require(script.Parent.Species)

export type RewardDef = {
	kind: "coins" | "seeds" | "potion" | "prism",
	units: number?,
	amount: number?,
	tierOffset: number?,
	potion: string?,
}

export type Reward = {
	label: string,
	icon: string,
	coins: number,
	seeds: { [string]: number },
	potions: { [string]: number },
}

local DailyRewards = {}

DailyRewards.cycle = {
	{ kind = "coins", units = 10 },
	{ kind = "seeds", tierOffset = 0, amount = 3 },
	{ kind = "potion", potion = "growth", amount = 1 },
	{ kind = "coins", units = 25 },
	{ kind = "potion", potion = "luck", amount = 1 },
	{ kind = "seeds", tierOffset = 1, amount = 2 },
	{ kind = "prism", amount = 1, units = 60 },
} :: { RewardDef }

function DailyRewards.dayNumber(unixTime: number): number
	return unixTime // 86400
end

export type Status = {
	canClaim: boolean,
	nextStreak: number, -- streak value after the next claim
	cycleDay: number, -- 1..7 reward slot of the next claim
}

function DailyRewards.status(lastClaimDay: number, streak: number, today: number): Status
	if lastClaimDay == today then
		local cycleDay = (streak % #DailyRewards.cycle) + 1
		return { canClaim = false, nextStreak = streak + 1, cycleDay = cycleDay }
	end
	local nextStreak = if lastClaimDay == today - 1 then streak + 1 else 1
	return {
		canClaim = true,
		nextStreak = nextStreak,
		cycleDay = ((nextStreak - 1) % #DailyRewards.cycle) + 1,
	}
end

local function seedTier(bestTier: number, offset: number): number
	-- Never hand out Cosmic seeds (rebirth-locked) or tier-1 filler.
	return math.clamp(bestTier + offset, 2, Species.MaxTier - 1)
end

function DailyRewards.resolve(cycleDay: number, bestTier: number): Reward
	local def = DailyRewards.cycle[cycleDay]
	local unit = Economy.unit(bestTier)
	local reward: Reward = { label = "", icon = "🎁", coins = 0, seeds = {}, potions = {} }
	if def.kind == "coins" then
		reward.coins = Economy.niceRound((def.units or 0) * unit)
		reward.icon = "🪙"
	elseif def.kind == "seeds" then
		local species = Species.byTier[seedTier(bestTier, def.tierOffset or 0)]
		reward.seeds[species.id] = def.amount or 1
		reward.icon = "🌱"
	elseif def.kind == "potion" then
		reward.potions[def.potion or "growth"] = def.amount or 1
		reward.icon = if def.potion == "luck" then "🔮" else "🧪"
	elseif def.kind == "prism" then
		reward.seeds.prism = def.amount or 1
		reward.coins = Economy.niceRound((def.units or 0) * unit)
		reward.icon = "🌈"
	end

	local parts = {}
	if reward.coins > 0 then
		table.insert(parts, `{Format.short(reward.coins)} coins`)
	end
	for id, count in reward.seeds do
		local species = Species.byId[id]
		table.insert(parts, `{count}x {if species then species.name else id} Seed`)
	end
	for potion, count in reward.potions do
		table.insert(parts, `{count}x {if potion == "luck" then "Luck" else "Growth"} Potion`)
	end
	reward.label = table.concat(parts, " + ")
	return reward
end

return DailyRewards
