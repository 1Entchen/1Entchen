--!strict
-- Five-step onboarding driven by real gameplay events:
--   0 plant -> 1 wait for growth -> 2 harvest -> 3 sell -> 4 buy a seed -> 5 done
-- Each step is logged to the onboarding funnel in Creator Analytics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local Notify = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Notify"))

local Analytics = require(script.Parent.Analytics)
local Monetization = require(script.Parent.Monetization)
local Sync = require(script.Parent.Sync)

type Profile = Types.Profile

local Tutorial = {}

Tutorial.DONE = 5

local STEP_NAMES = { "Plant", "Grow", "Harvest", "Sell", "BuySeed", "Complete" }

-- event -> { fromStep, toStep }
local TRANSITIONS: { [string]: { number } } = {
	planted = { 0, 1 },
	ripe = { 1, 2 },
	harvested = { 2, 3 },
	sold = { 3, 4 },
	bought = { 4, 5 },
}

local function setStep(player: Player, data: Profile, step: number)
	data.tutorialStep = step
	Analytics.onboarding(player, step + 1, STEP_NAMES[step + 1])
	if step == Tutorial.DONE then
		data.potions.growth = (data.potions.growth or 0) + 1
		data.coins += 50
		Notify.player(player, "🎉 Tutorial complete! You got a Growth Potion and 50 coins.", "reward")
	end
	Sync.mark(player, "main")
end

function Tutorial.event(player: Player, data: Profile, event: string)
	local transition = TRANSITIONS[event]
	if not transition or data.tutorialStep >= Tutorial.DONE then
		return
	end
	local from, to = transition[1], transition[2]
	if data.tutorialStep == from then
		setStep(player, data, to)
	elseif event == "harvested" and data.tutorialStep < 2 then
		-- harvested a slime that ripened while we weren't watching
		setStep(player, data, 3)
	end
end

function Tutorial.onReady(player: Player, data: Profile)
	if data.tutorialStep >= Tutorial.DONE then
		return
	end
	if data.tutorialStep == 0 then
		Analytics.onboarding(player, 1, STEP_NAMES[1])
	end
	-- Never strand a new player without a seed to plant.
	local hasSeeds = next(data.seeds) ~= nil
	if not hasSeeds and #data.plants == 0 and #data.slimes == 0 and data.coins < 10 then
		data.seeds.goo = 1
		Sync.mark(player, "main")
	end
end

function Tutorial.start()
	Monetization.PlayerReady:Connect(Tutorial.onReady)
end

return Tutorial
