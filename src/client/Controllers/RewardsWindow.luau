--!strict
-- Daily login rewards (7-day streak) and daily quests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))
local Windows = require(UI:WaitForChild("Windows"))

local State = require(script.Parent.Parent:WaitForChild("State"))

local RewardsWindow = {}

local dayCards: { Frame } = {}
local claimButton: TextButton
local streakLabel: TextLabel
local questRows: { { frame: Frame, text: TextLabel, fill: Frame, progress: TextLabel, claim: TextButton } } =
	{}
local resetLabel: TextLabel

local function refreshDaily()
	local daily = State.get("daily")
	if not daily or not claimButton then
		return
	end
	streakLabel.Text =
		`🔥 Streak: {daily.streak} day(s) · come back every day — missing a day restarts at Day 1`
	for day, card in dayCards do
		local preview = daily.preview[day]
		local icon = card:FindFirstChild("Icon") :: TextLabel
		local label = card:FindFirstChild("Reward") :: TextLabel
		if preview then
			icon.Text = preview.icon
			label.Text = preview.label
		end
		local isNext = day == daily.cycleDay
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if isNext and daily.canClaim then Theme.Colors.Gold else Theme.Colors.Stroke
			stroke.Thickness = if isNext and daily.canClaim then 5 else 3
		end
		card.BackgroundColor3 = if isNext and daily.canClaim
			then Theme.Colors.GoldDark
			else Theme.Colors.PanelLight
	end
	if daily.canClaim then
		claimButton.Text = `🎁 Claim Day {daily.cycleDay}!`
		Kit.setEnabled(claimButton, true, Theme.Colors.Green)
	else
		claimButton.Text = `Next reward in {Format.duration(daily.secondsToReset)}`
		Kit.setEnabled(claimButton, false, Theme.Colors.Green)
	end
end

local function refreshQuests()
	local daily = State.get("daily")
	if not daily or #questRows == 0 then
		return
	end
	for i, row in questRows do
		local quest = daily.quests[i]
		row.frame.Visible = quest ~= nil
		if quest then
			row.text.Text = quest.text
			local pct = math.clamp(quest.progress / math.max(quest.target, 1), 0, 1)
			row.fill.Size = UDim2.fromScale(pct, 1)
			local reward = `🪙 {Format.short(quest.rewardCoins)}`
			if quest.rewardItem then
				reward ..= if quest.rewardItem == "luck" then " + 🔮" else " + 🧪"
			end
			row.progress.Text = `{Format.short(quest.progress)}/{Format.short(quest.target)} · {reward}`
			if quest.claimed then
				row.claim.Text = "Done ✓"
				Kit.setEnabled(row.claim, false, Theme.Colors.Green)
			elseif quest.progress >= quest.target then
				row.claim.Text = "Claim!"
				Kit.setEnabled(row.claim, true, Theme.Colors.Green)
			else
				row.claim.Text = "In progress"
				Kit.setEnabled(row.claim, false, Theme.Colors.Green)
			end
		end
	end
	resetLabel.Text = `New quests in {Format.duration(daily.secondsToReset)}`
end

local function buildDaily(content: Frame)
	streakLabel = Kit.label({
		Text = "",
		Font = Theme.BodyFont,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = content,
	})
	local row: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 220),
		Position = UDim2.fromOffset(0, 34),
		Parent = content,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new(1 / 7, -8, 1, 0),
		CellPadding = UDim2.fromOffset(8, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	for day = 1, 7 do
		local card: Frame = Kit.new("Frame", {
			Name = `Day{day}`,
			BackgroundColor3 = Theme.Colors.PanelLight,
			LayoutOrder = day,
			Parent = row,
		})
		Kit.corner(14).Parent = card
		Kit.stroke(Theme.Colors.Stroke, 3).Parent = card
		Kit.label({
			Text = `Day {day}`,
			Size = UDim2.new(1, -8, 0, 26),
			Position = UDim2.fromOffset(4, 6),
			MaxTextSize = 20,
			Parent = card,
		})
		Kit.label({
			Name = "Icon",
			Text = "🎁",
			Size = UDim2.new(1, 0, 0, 60),
			Position = UDim2.fromOffset(0, 36),
			NoStroke = true,
			MaxTextSize = 46,
			Parent = card,
		})
		Kit.label({
			Name = "Reward",
			Text = "",
			Font = Theme.BodyFont,
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 100),
			Position = UDim2.fromOffset(4, 104),
			MaxTextSize = 16,
			NoStroke = true,
			Parent = card,
		})
		dayCards[day] = card
	end
	claimButton = Kit.button({
		text = "Claim",
		size = UDim2.fromOffset(320, 56),
		position = UDim2.new(0.5, 0, 1, -6),
		anchor = Vector2.new(0.5, 1),
		parent = content,
		onClick = function()
			Net.event("ClaimDaily"):FireServer()
		end,
	})
	refreshDaily()
end

local function buildQuests(content: Frame)
	resetLabel = Kit.label({
		Text = "",
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.TextDim,
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = content,
	})
	for i = 1, 3 do
		local frame: Frame = Kit.new("Frame", {
			BackgroundColor3 = Theme.Colors.PanelLight,
			Size = UDim2.new(1, 0, 0, 96),
			Position = UDim2.fromOffset(0, 30 + (i - 1) * 106),
			Parent = content,
		})
		Kit.corner(14).Parent = frame
		Kit.stroke(Theme.Colors.Stroke, 3).Parent = frame
		local text = Kit.label({
			Text = "",
			Size = UDim2.new(1, -190, 0, 32),
			Position = UDim2.fromOffset(14, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 24,
			Parent = frame,
		})
		local bar: Frame = Kit.new("Frame", {
			BackgroundColor3 = Theme.Colors.PanelDark,
			Size = UDim2.new(1, -190, 0, 18),
			Position = UDim2.fromOffset(14, 46),
			Parent = frame,
		})
		Kit.corner(9).Parent = bar
		local fill: Frame = Kit.new(
			"Frame",
			{ BackgroundColor3 = Theme.Colors.Green, Size = UDim2.fromScale(0, 1), Parent = bar }
		)
		Kit.corner(9).Parent = fill
		local progress = Kit.label({
			Text = "",
			Font = Theme.BodyFont,
			TextColor3 = Theme.Colors.TextDim,
			Size = UDim2.new(1, -190, 0, 20),
			Position = UDim2.fromOffset(14, 68),
			TextXAlignment = Enum.TextXAlignment.Left,
			NoStroke = true,
			MaxTextSize = 17,
			Parent = frame,
		})
		local claim = Kit.button({
			text = "Claim",
			size = UDim2.fromOffset(150, 52),
			position = UDim2.new(1, -14, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			parent = frame,
			onClick = function()
				Net.event("ClaimQuest"):FireServer(i)
			end,
		})
		questRows[i] = { frame = frame, text = text, fill = fill, progress = progress, claim = claim }
	end
	refreshQuests()
end

function RewardsWindow.start()
	Windows.register("Rewards", {
		title = "🎁 Daily Rewards",
		color = Theme.Colors.Pink,
		size = Vector2.new(820, 400),
		build = buildDaily,
		onOpen = refreshDaily,
	})
	Windows.register("Quests", {
		title = "📜 Daily Quests",
		color = Theme.Colors.Green,
		size = Vector2.new(700, 420),
		build = buildQuests,
		onOpen = refreshQuests,
	})
	State.Changed:Connect(function(section)
		if section == "daily" then
			if Windows.isOpen("Rewards") then
				refreshDaily()
			elseif Windows.isOpen("Quests") then
				refreshQuests()
			end
		end
	end)
	-- Pop the daily reward open once when there is something to claim.
	local shown = false
	State.Changed:Connect(function(section)
		local daily = State.get("daily")
		local main = State.main()
		if
			section == "daily"
			and not shown
			and daily
			and daily.canClaim
			and main
			and main.tutorialStep >= 5
		then
			shown = true
			task.delay(2, function()
				if not Windows.current() then
					Windows.open("Rewards")
				end
			end)
		end
	end)
end

return RewardsWindow
