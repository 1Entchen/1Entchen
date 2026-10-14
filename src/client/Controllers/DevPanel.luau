--!strict
-- Studio-only QA shortcuts. The server rejects these requests in live
-- servers (RunService:IsStudio() is checked server-side), and this panel is
-- never created outside Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))

local DevPanel = {}

function DevPanel.start()
	if not RunService:IsStudio() then
		return
	end
	local _, canvas = Kit.screen("SlimeDevPanel", 30)
	local panel: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelDark,
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -110),
		Size = UDim2.fromOffset(132, 176),
		Parent = canvas,
	})
	Kit.corner(10).Parent = panel
	Kit.padding(6).Parent = panel
	Kit.list(Enum.FillDirection.Vertical, 4).Parent = panel
	Kit.label({ Text = "STUDIO QA", Size = UDim2.new(1, 0, 0, 18), MaxTextSize = 14, Parent = panel })
	for i, entry in
		{
			{ "+1B coins", "dev_coins" },
			{ "+5 rare seeds", "dev_seeds" },
			{ "Ripen all", "instant_grow" },
			{ "Starfall", "weather_starfall" },
		}
	do
		Kit.button({
			text = entry[1],
			color = Theme.Colors.Grey,
			size = UDim2.new(1, 0, 0, 32),
			textSize = 15,
			layoutOrder = i,
			parent = panel,
			onClick = function()
				Net.event("DevGrant"):FireServer(entry[2])
			end,
		})
	end
end

return DevPanel
