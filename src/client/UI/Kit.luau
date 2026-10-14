--!strict
-- UI construction helpers. Everything is authored in "virtual pixels" on a
-- root canvas that a UIScale maps to the real screen (see Kit.screen).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SlimeBuilder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SlimeBuilder"))

local Theme = require(script.Parent.Theme)

local Kit = {}

local player = Players.LocalPlayer
local clickSound: (() -> ())? = nil

function Kit.setClickSound(fn: () -> ())
	clickSound = fn
end

function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.corner(radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Kit.stroke(color: Color3?, thickness: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.textStroke(thickness: number?): UIStroke
	return Kit.new("UIStroke", { Color = Theme.Colors.Stroke, Thickness = thickness or 2 })
end

function Kit.padding(px: number): UIPadding
	return Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

function Kit.list(
	direction: Enum.FillDirection,
	padding: number,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
): UIListLayout
	return Kit.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
	})
end

function Kit.gradient(top: Color3, bottom: Color3): UIGradient
	return Kit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function Kit.label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for key, value in props do
		if key ~= "MaxTextSize" and key ~= "NoStroke" and key ~= "StrokeThickness" then
			defaults[key] = value
		end
	end
	local label = Kit.new("TextLabel", defaults)
	if props.TextScaled ~= false then
		Kit.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 40, Parent = label })
	end
	if props.NoStroke ~= true then
		Kit.textStroke(props.StrokeThickness).Parent = label
	end
	return label
end

-- Scale "pop" feedback on any GuiObject (uses a UIScale child).
function Kit.pop(gui: GuiObject, amount: number?)
	local scale = gui:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		scale = Kit.new("UIScale", { Name = "PopScale", Parent = gui })
	end
	local s = scale :: UIScale
	s.Scale = amount or 1.15
	TweenService:Create(s, Theme.Tween.Pop, { Scale = 1 }):Play()
end

export type ButtonOptions = {
	text: string,
	color: Color3?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	textSize: number?,
	layoutOrder: number?,
	parent: Instance?,
	onClick: (() -> ())?,
	name: string?,
}

-- Chunky candy button with gradient, stroke, press animation and sound.
function Kit.button(options: ButtonOptions): TextButton
	local color = options.color or Theme.Colors.Green
	local button: TextButton = Kit.new("TextButton", {
		Name = options.name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = options.size or UDim2.fromOffset(160, 50),
		Position = options.position or UDim2.new(),
		AnchorPoint = options.anchor or Vector2.zero,
		Font = Theme.Font,
		Text = options.text,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		LayoutOrder = options.layoutOrder or 0,
	})
	Kit.corner(12).Parent = button
	Kit.stroke(Theme.Colors.Stroke, 3).Parent = button
	Kit.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
		Rotation = 90,
		Parent = button,
	})
	Kit.new("UITextSizeConstraint", { MaxTextSize = options.textSize or 26, Parent = button })
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = button,
	})
	Kit.textStroke(2).Parent = button
	local scale: UIScale = Kit.new("UIScale", { Name = "PopScale", Parent = button })

	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, Theme.Tween.Fast, { Scale = 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, Theme.Tween.Pop, { Scale = 1 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, Theme.Tween.Pop, { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		if clickSound then
			clickSound()
		end
		if options.onClick then
			options.onClick()
		end
	end)
	if options.parent then
		button.Parent = options.parent
	end
	return button
end

function Kit.setEnabled(button: GuiButton, enabled: boolean, enabledColor: Color3)
	button:SetAttribute("Disabled", not enabled)
	button.BackgroundColor3 = if enabled then enabledColor else Theme.Colors.Grey
end

-- Red dot used on HUD buttons for "something to claim".
function Kit.badge(parent: GuiObject, text: string?): TextLabel
	local badge = Kit.label({
		Name = "Badge",
		Text = text or "!",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -6, 0, -6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.Red,
		ZIndex = 5,
		MaxTextSize = 18,
		Visible = false,
		Parent = parent,
	})
	Kit.corner(12).Parent = badge
	return badge
end

-- Slime preview inside a ViewportFrame, framed from its bounding box.
function Kit.slimeViewport(speciesId: string, mutations: { string }, props: { [string]: any }?): ViewportFrame
	local viewport: ViewportFrame = Kit.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(80, 80),
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -2, 1),
	})
	if props then
		for key, value in props do
			(viewport :: any)[key] = value
		end
	end
	local ok, model = pcall(SlimeBuilder.build, speciesId, mutations, 1)
	if ok and model then
		model:PivotTo(CFrame.new())
		model.Parent = viewport
		local cf, size = model:GetBoundingBox()
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		local distance = math.max(size.X, size.Y, size.Z) * 1.9
		local target = cf.Position
		camera.CFrame = CFrame.lookAt(target + Vector3.new(0.35, 0.45, -1).Unit * distance, target)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end
	return viewport
end

-- Root ScreenGui + virtual canvas. The UIScale is recomputed on resize.
function Kit.screen(name: string, displayOrder: number?): (ScreenGui, Frame)
	local gui: ScreenGui = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local scale: UIScale = Kit.new("UIScale", { Parent = gui })
	local root: Frame = Kit.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})

	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		if viewport.X < 2 or viewport.Y < 2 then
			return
		end
		local s = math.min(viewport.Y / Theme.ReferenceHeight, viewport.X / Theme.ReferenceWidth)
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			s *= Theme.TouchBoost
		end
		s = math.clamp(s, 0.45, 1.6)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	update()
	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
	end
	watchCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera()
		update()
	end)
	return gui, root
end

-- Size of the virtual canvas in virtual pixels.
function Kit.canvasSize(root: Frame): Vector2
	local gui = root:FindFirstAncestorOfClass("ScreenGui")
	local scale = if gui then gui:FindFirstChildOfClass("UIScale") else nil
	local s = if scale then scale.Scale else 1
	return root.AbsoluteSize / s
end

return Kit
