--[[
	SetupWorld  (ModuleScript)  ->  ServerStorage
	Baut die komplette Welt (Map, Förderband, 8 Plots, Basis-Vorlage,
	Leaderboards, Klatsche, Sounds, Licht, Ordner) automatisch auf.

	Ausführen (Studio, NICHT im Play-Modus):
		View -> Command Bar, dann eingeben:
		require(game.ServerStorage.SetupWorld)()

	Mehrfaches Ausführen ist erlaubt: alte Objekte werden ersetzt.
	Danach kann das Modul gelöscht werden (oder liegen bleiben, es läuft nie von selbst).
]]

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPack = game:GetService("StarterPack")
local StarterPlayer = game:GetService("StarterPlayer")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Basis-Mittelpunkte: 4 Basen auf jeder Seite des Förderbands (Band liegt auf Z = 0)
local BASE_POSITIONS = {
	Vector3.new(-135, 0.5, -62), Vector3.new(-45, 0.5, -62),
	Vector3.new(45, 0.5, -62), Vector3.new(135, 0.5, -62),
	Vector3.new(-135, 0.5, 62), Vector3.new(-45, 0.5, 62),
	Vector3.new(45, 0.5, 62), Vector3.new(135, 0.5, 62),
}

local WHITE = Color3.new(1, 1, 1)
local INVISIBLE = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }

local function replace(parent, className, name)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function makePart(name, parent, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function at(x, y, z)
	return CFrame.new(x, y, z)
end

local function makeLabel(parent, text, color)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = parent
	return label
end

local function billboard(parent, name, sizeStuds, offset, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.new(sizeStuds.X, 0, sizeStuds.Y, 0)
	gui.StudsOffset = offset
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	makeLabel(gui, text, color)
	gui.Parent = parent
	return gui
end

------------------------------------------------------------------------
-- Map
------------------------------------------------------------------------
local function buildMap()
	local oldBaseplate = Workspace:FindFirstChild("Baseplate")
	if oldBaseplate then
		oldBaseplate:Destroy()
	end
	local oldSpawn = Workspace:FindFirstChild("SpawnLocation")
	if oldSpawn then
		oldSpawn:Destroy()
	end

	local map = replace(Workspace, "Folder", "Map")
	makePart("Ground", map, Vector3.new(420, 2, 280), at(0, -1, 0), Color3.fromRGB(106, 190, 92), Enum.Material.Grass)
	makePart("Walkway", map, Vector3.new(200, 0.2, 46), at(0, 0.1, 0), Color3.fromRGB(235, 225, 200), Enum.Material.Concrete)

	-- Unsichtbare Weltgrenzen
	local h = 80
	makePart("BoundaryN", map, Vector3.new(420, h, 2), at(0, h / 2, 141), WHITE, nil, { Transparency = 1 })
	makePart("BoundaryS", map, Vector3.new(420, h, 2), at(0, h / 2, -141), WHITE, nil, { Transparency = 1 })
	makePart("BoundaryE", map, Vector3.new(2, h, 280), at(211, h / 2, 0), WHITE, nil, { Transparency = 1 })
	makePart("BoundaryW", map, Vector3.new(2, h, 280), at(-211, h / 2, 0), WHITE, nil, { Transparency = 1 })

	-- Fallback-Spawn (Spieler werden per Script in ihre Basis gesetzt)
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.CFrame = at(0, 0.6, -20)
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Transparency = 0.5
	spawnLocation.Parent = Workspace

	ensureFolder(Workspace, "Bases")
	ensureFolder(Workspace, "ConveyorFigures")
end

------------------------------------------------------------------------
-- Förderband
------------------------------------------------------------------------
local function buildGate(parent, name, x, color, text)
	local gate = Instance.new("Model")
	gate.Name = name
	gate.Parent = parent
	makePart("PillarA", gate, Vector3.new(2, 14, 2), at(x, 7, -8), color, Enum.Material.Neon)
	makePart("PillarB", gate, Vector3.new(2, 14, 2), at(x, 7, 8), color, Enum.Material.Neon)
	local top = makePart("Top", gate, Vector3.new(2, 3, 18), at(x, 15.5, 0), color, Enum.Material.Neon)
	billboard(top, "GateGui", Vector2.new(14, 3), Vector3.new(0, 3.5, 0), text, WHITE)
end

local function buildConveyor()
	local conveyor = replace(Workspace, "Model", "Conveyor")
	local belt = makePart("Belt", conveyor, Vector3.new(180, 1, 12), at(0, 0.5, 0), Color3.fromRGB(45, 45, 52), Enum.Material.DiamondPlate)
	conveyor.PrimaryPart = belt

	local railColor = Color3.fromRGB(255, 200, 40)
	makePart("RailLeft", conveyor, Vector3.new(180, 1.6, 1), at(0, 1.3, -6.5), railColor, Enum.Material.Metal)
	makePart("RailRight", conveyor, Vector3.new(180, 1.6, 1), at(0, 1.3, 6.5), railColor, Enum.Material.Metal)

	local stripes = Instance.new("Folder")
	stripes.Name = "Stripes"
	stripes.Parent = conveyor
	for i = 0, 17 do
		makePart("Stripe", stripes, Vector3.new(1.5, 0.05, 10), at(-85 + i * 10, 1.03, 0), Color3.fromRGB(80, 80, 92), nil, { CanCollide = false, CanQuery = false, CanTouch = false })
	end

	makePart("StartPoint", conveyor, Vector3.new(2, 2, 2), at(-85, 1, 0), WHITE, nil, INVISIBLE)
	makePart("EndPoint", conveyor, Vector3.new(2, 2, 2), at(85, 1, 0), WHITE, nil, INVISIBLE)

	buildGate(conveyor, "SpawnGate", -92, Color3.fromRGB(166, 75, 255), "BRAINROT-FABRIK")
	buildGate(conveyor, "EndGate", 92, Color3.fromRGB(255, 60, 60), "LETZTE CHANCE!")
end

------------------------------------------------------------------------
-- Plots (Platzhalter, an denen die Basen zur Laufzeit erscheinen)
------------------------------------------------------------------------
local function buildPlots()
	local plots = replace(Workspace, "Folder", "Plots")
	for i, pos in ipairs(BASE_POSITIONS) do
		local lookTarget = Vector3.new(pos.X, pos.Y, 0) -- Tür zeigt zum Band
		local plot = makePart("Plot" .. i, plots, Vector3.new(80, 1, 60), CFrame.lookAt(pos, lookTarget), WHITE, nil, INVISIBLE)
		plot:SetAttribute("PlotIndex", i)
	end
end

------------------------------------------------------------------------
-- Basis-Vorlage (ServerStorage.BaseTemplate)
-- Lokales Koordinatensystem: Tür bei Z = -30 (Vorderseite = LookVector)
------------------------------------------------------------------------
local function buildBaseTemplate()
	local base = replace(ServerStorage, "Model", "BaseTemplate")

	local floor = makePart("Floor", base, Vector3.new(80, 1, 60), at(0, 0.5, 0), Color3.fromRGB(200, 200, 210))
	base.PrimaryPart = floor

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = base
	local wallColor = Color3.fromRGB(240, 240, 245)
	makePart("BackWall", walls, Vector3.new(80, 10, 1), at(0, 6, 29.5), wallColor)
	makePart("LeftWall", walls, Vector3.new(1, 10, 60), at(-39.5, 6, 0), wallColor)
	makePart("RightWall", walls, Vector3.new(1, 10, 60), at(39.5, 6, 0), wallColor)
	makePart("FrontLeftWall", walls, Vector3.new(30, 10, 1), at(-25, 6, -29.5), wallColor)
	makePart("FrontRightWall", walls, Vector3.new(30, 10, 1), at(25, 6, -29.5), wallColor)
	makePart("DoorBeam", walls, Vector3.new(20, 2, 1), at(0, 12, -29.5), wallColor)

	-- Laser-Tür (unsichtbar = offen; der Server macht sie beim Abschließen sichtbar)
	local door = makePart("LaserDoor", base, Vector3.new(20, 10, 0.4), at(0, 6, -29.5), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, {
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	local doorGui = billboard(door, "DoorGui", Vector2.new(8, 3), Vector3.new(0, 0, 0), "🔒 60", WHITE)
	doorGui.Enabled = false

	-- Besitzer-Schild über der Tür
	local sign = makePart("Sign", base, Vector3.new(24, 5, 0.6), at(0, 15.5, -29.5), Color3.fromRGB(30, 30, 40))
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "SignGui"
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 40
	signGui.LightInfluence = 0
	signGui.Parent = sign
	makeLabel(signGui, "Freie Basis", WHITE)

	-- Slots 1-10 (Start), 11-15 (Rebirth), 16-20 (Game Pass), 21 (Premium)
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = base
	for i = 1, 20 do
		local row = (i <= 10) and 0 or 1
		local col = (i - 1) % 10
		local slot = makePart("Slot" .. i, slots, Vector3.new(5, 0.4, 5), at(-31.5 + col * 7, 1.2, 6 + row * 13), WHITE)
		slot:SetAttribute("SlotIndex", i)
	end
	local premiumSlot = makePart("Slot21", slots, Vector3.new(5, 0.4, 5), at(0, 1.2, -4), Color3.fromRGB(255, 215, 0), Enum.Material.Neon)
	premiumSlot:SetAttribute("SlotIndex", 21)
	premiumSlot:SetAttribute("Premium", true)

	-- Cash-Pad (drüberlaufen = einsammeln)
	local cashPad = makePart("CashPad", base, Vector3.new(8, 0.4, 8), at(-28, 1.2, -18), Color3.fromRGB(60, 220, 90), Enum.Material.Neon)
	billboard(cashPad, "CashGui", Vector2.new(10, 3), Vector3.new(0, 3, 0), "$0", Color3.fromRGB(120, 255, 140))

	-- Schloss-Knopf
	local lockButton = makePart("LockButton", base, Vector3.new(5, 0.6, 5), at(28, 1.3, -18), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	billboard(lockButton, "LockGui", Vector2.new(10, 3), Vector3.new(0, 3, 0), "🔓 Abschließen", WHITE)

	makePart("SpawnPoint", base, Vector3.new(4, 1, 4), at(0, 1.5, -12), WHITE, nil, INVISIBLE)
	makePart("Zone", base, Vector3.new(78, 16, 58), at(0, 9, 0), WHITE, nil, INVISIBLE)
end

------------------------------------------------------------------------
-- Leaderboards
------------------------------------------------------------------------
local function buildBoard(parent, name, x, face, title)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local dark = Color3.fromRGB(25, 25, 35)
	local screen = makePart("Screen", model, Vector3.new(1, 16, 26), at(x, 11, 0), dark)
	makePart("PostA", model, Vector3.new(1.2, 3, 1.2), at(x, 1.5, -10), dark, Enum.Material.Metal)
	makePart("PostB", model, Vector3.new(1.2, 3, 1.2), at(x, 1.5, 10), dark, Enum.Material.Metal)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = screen

	local titleLabel = makeLabel(gui, title, Color3.fromRGB(255, 220, 80))
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 0.12)

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.03, 0.14)
	list.Size = UDim2.fromScale(0.94, 0.84)
	list.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.005, 0)
	layout.Parent = list
end

local function buildLeaderboards()
	local boards = replace(Workspace, "Folder", "Leaderboards")
	buildBoard(boards, "CashBoard", -112, Enum.NormalId.Right, "💰 Meistes Cash (gesamt)")
	buildBoard(boards, "RebirthBoard", 112, Enum.NormalId.Left, "⭐ Meiste Rebirths")
end

------------------------------------------------------------------------
-- Klatsche (Abwehr-Tool, jeder Spieler bekommt sie)
------------------------------------------------------------------------
local function buildTool()
	local tool = replace(StarterPack, "Tool", "Klatsche")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Triff Diebe!"
	tool.Grip = CFrame.new(0, -1.2, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 3.2, 0.4)
	handle.Color = Color3.fromRGB(150, 100, 60)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.6, 2.6, 0.3)
	head.Color = Color3.fromRGB(255, 90, 170)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 2.9, 0)
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle
end

------------------------------------------------------------------------
-- Sounds (SoundId später aus der Roblox-Audio-Bibliothek eintragen)
------------------------------------------------------------------------
local function buildSounds()
	local sfx = ensureFolder(SoundService, "Sfx")
	local names = {
		"Buy", "Sell", "Cash", "Steal", "Alarm", "Bonk", "Lock", "Unlock",
		"Rebirth", "Rare", "Legendary", "Secret", "Click", "Error", "Reward",
	}
	for _, name in ipairs(names) do
		if not sfx:FindFirstChild(name) then
			local s = Instance.new("Sound")
			s.Name = name
			s.Volume = 0.6
			s.Parent = sfx
		end
	end
	if not SoundService:FindFirstChild("Music") then
		local music = Instance.new("Sound")
		music.Name = "Music"
		music.Looped = true
		music.Volume = 0.25
		music.Parent = SoundService
	end
end

------------------------------------------------------------------------
-- Licht und Look (bunt, freundlich, "Brainrot")
------------------------------------------------------------------------
local function buildLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 155)
	Lighting.GlobalShadows = true

	local cc = replace(Lighting, "ColorCorrectionEffect", "Vibe")
	cc.Saturation = 0.2
	cc.Contrast = 0.05

	local bloom = replace(Lighting, "BloomEffect", "Glow")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.5

	local atmosphere = replace(Lighting, "Atmosphere", "Air")
	atmosphere.Density = 0.25
	atmosphere.Haze = 0.5
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
end

------------------------------------------------------------------------
-- Ordner für die Scripts aus Phase 3
------------------------------------------------------------------------
local function buildFolders()
	ensureFolder(ReplicatedStorage, "Shared")
	ensureFolder(ReplicatedStorage, "FigureModels")
	ensureFolder(ReplicatedStorage, "Remotes")
	ensureFolder(ServerScriptService, "Services")
	ensureFolder(StarterPlayer:WaitForChild("StarterPlayerScripts"), "ClientModules")
	Workspace.StreamingEnabled = false
end

return function()
	buildMap()
	buildConveyor()
	buildPlots()
	buildBaseTemplate()
	buildLeaderboards()
	buildTool()
	buildSounds()
	buildLighting()
	buildFolders()
	ChangeHistoryService:SetWaypoint("Brainrot Setup")
	print("✅ Brainrot-Welt aufgebaut! Basis-Vorlage liegt in ServerStorage.BaseTemplate.")
end
