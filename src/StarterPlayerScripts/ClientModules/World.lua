--[[
	World  (ModuleScript)  ->  StarterPlayer/StarterPlayerScripts/ClientModules/World
	Rein optische Client-Effekte:
	  - Prompts filtern (eigene Figuren: Verkaufen statt Stehlen)
	  - Meisterdieb: kürzere Haltezeit anzeigen (Server prüft selbst)
	  - Regenbogen-Figuren, Secret-Namen in Regenbogenfarben
	  - laufende Streifen auf dem Förderband
	  - "DEINE BASIS"-Markierung
	  - VIP-Tag im Chat, Musik
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local World = {}
local App
local player = Players.LocalPlayer
local hasMasterThief = false

local function applyPrompt(prompt, tag)
	local isMine = prompt:GetAttribute("OwnerId") == player.UserId
	if tag == "StealPrompt" then
		prompt.Enabled = not isMine
		prompt.HoldDuration = hasMasterThief and Config.Steal.MasterHoldTime or Config.Steal.HoldTime
	elseif tag == "OwnerOnlyPrompt" then
		prompt.Enabled = isMine
	end
end

local function watchTag(tag)
	for _, prompt in ipairs(CollectionService:GetTagged(tag)) do
		applyPrompt(prompt, tag)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(prompt)
		applyPrompt(prompt, tag)
	end)
end

local function rainbowLoop()
	while true do
		task.wait(0.1)
		local hue = (os.clock() * 0.25) % 1
		local color = Color3.fromHSV(hue, 0.85, 1)
		for _, model in ipairs(CollectionService:GetTagged("RainbowFigure")) do
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "Root" and not part:GetAttribute("NoTint") then
					part.Color = color
				end
			end
		end
		for _, model in ipairs(CollectionService:GetTagged("SecretFigure")) do
			local root = model.PrimaryPart
			local info = root and root:FindFirstChild("Info")
			if info and info:FindFirstChild("RarityLabel") then
				info.RarityLabel.TextColor3 = color
			end
		end
	end
end

local function animateBelt()
	local conveyor = Workspace:WaitForChild("Conveyor", 30)
	local stripesFolder = conveyor and conveyor:WaitForChild("Stripes", 10)
	if not stripesFolder then
		return
	end
	local stripes = stripesFolder:GetChildren()
	local origins = {}
	for i, stripe in ipairs(stripes) do
		origins[i] = stripe.CFrame
	end
	local length = 180
	local speed = length / Config.Conveyor.TravelTime
	RunService.RenderStepped:Connect(function()
		local offset = (os.clock() * speed) % 10
		for i, stripe in ipairs(stripes) do
			local origin = origins[i]
			local x = origin.Position.X + offset
			if x > 90 then
				x -= length
			end
			stripe.CFrame = CFrame.new(x, origin.Position.Y, origin.Position.Z)
		end
	end)
end

local function markOwnBase()
	local bases = Workspace:WaitForChild("Bases")
	local function check(base)
		if base:GetAttribute("OwnerId") ~= player.UserId then
			return
		end
		local sign = base:WaitForChild("Sign", 10)
		if not sign or sign:FindFirstChild("MineMarker") then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "MineMarker"
		gui.Size = UDim2.new(14, 0, 3, 0)
		gui.StudsOffset = Vector3.new(0, 6, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 1000
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = "⬇ DEINE BASIS ⬇"
		label.TextColor3 = Color3.fromRGB(120, 255, 140)
		label.TextStrokeTransparency = 0
		label.Parent = gui
		gui.Parent = sign
	end
	for _, base in ipairs(bases:GetChildren()) do
		task.spawn(check, base)
	end
	bases.ChildAdded:Connect(function(base)
		task.wait(0.5)
		check(base)
	end)
end

local function setupChatTags()
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local sender = Players:GetPlayerByUserId(source.UserId)
			if sender and sender:GetAttribute("VIP") then
				props.PrefixText = "<font color='#FFD700'>[👑 VIP]</font> " .. message.PrefixText
			end
		end
		return props
	end
end

function World.Update(state)
	local master = state.Passes.MasterThief == true
	if master ~= hasMasterThief then
		hasMasterThief = master
		for _, prompt in ipairs(CollectionService:GetTagged("StealPrompt")) do
			applyPrompt(prompt, "StealPrompt")
		end
	end
end

function World.Init(app)
	App = app
	watchTag("StealPrompt")
	watchTag("OwnerOnlyPrompt")
	task.spawn(rainbowLoop)
	task.spawn(animateBelt)
	task.spawn(markOwnBase)
	pcall(setupChatTags)

	local music = SoundService:FindFirstChild("Music")
	if music and music.SoundId ~= "" then
		music:Play()
	end
end

return World
