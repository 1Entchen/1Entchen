--!strict
-- Game passes and developer products. Rewards are granted only on the
-- server: passes via UserOwnsGamePassAsync / PromptGamePassPurchaseFinished,
-- products via MarketplaceService.ProcessReceipt.
--
-- Receipt handling is idempotent: the PurchaseId is recorded in the
-- player's profile in the same synchronous step as the reward, and
-- PurchaseGranted is returned only after that profile has been saved. A
-- crash before the save loses both reward and record, so Roblox retries and
-- the reward is granted exactly once.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Notify = require(Util:WaitForChild("Notify"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))
local Validate = require(Util:WaitForChild("Validate"))

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Sync = require(script.Parent.Sync)

type Profile = Types.Profile
export type ProductHandler = (Player, Profile) -> boolean

local Monetization = {}

-- Fired after a player's pass ownership is known (right after their profile
-- loads). Gameplay systems that depend on passes start from here.
Monetization.PlayerReady = Signal.new() :: Signal.Signal<Player, Profile>
Monetization.PassesChanged = Signal.new() :: Signal.Signal<Player, string>

local owned: { [Player]: { [string]: boolean } } = {}
local ready: { [Player]: boolean } = {}
local handlers: { [string]: ProductHandler } = {}
local inFlight: { [string]: boolean } = {}

function Monetization.owns(player: Player, passKey: string): boolean
	local set = owned[player]
	return set ~= nil and set[passKey] == true
end

function Monetization.isReady(player: Player): boolean
	return ready[player] == true
end

function Monetization.registerProduct(key: string, handler: ProductHandler)
	local product = Products.byKey[key]
	assert(product and product.kind == "product", `unknown developer product {key}`)
	assert(handlers[key] == nil, `duplicate handler for {key}`)
	handlers[key] = handler
end

local function grantStarterPack(player: Player, data: Profile)
	if data.starterPackClaimed then
		return
	end
	data.starterPackClaimed = true
	data.coins += 2500
	data.seeds.ember = (data.seeds.ember or 0) + 3
	data.seeds.frost = (data.seeds.frost or 0) + 2
	data.potions.growth = (data.potions.growth or 0) + 1
	data.potions.luck = (data.potions.luck or 0) + 1
	Analytics.coinSource(player, 2500, data.coins, Enum.AnalyticsEconomyTransactionType.IAP, "starter_pack")
	Notify.player(player, "🎁 Starter Pack unlocked! Seeds, coins and potions added.", "reward")
	Sync.mark(player, "main")
end

local function setOwned(player: Player, data: Profile, key: string)
	local set = owned[player]
	if not set or set[key] then
		return
	end
	set[key] = true
	data.passCache[key] = true
	if key == "starter_pack" then
		grantStarterPack(player, data)
	end
	if key == "vip" then
		player:SetAttribute("VIP", true)
	end
	Sync.mark(player, "passes")
	Sync.mark(player, "boosts")
	Monetization.PassesChanged:Fire(player, key)
end

local function loadOwnership(player: Player, data: Profile)
	local set: { [string]: boolean } = {}
	owned[player] = set
	local pending = 0
	for _, product in Products.list do
		if product.kind ~= "pass" then
			continue
		end
		if product.id == 0 then
			-- Unconfigured pass: only Studio test grants count.
			if RunService:IsStudio() and data.passCache[product.key] then
				set[product.key] = true
			end
			continue
		end
		pending += 1
		task.spawn(function()
			local ok, result = false, nil
			for attempt = 1, 3 do
				ok, result = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, product.id)
				end)
				if ok then
					break
				end
				task.wait(attempt)
			end
			if ok then
				set[product.key] = result == true
				if result == true then
					data.passCache[product.key] = true
				else
					data.passCache[product.key] = nil
				end
			elseif data.passCache[product.key] then
				-- API outage: trust the last verified ownership.
				set[product.key] = true
			end
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 15 do
		task.wait(0.1)
	end

	if set.starter_pack then
		grantStarterPack(player, data)
	end
	player:SetAttribute("VIP", set.vip == true)
	ready[player] = true
	Sync.mark(player, "passes")
	Sync.mark(player, "boosts")
	Monetization.PlayerReady:Fire(player, data)
end

-- ProcessReceipt: return PurchaseGranted only once the grant is persisted.
local function processReceipt(receipt: { [any]: any }): Enum.ProductPurchaseDecision
	local purchaseId = tostring(receipt.PurchaseId)
	local product = Products.byProductId[tonumber(receipt.ProductId) or -1]
	if not product then
		warn(`[Monetization] receipt for unknown product id {receipt.ProductId}; leaving unprocessed`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local handler = handlers[product.key]
	if not handler then
		warn(`[Monetization] no handler for {product.key}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(tonumber(receipt.PlayerId) or -1)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.waitFor(player, 20)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if inFlight[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	inFlight[purchaseId] = true

	local decision = Enum.ProductPurchaseDecision.NotProcessedYet
	local ok, err = pcall(function(): any
		if table.find(data.receipts, purchaseId) then
			-- Already granted in memory (an earlier save may have failed).
			if DataService.saveNow(player) then
				decision = Enum.ProductPurchaseDecision.PurchaseGranted
			end
			return nil
		end

		local granted = handler(player, data)
		if not granted then
			return nil
		end
		table.insert(data.receipts, purchaseId)
		while #data.receipts > Config.Data.MaxReceipts do
			table.remove(data.receipts, 1)
		end
		local spent = tonumber(receipt.CurrencySpent) or 0
		data.stats.robuxSpent += spent
		Analytics.custom(player, "RobuxPurchase_" .. product.key, spent)
		Sync.mark(player, "main")

		if DataService.saveNow(player) then
			decision = Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return nil
	end)
	inFlight[purchaseId] = nil
	if not ok then
		warn(`[Monetization] receipt {purchaseId} failed: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return decision
end

local function grantCoinPack(key: string): ProductHandler
	return function(player: Player, data: Profile): boolean
		local amount = Economy.coinPackAmount(key, data.bestTier)
		data.coins += amount
		Analytics.coinSource(player, amount, data.coins, Enum.AnalyticsEconomyTransactionType.IAP, key)
		Notify.player(player, `+{Format.short(amount)} coins! Thank you for your support 💚`, "reward")
		Notify.effect(player, "coins", { amount = amount })
		return true
	end
end

-- Studio-only purchase simulation for unconfigured ids and QA shortcuts.
local function onDevGrant(player: Player, key: unknown)
	if not RunService:IsStudio() then
		return -- never available in live servers
	end
	if not RateLimiter.allow(player, "DevGrant", 4, 6) then
		return
	end
	local productKey = Validate.shortString(key, 40)
	local data = DataService.get(player)
	if not productKey or not data then
		return
	end
	if productKey == "dev_coins" then
		data.coins += 1_000_000_000
		Sync.mark(player, "main")
		return
	elseif productKey == "dev_seeds" then
		for _, id in { "berry", "ember", "frost", "toxic", "crystal", "shadow", "king", "cosmic" } do
			data.seeds[id] = (data.seeds[id] or 0) + 5
		end
		Sync.mark(player, "main")
		return
	end
	local product = Products.byKey[productKey]
	if not product then
		return
	end
	if product.kind == "pass" then
		setOwned(player, data, product.key)
		Notify.player(player, `[Studio] Granted pass: {product.name}`, "success")
	else
		local handler = handlers[product.key]
		if handler and handler(player, data) then
			Sync.mark(player, "main")
			Notify.player(player, `[Studio] Simulated purchase: {product.name}`, "success")
		end
	end
end

function Monetization.init()
	for key in Products.CoinPackUnits do
		Monetization.registerProduct(key, grantCoinPack(key))
	end
	Monetization.registerProduct("prism_seed", function(player, data)
		data.seeds.prism = (data.seeds.prism or 0) + 1
		Notify.player(player, "🌈 Prism Seed added! Plant it in your garden.", "reward")
		return true
	end)

	Sync.register("passes", function(player)
		return owned[player] or {}
	end)
end

function Monetization.start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local product = Products.byPassId[passId]
		local data = DataService.get(player)
		if product and data then
			setOwned(player, data, product.key)
			Analytics.custom(player, "PassPurchase_" .. product.key, product.price)
			Notify.player(player, `{product.icon} {product.name} unlocked! Thank you 💚`, "reward")
		end
	end)

	DataService.ProfileLoaded:Connect(loadOwnership)
	DataService.ProfileReleased:Connect(function(player)
		owned[player] = nil
		ready[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- Profile may never have loaded (kicked during load).
		task.delay(60, function()
			if not player.Parent then
				owned[player] = nil
				ready[player] = nil
			end
		end)
	end)

	Net.event("DevGrant").OnServerEvent:Connect(onDevGrant)
end

-- Test hook.
Monetization._processReceipt = processReceipt

return Monetization
