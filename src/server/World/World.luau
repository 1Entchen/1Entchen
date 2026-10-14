--!strict
-- Builds the map procedurally at server start: central hub (Seed Shop, Sell
-- Stand, leaderboard, tips board) ringed by garden plots, with decor. No
-- uploaded meshes or images are required. Designers can later replace any
-- piece with a modelled version as long as the named parts/attributes stay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rng = require(Shared:WaitForChild("Rng"))
local SlimeBuilder = require(Shared:WaitForChild("SlimeBuilder"))

export type PlotRecord = {
	index: number,
	model: Model,
	origin: CFrame,
	spawn: CFrame,
	tiles: { BasePart },
	sign: SurfaceGui,
	plants: Folder,
	accent: Color3,
}

export type WorldRecord = {
	root: Folder,
	plots: { PlotRecord },
	shopCounter: BasePart,
	sellCounter: BasePart,
	leaderboard: SurfaceGui,
}

local World = {}

local PLOT_ACCENTS = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(255, 200, 70),
	Color3.fromRGB(150, 230, 120),
	Color3.fromRGB(200, 140, 255),
	Color3.fromRGB(255, 150, 80),
	Color3.fromRGB(120, 230, 220),
	Color3.fromRGB(240, 240, 240),
}

local WOOD = Color3.fromRGB(150, 105, 70)
local DARK_WOOD = Color3.fromRGB(110, 75, 50)

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function surfaceText(
	target: BasePart,
	face: Enum.NormalId,
	text: string,
	options: { textColor: Color3?, background: Color3?, pixelsPerStud: number? }?
): (SurfaceGui, TextLabel)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = if options and options.pixelsPerStud then options.pixelsPerStud else 40
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if options and options.background then 0 else 1
	label.BackgroundColor3 = if options and options.background
		then options.background
		else Color3.new(0, 0, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = if options and options.textColor then options.textColor else Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(40, 30, 50)
	stroke.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	return gui, label
end

local function prompt(parent: BasePart, actionText: string, objectText: string, name: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = parent
	return p
end

-- A market stall: counter, posts, striped roof and a sign facing `facing`.
local function buildStall(
	parent: Instance,
	name: string,
	cf: CFrame,
	signText: string,
	roofA: Color3,
	roofB: Color3,
	keeperSpecies: string
): BasePart
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local counter = part({
		Name = "Counter",
		Size = Vector3.new(16, 3.2, 4),
		CFrame = cf * CFrame.new(0, 1.6, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}, model)
	part({
		Name = "CounterTop",
		Size = Vector3.new(16.6, 0.4, 4.6),
		CFrame = cf * CFrame.new(0, 3.4, 0),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}, model)

	for _, x in { -7.6, 7.6 } do
		part({
			Name = "Post",
			Size = Vector3.new(0.8, 10, 0.8),
			CFrame = cf * CFrame.new(x, 5, 1.6),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		}, model)
	end

	for i = 0, 7 do
		part({
			Name = "Roof",
			Size = Vector3.new(2.2, 0.5, 7),
			CFrame = cf * CFrame.new(-7.7 + i * 2.2, 10.2, 0.6) * CFrame.Angles(math.rad(-14), 0, 0),
			Color = if i % 2 == 0 then roofA else roofB,
			Material = Enum.Material.Fabric,
		}, model)
	end

	local sign = part({
		Name = "Sign",
		Size = Vector3.new(12, 3, 0.4),
		CFrame = cf * CFrame.new(0, 12.6, -2.2),
		Color = roofA,
	}, model)
	surfaceText(sign, Enum.NormalId.Front, signText)

	-- Crates of goods on the counter.
	for i = -2, 2 do
		local crate = part({
			Name = "Crate",
			Size = Vector3.new(1.6, 1.2, 1.6),
			CFrame = cf * CFrame.new(i * 2.8, 4.2, -0.6),
			Color = Color3.fromHSV(((i + 2) / 5 + 0.1) % 1, 0.55, 0.95),
			Material = Enum.Material.SmoothPlastic,
		}, model)
		crate.CanCollide = false
	end

	-- Shopkeeper slime behind the counter, raised so it peeks over and faces customers.
	local keeper = SlimeBuilder.build(keeperSpecies, {}, 1.8)
	keeper.Name = "Keeper"
	keeper:PivotTo(cf * CFrame.new(0, 2.4, 3.8))
	keeper:SetAttribute("Bounce", true)
	keeper.Parent = model

	return counter
end

local function buildTree(parent: Instance, position: Vector3, scale: number, rng: () -> number)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent
	local trunkHeight = 6 * scale
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkHeight, 1.4 * scale, 1.4 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(125, 85, 55),
		Material = Enum.Material.Wood,
	}, model)
	local leafColor = Color3.fromHSV(0.27 + rng() * 0.08, 0.55 + rng() * 0.15, 0.7 + rng() * 0.15)
	for i = 1, 3 do
		local offset = Vector3.new((rng() - 0.5) * 2.4, i * 1.4, (rng() - 0.5) * 2.4) * scale
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (5.2 - i * 0.7) * scale,
			CFrame = CFrame.new(position + Vector3.new(0, trunkHeight, 0) + offset),
			Color = leafColor,
			Material = Enum.Material.Grass,
		}, model)
	end
end

local function buildFlowers(parent: Instance, position: Vector3, rng: () -> number)
	for _ = 1, 4 do
		local offset = Vector3.new((rng() - 0.5) * 3, 0, (rng() - 0.5) * 3)
		local stemTop = position + offset + Vector3.new(0, 0.8, 0)
		local flower = part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.7,
			CFrame = CFrame.new(stemTop),
			Color = Color3.fromHSV(rng(), 0.5, 1),
			CanCollide = false,
			CastShadow = false,
		}, parent)
		flower.CanQuery = false
	end
end

local function buildPlot(parent: Instance, index: number, origin: CFrame): PlotRecord
	local accent = PLOT_ACCENTS[(index - 1) % #PLOT_ACCENTS + 1]
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model.Parent = parent

	part({
		Name = "Base",
		Size = Vector3.new(46, 1, 44),
		CFrame = origin * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(96, 178, 80),
		Material = Enum.Material.Grass,
	}, model)

	-- Garden bed under the tiles.
	part({
		Name = "Bed",
		Size = Vector3.new(38, 0.6, 32),
		CFrame = origin * CFrame.new(0, 1.1, 1),
		Color = Color3.fromRGB(95, 66, 45),
		Material = Enum.Material.Ground,
	}, model)

	local tiles: { BasePart } = {}
	local cfg = Config.Plots
	local pitch = cfg.TileSize + cfg.TileGap
	for row = 1, cfg.Rows do
		for col = 1, cfg.Columns do
			local tileIndex = (row - 1) * cfg.Columns + col
			local x = (col - (cfg.Columns + 1) / 2) * pitch
			local z = -11 + (row - 1) * pitch
			local tile = part({
				Name = `Tile{tileIndex}`,
				Size = Vector3.new(cfg.TileSize, 0.6, cfg.TileSize),
				CFrame = origin * CFrame.new(x, 1.5, z),
				Color = Color3.fromRGB(122, 84, 56),
				Material = Enum.Material.Ground,
			}, model)
			tile:SetAttribute("TileIndex", tileIndex)
			tiles[tileIndex] = tile
		end
	end

	-- Fence with a gap at the front (toward the hub).
	local fenceColor = Color3.fromRGB(240, 230, 210)
	local function rail(cf: CFrame, length: number)
		part(
			{
				Name = "Rail",
				Size = Vector3.new(length, 0.5, 0.4),
				CFrame = cf * CFrame.new(0, 2.6, 0),
				Color = fenceColor,
			},
			model
		)
		part(
			{
				Name = "Rail",
				Size = Vector3.new(length, 0.5, 0.4),
				CFrame = cf * CFrame.new(0, 1.6, 0),
				Color = fenceColor,
			},
			model
		)
	end
	rail(origin * CFrame.new(0, 0, 21.8), 46)
	rail(origin * CFrame.new(-22.8, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 44)
	rail(origin * CFrame.new(22.8, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 44)
	rail(origin * CFrame.new(-15, 0, -21.8), 16)
	rail(origin * CFrame.new(15, 0, -21.8), 16)
	for _, x in { -22.8, -7, 7, 22.8 } do
		part(
			{
				Name = "FencePost",
				Size = Vector3.new(0.8, 3.6, 0.8),
				CFrame = origin * CFrame.new(x, 1.8, -21.8),
				Color = accent,
			},
			model
		)
		part(
			{
				Name = "FencePost",
				Size = Vector3.new(0.8, 3.6, 0.8),
				CFrame = origin * CFrame.new(x, 1.8, 21.8),
				Color = accent,
			},
			model
		)
	end

	-- Owner sign at the entrance.
	part({
		Name = "SignPost",
		Size = Vector3.new(0.8, 7, 0.8),
		CFrame = origin * CFrame.new(-9.5, 3.5, -22.6),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}, model)
	local board = part({
		Name = "SignBoard",
		Size = Vector3.new(10, 3.2, 0.5),
		-- Front face (-Z) points toward the hub so arriving players can read it
		CFrame = origin * CFrame.new(-9.5, 7.4, -22.6),
		Color = accent,
	}, model)
	local signGui = surfaceText(board, Enum.NormalId.Front, "Empty Plot")
	local thumb = Instance.new("ImageLabel")
	thumb.Name = "Avatar"
	thumb.BackgroundTransparency = 1
	thumb.Size = UDim2.fromScale(0.28, 0.84)
	thumb.Position = UDim2.fromScale(0.02, 0.08)
	thumb.Image = ""
	thumb.Parent = signGui
	local label = signGui:FindFirstChild("Label") :: TextLabel
	label.Size = UDim2.fromScale(0.68, 1)
	label.Position = UDim2.fromScale(0.31, 0)

	-- Path stones from the plot entrance toward the hub.
	for i = 0, 3 do
		local stone = part({
			Name = "PathStone",
			Size = Vector3.new(6, 0.3, 4),
			CFrame = origin * CFrame.new(0, 0.15, -25 - i * 6),
			Color = Color3.fromRGB(225, 210, 175),
			Material = Enum.Material.Slate,
		}, model)
		stone.CanCollide = false
	end

	local plants = Instance.new("Folder")
	plants.Name = "Plants"
	plants.Parent = model

	local spawnCf = origin * CFrame.new(0, 4, -17.5)
	return {
		index = index,
		model = model,
		origin = origin,
		spawn = CFrame.lookAt(spawnCf.Position, (origin * CFrame.new(0, 4, 0)).Position),
		tiles = tiles,
		sign = signGui,
		plants = plants,
		accent = accent,
	}
end

function World.build(): WorldRecord
	local existing = Workspace:FindFirstChild("SlimeGarden")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "SlimeGarden"

	part({
		Name = "Ground",
		Size = Vector3.new(480, 4, 480),
		CFrame = CFrame.new(0, -2, 0),
		Color = Color3.fromRGB(110, 196, 92),
		Material = Enum.Material.Grass,
	}, root)

	-- Invisible boundary walls.
	for _, wall in
		{
			{ Vector3.new(0, 30, 236), Vector3.new(480, 60, 4) },
			{ Vector3.new(0, 30, -236), Vector3.new(480, 60, 4) },
			{ Vector3.new(236, 30, 0), Vector3.new(4, 60, 480) },
			{ Vector3.new(-236, 30, 0), Vector3.new(4, 60, 480) },
		}
	do
		part(
			{
				Name = "Boundary",
				Size = wall[2],
				CFrame = CFrame.new(wall[1]),
				Transparency = 1,
				CanQuery = false,
			},
			root
		)
	end

	-- Hub plaza.
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = root
	part({
		Name = "PlazaRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 78, 78),
		CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 180, 150),
		Material = Enum.Material.Cobblestone,
	}, hub)
	part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 72, 72),
		CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(238, 222, 190),
		Material = Enum.Material.Slate,
	}, hub)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "HubSpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.CFrame = CFrame.new(0, 1.1, 14)
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = hub

	-- Centre fountain made of goo.
	part({
		Name = "FountainBowl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 12, 12),
		CFrame = CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(210, 200, 220),
		Material = Enum.Material.Marble,
	}, hub)
	local goo = part({
		Name = "FountainGoo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 10.6, 10.6),
		CFrame = CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 235, 110),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
	}, hub)
	local fountainSlime = SlimeBuilder.build("goo", { "shiny" }, 1.8)
	fountainSlime.Name = "FountainSlime"
	fountainSlime:PivotTo(CFrame.new(0, 2.4, 0))
	fountainSlime:SetAttribute("Bounce", true)
	fountainSlime.Parent = hub
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(170, 255, 150))
	sparkle.Rate = 8
	sparkle.Speed = NumberRange.new(4, 7)
	sparkle.Acceleration = Vector3.new(0, -10, 0)
	sparkle.SpreadAngle = Vector2.new(25, 25)
	sparkle.Lifetime = NumberRange.new(1, 1.5)
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Parent = goo

	-- Seed shop (faces the hub centre from the north) and sell stand (south).
	local shopCf = CFrame.lookAt(Vector3.new(0, 1, -26), Vector3.new(0, 1, 0))
	local shopCounter = buildStall(
		hub,
		"SeedShop",
		shopCf,
		"🌱 SEED SHOP",
		Color3.fromRGB(90, 200, 110),
		Color3.fromRGB(245, 245, 235),
		"goo"
	)
	prompt(shopCounter, "Open Shop", "Seed Shop", "ShopPrompt")

	local sellCf = CFrame.lookAt(Vector3.new(0, 1, 26), Vector3.new(0, 1, 0))
	local sellCounter = buildStall(
		hub,
		"SellStand",
		sellCf,
		"💰 SELL SLIMES",
		Color3.fromRGB(255, 190, 60),
		Color3.fromRGB(245, 245, 235),
		"king"
	)
	prompt(sellCounter, "Sell All", "Sell Stand", "SellPrompt")

	-- Leaderboard (west) and tips board (east).
	local function board(name: string, position: Vector3, size: Vector2): BasePart
		local cf = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
		for _, x in { -size.X / 2 + 0.6, size.X / 2 - 0.6 } do
			part({
				Name = "BoardPost",
				Size = Vector3.new(0.9, position.Y + size.Y / 2, 0.9),
				CFrame = cf * CFrame.new(x, -position.Y / 2 + size.Y / 4, 0.6),
				Color = DARK_WOOD,
				Material = Enum.Material.Wood,
			}, hub)
		end
		return part({
			Name = name,
			Size = Vector3.new(size.X, size.Y, 0.6),
			CFrame = cf,
			Color = Color3.fromRGB(60, 45, 80),
		}, hub)
	end

	local leaderboardPart = board("Leaderboard", Vector3.new(-30, 8, 0), Vector2.new(14, 12))
	local leaderboardGui = Instance.new("SurfaceGui")
	leaderboardGui.Name = "LeaderboardGui"
	leaderboardGui.Face = Enum.NormalId.Front
	leaderboardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	leaderboardGui.PixelsPerStud = 40
	leaderboardGui.LightInfluence = 0
	leaderboardGui.Parent = leaderboardPart

	local tipsPart = board("TipsBoard", Vector3.new(30, 8, 0), Vector2.new(14, 12))
	local _, tipsLabel = surfaceText(
		tipsPart,
		Enum.NormalId.Front,
		"HOW TO PLAY\n\n🌱 Plant seeds in your garden\n⏳ Slimes grow (even offline!)\n✋ Tap ripe slimes to harvest\n💰 Sell them here in the hub\n🌧️ Weather adds mutations\n⭐ Rebirth for permanent bonuses"
	)
	tipsLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Plots in a ring, each facing the hub.
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = root
	local plots: { PlotRecord } = {}
	local count = Config.Plots.Count
	for i = 1, count do
		local angle = math.rad(30 + (i - 1) * 360 / count)
		local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.Plots.Radius
		-- Local -Z (look direction) faces the hub, so the plot's front is toward the centre.
		local origin = CFrame.lookAt(position, Vector3.zero)
		plots[i] = buildPlot(plotsFolder, i, origin)

		-- Path from the hub rim to the plot entrance.
		local dir = (Vector3.zero - position).Unit
		local from = position + dir * 26
		local to = dir * -38
		local mid = (from + to) / 2
		local pathPart = part({
			Name = "Path",
			Size = Vector3.new(7, 0.2, (from - to).Magnitude),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.1, 0), to + Vector3.new(0, 0.1, 0)),
			Color = Color3.fromRGB(225, 205, 160),
			Material = Enum.Material.Sand,
			CanCollide = false,
		}, root)
		pathPart.CastShadow = false
	end

	-- Decor: trees and flowers in the gaps between plots and around the edge.
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = root
	local rng = Rng.new(20261014)
	for i = 1, count do
		local gapAngle = math.rad((i - 1) * 360 / count)
		for j = 1, 3 do
			local radius = 58 + j * 22
			local jitter = (rng() - 0.5) * 0.12
			local position = Vector3.new(math.cos(gapAngle + jitter), 0, math.sin(gapAngle + jitter)) * radius
			buildTree(decor, position, 0.9 + rng() * 0.5, rng)
			buildFlowers(decor, position + Vector3.new(4, 0, 3), rng)
		end
	end
	for i = 1, 36 do
		local angle = (i / 36) * math.pi * 2 + rng() * 0.1
		local radius = 160 + rng() * 55
		buildTree(decor, Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius, 1 + rng() * 0.8, rng)
	end

	root.Parent = Workspace

	return {
		root = root,
		plots = plots,
		shopCounter = shopCounter,
		sellCounter = sellCounter,
		leaderboard = leaderboardGui,
	}
end

return World
