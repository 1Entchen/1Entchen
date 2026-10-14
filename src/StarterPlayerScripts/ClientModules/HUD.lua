--[[
	HUD  (ModuleScript)  ->  StarterPlayer/StarterPlayerScripts/ClientModules/HUD
	Dauerhaft sichtbare Anzeige: Cash, Einkommen, Menü-Buttons, Schloss,
	Boosts/Events, Spielzeit-Geschenk, Freunde einladen.
	Alles in großen Buttons (mobilfreundlich), skaliert per UIScale.
]]

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local C = UIKit.Colors

local HUD = {}
local App
local refs = {}

local function sideButton(parent, order, icon, text, color, onClick)
	local button = UIKit.button({
		Size = UDim2.fromOffset(92, 80),
		LayoutOrder = order,
		Color = color,
		Text = "",
		Parent = parent,
	}, onClick)
	UIKit.label({ Size = UDim2.new(1, 0, 0.62, 0), Text = icon, TextStrokeTransparency = 1, MaxText = 38, Parent = button })
	UIKit.label({ Size = UDim2.new(1, 0, 0.36, 0), Position = UDim2.fromScale(0, 0.64), Text = text, MaxText = 18, Parent = button })
	return button, UIKit.badge(button)
end

function HUD.Init(app)
	App = app
	local gui = app.Gui

	-- Cash-Anzeige (oben Mitte)
	local cashFrame = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(330, 80),
		BackgroundColor3 = C.Panel,
		Parent = gui,
	})
	UIKit.corner(cashFrame, 16)
	UIKit.stroke(cashFrame, C.Dark, 4)
	refs.Cash = UIKit.label({ Size = UDim2.new(1, -70, 0.62, 0), Position = UDim2.fromOffset(10, 2), Text = "$0", TextColor3 = Color3.fromRGB(120, 255, 140), MaxText = 44, Parent = cashFrame })
	refs.Rate = UIKit.label({ Size = UDim2.new(1, -70, 0.34, 0), Position = UDim2.new(0, 10, 0.62, 0), Text = "+$0/s", TextColor3 = Color3.fromRGB(255, 230, 90), MaxText = 22, Parent = cashFrame })
	UIKit.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(54, 54),
		Color = C.Robux,
		Text = "+",
		MaxText = 40,
		Parent = cashFrame,
	}, function()
		App.Menus.Open("Shop", "Cash")
	end)

	-- Linke Menüleiste
	local left = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(92, 520),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = left })
	local shopButton
	shopButton, refs.ShopBadge = sideButton(left, 1, "🛒", "Shop", C.Robux, function()
		App.Menus.Open("Shop")
	end)
	UIKit.pulse(shopButton)
	local _
	_, refs.BaseBadge = sideButton(left, 2, "🎒", "Basis", C.Blue, function()
		App.Menus.Open("Base")
	end)
	_, refs.RebirthBadge = sideButton(left, 3, "⭐", "Rebirth", C.Purple, function()
		App.Menus.Open("Rebirth")
	end)
	_, refs.DailyBadge = sideButton(left, 4, "🎁", "Täglich", C.Pink, function()
		App.Menus.Open("Daily")
	end)
	_, refs.QuestBadge = sideButton(left, 5, "📜", "Quests", Color3.fromRGB(230, 130, 40), function()
		App.Menus.Open("Quests")
	end)
	sideButton(left, 6, "👥", "+10%", Color3.fromRGB(90, 90, 120), function()
		pcall(SocialService.PromptGameInvite, SocialService, Players.LocalPlayer)
	end)

	-- Rechte Seite: Schloss + Schloss-Verlängerung + Geschenk
	local right = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.42, 0),
		Size = UDim2.fromOffset(150, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = right })

	refs.Lock = UIKit.button({ Size = UDim2.fromOffset(150, 70), LayoutOrder = 1, Color = C.Red, Text = "🔓 Abschließen", MaxText = 26, Parent = right }, function()
		App.Request("ToggleLock")
	end)
	refs.LockExtend = UIKit.button({ Size = UDim2.fromOffset(150, 46), LayoutOrder = 2, Color = C.Robux, Text = "🔐 +5 Min", MaxText = 22, Parent = right }, function()
		App.Buy("LockExtend")
	end)
	refs.Gift = UIKit.button({ Size = UDim2.fromOffset(150, 60), LayoutOrder = 3, Color = C.Pink, Text = "🎁 2:00", MaxText = 24, Parent = right }, function()
		App.Menus.Open("Daily")
	end)
	refs.Boost = UIKit.button({ Size = UDim2.fromOffset(150, 52), LayoutOrder = 4, Color = C.Accent, Text = "⚡ 2x Cash", MaxText = 22, Parent = right }, function()
		App.Buy("Boost2x")
	end)

	-- Status-Chips (Boosts, Events, Schutz) oben rechts
	refs.Chips = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(300, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = refs.Chips })
end

local function setChips(chips)
	local key = table.concat(chips, "|")
	if refs.ChipKey == key then
		return
	end
	refs.ChipKey = key
	UIKit.clear(refs.Chips)
	for i, text in ipairs(chips) do
		local chip = UIKit.label({
			Size = UDim2.fromOffset(300, 32),
			LayoutOrder = i,
			Text = text,
			BackgroundTransparency = 0.15,
			BackgroundColor3 = C.Panel,
			MaxText = 20,
			Parent = refs.Chips,
		})
		UIKit.corner(chip, 10)
	end
end

function HUD.Update(state)
	refs.Cash.Text = Format.Money(state.Cash)
	refs.Rate.Text = "+" .. Format.Money(state.Rate) .. "/s"

	-- Schloss
	if state.LockRemaining > 0 then
		refs.Lock.Text = "🔒 " .. Format.Time(state.LockRemaining)
		refs.Lock.BackgroundColor3 = C.Green
	else
		refs.Lock.Text = "🔓 Abschließen"
		refs.Lock.BackgroundColor3 = C.Red
	end

	-- Boost-Button zeigt laufenden Boost oder lädt zum Kauf ein
	if state.BoostRemaining > 0 then
		refs.Boost.Text = "⚡ 2x " .. Format.Time(state.BoostRemaining)
	else
		refs.Boost.Text = "⚡ 2x Cash kaufen"
	end

	-- Nächstes Spielzeit-Geschenk
	local nextGift
	local ready = false
	for _, gift in ipairs(state.Gifts) do
		if not gift.Claimed then
			if gift.Remaining <= 0 then
				ready = true
				break
			end
			nextGift = nextGift or gift
		end
	end
	if ready then
		refs.Gift.Text = "🎁 Abholen!"
		refs.Gift.BackgroundColor3 = C.Green
	elseif nextGift then
		refs.Gift.Text = "🎁 " .. Format.Time(nextGift.Remaining)
		refs.Gift.BackgroundColor3 = C.Pink
	else
		refs.Gift.Text = "🎁 Alle geholt"
		refs.Gift.BackgroundColor3 = Color3.fromRGB(90, 90, 120)
	end

	-- Badges
	refs.DailyBadge.Visible = state.Daily.CanClaim or ready
	local questReady = false
	for _, quest in ipairs(state.Quests) do
		if not quest.Claimed and quest.Progress >= quest.Goal then
			questReady = true
		end
	end
	refs.QuestBadge.Visible = questReady
	refs.RebirthBadge.Visible = state.Cash >= state.Rebirth.Cost and state.Rebirth.HasRequirement
	refs.ShopBadge.Visible = not state.StarterBought
	local used = 0
	for _, slot in ipairs(state.Slots) do
		if slot.Id then
			used += 1
		end
	end
	refs.BaseBadge.Visible = used >= state.Capacity

	-- Chips
	local chips = {}
	if state.Protection > 0 then
		table.insert(chips, "🛡 Neuling-Schutz " .. Format.Time(state.Protection))
	end
	if state.LuckRemaining > 0 then
		table.insert(chips, "🍀 Lucky Spawn " .. Format.Time(state.LuckRemaining))
	end
	for _, name in ipairs(state.Event.Names) do
		table.insert(chips, name)
	end
	if state.Mult > 1 then
		table.insert(chips, ("📈 Multiplikator x%.2f"):format(state.Mult))
	end
	if state.Carrying then
		table.insert(chips, "🦹 Bring die Figur in DEINE Basis!")
	end
	setChips(chips)
end

return HUD
