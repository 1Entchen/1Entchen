--!strict
-- Local weather visuals: particles around the camera plus a lighting tint.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Weathers = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weathers"))

local State = require(script.Parent.Parent:WaitForChild("State"))

local WeatherFX = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local DEFAULT_CLOCK = 14.2

local emitterPart: Part
local emitter: ParticleEmitter
local tint: ColorCorrectionEffect
local current: string? = nil

type Preset = {
	color: ColorSequence,
	rate: number,
	speed: NumberRange,
	size: NumberSequence,
	lifetime: NumberRange,
	acceleration: Vector3,
	spread: Vector2,
	clockTime: number,
}

local PRESETS: { [string]: Preset } = {
	goorain = {
		color = ColorSequence.new(Color3.fromRGB(140, 255, 150), Color3.fromRGB(90, 220, 255)),
		rate = 260,
		speed = NumberRange.new(55, 70),
		size = NumberSequence.new(0.35),
		lifetime = NumberRange.new(1.2, 1.6),
		acceleration = Vector3.new(0, -20, 0),
		spread = Vector2.new(5, 5),
		clockTime = 13,
	},
	goldenhour = {
		color = ColorSequence.new(Color3.fromRGB(255, 220, 120)),
		rate = 50,
		speed = NumberRange.new(1, 3),
		size = NumberSequence.new(0.4, 0),
		lifetime = NumberRange.new(4, 6),
		acceleration = Vector3.new(0, -1, 0),
		spread = Vector2.new(180, 180),
		clockTime = 17.4,
	},
	snowfall = {
		color = ColorSequence.new(Color3.new(1, 1, 1)),
		rate = 180,
		speed = NumberRange.new(6, 10),
		size = NumberSequence.new(0.45),
		lifetime = NumberRange.new(5, 7),
		acceleration = Vector3.new(1.5, -2, 0),
		spread = Vector2.new(20, 20),
		clockTime = 12.5,
	},
	starfall = {
		color = ColorSequence.new(Color3.fromRGB(210, 170, 255), Color3.fromRGB(120, 210, 255)),
		rate = 40,
		speed = NumberRange.new(70, 90),
		size = NumberSequence.new(1.4, 0.2),
		lifetime = NumberRange.new(0.9, 1.2),
		acceleration = Vector3.zero,
		spread = Vector2.new(25, 25),
		clockTime = 20.5,
	},
}

local function apply(id: string?)
	if id == current then
		return
	end
	current = id
	local weather = Weathers.get(id)
	local preset = if id then PRESETS[id] else nil
	local tweenInfo = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	if weather and preset then
		emitter.Color = preset.color
		emitter.Rate = preset.rate
		emitter.Speed = preset.speed
		emitter.Size = preset.size
		emitter.Lifetime = preset.lifetime
		emitter.Acceleration = preset.acceleration
		emitter.SpreadAngle = preset.spread
		emitter.Enabled = true
		TweenService:Create(tint, tweenInfo, { TintColor = weather.tint }):Play()
		TweenService:Create(Lighting, tweenInfo, { ClockTime = preset.clockTime }):Play()
	else
		emitter.Enabled = false
		TweenService:Create(tint, tweenInfo, { TintColor = Color3.new(1, 1, 1) }):Play()
		TweenService:Create(Lighting, tweenInfo, { ClockTime = DEFAULT_CLOCK }):Play()
	end
end

function WeatherFX.start()
	emitterPart = Instance.new("Part")
	emitterPart.Name = "WeatherEmitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(140, 1, 140)
	emitterPart.Parent = Workspace

	emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.LightEmission = 0.7
	emitter.Enabled = false
	emitter.Parent = emitterPart

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "WeatherTint"
	tint.Parent = Lighting

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera and emitter.Enabled then
			local position = camera.CFrame.Position
			emitterPart.CFrame = CFrame.new(position.X, position.Y + 45, position.Z)
		end
	end)

	State.Changed:Connect(function(section)
		if section == "weather" then
			local weather = State.weather
			apply(if weather then weather.id else nil)
		end
	end)
end

return WeatherFX
