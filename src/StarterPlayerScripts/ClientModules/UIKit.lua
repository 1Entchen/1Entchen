--[[
	UIKit  (ModuleScript)  ->  StarterPlayer/StarterPlayerScripts/ClientModules/UIKit
	Kleine Helfer, um die UI per Code zu bauen (einheitlicher, mobilfreundlicher Look).
]]

local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(28, 26, 48),
	Panel2 = Color3.fromRGB(44, 40, 72),
	Card = Color3.fromRGB(56, 50, 92),
	Accent = Color3.fromRGB(255, 200, 40),
	Green = Color3.fromRGB(60, 210, 90),
	Red = Color3.fromRGB(240, 70, 70),
	Blue = Color3.fromRGB(70, 150, 255),
	Purple = Color3.fromRGB(166, 75, 255),
	Pink = Color3.fromRGB(255, 90, 170),
	Robux = Color3.fromRGB(0, 176, 111),
	Text = Color3.new(1, 1, 1),
	Sub = Color3.fromRGB(200, 195, 230),
	Dark = Color3.fromRGB(15, 14, 26),
}

UIKit.Font = Enum.Font.FredokaOne
UIKit.OnClick = nil -- wird von ClientMain gesetzt (Klick-Sound)

function UIKit.new(className, props, children)
	local inst = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.corner(parent, radius)
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function UIKit.stroke(parent, color, thickness)
	return UIKit.new("UIStroke", {
		Color = color or UIKit.Colors.Dark,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.padding(parent, px)
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function UIKit.gradient(parent, top, bottom)
	return UIKit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Parent = parent,
	})
end

function UIKit.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextScaled = true,
		TextColor3 = UIKit.Colors.Text,
		TextStrokeTransparency = 0.4,
		TextWrapped = true,
	}
	for k, v in pairs(props) do
		if k ~= "MaxText" and k ~= "NoConstraint" then
			defaults[k] = v
		end
	end
	local label = UIKit.new("TextLabel", defaults)
	if not props.NoConstraint then
		UIKit.new("UITextSizeConstraint", { MaxTextSize = props.MaxText or 40, Parent = label })
	end
	return label
end

function UIKit.button(props, onClick)
	local color = props.Color or UIKit.Colors.Green
	props.Color = nil
	local defaults = {
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Font = UIKit.Font,
		TextScaled = true,
		TextColor3 = UIKit.Colors.Text,
		TextStrokeTransparency = 0.3,
		Text = "",
	}
	for k, v in pairs(props) do
		defaults[k] = v
	end
	local maxText = defaults.MaxText or 34
	defaults.MaxText = nil
	local button = UIKit.new("TextButton", defaults)
	UIKit.corner(button, 12)
	UIKit.stroke(button, UIKit.Colors.Dark, 3)
	UIKit.gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	UIKit.new("UITextSizeConstraint", { MaxTextSize = maxText, Parent = button })
	UIKit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = button,
	})
	local scale = UIKit.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.92 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	if onClick then
		button.Activated:Connect(function()
			if UIKit.OnClick then
				UIKit.OnClick()
			end
			onClick()
		end)
	end
	return button
end

-- Kleiner roter Punkt (z. B. "Belohnung bereit")
function UIKit.badge(parent)
	local badge = UIKit.new("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = UIKit.Colors.Red,
		Text = "!",
		Font = UIKit.Font,
		TextScaled = true,
		TextColor3 = UIKit.Colors.Text,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	UIKit.corner(badge, 13)
	UIKit.stroke(badge, UIKit.Colors.Dark, 2)
	return badge
end

function UIKit.pulse(guiObject)
	local scale = guiObject:FindFirstChild("PulseScale") or UIKit.new("UIScale", { Name = "PulseScale", Parent = guiObject })
	local tween = TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 })
	tween:Play()
	return tween
end

function UIKit.clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIGridStyleLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

return UIKit
