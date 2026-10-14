--!strict
-- Seed Shop window: opened from the shop counter prompt. Shows this
-- restock's stock (per player), prices, growth times, values and the
-- published chance of each seed appearing in a restock.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Species = require(Shared:WaitForChild("Species"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))
local Windows = require(UI:WaitForChild("Windows"))

local State = require(script.Parent.Parent:WaitForChild("State"))

local ShopWindow = {}

type Row = {
	frame: Frame,
	stock: TextLabel,
	buyOne: TextButton,
	buyAll: TextButton,
}

local rows: { [string]: Row } = {}
local header: TextLabel? = nil

local function shopCounter(): BasePart?
	local world = Workspace:FindFirstChild("SlimeGarden")
	local hub = world and world:FindFirstChild("Hub")
	local shop = hub and hub:FindFirstChild("SeedShop")
	local counter = shop and shop:FindFirstChild("Counter")
	return if counter and counter:IsA("BasePart") then counter else nil
end

local function remainingFor(id: string): number
	local stock = State.stock
	local shop = State.get("shop")
	local listed = if stock then stock.stock[id] or 0 else 0
	local bought = 0
	if shop and stock and shop.restockId == stock.restockId then
		bought = shop.bought[id] or 0
	end
	return math.max(0, listed - bought)
end

local function refresh()
	local main = State.main()
	if not main then
		return
	end
	local stock = State.stock
	for id, row in rows do
		local species = Species.byId[id]
		local listed = if stock then stock.stock[id] else nil
		local remaining = remainingFor(id)
		local locked = main.rebirths < species.requiresRebirth
		if locked then
			row.stock.Text = `🔒 Unlocks at Rebirth {species.requiresRebirth}`
			row.stock.TextColor3 = Theme.Colors.TextDim
		elseif listed == nil then
			row.stock.Text = `Not in stock · appears in {Format.percent(species.stockChance)} of restocks`
			row.stock.TextColor3 = Theme.Colors.TextDim
		elseif remaining == 0 then
			row.stock.Text = "Sold out until next restock"
			row.stock.TextColor3 = Theme.Colors.Red
		else
			row.stock.Text = `x{remaining} in stock`
			row.stock.TextColor3 = Theme.Colors.Green
		end
		local affordable = main.coins >= species.price
		local canBuy = not locked and remaining > 0
		Kit.setEnabled(row.buyOne, canBuy and affordable, Theme.Colors.Green)
		Kit.setEnabled(row.buyAll, canBuy and affordable and remaining > 1, Theme.Colors.GreenDark)
		row.frame.BackgroundTransparency = if canBuy then 0 else 0.35
	end
end

local function buy(id: string, all: boolean)
	local main = State.main()
	if not main then
		return
	end
	local species = Species.byId[id]
	local quantity = 1
	if all then
		quantity = math.clamp(math.min(remainingFor(id), math.floor(main.coins / species.price)), 1, 50)
	end
	Net.event("BuySeed"):FireServer(id, quantity)
end

local function build(content: Frame)
	header = Kit.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = content,
	})
	local list: ScrollingFrame = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -34),
		Position = UDim2.fromOffset(0, 34),
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	Kit.list(Enum.FillDirection.Vertical, 8).Parent = list
	Kit.new("UIPadding", { PaddingRight = UDim.new(0, 12), Parent = list })

	for order, species in Species.shopOrder do
		local frame: Frame = Kit.new("Frame", {
			Name = species.id,
			BackgroundColor3 = Theme.Colors.PanelLight,
			Size = UDim2.new(1, 0, 0, 92),
			LayoutOrder = order,
			Parent = list,
		})
		Kit.corner(14).Parent = frame
		Kit.stroke(Species.RarityColors[species.rarity], 2).Parent = frame
		Kit.slimeViewport(species.id, {}, {
			Size = UDim2.fromOffset(84, 84),
			Position = UDim2.fromOffset(4, 4),
			Parent = frame,
		})
		Kit.label({
			Text = species.name,
			TextColor3 = Species.RarityColors[species.rarity],
			Size = UDim2.new(0.5, -90, 0, 30),
			Position = UDim2.fromOffset(94, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
			Parent = frame,
		})
		Kit.label({
			Text = `{species.rarity} · grows in {Format.duration(species.growTime)} · sells ~{Format.short(
				species.value
			)}`,
			Font = Theme.BodyFont,
			TextColor3 = Theme.Colors.TextDim,
			Size = UDim2.new(0.62, -90, 0, 22),
			Position = UDim2.fromOffset(94, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			NoStroke = true,
			Parent = frame,
		})
		local stockLabel = Kit.label({
			Text = "",
			Size = UDim2.new(0.62, -90, 0, 22),
			Position = UDim2.fromOffset(94, 62),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			Parent = frame,
		})
		Kit.label({
			Text = `🪙 {Format.short(species.price)}`,
			TextColor3 = Theme.Colors.Coin,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 6),
			Size = UDim2.fromOffset(200, 30),
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 26,
			Parent = frame,
		})
		local buyOne = Kit.button({
			text = "Buy 1",
			size = UDim2.fromOffset(96, 42),
			position = UDim2.new(1, -116, 1, -8),
			anchor = Vector2.new(1, 1),
			onClick = function()
				buy(species.id, false)
			end,
		})
		buyOne.Parent = frame
		local buyAll = Kit.button({
			text = "Buy Max",
			color = Theme.Colors.GreenDark,
			size = UDim2.fromOffset(100, 42),
			position = UDim2.new(1, -10, 1, -8),
			anchor = Vector2.new(1, 1),
			onClick = function()
				buy(species.id, true)
			end,
		})
		buyAll.Parent = frame
		rows[species.id] = { frame = frame, stock = stockLabel, buyOne = buyOne, buyAll = buyAll }
	end
	refresh()
end

function ShopWindow.start()
	Windows.register("Shop", {
		title = "🌱 Seed Shop",
		color = Theme.Colors.Green,
		size = Vector2.new(780, 520),
		build = build,
		onOpen = refresh,
	})

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == Players.LocalPlayer and prompt.Name == "ShopPrompt" then
			Windows.open("Shop")
		end
	end)

	State.Changed:Connect(function(section)
		if Windows.isOpen("Shop") and (section == "main" or section == "shop" or section == "stock") then
			refresh()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			if Windows.isOpen("Shop") then
				local stock = State.stock
				local main = State.main()
				if header and stock and main then
					header.Text = `🪙 {Format.short(main.coins)}   ·   Restock in {Format.clock(
						stock.nextRestockAt - Workspace:GetServerTimeNow()
					)}`
				end
				-- Close when the player walks away from the counter.
				local counter = shopCounter()
				local character = Players.LocalPlayer.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if counter and rootPart and rootPart:IsA("BasePart") then
					if (rootPart.Position - counter.Position).Magnitude > Config.Shop.ReachDistance + 6 then
						Windows.close()
					end
				end
			end
		end
	end)
end

return ShopWindow
