--[[
	RewardService  (ModuleScript)  ->  ServerScriptService/Services/RewardService
	Tägliche Belohnung (7-Tage-Serie), Tages-Quests, Spielzeit-Geschenke.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))
local Format = require(Shared:WaitForChild("Format"))

local RewardService = {}
local Services

local sessionStart = {} -- [player] = os.clock()
local giftsClaimed = {} -- [player] = { [index] = true }

local function today()
	return math.floor(os.time() / 86400)
end

local function scaledCash(player, seconds, minimum)
	local rate = Services.IncomeService.GetRate(player)
	return math.max(minimum or 0, math.floor(rate * seconds))
end

local function giveCash(player, data, amount, reason)
	data.Cash += amount
	data.TotalEarned += amount
	Services.Net.Notify(player, ("%s: +%s"):format(reason, Format.Money(amount)), "success", "Reward")
end

local function giveBoost(player, data, seconds, reason)
	data.Boost2xUntil = math.max(os.time(), data.Boost2xUntil) + seconds
	Services.Net.Notify(player, ("%s: ⚡ 2x Cash für %s"):format(reason, Format.Time(seconds)), "success", "Reward")
end

------------------------------------------------------------------------
-- Tägliche Belohnung
------------------------------------------------------------------------
function RewardService.GetDailyInfo(data)
	local day = today()
	local canClaim = data.Daily.LastDay < day
	local streak = data.Daily.Streak
	if canClaim and data.Daily.LastDay ~= day - 1 then
		streak = 0 -- Serie gerissen, beginnt wieder bei Tag 1
	end
	local nextIndex = (streak % #Config.Daily) + 1
	return {
		CanClaim = canClaim,
		Streak = streak,
		NextIndex = nextIndex,
		SecondsUntilNext = (day + 1) * 86400 - os.time(),
	}
end

local function claimDaily(player)
	local data = Services.DataService.Get(player)
	local info = RewardService.GetDailyInfo(data)
	if not info.CanClaim then
		return false, "Morgen wieder!"
	end
	data.Daily.Streak = info.Streak + 1
	data.Daily.LastDay = today()

	local reward = Config.Daily[info.NextIndex]
	local vipMult = Services.MonetizationService.HasPass(player, "VIP") and 2 or 1
	local reason = "Tag " .. info.NextIndex
	if reward.Type == "Cash" then
		giveCash(player, data, scaledCash(player, reward.Seconds, reward.Min) * vipMult, reason)
	elseif reward.Type == "Boost" then
		giveBoost(player, data, reward.Seconds * vipMult, reason)
	elseif reward.Type == "Figure" then
		local list = Figures.ByRarity[reward.Rarity]
		local fig = list[math.random(1, #list)]
		local slot = Services.BaseService.GiveFigure(player, fig.Id, "Normal")
		if slot then
			Services.Net.Effect(player, "Reveal", { Id = fig.Id, Mut = "Normal", Text = "TAG 7 BELOHNUNG!" })
		else
			giveCash(player, data, fig.Price, reason .. " (Basis voll)")
		end
	end
	Services.Net.Effect(player, "Confetti")
	Services.StateService.MarkDirty(player)
	return true
end

------------------------------------------------------------------------
-- Quests
------------------------------------------------------------------------
local function ensureQuests(player, data)
	local day = today()
	if data.Quests.Day == day and #data.Quests.List > 0 then
		return
	end
	local random = Random.new(day * 1000 + player.UserId % 1000)
	local pool = table.clone(Config.QuestPool)
	local list = {}
	for _ = 1, math.min(Config.QuestsPerDay, #pool) do
		local quest = table.remove(pool, random:NextInteger(1, #pool))
		table.insert(list, { Key = quest.Key, Goal = quest.Goal, Progress = 0, Claimed = false })
	end
	data.Quests = { Day = day, List = list }
end

local function questDef(key)
	for _, quest in ipairs(Config.QuestPool) do
		if quest.Key == key then
			return quest
		end
	end
	return nil
end

function RewardService.GetQuests(player)
	local data = Services.DataService.Get(player)
	if not data then
		return {}
	end
	ensureQuests(player, data)
	local result = {}
	for i, quest in ipairs(data.Quests.List) do
		local def = questDef(quest.Key)
		if def then
			table.insert(result, {
				Index = i,
				Text = def.Text,
				Goal = quest.Goal,
				Progress = quest.Progress,
				Claimed = quest.Claimed,
				Reward = scaledCash(player, def.Seconds, def.Min),
			})
		end
	end
	return result
end

function RewardService.AddProgress(player, key, amount)
	local data = Services.DataService.Get(player)
	if not data then
		return
	end
	ensureQuests(player, data)
	for _, quest in ipairs(data.Quests.List) do
		if quest.Key == key and not quest.Claimed and quest.Progress < quest.Goal then
			quest.Progress = math.min(quest.Goal, quest.Progress + amount)
			if quest.Progress >= quest.Goal then
				Services.Net.Notify(player, "✅ Quest erledigt! Hol dir deine Belohnung.", "success", "Reward")
			end
			Services.StateService.MarkDirty(player)
		end
	end
end

local function claimQuest(player, index)
	local data = Services.DataService.Get(player)
	ensureQuests(player, data)
	index = tonumber(index)
	local quest = index and data.Quests.List[index]
	if not quest or quest.Claimed or quest.Progress < quest.Goal then
		return false, "Noch nicht fertig"
	end
	local def = questDef(quest.Key)
	quest.Claimed = true
	giveCash(player, data, scaledCash(player, def.Seconds, def.Min), "Quest")
	Services.StateService.MarkDirty(player)
	return true
end

------------------------------------------------------------------------
-- Spielzeit-Geschenke
------------------------------------------------------------------------
function RewardService.GetGifts(player)
	local start = sessionStart[player] or os.clock()
	local elapsed = os.clock() - start
	local claimed = giftsClaimed[player] or {}
	local result = {}
	for i, gift in ipairs(Config.PlaytimeGifts) do
		table.insert(result, {
			Index = i,
			Remaining = math.max(0, gift.Minutes * 60 - elapsed),
			Claimed = claimed[i] == true,
			Label = gift.Boost and ("⚡ 2x " .. Format.Time(gift.Boost)) or Format.Money(scaledCash(player, gift.Seconds, gift.Min)),
		})
	end
	return result
end

local function claimGift(player, index)
	index = tonumber(index)
	local gift = index and Config.PlaytimeGifts[index]
	if not gift then
		return false
	end
	local claimed = giftsClaimed[player]
	if not claimed or claimed[index] then
		return false, "Schon abgeholt"
	end
	if os.clock() - (sessionStart[player] or os.clock()) < gift.Minutes * 60 - 1 then
		return false, "Noch nicht bereit"
	end
	claimed[index] = true
	local data = Services.DataService.Get(player)
	if gift.Boost then
		giveBoost(player, data, gift.Boost, "Geschenk")
	else
		giveCash(player, data, scaledCash(player, gift.Seconds, gift.Min), "Geschenk")
	end
	Services.StateService.MarkDirty(player)
	return true
end

------------------------------------------------------------------------
function RewardService.Init(services)
	Services = services
end

function RewardService.Start()
	Services.Net.Register("ClaimDaily", claimDaily, 2)
	Services.Net.Register("ClaimQuest", claimQuest, 3)
	Services.Net.Register("ClaimGift", claimGift, 3)

	Services.DataService.OnLoaded(function(player, data)
		sessionStart[player] = os.clock()
		giftsClaimed[player] = {}
		ensureQuests(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessionStart[player] = nil
		giftsClaimed[player] = nil
	end)
end

return RewardService
