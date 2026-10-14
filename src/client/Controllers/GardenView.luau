--!strict
-- Garden interaction and visuals on the client:
--  * tap / click a tile to plant the selected seed, tap a ripe slime to harvest
--  * grows slime models locally from replicated growth attributes
--  * bouncing ripe slimes, rainbow colour cycling, orbiting stars
--  * timers / "READY" labels and harvest prompts on the player's own garden
-- The server validates every request; nothing here is authoritative.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local Species = require(Shared:WaitForChild("Species"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))
local Windows = require(UI:WaitForChild("Windows"))

local State = require(script.Parent.Parent:WaitForChild("State"))
local Notifications = require(script.Parent.Notifications)

local GardenView = {}

GardenView.SelectionChanged = Signal.new() :: Signal.Signal<string?>
GardenView.selectedSeed = nil :: string?

local player = Players.LocalPlayer

type Tracked = {
	model: Model,
	own: boolean,
	base: CFrame,
	scale: number,
	phase: number,
	billboard: BillboardGui?,
	prompt: ProximityPrompt?,
}

local tracked: { [Model]: Tracked } = {}
local plotsFolder: Folder? = nil
local hoverHighlight: Highlight? = nil

local function ownPlot(): Model?
	local index = player:GetAttribute("PlotIndex")
	if typeof(index) ~= "number" or not plotsFolder then
		return nil
	end
	local plot = (plotsFolder :: Folder):FindFirstChild(`Plot{index}`)
	return if plot and plot:IsA("Model") then plot else nil
end

function GardenView.ownPlot(): Model?
	return ownPlot()
end

function GardenView.select(speciesId: string?)
	GardenView.selectedSeed = speciesId
	GardenView.SelectionChanged:Fire(speciesId)
end

-- Picks the most valuable seed the player owns.
local function bestOwnedSeed(): string?
	local main = State.main()
	if not main then
		return nil
	end
	local best: string? = nil
	local bestTier = -1
	for id, count in main.seeds do
		local species = Species.byId[id]
		if species and count > 0 then
			local tier = if species.tier == 0 then 100 else species.tier
			if tier > bestTier then
				best, bestTier = id, tier
			end
		end
	end
	return best
end

local function ensureSelection()
	local main = State.main()
	if not main then
		return
	end
	local selected = GardenView.selectedSeed
	if selected and (main.seeds[selected] or 0) > 0 then
		return
	end
	GardenView.select(bestOwnedSeed())
end

local function progressOf(model: Model): number
	if model:GetAttribute("Ripe") then
		return 1
	end
	local growTime = model:GetAttribute("GrowTime")
	local elapsed = model:GetAttribute("Elapsed")
	local rate = model:GetAttribute("Rate")
	local updatedAt = model:GetAttribute("UpdatedAt")
	if
		typeof(growTime) ~= "number"
		or typeof(elapsed) ~= "number"
		or typeof(rate) ~= "number"
		or typeof(updatedAt) ~= "number"
	then
		return 0
	end
	local current = elapsed + (Workspace:GetServerTimeNow() - updatedAt) * rate
	return math.clamp(current / math.max(growTime, 0.001), 0, 1)
end

local function remainingSeconds(model: Model): number
	local growTime = model:GetAttribute("GrowTime")
	local rate = model:GetAttribute("Rate")
	if typeof(growTime) ~= "number" or typeof(rate) ~= "number" or rate <= 0 then
		return 0
	end
	return (1 - progressOf(model)) * growTime / rate
end

local function slimeValue(model: Model): number
	local mutationsText = model:GetAttribute("Mutations")
	local mutations = {}
	if typeof(mutationsText) == "string" and mutationsText ~= "" then
		mutations = string.split(mutationsText, ",")
	end
	local weight = model:GetAttribute("Weight")
	local base = model:GetAttribute("BaseValue")
	local boosts = State.get("boosts")
	local multiplier = if boosts then boosts.multipliers.sell else 1
	return Economy.slimeValue({
		s = tostring(model:GetAttribute("Species")),
		w = if typeof(weight) == "number" then weight else 1,
		m = mutations,
		b = if typeof(base) == "number" then base else nil,
	}, multiplier)
end

local function buildBillboard(record: Tracked)
	local body = record.model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end
	local billboard: BillboardGui = Kit.new("BillboardGui", {
		Name = "SlimeLabel",
		Adornee = body,
		Size = UDim2.new(4.2, 0, 1.7, 0),
		ExtentsOffsetWorldSpace = Vector3.new(0, 0.6, 0),
		MaxDistance = 80,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = body,
	})
	local title = Kit.label({
		Name = "Title",
		Text = "",
		Size = UDim2.fromScale(1, 0.55),
		MaxTextSize = 60,
		Parent = billboard,
	})
	title.TextScaled = true
	local barBack: Frame = Kit.new("Frame", {
		Name = "Bar",
		BackgroundColor3 = Theme.Colors.PanelDark,
		Size = UDim2.fromScale(0.9, 0.3),
		Position = UDim2.fromScale(0.05, 0.62),
		Parent = billboard,
	})
	Kit.corner(8).Parent = barBack
	Kit.stroke(Theme.Colors.Stroke, 2).Parent = barBack
	local fill: Frame = Kit.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.Colors.Green,
		Size = UDim2.fromScale(0, 1),
		Parent = barBack,
	})
	Kit.corner(8).Parent = fill
	record.billboard = billboard
end

local function updateBillboard(record: Tracked)
	local billboard = record.billboard
	if not billboard then
		return
	end
	local title = billboard:FindFirstChild("Title") :: TextLabel
	local bar = billboard:FindFirstChild("Bar") :: Frame
	local fill = bar:FindFirstChild("Fill") :: Frame
	if record.model:GetAttribute("Ripe") then
		local mutationsText = record.model:GetAttribute("Mutations")
		local hasMutation = typeof(mutationsText) == "string" and mutationsText ~= ""
		title.Text = `✋ {Format.short(slimeValue(record.model))} 🪙`
		title.TextColor3 = if hasMutation then Theme.Colors.Pink else Theme.Colors.Coin
		bar.Visible = false
	else
		title.Text = `⏳ {Format.clock(remainingSeconds(record.model))}`
		title.TextColor3 = Theme.Colors.Text
		bar.Visible = true
		fill.Size = UDim2.fromScale(progressOf(record.model), 1)
	end
end

local function updatePrompt(record: Tracked)
	if not record.own then
		return
	end
	local ripe = record.model:GetAttribute("Ripe") == true
	if ripe and not record.prompt then
		local body = record.model:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			local speciesId = record.model:GetAttribute("Species")
			local species = if typeof(speciesId) == "string" then Species.byId[speciesId] else nil
			local prompt: ProximityPrompt = Kit.new("ProximityPrompt", {
				Name = "HarvestPrompt",
				ActionText = "Harvest",
				ObjectText = if species then species.name else "Slime",
				HoldDuration = 0,
				MaxActivationDistance = 11,
				RequiresLineOfSight = false,
				KeyboardKeyCode = Enum.KeyCode.E,
				Parent = body,
			})
			prompt:SetAttribute("Tile", record.model:GetAttribute("Tile"))
			record.prompt = prompt
		end
	elseif not ripe and record.prompt then
		record.prompt:Destroy()
		record.prompt = nil
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local owner = model:GetAttribute("OwnerUserId")
	local record: Tracked = {
		model = model,
		own = owner == player.UserId,
		base = model:GetPivot(),
		scale = 1,
		phase = math.random() * math.pi * 2,
		billboard = nil,
		prompt = nil,
	}
	tracked[model] = record
	if record.own then
		buildBillboard(record)
		updateBillboard(record)
		updatePrompt(record)
	end
	model:GetAttributeChangedSignal("Ripe"):Connect(function()
		updatePrompt(record)
		updateBillboard(record)
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			tracked[model] = nil
		end
	end)
end

local function watchFolder(folder: Instance)
	for _, child in folder:GetChildren() do
		track(child)
	end
	folder.ChildAdded:Connect(track)
end

-- Ambient slimes (shopkeepers, fountain) bounce too.
local function trackAmbient(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("Bounce") then
			tracked[descendant] = {
				model = descendant,
				own = false,
				base = descendant:GetPivot(),
				scale = 1,
				phase = math.random() * math.pi * 2,
				billboard = nil,
				prompt = nil,
			}
		end
	end
end

function GardenView.ripeCount(): number
	local count = 0
	for model, record in tracked do
		if record.own and model:GetAttribute("Ripe") then
			count += 1
		end
	end
	return count
end

function GardenView.growingCount(): number
	local count = 0
	for model, record in tracked do
		if
			record.own
			and model.Parent
			and model.Parent.Name == "Plants"
			and not model:GetAttribute("Ripe")
		then
			count += 1
		end
	end
	return count
end

local function plantOnTile(plot: Model, tileIndex: number): boolean
	local plants = plot:FindFirstChild("Plants")
	return plants ~= nil and plants:FindFirstChild(`Plant{tileIndex}`) ~= nil
end

function GardenView.plant(tileIndex: number): boolean
	local main = State.main()
	local plot = ownPlot()
	if not main or not plot then
		return false
	end
	ensureSelection()
	local seed = GardenView.selectedSeed
	if not seed or (main.seeds[seed] or 0) < 1 then
		Notifications.toast("Out of seeds! Buy more at the Seed Shop 🌱", "info")
		return false
	end
	if plantOnTile(plot, tileIndex) then
		return false
	end
	Net.event("Plant"):FireServer(tileIndex, seed)
	return true
end

-- Plants the selected seed on every empty usable tile (paced under the
-- server's rate limit).
function GardenView.plantAll()
	local plot = ownPlot()
	local main = State.main()
	if not plot or not main then
		return
	end
	ensureSelection()
	local seed = GardenView.selectedSeed
	if not seed then
		Notifications.toast("Out of seeds! Buy more at the Seed Shop 🌱", "info")
		return
	end
	local available = main.seeds[seed] or 0
	local tiles = {}
	for _, child in plot:GetChildren() do
		local index = child:GetAttribute("TileIndex")
		if typeof(index) == "number" and child:GetAttribute("Usable") and not plantOnTile(plot, index) then
			table.insert(tiles, index)
		end
	end
	table.sort(tiles)
	if #tiles == 0 then
		Notifications.toast("No empty tiles! Harvest or unlock more.", "info")
		return
	end
	task.spawn(function()
		for i = 1, math.min(#tiles, available) do
			Net.event("Plant"):FireServer(tiles[i], seed)
			task.wait(0.08)
		end
	end)
end

local function onTileTapped(tile: BasePart, tileIndex: number)
	local main = State.main()
	local plot = ownPlot()
	if not main or not plot then
		return
	end
	if tile:GetAttribute("Usable") then
		GardenView.plant(tileIndex)
		return
	end
	if tileIndex > Config.Plots.FreeTileLimit then
		Windows.open("Store")
		Notifications.toast("⭐ This row comes with the Big Garden pass.", "info")
		return
	end
	local nextTile = main.unlockedTiles + 1
	local cost = Economy.tileCost(nextTile)
	if tileIndex ~= nextTile then
		Notifications.toast(
			`Unlock tiles in order — the next one costs {Format.short(cost)} coins.`,
			"info"
		)
		return
	end
	Windows.confirm("Unlock Tile", `Expand your garden for {Format.short(cost)} coins?`, "Unlock", function()
		Net.event("UnlockTile"):FireServer()
	end)
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

local function raycastOwnPlot(screenPosition: Vector2): RaycastResult?
	local plot = ownPlot()
	local camera = Workspace.CurrentCamera
	if not plot or not camera then
		return nil
	end
	raycastParams.FilterDescendantsInstances = { plot }
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	return Workspace:Raycast(ray.Origin, ray.Direction * 600, raycastParams)
end

local function plantModelFrom(instance: Instance): Model?
	local current: Instance? = instance
	while current do
		if current:IsA("Model") and current.Parent and current.Parent.Name == "Plants" then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function onWorldTap(screenPosition: Vector2)
	local result = raycastOwnPlot(screenPosition)
	if not result then
		return
	end
	local plantModel = plantModelFrom(result.Instance)
	if plantModel then
		local tileIndex = plantModel:GetAttribute("Tile")
		if plantModel:GetAttribute("Ripe") then
			Net.event("Harvest"):FireServer(tileIndex)
		else
			Notifications.toast(`Still growing… ⏳ {Format.clock(remainingSeconds(plantModel))}`, "info")
		end
		return
	end
	local tileIndex = result.Instance:GetAttribute("TileIndex")
	if typeof(tileIndex) == "number" and result.Instance:IsA("BasePart") then
		onTileTapped(result.Instance, tileIndex)
	end
end

local function updateHover(screenPosition: Vector2)
	local highlight = hoverHighlight
	if not highlight then
		return
	end
	local result = raycastOwnPlot(screenPosition)
	local target: Instance? = nil
	if result then
		local plantModel = plantModelFrom(result.Instance)
		if plantModel and plantModel:GetAttribute("Ripe") then
			target = plantModel
		elseif result.Instance:GetAttribute("TileIndex") then
			target = result.Instance
		end
	end
	highlight.Adornee = target
	highlight.Enabled = target ~= nil
end

local function animate()
	local t = os.clock()
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	for model, record in tracked do
		if not model.Parent then
			tracked[model] = nil
			continue
		end
		local isPlant = model.Parent.Name == "Plants"
		local ripe = not isPlant or model:GetAttribute("Ripe") == true

		local near = (record.base.Position - cameraPosition).Magnitude < 170
		if isPlant and (near or ripe) then
			local minScale = Config.Growth.MinVisualScale
			local target = if ripe then 1 else minScale + (1 - minScale) * progressOf(model)
			-- ~35 visible growth steps per plant keeps ScaleTo calls cheap.
			if math.abs(target - record.scale) > 0.02 or (ripe and record.scale ~= 1) then
				record.scale = target
				model:PivotTo(record.base)
				model:ScaleTo(target)
			end
		end

		if ripe and near then
			local hop = math.abs(math.sin(t * 3.2 + record.phase)) * 0.35 * record.scale
			model:PivotTo(record.base * CFrame.new(0, hop, 0))
			if model:GetAttribute("Rainbow") then
				local body = model:FindFirstChild("Body")
				if body and body:IsA("BasePart") then
					body.Color = Color3.fromHSV((t * 0.25 + record.phase) % 1, 0.7, 1)
				end
			end
			-- Orbiting stars (Cosmic / Prism): placed directly each frame so
			-- they never drift relative to the bouncing body.
			local orbit = model:FindFirstChild("Orbit")
			local body = model.PrimaryPart
			if orbit and body then
				local center = body.Position
				local radius = body.Size.X * 0.68
				for _, star in orbit:GetChildren() do
					if star:IsA("BasePart") then
						local index = tonumber(string.match(star.Name, "%d+")) or 0
						local angle = index / 8 * math.pi * 2 + t * 1.2
						star.CFrame = CFrame.new(
							center
								+ Vector3.new(
									math.cos(angle) * radius,
									math.sin(angle) * radius * 0.35,
									math.sin(angle) * radius
								)
						)
					end
				end
			end
		end
	end
end

function GardenView.start()
	local world = Workspace:WaitForChild("SlimeGarden")
	plotsFolder = world:WaitForChild("Plots") :: Folder
	for _, plot in (plotsFolder :: Folder):GetChildren() do
		local plants = plot:WaitForChild("Plants")
		watchFolder(plants)
	end
	trackAmbient(world:WaitForChild("Hub"))

	-- Billboards refresh 4x per second; motion runs every frame.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, record in tracked do
				if record.own then
					updateBillboard(record)
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(animate)

	-- Input: taps on touch devices, clicks on desktop.
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if not processedByUI then
			onWorldTap(position)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onWorldTap(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	if UserInputService.MouseEnabled then
		hoverHighlight = Kit.new("Highlight", {
			Name = "TileHover",
			FillColor = Color3.fromRGB(255, 255, 200),
			FillTransparency = 0.75,
			OutlineColor = Color3.fromRGB(255, 255, 255),
			OutlineTransparency = 0.2,
			DepthMode = Enum.HighlightDepthMode.Occluded,
			Enabled = false,
			Parent = player:WaitForChild("PlayerGui"),
		})
		local lastHover = 0
		UserInputService.InputChanged:Connect(function(input, processed)
			if input.UserInputType == Enum.UserInputType.MouseMovement and os.clock() - lastHover > 0.05 then
				lastHover = os.clock()
				if processed then
					(hoverHighlight :: Highlight).Enabled = false
				else
					updateHover(Vector2.new(input.Position.X, input.Position.Y))
				end
			end
		end)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		if prompt.Name == "HarvestPrompt" then
			local tileIndex = prompt:GetAttribute("Tile")
			if typeof(tileIndex) == "number" then
				Net.event("Harvest"):FireServer(tileIndex)
			end
		end
	end)

	State.Changed:Connect(function(section)
		if section == "main" then
			ensureSelection()
		end
	end)
end

return GardenView
