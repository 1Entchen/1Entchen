--!strict
-- Toasts, server-wide announcements (also mirrored into chat), floating
-- reward text and the reaction to server "Effect" events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Mutations = require(Shared:WaitForChild("Mutations"))
local Net = require(Shared:WaitForChild("Net"))
local SlimeBuilder = require(Shared:WaitForChild("SlimeBuilder"))
local Species = require(Shared:WaitForChild("Species"))
local Economy = require(Shared:WaitForChild("Economy"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))

local Sounds = require(script.Parent.Sounds)

local Notifications = {}

local root: Frame
local toastList: Frame
local announceFrame: Frame

local KIND_COLORS: { [string]: Color3 } = {
	info = Theme.Colors.PanelLight,
	success = Theme.Colors.GreenDark,
	error = Color3.fromRGB(170, 50, 60),
	reward = Theme.Colors.GoldDark,
}

function Notifications.toast(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	local toast: Frame = Kit.new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(460, 44),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		Parent = toastList,
	})
	Kit.corner(12).Parent = toast
	Kit.stroke(Theme.Colors.Stroke, 3).Parent = toast
	Kit.padding(8).Parent = toast
	Kit.label({
		Text = text,
		Font = Theme.Font,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = toast,
	})
	Kit.pop(toast, 0.8)
	if kind == "error" then
		Sounds.play("Error", 0.7)
	end
	-- Keep at most 4 toasts on screen.
	local toasts = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 4 then
		toasts[1]:Destroy()
	end
	task.delay(3.5, function()
		if toast.Parent then
			TweenService:Create(toast, Theme.Tween.Smooth, { BackgroundTransparency = 1 }):Play()
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

local function systemChat(text: string, color: Color3?)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local system = channels and channels:FindFirstChild("RBXSystem")
	if system and system:IsA("TextChannel") then
		local hex = (color or Theme.Colors.Gold):ToHex()
		pcall(function()
			system:DisplaySystemMessage(`<font color="#{hex}">{text}</font>`)
		end)
	end
end

function Notifications.announce(text: string, color: Color3?)
	local banner = announceFrame:FindFirstChild("Banner") :: TextLabel
	banner.Text = text
	banner.TextColor3 = color or Theme.Colors.Gold
	announceFrame.Visible = true
	Kit.pop(announceFrame, 0.7)
	local previous = announceFrame:GetAttribute("Token")
	local token = (if typeof(previous) == "number" then previous else 0) + 1
	announceFrame:SetAttribute("Token", token)
	task.delay(5, function()
		if announceFrame:GetAttribute("Token") == token then
			announceFrame.Visible = false
		end
	end)
	systemChat(text, color)
end

-- Text that floats up from the screen centre (or a given position) and fades.
function Notifications.float(text: string, color: Color3?, position: UDim2?)
	local label = Kit.label({
		Text = text,
		TextColor3 = color or Theme.Colors.Coin,
		Size = UDim2.fromOffset(420, 48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.42),
		MaxTextSize = 40,
		ZIndex = 30,
		Parent = root,
	})
	Kit.pop(label, 0.6)
	local target = label.Position - UDim2.fromOffset(0, 70)
	TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = target,
		TextTransparency = 1,
	}):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(1.4), { Transparency = 1 }):Play()
	end
	task.delay(1.5, function()
		label:Destroy()
	end)
end

-- Coin icons flying to the coin counter.
local coinTarget: GuiObject? = nil
function Notifications.setCoinTarget(target: GuiObject)
	coinTarget = target
end

local function coinBurst(count: number)
	if not coinTarget then
		return
	end
	local target = coinTarget :: GuiObject
	local rootPos = root.AbsolutePosition
	local scaleObj = root:FindFirstAncestorOfClass("ScreenGui")
	local uiScale = if scaleObj then scaleObj:FindFirstChildOfClass("UIScale") else nil
	local s = if uiScale then uiScale.Scale else 1
	local targetPos = (target.AbsolutePosition + target.AbsoluteSize / 2 - rootPos) / s
	for i = 1, math.clamp(count, 3, 10) do
		local coin = Kit.label({
			Text = "🪙",
			Size = UDim2.fromOffset(34, 34),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.random(-120, 120), 0.55, math.random(-60, 60)),
			NoStroke = true,
			ZIndex = 31,
			Parent = root,
		})
		task.delay(i * 0.04, function()
			local tween = TweenService:Create(
				coin,
				TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = UDim2.fromOffset(targetPos.X, targetPos.Y),
				}
			)
			tween:Play()
			tween.Completed:Wait()
			coin:Destroy()
			Kit.pop(target, 1.08)
		end)
	end
end

local function describeSlime(speciesId: string, mutations: { string }, weight: number): string
	local species = Species.byId[speciesId]
	local parts = {}
	local mutationText = SlimeBuilder.mutationNames(mutations)
	if mutationText ~= "" then
		table.insert(parts, mutationText)
	end
	local weightLabel = Economy.weightLabel(weight)
	if weightLabel then
		table.insert(parts, weightLabel)
	end
	table.insert(parts, if species then species.name else speciesId)
	return table.concat(parts, " ")
end

local function onEffect(kind: string, data: any)
	if typeof(data) ~= "table" then
		return
	end
	if kind == "harvest" then
		local multiplier = Economy.mutationMultiplier(data.mutations or {})
		local rare = multiplier >= 6 or (Economy.effectiveTier(data.species) >= 7)
		Sounds.play(if rare then "Rare" else "Harvest")
		local text = if data.count == 1
			then `+1 {describeSlime(data.species, data.mutations or {}, data.weight or 1)}`
			else `+{data.count} slimes!`
		Notifications.float(text, if rare then Theme.Colors.Pink else Theme.Colors.Green)
	elseif kind == "sell" then
		Sounds.play("Sell")
		Notifications.float(`+{Format.short(data.amount or 0)} 🪙`, Theme.Colors.Coin)
		coinBurst(data.count or 3)
	elseif kind == "coins" then
		Sounds.play("Sell")
		coinBurst(8)
	elseif kind == "plant" then
		Sounds.play("Plant", 1.2)
	elseif kind == "buy" then
		Sounds.play("Click", 1.3)
	elseif kind == "ripe" then
		Sounds.play("Harvest", 1.4)
	elseif kind == "mutation" then
		local mutation = Mutations.byId[data.mutation]
		if mutation then
			Sounds.play("Rare", 1.2)
			Notifications.toast(
				`✨ {data.count} slime(s) became {mutation.name} (x{mutation.multiplier})!`,
				"reward"
			)
		end
	elseif kind == "unlock" then
		Sounds.play("Rare", 1.4)
	elseif kind == "rebirth" then
		Sounds.play("Rare", 0.9)
		Notifications.float(`⭐ REBIRTH {data.rebirths}! ⭐`, Theme.Colors.Gold, UDim2.fromScale(0.5, 0.35))
	elseif kind == "reward" then
		Sounds.play("Rare", 1.1)
		Notifications.float(`{data.icon or "🎁"} Reward!`, Theme.Colors.Gold)
	end
end

function Notifications.start()
	local _, canvas = Kit.screen("SlimeNotifications", 20)
	root = canvas
	toastList = Kit.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 222),
		Size = UDim2.fromOffset(460, 200),
		Parent = canvas,
	})
	Kit.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = toastList

	announceFrame = Kit.new("Frame", {
		Name = "Announcement",
		BackgroundColor3 = Theme.Colors.PanelDark,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(640, 48),
		Visible = false,
		Parent = canvas,
	})
	Kit.corner(14).Parent = announceFrame
	Kit.stroke(Theme.Colors.Gold, 3).Parent = announceFrame
	Kit.label({
		Name = "Banner",
		Text = "",
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		MaxTextSize = 26,
		Parent = announceFrame,
	})

	Net.event("Notify").OnClientEvent:Connect(function(text: any, kind: any)
		if typeof(text) == "string" then
			Notifications.toast(text, if typeof(kind) == "string" then kind else nil)
		end
	end)
	Net.event("Announce").OnClientEvent:Connect(function(text: any, color: any)
		if typeof(text) == "string" then
			Notifications.announce(text, if typeof(color) == "Color3" then color else nil)
		end
	end)
	Net.event("Effect").OnClientEvent:Connect(onEffect)

	-- Welcome line in chat.
	task.delay(4, function()
		systemChat(`Welcome to Slime Garden, {Players.LocalPlayer.DisplayName}! 🌱`, Theme.Colors.Green)
	end)
end

return Notifications
