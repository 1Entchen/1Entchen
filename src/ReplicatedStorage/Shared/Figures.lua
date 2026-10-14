--[[
	Figures  (ModuleScript)  ->  ReplicatedStorage/Shared/Figures
	Die 30 originalen Brainrot-Figuren + Hilfsfunktionen.
	Neue Figuren einfach unten anhängen (Id fortlaufend, Key ohne Umlaute).
]]

local Config = require(script.Parent:WaitForChild("Config"))

local Figures = {}

local LIST = {
	-- Common
	{ Id = 1, Key = "SpagettoGecko", Name = "Spagetto Gecko", Rarity = "Common", Price = 25, Income = 1, Weight = 30, Height = 4, Color1 = "#F2D16B", Color2 = "#6BBF59" },
	{ Id = 2, Key = "SockolinoMausolino", Name = "Sockolino Mausolino", Rarity = "Common", Price = 60, Income = 2, Weight = 22, Height = 4, Color1 = "#E94F4F", Color2 = "#BDBDBD" },
	{ Id = 3, Key = "KettloFroggolo", Name = "Kettlo Froggolo", Rarity = "Common", Price = 120, Income = 3, Weight = 16, Height = 4, Color1 = "#4CAF50", Color2 = "#C0C0C0" },
	{ Id = 4, Key = "BrezelwurmBrezelini", Name = "Brezelwurm Brezelini", Rarity = "Common", Price = 200, Income = 5, Weight = 12, Height = 4, Color1 = "#A0612B", Color2 = "#F5E6C8" },
	{ Id = 5, Key = "RadieroSchneckolo", Name = "Radiero Schneckolo", Rarity = "Common", Price = 350, Income = 8, Weight = 9, Height = 4, Color1 = "#FF8FB1", Color2 = "#7CB342" },
	{ Id = 6, Key = "MopettoPinguzzo", Name = "Mopetto Pinguzzo", Rarity = "Common", Price = 500, Income = 11, Weight = 7, Height = 4, Color1 = "#263238", Color2 = "#ECEFF1" },
	{ Id = 7, Key = "WackelWobblino", Name = "Wackel Wobblino", Rarity = "Common", Price = 750, Income = 15, Weight = 4, Height = 4, Color1 = "#66E07A", Color2 = "#D32F2F" },
	-- Rare
	{ Id = 8, Key = "LampadinoFalenino", Name = "Lampadino Falenino", Rarity = "Rare", Price = 1200, Income = 20, Weight = 28, Height = 5, Color1 = "#FFF59D", Color2 = "#8D6E63" },
	{ Id = 9, Key = "CiabattoCanguro", Name = "Ciabatto Canguro", Rarity = "Rare", Price = 1800, Income = 28, Weight = 22, Height = 5, Color1 = "#C68642", Color2 = "#5C6BC0" },
	{ Id = 10, Key = "SushiHamsterini", Name = "Sushi Hamsterini", Rarity = "Rare", Price = 2700, Income = 40, Weight = 18, Height = 5, Color1 = "#FFCC80", Color2 = "#212121" },
	{ Id = 11, Key = "BurstoIgelino", Name = "Bürsto Igelino", Rarity = "Rare", Price = 4000, Income = 55, Weight = 14, Height = 5, Color1 = "#8D6E63", Color2 = "#29B6F6" },
	{ Id = 12, Key = "KaktoffelKrabbo", Name = "Kaktoffel Krabbo", Rarity = "Rare", Price = 6000, Income = 75, Weight = 10, Height = 5, Color1 = "#E64A19", Color2 = "#388E3C" },
	{ Id = 13, Key = "TrommeloDackelini", Name = "Trommelo Dackelini", Rarity = "Rare", Price = 9000, Income = 105, Weight = 8, Height = 5, Color1 = "#795548", Color2 = "#FFD54F" },
	-- Epic
	{ Id = 14, Key = "TurboTortellino", Name = "Turbo Tortellino", Rarity = "Epic", Price = 15000, Income = 150, Weight = 26, Height = 6, Color1 = "#FFE082", Color2 = "#43A047" },
	{ Id = 15, Key = "DiscomuffoMantarini", Name = "Discomuffo Mantarini", Rarity = "Epic", Price = 22000, Income = 200, Weight = 21, Height = 6, Color1 = "#7E57C2", Color2 = "#E0E0E0" },
	{ Id = 16, Key = "WaschmaschinoWalrossi", Name = "Waschmaschino Walrossi", Rarity = "Epic", Price = 32000, Income = 270, Weight = 18, Height = 6, Color1 = "#ECEFF1", Color2 = "#8D6E63" },
	{ Id = 17, Key = "FonixFohnini", Name = "Fönix Föhnini", Rarity = "Epic", Price = 45000, Income = 360, Weight = 15, Height = 6, Color1 = "#FF7043", Color2 = "#EC407A" },
	{ Id = 18, Key = "ZitronoOkapini", Name = "Zitrono Okapini", Rarity = "Epic", Price = 65000, Income = 480, Weight = 12, Height = 6, Color1 = "#FFEB3B", Color2 = "#5D4037" },
	{ Id = 19, Key = "VentilatorePelicanzo", Name = "Ventilatore Pelicanzo", Rarity = "Epic", Price = 90000, Income = 620, Weight = 8, Height = 6, Color1 = "#90CAF9", Color2 = "#FFFFFF" },
	-- Legendary
	{ Id = 20, Key = "KaiserKurbissimo", Name = "Kaiser Kürbissimo", Rarity = "Legendary", Price = 160000, Income = 950, Weight = 30, Height = 7.5, Color1 = "#FB8C00", Color2 = "#2E7D32" },
	{ Id = 21, Key = "RakettoRaclettini", Name = "Raketto Raclettini", Rarity = "Legendary", Price = 240000, Income = 1300, Weight = 25, Height = 7.5, Color1 = "#FFD54F", Color2 = "#B0BEC5" },
	{ Id = 22, Key = "GondoloGoriglione", Name = "Gondolo Goriglione", Rarity = "Legendary", Price = 350000, Income = 1750, Weight = 20, Height = 7.5, Color1 = "#424242", Color2 = "#1565C0" },
	{ Id = 23, Key = "TictacoPolpettone", Name = "Tictaco Polpettone", Rarity = "Legendary", Price = 500000, Income = 2300, Weight = 15, Height = 7.5, Color1 = "#AB47BC", Color2 = "#8D6E63" },
	{ Id = 24, Key = "DonnerdonerGreifino", Name = "Donnerdöner Greifino", Rarity = "Legendary", Price = 750000, Income = 3100, Weight = 10, Height = 7.5, Color1 = "#FFCA28", Color2 = "#455A64" },
	-- Mythic
	{ Id = 25, Key = "GalaxioGelatone", Name = "Galaxio Gelatone", Rarity = "Mythic", Price = 1500000, Income = 5500, Weight = 40, Height = 9, Color1 = "#3949AB", Color2 = "#F48FB1" },
	{ Id = 26, Key = "VulcanoWaffelotto", Name = "Vulcano Waffelotto", Rarity = "Mythic", Price = 2500000, Income = 8500, Weight = 30, Height = 9, Color1 = "#D84315", Color2 = "#FFB74D" },
	{ Id = 27, Key = "KristalloKapibarone", Name = "Kristallo Kapibarone", Rarity = "Mythic", Price = 4000000, Income = 12500, Weight = 20, Height = 9, Color1 = "#80DEEA", Color2 = "#B39DDB" },
	{ Id = 28, Key = "AstronudelNautilino", Name = "Astronudel Nautilino", Rarity = "Mythic", Price = 6500000, Income = 18500, Weight = 10, Height = 9, Color1 = "#FFE0B2", Color2 = "#26C6DA" },
	-- Secret
	{ Id = 29, Key = "IlGrandeGlitchonzo", Name = "Il Grande Glitchonzo", Rarity = "Secret", Price = 20000000, Income = 45000, Weight = 70, Height = 11, Color1 = "#00E676", Color2 = "#D500F9" },
	{ Id = 30, Key = "OmegaOmelettore", Name = "Omega Omelettore", Rarity = "Secret", Price = 50000000, Income = 100000, Weight = 30, Height = 11, Color1 = "#FFFFFF", Color2 = "#FFC107" },
}

Figures.List = LIST
Figures.ById = {}
Figures.ByRarity = {}

for _, fig in ipairs(LIST) do
	fig.Color1 = Color3.fromHex(fig.Color1)
	fig.Color2 = Color3.fromHex(fig.Color2)
	Figures.ById[fig.Id] = fig
	Figures.ByRarity[fig.Rarity] = Figures.ByRarity[fig.Rarity] or {}
	table.insert(Figures.ByRarity[fig.Rarity], fig)
end

function Figures.Get(id)
	return Figures.ById[id]
end

function Figures.Mutation(mutation)
	return Config.Mutations[mutation] or Config.Mutations.Normal
end

function Figures.Price(id, mutation)
	local fig = Figures.ById[id]
	if not fig then
		return 0
	end
	return math.floor(fig.Price * Figures.Mutation(mutation).PriceMult)
end

function Figures.Income(id, mutation)
	local fig = Figures.ById[id]
	if not fig then
		return 0
	end
	return fig.Income * Figures.Mutation(mutation).IncomeMult
end

function Figures.SellValue(id, mutation)
	return math.floor(Figures.Price(id, mutation) * Config.SellRatio)
end

function Figures.RarityRank(id)
	local fig = Figures.ById[id]
	return fig and Config.Rarities[fig.Rarity].Rank or 0
end

function Figures.DisplayName(id, mutation)
	local fig = Figures.ById[id]
	if not fig then
		return "?"
	end
	local mut = Figures.Mutation(mutation)
	if mut.Display ~= "" then
		return mut.Display .. " " .. fig.Name
	end
	return fig.Name
end

function Figures.IndexKey(id, mutation)
	return tostring(id) .. "_" .. (mutation or "Normal")
end

-- Chancen innerhalb einer Seltenheit (für die Anzeige im Shop, Pflicht bei bezahlten Zufalls-Items)
function Figures.OddsInRarity(rarity)
	local list = Figures.ByRarity[rarity] or {}
	local total = 0
	for _, fig in ipairs(list) do
		total += fig.Weight
	end
	local odds = {}
	for _, fig in ipairs(list) do
		table.insert(odds, { Name = fig.Name, Percent = fig.Weight / total * 100 })
	end
	return odds
end

return Figures
