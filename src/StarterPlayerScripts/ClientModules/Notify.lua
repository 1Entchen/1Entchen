--[[
	Notify  (ModuleScript)  ->  StarterPlayer/StarterPlayerScripts/ClientModules/Notify
	Toasts (mit optionalem Kauf-Button), Server-Ansagen, Effekte
	(Reveal, Alarm, Konfetti, Rebirth, Bonk, Rare-Spawn).
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))
local Format = require(Shared:WaitForChild("Format"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local C = UIKit.Colors

local Notify = {}
local App
local toastHolder, bannerHolder, fxLayer
local bannerQueue = {}
local bannerBusy = false
local toastCounter = 0

local KIND_COLORS = {
	info = C.Panel2,
	success = Color3.fromRGB(40, 150, 70),
	cash = Color3.fromRGB(30, 130, 60),
	error = Color3.fromRGB(170, 40, 50),
	warning = Color3.fromRGB(190, 120, 20),
}

------------------------------------------------------------------------
-- Toasts
------------------------------------------------------------------------
function Notify.Toast(text, kind, offer)
	local holder = toastHolder
	local count = 0
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("Frame") then
			count += 1
		end
	end
	if count >= 4 then
		for _, child in ipairs(holder:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end

	toastCounter += 1
	local hasOffer = offer ~= nil and App.OfferInfo(offer) ~= nil
	local toast = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, hasOffer and 64 or 46),
		BackgroundColor3 = KIND_COLORS[kind] or C.Panel2,
		LayoutOrder = toastCounter,
		Parent = holder,
	})
	UIKit.corner(toast, 12)
	UIKit.stroke(toast, C.Dark, 3)
	UIKit.label({
		Size = UDim2.new(hasOffer and 0.66 or 1, -12, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = text,
		MaxText = 26,
		Parent = toast,
	})
	if hasOffer then
		local info = App.OfferInfo(offer)
		UIKit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0.32, 0, 0, 48),
			Color = C.Robux,
			Text = info.Icon .. " " .. info.Short .. "\nR$ " .. info.Price,
			MaxText = 20,
			Parent = toast,
		}, function()
			App.Buy(offer)
		end)
	end

	local scale = UIKit.new("UIScale", { Scale = 0.6, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(hasOffer and 6 or 3.2, function()
		if toast.Parent then
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
			task.wait(0.2)
			toast:Destroy()
		end
	end)
end

------------------------------------------------------------------------
-- Banner (Server-Ansagen)
------------------------------------------------------------------------
local function showNextBanner()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local item = table.remove(bannerQueue, 1)
	local banner = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -80),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = C.Panel,
		Parent = bannerHolder,
	})
	UIKit.corner(banner, 14)
	UIKit.stroke(banner, item.Color, 3)
	UIKit.label({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = item.Text,
		TextColor3 = item.Color,
		MaxText = 28,
		Parent = banner,
	})
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 0) }):Play()
	task.delay(4.2, function()
		TweenService:Create(banner, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
		task.wait(0.3)
		banner:Destroy()
		bannerBusy = false
		showNextBanner()
	end)
end

function Notify.Announce(text, color)
	table.insert(bannerQueue, { Text = text, Color = color or C.Accent })
	while #bannerQueue > 5 do
		table.remove(bannerQueue, 1)
	end
	showNextBanner()
end

------------------------------------------------------------------------
-- Effekte
------------------------------------------------------------------------
local function flash(color, times, duration)
	local frame = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = fxLayer,
	})
	task.spawn(function()
		for _ = 1, times do
			TweenService:Create(frame, TweenInfo.new(duration / 2), { BackgroundTransparency = 0.6 }):Play()
			task.wait(duration / 2)
			TweenService:Create(frame, TweenInfo.new(duration / 2), { BackgroundTransparency = 1 }):Play()
			task.wait(duration / 2)
		end
		frame:Destroy()
	end)
end

function Notify.Confetti()
	local colors = { C.Accent, C.Pink, C.Blue, C.Green, C.Purple, C.Red }
	for _ = 1, 45 do
		local piece = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(math.random(), -0.05),
			Size = UDim2.fromOffset(math.random(8, 16), math.random(12, 22)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = colors[math.random(1, #colors)],
			BorderSizePixel = 0,
			ZIndex = 60,
			Parent = fxLayer,
		})
		local duration = 1.6 + math.random() * 1.4
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 1.1),
			Rotation = piece.Rotation + math.random(-360, 360),
		}):Play()
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

function Notify.Reveal(id, mutation, title)
	local fig = Figures.Get(id)
	if not fig then
		return
	end
	local rarity = Config.Rarities[fig.Rarity]
	local card = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, 230),
		BackgroundColor3 = C.Panel,
		ZIndex = 70,
		Parent = fxLayer,
	})
	UIKit.corner(card, 20)
	UIKit.stroke(card, rarity.Color, 5)
	local scale = UIKit.new("UIScale", { Scale = 0, Parent = card })
	local glow = UIKit.new("UIGradient", {
		Color = ColorSequence.new(C.Panel, rarity.Color),
		Rotation = 0,
		Parent = card,
	})
	UIKit.label({ Size = UDim2.new(1, 0, 0.22, 0), Position = UDim2.fromScale(0, 0.05), Text = title or "NEU!", TextColor3 = C.Accent, ZIndex = 71, MaxText = 36, Parent = card })
	UIKit.label({ Size = UDim2.new(1, -20, 0.32, 0), Position = UDim2.new(0, 10, 0.28, 0), Text = Figures.DisplayName(id, mutation), ZIndex = 71, MaxText = 44, Parent = card })
	UIKit.label({ Size = UDim2.new(1, 0, 0.18, 0), Position = UDim2.fromScale(0, 0.6), Text = rarity.Display, TextColor3 = rarity.Color, ZIndex = 71, MaxText = 30, Parent = card })
	UIKit.label({ Size = UDim2.new(1, 0, 0.16, 0), Position = UDim2.fromScale(0, 0.8), Text = Format.Money(Figures.Income(id, mutation)) .. "/s", TextColor3 = Color3.fromRGB(255, 230, 90), ZIndex = 71, MaxText = 26, Parent = card })

	App.Sound(rarity.Rank >= 5 and "Secret" or "Legendary")
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(glow, TweenInfo.new(2.6, Enum.EasingStyle.Linear), { Rotation = 360 }):Play()
	if rarity.Rank >= 4 then
		Notify.Confetti()
	end
	task.delay(2.6, function()
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
		task.wait(0.25)
		card:Destroy()
	end)
end

local function bigText(text, color, duration)
	local label = UIKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(700, 110),
		Text = text,
		TextColor3 = color,
		ZIndex = 80,
		MaxText = 80,
		Parent = fxLayer,
	})
	local scale = UIKit.new("UIScale", { Scale = 0.3, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(duration, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.3)
		label:Destroy()
	end)
end

local function shakeCamera(strength, duration)
	local camera = Workspace.CurrentCamera
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < duration do
			local offset = Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
			camera.CFrame = camera.CFrame * CFrame.new(offset)
			task.wait()
		end
	end)
end

function Notify.Effect(kind, payload)
	payload = payload or {}
	if kind == "Reveal" then
		Notify.Reveal(payload.Id, payload.Mut, payload.Text)
	elseif kind == "Confetti" then
		Notify.Confetti()
		App.Sound("Reward")
	elseif kind == "Alarm" then
		flash(C.Red, 3, 0.5)
		bigText("⚠ DIEB! ⚠", C.Red, 1.8)
	elseif kind == "Rebirth" then
		flash(C.Accent, 1, 0.8)
		bigText(("⭐ REBIRTH %d ⭐"):format(payload.Rebirths or 0), C.Accent, 2.5)
		Notify.Confetti()
	elseif kind == "Bonked" then
		bigText("BONK!", C.Pink, 0.8)
		shakeCamera(0.6, 0.3)
		App.Sound("Bonk")
	elseif kind == "RareSpawn" then
		local fig = Figures.Get(payload.Id)
		if fig then
			local rarity = Config.Rarities[fig.Rarity]
			Notify.Toast(("🚨 %s auf dem Band: %s!"):format(rarity.Display, Figures.DisplayName(payload.Id, payload.Mut)), "warning")
			App.Sound(rarity.Rank >= 5 and "Secret" or "Legendary")
		end
	elseif kind == "Offline" then
		App.Menus.ShowOffline(payload)
	end
end

function Notify.Init(app)
	App = app
	local gui = app.Gui

	toastHolder = UIKit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(460, 300),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = gui,
	})
	UIKit.new("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = toastHolder,
	})

	bannerHolder = UIKit.new("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(620, 60),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Parent = gui,
	})

	fxLayer = UIKit.new("Frame", {
		Name = "Effects",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = gui,
	})
end

return Notify
