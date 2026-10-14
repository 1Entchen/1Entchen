--!strict
-- Backpack: every harvested slime with its value; favorite to protect it
-- from Sell All (and keep it through rebirth); sell singles at the stand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local SlimeBuilder = require(Shared:WaitForChild("SlimeBuilder"))
local Species = require(Shared:WaitForChild("Species"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))
local Windows = require(UI:WaitForChild("Windows"))

local State = require(script.Parent.Parent:WaitForChild("State"))

local BackpackWindow = {}

local grid: ScrollingFrame
local summary: TextLabel
local detail: Frame
local selectedId: number? = nil
local dirty = true

local function sellMultiplier(): number
	local boosts = State.get("boosts")
	return if boosts then boosts.multipliers.sell else 1
end

local function slimeTitle(slime: any): string
	local species = Species.byId[slime.s]
	local parts = {}
	local mutationText = SlimeBuilder.mutationNames(slime.m)
	if mutationText ~= "" then
		table.insert(parts, mutationText)
	end
	local weightLabel = Economy.weightLabel(slime.w)
	if weightLabel then
		table.insert(parts, weightLabel)
	end
	table.insert(parts, if species then species.name else slime.s)
	return table.concat(parts, " ")
end

local function findSlime(id: number?): any
	local backpack = State.get("backpack")
	if not backpack or not id then
		return nil
	end
	for _, slime in backpack do
		if slime.id == id then
			return slime
		end
	end
	return nil
end

local function renderDetail()
	for _, child in detail:GetChildren() do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	local slime = findSlime(selectedId)
	if not slime then
		Kit.label({
			Text = "Tap a slime to inspect it",
			Font = Theme.BodyFont,
			TextColor3 = Theme.Colors.TextDim,
			Size = UDim2.new(1, -20, 0, 60),
			Position = UDim2.fromOffset(10, 20),
			TextWrapped = true,
			NoStroke = true,
			MaxTextSize = 22,
			Parent = detail,
		})
		return
	end
	Kit.slimeViewport(slime.s, slime.m, {
		Size = UDim2.new(1, -20, 0, 130),
		Position = UDim2.fromOffset(10, 6),
		Parent = detail,
	})
	Kit.label({
		Text = slimeTitle(slime),
		Size = UDim2.new(1, -16, 0, 48),
		Position = UDim2.fromOffset(8, 138),
		TextWrapped = true,
		MaxTextSize = 22,
		Parent = detail,
	})
	Kit.label({
		Text = `Weight {Format.multiplier(slime.w)} · Mutations {Format.multiplier(
			Economy.mutationMultiplier(slime.m)
		)}`,
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.TextDim,
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 188),
		NoStroke = true,
		MaxTextSize = 16,
		Parent = detail,
	})
	Kit.label({
		Text = `🪙 {Format.short(Economy.slimeValue(slime, sellMultiplier()))}`,
		TextColor3 = Theme.Colors.Coin,
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 210),
		MaxTextSize = 28,
		Parent = detail,
	})
	Kit.button({
		text = if slime.f then "★ Unfavorite" else "☆ Favorite",
		color = Theme.Colors.Gold,
		size = UDim2.new(1, -16, 0, 42),
		position = UDim2.new(0, 8, 1, -100),
		parent = detail,
		onClick = function()
			Net.event("ToggleFavorite"):FireServer(slime.id)
		end,
	})
	local sell = Kit.button({
		text = "Sell",
		color = Theme.Colors.Green,
		size = UDim2.new(1, -16, 0, 42),
		position = UDim2.new(0, 8, 1, -52),
		parent = detail,
		onClick = function()
			Net.event("SellSlime"):FireServer(slime.id)
			selectedId = nil
		end,
	})
	Kit.setEnabled(sell, not slime.f, Theme.Colors.Green)
end

local function render()
	dirty = false
	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local backpack = State.get("backpack") or {}
	local multiplier = sellMultiplier()
	local sorted: { any } = table.clone(backpack)
	table.sort(sorted, function(a: any, b: any)
		if (a.f == true) ~= (b.f == true) then
			return a.f == true
		end
		return Economy.slimeValue(a, 1) > Economy.slimeValue(b, 1)
	end)
	local total = 0
	for order, slime in sorted do
		local value = Economy.slimeValue(slime, multiplier)
		if not slime.f then
			total += value
		end
		local species = Species.byId[slime.s]
		local cell: TextButton = Kit.new("TextButton", {
			Name = tostring(slime.id),
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = Theme.Colors.PanelLight,
			LayoutOrder = order,
			Parent = grid,
		})
		Kit.corner(12).Parent = cell
		Kit.stroke(if species then Species.RarityColors[species.rarity] else Theme.Colors.Stroke, 2).Parent =
			cell
		local blob: Frame = Kit.new("Frame", {
			BackgroundColor3 = SlimeBuilder.displayColor(slime.s, slime.m),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(46, 38),
			Parent = cell,
		})
		Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = blob })
		Kit.stroke(Theme.Colors.Stroke, 2).Parent = blob
		Kit.label({
			Text = "• •",
			TextColor3 = Theme.Colors.Stroke,
			Size = UDim2.fromScale(1, 0.6),
			Position = UDim2.fromScale(0, 0.15),
			NoStroke = true,
			Parent = blob,
		})
		if #slime.m > 0 then
			Kit.label({
				Text = "✨",
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromOffset(4, 4),
				NoStroke = true,
				Parent = cell,
			})
		end
		if slime.f then
			Kit.label({
				Text = "★",
				TextColor3 = Theme.Colors.Gold,
				Size = UDim2.fromOffset(22, 22),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 4),
				Parent = cell,
			})
		end
		Kit.label({
			Text = Format.short(value),
			TextColor3 = Theme.Colors.Coin,
			Size = UDim2.new(1, -6, 0, 22),
			Position = UDim2.new(0, 3, 1, -26),
			MaxTextSize = 18,
			Parent = cell,
		})
		cell.Activated:Connect(function()
			selectedId = slime.id
			renderDetail()
		end)
	end
	local capacity = Economy.backpackCapacity(State.owns("vip"))
	summary.Text =
		`{#backpack}/{capacity} slimes · worth 🪙 {Format.short(total)}  (★ favorites are never sold, max {Config.Backpack.MaxFavorites})`
	renderDetail()
end

local function build(content: Frame)
	summary = Kit.label({
		Text = "",
		Font = Theme.BodyFont,
		Size = UDim2.new(1, -190, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = content,
	})
	Kit.button({
		text = "💰 Sell All",
		color = Theme.Colors.Gold,
		size = UDim2.fromOffset(170, 40),
		position = UDim2.new(1, 0, 0, -6),
		anchor = Vector2.new(1, 0),
		parent = content,
		onClick = function()
			Net.event("SellAll"):FireServer()
		end,
	})
	grid = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -210, 1, -40),
		Position = UDim2.fromOffset(0, 40),
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(84, 92),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	detail = Kit.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelDark,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 40),
		Size = UDim2.new(0, 200, 1, -40),
		Parent = content,
	})
	Kit.corner(14).Parent = detail
	render()
end

function BackpackWindow.start()
	Windows.register("Backpack", {
		title = "🎒 Backpack",
		color = Theme.Colors.Blue,
		size = Vector2.new(820, 520),
		build = build,
		onOpen = function()
			if dirty then
				render()
			end
		end,
	})
	State.Changed:Connect(function(section)
		if section == "backpack" or section == "boosts" then
			dirty = true
			if Windows.isOpen("Backpack") then
				render()
			end
		end
	end)
end

return BackpackWindow
