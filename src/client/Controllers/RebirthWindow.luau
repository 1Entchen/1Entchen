--!strict
-- Rebirth: clear explanation of what is gained, reset and kept.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))
local Windows = require(UI:WaitForChild("Windows"))

local State = require(script.Parent.Parent:WaitForChild("State"))

local RebirthWindow = {}

local info: TextLabel
local fill: Frame
local progressLabel: TextLabel
local button: TextButton

local function refresh()
	local main = State.main()
	if not main or not info then
		return
	end
	local cost = Economy.rebirthCost(main.rebirths)
	local nextBonus = Config.Bonuses.RebirthBonus * (main.rebirths + 1)
	info.Text = table.concat({
		`<b>Rebirth {main.rebirths} → {main.rebirths + 1}</b>`,
		"",
		`<font color="#7CE070">GAIN</font>  Permanent coin bonus x{1 + nextBonus} (now x{1 + Config.Bonuses.RebirthBonus * main.rebirths})`,
		`<font color="#7CE070">GAIN</font>  Start with {Economy.startingTiles(main.rebirths + 1)} garden tiles`,
		if main.rebirths == 0
			then `<font color="#7CE070">GAIN</font>  Cosmic Slime seeds appear in the shop`
			else "",
		"",
		`<font color="#FF8080">RESET</font>  Coins, seeds, garden tiles and growing slimes`,
		`<font color="#FFD25A">KEPT</font>  ★ Favorited slimes, Slimepedia, passes, potions, daily streak`,
	}, "\n")
	local pct = math.clamp(main.coins / cost, 0, 1)
	fill.Size = UDim2.fromScale(pct, 1)
	progressLabel.Text = `🪙 {Format.short(main.coins)} / {Format.short(cost)}`
	Kit.setEnabled(button, main.coins >= cost, Theme.Colors.Gold)
end

local function build(content: Frame)
	info = Kit.label({
		Text = "",
		Font = Theme.BodyFont,
		RichText = true,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 1, -130),
		NoStroke = true,
		Parent = content,
	})
	local bar: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelDark,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -122),
		Parent = content,
	})
	Kit.corner(15).Parent = bar
	fill =
		Kit.new("Frame", { BackgroundColor3 = Theme.Colors.Gold, Size = UDim2.fromScale(0, 1), Parent = bar })
	Kit.corner(15).Parent = fill
	progressLabel = Kit.label({ Text = "", Size = UDim2.fromScale(1, 1), MaxTextSize = 20, Parent = bar })
	button = Kit.button({
		text = "⭐ REBIRTH",
		color = Theme.Colors.Gold,
		size = UDim2.fromOffset(300, 60),
		position = UDim2.new(0.5, 0, 1, -8),
		anchor = Vector2.new(0.5, 1),
		textSize = 30,
		parent = content,
		onClick = function()
			Windows.confirm(
				"Rebirth?",
				"Your coins, seeds, tiles and growing slimes reset. Favorites are kept.",
				"Rebirth!",
				function()
					Net.event("Rebirth"):FireServer()
				end
			)
		end,
	})
	refresh()
end

function RebirthWindow.start()
	Windows.register("Rebirth", {
		title = "⭐ Rebirth",
		color = Theme.Colors.GoldDark,
		size = Vector2.new(640, 440),
		build = build,
		onOpen = refresh,
	})
	State.Changed:Connect(function(section)
		if section == "main" and Windows.isOpen("Rebirth") then
			refresh()
		end
	end)
end

return RebirthWindow
