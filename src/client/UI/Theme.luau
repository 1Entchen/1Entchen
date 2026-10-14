--!strict
-- Visual identity: candy-bright slime colours on deep purple panels, chunky
-- rounded type. One place to restyle the whole UI.

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
Theme.BodyFont = Enum.Font.BuilderSansBold

Theme.Colors = {
	Panel = Color3.fromRGB(43, 33, 66),
	PanelLight = Color3.fromRGB(62, 50, 92),
	PanelDark = Color3.fromRGB(28, 21, 44),
	Stroke = Color3.fromRGB(22, 16, 36),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(200, 190, 225),
	Green = Color3.fromRGB(96, 214, 86),
	GreenDark = Color3.fromRGB(52, 150, 60),
	Gold = Color3.fromRGB(255, 196, 46),
	GoldDark = Color3.fromRGB(214, 140, 20),
	Pink = Color3.fromRGB(255, 104, 170),
	Blue = Color3.fromRGB(80, 168, 255),
	Purple = Color3.fromRGB(170, 110, 255),
	Red = Color3.fromRGB(240, 80, 80),
	Grey = Color3.fromRGB(120, 115, 135),
	Coin = Color3.fromRGB(255, 214, 70),
	Robux = Color3.fromRGB(80, 220, 120),
}

Theme.Tween = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Smooth = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
}

-- Reference "virtual screen" height. The UI is authored in virtual pixels
-- and a UIScale maps them to the device; touch devices get larger targets.
Theme.ReferenceHeight = 620
Theme.ReferenceWidth = 1000
Theme.TouchBoost = 1.15

return Theme
