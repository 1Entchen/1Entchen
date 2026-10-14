--[[
	FigureBuilder  (ModuleScript)  ->  ReplicatedStorage/Shared/FigureBuilder
	Baut ein Figuren-Modell:
	  - eigenes Modell aus ReplicatedStorage/FigureModels/<Key>, falls vorhanden
	  - sonst automatischer Platzhalter in den Figurfarben
	Danach: Mutations-Look, Seltenheits-Licht, Namensschild.
	Root ist verankert, alle anderen Teile sind per WeldConstraint an Root geschweißt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = script.Parent
local Config = require(Shared:WaitForChild("Config"))
local Figures = require(Shared:WaitForChild("Figures"))
local Format = require(Shared:WaitForChild("Format"))

local FigureBuilder = {}

local function newPart(model, name, shape, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Parent = model
	return p
end

-- Platzhalter: Körper + Kopf + große Augen + Ohren + Füße
local function buildPlaceholder(fig)
	local model = Instance.new("Model")
	local h = fig.Height
	local w = h * 0.7

	local root = newPart(model, "Root", Enum.PartType.Block, Vector3.new(3, 0.2, 3), CFrame.new(0, 0.1, 0), Color3.new(1, 1, 1))
	root.Transparency = 1
	model.PrimaryPart = root

	local bodyCenter = CFrame.new(0, h * 0.32, 0)
	local shapeType = fig.Id % 3
	if shapeType == 0 then
		newPart(model, "Body", Enum.PartType.Block, Vector3.new(w, h * 0.55, w * 0.85), bodyCenter, fig.Color1)
	elseif shapeType == 1 then
		newPart(model, "Body", Enum.PartType.Ball, Vector3.new(w, w, w), bodyCenter, fig.Color1)
	else
		newPart(model, "Body", Enum.PartType.Cylinder, Vector3.new(h * 0.55, w, w), bodyCenter * CFrame.Angles(0, 0, math.rad(90)), fig.Color1)
	end

	local headSize = h * 0.45
	local headCenter = CFrame.new(0, h * 0.78, -h * 0.05)
	newPart(model, "Head", Enum.PartType.Ball, Vector3.new(headSize, headSize, headSize), headCenter, fig.Color1)

	-- Augen schauen nach vorne (-Z)
	for _, side in ipairs({ -1, 1 }) do
		local eye = newPart(model, "Eye", Enum.PartType.Ball, Vector3.one * h * 0.16,
			headCenter * CFrame.new(side * h * 0.1, h * 0.04, -headSize * 0.42), Color3.new(1, 1, 1))
		eye:SetAttribute("NoTint", true)
		local pupil = newPart(model, "Pupil", Enum.PartType.Ball, Vector3.one * h * 0.075,
			headCenter * CFrame.new(side * h * 0.1, h * 0.04, -headSize * 0.42 - h * 0.06), Color3.new(0.05, 0.05, 0.05))
		pupil:SetAttribute("NoTint", true)

		newPart(model, "Ear", Enum.PartType.Block, Vector3.new(h * 0.1, h * 0.16, h * 0.1),
			headCenter * CFrame.new(side * headSize * 0.32, headSize * 0.48, 0) * CFrame.Angles(0, 0, math.rad(-side * 15)), fig.Color2)
		newPart(model, "Foot", Enum.PartType.Ball, Vector3.new(h * 0.2, h * 0.12, h * 0.26),
			CFrame.new(side * w * 0.28, h * 0.06, -w * 0.2), fig.Color2)
	end

	newPart(model, "Mouth", Enum.PartType.Block, Vector3.new(h * 0.16, h * 0.03, h * 0.03),
		headCenter * CFrame.new(0, -h * 0.08, -headSize * 0.48), Color3.new(0.1, 0.05, 0.05)):SetAttribute("NoTint", true)
	newPart(model, "Belly", Enum.PartType.Ball, Vector3.new(w * 0.55, h * 0.3, w * 0.2),
		bodyCenter * CFrame.new(0, 0, -w * 0.38), fig.Color2)

	return model
end

local function getModel(fig)
	local folder = ReplicatedStorage:FindFirstChild("FigureModels")
	local template = folder and folder:FindFirstChild(fig.Key)
	if template and template:IsA("Model") and template.PrimaryPart then
		local clone = template:Clone()
		clone.PrimaryPart.Name = "Root"
		return clone
	end
	if template then
		warn(("[FigureBuilder] Modell '%s' braucht ein PrimaryPart namens Root. Nutze Platzhalter."):format(fig.Key))
	end
	return buildPlaceholder(fig)
end

local function applyMutation(model, mutation)
	if mutation == "Normal" or not Config.Mutations[mutation] then
		return
	end
	local info = Config.Mutations[mutation]
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "Root" and not part:GetAttribute("NoTint") then
			if mutation == "Gold" then
				part.Color = part.Color:Lerp(info.Color, 0.65)
				part.Material = Enum.Material.Metal
				part.Reflectance = 0.15
			elseif mutation == "Diamond" then
				part.Color = part.Color:Lerp(info.Color, 0.6)
				part.Material = Enum.Material.Glass
				part.Transparency = math.max(part.Transparency, 0.15)
				part.Reflectance = 0.25
			elseif mutation == "Rainbow" then
				part.Material = Enum.Material.Neon
			end
		end
	end
	if mutation == "Rainbow" then
		CollectionService:AddTag(model, "RainbowFigure")
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = info.Color
	sparkles.Parent = model.PrimaryPart
end

local function applyRarityFx(model, fig)
	local rarity = Config.Rarities[fig.Rarity]
	if rarity.Rank >= 4 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 8 + rarity.Rank * 2
		light.Brightness = 1.5
		light.Parent = model.PrimaryPart
	end
	if fig.Rarity == "Secret" then
		CollectionService:AddTag(model, "SecretFigure")
	end
end

local function addInfo(model, fig, mutation, mode)
	local height = model:GetExtentsSize().Y
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.new(8, 0, 2.7, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 1.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Adornee = model.PrimaryPart

	local function label(name, text, color, y, hgt)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, hgt)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		l.TextStrokeTransparency = 0
		l.Parent = gui
		return l
	end

	local rarity = Config.Rarities[fig.Rarity]
	local mut = Figures.Mutation(mutation)
	local nameColor = mut.Color or Color3.new(1, 1, 1)
	label("NameLabel", Figures.DisplayName(fig.Id, mutation), nameColor, 0, 0.38)
	label("RarityLabel", rarity.Display, rarity.Color, 0.38, 0.28)
	if mode == "Conveyor" then
		label("ValueLabel", Format.Money(Figures.Price(fig.Id, mutation)), Color3.fromRGB(120, 255, 140), 0.66, 0.34)
	else
		label("ValueLabel", Format.Money(Figures.Income(fig.Id, mutation)) .. "/s", Color3.fromRGB(255, 230, 90), 0.66, 0.34)
	end
	gui.Parent = model.PrimaryPart
end

local function weldToRoot(model)
	local root = model.PrimaryPart
	root.Anchored = true
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = part == root
			part.Massless = true
			if part ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = part
				weld.Parent = part
				part.Anchored = false
			end
		elseif part:IsA("Script") or part:IsA("LocalScript") or part:IsA("Sound") then
			part:Destroy()
		end
	end
end

--[[
	opts.Mode:  "Conveyor" (Preis), "Base" (Einkommen), "Carry" (klein, ohne Schild)
	opts.Ghost: halb durchsichtig (wird gerade gestohlen)
]]
function FigureBuilder.Build(id, mutation, opts)
	opts = opts or {}
	local fig = Figures.Get(id)
	if not fig then
		return nil
	end
	mutation = mutation or "Normal"

	local model = getModel(fig)
	model.Name = fig.Key
	model:SetAttribute("FigureId", id)
	model:SetAttribute("Mutation", mutation)
	model:PivotTo(CFrame.new())

	applyMutation(model, mutation)
	applyRarityFx(model, fig)
	weldToRoot(model)

	if opts.Mode == "Carry" then
		pcall(function()
			model:ScaleTo(0.6)
		end)
	else
		addInfo(model, fig, mutation, opts.Mode)
	end

	if opts.Ghost then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "Root" then
				part.Transparency = math.max(part.Transparency, 0.75)
			end
		end
		local info = model.PrimaryPart:FindFirstChild("Info")
		if info then
			info.ValueLabel.Text = "⚠ WIRD GESTOHLEN!"
			info.ValueLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
		end
	end

	return model
end

-- Stellt das Modell mit der Unterseite von Root auf eine Oberfläche
function FigureBuilder.PlaceOn(model, surfaceCFrame)
	local root = model.PrimaryPart
	model:PivotTo(surfaceCFrame * CFrame.new(0, root.Size.Y / 2, 0))
end

return FigureBuilder
