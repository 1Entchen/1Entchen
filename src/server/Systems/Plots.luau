--!strict
-- Builds the world, assigns each player a garden plot, keeps tile visuals in
-- sync with their unlocks, sells tile expansions and teleports characters
-- home.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))

local ServerRoot = script.Parent.Parent
local Notify = require(ServerRoot:WaitForChild("Util"):WaitForChild("Notify"))
local RateLimiter = require(ServerRoot:WaitForChild("Util"):WaitForChild("RateLimiter"))
local World = require(ServerRoot:WaitForChild("World"):WaitForChild("World"))

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Monetization = require(script.Parent.Monetization)
local Sync = require(script.Parent.Sync)

type Profile = Types.Profile
type PlotRecord = World.PlotRecord

local Plots = {}

-- Fired once a player owns a plot and their passes are known.
Plots.Assigned = Signal.new() :: Signal.Signal<Player, PlotRecord, Profile>
Plots.Released = Signal.new() :: Signal.Signal<Player, PlotRecord>

local world: World.WorldRecord? = nil
local owners: { [number]: Player } = {}
local byPlayer: { [Player]: PlotRecord } = {}

local SOIL = Color3.fromRGB(122, 84, 56)
local LOCKED = Color3.fromRGB(88, 82, 78)
local PASS_LOCKED = Color3.fromRGB(150, 120, 60)

function Plots.world(): World.WorldRecord
	return world :: World.WorldRecord
end

function Plots.get(player: Player): PlotRecord?
	return byPlayer[player]
end

function Plots.tileTop(plot: PlotRecord, tileIndex: number): CFrame?
	local tile = plot.tiles[tileIndex]
	if not tile then
		return nil
	end
	return tile.CFrame * CFrame.new(0, tile.Size.Y / 2, 0)
end

local function setTileLabel(tile: BasePart, text: string?)
	local existing = tile:FindFirstChild("LockLabel")
	if not text then
		if existing then
			existing:Destroy()
		end
		return
	end
	local gui = existing :: SurfaceGui?
	if not gui then
		local newGui = Instance.new("SurfaceGui")
		newGui.Name = "LockLabel"
		newGui.Face = Enum.NormalId.Top
		newGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		newGui.PixelsPerStud = 50
		newGui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Rotation = 180 -- readable from the plot entrance
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = label
		label.Parent = newGui
		newGui.Parent = tile
		gui = newGui
	end
	((gui :: SurfaceGui):FindFirstChild("Text") :: TextLabel).Text = text
end

function Plots.refreshTiles(player: Player)
	local plot = byPlayer[player]
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	local hasBigGarden = Monetization.owns(player, "big_garden")
	local nextTile = data.unlockedTiles + 1
	for index, tile in plot.tiles do
		local usable = Economy.isTileUsable(index, data.unlockedTiles, hasBigGarden)
		tile:SetAttribute("Usable", usable)
		if usable then
			tile.Color = SOIL
			tile.Transparency = 0
			setTileLabel(tile, nil)
		elseif index > Config.Plots.FreeTileLimit then
			tile.Color = PASS_LOCKED
			tile.Transparency = 0.2
			local middle = Config.Plots.FreeTileLimit + math.ceil(Config.Plots.PassTiles / 2)
			setTileLabel(tile, if index == middle then "⭐ Big Garden" else nil)
		else
			tile.Color = LOCKED
			tile.Transparency = 0.25
			setTileLabel(
				tile,
				if index == nextTile then `🔒 {Format.short(Economy.tileCost(index))}` else nil
			)
		end
	end
end

local function resetPlot(plot: PlotRecord)
	plot.model:SetAttribute("OwnerUserId", 0)
	local label = plot.sign:FindFirstChild("Label") :: TextLabel
	label.Text = "Empty Plot"
	local avatar = plot.sign:FindFirstChild("Avatar") :: ImageLabel
	avatar.Image = ""
	for _, tile in plot.tiles do
		tile.Color = LOCKED
		tile.Transparency = 0.25
		tile:SetAttribute("Usable", false)
		setTileLabel(tile, nil)
	end
end

function Plots.teleportHome(player: Player)
	local plot = byPlayer[player]
	local character = player.Character
	if not plot or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		character:PivotTo(plot.spawn)
	end
end

local function assign(player: Player, data: Profile)
	if byPlayer[player] or not player.Parent then
		return
	end
	local w = world :: World.WorldRecord
	local plot: PlotRecord? = nil
	for _, candidate in w.plots do
		if not owners[candidate.index] then
			plot = candidate
			break
		end
	end
	if not plot then
		player:Kick("This server is full of gardens! Please join another server.")
		return
	end
	owners[plot.index] = player
	byPlayer[player] = plot
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotIndex", plot.index)

	local label = plot.sign:FindFirstChild("Label") :: TextLabel
	label.Text = `{player.DisplayName}'s Garden`
	local avatar = plot.sign:FindFirstChild("Avatar") :: ImageLabel
	avatar.Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`

	Plots.refreshTiles(player)
	Plots.teleportHome(player)
	Plots.Assigned:Fire(player, plot, data)
end

local function release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	owners[plot.index] = nil
	resetPlot(plot)
	Plots.Released:Fire(player, plot)
end

local function onUnlockTile(player: Player)
	if not RateLimiter.allow(player, "UnlockTile", 2, 3) then
		return
	end
	local data = DataService.get(player)
	if not data or not byPlayer[player] then
		return
	end
	local nextTile = data.unlockedTiles + 1
	if nextTile > Config.Plots.FreeTileLimit then
		Notify.player(player, "All coin tiles unlocked! Get Big Garden for 6 more.", "info")
		return
	end
	local cost = Economy.tileCost(nextTile)
	if data.coins < cost then
		Notify.player(player, `You need {Format.short(cost)} coins to unlock this tile.`, "error")
		return
	end
	data.coins -= cost
	data.unlockedTiles = nextTile
	Analytics.coinSink(player, cost, data.coins, Enum.AnalyticsEconomyTransactionType.Shop, "tile")
	Analytics.progression(player, "GardenSize", nextTile)
	Notify.player(player, `🌱 Tile unlocked! Your garden now has {nextTile} tiles.`, "success")
	Notify.effect(player, "unlock", { tile = nextTile })
	Plots.refreshTiles(player)
	Sync.mark(player, "main")
end

function Plots.init()
	world = World.build()
end

function Plots.start()
	Monetization.PlayerReady:Connect(assign)
	-- Released only after DataService has flushed growth into the profile.
	DataService.ProfileReleased:Connect(release)
	Monetization.PassesChanged:Connect(function(player, key)
		if key == "big_garden" then
			Plots.refreshTiles(player)
		end
	end)

	local function onCharacter(player: Player, character: Model)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		if byPlayer[player] and character.Parent then
			Plots.teleportHome(player)
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	Net.event("UnlockTile").OnServerEvent:Connect(onUnlockTile)
end

return Plots
