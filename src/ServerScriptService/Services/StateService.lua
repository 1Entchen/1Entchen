--[[
	StateService  (ModuleScript)  ->  ServerScriptService/Services/StateService
	Baut den Zustand für die UI und schickt ihn an den Client, sobald sich etwas ändert.
	Der Client bekommt nur Anzeige-Daten; er kann damit nichts verändern.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))

local StateService = {}
local Services

local dirty = {}
local joinClock = {}

function StateService.MarkDirty(player)
	dirty[player] = true
end

function StateService.Build(player)
	local data = Services.DataService.Get(player)
	if not data then
		return nil
	end
	local S = Services
	local slots = {}
	for i = 1, 21 do
		local slot = data.Slots[tostring(i)]
		local unlocked = S.BaseService.IsSlotUnlocked(player, i)
		table.insert(slots, {
			Index = i,
			Unlocked = unlocked,
			Id = slot and slot.Id or nil,
			Mut = slot and slot.Mut or nil,
			BeingStolen = slot and S.StealService.IsBeingStolen(player, i) or false,
		})
	end

	local index = {}
	for key in pairs(data.Index) do
		table.insert(index, key)
	end

	local mult, multParts = S.IncomeService.GetMultiplier(player)
	local indexBonus, indexCount = S.IncomeService.GetIndexBonus(data)
	local event = S.EventService.GetInfo()

	return {
		Cash = math.floor(data.Cash),
		Pending = math.floor(data.Pending),
		Rate = S.IncomeService.GetRate(player),
		BaseIncome = S.IncomeService.GetBaseIncome(data),
		Mult = mult,
		MultParts = multParts,
		TotalEarned = math.floor(data.TotalEarned),
		Rebirths = data.Rebirths,
		Rebirth = S.RebirthService.GetInfo(data),
		Slots = slots,
		Capacity = S.BaseService.GetCapacity(player),
		Index = index,
		IndexCount = indexCount,
		IndexBonus = indexBonus,
		Daily = S.RewardService.GetDailyInfo(data),
		Quests = S.RewardService.GetQuests(player),
		Gifts = S.RewardService.GetGifts(player),
		Passes = S.MonetizationService.GetOwnedPasses(player),
		Premium = S.MonetizationService.IsPremium(player),
		BoostRemaining = math.max(0, data.Boost2xUntil - os.time()),
		LuckRemaining = S.ConveyorService.GetLuckRemaining(),
		Lucky = S.ConveyorService.IsLucky(),
		LockRemaining = S.BaseService.GetLockRemaining(player),
		LockDuration = S.BaseService.GetLockDuration(player),
		Protection = S.StealService.GetProtectionRemaining(player),
		Carrying = S.StealService.IsCarrying(player),
		Event = event,
		StarterBought = data.StarterBought,
		OfflineReward = data.OfflineReward,
		SessionTime = os.clock() - (joinClock[player] or os.clock()),
		RobuxSpent = data.Stats.RobuxSpent,
		CashPacks = (function()
			local packs = {}
			for _, key in ipairs({ "CashSmall", "CashMedium", "CashLarge", "CashMega" }) do
				packs[key] = S.MonetizationService.CashPackAmount(player, Config.Products[key])
			end
			return packs
		end)(),
		FigureCount = Figures and #Figures.List or 0,
	}
end

function StateService.Init(services)
	Services = services
end

function StateService.Start()
	Services.Net.Register("GetState", function(player)
		return StateService.Build(player)
	end, 4)

	Services.DataService.OnLoaded(function(player)
		joinClock[player] = os.clock()
		dirty[player] = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		joinClock[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in pairs(dirty) do
				dirty[player] = nil
				if player.Parent then
					local ok, state = pcall(StateService.Build, player)
					if ok and state then
						Services.Net.StateUpdate:FireClient(player, state)
					elseif not ok then
						warn("[StateService]", state)
					end
				end
			end
		end
	end)
end

return StateService
