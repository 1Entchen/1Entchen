--!strict
-- Daily login streak rewards and daily quests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyRewards = require(Shared:WaitForChild("DailyRewards"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Quests = require(Shared:WaitForChild("Quests"))
local Types = require(Shared:WaitForChild("Types"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Notify = require(Util:WaitForChild("Notify"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))
local Validate = require(Util:WaitForChild("Validate"))

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Sync = require(script.Parent.Sync)

type Profile = Types.Profile

local Retention = {}

local function today(): number
	return DailyRewards.dayNumber(os.time())
end

local function ensureQuests(player: Player, data: Profile)
	local day = Quests.dayNumber(os.time())
	if data.quests.day ~= day then
		data.quests = { day = day, list = Quests.generate(day, player.UserId, data.bestTier) }
	end
end

function Retention.progress(player: Player, data: Profile, kind: string, amount: number)
	ensureQuests(player, data)
	local changed = false
	for _, quest in data.quests.list do
		if quest.kind == kind and not quest.claimed and quest.progress < quest.target then
			quest.progress = math.min(quest.target, quest.progress + amount)
			changed = true
			if quest.progress >= quest.target then
				Notify.player(player, "📜 Quest complete! Claim your reward.", "success")
			end
		end
	end
	if changed then
		Sync.mark(player, "daily")
	end
end

local function grantReward(
	player: Player,
	data: Profile,
	coins: number,
	seeds: { [string]: number },
	potions: { [string]: number },
	sku: string
)
	if coins > 0 then
		data.coins += coins
		Analytics.coinSource(player, coins, data.coins, Enum.AnalyticsEconomyTransactionType.TimedReward, sku)
	end
	for id, count in seeds do
		data.seeds[id] = (data.seeds[id] or 0) + count
	end
	for id, count in potions do
		data.potions[id] = (data.potions[id] or 0) + count
	end
end

local function onClaimDaily(player: Player)
	if not RateLimiter.allow(player, "ClaimDaily", 1, 3) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local day = today()
	local status = DailyRewards.status(data.daily.lastClaimDay, data.daily.streak, day)
	if not status.canClaim then
		return
	end
	local reward = DailyRewards.resolve(status.cycleDay, data.bestTier)
	data.daily.lastClaimDay = day
	data.daily.streak = status.nextStreak
	grantReward(player, data, reward.coins, reward.seeds, reward.potions, `daily_{status.cycleDay}`)
	Analytics.custom(player, "DailyClaim", status.nextStreak)
	Notify.player(player, `🎁 Day {status.cycleDay} reward: {reward.label}`, "reward")
	Notify.effect(player, "reward", { icon = reward.icon })
	Sync.mark(player, "main")
	Sync.mark(player, "daily")
end

local function onClaimQuest(player: Player, rawIndex: unknown)
	if not RateLimiter.allow(player, "ClaimQuest", 2, 4) then
		return
	end
	local data = DataService.get(player)
	local index = Validate.integer(rawIndex, 1, 3)
	if not data or not index then
		return
	end
	ensureQuests(player, data)
	local quest = data.quests.list[index]
	if not quest or quest.claimed or quest.progress < quest.target then
		return
	end
	quest.claimed = true
	local potions = {}
	if quest.rewardItem then
		potions[quest.rewardItem] = 1
	end
	grantReward(player, data, quest.rewardCoins, {}, potions, `quest_{quest.kind}`)
	Analytics.custom(player, "QuestClaim_" .. quest.kind, index)
	local extra = if quest.rewardItem
		then ` + 1 {if quest.rewardItem == "luck" then "Luck" else "Growth"} Potion`
		else ""
	Notify.player(player, `📜 Quest reward: {Format.short(quest.rewardCoins)} coins{extra}`, "reward")
	Sync.mark(player, "main")
	Sync.mark(player, "daily")
end

local function buildSection(player: Player, data: Profile): any
	ensureQuests(player, data)
	local day = today()
	local status = DailyRewards.status(data.daily.lastClaimDay, data.daily.streak, day)
	local preview = {}
	for cycleDay = 1, #DailyRewards.cycle do
		local reward = DailyRewards.resolve(cycleDay, data.bestTier)
		preview[cycleDay] = { label = reward.label, icon = reward.icon }
	end
	local quests = {}
	for i, quest in data.quests.list do
		quests[i] = {
			text = Quests.describe(quest, Format.short),
			progress = quest.progress,
			target = quest.target,
			claimed = quest.claimed,
			rewardCoins = quest.rewardCoins,
			rewardItem = quest.rewardItem,
		}
	end
	return {
		canClaim = status.canClaim,
		cycleDay = status.cycleDay,
		streak = data.daily.streak,
		preview = preview,
		quests = quests,
		secondsToReset = 86400 - (os.time() % 86400),
	}
end

function Retention.init()
	Sync.register("daily", buildSection)
end

function Retention.start()
	Net.event("ClaimDaily").OnServerEvent:Connect(onClaimDaily)
	Net.event("ClaimQuest").OnServerEvent:Connect(onClaimQuest)

	-- Refresh at UTC midnight so new quests / rewards appear without rejoining.
	task.spawn(function()
		local lastDay = today()
		while true do
			task.wait(15)
			local day = today()
			if day ~= lastDay then
				lastDay = day
				for _, player in Players:GetPlayers() do
					if DataService.get(player) then
						Sync.mark(player, "daily")
						Notify.player(
							player,
							"🌅 A new day! Fresh quests and your daily reward are ready.",
							"info"
						)
					end
				end
			end
		end
	end)
end

return Retention
