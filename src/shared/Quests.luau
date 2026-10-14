--!strict
-- Daily quests: three per UTC day, generated deterministically from the
-- player's id and the day so they survive rejoins and server hops.

local Economy = require(script.Parent.Economy)
local Rng = require(script.Parent.Rng)
local Types = require(script.Parent.Types)

type QuestData = Types.QuestData

export type Template = {
	kind: string,
	text: string,
	targets: { number }?,
	scaledUnits: { number }?,
	minTier: number?,
}

local Quests = {}

Quests.Kinds = {
	Harvest = "harvest",
	Plant = "plant",
	Sell = "sell",
	Mutated = "mutated",
	Buy = "buy",
	Rare = "rare",
}

local templates: { Template } = {
	{ kind = "harvest", text = "Harvest {n} slimes", targets = { 15, 30, 50 } },
	{ kind = "plant", text = "Plant {n} seeds", targets = { 15, 30 } },
	{ kind = "sell", text = "Earn {n} coins by selling", scaledUnits = { 30, 60 } },
	{ kind = "mutated", text = "Harvest {n} mutated slimes", targets = { 1, 3 } },
	{ kind = "buy", text = "Buy {n} seeds at the Seed Shop", targets = { 10, 20 } },
	{ kind = "rare", text = "Harvest {n} Rare-or-better slimes", targets = { 1, 2 }, minTier = 5 },
}

local byKind: { [string]: Template } = {}
for _, template in templates do
	byKind[template.kind] = template
end

Quests.templates = templates
Quests.byKind = byKind

local REWARD_UNITS = { 6, 8, 12 }

function Quests.dayNumber(unixTime: number): number
	return unixTime // 86400
end

function Quests.generate(day: number, userId: number, bestTier: number): { QuestData }
	local rng = Rng.new(Rng.hash(day, userId, 7919))
	local pool: { Template } = {}
	for _, template in templates do
		if (template.minTier or 0) <= bestTier then
			table.insert(pool, template)
		end
	end

	local unit = Economy.unit(bestTier)
	local quests: { QuestData } = {}
	for i = 1, 3 do
		local pick = math.floor(rng() * #pool) + 1
		local template = table.remove(pool, pick) :: Template
		local target
		if template.scaledUnits then
			local units = template.scaledUnits[math.floor(rng() * #template.scaledUnits) + 1]
			target = Economy.niceRound(units * unit)
		else
			local targets = template.targets :: { number }
			target = targets[math.floor(rng() * #targets) + 1]
		end
		table.insert(quests, {
			kind = template.kind,
			target = target,
			progress = 0,
			claimed = false,
			rewardCoins = Economy.niceRound(REWARD_UNITS[i] * unit),
			rewardItem = if i == 3 then (if day % 2 == 0 then "growth" else "luck") else nil,
		})
	end
	return quests
end

function Quests.describe(quest: QuestData, formatNumber: (number) -> string): string
	local template = byKind[quest.kind]
	if not template then
		return quest.kind
	end
	return (string.gsub(template.text, "{n}", formatNumber(quest.target)))
end

return Quests
