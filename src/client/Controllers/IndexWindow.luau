--!strict
-- Slimepedia (collection book) plus a full, plain-language odds sheet so
-- every random outcome in the game is disclosed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Mutations = require(Shared:WaitForChild("Mutations"))
local Species = require(Shared:WaitForChild("Species"))
local Weathers = require(Shared:WaitForChild("Weathers"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))
local Windows = require(UI:WaitForChild("Windows"))

local State = require(script.Parent.Parent:WaitForChild("State"))

local IndexWindow = {}

local cards: { [string]: { frame: Frame, cover: TextLabel, progress: TextLabel } } = {}
local summary: TextLabel
local collectionPage: ScrollingFrame
local oddsPage: ScrollingFrame
local oddsText: TextLabel
local tabButtons: { [string]: TextButton } = {}

local function currentLuck(): number
	local boosts = State.get("boosts")
	return if boosts then boosts.multipliers.luck else 1
end

local function buildOddsText(): string
	local luck = currentLuck()
	local lines = {
		"<b>SIZE (rolled when planted)</b>",
		"Normal x0.8–1.25: 75.5%   ·   Big x1.25–2: 20%",
		"Huge x2–4: 4%   ·   Titanic x4–6: 0.5%",
		"",
		`<b>VARIANTS (rolled once when a slime ripens) — your luck: x{luck}</b>`,
	}
	for _, mutation in Mutations.list do
		if mutation.kind == "variant" then
			table.insert(
				lines,
				`{mutation.name} ({Format.multiplier(mutation.multiplier)} value): {Format.percent(
					mutation.chance
				)} base, {Format.percent(math.min(mutation.chance * luck, 0.5))} for you`
			)
		end
	end
	table.insert(lines, "")
	table.insert(lines, "<b>WEATHER MUTATIONS (ripe slimes, per minute of weather)</b>")
	for _, mutation in Mutations.list do
		if mutation.kind == "weather" then
			local weather = Weathers.get(mutation.weather)
			table.insert(
				lines,
				`{mutation.name} ({Format.multiplier(mutation.multiplier)}) during {if weather
					then weather.name
					else "?"}: {Format.percent(mutation.chance)}/min base, {Format.percent(
					math.min(mutation.chance * luck, 0.95)
				)}/min for you`
			)
		end
	end
	table.insert(lines, "")
	table.insert(lines, "<b>WEATHER EVENTS</b> (every 9–13 min, 2.5 min long)")
	for _, weather in Weathers.list do
		table.insert(
			lines,
			`{weather.icon} {weather.name}: {Format.percent(weather.weight / Weathers.totalWeight)}`
		)
	end
	table.insert(lines, "")
	table.insert(lines, "<b>SEED SHOP RESTOCK</b> (every 5 min, chance a seed is in stock)")
	for _, species in Species.shopOrder do
		table.insert(
			lines,
			`{species.name}: {Format.percent(species.stockChance)} ({species.stockMin}–{species.stockMax} seeds)`
		)
	end
	table.insert(lines, "")
	table.insert(lines, "Robux purchases never contain random items. Luck boosts are listed in the Store.")
	return table.concat(lines, "\n")
end

local function refresh()
	local main = State.main()
	if not main then
		return
	end
	local index = main.index or {}
	local found, total = 0, 0
	for id, card in cards do
		local discovered = index[id] == true
		local variants = 0
		for _, mutation in Mutations.list do
			if index[`{id}:{mutation.id}`] then
				variants += 1
			end
		end
		total += 1 + #Mutations.list
		found += (if discovered then 1 else 0) + variants
		card.cover.Visible = not discovered
		card.progress.Text = if discovered
			then `✨ {variants}/{#Mutations.list} variants`
			else "Not discovered"
	end
	summary.Text =
		`Collection {found}/{total} ({math.floor(found / math.max(total, 1) * 100)}%) · first discoveries pay bonus coins!`
	oddsText.Text = buildOddsText()
end

local function selectTab(name: string)
	collectionPage.Visible = name == "Collection"
	oddsPage.Visible = name == "Odds"
	for tabName, button in tabButtons do
		button.BackgroundColor3 = if tabName == name then Theme.Colors.Purple else Theme.Colors.PanelLight
	end
end

local function build(content: Frame)
	local tabRow: Frame =
		Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Parent = content })
	Kit.list(Enum.FillDirection.Horizontal, 8).Parent = tabRow
	for i, name in { "Collection", "Odds" } do
		tabButtons[name] = Kit.button({
			text = if name == "Odds" then "🎲 Odds" else "📖 Collection",
			color = Theme.Colors.PanelLight,
			size = UDim2.fromOffset(170, 40),
			layoutOrder = i,
			parent = tabRow,
			onClick = function()
				selectTab(name)
			end,
		})
	end
	summary = Kit.label({
		Text = "",
		Font = Theme.BodyFont,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = content,
	})

	collectionPage = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -78),
		Position = UDim2.fromOffset(0, 78),
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(172, 200),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = collectionPage,
	})
	for _, species in Species.list do
		local frame: Frame = Kit.new("Frame", {
			Name = species.id,
			BackgroundColor3 = Theme.Colors.PanelLight,
			LayoutOrder = if species.tier == 0 then 99 else species.tier,
			Parent = collectionPage,
		})
		Kit.corner(14).Parent = frame
		Kit.stroke(Species.RarityColors[species.rarity], 3).Parent = frame
		Kit.slimeViewport(species.id, {}, {
			Size = UDim2.new(1, -20, 0, 100),
			Position = UDim2.fromOffset(10, 4),
			Parent = frame,
		})
		Kit.label({
			Text = species.name,
			TextColor3 = Species.RarityColors[species.rarity],
			Size = UDim2.new(1, -12, 0, 26),
			Position = UDim2.fromOffset(6, 106),
			MaxTextSize = 22,
			Parent = frame,
		})
		Kit.label({
			Text = if species.tier == 0
				then "Robux / Day 7 exclusive"
				else `{species.rarity} · {Format.short(species.value)} 🪙 · {Format.duration(
					species.growTime
				)}`,
			Font = Theme.BodyFont,
			TextColor3 = Theme.Colors.TextDim,
			Size = UDim2.new(1, -12, 0, 20),
			Position = UDim2.fromOffset(6, 134),
			NoStroke = true,
			MaxTextSize = 15,
			Parent = frame,
		})
		local progress = Kit.label({
			Text = "",
			Size = UDim2.new(1, -12, 0, 22),
			Position = UDim2.fromOffset(6, 160),
			MaxTextSize = 17,
			Parent = frame,
		})
		local cover = Kit.label({
			Text = "❓",
			BackgroundTransparency = 0.15,
			BackgroundColor3 = Theme.Colors.PanelDark,
			Size = UDim2.new(1, -20, 0, 100),
			Position = UDim2.fromOffset(10, 4),
			MaxTextSize = 60,
			NoStroke = true,
			Parent = frame,
		})
		Kit.corner(12).Parent = cover
		cards[species.id] = { frame = frame, cover = cover, progress = progress }
	end

	oddsPage = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -78),
		Position = UDim2.fromOffset(0, 78),
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = content,
	})
	oddsText = Kit.label({
		Text = "",
		Font = Theme.BodyFont,
		RichText = true,
		TextScaled = false,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -16, 0, 0),
		NoStroke = true,
		Parent = oddsPage,
	})
	selectTab("Collection")
	refresh()
end

function IndexWindow.start()
	Windows.register("Index", {
		title = "📖 Slimepedia",
		color = Theme.Colors.Purple,
		size = Vector2.new(820, 540),
		build = build,
		onOpen = refresh,
	})
	State.Changed:Connect(function(section)
		if Windows.isOpen("Index") and (section == "main" or section == "boosts") then
			refresh()
		end
	end)
end

-- Used by the store/odds links.
function IndexWindow.openOdds()
	Windows.open("Index")
	selectTab("Odds")
end

return IndexWindow
