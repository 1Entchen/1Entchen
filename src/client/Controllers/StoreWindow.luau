--!strict
-- Robux store. Prices shown are fetched live from Roblox for configured
-- ids, so the store never disagrees with the purchase prompt. Grants happen
-- only on the server (pass ownership / ProcessReceipt).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))
local Windows = require(UI:WaitForChild("Windows"))

local State = require(script.Parent.Parent:WaitForChild("State"))
local Notifications = require(script.Parent.Notifications)

local StoreWindow = {}

local player = Players.LocalPlayer
local livePrices: { [string]: number } = {}
local cards: { [string]: { frame: Frame, buy: TextButton, extra: TextLabel? } } = {}
local pages: { [string]: ScrollingFrame } = {}
local tabs: { [string]: TextButton } = {}
local currentTab = "Passes"

local CATEGORY_LABELS: { [string]: string } = {
	Passes = "⭐ Passes",
	Boosts = "🧪 Boosts",
	Coins = "🪙 Coins",
	Events = "🌠 Events",
}

local function priceOf(product: Products.Product): number
	return livePrices[product.key] or product.price
end

local function fetchPrices()
	for _, product in Products.list do
		if product.id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(
						product.id,
						if product.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
					)
				end)
				if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
					livePrices[product.key] = info.PriceInRobux
					StoreWindow.refresh()
				end
			end)
		end
	end
end

local function purchase(product: Products.Product)
	if product.id == 0 then
		if RunService:IsStudio() then
			Net.event("DevGrant"):FireServer(product.key)
		else
			Notifications.toast("This item isn't available yet — check back soon!", "info")
		end
		return
	end
	if product.kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, product.id)
	else
		MarketplaceService:PromptProductPurchase(player, product.id)
	end
end

function StoreWindow.refresh()
	local main = State.main()
	for key, card in cards do
		local product = Products.byKey[key]
		if product.kind == "pass" and State.owns(key) then
			card.buy.Text = "Owned ✓"
			Kit.setEnabled(card.buy, false, Theme.Colors.Robux)
		else
			card.buy.Text = `R$ {priceOf(product)}`
			Kit.setEnabled(card.buy, true, Theme.Colors.Robux)
		end
		if card.extra and main and Products.CoinPackUnits[key] then
			local amount = Economy.coinPackAmount(key, main.bestTier)
			local perRobux = amount / priceOf(product)
			local base = Products.byKey.coins_small
			local baseRate = Economy.coinPackAmount("coins_small", main.bestTier) / priceOf(base)
			local bonus = math.floor((perRobux / baseRate - 1) * 100 + 0.5)
			card.extra.Text = if bonus > 0
				then `+{Format.short(amount)} coins ({bonus}% more per R$)`
				else `+{Format.short(amount)} coins`
		end
	end
end

local function selectTab(category: string)
	currentTab = category
	for name, page in pages do
		page.Visible = name == category
	end
	for name, tab in tabs do
		tab.BackgroundColor3 = if name == category then Theme.Colors.Gold else Theme.Colors.PanelLight
	end
end

local function buildCard(product: Products.Product, parent: Instance)
	local frame: Frame = Kit.new("Frame", {
		Name = product.key,
		BackgroundColor3 = Theme.Colors.PanelLight,
		LayoutOrder = product.order,
		Parent = parent,
	})
	Kit.corner(16).Parent = frame
	Kit.stroke(if product.highlight then Theme.Colors.Gold else Theme.Colors.Stroke, 3).Parent = frame
	Kit.label({
		Text = product.icon,
		Size = UDim2.new(0, 56, 0, 56),
		Position = UDim2.fromOffset(10, 10),
		NoStroke = true,
		MaxTextSize = 48,
		Parent = frame,
	})
	Kit.label({
		Text = product.name,
		Size = UDim2.new(1, -80, 0, 30),
		Position = UDim2.fromOffset(72, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = frame,
	})
	if product.highlight then
		local ribbon = Kit.label({
			Text = product.highlight,
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.Colors.Pink,
			Size = UDim2.fromOffset(110, 22),
			Position = UDim2.fromOffset(72, 42),
			MaxTextSize = 14,
			Parent = frame,
		})
		Kit.corner(8).Parent = ribbon
	end
	Kit.label({
		Text = product.description,
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -20, 0, 62),
		Position = UDim2.fromOffset(10, 72),
		NoStroke = true,
		MaxTextSize = 17,
		Parent = frame,
	})
	local extra: TextLabel? = nil
	if Products.CoinPackUnits[product.key] then
		extra = Kit.label({
			Text = "",
			TextColor3 = Theme.Colors.Coin,
			Size = UDim2.new(1, -20, 0, 24),
			Position = UDim2.new(0, 10, 1, -82),
			MaxTextSize = 20,
			Parent = frame,
		})
	end
	local buy = Kit.button({
		text = `R$ {product.price}`,
		color = Theme.Colors.Robux,
		size = UDim2.new(1, -20, 0, 46),
		position = UDim2.new(0, 10, 1, -10),
		anchor = Vector2.new(0, 1),
		onClick = function()
			purchase(product)
		end,
	})
	buy.Parent = frame
	cards[product.key] = { frame = frame, buy = buy, extra = extra }
end

local function build(content: Frame)
	local tabRow: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = content,
	})
	Kit.list(Enum.FillDirection.Horizontal, 8).Parent = tabRow
	for i, category in Products.Categories do
		tabs[category] = Kit.button({
			text = CATEGORY_LABELS[category],
			color = Theme.Colors.PanelLight,
			size = UDim2.fromOffset(150, 42),
			layoutOrder = i,
			parent = tabRow,
			onClick = function()
				selectTab(category)
			end,
		})
		local page: ScrollingFrame = Kit.new("ScrollingFrame", {
			Name = category,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -54),
			Position = UDim2.fromOffset(0, 54),
			ScrollBarThickness = 8,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = false,
			Parent = content,
		})
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(236, 236),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = page,
		})
		pages[category] = page
	end
	for _, product in Products.list do
		buildCard(product, pages[product.category])
	end

	-- Roblox Premium perk card (members also earn the game engagement payouts).
	if player.MembershipType ~= Enum.MembershipType.Premium then
		local card: Frame = Kit.new("Frame", {
			Name = "Premium",
			BackgroundColor3 = Theme.Colors.PanelLight,
			LayoutOrder = 100,
			Parent = pages.Passes,
		})
		Kit.corner(16).Parent = card
		Kit.stroke(Theme.Colors.Purple, 3).Parent = card
		Kit.label({
			Text = "⭐ Roblox Premium",
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 14),
			MaxTextSize = 24,
			Parent = card,
		})
		Kit.label({
			Text = "Premium members earn +10% coins in Slime Garden.",
			Font = Theme.BodyFont,
			TextColor3 = Theme.Colors.TextDim,
			TextWrapped = true,
			Size = UDim2.new(1, -20, 0, 60),
			Position = UDim2.fromOffset(10, 60),
			NoStroke = true,
			MaxTextSize = 17,
			Parent = card,
		})
		Kit.button({
			text = "Learn more",
			color = Theme.Colors.Purple,
			size = UDim2.new(1, -20, 0, 46),
			position = UDim2.new(0, 10, 1, -10),
			anchor = Vector2.new(0, 1),
			parent = card,
			onClick = function()
				pcall(function()
					MarketplaceService:PromptPremiumPurchase(player)
				end)
			end,
		})
	end

	selectTab(currentTab)
	StoreWindow.refresh()
end

function StoreWindow.start()
	Windows.register("Store", {
		title = "🛒 Store",
		color = Theme.Colors.Gold,
		size = Vector2.new(800, 540),
		build = build,
		onOpen = StoreWindow.refresh,
	})
	fetchPrices()
	State.Changed:Connect(function(section)
		if Windows.isOpen("Store") and (section == "passes" or section == "main") then
			StoreWindow.refresh()
		end
	end)
end

return StoreWindow
