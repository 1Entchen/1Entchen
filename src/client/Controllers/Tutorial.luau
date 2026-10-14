--!strict
-- First-session guidance: a hint bubble plus a glowing beam and bouncing
-- arrow pointing at the next thing to do. Steps are driven by the server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))

local State = require(script.Parent.Parent:WaitForChild("State"))
local GardenView = require(script.Parent.GardenView)

local Tutorial = {}

local player = Players.LocalPlayer

local HINTS = {
	[0] = "👋 Welcome! Tap the glowing soil to plant your Goo Seed 🌱",
	[1] = "⏳ Your slime is growing! Slimes keep growing even while you're offline.",
	[2] = "✨ It's ripe! Tap your slime (or ✋ Harvest) to collect it.",
	[3] = "💰 Follow the arrow to the Sell Stand and sell your slimes!",
	[4] = "🌱 Now buy more seeds at the Seed Shop — then plant them all!",
}

local bubble: Frame
local bubbleText: TextLabel
local beam: Beam
local fromAttachment: Attachment?
local targetAttachment: Attachment
local anchorPart: Part
local arrow: BillboardGui
local tileHighlight: Highlight

local function hubPart(stall: string): BasePart?
	local world = Workspace:FindFirstChild("SlimeGarden")
	local hub = world and world:FindFirstChild("Hub")
	local model = hub and hub:FindFirstChild(stall)
	local counter = model and model:FindFirstChild("Counter")
	return if counter and counter:IsA("BasePart") then counter else nil
end

local function firstPlant(wantRipe: boolean?): Model?
	local plot = GardenView.ownPlot()
	local plants = plot and plot:FindFirstChild("Plants")
	if not plants then
		return nil
	end
	for _, model in plants:GetChildren() do
		if model:IsA("Model") and (wantRipe == nil or (model:GetAttribute("Ripe") == true) == wantRipe) then
			return model
		end
	end
	return nil
end

local function firstEmptyTile(): BasePart?
	local plot = GardenView.ownPlot()
	if not plot then
		return nil
	end
	local plants = plot:FindFirstChild("Plants")
	local best: BasePart? = nil
	local bestIndex = math.huge
	for _, child in plot:GetChildren() do
		local index = child:GetAttribute("TileIndex")
		if
			child:IsA("BasePart")
			and typeof(index) == "number"
			and child:GetAttribute("Usable")
			and index < bestIndex
			and not (plants and plants:FindFirstChild(`Plant{index}`))
		then
			best, bestIndex = child, index
		end
	end
	return best
end

local function targetFor(step: number): (BasePart?, BasePart?)
	if step == 0 then
		local tile = firstEmptyTile()
		return tile, tile
	elseif step == 1 then
		local plant = firstPlant(false)
		return if plant then plant.PrimaryPart else nil, nil
	elseif step == 2 then
		local plant = firstPlant(true)
		return if plant then plant.PrimaryPart else nil, nil
	elseif step == 3 then
		return hubPart("SellStand"), nil
	elseif step == 4 then
		return hubPart("SeedShop"), nil
	end
	return nil, nil
end

local function ensureFromAttachment(): Attachment?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	if fromAttachment and fromAttachment.Parent == root then
		return fromAttachment
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "TutorialFrom"
	attachment.Parent = root
	fromAttachment = attachment
	return attachment
end

local function update()
	local main = State.main()
	local step = if main then main.tutorialStep else 99
	local hint = HINTS[step]
	bubble.Visible = hint ~= nil
	if not hint then
		beam.Enabled = false
		arrow.Enabled = false
		tileHighlight.Enabled = false
		return
	end
	bubbleText.Text = hint
	if step == 0 and GardenView.selectedSeed == nil then
		GardenView.select("goo")
	end

	local target, highlightTarget = targetFor(step)
	local from = ensureFromAttachment()
	if target and from then
		anchorPart.CFrame = CFrame.new(target.Position + Vector3.new(0, target.Size.Y / 2 + 0.5, 0))
		beam.Attachment0 = from
		beam.Attachment1 = targetAttachment
		beam.Enabled = (from.WorldPosition - targetAttachment.WorldPosition).Magnitude > 8
		arrow.Enabled = true
	else
		beam.Enabled = false
		arrow.Enabled = false
	end
	tileHighlight.Adornee = highlightTarget
	tileHighlight.Enabled = highlightTarget ~= nil
end

function Tutorial.start()
	local _, canvas = Kit.screen("SlimeTutorial", 3)
	bubble = Kit.new("Frame", {
		Name = "Hint",
		BackgroundColor3 = Theme.Colors.Green,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.27, 0),
		Size = UDim2.fromOffset(560, 56),
		Visible = false,
		Parent = canvas,
	})
	Kit.corner(18).Parent = bubble
	Kit.stroke(Theme.Colors.Stroke, 4).Parent = bubble
	bubbleText = Kit.label({
		Text = "",
		Size = UDim2.new(1, -24, 1, -10),
		Position = UDim2.fromOffset(12, 5),
		MaxTextSize = 24,
		Parent = bubble,
	})

	anchorPart = Instance.new("Part")
	anchorPart.Name = "TutorialTarget"
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.CanTouch = false
	anchorPart.Transparency = 1
	anchorPart.Size = Vector3.one * 0.2
	anchorPart.Parent = Workspace
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = anchorPart

	beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(Color3.fromRGB(140, 255, 120))
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 0.7
	beam.Width1 = 0.7
	beam.Transparency = NumberSequence.new(0.25)
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = anchorPart

	arrow = Kit.new("BillboardGui", {
		Name = "TutorialArrow",
		Adornee = anchorPart,
		Size = UDim2.fromOffset(70, 70),
		StudsOffsetWorldSpace = Vector3.new(0, 4, 0),
		AlwaysOnTop = true,
		Enabled = false,
		Parent = anchorPart,
	})
	Kit.label({
		Text = "⬇️",
		Size = UDim2.fromScale(1, 1),
		NoStroke = true,
		MaxTextSize = 64,
		Parent = arrow,
	})

	tileHighlight = Kit.new("Highlight", {
		FillColor = Color3.fromRGB(140, 255, 120),
		FillTransparency = 0.45,
		OutlineColor = Color3.new(1, 1, 1),
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	RunService.RenderStepped:Connect(function()
		if arrow.Enabled then
			local t = os.clock()
			arrow.StudsOffsetWorldSpace = Vector3.new(0, 4 + math.abs(math.sin(t * 4)) * 1.2, 0)
			tileHighlight.FillTransparency = 0.35 + math.sin(t * 5) * 0.15
		end
	end)
	task.spawn(function()
		while true do
			update()
			task.wait(0.3)
		end
	end)
end

return Tutorial
