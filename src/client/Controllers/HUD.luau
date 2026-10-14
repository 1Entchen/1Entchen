--!strict
-- Always-on HUD: coins, restock / weather / boost status, menu buttons
-- (left), context actions (right) and the seed hotbar (bottom).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Species = require(Shared:WaitForChild("Species"))
local Weathers = require(Shared:WaitForChild("Weathers"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))
local Windows = require(UI:WaitForChild("Windows"))

local State = require(script.Parent.Parent:WaitForChild("State"))
local GardenView = require(script.Parent.GardenView)
local Notifications = require(script.Parent.Notifications)

local HUD = {}

local root: Frame
local coinsLabel: TextLabel
local coinsPill: Frame
local statusLabel: TextLabel
local weatherPill: Frame
local weatherLabel: TextLabel
local boostRow: Frame
local seedBar: ScrollingFrame
local seedHint: TextLabel
local menuButtons: { [string]: TextButton } = {}
local actionButtons: { [string]: TextButton } = {}

local displayedCoins = Instance.new("NumberValue")

local function menuButton(
	name: string,
	icon: string,
	caption: string,
	color: Color3,
	order: number,
	parent: Instance,
	onClick: () -> ()
): TextButton
	local button = Kit.button({
		name = name,
		text = "",
		color = color,
		size = UDim2.fromOffset(72, 72),
		layoutOrder = order,
		onClick = onClick,
	})
	Kit.label({
		Text = icon,
		Size = UDim2.new(1, 0, 0.62, 0),
		NoStroke = true,
		MaxTextSize = 40,
		Parent = button,
	})
	Kit.label({
		Text = caption,
		Size = UDim2.new(1, 8, 0.34, 0),
		Position = UDim2.new(0, -4, 0.66, 0),
		MaxTextSize = 15,
		Parent = button,
	})
	Kit.badge(button)
	button.Parent = parent
	menuButtons[name] = button
	return button
end

local function actionButton(
	name: string,
	text: string,
	color: Color3,
	order: number,
	parent: Instance,
	onClick: () -> ()
): TextButton
	local button = Kit.button({
		name = name,
		text = text,
		color = color,
		size = UDim2.fromOffset(158, 50),
		layoutOrder = order,
		textSize = 22,
		onClick = onClick,
	})
	button.Visible = false
	button.Parent = parent
	actionButtons[name] = button
	return button
end

local function setBadge(button: GuiObject, visible: boolean, text: string?)
	local badge = button:FindFirstChild("Badge") :: TextLabel?
	if badge then
		badge.Visible = visible
		if text then
			badge.Text = text
		end
	end
end

local seedSlots: { [string]: TextButton } = {}

local function refreshSeedSelection()
	for id, slot in seedSlots do
		local stroke = slot:FindFirstChildOfClass("UIStroke")
		if stroke then
			local selected = GardenView.selectedSeed == id
			stroke.Color = if selected then Theme.Colors.Gold else Theme.Colors.Stroke
			stroke.Thickness = if selected then 5 else 3
		end
	end
	local selected = GardenView.selectedSeed
	local species = if selected then Species.byId[selected] else nil
	seedHint.Text = if species
		then `Tap an empty soil tile to plant: {species.name}`
		else "No seeds — visit the Seed Shop 🌱"
end

local function rebuildSeedBar()
	local main = State.main()
	if not main then
		return
	end
	local ids = {}
	for id, count in main.seeds do
		if count > 0 and Species.byId[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local ta, tb = Species.byId[a].tier, Species.byId[b].tier
		ta = if ta == 0 then 100 else ta
		tb = if tb == 0 then 100 else tb
		return ta < tb
	end)

	local wanted: { [string]: boolean } = {}
	for order, id in ids do
		wanted[id] = true
		local slot = seedSlots[id]
		if not slot then
			local newSlot = Kit.button({
				name = id,
				text = "",
				color = Theme.Colors.PanelLight,
				size = UDim2.fromOffset(74, 74),
				onClick = function()
					GardenView.select(id)
				end,
			})
			local viewport = Kit.slimeViewport(id, {}, {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, -0.04),
			})
			viewport.Parent = newSlot
			Kit.label({
				Name = "Count",
				Text = "",
				Size = UDim2.fromOffset(46, 24),
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 4, 1, 2),
				TextXAlignment = Enum.TextXAlignment.Right,
				MaxTextSize = 20,
				ZIndex = 3,
				Parent = newSlot,
			})
			newSlot.Parent = seedBar
			seedSlots[id] = newSlot
			slot = newSlot
		end
		local s = slot :: TextButton
		s.LayoutOrder = order
		local countLabel = s:FindFirstChild("Count") :: TextLabel
		countLabel.Text = `x{main.seeds[id]}`
	end
	for id, slot in seedSlots do
		if not wanted[id] then
			slot:Destroy()
			seedSlots[id] = nil
		end
	end
	refreshSeedSelection()
end

local function nearSellStand(): boolean
	local world = Workspace:FindFirstChild("SlimeGarden")
	local hub = world and world:FindFirstChild("Hub")
	local stand = hub and hub:FindFirstChild("SellStand")
	local counter = stand and stand:FindFirstChild("Counter")
	local character = Players.LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if counter and counter:IsA("BasePart") and rootPart and rootPart:IsA("BasePart") then
		return (counter.Position - rootPart.Position).Magnitude < 28
	end
	return false
end

local function refreshMain()
	local main = State.main()
	if not main then
		return
	end
	TweenService:Create(displayedCoins, Theme.Tween.Smooth, { Value = main.coins }):Play()

	local backpack = State.get("backpack")
	local count = if backpack then #backpack else 0
	local capacity = Economy.backpackCapacity(State.owns("vip"))
	setBadge(menuButtons.Backpack, count > 0, tostring(count))
	if count >= capacity then
		setBadge(menuButtons.Backpack, true, "FULL")
	end
	setBadge(menuButtons.Rebirth, main.coins >= Economy.rebirthCost(main.rebirths))

	local potions = main.potions or {}
	actionButtons.GrowthPotion.Visible = (potions.growth or 0) > 0
	actionButtons.GrowthPotion.Text = `🧪 Growth x{potions.growth or 0}`
	actionButtons.LuckPotion.Visible = (potions.luck or 0) > 0
	actionButtons.LuckPotion.Text = `🔮 Luck x{potions.luck or 0}`
	actionButtons.InstantGrow.Visible = (main.instantGrowCharges or 0) > 0
	actionButtons.InstantGrow.Text = `⏩ Grow x{main.instantGrowCharges or 0}`
	actionButtons.AutoHarvest.Visible = State.owns("auto_harvest")
	actionButtons.AutoHarvest.Text = if main.autoHarvest then "🤖 Auto: ON" else "🤖 Auto: OFF"
	actionButtons.AutoHarvest.BackgroundColor3 = if main.autoHarvest
		then Theme.Colors.Green
		else Theme.Colors.Grey
end

local function refreshDaily()
	local daily = State.get("daily")
	if not daily then
		return
	end
	setBadge(menuButtons.Rewards, daily.canClaim)
	local claimable = false
	for _, quest in daily.quests do
		if not quest.claimed and quest.progress >= quest.target then
			claimable = true
		end
	end
	setBadge(menuButtons.Quests, claimable)
end

local function refreshBoosts()
	local boosts = State.get("boosts")
	for _, child in boostRow:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if not boosts then
		return
	end
	for i, entry in boosts.list do
		if entry.key == "weather" then
			continue
		end
		local chip = Kit.label({
			Name = entry.key,
			Text = entry.icon,
			Size = UDim2.fromOffset(92, 30),
			BackgroundTransparency = 0.2,
			BackgroundColor3 = Theme.Colors.PanelDark,
			LayoutOrder = i,
			MaxTextSize = 18,
			Parent = boostRow,
		})
		chip:SetAttribute("ExpiresAt", entry.expiresAt)
		chip:SetAttribute("Icon", entry.icon)
		chip:SetAttribute("Label", entry.label)
		Kit.corner(10).Parent = chip
	end
end

local function tickStatus()
	local now = Workspace:GetServerTimeNow()
	local stock = State.stock
	if stock then
		statusLabel.Text = `🌱 Seed restock in {Format.clock(stock.nextRestockAt - now)}`
	end
	local weatherState = State.weather
	local weather = if weatherState then Weathers.get(weatherState.id) else nil
	if weather and weatherState then
		weatherPill.Visible = true
		weatherLabel.Text = `{weather.icon} {weather.name} — {Format.clock(weatherState.endsAt - now)}`
	else
		weatherPill.Visible = false
	end
	for _, chip in boostRow:GetChildren() do
		if chip:IsA("TextLabel") then
			local expiresAt = chip:GetAttribute("ExpiresAt")
			local icon = chip:GetAttribute("Icon")
			if typeof(expiresAt) == "number" then
				chip.Text = `{icon} {Format.clock(expiresAt - now)}`
			else
				local label = chip:GetAttribute("Label")
				chip.Text =
					`{icon} {if typeof(label) == "string" then string.match(label, "%+%d+%%") or "" else ""}`
			end
		end
	end

	local ripe = GardenView.ripeCount()
	actionButtons.HarvestAll.Visible = ripe > 0
	actionButtons.HarvestAll.Text = `✋ Harvest ({ripe})`
	local backpack = State.get("backpack")
	local hasSlimes = backpack ~= nil and #backpack > 0
	actionButtons.Sell.Visible = hasSlimes and (State.owns("sell_anywhere") or nearSellStand())
	actionButtons.PlantAll.Visible = GardenView.selectedSeed ~= nil
end

function HUD.start()
	local _, canvas = Kit.screen("SlimeHUD", 1)
	root = canvas

	-- Coins pill (top centre).
	coinsPill = Kit.new("Frame", {
		Name = "Coins",
		BackgroundColor3 = Theme.Colors.Panel,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(250, 52),
		Parent = root,
	})
	Kit.corner(26).Parent = coinsPill
	Kit.stroke(Theme.Colors.Stroke, 3).Parent = coinsPill
	coinsLabel = Kit.label({
		Text = "🪙 0",
		TextColor3 = Theme.Colors.Coin,
		Size = UDim2.new(1, -24, 1, -8),
		Position = UDim2.fromOffset(12, 4),
		MaxTextSize = 34,
		Parent = coinsPill,
	})
	Notifications.setCoinTarget(coinsPill)
	displayedCoins.Changed:Connect(function(value)
		coinsLabel.Text = `🪙 {Format.short(value)}`
	end)

	statusLabel = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.TextDim,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(300, 22),
		MaxTextSize = 18,
		Parent = root,
	})
	weatherPill = Kit.new("Frame", {
		Name = "Weather",
		BackgroundColor3 = Theme.Colors.Blue,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.fromOffset(300, 34),
		Visible = false,
		Parent = root,
	})
	Kit.corner(17).Parent = weatherPill
	Kit.stroke(Theme.Colors.Stroke, 3).Parent = weatherPill
	weatherLabel = Kit.label({
		Text = "",
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		MaxTextSize = 22,
		Parent = weatherPill,
	})
	boostRow = Kit.new("Frame", {
		Name = "Boosts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 124),
		Size = UDim2.fromOffset(420, 30),
		Parent = root,
	})
	Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center).Parent = boostRow

	-- Menu buttons (left, 2 columns).
	local menu: Frame = Kit.new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.45, 0),
		Size = UDim2.fromOffset(156, 240),
		Parent = root,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(72, 72),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	menuButton("Store", "🛒", "Store", Theme.Colors.Gold, 1, menu, function()
		Windows.toggle("Store")
	end)
	menuButton("Backpack", "🎒", "Backpack", Theme.Colors.Blue, 2, menu, function()
		Windows.toggle("Backpack")
	end)
	menuButton("Index", "📖", "Slimepedia", Theme.Colors.Purple, 3, menu, function()
		Windows.toggle("Index")
	end)
	menuButton("Rewards", "🎁", "Daily", Theme.Colors.Pink, 4, menu, function()
		Windows.toggle("Rewards")
	end)
	menuButton("Quests", "📜", "Quests", Theme.Colors.Green, 5, menu, function()
		Windows.toggle("Quests")
	end)
	menuButton("Rebirth", "⭐", "Rebirth", Theme.Colors.GoldDark, 6, menu, function()
		Windows.toggle("Rebirth")
	end)

	-- Context actions (right).
	local actions: Frame = Kit.new("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.42, 0),
		Size = UDim2.fromOffset(158, 380),
		Parent = root,
	})
	Kit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center).Parent =
		actions
	actionButton("HarvestAll", "✋ Harvest", Theme.Colors.Green, 1, actions, function()
		Net.event("HarvestAll"):FireServer()
	end)
	actionButton("PlantAll", "🌱 Plant All", Theme.Colors.GreenDark, 2, actions, function()
		GardenView.plantAll()
	end)
	actionButton("Sell", "💰 Sell All", Theme.Colors.Gold, 3, actions, function()
		Net.event("SellAll"):FireServer()
	end)
	actionButton("InstantGrow", "⏩ Grow", Theme.Colors.Blue, 4, actions, function()
		Net.event("UseInstantGrow"):FireServer()
	end)
	actionButton("GrowthPotion", "🧪 Growth", Theme.Colors.Purple, 5, actions, function()
		Net.event("UsePotion"):FireServer("growth")
	end)
	actionButton("LuckPotion", "🔮 Luck", Theme.Colors.Purple, 6, actions, function()
		Net.event("UsePotion"):FireServer("luck")
	end)
	actionButton("AutoHarvest", "🤖 Auto", Theme.Colors.Green, 7, actions, function()
		local main = State.main()
		if main then
			Net.event("SetAutoHarvest"):FireServer(not main.autoHarvest)
		end
	end)

	-- Seed hotbar (bottom centre).
	seedHint = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.Text,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(460, 24),
		MaxTextSize = 20,
		Parent = root,
	})
	seedBar = Kit.new("ScrollingFrame", {
		Name = "Seeds",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(460, 90),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = root,
	})
	Kit.corner(16).Parent = seedBar
	Kit.stroke(Theme.Colors.Stroke, 3).Parent = seedBar
	Kit.padding(8).Parent = seedBar
	Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent =
		seedBar

	GardenView.SelectionChanged:Connect(refreshSeedSelection)
	State.Changed:Connect(function(section)
		if section == "main" then
			refreshMain()
			rebuildSeedBar()
		elseif section == "backpack" or section == "passes" then
			refreshMain()
		elseif section == "daily" then
			refreshDaily()
		elseif section == "boosts" then
			refreshBoosts()
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function()
		task.delay(1, refreshMain)
	end)

	task.spawn(function()
		while true do
			tickStatus()
			task.wait(0.25)
		end
	end)
end

return HUD
