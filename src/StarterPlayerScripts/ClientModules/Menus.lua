--[[
	Menus  (ModuleScript)  ->  StarterPlayer/StarterPlayerScripts/ClientModules/Menus
	Shop, Basis/Inventar + Index, Rebirth, Tägliche Belohnung + Geschenke, Quests
	sowie die Popups "Willkommen zurück" und "Starter-Paket".
	Panels werden nur neu gebaut, wenn sich ihr Inhalt ändert (sonst nur Timer/Texte),
	damit Buttons beim Antippen nicht verschwinden.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))
local Format = require(Shared:WaitForChild("Format"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local C = UIKit.Colors

local Menus = {}
local App
local modal, titleLabel, content
local popup
local current, lastSig
local refs = {}
local sections = {}
local baseTab = "Base"

------------------------------------------------------------------------
-- Bausteine
------------------------------------------------------------------------
local function card(parent, size, color, order)
	local frame = UIKit.new("Frame", {
		Size = size,
		BackgroundColor3 = color or C.Card,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	UIKit.corner(frame, 14)
	UIKit.stroke(frame, C.Dark, 3)
	return frame
end

local orderCounter = 0
local function nextOrder()
	orderCounter += 1
	return orderCounter
end

local function header(text, name)
	local label = UIKit.label({
		Size = UDim2.new(1, 0, 0, 40),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Accent,
		LayoutOrder = nextOrder(),
		MaxText = 30,
		Parent = content,
	})
	if name then
		sections[name] = label
	end
	return label
end

local function grid(cellSize)
	local frame = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
	UIKit.new("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})
	return frame
end

local function text(parent, str, size, pos, color, maxText, align)
	return UIKit.label({
		Size = size,
		Position = pos or UDim2.new(),
		Text = str,
		TextColor3 = color or C.Text,
		MaxText = maxText or 24,
		TextXAlignment = align or Enum.TextXAlignment.Center,
		Parent = parent,
	})
end

local function robuxButton(parent, key, size, pos)
	local info = App.OfferInfo(key)
	local owned = Config.GamePasses[key] and App.State and App.State.Passes[key]
	local button = UIKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Size = size or UDim2.new(0.9, 0, 0, 46),
		Position = pos or UDim2.new(0.5, 0, 1, -8),
		Color = owned and Color3.fromRGB(90, 90, 120) or C.Robux,
		Text = owned and "✅ Gekauft" or ("R$ " .. info.Price),
		MaxText = 26,
		Parent = parent,
	}, function()
		if not owned then
			App.Buy(key)
		end
	end)
	return button
end

local function progressBar(parent, size, pos, color)
	local back = UIKit.new("Frame", { Size = size, Position = pos, BackgroundColor3 = C.Dark, Parent = parent })
	UIKit.corner(back, 10)
	local fill = UIKit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or C.Green, Parent = back })
	UIKit.corner(fill, 10)
	local label = UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "", MaxText = 20, ZIndex = 2, Parent = back })
	return fill, label
end

local function setBar(fill, ratio)
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
end

------------------------------------------------------------------------
-- Shop
------------------------------------------------------------------------
local Shop = {}

function Shop.Sig(state)
	local parts = { tostring(state.StarterBought) }
	for _, key in ipairs(Config.GamePassOrder) do
		table.insert(parts, state.Passes[key] and "1" or "0")
	end
	for _, key in ipairs({ "CashSmall", "CashMedium", "CashLarge", "CashMega" }) do
		table.insert(parts, Format.Short(state.CashPacks[key]))
	end
	return table.concat(parts, ",")
end

local function productCard(parent, key, extraText, highlight)
	local def = Config.Products[key] or Config.GamePasses[key]
	local box = card(parent, UDim2.new(), highlight and Color3.fromRGB(90, 60, 20) or C.Card)
	if highlight then
		UIKit.stroke(box, C.Accent, 3)
	end
	if def.Image and def.Image ~= "" then
		UIKit.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.fromOffset(48, 48),
			BackgroundTransparency = 1,
			Image = def.Image,
			Parent = box,
		})
	else
		text(box, def.Icon, UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 6), nil, 40)
	end
	text(box, def.Name, UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 50), C.Text, 22)
	text(box, extraText or def.Desc or "", UDim2.new(1, -16, 0, 50), UDim2.fromOffset(8, 78), C.Sub, 16)
	robuxButton(box, key)
	return box
end

function Shop.Build(state)
	-- Top-Angebote
	header("🔥 Top-Angebote", "Offers")
	local offers = grid(UDim2.fromOffset(380, 200))
	if not state.StarterBought then
		local starter = productCard(offers, "StarterPack", nil, true)
		local tag = UIKit.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(110, 34),
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Red,
			Text = "NUR 1x!",
			MaxText = 22,
			Parent = starter,
		})
		UIKit.corner(tag, 10)
	end
	productCard(offers, "Boost2x", nil, state.BoostRemaining <= 0)

	-- Cash
	header("💰 Cash-Pakete (wachsen mit deinem Einkommen)", "Cash")
	local cash = grid(UDim2.fromOffset(250, 200))
	for _, key in ipairs({ "CashSmall", "CashMedium", "CashLarge", "CashMega" }) do
		local box = productCard(cash, key, "+" .. Format.Money(state.CashPacks[key]) .. " Cash", key == "CashMega")
		if key == "CashMega" then
			local tag = UIKit.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(110, 28),
				BackgroundTransparency = 0,
				BackgroundColor3 = C.Accent,
				TextColor3 = C.Dark,
				Text = "BESTER WERT",
				MaxText = 18,
				Parent = box,
			})
			UIKit.corner(tag, 8)
		end
	end

	-- Game Passes
	header("🎟 Game Passes (für immer)", "Passes")
	local passes = grid(UDim2.fromOffset(250, 200))
	for _, key in ipairs(Config.GamePassOrder) do
		productCard(passes, key, nil, key == "DoubleCash")
	end

	-- Boosts
	header("⚡ Boosts & Extras", "Boosts")
	local boosts = grid(UDim2.fromOffset(250, 200))
	productCard(boosts, "LuckySpawn")
	productCard(boosts, "MythicDrop")
	productCard(boosts, "LockExtend")

	-- Pflicht-Transparenz für bezahlte Zufalls-Items
	local odds = {}
	for _, entry in ipairs(Figures.OddsInRarity("Mythic")) do
		table.insert(odds, ("%s %s"):format(entry.Name, Format.Percent(entry.Percent)))
	end
	local mutations = {}
	for i = 2, #Config.MutationOrder do
		local name = Config.MutationOrder[i]
		table.insert(mutations, ("%s %s"):format(Config.Mutations[name].Display, Format.Percent(Config.Mutations[name].Chance)))
	end
	UIKit.label({
		Size = UDim2.new(1, 0, 0, 70),
		Text = "Chancen Mythic-Drop: " .. table.concat(odds, " · ") .. "\nMutation: " .. table.concat(mutations, " · "),
		TextColor3 = C.Sub,
		MaxText = 15,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

------------------------------------------------------------------------
-- Basis / Index
------------------------------------------------------------------------
local Base = {}

function Base.Sig(state)
	local parts = { baseTab, state.Capacity, state.IndexCount, #state.Index }
	for _, slot in ipairs(state.Slots) do
		table.insert(parts, (slot.Id or 0) .. (slot.Mut or "") .. tostring(slot.BeingStolen))
	end
	return table.concat(parts, ",")
end

local function tabs(state)
	local row = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = content })
	local used = 0
	for _, slot in ipairs(state.Slots) do
		if slot.Id then
			used += 1
		end
	end
	UIKit.button({ Size = UDim2.new(0.49, 0, 1, 0), Color = baseTab == "Base" and C.Blue or C.Panel2, Text = ("🏠 Meine Basis (%d/%d)"):format(used, state.Capacity), Parent = row }, function()
		baseTab = "Base"
		Menus.Refresh(true)
	end)
	UIKit.button({ Size = UDim2.new(0.49, 0, 1, 0), Position = UDim2.fromScale(0.51, 0), Color = baseTab == "Index" and C.Blue or C.Panel2, Text = ("📖 Index (%d/%d)"):format(state.IndexCount, #Figures.List), Parent = row }, function()
		baseTab = "Index"
		Menus.Refresh(true)
	end)
end

local function buildBaseList(state)
	UIKit.label({
		Size = UDim2.new(1, 0, 0, 60),
		Text = ("Einkommen: %s/s  (Basis %s/s × %.2f)\n%s"):format(Format.Money(state.Rate), Format.Money(state.BaseIncome), state.Mult, table.concat(state.MultParts, "  ")),
		TextColor3 = C.Sub,
		MaxText = 18,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local owned = {}
	for _, slot in ipairs(state.Slots) do
		if slot.Id then
			table.insert(owned, slot)
		end
	end
	table.sort(owned, function(a, b)
		return Figures.Income(a.Id, a.Mut) > Figures.Income(b.Id, b.Mut)
	end)
	if #owned == 0 then
		UIKit.label({ Size = UDim2.new(1, 0, 0, 60), Text = "Noch keine Figuren. Kauf welche am Förderband!", LayoutOrder = nextOrder(), Parent = content })
	end
	for _, slot in ipairs(owned) do
		local fig = Figures.Get(slot.Id)
		local rarity = Config.Rarities[fig.Rarity]
		local row = card(content, UDim2.new(1, 0, 0, 64), C.Card, nextOrder())
		local bar = UIKit.new("Frame", { Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = rarity.Color, Parent = row })
		UIKit.corner(bar, 6)
		text(row, Figures.DisplayName(slot.Id, slot.Mut), UDim2.new(0.45, 0, 0.55, 0), UDim2.new(0, 20, 0, 4), C.Text, 24, Enum.TextXAlignment.Left)
		text(row, rarity.Display .. "  ·  " .. Format.Money(Figures.Income(slot.Id, slot.Mut)) .. "/s", UDim2.new(0.45, 0, 0.4, 0), UDim2.new(0, 20, 0.55, 0), rarity.Color, 18, Enum.TextXAlignment.Left)
		if slot.BeingStolen then
			text(row, "⚠ WIRD GESTOHLEN!", UDim2.new(0.38, 0, 0.8, 0), UDim2.new(0.6, 0, 0.1, 0), C.Red, 22)
		else
			UIKit.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0.36, 0, 0, 48),
				Color = Color3.fromRGB(230, 130, 40),
				Text = "Verkaufen +" .. Format.Money(Figures.SellValue(slot.Id, slot.Mut)),
				MaxText = 20,
				Parent = row,
			}, function()
				App.Request("Sell", slot.Index)
			end)
		end
	end

	if not state.Passes.ExtraSlots then
		local upsell = card(content, UDim2.new(1, 0, 0, 70), Color3.fromRGB(30, 80, 60), nextOrder())
		text(upsell, "🏠 Basis voll? Hol dir 5 Slots mehr – für immer!", UDim2.new(0.6, 0, 1, 0), UDim2.fromOffset(12, 0), C.Text, 22, Enum.TextXAlignment.Left)
		robuxButton(upsell, "ExtraSlots", UDim2.new(0.34, 0, 0, 50), UDim2.new(0.82, 0, 1, -10))
	end
end

local function buildIndex(state)
	local collected = {}
	for _, key in ipairs(state.Index) do
		local id, mut = string.match(key, "^(%d+)_(%a+)$")
		id = tonumber(id)
		if id then
			collected[id] = collected[id] or {}
			collected[id][mut] = true
		end
	end
	local nextTier
	for i = #Config.IndexBonus, 1, -1 do
		if state.IndexCount < Config.IndexBonus[i].Count then
			nextTier = Config.IndexBonus[i]
			break
		end
	end
	UIKit.label({
		Size = UDim2.new(1, 0, 0, 50),
		Text = ("Entdeckt: %d/%d · Bonus +%d%%%s"):format(state.IndexCount, #Figures.List, state.IndexBonus * 100,
			nextTier and ("  (bei %d: +%d%%)"):format(nextTier.Count, nextTier.Bonus * 100) or ""),
		TextColor3 = C.Accent,
		MaxText = 22,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
	local cells = grid(UDim2.fromOffset(150, 96))
	for _, fig in ipairs(Figures.List) do
		local rarity = Config.Rarities[fig.Rarity]
		local found = collected[fig.Id]
		local box = card(cells, UDim2.new(), found and C.Card or C.Dark, fig.Id)
		UIKit.stroke(box, found and rarity.Color or C.Panel2, 3)
		text(box, found and fig.Name or "???", UDim2.new(1, -8, 0.5, 0), UDim2.fromOffset(4, 4), found and C.Text or C.Sub, 18)
		text(box, rarity.Display, UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0.5), rarity.Color, 14)
		if found then
			local marks = {}
			for _, mut in ipairs(Config.MutationOrder) do
				if mut ~= "Normal" and found[mut] then
					table.insert(marks, mut == "Gold" and "🟡" or (mut == "Diamond" and "💎" or "🌈"))
				end
			end
			text(box, table.concat(marks, " "), UDim2.new(1, 0, 0.25, 0), UDim2.fromScale(0, 0.72), C.Text, 16)
		end
	end
end

function Base.Build(state)
	tabs(state)
	if baseTab == "Base" then
		buildBaseList(state)
	else
		buildIndex(state)
	end
end

------------------------------------------------------------------------
-- Rebirth
------------------------------------------------------------------------
local Rebirth = {}

function Rebirth.Sig(state)
	return table.concat({ state.Rebirths, tostring(state.Rebirth.HasRequirement), state.Rebirth.Requirement }, ",")
end

function Rebirth.Build(state)
	local info = state.Rebirth
	local box = card(content, UDim2.new(1, 0, 0, 380), C.Card, nextOrder())
	text(box, ("⭐ Rebirth %d  ➜  %d"):format(state.Rebirths, state.Rebirths + 1), UDim2.new(1, 0, 0, 50), UDim2.fromOffset(0, 8), C.Accent, 40)
	text(box, ("📈 Einkommen x%.1f ➜ x%.1f   🏠 +1 Slot (max. 5)   🔒 Schloss +5 s"):format(info.CurrentMult, info.NextMult), UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 64), C.Text, 22)
	local reqRarity = Config.Rarities[info.Requirement]
	text(box, (info.HasRequirement and "✅ " or "❌ ") .. "Mindestens 1 " .. reqRarity.Display .. "-Figur in deiner Basis", UDim2.new(1, -20, 0, 32), UDim2.fromOffset(10, 104), info.HasRequirement and C.Green or C.Red, 22)
	text(box, "Kosten: " .. Format.Money(info.Cost), UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 142), C.Text, 26)
	refs.RebirthFill, refs.RebirthText = progressBar(box, UDim2.new(1, -40, 0, 36), UDim2.fromOffset(20, 184), C.Purple)
	refs.RebirthButton = UIKit.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 234),
		Size = UDim2.new(0.6, 0, 0, 64),
		Color = C.Purple,
		Text = "⭐ REBIRTH",
		MaxText = 34,
		Parent = box,
	}, function()
		App.Request("Rebirth")
	end)
	text(box, "⚠ Setzt Cash und Figuren zurück. Rebirths, Index, Pässe bleiben.", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 306), C.Sub, 18)
	UIKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(0.5, 0, 0, 36),
		Color = C.Robux,
		Text = "💰 Schneller mit Cash-Paketen",
		MaxText = 18,
		Parent = box,
	}, function()
		Menus.Open("Shop", "Cash")
	end)
	Rebirth.Tick(state)
end

function Rebirth.Tick(state)
	if not refs.RebirthFill then
		return
	end
	local info = state.Rebirth
	setBar(refs.RebirthFill, state.Cash / info.Cost)
	refs.RebirthText.Text = Format.Money(state.Cash) .. " / " .. Format.Money(info.Cost)
	local ready = state.Cash >= info.Cost and info.HasRequirement
	refs.RebirthButton.BackgroundColor3 = ready and C.Purple or Color3.fromRGB(90, 90, 120)
end

------------------------------------------------------------------------
-- Täglich + Geschenke
------------------------------------------------------------------------
local Daily = {}

function Daily.Sig(state)
	local parts = { tostring(state.Daily.CanClaim), state.Daily.Streak, state.Daily.NextIndex }
	for _, gift in ipairs(state.Gifts) do
		table.insert(parts, tostring(gift.Claimed) .. tostring(gift.Remaining <= 0))
	end
	return table.concat(parts, ",")
end

function Daily.Build(state)
	local daily = state.Daily
	header(("📅 Tägliche Belohnung · Serie: %d Tage"):format(daily.Streak))
	local days = grid(UDim2.fromOffset(104, 120))
	local claimedUpTo
	if daily.CanClaim then
		claimedUpTo = daily.NextIndex - 1
	else
		claimedUpTo = (daily.Streak - 1) % #Config.Daily + 1
	end
	for i, reward in ipairs(Config.Daily) do
		local isCurrent = daily.CanClaim and i == daily.NextIndex
		local claimed = i <= claimedUpTo
		local box = card(days, UDim2.new(), isCurrent and Color3.fromRGB(40, 120, 60) or (claimed and C.Dark or C.Card), i)
		if isCurrent then
			UIKit.stroke(box, C.Accent, 4)
		end
		text(box, "Tag " .. i, UDim2.new(1, 0, 0.25, 0), UDim2.fromScale(0, 0.04), C.Accent, 20)
		local label = reward.Type == "Cash" and ("💵\n" .. Format.Money(math.max(reward.Min, state.Rate * reward.Seconds))) or (reward.Type == "Boost" and "⚡\n" .. reward.Text or "🎁\n" .. reward.Text)
		text(box, claimed and "✅" or label, UDim2.new(1, -6, 0.68, 0), UDim2.new(0, 3, 0.3, 0), C.Text, 18)
	end
	refs.DailyButton = UIKit.button({
		Size = UDim2.new(1, 0, 0, 58),
		LayoutOrder = nextOrder(),
		Color = daily.CanClaim and C.Green or Color3.fromRGB(90, 90, 120),
		Text = daily.CanClaim and "🎁 ABHOLEN!" or "",
		MaxText = 30,
		Parent = content,
	}, function()
		App.Request("ClaimDaily")
	end)
	if not state.Passes.VIP then
		UIKit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "👑 VIP bekommt jede Tagesbelohnung doppelt!", TextColor3 = C.Accent, MaxText = 18, LayoutOrder = nextOrder(), Parent = content })
	end

	header("⏱ Spielzeit-Geschenke (diese Sitzung)")
	local gifts = grid(UDim2.fromOffset(104, 120))
	refs.GiftLabels = {}
	for _, gift in ipairs(state.Gifts) do
		local box = card(gifts, UDim2.new(), gift.Claimed and C.Dark or C.Card, gift.Index)
		text(box, gift.Label, UDim2.new(1, -6, 0.4, 0), UDim2.new(0, 3, 0.05, 0), C.Text, 18)
		if gift.Claimed then
			text(box, "✅", UDim2.new(1, 0, 0.45, 0), UDim2.fromScale(0, 0.5), C.Text, 26)
		elseif gift.Remaining <= 0 then
			UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(0.9, 0, 0.45, 0), Color = C.Green, Text = "Holen!", MaxText = 20, Parent = box }, function()
				App.Request("ClaimGift", gift.Index)
			end)
		else
			refs.GiftLabels[gift.Index] = text(box, Format.Time(gift.Remaining), UDim2.new(1, 0, 0.4, 0), UDim2.fromScale(0, 0.52), C.Sub, 22)
		end
	end
	Daily.Tick(state)
end

function Daily.Tick(state)
	if refs.DailyButton and not state.Daily.CanClaim then
		refs.DailyButton.Text = "Nächste Belohnung in " .. Format.Time(state.Daily.SecondsUntilNext)
	end
	for _, gift in ipairs(state.Gifts) do
		local label = refs.GiftLabels and refs.GiftLabels[gift.Index]
		if label then
			label.Text = Format.Time(gift.Remaining)
		end
	end
end

------------------------------------------------------------------------
-- Quests
------------------------------------------------------------------------
local Quests = {}

function Quests.Sig(state)
	local parts = {}
	for _, quest in ipairs(state.Quests) do
		table.insert(parts, quest.Progress .. "/" .. quest.Goal .. tostring(quest.Claimed) .. Format.Short(quest.Reward))
	end
	return table.concat(parts, ",")
end

function Quests.Build(state)
	header("📜 Tages-Quests")
	for _, quest in ipairs(state.Quests) do
		local row = card(content, UDim2.new(1, 0, 0, 96), C.Card, nextOrder())
		text(row, quest.Text, UDim2.new(0.62, 0, 0, 34), UDim2.fromOffset(14, 6), C.Text, 24, Enum.TextXAlignment.Left)
		local fill, label = progressBar(row, UDim2.new(0.6, 0, 0, 28), UDim2.fromOffset(14, 50), C.Accent)
		setBar(fill, quest.Progress / quest.Goal)
		label.Text = quest.Progress .. " / " .. quest.Goal
		if quest.Claimed then
			text(row, "✅ Erledigt", UDim2.new(0.32, 0, 0, 50), UDim2.new(0.66, 0, 0, 22), C.Green, 24)
		elseif quest.Progress >= quest.Goal then
			UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.32, 0, 0, 60), Color = C.Green, Text = "Holen +" .. Format.Money(quest.Reward), MaxText = 22, Parent = row }, function()
				App.Request("ClaimQuest", quest.Index)
			end)
		else
			text(row, "🎁 +" .. Format.Money(quest.Reward), UDim2.new(0.32, 0, 0, 50), UDim2.new(0.66, 0, 0, 22), C.Accent, 24)
		end
	end
	refs.QuestTimer = UIKit.label({ Size = UDim2.new(1, 0, 0, 34), Text = "", TextColor3 = C.Sub, MaxText = 20, LayoutOrder = nextOrder(), Parent = content })
	Quests.Tick(state)
end

function Quests.Tick(state)
	if refs.QuestTimer then
		refs.QuestTimer.Text = "Neue Quests in " .. Format.Time(state.Daily.SecondsUntilNext)
	end
end

------------------------------------------------------------------------
-- Panel-Verwaltung
------------------------------------------------------------------------
local PANELS = {
	Shop = { Title = "🛒 SHOP", Def = Shop },
	Base = { Title = "🎒 BASIS & INDEX", Def = Base },
	Rebirth = { Title = "⭐ REBIRTH", Def = Rebirth },
	Daily = { Title = "🎁 BELOHNUNGEN", Def = Daily },
	Quests = { Title = "📜 QUESTS", Def = Quests },
}

local function rebuild(state, keepScroll)
	local scroll = content.CanvasPosition
	UIKit.clear(content)
	refs = {}
	sections = {}
	orderCounter = 0
	PANELS[current].Def.Build(state)
	if keepScroll then
		task.defer(function()
			content.CanvasPosition = scroll
		end)
	end
end

function Menus.Refresh(keepScroll)
	if current and App.State then
		lastSig = PANELS[current].Def.Sig(App.State)
		rebuild(App.State, keepScroll)
	end
end

function Menus.Open(name, section)
	if not PANELS[name] or not App.State then
		return
	end
	if current == name and modal.Visible and not section then
		Menus.Close()
		return
	end
	current = name
	titleLabel.Text = PANELS[name].Title
	modal.Visible = true
	content.CanvasPosition = Vector2.zero
	lastSig = PANELS[name].Def.Sig(App.State)
	rebuild(App.State, false)
	if section then
		task.defer(function()
			local target = sections[section]
			if target then
				content.CanvasPosition = Vector2.new(0, target.AbsolutePosition.Y - content.AbsolutePosition.Y + content.CanvasPosition.Y)
			end
		end)
	end
end

function Menus.Close()
	modal.Visible = false
	current = nil
end

function Menus.Update(state)
	if not current or not modal.Visible then
		return
	end
	local def = PANELS[current].Def
	local sig = def.Sig(state)
	if sig ~= lastSig then
		lastSig = sig
		rebuild(state, true)
	elseif def.Tick then
		def.Tick(state)
	end
end

------------------------------------------------------------------------
-- Popups
------------------------------------------------------------------------
local function openPopup(title, bodyText, buttons, accent)
	if popup then
		popup:Destroy()
	end
	popup = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 300),
		BackgroundColor3 = C.Panel,
		ZIndex = 30,
		Parent = App.Gui,
	})
	UIKit.corner(popup, 20)
	UIKit.stroke(popup, accent or C.Accent, 5)
	text(popup, title, UDim2.new(1, -20, 0, 54), UDim2.fromOffset(10, 10), accent or C.Accent, 40)
	text(popup, bodyText, UDim2.new(1, -40, 0, 120), UDim2.fromOffset(20, 70), C.Text, 24)
	local width = 1 / #buttons
	for i, def in ipairs(buttons) do
		UIKit.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(width * (i - 0.5), 0, 1, -16),
			Size = UDim2.new(width, -20, 0, 64),
			Color = def.Color,
			Text = def.Text,
			MaxText = 26,
			Parent = popup,
		}, function()
			if def.Fn then
				def.Fn()
			end
			if popup then
				popup:Destroy()
				popup = nil
			end
		end)
	end
	local scale = UIKit.new("UIScale", { Scale = 0.5, Parent = popup })
	game:GetService("TweenService"):Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function Menus.ShowOffline(payload)
	local body = ("Du warst %s weg und hast %s verdient!"):format(Format.Time(payload.Away or 0), Format.Money(payload.Amount or 0))
	if not payload.Vip then
		body ..= "\n👑 Mit VIP doppelt so viel und bis zu 6 Stunden!"
	end
	openPopup("😴 Willkommen zurück!", body, {
		{ Text = "Einsammeln", Color = C.Blue },
		{ Text = "3x  ·  R$ " .. App.OfferInfo("OfflineTriple").Price, Color = C.Robux, Fn = function()
			App.Buy("OfflineTriple")
		end },
	}, C.Accent)
end

function Menus.ShowStarterOffer()
	openPopup("🎁 STARTER-PAKET", "Gold Turbo Tortellino (Epic, 300 $/s)\n+ 25.000 Cash + 30 Min 2x Cash\nNur EINMAL kaufbar!", {
		{ Text = "Später", Color = Color3.fromRGB(90, 90, 120) },
		{ Text = "Holen · R$ " .. App.OfferInfo("StarterPack").Price, Color = C.Robux, Fn = function()
			App.Buy("StarterPack")
		end },
	}, C.Accent)
end

------------------------------------------------------------------------
function Menus.Init(app)
	App = app
	modal = UIKit.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.53, 0),
		Size = UDim2.fromOffset(860, 560),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = app.Gui,
	})
	UIKit.corner(modal, 20)
	UIKit.stroke(modal, C.Dark, 5)
	titleLabel = UIKit.label({ Size = UDim2.new(1, -140, 0, 56), Position = UDim2.fromOffset(20, 6), Text = "", TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 40, Parent = modal })
	UIKit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(56, 56), Color = C.Red, Text = "X", MaxText = 32, Parent = modal }, Menus.Close)

	content = UIKit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 1, -90),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = modal,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = content })
	UIKit.new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = content })
end

return Menus
