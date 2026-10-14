--!strict
-- Slimepedia: records each species and species+mutation combination a
-- player has harvested. First discoveries pay a one-time coin bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Mutations = require(Shared:WaitForChild("Mutations"))
local Species = require(Shared:WaitForChild("Species"))
local Types = require(Shared:WaitForChild("Types"))

local Notify = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Notify"))

local Analytics = require(script.Parent.Analytics)

type Profile = Types.Profile
type SlimeData = Types.SlimeData

local Index = {}

local SPECIES_REWARD_UNITS = 5
local MUTATION_REWARD_UNITS = 2

function Index.discover(player: Player, data: Profile, slime: SlimeData)
	local species = Species.byId[slime.s]
	if not species then
		return
	end
	local reward = 0
	local messages = {}
	if not data.index[slime.s] then
		data.index[slime.s] = true
		reward += Economy.niceRound(SPECIES_REWARD_UNITS * math.max(Economy.baseValue(slime), 20))
		table.insert(messages, `📖 New species: {species.name}!`)
		Analytics.custom(player, "Discover_" .. slime.s)
	end
	for _, mutationId in slime.m do
		local key = `{slime.s}:{mutationId}`
		local mutation = Mutations.byId[mutationId]
		if mutation and not data.index[key] then
			data.index[key] = true
			reward += Economy.niceRound(MUTATION_REWARD_UNITS * math.max(Economy.baseValue(slime), 20))
			table.insert(messages, `📖 New variant: {mutation.name} {species.name}!`)
		end
	end
	if reward > 0 then
		data.coins += reward
		Analytics.coinSource(
			player,
			reward,
			data.coins,
			Enum.AnalyticsEconomyTransactionType.Gameplay,
			"index_discovery"
		)
		Notify.player(player, `{table.concat(messages, " ")} +{Format.short(reward)} coins`, "reward")
	end
end

return Index
