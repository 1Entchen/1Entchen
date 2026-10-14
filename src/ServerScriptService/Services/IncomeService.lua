--[[
	IncomeService  (ModuleScript)  ->  ServerScriptService/Services/IncomeService
	Passives Einkommen (jede Sekunde), Cash-Pad einsammeln, Offline-Einkommen,
	alle Multiplikatoren, leaderstats.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))
local Format = require(Shared:WaitForChild("Format"))

local IncomeService = {}
local Services

local inGroup = {} -- [player] = bool
local friendCount = {} -- [player] = number
local leaderstats = {} -- [player] = { Cash = StringValue, Rebirths = IntValue }

function IncomeService.GetBaseIncome(data)
	local total = 0
	for _, slot in pairs(data.Slots) do
		total += Figures.Income(slot.Id, slot.Mut)
	end
	return total
end

function IncomeService.GetIndexBonus(data)
	local unique = {}
	local count = 0
	for key in pairs(data.Index) do
		local id = tonumber(string.match(key, "^(%d+)_"))
		if id and not unique[id] then
			unique[id] = true
			count += 1
		end
	end
	for _, tier in ipairs(Config.IndexBonus) do
		if count >= tier.Count then
			return tier.Bonus, count
		end
	end
	return 0, count
end

-- Gesamt-Multiplikator + Aufschlüsselung für die UI
function IncomeService.GetMultiplier(player)
	local data = Services.DataService.Get(player)
	if not data then
		return 1, {}
	end
	local M = Config.Multipliers
	local Monetization = Services.MonetizationService
	local parts = {}
	local mult = 1

	local rebirth = 1 + M.RebirthPer * data.Rebirths
	mult *= rebirth
	if data.Rebirths > 0 then
		table.insert(parts, ("⭐ Rebirth x%.1f"):format(rebirth))
	end
	if Monetization.HasPass(player, "DoubleCash") then
		mult *= M.DoubleCash
		table.insert(parts, "💰 2x Cash")
	end
	if Monetization.HasPass(player, "VIP") then
		mult *= M.VIP
		table.insert(parts, "👑 VIP +10%")
	end
	if Monetization.IsPremium(player) then
		mult *= M.Premium
		table.insert(parts, "Premium +10%")
	end
	if inGroup[player] then
		mult *= M.Group
		table.insert(parts, "👥 Gruppe +10%")
	end
	local friends = math.min(friendCount[player] or 0, M.FriendMax)
	if friends > 0 then
		mult *= 1 + M.FriendPer * friends
		table.insert(parts, ("🤝 %d Freunde +%d%%"):format(friends, friends * 10))
	end
	local indexBonus = IncomeService.GetIndexBonus(data)
	if indexBonus > 0 then
		mult *= 1 + indexBonus
		table.insert(parts, ("📖 Index +%d%%"):format(indexBonus * 100))
	end
	if data.Boost2xUntil > os.time() then
		mult *= M.Boost
		table.insert(parts, "⚡ Boost 2x")
	end
	local eventMult = Services.EventService.GetCashMult()
	if eventMult > 1 then
		mult *= eventMult
		table.insert(parts, ("🎉 Event x%s"):format(eventMult))
	end
	return mult, parts
end

function IncomeService.GetRate(player)
	local data = Services.DataService.Get(player)
	if not data then
		return 0
	end
	return IncomeService.GetBaseIncome(data) * IncomeService.GetMultiplier(player)
end

function IncomeService.Collect(player)
	local data = Services.DataService.Get(player)
	if not data or data.Pending < 1 then
		return
	end
	local amount = math.floor(data.Pending)
	data.Cash += amount
	data.Pending -= amount
	Services.Net.Notify(player, "+" .. Format.Money(amount), "cash", "Cash")
	Services.RewardService.AddProgress(player, "Collect", 1)
	Services.BaseService.UpdateCashPad(player, data.Pending)
	Services.StateService.MarkDirty(player)
end

local function giveOffline(player, data)
	if data.LastOnline <= 0 then
		return
	end
	local away = os.time() - data.LastOnline
	if away < Config.Offline.MinSeconds then
		return
	end
	local isVip = Services.MonetizationService.HasPass(player, "VIP")
	local ratio = isVip and Config.Offline.VipRatio or Config.Offline.Ratio
	local maxSeconds = isVip and Config.Offline.VipMaxSeconds or Config.Offline.MaxSeconds
	local amount = math.floor(IncomeService.GetRate(player) * ratio * math.min(away, maxSeconds))
	if amount < 1 then
		return
	end
	data.Cash += amount
	data.TotalEarned += amount
	data.OfflineReward = { Amount = amount, Boosted = false }
	Services.Net.Effect(player, "Offline", { Amount = amount, Away = away, Vip = isVip })
end

local function setupLeaderstats(player, data)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = Format.Money(data.Cash)
	cash.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.Rebirths
	rebirths.Parent = folder
	folder.Parent = player
	leaderstats[player] = { Cash = cash, Rebirths = rebirths }
end

local function refreshFriends()
	local list = Services.DataService.GetLoadedPlayers()
	for _, player in ipairs(list) do
		local count = 0
		for _, other in ipairs(list) do
			if other ~= player then
				local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and isFriend then
					count += 1
				end
			end
		end
		friendCount[player] = count
	end
end

function IncomeService.Init(services)
	Services = services
end

function IncomeService.Start()
	Services.DataService.OnLoaded(function(player, data)
		if Config.GroupId > 0 then
			local ok, member = pcall(player.IsInGroup, player, Config.GroupId)
			inGroup[player] = ok and member or false
		end
		setupLeaderstats(player, data)
		giveOffline(player, data)
		task.spawn(refreshFriends)
	end)

	Players.PlayerRemoving:Connect(function(player)
		inGroup[player] = nil
		friendCount[player] = nil
		leaderstats[player] = nil
	end)

	-- Einkommens-Tick
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Services.DataService.GetLoadedPlayers()) do
				local data = Services.DataService.Get(player)
				if data then
					local rate = IncomeService.GetRate(player)
					if Services.MonetizationService.HasPass(player, "AutoCollect") then
						data.Cash += rate
					else
						data.Pending += rate
					end
					data.TotalEarned += rate
					data.Stats.PlayTime += 1
					if data.Stats.PlayTime % 60 == 0 then
						Services.RewardService.AddProgress(player, "Play", 1)
					end
					Services.BaseService.UpdateCashPad(player, data.Pending)
					local stats = leaderstats[player]
					if stats then
						stats.Cash.Value = Format.Money(data.Cash)
						stats.Rebirths.Value = data.Rebirths
					end
					Services.StateService.MarkDirty(player)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(30)
			refreshFriends()
		end
	end)
end

return IncomeService
