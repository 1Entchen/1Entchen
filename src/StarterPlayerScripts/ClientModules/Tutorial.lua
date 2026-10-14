--[[
	Tutorial  (ModuleScript)  ->  StarterPlayer/StarterPlayerScripts/ClientModules/Tutorial
	Führt neue Spieler mit Text + leuchtendem Pfeil durch die ersten Schritte:
	  1. Figur am Förderband kaufen
	  2. Cash am grünen Feld einsammeln
	  3. Basis abschließen
	Wird nur gezeigt, solange ein Spieler insgesamt weniger als 5.000 Cash verdient hat.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local C = UIKit.Colors

local Tutorial = {}
local App
local player = Players.LocalPlayer

local step = 0 -- 0 = noch nicht gestartet, 4 = fertig
local collected = false
local panel, label
local beam, attachTarget

local STEPS = {
	{ Text = "👉 Lauf zum FÖRDERBAND und kauf eine Figur (E drücken / antippen)!" },
	{ Text = "💰 Super! Lauf jetzt über das GRÜNE Feld in deiner Basis, um Cash einzusammeln." },
	{ Text = "🔒 Schließ deine Basis mit dem ROTEN Knopf ab, damit niemand klaut!" },
}

local function ownBase()
	local bases = Workspace:FindFirstChild("Bases")
	if not bases then
		return nil
	end
	for _, base in ipairs(bases:GetChildren()) do
		if base:GetAttribute("OwnerId") == player.UserId then
			return base
		end
	end
	return nil
end

local function targetPart()
	if step == 1 then
		local conveyor = Workspace:FindFirstChild("Conveyor")
		return conveyor and conveyor:FindFirstChild("Belt")
	end
	local base = ownBase()
	if not base then
		return nil
	end
	if step == 2 then
		return base:FindFirstChild("CashPad")
	elseif step == 3 then
		return base:FindFirstChild("LockButton")
	end
	return nil
end

local function updateBeam()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = targetPart()
	if not root or not target or step < 1 or step > 3 then
		if beam then
			beam.Enabled = false
		end
		return
	end
	if not beam or not beam.Parent then
		local a0 = Instance.new("Attachment")
		a0.Name = "TutorialFrom"
		a0.Parent = root
		attachTarget = Instance.new("Attachment")
		attachTarget.Name = "TutorialTo"
		beam = Instance.new("Beam")
		beam.Name = "TutorialBeam"
		beam.Attachment0 = a0
		beam.Attachment1 = attachTarget
		beam.Width0 = 1.2
		beam.Width1 = 1.2
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 60), Color3.fromRGB(90, 255, 120))
		beam.Transparency = NumberSequence.new(0.15)
		beam.Parent = root
	end
	if attachTarget.Parent ~= target then
		attachTarget.Parent = target
		attachTarget.Position = Vector3.new(0, 1.5, 0)
	end
	beam.Enabled = true
end

local function setStep(newStep)
	if newStep == step then
		return
	end
	step = newStep
	if step >= 1 and step <= 3 then
		panel.Visible = true
		label.Text = ("Schritt %d/3: %s"):format(step, STEPS[step].Text)
		local scale = panel:FindFirstChildOfClass("UIScale")
		scale.Scale = 0.7
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		App.Sound("Reward")
	else
		panel.Visible = false
		if beam then
			beam.Enabled = false
		end
		if step == 4 then
			App.Notify.Toast("🎉 Tutorial geschafft! Sammle seltene Figuren und werde der reichste Bandit!", "success")
			App.Notify.Confetti()
		end
	end
	updateBeam()
end

function Tutorial.OnCashCollected()
	collected = true
end

function Tutorial.Update(state)
	if step == 4 then
		return
	end
	if step == 0 then
		if state.TotalEarned >= 5000 then
			step = 4 -- erfahrener Spieler: kein Tutorial
			return
		end
		setStep(1)
	end
	local owned = false
	for _, slot in ipairs(state.Slots) do
		if slot.Id then
			owned = true
			break
		end
	end
	if step == 1 and owned then
		setStep(2)
	end
	if step == 2 and (collected or state.Passes.AutoCollect) then
		setStep(3)
	end
	if step == 3 and state.LockRemaining > 0 then
		setStep(4)
	end
	updateBeam()
end

function Tutorial.Init(app)
	App = app
	panel = UIKit.new("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 165),
		Size = UDim2.fromOffset(640, 70),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = app.Gui,
	})
	UIKit.corner(panel, 16)
	UIKit.stroke(panel, C.Accent, 4)
	UIKit.new("UIScale", { Parent = panel })
	label = UIKit.label({
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Text = "",
		MaxText = 26,
		Parent = panel,
	})
	player.CharacterAdded:Connect(function()
		beam = nil
		task.wait(1)
		updateBeam()
	end)
end

return Tutorial
