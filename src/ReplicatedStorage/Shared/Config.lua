--[[
	Config  (ModuleScript)  ->  ReplicatedStorage/Shared/Config
	Alle Balancing-Werte und Robux-IDs an einer Stelle.
	Nach dem Anlegen der Game Passes / Developer Products im Creator Dashboard
	die IDs unten eintragen (0 = noch nicht angelegt).
	Optional pro Pass/Product: Image = "rbxassetid://123..." zeigt im Shop ein Bild statt Emoji
	(Bilder liegen fertig in marketing/icons/).
]]

local Config = {}

------------------------------------------------------------------------
-- Allgemein
------------------------------------------------------------------------
Config.GameName = "Brainrot Bandits"
Config.GroupId = 0 -- deine Roblox-Gruppen-ID (Gruppen-Bonus +10 %), 0 = aus

Config.StartCash = 100
Config.BaseSlots = 10
Config.MaxRebirthSlots = 5
Config.PassSlots = 5
Config.PremiumSlot = 21
Config.SellRatio = 0.5
Config.WalkSpeed = 16
Config.SpeedPassWalkSpeed = 21

Config.Conveyor = {
	SpawnInterval = 2.5,
	TravelTime = 18,
	MaxFigures = 12,
	PityThreshold = 400,
	BuyDistance = 16,
	ReserveSeconds = 12, -- Mythic-Drop: so lange darf nur der Käufer kaufen
}

------------------------------------------------------------------------
-- Seltenheiten
------------------------------------------------------------------------
Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Config.Rarities = {
	Common = { Rank = 1, Display = "Common", Color = Color3.fromRGB(180, 180, 180), Weight = 62, LuckyWeight = 50 },
	Rare = { Rank = 2, Display = "Rare", Color = Color3.fromRGB(60, 140, 255), Weight = 25, LuckyWeight = 28 },
	Epic = { Rank = 3, Display = "Epic", Color = Color3.fromRGB(166, 75, 255), Weight = 9, LuckyWeight = 13.5 },
	Legendary = { Rank = 4, Display = "Legendary", Color = Color3.fromRGB(255, 180, 0), Weight = 3.2, LuckyWeight = 6 },
	Mythic = { Rank = 5, Display = "Mythic", Color = Color3.fromRGB(255, 60, 60), Weight = 0.7, LuckyWeight = 2.2 },
	Secret = { Rank = 6, Display = "SECRET", Color = Color3.fromRGB(255, 255, 255), Weight = 0.1, LuckyWeight = 0.3 },
}

------------------------------------------------------------------------
-- Mutationen
------------------------------------------------------------------------
Config.MutationOrder = { "Normal", "Gold", "Diamond", "Rainbow" }

Config.Mutations = {
	Normal = { Display = "", Chance = 94.8, PriceMult = 1, IncomeMult = 1 },
	Gold = { Display = "Gold", Chance = 4, PriceMult = 1.5, IncomeMult = 2, Color = Color3.fromRGB(255, 200, 40) },
	Diamond = { Display = "Diamant", Chance = 1, PriceMult = 3, IncomeMult = 5, Color = Color3.fromRGB(110, 230, 255) },
	Rainbow = { Display = "Regenbogen", Chance = 0.2, PriceMult = 6, IncomeMult = 12, Color = Color3.fromRGB(255, 120, 220) },
}
Config.LuckyMutationMult = 2 -- bei Lucky Spawn doppelte Mutations-Chancen

------------------------------------------------------------------------
-- Einkommen
------------------------------------------------------------------------
Config.Multipliers = {
	DoubleCash = 2,
	VIP = 1.1,
	Premium = 1.1,
	Group = 1.1,
	FriendPer = 0.1,
	FriendMax = 3,
	Boost = 2,
	RebirthPer = 0.5,
}
Config.IndexBonus = { { Count = 30, Bonus = 0.15 }, { Count = 20, Bonus = 0.10 }, { Count = 10, Bonus = 0.05 } }

Config.Offline = {
	MinSeconds = 60,
	Ratio = 0.2,
	MaxSeconds = 2 * 3600,
	VipRatio = 0.4,
	VipMaxSeconds = 6 * 3600,
}

------------------------------------------------------------------------
-- Stehlen, Klatsche, Schloss
------------------------------------------------------------------------
Config.Steal = {
	HoldTime = 2,
	MasterHoldTime = 1,
	CarrySpeedMult = 0.7,
	MasterCarrySpeedMult = 0.85,
	MaxCarryTime = 40,
	Cooldown = 20,
	NewbieProtection = 300,
	PromptDistance = 10,
}

Config.Bonk = {
	Range = 9,
	SuperRange = 14,
	Stun = 1.5,
	SuperStun = 2.5,
	Cooldown = 0.8,
}

Config.Lock = {
	BaseDuration = 60,
	PerRebirth = 5,
	MaxDuration = 120,
	ExtendSeconds = 300,
}

------------------------------------------------------------------------
-- Rebirth
------------------------------------------------------------------------
Config.Rebirth = {
	BaseCost = 2500000,
	CostFactor = 3,
}

function Config.RebirthCost(currentRebirths)
	return Config.Rebirth.BaseCost * Config.Rebirth.CostFactor ^ currentRebirths
end

function Config.RebirthRequirement(currentRebirths)
	local nextRebirth = currentRebirths + 1
	if nextRebirth <= 2 then
		return "Legendary"
	elseif nextRebirth <= 4 then
		return "Mythic"
	end
	return "Secret"
end

------------------------------------------------------------------------
-- Robux: Game Passes  (Id im Creator Dashboard anlegen und hier eintragen)
------------------------------------------------------------------------
Config.GamePassOrder = { "DoubleCash", "VIP", "ExtraSlots", "AutoCollect", "MasterThief", "Speed", "SuperBonk" }

Config.GamePasses = {
	DoubleCash = { Id = 0, Price = 249, Icon = "💰", Name = "2x Cash", Desc = "Verdoppelt dein komplettes Einkommen. Für immer!" },
	VIP = { Id = 0, Price = 349, Icon = "👑", Name = "VIP", Desc = "+10 % Cash, VIP-Tag im Chat, doppelte Tagesbelohnung, 40 % Offline-Einkommen bis 6 h" },
	ExtraSlots = { Id = 0, Price = 299, Icon = "🏠", Name = "+5 Basis-Slots", Desc = "5 zusätzliche Plätze für deine Brainrots" },
	AutoCollect = { Id = 0, Price = 179, Icon = "🧲", Name = "Auto-Collect", Desc = "Cash landet automatisch auf deinem Konto" },
	MasterThief = { Id = 0, Price = 199, Icon = "🦹", Name = "Meisterdieb", Desc = "Doppelt so schnell stehlen und schneller wegrennen" },
	Speed = { Id = 0, Price = 129, Icon = "👟", Name = "Turbo-Schuhe", Desc = "+30 % Laufgeschwindigkeit" },
	SuperBonk = { Id = 0, Price = 149, Icon = "🔨", Name = "Mega-Klatsche", Desc = "Mehr Reichweite und Diebe sind länger betäubt" },
}

------------------------------------------------------------------------
-- Robux: Developer Products
------------------------------------------------------------------------
Config.ProductOrder = {
	"StarterPack", "Boost2x", "CashSmall", "CashMedium", "CashLarge", "CashMega",
	"LuckySpawn", "MythicDrop", "LockExtend", "OfflineTriple",
}

Config.Products = {
	StarterPack = { Id = 0, Price = 49, Icon = "🎁", Name = "Starter-Paket", Desc = "Gold-Turbo-Tortellino (Epic) + 25K Cash + 30 Min 2x Cash. Nur einmal!" },
	Boost2x = { Id = 0, Price = 49, Icon = "⚡", Name = "2x Cash (30 Min)", Desc = "Verdoppelt dein Einkommen 30 Minuten lang. Stapelbar!", Seconds = 1800 },
	CashSmall = { Id = 0, Price = 25, Icon = "💵", Name = "Cash-Beutel", Seconds = 300, Min = 1000 },
	CashMedium = { Id = 0, Price = 79, Icon = "💰", Name = "Cash-Koffer", Seconds = 1200, Min = 5000 },
	CashLarge = { Id = 0, Price = 199, Icon = "🏦", Name = "Cash-Tresor", Seconds = 3600, Min = 25000 },
	CashMega = { Id = 0, Price = 499, Icon = "💎", Name = "Cash-Berg", Seconds = 10800, Min = 100000 },
	LuckySpawn = { Id = 0, Price = 99, Icon = "🍀", Name = "Lucky Spawn", Desc = "10 Min bessere Chancen auf dem Förderband, für den ganzen Server!", Seconds = 600 },
	MythicDrop = { Id = 0, Price = 249, Icon = "🔥", Name = "Mythic-Drop", Desc = "Ein Mythic erscheint sofort auf dem Band, 12 s nur für dich reserviert" },
	LockExtend = { Id = 0, Price = 29, Icon = "🔐", Name = "Schloss +5 Min", Desc = "Deine Basis ist sofort 5 Minuten extra gesichert" },
	OfflineTriple = { Id = 0, Price = 25, Icon = "😴", Name = "Offline-Cash x3", Desc = "Verdreifacht dein letztes Offline-Einkommen" },
}

------------------------------------------------------------------------
-- Retention
------------------------------------------------------------------------
-- Tagesbelohnung (7-Tage-Zyklus). Cash = max(Min, Einkommen/s * Seconds)
Config.Daily = {
	{ Type = "Cash", Seconds = 300, Min = 500, Text = "Cash" },
	{ Type = "Cash", Seconds = 600, Min = 1500, Text = "Cash" },
	{ Type = "Boost", Seconds = 900, Text = "15 Min 2x Cash" },
	{ Type = "Cash", Seconds = 1200, Min = 5000, Text = "Cash" },
	{ Type = "Cash", Seconds = 1800, Min = 10000, Text = "Cash" },
	{ Type = "Boost", Seconds = 1800, Text = "30 Min 2x Cash" },
	{ Type = "Figure", Rarity = "Epic", Text = "Epic-Figur!" },
}

-- Spielzeit-Geschenke pro Sitzung
Config.PlaytimeGifts = {
	{ Minutes = 2, Seconds = 120, Min = 200 },
	{ Minutes = 5, Seconds = 240, Min = 600 },
	{ Minutes = 10, Seconds = 360, Min = 1500 },
	{ Minutes = 15, Seconds = 480, Min = 3000 },
	{ Minutes = 25, Seconds = 600, Min = 6000 },
	{ Minutes = 40, Seconds = 900, Min = 12000 },
	{ Minutes = 60, Boost = 900 },
}

-- Tages-Quests (3 pro Tag zufällig)
Config.QuestPool = {
	{ Key = "Buy", Goal = 15, Text = "Kaufe 15 Figuren", Seconds = 600, Min = 2000 },
	{ Key = "BuyRare", Goal = 3, Text = "Kaufe 3 Rare oder besser", Seconds = 900, Min = 5000 },
	{ Key = "Collect", Goal = 10, Text = "Sammle 10x dein Cash ein", Seconds = 600, Min = 2000 },
	{ Key = "Steal", Goal = 2, Text = "Stiehl 2 Figuren", Seconds = 1200, Min = 8000 },
	{ Key = "Defend", Goal = 1, Text = "Erwische einen Dieb mit der Klatsche", Seconds = 1200, Min = 8000 },
	{ Key = "Bonk", Goal = 10, Text = "Triff 10x mit der Klatsche", Seconds = 600, Min = 2000 },
	{ Key = "Lock", Goal = 3, Text = "Schließ deine Basis 3x ab", Seconds = 600, Min = 2000 },
	{ Key = "Play", Goal = 15, Text = "Spiele 15 Minuten", Seconds = 900, Min = 4000 },
	{ Key = "Sell", Goal = 5, Text = "Verkaufe 5 Figuren", Seconds = 600, Min = 2000 },
}
Config.QuestsPerDay = 3

-- Events (UTC)
Config.Events = {
	WeekendCashMult = 2, -- Samstag + Sonntag
	HappyHourStartUTC = 18, -- jeden Tag 18-19 Uhr UTC: Lucky Spawn gratis
	HappyHourEndUTC = 19,
}

Config.Announce = {
	ServerMinRarity = "Legendary",
	GlobalMinRarity = "Secret",
}

-- Monetarisierungs-Popups
Config.StarterOfferAfter = 150 -- Sekunden nach dem Beitritt
Config.FavoriteHintAfter = 600

return Config
