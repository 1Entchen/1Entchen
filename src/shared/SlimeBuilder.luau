--!strict
-- Builds slime models entirely from primitive parts (no uploaded assets
-- needed). The model's pivot is the centre of its base so PivotTo() drops it
-- onto a surface, and Model:ScaleTo() grows it from the ground up.

local Mutations = require(script.Parent.Mutations)
local Species = require(script.Parent.Species)

local SlimeBuilder = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local BODY_DIAMETER = 2.6
local SINK = 0.3 -- fraction of the body sphere hidden below the base

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function ball(name: string, diameter: number, cf: CFrame, color: Color3, parent: Instance): BasePart
	return part({
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		CFrame = cf,
		Color = color,
	}, parent)
end

local function emitter(parent: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 0.6
	e.Rate = 4
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.25, 0)
	e.Texture = SPARKLE
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function hasMutation(mutations: { string }, id: string): boolean
	return table.find(mutations, id) ~= nil
end

local function addAccessories(speciesId: string, model: Model, body: BasePart, s: number, accent: Color3)
	local radius = BODY_DIAMETER * s / 2
	local top = body.CFrame.Position + Vector3.new(0, radius * 0.92, 0)

	if speciesId == "bubble" then
		local b = ball("Bubble", 0.7 * s, CFrame.new(top + Vector3.new(0.6 * s, 0.2 * s, 0)), accent, model)
		b.Material = Enum.Material.Glass
		b.Transparency = 0.45
	elseif speciesId == "berry" then
		for i, angle in { -35, 35 } do
			part({
				Name = "Leaf" .. i,
				Size = Vector3.new(0.75, 0.12, 0.38) * s,
				CFrame = CFrame.new(top + Vector3.new(0, 0.1 * s, 0))
					* CFrame.Angles(0, math.rad(angle + 90), math.rad(25))
					* CFrame.new(0.3 * s, 0, 0),
				Color = accent,
			}, model)
		end
	elseif speciesId == "ember" then
		local flame = ball("Flame", 0.6 * s, CFrame.new(top + Vector3.new(0, 0.15 * s, 0)), accent, model)
		flame.Material = Enum.Material.Neon
		emitter(flame, {
			Texture = FIRE,
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20)),
			Size = NumberSequence.new(0.45 * s, 0),
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(10, 10),
			Rate = 12,
			Lifetime = NumberRange.new(0.4, 0.7),
		})
	elseif speciesId == "frost" or speciesId == "crystal" then
		local count = if speciesId == "crystal" then 3 else 4
		for i = 1, count do
			local angle = (i / count) * math.pi * 2
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.35
			local height = (if speciesId == "crystal" then 1.1 else 0.7) * s
			local shard = part({
				Name = "Shard" .. i,
				Size = Vector3.new(0.35 * s, height, 0.35 * s),
				CFrame = CFrame.new(top + offset - Vector3.new(0, 0.15 * s, 0))
					* CFrame.Angles(math.cos(angle) * 0.35, angle, math.sin(angle) * 0.35)
					* CFrame.new(0, height / 2, 0),
				Color = accent,
				Material = if speciesId == "crystal" then Enum.Material.Neon else Enum.Material.Ice,
				Transparency = 0.15,
			}, model)
			shard.CastShadow = false
		end
	elseif speciesId == "toxic" then
		emitter(body, {
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(190, 255, 80)),
			Size = NumberSequence.new(0.3 * s, 0.6 * s),
			Transparency = NumberSequence.new(0.3, 1),
			Acceleration = Vector3.new(0, 2, 0),
			Rate = 3,
		})
	elseif speciesId == "king" then
		local crownY = top + Vector3.new(0, 0.05 * s, 0)
		part({
			Name = "CrownBand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.35 * s, 1.3 * s, 1.3 * s),
			CFrame = CFrame.new(crownY) * CFrame.Angles(0, 0, math.rad(90)),
			Color = accent,
			Material = Enum.Material.Foil,
		}, model)
		for i = 1, 5 do
			local angle = (i / 5) * math.pi * 2
			part({
				Name = "CrownSpike" .. i,
				Size = Vector3.new(0.22, 0.45, 0.22) * s,
				CFrame = CFrame.new(crownY + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 0.55 * s)
					* CFrame.new(0, 0.35 * s, 0)
					* CFrame.Angles(0, angle, math.rad(45)),
				Color = accent,
				Material = Enum.Material.Foil,
			}, model)
		end
		local gem = ball(
			"Gem",
			0.28 * s,
			CFrame.new(crownY + Vector3.new(0, 0.05 * s, -0.66 * s)),
			Color3.fromRGB(230, 40, 70),
			model
		)
		gem.Material = Enum.Material.Neon
	elseif speciesId == "cosmic" or speciesId == "prism" then
		local orbit = Instance.new("Model")
		orbit.Name = "Orbit"
		orbit.Parent = model
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			local position = body.CFrame.Position
				+ Vector3.new(
					math.cos(angle) * radius * 1.35,
					math.sin(angle) * radius * 0.35,
					math.sin(angle) * radius * 1.35
				)
			local star = ball("Star" .. i, 0.22 * s, CFrame.new(position), accent, orbit)
			star.Material = Enum.Material.Neon
		end
		emitter(body, { Color = ColorSequence.new(accent), Rate = 5 })
	end
end

local function applyMutations(model: Model, body: BasePart, mutations: { string }, s: number)
	if hasMutation(mutations, "golden") then
		body.Color = Color3.fromRGB(255, 205, 50)
		body.Material = Enum.Material.Foil
		body.Transparency = 0
	elseif hasMutation(mutations, "rainbow") then
		body.Material = Enum.Material.SmoothPlastic
		model:SetAttribute("Rainbow", true)
	end
	if hasMutation(mutations, "frozen") then
		body.Color = body.Color:Lerp(Color3.fromRGB(190, 235, 255), 0.55)
		body.Material = Enum.Material.Ice
	end
	if hasMutation(mutations, "sunkissed") then
		body.Color = body.Color:Lerp(Color3.fromRGB(255, 160, 60), 0.35)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 180, 90)
		light.Range = 8 * s
		light.Brightness = 1.2
		light.Parent = body
	end
	if hasMutation(mutations, "drenched") then
		body.Transparency = math.min(body.Transparency + 0.25, 0.5)
		emitter(body, {
			Texture = SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(90, 200, 255)),
			Acceleration = Vector3.new(0, -12, 0),
			Speed = NumberRange.new(0.2, 0.5),
			Rate = 6,
			Size = NumberSequence.new(0.18 * s, 0.05),
		})
	end
	if hasMutation(mutations, "shiny") then
		emitter(body, {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 220)),
			Rate = 6,
			Size = NumberSequence.new(0.35 * s, 0),
		})
	end
	if hasMutation(mutations, "starstruck") then
		emitter(body, {
			Color = ColorSequence.new(Color3.fromRGB(210, 170, 255), Color3.fromRGB(120, 200, 255)),
			Rate = 10,
			Size = NumberSequence.new(0.5 * s, 0),
			Speed = NumberRange.new(1, 3),
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(190, 150, 255)
		light.Range = 10 * s
		light.Brightness = 1.5
		light.Parent = body
	end
end

-- size: overall scale (from Economy.visualSize(weight)).
function SlimeBuilder.build(speciesId: string, mutations: { string }, size: number): Model
	local species = Species.byId[speciesId]
	assert(species, `unknown species {speciesId}`)
	local s = size

	local model = Instance.new("Model")
	model.Name = species.name

	local diameter = BODY_DIAMETER * s
	local center = Vector3.new(0, diameter * (0.5 - SINK), 0)

	local body = ball("Body", diameter, CFrame.new(center), species.color, model)
	body.Material = species.material
	body.Transparency = species.transparency
	body.CanQuery = true
	body.CastShadow = true
	model.PrimaryPart = body

	-- Puddle-like base ring so the slime reads as squishy on the ground.
	local base = part({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2 * s, diameter * 1.08, diameter * 1.08),
		CFrame = CFrame.new(0, 0.1 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = species.color,
		Material = species.material,
		Transparency = math.min(species.transparency + 0.1, 0.6),
	}, model)
	base.CastShadow = false

	local radius = diameter / 2
	local front = -radius * 0.86
	local eyeHeight = center.Y + radius * 0.22
	local eyeWhite = if speciesId == "shadow" then Color3.fromRGB(30, 20, 45) else Color3.new(1, 1, 1)
	local pupilColor = if speciesId == "shadow"
		then Color3.fromRGB(220, 120, 255)
		else Color3.fromRGB(25, 25, 35)
	for _, side in { -1, 1 } do
		ball(
			if side < 0 then "EyeL" else "EyeR",
			0.58 * s,
			CFrame.new(side * 0.42 * s, eyeHeight, front),
			eyeWhite,
			model
		)
		local pupil = ball(
			if side < 0 then "PupilL" else "PupilR",
			0.32 * s,
			CFrame.new(side * 0.42 * s, eyeHeight - 0.03 * s, front - 0.2 * s),
			pupilColor,
			model
		)
		if speciesId == "shadow" then
			pupil.Material = Enum.Material.Neon
		end
		local cheek = ball(
			if side < 0 then "CheekL" else "CheekR",
			0.32 * s,
			CFrame.new(side * 0.78 * s, eyeHeight - 0.38 * s, front * 0.86),
			Color3.fromRGB(255, 130, 160),
			model
		)
		cheek.Transparency = 0.35
	end

	local shine = ball(
		"Shine",
		0.48 * s,
		CFrame.new(-0.55 * s, center.Y + radius * 0.6, -radius * 0.45),
		Color3.new(1, 1, 1),
		model
	)
	shine.Transparency = 0.4

	addAccessories(speciesId, model, body, s, species.accent)
	applyMutations(model, body, mutations, s)

	model:SetAttribute("Species", speciesId)
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

-- Colour for UI chips that represent a slime with mutations.
function SlimeBuilder.displayColor(speciesId: string, mutations: { string }): Color3
	if table.find(mutations, "golden") then
		return Color3.fromRGB(255, 205, 50)
	end
	local species = Species.byId[speciesId]
	local color = if species then species.color else Color3.new(1, 1, 1)
	if table.find(mutations, "frozen") then
		color = color:Lerp(Color3.fromRGB(190, 235, 255), 0.55)
	end
	return color
end

function SlimeBuilder.mutationNames(mutations: { string }): string
	local names = {}
	local sorted = table.clone(mutations)
	table.sort(sorted, function(a, b)
		local ma, mb = Mutations.byId[a], Mutations.byId[b]
		return (if ma then ma.order else 99) < (if mb then mb.order else 99)
	end)
	for _, id in sorted do
		local mutation = Mutations.byId[id]
		if mutation then
			table.insert(names, mutation.name)
		end
	end
	return table.concat(names, " ")
end

return SlimeBuilder
