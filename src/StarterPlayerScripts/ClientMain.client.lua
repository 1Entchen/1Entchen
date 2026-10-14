--[[
	ClientMain  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/ClientMain
	Baut die UI, verbindet die Remotes und verteilt den Zustand an alle UI-Module.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local modules = script.Parent:WaitForChild("ClientModules")
local UIKit = require(modules:WaitForChild("UIKit"))
local Notify = require(modules:WaitForChild("Notify"))
local HUD = require(modules:WaitForChild("HUD"))
local Menus = require(modules:WaitForChild("Menus"))
local World = require(modules:WaitForChild("World"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateUpdate = Remotes:WaitForChild("StateUpdate")
local NotifyEvent = Remotes:WaitForChild("Notify")
local AnnounceEvent = Remotes:WaitForChild("Announce")
local EffectEvent = Remotes:WaitForChild("Effect")
local Request = Remotes:WaitForChild("Request")

------------------------------------------------------------------------
-- ScreenGui + Skalierung (Design-Auflösung 1280x720)
------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MainGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function updateScale()
	local viewport = Workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.5, 1.4)
end
updateScale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

------------------------------------------------------------------------
-- App: gemeinsamer Kontext für alle Module
------------------------------------------------------------------------
local App = {
	Gui = gui,
	State = nil,
	Menus = Menus,
}

local priceCache = {}

function App.Sound(name)
	local sfx = SoundService:FindFirstChild("Sfx")
	local sound = name and sfx and sfx:FindFirstChild(name)
	if sound and sound.SoundId ~= "" then
		SoundService:PlayLocalSound(sound)
	end
end

function App.OfferInfo(key)
	local def = Config.GamePasses[key] or Config.Products[key]
	if not def then
		return nil
	end
	return {
		Icon = def.Icon,
		Short = def.Name,
		Price = priceCache[key] or def.Price,
	}
end

function App.Buy(key)
	local pass = Config.GamePasses[key]
	local product = Config.Products[key]
	local id = (pass and pass.Id) or (product and product.Id) or 0
	if id == 0 then
		Notify.Toast("Dieses Angebot ist noch nicht eingerichtet (ID in Config fehlt).", "error")
		return
	end
	if pass then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

function App.Request(action, payload)
	local ok, result, message = pcall(Request.InvokeServer, Request, action, payload)
	if not ok then
		return false
	end
	if result == false and message then
		Notify.Toast(message, "error")
		App.Sound("Error")
	end
	return result, message
end

-- Echte Preise aus dem Creator Dashboard laden (falls geändert)
task.spawn(function()
	for key, pass in pairs(Config.GamePasses) do
		if pass.Id > 0 then
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, pass.Id, Enum.InfoType.GamePass)
			if ok and info and info.PriceInRobux then
				priceCache[key] = info.PriceInRobux
			end
		end
	end
	for key, product in pairs(Config.Products) do
		if product.Id > 0 then
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, product.Id, Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then
				priceCache[key] = info.PriceInRobux
			end
		end
	end
end)

UIKit.OnClick = function()
	App.Sound("Click")
end

Notify.Init(App)
HUD.Init(App)
Menus.Init(App)
World.Init(App)

------------------------------------------------------------------------
-- Zustand
------------------------------------------------------------------------
local starterShown = false
local favoriteShown = false

local function onState(state)
	App.State = state
	HUD.Update(state)
	Menus.Update(state)
	World.Update(state)

	if not starterShown and not state.StarterBought and state.SessionTime >= Config.StarterOfferAfter then
		starterShown = true
		Menus.ShowStarterOffer()
	end
	if not favoriteShown and state.SessionTime >= Config.FavoriteHintAfter then
		favoriteShown = true
		Notify.Toast("Gefällt dir Brainrot Bandits? Drück ⭐ Favorit und 👍, damit du uns wiederfindest!", "info")
	end
end

StateUpdate.OnClientEvent:Connect(onState)
NotifyEvent.OnClientEvent:Connect(function(text, kind, sound, offer)
	Notify.Toast(text, kind, offer)
	App.Sound(sound)
end)
AnnounceEvent.OnClientEvent:Connect(function(text, color)
	Notify.Announce(text, color)
end)
EffectEvent.OnClientEvent:Connect(function(kind, payload)
	Notify.Effect(kind, payload)
end)

-- Erster Zustand (Server lädt evtl. noch)
task.spawn(function()
	for _ = 1, 60 do
		if App.State then
			return
		end
		local ok, state = pcall(Request.InvokeServer, Request, "GetState")
		if ok and type(state) == "table" then
			onState(state)
			return
		end
		task.wait(1)
	end
end)

Notify.Toast("Willkommen bei " .. Config.GameName .. "! Kauf Figuren am Förderband 💰", "info")
print("✅ Client bereit", Format.Money(0))
