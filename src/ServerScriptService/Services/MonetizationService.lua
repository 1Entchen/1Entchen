--[[
	MonetizationService  (ModuleScript)  ->  ServerScriptService/Services/MonetizationService
	Game Passes, Developer Products (ProcessReceipt), Roblox Premium.
	ProcessReceipt ist idempotent: jede PurchaseId wird nur einmal gutgeschrieben
	und erst nach erfolgreichem Speichern als "granted" bestätigt.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Figures = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("Figures"))
local Format = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("Format"))

local MonetizationService = {}
local Services

local ownedPasses = {} -- [player] = { [key] = true }
local passKeyById = {}
local productKeyById = {}
local productHandlers = {}

------------------------------------------------------------------------
-- Game Passes
------------------------------------------------------------------------
function MonetizationService.HasPass(player, key)
	local owned = ownedPasses[player]
	return owned ~= nil and owned[key] == true
end

function MonetizationService.GetOwnedPasses(player)
	local result = {}
	for key in pairs(ownedPasses[player] or {}) do
		result[key] = true
	end
	return result
end

function MonetizationService.IsPremium(player)
	return player.MembershipType == Enum.MembershipType.Premium
end

local function applyPassEffects(player)
	player:SetAttribute("VIP", MonetizationService.HasPass(player, "VIP"))
	Services.BaseService.ApplyWalkSpeed(player)
	Services.BaseService.RenderAll(player)
	Services.StateService.MarkDirty(player)
end

local function loadPasses(player)
	local owned = {}
	for key, pass in pairs(Config.GamePasses) do
		if pass.Id and pass.Id > 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and has then
				owned[key] = true
			end
		end
	end
	ownedPasses[player] = owned
end

------------------------------------------------------------------------
-- Developer Products
------------------------------------------------------------------------
local function cashPackAmount(player, product)
	local rate = Services.IncomeService.GetRate(player)
	return math.max(product.Min, math.floor(rate * product.Seconds))
end
MonetizationService.CashPackAmount = cashPackAmount

local function grantCash(player, data, amount, reason)
	data.Cash += amount
	data.TotalEarned += amount
	Services.Net.Notify(player, ("%s: +%s"):format(reason, Format.Money(amount)), "success", "Reward")
end

for _, key in ipairs({ "CashSmall", "CashMedium", "CashLarge", "CashMega" }) do
	productHandlers[key] = function(player, data)
		local product = Config.Products[key]
		grantCash(player, data, cashPackAmount(player, product), product.Name)
		Services.Net.Effect(player, "Confetti")
	end
end

productHandlers.Boost2x = function(player, data)
	data.Boost2xUntil = math.max(os.time(), data.Boost2xUntil) + Config.Products.Boost2x.Seconds
	Services.Net.Notify(player, "⚡ 2x Cash aktiv! Noch " .. Format.Time(data.Boost2xUntil - os.time()), "success", "Reward")
end

productHandlers.LuckySpawn = function(player)
	Services.ConveyorService.AddLuck(Config.Products.LuckySpawn.Seconds)
	Services.Net.Announce(("🍀 %s hat LUCKY SPAWN für den ganzen Server aktiviert! Bessere Chancen für alle!"):format(player.DisplayName), Color3.fromRGB(90, 255, 120))
end

productHandlers.MythicDrop = function(player)
	Services.ConveyorService.ForceSpawn("Mythic", player)
	Services.Net.Announce(("🔥 %s hat einen MYTHIC-DROP gekauft!"):format(player.DisplayName), Config.Rarities.Mythic.Color)
end

productHandlers.LockExtend = function(player)
	Services.BaseService.ExtendLock(player, Config.Lock.ExtendSeconds)
	Services.Net.Notify(player, "🔐 Basis 5 Minuten extra gesichert!", "success", "Lock")
end

productHandlers.StarterPack = function(player, data)
	data.StarterBought = true
	local slot = Services.BaseService.GiveFigure(player, 14, "Gold")
	if not slot then
		grantCash(player, data, Figures.Price(14, "Gold"), "Basis voll, Figur als Cash")
	end
	grantCash(player, data, 25000, "Starter-Paket")
	data.Boost2xUntil = math.max(os.time(), data.Boost2xUntil) + 1800
	Services.Net.Effect(player, "Reveal", { Id = 14, Mut = "Gold", Text = "STARTER-PAKET!" })
end

productHandlers.OfflineTriple = function(player, data)
	local reward = data.OfflineReward
	if reward and reward.Amount > 0 and not reward.Boosted then
		reward.Boosted = true
		grantCash(player, data, reward.Amount * 2, "Offline-Cash x3")
	else
		grantCash(player, data, cashPackAmount(player, Config.Products.CashSmall), "Cash-Bonus")
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = Services.DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.Purchases, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productKeyById[receipt.ProductId]
	local handler = key and productHandlers[key]
	if not handler then
		warn("[Monetization] Unbekannte ProductId:", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(handler, player, data)
	if not ok then
		warn("[Monetization] Fehler beim Gutschreiben:", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.Purchases, receipt.PurchaseId)
	while #data.Purchases > 100 do
		table.remove(data.Purchases, 1)
	end
	data.Stats.RobuxSpent += receipt.CurrencySpent or 0
	Services.StateService.MarkDirty(player)

	if Services.DataService.Save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

------------------------------------------------------------------------
-- Server-seitige Kaufaufforderungen (z. B. gesperrte Slots in der Basis)
------------------------------------------------------------------------
function MonetizationService.PromptPass(player, key)
	local pass = Config.GamePasses[key]
	if pass and pass.Id > 0 and not MonetizationService.HasPass(player, key) then
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	end
end

function MonetizationService.PromptPremium(player)
	if not MonetizationService.IsPremium(player) then
		pcall(MarketplaceService.PromptPremiumPurchase, MarketplaceService, player)
	end
end

------------------------------------------------------------------------
function MonetizationService.Init(services)
	Services = services
	for key, pass in pairs(Config.GamePasses) do
		if pass.Id > 0 then
			passKeyById[pass.Id] = key
		end
	end
	for key, product in pairs(Config.Products) do
		if product.Id > 0 then
			productKeyById[product.Id] = key
		end
	end
	MarketplaceService.ProcessReceipt = processReceipt
end

function MonetizationService.Start()
	Services.DataService.OnLoaded(function(player)
		loadPasses(player)
		player:SetAttribute("VIP", MonetizationService.HasPass(player, "VIP"))
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passKeyById[passId]
		if not key then
			return
		end
		ownedPasses[player] = ownedPasses[player] or {}
		ownedPasses[player][key] = true
		local pass = Config.GamePasses[key]
		Services.Net.Notify(player, ("%s %s freigeschaltet! Danke ❤"):format(pass.Icon, pass.Name), "success", "Reward")
		Services.Net.Effect(player, "Confetti")
		Services.Net.Announce(("%s hat %s %s gekauft!"):format(player.DisplayName, pass.Icon, pass.Name), Color3.fromRGB(255, 215, 0))
		applyPassEffects(player)
	end)

	Players.PlayerMembershipStatusChanged:Connect(function(player)
		if Services.DataService.IsLoaded(player) then
			Services.BaseService.RenderAll(player)
			Services.StateService.MarkDirty(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			ownedPasses[player] = nil
		end)
	end)
end

return MonetizationService
